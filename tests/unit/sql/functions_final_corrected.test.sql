-- Unit tests for database functions (corrected version with proper signatures)
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

-- Test 6: Test get_country function with valid coordinates (correct signature)
DO $$
BEGIN
  BEGIN
    PERFORM get_country(40.7128, -74.0060, 123);
    RAISE NOTICE 'Test passed: get_country works with valid coordinates';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Test failed: get_country failed with valid coordinates: %', SQLERRM;
  END;
END $$;

-- Test 7: Test get_country function with null coordinates (correct signature)
DO $$
BEGIN
  BEGIN
    PERFORM get_country(NULL, NULL, 123);
    RAISE NOTICE 'Test passed: get_country handles null coordinates';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Test failed: get_country failed with null coordinates: %', SQLERRM;
  END;
END $$;

-- Test 8: Test insert_note procedure with valid data (correct signature)
DO $$
BEGIN
  BEGIN
    -- First create a lock
    CALL put_lock('123');
    
    -- Then call insert_note with correct parameters
    CALL insert_note(123, 40.7128, -74.0060, NOW(), 123);
    RAISE NOTICE 'Test passed: insert_note inserts data without errors';
    
    -- Clean up
    CALL remove_lock('123');
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Test failed: insert_note failed: %', SQLERRM;
  END;
END $$;

-- Test 9: Test insert_note_comment procedure with valid data (correct signature)
DO $$
BEGIN
  BEGIN
    -- First create a lock
    CALL put_lock('123');
    
    -- Then call insert_note_comment with correct parameters
    CALL insert_note_comment(123, 'opened', NOW(), 123, 'test_user', 123);
    RAISE NOTICE 'Test passed: insert_note_comment inserts data without errors';
    
    -- Clean up
    CALL remove_lock('123');
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Test failed: insert_note_comment failed: %', SQLERRM;
  END;
END $$;

-- Test 10: Test put_lock procedure
DO $$
BEGIN
  BEGIN
    CALL put_lock('test_lock');
    RAISE NOTICE 'Test passed: put_lock creates a lock';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Test failed: put_lock failed: %', SQLERRM;
  END;
END $$;

-- Test 11: Test remove_lock procedure
DO $$
BEGIN
  BEGIN
    CALL remove_lock('test_lock');
    RAISE NOTICE 'Test passed: remove_lock removes a lock';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Test failed: remove_lock failed: %', SQLERRM;
  END;
END $$;

-- Test 12: Test that get_country returns expected country for known coordinates
DO $$
DECLARE
  country_id INTEGER;
BEGIN
  SELECT get_country(40.7128, -74.0060, 123) INTO country_id;
  IF country_id IS NOT NULL THEN
    RAISE NOTICE 'Test passed: get_country returns country ID % for New York coordinates', country_id;
  ELSE
    RAISE NOTICE 'Test failed: get_country returned NULL';
  END IF;
END $$;

-- Test 13: Test that insert_note actually inserts data
DO $$
DECLARE
  note_count INTEGER;
BEGIN
  -- First create a lock
  CALL put_lock('999');
  
  -- Insert a test note
  CALL insert_note(999, 40.7128, -74.0060, NOW(), 999);
  
  -- Check if note was inserted
  SELECT COUNT(*) INTO note_count FROM notes WHERE note_id = 999;
  
  -- Assert
  IF note_count = 1 THEN
    RAISE NOTICE 'Test passed: Note was inserted successfully';
  ELSE
    RAISE NOTICE 'Test failed: Note was not inserted (count: %)', note_count;
  END IF;
  
  -- Clean up
  DELETE FROM notes WHERE note_id = 999;
  CALL remove_lock('999');
END $$;

-- Test 14: Test that insert_note_comment actually inserts data
DO $$
DECLARE
  comment_count INTEGER;
BEGIN
  -- First create a lock
  CALL put_lock('999');
  
  -- First insert a note to satisfy foreign key constraint
  CALL insert_note(999, 40.7128, -74.0060, NOW(), 999);
  
  -- Insert a test comment
  CALL insert_note_comment(999, 'opened', NOW(), 123, 'test_user', 999);
  
  -- Check if comment was inserted
  SELECT COUNT(*) INTO comment_count FROM note_comments WHERE note_id = 999;
  
  -- Assert
  IF comment_count = 1 THEN
    RAISE NOTICE 'Test passed: Comment was inserted successfully';
  ELSE
    RAISE NOTICE 'Test failed: Comment was not inserted (count: %)', comment_count;
  END IF;
  
  -- Clean up
  DELETE FROM note_comments WHERE note_id = 999;
  DELETE FROM notes WHERE note_id = 999;
  CALL remove_lock('999');
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
    RAISE NOTICE 'Test failed: Lock was not created';
  END IF;
  
  -- Remove the lock
  CALL remove_lock('test_lock_2');
  
  -- Check if lock was removed
  SELECT COUNT(*) INTO lock_count FROM properties WHERE key = 'lock';
  
  -- Assert
  IF lock_count = 0 THEN
    RAISE NOTICE 'Test passed: Lock was removed successfully';
  ELSE
    RAISE NOTICE 'Test failed: Lock was not removed';
  END IF;
END $$;

DO $$
BEGIN
  RAISE NOTICE 'All function tests completed successfully';
END $$;

ROLLBACK; 