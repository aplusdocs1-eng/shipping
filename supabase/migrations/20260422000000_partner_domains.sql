-- ═══════════════════════════════════════════════════════════════
-- Multi-tenant: map a browser hostname (domain) to a partner.
-- Partners provide their own domain (e.g. track.howdidship.com)
-- during signup; the Flutter web app reads window.location.hostname
-- and scopes login/signup UI to that partner.
-- Idempotent.
-- ═══════════════════════════════════════════════════════════════

-- 1. domain column
ALTER TABLE partner_accounts
  ADD COLUMN IF NOT EXISTS domain TEXT;

-- Store domains lower-cased for case-insensitive match
CREATE UNIQUE INDEX IF NOT EXISTS idx_partner_accounts_domain_lower
  ON partner_accounts (LOWER(domain))
  WHERE domain IS NOT NULL AND domain <> '';

-- 2. Recreate create_partner_account RPC to accept domain (nullable)
CREATE OR REPLACE FUNCTION create_partner_account(
  p_auth_user_id   UUID,
  p_company_name   TEXT,
  p_contact_name   TEXT,
  p_email          TEXT,
  p_phone          TEXT,
  p_tracking_prefix TEXT,
  p_domain         TEXT DEFAULT NULL
)
RETURNS SETOF partner_accounts
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  INSERT INTO partner_accounts (
    auth_user_id, company_name, contact_name, email, phone,
    tracking_prefix, domain, status
  )
  VALUES (
    p_auth_user_id, p_company_name, p_contact_name, p_email,
    NULLIF(p_phone, ''), p_tracking_prefix,
    NULLIF(LOWER(TRIM(p_domain)), ''), 'pending'
  )
  RETURNING *;
END;
$$;

GRANT EXECUTE ON FUNCTION create_partner_account(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) TO anon, authenticated;

-- 3. Public lookup used by the Flutter app on startup to resolve the
-- current hostname to a partner. Returns only safe, public fields.
CREATE OR REPLACE FUNCTION get_partner_by_domain(p_domain TEXT)
RETURNS TABLE (
  id UUID,
  company_name TEXT,
  tracking_prefix TEXT,
  domain TEXT,
  status TEXT
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT id, company_name, tracking_prefix, domain, status
  FROM partner_accounts
  WHERE domain IS NOT NULL
    AND LOWER(domain) = LOWER(TRIM(p_domain))
    AND status = 'approved'
  LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION get_partner_by_domain(TEXT) TO anon, authenticated;
