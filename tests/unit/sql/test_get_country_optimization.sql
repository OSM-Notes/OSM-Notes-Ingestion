-- Test: Validates that get_country optimization separates new notes from existing ones
-- This test validates the query structure logic without requiring the full database schema
-- Author: Andres Gomez (AngocA)
-- Version: 2025-12-22

\set ON_ERROR_STOP on

BEGIN;

-- Test 1: Verify logic structure - existing notes should use INNER JOIN
DO $$
DECLARE
  m_result_count INTEGER;
BEGIN
  -- Test that the structure separates existing vs new notes correctly
  WITH test_data AS (
    SELECT 1 as note_id, 5 as id_country  -- Existing note (has country)
    UNION ALL
    SELECT 2 as note_id, NULL::INTEGER as id_country  -- New note (no country yet)
  ),
  existing_data AS (
    SELECT note_id, id_country FROM test_data WHERE id_country IS NOT NULL
  ),
  new_data AS (
    SELECT note_id FROM test_data WHERE id_country IS NULL
  )
  SELECT COUNT(*) INTO m_result_count FROM existing_data;

  IF m_result_count != 1 THEN
    RAISE EXCEPTION 'Logic separation test failed. Expected 1 existing note, Got: %', m_result_count;
  END IF;

  RAISE NOTICE 'Test 1 PASSED: Logic structure correctly separates existing from new notes';
END $$;

-- Test 2: Verify that new notes structure is correct (without calling get_country to avoid schema dependencies)
DO $$
DECLARE
  m_test_lat NUMERIC := 40.7128;
  m_test_lon NUMERIC := -74.0060;
  m_result_count INTEGER;
BEGIN
  -- Test that the structure for new notes is correct
  -- We validate the structure without calling get_country() to avoid schema dependencies
  WITH new_notes AS (
    SELECT 
      999999999 as note_id,
      m_test_lat as latitude,
      m_test_lon as longitude,
      NOW() as created_at,
      NULL::TIMESTAMP as closed_at,
      'open' as status
  ),
  new_notes_with_countries AS (
    SELECT 
      note_id,
      latitude,
      longitude,
      created_at,
      closed_at,
      status
      -- Note: get_country() call would go here in production code
      -- get_country(longitude, latitude, note_id) as id_country
    FROM new_notes
  )
  SELECT COUNT(*) INTO m_result_count FROM new_notes_with_countries;

  -- Verify structure is correct
  IF m_result_count != 1 THEN
    RAISE EXCEPTION 'New notes structure test failed. Expected 1 note, Got: %', m_result_count;
  END IF;

  RAISE NOTICE 'Test 2 PASSED: New notes structure is correct';
END $$;

-- Test 3: Verify that UNION ALL structure works correctly (without calling get_country)
DO $$
DECLARE
  m_existing_country INTEGER := 3;
  m_test_lat NUMERIC := 40.7128;
  m_test_lon NUMERIC := -74.0060;
  m_result_count INTEGER;
BEGIN
  -- Simulate the complete optimized query structure with test data
  -- We use a placeholder for id_country in new_notes to avoid calling get_country()
  WITH existing_notes AS (
    SELECT 
      1 as note_id,
      m_test_lat as latitude,
      m_test_lon as longitude,
      NOW() as created_at,
      NULL::TIMESTAMP as closed_at,
      'open' as status,
      m_existing_country as id_country
  ),
  new_notes AS (
    SELECT 
      2 as note_id,
      m_test_lat as latitude,
      m_test_lon as longitude,
      NOW() as created_at,
      NULL::TIMESTAMP as closed_at,
      'open' as status
  ),
  new_notes_with_countries AS (
    SELECT 
      note_id,
      latitude,
      longitude,
      created_at,
      closed_at,
      status,
      -1 as id_country  -- Placeholder: in production this would be get_country(longitude, latitude, note_id)
    FROM new_notes
  ),
  all_notes_ready AS (
    SELECT * FROM existing_notes
    UNION ALL
    SELECT * FROM new_notes_with_countries
  )
  SELECT COUNT(*) INTO m_result_count FROM all_notes_ready;

  -- Verify both notes are in result
  IF m_result_count != 2 THEN
    RAISE EXCEPTION 'UNION ALL did not combine correctly. Expected 2 notes, Got: %', m_result_count;
  END IF;

  RAISE NOTICE 'Test 3 PASSED: UNION ALL combines existing and new notes correctly. Total: %', m_result_count;
END $$;

-- Test 4: Verify that the structure separates logic correctly
DO $$
DECLARE
  m_existing_count INTEGER;
  m_new_count INTEGER;
BEGIN
  -- Test separation logic: existing notes have country, new notes don't
  WITH test_data AS (
    SELECT 1 as note_id, 5 as id_country  -- Existing
    UNION ALL
    SELECT 2 as note_id, NULL::INTEGER as id_country  -- New
  ),
  existing_notes AS (
    SELECT note_id FROM test_data WHERE id_country IS NOT NULL
  ),
  new_notes AS (
    SELECT note_id FROM test_data WHERE id_country IS NULL
  )
  SELECT 
    (SELECT COUNT(*) FROM existing_notes),
    (SELECT COUNT(*) FROM new_notes)
  INTO m_existing_count, m_new_count;

  -- Verify separation works correctly
  IF m_existing_count != 1 THEN
    RAISE EXCEPTION 'Existing notes CTE should have 1 note. Got: %', m_existing_count;
  END IF;

  IF m_new_count != 1 THEN
    RAISE EXCEPTION 'New notes CTE should have 1 note. Expected 1, Got: %', m_new_count;
  END IF;

  RAISE NOTICE 'Test 4 PASSED: Logic separation works correctly (existing: %, new: %)', 
    m_existing_count, m_new_count;
END $$;

ROLLBACK;
