-- GDPR List User Data - Summary of user data (for verification)
--
-- This script provides a summary of all data associated with a specific user.
-- Use this script to verify user data before processing GDPR requests.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-12-13
--
-- Usage:
--   psql -d notes -v user_id=12345 -f sql/gdpr/gdpr_list_user_data.sql
--   psql -d notes -v username='john_doe' -f sql/gdpr/gdpr_list_user_data.sql
--
-- Parameters:
--   user_id: OSM User ID (optional if username provided)
--   username: OSM Username (optional if user_id provided)

\set ON_ERROR_STOP on

-- Determine user_id from username if needed
DO $$
DECLARE
  v_user_id INTEGER;
  v_username VARCHAR(256);
BEGIN
  -- If username is provided but user_id is not, look it up
  IF :'username' IS NOT NULL AND :'username' != '' AND 
     (:user_id IS NULL OR :user_id = 0) THEN
    SELECT user_id, username INTO v_user_id, v_username
    FROM users
    WHERE username = :'username'
    LIMIT 1;
    
    IF v_user_id IS NULL THEN
      RAISE EXCEPTION 'User not found with username: %', :'username';
    END IF;
    
    PERFORM set_config('user_id', v_user_id::TEXT, false);
  ELSIF :user_id IS NOT NULL AND :user_id > 0 THEN
    SELECT user_id, username INTO v_user_id, v_username
    FROM users
    WHERE user_id = :user_id
    LIMIT 1;
    
    IF v_user_id IS NULL THEN
      RAISE EXCEPTION 'User not found with user_id: %', :user_id;
    END IF;
  ELSE
    RAISE EXCEPTION 'Either user_id or username must be provided';
  END IF;
  
  RAISE NOTICE 'Summary for User ID: %, Username: %', v_user_id, v_username;
END $$;

\echo '=== GDPR USER DATA SUMMARY ==='
\echo ''

-- Basic user information
SELECT
  'User Information' AS "Section",
  user_id::TEXT AS "User ID",
  username AS "Username"
FROM users
WHERE user_id = (
  SELECT user_id::INTEGER
  FROM users
  WHERE (:user_id IS NOT NULL AND :user_id > 0 AND user_id = :user_id)
     OR (:username IS NOT NULL AND :username != '' AND username = :'username')
  LIMIT 1
);

-- Statistics
\echo ''
\echo '=== STATISTICS ==='
SELECT
  'Notes Created' AS "Metric",
  COUNT(DISTINCT n.note_id)::TEXT AS "Count"
FROM notes AS n
INNER JOIN note_comments AS nc ON n.note_id = nc.note_id
WHERE nc.id_user = (
  SELECT user_id::INTEGER
  FROM users
  WHERE (:user_id IS NOT NULL AND :user_id > 0 AND user_id = :user_id)
     OR (:username IS NOT NULL AND :username != '' AND username = :'username')
  LIMIT 1
)
  AND nc.sequence_action = 1
  AND nc.event = 'opened'
UNION ALL
SELECT
  'Total Comments',
  COUNT(nc.id)::TEXT
FROM note_comments AS nc
WHERE nc.id_user = (
  SELECT user_id::INTEGER
  FROM users
  WHERE (:user_id IS NOT NULL AND :user_id > 0 AND user_id = :user_id)
     OR (:username IS NOT NULL AND :username != '' AND username = :'username')
  LIMIT 1
)
UNION ALL
SELECT
  'Comments with Text',
  COUNT(DISTINCT nct.id)::TEXT
FROM note_comments_text AS nct
WHERE EXISTS (
  SELECT 1
  FROM note_comments AS nc
  WHERE nc.note_id = nct.note_id
    AND nc.sequence_action = nct.sequence_action
    AND nc.id_user = (
      SELECT user_id::INTEGER
      FROM users
      WHERE (:user_id IS NOT NULL AND :user_id > 0 AND user_id = :user_id)
         OR (:username IS NOT NULL AND :username != '' AND username = :'username')
      LIMIT 1
    )
)
UNION ALL
SELECT
  'Date Range',
  MIN(nc.created_at)::TEXT || ' to ' || MAX(nc.created_at)::TEXT
FROM note_comments AS nc
WHERE nc.id_user = (
  SELECT user_id::INTEGER
  FROM users
  WHERE (:user_id IS NOT NULL AND :user_id > 0 AND user_id = :user_id)
     OR (:username IS NOT NULL AND :username != '' AND username = :'username')
  LIMIT 1
)
UNION ALL
SELECT
  'Countries with Activity',
  COUNT(DISTINCT n.id_country)::TEXT
FROM notes AS n
INNER JOIN note_comments AS nc ON n.note_id = nc.note_id
WHERE nc.id_user = (
  SELECT user_id::INTEGER
  FROM users
  WHERE (:user_id IS NOT NULL AND :user_id > 0 AND user_id = :user_id)
     OR (:username IS NOT NULL AND :username != '' AND username = :'username')
  LIMIT 1
)
  AND n.id_country IS NOT NULL;

-- Recent activity (last 10 comments)
\echo ''
\echo '=== RECENT ACTIVITY (Last 10 Comments) ==='
SELECT
  nc.created_at AS "Date",
  nc.note_id AS "Note ID",
  nc.event AS "Event",
  LEFT(nct.body, 50) AS "Comment Preview"
FROM note_comments AS nc
LEFT JOIN note_comments_text AS nct
  ON nc.note_id = nct.note_id
  AND nc.sequence_action = nct.sequence_action
WHERE nc.id_user = (
  SELECT user_id::INTEGER
  FROM users
  WHERE (:user_id IS NOT NULL AND :user_id > 0 AND user_id = :user_id)
     OR (:username IS NOT NULL AND :username != '' AND username = :'username')
  LIMIT 1
)
ORDER BY nc.created_at DESC
LIMIT 10;

\echo ''
\echo '=== END OF SUMMARY ==='

