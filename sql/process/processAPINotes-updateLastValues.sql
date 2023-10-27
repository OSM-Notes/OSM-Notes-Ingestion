-- Refreshes the last value stored in the database.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-10-25
  
  SELECT timestamp FROM max_note_timestamp;
  DO
  $$
   DECLARE
    last_update TIMESTAMP;
    new_last_update TIMESTAMP;
   BEGIN
    SELECT MAX(TIMESTAMP)
      INTO new_last_update
    FROM (
     SELECT MAX(created_at) TIMESTAMP
     FROM notes
     UNION
     SELECT MAX(closed_at) TIMESTAMP
     FROM notes
     UNION
     SELECT MAX(created_at) TIMESTAMP
     FROM note_comments
    ) T;

    UPDATE max_note_timestamp
     SET timestamp = new_last_update;
   END;
  $$;
  SELECT timestamp, 'newLastUpdate' AS key
  FROM max_note_timestamp;
