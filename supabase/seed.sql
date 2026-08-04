-- ═══════════════════════════════════════════════════════════════
-- Seed data for Courier Warehousing
-- Safe to re-run: uses ON CONFLICT DO NOTHING / upsert patterns
-- ═══════════════════════════════════════════════════════════════

-- ── Branches ───────────────────────────────────────────────────
INSERT INTO branches (id, name, address, phone, email, manager, is_active) VALUES
  ('11111111-1111-1111-1111-000000000001', 'Kingston Head Office', '106 Browning Ave, Kingston', '+1 876 305 4847', 'kingston@applizonecentralja.com', 'Sandra Blake', true),
  ('11111111-1111-1111-1111-000000000002', 'Montego Bay Branch',  '45 Barnett St, Montego Bay',  '+1 876 952 0011', 'mobay@applizonecentralja.com',   'Karen Lewis',  true),
  ('11111111-1111-1111-1111-000000000003', 'Portmore Branch',     '12 Central Village Plaza, Portmore', '+1 876 988 3312', 'portmore@applizonecentralja.com', 'Peter Wilson', true),
  ('11111111-1111-1111-1111-000000000004', 'Mandeville Branch',   '3 Ward Ave, Mandeville', '+1 876 625 7745', 'mandeville@applizonecentralja.com', NULL, false)
ON CONFLICT (id) DO NOTHING;

-- ── Staff ──────────────────────────────────────────────────────
INSERT INTO staff (id, name, email, phone, role, branch_id, is_active) VALUES
  ('22222222-2222-2222-2222-000000000001', 'Robert Admin',    'admin@applizonecentralja.com',    '+1 876 400 0001', 'admin',   '11111111-1111-1111-1111-000000000001', true),
  ('22222222-2222-2222-2222-000000000002', 'Sandra Blake',    'sandra@applizonecentralja.com',   '+1 876 400 0002', 'manager', '11111111-1111-1111-1111-000000000001', true),
  ('22222222-2222-2222-2222-000000000003', 'Michael Brown',   'michael@applizonecentralja.com',  '+1 876 400 0003', 'agent',   '11111111-1111-1111-1111-000000000001', true),
  ('22222222-2222-2222-2222-000000000004', 'Karen Lewis',     'karen@applizonecentralja.com',    '+1 876 400 0004', 'agent',   '11111111-1111-1111-1111-000000000002', true),
  ('22222222-2222-2222-2222-000000000005', 'Tony Davis',      'tony@applizonecentralja.com',     '+1 876 400 0005', 'driver',  '11111111-1111-1111-1111-000000000001', true),
  ('22222222-2222-2222-2222-000000000006', 'Grace Thompson',  'grace@applizonecentralja.com',    '+1 876 400 0006', 'driver',  '11111111-1111-1111-1111-000000000002', true),
  ('22222222-2222-2222-2222-000000000007', 'Peter Wilson',    'peter@applizonecentralja.com',    '+1 876 400 0007', 'manager', '11111111-1111-1111-1111-000000000003', false)
ON CONFLICT (id) DO NOTHING;

-- ── Customers ──────────────────────────────────────────────────
INSERT INTO customers (id, name, email, phone, address, mailbox_number, status) VALUES
  ('33333333-3333-3333-3333-000000000001', 'James Harbor',     'james@harborcorp.com',   '+1 305 444 2210', '14 Ocean Blvd, Miami, USA',       'ACJ-1001', 'active'),
  ('33333333-3333-3333-3333-000000000002', 'Maria Santos',     'maria@santos.biz',       '+1 718 552 9900', '55 Park Ave, New York, USA',      'ACJ-1002', 'active'),
  ('33333333-3333-3333-3333-000000000003', 'Devon Clarke',     'dclarke@mail.com',       '+1 876 407 1133', '8 King St, Kingston, Jamaica',    'ACJ-1003', 'active'),
  ('33333333-3333-3333-3333-000000000004', 'Priya Nair',       'priya.nair@techflow.io', '+91 98765 43210', '22 MG Road, Bangalore, India',    'ACJ-1004', 'active'),
  ('33333333-3333-3333-3333-000000000005', 'Carlos Vega',      'cvega@vegatrade.mx',     '+52 55 1234 5678','Av. Insurgentes 400, Mexico City','ACJ-1005', 'inactive'),
  ('33333333-3333-3333-3333-000000000006', 'Amara Diallo',     'amara@diallo.sn',        '+221 76 123 4567','Rue 10 x 23, Dakar, Senegal',     'ACJ-1006', 'active'),
  ('33333333-3333-3333-3333-000000000007', 'Liu Wei',          'liu.wei@shippingco.cn',  '+86 138 0013 8000','88 Nanjing Rd, Shanghai, China', 'ACJ-1007', 'active'),
  ('33333333-3333-3333-3333-000000000008', 'Fatima Al-Hassan', 'fatima@alhassan.ae',     '+971 50 123 4567','Sheikh Zayed Rd, Dubai, UAE',     'ACJ-1008', 'active')
