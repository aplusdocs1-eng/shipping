-- Retry: seed Howdidship customer. Earlier attempt matched tracking_prefix='HDS'
-- but the actual prefix is 'HDS-' — use a LIKE match to be robust.
INSERT INTO customers (name, email, phone, address, mailbox_number, status, partner_id)
SELECT
  'Howdidship Sample Customer',
  'sample.customer@howdidship.com',
  '+1 876 555 0100',
  '1 Howdidship Way, Kingston, Jamaica',
  pa.tracking_prefix || to_char(now(), 'YYYYMMDDHH24MISS'),
  'active',
  pa.id
FROM partner_accounts pa
WHERE pa.company_name ILIKE 'Howdidship%'
LIMIT 1;

-- Add a couple more so the dashboard has something to chart.
INSERT INTO customers (name, email, phone, address, mailbox_number, status, partner_id)
SELECT
  'Marcia Williams',
  'marcia.williams@example.com',
  '+1 876 555 0111',
  '14 Half Way Tree Road, Kingston 5',
  pa.tracking_prefix || '1001',
  'active',
  pa.id
FROM partner_accounts pa
WHERE pa.company_name ILIKE 'Howdidship%'
  AND NOT EXISTS (
    SELECT 1 FROM customers c WHERE c.email = 'marcia.williams@example.com'
  )
LIMIT 1;

INSERT INTO customers (name, email, phone, address, mailbox_number, status, partner_id)
SELECT
  'Devon Brown',
  'devon.brown@example.com',
  '+1 876 555 0122',
  '22 Constant Spring Rd, Kingston 10',
  pa.tracking_prefix || '1002',
  'active',
  pa.id
FROM partner_accounts pa
WHERE pa.company_name ILIKE 'Howdidship%'
  AND NOT EXISTS (
    SELECT 1 FROM customers c WHERE c.email = 'devon.brown@example.com'
  )
LIMIT 1;

-- Diagnostic
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT name, email, mailbox_number, partner_id FROM customers ORDER BY created_at DESC LIMIT 5 LOOP
    RAISE NOTICE 'Seeded customer: % | % | mailbox=% | partner_id=%',
      r.name, r.email, r.mailbox_number, r.partner_id;
  END LOOP;
END $$;
