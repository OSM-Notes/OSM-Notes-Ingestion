-- Loads the notes and note comments on the API tables.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-10-25
  
  SELECT CURRENT_TIMESTAMP, 'Loading notes from API' as text;
  COPY notes_api (note_id, latitude, longitude, created_at, closed_at, status)
    FROM '${OUTPUT_NOTES_FILE}' csv;
  SELECT CURRENT_TIMESTAMP, 'Statistics on notes from API' as text;
  ANALYZE notes_api;
  SELECT CURRENT_TIMESTAMP, 'Counting notes from API' as text;
  SELECT CURRENT_TIMESTAMP, COUNT(1), 'uploaded new notes' as type
  FROM notes_api;

  SELECT CURRENT_TIMESTAMP, 'Loading comments from API' as text;
  COPY note_comments_api FROM '${OUTPUT_NOTE_COMMENTS_FILE}' csv
    DELIMITER ',' QUOTE '''';
  SELECT CURRENT_TIMESTAMP, 'Statistics on comments from API' as text;
  ANALYZE note_comments_api;
  SELECT CURRENT_TIMESTAMP, 'Counting comments from API' as text;
  SELECT CURRENT_TIMESTAMP, COUNT(1), 'uploaded new comments' as type
  FROM note_comments_api;
