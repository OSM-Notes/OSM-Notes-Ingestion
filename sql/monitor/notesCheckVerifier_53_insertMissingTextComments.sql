-- Inserts missing text comments from check tables into main tables.
-- This script is executed after differences are identified.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-01-21

-- Insert missing text comments from check to main tables
SELECT /* Notes-check */ clock_timestamp() AS Processing,
  'Inserting missing text comments from check tables' AS Text;

-- Insert text comments that exist in check but not in main
-- Only insert if the corresponding comment exists
INSERT INTO note_comments_text (
  id,
  note_id,
  sequence_action,
  body
)
SELECT /* Notes-check */
  nextval('note_comments_text_id_seq'),
  note_id,
  sequence_action,
  body
FROM note_comments_text_check
WHERE (note_id, sequence_action) NOT IN (
  SELECT /* Notes-check */ note_id, sequence_action
  FROM note_comments_text
)
AND EXISTS (
  SELECT /* Notes-check */ 1
  FROM note_comments nc
  WHERE nc.note_id = note_comments_text_check.note_id
    AND nc.sequence_action = note_comments_text_check.sequence_action
)
ON CONFLICT DO NOTHING;

-- Show count of inserted text comments
SELECT /* Notes-check */ clock_timestamp() AS Processing,
  COUNT(1) AS Qty,
  'Inserted missing text comments' AS Text
FROM note_comments_text_check
WHERE (note_id, sequence_action) NOT IN (
  SELECT /* Notes-check */ note_id, sequence_action
  FROM note_comments_text
)
AND EXISTS (
  SELECT /* Notes-check */ 1
  FROM note_comments nc
  WHERE nc.note_id = note_comments_text_check.note_id
    AND nc.sequence_action = note_comments_text_check.sequence_action
);

-- Update statistics
SELECT /* Notes-check */ clock_timestamp() AS Processing,
  'Updating text comments statistics' AS Text;
ANALYZE note_comments_text;

SELECT /* Notes-check */ clock_timestamp() AS Processing,
  'Missing text comments insertion completed' AS Text;



