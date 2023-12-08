-- Loads the notes and note comments on the API tables.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-12-08
  
SELECT /* Notes-processAPI */ CURRENT_TIMESTAMP AS Processing,
 'Loading notes from API' AS Text;
COPY notes_api (note_id, latitude, longitude, created_at, closed_at, status)
FROM '${OUTPUT_NOTES_FILE}' csv;
SELECT /* Notes-processAPI */ CURRENT_TIMESTAMP AS Processing,
 'Statistics on notes from API' AS Text;
ANALYZE notes_api;
SELECT /* Notes-processAPI */ CURRENT_TIMESTAMP AS Processing,
 'Counting notes from API' AS Text;
SELECT /* Notes-processAPI */ CURRENT_TIMESTAMP AS Processing,
 COUNT(1) AS Qty, 'Uploaded new notes' AS Text
FROM notes_api;

SELECT /* Notes-processAPI */ CURRENT_TIMESTAMP AS Processing,
 'Loading comments from API' AS Text;
COPY note_comments_api (note_id, event, created_at, id_user, username)
FROM '${OUTPUT_NOTE_COMMENTS_FILE}' csv DELIMITER ',' QUOTE '''';
SELECT /* Notes-processAPI */ CURRENT_TIMESTAMP AS Processing,
 'Statistics on comments from API' AS Text;
ANALYZE note_comments_api;
SELECT /* Notes-processAPI */ CURRENT_TIMESTAMP AS Processing,
 'Counting comments from API' AS Text;
SELECT /* Notes-processAPI */ CURRENT_TIMESTAMP AS Processing,
 COUNT(1) AS Qty, 'Uploaded new comments' AS Text
FROM note_comments_api;
