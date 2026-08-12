-- The warehouse "Assign Location" dialog pre-filled its dropdown with the
-- synthetic StorageLocation that WarehouseEntry.fromMap reconstructs from
-- the single warehouse_entries.storage_location TEXT column (whole raw
-- text in .shelf, .slot always ''). Re-opening the dialog for an
-- already-stored entry and saving without changing the selection wrote
-- '${shelf}-${slot}' using that synthetic shelf (which is already the
-- combined "shelf-bin" text), joining it a second time — e.g.
-- "1-1" -> "1-1-". Fixed in application code (warehouse_screen.dart now
-- resolves the real storage_locations row instead of reusing the
-- synthetic one). This is the one-time cleanup for rows it already
-- corrupted in production, so their location text matches
-- storage_locations again instead of silently no longer matching any real
-- location (which let another entry double-book the same physical slot).
UPDATE warehouse_entries
SET storage_location = regexp_replace(storage_location, '-+$', '')
WHERE storage_location ~ '-$';
