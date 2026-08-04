-- Seed two more Howdidship packages (Devon Brown + Sample Customer)
-- Idempotent: skips inserts if the customer already has any package for this partner.

WITH partner AS (
  SELECT id, tracking_prefix FROM partner_accounts
  WHERE company_name ILIKE 'Howdidship%' LIMIT 1
),
targets AS (
  SELECT c.id AS customer_id, c.name AS customer_name, c.email, p.id AS partner_id, p.tracking_prefix,
         CASE c.email
           WHEN 'devon.brown@example.com'        THEN 'Apple AirPods Pro (2nd gen)'
           WHEN 'sample.customer@howdidship.com' THEN 'Amazon Basics kitchen scale + bath towels'
         END AS description,
         CASE c.email
           WHEN 'devon.brown@example.com'        THEN 0.75
           WHEN 'sample.customer@howdidship.com' THEN 5.80
         END AS weight,
         CASE c.email
           WHEN 'devon.brown@example.com'        THEN 249.00
           WHEN 'sample.customer@howdidship.com' THEN 68.50
         END AS declared_value,
         CASE c.email
           WHEN 'devon.brown@example.com'        THEN 'in_transit'
           WHEN 'sample.customer@howdidship.com' THEN 'received'
         END AS status,
         CASE c.email
           WHEN 'devon.brown@example.com'        THEN 'B'
           WHEN 'sample.customer@howdidship.com' THEN 'A'
         END AS storage_zone,
         CASE c.email
           WHEN 'devon.brown@example.com'        THEN 'B-04'
           WHEN 'sample.customer@howdidship.com' THEN 'A-21'
         END AS storage_location
  FROM customers c
  JOIN partner p ON p.id = c.partner_id
  WHERE c.email IN ('devon.brown@example.com', 'sample.customer@howdidship.com')
),
inserted AS (
  INSERT INTO packages (
    tracking_number, customer_id, customer_name, description,
    weight, declared_value, status, service_type, origin, destination, partner_id
  )
  SELECT
    t.tracking_prefix || to_char(now(), 'YYYYMMDDHH24MISS') || upper(substr(md5(t.email), 1, 4)),
    t.customer_id,
    t.customer_name,
    t.description,
    t.weight,
    t.declared_value,
    t.status,
    'standard',
    'Miami, FL, USA',
    'Kingston, Jamaica',
    t.partner_id
  FROM targets t
  WHERE NOT EXISTS (
    SELECT 1 FROM packages p
    WHERE p.customer_id = t.customer_id AND p.partner_id = t.partner_id
  )
  RETURNING tracking_number, customer_name, description, weight
)
INSERT INTO warehouse_entries (
  tracking_number, customer_name, description, weight,
  storage_zone, storage_location, status, scanned_in_by
)
SELECT i.tracking_number, i.customer_name, i.description, i.weight,
       t.storage_zone, t.storage_location, 'scanned_in', 'Warehouse Ops'
FROM inserted i
JOIN targets t ON t.customer_name = i.customer_name
WHERE NOT EXISTS (
  SELECT 1 FROM warehouse_entries w WHERE w.tracking_number = i.tracking_number
);

-- Diagnostic
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT p.tracking_number, p.customer_name, p.description, p.status, pa.company_name AS partner
    FROM packages p
    JOIN partner_accounts pa ON pa.id = p.partner_id
    WHERE pa.company_name ILIKE 'Howdidship%'
    ORDER BY p.created_at DESC
  LOOP
    RAISE NOTICE 'Package: % | % | % | status=% | partner=%',
      r.tracking_number, r.customer_name, r.description, r.status, r.partner;
  END LOOP;
END $$;
