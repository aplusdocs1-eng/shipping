-- Every section of the partner dashboard's Settings screen rendered a
-- hardcoded demo list or static field values with dead Add/Edit buttons
-- and a Save bar that showed a fake "Settings saved" toast without writing
-- anything. This gives each section real, partner-scoped storage.

-- Simple scalar preferences (Storage Fee, Terms, Currency, Rate Calculator,
-- Branding, Api/Webhooks) share one JSONB bag rather than ~25 one-off
-- columns — each section reads/writes its own small set of named keys.
ALTER TABLE partner_accounts
  ADD COLUMN IF NOT EXISTS settings JSONB NOT NULL DEFAULT '{}'::jsonb;

-- List-shaped sections get real, normalized, partner-scoped tables.

CREATE TABLE IF NOT EXISTS partner_locations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id UUID NOT NULL REFERENCES partner_accounts(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  address TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'Store',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS partner_charges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id UUID NOT NULL REFERENCES partner_accounts(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  amount NUMERIC NOT NULL DEFAULT 0,
  amount_type TEXT NOT NULL DEFAULT 'fixed', -- 'fixed' | 'percent'
  unit TEXT NOT NULL DEFAULT 'Per package',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS partner_discounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id UUID NOT NULL REFERENCES partner_accounts(id) ON DELETE CASCADE,
  code TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'active', -- 'active' | 'paused'
  expires_at DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS partner_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id UUID NOT NULL REFERENCES partner_accounts(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  permissions TEXT[] NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS partner_staff (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id UUID NOT NULL REFERENCES partner_accounts(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'Cashier',
  status TEXT NOT NULL DEFAULT 'invited', -- 'invited' | 'active'
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS partner_shipping_addresses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id UUID NOT NULL REFERENCES partner_accounts(id) ON DELETE CASCADE,
  label TEXT NOT NULL,
  address TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- RLS: admin full access + the owning partner manages their own rows only,
-- matching the tiered admin_users / partner_accounts.auth_user_id pattern
-- already enforced on customers/packages/etc.
DO $$
DECLARE
  t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'partner_locations', 'partner_charges', 'partner_discounts',
    'partner_roles', 'partner_staff', 'partner_shipping_addresses'
  ] LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format(
      'CREATE POLICY "Admin full access" ON %I FOR ALL USING (EXISTS (SELECT 1 FROM admin_users WHERE auth_user_id = auth.uid() AND is_active)) WITH CHECK (EXISTS (SELECT 1 FROM admin_users WHERE auth_user_id = auth.uid() AND is_active))',
      t
    );
    EXECUTE format(
      'CREATE POLICY "Partner manages own rows" ON %I FOR ALL USING (partner_id IN (SELECT id FROM partner_accounts WHERE auth_user_id = auth.uid())) WITH CHECK (partner_id IN (SELECT id FROM partner_accounts WHERE auth_user_id = auth.uid()))',
      t
    );
  END LOOP;
END $$;
