-- Real backend for the "API for 3rd Party Vendors" section on the admin
-- Settings screen. Previously that UI showed a fake base URL and a
-- client-side-only key that reset on page reload and authenticated
-- nothing. This gives it an actual key store, webhook subscriptions, and
-- (via pg_net) real webhook delivery on package creation.

CREATE TABLE IF NOT EXISTS vendor_api_keys (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key TEXT UNIQUE NOT NULL,
  sandbox BOOLEAN NOT NULL DEFAULT false,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE vendor_api_keys ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins manage vendor api keys" ON vendor_api_keys
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM admin_users WHERE auth_user_id = auth.uid() AND is_active))
  WITH CHECK (EXISTS (SELECT 1 FROM admin_users WHERE auth_user_id = auth.uid() AND is_active));

CREATE TRIGGER set_updated_at BEFORE UPDATE ON vendor_api_keys
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TABLE IF NOT EXISTS vendor_webhooks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  url TEXT NOT NULL,
  event TEXT NOT NULL DEFAULT 'package.created',
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE vendor_webhooks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins manage vendor webhooks" ON vendor_webhooks
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM admin_users WHERE auth_user_id = auth.uid() AND is_active))
  WITH CHECK (EXISTS (SELECT 1 FROM admin_users WHERE auth_user_id = auth.uid() AND is_active));

-- Real webhook delivery: fire registered "package.created" webhooks
-- whenever a package row is inserted, regardless of whether it came in
-- through the app or the vendor API itself. pg_net manages its own "net"
-- schema regardless of where the extension itself is registered.
CREATE EXTENSION IF NOT EXISTS pg_net;

CREATE OR REPLACE FUNCTION notify_package_webhooks()
RETURNS TRIGGER AS $$
DECLARE
  hook RECORD;
  payload JSONB;
BEGIN
  payload := jsonb_build_object(
    'event', 'package.created',
    'data', jsonb_build_object(
      'id', NEW.id,
      'tracking_number', NEW.tracking_number,
      'customer_name', NEW.customer_name,
      'status', NEW.status,
      'origin', NEW.origin,
      'destination', NEW.destination,
      'weight', NEW.weight,
      'declared_value', NEW.declared_value,
      'created_at', NEW.created_at
    )
  );
  FOR hook IN
    SELECT url FROM vendor_webhooks WHERE event = 'package.created' AND is_active
  LOOP
    PERFORM net.http_post(
      url := hook.url,
      body := payload,
      headers := '{"Content-Type": "application/json"}'::jsonb
    );
  END LOOP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, net;

DROP TRIGGER IF EXISTS package_webhook_trigger ON packages;
CREATE TRIGGER package_webhook_trigger
  AFTER INSERT ON packages
  FOR EACH ROW EXECUTE FUNCTION notify_package_webhooks();
