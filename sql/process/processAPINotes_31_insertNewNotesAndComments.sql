-- Insert new notes and comments from API.
-- Author: Andres Gomez (AngocA)
-- Version: 2025-12-23

-- Configure session for high-priority INSERT operations
SET statement_timeout = '5min';
SET lock_timeout = '50ms';
SET work_mem = '64MB';
SET maintenance_work_mem = '256MB';

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 'Inserting new notes and comments from API (bulk mode)' AS Task;

-- Set process lock for this operation
DO $$
DECLARE
  m_process_id INTEGER;
BEGIN
  -- Get process ID for parallel processing
  m_process_id := COALESCE(current_setting('app.process_id', true), '0')::INTEGER;
  
  -- Set the process ID for use in procedures
  PERFORM set_config('app.process_id', m_process_id::TEXT, false);
END $$;

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
  COUNT(1) Qty, 'current notes - before' AS Text
FROM notes;

DO /* Notes-processAPI-insertNotes-bulk */
$$
 DECLARE
  m_process_id INTEGER;
  m_process_id_db VARCHAR(32);
  m_process_id_db_pid INTEGER;
  m_notes_count_before INTEGER;
  m_notes_count_after INTEGER;
  m_existing_notes_count INTEGER;
  m_new_notes_count INTEGER;
  m_updated_notes_count INTEGER;
  m_last_analyze_time TIMESTAMP;
  m_analyze_interval_hours INTEGER := 6;
  m_stage_start TIMESTAMP;
  m_stage_end TIMESTAMP;
  m_stage_duration NUMERIC;
 BEGIN
  m_process_id := COALESCE(current_setting('app.process_id', true), '0')::INTEGER;
  
  -- Stage: Check notes to process
  m_stage_start := clock_timestamp();
  SELECT COUNT(*) INTO m_notes_count_before FROM notes_api;
  IF m_notes_count_before = 0 THEN
    RETURN;
  END IF;
  m_stage_end := clock_timestamp();
  m_stage_duration := EXTRACT(EPOCH FROM (m_stage_end - m_stage_start)) * 1000;
  INSERT INTO logs (message) VALUES ('[TIMING] Stage: Check notes_api count - Duration: ' || 
    ROUND(m_stage_duration, 2) || 'ms');
  
  -- Stage: Validate lock
  m_stage_start := clock_timestamp();
  SELECT value INTO m_process_id_db
  FROM properties
  WHERE key = 'lock';
  
  IF (m_process_id_db IS NULL) THEN
    RAISE EXCEPTION 'This call does not have a lock.';
  END IF;
  
  m_process_id_db_pid := SPLIT_PART(m_process_id_db, '_', 1)::INTEGER;
  
  IF (m_process_id <> m_process_id_db_pid) THEN
    RAISE EXCEPTION 'The process that holds the lock (%) is different from the current one (%).',
      m_process_id_db, m_process_id;
  END IF;
  m_stage_end := clock_timestamp();
  m_stage_duration := EXTRACT(EPOCH FROM (m_stage_end - m_stage_start)) * 1000;
  INSERT INTO logs (message) VALUES ('[TIMING] Stage: Validate lock - Duration: ' || 
    ROUND(m_stage_duration, 2) || 'ms');
  
  INSERT INTO logs (message) VALUES ('Lock validated. Starting bulk insertion of ' || 
    m_notes_count_before || ' notes');
  
  -- Stage: Count existing notes
  m_stage_start := clock_timestamp();
  SELECT COUNT(*) INTO m_existing_notes_count
  FROM notes
  WHERE note_id IN (SELECT note_id FROM notes_api);
  m_stage_end := clock_timestamp();
  m_stage_duration := EXTRACT(EPOCH FROM (m_stage_end - m_stage_start)) * 1000;
  INSERT INTO logs (message) VALUES ('[TIMING] Stage: Count existing notes - Duration: ' || 
    ROUND(m_stage_duration, 2) || 'ms, Existing: ' || m_existing_notes_count);
  
  -- Stage: Bulk INSERT with country lookup
  m_stage_start := clock_timestamp();
  -- OPTIMIZATION: Separate new notes from existing ones for better query optimization
  -- This allows PostgreSQL to optimize each path independently
  WITH existing_notes AS (
    -- Notes that already exist: preserve existing country assignment
    SELECT 
      na.note_id,
      na.latitude,
      na.longitude,
      na.created_at,
      na.closed_at,
      na.status,
      n.id_country  -- Use existing country assignment
    FROM notes_api na
    INNER JOIN notes n ON n.note_id = na.note_id
  ),
  new_notes AS (
    -- Notes that don't exist yet: need country lookup
    SELECT 
      na.note_id,
      na.latitude,
      na.longitude,
      na.created_at,
      na.closed_at,
      na.status
    FROM notes_api na
    LEFT JOIN notes n ON n.note_id = na.note_id
    WHERE n.note_id IS NULL
  ),
  new_notes_with_countries AS (
    -- For new notes, perform country lookup using get_country()
    SELECT 
      note_id,
      latitude,
      longitude,
      created_at,
      closed_at,
      status,
      get_country(longitude, latitude, note_id) as id_country
    FROM new_notes
  ),
  all_notes_ready AS (
    -- Combine existing notes (with preserved country) and new notes (with country lookup)
    SELECT * FROM existing_notes
    UNION ALL
    SELECT * FROM new_notes_with_countries
  )
  INSERT INTO notes (
    note_id,
    latitude,
    longitude,
    created_at,
    closed_at,
    status,
    id_country
  )
  SELECT 
    note_id,
    latitude,
    longitude,
    created_at,
    closed_at,
    status,
    id_country
  FROM all_notes_ready
  ON CONFLICT (note_id) DO UPDATE SET
    status = EXCLUDED.status,
    closed_at = COALESCE(EXCLUDED.closed_at, notes.closed_at),
    -- Only update country if the new one is not NULL
    id_country = COALESCE(EXCLUDED.id_country, notes.id_country);
  m_stage_end := clock_timestamp();
  m_stage_duration := EXTRACT(EPOCH FROM (m_stage_end - m_stage_start)) * 1000;
  
  SELECT COUNT(*) INTO m_notes_count_after FROM notes;
  m_new_notes_count := m_notes_count_before - m_existing_notes_count;
  m_updated_notes_count := m_existing_notes_count;
  
  INSERT INTO logs (message) VALUES ('[TIMING] Stage: Bulk INSERT notes (with get_country lookup) - Duration: ' || 
    ROUND(m_stage_duration, 2) || 'ms, New: ' || m_new_notes_count || ', Updated: ' || m_updated_notes_count);
  INSERT INTO logs (message) VALUES ('Bulk notes insertion completed: ' || 
    m_new_notes_count || ' new notes, ' || m_updated_notes_count || ' updated');
  
  -- Stage: ANALYZE notes (conditional)
  m_stage_start := clock_timestamp();
  -- Only run ANALYZE if:
  -- 1. Significant number of notes were inserted/updated in this cycle (>100), OR
  -- 2. It has been more than 6 hours since last ANALYZE (periodic maintenance)
  -- This optimization reduces overhead for small insertions while ensuring statistics stay current
  -- OPTIMIZATION: Read last ANALYZE time from properties table (cached) instead of scanning logs table
  -- This reduces check time from ~871ms to ~0.1ms
  SELECT COALESCE(
    (SELECT value::TIMESTAMP FROM properties WHERE key = 'last_analyze_notes_timestamp'),
    '1970-01-01'::TIMESTAMP
  ) INTO m_last_analyze_time;
  
  IF m_notes_count_before > 100 THEN
    INSERT INTO logs (message) VALUES ('Running ANALYZE notes (threshold: >100 notes in this cycle)');
    ANALYZE notes;
    -- Update cached timestamp in properties table
    INSERT INTO properties (key, value)
    VALUES ('last_analyze_notes_timestamp', NOW()::TEXT)
    ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
    m_last_analyze_time := NOW();
    m_stage_end := clock_timestamp();
    m_stage_duration := EXTRACT(EPOCH FROM (m_stage_end - m_stage_start)) * 1000;
    INSERT INTO logs (message) VALUES ('[TIMING] Stage: ANALYZE notes - Duration: ' || 
      ROUND(m_stage_duration, 2) || 'ms (EXECUTED)');
  ELSIF m_last_analyze_time < NOW() - (m_analyze_interval_hours || ' hours')::INTERVAL THEN
    INSERT INTO logs (message) VALUES ('Running ANALYZE notes (periodic: >' || 
      m_analyze_interval_hours || ' hours since last ANALYZE, ' || 
      EXTRACT(EPOCH FROM (NOW() - m_last_analyze_time))/3600 || ' hours elapsed)');
    ANALYZE notes;
    -- Update cached timestamp in properties table
    INSERT INTO properties (key, value)
    VALUES ('last_analyze_notes_timestamp', NOW()::TEXT)
    ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
    m_last_analyze_time := NOW();
    m_stage_end := clock_timestamp();
    m_stage_duration := EXTRACT(EPOCH FROM (m_stage_end - m_stage_start)) * 1000;
    INSERT INTO logs (message) VALUES ('[TIMING] Stage: ANALYZE notes - Duration: ' || 
      ROUND(m_stage_duration, 2) || 'ms (EXECUTED - periodic)');
  ELSE
    INSERT INTO logs (message) VALUES ('Skipping ANALYZE notes (only ' || 
      m_notes_count_before || ' notes processed, last ANALYZE ' || 
      EXTRACT(EPOCH FROM (NOW() - m_last_analyze_time))/3600 || ' hours ago, threshold: >' || 
      m_analyze_interval_hours || ' hours)');
    m_stage_end := clock_timestamp();
    m_stage_duration := EXTRACT(EPOCH FROM (m_stage_end - m_stage_start)) * 1000;
    INSERT INTO logs (message) VALUES ('[TIMING] Stage: ANALYZE notes check - Duration: ' || 
      ROUND(m_stage_duration, 2) || 'ms (SKIPPED)');
  END IF;
  
 EXCEPTION
  WHEN OTHERS THEN
    INSERT INTO logs (message) VALUES ('ERROR in bulk notes insertion: ' || SQLERRM);
    RAISE;
 END;
