-- Analysis script to validate performance of country assignment operations
-- This script validates that UPDATE operations with get_country() function
-- are performing optimally by checking execution times, index usage, and spatial query efficiency
--
-- This script focuses on validating CURRENT performance for country assignment
-- which uses UPDATE with get_country() function calls.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-11-25

-- ============================================================================
-- SETUP: Enable query timing and explain
-- ============================================================================

\timing on
\set ECHO all

-- ============================================================================
-- TEST 1: Analyze country assignment UPDATE performance
-- Validates: UPDATE operation efficiency, function call overhead
-- ============================================================================

\echo '============================================================================'
\echo 'TEST 1: Country Assignment UPDATE Performance Analysis'
\echo 'Validates: UPDATE with get_country() efficiency, index usage'
\echo '============================================================================'

-- Test UPDATE with get_country() function
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
UPDATE notes AS n /* Notes-assign chunk */
SET id_country = get_country(n.longitude, n.latitude, n.note_id)
WHERE n.id_country IS NULL
  AND n.note_id BETWEEN 1 AND 1000
LIMIT 100;

-- Rollback to avoid modifying data
ROLLBACK;

-- ============================================================================
-- TEST 2: get_country() function performance
-- Validates: Function execution time, spatial query efficiency
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo 'TEST 2: get_country() Function Performance'
\echo 'Validates: Function execution time, spatial query efficiency'
\echo '============================================================================'

-- Test function call performance
DO $$
DECLARE
  start_time TIMESTAMP;
  end_time INTERVAL;
  country_id INTEGER;
  test_count INTEGER := 100;
  i INTEGER;
BEGIN
  start_time := clock_timestamp();
  
  FOR i IN 1..test_count LOOP
    -- Test with sample coordinates
    SELECT get_country(40.7128, -74.0060, i) INTO country_id;
  END LOOP;
  
  end_time := clock_timestamp() - start_time;
  RAISE NOTICE 'get_country() called % times in %', test_count, end_time;
  RAISE NOTICE 'Average time per call: %', (EXTRACT(EPOCH FROM end_time) * 1000 / test_count) || ' ms';
END $$;

-- ============================================================================
-- TEST 3: Chunk-based assignment performance
-- Validates: Chunk processing efficiency, parallel processing readiness
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo 'TEST 3: Chunk-based Assignment Performance'
\echo 'Validates: Chunk processing efficiency, parallel processing readiness'
\echo '============================================================================'

-- Test chunk-based UPDATE (simulating parallel processing)
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
WITH target AS (
  SELECT UNNEST(ARRAY[1, 2, 3, 4, 5, 6, 7, 8, 9, 10])::BIGINT AS note_id
),
updated AS (
  UPDATE notes AS n /* Notes-assign chunk */
  SET id_country = get_country(n.longitude, n.latitude, n.note_id)
  FROM target t
  WHERE n.note_id = t.note_id
  AND n.id_country IS NULL
  RETURNING n.note_id
)
SELECT COUNT(*) FROM updated;

-- Rollback to avoid modifying data
ROLLBACK;

-- ============================================================================
-- TEST 4: Spatial index usage validation
-- Validates: PostGIS index usage for country boundaries
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo 'TEST 4: Spatial Index Usage Validation'
\echo 'Validates: PostGIS index usage for country boundaries'
\echo '============================================================================'

-- Check if spatial indexes exist on countries table
SELECT
  schemaname,
  tablename,
  indexname,
  pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
  idx_scan AS index_scans,
  idx_tup_read AS tuples_read,
  idx_tup_fetch AS tuples_fetched
FROM pg_stat_user_indexes
WHERE relname = 'countries'
ORDER BY indexname;

-- Test spatial query plan
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT country_id
FROM countries
WHERE ST_Contains(geom, ST_SetSRID(ST_Point(-74.0060, 40.7128), 4326))
LIMIT 1;

-- ============================================================================
-- TEST 5: Notes table index usage for assignment
-- Validates: Index effectiveness for UPDATE operations
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo 'TEST 5: Notes Table Index Usage for Assignment'
\echo 'Validates: Index effectiveness for UPDATE operations'
\echo '============================================================================'

-- Check indexes on notes table
SELECT
  schemaname,
  relname AS tablename,
  indexrelname AS indexname,
  pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
  idx_scan AS index_scans,
  idx_tup_read AS tuples_read,
  idx_tup_fetch AS tuples_fetched
FROM pg_stat_user_indexes
WHERE relname = 'notes'
  AND indexrelname IN ('pk_notes', 'notes_country_note_id', 'notes_spatial')
ORDER BY indexrelname;

-- ============================================================================
-- TEST 6: Performance benchmarks
-- Validates: Execution time meets performance thresholds
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo 'TEST 6: Performance Benchmarks'
\echo 'Validates: Execution time meets performance thresholds'
\echo 'Expected: < 10ms per get_country() call, < 500ms for 100 row UPDATE'
\echo '============================================================================'

-- Test single function call timing
\echo 'Testing single get_country() call...'
\timing on
SELECT get_country(40.7128, -74.0060, 1);
\timing off

