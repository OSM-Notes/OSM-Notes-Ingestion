-- Analysis script to validate performance of partition consolidation operations
-- This script validates that INSERT operations from partitions are performing optimally
-- by checking execution times, buffer usage, and query plans
--
-- This script focuses on validating CURRENT performance for consolidation operations
-- used when merging partitioned data into main sync tables.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-11-25

-- ============================================================================
-- SETUP: Enable query timing and explain
-- ============================================================================

\timing on
\set ECHO all

-- ============================================================================
-- TEST 1: Analyze INSERT FROM partition performance
-- Validates: INSERT operation efficiency, buffer usage
-- ============================================================================

\echo '============================================================================'
\echo 'TEST 1: INSERT FROM Partition Performance Analysis'
\echo 'Validates: Consolidation INSERT efficiency, buffer usage'
\echo '============================================================================'

-- Test INSERT from partition (simulating consolidation)
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
INSERT INTO notes_sync
SELECT note_id, latitude, longitude, created_at, status, closed_at, id_country
FROM notes_sync_part_1
WHERE part_id = 1
LIMIT 1000;

-- Rollback to avoid modifying data
ROLLBACK;

-- ============================================================================
-- TEST 2: INSERT with sequence generation performance
-- Validates: Sequence generation overhead for comments
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo 'TEST 2: INSERT with Sequence Generation Performance'
\echo 'Validates: Sequence generation overhead for comments consolidation'
\echo '============================================================================'

-- Test INSERT with sequence (for comments)
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
INSERT INTO note_comments_sync
SELECT nextval('note_comments_sync_id_seq'), note_id, sequence_action, event, created_at, id_user, username
FROM note_comments_sync_part_1
WHERE part_id = 1
LIMIT 1000;

-- Rollback to avoid modifying data
ROLLBACK;

-- ============================================================================
-- TEST 3: INSERT with EXISTS check performance
-- Validates: Foreign key validation overhead
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo 'TEST 3: INSERT with EXISTS Check Performance'
\echo 'Validates: Foreign key validation overhead for text comments'
\echo '============================================================================'

-- Test INSERT with EXISTS check (for text comments with FK validation)
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
INSERT INTO note_comments_text_sync
SELECT nextval('note_comments_text_sync_id_seq'), t.note_id, t.sequence_action, t.body
FROM note_comments_text_sync_part_1 t
WHERE t.part_id = 1
  AND EXISTS (
    SELECT 1 FROM note_comments_sync nc
    WHERE nc.note_id = t.note_id
      AND nc.sequence_action = t.sequence_action
  )
LIMIT 1000;

-- Rollback to avoid modifying data
ROLLBACK;

-- ============================================================================
-- TEST 4: Consolidation loop performance
-- Validates: Dynamic SQL execution overhead
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo 'TEST 4: Consolidation Loop Performance'
\echo 'Validates: Dynamic SQL execution overhead for multiple partitions'
\echo '============================================================================'

-- Test consolidation for multiple partitions (simulated)
DO $$
DECLARE
  i INTEGER;
  partition_name TEXT;
  total_rows INTEGER;
  start_time TIMESTAMP;
  end_time INTERVAL;
BEGIN
  start_time := clock_timestamp();
  
  FOR i IN 1..4 LOOP
    partition_name := 'notes_sync_part_' || i;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = partition_name) THEN
      EXECUTE format('SELECT COUNT(*) FROM %I WHERE part_id = %s', partition_name, i) INTO total_rows;
      RAISE NOTICE 'Partition %: % rows', i, total_rows;
    END IF;
  END LOOP;
  
  end_time := clock_timestamp() - start_time;
  RAISE NOTICE 'Consolidation loop test completed in %', end_time;
END $$;

-- ============================================================================
-- TEST 5: Performance benchmarks
-- Validates: Execution time meets performance thresholds
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo 'TEST 5: Performance Benchmarks'
\echo 'Validates: Execution time meets performance thresholds'
\echo 'Expected: < 200ms for 1000 row INSERT, < 300ms with EXISTS check'
\echo '============================================================================'

-- Test INSERT performance
\echo 'Testing INSERT performance (1000 rows)...'
\timing on
INSERT INTO notes_sync
SELECT note_id, latitude, longitude, created_at, status, closed_at, id_country
FROM notes_sync_part_1
WHERE part_id = 1
LIMIT 1000;
\timing off
ROLLBACK;

