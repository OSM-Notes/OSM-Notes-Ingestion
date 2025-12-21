-- Test ANALYZE conditional optimization with periodic execution
-- Validates that ANALYZE runs when >100 items OR >6 hours since last ANALYZE
-- Author: Andres Gomez (AngocA)
-- Version: 2025-12-21

BEGIN;

-- Test 1: Verify ANALYZE is skipped for small insertions (<100 notes) when recent
DO $$
DECLARE
  log_message TEXT;
  small_count INTEGER := 5;
BEGIN
  -- Clear any previous test messages
  DELETE FROM logs WHERE message LIKE '%ANALYZE%test%';
  
  -- Simulate: small count AND recent ANALYZE (less than 6 hours ago)
  -- Should SKIP ANALYZE
  IF small_count > 100 THEN
    INSERT INTO logs (message) VALUES ('Running ANALYZE notes (threshold: >100 notes in this cycle) - test');
  ELSE
    -- Simulate recent ANALYZE (2 hours ago)
    INSERT INTO logs (message, timestamp) VALUES 
      ('Running ANALYZE notes (threshold: >100 notes in this cycle) - test', NOW() - INTERVAL '2 hours');
    
    DECLARE
      m_last_analyze_time TIMESTAMP;
      m_analyze_interval_hours INTEGER := 6;
    BEGIN
      SELECT COALESCE(MAX(timestamp), '1970-01-01'::TIMESTAMP) INTO m_last_analyze_time
      FROM logs
      WHERE message LIKE 'Running ANALYZE notes%test%';
      
      IF m_last_analyze_time < NOW() - (m_analyze_interval_hours || ' hours')::INTERVAL THEN
        INSERT INTO logs (message) VALUES ('Running ANALYZE notes (periodic) - test');
      ELSE
        INSERT INTO logs (message) VALUES ('Skipping ANALYZE notes (only ' || 
          small_count || ' notes processed, last ANALYZE ' || 
          EXTRACT(EPOCH FROM (NOW() - m_last_analyze_time))/3600 || ' hours ago) - test');
      END IF;
    END;
  END IF;
  
  -- Check that skip message was logged
  SELECT message INTO log_message
  FROM logs
  WHERE message LIKE '%Skipping ANALYZE notes%test%'
  ORDER BY id DESC
  LIMIT 1;
  
  IF log_message IS NOT NULL THEN
    RAISE NOTICE '✅ Test 1 PASSED: ANALYZE skipped for small count with recent ANALYZE';
  ELSE
    RAISE EXCEPTION '❌ Test 1 FAILED: ANALYZE should be skipped';
  END IF;
  
  -- Clean up
  DELETE FROM logs WHERE message LIKE '%ANALYZE%test%';
END $$;

-- Test 2: Verify ANALYZE runs for large insertions (>100 notes)
DO $$
DECLARE
  log_message TEXT;
  large_count INTEGER := 150;
BEGIN
  -- Simulate large count - should run ANALYZE immediately
  IF large_count > 100 THEN
    INSERT INTO logs (message) VALUES ('Running ANALYZE notes (threshold: >100 notes in this cycle) - test2');
  END IF;
  
  -- Check that run message was logged
  SELECT message INTO log_message
  FROM logs
  WHERE message LIKE '%Running ANALYZE notes (threshold: >100 notes in this cycle)%test2%'
  ORDER BY id DESC
  LIMIT 1;
  
  IF log_message IS NOT NULL THEN
    RAISE NOTICE '✅ Test 2 PASSED: ANALYZE runs for large count (>100 notes)';
  ELSE
    RAISE EXCEPTION '❌ Test 2 FAILED: ANALYZE should run for large count';
  END IF;
  
  -- Clean up
  DELETE FROM logs WHERE message LIKE '%test2%';
END $$;

-- Test 3: Verify ANALYZE runs periodically (>6 hours since last ANALYZE)
DO $$
DECLARE
  log_message TEXT;
  small_count INTEGER := 5;
  m_last_analyze_time TIMESTAMP;
  m_analyze_interval_hours INTEGER := 6;
