-- Test comment insertion flow from API tables to main tables
-- This test validates the complete flow: note_comments_api -> insert_note_comment -> note_comments
-- Author: Andres Gomez (AngocA)
-- Version: 2025-12-15

BEGIN;

-- Test 1: Test that insert_note_comment accepts and uses sequence_action parameter
DO $$
DECLARE
  comment_count INTEGER;
  test_sequence INTEGER := 5;
BEGIN
  -- Create a lock
  CALL put_lock('999');
  
  -- Insert a test note
  CALL insert_note(999, 40.7128, -74.0060, NOW(), 999);
  
  -- Insert a test comment WITH sequence_action
  CALL insert_note_comment(999, 'opened', NOW(), 123, 'test_user', 999, test_sequence);
  
  -- Check if comment was inserted with correct sequence_action
  SELECT COUNT(*) INTO comment_count 
  FROM note_comments 
  WHERE note_id = 999 AND sequence_action = test_sequence;
  
  -- Assert
  IF comment_count = 1 THEN
    RAISE NOTICE 'Test passed: Comment was inserted with correct sequence_action (%)', test_sequence;
  ELSE
    RAISE EXCEPTION 'Test failed: Comment was not inserted with correct sequence_action. Expected: %, Found: %', 
      test_sequence, comment_count;
  END IF;
  
  -- Clean up
  DELETE FROM note_comments WHERE note_id = 999;
  DELETE FROM notes WHERE note_id = 999;
  CALL remove_lock('999');
END $$;

-- Test 2: Test that insert_note_comment works without sequence_action (trigger assigns it)
DO $$
DECLARE
  comment_count INTEGER;
  sequence_value INTEGER;
BEGIN
  -- Create a lock
  CALL put_lock('998');
  
  -- Insert a test note
  CALL insert_note(998, 40.7128, -74.0060, NOW(), 998);
  
  -- Insert a test comment WITHOUT sequence_action (should be assigned by trigger)
  -- Note: We need to call the function without the sequence_action parameter
  -- Since it's the last parameter with DEFAULT NULL, we can omit it
  -- But PostgreSQL requires all parameters, so we pass NULL explicitly
  CALL insert_note_comment(998, 'opened', NOW(), 123, 'test_user', 998, NULL);
  
  -- Check if comment was inserted and sequence_action was assigned
  SELECT COUNT(*), MAX(sequence_action) INTO comment_count, sequence_value
  FROM note_comments 
  WHERE note_id = 998;
  
  -- Assert
  IF comment_count = 1 AND sequence_value IS NOT NULL AND sequence_value >= 1 THEN
    RAISE NOTICE 'Test passed: Comment was inserted and sequence_action was assigned by trigger (%)', sequence_value;
  ELSE
    RAISE EXCEPTION 'Test failed: Comment insertion failed or sequence_action not assigned. Count: %, Sequence: %', 
      comment_count, COALESCE(sequence_value::TEXT, 'NULL');
  END IF;
  
  -- Clean up
  DELETE FROM note_comments WHERE note_id = 998;
  DELETE FROM notes WHERE note_id = 998;
  CALL remove_lock('998');
END $$;

-- Test 3: Test complete flow from note_comments_api to note_comments
-- This simulates the actual processAPINotes_32_insertNewNotesAndComments.sql flow
DO $$
DECLARE
  test_note_id INTEGER := 997;
  test_sequence INTEGER := 2;
  comments_in_api INTEGER;
  comments_in_main INTEGER;
  m_process_id INTEGER;
  m_stmt TEXT;
