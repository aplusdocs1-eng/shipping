-- ═══════════════════════════════════════════════════════════════
-- Migration: Two-tier billing
-- invoice_type = 'customer_billing'  → partner bills customer
-- invoice_type = 'partner_billing'   → admin bills partner
-- partner_account_id links to partner_accounts.id for partner invoices
-- ═══════════════════════════════════════════════════════════════

-- Add invoice_type column (default customer_billing for existing rows)
ALTER TABLE invoices
  ADD COLUMN IF NOT EXISTS invoice_type TEXT NOT NULL DEFAULT 'customer_billing';

-- Add partner_account_id column for admin→partner invoices
ALTER TABLE invoices
  ADD COLUMN IF NOT EXISTS partner_account_id UUID REFERENCES partner_accounts(id);

-- Add partner_name for display on admin billing invoices
ALTER TABLE invoices
  ADD COLUMN IF NOT EXISTS partner_name TEXT;

-- Index for fast filtered lookups
CREATE INDEX IF NOT EXISTS idx_invoices_type          ON invoices(invoice_type);
CREATE INDEX IF NOT EXISTS idx_invoices_partner_acct  ON invoices(partner_account_id);
