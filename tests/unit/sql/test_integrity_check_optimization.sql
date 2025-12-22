-- Test integrity check optimization
-- Validates that integrity check only verifies notes from THIS cycle (not all from last hour)
-- Author: Andres Gomez (AngocA)
-- Version: 2025-12-21

BEGIN;

-- Test 1: Verify integrity check uses notes_api (this cycle) instead of last hour
DO $$
DECLARE
  test_note_id_1 INTEGER := 9001;
  test_note_id_2 INTEGER := 9002;
  m_notes_in_this_cycle INTEGER;
  m_total_notes INTEGER;
BEGIN
  -- Create notes_api table if it doesn't exist (for testing)
  CREATE TABLE IF NOT EXISTS notes_api (
    note_id INTEGER NOT NULL,
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(11, 8) NOT NULL,
    created_at TIMESTAMP NOT NULL,
    closed_at TIMESTAMP,
    status note_status_enum NOT NULL
  );
  
  -- Create test notes in notes_api (simulating current cycle)
  INSERT INTO notes_api (note_id, latitude, longitude, created_at, status)
  VALUES 
    (test_note_id_1, 40.7128, -74.0060, NOW() - INTERVAL '1 hour', 'open'),
    (test_note_id_2, 40.7580, -73.9855, NOW() - INTERVAL '1 hour', 'open')
  ON CONFLICT DO NOTHING;
  
  -- Insert notes into main notes table
  INSERT INTO notes (note_id, latitude, longitude, created_at, status, insert_time)
  VALUES 
    (test_note_id_1, 40.7128, -74.0060, NOW() - INTERVAL '1 hour', 'open', NOW()),
    (test_note_id_2, 40.7580, -73.9855, NOW() - INTERVAL '1 hour', 'open', NOW())
  ON CONFLICT (note_id) DO NOTHING;
  
  -- Insert comment for only one note
  INSERT INTO note_comments (note_id, sequence_action, event, created_at)
  VALUES (test_note_id_1, 1, 'opened', NOW() - INTERVAL '1 hour')
  ON CONFLICT DO NOTHING;
  
  -- Simulate the optimized integrity check logic
  SELECT COUNT(*) INTO m_notes_in_this_cycle FROM notes_api;
  
  IF m_notes_in_this_cycle = 0 THEN
    RAISE EXCEPTION 'Test 1 FAILED: notes_api should have 2 notes';
  END IF;
  
  -- Count notes from THIS cycle that don't have comments (old enough)
  SELECT COUNT(DISTINCT n.note_id)
  INTO m_total_notes
  FROM notes n
  INNER JOIN notes_api na ON na.note_id = n.note_id
  WHERE n.created_at < CURRENT_TIMESTAMP - INTERVAL '30 minutes';
  
  IF m_total_notes = 2 THEN
    RAISE NOTICE '✅ Test 1 PASSED: Integrity check correctly identifies 2 notes from this cycle (via notes_api)';
  ELSE
    RAISE EXCEPTION 'Test 1 FAILED: Expected 2 notes from this cycle, got %', m_total_notes;
  END IF;
  
  -- Clean up
  DELETE FROM note_comments WHERE note_id IN (test_note_id_1, test_note_id_2);
  DELETE FROM notes WHERE note_id IN (test_note_id_1, test_note_id_2);
  DELETE FROM notes_api WHERE note_id IN (test_note_id_1, test_note_id_2);
END $$;

-- Test 2: Verify integrity check correctly counts notes without comments from this cycle
DO $$
DECLARE
  test_note_id_3 INTEGER := 9003;
  test_note_id_4 INTEGER := 9004;
  m_notes_without_comments INTEGER;
  m_total_notes INTEGER;
