-- Insert new text comments.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2024-01-08


DO /* Notes-processApi-assignSequence-text */
$$
DECLARE
  m_current_note_id INTEGER;
  m_previous_note_id INTEGER;
  m_sequence_value INTEGER;
  m_rec_note_comment_text RECORD;
  m_note_comments_text_api_cursor CURSOR  FOR
   SELECT /* Notes-processAPI */ note_id
   FROM note_comments_text_api
   ORDER BY note_id, id
   FOR UPDATE;

 BEGIN
  OPEN m_note_comments_text_api_cursor;

  LOOP
   FETCH m_note_comments_text_api_cursor INTO m_rec_note_comment_text;
   -- Exit when no more rows to fetch.
   EXIT WHEN NOT FOUND;

   m_current_note_id := m_rec_note_comment_text.note_id;
   --RAISE NOTICE 'Old Values %-%: %.', m_previous_note_id, m_current_note_id,
   -- m_sequence_value;
   IF (m_previous_note_id = m_current_note_id) THEN
    m_sequence_value := m_sequence_value + 1;
   ELSE
    m_sequence_value := 1;
    m_previous_note_id := m_current_note_id;
   END IF;

   --RAISE NOTICE 'New values %-%: %.', m_previous_note_id, m_current_note_id,
   -- m_sequence_value;
   UPDATE note_comments_text_api
    SET sequence_action = m_sequence_value
    WHERE CURRENT OF m_note_comments_text_api_cursor;
  END LOOP;
  RAISE NOTICE 'End loop.';

  CLOSE m_note_comments_text_api_cursor;
END
$$;
SELECT /* Notes-processAPI */ CURRENT_TIMESTAMP AS Processing,
 'Sequence values assigned' AS Text;

INSERT INTO note_comments_text (note_id, sequence_action, body)
 SELECT /* Notes-processAPI */ note_id, sequence_action, body FROM note_comments_text_api
 ON CONFLICT DO NOTHING;