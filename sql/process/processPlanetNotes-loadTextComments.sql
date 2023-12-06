-- Loads notes into the sync tables.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-12-06
  
TRUNCATE TABLE note_comments_text;
SELECT CURRENT_TIMESTAMP AS Processing, 'Uploading text comments' AS Text;
COPY note_comments_text(note_id, body)
  FROM '${OUTPUT_TEXT_COMMENTS_FILE}' csv;
SELECT CURRENT_TIMESTAMP AS Processing, 'Statistics on text comments' as Text;
ANALYZE note_comments_text;
SELECT CURRENT_TIMESTAMP AS Processing, 'Counting text comments' AS Text;
SELECT CURRENT_TIMESTAMP AS Processing, COUNT(1) AS Qty,
  'Uploaded text comments' AS Text FROM note_comments_text;
