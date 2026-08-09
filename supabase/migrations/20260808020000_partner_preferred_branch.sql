-- Backs the partner dashboard's top-bar location button, which previously
-- showed a hardcoded, non-functional "kingston" label with no real data
-- behind it. Lets a partner tenant record which OneVillage branch their
-- shipments primarily route through.
ALTER TABLE partner_accounts
  ADD COLUMN IF NOT EXISTS preferred_branch_id UUID REFERENCES branches(id);
