-- Analysis script to validate performance of integrity verification queries
-- This script validates that the current implementation is performing optimally
-- by checking index usage, query plans, and execution times
--
-- This script focuses on validating CURRENT performance rather than comparing
-- with old implementations, making it useful long-term for performance monitoring.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-11-25

-- ============================================================================
-- SETUP: Enable query timing and explain
-- ============================================================================

\timing on
\set ECHO all

-- ============================================================================
-- TEST 1: Analyze CURRENT integrity verification query
-- Uses: Composite index + Direct ST_Contains check
-- ============================================================================

\echo '============================================================================'
\echo 'TEST 1: Current Integrity Verification Query'
\echo 'Uses: Composite index notes_country_note_id + Direct ST_Contains'
\echo 'Validates: Index usage, query plan efficiency, execution time'
\echo '============================================================================'

EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
WITH notes_to_verify AS (
  SELECT n.note_id,
         n.id_country,
         n.longitude,
         n.latitude
  FROM notes AS n
  WHERE n.id_country IS NOT NULL
  AND 0 <= n.note_id AND n.note_id < 5000
),
verified AS (
  SELECT ntv.note_id,
         ntv.id_country AS current_country,
         CASE
           WHEN ST_Contains(c.geom, ST_SetSRID(ST_Point(ntv.longitude, ntv.latitude), 4326))
           THEN ntv.id_country
           ELSE -1
         END AS verified_country
  FROM notes_to_verify ntv
  LEFT JOIN countries c ON c.country_id = ntv.id_country
),
invalidated AS (
  SELECT ntv.note_id
  FROM notes_to_verify ntv
  JOIN verified v ON ntv.note_id = v.note_id
  WHERE v.verified_country = -1 OR v.verified_country <> v.current_country
)
SELECT COUNT(*) FROM invalidated;

-- ============================================================================
-- TEST 2: Performance benchmarks and thresholds
-- Validates that current performance meets expected thresholds
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo 'TEST 2: Performance Benchmarks'
\echo 'Validates: Execution time meets performance thresholds'
\echo 'Expected: < 1ms for 5000 notes, < 10ms for 100000 notes'
\echo '============================================================================'

-- Test with different data sizes to validate scalability
\echo 'Testing with 5000 notes...'
\timing on
WITH notes_to_verify AS (
  SELECT n.note_id, n.id_country, n.longitude, n.latitude
  FROM notes AS n
  WHERE n.id_country IS NOT NULL
  AND 0 <= n.note_id AND n.note_id < 5000
),
verified AS (
  SELECT ntv.note_id, ntv.id_country AS current_country,
         CASE
           WHEN ST_Contains(c.geom, ST_SetSRID(ST_Point(ntv.longitude, ntv.latitude), 4326))
           THEN ntv.id_country
           ELSE -1
         END AS verified_country
  FROM notes_to_verify ntv
  LEFT JOIN countries c ON c.country_id = ntv.id_country
)
SELECT COUNT(*) INTO TEMP TABLE test2_result FROM verified WHERE verified_country = -1 OR verified_country <> current_country;
\timing off

-- Validate TEST 2 results automatically
DO $$
DECLARE
  execution_time_ms NUMERIC;
BEGIN
  -- Note: \timing output is not directly accessible in SQL
  -- This is a placeholder - actual timing is shown by \timing command
  RAISE NOTICE '';
  RAISE NOTICE 'TEST 2 Validation:';
  RAISE NOTICE '  Check timing output above - should be < 1ms for 5000 notes';
  RAISE NOTICE '  If timing shows > 1ms, performance may need optimization';
END $$;

-- ============================================================================
-- TEST 3: Index usage verification
-- Verify that the composite index is being used
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo 'TEST 3: Index Usage Verification'
\echo 'Verify that notes_country_note_id index is being used'
\echo '============================================================================'

EXPLAIN (ANALYZE, BUFFERS)
SELECT n.note_id, n.id_country
FROM notes AS n
WHERE n.id_country IS NOT NULL
AND 0 <= n.note_id AND n.note_id < 5000;

-- ============================================================================
-- TEST 4: Index statistics
-- Show index size and usage statistics
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo 'TEST 4: Index Statistics'
\echo 'Show index sizes and usage'
\echo '============================================================================'

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
  AND indexrelname IN ('notes_country_note_id', 'notes_countries', 'notes_spatial')
ORDER BY indexrelname;

-- ============================================================================
-- TEST 5: Scalability test with larger dataset
-- Validates performance with realistic data sizes
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo 'TEST 5: Scalability Test'
\echo 'Validates: Performance scales well with larger datasets'
\echo 'Expected: Linear scaling, index usage maintained'
\echo '============================================================================'

-- Test with larger dataset (if available)
\echo 'Testing with 100000 notes (if available)...'
\timing on
WITH notes_to_verify AS (
  SELECT n.note_id, n.id_country, n.longitude, n.latitude
  FROM notes AS n
  WHERE n.id_country IS NOT NULL
  AND 0 <= n.note_id AND n.note_id < 100000
),
verified AS (
  SELECT ntv.note_id, ntv.id_country AS current_country,
         CASE
           WHEN ST_Contains(c.geom, ST_SetSRID(ST_Point(ntv.longitude, ntv.latitude), 4326))
           THEN ntv.id_country
           ELSE -1
         END AS verified_country
  FROM notes_to_verify ntv
  LEFT JOIN countries c ON c.country_id = ntv.id_country
)
SELECT COUNT(*) INTO TEMP TABLE test5_result FROM verified WHERE verified_country = -1 OR verified_country <> current_country;
\timing off

-- Validate TEST 5 results automatically
DO $$
DECLARE
  note_count BIGINT;
