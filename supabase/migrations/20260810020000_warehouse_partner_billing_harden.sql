-- Tighten "Partners pay own charges" from the previous migration.
--
-- As first written, the UPDATE policy only checked tracking-prefix
-- ownership — it didn't restrict *what* a partner could change. A partner
-- could, via a direct REST call (not through the app UI, which only ever
-- offers "mark paid"), set their own partner_charge_status to 'billed' with
-- a self-chosen amount, or flip a legitimately billed charge back to
-- 'unbilled'. Only One Village staff (the admin FOR ALL policy) should ever
-- be able to originate or reverse a charge; a partner should only be able
-- to move a charge that is already 'billed' forward to 'paid'.
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
  AND partner_charge_status = 'billed'
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM partner_accounts pa
    WHERE pa.auth_user_id = auth.uid()
      AND pa.tracking_prefix IS NOT NULL
      AND pa.tracking_prefix <> ''
      AND warehouse_entries.tracking_number ILIKE pa.tracking_prefix || '%'
  )
  AND partner_charge_status = 'paid'
);
