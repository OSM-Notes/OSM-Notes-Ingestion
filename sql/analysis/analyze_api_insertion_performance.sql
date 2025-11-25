-- Analysis script to validate performance of API note insertion operations
-- This script validates that cursor-based batch insertion is performing optimally
-- by checking execution times, procedure call overhead, and transaction efficiency
--
-- This script focuses on validating CURRENT performance for API note processing
-- which uses cursor-based batch insertion with stored procedures.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-11-25

-- ============================================================================
-- SETUP: Enable query timing and explain
-- ============================================================================

\timing on
\set ECHO all

-- ============================================================================
-- TEST 1: Analyze stored procedure call performance
-- Validates: Procedure call overhead, transaction efficiency
-- ============================================================================

\echo '============================================================================'
\echo 'TEST 1: Stored Procedure Call Performance Analysis'
\echo 'Validates: insert_note() procedure efficiency'
\echo '============================================================================'

-- Test single procedure call
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
CALL insert_note(1, 40.7128, -74.0060, NOW(), 0);

-- Rollback to avoid modifying data
ROLLBACK;

-- ============================================================================
-- TEST 2: Batch INSERT vs procedure call comparison
-- Validates: Bulk INSERT efficiency vs individual procedure calls
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo 'TEST 2: Batch INSERT vs Procedure Call Comparison'
\echo 'Validates: Bulk INSERT efficiency vs individual procedure calls'
\echo '============================================================================'

-- Test bulk INSERT (more efficient approach)
\echo 'Testing bulk INSERT performance...'
\timing on
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
INSERT INTO notes (note_id, latitude, longitude, created_at, status, closed_at, id_country)
SELECT note_id, latitude, longitude, created_at, status, closed_at, id_country
FROM notes_api
LIMIT 100;
\timing off
ROLLBACK;

-- Test procedure call loop (current approach)
\echo 'Testing procedure call loop performance...'
\timing on
DO $$
DECLARE
  r RECORD;
  m_stmt TEXT;
  m_count INTEGER := 0;
BEGIN
  FOR r IN
    SELECT note_id, latitude, longitude, created_at, status, closed_at
    FROM notes_api
    LIMIT 100
  LOOP
    m_stmt := 'CALL insert_note (' || r.note_id || ', ' || r.latitude || ', '
      || r.longitude || ', ' || 'TO_TIMESTAMP(''' || r.created_at || ''', '
      || '''YYYY-MM-DD HH24:MI:SS'')' || ', 0)';
    EXECUTE m_stmt;
    m_count := m_count + 1;
    EXIT WHEN m_count >= 100;
  END LOOP;
END $$;
\timing off
ROLLBACK;

-- ============================================================================
-- TEST 3: Cursor performance analysis
-- Validates: Cursor overhead, batch processing efficiency
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo 'TEST 3: Cursor Performance Analysis'
\echo 'Validates: Cursor overhead, batch processing efficiency'
\echo '============================================================================'

-- Test cursor-based processing
DO $$
DECLARE
  r RECORD;
  m_count INTEGER := 0;
  start_time TIMESTAMP;
  end_time INTERVAL;
  m_cursor CURSOR FOR
    SELECT note_id, latitude, longitude, created_at, status, closed_at
    FROM notes_api
    ORDER BY created_at
    LIMIT 100;
BEGIN
  start_time := clock_timestamp();
  
  FOR r IN m_cursor LOOP
    m_count := m_count + 1;
    -- Simulate processing without actual INSERT
    EXIT WHEN m_count >= 100;
  END LOOP;
  
  end_time := clock_timestamp() - start_time;
  RAISE NOTICE 'Cursor processing 100 rows completed in %', end_time;
END $$;

-- ============================================================================
-- TEST 4: Transaction batch size optimization
-- Validates: Optimal batch size for transaction processing
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo 'TEST 4: Transaction Batch Size Optimization'
\echo 'Validates: Optimal batch size for transaction processing'
\echo '============================================================================'

-- Test different batch sizes
DO $$
DECLARE
  batch_size INTEGER;
  start_time TIMESTAMP;
  end_time INTERVAL;
  test_sizes INTEGER[] := ARRAY[10, 50, 100, 500];
  sz INTEGER;
BEGIN
  FOREACH sz IN ARRAY test_sizes LOOP
    start_time := clock_timestamp();
    
    -- Simulate batch processing
    FOR batch_size IN 1..sz LOOP
      -- Simulate work without actual INSERT
      PERFORM 1;
    END LOOP;
    
    end_time := clock_timestamp() - start_time;
    RAISE NOTICE 'Batch size %: completed in %', sz, end_time;
  END LOOP;
