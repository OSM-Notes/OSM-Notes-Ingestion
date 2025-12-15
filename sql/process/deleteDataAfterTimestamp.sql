-- Delete data inserted after a specific timestamp
-- This script allows rolling back to a stable point in time
--
-- Usage:
--   psql -d notes -v CUTOFF_TIMESTAMP="'2025-12-09 04:33:04'" -f deleteDataAfterTimestamp.sql
--   Or set the timestamp directly in the script below
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-12-15

-- Set cutoff timestamp (modify this value or pass via -v CUTOFF_TIMESTAMP)
-- Default: Use max_note_timestamp from before the problematic period
DO $$
DECLARE
  cutoff_timestamp TIMESTAMP;
  notes_deleted INTEGER := 0;
  comments_deleted INTEGER := 0;
  comments_text_deleted INTEGER := 0;
  notes_affected INTEGER := 0;
BEGIN
  -- Get cutoff timestamp from variable or use default
  BEGIN
    cutoff_timestamp := COALESCE(
      current_setting('CUTOFF_TIMESTAMP', true)::TIMESTAMP,
      '2025-12-09 04:33:04'::TIMESTAMP  -- Default: before problematic period
    );
  EXCEPTION
    WHEN OTHERS THEN
      cutoff_timestamp := '2025-12-09 04:33:04'::TIMESTAMP;
  END;

  RAISE NOTICE 'Deleting data after timestamp: %', cutoff_timestamp;

  -- Delete note_comments_text first (no FK dependencies)
  -- Delete by processing_time (when inserted) OR by note_id (if note is deleted)
  DELETE FROM note_comments_text
  WHERE processing_time > cutoff_timestamp
     OR note_id IN (
       SELECT note_id FROM notes
       WHERE created_at > cutoff_timestamp
          OR (insert_time IS NOT NULL AND insert_time > cutoff_timestamp)
     );
  GET DIAGNOSTICS comments_text_deleted = ROW_COUNT;
  RAISE NOTICE 'Deleted % rows from note_comments_text', comments_text_deleted;

  -- Delete note_comments (must be deleted before notes due to FK constraint)
  -- Delete by processing_time (when inserted), created_at (when created in OSM),
  -- OR by note_id (if note is deleted)
  DELETE FROM note_comments
  WHERE processing_time > cutoff_timestamp
     OR created_at > cutoff_timestamp
     OR note_id IN (
       SELECT note_id FROM notes
       WHERE created_at > cutoff_timestamp
          OR (insert_time IS NOT NULL AND insert_time > cutoff_timestamp)
     );
  GET DIAGNOSTICS comments_deleted = ROW_COUNT;
  RAISE NOTICE 'Deleted % rows from note_comments', comments_deleted;

  -- Delete notes (must be deleted after comments due to FK constraint NO ACTION)
  -- Delete by created_at (when created in OSM) OR insert_time (when inserted in DB)
  -- OR closed_at (if closed after cutoff)
  DELETE FROM notes
  WHERE created_at > cutoff_timestamp
     OR (insert_time IS NOT NULL AND insert_time > cutoff_timestamp)
     OR (closed_at IS NOT NULL AND closed_at > cutoff_timestamp);
  GET DIAGNOSTICS notes_deleted = ROW_COUNT;
  RAISE NOTICE 'Deleted % rows from notes', notes_deleted;

  -- Count total notes affected (check remaining notes that match criteria)
  SELECT COUNT(*) INTO notes_affected
  FROM notes
  WHERE created_at > cutoff_timestamp
     OR (insert_time IS NOT NULL AND insert_time > cutoff_timestamp)
     OR (closed_at IS NOT NULL AND closed_at > cutoff_timestamp);

  RAISE NOTICE 'Total notes affected: %', notes_affected;
  RAISE NOTICE 'Summary:';
  RAISE NOTICE '  - Notes deleted: %', notes_deleted;
  RAISE NOTICE '  - Comments deleted: %', comments_deleted;
  RAISE NOTICE '  - Comment texts deleted: %', comments_text_deleted;

  -- Update max_note_timestamp to the cutoff timestamp
  UPDATE max_note_timestamp
  SET timestamp = cutoff_timestamp;
  RAISE NOTICE 'Updated max_note_timestamp to: %', cutoff_timestamp;

END $$;

-- Show current state
SELECT 'Current max_note_timestamp' AS info, timestamp::TEXT AS value
FROM max_note_timestamp
UNION ALL
SELECT 'Latest note created_at', COALESCE(MAX(created_at)::TEXT, 'NULL')
FROM notes
UNION ALL
SELECT 'Latest note insert_time', COALESCE(MAX(insert_time)::TEXT, 'NULL')
FROM notes
WHERE insert_time IS NOT NULL
UNION ALL
SELECT 'Latest note closed_at', COALESCE(MAX(closed_at)::TEXT, 'NULL')
FROM notes
WHERE closed_at IS NOT NULL
UNION ALL
SELECT 'Latest comment created_at', COALESCE(MAX(created_at)::TEXT, 'NULL')
FROM note_comments
UNION ALL
SELECT 'Latest comment processing_time', COALESCE(MAX(processing_time)::TEXT, 'NULL')
FROM note_comments
WHERE processing_time IS NOT NULL;

