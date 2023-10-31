-- Create data warehouse tables, indexes, functions and triggers.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-10-28

CREATE SCHEMA IF NOT EXISTS dwh;

CREATE TABLE IF NOT EXISTS dwh.facts (
 fact_id SERIAL,
 id_note INTEGER NOT NULL, -- id
 created_at TIMESTAMP NOT NULL,
 created_dimension_id_user INTEGER,
 closed_at TIMESTAMP,
 closed_dimension_id_user INTEGER,
 dimension_id_country INTEGER,
 action_comment note_event_enum,
 action_dimension_id_user INTEGER,
 action_at TIMESTAMP,
 action_dimension_id_date INTEGER,
 action_dimension_id_hour INTEGER
);

CREATE TABLE IF NOT EXISTS dwh.dimension_users (
 dimension_user_id SERIAL,
 user_id INTEGER NOT NULL,
 username VARCHAR(256)
);

CREATE TABLE IF NOT EXISTS dwh.dimension_countries (
 dimension_country_id SERIAL,
 country_id INTEGER NOT NULL,
 country_name VARCHAR(100),
 country_name_es VARCHAR(100),
 country_name_en VARCHAR(100)
-- ToDo Include the regions
);

CREATE TABLE IF NOT EXISTS dwh.dimension_days (
 dimension_day_id SERIAL,
 date_id DATE,
 days_from_notes_epoch INTEGER,
 days_to_next_year INTEGER
);

CREATE TABLE IF NOT EXISTS dwh.dimension_times (
 dimension_time_id SERIAL,
 hour SMALLINT,
 morning BOOLEAN -- true for am, false for pm.
);
