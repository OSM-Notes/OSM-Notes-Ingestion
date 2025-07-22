-- Unit tests for database tables using pgTAP
-- Author: Andres Gomez (AngocA)
-- Version: 2025-07-20

BEGIN;

-- Load pgTAP
\i /usr/share/postgresql/15/extension/pgtap.sql

-- Plan the tests
SELECT plan(20);

-- Test 1: Check if notes table exists
SELECT has_table('notes');

-- Test 2: Check if note_comments table exists
SELECT has_table('note_comments');

-- Test 3: Check if note_comments_text table exists
SELECT has_table('note_comments_text');

-- Test 4: Check if users table exists
SELECT has_table('users');

-- Test 5: Check if notes_sync table exists
SELECT has_table('notes_sync');

-- Test 6: Check if note_comments_sync table exists
SELECT has_table('note_comments_sync');

-- Test 7: Check if note_comments_text_sync table exists
SELECT has_table('note_comments_text_sync');

-- Test 8: Check if notes_api table exists
SELECT has_table('notes_api');

-- Test 9: Check if note_comments_api table exists
SELECT has_table('note_comments_api');

-- Test 10: Check if note_comments_text_api table exists
SELECT has_table('note_comments_text_api');

-- Test 11: Check notes table structure
SELECT has_column('notes', 'note_id');
SELECT has_column('notes', 'latitude');
SELECT has_column('notes', 'longitude');
SELECT has_column('notes', 'created_at');
SELECT has_column('notes', 'status');
SELECT has_column('notes', 'closed_at');
SELECT has_column('notes', 'id_country');

-- Test 12: Check note_comments table structure
SELECT has_column('note_comments', 'id');
SELECT has_column('note_comments', 'note_id');
SELECT has_column('note_comments', 'sequence_action');
SELECT has_column('note_comments', 'event');
SELECT has_column('note_comments', 'created_at');
SELECT has_column('note_comments', 'id_user');

-- Test 13: Check note_comments_text table structure
SELECT has_column('note_comments_text', 'id');
SELECT has_column('note_comments_text', 'note_id');
SELECT has_column('note_comments_text', 'sequence_action');
SELECT has_column('note_comments_text', 'body');

-- Test 14: Check users table structure
SELECT has_column('users', 'user_id');
SELECT has_column('users', 'username');

-- Test 15: Check primary keys
SELECT has_pk('notes');
SELECT has_pk('note_comments');
SELECT has_pk('note_comments_text');
SELECT has_pk('users');

-- Test 16: Check foreign keys
SELECT has_fk('note_comments');

-- Test 17: Check indexes
SELECT has_index('notes', 'notes_note_id_idx');
SELECT has_index('note_comments', 'note_comments_note_id_idx');
SELECT has_index('note_comments_text', 'note_comments_id_text');

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

-- Finish the tests
SELECT finish();

ROLLBACK; 