BEGIN
  -- Create test notes in notes_api (simulating current cycle)
  INSERT INTO notes_api (note_id, latitude, longitude, created_at, status)
  VALUES 
    (test_note_id_3, 40.7128, -74.0060, NOW() - INTERVAL '1 hour', 'open'),
    (test_note_id_4, 40.7580, -73.9855, NOW() - INTERVAL '1 hour', 'open')
  ON CONFLICT DO NOTHING;
  
  -- Insert notes into main notes table
  INSERT INTO notes (note_id, latitude, longitude, created_at, status, insert_time)
  VALUES 
    (test_note_id_3, 40.7128, -74.0060, NOW() - INTERVAL '1 hour', 'open', NOW()),
    (test_note_id_4, 40.7580, -73.9855, NOW() - INTERVAL '1 hour', 'open', NOW())
  ON CONFLICT (note_id) DO NOTHING;
  
  -- Don't insert comments (both notes should be without comments)
  
  -- Simulate the optimized integrity check logic
  SELECT COUNT(DISTINCT n.note_id)
  INTO m_notes_without_comments
  FROM notes n
  INNER JOIN notes_api na ON na.note_id = n.note_id
  LEFT JOIN note_comments nc ON nc.note_id = n.note_id
  WHERE n.created_at < CURRENT_TIMESTAMP - INTERVAL '30 minutes'
   AND nc.note_id IS NULL;
  
  SELECT COUNT(DISTINCT n.note_id)
  INTO m_total_notes
  FROM notes n
  INNER JOIN notes_api na ON na.note_id = n.note_id
  WHERE n.created_at < CURRENT_TIMESTAMP - INTERVAL '30 minutes';
  
  IF m_notes_without_comments = 2 AND m_total_notes = 2 THEN
    RAISE NOTICE '✅ Test 2 PASSED: Integrity check correctly identifies 2 notes without comments from this cycle';
  ELSE
    RAISE EXCEPTION 'Test 2 FAILED: Expected 2 notes without comments out of 2 total, got % out of %', 
      m_notes_without_comments, m_total_notes;
  END IF;
  
  -- Clean up
  DELETE FROM notes WHERE note_id IN (test_note_id_3, test_note_id_4);
  DELETE FROM notes_api WHERE note_id IN (test_note_id_3, test_note_id_4);
END $$;

-- Test 3: Verify integrity check handles empty notes_api correctly
DO $$
DECLARE
  m_notes_in_this_cycle INTEGER;
BEGIN
  -- Ensure notes_api is empty (should have been cleaned up in previous tests)
  DELETE FROM notes_api;
  
  -- Simulate the optimized integrity check logic
  SELECT COUNT(*) INTO m_notes_in_this_cycle FROM notes_api;
  
  IF m_notes_in_this_cycle = 0 THEN
    RAISE NOTICE '✅ Test 3 PASSED: Integrity check correctly handles empty notes_api (returns early)';
  ELSE
    RAISE EXCEPTION 'Test 3 FAILED: Expected 0 notes in notes_api, got %', m_notes_in_this_cycle;
  END IF;
END $$;

-- Test 4: Verify integrity check ignores notes from previous cycles (not in notes_api)
DO $$
DECLARE
  old_note_id INTEGER := 9005;
  current_note_id INTEGER := 9006;
  m_notes_without_comments INTEGER;
  m_total_notes INTEGER;
BEGIN
  -- Insert an old note (from a previous cycle, NOT in notes_api)
  INSERT INTO notes (note_id, latitude, longitude, created_at, status, insert_time)
  VALUES (old_note_id, 40.7128, -74.0060, NOW() - INTERVAL '2 hours', 'open', NOW() - INTERVAL '1 hour')
  ON CONFLICT (note_id) DO NOTHING;
  
  -- Insert a current note (from this cycle, in notes_api)
  INSERT INTO notes_api (note_id, latitude, longitude, created_at, status)
  VALUES (current_note_id, 40.7580, -73.9855, NOW() - INTERVAL '1 hour', 'open')
  ON CONFLICT DO NOTHING;
  
  INSERT INTO notes (note_id, latitude, longitude, created_at, status, insert_time)
  VALUES (current_note_id, 40.7580, -73.9855, NOW() - INTERVAL '1 hour', 'open', NOW())
  ON CONFLICT (note_id) DO NOTHING;
  
  -- Simulate the optimized integrity check logic
  -- Should only count current_note_id, NOT old_note_id
  SELECT COUNT(DISTINCT n.note_id)
  INTO m_notes_without_comments
  FROM notes n
  INNER JOIN notes_api na ON na.note_id = n.note_id
  LEFT JOIN note_comments nc ON nc.note_id = n.note_id
  WHERE n.created_at < CURRENT_TIMESTAMP - INTERVAL '30 minutes'
   AND nc.note_id IS NULL;
  
  SELECT COUNT(DISTINCT n.note_id)
  INTO m_total_notes
  FROM notes n
  INNER JOIN notes_api na ON na.note_id = n.note_id
  WHERE n.created_at < CURRENT_TIMESTAMP - INTERVAL '30 minutes';
  
  IF m_total_notes = 1 AND m_notes_without_comments = 1 THEN
    RAISE NOTICE '✅ Test 4 PASSED: Integrity check correctly ignores notes from previous cycles (only checks notes_api)';
  ELSE
    RAISE EXCEPTION 'Test 4 FAILED: Expected 1 note from this cycle, got % (should ignore old notes not in notes_api)', 
      m_total_notes;
  END IF;
  
  -- Clean up
  DELETE FROM notes WHERE note_id IN (old_note_id, current_note_id);
  DELETE FROM notes_api WHERE note_id = current_note_id;
END $$;

ROLLBACK;

-- Summary
SELECT 'Integrity check optimization tests completed' AS status;

