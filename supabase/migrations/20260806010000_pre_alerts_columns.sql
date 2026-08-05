-- ═══════════════════════════════════════════════════════════════
-- lib/models/models.dart's PreAlert.fromMap has always read
-- weight, declared_value, and freight_type from pre_alerts rows,
-- but those columns never existed on the table — every pre-alert
-- has silently shown weight=0, value=0, type=air regardless of
-- what was actually submitted. Add the missing columns.
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE pre_alerts ADD COLUMN IF NOT EXISTS weight NUMERIC(10,2) NOT NULL DEFAULT 0;
ALTER TABLE pre_alerts ADD COLUMN IF NOT EXISTS declared_value NUMERIC(10,2) NOT NULL DEFAULT 0;
ALTER TABLE pre_alerts ADD COLUMN IF NOT EXISTS freight_type TEXT NOT NULL DEFAULT 'air';
