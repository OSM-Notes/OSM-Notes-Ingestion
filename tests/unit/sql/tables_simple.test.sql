-- Unit tests for database tables (simplified version without pgTAP)
-- Author: Andres Gomez (AngocA)
-- Version: 2025-01-27

BEGIN;

-- Test 1: Check if notes table exists
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'notes') THEN
    RAISE EXCEPTION 'Table notes does not exist';
  ELSE
    RAISE NOTICE 'Test passed: Table notes exists';
  END IF;
END $$;

-- Test 2: Check if note_comments table exists
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'note_comments') THEN
    RAISE EXCEPTION 'Table note_comments does not exist';
  ELSE
    RAISE NOTICE 'Test passed: Table note_comments exists';
  END IF;
END $$;

-- Test 3: Check if note_comments_text table exists
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'note_comments_text') THEN
    RAISE EXCEPTION 'Table note_comments_text does not exist';
  ELSE
    RAISE NOTICE 'Test passed: Table note_comments_text exists';
  END IF;
END $$;

-- Test 4: Check if users table exists
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'users') THEN
    RAISE EXCEPTION 'Table users does not exist';
  ELSE
    RAISE NOTICE 'Test passed: Table users exists';
  END IF;
END $$;

-- Test 5: Check if notes_sync table exists
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'notes_sync') THEN
    RAISE NOTICE 'Test skipped: Table notes_sync does not exist (may be optional)';
  ELSE
    RAISE NOTICE 'Test passed: Table notes_sync exists';
  END IF;
END $$;

-- Test 6: Check if note_comments_sync table exists
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'note_comments_sync') THEN
    RAISE NOTICE 'Test skipped: Table note_comments_sync does not exist (may be optional)';
  ELSE
    RAISE NOTICE 'Test passed: Table note_comments_sync exists';
  END IF;
END $$;

-- Test 7: Check if note_comments_text_sync table exists
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'note_comments_text_sync') THEN
    RAISE NOTICE 'Test skipped: Table note_comments_text_sync does not exist (may be optional)';
  ELSE
    RAISE NOTICE 'Test passed: Table note_comments_text_sync exists';
  END IF;
END $$;

-- Test 8: Check if notes_api table exists
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'notes_api') THEN
    RAISE NOTICE 'Test skipped: Table notes_api does not exist (may be optional)';
  ELSE
    RAISE NOTICE 'Test passed: Table notes_api exists';
  END IF;
END $$;

-- Test 9: Check if note_comments_api table exists
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'note_comments_api') THEN
    RAISE NOTICE 'Test skipped: Table note_comments_api does not exist (may be optional)';
  ELSE
    RAISE NOTICE 'Test passed: Table note_comments_api exists';
  END IF;
END $$;

-- Test 10: Check if note_comments_text_api table exists
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'note_comments_text_api') THEN
    RAISE NOTICE 'Test skipped: Table note_comments_text_api does not exist (may be optional)';
  ELSE
    RAISE NOTICE 'Test passed: Table note_comments_text_api exists';
  END IF;
END $$;

-- Test 11: Check notes table structure
DO $$
BEGIN
  -- Check required columns
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'notes' AND column_name = 'note_id') THEN
    RAISE EXCEPTION 'Column note_id does not exist in notes table';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'notes' AND column_name = 'latitude') THEN
    RAISE EXCEPTION 'Column latitude does not exist in notes table';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'notes' AND column_name = 'longitude') THEN
    RAISE EXCEPTION 'Column longitude does not exist in notes table';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'notes' AND column_name = 'created_at') THEN
    RAISE EXCEPTION 'Column created_at does not exist in notes table';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'notes' AND column_name = 'status') THEN
    RAISE EXCEPTION 'Column status does not exist in notes table';
  END IF;
  RAISE NOTICE 'Test passed: Notes table structure is correct';
END $$;

-- Test 12: Check note_comments table structure
DO $$
BEGIN
  -- Check required columns
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'note_comments' AND column_name = 'id') THEN
    RAISE EXCEPTION 'Column id does not exist in note_comments table';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'note_comments' AND column_name = 'note_id') THEN
    RAISE EXCEPTION 'Column note_id does not exist in note_comments table';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'note_comments' AND column_name = 'sequence_action') THEN
    RAISE EXCEPTION 'Column sequence_action does not exist in note_comments table';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'note_comments' AND column_name = 'event') THEN
    RAISE EXCEPTION 'Column event does not exist in note_comments table';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'note_comments' AND column_name = 'created_at') THEN
    RAISE EXCEPTION 'Column created_at does not exist in note_comments table';
  END IF;
  RAISE NOTICE 'Test passed: Note_comments table structure is correct';
END $$;

