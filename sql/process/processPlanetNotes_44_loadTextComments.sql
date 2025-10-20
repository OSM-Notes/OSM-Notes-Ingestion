-- Loads text comments into the sync tables.
-- Sequence numbers are already generated in AWK extraction
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-07-26

TRUNCATE TABLE note_comments_text;
SELECT /* Notes-processPlanet */ clock_timestamp() AS Processing,
 'Uploading text comments with sequence numbers from XSLT' AS Text;

-- Load text comments with sequence_action already provided by AWK
COPY note_comments_text(note_id, sequence_action, body)
FROM '${OUTPUT_TEXT_COMMENTS_FILE}' csv;

SELECT /* Notes-processPlanet */ clock_timestamp() AS Processing,
 'Statistics on text comments' AS Text;
ANALYZE note_comments_text;

SELECT /* Notes-processPlanet */ clock_timestamp() AS Processing,
 'Counting text comments' AS Text;
SELECT /* Notes-processPlanet */ clock_timestamp() AS Processing,
 COUNT(1) AS Qty,
  'Uploaded text comments with sequence numbers' AS Text
FROM note_comments_text;

SELECT /* Notes-processPlanet */ clock_timestamp() AS Processing,
 'Text comments loaded successfully with sequence numbers from XSLT' AS Text;

