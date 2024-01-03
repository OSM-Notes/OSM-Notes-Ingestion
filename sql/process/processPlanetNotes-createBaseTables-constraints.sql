-- Create constraints in base tables.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2024-01-02
  
ALTER TABLE users
 ADD CONSTRAINT pk_users
 PRIMARY KEY (user_id);

ALTER TABLE notes
 ADD CONSTRAINT pk_notes
 PRIMARY KEY (note_id);

-- The API does not provide an identifier for the comments, therefore, this
-- project implemented another column for the id. However, the execution cannot
-- be parallelized. With the sequence, the order the comments were inserted can
-- identified.
ALTER TABLE note_comments
 ADD CONSTRAINT pk_note_comments
 PRIMARY KEY (id);

ALTER TABLE note_comments_text
 ADD CONSTRAINT pk_text_comments
 PRIMARY KEY (id);

CREATE UNIQUE INDEX sequence_note_comment
 ON note_comments
 (note_id, sequence_action);
COMMENT ON INDEX sequence_note_comment IS 'Sequence of comments creation';
ALTER TABLE note_comments
 ADD CONSTRAINT unique_comment_note
 UNIQUE USING INDEX sequence_note_comment;

CREATE UNIQUE INDEX sequence_note_comment_text
 ON note_comments_text
 (note_id, sequence_action);
COMMENT ON INDEX sequence_note_comment_text IS 'Sequence of comments creation';
ALTER TABLE note_comments_text
 ADD CONSTRAINT unique_comment_note_text
 UNIQUE USING INDEX sequence_note_comment_text;

ALTER TABLE note_comments
 ADD CONSTRAINT fk_notes
 FOREIGN KEY (note_id)
 REFERENCES notes (note_id);

ALTER TABLE note_comments
 ADD CONSTRAINT fk_users
 FOREIGN KEY (id_user)
 REFERENCES users (user_id);

--ALTER TABLE note_comments_text
-- ADD CONSTRAINT fk_note_comment
-- FOREIGN KEY (id)
-- REFERENCES note_comments (id);

ALTER TABLE note_comments_text
 ADD CONSTRAINT fk_note_comment
 FOREIGN KEY (note_id, sequence_action)
 REFERENCES note_comments (note_id, sequence_action);

CREATE INDEX IF NOT EXISTS usernames ON users (username);
COMMENT ON INDEX usernames IS 'To query by username';

CREATE INDEX IF NOT EXISTS notes_closed ON notes (closed_at);
COMMENT ON INDEX notes_closed IS 'To query by closed time';
CREATE INDEX IF NOT EXISTS notes_created ON notes (created_at);
COMMENT ON INDEX notes_created IS 'To query by opening time';
CREATE INDEX IF NOT EXISTS notes_countries ON notes (id_country);
COMMENT ON INDEX notes_countries IS 'To query by location of the note';

CREATE INDEX IF NOT EXISTS note_comments_id ON note_comments (note_id);
COMMENT ON INDEX note_comments_id IS 'To query by the associated note';
CREATE INDEX IF NOT EXISTS note_comments_users ON note_comments (id_user);
COMMENT ON INDEX note_comments_users IS
  'To query by the user who perfomed the action';
CREATE INDEX IF NOT EXISTS note_comments_created ON note_comments (created_at);
COMMENT ON INDEX note_comments_created IS 'To query by the time of the action';
CREATE INDEX IF NOT EXISTS note_comments_id_event ON note_comments (note_id, event);
COMMENT ON INDEX note_comments_id_event IS 'To query by the id and event';
CREATE INDEX IF NOT EXISTS note_comments_id_created ON note_comments (note_id, created_at);
COMMENT ON INDEX note_comments_id_created IS 'To query by the id and creation time';

CREATE INDEX IF NOT EXISTS note_comments_id_text ON note_comments_text (note_id);
COMMENT ON INDEX note_comments_id_text IS 'To query by the note id';

CREATE OR REPLACE FUNCTION put_seq_on_comment()
  RETURNS TRIGGER AS
 $$
 DECLARE
  max_value INTEGER;
 BEGIN
   SELECT MAX(sequence_action)
    INTO max_value
   FROM note_comments
   WHERE note_id = NEW.note_id;
   IF (max_value IS NULL) THEN
    max_value := 1;
   ELSE
    max_value := max_value + 1;
   END IF;
   NEW.seq := max_value;

   RETURN NEW;
 END;
 $$ LANGUAGE plpgsql
;
COMMENT ON FUNCTION put_seq_on_comment IS
  'Assigns the sequence value for the comments on the same note';

CREATE OR REPLACE TRIGGER put_seq_on_comment_trigger
  BEFORE INSERT ON note_comments
  FOR EACH ROW
  EXECUTE FUNCTION put_seq_on_comment()
;
COMMENT ON TRIGGER put_seq_on_comment_trigger ON note_comments IS
  'Trigger to assign the sequence value';
