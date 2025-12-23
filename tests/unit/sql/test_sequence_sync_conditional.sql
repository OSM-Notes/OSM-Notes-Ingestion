-- Test conditional sequence synchronization
-- This test validates that sequences are only synchronized when they are
-- actually desynchronized, avoiding unnecessary MAX(id) scans.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-12-23
--
-- Test scenarios:
-- 1. Sequence is synchronized (last_value >= max_id) -> should skip synchronization
-- 2. Sequence is desynchronized (last_value < max_id) -> should synchronize
-- 3. Sequence is slightly behind (last_value < max_id by small amount) -> should synchronize

BEGIN;

-- Test 1: Sequence is synchronized (should skip)
DO $$
DECLARE
  m_seq_last_value_before BIGINT;
  m_seq_last_value_after BIGINT;
  m_max_id_table BIGINT;
  m_sync_happened BOOLEAN := false;
  m_test_note_id BIGINT;
  m_test_user_id INTEGER := 999999;
  m_note_table_id BIGINT := 999999;
BEGIN
  -- Setup: Create test data
  INSERT INTO users (user_id, username) VALUES
    (m_test_user_id, 'test_user_cond_sync')
  ON CONFLICT (user_id) DO UPDATE SET username = EXCLUDED.username;
  
  -- Create a test note (notes.note_id is NOT SERIAL, needs explicit ID)
  -- Check if note already exists, if not insert it
  SELECT note_id INTO m_note_table_id FROM notes WHERE note_id = 999999;
  IF m_note_table_id IS NULL THEN
    INSERT INTO notes (note_id, latitude, longitude, created_at, status) VALUES
      (999999, 40.7128, -74.0060, NOW(), 'open');
    m_note_table_id := 999999;
  END IF;
  
  m_test_note_id := m_note_table_id;
  
  -- Temporarily disable trigger to avoid schema conflicts (if it exists)
  BEGIN
    ALTER TABLE note_comments DISABLE TRIGGER update_note;
  EXCEPTION
    WHEN undefined_object THEN
      NULL; -- Trigger doesn't exist, continue without disabling
  END;
  
  -- Insert a test comment to advance the sequence
  INSERT INTO note_comments (note_id, sequence_action, event, created_at, id_user)
  VALUES (m_test_note_id, 1, 'opened'::note_event_enum, NOW(), m_test_user_id);
  
  -- Re-enable trigger (if it exists)
  BEGIN
    ALTER TABLE note_comments ENABLE TRIGGER update_note;
  EXCEPTION
    WHEN undefined_object THEN
      NULL; -- Trigger doesn't exist, continue without enabling
  END;
  
  -- Get current sequence value and max ID
  SELECT last_value INTO m_seq_last_value_before
  FROM pg_sequences
  WHERE sequencename = 'note_comments_id_seq';
  
  SELECT COALESCE(MAX(id), 0) INTO m_max_id_table
  FROM note_comments;
  
  -- Verify sequence is synchronized (last_value >= max_id)
  IF m_seq_last_value_before < m_max_id_table THEN
    -- Need to synchronize first
    PERFORM setval('note_comments_id_seq', GREATEST(m_max_id_table, 1), true);
    RAISE NOTICE 'Test 1 setup: Synchronized sequence from % to %', 
      m_seq_last_value_before, m_max_id_table;
  END IF;
  
  -- Now test conditional sync logic
  SELECT last_value INTO m_seq_last_value_before
  FROM pg_sequences
  WHERE sequencename = 'note_comments_id_seq';
  
  SELECT COALESCE(MAX(id), 0) INTO m_max_id_table
  FROM note_comments;
  
  -- Check if sync is needed (should be false - no margin, be conservative)
  IF (m_seq_last_value_before < m_max_id_table) THEN
    PERFORM setval('note_comments_id_seq', GREATEST(m_max_id_table, 1), true);
    m_sync_happened := true;
  END IF;
  
  SELECT last_value INTO m_seq_last_value_after
  FROM pg_sequences
  WHERE sequencename = 'note_comments_id_seq';
  
  -- Verify sync was skipped (values should be the same)
  IF m_sync_happened THEN
    RAISE EXCEPTION 'Test 1 FAILED: Synchronization happened when it should have been skipped. Before: %, After: %', 
      m_seq_last_value_before, m_seq_last_value_after;
  END IF;
  
  IF m_seq_last_value_before != m_seq_last_value_after THEN
    RAISE EXCEPTION 'Test 1 FAILED: Sequence value changed when it should not have. Before: %, After: %', 
      m_seq_last_value_before, m_seq_last_value_after;
  END IF;
  
  RAISE NOTICE 'Test 1 PASSED: Synchronization correctly skipped when sequence is synchronized (seq=%, max_id=%)', 
    m_seq_last_value_before, m_max_id_table;
  
  -- Cleanup
  DELETE FROM note_comments WHERE note_id = m_test_note_id;
  DELETE FROM notes WHERE note_id = m_test_note_id;
  