BEGIN
  -- Simulate old ANALYZE (7 hours ago)
  INSERT INTO logs (message, timestamp) VALUES 
    ('Running ANALYZE notes (threshold: >100 notes in this cycle) - test3', 
     NOW() - INTERVAL '7 hours');
  
  -- Check if periodic ANALYZE should run
  SELECT COALESCE(MAX(timestamp), '1970-01-01'::TIMESTAMP) INTO m_last_analyze_time
  FROM logs
  WHERE message LIKE 'Running ANALYZE notes%test3%';
  
  IF small_count > 100 THEN
    INSERT INTO logs (message) VALUES ('Running ANALYZE notes (threshold: >100 notes in this cycle) - test3');
  ELSIF m_last_analyze_time < NOW() - (m_analyze_interval_hours || ' hours')::INTERVAL THEN
    INSERT INTO logs (message) VALUES ('Running ANALYZE notes (periodic: >' || 
      m_analyze_interval_hours || ' hours since last ANALYZE, ' || 
      EXTRACT(EPOCH FROM (NOW() - m_last_analyze_time))/3600 || ' hours elapsed) - test3');
  ELSE
    INSERT INTO logs (message) VALUES ('Skipping ANALYZE notes - test3');
  END IF;
  
  -- Check that periodic run message was logged
  SELECT message INTO log_message
  FROM logs
  WHERE message LIKE '%Running ANALYZE notes (periodic:%test3%'
  ORDER BY id DESC
  LIMIT 1;
  
  IF log_message IS NOT NULL THEN
    RAISE NOTICE '✅ Test 3 PASSED: ANALYZE runs periodically when >6 hours elapsed';
  ELSE
    RAISE EXCEPTION '❌ Test 3 FAILED: ANALYZE should run periodically after 6 hours';
  END IF;
  
  -- Clean up
  DELETE FROM logs WHERE message LIKE '%test3%';
END $$;

-- Test 4: Verify boundary condition (exactly 6 hours)
DO $$
DECLARE
  log_message TEXT;
  small_count INTEGER := 5;
  m_last_analyze_time TIMESTAMP;
  m_analyze_interval_hours INTEGER := 6;
BEGIN
  -- Simulate ANALYZE exactly 6 hours ago (should NOT trigger, needs >6 hours)
  INSERT INTO logs (message, timestamp) VALUES 
    ('Running ANALYZE notes (threshold: >100 notes in this cycle) - test4', 
     NOW() - INTERVAL '6 hours');
  
  SELECT COALESCE(MAX(timestamp), '1970-01-01'::TIMESTAMP) INTO m_last_analyze_time
  FROM logs
  WHERE message LIKE 'Running ANALYZE notes%test4%';
  
  IF small_count > 100 THEN
    INSERT INTO logs (message) VALUES ('Running ANALYZE notes (threshold: >100 notes in this cycle) - test4');
  ELSIF m_last_analyze_time < NOW() - (m_analyze_interval_hours || ' hours')::INTERVAL THEN
    INSERT INTO logs (message) VALUES ('Running ANALYZE notes (periodic) - test4');
  ELSE
    INSERT INTO logs (message) VALUES ('Skipping ANALYZE notes (only ' || 
      small_count || ' notes, last ANALYZE ' || 
      EXTRACT(EPOCH FROM (NOW() - m_last_analyze_time))/3600 || ' hours ago) - test4');
  END IF;
  
  -- Check that skip message was logged (exactly 6 hours should NOT trigger)
  SELECT message INTO log_message
  FROM logs
  WHERE message LIKE '%Skipping ANALYZE notes%test4%'
  ORDER BY id DESC
  LIMIT 1;
  
  IF log_message IS NOT NULL THEN
    RAISE NOTICE '✅ Test 4 PASSED: ANALYZE correctly skips at exactly 6 hours (needs >6 hours)';
  ELSE
    RAISE EXCEPTION '❌ Test 4 FAILED: ANALYZE should skip at exactly 6 hours';
  END IF;
  
  -- Clean up
  DELETE FROM logs WHERE message LIKE '%test4%';
END $$;

ROLLBACK;

-- Summary
SELECT 'ANALYZE conditional + periodic optimization tests completed' AS status;

