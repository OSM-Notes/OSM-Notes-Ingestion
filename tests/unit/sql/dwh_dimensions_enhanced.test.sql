-- Unit tests for enhanced DWH dimensions
-- Author: Andres Gomez (AngocA)
-- Version: 2025-08-08

BEGIN;

-- Test 1: Check if new dimension tables exist
DO $$
BEGIN
  -- Check dimension_timezones
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'dwh' AND table_name = 'dimension_timezones') THEN
    RAISE EXCEPTION 'Table dwh.dimension_timezones does not exist';
  ELSE
    RAISE NOTICE 'Test passed: Table dwh.dimension_timezones exists';
  END IF;

  -- Check dimension_seasons
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'dwh' AND table_name = 'dimension_seasons') THEN
    RAISE EXCEPTION 'Table dwh.dimension_seasons does not exist';
  ELSE
    RAISE NOTICE 'Test passed: Table dwh.dimension_seasons exists';
  END IF;

  -- Check dimension_continents
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'dwh' AND table_name = 'dimension_continents') THEN
    RAISE EXCEPTION 'Table dwh.dimension_continents does not exist';
  ELSE
    RAISE NOTICE 'Test passed: Table dwh.dimension_continents exists';
  END IF;

  -- Check dimension_application_versions
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'dwh' AND table_name = 'dimension_application_versions') THEN
    RAISE EXCEPTION 'Table dwh.dimension_application_versions does not exist';
  ELSE
    RAISE NOTICE 'Test passed: Table dwh.dimension_application_versions exists';
  END IF;

  -- Check fact_hashtags bridge table
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'dwh' AND table_name = 'fact_hashtags') THEN
    RAISE EXCEPTION 'Table dwh.fact_hashtags does not exist';
  ELSE
    RAISE NOTICE 'Test passed: Table dwh.fact_hashtags exists';
  END IF;
END $$;

-- Test 2: Check if dimension_time_of_week was renamed correctly
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'dwh' AND table_name = 'dimension_time_of_week') THEN
    RAISE EXCEPTION 'Table dwh.dimension_time_of_week does not exist (should be renamed from dimension_hours_of_week)';
  ELSE
    RAISE NOTICE 'Test passed: Table dwh.dimension_time_of_week exists (renamed correctly)';
  END IF;
END $$;

-- Test 3: Check new columns in dimension_days
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'dwh' AND table_name = 'dimension_days' AND column_name = 'iso_week'
  ) THEN
    RAISE EXCEPTION 'Column iso_week does not exist in dwh.dimension_days';
  ELSE
    RAISE NOTICE 'Test passed: Column iso_week exists in dwh.dimension_days';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'dwh' AND table_name = 'dimension_days' AND column_name = 'quarter'
  ) THEN
    RAISE EXCEPTION 'Column quarter does not exist in dwh.dimension_days';
  ELSE
    RAISE NOTICE 'Test passed: Column quarter exists in dwh.dimension_days';
  END IF;
END $$;

-- Test 4: Check SCD2 columns in dimension_users
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'dwh' AND table_name = 'dimension_users' AND column_name = 'valid_from'
  ) THEN
    RAISE EXCEPTION 'Column valid_from does not exist in dwh.dimension_users (SCD2)';
  ELSE
    RAISE NOTICE 'Test passed: Column valid_from exists in dwh.dimension_users';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'dwh' AND table_name = 'dimension_users' AND column_name = 'is_current'
  ) THEN
    RAISE EXCEPTION 'Column is_current does not exist in dwh.dimension_users (SCD2)';
  ELSE
    RAISE NOTICE 'Test passed: Column is_current exists in dwh.dimension_users';
  END IF;
END $$;

-- Test 5: Check new columns in dimension_countries
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'dwh' AND table_name = 'dimension_countries' AND column_name = 'iso_alpha2'
  ) THEN
    RAISE EXCEPTION 'Column iso_alpha2 does not exist in dwh.dimension_countries';
  ELSE
    RAISE NOTICE 'Test passed: Column iso_alpha2 exists in dwh.dimension_countries';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'dwh' AND table_name = 'dimension_countries' AND column_name = 'iso_alpha3'
  ) THEN
    RAISE EXCEPTION 'Column iso_alpha3 does not exist in dwh.dimension_countries';
  ELSE
    RAISE NOTICE 'Test passed: Column iso_alpha3 exists in dwh.dimension_countries';
  END IF;
