-- Insert new notes and comments from API
-- Author: Andres Gomez (AngocA)
-- Version: 2025-07-26

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 'Inserting new notes and comments from API' AS Task;

-- Set process lock for this operation
DO $$
DECLARE
  m_process_id INTEGER;
BEGIN
  -- Get process ID for parallel processing
  m_process_id := COALESCE(current_setting('app.process_id', true), '0')::INTEGER;
  
  -- Set lock for this process
  CALL put_lock(m_process_id::VARCHAR(32));
  
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
 BEGIN

  -- Get process ID for parallel processing
  m_process_id := COALESCE(current_setting('app.process_id', true), '0')::INTEGER;
  
  -- Check if there are notes to process
  IF (SELECT COUNT(1) FROM notes_api) = 0 THEN
   RETURN;
  END IF;
  
  -- Get range for parallel processing if process_id contains chunk info
  IF m_process_id > 999 THEN
   -- Validate that the second part is a valid integer
   IF m_process_id::TEXT ~ '^[0-9]+_[0-9]+$' THEN
    m_current_chunk := SPLIT_PART(m_process_id, '_', 2)::INTEGER;
    m_chunk_size := (SELECT COUNT(1) FROM notes_api) / 4; -- Using MAX_THREADS (4)
    m_min_note_id := (m_current_chunk - 1) * m_chunk_size + 1;
    m_max_note_id := m_current_chunk * m_chunk_size;
   ELSE
    -- Fall back to sequential processing if chunk info is invalid
    m_current_chunk := 0;
    m_chunk_size := 0;
    m_min_note_id := 0;
    m_max_note_id := 0;
   END IF;
   
   -- Process only notes in this chunk range (if valid chunk info)
   IF m_current_chunk > 0 THEN
    FOR r IN
     SELECT /* Notes-processAPI */ note_id, latitude, longitude, created_at,
       closed_at, status
     FROM notes_api
     WHERE note_id BETWEEN m_min_note_id AND m_max_note_id
     ORDER BY created_at
    LOOP
    m_closed_time := QUOTE_NULLABLE(r.closed_at);

    INSERT INTO logs (message) VALUES (r.note_id || ' - created:'
     || r.created_at || ',closed:' || m_closed_time || '.');

    m_stmt := 'CALL insert_note (' || r.note_id || ', ' || r.latitude || ', '
      || r.longitude || ', ' || 'TO_TIMESTAMP(''' || r.created_at
      || ''', ''YYYY-MM-DD HH24:MI:SS'')' || ', ' || m_process_id || ')';
    --RAISE NOTICE 'Note % (%) %.', r.note_id, m_stmt;
    EXECUTE m_stmt;
         INSERT INTO logs (message) VALUES (r.note_id || ' - Note inserted.');
    END LOOP;
   ELSE
    -- Sequential processing for this chunk (fallback)
    FOR r IN
     SELECT /* Notes-processAPI */ note_id, latitude, longitude, created_at,
       closed_at, status
     FROM notes_api
     ORDER BY created_at
    LOOP
     m_closed_time := QUOTE_NULLABLE(r.closed_at);

     INSERT INTO logs (message) VALUES (r.note_id || ' - created:'
      || r.created_at || ',closed:' || m_closed_time || '.');

     m_stmt := 'CALL insert_note (' || r.note_id || ', ' || r.latitude || ', '
       || r.longitude || ', ' || 'TO_TIMESTAMP(''' || r.created_at
       || ''', ''YYYY-MM-DD HH24:MI:SS'')' || ', ' || m_process_id || ')';
     --RAISE NOTICE 'Note % (%) %.', r.note_id, m_stmt;
     EXECUTE m_stmt;
     INSERT INTO logs (message) VALUES (r.note_id || ' - Note inserted.');
    END LOOP;
   END IF;
   
  ELSE
   -- Sequential processing for single process
   FOR r IN
    SELECT /* Notes-processAPI */ note_id, latitude, longitude, created_at,
      closed_at, status
    FROM notes_api
    ORDER BY created_at
   LOOP
    m_closed_time := QUOTE_NULLABLE(r.closed_at);

    INSERT INTO logs (message) VALUES (r.note_id || ' - created:'
     || r.created_at || ',closed:' || m_closed_time || '.');

    m_stmt := 'CALL insert_note (' || r.note_id || ', ' || r.latitude || ', '
      || r.longitude || ', ' || 'TO_TIMESTAMP(''' || r.created_at
      || ''', ''YYYY-MM-DD HH24:MI:SS'')' || ', ' || m_process_id || ')';
    --RAISE NOTICE 'Note % (%) %.', r.note_id, m_stmt;
    EXECUTE m_stmt;
    INSERT INTO logs (message) VALUES (r.note_id || ' - Note inserted.');
   END LOOP;
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
 BEGIN

  -- Get process ID for parallel processing
  m_process_id := COALESCE(current_setting('app.process_id', true), '0')::INTEGER;

  FOR r IN
   SELECT /* Notes-processAPI */ note_id, event, created_at, id_user,
    username
   FROM note_comments_api
   ORDER BY created_at, sequence_action
  LOOP

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
   --RAISE NOTICE 'Comment %.', m_stmt;
   EXECUTE m_stmt;
   INSERT INTO logs (message) VALUES (r.note_id
     || ' - Comment for note inserted.');
  END LOOP;
 END;
$$;

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
  'Statistics on comments' AS Text;
ANALYZE note_comments;
SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
  COUNT(1) AS Qty, 'current comments - after' AS Qty
FROM note_comments;

-- Remove process lock
DO $$
DECLARE
  m_process_id INTEGER;
BEGIN
  -- Get process ID for parallel processing
  m_process_id := COALESCE(current_setting('app.process_id', true), '0')::INTEGER;
  
      -- Remove lock for this process
    CALL remove_lock(m_process_id::VARCHAR(32));
END $$;
