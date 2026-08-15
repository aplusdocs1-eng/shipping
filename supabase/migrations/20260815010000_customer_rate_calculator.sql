-- Customer portal's Rate Calculator used hardcoded demo numbers
-- ($4.50/lb air, $2.25/lb sea, 20% duty) instead of whatever a courier
-- actually configured in their own dashboard's Rate Calculator/Api
-- Sync settings tabs (rate_air_per_lb / rate_sea_per_lb /
-- rate_duty_percent / gct_rate in partner_accounts.settings) — every
-- customer got the same generic estimate regardless of which courier's
-- portal they were on, or what that courier really charges.
--
-- get_partner_by_domain/get_partner_by_code are already the correct,
-- narrow way for a logged-out customer-facing page to read curated
-- public fields off a partner's row without exposing the full account
-- (see their own "branding" column for the existing pattern) — adding
-- a same-shaped "rates" column here follows that, rather than opening
-- broader read access to partner_accounts.settings itself.
--
-- CREATE OR REPLACE can't add a column to an existing RETURNS TABLE
-- signature — Postgres treats that as a return-type change, same
-- class of thing this session already hit once with create_partner_account's
-- overloads. Drop and recreate rather than fight it.

DROP FUNCTION IF EXISTS get_partner_by_domain(text);
DROP FUNCTION IF EXISTS get_partner_by_code(text);

CREATE FUNCTION get_partner_by_domain(p_domain text)
RETURNS TABLE(id uuid, company_name text, tracking_prefix text, domain text, status text, branding jsonb, rates jsonb)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT id, company_name, tracking_prefix, domain, status,
    jsonb_build_object(
      'color', settings->'branding_color',
      'portalTitle', settings->>'branding_portal_title',
      'subtitle', settings->>'branding_subtitle',
      'features', COALESCE(settings->'branding_features', '[]'::jsonb),
      'logoUrl', settings->>'branding_logo_url',
      'heroImageUrl', settings->>'branding_hero_image_url'
    ) AS branding,
    jsonb_build_object(
      'airPerLb', settings->'rate_air_per_lb',
      'seaPerLb', settings->'rate_sea_per_lb',
      'dutyPercent', settings->'rate_duty_percent',
      'gctPercent', settings->'gct_rate'
    ) AS rates
  FROM partner_accounts
  WHERE domain IS NOT NULL
    AND LOWER(domain) = LOWER(TRIM(p_domain))
    AND status = 'approved'
  LIMIT 1;
$function$;

CREATE FUNCTION get_partner_by_code(p_code text)
RETURNS TABLE(id uuid, company_name text, tracking_prefix text, domain text, status text, branding jsonb, rates jsonb)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT id, company_name, tracking_prefix, domain, status,
    jsonb_build_object(
      'color', settings->'branding_color',
      'portalTitle', settings->>'branding_portal_title',
      'subtitle', settings->>'branding_subtitle',
      'features', COALESCE(settings->'branding_features', '[]'::jsonb),
      'logoUrl', settings->>'branding_logo_url',
      'heroImageUrl', settings->>'branding_hero_image_url'
    ) AS branding,
    jsonb_build_object(
      'airPerLb', settings->'rate_air_per_lb',
      'seaPerLb', settings->'rate_sea_per_lb',
      'dutyPercent', settings->'rate_duty_percent',
      'gctPercent', settings->'gct_rate'
    ) AS rates
  FROM partner_accounts
  WHERE status = 'approved'
    AND p_code IS NOT NULL
    AND TRIM(p_code) <> ''
    AND UPPER(REPLACE(tracking_prefix, '-', '')) = UPPER(REPLACE(TRIM(p_code), '-', ''))
  LIMIT 1;
$function$;

GRANT EXECUTE ON FUNCTION get_partner_by_domain(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_partner_by_code(text) TO anon, authenticated;
