-- Insert new text comments.
-- Sequence numbers are already generated in AWK extraction
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-10-21

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 'Inserting text comments with sequence numbers from AWK' AS Text;

-- Insert text comments directly from API tables
-- Sequence numbers are already provided by AWK extraction
-- IMPORTANT: Only insert if (note_id, sequence_action) exists in note_comments
-- This prevents FK violations when duplicate comments are deduplicated
INSERT INTO note_comments_text (note_id, sequence_action, body)
 SELECT /* Notes-processAPI */ t.note_id, t.sequence_action, t.body
 FROM note_comments_text_api t
 WHERE EXISTS (
   SELECT 1
   FROM note_comments nc
   WHERE nc.note_id = t.note_id
     AND nc.sequence_action = t.sequence_action
 )
 ON CONFLICT DO NOTHING;

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 'Text comments inserted successfully (with FK validation)' AS Text;