ON CONFLICT (id) DO NOTHING;

-- ── Packages ───────────────────────────────────────────────────
INSERT INTO packages (id, tracking_number, customer_id, customer_name, description, weight, declared_value, status, service_type, origin, destination, created_at) VALUES
  ('44444444-4444-4444-4444-000000000001', 'CW-20260101-4821', '33333333-3333-3333-3333-000000000001', 'James Harbor',     'Electronics - Laptop',   2.4,  1200.00, 'in_transit',       'air',      'Miami, USA',        'Kingston, Jamaica',   '2026-04-01 09:30+00'),
  ('44444444-4444-4444-4444-000000000002', 'CW-20260102-7733', '33333333-3333-3333-3333-000000000002', 'Maria Santos',     'Clothing - Assorted',    5.1,   350.00, 'delivered',        'air',      'New York, USA',     'Santo Domingo, DR',   '2026-03-28 12:00+00'),
  ('44444444-4444-4444-4444-000000000003', 'CW-20260103-1122', '33333333-3333-3333-3333-000000000003', 'Devon Clarke',     'Auto Parts',             8.7,   620.00, 'out_for_delivery', 'standard', 'Kingston, Jamaica', 'Montego Bay, Jamaica','2026-04-05 10:00+00'),
  ('44444444-4444-4444-4444-000000000004', 'CW-20260104-9988', '33333333-3333-3333-3333-000000000004', 'Priya Nair',       'Pharmaceuticals',        1.2,   890.00, 'pending',          'air',      'Bangalore, India',  'Dubai, UAE',          '2026-04-08 08:15+00'),
  ('44444444-4444-4444-4444-000000000005', 'CW-20260104-3344', '33333333-3333-3333-3333-000000000005', 'Carlos Vega',      'Documents',              0.3,    50.00, 'exception',        'express',  'Mexico City, Mexico','Miami, USA',         '2026-04-03 14:30+00'),
  ('44444444-4444-4444-4444-000000000006', 'CW-20260105-5566', '33333333-3333-3333-3333-000000000007', 'Liu Wei',          'Furniture Parts',       22.0,  3200.00, 'in_transit',       'sea',      'Shanghai, China',   'Los Angeles, USA',    '2026-03-25 06:00+00'),
  ('44444444-4444-4444-4444-000000000007', 'CW-20260106-7711', '33333333-3333-3333-3333-000000000008', 'Fatima Al-Hassan', 'Jewelry',                0.5,  5000.00, 'delivered',        'express',  'Dubai, UAE',        'London, UK',          '2026-04-04 11:45+00'),
  ('44444444-4444-4444-4444-000000000008', 'CW-20260107-2200', '33333333-3333-3333-3333-000000000006', 'Amara Diallo',     'Food Items',             4.5,   120.00, 'in_transit',       'sea',      'Dakar, Senegal',    'Paris, France',       '2026-04-07 16:20+00')
ON CONFLICT (id) DO NOTHING;

