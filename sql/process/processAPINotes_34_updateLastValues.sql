-- Refreshes the last value stored in the database. It calculates the max value
-- by taking the most recent open note, most recent closed note and most recent
-- comment.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-10-22

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
  gap_percentage DECIMAL(5,2);
  notes_without_comments_json TEXT;
 BEGIN
  -- Check if integrity check passed
  integrity_check_passed := COALESCE(
   current_setting('app.integrity_check_passed', true)::BOOLEAN, 
   FALSE
  );
  
  -- Count notes without comments in recent data
  SELECT COUNT(DISTINCT n.note_id)
   INTO notes_without_comments
  FROM notes n
  LEFT JOIN note_comments nc ON nc.note_id = n.note_id
  WHERE n.created_at > (
    SELECT timestamp FROM max_note_timestamp
   ) - INTERVAL '1 day'
   AND nc.note_id IS NULL;
  
  -- Count total notes from last day
  SELECT COUNT(DISTINCT note_id)
   INTO total_notes
  FROM notes
  WHERE created_at > (
    SELECT timestamp FROM max_note_timestamp
   ) - INTERVAL '1 day';
  
  -- Calculate gap percentage
  IF total_notes > 0 THEN
   gap_percentage := (notes_without_comments::DECIMAL / total_notes::DECIMAL * 100);
  ELSE
   gap_percentage := 0;
  END IF;
  
  -- Log gap status
  IF notes_without_comments > 0 THEN
   -- Get list of note_ids without comments (JSON array)
   SELECT json_agg(note_id ORDER BY note_id)
    INTO notes_without_comments_json
   FROM (
    SELECT DISTINCT n.note_id
    FROM notes n
    LEFT JOIN note_comments nc ON nc.note_id = n.note_id
    WHERE n.created_at > (SELECT timestamp FROM max_note_timestamp) - INTERVAL '1 day'
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
   RAISE NOTICE 'Too many notes without comments (%%). Not updating timestamp.', 
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
  IF (new_last_update IS NOT NULL) THEN
   UPDATE max_note_timestamp
    SET timestamp = new_last_update;
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
