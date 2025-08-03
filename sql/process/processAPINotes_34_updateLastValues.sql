-- Refreshes the last value stored in the database. It calculates the max value
-- by taking the most recent open note, most recent closed note and most recent
-- comment.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-08-02

SELECT /* Notes-processAPI */ timestamp
FROM max_note_timestamp;
DO /* Notes-proessAPI-updateLastValues */
$$
 DECLARE
  last_update TIMESTAMP;
  new_last_update TIMESTAMP;
 BEGIN
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
  ELSE
   -- If no valid timestamp found, keep the current value
   RAISE NOTICE 'No valid timestamp found, keeping current value';
  END IF;
 END;
$$;
SELECT /* Notes-processAPI */ timestamp, 'newLastUpdate' AS key
FROM max_note_timestamp;