-- ── Shipments ──────────────────────────────────────────────────
INSERT INTO shipments (id, shipment_number, origin, destination, carrier, status, total_packages, total_weight, estimated_arrival, created_at) VALUES
  ('55555555-5555-5555-5555-000000000001', 'AIR-2026-0041', 'Miami, USA',           'Kingston, Jamaica', 'AA2204 (air)',         'in_transit', 38,  142.5,  '2026-04-09 14:00+00', '2026-04-05 08:00+00'),
  ('55555555-5555-5555-5555-000000000002', 'SEA-2026-0019', 'Fort Lauderdale, USA', 'Kingston, Jamaica', 'Caribbean Star (sea)', 'arrived',   214, 3840.0,  '2026-04-07 09:00+00', '2026-03-20 08:00+00'),
  ('55555555-5555-5555-5555-000000000003', 'AIR-2026-0040', 'Miami, USA',           'Kingston, Jamaica', 'JB1122 (air)',         'cleared',    52,  198.0,  '2026-04-03 11:00+00', '2026-04-01 08:00+00'),
  ('55555555-5555-5555-5555-000000000004', 'SEA-2026-0018', 'New York, USA',        'Kingston, Jamaica', 'Atlantic Voyager (sea)','closed',   310, 6200.0,  '2026-03-28 10:00+00', '2026-03-10 08:00+00'),
  ('55555555-5555-5555-5555-000000000005', 'AIR-2026-0042', 'Miami, USA',           'Kingston, Jamaica', 'AA2208 (air)',         'preparing',   0,    0.0,  '2026-04-12 14:00+00', '2026-04-08 08:00+00')
ON CONFLICT (id) DO NOTHING;

-- ── Pre-Alerts ─────────────────────────────────────────────────
INSERT INTO pre_alerts (id, tracking_number, customer_id, customer_name, carrier, description, status, created_at) VALUES
  ('66666666-6666-6666-6666-000000000001', '1Z999AA10123456784',    '33333333-3333-3333-3333-000000000001', 'James Harbor',    'UPS',         'Laptop & Accessories', 'received',   '2026-04-05 10:00+00'),
  ('66666666-6666-6666-6666-000000000002', '9400111899223059705082','33333333-3333-3333-3333-000000000002', 'Maria Santos',    'USPS',        'Clothing x5',          'pending',    '2026-04-07 12:00+00'),
  ('66666666-6666-6666-6666-000000000003', 'JD014600004987020901',  '33333333-3333-3333-3333-000000000003', 'Devon Clarke',    'DHL',         'Industrial Parts',     'processing', '2026-04-03 14:00+00'),
  ('66666666-6666-6666-6666-000000000004', '773849201',             '33333333-3333-3333-3333-000000000007', 'Liu Wei',         'FedEx',       'Electronics - TV',     'ready',      '2026-04-01 09:00+00'),
  ('66666666-6666-6666-6666-000000000005', 'EE123456789IN',         '33333333-3333-3333-3333-000000000004', 'Priya Nair',      'India Post',  'Pharmaceuticals',      'pending',    '2026-04-08 08:00+00'),
  ('66666666-6666-6666-6666-000000000006', 'CN876543210',           '33333333-3333-3333-3333-000000000006', 'Amara Diallo',    'China Post',  'Shoes x3',             'completed',  '2026-03-28 16:00+00')
ON CONFLICT (id) DO NOTHING;

-- ── Warehouse Entries ──────────────────────────────────────────
INSERT INTO warehouse_entries (id, tracking_number, customer_name, description, weight, storage_zone, storage_location, status, scanned_in_at, scanned_in_by) VALUES
  ('77777777-7777-7777-7777-000000000001', 'CW-20260101-4821', 'James Harbor',     'Electronics - Laptop',  2.4, 'Zone A', 'A1-01', 'stored',           '2026-04-02 09:30+00', 'Michael Brown'),
  ('77777777-7777-7777-7777-000000000002', 'CW-20260103-1122', 'Devon Clarke',     'Auto Parts',            8.7, 'Zone B', 'B1-02', 'ready_for_pickup', '2026-04-06 11:00+00', 'Karen Lewis'),
  ('77777777-7777-7777-7777-000000000003', 'CW-20260106-7711', 'Fatima Al-Hassan', 'Jewelry',               0.5, 'Zone A', 'A2-01', 'picked_up',        '2026-04-05 10:00+00', 'Michael Brown'),
  ('77777777-7777-7777-7777-000000000004', 'CW-20260107-2200', 'Amara Diallo',     'Food Items',            4.5, 'Zone C', 'C1-01', 'scanned_in',       '2026-04-08 14:00+00', 'Sandra Blake')
