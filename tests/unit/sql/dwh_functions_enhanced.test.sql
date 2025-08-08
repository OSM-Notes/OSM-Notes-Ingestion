-- Unit tests for enhanced DWH functions
-- Author: Andres Gomez (AngocA)
-- Version: 2025-08-08

BEGIN;

-- Test 1: Test get_timezone_id_by_lonlat function
DO $$
DECLARE
  tz_id INTEGER;
BEGIN
  -- Test for UTC+0 (Greenwich)
  SELECT dwh.get_timezone_id_by_lonlat(0.0, 51.5) INTO tz_id;
  IF tz_id IS NULL THEN
    RAISE EXCEPTION 'get_timezone_id_by_lonlat returned NULL for Greenwich coordinates';
  ELSE
    RAISE NOTICE 'Test passed: get_timezone_id_by_lonlat returned % for Greenwich', tz_id;
  END IF;
  
  -- Test for UTC-5 (New York area)
  SELECT dwh.get_timezone_id_by_lonlat(-74.0, 40.7) INTO tz_id;
  IF tz_id IS NULL THEN
    RAISE EXCEPTION 'get_timezone_id_by_lonlat returned NULL for New York coordinates';
  ELSE
    RAISE NOTICE 'Test passed: get_timezone_id_by_lonlat returned % for New York', tz_id;
  END IF;
  
  -- Test for UTC+8 (Beijing area)
  SELECT dwh.get_timezone_id_by_lonlat(116.4, 39.9) INTO tz_id;
  IF tz_id IS NULL THEN
    RAISE EXCEPTION 'get_timezone_id_by_lonlat returned NULL for Beijing coordinates';
  ELSE
    RAISE NOTICE 'Test passed: get_timezone_id_by_lonlat returned % for Beijing', tz_id;
  END IF;
END $$;

-- Test 2: Test get_season_id function
DO $$
DECLARE
  season_id INTEGER;
BEGIN
  -- Test for Northern Hemisphere winter (January)
  SELECT dwh.get_season_id('2024-01-15 12:00:00'::timestamp, 40.7) INTO season_id;
  IF season_id IS NULL THEN
    RAISE EXCEPTION 'get_season_id returned NULL for Northern winter';
  ELSE
    RAISE NOTICE 'Test passed: get_season_id returned % for Northern winter', season_id;
  END IF;
  
  -- Test for Southern Hemisphere summer (January)
  SELECT dwh.get_season_id('2024-01-15 12:00:00'::timestamp, -33.9) INTO season_id;
  IF season_id IS NULL THEN
    RAISE EXCEPTION 'get_season_id returned NULL for Southern summer';
  ELSE
    RAISE NOTICE 'Test passed: get_season_id returned % for Southern summer', season_id;
  END IF;
  
  -- Test for equatorial region (no seasons)
  SELECT dwh.get_season_id('2024-01-15 12:00:00'::timestamp, 0.0) INTO season_id;
  IF season_id IS NULL THEN
    RAISE EXCEPTION 'get_season_id returned NULL for equatorial region';
  ELSE
    RAISE NOTICE 'Test passed: get_season_id returned % for equatorial region', season_id;
  END IF;
END $$;

-- Test 3: Test get_application_version_id function
DO $$
DECLARE
  app_version_id INTEGER;
BEGIN
  -- Test for known application version
  SELECT dwh.get_application_version_id(1, '1.0.0') INTO app_version_id;
  IF app_version_id IS NULL THEN
    RAISE EXCEPTION 'get_application_version_id returned NULL for known version';
  ELSE
    RAISE NOTICE 'Test passed: get_application_version_id returned % for known version', app_version_id;
  END IF;
  
  -- Test for unknown application version (should create new)
  SELECT dwh.get_application_version_id(999, '9.9.9') INTO app_version_id;
  IF app_version_id IS NULL THEN
    RAISE EXCEPTION 'get_application_version_id returned NULL for unknown version';
  ELSE
    RAISE NOTICE 'Test passed: get_application_version_id returned % for unknown version', app_version_id;
  END IF;
END $$;

-- Test 4: Test get_local_date_id function
DO $$
DECLARE
  local_date_id INTEGER;
BEGIN
  -- Test for local date calculation
  SELECT dwh.get_local_date_id('2024-01-15 12:00:00'::timestamp, 1) INTO local_date_id;
  IF local_date_id IS NULL THEN
    RAISE EXCEPTION 'get_local_date_id returned NULL for local date';
  ELSE
    RAISE NOTICE 'Test passed: get_local_date_id returned % for local date', local_date_id;
  END IF;
END $$;

-- Test 5: Test get_local_hour_of_week_id function
DO $$
DECLARE
  local_hour_id INTEGER;
BEGIN
  -- Test for local hour calculation
  SELECT dwh.get_local_hour_of_week_id('2024-01-15 12:00:00'::timestamp, 1) INTO local_hour_id;
  IF local_hour_id IS NULL THEN
    RAISE EXCEPTION 'get_local_hour_of_week_id returned NULL for local hour';
  ELSE
    RAISE NOTICE 'Test passed: get_local_hour_of_week_id returned % for local hour', local_hour_id;
  END IF;
END $$;

-- Test 6: Test enhanced get_date_id function
DO $$
DECLARE
  date_id INTEGER;
  date_record RECORD;
