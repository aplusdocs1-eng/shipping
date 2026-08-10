-- Backs three more Settings-adjacent partner dashboard sections that were
-- pure mockups: Broadcast (draft/sent messages), Referrals (real tracking
-- instead of fabricated stats), and Support (real ticket persistence
-- instead of a fake "Ticket submitted" toast with nowhere for it to go).

CREATE TABLE IF NOT EXISTS partner_broadcasts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id UUID NOT NULL REFERENCES partner_accounts(id) ON DELETE CASCADE,
  channel TEXT NOT NULL DEFAULT 'Email',
  audience TEXT NOT NULL DEFAULT 'All Customers',
  subject TEXT NOT NULL DEFAULT '',
  message TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'draft', -- 'draft' | 'sent'
  sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS partner_referrals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id UUID NOT NULL REFERENCES partner_accounts(id) ON DELETE CASCADE,
  referred_company TEXT NOT NULL,
  referred_email TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending', -- 'pending' | 'active'
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS partner_support_tickets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id UUID NOT NULL REFERENCES partner_accounts(id) ON DELETE CASCADE,
  subject TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'open', -- 'open' | 'closed'
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

DO $$
DECLARE
  t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'partner_broadcasts', 'partner_referrals', 'partner_support_tickets'
  ] LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format(
      'CREATE POLICY "Admin full access" ON %I FOR ALL USING (EXISTS (SELECT 1 FROM admin_users WHERE auth_user_id = auth.uid() AND is_active)) WITH CHECK (EXISTS (SELECT 1 FROM admin_users WHERE auth_user_id = auth.uid() AND is_active))',
      t
    );
    EXECUTE format(
      'CREATE POLICY "Partner manages own rows" ON %I FOR ALL USING (partner_id IN (SELECT id FROM partner_accounts WHERE auth_user_id = auth.uid())) WITH CHECK (partner_id IN (SELECT id FROM partner_accounts WHERE auth_user_id = auth.uid()))',
      t
    );
  END LOOP;
END $$;
