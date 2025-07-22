-- Drop API tables and their partitions.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-07-20

-- Drop partitioned API tables (created during parallel processing)
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
    max_threads := 4; -- Use default if invalid
  END IF;
  
  -- Drop partition tables for notes_api
  FOR i IN 1..max_threads LOOP
    partition_name := 'notes_api_part_' || i;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = partition_name) THEN
      EXECUTE format('DROP TABLE IF EXISTS %I', partition_name);
    END IF;
  END LOOP;
  
  -- Drop partition tables for note_comments_api
  FOR i IN 1..max_threads LOOP
    partition_name := 'note_comments_api_part_' || i;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = partition_name) THEN
      EXECUTE format('DROP TABLE IF EXISTS %I', partition_name);
    END IF;
  END LOOP;
  
  -- Drop partition tables for note_comments_text_api
  FOR i IN 1..max_threads LOOP
    partition_name := 'note_comments_text_api_part_' || i;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = partition_name) THEN
      EXECUTE format('DROP TABLE IF EXISTS %I', partition_name);
    END IF;
  END LOOP;
  
  RAISE NOTICE 'Dropped % partition tables for each API table', max_threads;
END $$;

-- Drop main API tables
DROP TABLE IF EXISTS max_note_timestamp;
DROP TABLE IF EXISTS note_comments_text_api;
DROP TABLE IF EXISTS note_comments_api;
DROP TABLE IF EXISTS notes_api;
