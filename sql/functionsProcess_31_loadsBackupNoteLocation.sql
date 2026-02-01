-- Loads the old notes locations into the database, and then updates the
-- note's location.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2026-02-01

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 'Creating table...' AS Text;

DROP TABLE IF EXISTS backup_note_locations;
CREATE TABLE backup_note_locations (
  note_id INTEGER,
  id_country INTEGER
);

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 'Loading old note locations from backup CSV...' AS Text;
DO $$ BEGIN
  RAISE NOTICE '============================================================================';
  RAISE NOTICE 'LOADING BACKUP NOTE LOCATIONS';
  RAISE NOTICE '============================================================================';
  RAISE NOTICE 'This operation will load note location data from backup CSV file.';
  RAISE NOTICE 'This COPY operation may take several minutes for large datasets.';
  RAISE NOTICE 'Please wait, the process is actively working...';
  RAISE NOTICE '============================================================================';
END $$;
COPY backup_note_locations (note_id, id_country)
FROM '${CSV_BACKUP_NOTE_LOCATION}' csv;

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 'Creating index on backup table...' AS Text;
CREATE INDEX IF NOT EXISTS idx_backup_note_locations_note_id
  ON backup_note_locations (note_id);
CREATE INDEX IF NOT EXISTS idx_backup_note_locations_id_country
  ON backup_note_locations (id_country);
ANALYZE backup_note_locations;

-- Report backup statistics
DO $$
DECLARE
  backup_total BIGINT;
  backup_valid_countries BIGINT;
  backup_invalid_countries BIGINT;
BEGIN
  SELECT COUNT(*) INTO backup_total FROM backup_note_locations;
  SELECT COUNT(DISTINCT b.id_country) INTO backup_valid_countries
  FROM backup_note_locations b
  INNER JOIN countries c ON c.country_id = b.id_country
  WHERE b.id_country > 0;
  SELECT COUNT(DISTINCT b.id_country) INTO backup_invalid_countries
  FROM backup_note_locations b
  LEFT JOIN countries c ON c.country_id = b.id_country
  WHERE b.id_country > 0 AND c.country_id IS NULL;
  
  RAISE NOTICE 'Backup statistics:';
  RAISE NOTICE '  Total rows in backup: %', backup_total;
  RAISE NOTICE '  Countries in backup that exist in countries table: %', backup_valid_countries;
  RAISE NOTICE '  Countries in backup that do NOT exist in countries table: %', backup_invalid_countries;

  IF backup_invalid_countries > 0 THEN
    RAISE WARNING 'Some countries in backup do not exist in countries table. These will be skipped.';
  END IF;
END $$;

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 'Locations loaded. Updating notes...' AS Text;

-- Update notes with backup data, only for countries that exist in countries table
-- This ensures data integrity while using the backup for speed
DO $$
DECLARE
  updated_count BIGINT;
  notes_pending BIGINT;
BEGIN
  -- Update notes with backup data (only valid countries)
  UPDATE notes AS n /* Notes-processAPI */
  SET id_country = b.id_country
  FROM backup_note_locations AS b
  INNER JOIN countries AS c ON c.country_id = b.id_country
  WHERE b.note_id = n.note_id
    AND (n.id_country IS NULL OR n.id_country < 0)
    AND b.id_country > 0;
  
  GET DIAGNOSTICS updated_count = ROW_COUNT;
  
  -- Count how many notes still need country assignment
  SELECT COUNT(*) INTO notes_pending
  FROM notes
  WHERE (id_country IS NULL OR id_country < 0);

  RAISE NOTICE 'Update results:';
  RAISE NOTICE '  Notes updated from backup: %', updated_count;
  RAISE NOTICE '  Notes still pending country assignment: %', notes_pending;

  IF updated_count = 0 THEN
    RAISE WARNING 'No notes were updated from backup. This may indicate that:';
    RAISE WARNING '  1. Country IDs in backup do not match country_ids in countries table';
    RAISE WARNING '  2. All notes already have countries assigned';
    RAISE WARNING '  3. Backup file may be outdated or incompatible';
  END IF;
END $$;

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 'Notes updated with location...' AS Text;

DROP TABLE backup_note_locations;
