-- Branch.fromMap reads city, but no such column exists, and the
-- "Add Branch" dialog collects a City field that was being silently
-- discarded on submit.
ALTER TABLE branches ADD COLUMN IF NOT EXISTS city TEXT NOT NULL DEFAULT '';
