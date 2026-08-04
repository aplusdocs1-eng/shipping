-- Allow warehouse admins to read + update all partner_accounts.
-- Partners still only see their own row; admins see everything.

DROP POLICY IF EXISTS "Admins read all partner_accounts" ON partner_accounts;
CREATE POLICY "Admins read all partner_accounts" ON partner_accounts
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM admin_users
      WHERE admin_users.auth_user_id = auth.uid()
        AND admin_users.is_active = true
    )
  );

DROP POLICY IF EXISTS "Admins update all partner_accounts" ON partner_accounts;
CREATE POLICY "Admins update all partner_accounts" ON partner_accounts
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM admin_users
      WHERE admin_users.auth_user_id = auth.uid()
        AND admin_users.is_active = true
    )
  );

-- Demo pending partner
INSERT INTO partner_accounts (auth_user_id, company_name, contact_name, email, phone, tracking_prefix, status)
VALUES (gen_random_uuid(), 'Demo Courier Co', 'Jane Test', 'demo-pending@example.com', '+1 876 555 0100', 'DEMO', 'pending')
ON CONFLICT (email) DO NOTHING;
