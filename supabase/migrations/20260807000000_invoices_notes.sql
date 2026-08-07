-- The "Bill Partner" dialog collects an optional notes field but the
-- invoices table never had a column for it, so every partner-invoice
-- creation failed with PGRST204 (Could not find the 'notes' column).
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS notes TEXT;
