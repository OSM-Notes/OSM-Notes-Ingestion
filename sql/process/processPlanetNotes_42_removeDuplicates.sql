-- Remove duplicates for notes and note comments, when syncing from the Planet.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2024-02-16

SELECT /* Notes-processPlanet */ CURRENT_TIMESTAMP AS Processing,
  'Counting notes sync' AS Text;
SELECT /* Notes-processPlanet */ CURRENT_TIMESTAMP AS Processing,
  COUNT(1) AS Qty, 'Sync notes' AS Text
  FROM notes_sync;
SELECT /* Notes-processPlanet */ CURRENT_TIMESTAMP AS Processing,
  'Deleting duplicates notes sync' AS Text;

DROP TABLE IF EXISTS notes_sync_no_duplicates;
CREATE TABLE notes_sync_no_duplicates AS
  SELECT /* Notes-processPlanet */
   note_id,
   latitude,
   longitude,
   created_at,
   status,
   closed_at,
   id_country
  FROM notes_sync WHERE note_id IN (
    SELECT /* Notes-processPlanet */ note_id
    FROM notes_sync s
    EXCEPT
    SELECT /* Notes-processPlanet */ note_id
    FROM notes
  );
COMMENT ON TABLE notes_sync_no_duplicates IS
  'Temporal table that stores the notes to insert';
COMMENT ON COLUMN notes_sync_no_duplicates.note_id IS 'OSM note id';
COMMENT ON COLUMN notes_sync_no_duplicates.latitude IS 'Latitude';
COMMENT ON COLUMN notes_sync_no_duplicates.longitude IS 'Longitude';
COMMENT ON COLUMN notes_sync_no_duplicates.created_at IS
  'Timestamp of the creation of the note';
COMMENT ON COLUMN notes_sync_no_duplicates.status IS
  'Current status of the note (opened, closed; hidden is not possible)';
COMMENT ON COLUMN notes_sync_no_duplicates.closed_at IS
  'Timestamp when the note was closed';
COMMENT ON COLUMN notes_sync_no_duplicates.id_country IS
  'Country id where the note is located';

DROP TABLE IF EXISTS notes_sync;
ALTER TABLE notes_sync_no_duplicates RENAME TO notes_sync;
SELECT /* Notes-processPlanet */ CURRENT_TIMESTAMP AS Processing,
  'Statistics on notes sync' AS Text;

ANALYZE notes_sync;

SELECT /* Notes-processPlanet */ CURRENT_TIMESTAMP AS Processing,
  'Counting notes sync different' AS Text;
SELECT /* Notes-processPlanet */ COUNT(1) AS Qty,
  'Sync notes no duplicates' AS Text
FROM notes_sync;

SELECT /* Notes-processPlanet */ CURRENT_TIMESTAMP AS Processing,
  'Inserting sync note' AS Text;
DO /* Notes-processPlanet-insertNotes */
$$
DECLARE
 r RECORD;
 m_qty INT;
BEGIN
 SELECT /* Notes-processPlanet */ COUNT(1)
  INTO m_qty
 FROM properties
 WHERE key = 'initialLoadNotes' AND value = 'true';
 IF (m_qty = 1) THEN
  RAISE NOTICE 'Inserting bulk notes.';
  -- Load all historical notes as open.
  INSERT INTO notes (
    note_id, latitude, longitude, created_at, status, closed_at, id_country
   )
   SELECT /* Notes-processPlanet */
     note_id, latitude, longitude, created_at, 'open', null, id_country
   FROM notes_sync
   ORDER BY note_id;

  -- Remove the trigger that register the log.
  DROP TRIGGER IF EXISTS log_insert_note ON notes;
  DROP FUNCTION IF EXISTS log_insert_note;

  -- Removes the initial property to load in bulk.
  DELETE FROM properties
  WHERE key = 'initialLoadNotes' AND value = 'true';
 ELSE
  RAISE NOTICE 'Inserting notes.';
  FOR r IN
   SELECT /* Notes-processPlanet */ note_id, latitude, longitude, created_at,
    closed_at, status
   FROM notes_sync
   ORDER BY note_id
  LOOP
   EXECUTE 'CALL insert_note (' || r.note_id || ', ' || r.latitude || ', '
     || r.longitude || ', ' || 'TO_TIMESTAMP(''' || r.created_at || ''', '
     ||'''YYYY-MM-DD HH24:MI:SS'')' || ', $PROCESS_ID' || ')';
  END LOOP;
  COMMIT;
 END IF;
END;
$$;

SELECT /* Notes-processPlanet */ CURRENT_TIMESTAMP AS Processing,
  'Statistics on notes' AS Text;
ANALYZE notes;
SELECT /* Notes-processPlanet */ CURRENT_TIMESTAMP AS Processing,
  'Counting comments sync' AS Text;
