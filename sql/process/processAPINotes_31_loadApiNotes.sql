-- Loads the notes and note comments on the API tables
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-12-12

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 'Loading notes from API' AS Text;

-- Load notes (simplified, no partition handling)
-- Standardized order: note_id, latitude, longitude, created_at, status, closed_at, id_country
COPY notes_api (note_id, latitude, longitude, created_at, status, closed_at, id_country)
FROM '${OUTPUT_NOTES_PART}' csv;

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 'Statistics on notes from API' AS Text;
ANALYZE notes_api;

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 'Counting notes from API' AS Text;
SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 COUNT(1) AS Qty, 'Uploaded new notes' AS Text
FROM notes_api;

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 'Loading comments from API' AS Text;

-- Load comments (sequence_action already provided by AWK)
COPY note_comments_api (note_id, sequence_action, event, created_at, id_user, username)
FROM '${OUTPUT_COMMENTS_PART}' csv DELIMITER ',' QUOTE '"';

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 'Statistics on comments from API' AS Text;
ANALYZE note_comments_api;

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 'Counting comments from API' AS Text;
SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 COUNT(1) AS Qty, 'Uploaded new comments' AS Text
FROM note_comments_api;

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 'Loading text comments from API' AS Text;

-- Load text comments (sequence_action already provided by AWK)
COPY note_comments_text_api (note_id, sequence_action, body)
FROM '${OUTPUT_TEXT_PART}' csv DELIMITER ',' QUOTE '"';

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 'Statistics on text comments from API' AS Text;
ANALYZE note_comments_text_api;

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 'Counting text comments from API' AS Text;
SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 COUNT(1) AS Qty, 'Uploaded new text comments' AS Text
FROM note_comments_text_api;
