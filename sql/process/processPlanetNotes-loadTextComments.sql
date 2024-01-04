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

ALTER TABLE note_comments_text ALTER COLUMN sequence_action SET NOT NULL;

CREATE UNIQUE INDEX sequence_note_comment_text
 ON note_comments_text
 (note_id, sequence_action);
COMMENT ON INDEX sequence_note_comment_text IS 'Sequence of comments creation';
ALTER TABLE note_comments_text
 ADD CONSTRAINT unique_comment_note_text
 UNIQUE USING INDEX sequence_note_comment_text;

ALTER TABLE note_comments_text
 ADD CONSTRAINT fk_note_comment_uniq
 FOREIGN KEY (note_id, sequence_action)
 REFERENCES note_comments (note_id, sequence_action);

CREATE OR REPLACE FUNCTION put_seq_on_comment_text()
  RETURNS TRIGGER AS
 $$
 DECLARE
  max_value INTEGER;
 BEGIN
   SELECT MAX(sequence_action)
    INTO max_value
   FROM note_comments_text
   WHERE note_id = NEW.note_id;
   IF (max_value IS NULL) THEN
    max_value := 1;
   ELSE
    max_value := max_value + 1;
   END IF;
   NEW.sequence_action := max_value;

   RETURN NEW;
 END;
 $$ LANGUAGE plpgsql
;
COMMENT ON FUNCTION put_seq_on_comment_text IS
  'Assigns the sequence value for the comments on the same note';

CREATE OR REPLACE TRIGGER put_seq_on_comment_text_trigger
  BEFORE INSERT ON note_comments_text
  FOR EACH ROW
  EXECUTE FUNCTION put_seq_on_comment_text()
;
COMMENT ON TRIGGER put_seq_on_comment_text_trigger ON note_comments_text IS
  'Trigger to assign the sequence value';
