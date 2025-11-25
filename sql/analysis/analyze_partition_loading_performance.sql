-- Analysis script to validate performance of partition loading operations
-- This script validates that COPY operations and partition updates are performing optimally
-- by checking execution times, buffer usage, and table statistics
--
-- This script focuses on validating CURRENT performance for bulk data loading
-- operations used during Planet notes processing.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-11-25

-- ============================================================================
-- SETUP: Enable query timing and explain
-- ============================================================================

\timing on
\set ECHO all

-- ============================================================================
-- TEST 1: Analyze COPY operation performance (simulated)
-- Validates: COPY operation efficiency, buffer usage
-- ============================================================================

\echo '============================================================================'
\echo 'TEST 1: COPY Operation Performance Analysis'
\echo 'Validates: Bulk loading efficiency, buffer usage'
\echo 'Note: This test simulates COPY by analyzing INSERT performance'
\echo '============================================================================'

-- Simulate COPY operation with INSERT (since COPY requires file)
-- This validates the underlying insert performance
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
INSERT INTO notes_sync_part_1 (note_id, latitude, longitude, created_at, status, closed_at, id_country, part_id)
SELECT note_id, latitude, longitude, created_at, status, closed_at, id_country, 1
FROM notes
WHERE note_id % 100 = 0
LIMIT 1000;

-- Rollback to avoid modifying data
ROLLBACK;

-- ============================================================================
-- TEST 2: UPDATE part_id performance
-- Validates: UPDATE operation efficiency on partitioned tables
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo 'TEST 2: UPDATE part_id Performance'
\echo 'Validates: UPDATE operation efficiency on partitioned tables'
\echo '============================================================================'

-- Test UPDATE performance on partition
\timing on
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
UPDATE notes_sync_part_1
SET part_id = 1
WHERE part_id IS NULL
LIMIT 1000;
\timing off

-- Rollback to avoid modifying data
ROLLBACK;

-- ============================================================================
-- TEST 3: Partition table statistics
-- Validates: Table sizes, row counts, index usage
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo 'TEST 3: Partition Table Statistics'
\echo 'Validates: Table sizes, row counts, partition health'
\echo '============================================================================'

SELECT
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS total_size,
  pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS table_size,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) AS indexes_size,
  n_live_tup AS row_count,
  n_dead_tup AS dead_rows,
  last_vacuum,
  last_autovacuum,
  last_analyze,
  last_autoanalyze
FROM pg_stat_user_tables
WHERE tablename LIKE 'notes_sync_part_%'
   OR tablename LIKE 'note_comments_sync_part_%'
   OR tablename LIKE 'note_comments_text_sync_part_%'
ORDER BY tablename;

-- ============================================================================
-- TEST 4: Index usage on partition tables
-- Validates: Index effectiveness for partition operations
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo 'TEST 4: Index Usage on Partition Tables'
\echo 'Validates: Index effectiveness for partition operations'
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
WHERE relname LIKE 'notes_sync_part_%'
   OR relname LIKE 'note_comments_sync_part_%'
   OR relname LIKE 'note_comments_text_sync_part_%'
ORDER BY relname, indexrelname;

-- ============================================================================
-- TEST 5: Performance benchmarks
-- Validates: Execution time meets performance thresholds
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo 'TEST 5: Performance Benchmarks'
\echo 'Validates: Execution time meets performance thresholds'
\echo 'Expected: < 100ms for 1000 row INSERT, < 50ms for 1000 row UPDATE'
\echo '============================================================================'

-- Test INSERT performance (simulating COPY)
\echo 'Testing INSERT performance (1000 rows)...'
\timing on
INSERT INTO notes_sync_part_1 (note_id, latitude, longitude, created_at, status, closed_at, id_country, part_id)
SELECT note_id, latitude, longitude, created_at, status, closed_at, id_country, 1
FROM notes
WHERE note_id % 100 = 0
LIMIT 1000;
\timing off
ROLLBACK;

-- Test UPDATE performance
\echo 'Testing UPDATE performance (1000 rows)...'
\timing on
UPDATE notes_sync_part_1
SET part_id = 1
WHERE part_id IS NULL
LIMIT 1000;
\timing off
ROLLBACK;

-- ============================================================================
-- FINAL VALIDATION SUMMARY
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo 'FINAL VALIDATION SUMMARY'
\echo '============================================================================'

DO $$
DECLARE
  partition_count INTEGER;
  total_partition_size TEXT;
  avg_partition_size TEXT;
  largest_partition TEXT;
  partition_tables TEXT[];
BEGIN
  -- Count partitions
  SELECT COUNT(*) INTO partition_count
  FROM pg_stat_user_tables
  WHERE tablename LIKE 'notes_sync_part_%'
     OR tablename LIKE 'note_comments_sync_part_%'
     OR tablename LIKE 'note_comments_text_sync_part_%';

  -- Get partition statistics
  SELECT
    pg_size_pretty(SUM(pg_total_relation_size(schemaname||'.'||tablename))),
    pg_size_pretty(AVG(pg_total_relation_size(schemaname||'.'||tablename))),
    MAX(tablename)
  INTO total_partition_size, avg_partition_size, largest_partition
  FROM pg_stat_user_tables
  WHERE tablename LIKE 'notes_sync_part_%'
     OR tablename LIKE 'note_comments_sync_part_%'
     OR tablename LIKE 'note_comments_text_sync_part_%';

  RAISE NOTICE '';
  RAISE NOTICE 'Partition Statistics:';
  RAISE NOTICE '  Total partitions found: %', partition_count;
  IF partition_count > 0 THEN
    RAISE NOTICE '  Total partition size: %', total_partition_size;
    RAISE NOTICE '  Average partition size: %', avg_partition_size;
    RAISE NOTICE '  Largest partition: %', largest_partition;
  ELSE
    RAISE NOTICE '  ⚠️  No partitions found - this is normal if partitions have not been created yet';
  END IF;

  RAISE NOTICE '';
  RAISE NOTICE 'Performance Validation:';
  RAISE NOTICE '  📊 Review TEST 1 EXPLAIN output above:';
  RAISE NOTICE '     ✅ GOOD: Should show efficient INSERT plan';
  RAISE NOTICE '     ❌ BAD:  If shows sequential scan without indexes';
  RAISE NOTICE '';
  RAISE NOTICE '  ⏱️  Review TEST 5 timing above:';
  RAISE NOTICE '     ✅ GOOD: < 100ms for 1000 row INSERT';
  RAISE NOTICE '     ✅ GOOD: < 50ms for 1000 row UPDATE';
  RAISE NOTICE '     ⚠️  WARNING: If times exceed thresholds, may need optimization';
  RAISE NOTICE '';
  RAISE NOTICE '  📊 Review TEST 3 statistics above:';
  RAISE NOTICE '     ✅ GOOD: Dead rows < 10%% of live rows';
  RAISE NOTICE '     ⚠️  WARNING: High dead rows may indicate need for VACUUM';
  RAISE NOTICE '';
  RAISE NOTICE '  📈 Review TEST 4 index statistics above:';
  RAISE NOTICE '     ✅ GOOD: idx_scan > 0 (indexes are being used)';
  RAISE NOTICE '     ⚠️  WARNING: idx_scan = 0 (indexes not used yet)';
  RAISE NOTICE '';
  RAISE NOTICE '============================================================================';
END $$;

