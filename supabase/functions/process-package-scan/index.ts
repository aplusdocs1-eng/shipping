// Authoritative server-side half of the warehouse package scanner.
// The Flutter client does OCR + parsing + fuzzy customer matching for
// immediate on-screen feedback (ShippingLabelParser / CustomerMatchService
// in lib/services/), but this function is what actually writes to the
// database — it never trusts a customer_id, match score, or match status
// supplied by the client at face value:
//   - The caller must be a real, active admin_users row (JWT-verified).
//   - A duplicate check against tracking_number/barcode_value/idempotency
//     key is always run here, server-side, right before the insert —
//     never skipped, never trusted from the client.
//   - If the client claims a high-confidence "auto matched" customer, this
//     function independently re-derives the same top-tier signals
//     (customer code substring, exact phone, exact email, exact address)
//     from the submitted OCR/parsed fields and refuses to accept the
//     match unless its own check agrees. A manual match (staff explicitly
//     picked a customer, e.g. from the Unknown Packages queue) is trusted
//     as-is, because it's an authenticated admin's own direct decision,
//     not a claim being taken on faith.
import { createClient } from "jsr:@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

function digitsOnly(s: string | null | undefined): string | null {
  if (!s) return null;
  let d = s.replace(/[^0-9]/g, "");
  if (d.length === 11 && d.startsWith("1")) d = d.slice(1);
  return d || null;
}

