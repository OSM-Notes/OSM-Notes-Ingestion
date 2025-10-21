-- Creates country tables with intelligent 2D grid partitioning.
-- The world is divided into 24 geographic zones based on longitude AND
-- latitude to minimize expensive ST_Contains calls.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-10-20

CREATE TABLE countries (
 country_id INTEGER NOT NULL,
 country_name VARCHAR(100) NOT NULL,
 country_name_es VARCHAR(100),
 country_name_en VARCHAR(100),
 geom GEOMETRY NOT NULL,
 -- Legacy columns (deprecated but kept for compatibility)
 americas INTEGER,
 europe INTEGER,
 russia_middle_east INTEGER,
 asia_oceania INTEGER,
 -- New 2D grid zones (lon + lat based)
 zone_us_canada INTEGER,
 zone_mexico_central_america INTEGER,
 zone_caribbean INTEGER,
 zone_northern_south_america INTEGER,
 zone_southern_south_america INTEGER,
 zone_western_europe INTEGER,
 zone_eastern_europe INTEGER,
 zone_northern_europe INTEGER,
 zone_southern_europe INTEGER,
 zone_northern_africa INTEGER,
 zone_western_africa INTEGER,
 zone_eastern_africa INTEGER,
 zone_southern_africa INTEGER,
 zone_middle_east INTEGER,
 zone_russia_north INTEGER,
 zone_russia_south INTEGER,
 zone_central_asia INTEGER,
 zone_india_south_asia INTEGER,
 zone_southeast_asia INTEGER,
 zone_eastern_asia INTEGER,
 zone_australia_nz INTEGER,
 zone_pacific_islands INTEGER,
 zone_arctic INTEGER,
 zone_antarctic INTEGER,
 updated BOOLEAN
);
COMMENT ON TABLE countries IS
  'Basic data about countries and maritimes areas from OSM with 2D grid';
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
  'DEPRECATED: Position in sequence for Americas (use zone_* columns)';
COMMENT ON COLUMN countries.europe IS
  'DEPRECATED: Position in sequence for Europe (use zone_* columns)';
COMMENT ON COLUMN countries.russia_middle_east IS
  'DEPRECATED: Position in sequence for Russia/Middle East (use zone_* columns)';
COMMENT ON COLUMN countries.asia_oceania IS
  'DEPRECATED: Position in sequence for Asia/Oceania (use zone_* columns)';
COMMENT ON COLUMN countries.zone_us_canada IS
  'Priority for USA/Canada zone (lon:-150 to -60, lat:30 to 75)';
COMMENT ON COLUMN countries.zone_mexico_central_america IS
  'Priority for Mexico/Central America (lon:-120 to -75, lat:5 to 35)';
COMMENT ON COLUMN countries.zone_caribbean IS
  'Priority for Caribbean (lon:-90 to -60, lat:10 to 30)';
COMMENT ON COLUMN countries.zone_northern_south_america IS
  'Priority for Northern S.America (lon:-80 to -35, lat:-15 to 15)';
COMMENT ON COLUMN countries.zone_southern_south_america IS
  'Priority for Southern S.America (lon:-75 to -35, lat:-56 to -15)';
COMMENT ON COLUMN countries.zone_western_europe IS
  'Priority for Western Europe (lon:-10 to 15, lat:35 to 60)';
COMMENT ON COLUMN countries.zone_eastern_europe IS
  'Priority for Eastern Europe (lon:15 to 45, lat:35 to 60)';
COMMENT ON COLUMN countries.zone_northern_europe IS
  'Priority for Northern Europe (lon:-10 to 35, lat:55 to 75)';
COMMENT ON COLUMN countries.zone_southern_europe IS
  'Priority for Southern Europe (lon:-10 to 30, lat:30 to 50)';
COMMENT ON COLUMN countries.zone_northern_africa IS
  'Priority for Northern Africa (lon:-20 to 50, lat:15 to 40)';
COMMENT ON COLUMN countries.zone_western_africa IS
  'Priority for Western Africa (lon:-20 to 20, lat:-10 to 20)';
COMMENT ON COLUMN countries.zone_eastern_africa IS
  'Priority for Eastern Africa (lon:20 to 55, lat:-15 to 20)';
COMMENT ON COLUMN countries.zone_southern_africa IS
  'Priority for Southern Africa (lon:10 to 50, lat:-36 to -15)';
COMMENT ON COLUMN countries.zone_middle_east IS
  'Priority for Middle East (lon:25 to 65, lat:10 to 45)';
COMMENT ON COLUMN countries.zone_russia_north IS
  'Priority for Northern Russia (lon:25 to 180, lat:55 to 80)';
COMMENT ON COLUMN countries.zone_russia_south IS
  'Priority for Southern Russia (lon:30 to 150, lat:40 to 60)';
COMMENT ON COLUMN countries.zone_central_asia IS
  'Priority for Central Asia (lon:45 to 90, lat:30 to 55)';
COMMENT ON COLUMN countries.zone_india_south_asia IS
  'Priority for India/South Asia (lon:60 to 95, lat:5 to 40)';
COMMENT ON COLUMN countries.zone_southeast_asia IS
  'Priority for Southeast Asia (lon:95 to 140, lat:-12 to 25)';
COMMENT ON COLUMN countries.zone_eastern_asia IS
  'Priority for Eastern Asia (lon:100 to 145, lat:20 to 55)';
COMMENT ON COLUMN countries.zone_australia_nz IS
  'Priority for Australia/NZ (lon:110 to 180, lat:-50 to -10)';
COMMENT ON COLUMN countries.zone_pacific_islands IS
  'Priority for Pacific Islands (lon:130 to -120, lat:-30 to 30)';
COMMENT ON COLUMN countries.zone_arctic IS
  'Priority for Arctic regions (all lon, lat>70)';
COMMENT ON COLUMN countries.zone_antarctic IS
  'Priority for Antarctic regions (all lon, lat<-60)';
COMMENT ON COLUMN countries.updated IS
  'Used when updating all countries to refresh properties';

CREATE INDEX IF NOT EXISTS countries_spatial ON countries
  USING GIST (geom);
COMMENT ON INDEX countries_spatial IS 'Spatial index for countries';

ALTER TABLE countries
 ADD CONSTRAINT pk_countries
 PRIMARY KEY (country_id);

CREATE TABLE tries (
 area VARCHAR(50),
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
