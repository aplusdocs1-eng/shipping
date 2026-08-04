-- ═══════════════════════════════════════════════════════════════
-- "Applizone Central Jamaica" direct tenant.
--
-- Customers who sign up from the main marketing site (not a partner's
-- own domain) need a partner_id to be scoped under, same as any other
-- customer. This row represents Applizone itself as its own direct
-- shipping tenant — same tables, same RLS, same scoping as a partner,
-- just resolved as the fallback tenant on the admin host instead of
-- via a custom domain lookup.
--
-- auth_user_id anchors to a pre-created service account
-- (direct@applizonecentralja.com) that exists purely to satisfy the
-- NOT NULL FK — nobody logs in through it.
--
-- Fixed id so Flutter code can reference it directly without an
-- extra lookup query.
-- ═══════════════════════════════════════════════════════════════

INSERT INTO partner_accounts (
  id, auth_user_id, company_name, contact_name, email, phone,
  tracking_prefix, status, plan
)
VALUES (
  '00000000-0000-0000-0000-000000000001',
  '0a9c0184-a976-49eb-94fb-954ce5d50528',
  'Applizone Central Jamaica',
  'Applizone Central Jamaica',
  'direct@applizonecentralja.com',
  NULL,
  'ACJ-',
  'approved',
  'direct'
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO shipping_partners (id, code, name, region, tracking_prefix, contact_email, is_active)
VALUES (
  '00000000-0000-0000-0000-000000000002',
  'ACJ',
  'Applizone Central Jamaica',
  'Jamaica',
  'ACJ-',
  'direct@applizonecentralja.com',
  true
)
ON CONFLICT (id) DO NOTHING;

UPDATE partner_accounts
SET partner_id = '00000000-0000-0000-0000-000000000002'
WHERE id = '00000000-0000-0000-0000-000000000001'
  AND partner_id IS NULL;
