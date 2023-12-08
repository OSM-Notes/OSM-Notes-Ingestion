-- Loads check notes.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-12-08
  
TRUNCATE TABLE notes_check;
SELECT /* Notes-check */ CURRENT_TIMESTAMP AS Processing,
 'Uploading check notes' AS Text;
COPY notes_check (note_id, latitude, longitude, created_at, closed_at,
 status)
FROM '${OUTPUT_NOTES_FILE}' csv;
SELECT /* Notes-check */ CURRENT_TIMESTAMP AS Processing,
 'Statistics on notes check' AS Text;
ANALYZE notes_check;
SELECT /* Notes-check */ CURRENT_TIMESTAMP AS Processing,
 'Counting check notes' AS Text;
SELECT /* Notes-check */ CURRENT_TIMESTAMP AS Processing,
 COUNT(1) AS Qty, 'Uploaded check notes' AS Text
FROM notes_check;

TRUNCATE TABLE note_comments_check;
SELECT /* Notes-check */ CURRENT_TIMESTAMP AS Processing,
 'Uploading check comments' AS Text;
COPY note_comments_check
FROM '${OUTPUT_NOTE_COMMENTS_FILE}' csv;
SELECT /* Notes-check */ CURRENT_TIMESTAMP AS Processing,
 'Statistics on comments check' AS Text;
ANALYZE note_comments_check;
SELECT /* Notes-check */ CURRENT_TIMESTAMP AS Processing,
 'Counting check comments' AS Text;
SELECT /* Notes-check */ CURRENT_TIMESTAMP AS Processing,
 COUNT(1) AS Qty, 'Uploaded check comments' AS Text
FROM note_comments_check;
