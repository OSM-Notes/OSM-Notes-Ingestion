-- Drops ALL sync tables and their partitions, regardless of MAX_THREADS value.
-- This script is designed to clean up any remaining partition tables.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-07-20

-- Drop ALL partition tables for notes_sync (up to 100 to be safe)
DO $$
DECLARE
  i INTEGER;
  partition_name TEXT;
  dropped_count INTEGER := 0;
BEGIN
  -- Drop partition tables for notes_sync (up to 100)
  FOR i IN 1..100 LOOP
    partition_name := 'notes_sync_part_' || i;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = partition_name) THEN
      EXECUTE format('DROP TABLE IF EXISTS %I', partition_name);
      dropped_count := dropped_count + 1;
    END IF;
  END LOOP;
  
  RAISE NOTICE 'Dropped % notes_sync partition tables', dropped_count;
END $$;

-- Drop ALL partition tables for note_comments_sync (up to 100 to be safe)
DO $$
DECLARE
  i INTEGER;
  partition_name TEXT;
  dropped_count INTEGER := 0;
BEGIN
  -- Drop partition tables for note_comments_sync (up to 100)
  FOR i IN 1..100 LOOP
    partition_name := 'note_comments_sync_part_' || i;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = partition_name) THEN
      EXECUTE format('DROP TABLE IF EXISTS %I', partition_name);
      dropped_count := dropped_count + 1;
    END IF;
  END LOOP;
  
  RAISE NOTICE 'Dropped % note_comments_sync partition tables', dropped_count;
END $$;

-- Drop ALL partition tables for note_comments_text_sync (up to 100 to be safe)
DO $$
DECLARE
  i INTEGER;
  partition_name TEXT;
  dropped_count INTEGER := 0;
BEGIN
  -- Drop partition tables for note_comments_text_sync (up to 100)
  FOR i IN 1..100 LOOP
    partition_name := 'note_comments_text_sync_part_' || i;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = partition_name) THEN
      EXECUTE format('DROP TABLE IF EXISTS %I', partition_name);
      dropped_count := dropped_count + 1;
    END IF;
  END LOOP;
  
  RAISE NOTICE 'Dropped % note_comments_text_sync partition tables', dropped_count;
END $$;

-- Drop ALL partition tables for notes_api (up to 100 to be safe)
DO $$
DECLARE
  i INTEGER;
  partition_name TEXT;
  dropped_count INTEGER := 0;
BEGIN
  -- Drop partition tables for notes_api (up to 100)
  FOR i IN 1..100 LOOP
    partition_name := 'notes_api_part_' || i;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = partition_name) THEN
      EXECUTE format('DROP TABLE IF EXISTS %I', partition_name);
      dropped_count := dropped_count + 1;
    END IF;
  END LOOP;
  
  RAISE NOTICE 'Dropped % notes_api partition tables', dropped_count;
END $$;

-- Drop ALL partition tables for note_comments_api (up to 100 to be safe)
DO $$
DECLARE
  i INTEGER;
  partition_name TEXT;
  dropped_count INTEGER := 0;
BEGIN
  -- Drop partition tables for note_comments_api (up to 100)
  FOR i IN 1..100 LOOP
    partition_name := 'note_comments_api_part_' || i;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = partition_name) THEN
      EXECUTE format('DROP TABLE IF EXISTS %I', partition_name);
      dropped_count := dropped_count + 1;
    END IF;
  END LOOP;
  
  RAISE NOTICE 'Dropped % note_comments_api partition tables', dropped_count;
END $$;

-- Drop ALL partition tables for note_comments_text_api (up to 100 to be safe)
DO $$
DECLARE
  i INTEGER;
  partition_name TEXT;
  dropped_count INTEGER := 0;
BEGIN
  -- Drop partition tables for note_comments_text_api (up to 100)
  FOR i IN 1..100 LOOP
    partition_name := 'note_comments_text_api_part_' || i;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = partition_name) THEN
      EXECUTE format('DROP TABLE IF EXISTS %I', partition_name);
      dropped_count := dropped_count + 1;
    END IF;
  END LOOP;
  
  RAISE NOTICE 'Dropped % note_comments_text_api partition tables', dropped_count;
END $$;

-- Drop main sync tables
DROP TABLE IF EXISTS note_comments_text_sync;
DROP TABLE IF EXISTS note_comments_sync;
DROP TABLE IF EXISTS notes_sync;

-- Drop main API tables
DROP TABLE IF EXISTS max_note_timestamp;
DROP TABLE IF EXISTS note_comments_text_api;
DROP TABLE IF EXISTS note_comments_api;
DROP TABLE IF EXISTS notes_api; 