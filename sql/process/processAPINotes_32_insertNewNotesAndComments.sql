-- Insert new notes and comments from API
-- Author: Andres Gomez (AngocA)
-- Version: 2025-10-22

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 'Inserting new notes and comments from API' AS Task;

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

DO /* Notes-processAPI-insertNotes */
$$
 DECLARE
  r RECORD;
  m_closed_time VARCHAR(100);
  m_stmt VARCHAR(200);
  m_min_note_id INTEGER;
  m_max_note_id INTEGER;
  m_chunk_size INTEGER;
  m_current_chunk INTEGER;
  m_process_id INTEGER;
  m_batch_size INTEGER := 50;  -- Batch size for transaction processing
  m_batch_count INTEGER := 0;   -- Counter for batch processing
  m_success_count INTEGER := 0; -- Counter for successful insertions
  m_error_count INTEGER := 0;   -- Counter for failed insertions
  m_notes_cursor CURSOR FOR      -- Cursor for batch processing
   SELECT note_id, latitude, longitude, created_at, closed_at, status
   FROM notes_api
   ORDER BY created_at;
 BEGIN

  -- Get process ID for parallel processing
  m_process_id := COALESCE(current_setting('app.process_id', true), '0')::INTEGER;
  
  -- Check if there are notes to process
  IF (SELECT COUNT(1) FROM notes_api) = 0 THEN
   RETURN;
  END IF;
  
  -- Process notes in batches with transactions
  FOR r IN m_notes_cursor LOOP
   m_batch_count := m_batch_count + 1;
   
   -- Start transaction for each note
   BEGIN
    m_closed_time := QUOTE_NULLABLE(r.closed_at);

    INSERT INTO logs (message) VALUES (r.note_id || ' - Batch ' || 
     (m_batch_count / m_batch_size + 1) || ' - Processing note');

    m_stmt := 'CALL insert_note (' || r.note_id || ', ' || r.latitude || ', '
      || r.longitude || ', ' || 'TO_TIMESTAMP(''' || r.created_at
      || ''', ''YYYY-MM-DD HH24:MI:SS'')' || ', ' || m_process_id || ')';
    
    EXECUTE m_stmt;
    
    m_success_count := m_success_count + 1;
    INSERT INTO logs (message) VALUES (r.note_id || ' - Note inserted successfully');
    
    -- Log batch completion every batch_size notes
    IF m_batch_count % m_batch_size = 0 THEN
     INSERT INTO logs (message) VALUES ('Batch ' || (m_batch_count / m_batch_size) || 
      ' completed: ' || m_success_count || ' notes processed');
    END IF;
    
   EXCEPTION
    WHEN OTHERS THEN
     m_error_count := m_error_count + 1;
     INSERT INTO logs (message) VALUES (r.note_id || ' - ERROR inserting note: ' || SQLERRM);
     -- Continue with next note (don't fail entire batch)
     RAISE NOTICE 'Failed to insert note %: %', r.note_id, SQLERRM;
   END;
  END LOOP;
  
  -- Log final statistics
  INSERT INTO logs (message) VALUES ('Notes processing completed: ' || 
   m_success_count || ' successful, ' || m_error_count || ' failed');
   
  -- If too many errors, raise exception
  IF m_error_count > (m_success_count * 0.1) THEN  -- More than 10% errors
   RAISE EXCEPTION 'Too many note insertion errors: % failed out of % total', 
    m_error_count, (m_success_count + m_error_count);
  END IF;
 END;
$$;

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
  'Statistics on notes' AS Text;
ANALYZE notes;

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
  COUNT(1) AS Qty, 'current notes - after' AS Text
FROM notes;

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
  COUNT(1) AS Qty, 'current comments - before' AS Text
FROM note_comments;

DO /* Notes-processAPI-insertComments */
$$
 DECLARE
  r RECORD;
  m_created_time VARCHAR(100);
  m_stmt VARCHAR(500);
  m_process_id INTEGER;
  m_batch_size INTEGER := 50;     -- Batch size for transaction processing
  m_batch_count INTEGER := 0;     -- Counter for batch processing
  m_success_count INTEGER := 0;   -- Counter for successful insertions
  m_error_count INTEGER := 0;     -- Counter for failed insertions
  m_comments_cursor CURSOR FOR    -- Cursor for batch processing
   SELECT note_id, event, created_at, id_user, username
   FROM note_comments_api
   ORDER BY created_at, sequence_action;
 BEGIN

  -- Get process ID for parallel processing
  m_process_id := COALESCE(current_setting('app.process_id', true), '0')::INTEGER;

  -- Process comments in batches with transactions
  FOR r IN m_comments_cursor LOOP
   m_batch_count := m_batch_count + 1;
   
   -- Start transaction for each comment
   BEGIN
    IF (r.id_user IS NOT NULL) THEN
     m_stmt := 'CALL insert_note_comment (' || r.note_id || ', '
       || '''' || r.event || '''::note_event_enum, '
       || 'TO_TIMESTAMP(''' || r.created_at
       || ''', ''YYYY-MM-DD HH24:MI:SS''), '
       || r.id_user || ', '
       || QUOTE_NULLABLE(r.username) || ', ' || m_process_id || ')';
    ELSE
     m_stmt := 'CALL insert_note_comment (' || r.note_id || ', '
       || '''' || r.event || '''::note_event_enum, '
       || 'TO_TIMESTAMP(''' || r.created_at
       || ''', ''YYYY-MM-DD HH24:MI:SS''), '
       || 'NULL, '
       || QUOTE_NULLABLE(r.username) || ', ' || m_process_id || ')';
    END IF;
    
    EXECUTE m_stmt;
    
    m_success_count := m_success_count + 1;
    INSERT INTO logs (message) VALUES (r.note_id || ' - Comment inserted successfully');
    
    -- Log batch completion every batch_size comments
    IF m_batch_count % m_batch_size = 0 THEN
     INSERT INTO logs (message) VALUES ('Comment batch ' || (m_batch_count / m_batch_size) || 
      ' completed: ' || m_success_count || ' comments processed');
    END IF;
    
   EXCEPTION
    WHEN OTHERS THEN
     m_error_count := m_error_count + 1;
     INSERT INTO logs (message) VALUES (r.note_id || ' - ERROR inserting comment: ' || SQLERRM);
     -- Continue with next comment (don't fail entire batch)
     RAISE NOTICE 'Failed to insert comment for note %: %', r.note_id, SQLERRM;
   END;
  END LOOP;
  
  -- Log final statistics
  INSERT INTO logs (message) VALUES ('Comments processing completed: ' || 
   m_success_count || ' successful, ' || m_error_count || ' failed');
   
  -- If too many errors, raise exception
  IF m_error_count > (m_success_count * 0.1) THEN  -- More than 10% errors
   RAISE EXCEPTION 'Too many comment insertion errors: % failed out of % total', 
    m_error_count, (m_success_count + m_error_count);
  END IF;
 END;
$$;

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
  'Statistics on comments' AS Text;
ANALYZE note_comments;
SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
  COUNT(1) AS Qty, 'current comments - after' AS Qty
FROM note_comments;

-- Validate data integrity before proceeding
DO /* Notes-processAPI-validateIntegrity */
$$
 DECLARE
  m_notes_without_comments INTEGER;
  m_total_notes INTEGER;
  m_integrity_check_passed BOOLEAN := TRUE;
 BEGIN
  -- Count notes that don't have any comments
  SELECT COUNT(DISTINCT n.note_id)
   INTO m_notes_without_comments
  FROM notes n
  LEFT JOIN note_comments nc ON nc.note_id = n.note_id
  WHERE n.created_at > (
    SELECT timestamp FROM max_note_timestamp
   ) - INTERVAL '1 day'  -- Check notes from last day
   AND nc.note_id IS NULL;
  
  -- Count total notes from last day
  SELECT COUNT(DISTINCT note_id)
   INTO m_total_notes
  FROM notes
  WHERE created_at > (
    SELECT timestamp FROM max_note_timestamp
   ) - INTERVAL '1 day';
  
  -- Log integrity check results
  INSERT INTO logs (message) VALUES ('Integrity check: ' || m_notes_without_comments || 
   ' notes without comments out of ' || m_total_notes || ' total notes from last day');
  
  -- If more than 5% of notes lack comments, flag as integrity issue
  IF m_notes_without_comments > (m_total_notes * 0.05) THEN
   m_integrity_check_passed := FALSE;
   INSERT INTO logs (message) VALUES ('WARNING: Integrity check FAILED - too many notes without comments');
   RAISE NOTICE 'Integrity check failed: % notes without comments out of % total', 
    m_notes_without_comments, m_total_notes;
  ELSE
   INSERT INTO logs (message) VALUES ('Integrity check PASSED - data consistency maintained');
  END IF;
  
  -- Store integrity check result for use by updateLastValues
  PERFORM set_config('app.integrity_check_passed', m_integrity_check_passed::TEXT, false);
 END;
$$;

-- Process lock is handled by the calling script