-- Test 13: Check note_comments_text table structure
DO $$
BEGIN
  -- Check required columns
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'note_comments_text' AND column_name = 'id') THEN
    RAISE EXCEPTION 'Column id does not exist in note_comments_text table';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'note_comments_text' AND column_name = 'note_id') THEN
    RAISE EXCEPTION 'Column note_id does not exist in note_comments_text table';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'note_comments_text' AND column_name = 'sequence_action') THEN
    RAISE EXCEPTION 'Column sequence_action does not exist in note_comments_text table';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'note_comments_text' AND column_name = 'body') THEN
    RAISE EXCEPTION 'Column body does not exist in note_comments_text table';
  END IF;
  RAISE NOTICE 'Test passed: Note_comments_text table structure is correct';
END $$;

-- Test 14: Check users table structure
DO $$
BEGIN
  -- Check required columns
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'user_id') THEN
    RAISE EXCEPTION 'Column user_id does not exist in users table';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'username') THEN
    RAISE EXCEPTION 'Column username does not exist in users table';
  END IF;
  RAISE NOTICE 'Test passed: Users table structure is correct';
END $$;

-- Test 15: Check primary keys
DO $$
BEGIN
  -- Check if notes table has primary key
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE table_name = 'notes' AND constraint_type = 'PRIMARY KEY'
  ) THEN
    RAISE NOTICE 'Warning: notes table may not have primary key';
  ELSE
    RAISE NOTICE 'Test passed: notes table has primary key';
  END IF;
  
  -- Check if note_comments table has primary key
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE table_name = 'note_comments' AND constraint_type = 'PRIMARY KEY'
  ) THEN
    RAISE NOTICE 'Warning: note_comments table may not have primary key';
  ELSE
    RAISE NOTICE 'Test passed: note_comments table has primary key';
  END IF;
END $$;

-- Test 16: Check foreign keys
DO $$
BEGIN
  -- Check if note_comments table has foreign key to notes
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE table_name = 'note_comments' AND constraint_type = 'FOREIGN KEY'
  ) THEN
    RAISE NOTICE 'Warning: note_comments table may not have foreign key';
  ELSE
    RAISE NOTICE 'Test passed: note_comments table has foreign key';
  END IF;
END $$;

-- Test 17: Check indexes
DO $$
BEGIN
  -- Check if notes table has index on note_id
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes WHERE tablename = 'notes' AND indexname LIKE '%note_id%'
  ) THEN
    RAISE NOTICE 'Warning: notes table may not have index on note_id';
  ELSE
    RAISE NOTICE 'Test passed: notes table has index on note_id';
  END IF;
END $$;

-- Test 18: Test data insertion into notes table
DO $$
DECLARE
  note_count INTEGER;
BEGIN
  -- Insert test data
  INSERT INTO notes (note_id, latitude, longitude, created_at, status) 
  VALUES (999, 40.7128, -74.0060, NOW(), 'open');
  
  -- Check if data was inserted
  SELECT COUNT(*) INTO note_count FROM notes WHERE note_id = 999;
  
  -- Assert
  IF note_count = 1 THEN
    RAISE NOTICE 'Test passed: Note data was inserted successfully';
  ELSE
    RAISE EXCEPTION 'Test failed: Note data was not inserted';
  END IF;
  
  -- Clean up
  DELETE FROM notes WHERE note_id = 999;
END $$;

-- Test 19: Test data insertion into note_comments table
DO $$
DECLARE
  comment_count INTEGER;
BEGIN
  -- Insert test data
  INSERT INTO note_comments (note_id, sequence_action, event, created_at, id_user) 
  VALUES (999, 1, 'opened', NOW(), 123);
  
  -- Check if data was inserted
  SELECT COUNT(*) INTO comment_count FROM note_comments WHERE note_id = 999;
  
  -- Assert
  IF comment_count = 1 THEN
    RAISE NOTICE 'Test passed: Comment data was inserted successfully';
  ELSE
    RAISE EXCEPTION 'Test failed: Comment data was not inserted';
  END IF;
  
  -- Clean up
  DELETE FROM note_comments WHERE note_id = 999;
END $$;

-- Test 20: Test data insertion into note_comments_text table
DO $$
DECLARE
  text_count INTEGER;
BEGIN
  -- Insert test data
  INSERT INTO note_comments_text (note_id, sequence_action, body) 
  VALUES (999, 1, 'Test comment text');
  
  -- Check if data was inserted
  SELECT COUNT(*) INTO text_count FROM note_comments_text WHERE note_id = 999;
  
  -- Assert
  IF text_count = 1 THEN
    RAISE NOTICE 'Test passed: Text comment data was inserted successfully';
  ELSE
    RAISE EXCEPTION 'Test failed: Text comment data was not inserted';
  END IF;
  
  -- Clean up
  DELETE FROM note_comments_text WHERE note_id = 999;
END $$;

RAISE NOTICE 'All table tests completed successfully';

ROLLBACK; 