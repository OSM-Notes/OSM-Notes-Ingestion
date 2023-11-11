-- Loads the notes and note comments on the API tables.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-10-25
  
SELECT CURRENT_TIMESTAMP AS Processing, 'Loading notes from API' as Text;
COPY notes_api (note_id, latitude, longitude, created_at, closed_at, status)
  FROM '${OUTPUT_NOTES_FILE}' csv;
SELECT CURRENT_TIMESTAMP AS Processing,
 'Statistics on notes from API' as Text;
ANALYZE notes_api;
SELECT CURRENT_TIMESTAMP AS Processing, 'Counting notes from API' as Text;
SELECT CURRENT_TIMESTAMP AS Processing, COUNT(1) AS Qty,
 'Uploaded new notes' as Text
FROM notes_api;

SELECT CURRENT_TIMESTAMP AS Processing, 'Loading comments from API' as Text;
COPY note_comments_api (note_id, event, processing_time, created_at, id_user)
  FROM '${OUTPUT_NOTE_COMMENTS_FILE}' csv DELIMITER ',' QUOTE '''';
SELECT CURRENT_TIMESTAMP AS Processing,
 'Statistics on comments from API' as Text;
ANALYZE note_comments_api;
SELECT CURRENT_TIMESTAMP AS Processing, 'Counting comments from API' as Text;
SELECT CURRENT_TIMESTAMP AS Processing, COUNT(1) AS Qty,
 'Uploaded new comments' as Text
FROM note_comments_api;