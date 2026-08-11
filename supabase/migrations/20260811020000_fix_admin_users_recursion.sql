-- Fixes a self-inflicted bug in the previous migration: "Admins read all
-- admin_users" queried admin_users from its own USING clause. Confirmed
-- live (via a direct authenticated query) that this throws Postgres
-- error 42P17 "infinite recursion detected in policy for relation
-- admin_users" — not a permissions denial, a hard query failure. Because
-- nearly every admin-gated table in this app checks admin status via
-- `EXISTS (SELECT 1 FROM admin_users WHERE auth_user_id = auth.uid() AND
-- is_active)`, and evaluating that subquery itself requires resolving
-- admin_users' own row-security, this broke admin access far beyond the
-- one new policy — anything that touched admin_users at all, including
-- pre-existing features from earlier this session, started 500ing.
--
-- Fix: move the admin check into a SECURITY DEFINER function. Functions
-- like this run as their owner (the migration role, which owns
-- admin_users and is exempt from its own table's RLS, since FORCE ROW
-- LEVEL SECURITY was never set) — so the query inside it does not
-- re-trigger row security on admin_users, and there is nothing left to
-- recurse into. This is the standard, documented pattern for exactly
-- this situation (a role/permission check against the same table the
-- policy protects), not a workaround specific to this bug.
CREATE OR REPLACE FUNCTION is_active_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM admin_users
    WHERE auth_user_id = auth.uid() AND is_active
  );
$$;

GRANT EXECUTE ON FUNCTION is_active_admin() TO authenticated;

DROP POLICY IF EXISTS "Admins read all admin_users" ON admin_users;
CREATE POLICY "Admins read all admin_users" ON admin_users FOR SELECT
USING (is_active_admin());
