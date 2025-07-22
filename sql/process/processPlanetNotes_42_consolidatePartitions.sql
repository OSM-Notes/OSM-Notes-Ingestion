-- Consolidates data from all Planet sync partitions into main tables.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-07-20

-- This script consolidates data from partitioned sync tables into the main tables
-- It should be called after all parallel processing is complete

DO $$
DECLARE
  max_threads INTEGER;
  i INTEGER;
  partition_name TEXT;
  total_notes INTEGER;
  total_comments INTEGER;
  total_text_comments INTEGER;
BEGIN
  -- Get MAX_THREADS from environment variable, default to 4 if not set
  max_threads := COALESCE(current_setting('app.max_threads', true)::INTEGER, 4);
  
  -- Validate MAX_THREADS
  IF max_threads < 1 OR max_threads > 100 THEN
    RAISE EXCEPTION 'Invalid MAX_THREADS: %. Must be between 1 and 100.', max_threads;
  END IF;
  
  -- Initialize counters
  total_notes := 0;
  total_comments := 0;
  total_text_comments := 0;
  
  -- Consolidate data from all partitions
  FOR i IN 1..max_threads LOOP
    partition_name := 'notes_sync_part_' || i;
    
    -- Check if partition exists and has data
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = partition_name) THEN
      -- Insert notes from partition
      EXECUTE format('INSERT INTO notes_sync 
        SELECT note_id, latitude, longitude, created_at, status, closed_at, id_country 
        FROM %I WHERE part_id = %s', partition_name, i);
      
      -- Count inserted notes
      GET DIAGNOSTICS total_notes = ROW_COUNT;
      
      -- Insert comments from partition
      EXECUTE format('INSERT INTO note_comments_sync 
        SELECT nextval(''note_comments_sync_id_seq''), note_id, sequence_action, event, created_at, id_user, username 
        FROM note_comments_sync_part_%s WHERE part_id = %s', i, i);
      
      -- Count inserted comments
      GET DIAGNOSTICS total_comments = ROW_COUNT;
      
      -- Insert text comments from partition
      EXECUTE format('INSERT INTO note_comments_text_sync 
        SELECT note_id, body 
        FROM note_comments_text_sync_part_%s WHERE part_id = %s', i, i);
      
      -- Count inserted text comments
      GET DIAGNOSTICS total_text_comments = ROW_COUNT;
      
      RAISE NOTICE 'Consolidated partition %: % notes, % comments, % text comments', 
                   i, total_notes, total_comments, total_text_comments;
    END IF;
  END LOOP;
  
  -- Update statistics on consolidated tables
  ANALYZE notes_sync;
  ANALYZE note_comments_sync;
  ANALYZE note_comments_text_sync;
  
  RAISE NOTICE 'Consolidation complete. Total: % notes, % comments, % text comments', 
               total_notes, total_comments, total_text_comments;
END $$;

-- Clean up partition tables
DO $$
DECLARE
  max_threads INTEGER;
  i INTEGER;
  partition_name TEXT;
BEGIN
  -- Get MAX_THREADS from environment variable, default to 4 if not set
  max_threads := COALESCE(current_setting('app.max_threads', true)::INTEGER, 4);
  
  -- Drop partition tables
  FOR i IN 1..max_threads LOOP
    -- Drop notes partition
    partition_name := 'notes_sync_part_' || i;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = partition_name) THEN
      EXECUTE format('DROP TABLE IF EXISTS %I', partition_name);
    END IF;
    
    -- Drop comments partition
    partition_name := 'note_comments_sync_part_' || i;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = partition_name) THEN
      EXECUTE format('DROP TABLE IF EXISTS %I', partition_name);
    END IF;
    
    -- Drop text comments partition
    partition_name := 'note_comments_text_sync_part_' || i;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = partition_name) THEN
      EXECUTE format('DROP TABLE IF EXISTS %I', partition_name);
    END IF;
  END LOOP;
  
  RAISE NOTICE 'Cleaned up all partition tables';
END $$; 