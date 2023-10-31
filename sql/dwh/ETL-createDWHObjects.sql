-- Create data warehouse tables, indexes, functions and triggers.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-10-31

CREATE SCHEMA IF NOT EXISTS dwh;

CREATE TABLE IF NOT EXISTS dwh.facts (
 fact_id SERIAL,
 id_note INTEGER NOT NULL,
 dimension_id_country INTEGER,
 action_at TIMESTAMP,
 action_comment note_event_enum NOT NULL,
 action_dimension_id_date INTEGER,
 action_dimension_id_hour INTEGER,
 action_dimension_id_user INTEGER,
 opened_dimension_id_date INTEGER NOT NULL,
 opened_dimension_id_hour INTEGER NOT NULL,
 opened_dimension_id_user INTEGER,
 closed_dimension_id_date INTEGER,
 closed_dimension_id_hour INTEGER,
 closed_dimension_id_user INTEGER
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
