-- ═══════════════════════════════════════════════════════════════
-- Harden RLS: replace blanket "any authenticated user / anon" access
-- with tiered admin / partner / customer scoping.
--
-- Prerequisite for public customer self-signup: without this, any
-- signed-up user (or even an anonymous visitor, via the public anon
-- key) can read or write every partner's customers/packages/invoices.
-- Idempotent (drops policies by name before recreating).
-- ═══════════════════════════════════════════════════════════════

-- Helper predicates are inlined per-policy (Postgres RLS can't share
-- expressions across policies cleanly without a function; keeping the
-- admin_users / partner_accounts subqueries identical everywhere they
-- appear, mirroring the pattern already used for admin_users itself).

-- ── customers ──────────────────────────────────────────────────
DROP POLICY IF EXISTS "Allow all for authenticated" ON customers;
DROP POLICY IF EXISTS "Allow anon read" ON customers;

CREATE POLICY "Admins full access" ON customers FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM admin_users WHERE auth_user_id = auth.uid() AND is_active))
  WITH CHECK (EXISTS (SELECT 1 FROM admin_users WHERE auth_user_id = auth.uid() AND is_active));

CREATE POLICY "Partners manage own customers" ON customers FOR ALL TO authenticated
  USING (partner_id IN (SELECT id FROM partner_accounts WHERE auth_user_id = auth.uid() AND status = 'approved'))
  WITH CHECK (partner_id IN (SELECT id FROM partner_accounts WHERE auth_user_id = auth.uid() AND status = 'approved'));

CREATE POLICY "Customers read own row" ON customers FOR SELECT TO authenticated
  USING (auth_user_id = auth.uid());

CREATE POLICY "Customers update own row" ON customers FOR UPDATE TO authenticated
  USING (auth_user_id = auth.uid())
  WITH CHECK (auth_user_id = auth.uid());

-- ── packages ───────────────────────────────────────────────────
DROP POLICY IF EXISTS "Allow all for authenticated" ON packages;
DROP POLICY IF EXISTS "Allow anon read" ON packages;

CREATE POLICY "Admins full access" ON packages FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM admin_users WHERE auth_user_id = auth.uid() AND is_active))
  WITH CHECK (EXISTS (SELECT 1 FROM admin_users WHERE auth_user_id = auth.uid() AND is_active));

CREATE POLICY "Partners manage own packages" ON packages FOR ALL TO authenticated
  USING (partner_id IN (SELECT id FROM partner_accounts WHERE auth_user_id = auth.uid() AND status = 'approved'))
  WITH CHECK (partner_id IN (SELECT id FROM partner_accounts WHERE auth_user_id = auth.uid() AND status = 'approved'));

CREATE POLICY "Customers read own packages" ON packages FOR SELECT TO authenticated
  USING (customer_id IN (SELECT id FROM customers WHERE auth_user_id = auth.uid()));

-- ── invoices ───────────────────────────────────────────────────
DROP POLICY IF EXISTS "Allow all for authenticated" ON invoices;
DROP POLICY IF EXISTS "Allow anon read" ON invoices;

CREATE POLICY "Admins full access" ON invoices FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM admin_users WHERE auth_user_id = auth.uid() AND is_active))
  WITH CHECK (EXISTS (SELECT 1 FROM admin_users WHERE auth_user_id = auth.uid() AND is_active));

CREATE POLICY "Partners manage own invoices" ON invoices FOR ALL TO authenticated
  USING (partner_id IN (SELECT id FROM partner_accounts WHERE auth_user_id = auth.uid() AND status = 'approved'))
  WITH CHECK (partner_id IN (SELECT id FROM partner_accounts WHERE auth_user_id = auth.uid() AND status = 'approved'));

CREATE POLICY "Customers read own invoices" ON invoices FOR SELECT TO authenticated
  USING (customer_id IN (SELECT id FROM customers WHERE auth_user_id = auth.uid()));

-- ── pre_alerts ─────────────────────────────────────────────────
DROP POLICY IF EXISTS "Allow all for authenticated" ON pre_alerts;
DROP POLICY IF EXISTS "Allow anon read" ON pre_alerts;

CREATE POLICY "Admins full access" ON pre_alerts FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM admin_users WHERE auth_user_id = auth.uid() AND is_active))
  WITH CHECK (EXISTS (SELECT 1 FROM admin_users WHERE auth_user_id = auth.uid() AND is_active));

