-- Create data warehouse tables, indexes, functions and triggers.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-10-28

CREATE SCHEMA IF NOT EXISTS dwh;

CREATE TABLE IF NOT EXISTS dwh.facts (
 fact_id INTEGER NOT NULL,
 id_note INTEGER NOT NULL, -- id
 created_at TIMESTAMP NOT NULL,
 created_id_user INTEGER,
 closed_at TIMESTAMP,
 closed_id_user INTEGER,
 id_country INTEGER,
 action_comment note_event_enum,
 action_id_user INTEGER,
 action_at TIMESTAMP,
 action_id_date DATE
);

CREATE TABLE IF NOT EXISTS dwh.dimension_users (
 dimension_user_id INTEGER NOT NULL,
 user_id INTEGER NOT NULL,
 username VARCHAR(256)
);

CREATE TABLE IF NOT EXISTS dwh.dimension_countries (
 dimension_country_id INTEGER NOT NULL,
 country_id INTEGER NOT NULL,
 country_name VARCHAR(100),
 country_name_es VARCHAR(100),
 country_name_en VARCHAR(100)
-- ToDo Include the regions
);

CREATE TABLE IF NOT EXISTS dwh.dimension_days (
 dimension_day_id INTEGER NOT NULL,
 date_id DATE,
 days_from_notes_epoch INTEGER,
 days_to_next_year INTEGER
);
