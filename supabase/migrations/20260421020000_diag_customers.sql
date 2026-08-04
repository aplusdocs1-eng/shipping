-- Diagnostic: print customer + partner_accounts counts/details via NOTICE.
DO $$
DECLARE
  r RECORD;
  cust_count INT;
  partner_count INT;
BEGIN
  SELECT COUNT(*) INTO cust_count FROM customers;
  SELECT COUNT(*) INTO partner_count FROM partner_accounts;
  RAISE NOTICE 'Customer count: %', cust_count;
  RAISE NOTICE 'Partner count: %', partner_count;

  FOR r IN SELECT id, company_name, tracking_prefix, status FROM partner_accounts LOOP
    RAISE NOTICE 'Partner: % | prefix=% | status=% | id=%',
      r.company_name, r.tracking_prefix, r.status, r.id;
  END LOOP;

  FOR r IN SELECT id, name, email, mailbox_number, partner_id, status FROM customers ORDER BY created_at DESC LIMIT 20 LOOP
    RAISE NOTICE 'Customer: % | email=% | mailbox=% | partner_id=% | status=%',
      r.name, r.email, r.mailbox_number, r.partner_id, r.status;
  END LOOP;
END $$;