BEGIN
  -- Test for date with enhanced attributes
  SELECT dwh.get_date_id('2024-01-15'::date) INTO date_id;
  
  -- Check if enhanced attributes are populated
  SELECT * INTO date_record
  FROM dwh.dimension_days
  WHERE dimension_day_id = date_id;
  
  IF date_record.iso_week IS NULL THEN
    RAISE EXCEPTION 'get_date_id did not populate iso_week';
  ELSE
    RAISE NOTICE 'Test passed: get_date_id populated iso_week = %', date_record.iso_week;
  END IF;
  
  IF date_record.quarter IS NULL THEN
    RAISE EXCEPTION 'get_date_id did not populate quarter';
  ELSE
    RAISE NOTICE 'Test passed: get_date_id populated quarter = %', date_record.quarter;
  END IF;
  
  IF date_record.month_name IS NULL THEN
    RAISE EXCEPTION 'get_date_id did not populate month_name';
  ELSE
    RAISE NOTICE 'Test passed: get_date_id populated month_name = %', date_record.month_name;
  END IF;
END $$;

-- Test 7: Test enhanced get_time_of_week_id function
DO $$
DECLARE
  time_id INTEGER;
  time_record RECORD;
BEGIN
  -- Test for time with enhanced attributes
  SELECT dwh.get_time_of_week_id('2024-01-15 12:00:00'::timestamp) INTO time_id;
  
  -- Check if enhanced attributes are populated
  SELECT * INTO time_record
  FROM dwh.dimension_time_of_week
  WHERE dimension_tow_id = time_id;
  
  IF time_record.hour_of_week IS NULL THEN
    RAISE EXCEPTION 'get_time_of_week_id did not populate hour_of_week';
  ELSE
    RAISE NOTICE 'Test passed: get_time_of_week_id populated hour_of_week = %', time_record.hour_of_week;
  END IF;
  
  IF time_record.period_of_day IS NULL THEN
    RAISE EXCEPTION 'get_time_of_week_id did not populate period_of_day';
  ELSE
    RAISE NOTICE 'Test passed: get_time_of_week_id populated period_of_day = %', time_record.period_of_day;
  END IF;
END $$;

-- Test 8: Test SCD2 user dimension functionality
DO $$
DECLARE
  user_count INTEGER;
  current_user_count INTEGER;
BEGIN
  -- Check if Anonymous user exists and is current
  SELECT COUNT(*) INTO user_count
  FROM dwh.dimension_users
  WHERE user_id = -1;
  
  IF user_count = 0 THEN
    RAISE EXCEPTION 'Anonymous user does not exist in dimension_users';
  ELSE
    RAISE NOTICE 'Test passed: Anonymous user exists in dimension_users';
  END IF;
  
  -- Check if there's only one current row per user_id
  SELECT COUNT(*) INTO current_user_count
  FROM dwh.dimension_users
  WHERE is_current = TRUE
  GROUP BY user_id
  HAVING COUNT(*) > 1;
  
  IF current_user_count > 0 THEN
    RAISE EXCEPTION 'Multiple current rows found for some users (SCD2 violation)';
  ELSE
    RAISE NOTICE 'Test passed: SCD2 constraint maintained (one current row per user)';
  END IF;
END $$;

-- Test 9: Test bridge table functionality
DO $$
DECLARE
  bridge_count INTEGER;
BEGIN
  -- Check if bridge table exists and has correct structure
  SELECT COUNT(*) INTO bridge_count
  FROM information_schema.columns
  WHERE table_schema = 'dwh' 
    AND table_name = 'fact_hashtags'
    AND column_name IN ('fact_id', 'dimension_hashtag_id', 'position');
  
  IF bridge_count < 3 THEN
    RAISE EXCEPTION 'fact_hashtags bridge table missing required columns';
  ELSE
    RAISE NOTICE 'Test passed: fact_hashtags bridge table has correct structure';
  END IF;
END $$;

-- Test 10: Test dimension population
DO $$
DECLARE
  continent_count INTEGER;
  timezone_count INTEGER;
  season_count INTEGER;
BEGIN
  -- Check continents population
  SELECT COUNT(*) INTO continent_count
  FROM dwh.dimension_continents;
  
  IF continent_count < 5 THEN
    RAISE EXCEPTION 'dimension_continents not properly populated (expected at least 5)';
  ELSE
    RAISE NOTICE 'Test passed: dimension_continents has % records', continent_count;
  END IF;
  
  -- Check timezones population
  SELECT COUNT(*) INTO timezone_count
  FROM dwh.dimension_timezones;
  
  IF timezone_count < 10 THEN
    RAISE EXCEPTION 'dimension_timezones not properly populated (expected at least 10)';
  ELSE
    RAISE NOTICE 'Test passed: dimension_timezones has % records', timezone_count;
  END IF;
  
  -- Check seasons population
  SELECT COUNT(*) INTO season_count
  FROM dwh.dimension_seasons;
  
  IF season_count < 3 THEN
    RAISE EXCEPTION 'dimension_seasons not properly populated (expected at least 3)';
  ELSE
    RAISE NOTICE 'Test passed: dimension_seasons has % records', season_count;
  END IF;
END $$;

COMMIT;
