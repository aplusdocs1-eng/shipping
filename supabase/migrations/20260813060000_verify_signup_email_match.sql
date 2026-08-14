-- Closes the identity-spoofing gap found during the auth audit
-- (20260813050000_auth_security_audit.sql) but deliberately left unfixed
-- at the time: create_partner_account / create_customer_account are
-- SECURITY DEFINER, granted to `anon`, and took p_auth_user_id from the
-- caller with zero verification it was actually theirs.
--
-- Why not `auth.uid() = p_auth_user_id`: this project has
-- mailer_autoconfirm OFF (confirmed live via GET /auth/v1/settings), so a
-- brand-new signUp() has no session yet — the very next call these RPCs
-- make legitimately runs as `anon` with auth.uid() = NULL. A strict
-- auth.uid() check would reject every real signup, not just spoofed ones.
--
-- Instead: require p_auth_user_id to belong to a real auth.users row
-- whose email matches p_email. This is a zero-cost invariant for the
-- legitimate flow (p_email is always the address signUp() was just
-- called with, for that exact user), while forcing a spoofing attempt to
-- already know both the victim's auth UUID *and* their exact registered
-- email — closing the "just guess/leak a UUID" version of the attack.
-- (auth_user_id is already UNIQUE on both tables, so a second claim
-- against an already-linked identity was already rejected before this.)

CREATE OR REPLACE FUNCTION create_partner_account(
  p_auth_user_id UUID,
  p_company_name TEXT,
  p_contact_name TEXT,
  p_email TEXT,
  p_phone TEXT,
  p_tracking_prefix TEXT,
  p_domain TEXT DEFAULT NULL,
  p_plan TEXT DEFAULT NULL
)
RETURNS SETOF partner_accounts
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_shipping_partner_id UUID;
  v_code TEXT;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = p_auth_user_id AND lower(u.email) = lower(p_email)
  ) THEN
    RAISE EXCEPTION 'p_auth_user_id does not match a user with this email';
  END IF;

  v_code := LEFT(p_tracking_prefix, 3);

  INSERT INTO shipping_partners (code, name, region, tracking_prefix, contact_email, is_active)
  VALUES (v_code, p_company_name, '', p_tracking_prefix, p_email, true)
  ON CONFLICT (code) DO NOTHING
  RETURNING id INTO v_shipping_partner_id;

  RETURN QUERY
  INSERT INTO partner_accounts (
    auth_user_id, company_name, contact_name, email, phone,
    tracking_prefix, domain, plan, partner_id, status
  )
  VALUES (
    p_auth_user_id, p_company_name, p_contact_name, p_email,
    NULLIF(p_phone, ''), p_tracking_prefix,
    NULLIF(LOWER(TRIM(p_domain)), ''), p_plan, v_shipping_partner_id,
    'approved'
  )
  RETURNING *;
END;
$$;

CREATE OR REPLACE FUNCTION create_customer_account(
  p_auth_user_id UUID,
  p_partner_id UUID,
  p_name TEXT,
  p_email TEXT,
  p_phone TEXT DEFAULT NULL
)
RETURNS SETOF customers
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = p_auth_user_id AND lower(u.email) = lower(p_email)
  ) THEN
    RAISE EXCEPTION 'p_auth_user_id does not match a user with this email';
  END IF;

  RETURN QUERY
  INSERT INTO customers (auth_user_id, partner_id, name, email, phone, status)
  VALUES (p_auth_user_id, p_partner_id, p_name, p_email, NULLIF(p_phone, ''), 'active')
  RETURNING *;
END;
$$;
