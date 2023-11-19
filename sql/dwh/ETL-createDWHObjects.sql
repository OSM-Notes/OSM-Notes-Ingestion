-- Create data warehouse tables, indexes, functions and triggers.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-11-18

CREATE SCHEMA IF NOT EXISTS dwh;
COMMENT ON SCHEMA dwh IS
  'Data warehouse objects';

CREATE TABLE IF NOT EXISTS dwh.facts (
 fact_id SERIAL,
 id_note INTEGER NOT NULL,
 dimension_id_country INTEGER NOT NULL,
 processing_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
 action_at TIMESTAMP NOT NULL,
 action_comment note_event_enum NOT NULL,
 action_dimension_id_date INTEGER NOT NULL,
 action_dimension_id_hour INTEGER NOT NULL,
 action_dimension_id_user INTEGER,
 opened_dimension_id_date INTEGER NOT NULL,
 opened_dimension_id_hour INTEGER NOT NULL,
 opened_dimension_id_user INTEGER,
 closed_dimension_id_date INTEGER,
 closed_dimension_id_hour INTEGER,
 closed_dimension_id_user INTEGER
);
COMMENT ON TABLE dwh.facts IS 'Facts id, center of the star schema';
COMMENT ON COLUMN dwh.facts.fact_id IS 'Surrogated ID';
COMMENT ON COLUMN dwh.facts.id_note IS 'OSM note id';
COMMENT ON COLUMN dwh.facts.dimension_id_country IS 'OSM country relation id';
COMMENT ON COLUMN dwh.facts.processing_time IS
  'Timestamp when the comment was processed';
COMMENT ON COLUMN dwh.facts.action_at IS
 'Timestamp when the action took place';
COMMENT ON COLUMN dwh.facts.action_comment IS 'Type of comment action';
COMMENT ON COLUMN dwh.facts.action_dimension_id_date IS 'Date of the action';
COMMENT ON COLUMN dwh.facts.action_dimension_id_hour IS 'Hour of the action';
COMMENT ON COLUMN dwh.facts.action_dimension_id_user IS
  'User who performed the action';
COMMENT ON COLUMN dwh.facts.opened_dimension_id_date IS
  'Date when the note was created';
COMMENT ON COLUMN dwh.facts.opened_dimension_id_hour IS
  'Hour when the note was created';
COMMENT ON COLUMN dwh.facts.opened_dimension_id_user IS
  'User who created the note. It could be annonymous';
COMMENT ON COLUMN dwh.facts.closed_dimension_id_date IS
  'Date when the note was closed';
COMMENT ON COLUMN dwh.facts.closed_dimension_id_hour IS
  'Time when the note was closed';
COMMENT ON COLUMN dwh.facts.closed_dimension_id_user IS
  'User who created the note';

CREATE TABLE IF NOT EXISTS dwh.dimension_users (
 dimension_user_id SERIAL,
 user_id INTEGER NOT NULL,
 username VARCHAR(256),
 modified BOOLEAN
);
COMMENT ON TABLE dwh.dimension_users IS 'Dimension for users';
COMMENT ON COLUMN dwh.dimension_users.dimension_user_id IS 'Surrogated ID';
COMMENT ON COLUMN dwh.dimension_users.user_id IS 'OSM User ir';
COMMENT ON COLUMN dwh.dimension_users.username IS
  'Username at the moment of the last note';
COMMENT ON COLUMN dwh.dimension_users.modified IS
  'Flag to mark users that have performed note actions';

CREATE TABLE IF NOT EXISTS dwh.dimension_regions (
 dimension_region_id SERIAL,
 region_name_es VARCHAR(30),
 region_name_en VARCHAR(30)
);
COMMENT ON TABLE dwh.dimension_regions IS 'Regions for contries';
COMMENT ON COLUMN dwh.dimension_regions.dimension_region_id IS 'Id';
COMMENT ON COLUMN dwh.dimension_regions.region_name IS 'Name of the region';

CREATE TABLE IF NOT EXISTS dwh.dimension_countries (
 dimension_country_id SERIAL,
 country_id INTEGER NOT NULL,
 country_name VARCHAR(100),
 country_name_es VARCHAR(100),
 country_name_en VARCHAR(100),
 region_id INTEGER;
 modified BOOLEAN
);
COMMENT ON TABLE dwh.dimension_countries IS 'Dimension for contries';
COMMENT ON COLUMN dwh.dimension_countries.dimension_country_id IS
  'Surrogated ID';
COMMENT ON COLUMN dwh.dimension_countries.country_id IS
  'OSM Contry relation ID';
COMMENT ON COLUMN dwh.dimension_countries.country_name IS
  'Name in local language';
COMMENT ON COLUMN dwh.dimension_countries.country_name_es IS 'Name in English';
COMMENT ON COLUMN dwh.dimension_countries.country_name_en IS 'Name in Spanish';
COMMENT ON COLUMN dwh.dimension_countries.modified IS
 'Flag to mark countries that have note actions on them';

CREATE TABLE IF NOT EXISTS dwh.dimension_days (
 dimension_day_id SERIAL,
 date_id DATE
);
COMMENT ON TABLE dwh.dimension_days IS 'Dimension for days';
COMMENT ON COLUMN dwh.dimension_days.dimension_day_id IS 'Surrogated ID';
COMMENT ON COLUMN dwh.dimension_days.date_id IS 'Complete date';

CREATE TABLE IF NOT EXISTS dwh.dimension_times (
 dimension_time_id SERIAL,
 hour SMALLINT
);
COMMENT ON TABLE dwh.dimension_times IS 'Dimension for days';
COMMENT ON COLUMN dwh.dimension_times.dimension_time_id IS 'Surrogated ID';
COMMENT ON COLUMN dwh.dimension_times.hour IS 'Hour of the day';

INSERT INTO dwh.dimension_regions (region_name) VALUES
 ('Indefinida', 'Undefined'),
 ('Norteamérica', 'North America'),
 ('Centroamérica', 'Central America'),
 ('Antillas', 'Antilles'),
 ('Sudamérica', 'South America'),
 ('Europa Occidental', 'Western Europe'),
 ('Europa Oriental', 'Eastern Europe'),
 ('Cáucaso', 'Caucasus'),
 ('Siberia', 'Siberia'),
 ('Asia Central', 'Central Asia'),
 ('Asia Oriental', 'East Asia'),
 ('África del Norte', 'North Africa'),
 ('África subsahariana', 'Sub-Saharan Africa'),
 ('Medio Oriente', 'Middle East'),
 ('Indostán', 'Indian subcontinent'),
 ('Indochina', 'Mainland Southeast Asia'),
 ('Insulindia', 'Malay Archipelago'),
 ('Islas del Pacífico (Melanesia, Micronesia y Polinesia)', 'Pacific Islands (Melanesia, Micronesia and Polynesia)'),
 ('Australia', 'Australia');
