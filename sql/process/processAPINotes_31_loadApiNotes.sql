-- Loads the notes and note comments on the API tables with parallel processing support.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-07-18

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 'Loading notes from API' AS Text;
COPY notes_api (note_id, latitude, longitude, created_at, closed_at, status)
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
COPY note_comments_api (note_id, event, created_at, id_user, username)
FROM '${OUTPUT_COMMENTS_PART}' csv DELIMITER ',' QUOTE '''';
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
COPY note_comments_text_api (note_id, body)
FROM '${OUTPUT_TEXT_PART}' csv DELIMITER ',' QUOTE '''';
SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 'Statistics on text comments from API' AS Text;
ANALYZE note_comments_text_api;
SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 'Counting text comments from API' AS Text;
SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 COUNT(1) AS Qty, 'Uploaded new text comments' AS Text
FROM note_comments_text_api;

DO /* Notes-processPlanet-assignSequence-api */
$$
DECLARE
  m_current_note_id INTEGER;
  m_previous_note_id INTEGER;
  m_sequence_value INTEGER;
  m_rec_note_comment_api RECORD;
  m_note_comments_api_cursor CURSOR FOR
   SELECT /* Notes-processAPI */ note_id
   FROM note_comments_api
   ORDER BY note_id, id
   FOR UPDATE;

 BEGIN
  OPEN m_note_comments_api_cursor;

  LOOP
   FETCH m_note_comments_api_cursor INTO m_rec_note_comment_api;
   -- Exit when no more rows to fetch.
   EXIT WHEN NOT FOUND;

   m_current_note_id := m_rec_note_comment_api.note_id;
   IF (m_previous_note_id = m_current_note_id) THEN
    m_sequence_value := m_sequence_value + 1;
   ELSE
    m_sequence_value := 1;
    m_previous_note_id := m_current_note_id;
   END IF;

   UPDATE note_comments_api
    SET sequence_action = m_sequence_value
    WHERE CURRENT OF m_note_comments_api_cursor;
  END LOOP;

  CLOSE m_note_comments_api_cursor;

END
$$;
