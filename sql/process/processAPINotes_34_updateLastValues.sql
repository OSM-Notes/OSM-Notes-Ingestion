-- Refreshes the last value stored in the database. It calculates the max value
-- by taking the most recent open note, most recent closed note and most recent
-- comment.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-12-20

SELECT /* Notes-processAPI */ timestamp
FROM max_note_timestamp;
DO /* Notes-processAPI-updateLastValues */
$$
 DECLARE
  last_update TIMESTAMP;
  new_last_update TIMESTAMP;
  integrity_check_passed BOOLEAN;
  notes_without_comments INTEGER;
  total_notes INTEGER;
  total_comments_in_db INTEGER;
  gap_percentage DECIMAL(5,2);
  notes_without_comments_json TEXT;
 BEGIN
  -- Check if integrity check passed
  -- Handle case where variable doesn't exist (returns empty string or NULL)
  -- The variable is set by processAPINotes_32_insertNewNotesAndComments.sql
  -- with set_config('app.integrity_check_passed', ..., true) which makes it session-level
  -- IMPORTANT: The variable should persist across DO blocks in the same psql session
  -- If it doesn't, we'll re-check the integrity condition here
  BEGIN
   -- Try to read the variable, defaulting to FALSE if not set
   integrity_check_passed := COALESCE(
    NULLIF(current_setting('app.integrity_check_passed', true), '')::BOOLEAN,
    FALSE
   );
  EXCEPTION
   WHEN OTHERS THEN
    -- If variable doesn't exist or is invalid, default to FALSE
    -- We'll re-check the integrity condition below
    integrity_check_passed := FALSE;
  END;
  
  -- If variable was not set or is FALSE, re-check integrity condition
  -- This handles the case where the variable didn't persist between DO blocks
  IF NOT integrity_check_passed THEN
   -- Re-check integrity: count notes without comments in recently inserted data
   -- Only check notes inserted in the last hour that were created more than 30 minutes ago
   SELECT COUNT(DISTINCT n.note_id)
    INTO notes_without_comments
   FROM notes n
   LEFT JOIN note_comments nc ON nc.note_id = n.note_id
   WHERE n.insert_time > CURRENT_TIMESTAMP - INTERVAL '1 hour'
    AND n.created_at < CURRENT_TIMESTAMP - INTERVAL '30 minutes'
    AND nc.note_id IS NULL;
   
   -- Count total notes inserted in the last hour that are old enough to have comments
   SELECT COUNT(DISTINCT note_id)
    INTO total_notes
   FROM notes
   WHERE insert_time > CURRENT_TIMESTAMP - INTERVAL '1 hour'
    AND created_at < CURRENT_TIMESTAMP - INTERVAL '30 minutes';
   
   -- If very few notes (< 10), be permissive
   IF total_notes < 10 THEN
    integrity_check_passed := TRUE;
    INSERT INTO logs (message) VALUES ('Integrity check re-validated: very few notes to verify (' || total_notes || '), being permissive');
   ELSIF notes_without_comments <= (total_notes * 0.05) THEN
    -- If 5% or less of notes lack comments, integrity check passes
    integrity_check_passed := TRUE;
    INSERT INTO logs (message) VALUES ('Integrity check re-validated: ' || notes_without_comments || ' notes without comments out of ' || total_notes || ' total (acceptable)');
   ELSE
    -- Too many notes without comments
    integrity_check_passed := FALSE;
    INSERT INTO logs (message) VALUES ('Integrity check re-validated: FAILED - ' || notes_without_comments || ' notes without comments out of ' || total_notes || ' total (too many)');
   END IF;
  END IF;
  
  -- Count total comments in entire database
  -- This helps detect if we're in a state after data deletion
  SELECT COUNT(*) INTO total_comments_in_db FROM note_comments;
  
  -- Special case: If database has no comments at all, skip gap checking
  -- This handles the case after deleteDataAfterTimestamp.sql execution
  IF total_comments_in_db = 0 THEN
   notes_without_comments := 0;
   total_notes := 0;
   gap_percentage := 0;
  ELSE
   -- Count notes without comments in recently inserted data
   -- Only check notes inserted in the last hour that were created more than 30 minutes ago
   -- This prevents false positives from very new notes that legitimately don't have comments yet
   -- Notes created less than 30 minutes ago may not have comments yet, which is normal
   -- OSM API may not have comments available for very new notes immediately
   SELECT COUNT(DISTINCT n.note_id)
    INTO notes_without_comments
   FROM notes n
   LEFT JOIN note_comments nc ON nc.note_id = n.note_id
   WHERE n.insert_time > CURRENT_TIMESTAMP - INTERVAL '1 hour'  -- Check only recently inserted notes
    AND n.created_at < CURRENT_TIMESTAMP - INTERVAL '30 minutes'  -- Only check notes old enough to have comments
    AND nc.note_id IS NULL;
   
   -- Count total notes inserted in the last hour that are old enough to have comments
   SELECT COUNT(DISTINCT note_id)
    INTO total_notes
   FROM notes
   WHERE insert_time > CURRENT_TIMESTAMP - INTERVAL '1 hour'
    AND created_at < CURRENT_TIMESTAMP - INTERVAL '30 minutes';
   
   -- Calculate gap percentage
   IF total_notes > 0 THEN
    gap_percentage := (notes_without_comments::DECIMAL / total_notes::DECIMAL * 100);
   ELSE
    gap_percentage := 0;
   END IF;
  END IF;
  
  -- Log gap status
  IF notes_without_comments > 0 THEN
   -- Get list of note_ids without comments (JSON array)
   -- Only check notes inserted in the last hour that are old enough to have comments
   SELECT json_agg(note_id ORDER BY note_id)
    INTO notes_without_comments_json
   FROM (
    SELECT DISTINCT n.note_id
    FROM notes n
    LEFT JOIN note_comments nc ON nc.note_id = n.note_id
    WHERE n.insert_time > CURRENT_TIMESTAMP - INTERVAL '1 hour'  -- Check only recently inserted notes
      AND n.created_at < CURRENT_TIMESTAMP - INTERVAL '30 minutes'  -- Only check notes old enough to have comments
      AND nc.note_id IS NULL
    ORDER BY n.note_id
   ) t;
   
   -- Insert into data_gaps table
   INSERT INTO data_gaps (
    gap_type,
    gap_count,
    total_count,
    gap_percentage,
    notes_without_comments,
    error_details,
    processed
   ) VALUES (
    'notes_without_comments',
    notes_without_comments,
    total_notes,
    gap_percentage,
    notes_without_comments_json,
    'Notes were inserted but their comments failed to insert',
    FALSE
   );
   
   INSERT INTO logs (message) VALUES ('WARNING: Found ' || 
    notes_without_comments || ' notes without comments (' || 
    gap_percentage::INTEGER || '% of total)');
   INSERT INTO logs (message) VALUES ('WARNING: Gap details logged in data_gaps table');
  END IF;
  
  -- Only proceed if integrity check passed
  IF NOT integrity_check_passed THEN
   RAISE NOTICE 'Skipping timestamp update due to integrity check failure';
   INSERT INTO logs (message) VALUES ('Timestamp update SKIPPED - integrity check failed');
   RETURN;
  END IF;
  
  -- If more than 5% of notes lack comments, don't update timestamp
  IF notes_without_comments > (total_notes * 0.05) THEN
   RAISE NOTICE 'Too many notes without comments (%%%). Not updating timestamp.', 
    gap_percentage::INTEGER;
   INSERT INTO logs (message) VALUES ('Timestamp update SKIPPED - too many gaps (' || 
    gap_percentage::INTEGER || '%)');
   RETURN;
  END IF;
  
  -- Takes the max value among: most recent open note, closed note, comment.
  SELECT /* Notes-processAPI */ MAX(TIMESTAMP)
    INTO new_last_update
  FROM (
   SELECT /* Notes-processAPI */ MAX(created_at) TIMESTAMP
   FROM notes
   UNION
   SELECT /* Notes-processAPI */ MAX(closed_at) TIMESTAMP
   FROM notes
   UNION
   SELECT /* Notes-processAPI */ MAX(created_at) TIMESTAMP
   FROM note_comments
  ) T;
  
  -- Only update if we have a valid timestamp
  -- Use UPSERT with ON CONFLICT since table always has id column
  IF (new_last_update IS NOT NULL) THEN
   INSERT INTO max_note_timestamp (id, timestamp)
   VALUES (1, new_last_update)
   ON CONFLICT (id) DO UPDATE SET timestamp = EXCLUDED.timestamp;
   
   INSERT INTO logs (message) VALUES ('Timestamp updated to: ' || new_last_update);
  ELSE
   -- If no valid timestamp found, keep the current value
   RAISE NOTICE 'No valid timestamp found, keeping current value';
   INSERT INTO logs (message) VALUES ('No valid timestamp found, keeping current value');
  END IF;
 END;
$$;
SELECT /* Notes-processAPI */ timestamp, 'newLastUpdate' AS key
FROM max_note_timestamp;
