-- Loads notes into the sync tables.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2024-01-03
  
TRUNCATE TABLE note_comments_text;
SELECT /* Notes-processPlanet */ CURRENT_TIMESTAMP AS Processing,
 'Uploading text comments' AS Text;
COPY note_comments_text(note_id, body)
FROM '${OUTPUT_TEXT_COMMENTS_FILE}' csv;
SELECT /* Notes-processPlanet */ CURRENT_TIMESTAMP AS Processing,
 'Statistics on text comments' AS Text;
ANALYZE note_comments_text;
SELECT /* Notes-processPlanet */ CURRENT_TIMESTAMP AS Processing,
 'Counting text comments' AS Text;
SELECT /* Notes-processPlanet */ CURRENT_TIMESTAMP AS Processing,
 COUNT(1) AS Qty,
  'Uploaded text comments' AS Text
FROM note_comments_text;

DO /* Notes-processPlanet-assignSequence-text */
$$
DECLARE
  m_current_note_id INTEGER;
  m_previous_note_id INTEGER;
  m_sequence_value INTEGER;
  m_rec_note_comment_text RECORD;
  m_note_comments_text_cursor CURSOR  FOR
   SELECT
    note_id
   FROM note_comments_text
   ORDER BY note_id, id
   FOR UPDATE;

 BEGIN
  OPEN m_note_comments_text_cursor;

  LOOP
   FETCH m_note_comments_text_cursor INTO m_rec_note_comment_text;
   -- Exit when no more rows to fetch.
   EXIT WHEN NOT FOUND;

   m_current_note_id := m_rec_note_comment_text.note_id;
   IF (m_previous_note_id = m_current_note_id) THEN
    m_sequence_value := m_sequence_value + 1;
   ELSE
    m_sequence_value := 1;
    m_previous_note_id := m_current_note_id;
   END IF;

   UPDATE note_comments_text
    SET sequence_action = m_sequence_value
    WHERE CURRENT OF m_note_comments_text_cursor;
  END LOOP;

  CLOSE m_note_comments_text_cursor;

END
$$;