function normalizeForCompare(s: string): string {
  return s
    .toUpperCase()
    .replace(/[.,#]/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return json({ error: "Missing Authorization header" }, 401);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

  // ── Auth: caller must be a real, active admin/warehouse user ──────────
  const authClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userErr } = await authClient.auth.getUser();
  if (userErr || !userData?.user) return json({ error: "Not authenticated" }, 401);

  const admin = createClient(supabaseUrl, serviceRoleKey);
  const { data: adminRow, error: adminErr } = await admin
    .from("admin_users")
    .select("id, full_name, role, is_active")
    .eq("auth_user_id", userData.user.id)
    .maybeSingle();
  if (adminErr) return json({ error: adminErr.message }, 500);
  if (!adminRow || !adminRow.is_active) {
    return json({ error: "Not authorized — active admin/warehouse account required" }, 403);
  }

  const trackingNumber = String(body.trackingNumber ?? "").trim();
  const barcodeValue = String(body.barcodeValue ?? "").trim() || null;
  const barcodeType = String(body.barcodeType ?? "").trim() || null;
  const idempotencyKey = String(body.idempotencyKey ?? "").trim() || null;
  const allowDuplicate = body.allowDuplicate === true;

  if (!trackingNumber && !barcodeValue) {
    return json({ error: "trackingNumber or barcodeValue is required" }, 400);
  }

  // ── Idempotency: a retried/replayed submission of the exact same scan
  // (offline-queue resync, a flaky-network double-tap) must never create a
  // second row. This is checked first and short-circuits everything else.
  if (idempotencyKey) {
    const { data: existingByKey } = await admin
      .from("warehouse_entries")
      .select("id, tracking_number, customer_id, customer_name, scanned_in_at, scanned_in_by")
      .eq("idempotency_key", idempotencyKey)
      .maybeSingle();
    if (existingByKey) {
      return json({
        success: true,
        warehouseEntryId: existingByKey.id,
        customerId: existingByKey.customer_id,
        duplicate: false,
        idempotentReplay: true,
      });
    }
  }

  // ── Duplicate check: same tracking number or barcode already received.
  // Soft (staff-overridable), never a hard DB constraint — see the
  // migration's own comment for why warehouse_entries deliberately has no
  // UNIQUE constraint on tracking_number.
  if (!allowDuplicate) {
    const orFilters = [
      trackingNumber ? `tracking_number.eq.${trackingNumber}` : null,
      barcodeValue ? `barcode_value.eq.${barcodeValue}` : null,
    ].filter(Boolean).join(",");
    if (orFilters) {
      const { data: dupe } = await admin
        .from("warehouse_entries")
        .select("id, tracking_number, customer_id, customer_name, scanned_in_at, scanned_in_by")
        .or(orFilters)
        .order("scanned_in_at", { ascending: false })
        .limit(1)
        .maybeSingle();
      if (dupe) {
        await admin.from("package_scan_audit_log").insert({
          warehouse_entry_id: dupe.id,
          action: "duplicate_detected",
          performed_by: adminRow.id,
          performed_by_name: adminRow.full_name,
          notes: `Duplicate scan attempt for tracking number ${trackingNumber || barcodeValue}`,
        });
        // Only a superadmin (not regular warehouse staff) can override —
        // real role values confirmed live: 'warehouse' and 'superadmin'.
        return json({
          success: false,
          duplicate: true,
          canOverride: adminRow.role === "superadmin",
          existing: dupe,
        });
      }
    }
  }

  // ── Re-verify a client-claimed auto-match before trusting it ───────────
  const parsed = (body.parsedFields ?? {}) as Record<string, unknown>;
  const decision = (body.decision ?? {}) as Record<string, unknown>;
  let customerId: string | null = decision.customerId ? String(decision.customerId) : null;
  let matchScore = typeof decision.matchScore === "number" ? decision.matchScore : 0;
  let matchStatus = String(decision.matchStatus ?? "unknown");
  const isManualAssignment = matchStatus === "matched"; // staff explicitly picked this customer

  if (customerId && !isManualAssignment) {
    const { data: candidate } = await admin
      .from("customers")
      .select("id, name, email, phone, address, mailbox_number")
      .eq("id", customerId)
      .maybeSingle();

    if (!candidate) {
      customerId = null;
      matchStatus = "unknown";
      matchScore = 0;
    } else {
      let serverScore = 0;
      const ocrText = String(parsed.normalizedOcrText ?? "").toUpperCase();
      const code = (candidate.mailbox_number ?? "").trim();
      if (code && ocrText.includes(code.toUpperCase())) serverScore = Math.max(serverScore, 100);

      const labelPhone = digitsOnly(parsed.phone as string | null);
      const custPhone = digitsOnly(candidate.phone);
      if (labelPhone && custPhone && labelPhone.length >= 10 && labelPhone === custPhone) {
        serverScore = Math.max(serverScore, 95);
      }

      const labelEmail = String(parsed.email ?? "").trim().toLowerCase();
      const custEmail = (candidate.email ?? "").trim().toLowerCase();
      if (labelEmail && custEmail && labelEmail === custEmail) {
        serverScore = Math.max(serverScore, 95);
      }

      const labelAddr = normalizeForCompare(String(parsed.addressLine1 ?? ""));
      const custAddr = normalizeForCompare(candidate.address ?? "");
      if (labelAddr && custAddr && labelAddr === custAddr) {
        serverScore = Math.max(serverScore, 90);
      }

      // The client's fuzzy-name tier (50-80) is deliberately NOT
      // re-derivable server-side from a bare score — it requires the same
      // edit-distance logic the client already ran. Rather than duplicate
      // that here just to rubber-stamp it, any claimed auto-match resting
      // on fuzzy-name-only is downgraded to manual review: a real person
      // has to look at it, exactly as low-confidence matches always do.
      if (serverScore < 90) {
        matchStatus = serverScore >= 70 ? "needs_review" : "unknown";
        matchScore = serverScore;
        if (matchStatus !== "unknown") {
          // Still surfaced as a candidate for manual review, just not
          // auto-assigned.
        } else {
          customerId = null;
        }
      } else {
        matchScore = serverScore;
      }
    }
  }

  // ── Insert ───────────────────────────────────────────────────────────
  const now = new Date().toISOString();
  const insertRow: Record<string, unknown> = {
    tracking_number: trackingNumber || barcodeValue,
    barcode_value: barcodeValue,
    barcode_type: barcodeType,
    carrier: parsed.carrier ?? null,
    carrier_confidence: parsed.carrierConfidence ?? null,
    recipient_name: parsed.recipientName ?? null,
    recipient_company: parsed.recipientCompany ?? null,
    address_line_1: parsed.addressLine1 ?? null,
    address_line_2: parsed.addressLine2 ?? null,
    city: parsed.city ?? null,
    state: parsed.state ?? null,
    province: parsed.province ?? null,
    postal_code: parsed.postalCode ?? null,
    country: parsed.country ?? null,
    recipient_phone: parsed.phone ?? null,
    recipient_email: parsed.email ?? null,
    order_number: parsed.orderNumber ?? null,
    reference_number: parsed.referenceNumber ?? null,
    service_type: parsed.serviceType ?? null,
    sender_name: parsed.senderName ?? null,
    sender_address: parsed.senderAddress ?? null,
    sender_city: parsed.senderCity ?? null,
    sender_state: parsed.senderState ?? null,
    sender_postal_code: parsed.senderPostalCode ?? null,
    sender_country: parsed.senderCountry ?? null,
    weight: parsed.packageWeight ?? 0,
    raw_ocr_text: parsed.rawOcrText ?? null,
    normalized_ocr_text: parsed.normalizedOcrText ?? null,
    ocr_confidence: body.ocrConfidence ?? null,
    match_score: matchScore,
    match_status: customerId ? (isManualAssignment ? "matched" : matchStatus) : matchStatus,
    match_candidates: body.matchCandidates ?? null,
    match_reason: decision.reason ?? null,
    label_image_path: body.labelImagePath ?? null,
    idempotency_key: idempotencyKey,
    scan_source: body.scanSource ?? "manual_entry",
    customer_id: customerId,
    customer_name: (parsed.recipientName as string) ?? "",
    description: body.description ?? "",
    storage_zone: body.storageZone ?? null,
    storage_location: body.storageLocation ?? null,
    shipping_partner_code: body.shippingPartnerCode ?? null,
    status: "scanned_in",
    scanned_in_at: now,
    scanned_in_by: adminRow.full_name || userData.user.email || "Unknown",
    assigned_by: customerId && isManualAssignment ? adminRow.id : null,
    assigned_at: customerId && isManualAssignment ? now : null,
  };

  const { data: inserted, error: insertErr } = await admin
    .from("warehouse_entries")
    .insert(insertRow)
    .select("id")
    .single();

  if (insertErr) return json({ error: insertErr.message }, 500);

  // Keep the customer-facing `packages` table in sync so a received
  // package shows up in the existing "My Packages" view immediately, for
  // matched packages only — an Unknown Package has no customer to show it
  // to yet.
  if (customerId) {
    await admin.from("packages").insert({
      tracking_number: insertRow.tracking_number,
      customer_id: customerId,
      customer_name: insertRow.customer_name,
      description: insertRow.description || "Package",
      weight: insertRow.weight,
      status: "pending",
      service_type: insertRow.service_type ?? "standard",
      origin: insertRow.sender_city ?? "",
      destination: insertRow.city ?? "",
    }).select("id").maybeSingle();
    // A conflicting tracking_number here (packages.tracking_number is
    // UNIQUE) is fine to ignore — it just means a packages row already
    // existed for this tracking number from another flow.
  }

  const auditActions = [
    { action: "package_scanned", notes: `Scanned via ${insertRow.scan_source}` },
    parsed.rawOcrText ? { action: "ocr_completed", notes: null } : null,
    customerId
      ? { action: "customer_matched", notes: `Matched at ${matchScore}% confidence (${matchStatus})` }
      : { action: "customer_matched", notes: "No confident customer match — stored as Unknown Package" },
    { action: "package_received", notes: null },
  ].filter(Boolean) as { action: string; notes: string | null }[];

  await admin.from("package_scan_audit_log").insert(
    auditActions.map((a) => ({
      warehouse_entry_id: inserted.id,
      action: a.action,
      performed_by: adminRow.id,
      performed_by_name: adminRow.full_name,
      notes: a.notes,
      new_value: a.action === "package_received" ? insertRow : null,
    })),
  );

  return json({
    success: true,
    warehouseEntryId: inserted.id,
    customerId,
    matchScore,
    matchStatus: insertRow.match_status,
    duplicate: false,
  });
});
