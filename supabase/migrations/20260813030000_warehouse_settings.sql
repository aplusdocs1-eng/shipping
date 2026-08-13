-- The warehouse address needs to be readable by every authenticated
-- customer and courier (it's what renders on the customer portal's
-- Shipping Addresses page and the courier dashboard), but it was first
-- added as a nested key inside company_settings.settings — which is
-- admin-only by design (that JSONB blob also holds integration API keys
-- for Stripe/SendGrid/Twilio/webhooks, so a blanket read grant on the
-- whole row would leak those to every customer and partner). A customer
-- or courier session silently failed to read it at all and fell back to
-- the compiled-in default address, never the admin's real one.
--
-- Splits it into its own singleton table instead — same shape and same
-- "admin write, authenticated read" RLS pattern as scanner_settings
-- (20260813000000_package_scanning_ocr.sql), which solved this exact
-- problem for a different admin-configurable value already.
CREATE TABLE IF NOT EXISTS warehouse_settings (
  id BOOLEAN PRIMARY KEY DEFAULT true CONSTRAINT warehouse_settings_singleton CHECK (id),
  line1 TEXT NOT NULL DEFAULT '559 NE 42ND ST',
  city TEXT NOT NULL DEFAULT 'OAKLAND PARK',
  state TEXT NOT NULL DEFAULT 'Florida',
  zip TEXT NOT NULL DEFAULT '33334',
  country TEXT NOT NULL DEFAULT 'United States',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by UUID REFERENCES admin_users(id)
);
INSERT INTO warehouse_settings (id) VALUES (true) ON CONFLICT (id) DO NOTHING;

ALTER TABLE warehouse_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins full access" ON warehouse_settings;
CREATE POLICY "Admins full access" ON warehouse_settings FOR ALL TO authenticated
  USING (is_active_admin())
  WITH CHECK (is_active_admin());
-- Every authenticated user (customers, couriers) needs to read this —
-- nothing in this row is sensitive, unlike company_settings.
DROP POLICY IF EXISTS "Authenticated read" ON warehouse_settings;
CREATE POLICY "Authenticated read" ON warehouse_settings FOR SELECT TO authenticated
  USING (true);

-- Best-effort migrate forward any address an admin already saved into
-- company_settings.settings.warehouseAddress during the brief window
-- before this table existed, so that save isn't silently lost.
UPDATE warehouse_settings ws
   SET line1 = COALESCE(NULLIF(cs.settings->'warehouseAddress'->>'line1', ''), ws.line1),
       city = COALESCE(NULLIF(cs.settings->'warehouseAddress'->>'city', ''), ws.city),
       state = COALESCE(NULLIF(cs.settings->'warehouseAddress'->>'state', ''), ws.state),
       zip = COALESCE(NULLIF(cs.settings->'warehouseAddress'->>'zip', ''), ws.zip),
       country = COALESCE(NULLIF(cs.settings->'warehouseAddress'->>'country', ''), ws.country)
  FROM company_settings cs
 WHERE cs.id = 'default' AND cs.settings ? 'warehouseAddress';