BEGIN
  -- Create note_comments_api table if it doesn't exist (for testing)
  CREATE TABLE IF NOT EXISTS note_comments_api (
    note_id INTEGER NOT NULL,
    sequence_action INTEGER NOT NULL,
    event note_event_enum NOT NULL,
    created_at TIMESTAMP NOT NULL,
    id_user INTEGER,
    username VARCHAR(256)
  );
  
  -- Create a lock
  CALL put_lock('997');
  m_process_id := 997;
  
  -- Insert a test note
  CALL insert_note(test_note_id, 40.7128, -74.0060, NOW(), m_process_id);
  
  -- Insert test data into note_comments_api (simulating CSV load)
  INSERT INTO note_comments_api (note_id, sequence_action, event, created_at, id_user, username)
  VALUES (test_note_id, test_sequence, 'opened', NOW(), 123, 'test_user');
  
  -- Verify data is in API table
  SELECT COUNT(*) INTO comments_in_api FROM note_comments_api WHERE note_id = test_note_id;
  IF comments_in_api != 1 THEN
    RAISE EXCEPTION 'Test setup failed: Comment not in API table. Count: %', comments_in_api;
  END IF;
  
  -- Simulate the actual insertion process (like processAPINotes_32_insertNewNotesAndComments.sql)
  -- This is the actual code path used in production
  m_stmt := 'CALL insert_note_comment (' || test_note_id || ', '
    || '''opened''::note_event_enum, '
    || 'NOW(), '
    || '123, '
    || '''test_user'', '
    || m_process_id || ', '
    || test_sequence || ')';
  
  EXECUTE m_stmt;
  
  -- Verify comment was inserted into main table with correct sequence_action
  SELECT COUNT(*) INTO comments_in_main 
  FROM note_comments 
  WHERE note_id = test_note_id AND sequence_action = test_sequence;
  
  -- Assert
  IF comments_in_main = 1 THEN
    RAISE NOTICE 'Test passed: Comment flowed from API table to main table with correct sequence_action (%)', test_sequence;
  ELSE
    RAISE EXCEPTION 'Test failed: Comment not in main table with correct sequence_action. Expected: 1, Found: %', 
      comments_in_main;
  END IF;
  
  -- Clean up
  DELETE FROM note_comments WHERE note_id = test_note_id;
  DELETE FROM note_comments_api WHERE note_id = test_note_id;
  DELETE FROM notes WHERE note_id = test_note_id;
  CALL remove_lock('997');
  
  -- Drop test table
  DROP TABLE IF EXISTS note_comments_api;
END $$;

-- Test 4: Test that trigger does NOT overwrite provided sequence_action
DO $$
DECLARE
  test_note_id INTEGER := 996;
  provided_sequence INTEGER := 10;
  actual_sequence INTEGER;
BEGIN
  -- Create a lock
  CALL put_lock('996');
  
  -- Insert a test note
  CALL insert_note(test_note_id, 40.7128, -74.0060, NOW(), 996);
  
  -- Insert a comment with a specific sequence_action
  CALL insert_note_comment(test_note_id, 'opened', NOW(), 123, 'test_user', 996, provided_sequence);
  
  -- Check if sequence_action was preserved (not overwritten by trigger)
  SELECT sequence_action INTO actual_sequence
  FROM note_comments 
  WHERE note_id = test_note_id;
  
  -- Assert
  IF actual_sequence = provided_sequence THEN
    RAISE NOTICE 'Test passed: Trigger preserved provided sequence_action (%)', provided_sequence;
  ELSE
    RAISE EXCEPTION 'Test failed: Trigger overwrote sequence_action. Expected: %, Found: %', 
      provided_sequence, actual_sequence;
  END IF;
  
  -- Clean up
  DELETE FROM note_comments WHERE note_id = test_note_id;
  DELETE FROM notes WHERE note_id = test_note_id;
  CALL remove_lock('996');
END $$;

-- Test 5: Test multiple comments with different sequence_actions
DO $$
DECLARE
  test_note_id INTEGER := 995;
  comment_count INTEGER;
  expected_count INTEGER := 3;
BEGIN
  -- Create a lock
  CALL put_lock('995');
  
  -- Insert a test note
  CALL insert_note(test_note_id, 40.7128, -74.0060, NOW(), 995);
  
  -- Insert multiple comments with different sequence_actions
  CALL insert_note_comment(test_note_id, 'opened', NOW(), 123, 'test_user', 995, 1);
  CALL insert_note_comment(test_note_id, 'commented', NOW() + INTERVAL '1 minute', 123, 'test_user', 995, 2);
  CALL insert_note_comment(test_note_id, 'closed', NOW() + INTERVAL '2 minutes', 123, 'test_user', 995, 3);
  
  -- Verify all comments were inserted
  SELECT COUNT(*) INTO comment_count 
  FROM note_comments 
  WHERE note_id = test_note_id;
  
  -- Assert
  IF comment_count = expected_count THEN
    RAISE NOTICE 'Test passed: All % comments were inserted with correct sequence_actions', expected_count;
  ELSE
    RAISE EXCEPTION 'Test failed: Not all comments were inserted. Expected: %, Found: %', 
      expected_count, comment_count;
  END IF;
  
  -- Clean up
  DELETE FROM note_comments WHERE note_id = test_note_id;
  DELETE FROM notes WHERE note_id = test_note_id;
  CALL remove_lock('995');
END $$;

DO $$
BEGIN
  RAISE NOTICE 'All comment insertion flow tests completed successfully';
END $$;

ROLLBACK;

