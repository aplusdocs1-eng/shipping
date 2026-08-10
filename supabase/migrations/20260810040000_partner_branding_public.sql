-- Lets a courier's customer-facing login page ("their customer main page")
-- actually reflect what the courier saves in the dashboard's Settings ->
-- Customization tab. That tab has saved branding_* keys into
-- partner_accounts.settings since it was first built, but nothing ever
-- read them back — CustomerLoginScreen was 100% hardcoded to One Village's
-- own branding regardless of which courier's link a customer visited.
--
-- The customer viewing this page is anonymous (or at most authenticated as
-- a *different* customer) — never the courier themselves — so this has to
-- go through the same public, SECURITY DEFINER lookup RPCs already used to
-- resolve the tenant (get_partner_by_domain / get_partner_by_code), not
-- direct table access. `settings` also holds unrelated, non-public
-- configuration for other tabs (currency, charges, discounts, webhooks,
-- API sync, etc.), so this deliberately extracts and exposes only the
-- specific branding_* keys as a curated `branding` object, not the raw
-- settings column.
-- CREATE OR REPLACE cannot change an existing function's return row
-- shape (adding the `branding` column counts as changing it) — drop
-- first.
DROP FUNCTION IF EXISTS get_partner_by_domain(TEXT);
CREATE FUNCTION get_partner_by_domain(p_domain TEXT)
RETURNS TABLE (
  id UUID,
  company_name TEXT,
  tracking_prefix TEXT,
  domain TEXT,
  status TEXT,
  branding JSONB
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT id, company_name, tracking_prefix, domain, status,
    jsonb_build_object(
      'color', settings->'branding_color',
      'portalTitle', settings->>'branding_portal_title',
      'subtitle', settings->>'branding_subtitle',
      'features', COALESCE(settings->'branding_features', '[]'::jsonb),
      'logoUrl', settings->>'branding_logo_url',
      'heroImageUrl', settings->>'branding_hero_image_url'
    ) AS branding
  FROM partner_accounts
  WHERE domain IS NOT NULL
    AND LOWER(domain) = LOWER(TRIM(p_domain))
    AND status = 'approved'
  LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION get_partner_by_domain(TEXT) TO anon, authenticated;

DROP FUNCTION IF EXISTS get_partner_by_code(TEXT);
CREATE FUNCTION get_partner_by_code(p_code TEXT)
RETURNS TABLE (
  id UUID,
  company_name TEXT,
  tracking_prefix TEXT,
  domain TEXT,
  status TEXT,
  branding JSONB
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT id, company_name, tracking_prefix, domain, status,
    jsonb_build_object(
      'color', settings->'branding_color',
      'portalTitle', settings->>'branding_portal_title',
      'subtitle', settings->>'branding_subtitle',
      'features', COALESCE(settings->'branding_features', '[]'::jsonb),
      'logoUrl', settings->>'branding_logo_url',
      'heroImageUrl', settings->>'branding_hero_image_url'
    ) AS branding
  FROM partner_accounts
  WHERE status = 'approved'
    AND p_code IS NOT NULL
    AND TRIM(p_code) <> ''
    AND UPPER(REPLACE(tracking_prefix, '-', '')) = UPPER(REPLACE(TRIM(p_code), '-', ''))
  LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION get_partner_by_code(TEXT) TO anon, authenticated;