END $$;

-- Test 6: Check new columns in dimension_applications
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'dwh' AND table_name = 'dimension_applications' AND column_name = 'pattern_type'
  ) THEN
    RAISE EXCEPTION 'Column pattern_type does not exist in dwh.dimension_applications';
  ELSE
    RAISE NOTICE 'Test passed: Column pattern_type exists in dwh.dimension_applications';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'dwh' AND table_name = 'dimension_applications' AND column_name = 'vendor'
  ) THEN
    RAISE EXCEPTION 'Column vendor does not exist in dwh.dimension_applications';
  ELSE
    RAISE NOTICE 'Test passed: Column vendor exists in dwh.dimension_applications';
  END IF;
END $$;

-- Test 7: Check new columns in facts table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'dwh' AND table_name = 'facts' AND column_name = 'action_timezone_id'
  ) THEN
    RAISE EXCEPTION 'Column action_timezone_id does not exist in dwh.facts';
  ELSE
    RAISE NOTICE 'Test passed: Column action_timezone_id exists in dwh.facts';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'dwh' AND table_name = 'facts' AND column_name = 'local_action_dimension_id_date'
  ) THEN
    RAISE EXCEPTION 'Column local_action_dimension_id_date does not exist in dwh.facts';
  ELSE
    RAISE NOTICE 'Test passed: Column local_action_dimension_id_date exists in dwh.facts';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'dwh' AND table_name = 'facts' AND column_name = 'action_dimension_id_season'
  ) THEN
    RAISE EXCEPTION 'Column action_dimension_id_season does not exist in dwh.facts';
  ELSE
    RAISE NOTICE 'Test passed: Column action_dimension_id_season exists in dwh.facts';
  END IF;
END $$;

-- Test 8: Check if new functions exist
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'get_timezone_id_by_lonlat') THEN
    RAISE EXCEPTION 'Function dwh.get_timezone_id_by_lonlat does not exist';
  ELSE
    RAISE NOTICE 'Test passed: Function dwh.get_timezone_id_by_lonlat exists';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'get_season_id') THEN
    RAISE EXCEPTION 'Function dwh.get_season_id does not exist';
  ELSE
    RAISE NOTICE 'Test passed: Function dwh.get_season_id exists';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'get_application_version_id') THEN
    RAISE EXCEPTION 'Function dwh.get_application_version_id does not exist';
  ELSE
    RAISE NOTICE 'Test passed: Function dwh.get_application_version_id exists';
  END IF;
END $$;

-- Test 9: Check if Anonymous user exists in dimension_users
DO $$
DECLARE
  anonymous_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO anonymous_count
  FROM dwh.dimension_users
  WHERE user_id = -1 AND username = 'Anonymous';
  
  IF anonymous_count = 0 THEN
    RAISE EXCEPTION 'Anonymous user (user_id=-1) does not exist in dwh.dimension_users';
  ELSE
    RAISE NOTICE 'Test passed: Anonymous user exists in dwh.dimension_users';
  END IF;
END $$;

-- Test 10: Check if continents are populated
DO $$
DECLARE
  continent_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO continent_count
  FROM dwh.dimension_continents;
  
  IF continent_count = 0 THEN
    RAISE EXCEPTION 'dwh.dimension_continents is not populated';
  ELSE
    RAISE NOTICE 'Test passed: dwh.dimension_continents has % records', continent_count;
  END IF;
END $$;

-- Test 11: Check if timezones are populated
DO $$
DECLARE
  timezone_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO timezone_count
  FROM dwh.dimension_timezones;
  
  IF timezone_count = 0 THEN
    RAISE EXCEPTION 'dwh.dimension_timezones is not populated';
  ELSE
    RAISE NOTICE 'Test passed: dwh.dimension_timezones has % records', timezone_count;
  END IF;
END $$;

-- Test 12: Check if seasons are populated
DO $$
DECLARE
  season_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO season_count
  FROM dwh.dimension_seasons;
  
  IF season_count = 0 THEN
    RAISE EXCEPTION 'dwh.dimension_seasons is not populated';
  ELSE
    RAISE NOTICE 'Test passed: dwh.dimension_seasons has % records', season_count;
  END IF;
END $$;

COMMIT;
