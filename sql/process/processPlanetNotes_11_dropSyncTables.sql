-- Drops sync tables and their partitions.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-10-16

-- Drop partitioned sync tables (created during parallel processing)
-- This version dynamically finds ALL partitions, not just MAX_THREADS
DO $$
DECLARE
  partition_record RECORD;
  dropped_count INTEGER := 0;
BEGIN
  -- Drop ALL partition tables for notes_sync (find dynamically)
  FOR partition_record IN 
    SELECT table_name 
    FROM information_schema.tables 
    WHERE table_schema = 'public' 
      AND table_name LIKE 'notes_sync_part_%'
      AND table_name ~ 'notes_sync_part_[0-9]+'
  LOOP
    EXECUTE format('DROP TABLE IF EXISTS %I CASCADE', partition_record.table_name);
    dropped_count := dropped_count + 1;
  END LOOP;
  
  -- Drop ALL partition tables for note_comments_sync (find dynamically)
  FOR partition_record IN 
    SELECT table_name 
    FROM information_schema.tables 
    WHERE table_schema = 'public' 
      AND table_name LIKE 'note_comments_sync_part_%'
      AND table_name ~ 'note_comments_sync_part_[0-9]+'
  LOOP
    EXECUTE format('DROP TABLE IF EXISTS %I CASCADE', partition_record.table_name);
    dropped_count := dropped_count + 1;
  END LOOP;
  
  -- Drop ALL partition tables for note_comments_text_sync (find dynamically)
  FOR partition_record IN 
    SELECT table_name 
    FROM information_schema.tables 
    WHERE table_schema = 'public' 
      AND table_name LIKE 'note_comments_text_sync_part_%'
      AND table_name ~ 'note_comments_text_sync_part_[0-9]+'
  LOOP
    EXECUTE format('DROP TABLE IF EXISTS %I CASCADE', partition_record.table_name);
    dropped_count := dropped_count + 1;
  END LOOP;
  
  RAISE NOTICE 'Dropped % partition tables total', dropped_count;
END $$;

-- Drop main sync tables
DROP TABLE IF EXISTS note_comments_text_sync;
DROP TABLE IF EXISTS note_comments_sync;
DROP TABLE IF EXISTS notes_sync;

