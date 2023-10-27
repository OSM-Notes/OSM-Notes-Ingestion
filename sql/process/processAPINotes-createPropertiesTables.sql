-- Creates the max note timestamp table.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-10-25
  
  DO
  $$
  DECLARE
   last_update TIMESTAMP;
   new_last_update TIMESTAMP;
   qty INT;
  BEGIN
   SELECT COUNT(TABLE_NAME) INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA LIKE 'public'
   AND TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_NAME = 'max_note_timestamp'
   ;

   IF (qty = 0) THEN
    EXECUTE 'CREATE TABLE max_note_timestamp ('
      || 'timestamp TIMESTAMP NOT NULL'
      || ')';
   END IF;

   SELECT MAX(TIMESTAMP)
     INTO new_last_update
   FROM (
    SELECT MAX(created_at) AS TIMESTAMP
    FROM notes
    UNION
    SELECT MAX(closed_at) AS TIMESTAMP
    FROM notes
    UNION
    SELECT MAX(created_at) AS TIMESTAMP
    FROM note_comments
   ) T;

   IF (new_last_update IS NOT NULL) THEN
    SELECT timestamp INTO last_update
      FROM max_note_timestamp;

    IF (last_update IS NULL) THEN
     INSERT INTO max_note_timestamp (timestamp) VALUES (new_last_update);
    ELSE
     UPDATE max_note_timestamp
       SET timestamp = new_last_update;
    END IF;
   ELSE
    RAISE EXCEPTION 'Notes are not yet on the database';
   END IF;
  END;
  $$;
  SELECT timestamp, 'oldLastUpdate' AS key
  FROM max_note_timestamp;
