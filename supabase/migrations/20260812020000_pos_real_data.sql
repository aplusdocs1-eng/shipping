-- Point of Sale has run entirely on bundled mock data since it was built —
-- pos_screen.dart read/wrote MockDataService().posItems/posTransactions,
-- so a "completed" sale never touched the database and vanished on
-- refresh, invisible to Accounting/Reports. This gives it real tables.
--
-- pos_transaction_items is normalized out (not embedded JSON on
-- pos_transactions) so a completed sale keeps an exact historical record
-- of what was actually sold at what price, even if the pos_items catalog
-- is edited or an item is deactivated later.

CREATE TABLE IF NOT EXISTS pos_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT '',
  price NUMERIC(10,2) NOT NULL DEFAULT 0,
  unit TEXT NOT NULL DEFAULT '',
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS pos_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  receipt_number TEXT UNIQUE NOT NULL,
  customer_id UUID REFERENCES customers(id),
  customer_name TEXT NOT NULL DEFAULT 'Walk-in customer',
  subtotal NUMERIC(10,2) NOT NULL DEFAULT 0,
  tax NUMERIC(10,2) NOT NULL DEFAULT 0,
  total NUMERIC(10,2) NOT NULL DEFAULT 0,
  payment_method TEXT NOT NULL DEFAULT 'Cash',
  created_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS pos_transaction_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id UUID NOT NULL REFERENCES pos_transactions(id) ON DELETE CASCADE,
  pos_item_id UUID REFERENCES pos_items(id) ON DELETE SET NULL,
  item_name TEXT NOT NULL,
  unit_price NUMERIC(10,2) NOT NULL DEFAULT 0,
  quantity INTEGER NOT NULL DEFAULT 1,
  line_total NUMERIC(10,2) NOT NULL DEFAULT 0
);

ALTER TABLE pos_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE pos_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE pos_transaction_items ENABLE ROW LEVEL SECURITY;

-- POS is an internal admin/warehouse tool (pos_screen.dart is only wired
-- into the admin app, never the partner or customer portals) — admin-only,
-- via the existing is_active_admin() helper (SECURITY DEFINER, so it
-- doesn't re-trigger these same tables' own row security).
CREATE POLICY "Admins full access" ON pos_items FOR ALL TO authenticated
  USING (is_active_admin()) WITH CHECK (is_active_admin());

CREATE POLICY "Admins full access" ON pos_transactions FOR ALL TO authenticated
  USING (is_active_admin()) WITH CHECK (is_active_admin());

CREATE POLICY "Admins full access" ON pos_transaction_items FOR ALL TO authenticated
  USING (is_active_admin()) WITH CHECK (is_active_admin());

-- Starting catalog — the same line items the mock data always showed, so
-- POS isn't an empty screen the moment it goes real. An admin can edit
-- prices/items from the new "Manage Items" action in POS itself.
-- name has no unique constraint to key an ON CONFLICT off, so the
-- idempotency guard is an explicit "only if the table is still empty"
-- instead — safe if this migration is ever accidentally re-run.
INSERT INTO pos_items (name, category, price, unit)
SELECT * FROM (VALUES
  ('Air Freight - Per Lb', 'Shipping', 6.50, 'per lb'),
  ('Sea Freight - Per Lb', 'Shipping', 2.75, 'per lb'),
  ('Door Delivery - Kingston', 'Delivery', 800.00, 'per delivery'),
  ('Door Delivery - MoBay', 'Delivery', 1200.00, 'per delivery'),
  ('Insurance', 'Add-on', 2.50, 'per $100 value'),
  ('Packaging Fee', 'Add-on', 350.00, 'per box'),
  ('Fuel Surcharge', 'Surcharge', 150.00, 'per package'),
  ('Custom Clearance', 'Customs', 1500.00, 'per shipment'),
  ('Label Reprint', 'Admin', 50.00, 'per label')
) AS seed(name, category, price, unit)
WHERE NOT EXISTS (SELECT 1 FROM pos_items);
