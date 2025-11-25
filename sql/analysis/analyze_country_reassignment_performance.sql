-- Analysis script to validate performance of country reassignment operations
-- This script validates that UPDATE operations with ST_Intersects spatial queries
-- are performing optimally by checking execution times, spatial index usage, and bounding box efficiency
--
-- This script focuses on validating CURRENT performance for country reassignment
-- which is used when country boundaries are updated.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-11-25

-- ============================================================================
-- SETUP: Enable query timing and explain
-- ============================================================================

\timing on
\set ECHO all

-- ============================================================================
-- TEST 1: Analyze country reassignment UPDATE performance
-- Validates: UPDATE operation efficiency, spatial query performance
-- ============================================================================

\echo '============================================================================'
\echo 'TEST 1: Country Reassignment UPDATE Performance Analysis'
\echo 'Validates: UPDATE with ST_Intersects efficiency, spatial index usage'
\echo '============================================================================'

-- Test UPDATE with ST_Intersects (simulating boundary update scenario)
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
UPDATE notes n
SET id_country = get_country(n.longitude, n.latitude, n.note_id)
WHERE EXISTS (
  SELECT 1
  FROM countries c
  WHERE c.updated = TRUE
    AND ST_Intersects(
      ST_MakeEnvelope(
        ST_XMin(c.geom), ST_YMin(c.geom),
        ST_XMax(c.geom), ST_YMax(c.geom),
        4326
      ),
      ST_SetSRID(ST_MakePoint(n.longitude, n.latitude), 4326)
    )
)
LIMIT 100;

-- Rollback to avoid modifying data
ROLLBACK;

-- ============================================================================
-- TEST 2: Bounding box vs full geometry comparison
-- Validates: Bounding box optimization effectiveness
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo 'TEST 2: Bounding Box vs Full Geometry Comparison'
\echo 'Validates: Bounding box optimization effectiveness'
\echo '============================================================================'

-- Test with bounding box (current optimized approach)
\echo 'Testing with bounding box (optimized)...'
\timing on
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT COUNT(*)
FROM notes n
WHERE EXISTS (
  SELECT 1
  FROM countries c
  WHERE c.updated = TRUE
    AND ST_Intersects(
      ST_MakeEnvelope(
        ST_XMin(c.geom), ST_YMin(c.geom),
        ST_XMax(c.geom), ST_YMax(c.geom),
        4326
      ),
      ST_SetSRID(ST_MakePoint(n.longitude, n.latitude), 4326)
    )
)
LIMIT 100;
\timing off

-- Test with full geometry (non-optimized, for comparison)
\echo 'Testing with full geometry (non-optimized)...'
\timing on
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT COUNT(*)
FROM notes n
WHERE EXISTS (
  SELECT 1
  FROM countries c
  WHERE c.updated = TRUE
    AND ST_Contains(c.geom, ST_SetSRID(ST_MakePoint(n.longitude, n.latitude), 4326))
)
LIMIT 100;
\timing off

-- ============================================================================
-- TEST 3: Updated countries identification
-- Validates: Identification of countries needing reassignment
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo 'TEST 3: Updated Countries Identification'
\echo 'Validates: Identification of countries needing reassignment'
\echo '============================================================================'

-- Check which countries are marked as updated
SELECT
  country_id,
  name,
  updated,
  pg_size_pretty(ST_NPoints(geom)) AS geometry_points,
  ST_XMin(geom) AS min_longitude,
  ST_YMin(geom) AS min_latitude,
  ST_XMax(geom) AS max_longitude,
  ST_YMax(geom) AS max_latitude
FROM countries
WHERE updated = TRUE
ORDER BY country_id;

-- Count notes potentially affected by updated countries
SELECT
  COUNT(*) AS potentially_affected_notes
FROM notes n
WHERE EXISTS (
  SELECT 1
  FROM countries c
  WHERE c.updated = TRUE
    AND ST_Intersects(
      ST_MakeEnvelope(
        ST_XMin(c.geom), ST_YMin(c.geom),
        ST_XMax(c.geom), ST_YMax(c.geom),
        4326
      ),
      ST_SetSRID(ST_MakePoint(n.longitude, n.latitude), 4326)
    )
);

-- ============================================================================
-- TEST 4: Spatial index usage for reassignment
-- Validates: PostGIS spatial index effectiveness
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo 'TEST 4: Spatial Index Usage for Reassignment'
\echo 'Validates: PostGIS spatial index effectiveness'
\echo '============================================================================'

-- Check spatial indexes on countries table
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
  AND indexname LIKE '%spatial%' OR indexname LIKE '%geom%'
ORDER BY indexname;

-- Test spatial query plan with bounding box
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT c.country_id, c.name
FROM countries c
WHERE c.updated = TRUE
  AND ST_Intersects(
    ST_MakeEnvelope(-180, -90, 180, 90, 4326),
    c.geom
  );

-- ============================================================================
-- TEST 5: Notes table spatial index usage
-- Validates: Spatial index on notes table for reassignment queries
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo 'TEST 5: Notes Table Spatial Index Usage'
\echo 'Validates: Spatial index on notes table for reassignment queries'
\echo '============================================================================'

-- Check spatial indexes on notes table
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
  AND (indexrelname LIKE '%spatial%' OR indexrelname LIKE '%geom%' OR indexrelname LIKE '%point%')
ORDER BY indexrelname;

