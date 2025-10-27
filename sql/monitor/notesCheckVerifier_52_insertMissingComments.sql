-- Inserts missing comments from check tables into main tables.
-- This script is executed after differences are identified.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-01-21

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
-- We need to get the id from the sequence first
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
  note_id,
  sequence_action,
  event,
  created_at,
  id_user
FROM note_comments_check
WHERE (note_id, sequence_action) NOT IN (
  SELECT /* Notes-check */ note_id, sequence_action
  FROM note_comments
)
AND (id_user IS NULL OR id_user IN (
  SELECT /* Notes-check */ user_id FROM users
))
ON CONFLICT DO NOTHING;

-- Show count of inserted comments
SELECT /* Notes-check */ clock_timestamp() AS Processing,
  COUNT(1) AS Qty,
  'Inserted missing comments' AS Text
FROM note_comments_check
WHERE (note_id, sequence_action) NOT IN (
  SELECT /* Notes-check */ note_id, sequence_action
  FROM note_comments
);

-- Update statistics
SELECT /* Notes-check */ clock_timestamp() AS Processing,
  'Updating comments statistics' AS Text;
ANALYZE note_comments;

SELECT /* Notes-check */ clock_timestamp() AS Processing,
  'Missing comments insertion completed' AS Text;