CREATE POLICY "Partners manage own pre_alerts" ON pre_alerts FOR ALL TO authenticated
  USING (partner_id IN (SELECT id FROM partner_accounts WHERE auth_user_id = auth.uid() AND status = 'approved'))
  WITH CHECK (partner_id IN (SELECT id FROM partner_accounts WHERE auth_user_id = auth.uid() AND status = 'approved'));

CREATE POLICY "Customers read own pre_alerts" ON pre_alerts FOR SELECT TO authenticated
  USING (customer_id IN (SELECT id FROM customers WHERE auth_user_id = auth.uid()));

CREATE POLICY "Customers create own pre_alerts" ON pre_alerts FOR INSERT TO authenticated
  WITH CHECK (customer_id IN (SELECT id FROM customers WHERE auth_user_id = auth.uid()));

-- ── shipments (no customer_id column — admin/partner only) ───────
DROP POLICY IF EXISTS "Allow all for authenticated" ON shipments;
DROP POLICY IF EXISTS "Allow anon read" ON shipments;

CREATE POLICY "Admins full access" ON shipments FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM admin_users WHERE auth_user_id = auth.uid() AND is_active))
  WITH CHECK (EXISTS (SELECT 1 FROM admin_users WHERE auth_user_id = auth.uid() AND is_active));

CREATE POLICY "Partners manage own shipments" ON shipments FOR ALL TO authenticated
  USING (partner_id IN (SELECT id FROM partner_accounts WHERE auth_user_id = auth.uid() AND status = 'approved'))
  WITH CHECK (partner_id IN (SELECT id FROM partner_accounts WHERE auth_user_id = auth.uid() AND status = 'approved'));

-- ── internal-only tables: admin-only ──────────────────────────
DROP POLICY IF EXISTS "Allow all for authenticated" ON staff;
DROP POLICY IF EXISTS "Allow anon read" ON staff;
CREATE POLICY "Admins full access" ON staff FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM admin_users WHERE auth_user_id = auth.uid() AND is_active))
  WITH CHECK (EXISTS (SELECT 1 FROM admin_users WHERE auth_user_id = auth.uid() AND is_active));

DROP POLICY IF EXISTS "Allow all for authenticated" ON branches;
DROP POLICY IF EXISTS "Allow anon read" ON branches;
CREATE POLICY "Admins full access" ON branches FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM admin_users WHERE auth_user_id = auth.uid() AND is_active))
  WITH CHECK (EXISTS (SELECT 1 FROM admin_users WHERE auth_user_id = auth.uid() AND is_active));

DROP POLICY IF EXISTS "Allow all for authenticated" ON storage_zones;
DROP POLICY IF EXISTS "Allow anon read" ON storage_zones;
CREATE POLICY "Admins full access" ON storage_zones FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM admin_users WHERE auth_user_id = auth.uid() AND is_active))
  WITH CHECK (EXISTS (SELECT 1 FROM admin_users WHERE auth_user_id = auth.uid() AND is_active));

DROP POLICY IF EXISTS "Allow all for authenticated" ON storage_locations;
DROP POLICY IF EXISTS "Allow anon read" ON storage_locations;
CREATE POLICY "Admins full access" ON storage_locations FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM admin_users WHERE auth_user_id = auth.uid() AND is_active))
  WITH CHECK (EXISTS (SELECT 1 FROM admin_users WHERE auth_user_id = auth.uid() AND is_active));

DROP POLICY IF EXISTS "Allow all for authenticated" ON warehouse_entries;
DROP POLICY IF EXISTS "Allow anon read" ON warehouse_entries;
CREATE POLICY "Admins full access" ON warehouse_entries FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM admin_users WHERE auth_user_id = auth.uid() AND is_active))
  WITH CHECK (EXISTS (SELECT 1 FROM admin_users WHERE auth_user_id = auth.uid() AND is_active));

-- shipping_partners: admin-managed; writes from the signup flow now go
-- through the SECURITY DEFINER create_partner_account RPC instead of a
-- direct client insert, so no public insert policy is needed here.
DROP POLICY IF EXISTS "Allow all for authenticated" ON shipping_partners;
DROP POLICY IF EXISTS "Allow anon read" ON shipping_partners;
CREATE POLICY "Admins full access" ON shipping_partners FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM admin_users WHERE auth_user_id = auth.uid() AND is_active))
  WITH CHECK (EXISTS (SELECT 1 FROM admin_users WHERE auth_user_id = auth.uid() AND is_active));
