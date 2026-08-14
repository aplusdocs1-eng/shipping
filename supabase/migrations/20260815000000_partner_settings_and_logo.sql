-- Two things, found in the same pass while wiring up partner logo
-- upload (which needed to save into the same settings JSONB):
--
-- 1. Real regression from the auth audit (20260813050000): dropping
--    "Partners update own" (too broad — unrestricted column access) left
--    updatePartnerSettings with nothing to run on. It does a raw
--    .update() trusting a client-supplied account id for 6 partner
--    Settings tabs (Storage Fee, Currency, Terms, Rate Calculator,
--    Branding, Api/Webhooks) — confirmed live, this was returning 0
--    rows (silently at the REST layer; .single() throws in the actual
--    app) for every partner trying to save any of them. Same fix shape
--    as the other narrow RPCs from that audit: resolve the row via
--    auth.uid() server-side instead of trusting a client-supplied id.
--
-- 2. New: partner-logos storage bucket + policies, for the logo upload
--    feature itself. Public bucket — a courier's logo needs to be
--    visible to their customers viewing the branded portal, most of
--    whom aren't authenticated as that partner (or authenticated at
--    all). Upload/replace/delete stay restricted to the owning partner.

CREATE OR REPLACE FUNCTION update_own_partner_settings(p_patch JSONB)
RETURNS SETOF partner_accounts
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  UPDATE partner_accounts
     SET settings = COALESCE(settings, '{}'::jsonb) || p_patch,
         updated_at = now()
   WHERE auth_user_id = auth.uid()
  RETURNING *;
END;
$$;
GRANT EXECUTE ON FUNCTION update_own_partner_settings(JSONB) TO authenticated;

INSERT INTO storage.buckets (id, name, public)
VALUES ('partner-logos', 'partner-logos', true)
ON CONFLICT (id) DO NOTHING;

-- Path convention: {partner_accounts.id}/logo.<ext> — ownership check
-- is "does a partner_accounts row with this id belong to me", not a
-- literal auth.uid() path match, since the id in the path is the
-- account id, not the auth user id.
CREATE POLICY "Partners manage own logo"
ON storage.objects FOR ALL TO authenticated
USING (
  bucket_id = 'partner-logos'
  AND EXISTS (
    SELECT 1 FROM partner_accounts
    WHERE id::text = (storage.foldername(name))[1]
      AND auth_user_id = auth.uid()
  )
)
WITH CHECK (
  bucket_id = 'partner-logos'
  AND EXISTS (
    SELECT 1 FROM partner_accounts
    WHERE id::text = (storage.foldername(name))[1]
      AND auth_user_id = auth.uid()
  )
);

CREATE POLICY "Public read partner logos"
ON storage.objects FOR SELECT TO anon, authenticated
USING (bucket_id = 'partner-logos');
