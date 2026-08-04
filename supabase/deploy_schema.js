const https = require('https');

const PROJECT_REF = 'biuydcyyqeutfddxtruu';
const ACCESS_TOKEN = process.env.SUPABASE_ACCESS_TOKEN || '';

const sql = `
-- ═══════════════════════════════════════════════════════════════
-- Applizone Central Jamaica — Courier Warehousing Schema
-- ═══════════════════════════════════════════════════════════════

-- Enable UUID extension
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

-- ── RLS Policies: Allow all for authenticated users ────────────
DO $$ 
DECLARE
  t TEXT;
BEGIN
  FOR t IN SELECT unnest(ARRAY[
    'shipping_partners','customers','packages','warehouse_entries',
    'invoices','pre_alerts','shipments','branches','staff',
    'storage_zones','storage_locations'
  ]) LOOP
    EXECUTE format('CREATE POLICY IF NOT EXISTS "Allow all for authenticated" ON %I FOR ALL TO authenticated USING (true) WITH CHECK (true)', t);
    EXECUTE format('CREATE POLICY IF NOT EXISTS "Allow anon read" ON %I FOR SELECT TO anon USING (true)', t);
  END LOOP;
END $$;

-- ── Updated-at trigger ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$ 
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
DECLARE
  t TEXT;
BEGIN
  FOR t IN SELECT unnest(ARRAY[
    'shipping_partners','customers','packages','warehouse_entries',
    'invoices','pre_alerts','shipments','branches','staff'
  ]) LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS set_updated_at ON %I', t);
    EXECUTE format('CREATE TRIGGER set_updated_at BEFORE UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION update_updated_at()', t);
  END LOOP;
END $$;

-- ── Seed shipping partners ─────────────────────────────────────
INSERT INTO shipping_partners (code, name, region, tracking_prefix, contact_email, is_active)
VALUES
  ('APS', 'Applizone Shipping', 'Caribbean', 'APS-', 'support@applizonecentralja.com', true),
  ('CWL', 'Caribbean Wave Logistics', 'Jamaica / Trinidad', 'CWL-', 'ops@caribwavelogistics.com', true),
  ('ISX', 'Island Express Freight', 'Jamaica / Bahamas', 'ISX-', 'dispatch@islandexpressfreight.com', true),
  ('GSC', 'Global Ship Connect', 'USA / Caribbean', 'GSC-', 'hello@globalshipconnect.com', false)
ON CONFLICT (code) DO NOTHING;
`;

// Split into individual statements and execute each via PostgREST rpc
// First, try the direct pg-meta SQL endpoint
const body = JSON.stringify({ query: sql });

// Try multiple endpoints
async function deploy() {
  const fetch = globalThis.fetch || (await import('node-fetch')).default;
  const BASE = 'https://biuydcyyqeutfddxtruu.supabase.co';
  const KEY = ACCESS_TOKEN;

  // Approach: use pg-meta SQL execution endpoint
  const endpoints = [
    { url: BASE + '/pg/query', method: 'POST', body: JSON.stringify({ query: sql }) },
    { url: BASE + '/rest/v1/rpc/exec_sql', method: 'POST', body: JSON.stringify({ sql_string: sql }) },
  ];

  // Try direct pg endpoint first
  for (const ep of endpoints) {
    console.log('Trying:', ep.url);
    try {
      const res = await fetch(ep.url, {
        method: ep.method,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + KEY,
          'apikey': KEY,
        },
        body: ep.body,
      });
      const text = await res.text();
      console.log('Status:', res.status);
      if (res.status >= 200 && res.status < 300) {
        console.log('SUCCESS — Tables deployed!');
        return;
      }
      console.log('Response:', text.substring(0, 500));
    } catch (e) {
      console.log('Error:', e.message);
    }
    console.log('---');
  }

  // Fallback: execute statements one at a time via individual table creation
  console.log('\nDirect SQL endpoints unavailable. Trying individual table creation via REST...');
  
  // Test connection by querying an empty table
  try {
    const testRes = await fetch(BASE + '/rest/v1/shipping_partners?select=count', {
      headers: { 'Authorization': 'Bearer ' + KEY, 'apikey': KEY },
    });
    console.log('REST API test status:', testRes.status);
    const testText = await testRes.text();
    console.log('REST API test:', testText.substring(0, 200));
    
    if (testRes.status === 404 || testRes.status === 400) {
      console.log('\nTables do not exist yet. SQL must be run in the Supabase SQL editor.');
      console.log('SQL saved to: supabase/schema.sql');
      console.log('Go to: https://supabase.com/dashboard/project/biuydcyyqeutfddxtruu/sql/new');
      console.log('Paste the contents of supabase/schema.sql and click Run.');
    }
  } catch (e) {
    console.log('Connection test error:', e.message);
  }
}

deploy().catch(console.error);
