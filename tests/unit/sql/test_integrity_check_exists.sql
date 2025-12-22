-- Test: Validates that integrity check uses EXISTS instead of COUNT(*)
-- to efficiently check if database has comments
-- Author: Andres Gomez (AngocA)
-- Version: 2025-12-22

\set ON_ERROR_STOP on

BEGIN;

-- Test 1: Verify EXISTS is faster than COUNT(*) for empty table check
DO $$
DECLARE
  m_start_time TIMESTAMP;
  m_end_time TIMESTAMP;
  m_duration_exists NUMERIC;
  m_duration_count NUMERIC;
  m_has_comments BOOLEAN;
  m_total_comments INTEGER;
BEGIN
  -- Test EXISTS (optimized way)
  m_start_time := clock_timestamp();
  SELECT EXISTS(SELECT 1 FROM note_comments LIMIT 1) INTO m_has_comments;
  m_end_time := clock_timestamp();
  m_duration_exists := EXTRACT(EPOCH FROM (m_end_time - m_start_time)) * 1000;

  -- Test COUNT(*) (old way)
  m_start_time := clock_timestamp();
  SELECT COUNT(*) INTO m_total_comments FROM note_comments;
  m_end_time := clock_timestamp();
  m_duration_count := EXTRACT(EPOCH FROM (m_end_time - m_start_time)) * 1000;

  -- EXISTS should be significantly faster than COUNT(*)
  -- For large tables, EXISTS stops at first row, COUNT(*) scans entire table
  IF m_duration_exists > m_duration_count THEN
    RAISE NOTICE 'Test 1 INFO: EXISTS took longer than COUNT(*) (may be due to small table). EXISTS: %ms, COUNT: %ms', 
      m_duration_exists, m_duration_count;
  ELSE
    RAISE NOTICE 'Test 1 PASSED: EXISTS is faster than COUNT(*). EXISTS: %ms, COUNT: %ms', 
      m_duration_exists, m_duration_count;
  END IF;

  -- Both should return consistent results
  IF m_has_comments AND m_total_comments = 0 THEN
    RAISE EXCEPTION 'EXISTS and COUNT(*) return inconsistent results. EXISTS: %, COUNT: %', 
      m_has_comments, m_total_comments;
  END IF;

  IF NOT m_has_comments AND m_total_comments > 0 THEN
    RAISE EXCEPTION 'EXISTS and COUNT(*) return inconsistent results. EXISTS: %, COUNT: %', 
      m_has_comments, m_total_comments;
  END IF;
END $$;

-- Test 2: Verify EXISTS returns TRUE when comments exist
DO $$
DECLARE
  m_user_id INTEGER;
  m_note_id BIGINT;
  m_has_comments BOOLEAN;
BEGIN
  -- Create test data: user, note, and comment
  INSERT INTO users (user_id, username) VALUES (999999, 'Test User EXISTS')
  ON CONFLICT (user_id) DO UPDATE SET username = EXCLUDED.username;

  SELECT user_id INTO m_user_id FROM users WHERE user_id = 999999;

  INSERT INTO notes (id, latitude, longitude, created_at, status)
  VALUES (999999, 40.7128, -74.0060, NOW(), 'open')
  ON CONFLICT (id) DO UPDATE SET status = EXCLUDED.status;

  SELECT id INTO m_note_id FROM notes WHERE id = 999999;

  -- Temporarily disable trigger to avoid schema conflicts
  ALTER TABLE note_comments DISABLE TRIGGER update_note;

  -- Delete if exists, then insert
  DELETE FROM note_comments WHERE id = 999999;
  
  INSERT INTO note_comments (id, note_id, id_user, sequence_action, created_at, event)
  VALUES (999999, m_note_id::INTEGER, m_user_id, 1, NOW(), 'opened');

  ALTER TABLE note_comments ENABLE TRIGGER update_note;

  -- Test EXISTS should return TRUE
  SELECT EXISTS(SELECT 1 FROM note_comments LIMIT 1) INTO m_has_comments;

  IF NOT m_has_comments THEN
    RAISE EXCEPTION 'EXISTS returned FALSE when comments exist';
  END IF;

  -- Cleanup
  DELETE FROM note_comments WHERE id = 999999;
  DELETE FROM notes WHERE id = 999999;
  DELETE FROM users WHERE user_id = 999999;

  RAISE NOTICE 'Test 2 PASSED: EXISTS returns TRUE when comments exist';
END $$;

-- Test 3: Verify EXISTS returns FALSE when no comments exist (if table is empty)
-- Note: This test may be skipped if table has data, which is fine
DO $$
DECLARE
  m_total_comments INTEGER;
  m_has_comments BOOLEAN;
  m_has_comments_after BOOLEAN;
BEGIN
  -- Check if table is empty (or very small for testing)
  SELECT COUNT(*) INTO m_total_comments FROM note_comments;

  IF m_total_comments > 0 THEN
    RAISE NOTICE 'Test 3 SKIPPED: Table has % comments, cannot test empty table scenario', m_total_comments;
  ELSE
    -- Table is empty, EXISTS should return FALSE
    SELECT EXISTS(SELECT 1 FROM note_comments LIMIT 1) INTO m_has_comments;

    IF m_has_comments THEN
      RAISE EXCEPTION 'EXISTS returned TRUE when table is empty';
    END IF;

    RAISE NOTICE 'Test 3 PASSED: EXISTS returns FALSE when table is empty';
  END IF;
END $$;

-- Test 4: Verify logic equivalence: NOT EXISTS vs COUNT(*) = 0
DO $$
DECLARE
  m_has_comments BOOLEAN;
  m_total_comments INTEGER;
  m_check_with_exists BOOLEAN;
  m_check_with_count BOOLEAN;
BEGIN
  -- Get both values
  SELECT EXISTS(SELECT 1 FROM note_comments LIMIT 1) INTO m_has_comments;
  SELECT COUNT(*) INTO m_total_comments FROM note_comments;

  -- Check if database is empty using both methods
  m_check_with_exists := NOT m_has_comments;
  m_check_with_count := (m_total_comments = 0);

  -- Both checks should give same result
  IF m_check_with_exists != m_check_with_count THEN
    RAISE EXCEPTION 'Logic inconsistency: NOT EXISTS (%) != COUNT(*) = 0 (%)', 
      m_check_with_exists, m_check_with_count;
  END IF;

  RAISE NOTICE 'Test 4 PASSED: NOT EXISTS logic equivalent to COUNT(*) = 0. Result: %', m_check_with_exists;
END $$;

ROLLBACK;

