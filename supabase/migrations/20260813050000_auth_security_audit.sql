-- ═══════════════════════════════════════════════════════════════
-- Security audit: "ensure proper authentication across the whole
-- site." Full review of every RLS policy and every SECURITY DEFINER
-- function on the live project (via `supabase db advisors` plus a
-- manual read of pg_policies) surfaced several real, pre-existing
-- gaps unrelated to anything built this session. Fixed here.
-- ═══════════════════════════════════════════════════════════════

-- ── 1. get_partner_account(uuid): unauthenticated IDOR ──────────
-- Took a client-supplied auth_user_id with NO check that it matched
-- the caller, and returned the FULL partner_accounts row (email,
-- phone, contact_name, tracking_prefix, domain) as SECURITY DEFINER
-- — callable by anon. Anyone could read any partner's contact info
-- with one unauthenticated REST call. Nothing in the app calls this
-- RPC (lib/services/database_service.dart's getPartnerAccount does a
-- plain RLS-protected .select() instead) — it was dead, dangerous
-- code, most likely superseded by that safer approach and never
-- dropped. Removed outright rather than "fixed", since the safe
-- version already exists and is what's actually used.
DROP FUNCTION IF EXISTS public.get_partner_account(uuid);

-- ── 2. partner_accounts: unauthenticated arbitrary INSERT ───────
-- "Allow anon insert" / "Allow authenticated insert" had
-- WITH CHECK (true) — no restriction at all. Anyone, logged in or
-- not, could INSERT a row directly into partner_accounts with any
-- auth_user_id (not necessarily their own), any status (including
-- 'approved', bypassing the create_partner_account RPC's own logic
-- entirely), and any tracking_prefix — including one colliding with
-- an existing real courier's, which would let them read that
-- courier's warehouse_entries/packages via the prefix-scoped RLS
-- policies on those tables. create_partner_account is SECURITY
-- DEFINER and bypasses RLS for its own INSERT, so it never needed
-- these policies — confirmed no other code path does a raw insert
-- into this table.
DROP POLICY IF EXISTS "Allow anon insert" ON partner_accounts;
DROP POLICY IF EXISTS "Allow authenticated insert" ON partner_accounts;

-- ── 3. partner_accounts: unrestricted self-UPDATE ────────────────
-- "Partners update own" scoped by auth_user_id = auth.uid() but with
-- no column restriction — and the real "Company Profile" UI already
-- used it to let a partner rewrite their own tracking_prefix
-- directly. Since prefix is what scopes warehouse_entries/packages
-- access, a partner (malicious or just careless) could set their own
-- prefix to collide with another courier's and start seeing that
-- courier's packages in their own dashboard. Same class of problem
-- already fixed for customers this session (RLS restricts which rows
-- are visible, not which columns a client changes) — same fix: drop
-- the broad policy, replace with narrow RPCs that only ever touch
-- the fields they're named for. tracking_prefix, status, plan, and
-- domain are deliberately NOT among them — changing tracking_prefix
-- now requires direct admin/DB access, which is the right trade-off
-- given what it controls; domain already goes through its own
-- provision-partner-domain Edge Function (service_role, unaffected).
DROP POLICY IF EXISTS "Partners update own" ON partner_accounts;

CREATE OR REPLACE FUNCTION update_own_partner_profile(
  p_company_name TEXT,
  p_email TEXT,
  p_phone TEXT,
  p_address TEXT
)
RETURNS SETOF partner_accounts
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  UPDATE partner_accounts
     SET company_name = NULLIF(TRIM(p_company_name), ''),
         email = NULLIF(TRIM(p_email), ''),
         phone = NULLIF(TRIM(p_phone), ''),
         address = NULLIF(TRIM(p_address), ''),
         updated_at = now()
   WHERE auth_user_id = auth.uid()
  RETURNING *;
