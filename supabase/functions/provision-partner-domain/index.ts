// Registers a partner's custom domain on the Vercel project so it's
// ready to serve traffic the moment the partner's own DNS points at us.
// DNS itself can never be automated here — that's the partner's own
// registrar — but Vercel-side registration is.
import { createClient } from "jsr:@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return json({ error: "Missing Authorization header" }, 401);

  let domain: string, partnerAccountId: string;
  try {
    const body = await req.json();
    domain = String(body.domain ?? "").trim().toLowerCase();
    partnerAccountId = String(body.partnerAccountId ?? "");
    if (!domain || !partnerAccountId) throw new Error("domain and partnerAccountId are required");
  } catch (e) {
    return json({ error: e instanceof Error ? e.message : "Invalid request body" }, 400);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  // Verify the caller's JWT identifies the same user that owns this partner account.
  const authClient = createClient(supabaseUrl, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userErr } = await authClient.auth.getUser();
  if (userErr || !userData?.user) return json({ error: "Not authenticated" }, 401);

  const admin = createClient(supabaseUrl, serviceRoleKey);
  const { data: account, error: accountErr } = await admin
    .from("partner_accounts")
    .select("id, auth_user_id, domain")
    .eq("id", partnerAccountId)
    .maybeSingle();

  if (accountErr) return json({ error: accountErr.message }, 500);
  if (!account) return json({ error: "Partner account not found" }, 404);
  if (account.auth_user_id !== userData.user.id) {
    return json({ error: "This partner account does not belong to you" }, 403);
  }

  const vercelToken = Deno.env.get("VERCEL_TOKEN");
  const vercelProjectId = Deno.env.get("VERCEL_PROJECT_ID");
  const vercelTeamId = Deno.env.get("VERCEL_TEAM_ID");
  if (!vercelToken || !vercelProjectId || !vercelTeamId) {
    return json({ error: "Domain provisioning is not configured on the server yet." }, 503);
  }

  const vercelRes = await fetch(
    `https://api.vercel.com/v10/projects/${vercelProjectId}/domains?teamId=${vercelTeamId}`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${vercelToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ name: domain }),
    },
  );
  const vercelBody = await vercelRes.json();

  if (!vercelRes.ok) {
    // Domain already registered on this same project is not a failure —
    // treat it as success so retries/re-saves are safe.
    const code = vercelBody?.error?.code;
    if (code !== "domain_already_in_use" || vercelBody?.error?.projectId !== vercelProjectId) {
      return json({ error: vercelBody?.error?.message ?? "Vercel domain registration failed" }, 502);
    }
  }

  await admin
    .from("partner_accounts")
    .update({ domain: domain, domain_status: "pending_dns" })
    .eq("id", partnerAccountId);

  return json({
    status: "pending_dns",
    domain,
    verification: vercelBody?.verification ?? null,
    instructions:
      "Add a CNAME record for this domain pointing to cname.vercel-dns.com at your DNS provider. " +
      "It can take a few minutes to a few hours to propagate.",
  });
});