SELECT /* Notes-processPlanet */ CURRENT_TIMESTAMP AS Processing,
  COUNT(1) AS Qty, 'Sync comments' AS Text
FROM note_comments_sync;

SELECT /* Notes-processPlanet */ CURRENT_TIMESTAMP AS Processing,
  'Deleting duplicates comments sync' AS Text;
DROP TABLE IF EXISTS note_comments_sync_no_duplicates;
CREATE TABLE note_comments_sync_no_duplicates AS
  SELECT /* Notes-processPlanet */
   note_id,
   sequence_action,
   event,
   created_at,
   id_user,
   username
  FROM note_comments_sync
  WHERE note_id IN (
    SELECT /* Notes-processPlanet */ note_id
    FROM note_comments_sync s
    EXCEPT
    SELECT /* Notes-processPlanet */ note_id
    FROM note_comments
  )
  ORDER BY note_id, sequence_action;
COMMENT ON TABLE note_comments_sync_no_duplicates IS
  'Temporal table with the comments to insert';
COMMENT ON COLUMN note_comments_sync_no_duplicates.note_id IS
  'OSM Note Id associated to this comment';
COMMENT ON COLUMN note_comments_sync_no_duplicates.sequence_action IS
  'Comment sequence generated from this tool';
COMMENT ON COLUMN note_comments_sync_no_duplicates.event IS
  'Type of action was performed on the note';
COMMENT ON COLUMN note_comments_sync_no_duplicates.created_at IS
  'Timestamps when the comment/action was done';
COMMENT ON COLUMN note_comments_sync_no_duplicates.id_user IS
  'OSM id of the user who performed the action';
COMMENT ON COLUMN note_comments_sync_no_duplicates.username IS
  'OSM username at the time of this action';

DROP TABLE IF EXISTS note_comments_sync;
ALTER TABLE note_comments_sync_no_duplicates RENAME TO note_comments_sync;
SELECT /* Notes-processPlanet */ CURRENT_TIMESTAMP AS Processing,
  'Statistics on comments sync' AS Text;
ANALYZE note_comments_sync;
SELECT /* Notes-processPlanet */ CURRENT_TIMESTAMP AS Processing,
  'Counting comments sync different' AS Text;
SELECT /* Notes-processPlanet */ CURRENT_TIMESTAMP AS Processing,
  COUNT(1) AS Qty, 'Sync comments no duplicates' AS Text
  FROM note_comments_sync;

SELECT /* Notes-processPlanet */ CURRENT_TIMESTAMP AS Processing,
  'Inserting sync comments' AS Text;
DO /* Notes-processPlanet-insertComments */
$$
DECLARE
 r RECORD;
 m_created_time VARCHAR(100);
 m_qty INT;
BEGIN
 SELECT /* Notes-processPlanet */ COUNT(1)
  INTO m_qty
 FROM properties
 WHERE key = 'initialLoadComments' AND value = 'true';
 IF (m_qty = 1) THEN
  RAISE NOTICE 'Inserting bulk users.';

  INSERT INTO users (
    user_id, username
   )
   SELECT /* Notes-processPlanet */
     id_user, username
   FROM note_comments_sync
   WHERE id_user IS NOT NULL
   GROUP BY id_user, username;

  RAISE NOTICE 'Inserting bulk comments.';

  INSERT INTO note_comments (
    note_id, event, created_at, id_user
   )
   SELECT /* Notes-processPlanet */
    note_id, event, created_at, id_user
   FROM note_comments_sync
   ORDER BY created_at, sequence_action;

  -- Removes the initial property to load in bulk.
  DELETE FROM properties
  WHERE key = 'initialLoadComments' AND value = 'true';
 ELSE
  RAISE NOTICE 'Inserting comments.';
  FOR r IN
   SELECT /* Notes-processPlanet */
    note_id, event, created_at, id_user, username
   FROM note_comments_sync
   ORDER BY created_at
  LOOP
   m_created_time := 'TO_TIMESTAMP(''' || r.created_at
     || ''', ''YYYY-MM-DD HH24:MI:SS'')';
   EXECUTE 'CALL insert_note_comment (' || r.note_id || ', '
     || '''' || r.event || '''::note_event_enum, '
     || COALESCE(m_created_time, 'NULL') || ', '
     || COALESCE(r.id_user || '', 'NULL') || ', '
     || QUOTE_NULLABLE(r.username) || ', $PROCESS_ID' || ')';
  END LOOP;
  COMMIT;
 END IF;
END
$$;

SELECT /* Notes-processPlanet */ CURRENT_TIMESTAMP AS Processing,
 'Statistics on comments' AS Text;
ANALYZE note_comments;

-- TODO Perform checks
-- Toda nota tiene acci'on inicial como open
-- Toda nota cerrada tiene acci'on final close, tiene al menos 2 comentarios

