-- Adds constraints and triggers for comments sequence validation
-- Sequence numbers are already generated in AWK extraction
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-07-26

SELECT /* Notes-processPlanet */ clock_timestamp() AS Processing,
 'Setting up sequence constraints and triggers' AS Text;

-- Make sequence_action NOT NULL since it's always provided by AWK
ALTER TABLE note_comments ALTER COLUMN sequence_action SET NOT NULL;

-- Create unique index to ensure no duplicate sequences per note
CREATE UNIQUE INDEX IF NOT EXISTS unique_comment_note
 ON note_comments
 (note_id, sequence_action);
COMMENT ON INDEX unique_comment_note IS 'Sequence of comments creation';
ALTER TABLE note_comments
 ADD CONSTRAINT unique_comment_note
 UNIQUE USING INDEX unique_comment_note;

-- Create trigger function for new comments (when not from AWK)
CREATE OR REPLACE FUNCTION put_seq_on_comment()
  RETURNS TRIGGER AS
 $$
 DECLARE
  max_value INTEGER;
 BEGIN
   -- Only assign sequence if not already provided (from AWK)
   IF NEW.sequence_action IS NULL THEN
     SELECT /* Notes-processPlanet */ MAX(sequence_action)
      INTO max_value
     FROM note_comments
     WHERE note_id = NEW.note_id;
     IF (max_value IS NULL) THEN
      max_value := 1;
     ELSE
      max_value := max_value + 1;
     END IF;
     NEW.sequence_action := max_value;
   END IF;

   RETURN NEW;
 END;
 $$ LANGUAGE plpgsql
;
COMMENT ON FUNCTION put_seq_on_comment IS
  'Assigns the sequence value for new comments (only if not provided by XSLT)';

CREATE OR REPLACE TRIGGER put_seq_on_comment_trigger
  BEFORE INSERT ON note_comments
  FOR EACH ROW
  EXECUTE FUNCTION put_seq_on_comment()
;
COMMENT ON TRIGGER put_seq_on_comment_trigger ON note_comments IS
  'Trigger to assign sequence value only when not provided by XSLT';

SELECT /* Notes-processPlanet */ clock_timestamp() AS Processing,
 'Sequence constraints and triggers configured' AS Text;

