-- Link packages to their generated invoice and record the billed amount so
-- pickup can be gated on payment.
ALTER TABLE packages ADD COLUMN IF NOT EXISTS invoice_id UUID REFERENCES invoices(id);
ALTER TABLE packages ADD COLUMN IF NOT EXISTS billed_amount NUMERIC(10,2);
ALTER TABLE packages ADD COLUMN IF NOT EXISTS picked_up_at TIMESTAMPTZ;
ALTER TABLE packages ADD COLUMN IF NOT EXISTS picked_up_by TEXT;

CREATE INDEX IF NOT EXISTS idx_packages_invoice_id ON packages(invoice_id);