END;
$$;
GRANT EXECUTE ON FUNCTION update_own_partner_profile(TEXT, TEXT, TEXT, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION update_own_partner_preferred_branch(p_branch_id UUID)
RETURNS SETOF partner_accounts
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  UPDATE partner_accounts
     SET preferred_branch_id = p_branch_id,
         updated_at = now()
   WHERE auth_user_id = auth.uid()
  RETURNING *;
END;
$$;
GRANT EXECUTE ON FUNCTION update_own_partner_preferred_branch(UUID) TO authenticated;

-- Keeps the client-side key-generation logic as-is (see
-- _generateApiKey in partner_dashboard_screen.dart) — only the WRITE
-- moves to a narrow RPC; this isn't the identity-security-critical
-- field tracking_prefix is, so re-deriving it server-side isn't
-- necessary to close the actual gap (arbitrary-column self-update).
CREATE OR REPLACE FUNCTION regenerate_own_partner_api_key(p_api_key TEXT)
RETURNS SETOF partner_accounts
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  UPDATE partner_accounts
     SET api_key = p_api_key,
         updated_at = now()
   WHERE auth_user_id = auth.uid()
  RETURNING *;
END;
$$;
GRANT EXECUTE ON FUNCTION regenerate_own_partner_api_key(TEXT) TO authenticated;

-- ── 4. create_partner_account: orphaned old overloads ────────────
-- CREATE OR REPLACE only replaces a function with the exact same
-- parameter list — each time this function's signature grew (adding
-- p_domain, then p_plan), the old version became a second, silently
-- coexisting overload instead of being replaced. Both older versions
-- still set status = 'pending' (predating the auto-approve decision)
-- and never link a shipping_partners row or set partner_id, so an
-- account created through either one is a real but inert, orphaned,
-- confusing row a caller could still create today. The Dart client
-- always calls with all 8 named params, which PostgREST resolves
-- only to the current version — confirmed dropping the other two
-- doesn't affect the app.
DROP FUNCTION IF EXISTS public.create_partner_account(uuid, text, text, text, text, text);
DROP FUNCTION IF EXISTS public.create_partner_account(uuid, text, text, text, text, text, text);

-- ── 5. Partner-owned auxiliary tables: missing status check ──────
-- customers/invoices/packages/pre_alerts/payment_submissions/shipments
-- all scope partner access with "... AND partner_accounts.status =
-- 'approved'"; these 9 tables' "Partner manages own rows" policies
-- were missing that check. Low practical risk today (signup
-- auto-approves, so no 'pending' partner_accounts row should
-- normally exist) but inconsistent, and was a meaningfully bigger
-- risk before item 2 above was fixed (a forged 'pending' row via the
-- anon-insert hole could have used these). Bringing in line with the
-- other 6 tables' pattern.
DO $$
DECLARE
  t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'partner_broadcasts', 'partner_charges', 'partner_discounts',
    'partner_locations', 'partner_referrals', 'partner_roles',
    'partner_shipping_addresses', 'partner_staff', 'partner_support_tickets'
  ]
  LOOP
    EXECUTE format(
      'DROP POLICY IF EXISTS %I ON %I;
       CREATE POLICY %I ON %I FOR ALL TO authenticated
         USING (partner_id IN (SELECT id FROM partner_accounts WHERE auth_user_id = auth.uid() AND status = ''approved''))
         WITH CHECK (partner_id IN (SELECT id FROM partner_accounts WHERE auth_user_id = auth.uid() AND status = ''approved''));',
      'Partner manages own rows', t, 'Partner manages own rows', t
    );
  END LOOP;
END $$;

-- ── 6. update_updated_at: mutable search_path ────────────────────
-- Flagged by the linter — a trigger function with no search_path set
-- is (in general) vulnerable to being tricked into resolving an
-- unqualified name against a schema an attacker controls, if one
-- were earlier in the caller's search_path. Cheap, zero-behavior-
-- change hardening; matches every other function in this project.
CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;
