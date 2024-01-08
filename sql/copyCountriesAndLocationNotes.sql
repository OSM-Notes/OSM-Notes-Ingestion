-- When running the whole planet process, it could fail to assign the new notes
-- location, or if the process is interrupted it should be started from the 
-- beginning. If there is a copy of the locations ids of a previous execution,
-- one can reuse these locations after recreating the tables.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2024-01-07

-- ===========
-- PREPARATION

-- ---------
-- Countries
CREATE TABLE backup_countries AS TABLE countries;
COMMENT ON TABLE backup_countries IS
  'Basic data about countries and maritimes areas from OSM';
COMMENT ON COLUMN backup_countries.country_id IS
  'Relation id from OSM for the country';
COMMENT ON COLUMN backup_countries.country_name IS
  'Country name in the local language';
COMMENT ON COLUMN backup_countries.country_name_es IS
  'Country name in Spanish';
COMMENT ON COLUMN backup_countries.country_name_en IS
  'Country name in English';
COMMENT ON COLUMN backup_countries.geom IS
  'Geometry of the country''s boundary';
COMMENT ON COLUMN backup_countries.americas IS
  'Position in the sequence to look for the location of this country in America';
COMMENT ON COLUMN backup_countries.europe IS
  'Position in the sequence to look for the location of this country in Europe';
COMMENT ON COLUMN backup_countries.russia_middle_east IS
  'Position in the sequence to look for the location of this country in Russia and Middle East';
COMMENT ON COLUMN backup_countries.asia_oceania IS
  'Position in the sequence to look for the location of this country in Oceania';

-- ---------------
-- Note's location
-- Copy the note_id and location.
-- To run before the new execution.
CREATE TABLE backup_note_country (
  note_id INTEGER,
  id_country INTEGER
);
COMMENT ON TABLE backup_note_country IS
  'Stores the location of the already processed notes';
COMMENT ON COLUMN backup_note_country.note_id IS 'OSM note id';
COMMENT ON COLUMN backup_note_country.id_country IS 'Location of the note';
INSERT INTO backup_note_country
  SELECT note_id, id_country
  FROM notes;

-- =======
-- RECOVER

-- ---------
-- Countries
INSERT INTO countries
  SELECT * FROM backup_countries ;

-- ---------------
-- Note's location
-- To run after the new execution.
UPDATE notes AS n
SET id_country = b.id_country
FROM backup_note_country AS b
WHERE b.note_id = n.note_id;

-- To release space.
DROP TABLE IF EXISTS backup_note_country;
