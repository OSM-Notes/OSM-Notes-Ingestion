-- Chech staging tables.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-10-28

CREATE SCHEMA IF NOT EXISTS staging;

CREATE TABLE IF NOT EXISTS staging.ranking_historic (
 action note_event_enum,
 id_country INTEGER,
 id_user INTEGER NOT NULL,
 position INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS staging.ranking_year (
 action note_event_enum,
 id_country INTEGER,
 id_user INTEGER NOT NULL,
 position INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS staging.ranking_month (
 action note_event_enum,
 id_country INTEGER,
 id_user INTEGER NOT NULL,
 position INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS  (
 action note_event_enum,
 id_country INTEGER,
 id_user INTEGER NOT NULL,
 position INTEGER NOT NULL
);
