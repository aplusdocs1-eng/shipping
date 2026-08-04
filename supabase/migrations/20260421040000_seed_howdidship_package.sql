-- Seed a package for Howdidship's customer "Marcia Williams".
-- This also creates a matching warehouse_entries row so the warehouse
-- screen shows the package.
INSERT INTO packages (
  tracking_number,
  customer_id,
  customer_name,
  description,
  weight,
  declared_value,
  status,
  service_type,
  origin,
  destination,
  partner_id
)
SELECT
  pa.tracking_prefix || to_char(now(), 'YYYYMMDDHH24MISS'),
  c.id,
  c.name,
  'Nike Air Max sneakers (size 10)',
  3.25,
  120.00,
  'received',
  'standard',
  'Miami, FL, USA',
  'Kingston, Jamaica',
  pa.id
FROM partner_accounts pa
JOIN customers c
  ON c.partner_id = pa.id
WHERE pa.company_name ILIKE 'Howdidship%'
  AND c.email = 'marcia.williams@example.com'
LIMIT 1;

-- Matching warehouse_entries row (denormalised — uses the same tracking_number)
INSERT INTO warehouse_entries (
  tracking_number,
  customer_name,
  description,
  weight,
  storage_zone,
  storage_location,
  status,
  scanned_in_by
)
SELECT
  p.tracking_number,
  p.customer_name,
  p.description,
  p.weight,
  'A',
  'A-12',
  'scanned_in',
  'Warehouse Ops'
FROM packages p
JOIN partner_accounts pa ON pa.id = p.partner_id
WHERE pa.company_name ILIKE 'Howdidship%'
  AND p.customer_name = 'Marcia Williams'
  AND NOT EXISTS (
    SELECT 1 FROM warehouse_entries w WHERE w.tracking_number = p.tracking_number
  );

-- Diagnostic
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT p.tracking_number, p.customer_name, p.description, p.weight, p.status,
           pa.company_name AS partner
    FROM packages p
    JOIN partner_accounts pa ON pa.id = p.partner_id
    WHERE pa.company_name ILIKE 'Howdidship%'
    ORDER BY p.created_at DESC
    LIMIT 5
  LOOP
    RAISE NOTICE 'Package: % | % | % | %lb | status=% | partner=%',
      r.tracking_number, r.customer_name, r.description, r.weight, r.status, r.partner;
  END LOOP;
END $$;
