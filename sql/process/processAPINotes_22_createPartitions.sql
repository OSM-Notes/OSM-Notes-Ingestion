-- Creates partitions dynamically based on MAX_THREADS.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-08-02

-- This script creates partitions dynamically based on the MAX_THREADS environment variable
-- It should be called after creating the partitioned tables

DO $$
DECLARE
  max_threads INTEGER;
  i INTEGER;
  partition_name TEXT;
  start_value INTEGER;
  end_value INTEGER;
BEGIN
  -- Get MAX_THREADS from environment variable substitution, default to 4 if not set
  max_threads := $MAX_THREADS;
  
  -- Validate MAX_THREADS
  IF max_threads < 1 OR max_threads > 100 THEN
    RAISE EXCEPTION 'Invalid MAX_THREADS: %. Must be between 1 and 100.', max_threads;
  END IF;
  
  -- Create partitions for notes_api
  FOR i IN 1..max_threads LOOP
    partition_name := 'notes_api_part_' || i;
    start_value := i;
    end_value := i + 1;
    
    EXECUTE format('CREATE TABLE IF NOT EXISTS %I PARTITION OF notes_api FOR VALUES FROM (%s) TO (%s)',
                   partition_name, start_value, end_value);
  END LOOP;
  
  -- Create partitions for note_comments_api
  FOR i IN 1..max_threads LOOP
    partition_name := 'note_comments_api_part_' || i;
    start_value := i;
    end_value := i + 1;
    
    EXECUTE format('CREATE TABLE IF NOT EXISTS %I PARTITION OF note_comments_api FOR VALUES FROM (%s) TO (%s)',
                   partition_name, start_value, end_value);
  END LOOP;
  
  -- Create partitions for note_comments_text_api
  FOR i IN 1..max_threads LOOP
    partition_name := 'note_comments_text_api_part_' || i;
    start_value := i;
    end_value := i + 1;
    
    EXECUTE format('CREATE TABLE IF NOT EXISTS %I PARTITION OF note_comments_text_api FOR VALUES FROM (%s) TO (%s)',
                   partition_name, start_value, end_value);
  END LOOP;
  
  RAISE NOTICE 'Created % partitions for each table', max_threads;
END $$; 