-- Inserts missing text comments from check tables into main tables.
-- This script is executed after differences are identified.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-12-14
-- Optimized: Changed NOT IN to LEFT JOIN for better performance with large datasets

-- Insert missing text comments from check to main tables
SELECT /* Notes-check */ clock_timestamp() AS Processing,
  'Inserting missing text comments from check tables' AS Text;

-- Insert text comments that exist in check but not in main
-- Only insert if the corresponding comment exists
-- Using LEFT JOIN instead of NOT IN for better performance with large datasets
INSERT INTO note_comments_text (
  id,
  note_id,
  sequence_action,
  body
)
SELECT /* Notes-check */
  nextval('note_comments_text_id_seq'),
  check_tc.note_id,
  check_tc.sequence_action,
  check_tc.body
FROM note_comments_text_check check_tc
LEFT JOIN note_comments_text main_tc
  ON check_tc.note_id = main_tc.note_id
  AND check_tc.sequence_action = main_tc.sequence_action
WHERE main_tc.note_id IS NULL
  AND EXISTS (
    SELECT /* Notes-check */ 1
    FROM note_comments nc
    WHERE nc.note_id = check_tc.note_id
      AND nc.sequence_action = check_tc.sequence_action
  )
ON CONFLICT DO NOTHING;

-- Show count of inserted text comments (using LEFT JOIN for performance)
SELECT /* Notes-check */ clock_timestamp() AS Processing,
  COUNT(1) AS Qty,
  'Inserted missing text comments' AS Text
FROM note_comments_text_check check_tc
LEFT JOIN note_comments_text main_tc
  ON check_tc.note_id = main_tc.note_id
  AND check_tc.sequence_action = main_tc.sequence_action
WHERE main_tc.note_id IS NULL
  AND EXISTS (
    SELECT /* Notes-check */ 1
    FROM note_comments nc
    WHERE nc.note_id = check_tc.note_id
      AND nc.sequence_action = check_tc.sequence_action
  );

-- Update statistics
SELECT /* Notes-check */ clock_timestamp() AS Processing,
  'Updating text comments statistics' AS Text;
ANALYZE note_comments_text;

SELECT /* Notes-check */ clock_timestamp() AS Processing,
  'Missing text comments insertion completed' AS Text;



