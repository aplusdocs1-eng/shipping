-- ═══════════════════════════════════════════════════════════════
-- Applizone Central Jamaica — Courier Warehousing Schema
-- ═══════════════════════════════════════════════════════════════

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ── Shipping Partners ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS shipping_partners (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  region TEXT NOT NULL DEFAULT '',
  tracking_prefix TEXT NOT NULL DEFAULT '',
  contact_email TEXT NOT NULL DEFAULT '',
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── Customers ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS customers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  address TEXT,
  mailbox_number TEXT,
  status TEXT NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── Packages ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS packages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tracking_number TEXT UNIQUE NOT NULL,
  customer_id UUID REFERENCES customers(id),
  customer_name TEXT NOT NULL DEFAULT '',
  description TEXT NOT NULL DEFAULT '',
  weight NUMERIC(10,2) NOT NULL DEFAULT 0,
  declared_value NUMERIC(10,2) DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending',
  service_type TEXT NOT NULL DEFAULT 'standard',
  origin TEXT,
  destination TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── Warehouse Entries ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS warehouse_entries (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  package_id TEXT,
  tracking_number TEXT NOT NULL,
  customer_name TEXT NOT NULL DEFAULT '',
  description TEXT NOT NULL DEFAULT '',
  weight NUMERIC(10,2) NOT NULL DEFAULT 0,
  storage_zone TEXT,
  storage_location TEXT,
  status TEXT NOT NULL DEFAULT 'scanned_in',
  scanned_in_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  scanned_in_by TEXT NOT NULL DEFAULT '',
  picked_up_at TIMESTAMPTZ,
  picked_up_by TEXT,
  shipping_partner_code TEXT,
  synced_to_partner BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── Invoices ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS invoices (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  invoice_number TEXT UNIQUE NOT NULL,
  customer_id UUID REFERENCES customers(id),
  customer_name TEXT NOT NULL DEFAULT '',
  amount NUMERIC(10,2) NOT NULL DEFAULT 0,
  tax NUMERIC(10,2) NOT NULL DEFAULT 0,
  total NUMERIC(10,2) NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending',
  due_date DATE,
  paid_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── Pre-Alerts ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS pre_alerts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tracking_number TEXT NOT NULL,
  customer_id UUID REFERENCES customers(id),
  customer_name TEXT NOT NULL DEFAULT '',
  carrier TEXT NOT NULL DEFAULT '',
  description TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── Shipments ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS shipments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  shipment_number TEXT UNIQUE NOT NULL,
  origin TEXT NOT NULL DEFAULT '',
  destination TEXT NOT NULL DEFAULT '',
  carrier TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'pending',
  total_packages INTEGER NOT NULL DEFAULT 0,
  total_weight NUMERIC(10,2) NOT NULL DEFAULT 0,
  estimated_arrival TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── Branches ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS branches (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  address TEXT NOT NULL DEFAULT '',
  phone TEXT,
  email TEXT,
  manager TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── Staff ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS staff (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  phone TEXT,
  role TEXT NOT NULL DEFAULT 'agent',
  branch_id UUID REFERENCES branches(id),
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── Storage Zones & Locations ──────────────────────────────────
CREATE TABLE IF NOT EXISTS storage_zones (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  capacity INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS storage_locations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  zone_id UUID REFERENCES storage_zones(id),
  label TEXT NOT NULL,
  shelf TEXT NOT NULL DEFAULT '',
  bin TEXT NOT NULL DEFAULT '',
  is_occupied BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── Enable Row Level Security ──────────────────────────────────
ALTER TABLE shipping_partners ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE packages ENABLE ROW LEVEL SECURITY;
ALTER TABLE warehouse_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE pre_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE shipments ENABLE ROW LEVEL SECURITY;
ALTER TABLE branches ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff ENABLE ROW LEVEL SECURITY;
ALTER TABLE storage_zones ENABLE ROW LEVEL SECURITY;
ALTER TABLE storage_locations ENABLE ROW LEVEL SECURITY;

-- ── RLS Policies ───────────────────────────────────────────────
CREATE POLICY "Allow all for authenticated" ON shipping_partners FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow anon read" ON shipping_partners FOR SELECT TO anon USING (true);
CREATE POLICY "Allow all for authenticated" ON customers FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow anon read" ON customers FOR SELECT TO anon USING (true);
CREATE POLICY "Allow all for authenticated" ON packages FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow anon read" ON packages FOR SELECT TO anon USING (true);
CREATE POLICY "Allow all for authenticated" ON warehouse_entries FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow anon read" ON warehouse_entries FOR SELECT TO anon USING (true);
CREATE POLICY "Allow all for authenticated" ON invoices FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow anon read" ON invoices FOR SELECT TO anon USING (true);
CREATE POLICY "Allow all for authenticated" ON pre_alerts FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow anon read" ON pre_alerts FOR SELECT TO anon USING (true);
CREATE POLICY "Allow all for authenticated" ON shipments FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow anon read" ON shipments FOR SELECT TO anon USING (true);
CREATE POLICY "Allow all for authenticated" ON branches FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow anon read" ON branches FOR SELECT TO anon USING (true);
CREATE POLICY "Allow all for authenticated" ON staff FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow anon read" ON staff FOR SELECT TO anon USING (true);
CREATE POLICY "Allow all for authenticated" ON storage_zones FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow anon read" ON storage_zones FOR SELECT TO anon USING (true);
CREATE POLICY "Allow all for authenticated" ON storage_locations FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow anon read" ON storage_locations FOR SELECT TO anon USING (true);

-- ── Updated-at trigger ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$ 
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_updated_at BEFORE UPDATE ON shipping_partners FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON customers FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON packages FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON warehouse_entries FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON invoices FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON pre_alerts FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON shipments FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON branches FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON staff FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ── Seed shipping partners ─────────────────────────────────────
INSERT INTO shipping_partners (code, name, region, tracking_prefix, contact_email, is_active)
VALUES
  ('APS', 'Applizone Shipping', 'Caribbean', 'APS-', 'support@applizonecentralja.com', true),
  ('CWL', 'Caribbean Wave Logistics', 'Jamaica / Trinidad', 'CWL-', 'ops@caribwavelogistics.com', true),
  ('ISX', 'Island Express Freight', 'Jamaica / Bahamas', 'ISX-', 'dispatch@islandexpressfreight.com', true),
  ('GSC', 'Global Ship Connect', 'USA / Caribbean', 'GSC-', 'hello@globalshipconnect.com', false)
ON CONFLICT (code) DO NOTHING;
