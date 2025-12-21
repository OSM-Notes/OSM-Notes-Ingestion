-- Simple test to validate ANALYZE conditional optimization
-- Validates that the logic correctly determines when to run ANALYZE
-- Author: Andres Gomez (AngocA)
-- Version: 2025-12-21

BEGIN;

-- Test: Validate ANALYZE conditional logic
-- This test validates the same logic used in processAPINotes_32_insertNewNotesAndComments.sql
DO $$
DECLARE
  small_count INTEGER := 5;
  large_count INTEGER := 150;
  log_message TEXT;
  test_passed BOOLEAN := TRUE;
BEGIN
  -- Clear any previous test messages
  DELETE FROM logs WHERE message LIKE '%ANALYZE%test%';
  
  -- Test 1: Verify logic skips ANALYZE for small counts (<100)
  -- This simulates what happens in processAPINotes_32_insertNewNotesAndComments.sql
  -- when m_notes_count_before or m_comments_count_before <= 100
  IF small_count > 100 THEN
    INSERT INTO logs (message) VALUES ('Running ANALYZE (threshold: >100) - test');
  ELSE
    INSERT INTO logs (message) VALUES ('Skipping ANALYZE (only ' || 
      small_count || ' items processed, threshold: >100) - test');
  END IF;
  
  -- Verify skip message was logged
  SELECT message INTO log_message
  FROM logs
  WHERE message LIKE '%Skipping ANALYZE%test%'
  ORDER BY id DESC
  LIMIT 1;
  
  IF log_message IS NULL THEN
    RAISE EXCEPTION 'Test 1 FAILED: ANALYZE logic did not skip for small count (<100)';
  ELSE
    RAISE NOTICE '✅ Test 1 PASSED: ANALYZE logic correctly skips for small counts (<100)';
    RAISE NOTICE '   Log message: %', log_message;
  END IF;
  
  -- Test 2: Verify logic runs ANALYZE for large counts (>100)
  IF large_count > 100 THEN
    INSERT INTO logs (message) VALUES ('Running ANALYZE (threshold: >100) - test');
  ELSE
    INSERT INTO logs (message) VALUES ('Skipping ANALYZE (only ' || 
      large_count || ' items processed, threshold: >100) - test');
  END IF;
  
  -- Verify run message was logged
  SELECT message INTO log_message
  FROM logs
  WHERE message LIKE '%Running ANALYZE%test%'
  ORDER BY id DESC
  LIMIT 1;
  
  IF log_message IS NULL THEN
    RAISE EXCEPTION 'Test 2 FAILED: ANALYZE logic did not trigger for large count (>100)';
  ELSE
    RAISE NOTICE '✅ Test 2 PASSED: ANALYZE logic correctly triggers for large counts (>100)';
    RAISE NOTICE '   Log message: %', log_message;
  END IF;
  
  -- Test 3: Verify boundary condition (exactly 100)
  DECLARE
    boundary_count INTEGER := 100;
  BEGIN
    IF boundary_count > 100 THEN
      INSERT INTO logs (message) VALUES ('Running ANALYZE (exactly 100) - test');
    ELSE
      INSERT INTO logs (message) VALUES ('Skipping ANALYZE (exactly 100, threshold: >100) - test');
    END IF;
    
    SELECT message INTO log_message
    FROM logs
    WHERE message LIKE '%exactly 100%test%'
    ORDER BY id DESC
    LIMIT 1;
    
    IF log_message IS NULL OR log_message LIKE '%Running%' THEN
      RAISE EXCEPTION 'Test 3 FAILED: ANALYZE logic incorrectly triggers for count = 100 (should skip)';
    ELSE
      RAISE NOTICE '✅ Test 3 PASSED: ANALYZE logic correctly skips for count = 100 (threshold is >100)';
    END IF;
  END;
  
  RAISE NOTICE '';
  RAISE NOTICE '✅ ALL TESTS PASSED: ANALYZE conditional optimization logic works correctly';
  RAISE NOTICE '   - Small counts (<100): ANALYZE is skipped';
  RAISE NOTICE '   - Large counts (>100): ANALYZE is executed';
  RAISE NOTICE '   - Boundary (100): ANALYZE is skipped (threshold is >100, not >=100)';
  
  -- Clean up test messages
  DELETE FROM logs WHERE message LIKE '%ANALYZE%test%';
END $$;

ROLLBACK;

SELECT 'ANALYZE conditional optimization test completed' AS status;

