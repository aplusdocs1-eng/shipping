-- Every customer's mailbox_number (e.g. "HDS-1001") doubles as their
-- unique forwarding-address ID — it's what gets appended to the shared
-- warehouse address on their "Shipping Addresses" page, and it's the
-- single highest-confidence signal the OCR CustomerMatchService uses
-- ("Customer ID substring in OCR text" = 100, its top tier). Two
-- customers sharing one mailbox number would make that signal actively
-- wrong instead of just missing, and would mean warehouse staff can no
-- longer tell them apart from the address alone. Until now nothing
-- enforced it was unique — this is the real, DB-level guarantee.
--
-- A generated *suggestion* is still just a suggestion (see
-- DatabaseService.suggestNextMailboxNumber) — this partial unique index
-- is what actually stops two customers from ending up with the same one,
-- including via a raw REST call that bypasses the app entirely.
-- Partial (WHERE ... IS NOT NULL AND <> '') because the column has
-- always allowed null/blank for customers created before this existed —
-- confirmed zero existing duplicates in production before adding this.
CREATE UNIQUE INDEX IF NOT EXISTS idx_customers_mailbox_number_unique
  ON customers (mailbox_number)
  WHERE mailbox_number IS NOT NULL AND mailbox_number <> '';