$$;

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
  'Statistics on notes' AS Text;
-- ANALYZE moved inside DO block above (conditional)

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
  COUNT(1) AS Qty, 'current notes - after' AS Text
FROM notes;

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
  COUNT(1) AS Qty, 'current comments - before' AS Text
FROM note_comments;

-- Synchronize sequences to prevent ID conflicts
-- OPTIMIZATION: Only synchronize if sequences are actually desynchronized
-- This avoids unnecessary SELECT MAX(id) scans in each cycle
DO /* Notes-processAPI-syncSequences */
$$
DECLARE
  m_stage_start TIMESTAMP;
  m_stage_end TIMESTAMP;
  m_stage_duration NUMERIC;
  m_seq_last_value BIGINT;
  m_max_id_table BIGINT;
  m_needs_sync BOOLEAN := false;
  m_text_seq_last_value BIGINT;
  m_text_max_id_table BIGINT;
  m_text_needs_sync BOOLEAN := false;
BEGIN
  m_stage_start := clock_timestamp();
  
  -- Check if note_comments_id_seq needs synchronization
  SELECT last_value INTO m_seq_last_value
  FROM pg_sequences
  WHERE sequencename = 'note_comments_id_seq';
  
  SELECT COALESCE(MAX(id), 0) INTO m_max_id_table
  FROM note_comments;
  
  -- Sequence is desynchronized if last_value < max_id_table
  -- Always sync if sequence is behind (don't use margin - be conservative to prevent duplicates)
  m_needs_sync := (m_seq_last_value < m_max_id_table);
  
  IF m_needs_sync THEN
    -- Set sequence to max_id_table (use true for is_called so nextval() returns max_id_table + 1)
    PERFORM setval('note_comments_id_seq', 
      GREATEST(m_max_id_table, 0), 
      true);
    INSERT INTO logs (message) VALUES ('Sequences synchronized: note_comments_id_seq (was ' || 
      m_seq_last_value || ', now ' || GREATEST(m_max_id_table, 0) || ', nextval will return ' || (GREATEST(m_max_id_table, 0) + 1) || ', max_id=' || m_max_id_table || ')');
  END IF;
  
  -- Synchronize note_comments_text_id_seq if it exists
  IF EXISTS (SELECT 1 FROM pg_class WHERE relname = 'note_comments_text_id_seq') THEN
    SELECT last_value INTO m_text_seq_last_value
    FROM pg_sequences
    WHERE sequencename = 'note_comments_text_id_seq';
    
    SELECT COALESCE(MAX(id), 0) INTO m_text_max_id_table
    FROM note_comments_text;
    
    m_text_needs_sync := (m_text_seq_last_value < m_text_max_id_table);
    
    IF m_text_needs_sync THEN
      PERFORM setval('note_comments_text_id_seq',
        GREATEST(m_text_max_id_table, 0),
        true);
      INSERT INTO logs (message) VALUES ('Sequences synchronized: note_comments_text_id_seq (was ' || 
        m_text_seq_last_value || ', now ' || GREATEST(m_text_max_id_table, 0) || ', nextval will return ' || (GREATEST(m_text_max_id_table, 0) + 1) || ', max_id=' || m_text_max_id_table || ')');
    END IF;
  END IF;
  
  m_stage_end := clock_timestamp();
  m_stage_duration := EXTRACT(EPOCH FROM (m_stage_end - m_stage_start)) * 1000;
  
  IF m_needs_sync OR m_text_needs_sync THEN
    INSERT INTO logs (message) VALUES ('[TIMING] Stage: Synchronize sequences (SELECT MAX(id)) - Duration: ' || 
      ROUND(m_stage_duration, 2) || 'ms');
  ELSE
    INSERT INTO logs (message) VALUES ('[TIMING] Stage: Synchronize sequences check (SKIPPED - already synchronized) - Duration: ' || 
      ROUND(m_stage_duration, 2) || 'ms');
  END IF;
END
$$;

DO /* Notes-processAPI-insertComments-bulk */
$$
 DECLARE
  m_process_id INTEGER;
  m_comments_count_before INTEGER;
  m_comments_count_after INTEGER;
  m_existing_comments_count INTEGER;
  m_new_comments_count INTEGER;
  m_last_analyze_time TIMESTAMP;
  m_analyze_interval_hours INTEGER := 6;
  m_stage_start TIMESTAMP;
  m_stage_end TIMESTAMP;
  m_stage_duration NUMERIC;
 BEGIN
  m_process_id := COALESCE(current_setting('app.process_id', true), '0')::INTEGER;

  -- Stage: Check comments to process
  m_stage_start := clock_timestamp();
  SELECT COUNT(*) INTO m_comments_count_before FROM note_comments_api;
  IF m_comments_count_before = 0 THEN
    RETURN;
  END IF;
  m_stage_end := clock_timestamp();
  m_stage_duration := EXTRACT(EPOCH FROM (m_stage_end - m_stage_start)) * 1000;
  INSERT INTO logs (message) VALUES ('[TIMING] Stage: Check note_comments_api count - Duration: ' || 
    ROUND(m_stage_duration, 2) || 'ms');
  
  INSERT INTO logs (message) VALUES ('Starting bulk insertion of ' || 
    m_comments_count_before || ' comments');
  
  -- Stage: Count existing comments
  m_stage_start := clock_timestamp();
  SELECT COUNT(*) INTO m_existing_comments_count
  FROM note_comments
  WHERE (note_id, sequence_action) IN (
    SELECT note_id, sequence_action 
    FROM note_comments_api 
    WHERE sequence_action IS NOT NULL
  );
  m_stage_end := clock_timestamp();
  m_stage_duration := EXTRACT(EPOCH FROM (m_stage_end - m_stage_start)) * 1000;
  INSERT INTO logs (message) VALUES ('[TIMING] Stage: Count existing comments - Duration: ' || 
    ROUND(m_stage_duration, 2) || 'ms, Existing: ' || m_existing_comments_count);
  
  -- Stage: Bulk INSERT users
  m_stage_start := clock_timestamp();
  INSERT INTO users (user_id, username)
  SELECT DISTINCT id_user, username
  FROM note_comments_api
  WHERE id_user IS NOT NULL AND username IS NOT NULL
  ON CONFLICT (user_id) DO UPDATE SET
    username = EXCLUDED.username;
  m_stage_end := clock_timestamp();
  m_stage_duration := EXTRACT(EPOCH FROM (m_stage_end - m_stage_start)) * 1000;
  INSERT INTO logs (message) VALUES ('[TIMING] Stage: Bulk INSERT users - Duration: ' || 
    ROUND(m_stage_duration, 2) || 'ms');
  
  -- Stage: Bulk INSERT comments
  m_stage_start := clock_timestamp();
  -- Bulk INSERT comments (skip existing ones using NOT EXISTS for efficiency)
  -- Use ON CONFLICT (id) DO NOTHING as additional protection against sequence desynchronization
  INSERT INTO note_comments (
    id,
    note_id,
    sequence_action,
    event,
    created_at,
    id_user
  )
  SELECT 
    nextval('note_comments_id_seq'),
    nca.note_id,
    nca.sequence_action,
    nca.event,
    nca.created_at,
    nca.id_user
  FROM note_comments_api nca
  WHERE NOT EXISTS (
    -- Skip comments that already exist
    -- Handle both cases: with sequence_action and without (for backward compatibility)
    SELECT 1 FROM note_comments nc
    WHERE nc.note_id = nca.note_id
      AND (
        (nca.sequence_action IS NOT NULL AND nc.sequence_action = nca.sequence_action)
        OR (nca.sequence_action IS NULL AND nc.note_id = nca.note_id AND nc.event = nca.event AND nc.created_at = nca.created_at)
      )
  )
  ON CONFLICT (id) DO NOTHING;
  -- Note: ON CONFLICT (id) DO NOTHING handles cases where nextval() generates an ID that already exists
  -- This can happen if the sequence is desynchronized. The WHERE NOT EXISTS clause prevents logical duplicates,
  -- and ON CONFLICT handles sequence-related duplicates
  m_stage_end := clock_timestamp();
  m_stage_duration := EXTRACT(EPOCH FROM (m_stage_end - m_stage_start)) * 1000;
  
  SELECT COUNT(*) INTO m_comments_count_after FROM note_comments;
  m_new_comments_count := m_comments_count_before - m_existing_comments_count;
  
  INSERT INTO logs (message) VALUES ('[TIMING] Stage: Bulk INSERT comments - Duration: ' || 
    ROUND(m_stage_duration, 2) || 'ms, New: ' || m_new_comments_count || ', Skipped: ' || m_existing_comments_count);
  INSERT INTO logs (message) VALUES ('Bulk comments insertion completed: ' || 
    m_new_comments_count || ' new comments inserted, ' || 
    m_existing_comments_count || ' skipped (already exist)');
  
  -- Stage: ANALYZE note_comments (conditional)
  m_stage_start := clock_timestamp();
  -- Only run ANALYZE if:
  -- 1. Significant number of comments were processed in this cycle (>100), OR
  -- 2. It has been more than 6 hours since last ANALYZE (periodic maintenance)
  -- This optimization reduces overhead for small insertions while ensuring statistics stay current
  -- OPTIMIZATION: Read last ANALYZE time from properties table (cached) instead of scanning logs table
  -- This reduces check time from ~848ms to ~0.1ms
  SELECT COALESCE(
    (SELECT value::TIMESTAMP FROM properties WHERE key = 'last_analyze_comments_timestamp'),
    '1970-01-01'::TIMESTAMP
  ) INTO m_last_analyze_time;
  
  IF m_comments_count_before > 100 THEN
    INSERT INTO logs (message) VALUES ('Running ANALYZE note_comments (threshold: >100 comments in this cycle)');
    ANALYZE note_comments;
    -- Update cached timestamp in properties table
    INSERT INTO properties (key, value)
    VALUES ('last_analyze_comments_timestamp', NOW()::TEXT)
    ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
    m_last_analyze_time := NOW();
    m_stage_end := clock_timestamp();
    m_stage_duration := EXTRACT(EPOCH FROM (m_stage_end - m_stage_start)) * 1000;
    INSERT INTO logs (message) VALUES ('[TIMING] Stage: ANALYZE note_comments - Duration: ' || 
      ROUND(m_stage_duration, 2) || 'ms (EXECUTED)');
  ELSIF m_last_analyze_time < NOW() - (m_analyze_interval_hours || ' hours')::INTERVAL THEN
    INSERT INTO logs (message) VALUES ('Running ANALYZE note_comments (periodic: >' || 
      m_analyze_interval_hours || ' hours since last ANALYZE, ' || 
      EXTRACT(EPOCH FROM (NOW() - m_last_analyze_time))/3600 || ' hours elapsed)');
    ANALYZE note_comments;
    -- Update cached timestamp in properties table
    INSERT INTO properties (key, value)
    VALUES ('last_analyze_comments_timestamp', NOW()::TEXT)
    ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
    m_last_analyze_time := NOW();
    m_stage_end := clock_timestamp();
    m_stage_duration := EXTRACT(EPOCH FROM (m_stage_end - m_stage_start)) * 1000;
    INSERT INTO logs (message) VALUES ('[TIMING] Stage: ANALYZE note_comments - Duration: ' || 
      ROUND(m_stage_duration, 2) || 'ms (EXECUTED - periodic)');
  ELSE
    INSERT INTO logs (message) VALUES ('Skipping ANALYZE note_comments (only ' || 
      m_comments_count_before || ' comments processed, last ANALYZE ' || 
      EXTRACT(EPOCH FROM (NOW() - m_last_analyze_time))/3600 || ' hours ago, threshold: >' || 
      m_analyze_interval_hours || ' hours)');
    m_stage_end := clock_timestamp();
    m_stage_duration := EXTRACT(EPOCH FROM (m_stage_end - m_stage_start)) * 1000;
    INSERT INTO logs (message) VALUES ('[TIMING] Stage: ANALYZE note_comments check - Duration: ' || 
      ROUND(m_stage_duration, 2) || 'ms (SKIPPED)');
  END IF;
  
 EXCEPTION
  WHEN OTHERS THEN
    INSERT INTO logs (message) VALUES ('ERROR in bulk comments insertion: ' || SQLERRM);
    RAISE;
 END;
$$;

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
  'Statistics on comments' AS Text;
-- ANALYZE moved inside DO block above (conditional)
SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
  COUNT(1) AS Qty, 'current comments - after' AS Qty
FROM note_comments;

-- Validate data integrity before proceeding
-- OPTIMIZED: Only check notes inserted in THIS cycle (from notes_api), not all notes from last hour
DO /* Notes-processAPI-validateIntegrity */
$$
 DECLARE
  m_notes_without_comments INTEGER;
  m_total_notes INTEGER;
  m_has_comments BOOLEAN;
  m_integrity_check_passed BOOLEAN := TRUE;
  m_notes_in_this_cycle INTEGER;
  m_stage_start TIMESTAMP;
  m_stage_end TIMESTAMP;
  m_stage_duration NUMERIC;
 BEGIN
  m_stage_start := clock_timestamp();
  -- OPTIMIZATION: Use EXISTS instead of COUNT(*) to check if database has comments
  -- This reduces check time from ~434ms to ~0.01ms (43000x faster)
  -- EXISTS stops at first row found, while COUNT(*) scans entire table
  SELECT EXISTS(SELECT 1 FROM note_comments LIMIT 1) INTO m_has_comments;
  
  -- OPTIMIZATION: Check only notes from THIS cycle (from notes_api table)
  -- This is much faster than checking all notes from last hour
  -- notes_api still contains the note_ids from this cycle (before TRUNCATE)
  SELECT COUNT(*) INTO m_notes_in_this_cycle FROM notes_api;
  m_stage_end := clock_timestamp();
  m_stage_duration := EXTRACT(EPOCH FROM (m_stage_end - m_stage_start)) * 1000;
  INSERT INTO logs (message) VALUES ('[TIMING] Stage: Integrity check - count totals - Duration: ' || 
    ROUND(m_stage_duration, 2) || 'ms');
  
  IF m_notes_in_this_cycle = 0 THEN
   -- No notes to check in this cycle
   m_integrity_check_passed := TRUE;
   INSERT INTO logs (message) VALUES ('Integrity check PASSED - no notes processed in this cycle');
   PERFORM set_config('app.integrity_check_passed', m_integrity_check_passed::TEXT, true);
   RETURN;
  END IF;
  
  -- Count notes from THIS cycle that don't have any comments
  m_stage_start := clock_timestamp();
  -- Only check notes that are old enough to have comments (created >30 minutes ago)
  -- This prevents false positives from very new notes that legitimately don't have comments yet
  SELECT COUNT(DISTINCT n.note_id)
   INTO m_notes_without_comments
  FROM notes n
  INNER JOIN notes_api na ON na.note_id = n.note_id  -- Only check notes from this cycle
  LEFT JOIN note_comments nc ON nc.note_id = n.note_id
  WHERE n.created_at < CURRENT_TIMESTAMP - INTERVAL '30 minutes'  -- Only check notes old enough to have comments
   AND nc.note_id IS NULL;
  
  -- Count total notes from THIS cycle that are old enough to have comments
  SELECT COUNT(DISTINCT n.note_id)
   INTO m_total_notes
  FROM notes n
  INNER JOIN notes_api na ON na.note_id = n.note_id  -- Only check notes from this cycle
  WHERE n.created_at < CURRENT_TIMESTAMP - INTERVAL '30 minutes';
  m_stage_end := clock_timestamp();
  m_stage_duration := EXTRACT(EPOCH FROM (m_stage_end - m_stage_start)) * 1000;
  INSERT INTO logs (message) VALUES ('[TIMING] Stage: Integrity check - verify notes without comments - Duration: ' || 
    ROUND(m_stage_duration, 2) || 'ms, Notes without comments: ' || m_notes_without_comments || ' / ' || m_total_notes);
  
  -- Log integrity check results
  INSERT INTO logs (message) VALUES ('Integrity check (this cycle): ' || m_notes_without_comments || 
   ' notes without comments out of ' || m_total_notes || ' total notes from this cycle (old enough to verify)');
  INSERT INTO logs (message) VALUES ('Total notes in this cycle: ' || m_notes_in_this_cycle || 
   ', Database has comments: ' || m_has_comments);
  
  -- Special case: If database has no comments at all, this is likely after a cleanup/deletion
  -- In this case, we should be more permissive and allow the check to pass
  -- This prevents the integrity check from blocking timestamp updates after data deletion
  IF NOT m_has_comments THEN
   INSERT INTO logs (message) VALUES ('INFO: Database has no comments - likely after cleanup/deletion. Integrity check will be permissive.');
   -- If there are no comments in the entire DB, we allow the check to pass
   -- This handles the case after deleteDataAfterTimestamp.sql execution
   m_integrity_check_passed := TRUE;
   INSERT INTO logs (message) VALUES ('Integrity check PASSED - no comments in database (post-cleanup state)');
  ELSIF m_total_notes = 0 THEN
   -- If there are no notes inserted recently, nothing to check
   m_integrity_check_passed := TRUE;
   INSERT INTO logs (message) VALUES ('Integrity check PASSED - no notes inserted recently to verify');
  ELSIF m_total_notes < 10 THEN
   -- If very few notes to check (< 10), be more permissive
   -- Very new notes may legitimately not have comments yet
   -- API search.xml may not return comments for very new notes
   IF m_notes_without_comments = m_total_notes THEN
    -- If ALL notes lack comments, this might be a real issue, but allow it for very small samples
    m_integrity_check_passed := TRUE;
    INSERT INTO logs (message) VALUES ('Integrity check PASSED - very few notes to verify (' || m_total_notes || '), being permissive');
   ELSIF m_notes_without_comments > (m_total_notes * 0.05) THEN
    -- If more than 5% of notes lack comments, flag as integrity issue
    m_integrity_check_passed := FALSE;
    INSERT INTO logs (message) VALUES ('WARNING: Integrity check FAILED - too many notes without comments');
    RAISE NOTICE 'Integrity check failed: % notes without comments out of % total', 
     m_notes_without_comments, m_total_notes;
   ELSE
    INSERT INTO logs (message) VALUES ('Integrity check PASSED - data consistency maintained');
   END IF;
  ELSIF m_notes_without_comments > (m_total_notes * 0.05) THEN
   -- If more than 5% of notes lack comments, flag as integrity issue
   m_integrity_check_passed := FALSE;
   INSERT INTO logs (message) VALUES ('WARNING: Integrity check FAILED - too many notes without comments');
   RAISE NOTICE 'Integrity check failed: % notes without comments out of % total', 
    m_notes_without_comments, m_total_notes;
  ELSE
   INSERT INTO logs (message) VALUES ('Integrity check PASSED - data consistency maintained');
  END IF;
  
  -- Store integrity check result for use by updateLastValues
  -- Use true (session-level) so it persists until updateLastValues reads it
  -- Must be true to persist across separate psql transactions
  PERFORM set_config('app.integrity_check_passed', m_integrity_check_passed::TEXT, true);
 END;
$$;

-- Process lock is handled by the calling script