ON CONFLICT (id) DO NOTHING;

-- ── Invoices ───────────────────────────────────────────────────
INSERT INTO invoices (id, invoice_number, customer_id, customer_name, amount, tax, total, status, due_date, created_at) VALUES
  ('88888888-8888-8888-8888-000000000001', 'INV-2026-0041', '33333333-3333-3333-3333-000000000001', 'James Harbor',     97.00,  9.70, 106.70, 'sent',     '2026-04-15', '2026-04-01 08:00+00'),
  ('88888888-8888-8888-8888-000000000002', 'INV-2026-0040', '33333333-3333-3333-3333-000000000002', 'Maria Santos',     55.00,  5.50,  60.50, 'paid',     '2026-04-11', '2026-03-28 08:00+00'),
  ('88888888-8888-8888-8888-000000000003', 'INV-2026-0039', '33333333-3333-3333-3333-000000000007', 'Liu Wei',         503.00, 50.30, 553.30, 'sent',     '2026-04-08', '2026-03-25 08:00+00'),
  ('88888888-8888-8888-8888-000000000004', 'INV-2026-0038', '33333333-3333-3333-3333-000000000005', 'Carlos Vega',      28.00,  2.80,  30.80, 'overdue',  '2026-04-03', '2026-03-20 08:00+00'),
  ('88888888-8888-8888-8888-000000000005', 'INV-2026-0037', '33333333-3333-3333-3333-000000000003', 'Devon Clarke',     45.00,  4.50,  49.50, 'paid',     '2026-04-19', '2026-04-05 08:00+00'),
  ('88888888-8888-8888-8888-000000000006', 'INV-2026-0036', '33333333-3333-3333-3333-000000000008', 'Fatima Al-Hassan',255.00, 25.50, 280.50, 'paid',     '2026-04-18', '2026-04-04 08:00+00'),
  ('88888888-8888-8888-8888-000000000007', 'INV-2026-0035', '33333333-3333-3333-3333-000000000004', 'Priya Nair',      120.00, 12.00, 132.00, 'draft',    '2026-04-22', '2026-04-08 08:00+00')
ON CONFLICT (id) DO NOTHING;

-- ── Shipping Partners ──────────────────────────────────────────
INSERT INTO shipping_partners (id, code, name, region, tracking_prefix, contact_email, is_active) VALUES
  ('99999999-9999-9999-9999-000000000001', 'DHL',   'DHL Express',     'Global',       'DHL',  'partners@dhl.com',   true),
  ('99999999-9999-9999-9999-000000000002', 'FEDEX', 'FedEx',           'Global',       'FDX',  'partners@fedex.com', true),
  ('99999999-9999-9999-9999-000000000003', 'UPS',   'UPS Worldwide',   'Global',       'UPS',  'partners@ups.com',   true),
  ('99999999-9999-9999-9999-000000000004', 'USPS',  'US Postal',       'United States','USPS', 'partners@usps.com',  true),
  ('99999999-9999-9999-9999-000000000005', 'KNUT',  'Knutsford Express','Jamaica',     'KNT',  'partners@knutsford.com', true)
ON CONFLICT (id) DO NOTHING;

-- ── Verify counts ──────────────────────────────────────────────
SELECT 'branches'           AS table_name, COUNT(*) AS rows FROM branches          UNION ALL
SELECT 'staff',              COUNT(*) FROM staff               UNION ALL
SELECT 'customers',          COUNT(*) FROM customers           UNION ALL
SELECT 'packages',           COUNT(*) FROM packages            UNION ALL
SELECT 'shipments',          COUNT(*) FROM shipments           UNION ALL
SELECT 'pre_alerts',         COUNT(*) FROM pre_alerts          UNION ALL
SELECT 'warehouse_entries',  COUNT(*) FROM warehouse_entries   UNION ALL
SELECT 'invoices',           COUNT(*) FROM invoices            UNION ALL
SELECT 'shipping_partners',  COUNT(*) FROM shipping_partners;
