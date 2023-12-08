-- Refreshes the last value stored in the database.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-12-08
  
SELECT /* Notes-processAPI */ timestamp
FROM max_note_timestamp;
DO /* Notes-proessAPI-updateLastValues */
$$
 DECLARE
  last_update TIMESTAMP;
  new_last_update TIMESTAMP;
 BEGIN
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
  UPDATE max_note_timestamp
   SET timestamp = new_last_update;
 END;
$$;
SELECT /* Notes-processAPI */ timestamp, 'newLastUpdate' AS key
FROM max_note_timestamp;
