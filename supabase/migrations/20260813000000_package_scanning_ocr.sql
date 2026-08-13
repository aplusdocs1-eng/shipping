-- Warehouse package receiving: barcode + OCR scanning.
--
-- Adapts the EXISTING warehouse_entries table (the real "a physical
-- package arrived at the warehouse" event record — see
-- 20260808010000_warehouse_entry_customer_link.sql) rather than creating
-- a parallel packages-like table. warehouse_entries already has
-- customer_id, courier-billing fields, and a working "unknown package"
-- precedent (customer_id IS NULL, used today by the partner portal's
-- unknown-packages view) — this migration extends that same table with
-- everything the OCR/matching pipeline needs, instead of duplicating it.
--
-- customers.mailbox_number (e.g. "HDS-1001") already IS the "Customer ID"
-- concept the matching engine's strongest tier needs — no new column
-- required there.

-- ── warehouse_entries: OCR + barcode + matching fields ──────────────────
ALTER TABLE warehouse_entries
  ADD COLUMN IF NOT EXISTS barcode_value TEXT,
  ADD COLUMN IF NOT EXISTS barcode_type TEXT,
  ADD COLUMN IF NOT EXISTS carrier TEXT,
  ADD COLUMN IF NOT EXISTS carrier_confidence NUMERIC(3,2),
  ADD COLUMN IF NOT EXISTS recipient_name TEXT,
  ADD COLUMN IF NOT EXISTS recipient_company TEXT,
  ADD COLUMN IF NOT EXISTS address_line_1 TEXT,
  ADD COLUMN IF NOT EXISTS address_line_2 TEXT,
  ADD COLUMN IF NOT EXISTS city TEXT,
  ADD COLUMN IF NOT EXISTS state TEXT,
  ADD COLUMN IF NOT EXISTS province TEXT,
  ADD COLUMN IF NOT EXISTS postal_code TEXT,
  ADD COLUMN IF NOT EXISTS country TEXT,
  ADD COLUMN IF NOT EXISTS recipient_phone TEXT,
  ADD COLUMN IF NOT EXISTS recipient_email TEXT,
  ADD COLUMN IF NOT EXISTS order_number TEXT,
  ADD COLUMN IF NOT EXISTS reference_number TEXT,
  ADD COLUMN IF NOT EXISTS service_type TEXT,
  ADD COLUMN IF NOT EXISTS sender_name TEXT,
  ADD COLUMN IF NOT EXISTS sender_address TEXT,
  ADD COLUMN IF NOT EXISTS sender_city TEXT,
  ADD COLUMN IF NOT EXISTS sender_state TEXT,
  ADD COLUMN IF NOT EXISTS sender_postal_code TEXT,
  ADD COLUMN IF NOT EXISTS sender_country TEXT,
  ADD COLUMN IF NOT EXISTS raw_ocr_text TEXT,
  ADD COLUMN IF NOT EXISTS normalized_ocr_text TEXT,
  ADD COLUMN IF NOT EXISTS ocr_confidence NUMERIC(3,2),
  -- 0-100 overall customer-match score (see CustomerMatchService).
  ADD COLUMN IF NOT EXISTS match_score NUMERIC(5,2) NOT NULL DEFAULT 0,
  -- auto_matched | needs_review | unknown | matched | rejected
  ADD COLUMN IF NOT EXISTS match_status TEXT NOT NULL DEFAULT 'unmatched',
  -- Ranked candidate matches computed at scan time, so the manual-review
  -- screen doesn't need to recompute them and staff can see exactly what
  -- the engine considered.
  ADD COLUMN IF NOT EXISTS match_candidates JSONB,
  ADD COLUMN IF NOT EXISTS match_reason TEXT,
  -- Path within the package-labels bucket, not a URL — signed URLs expire,
  -- so the UI mints a fresh one from this path on demand.
  ADD COLUMN IF NOT EXISTS label_image_path TEXT,
  -- warehouse_id + tracking/barcode — prevents a retried or replayed scan
  -- (flaky network, offline-queue resync) from ever creating a second row
  -- for the same physical scan action. See idempotency_key generation in
  -- OfflineScanQueue / process-package-scan.
  ADD COLUMN IF NOT EXISTS idempotency_key TEXT,
  ADD COLUMN IF NOT EXISTS scan_source TEXT NOT NULL DEFAULT 'manual_entry',
  ADD COLUMN IF NOT EXISTS internal_notes TEXT,
  ADD COLUMN IF NOT EXISTS rejected_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS rejected_by UUID REFERENCES admin_users(id),
  ADD COLUMN IF NOT EXISTS rejected_reason TEXT,
  -- Set when an Unknown Package is later matched/assigned to a customer —
  -- distinct from scanned_in_by, which is who did the original scan.
  ADD COLUMN IF NOT EXISTS assigned_by UUID REFERENCES admin_users(id),
  ADD COLUMN IF NOT EXISTS assigned_at TIMESTAMPTZ;

