-- GDPR Access Request - Retrieve all personal data for a user
--
-- This script retrieves all personal data associated with a specific OSM user
-- for GDPR Article 15 (Right of Access) requests.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-12-13
--
-- Usage:
--   psql -d notes -v user_id=12345 -v username='john_doe' \
--     -f sql/gdpr/gdpr_access_request.sql
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
    
    -- Set the variable for use in queries
    PERFORM set_config('user_id', v_user_id::TEXT, false);
  ELSIF :user_id IS NOT NULL AND :user_id > 0 THEN
    -- Verify user exists
    SELECT user_id, username INTO v_user_id, v_username
    FROM users
    WHERE user_id = :user_id
    LIMIT 1;
    
    IF v_user_id IS NULL THEN
      RAISE EXCEPTION 'User not found with user_id: %', :user_id;
    END IF;
    
    -- Set username for verification
    PERFORM set_config('username', v_username, false);
  ELSE
    RAISE EXCEPTION 'Either user_id or username must be provided';
  END IF;
  
  RAISE NOTICE 'Processing GDPR access request for User ID: %, Username: %',
    v_user_id, v_username;
END $$;

-- Output header
\echo '=== GDPR ACCESS REQUEST RESULTS ==='
\echo ''
\echo 'Generated: ' || CURRENT_TIMESTAMP
\echo ''

-- 1. User Information
\echo '=== USER INFORMATION ==='
SELECT
  user_id AS "User ID",
  username AS "Username"
FROM users
WHERE user_id = (
  SELECT user_id::INTEGER
  FROM users
  WHERE (:user_id IS NOT NULL AND :user_id > 0 AND user_id = :user_id)
     OR (:username IS NOT NULL AND :username != '' AND username = :'username')
  LIMIT 1
);

-- 2. Notes Created by User
\echo ''
\echo '=== NOTES CREATED BY USER ==='
\echo 'Count of notes created by this user:'
SELECT
  COUNT(DISTINCT n.note_id) AS "Total Notes Created"
FROM notes AS n
INNER JOIN note_comments AS nc ON n.note_id = nc.note_id
WHERE nc.id_user = (
  SELECT user_id::INTEGER
  FROM users
  WHERE (:user_id IS NOT NULL AND :user_id > 0 AND user_id = :user_id)
     OR (:username IS NOT NULL AND :username != '' AND username = :'username')
  LIMIT 1
)
  AND nc.sequence_action = 1  -- First comment (note creation)
  AND nc.event = 'opened';

-- Detailed notes created by user
\echo ''
\echo '=== DETAILED NOTES CREATED ==='
SELECT
  n.note_id AS "Note ID",
  n.latitude AS "Latitude",
  n.longitude AS "Longitude",
  n.created_at AS "Created At",
  n.status AS "Status",
  n.closed_at AS "Closed At",
  n.id_country AS "Country ID"
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
ORDER BY n.created_at DESC;

-- 3. Comments Made by User
\echo ''
\echo '=== COMMENTS MADE BY USER ==='
\echo 'Count of comments made by this user:'
SELECT
  COUNT(nc.id) AS "Total Comments"
FROM note_comments AS nc
WHERE nc.id_user = (
  SELECT user_id::INTEGER
  FROM users
  WHERE (:user_id IS NOT NULL AND :user_id > 0 AND user_id = :user_id)
     OR (:username IS NOT NULL AND :username != '' AND username = :'username')
  LIMIT 1
);

-- Detailed comments made by user
\echo ''
\echo '=== DETAILED COMMENTS ==='
SELECT
  nc.id AS "Comment ID",
  nc.note_id AS "Note ID",
  nc.sequence_action AS "Sequence",
  nc.event AS "Event Type",
  nc.created_at AS "Created At",
  nc.processing_time AS "Processing Time"
FROM note_comments AS nc
WHERE nc.id_user = (
  SELECT user_id::INTEGER
  FROM users
  WHERE (:user_id IS NOT NULL AND :user_id > 0 AND user_id = :user_id)
     OR (:username IS NOT NULL AND :username != '' AND username = :'username')
  LIMIT 1
)
ORDER BY nc.created_at DESC;

-- 4. Comment Texts
\echo ''
\echo '=== COMMENT TEXTS ==='
SELECT
  nct.note_id AS "Note ID",
  nct.sequence_action AS "Sequence",
  nct.body AS "Comment Text",
  nct.processing_time AS "Processing Time"
FROM note_comments_text AS nct
WHERE nct.note_id IN (
  SELECT DISTINCT nc.note_id
  FROM note_comments AS nc
  WHERE nc.id_user = (
    SELECT user_id::INTEGER
    FROM users
    WHERE (:user_id IS NOT NULL AND :user_id > 0 AND user_id = :user_id)
       OR (:username IS NOT NULL AND :username != '' AND username = :'username')
    LIMIT 1
  )
)
  AND nct.sequence_action IN (
    SELECT nc2.sequence_action
    FROM note_comments AS nc2
    WHERE nc2.note_id = nct.note_id
      AND nc2.id_user = (
        SELECT user_id::INTEGER
        FROM users
        WHERE (:user_id IS NOT NULL AND :user_id > 0 AND user_id = :user_id)
           OR (:username IS NOT NULL AND :username != '' AND username = :'username')
        LIMIT 1
      )
  )
ORDER BY nct.note_id, nct.sequence_action;

-- 5. Summary Statistics
\echo ''
\echo '=== SUMMARY STATISTICS ==='
SELECT
  'Data Range' AS "Statistic",
  MIN(nc.created_at)::TEXT || ' to ' || MAX(nc.created_at)::TEXT AS "Value"
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
  'Total Notes Created',
  COUNT(DISTINCT n.note_id)::TEXT
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
  'Total Comments Made',
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
  'Countries with Notes',
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

\echo ''
\echo '=== END OF GDPR ACCESS REQUEST ==='

