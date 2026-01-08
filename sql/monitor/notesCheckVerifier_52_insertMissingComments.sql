-- Inserts missing comments from check tables into main tables.
-- This script is executed after differences are identified.
-- Before inserting, it saves the missing comments to history table
-- for later analysis.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2026-01-08
-- Optimized: Changed NOT IN to LEFT JOIN for better performance with large datasets

-- First, save missing comments to history table BEFORE insertion
SELECT /* Notes-check */ clock_timestamp() AS Processing,
  'Saving missing comments to history table' AS Text;

INSERT INTO missing_comments_history (
  note_id,
  sequence_action,
  event,
  created_at,
  id_user,
  username,
  detected_at,
  inserted
)
SELECT /* Notes-check */
  check_c.note_id,
  check_c.sequence_action,
  check_c.event,
  check_c.created_at,
  check_c.id_user,
  check_c.username,
  CURRENT_TIMESTAMP,
  FALSE
FROM note_comments_check check_c
LEFT JOIN note_comments main_c
  ON check_c.note_id = main_c.note_id
  AND check_c.sequence_action = main_c.sequence_action
WHERE main_c.note_id IS NULL
  AND DATE(check_c.created_at) < CURRENT_DATE
ON CONFLICT (note_id, sequence_action, detected_at) DO NOTHING;

-- Insert missing users from check comments first
SELECT /* Notes-check */ clock_timestamp() AS Processing,
  'Inserting missing users from check comments' AS Text;

INSERT INTO users (user_id, username)
SELECT /* Notes-check */
  id_user,
  MIN(username) AS username
FROM note_comments_check
WHERE id_user IS NOT NULL
  AND username IS NOT NULL
  AND id_user NOT IN (SELECT /* Notes-check */ user_id FROM users)
GROUP BY id_user
ON CONFLICT (user_id) DO UPDATE SET
  username = EXCLUDED.username;

-- Insert missing comments from check to main tables
SELECT /* Notes-check */ clock_timestamp() AS Processing,
  'Inserting missing comments from check tables' AS Text;

-- Insert comments that exist in check but not in main
-- Using LEFT JOIN instead of NOT IN for better performance with large datasets
-- We need to get the id from the sequence first
WITH inserted_comments AS (
  INSERT INTO note_comments (
    id,
    note_id,
    sequence_action,
    event,
    created_at,
    id_user
  )
  SELECT /* Notes-check */
    nextval('note_comments_id_seq'),
    check_c.note_id,
    check_c.sequence_action,
    check_c.event,
    check_c.created_at,
    check_c.id_user
  FROM note_comments_check check_c
  LEFT JOIN note_comments main_c
    ON check_c.note_id = main_c.note_id
    AND check_c.sequence_action = main_c.sequence_action
  WHERE main_c.note_id IS NULL
    AND (check_c.id_user IS NULL OR check_c.id_user IN (
      SELECT /* Notes-check */ user_id FROM users
    ))
  ON CONFLICT DO NOTHING
  RETURNING note_id, sequence_action
)
-- Update history table to mark comments as inserted
UPDATE missing_comments_history mch
SET inserted = TRUE,
    inserted_at = CURRENT_TIMESTAMP
FROM inserted_comments ic
WHERE mch.note_id = ic.note_id
  AND mch.sequence_action = ic.sequence_action
  AND mch.inserted = FALSE;

-- Show count of inserted comments (using LEFT JOIN for performance)
SELECT /* Notes-check */ clock_timestamp() AS Processing,
  COUNT(1) AS Qty,
  'Inserted missing comments' AS Text
FROM note_comments_check check_c
LEFT JOIN note_comments main_c
  ON check_c.note_id = main_c.note_id
  AND check_c.sequence_action = main_c.sequence_action
WHERE main_c.note_id IS NULL;

-- Update statistics
SELECT /* Notes-check */ clock_timestamp() AS Processing,
  'Updating comments statistics' AS Text;
ANALYZE note_comments;

SELECT /* Notes-check */ clock_timestamp() AS Processing,
  'Missing comments insertion completed' AS Text;



