-- Creates the max note timestamp table.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-12-08

DO /* Notes-processAPI-createLastUpdateTable */
$$
DECLARE
 last_update TIMESTAMP;
 new_last_update TIMESTAMP;
 qty INT;
BEGIN
 SELECT /* Notes-processAPI */ COUNT(TABLE_NAME)
  INTO qty
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

 -- Takes the max value among: most recent open note, closed note, comment.
 SELECT /* Notes-processAPI */ MAX(TIMESTAMP)
   INTO new_last_update
 FROM (
  SELECT /* Notes-processAPI */ MAX(created_at) AS TIMESTAMP
  FROM notes
  UNION
  SELECT /* Notes-processAPI */ MAX(closed_at) AS TIMESTAMP
  FROM notes
  UNION
  SELECT /* Notes-processAPI */ MAX(created_at) AS TIMESTAMP
  FROM note_comments
 ) T;

 IF (new_last_update IS NOT NULL) THEN
  SELECT /* Notes-processAPI */ timestamp
    INTO last_update
  FROM max_note_timestamp;

  IF (last_update IS NULL) THEN
   -- Inserting the first "Max" value.
   INSERT INTO max_note_timestamp (timestamp) VALUES (new_last_update);
  ELSE
   -- Updating the "Max" value.
   UPDATE max_note_timestamp
     SET timestamp = new_last_update;
  END IF;
 ELSE
  -- Tables are empty, insert a default timestamp
  INSERT INTO max_note_timestamp (timestamp) VALUES (CURRENT_TIMESTAMP)
   ON CONFLICT DO NOTHING;
 END IF;
END;
$$;
COMMENT ON TABLE max_note_timestamp IS
  'Timestamps of the max notes to reduce queries';
COMMENT ON COLUMN max_note_timestamp.timestamp IS
  'Timestamp of the last note inserted';
SELECT /* Notes-processAPI */ timestamp, 'oldLastUpdate' AS key
FROM max_note_timestamp;