-- Test chunk UPDATE timing
\echo 'Testing chunk UPDATE (100 rows)...'
\timing on
UPDATE notes AS n /* Notes-assign chunk */
SET id_country = get_country(n.longitude, n.latitude, n.note_id)
WHERE n.id_country IS NULL
  AND n.note_id BETWEEN 1 AND 1000
LIMIT 100;
\timing off
ROLLBACK;

-- ============================================================================
-- TEST 7: Country assignment statistics
-- Validates: Assignment coverage, distribution
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo 'TEST 7: Country Assignment Statistics'
\echo 'Validates: Assignment coverage, distribution'
\echo '============================================================================'

SELECT
  COUNT(*) AS total_notes,
  COUNT(id_country) AS notes_with_country,
  COUNT(*) - COUNT(id_country) AS notes_without_country,
  CASE
    WHEN COUNT(*) > 0 THEN ROUND((COUNT(id_country)::NUMERIC / COUNT(*) * 100)::NUMERIC, 2)
    ELSE 0
  END AS assignment_percentage
FROM notes;

-- Distribution by country
SELECT
  id_country,
  COUNT(*) AS note_count,
  ROUND((COUNT(*)::NUMERIC / (SELECT COUNT(*) FROM notes WHERE id_country IS NOT NULL) * 100)::NUMERIC, 2) AS percentage
FROM notes
WHERE id_country IS NOT NULL
GROUP BY id_country
ORDER BY note_count DESC
LIMIT 10;

-- ============================================================================
-- FINAL VALIDATION SUMMARY
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo 'FINAL VALIDATION SUMMARY'
\echo '============================================================================'

DO $$
DECLARE
  function_exists BOOLEAN;
  countries_table_exists BOOLEAN;
  countries_count BIGINT;
  notes_count BIGINT;
  notes_with_country BIGINT;
  assignment_percentage NUMERIC;
  index_exists BOOLEAN;
BEGIN
  -- Check if function exists
  SELECT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public' AND p.proname = 'get_country'
  ) INTO function_exists;

  -- Check if countries table exists
  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_name = 'countries'
  ) INTO countries_table_exists;

  -- Get statistics
  SELECT COUNT(*) INTO countries_count FROM countries;
  SELECT COUNT(*) INTO notes_count FROM notes;
  SELECT COUNT(*) INTO notes_with_country FROM notes WHERE id_country IS NOT NULL;
  
  IF notes_count > 0 THEN
    assignment_percentage := (notes_with_country::NUMERIC / notes_count * 100);
  ELSE
    assignment_percentage := 0;
  END IF;

  -- Check if composite index exists
  SELECT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE tablename = 'notes'
      AND indexname = 'notes_country_note_id'
  ) INTO index_exists;

  RAISE NOTICE '';
  RAISE NOTICE 'Function and Table Validation:';
  IF function_exists THEN
    RAISE NOTICE '  ✅ get_country() function EXISTS';
  ELSE
    RAISE WARNING '  ❌ get_country() function MISSING - CRITICAL ISSUE!';
  END IF;

  IF countries_table_exists THEN
    RAISE NOTICE '  ✅ countries table EXISTS (% countries)', countries_count;
  ELSE
    RAISE WARNING '  ❌ countries table MISSING - CRITICAL ISSUE!';
  END IF;

  RAISE NOTICE '';
  RAISE NOTICE 'Assignment Statistics:';
  RAISE NOTICE '  Total notes: %', notes_count;
  RAISE NOTICE '  Notes with country: % (%.1f%%)', notes_with_country, assignment_percentage;
  RAISE NOTICE '  Notes without country: %', notes_count - notes_with_country;

  RAISE NOTICE '';
  RAISE NOTICE 'Index Validation:';
  IF index_exists THEN
    RAISE NOTICE '  ✅ Composite index notes_country_note_id EXISTS';
  ELSE
    RAISE WARNING '  ❌ Composite index notes_country_note_id MISSING - may impact performance';
  END IF;

  RAISE NOTICE '';
  RAISE NOTICE 'Performance Validation:';
  RAISE NOTICE '  📊 Review TEST 1 EXPLAIN output above:';
  RAISE NOTICE '     ✅ GOOD: Should show efficient UPDATE plan with index usage';
  RAISE NOTICE '     ❌ BAD:  If shows sequential scan without indexes';
  RAISE NOTICE '';
  RAISE NOTICE '  ⏱️  Review TEST 2 timing above:';
  RAISE NOTICE '     ✅ GOOD: < 10ms per get_country() call';
  RAISE NOTICE '     ⚠️  WARNING: > 10ms may indicate spatial index issues';
  RAISE NOTICE '';
  RAISE NOTICE '  ⏱️  Review TEST 6 timing above:';
  RAISE NOTICE '     ✅ GOOD: < 500ms for 100 row UPDATE';
  RAISE NOTICE '     ⚠️  WARNING: > 500ms may need optimization';
  RAISE NOTICE '';
  RAISE NOTICE '  📊 Review TEST 4 spatial index statistics above:';
  RAISE NOTICE '     ✅ GOOD: idx_scan > 0 (spatial indexes are being used)';
  RAISE NOTICE '     ⚠️  WARNING: idx_scan = 0 (spatial indexes not used yet)';
  RAISE NOTICE '';
  RAISE NOTICE '============================================================================';
END $$;

