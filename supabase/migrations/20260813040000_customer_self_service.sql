-- Customer portal "Settings" was entirely decorative — every button
-- (Add/Edit/Delete address, Request account deletion) was a no-op. This
-- gives customers a real way to edit their own profile and to submit a
-- real, persisted account-deletion request.
--
-- "Customers update own row" (20260804000001_tenant_rls.sql) already lets
-- a customer UPDATE their own row, but with no column restriction at all
-- — nothing currently calls it (confirmed: no customer-facing code calls
-- updateCustomer today), but shipping a real "edit my profile" UI on top
-- of it would let a customer rewrite ANY column on their own row via a
-- direct REST call, including mailbox_number (their unique warehouse
-- forwarding ID — collide/impersonate another customer's) or partner_id
-- (jump to a different courier's tenant). Same class of problem the
-- warehouse_entries "harden" migration fixed earlier this session: RLS
-- can restrict which rows are visible, not which columns a client
-- changes. Fixed the same way — a narrow SECURITY DEFINER RPC that only
-- ever touches the fields it's named for, instead of a blanket grant.
DROP POLICY IF EXISTS "Customers update own row" ON customers;

ALTER TABLE customers ADD COLUMN IF NOT EXISTS deletion_requested_at TIMESTAMPTZ;

CREATE OR REPLACE FUNCTION update_own_customer_profile(
  p_name TEXT,
  p_phone TEXT,
  p_address TEXT
)
RETURNS SETOF customers
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  UPDATE customers
     SET name = NULLIF(TRIM(p_name), ''),
         phone = NULLIF(TRIM(p_phone), ''),
         address = NULLIF(TRIM(p_address), ''),
         updated_at = now()
   WHERE auth_user_id = auth.uid()
  RETURNING *;
END;
$$;

GRANT EXECUTE ON FUNCTION update_own_customer_profile(TEXT, TEXT, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION request_own_account_deletion()
RETURNS SETOF customers
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  UPDATE customers
     SET deletion_requested_at = now(),
         updated_at = now()
   WHERE auth_user_id = auth.uid()
  RETURNING *;
END;
$$;

GRANT EXECUTE ON FUNCTION request_own_account_deletion() TO authenticated;

COMMENT ON COLUMN customers.deletion_requested_at IS
  'Set when the customer submits "Request account deletion" from their '
  'own portal. Nothing auto-deletes on this — it is a request for staff '
  'to review and action, same as the button''s own copy always promised.';
