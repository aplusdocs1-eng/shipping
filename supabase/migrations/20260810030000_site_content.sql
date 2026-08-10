-- Lets an admin fully customize the copy, images, and numbers on the
-- public landing page from a new in-app editor, without touching code.
--
-- Single-row "singleton" table keyed by page id (only 'landing' exists for
-- now, but the shape allows future pages e.g. a per-partner page later).
-- The stored content is a partial overlay: the Flutter app always merges
-- it over a canonical set of defaults (lib/models/landing_content.dart),
-- so an admin who has only edited a few fields still gets a complete,
-- correctly laid out page for everything they haven't touched, and a
-- brand-new/empty row renders identically to the page as it looks today.
CREATE TABLE IF NOT EXISTS site_content (
  id TEXT PRIMARY KEY,
  content JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by UUID REFERENCES auth.users(id)
);

INSERT INTO site_content (id, content)
VALUES ('landing', '{}'::jsonb)
ON CONFLICT (id) DO NOTHING;

ALTER TABLE site_content ENABLE ROW LEVEL SECURITY;

-- Unlike every other table in this app, public/anon SELECT here is
-- correct and intentional, not a gap: this table only ever holds the
-- public marketing page's own content, which unauthenticated visitors
-- must be able to read to see the landing page at all. It holds no
-- tenant, customer, or account data.
DROP POLICY IF EXISTS "Public can read site content" ON site_content;
CREATE POLICY "Public can read site content" ON site_content FOR SELECT
USING (true);

DROP POLICY IF EXISTS "Admins manage site content" ON site_content;
CREATE POLICY "Admins manage site content" ON site_content FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM admin_users
    WHERE admin_users.auth_user_id = auth.uid() AND admin_users.is_active
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM admin_users
    WHERE admin_users.auth_user_id = auth.uid() AND admin_users.is_active
  )
);
