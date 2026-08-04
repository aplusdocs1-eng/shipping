CREATE TABLE IF NOT EXISTS partner_accounts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  auth_user_id UUID UNIQUE NOT NULL,
  partner_id UUID REFERENCES shipping_partners(id),
  company_name TEXT NOT NULL,
  contact_name TEXT NOT NULL DEFAULT '',
  email TEXT UNIQUE NOT NULL,
  phone TEXT,
  tracking_prefix TEXT NOT NULL DEFAULT '',
  api_key TEXT UNIQUE,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Migration for existing installs:
ALTER TABLE partner_accounts ADD COLUMN IF NOT EXISTS api_key TEXT UNIQUE;

ALTER TABLE partner_accounts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Partners read own" ON partner_accounts FOR SELECT TO authenticated USING (auth_user_id = auth.uid());
CREATE POLICY "Partners update own" ON partner_accounts FOR UPDATE TO authenticated USING (auth_user_id = auth.uid());
CREATE POLICY "Allow anon insert" ON partner_accounts FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Allow authenticated insert" ON partner_accounts FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Service role all" ON partner_accounts FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE TRIGGER set_updated_at BEFORE UPDATE ON partner_accounts FOR EACH ROW EXECUTE FUNCTION update_updated_at();
