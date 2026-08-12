-- Adding staff payroll fields (address, banking, monthly pay) — needed to
-- record a staff member's pay rate and where their payroll payment goes.
-- No money moves through this app yet (see payroll_runs/payroll_entries
-- below); these are the details an admin fills in once per staff member
-- so a payroll run has something real to record against.
ALTER TABLE staff
  ADD COLUMN IF NOT EXISTS address TEXT,
  ADD COLUMN IF NOT EXISTS monthly_salary NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS bank_name TEXT,
  ADD COLUMN IF NOT EXISTS bank_account_name TEXT,
  ADD COLUMN IF NOT EXISTS bank_account_number TEXT,
  ADD COLUMN IF NOT EXISTS bank_routing_number TEXT;

-- ═══════════════════════════════════════════════════════════════
-- Payroll — real record-keeping, not a real payment integration. There
-- is no Stripe Connect (or any other payout capability) wired into this
-- app: the "Stripe" toggle in Settings has never been more than a
-- stored on/off flag and an API key field nothing reads. A "Pay" button
-- that pretended to move real money without that infrastructure would
-- be actively dangerous — staff could be told they were paid when they
-- weren't. So payroll_runs / payroll_entries record who was paid, how
-- much, and when an admin marks it so; the actual transfer happens
-- however it does today (bank transfer, check, etc.), outside this app.
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS payroll_runs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  period_label TEXT NOT NULL,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  status TEXT NOT NULL DEFAULT 'draft', -- draft | paid
  total_amount NUMERIC(10,2) NOT NULL DEFAULT 0,
  created_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  paid_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS payroll_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payroll_run_id UUID NOT NULL REFERENCES payroll_runs(id) ON DELETE CASCADE,
  staff_id UUID REFERENCES staff(id) ON DELETE SET NULL,
  staff_name TEXT NOT NULL,
  amount NUMERIC(10,2) NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending', -- pending | paid
  payment_method TEXT NOT NULL DEFAULT 'Bank Transfer',
  reference TEXT,
  paid_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE payroll_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE payroll_entries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins full access" ON payroll_runs FOR ALL TO authenticated
  USING (is_active_admin()) WITH CHECK (is_active_admin());

CREATE POLICY "Admins full access" ON payroll_entries FOR ALL TO authenticated
  USING (is_active_admin()) WITH CHECK (is_active_admin());