-- Idempotency: hard-enforced at the DB level (safe to make unique — it's
-- specifically a dedup key for the same scan action, not a business
-- constraint on tracking numbers, which legitimately can't be a hard
-- UNIQUE here: warehouse_entries has no such constraint today and
-- shouldn't gain one from this feature, since duplicate *tracking numbers*
-- are a soft, staff-overridable warning per spec, not an impossibility).
CREATE UNIQUE INDEX IF NOT EXISTS idx_warehouse_entries_idempotency_key
  ON warehouse_entries(idempotency_key) WHERE idempotency_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_warehouse_entries_barcode_value
  ON warehouse_entries(barcode_value);
CREATE INDEX IF NOT EXISTS idx_warehouse_entries_match_status
  ON warehouse_entries(match_status);
CREATE INDEX IF NOT EXISTS idx_warehouse_entries_recipient_name
  ON warehouse_entries(recipient_name);
CREATE INDEX IF NOT EXISTS idx_warehouse_entries_order_number
  ON warehouse_entries(order_number);
CREATE INDEX IF NOT EXISTS idx_warehouse_entries_reference_number
  ON warehouse_entries(reference_number);
CREATE INDEX IF NOT EXISTS idx_warehouse_entries_postal_code
  ON warehouse_entries(postal_code);
-- tracking_number already has default btree coverage via lookups elsewhere
-- in this codebase, but this feature adds ILIKE-prefix search, which wants
-- its own index.
CREATE INDEX IF NOT EXISTS idx_warehouse_entries_tracking_number
  ON warehouse_entries(tracking_number);

COMMENT ON COLUMN warehouse_entries.match_status IS
  'unmatched (legacy default) | auto_matched | needs_review | unknown | matched | rejected';

-- ── Audit log ─────────────────────────────────────────────────────────
-- No general-purpose audit table existed anywhere in the schema before
-- this — this one is scoped to the scanning/receiving workflow rather
-- than claiming to be a whole-app audit system.
CREATE TABLE IF NOT EXISTS package_scan_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  warehouse_entry_id UUID REFERENCES warehouse_entries(id) ON DELETE SET NULL,
  action TEXT NOT NULL,
  performed_by UUID REFERENCES admin_users(id),
  performed_by_name TEXT NOT NULL DEFAULT '',
  old_value JSONB,
  new_value JSONB,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_package_scan_audit_log_entry
  ON package_scan_audit_log(warehouse_entry_id);
CREATE INDEX IF NOT EXISTS idx_package_scan_audit_log_created_at
  ON package_scan_audit_log(created_at DESC);

COMMENT ON COLUMN package_scan_audit_log.action IS
  'package_scanned | ocr_completed | customer_matched | package_received | '
  'package_updated | customer_assignment_changed | duplicate_detected | '
  'package_rejected | manual_override';

ALTER TABLE package_scan_audit_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins full access" ON package_scan_audit_log;
CREATE POLICY "Admins full access" ON package_scan_audit_log FOR ALL TO authenticated
  USING (is_active_admin())
  WITH CHECK (is_active_admin());

-- ── Scanner settings (admin-configurable thresholds/toggles) ────────────
-- One row, same shape as the existing single-row company/admin settings
-- pattern already used elsewhere (admin_settings) rather than a new
-- key-value table.
CREATE TABLE IF NOT EXISTS scanner_settings (
  id BOOLEAN PRIMARY KEY DEFAULT true CONSTRAINT scanner_settings_singleton CHECK (id),
  auto_match_threshold NUMERIC(5,2) NOT NULL DEFAULT 90,
  manual_review_threshold NUMERIC(5,2) NOT NULL DEFAULT 70,
  auto_capture_label BOOLEAN NOT NULL DEFAULT true,
  rapid_scanning BOOLEAN NOT NULL DEFAULT true,
  save_label_images BOOLEAN NOT NULL DEFAULT true,
  require_manual_confirmation BOOLEAN NOT NULL DEFAULT true,
  offline_scanning BOOLEAN NOT NULL DEFAULT true,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by UUID REFERENCES admin_users(id)
);
INSERT INTO scanner_settings (id) VALUES (true) ON CONFLICT (id) DO NOTHING;

ALTER TABLE scanner_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins full access" ON scanner_settings;
CREATE POLICY "Admins full access" ON scanner_settings FOR ALL TO authenticated
  USING (is_active_admin())
  WITH CHECK (is_active_admin());
-- Every authenticated user (including customers/partners, indirectly, via
-- any future scanning surface) can read the thresholds — nothing in this
-- row is sensitive, and the scanner UI itself needs to read it.
DROP POLICY IF EXISTS "Authenticated read" ON scanner_settings;
CREATE POLICY "Authenticated read" ON scanner_settings FOR SELECT TO authenticated
  USING (true);
