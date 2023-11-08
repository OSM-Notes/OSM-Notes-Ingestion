-- Loads check notes.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-10-25
  
 TRUNCATE TABLE notes_check;
  SELECT CURRENT_TIMESTAMP AS Processing, 'Uploading check notes' AS Text;
  COPY notes_check (note_id, latitude, longitude, created_at, closed_at, status)
    FROM '${OUTPUT_NOTES_FILE}' csv;
  SELECT CURRENT_TIMESTAMP AS Processing, 'Statistics on notes check' as Text;
  ANALYZE notes_check;
  SELECT CURRENT_TIMESTAMP AS Processing, 'Counting check notes' AS Text;
  SELECT CURRENT_TIMESTAMP AS Processing, COUNT(1) AS Qty,
    'Uploaded check notes' AS Text FROM notes_check;

  TRUNCATE TABLE note_comments_check;
  SELECT CURRENT_TIMESTAMP AS Processing, 'Uploading check comments' AS Text;
  COPY note_comments_check FROM '${OUTPUT_NOTE_COMMENTS_FILE}' csv
    DELIMITER ',' QUOTE '''';
  SELECT CURRENT_TIMESTAMP AS Processing, 'Statistics on comments check' as Text;
  ANALYZE note_comments_check;
  SELECT CURRENT_TIMESTAMP AS Processing, 'Counting check comments' AS Text;
  SELECT CURRENT_TIMESTAMP AS Processing, COUNT(1) AS Qty,
    'Uploaded check comments' AS Text FROM note_comments_check;
