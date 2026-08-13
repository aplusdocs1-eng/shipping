-- RLS for the package-labels Storage bucket (created out-of-band via the
-- Storage Management API, since bucket creation isn't a SQL statement).
-- Admin-only, same is_active_admin() pattern as every table policy in this
-- project — label images are never public and are always served via
-- short-lived signed URLs, never a public bucket URL.

DROP POLICY IF EXISTS "Admins manage package labels" ON storage.objects;
CREATE POLICY "Admins manage package labels" ON storage.objects FOR ALL TO authenticated
  USING (bucket_id = 'package-labels' AND is_active_admin())
  WITH CHECK (bucket_id = 'package-labels' AND is_active_admin());