-- ============================================================================
-- TEST 6: Performance benchmarks
-- Validates: Execution time meets performance thresholds
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo 'TEST 6: Performance Benchmarks'
\echo 'Validates: Execution time meets performance thresholds'
\echo 'Expected: < 1000ms for 100 row UPDATE with bounding box'
\echo '============================================================================'

-- Test reassignment UPDATE timing
\echo 'Testing reassignment UPDATE (100 rows)...'
\timing on
UPDATE notes n
SET id_country = get_country(n.longitude, n.latitude, n.note_id)
WHERE EXISTS (
  SELECT 1
  FROM countries c
  WHERE c.updated = TRUE
    AND ST_Intersects(
      ST_MakeEnvelope(
        ST_XMin(c.geom), ST_YMin(c.geom),
        ST_XMax(c.geom), ST_YMax(c.geom),
        4326
      ),
      ST_SetSRID(ST_MakePoint(n.longitude, n.latitude), 4326)
    )
)
LIMIT 100;
\timing off
ROLLBACK;

-- ============================================================================
-- TEST 7: Reassignment statistics
-- Validates: Reassignment coverage, efficiency
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo 'TEST 7: Reassignment Statistics'
\echo 'Validates: Reassignment coverage, efficiency'
\echo '============================================================================'

-- Count notes that would be affected by reassignment
SELECT
  COUNT(*) AS total_notes,
  COUNT(CASE WHEN EXISTS (
    SELECT 1
    FROM countries c
    WHERE c.updated = TRUE
      AND ST_Intersects(
        ST_MakeEnvelope(
          ST_XMin(c.geom), ST_YMin(c.geom),
          ST_XMax(c.geom), ST_YMax(c.geom),
          4326
        ),
        ST_SetSRID(ST_MakePoint(n.longitude, n.latitude), 4326)
      )
  ) THEN 1 END) AS notes_in_updated_countries
FROM notes n;

-- ============================================================================
-- FINAL VALIDATION SUMMARY
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo 'FINAL VALIDATION SUMMARY'
\echo '============================================================================'

DO $$
DECLARE
  countries_table_exists BOOLEAN;
  updated_countries_count BIGINT;
  potentially_affected_notes BIGINT;
  spatial_index_exists BOOLEAN;
BEGIN
  -- Check if countries table exists
  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_name = 'countries'
  ) INTO countries_table_exists;

  -- Get statistics
  SELECT COUNT(*) INTO updated_countries_count
  FROM countries
  WHERE updated = TRUE;

  SELECT COUNT(*) INTO potentially_affected_notes
  FROM notes n
  WHERE EXISTS (
    SELECT 1
    FROM countries c
    WHERE c.updated = TRUE
      AND ST_Intersects(
        ST_MakeEnvelope(
          ST_XMin(c.geom), ST_YMin(c.geom),
          ST_XMax(c.geom), ST_YMax(c.geom),
          4326
        ),
        ST_SetSRID(ST_MakePoint(n.longitude, n.latitude), 4326)
      )
  );

  -- Check if spatial index exists on countries
  SELECT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE tablename = 'countries'
      AND (indexname LIKE '%spatial%' OR indexname LIKE '%geom%')
  ) INTO spatial_index_exists;

  RAISE NOTICE '';
  RAISE NOTICE 'Table Validation:';
  IF countries_table_exists THEN
    RAISE NOTICE '  ✅ countries table EXISTS';
  ELSE
    RAISE WARNING '  ❌ countries table MISSING - CRITICAL ISSUE!';
  END IF;

  RAISE NOTICE '';
  RAISE NOTICE 'Reassignment Statistics:';
  RAISE NOTICE '  Countries marked as updated: %', updated_countries_count;
  RAISE NOTICE '  Notes potentially affected: %', potentially_affected_notes;
  
  IF updated_countries_count = 0 THEN
    RAISE NOTICE '  ℹ️  No countries marked as updated - this is normal if boundaries have not changed';
  END IF;

  RAISE NOTICE '';
  RAISE NOTICE 'Index Validation:';
  IF spatial_index_exists THEN
    RAISE NOTICE '  ✅ Spatial index on countries table EXISTS';
  ELSE
    RAISE WARNING '  ❌ Spatial index on countries table MISSING - may impact performance';
  END IF;

  RAISE NOTICE '';
  RAISE NOTICE 'Performance Validation:';
  RAISE NOTICE '  📊 Review TEST 1 EXPLAIN output above:';
  RAISE NOTICE '     ✅ GOOD: Should show efficient UPDATE plan with spatial index usage';
  RAISE NOTICE '     ❌ BAD:  If shows sequential scan without spatial indexes';
  RAISE NOTICE '';
  RAISE NOTICE '  📊 Review TEST 2 comparison above:';
  RAISE NOTICE '     ✅ GOOD: Bounding box approach should be faster than full geometry';
  RAISE NOTICE '     ⚠️  NOTE: Bounding box is used for initial filtering, then full geometry check';
  RAISE NOTICE '';
  RAISE NOTICE '  ⏱️  Review TEST 6 timing above:';
  RAISE NOTICE '     ✅ GOOD: < 1000ms for 100 row UPDATE';
  RAISE NOTICE '     ⚠️  WARNING: > 1000ms may need optimization';
  RAISE NOTICE '';
  RAISE NOTICE '  📊 Review TEST 4 spatial index statistics above:';
  RAISE NOTICE '     ✅ GOOD: idx_scan > 0 (spatial indexes are being used)';
  RAISE NOTICE '     ⚠️  WARNING: idx_scan = 0 (spatial indexes not used yet)';
  RAISE NOTICE '';
  RAISE NOTICE '============================================================================';
END $$;

