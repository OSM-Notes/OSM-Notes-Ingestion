-- Unit tests for database functions (simplified version without pgTAP)
-- Author: Andres Gomez (AngocA)
-- Version: 2025-01-27

BEGIN;

-- Test 1: Check if get_country function exists
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'get_country') THEN
    RAISE EXCEPTION 'Function get_country does not exist';
  ELSE
    RAISE NOTICE 'Test passed: Function get_country exists';
  END IF;
END $$;

-- Test 2: Check if insert_note procedure exists
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'insert_note') THEN
    RAISE EXCEPTION 'Procedure insert_note does not exist';
  ELSE
    RAISE NOTICE 'Test passed: Procedure insert_note exists';
  END IF;
END $$;

-- Test 3: Check if insert_note_comment procedure exists
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'insert_note_comment') THEN
    RAISE EXCEPTION 'Procedure insert_note_comment does not exist';
  ELSE
    RAISE NOTICE 'Test passed: Procedure insert_note_comment exists';
  END IF;
END $$;

-- Test 4: Check if put_lock procedure exists
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'put_lock') THEN
    RAISE EXCEPTION 'Procedure put_lock does not exist';
  ELSE
    RAISE NOTICE 'Test passed: Procedure put_lock exists';
  END IF;
END $$;

-- Test 5: Check if remove_lock procedure exists
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'remove_lock') THEN
    RAISE EXCEPTION 'Procedure remove_lock does not exist';
  ELSE
    RAISE NOTICE 'Test passed: Procedure remove_lock exists';
  END IF;
END $$;

-- Test 6: Test get_country function with valid coordinates
DO $$
BEGIN
  BEGIN
    PERFORM get_country(40.7128, -74.0060);
    RAISE NOTICE 'Test passed: get_country works with valid coordinates';
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Test failed: get_country failed with valid coordinates: %', SQLERRM;
  END;
END $$;

-- Test 7: Test get_country function with null coordinates
DO $$
BEGIN
  BEGIN
    PERFORM get_country(NULL, NULL);
    RAISE NOTICE 'Test passed: get_country handles null coordinates';
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Test failed: get_country failed with null coordinates: %', SQLERRM;
  END;
END $$;

-- Test 8: Test insert_note procedure with valid data
DO $$
BEGIN
  BEGIN
    CALL insert_note(123, 40.7128, -74.0060, NOW(), 'test');
    RAISE NOTICE 'Test passed: insert_note inserts data without errors';
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Test failed: insert_note failed: %', SQLERRM;
  END;
END $$;

-- Test 9: Test insert_note_comment procedure with valid data
DO $$
BEGIN
  BEGIN
    CALL insert_note_comment(123, 'opened', NOW(), 123);
    RAISE NOTICE 'Test passed: insert_note_comment inserts data without errors';
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Test failed: insert_note_comment failed: %', SQLERRM;
  END;
END $$;

-- Test 10: Test put_lock procedure
DO $$
BEGIN
  BEGIN
    CALL put_lock('test_lock');
    RAISE NOTICE 'Test passed: put_lock creates a lock';
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Test failed: put_lock failed: %', SQLERRM;
  END;
END $$;

-- Test 11: Test remove_lock procedure
DO $$
BEGIN
  BEGIN
    CALL remove_lock('test_lock');
    RAISE NOTICE 'Test passed: remove_lock removes a lock';
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Test failed: remove_lock failed: %', SQLERRM;
  END;
END $$;

-- Test 12: Test that get_country returns expected country for known coordinates
DO $$
DECLARE
  country_id INTEGER;
BEGIN
  SELECT get_country(40.7128, -74.0060) INTO country_id;
  IF country_id = 1 THEN
    RAISE NOTICE 'Test passed: get_country returns country ID 1 for New York coordinates';
  ELSE
    RAISE EXCEPTION 'Test failed: get_country returned % instead of 1', country_id;
  END IF;
END $$;

-- Test 13: Test that insert_note actually inserts data
DO $$
DECLARE
  note_count INTEGER;
BEGIN
  -- Insert a test note
  CALL insert_note(999, 40.7128, -74.0060, NOW(), 'test');
  
  -- Check if note was inserted
  SELECT COUNT(*) INTO note_count FROM notes WHERE note_id = 999;
  
  -- Assert
  IF note_count = 1 THEN
    RAISE NOTICE 'Test passed: Note was inserted successfully';
  ELSE
    RAISE EXCEPTION 'Test failed: Note was not inserted';
  END IF;
END $$;

-- Test 14: Test that insert_note_comment actually inserts data
DO $$
DECLARE
  comment_count INTEGER;
BEGIN
  -- Insert a test comment
  CALL insert_note_comment(999, 'opened', NOW(), 123);
  
  -- Check if comment was inserted
  SELECT COUNT(*) INTO comment_count FROM note_comments WHERE note_id = 999;
  
  -- Assert
  IF comment_count = 1 THEN
    RAISE NOTICE 'Test passed: Comment was inserted successfully';
  ELSE
    RAISE EXCEPTION 'Test failed: Comment was not inserted';
  END IF;
END $$;

-- Test 15: Test lock mechanism
DO $$
DECLARE
  lock_count INTEGER;
BEGIN
  -- Put a lock
  CALL put_lock('test_lock_2');
  
  -- Check if lock exists
  SELECT COUNT(*) INTO lock_count FROM properties WHERE key = 'lock' AND value = 'test_lock_2';
  
  -- Assert
  IF lock_count = 1 THEN
    RAISE NOTICE 'Test passed: Lock was created successfully';
  ELSE
    RAISE EXCEPTION 'Test failed: Lock was not created';
  END IF;
  
  -- Remove the lock
  CALL remove_lock('test_lock_2');
  
  -- Check if lock was removed
  SELECT COUNT(*) INTO lock_count FROM properties WHERE key = 'lock';
  
  -- Assert
  IF lock_count = 0 THEN
    RAISE NOTICE 'Test passed: Lock was removed successfully';
  ELSE
    RAISE EXCEPTION 'Test failed: Lock was not removed';
  END IF;
END $$;

RAISE NOTICE 'All function tests completed successfully';

ROLLBACK; 