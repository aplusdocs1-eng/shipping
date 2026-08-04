-- One-off: seed a customer for the Howdidship partner account.
-- Matches partner_accounts by tracking_prefix = 'HDS' (Howdidship).
INSERT INTO customers (name, email, phone, address, mailbox_number, status, partner_id)
SELECT
  'Howdidship Sample Customer',
  'sample.customer@howdidship.com',
  '+1 876 555 0100',
  '1 Howdidship Way, Kingston, Jamaica',
  'HDS-' || to_char(now(), 'YYYYMMDDHH24MISS'),
  'active',
  pa.id
FROM partner_accounts pa
WHERE pa.tracking_prefix = 'HDS'
LIMIT 1;
