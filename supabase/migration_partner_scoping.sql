-- ═══════════════════════════════════════════════════════════════
-- Migration: Scope customers/packages/invoices/pre_alerts/shipments
-- to partner accounts via a partner_id column.
-- Safe to run multiple times (idempotent).
-- ═══════════════════════════════════════════════════════════════

-- Add partner_id columns (nullable for legacy rows)
ALTER TABLE customers   ADD COLUMN IF NOT EXISTS partner_id UUID REFERENCES partner_accounts(id);
ALTER TABLE packages    ADD COLUMN IF NOT EXISTS partner_id UUID REFERENCES partner_accounts(id);
ALTER TABLE invoices    ADD COLUMN IF NOT EXISTS partner_id UUID REFERENCES partner_accounts(id);
ALTER TABLE pre_alerts  ADD COLUMN IF NOT EXISTS partner_id UUID REFERENCES partner_accounts(id);
ALTER TABLE shipments   ADD COLUMN IF NOT EXISTS partner_id UUID REFERENCES partner_accounts(id);

-- Indexes to keep partner-scoped queries fast
CREATE INDEX IF NOT EXISTS idx_customers_partner_id   ON customers(partner_id);
CREATE INDEX IF NOT EXISTS idx_packages_partner_id    ON packages(partner_id);
CREATE INDEX IF NOT EXISTS idx_invoices_partner_id    ON invoices(partner_id);
CREATE INDEX IF NOT EXISTS idx_pre_alerts_partner_id  ON pre_alerts(partner_id);
CREATE INDEX IF NOT EXISTS idx_shipments_partner_id   ON shipments(partner_id);

-- Backfill existing rows by matching packages.tracking_number prefix to
-- partner_accounts.tracking_prefix. Adjust / re-run after adding prefixes.
UPDATE packages p
SET    partner_id = pa.id
FROM   partner_accounts pa
WHERE  p.partner_id IS NULL
  AND  pa.tracking_prefix IS NOT NULL
  AND  pa.tracking_prefix <> ''
  AND  p.tracking_number ILIKE pa.tracking_prefix || '%';

-- Backfill customers via their packages
UPDATE customers c
SET    partner_id = p.partner_id
FROM   packages p
WHERE  c.partner_id IS NULL
  AND  p.customer_id = c.id
  AND  p.partner_id IS NOT NULL;

-- Backfill invoices via customers
UPDATE invoices i
SET    partner_id = c.partner_id
FROM   customers c
WHERE  i.partner_id IS NULL
  AND  i.customer_id = c.id
  AND  c.partner_id IS NOT NULL;

-- Backfill pre_alerts via customers
UPDATE pre_alerts a
SET    partner_id = c.partner_id
FROM   customers c
WHERE  a.partner_id IS NULL
  AND  a.customer_id = c.id
  AND  c.partner_id IS NOT NULL;
