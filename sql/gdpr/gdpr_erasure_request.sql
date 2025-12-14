-- GDPR Erasure Request - Anonymize personal data for a user
--
-- This script anonymizes personal data associated with a specific OSM user
-- for GDPR Article 17 (Right to Erasure / Right to be Forgotten) requests.
--
-- WARNING: This script ANONYMIZES data rather than deleting it completely
-- due to foreign key constraints and license requirements (ODbL).
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-01-23
--
-- Usage:
--   psql -d notes -v user_id=12345 -v username='john_doe' \
--     -f sql/gdpr/gdpr_erasure_request.sql
--
-- Parameters:
--   user_id: OSM User ID (required)
--   username: OSM Username (required for verification)
--
-- Actions:
--   1. Verifies user identity (user_id must match username)
--   2. Anonymizes username in users table
--   3. Sets id_user to NULL in note_comments table (removes user attribution)
--   4. Creates audit log entry

\set ON_ERROR_STOP on

BEGIN;

-- Verify user exists and username matches user_id
DO $$
DECLARE
  v_user_id INTEGER;
  v_username VARCHAR(256);
  v_actual_username VARCHAR(256);
BEGIN
  -- Check if user_id is provided
  IF :user_id IS NULL OR :user_id = 0 THEN
    RAISE EXCEPTION 'user_id parameter is required';
  END IF;
  
  -- Check if username is provided
  IF :'username' IS NULL OR :'username' = '' THEN
    RAISE EXCEPTION 'username parameter is required for verification';
  END IF;
  
  -- Get actual user data
  SELECT user_id, username INTO v_user_id, v_actual_username
  FROM users
  WHERE user_id = :user_id
  LIMIT 1;
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'User not found with user_id: %', :user_id;
  END IF;
  
  -- Verify username matches
  IF v_actual_username != :'username' THEN
    RAISE EXCEPTION 'Username verification failed. Expected: %, Found: %',
      :'username', v_actual_username;
  END IF;
  
  RAISE NOTICE 'Processing GDPR erasure request for User ID: %, Username: %',
    v_user_id, v_actual_username;
END $$;

-- Create audit log table if it doesn't exist
CREATE TABLE IF NOT EXISTS gdpr_audit_log (
  id SERIAL PRIMARY KEY,
  timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  user_id INTEGER NOT NULL,
  username VARCHAR(256) NOT NULL,
  action VARCHAR(50) NOT NULL,
  details TEXT,
  executed_by VARCHAR(256)
);
COMMENT ON TABLE gdpr_audit_log IS
  'Audit log for GDPR data subject requests';
COMMENT ON COLUMN gdpr_audit_log.user_id IS 'OSM User ID affected';
COMMENT ON COLUMN gdpr_audit_log.username IS 'OSM Username affected (original)';
COMMENT ON COLUMN gdpr_audit_log.action IS 'Action performed (erasure, access, etc.)';
COMMENT ON COLUMN gdpr_audit_log.details IS 'Additional details about the action';

-- Count affected records before anonymization
DO $$
DECLARE
  v_user_id INTEGER := :user_id;
  v_username VARCHAR(256) := :'username';
  v_notes_count INTEGER;
  v_comments_count INTEGER;
BEGIN
  -- Count notes created by user
  SELECT COUNT(DISTINCT n.note_id) INTO v_notes_count
  FROM notes AS n
  INNER JOIN note_comments AS nc ON n.note_id = nc.note_id
  WHERE nc.id_user = v_user_id
    AND nc.sequence_action = 1
    AND nc.event = 'opened';
  
  -- Count comments made by user
  SELECT COUNT(nc.id) INTO v_comments_count
  FROM note_comments AS nc
  WHERE nc.id_user = v_user_id;
  
  RAISE NOTICE 'Records to be anonymized:';
  RAISE NOTICE '  - Notes created: %', v_notes_count;
  RAISE NOTICE '  - Comments made: %', v_comments_count;
  
  -- Log audit entry
  INSERT INTO gdpr_audit_log (user_id, username, action, details)
  VALUES (
    v_user_id,
    v_username,
    'erasure_request_started',
    format('Notes: %, Comments: %', v_notes_count, v_comments_count)
  );
END $$;

-- Step 1: Anonymize username in users table
-- Replace with anonymized version: [ANONYMIZED_USER_<user_id>]
UPDATE users
SET username = '[ANONYMIZED_USER_' || user_id || ']'
WHERE user_id = :user_id
  AND username = :'username';

-- Verify update
DO $$
DECLARE
  v_updated_count INTEGER;
BEGIN
  GET DIAGNOSTICS v_updated_count = ROW_COUNT;
  IF v_updated_count = 0 THEN
    RAISE EXCEPTION 'Failed to anonymize username. User may have been '
      'already anonymized or username does not match.';
  END IF;
  RAISE NOTICE 'Anonymized username in users table (rows affected: %)',
    v_updated_count;
END $$;

-- Step 2: Remove user attribution from note_comments
-- Set id_user to NULL to remove link to user while preserving comment data
UPDATE note_comments
SET id_user = NULL
WHERE id_user = :user_id;

-- Verify update
DO $$
DECLARE
  v_updated_count INTEGER;
BEGIN
  GET DIAGNOSTICS v_updated_count = ROW_COUNT;
  RAISE NOTICE 'Removed user attribution from note_comments (rows affected: %)',
    v_updated_count;
END $$;

-- Step 3: Log completion
DO $$
DECLARE
  v_user_id INTEGER := :user_id;
  v_username VARCHAR(256) := :'username';
BEGIN
  INSERT INTO gdpr_audit_log (user_id, username, action, details)
  VALUES (
    v_user_id,
    v_username,
    'erasure_request_completed',
    'Username anonymized, user attribution removed from comments'
  );
  
  RAISE NOTICE 'GDPR erasure request completed successfully';
  RAISE NOTICE 'User ID: % has been anonymized', v_user_id;
END $$;

COMMIT;

-- Display summary
SELECT
  'Erasure Request Summary' AS "Status",
  'User ID: ' || :user_id::TEXT || ' anonymized' AS "Details"
UNION ALL
SELECT
  'Username',
  username
FROM users
WHERE user_id = :user_id;

\echo ''
\echo '=== GDPR ERASURE REQUEST COMPLETED ==='
\echo 'Note: Data structure preserved, user attribution removed.'
\echo 'Geographic and temporal data retained for research purposes.'
\echo ''

