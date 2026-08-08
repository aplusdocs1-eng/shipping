// Real backend for the admin Settings screen's "API for 3rd Party Vendors"
// section. Authenticates vendor requests via a bearer key stored in
// vendor_api_keys (not Supabase Auth — vendors are external systems, not
// app users), then reads/writes real warehouse data scoped to this One
// Village instance. Exposed publicly at /api/v1/* via a Vercel rewrite
// (see .vercel/output/config.json) so vendors never see the raw
// supabase.co function URL.
import { createClient } from "jsr:@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body, null, 2), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

// Fixed sample data returned for sandbox-mode keys, so a vendor can build
// against the API without ever touching real warehouse data.
const SANDBOX = {
  packages: [
    {
      id: "sandbox-pkg-1",
      tracking_number: "SANDBOX-0001",
      customer_name: "Sandbox Customer",
      description: "Sample package",
      status: "pending",
      origin: "Miami, FL",
      destination: "Kingston, JA",
      weight: 4.2,
      declared_value: 85,
      created_at: "2026-01-01T12:00:00Z",
    },
  ],
  shipments: [
    {
      id: "sandbox-ship-1",
      shipment_number: "SANDBOX-AIR-001",
      origin: "Miami, FL",
      destination: "Kingston, JA",
      carrier: "Sandbox Air",
      status: "preparing",
      total_packages: 1,
      total_weight: 4.2,
      created_at: "2026-01-01T12:00:00Z",
    },
  ],
  preAlerts: [
    {
      id: "sandbox-pa-1",
      tracking_number: "SANDBOX-PA-0001",
      customer_name: "Sandbox Customer",
      carrier: "UPS",
      description: "Sample pre-alert",
      status: "pending",
      weight: 2,
      declared_value: 40,
      created_at: "2026-01-01T12:00:00Z",
    },
  ],
  invoices: [
    {
      id: "sandbox-inv-1",
      invoice_number: "SANDBOX-INV-0001",
      customer_name: "Sandbox Customer",
      amount: 50,
      tax: 5,
      total: 55,
      status: "sent",
      created_at: "2026-01-01T12:00:00Z",
    },
  ],
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });

  const authHeader = req.headers.get("Authorization") ?? "";
  const key = authHeader.replace(/^Bearer\s+/i, "").trim();
  if (!key) {
    return json({ error: "Missing Authorization header. Use: Authorization: Bearer YOUR_API_KEY" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const admin = createClient(supabaseUrl, serviceRoleKey);

  const { data: keyRow, error: keyErr } = await admin
    .from("vendor_api_keys")
    .select("id, sandbox, is_active")
    .eq("key", key)
    .maybeSingle();

  if (keyErr) return json({ error: keyErr.message }, 500);
  if (!keyRow || !keyRow.is_active) return json({ error: "Invalid or inactive API key" }, 401);

  const sandbox = keyRow.sandbox === true;

  // Path relative to the function name, e.g. "/vendor-api/packages" -> "packages".
  const url = new URL(req.url);
  const parts = url.pathname.split("/").filter(Boolean);
  const fnIdx = parts.indexOf("vendor-api");
  const segments = fnIdx >= 0 ? parts.slice(fnIdx + 1) : parts;
  const [resource, param] = segments;

  try {
    if (resource === "packages" && req.method === "GET" && !param) {
      if (sandbox) return json({ data: SANDBOX.packages, sandbox: true });
      const { data, error } = await admin
        .from("packages")
        .select(
          "id, tracking_number, customer_name, description, status, origin, destination, weight, declared_value, created_at",
        )
        .order("created_at", { ascending: false })
        .limit(100);
      if (error) throw error;
      return json({ data });
    }

    if (resource === "packages" && req.method === "GET" && param) {
      if (sandbox) {
        const match = SANDBOX.packages.find((p) => p.tracking_number === param);
        return match ? json({ data: match, sandbox: true }) : json({ error: "Package not found" }, 404);
      }
      const { data, error } = await admin
        .from("packages")
        .select(
          "id, tracking_number, customer_name, description, status, origin, destination, weight, declared_value, created_at",
        )
        .eq("tracking_number", param)
        .maybeSingle();
      if (error) throw error;
      if (!data) return json({ error: "Package not found" }, 404);
      return json({ data });
    }

    if (resource === "packages" && req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      if (!body.tracking_number) return json({ error: "tracking_number is required" }, 400);
      if (sandbox) {
        return json({ data: { ...body, id: "sandbox-generated", status: "pending" }, sandbox: true }, 201);
      }
      const { data, error } = await admin
        .from("packages")
        .insert({
          tracking_number: body.tracking_number,
          customer_name: body.customer_name ?? "",
          description: body.description ?? "",
          origin: body.origin ?? null,
          destination: body.destination ?? null,
          weight: body.weight ?? 0,
          declared_value: body.declared_value ?? 0,
          service_type: body.service_type ?? "standard",
          status: "pending",
        })
        .select()
        .single();
      if (error) throw error;
      return json({ data }, 201);
    }

    if (resource === "shipments" && req.method === "GET") {
      if (sandbox) return json({ data: SANDBOX.shipments, sandbox: true });
      const { data, error } = await admin
        .from("shipments")
        .select(
          "id, shipment_number, origin, destination, carrier, status, total_packages, total_weight, estimated_arrival, created_at",
        )
        .order("created_at", { ascending: false })
        .limit(100);
      if (error) throw error;
      return json({ data });
    }

    if (resource === "shipments" && req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      if (!body.shipment_number) return json({ error: "shipment_number is required" }, 400);
      if (sandbox) {
        return json({ data: { ...body, id: "sandbox-generated", status: "preparing" }, sandbox: true }, 201);
      }
      const { data, error } = await admin
        .from("shipments")
        .insert({
          shipment_number: body.shipment_number,
          origin: body.origin ?? "",
          destination: body.destination ?? "",
          carrier: body.carrier ?? "",
          total_packages: body.total_packages ?? 0,
          total_weight: body.total_weight ?? 0,
          estimated_arrival: body.estimated_arrival ?? null,
          vessel_name: body.vessel_name ?? null,
          flight_number: body.flight_number ?? null,
          notes: body.notes ?? null,
          status: "preparing",
        })
        .select()
        .single();
      if (error) throw error;
      return json({ data }, 201);
    }

    if (resource === "pre-alerts" && req.method === "GET") {
      if (sandbox) return json({ data: SANDBOX.preAlerts, sandbox: true });
      const { data, error } = await admin
        .from("pre_alerts")
        .select(
          "id, tracking_number, customer_name, carrier, description, status, weight, declared_value, freight_type, created_at",
        )
        .order("created_at", { ascending: false })
        .limit(100);
      if (error) throw error;
      return json({ data });
    }

    if (resource === "pre-alerts" && req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      if (!body.tracking_number) return json({ error: "tracking_number is required" }, 400);
      if (sandbox) {
        return json({ data: { ...body, id: "sandbox-generated", status: "pending" }, sandbox: true }, 201);
      }
      const { data, error } = await admin
        .from("pre_alerts")
        .insert({
          tracking_number: body.tracking_number,
          customer_name: body.customer_name ?? "",
          carrier: body.carrier ?? "",
          description: body.description ?? "",
          weight: body.weight ?? 0,
          declared_value: body.declared_value ?? 0,
          freight_type: body.freight_type ?? "air",
          status: "pending",
        })
        .select()
        .single();
      if (error) throw error;
      return json({ data }, 201);
    }

    if (resource === "invoices" && req.method === "GET") {
      if (sandbox) return json({ data: SANDBOX.invoices, sandbox: true });
      const { data, error } = await admin
        .from("invoices")
        .select("id, invoice_number, customer_name, amount, tax, total, status, due_date, created_at")
        .order("created_at", { ascending: false })
        .limit(100);
      if (error) throw error;
      return json({ data });
    }

    if (resource === "webhooks" && req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      if (!body.url) return json({ error: "url is required" }, 400);
      try {
        new URL(body.url);
      } catch {
        return json({ error: "url must be a valid absolute URL" }, 400);
      }
      if (sandbox) {
        return json({ data: { id: "sandbox-generated", url: body.url, event: body.event ?? "package.created" }, sandbox: true }, 201);
      }
      const { data, error } = await admin
        .from("vendor_webhooks")
        .insert({ url: body.url, event: body.event ?? "package.created" })
        .select()
        .single();
      if (error) throw error;
      return json({ data }, 201);
    }

    return json({ error: `No route for ${req.method} /${segments.join("/")}` }, 404);
  } catch (e) {
    return json({ error: e instanceof Error ? e.message : "Internal error" }, 500);
  }
});
