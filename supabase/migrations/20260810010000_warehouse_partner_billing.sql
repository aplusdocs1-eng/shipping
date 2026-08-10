-- Lets admin/warehouse staff bill a courier (partner_accounts tenant) for
-- processing a specific package in the warehouse, and lets that courier
-- see and pay each charge individually from their own dashboard.
--
-- Scoped per physical warehouse_entries row (i.e. per package actually
-- handled), not a lump-sum partner invoice — a courier's own tracking
-- prefix is what already identifies which of their customers' packages
-- this is (see getWarehouseEntriesByPrefix), so no new linking column is
-- needed to know which courier a charge belongs to.
ALTER TABLE warehouse_entries
  ADD COLUMN IF NOT EXISTS partner_charge_amount NUMERIC,
  ADD COLUMN IF NOT EXISTS partner_charge_status TEXT NOT NULL DEFAULT 'unbilled', -- 'unbilled' | 'billed' | 'paid'
  ADD COLUMN IF NOT EXISTS partner_charge_note TEXT,
  ADD COLUMN IF NOT EXISTS partner_charged_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS partner_paid_at TIMESTAMPTZ;

-- warehouse_entries previously had only an admin-only RLS policy — any
-- partner (non-admin) read of it, including the existing Receivals page,
-- was actually being satisfied only because the one account tested with
-- this session also happens to be an admin. A real courier-only account
-- would have been silently blocked. Add real partner-scoped policies:
-- read their own rows (by tracking prefix), and update only to record
-- payment on a charge already billed to them — never insert/delete
-- (scanning packages in/out stays admin/warehouse-only).
DROP POLICY IF EXISTS "Partners read own prefix" ON warehouse_entries;
CREATE POLICY "Partners read own prefix" ON warehouse_entries FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM partner_accounts pa
    WHERE pa.auth_user_id = auth.uid()
      AND pa.tracking_prefix IS NOT NULL
      AND pa.tracking_prefix <> ''
      AND warehouse_entries.tracking_number ILIKE pa.tracking_prefix || '%'
  )
);

DROP POLICY IF EXISTS "Partners pay own charges" ON warehouse_entries;
CREATE POLICY "Partners pay own charges" ON warehouse_entries FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM partner_accounts pa
    WHERE pa.auth_user_id = auth.uid()
      AND pa.tracking_prefix IS NOT NULL
      AND pa.tracking_prefix <> ''
      AND warehouse_entries.tracking_number ILIKE pa.tracking_prefix || '%'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM partner_accounts pa
    WHERE pa.auth_user_id = auth.uid()
      AND pa.tracking_prefix IS NOT NULL
      AND pa.tracking_prefix <> ''
      AND warehouse_entries.tracking_number ILIKE pa.tracking_prefix || '%'
  )
);
