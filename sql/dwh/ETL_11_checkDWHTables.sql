-- Check DWH tables structure (extended)
-- Version: 2025-08-08

SELECT 'Checking DWH tables' AS step;

-- Basic presence checks
SELECT to_regclass('dwh.facts') AS facts_exists;
SELECT to_regclass('dwh.dimension_days') AS dim_days_exists;
SELECT to_regclass('dwh.dimension_time_of_week') AS dim_tow_exists;
SELECT to_regclass('dwh.dimension_users') AS dim_users_exists;
SELECT to_regclass('dwh.dimension_countries') AS dim_countries_exists;
SELECT to_regclass('dwh.dimension_regions') AS dim_regions_exists;
SELECT to_regclass('dwh.dimension_continents') AS dim_continents_exists;
SELECT to_regclass('dwh.dimension_timezones') AS dim_timezones_exists;
SELECT to_regclass('dwh.dimension_seasons') AS dim_seasons_exists;
SELECT to_regclass('dwh.fact_hashtags') AS fact_hashtags_exists;
-- Check data warehouse tables.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2024-01-02

  DO /* Notes-ETL-checkTables */
  $$
  DECLARE
   qty INT;
  BEGIN

   SELECT /* Notes-ETL */ COUNT(TABLE_NAME)
    INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA LIKE 'dwh'
   AND TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_NAME = 'facts'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Tables are missing: dwh.facts.';
   END IF;

   SELECT /* Notes-ETL */ COUNT(TABLE_NAME)
    INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA LIKE 'dwh'
   AND TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_NAME = 'dimension_users'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Tables are missing: dwh.dimension_users.';
   END IF;

   SELECT /* Notes-ETL */ COUNT(TABLE_NAME)
    INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA LIKE 'dwh'
   AND TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_NAME = 'dimension_regions'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Tables are missing: dwh.dimension_regions.';
   END IF;

   SELECT /* Notes-ETL */ COUNT(TABLE_NAME)
    INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA LIKE 'dwh'
   AND TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_NAME = 'dimension_countries'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Tables are missing: dwh.dimension_countries.';
   END IF;

   SELECT /* Notes-ETL */ COUNT(TABLE_NAME)
    INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA LIKE 'dwh'
   AND TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_NAME = 'dimension_days'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Tables are missing: dwh.dimension_days.';
   END IF;

   SELECT /* Notes-ETL */ COUNT(TABLE_NAME)
    INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA LIKE 'dwh'
   AND TABLE_TYPE LIKE 'BASE TABLE'
    AND TABLE_NAME = 'dimension_time_of_week'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Tables are missing: dwh.dimension_time_of_week.';
   END IF;

   SELECT /* Notes-ETL */ COUNT(TABLE_NAME)
    INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA LIKE 'dwh'
   AND TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_NAME = 'dimension_applications'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Tables are missing: dwh.dimension_applications.';
   END IF;

   SELECT /* Notes-ETL */ COUNT(TABLE_NAME)
    INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA LIKE 'dwh'
   AND TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_NAME = 'dimension_hashtags'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Tables are missing: dwh.dimension_hashtags.';
   END IF;

   SELECT /* Notes-ETL */ COUNT(TABLE_NAME)
    INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA LIKE 'dwh'
   AND TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_NAME = 'properties'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Tables are missing: dwh.properties.';
   END IF;

   SELECT /* Notes-ETL */ COUNT(1)
    INTO qty
   FROM dwh.properties
   WHERE key = 'initial load'
   AND value = 'true'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Previous initial load was not complete correctly.';
   END IF;
  END;
  $$;
