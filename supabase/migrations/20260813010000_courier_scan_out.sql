-- Courier "Scan Out" — lets a partner (courier) account scan a package's
-- barcode/tracking number from their own dashboard to record that they
-- physically picked it up from the warehouse.
--
-- warehouse_entries already has an admin-only UPDATE policy, and a
-- narrowly-hardened partner UPDATE policy that only allows moving
-- partner_charge_status 'billed' -> 'paid' (see
-- 20260810020000_warehouse_partner_billing_harden.sql — that migration's
-- own comment explains exactly why a broad partner UPDATE policy is
-- dangerous: RLS can't restrict *which columns* a client changes, only
-- which *rows* are visible, so a raw UPDATE grant would let a partner
-- rewrite arbitrary columns on any row matching their prefix via a direct
-- REST call). Scan Out needs the same discipline, so it goes through a
-- SECURITY DEFINER RPC that only ever touches the pickup fields, instead
-- of a new RLS policy.
--
-- Looks up the caller's partner_accounts row itself (via auth.uid()) —
-- never trusts a client-supplied partner/tracking prefix — and scopes the
-- package lookup to that partner's own tracking_prefix, exactly matching
-- the existing getWarehouseEntriesByPrefix / "Partners read own prefix"
-- convention used everywhere else in the partner dashboard.
CREATE OR REPLACE FUNCTION scan_out_package(
  p_code TEXT,
  p_picked_up_by TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_partner partner_accounts%ROWTYPE;
  v_entry warehouse_entries%ROWTYPE;
  v_was_picked_up BOOLEAN;
  v_actor TEXT;
  v_code TEXT := TRIM(p_code);
BEGIN
  IF v_code IS NULL OR v_code = '' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'empty_code');
  END IF;

  SELECT * INTO v_partner FROM partner_accounts WHERE auth_user_id = auth.uid() LIMIT 1;
  IF v_partner.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_a_partner');
  END IF;
  IF v_partner.tracking_prefix IS NULL OR v_partner.tracking_prefix = '' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'no_tracking_prefix');
  END IF;

  v_actor := COALESCE(NULLIF(TRIM(p_picked_up_by), ''), v_partner.company_name, 'Courier');

  SELECT * INTO v_entry FROM warehouse_entries
   WHERE (UPPER(tracking_number) = UPPER(v_code) OR UPPER(barcode_value) = UPPER(v_code))
     AND tracking_number ILIKE v_partner.tracking_prefix || '%'
   ORDER BY scanned_in_at DESC
   LIMIT 1;

  IF v_entry.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_found');
  END IF;

  v_was_picked_up := v_entry.status = 'picked_up';

  IF NOT v_was_picked_up THEN
    UPDATE warehouse_entries
       SET status = 'picked_up',
           picked_up_at = now(),
           picked_up_by = v_actor,
           updated_at = now()
     WHERE id = v_entry.id
     RETURNING * INTO v_entry;

    -- Best-effort sync into the customer-facing packages table, mirroring
    -- the same tracking_number-keyed sync process-package-scan already
    -- does on the way in. No matching row (e.g. an Unknown Package that
    -- was never assigned to a customer) or a package already marked
    -- picked_up is left untouched — never an error, matching the "fine
    -- to ignore" precedent already established for this same link.
    UPDATE packages
       SET status = 'picked_up',
           picked_up_at = v_entry.picked_up_at,
           picked_up_by = v_actor,
           updated_at = now()
     WHERE tracking_number = v_entry.tracking_number
       AND status IS DISTINCT FROM 'picked_up';

    INSERT INTO package_scan_audit_log (
      warehouse_entry_id, action, performed_by, performed_by_name,
      old_value, new_value, notes
    ) VALUES (
      v_entry.id, 'package_picked_up', NULL, v_actor,
      jsonb_build_object('status', 'pre-pickup'),
      jsonb_build_object('status', 'picked_up', 'picked_up_by', v_actor),
      'Scanned out via courier dashboard (' || v_partner.company_name || ')'
    );
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'already_picked_up', v_was_picked_up,
    'entry', to_jsonb(v_entry)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION scan_out_package(TEXT, TEXT) TO authenticated;

COMMENT ON FUNCTION scan_out_package IS
  'Courier-facing scan-out: marks a warehouse_entries row (and its synced '
  'packages row, if any) picked_up. Scopes the lookup to the calling '
  'partner_accounts.tracking_prefix server-side — never trusts a '
  'client-supplied partner id. Idempotent: re-scanning an already '
  'picked-up package returns already_picked_up:true without rewriting it.';
