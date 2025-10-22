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
 BEGIN
  -- Check if integrity check passed
  integrity_check_passed := COALESCE(
   current_setting('app.integrity_check_passed', true)::BOOLEAN, 
   FALSE
  );
  
  -- Only proceed if integrity check passed
  IF NOT integrity_check_passed THEN
   RAISE NOTICE 'Skipping timestamp update due to integrity check failure';
   INSERT INTO logs (message) VALUES ('Timestamp update SKIPPED - integrity check failed');
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
   -- Additional validation: ensure no gaps in recent data
   IF NOT EXISTS (
    SELECT 1 
    FROM notes n
    LEFT JOIN note_comments nc ON nc.note_id = n.note_id
    WHERE n.created_at > last_update 
      AND n.created_at <= new_last_update
      AND nc.note_id IS NULL
   ) THEN
    UPDATE max_note_timestamp
     SET timestamp = new_last_update;
    INSERT INTO logs (message) VALUES ('Timestamp updated to: ' || new_last_update);
   ELSE
    RAISE NOTICE 'Gap detected in recent data, not updating timestamp';
    INSERT INTO logs (message) VALUES ('Timestamp update BLOCKED - gap detected in recent data');
   END IF;
  ELSE
   -- If no valid timestamp found, keep the current value
   RAISE NOTICE 'No valid timestamp found, keeping current value';
   INSERT INTO logs (message) VALUES ('No valid timestamp found, keeping current value');
  END IF;
 END;
$$;
SELECT /* Notes-processAPI */ timestamp, 'newLastUpdate' AS key
FROM max_note_timestamp;
