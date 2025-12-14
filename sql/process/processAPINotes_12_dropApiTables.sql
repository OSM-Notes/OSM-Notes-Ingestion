-- Drop API tables (no longer partitioned).
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-12-14

-- Drop any remaining partition tables (for backward compatibility)
DO $$
DECLARE
  partition_name TEXT;
BEGIN
  -- Drop any remaining partition tables for notes_api
  FOR partition_name IN
    SELECT tablename FROM pg_tables
    WHERE tablename LIKE 'notes_api_part_%'
  LOOP
    EXECUTE format('DROP TABLE IF EXISTS %I CASCADE', partition_name);
  END LOOP;
  
  -- Drop any remaining partition tables for note_comments_api
  FOR partition_name IN
    SELECT tablename FROM pg_tables
    WHERE tablename LIKE 'note_comments_api_part_%'
  LOOP
    EXECUTE format('DROP TABLE IF EXISTS %I CASCADE', partition_name);
  END LOOP;
  
  -- Drop any remaining partition tables for note_comments_text_api
  FOR partition_name IN
    SELECT tablename FROM pg_tables
    WHERE tablename LIKE 'note_comments_text_api_part_%'
  LOOP
    EXECUTE format('DROP TABLE IF EXISTS %I CASCADE', partition_name);
  END LOOP;
END $$;

-- Drop main API tables
DROP TABLE IF EXISTS max_note_timestamp;
DROP TABLE IF EXISTS note_comments_text_api CASCADE;
DROP TABLE IF EXISTS note_comments_api CASCADE;
DROP TABLE IF EXISTS notes_api CASCADE;
