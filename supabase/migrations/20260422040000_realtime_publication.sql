-- Enable Supabase Realtime for tables used in partner dashboard and customer portal.
-- Idempotent: skip tables that are already members of supabase_realtime.
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['packages', 'invoices', 'pre_alerts'] LOOP
    IF NOT EXISTS (
      SELECT 1
      FROM   pg_publication_tables
      WHERE  pubname    = 'supabase_realtime'
      AND    schemaname = 'public'
      AND    tablename  = t
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    END IF;
  END LOOP;
END $$;
