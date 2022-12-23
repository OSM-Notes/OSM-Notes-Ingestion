DROP TRIGGER IF EXISTS update_notes ON notes;
DROP TRIGGER IF EXISTS insert_new_notes ON notes;
DROP FUNCTION IF EXISTS wms.update_notes();
DROP FUNCTION IF EXISTS wms.insert_new_notes();
DROP INDEX IF EXISTS wms.notes_closed;
DROP INDEX IF EXISTS wms.notes_open;
DROP INDEX IF EXISTS wms.notes_id;
DROP TABLE IF EXISTS wms.notes_wms;
DROP SCHEMA IF EXISTS wms;
