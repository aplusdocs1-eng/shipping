-- The admin Settings screen (Company Profile, Regional Settings,
-- Notifications, Security, Integrations) was entirely decorative —
-- every field was a hardcoded literal or an in-memory State variable with
-- no read or write to the database at all, and its "Save Changes" button
-- showed a success message without saving anything. This gives it a real
-- place to persist to.
--
-- Single JSONB blob, singleton row, same shape as site_content — this is
-- org-wide config (One Village's own profile/preferences), not
-- per-partner or per-admin, so every admin reads/writes the same row.
CREATE TABLE IF NOT EXISTS company_settings (
  id TEXT PRIMARY KEY,
  settings JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by UUID REFERENCES auth.users(id)
);

INSERT INTO company_settings (id, settings)
VALUES ('default', '{}'::jsonb)
ON CONFLICT (id) DO NOTHING;

ALTER TABLE company_settings ENABLE ROW LEVEL SECURITY;

-- Unlike site_content, this is internal operational data (phone numbers,
-- integration credentials, security preferences) — admin-only, no public
-- read.
DROP POLICY IF EXISTS "Admins manage company settings" ON company_settings;
CREATE POLICY "Admins manage company settings" ON company_settings FOR ALL
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

-- admin_users previously only let an admin read their *own* row ("Admin
-- reads own"), which is what getAdminUser/the login check need — but it
-- meant a real "who's on the team" list was impossible, not just
-- unbuilt. Add real team visibility: any active admin can see the full
-- roster (name, email, role, last login — no secrets on this table).
-- Self-referencing admin_users from its own policy is the same bounded
-- EXISTS pattern already used to gate every other admin-only table in
-- this app; it does not recurse.
DROP POLICY IF EXISTS "Admins read all admin_users" ON admin_users;
CREATE POLICY "Admins read all admin_users" ON admin_users FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM admin_users au
    WHERE au.auth_user_id = auth.uid() AND au.is_active
  )
);
