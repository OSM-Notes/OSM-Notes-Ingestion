-- Drop base tables.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-10-25

DROP FUNCTION IF EXISTS get_country;
DROP PROCEDURE IF EXISTS insert_note_comment;
DROP PROCEDURE IF EXISTS insert_note;
DROP TABLE IF EXISTS note_comments_check;
DROP TABLE IF EXISTS notes_check;
DROP TABLE IF EXISTS note_comments_text;
DROP TABLE IF EXISTS note_comments;
DROP TABLE IF EXISTS notes;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS logs;
DROP TYPE note_event_enum;
DROP TYPE note_status_enum;
