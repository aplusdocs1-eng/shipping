-- The Scan In Package dialog previously let a package be scanned in with no
-- real customer (falling back to the literal string "Unknown Customer") and
-- no required courier/partner assignment (shipping_partner_code could be
-- left null with no way to explicitly mark it as an in-house "One Village
-- Shipping & Freight" (OVS) package). Both are now required in the UI; this
-- column gives the customer link real relational integrity instead of only
-- a denormalized name string. shipping_partner_code already references a
-- real shipping_partners.code (including the seeded OVS row for in-house
-- packages), so no equivalent column is needed for the courier side.
ALTER TABLE warehouse_entries
  ADD COLUMN IF NOT EXISTS customer_id UUID REFERENCES customers(id);

CREATE INDEX IF NOT EXISTS idx_warehouse_entries_customer_id
  ON warehouse_entries(customer_id);
