-- Drop data warehouse objects.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-10-28

DROP FUNCTION IF EXISTS get_country_region;

DROP FUNCTION IF EXISTS dwh.get_hour_of_week_id;

DROP FUNCTION IF EXISTS dwh.get_date_id;

DROP TABLE IF EXISTS dwh.facts;

DROP TABLE IF EXISTS dwh.dimension_hours_of_week;

DROP TABLE IF EXISTS dwh.dimension_days;

DROP TABLE IF EXISTS dwh.dimension_countries;

DROP TABLE IF EXISTS dwh.dimension_users;

DROP SCHEMA IF EXISTS dwh;