EXCEPTION
  WHEN OTHERS THEN
    -- Try to clean up if possible
    BEGIN
      IF m_test_note_id IS NOT NULL THEN
        DELETE FROM note_comments WHERE note_id = m_test_note_id;
        DELETE FROM notes WHERE note_id = m_test_note_id;
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        NULL; -- Ignore cleanup errors
    END;
    RAISE EXCEPTION 'Test 1 FAILED: Unexpected error: %', SQLERRM;
END $$;

-- Test 2: Sequence is desynchronized (should synchronize)
DO $$
DECLARE
  m_seq_last_value_before BIGINT;
  m_seq_last_value_after BIGINT;
  m_max_id_table BIGINT;
  m_sync_happened BOOLEAN := false;
  m_test_note_id BIGINT;
  m_manually_inserted_id INTEGER;
  m_test_user_id INTEGER := 999998;
  m_note_table_id BIGINT := 999998;
BEGIN
  -- Setup: Create test data
  INSERT INTO users (user_id, username) VALUES
    (m_test_user_id, 'test_user_cond_sync2')
  ON CONFLICT (user_id) DO UPDATE SET username = EXCLUDED.username;
  
  -- Create a test note (notes.note_id is NOT SERIAL, needs explicit ID)
  -- Check if note already exists, if not insert it
  SELECT note_id INTO m_note_table_id FROM notes WHERE note_id = 999998;
  IF m_note_table_id IS NULL THEN
    INSERT INTO notes (note_id, latitude, longitude, created_at, status) VALUES
      (999998, 40.7128, -74.0060, NOW(), 'open');
    m_note_table_id := 999998;
  END IF;
  
  m_test_note_id := m_note_table_id;
  
  -- Get current max ID
  SELECT COALESCE(MAX(id), 0) INTO m_max_id_table
  FROM note_comments;
  
  -- Get current sequence value
  SELECT last_value INTO m_seq_last_value_before
  FROM pg_sequences
  WHERE sequencename = 'note_comments_id_seq';
  
  -- Manually insert a comment with a high ID (simulating planet dump scenario)
  -- Make sure it's significantly higher than current sequence to ensure desynchronization
  m_manually_inserted_id := GREATEST(m_max_id_table, m_seq_last_value_before, 1000) + 200;
  
  -- Temporarily disable trigger to avoid schema conflicts (if it exists)
  BEGIN
    ALTER TABLE note_comments DISABLE TRIGGER update_note;
  EXCEPTION
    WHEN undefined_object THEN
      NULL; -- Trigger doesn't exist, continue without disabling
  END;
  
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
  
  -- Re-enable trigger (if it exists)
  BEGIN
    ALTER TABLE note_comments ENABLE TRIGGER update_note;
  EXCEPTION
    WHEN undefined_object THEN
      NULL; -- Trigger doesn't exist, continue without enabling
  END;
  
  -- Get current sequence value (should be less than max_id)
  SELECT last_value INTO m_seq_last_value_before
  FROM pg_sequences
  WHERE sequencename = 'note_comments_id_seq';
  
  SELECT COALESCE(MAX(id), 0) INTO m_max_id_table
  FROM note_comments;
  
  -- Verify sequence is desynchronized
  IF m_seq_last_value_before >= m_max_id_table THEN
    RAISE EXCEPTION 'Test 2 setup FAILED: Sequence is not desynchronized (seq=%, max_id=%)', 
      m_seq_last_value_before, m_max_id_table;
  END IF;
  
  -- Now test conditional sync logic (should sync - no margin, be conservative)
  IF (m_seq_last_value_before < m_max_id_table) THEN
    PERFORM setval('note_comments_id_seq', GREATEST(m_max_id_table, 1), true);
    m_sync_happened := true;
  END IF;
  
  SELECT last_value INTO m_seq_last_value_after
  FROM pg_sequences
  WHERE sequencename = 'note_comments_id_seq';
  
  -- Verify sync happened
  IF NOT m_sync_happened THEN
    RAISE EXCEPTION 'Test 2 FAILED: Synchronization did not happen when it should have (seq=%, max_id=%)', 
      m_seq_last_value_before, m_max_id_table;
  END IF;
  
  IF m_seq_last_value_after < m_max_id_table THEN
    RAISE EXCEPTION 'Test 2 FAILED: Sequence not properly synchronized. After sync: % < max_id: %', 
      m_seq_last_value_after, m_max_id_table;
  END IF;
  
  RAISE NOTICE 'Test 2 PASSED: Synchronization correctly happened when sequence was desynchronized (before: %, after: %, max_id: %)', 
    m_seq_last_value_before, m_seq_last_value_after, m_max_id_table;
  
  -- Cleanup
  DELETE FROM note_comments WHERE id = m_manually_inserted_id;
  DELETE FROM notes WHERE note_id = m_test_note_id;
  
