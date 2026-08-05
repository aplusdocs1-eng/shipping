-- Shipment.fromMap in lib/models/models.dart reads vessel_name,
-- flight_number, and notes, but none of these columns exist on the
-- shipments table yet.
ALTER TABLE shipments ADD COLUMN IF NOT EXISTS vessel_name TEXT;
ALTER TABLE shipments ADD COLUMN IF NOT EXISTS flight_number TEXT;
ALTER TABLE shipments ADD COLUMN IF NOT EXISTS notes TEXT;
