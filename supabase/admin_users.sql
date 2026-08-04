-- ═══════════════════════════════════════════════════════════════
-- Warehouse / platform admin accounts
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS admin_users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  auth_user_id UUID UNIQUE NOT NULL,
  email TEXT UNIQUE NOT NULL,
  full_name TEXT NOT NULL DEFAULT '',
  role TEXT NOT NULL DEFAULT 'warehouse', -- warehouse | superadmin | viewer
  is_active BOOLEAN NOT NULL DEFAULT true,
  last_login_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE admin_users ENABLE ROW LEVEL SECURITY;

-- A signed-in admin can read their own row (used by the app after login).
CREATE POLICY "Admin reads own" ON admin_users
  FOR SELECT TO authenticated
  USING (auth_user_id = auth.uid());

-- Only service_role can insert/update/delete admin rows (bootstrap via SQL).
CREATE POLICY "Service role all" ON admin_users
  FOR ALL TO service_role
  USING (true) WITH CHECK (true);

CREATE TRIGGER set_updated_at BEFORE UPDATE ON admin_users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ── Seed the default warehouse admin ─────────────────────────────
-- Steps to bootstrap:
-- 1. In Supabase Dashboard → Authentication → Users → "Add user"
--    Email:    warehouse@applizonecentralja.com
--    Password: (choose a strong one)
--    Auto-confirm: yes
--    Copy the new user's UUID.
--
-- 2. Run the INSERT below, replacing <AUTH_UUID> with that UUID:
--
-- INSERT INTO admin_users (auth_user_id, email, full_name, role)
-- VALUES (
--   '<AUTH_UUID>',
--   'warehouse@applizonecentralja.com',
--   'Warehouse Admin',
--   'warehouse'
-- );
