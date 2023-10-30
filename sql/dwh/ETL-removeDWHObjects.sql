-- Drop data warehouse objects.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-10-28

DROP FUNCTION IF EXISTS dwh.insert_new_dates();

DROP INDEX IF EXISTS facts_action_date;

DROP TABLE IF EXISTS dwh.facts;

DROP TABLE IF EXISTS dwh.dimension_times;

DROP TABLE IF EXISTS dwh.dimension_days;

DROP TABLE IF EXISTS dwh.dimension_countries;

DROP TABLE IF EXISTS dwh.dimension_users;

DROP SCHEMA IF EXISTS dwh;
