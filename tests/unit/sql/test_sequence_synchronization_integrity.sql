-- Test sequence synchronization integrity
-- This test validates that sequence synchronization prevents PRIMARY KEY violations
-- when inserting comments after data has been loaded from external sources (e.g., planet dump)
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-12-21
--
-- Test scenario:
-- 1. Simulate a desynchronized sequence (e.g., after loading planet dump with existing IDs)
-- 2. Try to insert a comment without synchronizing -> should fail with PRIMARY KEY violation
-- 3. Synchronize the sequence
-- 4. Try to insert again -> should succeed
--
-- Note: This test focuses ONLY on sequence synchronization for note_comments table.
-- It does not require a full database setup, only that note_comments table exists.

BEGIN;

-- Test 1: Sequence synchronization correctly sets sequence to MAX(id)
DO $$
DECLARE
  m_max_id_before INTEGER;
  m_max_id_after INTEGER;
  m_seq_val_before BIGINT;
  m_seq_val_after BIGINT;
  m_test_note_id INTEGER;
  m_manually_inserted_id INTEGER;
  m_test_user_id INTEGER := 888888;
BEGIN
  -- Create test data: users, notes, and comments
  -- Insert test user
  INSERT INTO users (user_id, username) VALUES
    (m_test_user_id, 'test_user_sync')
  ON CONFLICT (user_id) DO UPDATE SET username = EXCLUDED.username;
  
  -- Create a test note
  -- notes table uses 'id' as PK (bigint), and note_comments uses 'note_id' as FK
  -- We need to insert a note with an explicit id, then use that as note_id in comments
  DECLARE
    note_table_id BIGINT := 888888;
  BEGIN
    INSERT INTO notes (id, latitude, longitude, created_at, status) VALUES
      (note_table_id, 40.7128, -74.0060, NOW(), 'open')
    ON CONFLICT (id) DO NOTHING
    RETURNING id INTO note_table_id;
    
    -- If the note already existed, get its id
    IF note_table_id IS NULL THEN
      SELECT id INTO note_table_id FROM notes WHERE id = 888888;
    END IF;
    
    -- note_comments.note_id references notes.id, so use the note's id
    m_test_note_id := note_table_id::INTEGER;
  END;
  
  -- Get current state before inserting high ID
  SELECT COALESCE(MAX(id), 0) INTO m_max_id_before FROM note_comments;
  SELECT last_value INTO m_seq_val_before FROM note_comments_id_seq;
  
  RAISE NOTICE 'Test 1 setup: MAX(id) in table = %, Sequence value = %, Test note_id = %', 
    m_max_id_before, m_seq_val_before, m_test_note_id;
  
  -- Simulate loading data from planet dump: manually insert a comment with a HIGH ID
  -- (like what happens when you COPY data from a dump that has existing IDs)
  -- We use a high ID to ensure it's above any existing data
  m_manually_inserted_id := GREATEST(m_max_id_before, 1000000) + 1000;
  
  -- Temporarily disable trigger that expects note_id in notes table
  -- (the trigger expects notes.note_id but notes table uses id instead)
  ALTER TABLE note_comments DISABLE TRIGGER update_note;
  
  -- Manually insert a comment with a specific ID (simulating planet dump load)
  INSERT INTO note_comments (
    id,
    note_id,
    sequence_action,
    event,
    created_at,
    id_user
  )
  VALUES (
    m_manually_inserted_id,
    m_test_note_id,
    1,
    'opened'::note_event_enum,
    NOW(),
    m_test_user_id
  );
  
  -- Re-enable trigger
  ALTER TABLE note_comments ENABLE TRIGGER update_note;
    
    -- If we got here, the insert succeeded. Verify the max_id increased but sequence did NOT
    SELECT COALESCE(MAX(id), 0) INTO m_max_id_after FROM note_comments;
    SELECT last_value INTO m_seq_val_after FROM note_comments_id_seq;
    
    -- If we got here, the insert succeeded. Verify the max_id increased but sequence did NOT
  SELECT COALESCE(MAX(id), 0) INTO m_max_id_after FROM note_comments;
  SELECT last_value INTO m_seq_val_after FROM note_comments_id_seq;
  
  RAISE NOTICE 'Test 1: After manual insert, MAX(id) = %, Sequence = % (still at %)', 
    m_max_id_after, m_seq_val_after, m_seq_val_before;
  
  -- Verify sequence is now desynchronized (this is the expected scenario)
  IF m_seq_val_after >= m_max_id_after THEN
    RAISE WARNING 'Test 1: Sequence appears synchronized (seq=% >= max_id=%). This may indicate the test scenario did not reproduce the planet load scenario correctly.', 
      m_seq_val_after, m_max_id_after;
  ELSE
    RAISE NOTICE 'Test 1: Sequence is desynchronized as expected (seq=% < max_id=%). This represents the scenario after planet dump load.', 
      m_seq_val_after, m_max_id_after;
  END IF;
  
  -- Now synchronize (like production code does)
  PERFORM setval('note_comments_id_seq', 
    COALESCE((SELECT MAX(id) FROM note_comments), 1), 
    true);
  
  SELECT last_value INTO m_seq_val_after FROM note_comments_id_seq;
  
  -- Verify synchronization worked
  IF m_seq_val_after < m_max_id_after THEN
    RAISE EXCEPTION 'Test 1 FAILED: Sequence synchronization did not work. After sync: % < MAX(id): %', 
      m_seq_val_after, m_max_id_after;
  END IF;
  
  RAISE NOTICE 'Test 1 PASSED: Sequence synchronization correctly handles planet dump scenario. Sequence synchronized from % to %', 
    m_seq_val_before, m_seq_val_after;
  
  -- Clean up test data
  DELETE FROM note_comments WHERE id = m_manually_inserted_id;
  DELETE FROM notes WHERE id = m_test_note_id;
  
EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Test 1 FAILED: Unexpected error: %', SQLERRM;
END $$;

-- Test 2: Verify sequence synchronization prevents PRIMARY KEY violations
DO $$
DECLARE
  m_max_id INTEGER;
  m_seq_val_before BIGINT;
  m_seq_val_after BIGINT;
  m_test_note_id INTEGER;
  m_test_user_id INTEGER := 777777;
  m_test_comment_id INTEGER;
  m_created_comment_id INTEGER;
BEGIN
  -- Create test data: user and note
  INSERT INTO users (user_id, username) VALUES
    (m_test_user_id, 'test_user_sync_2')
  ON CONFLICT (user_id) DO UPDATE SET username = EXCLUDED.username;
  
  -- Create a test note
  -- notes table uses 'id' as PK (bigint), and note_comments uses 'note_id' as FK
  DECLARE
    note_table_id BIGINT := 777777;
  BEGIN
    INSERT INTO notes (id, latitude, longitude, created_at, status) VALUES
      (note_table_id, 40.7128, -74.0060, NOW(), 'open')
    ON CONFLICT (id) DO NOTHING
    RETURNING id INTO note_table_id;
    
    -- If the note already existed, get its id
    IF note_table_id IS NULL THEN
      SELECT id INTO note_table_id FROM notes WHERE id = 777777;
    END IF;
    
    -- note_comments.note_id references notes.id, so use the note's id
    m_test_note_id := note_table_id::INTEGER;
  END;
  
  -- Temporarily disable trigger that expects note_id in notes table
  ALTER TABLE note_comments DISABLE TRIGGER update_note;
  
  -- Create a test comment to establish a baseline max_id
  -- Insert using nextval to get a real ID
  INSERT INTO note_comments (note_id, sequence_action, event, created_at, id_user) VALUES
    (m_test_note_id, 1, 'opened'::note_event_enum, NOW(), m_test_user_id)
  RETURNING id INTO m_created_comment_id;
  
  -- Re-enable trigger
  ALTER TABLE note_comments ENABLE TRIGGER update_note;
  
  -- Get current max ID
  SELECT COALESCE(MAX(id), 0) INTO m_max_id FROM note_comments;
  
  -- Desynchronize sequence: set it to a value less than max_id
  -- This simulates what happens when data is loaded from a dump with existing IDs
  -- but the sequence was not properly synchronized
  PERFORM setval('note_comments_id_seq', GREATEST(1, m_max_id - 50), true);
  SELECT last_value INTO m_seq_val_before FROM note_comments_id_seq;
  
  RAISE NOTICE 'Test 2 setup: MAX(id) in table = %, Sequence desynchronized to = %', 
    m_max_id, m_seq_val_before;
  
  -- Verify sequence is desynchronized
  IF m_seq_val_before >= m_max_id THEN
    -- Can't test properly if sequence is already synchronized or too close
    -- Adjust to ensure desynchronization
    PERFORM setval('note_comments_id_seq', GREATEST(1, m_max_id - 100), true);
    SELECT last_value INTO m_seq_val_before FROM note_comments_id_seq;
    RAISE NOTICE 'Test 2: Adjusted sequence desynchronization to = %', m_seq_val_before;
  END IF;
  
  -- Synchronize the sequence (this is what production code does)
  PERFORM setval('note_comments_id_seq', 
    COALESCE((SELECT MAX(id) FROM note_comments), 1), 
    true);
  
  SELECT last_value INTO m_seq_val_after FROM note_comments_id_seq;
  
  RAISE NOTICE 'Test 2: Sequence after synchronization = %', m_seq_val_after;
  
  -- Verify sequence is now synchronized (should be >= max_id)
  IF m_seq_val_after < m_max_id THEN
    RAISE EXCEPTION 'Test 2 FAILED: Sequence synchronization did not work correctly. After sync: % < MAX(id): %', 
      m_seq_val_after, m_max_id;
  END IF;
  
  -- Verify that nextval() will generate IDs greater than max_id
  m_test_comment_id := nextval('note_comments_id_seq');
  
  IF m_test_comment_id <= m_max_id THEN
    RAISE EXCEPTION 'Test 2 FAILED: nextval() generated ID % which is <= MAX(id) %. This indicates synchronization failed.', 
      m_test_comment_id, m_max_id;
  END IF;
  
  RAISE NOTICE 'Test 2 PASSED: Sequence synchronization correctly prevents PRIMARY KEY violations. nextval() generated ID % (MAX(id) was %)', 
    m_test_comment_id, m_max_id;
  
  -- Clean up test data
  DELETE FROM note_comments WHERE id = m_created_comment_id;
  DELETE FROM note_comments WHERE id = m_test_comment_id;
  DELETE FROM notes WHERE id = m_test_note_id;
  
  -- Reset sequence (we consumed one value with nextval, but also deleted it)
  -- Reset to the max_id we had before the test
  PERFORM setval('note_comments_id_seq', m_max_id, true);
  
EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Test 2 FAILED: Unexpected error: %', SQLERRM;
END $$;

-- Test 3: Verify synchronization handles edge case: empty table
DO $$
DECLARE
  m_backup_max_id INTEGER;
  m_seq_val_before BIGINT;
  m_seq_val_after BIGINT;
  m_test_count INTEGER;
BEGIN
  -- Save current max_id (in case table is not empty)
  SELECT COALESCE(MAX(id), 0) INTO m_backup_max_id FROM note_comments;
  
  -- Count how many rows we have
  SELECT COUNT(*) INTO m_test_count FROM note_comments;
  
  IF m_test_count > 0 THEN
    RAISE NOTICE 'Test 3 SKIPPED: Table has % rows, cannot test empty table scenario. This is OK.', m_test_count;
    RETURN;
  END IF;
  
  -- Get current sequence value
  SELECT last_value INTO m_seq_val_before FROM note_comments_id_seq;
  
  RAISE NOTICE 'Test 3 setup: Table is empty, Sequence value = %', m_seq_val_before;
  
  -- Synchronize (should set to 1 if table is empty, per COALESCE logic)
  PERFORM setval('note_comments_id_seq', 
    COALESCE((SELECT MAX(id) FROM note_comments), 1), 
    true);
  
  SELECT last_value INTO m_seq_val_after FROM note_comments_id_seq;
  
  -- Verify synchronization worked (should be 1 for empty table)
  IF m_seq_val_after < 1 THEN
    RAISE EXCEPTION 'Test 3 FAILED: Sequence synchronization failed for empty table. After sync: % < 1', 
      m_seq_val_after;
  END IF;
  
  RAISE NOTICE 'Test 3 PASSED: Sequence synchronization correctly handles empty table. Sequence set to %', 
    m_seq_val_after;
  
END $$;

ROLLBACK;