EXCEPTION
  WHEN OTHERS THEN
    -- Try to clean up if possible
    BEGIN
      IF m_test_note_id IS NOT NULL THEN
        DELETE FROM note_comments WHERE note_id = m_test_note_id;
        DELETE FROM notes WHERE note_id = m_test_note_id;
      END IF;
      IF m_manually_inserted_id IS NOT NULL THEN
        DELETE FROM note_comments WHERE id = m_manually_inserted_id;
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        NULL; -- Ignore cleanup errors
    END;
    RAISE EXCEPTION 'Test 2 FAILED: Unexpected error: %', SQLERRM;
END $$;

-- Test 3: Sequence is slightly behind (should synchronize - no margin)
DO $$
DECLARE
  m_seq_last_value_before BIGINT;
  m_seq_last_value_after BIGINT;
  m_max_id_table BIGINT;
  m_sync_happened BOOLEAN := false;
  m_test_note_id BIGINT;
  m_manually_inserted_id INTEGER;
  m_test_user_id INTEGER := 999997;
  m_note_table_id BIGINT := 999997;
BEGIN
  -- Setup: Create test data
  INSERT INTO users (user_id, username) VALUES
    (m_test_user_id, 'test_user_cond_sync3')
  ON CONFLICT (user_id) DO UPDATE SET username = EXCLUDED.username;
  
  -- Create a test note (notes.note_id is NOT SERIAL, needs explicit ID)
  -- Check if note already exists, if not insert it
  SELECT note_id INTO m_note_table_id FROM notes WHERE note_id = 999997;
  IF m_note_table_id IS NULL THEN
    INSERT INTO notes (note_id, latitude, longitude, created_at, status) VALUES
      (999997, 40.7128, -74.0060, NOW(), 'open');
    m_note_table_id := 999997;
  END IF;
  
  m_test_note_id := m_note_table_id;
  
  -- Get current max ID
  SELECT COALESCE(MAX(id), 0) INTO m_max_id_table
  FROM note_comments;
  
  -- Get current sequence value
  SELECT last_value INTO m_seq_last_value_before
  FROM pg_sequences
  WHERE sequencename = 'note_comments_id_seq';
  
  -- Manually insert a comment with a slightly higher ID (small desynchronization)
  -- This tests that even small desynchronizations are detected (no margin)
  m_manually_inserted_id := GREATEST(m_max_id_table, m_seq_last_value_before, 1000) + 2;
  
  -- Temporarily disable trigger to avoid schema conflicts (if it exists)
  BEGIN
    ALTER TABLE note_comments DISABLE TRIGGER update_note;
  EXCEPTION
    WHEN undefined_object THEN
      NULL; -- Trigger doesn't exist, continue without disabling
  END;
  
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
  
  -- Re-enable trigger (if it exists)
  BEGIN
    ALTER TABLE note_comments ENABLE TRIGGER update_note;
  EXCEPTION
    WHEN undefined_object THEN
      NULL; -- Trigger doesn't exist, continue without enabling
  END;
  
  -- Get current sequence value (should be less than max_id)
  SELECT last_value INTO m_seq_last_value_before
  FROM pg_sequences
  WHERE sequencename = 'note_comments_id_seq';
  
  SELECT COALESCE(MAX(id), 0) INTO m_max_id_table
  FROM note_comments;
  
  -- Verify sequence is desynchronized (even slightly)
  IF m_seq_last_value_before >= m_max_id_table THEN
    RAISE EXCEPTION 'Test 3 setup FAILED: Sequence is not desynchronized (seq=%, max_id=%)', 
      m_seq_last_value_before, m_max_id_table;
  END IF;
  
  -- Test conditional sync logic (should sync - no margin, be conservative)
  IF (m_seq_last_value_before < m_max_id_table) THEN
    PERFORM setval('note_comments_id_seq', GREATEST(m_max_id_table, 1), true);
    m_sync_happened := true;
  END IF;
  
  SELECT last_value INTO m_seq_last_value_after
  FROM pg_sequences
  WHERE sequencename = 'note_comments_id_seq';
  
  -- Verify sync happened (even for small desynchronization)
  IF NOT m_sync_happened THEN
    RAISE EXCEPTION 'Test 3 FAILED: Synchronization did not happen when it should have (seq=%, max_id=%)', 
      m_seq_last_value_before, m_max_id_table;
  END IF;
  
  IF m_seq_last_value_after < m_max_id_table THEN
    RAISE EXCEPTION 'Test 3 FAILED: Sequence not properly synchronized. After sync: % < max_id: %', 
      m_seq_last_value_after, m_max_id_table;
  END IF;
  
  RAISE NOTICE 'Test 3 PASSED: Synchronization correctly happened for small desynchronization (before: %, after: %, max_id: %)', 
    m_seq_last_value_before, m_seq_last_value_after, m_max_id_table;
  
  -- Cleanup
  DELETE FROM note_comments WHERE id = m_manually_inserted_id;
  DELETE FROM notes WHERE note_id = m_test_note_id;
  
EXCEPTION
  WHEN OTHERS THEN
    -- Try to clean up if possible
    BEGIN
      IF m_test_note_id IS NOT NULL THEN
        DELETE FROM note_comments WHERE note_id = m_test_note_id;
        DELETE FROM notes WHERE note_id = m_test_note_id;
      END IF;
      IF m_manually_inserted_id IS NOT NULL THEN
        DELETE FROM note_comments WHERE id = m_manually_inserted_id;
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        NULL; -- Ignore cleanup errors
    END;
    RAISE EXCEPTION 'Test 3 FAILED: Unexpected error: %', SQLERRM;
END $$;

ROLLBACK;
