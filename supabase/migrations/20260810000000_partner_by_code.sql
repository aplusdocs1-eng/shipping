-- Lets a partner share a working customer-facing link immediately, without
-- first setting up a custom domain (DNS, CNAME, propagation, etc. — a real
-- barrier for a brand-new partner). Mirrors get_partner_by_domain exactly,
-- but resolves by tracking_prefix (their short public "code", already
-- shown to them on the Referrals page) via a `?partner=CODE` query param
-- instead of the hostname. Same SECURITY DEFINER + public-fields-only
-- pattern — safe for anon to call without exposing the rest of
-- partner_accounts (which anon can no longer read directly per the RLS
-- hardening in this schema).
CREATE OR REPLACE FUNCTION get_partner_by_code(p_code TEXT)
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
  WHERE status = 'approved'
    AND p_code IS NOT NULL
    AND TRIM(p_code) <> ''
    AND UPPER(REPLACE(tracking_prefix, '-', '')) = UPPER(REPLACE(TRIM(p_code), '-', ''))
  LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION get_partner_by_code(TEXT) TO anon, authenticated;
