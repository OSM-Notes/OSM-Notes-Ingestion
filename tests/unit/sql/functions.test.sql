-- Unit tests for database functions using pgTAP
-- Author: Andres Gomez (AngocA)
-- Version: 2025-07-20

BEGIN;

-- Load pgTAP
\i /usr/share/postgresql/15/extension/pgtap.sql

-- Plan the tests
SELECT plan(15);

-- Test 1: Check if get_country function exists
SELECT has_function('get_country');

-- Test 2: Check if insert_note procedure exists
SELECT has_function('insert_note');

-- Test 3: Check if insert_note_comment procedure exists
SELECT has_function('insert_note_comment');

-- Test 4: Check if put_lock procedure exists
SELECT has_function('put_lock');

-- Test 5: Check if remove_lock procedure exists
SELECT has_function('remove_lock');

-- Test 6: Test get_country function with valid coordinates
SELECT lives_ok(
  'SELECT get_country(40.7128, -74.0060)',
  'get_country should work with valid coordinates'
);

-- Test 7: Test get_country function with null coordinates
SELECT lives_ok(
  'SELECT get_country(NULL, NULL)',
  'get_country should handle null coordinates'
);

-- Test 8: Test insert_note procedure with valid data
SELECT lives_ok(
  'CALL insert_note(123, 40.7128, -74.0060, NOW(), ''test'')',
  'insert_note should insert data without errors'
);

-- Test 9: Test insert_note_comment procedure with valid data
SELECT lives_ok(
  'CALL insert_note_comment(123, ''opened'', NOW(), 123)',
  'insert_note_comment should insert data without errors'
);

-- Test 10: Test put_lock procedure
SELECT lives_ok(
  'CALL put_lock(''test_lock'')',
  'put_lock should create a lock'
);

-- Test 11: Test remove_lock procedure
SELECT lives_ok(
  'CALL remove_lock(''test_lock'')',
  'remove_lock should remove a lock'
);

-- Test 12: Test that get_country returns expected country for known coordinates
SELECT results_eq(
  'SELECT get_country(40.7128, -74.0060)',
  ARRAY[1::INTEGER],
  'get_country should return country ID 1 for New York coordinates'
);

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

-- Finish the tests
SELECT finish();

ROLLBACK; 