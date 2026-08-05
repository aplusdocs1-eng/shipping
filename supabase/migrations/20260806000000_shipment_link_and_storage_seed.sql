-- ═══════════════════════════════════════════════════════════════
-- Link packages to shipments (manifest screen needs to filter
-- packages by the selected shipment instead of showing everything),
-- and seed a starter set of storage zones/locations so the
-- warehouse scan-in flow has real locations to assign, not an
-- empty dropdown.
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE packages ADD COLUMN IF NOT EXISTS shipment_id UUID REFERENCES shipments(id);

INSERT INTO storage_zones (code, name, description, capacity) VALUES
  ('A', 'Zone A', 'Ground floor — small parcels', 200),
  ('B', 'Zone B', 'Ground floor — standard packages', 200),
  ('C', 'Zone C', 'Mezzanine — bulk / oversized', 100)
ON CONFLICT (code) DO NOTHING;

INSERT INTO storage_locations (zone_id, label, shelf, bin, is_occupied)
SELECT z.id, z.code || '-' || s.shelf || '-' || b.bin, s.shelf, b.bin, false
FROM storage_zones z
CROSS JOIN (VALUES ('1'), ('2'), ('3')) AS s(shelf)
CROSS JOIN (VALUES ('1'), ('2'), ('3'), ('4')) AS b(bin)
WHERE z.code IN ('A', 'B', 'C')
  AND NOT EXISTS (SELECT 1 FROM storage_locations WHERE label = z.code || '-' || s.shelf || '-' || b.bin);
