DROP TRIGGER update_notes ON notes;
DROP TRIGGER insert_new_notes ON notes;
DROP FUNCTION wms.update_notes();
DROP FUNCTION wms.insert_new_notes();
DROP INDEX notes_closed;
DROP INDEX notes_open;
DROP TABLE wms.notes_wms
DROP SCHEMA wms;
