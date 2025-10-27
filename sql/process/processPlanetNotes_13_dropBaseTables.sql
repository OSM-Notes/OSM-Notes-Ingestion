-- Drop base tables.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-10-27

-- Set statement timeout to 30 seconds for DROP operations
SET statement_timeout = '30s';

DROP TRIGGER IF EXISTS update_note ON note_comments;
DROP FUNCTION IF EXISTS update_note CASCADE;
DROP TRIGGER IF EXISTS log_insert_note ON notes;
DROP FUNCTION IF EXISTS log_insert_note CASCADE;
DROP PROCEDURE IF EXISTS remove_lock CASCADE;
DROP PROCEDURE IF EXISTS put_lock CASCADE;
DROP TABLE IF EXISTS properties CASCADE;
DROP TABLE IF EXISTS logs CASCADE;
DROP TABLE IF EXISTS note_comments_text CASCADE;
DROP TABLE IF EXISTS note_comments CASCADE;
DROP TABLE IF EXISTS notes CASCADE;
DROP TABLE IF EXISTS users CASCADE;

DROP TYPE IF EXISTS note_event_enum CASCADE;
DROP TYPE IF EXISTS note_status_enum CASCADE;

-- Reset statement timeout
SET statement_timeout = DEFAULT;
