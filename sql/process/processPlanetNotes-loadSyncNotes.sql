-- Loads notes into the sync tables.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-10-25
  
TRUNCATE TABLE notes_sync;
SELECT CURRENT_TIMESTAMP AS Processing, 'Uploading sync notes' AS Text;
COPY notes_sync (note_id, latitude, longitude, created_at, closed_at, status)
  FROM '${OUTPUT_NOTES_FILE}' csv;
SELECT CURRENT_TIMESTAMP AS Processing, 'Statistics on notes sync' as Text;
ANALYZE notes_sync;
SELECT CURRENT_TIMESTAMP AS Processing, 'Counting sync notes' AS Text;
SELECT CURRENT_TIMESTAMP AS Processing, COUNT(1) AS Qty,
  'Uploaded sync notes' AS Text FROM notes_sync;

TRUNCATE TABLE note_comments_sync;
SELECT CURRENT_TIMESTAMP AS Processing, 'Uploading sync comments' AS Text;
COPY note_comments_sync(note_id, event, created_at, id_user, username)
  FROM '${OUTPUT_NOTE_COMMENTS_FILE}' csv;
SELECT CURRENT_TIMESTAMP AS Processing, 'Statistics on comments sync' as Text;
ANALYZE note_comments_sync;
SELECT CURRENT_TIMESTAMP AS Processing, 'Counting sync comments' AS Text;
SELECT CURRENT_TIMESTAMP AS Processing, COUNT(1) AS Qty,
  'Uploaded sync comments' AS Text FROM note_comments_sync;
