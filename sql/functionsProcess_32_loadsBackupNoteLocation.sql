-- Loads the old notes locations into the database, and then updates the
-- note's location.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-12-30

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
ANALYZE backup_note_locations;

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 'Locations loaded. Updating notes...' AS Text;
UPDATE notes AS n /* Notes-processAPI */
 SET id_country = b.id_country
 FROM backup_note_locations AS b
 INNER JOIN countries AS c ON c.country_id = b.id_country
 WHERE b.note_id = n.note_id
 AND (n.id_country IS NULL OR n.id_country < 0)
 AND b.id_country > 0;
SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 'Notes updated with location...' AS Text;

DROP TABLE backup_note_locations;