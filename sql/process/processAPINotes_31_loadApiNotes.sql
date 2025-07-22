-- Loads the notes and note comments on the API tables with parallel processing support.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-07-18

-- Get partition ID and MAX_THREADS from environment variables
DO $$
DECLARE
  part_id INTEGER;
  max_threads INTEGER;
BEGIN
  -- Get partition ID from environment variable, default to 1 if not set
  part_id := COALESCE(current_setting('app.part_id', true)::INTEGER, 1);
  
  -- Get MAX_THREADS from environment variable, default to 4 if not set
  max_threads := COALESCE(current_setting('app.max_threads', true)::INTEGER, 4);
  
  -- Validate partition ID
  IF part_id < 1 OR part_id > max_threads THEN
    RAISE EXCEPTION 'Invalid partition ID: %. Must be between 1 and %.', part_id, max_threads;
  END IF;
  
  -- Set partition ID for this session
  PERFORM set_config('app.part_id', part_id::TEXT, false);
END $$;

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 'Loading notes from API partition ' || current_setting('app.part_id', true) AS Text;

-- Load notes into specific partition
COPY notes_api (note_id, latitude, longitude, created_at, closed_at, status, part_id)
FROM '${OUTPUT_NOTES_PART}' csv;

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 'Statistics on notes from API partition ' || current_setting('app.part_id', true) AS Text;
ANALYZE notes_api;

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 'Counting notes from API partition ' || current_setting('app.part_id', true) AS Text;
SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 COUNT(1) AS Qty, 'Uploaded new notes partition ' || current_setting('app.part_id', true) AS Text
FROM notes_api WHERE part_id = current_setting('app.part_id', true)::INTEGER;

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 'Loading comments from API partition ' || current_setting('app.part_id', true) AS Text;

-- Load comments into specific partition
COPY note_comments_api (note_id, event, created_at, id_user, username, part_id)
FROM '${OUTPUT_COMMENTS_PART}' csv DELIMITER ',' QUOTE '''';

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 'Statistics on comments from API partition ' || current_setting('app.part_id', true) AS Text;
ANALYZE note_comments_api;

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 'Counting comments from API partition ' || current_setting('app.part_id', true) AS Text;
SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 COUNT(1) AS Qty, 'Uploaded new comments partition ' || current_setting('app.part_id', true) AS Text
FROM note_comments_api WHERE part_id = current_setting('app.part_id', true)::INTEGER;

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 'Loading text comments from API partition ' || current_setting('app.part_id', true) AS Text;

-- Load text comments into specific partition
COPY note_comments_text_api (note_id, sequence_action, body, part_id)
FROM '${OUTPUT_TEXT_PART}' csv DELIMITER ',' QUOTE '''';

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 'Statistics on text comments from API partition ' || current_setting('app.part_id', true) AS Text;
ANALYZE note_comments_text_api;

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 'Counting text comments from API partition ' || current_setting('app.part_id', true) AS Text;
SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 COUNT(1) AS Qty, 'Uploaded new text comments partition ' || current_setting('app.part_id', true) AS Text
FROM note_comments_text_api WHERE part_id = current_setting('app.part_id', true)::INTEGER;

-- Assign sequence values for comments in this partition
DO /* Notes-processPlanet-assignSequence-api */
$$
DECLARE
  m_current_note_id INTEGER;
  m_previous_note_id INTEGER;
  m_sequence_value INTEGER;
  m_rec_note_comment_api RECORD;
  m_part_id INTEGER;
  m_note_comments_api_cursor CURSOR FOR
   SELECT /* Notes-processAPI */ note_id
   FROM note_comments_api
   WHERE part_id = current_setting('app.part_id', true)::INTEGER
   ORDER BY note_id, id
   FOR UPDATE;

 BEGIN
  m_part_id := current_setting('app.part_id', true)::INTEGER;
  
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
