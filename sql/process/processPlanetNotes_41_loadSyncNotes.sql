-- Loads notes into the sync tables.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-12-08

TRUNCATE TABLE notes_sync;
SELECT /* Notes-processPlanet */ CURRENT_TIMESTAMP AS Processing,
 'Uploading sync notes' AS Text;
COPY notes_sync (note_id, latitude, longitude, created_at, closed_at, status)
FROM '${OUTPUT_NOTES_FILE}' csv;
SELECT /* Notes-processPlanet */ CURRENT_TIMESTAMP AS Processing,
 'Statistics on notes sync' AS Text;
ANALYZE notes_sync;
SELECT /* Notes-processPlanet */ CURRENT_TIMESTAMP AS Processing,
 'Counting sync notes' AS Text;
SELECT /* Notes-processPlanet */ CURRENT_TIMESTAMP AS Processing,
 COUNT(1) AS Qty,
  'Uploaded sync notes' AS Text
FROM notes_sync;

TRUNCATE TABLE note_comments_sync;
SELECT /* Notes-processPlanet */ CURRENT_TIMESTAMP AS Processing,
 'Uploading sync comments' AS Text;
COPY note_comments_sync(note_id, event, created_at, id_user, username)
FROM '${OUTPUT_NOTE_COMMENTS_FILE}' csv;
SELECT /* Notes-processPlanet */ CURRENT_TIMESTAMP AS Processing,
 'Statistics on comments sync' AS Text;
ANALYZE note_comments_sync;
SELECT /* Notes-processPlanet */ CURRENT_TIMESTAMP AS Processing,
 'Counting sync comments' AS Text;
SELECT /* Notes-processPlanet */ CURRENT_TIMESTAMP AS Processing,
 COUNT(1) AS Qty, 'Uploaded sync comments' AS Text
FROM note_comments_sync;

DO /* Notes-processPlanet-assignSequence-sync */
$$
DECLARE
  m_current_note_id INTEGER;
  m_previous_note_id INTEGER;
  m_sequence_value INTEGER;
  m_rec_note_comment_sync RECORD;
  m_note_comments_sync_cursor CURSOR  FOR
   SELECT /* Notes-processPlanet */ note_id
   FROM note_comments_sync
   ORDER BY note_id, id
   FOR UPDATE;

 BEGIN
  OPEN m_note_comments_sync_cursor;

  LOOP
   FETCH m_note_comments_sync_cursor INTO m_rec_note_comment_sync;
   -- Exit when no more rows to fetch.
   EXIT WHEN NOT FOUND;

   m_current_note_id := m_rec_note_comment_sync.note_id;
   IF (m_previous_note_id = m_current_note_id) THEN
    m_sequence_value := m_sequence_value + 1;
   ELSE
    m_sequence_value := 1;
    m_previous_note_id := m_current_note_id;
   END IF;

   UPDATE note_comments_sync
    SET sequence_action = m_sequence_value
    WHERE CURRENT OF m_note_comments_sync_cursor;
  END LOOP;

  CLOSE m_note_comments_sync_cursor;

END
$$;
