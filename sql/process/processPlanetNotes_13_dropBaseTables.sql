-- Drop base tables.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-08-13

DROP TRIGGER IF EXISTS update_note ON note_comments;
DROP FUNCTION IF EXISTS update_note;
DROP TRIGGER IF EXISTS log_insert_note ON notes;
DROP FUNCTION IF EXISTS log_insert_note;
DROP PROCEDURE IF EXISTS remove_lock;
DROP PROCEDURE IF EXISTS put_lock;
DROP TABLE IF EXISTS properties;
DROP TABLE IF EXISTS logs;
DROP TABLE IF EXISTS note_comments_text;
DROP TABLE IF EXISTS note_comments;
DROP TABLE IF EXISTS notes;
DROP TABLE IF EXISTS users;

DROP TYPE IF EXISTS note_event_enum CASCADE;
DROP TYPE IF EXISTS note_status_enum CASCADE;
