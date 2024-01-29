-- Loads the old notes locations into the database, and then updates the
-- note's location.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2024-01-29

SELECT /* Notes-processAPI */ CURRENT_TIMESTAMP AS Processing,
 'Creating table...' AS Text;

DROP TABLE IF EXISTS backup_note_locations;
CREATE TABLE backup_note_locations (
  note_id INTEGER,
  id_country INTEGER
);

SELECT /* Notes-processAPI */ CURRENT_TIMESTAMP AS Processing,
 'Loading old note locations...' AS Text;
COPY backup_note_locations (note_id, id_country)
FROM '${CSV_BACKUP_NOTE_LOCATION}' csv;
SELECT /* Notes-processAPI */ CURRENT_TIMESTAMP AS Processing,
 'Locations loaded. Updating notes...' AS Text;
UPDATE notes AS n
 SET id_country = b.id_country
 FROM backup_note_locations AS b
 WHERE b.note_id = n.note_id
 AND n.id_country IS NULL;
SELECT /* Notes-processAPI */ CURRENT_TIMESTAMP AS Processing,
 'Notes updated with location...' AS Text;

DROP TABLE backup_note_locations;