-- Drop staging objects.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-10-28

DROP TABLE IF EXISTS staging.ranking_day;

DROP TABLE IF EXISTS staging.ranking_month;

DROP TABLE IF EXISTS staging.ranking_year;

DROP TABLE IF EXISTS staging.ranking_historic;

DROP SCHEMA IF EXISTS staging;
