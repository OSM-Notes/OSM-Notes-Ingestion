-- Creates partitions dynamically for Planet sync tables based on MAX_THREADS.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-07-20

-- This script creates partitions dynamically based on the MAX_THREADS environment variable
-- It should be called after creating the sync tables

DO $$
DECLARE
  max_threads INTEGER;
  i INTEGER;
  partition_name TEXT;
BEGIN
  -- Get MAX_THREADS from environment variable, default to 4 if not set
  max_threads := COALESCE(current_setting('app.max_threads', true)::INTEGER, 4);
  
  -- Validate MAX_THREADS
  IF max_threads < 1 OR max_threads > 100 THEN
    RAISE EXCEPTION 'Invalid MAX_THREADS: %. Must be between 1 and 100.', max_threads;
  END IF;
  
  -- Create partitions for notes_sync
  FOR i IN 1..max_threads LOOP
    partition_name := 'notes_sync_part_' || i;
    
    EXECUTE format('CREATE TABLE IF NOT EXISTS %I (
      note_id INTEGER NOT NULL,
      latitude DECIMAL NOT NULL,
      longitude DECIMAL NOT NULL,
      created_at TIMESTAMP NOT NULL,
      status note_status_enum,
      closed_at TIMESTAMP,
      id_country INTEGER,
      part_id INTEGER DEFAULT %s
    )', partition_name, i);
  END LOOP;
  
  -- Create partitions for note_comments_sync
  FOR i IN 1..max_threads LOOP
    partition_name := 'note_comments_sync_part_' || i;
    
    EXECUTE format('CREATE TABLE IF NOT EXISTS %I (
      id SERIAL,
      note_id INTEGER NOT NULL,
      sequence_action INTEGER,
      event note_event_enum NOT NULL,
      created_at TIMESTAMP NOT NULL,
      id_user INTEGER,
      username VARCHAR(256),
      part_id INTEGER DEFAULT %s
    )', partition_name, i);
  END LOOP;
  
  -- Create partitions for note_comments_text_sync
  FOR i IN 1..max_threads LOOP
    partition_name := 'note_comments_text_sync_part_' || i;
    
    EXECUTE format('CREATE TABLE IF NOT EXISTS %I (
      id SERIAL,
      note_id INTEGER NOT NULL,
      sequence_action INTEGER,
      body TEXT,
      part_id INTEGER DEFAULT %s
    )', partition_name, i);
  END LOOP;
  
  RAISE NOTICE 'Created % partitions for each Planet sync table', max_threads;
END $$; 