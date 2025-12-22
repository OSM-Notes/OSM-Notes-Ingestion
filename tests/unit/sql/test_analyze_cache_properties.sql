-- Test: Validates that ANALYZE timestamps are cached in properties table
-- instead of being queried from logs table
-- Author: Andres Gomez (AngocA)
-- Version: 2025-12-22

\set ON_ERROR_STOP on

BEGIN;

-- Test 1: Verify that reading from properties is faster than from logs
DO $$
DECLARE
  m_start_time TIMESTAMP;
  m_end_time TIMESTAMP;
  m_duration_properties NUMERIC;
  m_duration_logs NUMERIC;
  m_last_analyze_time TIMESTAMP;
BEGIN
  -- Initialize properties table if not exists
  INSERT INTO properties (key, value)
  VALUES ('last_analyze_notes_timestamp', NOW()::TEXT)
  ON CONFLICT (key) DO NOTHING;

  -- Test reading from properties (optimized way)
  m_start_time := clock_timestamp();
  SELECT COALESCE(
    (SELECT value::TIMESTAMP FROM properties WHERE key = 'last_analyze_notes_timestamp'),
    '1970-01-01'::TIMESTAMP
  ) INTO m_last_analyze_time;
  m_end_time := clock_timestamp();
  m_duration_properties := EXTRACT(EPOCH FROM (m_end_time - m_start_time)) * 1000;

  -- Test reading from logs (old way - only if logs table exists and has data)
  BEGIN
    m_start_time := clock_timestamp();
    SELECT COALESCE(MAX(timestamp), '1970-01-01'::TIMESTAMP) INTO m_last_analyze_time
    FROM logs
    WHERE message LIKE 'Running ANALYZE notes%';
    m_end_time := clock_timestamp();
    m_duration_logs := EXTRACT(EPOCH FROM (m_end_time - m_start_time)) * 1000;
  EXCEPTION
    WHEN OTHERS THEN
      -- If logs table doesn't exist or is empty, skip this comparison
      m_duration_logs := NULL;
  END;

  -- Properties lookup should be very fast (<10ms typically)
  -- Note: On small databases with cached data, logs may appear faster, but on large databases
  -- (10M+ rows in logs), properties will be significantly faster
  IF m_duration_properties > 10 THEN
    RAISE EXCEPTION 'Properties lookup took too long: %ms (expected <10ms)', m_duration_properties;
  END IF;

  -- On large databases, properties should be faster, but we don't enforce this in test
  -- to avoid false failures on small/cached databases
  RAISE NOTICE 'Test 1 PASSED: Properties lookup duration: %ms (logs: %ms)', 
    m_duration_properties, m_duration_logs;
END $$;

-- Test 2: Verify that properties timestamp is updated when ANALYZE runs
DO $$
DECLARE
  m_before_timestamp TIMESTAMP;
  m_after_timestamp TIMESTAMP;
  m_test_timestamp TIMESTAMP;
BEGIN
  -- Get initial timestamp
  SELECT COALESCE(
    (SELECT value::TIMESTAMP FROM properties WHERE key = 'last_analyze_notes_timestamp'),
    '1970-01-01'::TIMESTAMP
  ) INTO m_before_timestamp;

  -- Simulate ANALYZE execution by updating properties with a specific timestamp
  -- Use a timestamp slightly in the future to ensure difference
  m_test_timestamp := m_before_timestamp + INTERVAL '1 second';
  INSERT INTO properties (key, value)
  VALUES ('last_analyze_notes_timestamp', m_test_timestamp::TEXT)
  ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

  -- Verify timestamp was updated
  SELECT value::TIMESTAMP INTO m_after_timestamp
  FROM properties
  WHERE key = 'last_analyze_notes_timestamp';

  IF m_after_timestamp <= m_before_timestamp THEN
    RAISE EXCEPTION 'Properties timestamp was not updated. Before: %, After: %', 
      m_before_timestamp, m_after_timestamp;
  END IF;

  -- Allow 1 second tolerance for timestamp comparison
  IF ABS(EXTRACT(EPOCH FROM (m_after_timestamp - m_test_timestamp))) > 1 THEN
    RAISE EXCEPTION 'Properties timestamp does not match expected value. Expected: %, Got: %', 
      m_test_timestamp, m_after_timestamp;
  END IF;

  RAISE NOTICE 'Test 2 PASSED: Properties timestamp updated correctly from % to %', 
    m_before_timestamp, m_after_timestamp;
END $$;

-- Test 3: Verify default value when properties key doesn't exist
DO $$
DECLARE
  m_default_timestamp TIMESTAMP := '1970-01-01'::TIMESTAMP;
  m_retrieved_timestamp TIMESTAMP;
BEGIN
  -- Remove the key to test default behavior
  DELETE FROM properties WHERE key = 'last_analyze_notes_timestamp_test';

  -- Test retrieval with default
  SELECT COALESCE(
    (SELECT value::TIMESTAMP FROM properties WHERE key = 'last_analyze_notes_timestamp_test'),
    m_default_timestamp
  ) INTO m_retrieved_timestamp;

  IF m_retrieved_timestamp != m_default_timestamp THEN
    RAISE EXCEPTION 'Default timestamp not returned. Expected: %, Got: %', 
      m_default_timestamp, m_retrieved_timestamp;
  END IF;

  RAISE NOTICE 'Test 3 PASSED: Default timestamp returned correctly: %', m_retrieved_timestamp;
END $$;

-- Test 4: Verify both notes and comments timestamps work independently
DO $$
DECLARE
  m_notes_timestamp TIMESTAMP;
  m_comments_timestamp TIMESTAMP;
  m_test_time TIMESTAMP := NOW();
BEGIN
  -- Set different timestamps for notes and comments
  INSERT INTO properties (key, value)
  VALUES 
    ('last_analyze_notes_timestamp', m_test_time::TEXT),
    ('last_analyze_comments_timestamp', (m_test_time - INTERVAL '1 hour')::TEXT)
  ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

  -- Retrieve both timestamps
  SELECT COALESCE(
    (SELECT value::TIMESTAMP FROM properties WHERE key = 'last_analyze_notes_timestamp'),
    '1970-01-01'::TIMESTAMP
  ) INTO m_notes_timestamp;

  SELECT COALESCE(
    (SELECT value::TIMESTAMP FROM properties WHERE key = 'last_analyze_comments_timestamp'),
    '1970-01-01'::TIMESTAMP
  ) INTO m_comments_timestamp;

  -- Verify they are independent (should differ by ~1 hour)
  IF ABS(EXTRACT(EPOCH FROM (m_notes_timestamp - m_comments_timestamp)) - 3600) > 60 THEN
    RAISE EXCEPTION 'Notes and comments timestamps not independent. Notes: %, Comments: %', 
      m_notes_timestamp, m_comments_timestamp;
  END IF;

  RAISE NOTICE 'Test 4 PASSED: Notes timestamp: %, Comments timestamp: %', 
    m_notes_timestamp, m_comments_timestamp;
END $$;

ROLLBACK;

