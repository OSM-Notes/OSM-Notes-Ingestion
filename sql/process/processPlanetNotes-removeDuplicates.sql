-- Remove duplicates for notes and note comments, when syncing from the Planet.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-10-25
  
SELECT CURRENT_TIMESTAMP AS Processing, 'Counting notes sync' AS Text;
SELECT CURRENT_TIMESTAMP AS Processing, COUNT(1) AS Qty, 'Sync notes' AS Text
  FROM notes_sync;
SELECT CURRENT_TIMESTAMP AS Processing,
  'Deleting duplicates notes sync' AS Text;

DROP TABLE IF EXISTS notes_sync_no_duplicates;
CREATE TABLE notes_sync_no_duplicates AS
  SELECT
   note_id,
   latitude,
   longitude,
   created_at,
   status,
   closed_at,
   id_country
  FROM notes_sync WHERE note_id IN (
    SELECT note_id FROM notes_sync s
    EXCEPT 
    SELECT note_id FROM notes);

DROP TABLE notes_sync;
ALTER TABLE notes_sync_no_duplicates RENAME TO notes_sync;
SELECT CURRENT_TIMESTAMP AS Processing, 'Statistics on notes sync' as Text;

ANALYZE notes_sync;

SELECT CURRENT_TIMESTAMP AS Processing,
  'Counting notes sync different' as Text;
SELECT COUNT(1) AS Qty, 'Sync notes no duplicates' AS Text
 FROM notes_sync;

SELECT CURRENT_TIMESTAMP AS Processing, 'Inserting sync note' AS Text;
DO
$$
DECLARE
 r RECORD;
 closed_time VARCHAR(100);
 qty INT;
 count INT;
BEGIN
 SELECT COUNT(1) INTO qty
 FROM notes;
 IF (qty = 0) THEN
  INSERT INTO notes (
    note_id, latitude, longitude, created_at, status, closed_at, id_country
    ) SELECT
    note_id, latitude, longitude, created_at, status, closed_at, id_country
    FROM notes_sync;
 ELSE
  count := 0;
  FOR r IN
   SELECT note_id, latitude, longitude, created_at, closed_at, status
   FROM notes_sync
  LOOP
   closed_time := 'TO_TIMESTAMP(''' || r.closed_at
     || ''', ''YYYY-MM-DD HH24:MI:SS'')';
   EXECUTE 'CALL insert_note (' || r.note_id || ', ' || r.latitude || ', '
     || r.longitude || ', '
     || 'TO_TIMESTAMP(''' || r.created_at || ''', ''YYYY-MM-DD HH24:MI:SS''), '
     || COALESCE (closed_time, 'NULL')
     || ')';
  END LOOP;
  IF (count % 1000 = 0) THEN
   COMMIT;
  END IF;
  count := count + 1;
 END IF;
END;
$$;

SELECT CURRENT_TIMESTAMP AS Processing, 'Statistics on notes' as Text;
ANALYZE notes;
SELECT CURRENT_TIMESTAMP AS Processing, 'Counting comments sync' as Text;
SELECT CURRENT_TIMESTAMP AS Processing, COUNT(1), 'Sync comments' AS Text
  FROM note_comments_sync;

SELECT CURRENT_TIMESTAMP AS Processing,
  'Deleting duplicates comments sync' as Text;
DROP TABLE IF EXISTS note_comments_sync_no_duplicates;
CREATE TABLE note_comments_sync_no_duplicates AS
  SELECT
   note_id,
   event,
   created_at,
   id_user,
   username
  FROM note_comments_sync
  WHERE note_id IN (
    SELECT note_id FROM note_comments_sync s
    EXCEPT 
    SELECT note_id FROM note_comments);

DROP TABLE note_comments_sync;
ALTER TABLE note_comments_sync_no_duplicates RENAME TO note_comments_sync;
SELECT CURRENT_TIMESTAMP AS Processing, 'Statistics on comments sync' as Text;
ANALYZE note_comments_sync;
SELECT CURRENT_TIMESTAMP AS Processing,
  'Counting comments sync different' as Text;
SELECT CURRENT_TIMESTAMP AS Processing, COUNT(1) AS Qty,
  'Sync comments no duplicates' AS Text
  FROM note_comments_sync;

SELECT CURRENT_TIMESTAMP AS Processing, 'Inserting sync comments' AS Text;
DO
$$
DECLARE
 r RECORD;
 created_time VARCHAR(100);
 qty INT;
BEGIN
 SELECT COUNT(1) INTO qty
 FROM note_comments;
 IF (qty = 0) THEN
  INSERT INTO users (
   user_id, username
   ) SELECT
   id_user, username
   FROM note_comments_sync
   WHERE id_user IS NOT NULL
   GROUP BY id_user, username;
   
  INSERT INTO note_comments (
   note_id, event, created_at, id_user
   ) SELECT 
   note_id, event, created_at, id_user
   FROM note_comments_sync;
 ELSE
  FOR r IN
   SELECT note_id, event, created_at, id_user, username
   FROM note_comments_sync
  LOOP
   created_time := 'TO_TIMESTAMP(''' || r.created_at
     || ''', ''YYYY-MM-DD HH24:MI:SS'')';
   EXECUTE 'CALL insert_note_comment (' || r.note_id || ', '
     || '''' || r.event || '''::note_event_enum, '
     || COALESCE(created_time, 'NULL') || ', '
     || COALESCE(r.id_user || '', 'NULL') || ', '
     || QUOTE_NULLABLE(r.username) || ')';
  END LOOP;
 END IF;
END
$$;

SELECT CURRENT_TIMESTAMP AS Processing, 'Statistics on comments' as Text;
ANALYZE note_comments;