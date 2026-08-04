-- ═══════════════════════════════════════════════════════════════
-- Partner self-serve signup: plan selection, domain provisioning
-- state, auto-approve, and customer self-signup linkage.
-- Idempotent.
-- ═══════════════════════════════════════════════════════════════

-- 1. partner_accounts: plan, address, domain provisioning status
ALTER TABLE partner_accounts ADD COLUMN IF NOT EXISTS plan TEXT;
ALTER TABLE partner_accounts ADD COLUMN IF NOT EXISTS address TEXT;
ALTER TABLE partner_accounts ADD COLUMN IF NOT EXISTS domain_status TEXT NOT NULL DEFAULT 'unset';

-- 2. customers: link a self-registered customer to their Supabase Auth user
ALTER TABLE customers ADD COLUMN IF NOT EXISTS auth_user_id UUID UNIQUE REFERENCES auth.users(id);

-- 3. Recreate create_partner_account: accept plan, auto-approve, and
-- atomically create the linked shipping_partners row (previously done
-- as a separate best-effort client insert with no RLS policy covering
-- it under the hardened rules).
CREATE OR REPLACE FUNCTION create_partner_account(
  p_auth_user_id    UUID,
  p_company_name    TEXT,
  p_contact_name    TEXT,
  p_email           TEXT,
  p_phone           TEXT,
  p_tracking_prefix TEXT,
  p_domain          TEXT DEFAULT NULL,
  p_plan            TEXT DEFAULT NULL
)
RETURNS SETOF partner_accounts
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_shipping_partner_id UUID;
  v_code TEXT;
BEGIN
  v_code := LEFT(p_tracking_prefix, 3);

  INSERT INTO shipping_partners (code, name, region, tracking_prefix, contact_email, is_active)
  VALUES (v_code, p_company_name, '', p_tracking_prefix, p_email, true)
  ON CONFLICT (code) DO NOTHING
  RETURNING id INTO v_shipping_partner_id;

  RETURN QUERY
  INSERT INTO partner_accounts (
    auth_user_id, company_name, contact_name, email, phone,
    tracking_prefix, domain, plan, partner_id, status
  )
  VALUES (
    p_auth_user_id, p_company_name, p_contact_name, p_email,
    NULLIF(p_phone, ''), p_tracking_prefix,
    NULLIF(LOWER(TRIM(p_domain)), ''), p_plan, v_shipping_partner_id,
    'approved'
  )
  RETURNING *;
END;
$$;

GRANT EXECUTE ON FUNCTION create_partner_account(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) TO anon, authenticated;

-- 4. Customer self-signup RPC (SECURITY DEFINER — the hardened RLS
-- policies require a customer row to already exist and be linked via
-- auth_user_id before any client-side insert would be permitted, so
-- account creation itself must go through here, same pattern as
-- create_partner_account).
CREATE OR REPLACE FUNCTION create_customer_account(
  p_auth_user_id UUID,
  p_partner_id   UUID,
  p_name         TEXT,
  p_email        TEXT,
  p_phone        TEXT DEFAULT NULL
)
RETURNS SETOF customers
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  INSERT INTO customers (auth_user_id, partner_id, name, email, phone, status)
  VALUES (p_auth_user_id, p_partner_id, p_name, p_email, NULLIF(p_phone, ''), 'active')
  RETURNING *;
END;
$$;

GRANT EXECUTE ON FUNCTION create_customer_account(UUID, UUID, TEXT, TEXT, TEXT) TO anon, authenticated;