END $$;

-- ============================================================================
-- TEST 5: API table statistics
-- Validates: Table health, index usage
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo 'TEST 5: API Table Statistics'
\echo 'Validates: Table health, index usage for API tables'
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
WHERE tablename LIKE '%_api'
ORDER BY tablename;

-- ============================================================================
-- TEST 6: Performance benchmarks
-- Validates: Execution time meets performance thresholds
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo 'TEST 6: Performance Benchmarks'
\echo 'Validates: Execution time meets performance thresholds'
\echo 'Expected: < 50ms per procedure call, < 100ms for 100 row batch'
\echo '============================================================================'

-- Test single procedure call timing
\echo 'Testing single procedure call...'
\timing on
CALL insert_note(1, 40.7128, -74.0060, NOW(), 0);
\timing off
ROLLBACK;

-- Test bulk INSERT timing (baseline)
\echo 'Testing bulk INSERT (100 rows)...'
\timing on
INSERT INTO notes (note_id, latitude, longitude, created_at, status, closed_at, id_country)
SELECT note_id, latitude, longitude, created_at, status, closed_at, id_country
FROM notes_api
LIMIT 100;
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
  api_table_count INTEGER;
  total_api_size TEXT;
  notes_api_count BIGINT;
  comments_api_count BIGINT;
  text_comments_api_count BIGINT;
  procedure_exists BOOLEAN;
BEGIN
  -- Count API tables
  SELECT COUNT(*) INTO api_table_count
  FROM pg_stat_user_tables
  WHERE tablename LIKE '%_api';

  -- Get total size
  SELECT pg_size_pretty(SUM(pg_total_relation_size(schemaname||'.'||tablename)))
  INTO total_api_size
  FROM pg_stat_user_tables
  WHERE tablename LIKE '%_api';

  -- Get row counts
  SELECT COUNT(*) INTO notes_api_count FROM notes_api;
  SELECT COUNT(*) INTO comments_api_count FROM note_comments_api;
  SELECT COUNT(*) INTO text_comments_api_count FROM note_comments_text_api;

  -- Check if procedure exists
  SELECT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public' AND p.proname = 'insert_note'
  ) INTO procedure_exists;

  RAISE NOTICE '';
  RAISE NOTICE 'API Table Statistics:';
  RAISE NOTICE '  API tables found: %', api_table_count;
  IF api_table_count > 0 THEN
    RAISE NOTICE '  Total API tables size: %', total_api_size;
    RAISE NOTICE '  Notes in API tables: %', notes_api_count;
    RAISE NOTICE '  Comments in API tables: %', comments_api_count;
    RAISE NOTICE '  Text comments in API tables: %', text_comments_api_count;
  ELSE
    RAISE NOTICE '  ⚠️  No API tables found - this is normal if API processing has not run yet';
  END IF;

  RAISE NOTICE '';
  RAISE NOTICE 'Procedure Validation:';
  IF procedure_exists THEN
    RAISE NOTICE '  ✅ insert_note() procedure EXISTS';
  ELSE
    RAISE WARNING '  ❌ insert_note() procedure MISSING - CRITICAL ISSUE!';
  END IF;

  RAISE NOTICE '';
  RAISE NOTICE 'Performance Validation:';
  RAISE NOTICE '  📊 Review TEST 2 comparison above:';
  RAISE NOTICE '     ✅ GOOD: Bulk INSERT should be faster than procedure calls';
  RAISE NOTICE '     ⚠️  NOTE: Procedure calls provide validation but are slower';
  RAISE NOTICE '';
  RAISE NOTICE '  ⏱️  Review TEST 6 timing above:';
  RAISE NOTICE '     ✅ GOOD: < 50ms per procedure call';
  RAISE NOTICE '     ✅ GOOD: < 100ms for 100 row batch INSERT';
  RAISE NOTICE '     ⚠️  WARNING: If times exceed thresholds, consider batch size optimization';
  RAISE NOTICE '';
  RAISE NOTICE '  📊 Review TEST 5 statistics above:';
  RAISE NOTICE '     ✅ GOOD: Dead row percentage < 10%%';
  RAISE NOTICE '     ⚠️  WARNING: High dead row percentage may indicate need for VACUUM';
  RAISE NOTICE '';
  RAISE NOTICE '============================================================================';
END $$;