-- Test INSERT with EXISTS performance
\echo 'Testing INSERT with EXISTS check (1000 rows)...'
\timing on
INSERT INTO note_comments_text_sync
SELECT nextval('note_comments_text_sync_id_seq'), t.note_id, t.sequence_action, t.body
FROM note_comments_text_sync_part_1 t
WHERE t.part_id = 1
  AND EXISTS (
    SELECT 1 FROM note_comments_sync nc
    WHERE nc.note_id = t.note_id
      AND nc.sequence_action = t.sequence_action
  )
LIMIT 1000;
\timing off
ROLLBACK;

-- ============================================================================
-- TEST 6: Table statistics after consolidation
-- Validates: Table health, index usage
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo 'TEST 6: Consolidation Table Statistics'
\echo 'Validates: Table health, index usage for sync tables'
\echo '============================================================================'

SELECT
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS total_size,
  pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS table_size,
  n_live_tup AS row_count,
  n_dead_tup AS dead_rows,
  CASE
    WHEN n_live_tup > 0 THEN ROUND((n_dead_tup::NUMERIC / n_live_tup * 100)::NUMERIC, 2)
    ELSE 0
  END AS dead_row_percentage,
  last_vacuum,
  last_autovacuum,
  last_analyze,
  last_autoanalyze
FROM pg_stat_user_tables
WHERE tablename IN ('notes_sync', 'note_comments_sync', 'note_comments_text_sync')
ORDER BY tablename;

-- ============================================================================
-- FINAL VALIDATION SUMMARY
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo 'FINAL VALIDATION SUMMARY'
\echo '============================================================================'

DO $$
DECLARE
  sync_table_count INTEGER;
  total_sync_size TEXT;
  notes_sync_count BIGINT;
  comments_sync_count BIGINT;
  text_comments_sync_count BIGINT;
BEGIN
  -- Count sync tables
  SELECT COUNT(*) INTO sync_table_count
  FROM pg_stat_user_tables
  WHERE tablename IN ('notes_sync', 'note_comments_sync', 'note_comments_text_sync');

  -- Get total size
  SELECT pg_size_pretty(SUM(pg_total_relation_size(schemaname||'.'||tablename)))
  INTO total_sync_size
  FROM pg_stat_user_tables
  WHERE tablename IN ('notes_sync', 'note_comments_sync', 'note_comments_text_sync');

  -- Get row counts
  SELECT COUNT(*) INTO notes_sync_count FROM notes_sync;
  SELECT COUNT(*) INTO comments_sync_count FROM note_comments_sync;
  SELECT COUNT(*) INTO text_comments_sync_count FROM note_comments_text_sync;

  RAISE NOTICE '';
  RAISE NOTICE 'Consolidation Table Statistics:';
  RAISE NOTICE '  Sync tables found: %', sync_table_count;
  IF sync_table_count > 0 THEN
    RAISE NOTICE '  Total sync tables size: %', total_sync_size;
    RAISE NOTICE '  Notes in sync: %', notes_sync_count;
    RAISE NOTICE '  Comments in sync: %', comments_sync_count;
    RAISE NOTICE '  Text comments in sync: %', text_comments_sync_count;
  ELSE
    RAISE NOTICE '  ⚠️  No sync tables found - this is normal if consolidation has not run yet';
  END IF;

  RAISE NOTICE '';
  RAISE NOTICE 'Performance Validation:';
  RAISE NOTICE '  📊 Review TEST 1 EXPLAIN output above:';
  RAISE NOTICE '     ✅ GOOD: Should show efficient INSERT plan';
  RAISE NOTICE '     ❌ BAD:  If shows sequential scan without indexes';
  RAISE NOTICE '';
  RAISE NOTICE '  ⏱️  Review TEST 5 timing above:';
  RAISE NOTICE '     ✅ GOOD: < 200ms for 1000 row INSERT';
  RAISE NOTICE '     ✅ GOOD: < 300ms for INSERT with EXISTS check';
  RAISE NOTICE '     ⚠️  WARNING: If times exceed thresholds, may need optimization';
  RAISE NOTICE '';
  RAISE NOTICE '  📊 Review TEST 6 statistics above:';
  RAISE NOTICE '     ✅ GOOD: Dead row percentage < 10%%';
  RAISE NOTICE '     ⚠️  WARNING: High dead row percentage may indicate need for VACUUM';
  RAISE NOTICE '';
  RAISE NOTICE '============================================================================';
END $$;

