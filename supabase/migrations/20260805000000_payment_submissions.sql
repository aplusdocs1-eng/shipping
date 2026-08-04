-- ═══════════════════════════════════════════════════════════════
-- Customer-submitted payment references for invoices.
--
-- Customers cannot mark their own invoice paid directly (that would
-- let anyone claim payment for free service). Instead they submit a
-- payment method + reference (e.g. a bank transfer confirmation
-- number), and a partner/admin reviews and confirms it, which then
-- calls the existing markInvoicePaid path.
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS payment_submissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_id UUID NOT NULL REFERENCES invoices(id),
  customer_id UUID NOT NULL REFERENCES customers(id),
  partner_id UUID REFERENCES partner_accounts(id),
  method TEXT NOT NULL,
  reference TEXT,
  notes TEXT,
  amount NUMERIC(10,2),
  status TEXT NOT NULL DEFAULT 'pending_review',
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_payment_submissions_invoice_id ON payment_submissions(invoice_id);
CREATE INDEX IF NOT EXISTS idx_payment_submissions_partner_id ON payment_submissions(partner_id);
CREATE INDEX IF NOT EXISTS idx_payment_submissions_customer_id ON payment_submissions(customer_id);

ALTER TABLE payment_submissions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins full access" ON payment_submissions FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM admin_users WHERE auth_user_id = auth.uid() AND is_active))
  WITH CHECK (EXISTS (SELECT 1 FROM admin_users WHERE auth_user_id = auth.uid() AND is_active));

CREATE POLICY "Partners manage own submissions" ON payment_submissions FOR ALL TO authenticated
  USING (partner_id IN (SELECT id FROM partner_accounts WHERE auth_user_id = auth.uid() AND status = 'approved'))
  WITH CHECK (partner_id IN (SELECT id FROM partner_accounts WHERE auth_user_id = auth.uid() AND status = 'approved'));

CREATE POLICY "Customers submit own payments" ON payment_submissions FOR INSERT TO authenticated
  WITH CHECK (customer_id IN (SELECT id FROM customers WHERE auth_user_id = auth.uid()));

CREATE POLICY "Customers read own submissions" ON payment_submissions FOR SELECT TO authenticated
  USING (customer_id IN (SELECT id FROM customers WHERE auth_user_id = auth.uid()));

CREATE TRIGGER set_updated_at BEFORE UPDATE ON payment_submissions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
