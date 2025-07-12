-- Creates country tables.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-07-11

CREATE TABLE countries (
 country_id INTEGER NOT NULL,
 country_name VARCHAR(100) NOT NULL,
 country_name_es VARCHAR(100),
 country_name_en VARCHAR(100),
 geom GEOMETRY NOT NULL,
 americas INTEGER,
 europe INTEGER,
 russia_middle_east INTEGER,
 asia_oceania INTEGER,
 updated BOOLEAN
);
COMMENT ON TABLE countries IS
  'Basic data about countries and maritimes areas from OSM';
COMMENT ON COLUMN countries.country_id IS
  'Relation id from OSM for the country';
COMMENT ON COLUMN countries.country_name IS
  'Country name in the local language';
COMMENT ON COLUMN countries.country_name_es IS
  'Country name in Spanish';
COMMENT ON COLUMN countries.country_name_en IS
  'Country name in English';
COMMENT ON COLUMN countries.geom IS
  'Geometry of the country''s boundary';
COMMENT ON COLUMN countries.americas IS
  'Position in the sequence to look for the location of this country in America';
COMMENT ON COLUMN countries.europe IS
  'Position in the sequence to look for the location of this country in Europe';
COMMENT ON COLUMN countries.russia_middle_east IS
  'Position in the sequence to look for the location of this country in Russia and Middle East';
COMMENT ON COLUMN countries.asia_oceania IS
  'Position in the sequence to look for the location of this country in Oceania';
COMMENT ON COLUMN countries.updated IS
  'Used when updating all countries to refresh properties';

CREATE INDEX IF NOT EXISTS countries_spatial ON countries
  USING GIST (geom);
COMMENT ON INDEX countries_spatial IS 'Spatial index for countries';

ALTER TABLE countries
 ADD CONSTRAINT pk_countries
 PRIMARY KEY (country_id);

CREATE TABLE tries (
 area VARCHAR(20),
 iter INTEGER,
 id_note INTEGER,
 id_country INTEGER
);
COMMENT ON TABLE tries IS
  'Number of tries to find a country. This is used to improve the sequence order';
COMMENT ON COLUMN tries.area IS 'Name of the area where the note is located';
COMMENT ON COLUMN tries.iter IS 'Number of tries before find the proper country';
COMMENT ON COLUMN tries.id_note IS 'OSM note id';
COMMENT ON COLUMN tries.id_country IS 'OSM country id';
