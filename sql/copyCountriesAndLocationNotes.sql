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

-- =======
-- RECOVER

-- ---------
-- Countries
INSERT INTO countries
  SELECT * FROM backup_countries ;

