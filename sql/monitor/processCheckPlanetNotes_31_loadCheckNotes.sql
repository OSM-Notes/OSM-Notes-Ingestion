-- Loads check notes into the check tables.
-- Sequence numbers are already generated in AWK extraction
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-10-19

TRUNCATE TABLE notes_check;
SELECT /* Notes-check */ clock_timestamp() AS Processing,
 'Uploading check notes' AS Text;
COPY notes_check (note_id, latitude, longitude, created_at, status, closed_at)
FROM '${OUTPUT_NOTES_FILE}' csv;
SELECT /* Notes-check */ clock_timestamp() AS Processing,
 'Statistics on check notes' AS Text;
ANALYZE notes_check;
SELECT /* Notes-check */ clock_timestamp() AS Processing,
 'Counting check notes' AS Text;
SELECT /* Notes-check */ clock_timestamp() AS Processing,
 COUNT(1) AS Qty, 'Uploaded check notes' AS Text
FROM notes_check;

TRUNCATE TABLE note_comments_check;
SELECT /* Notes-check */ clock_timestamp() AS Processing,
 'Uploading check comments with sequence numbers from XSLT' AS Text;

-- Load comments with sequence_action already provided by AWK
COPY note_comments_check (note_id, sequence_action, event, created_at, id_user, username)
FROM '${OUTPUT_COMMENTS_FILE}' csv;

SELECT /* Notes-check */ clock_timestamp() AS Processing,
 'Statistics on check comments' AS Text;
ANALYZE note_comments_check;
SELECT /* Notes-check */ clock_timestamp() AS Processing,
 'Counting check comments' AS Text;
SELECT /* Notes-check */ clock_timestamp() AS Processing,
 COUNT(1) AS Qty, 'Uploaded check comments' AS Text
FROM note_comments_check;

TRUNCATE TABLE note_comments_text_check;
SELECT /* Notes-check */ clock_timestamp() AS Processing,
 'Uploading check text comments with sequence numbers from XSLT' AS Text;

-- Load text comments with sequence_action already provided by AWK
COPY note_comments_text_check (note_id, sequence_action, body)
FROM '${OUTPUT_TEXT_COMMENTS_FILE}' csv;

SELECT /* Notes-check */ clock_timestamp() AS Processing,
 'Statistics on text comments check' AS Text;
ANALYZE note_comments_text_check;
SELECT /* Notes-check */ clock_timestamp() AS Processing,
 'Counting check text comments' AS Text;
SELECT /* Notes-check */ clock_timestamp() AS Processing,
 COUNT(1) AS Qty, 'Uploaded check text comments' AS Text
FROM note_comments_text_check;

SELECT /* Notes-check */ clock_timestamp() AS Processing,
 'Check data loaded successfully with sequence numbers from XSLT' AS Text;