BEGIN
  SELECT COUNT(*) INTO note_count FROM notes WHERE id_country IS NOT NULL AND note_id < 100000;
  
  RAISE NOTICE '';
  RAISE NOTICE 'TEST 5 Validation:';
  IF note_count >= 100000 THEN
    RAISE NOTICE '  Check timing output above - should be < 10ms for 100000 notes';
    RAISE NOTICE '  If timing shows > 10ms, performance may need optimization';
  ELSE
    RAISE NOTICE '  ⚠️  Only % notes available (less than 100000)', note_count;
    RAISE NOTICE '  Test skipped - not enough data for scalability test';
  END IF;
END $$;

-- Cleanup temp tables
DROP TABLE IF EXISTS test2_result;
DROP TABLE IF EXISTS test5_result;

-- ============================================================================
-- SUMMARY: Automatic validation summary
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo 'SUMMARY: Automatic Performance Validation'
\echo '============================================================================'

-- Validate index exists and is being used
DO $$
DECLARE
  index_exists BOOLEAN;
  index_scans INTEGER;
  index_name TEXT := 'notes_country_note_id';
BEGIN
  -- Check if index exists
  SELECT EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE tablename = 'notes' 
    AND indexname = index_name
  ) INTO index_exists;
  
  -- Get index scan count
  SELECT COALESCE(idx_scan, 0) INTO index_scans
  FROM pg_stat_user_indexes
  WHERE relname = 'notes' 
    AND indexrelname = index_name;
  
  -- Report results
  IF index_exists THEN
    RAISE NOTICE '✅ Index % exists', index_name;
  ELSE
    RAISE WARNING '❌ Index % does NOT exist - performance will be degraded!', index_name;
  END IF;
  
  IF index_scans > 0 THEN
    RAISE NOTICE '✅ Index % has been used % times', index_name, index_scans;
  ELSE
    RAISE WARNING '⚠️  Index % exists but has NOT been used yet (idx_scan = 0)', index_name;
    RAISE NOTICE '   This is normal if the query has not been executed yet.';
  END IF;
END $$;

-- Validate table statistics
DO $$
DECLARE
  table_size TEXT;
  note_count BIGINT;
  notes_with_country BIGINT;
BEGIN
  -- Get table size
  SELECT pg_size_pretty(pg_total_relation_size('notes')) INTO table_size;
  
  -- Get note counts
  SELECT COUNT(*) INTO note_count FROM notes;
  SELECT COUNT(*) INTO notes_with_country FROM notes WHERE id_country IS NOT NULL;
  
  RAISE NOTICE '';
  RAISE NOTICE 'Database Statistics:';
  RAISE NOTICE '  Table size: %', table_size;
  RAISE NOTICE '  Total notes: %', note_count;
  RAISE NOTICE '  Notes with country: % (%.1f%%)', 
    notes_with_country, 
    CASE WHEN note_count > 0 THEN (notes_with_country::NUMERIC / note_count * 100) ELSE 0 END;
END $$;

-- Final automatic validation summary
DO $$
DECLARE
  index_exists BOOLEAN;
  index_scans INTEGER;
  uses_index_scan BOOLEAN := FALSE;
  plan_text TEXT;
BEGIN
  -- Check index exists and is used
  SELECT EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE tablename = 'notes' 
    AND indexname = 'notes_country_note_id'
  ) INTO index_exists;
  
  SELECT COALESCE(idx_scan, 0) INTO index_scans
  FROM pg_stat_user_indexes
  WHERE relname = 'notes' 
    AND indexrelname = 'notes_country_note_id';
  
  RAISE NOTICE '';
  RAISE NOTICE '============================================================================';
  RAISE NOTICE 'FINAL VALIDATION SUMMARY';
  RAISE NOTICE '============================================================================';
  RAISE NOTICE '';
  
  -- Index validation
  IF index_exists THEN
    RAISE NOTICE '✅ Index notes_country_note_id EXISTS';
  ELSE
    RAISE WARNING '❌ Index notes_country_note_id MISSING - CRITICAL ISSUE!';
  END IF;
  
  IF index_scans > 0 THEN
    RAISE NOTICE '✅ Index has been used % times (idx_scan = %)', index_scans, index_scans;
  ELSE
    RAISE NOTICE '⚠️  Index exists but not used yet (idx_scan = 0)';
    RAISE NOTICE '   This is normal if queries have not been executed yet.';
  END IF;
  
  RAISE NOTICE '';
  RAISE NOTICE 'Performance Validation:';
  RAISE NOTICE '  📊 Review TEST 1 EXPLAIN output above:';
  RAISE NOTICE '     ✅ GOOD: Should show "Index Scan using notes_country_note_id"';
  RAISE NOTICE '     ❌ BAD:  If shows "Seq Scan" - index is not being used!';
  RAISE NOTICE '';
  RAISE NOTICE '  ⏱️  Review TEST 2 timing above:';
  RAISE NOTICE '     ✅ GOOD: < 1ms for 5000 notes';
  RAISE NOTICE '     ⚠️  WARNING: > 1ms - may need optimization';
  RAISE NOTICE '';
  RAISE NOTICE '  📈 Review TEST 5 timing above (if enough data):';
  RAISE NOTICE '     ✅ GOOD: < 10ms for 100000 notes';
  RAISE NOTICE '     ⚠️  WARNING: > 10ms - may need optimization';
  RAISE NOTICE '';
  RAISE NOTICE '  📊 Review TEST 4 statistics above:';
  RAISE NOTICE '     ✅ GOOD: idx_scan > 0 (index is being used)';
  RAISE NOTICE '     ⚠️  WARNING: idx_scan = 0 (index not used yet)';
  RAISE NOTICE '';
  RAISE NOTICE '============================================================================';
END $$;

