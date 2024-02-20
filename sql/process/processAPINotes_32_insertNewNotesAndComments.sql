-- Bulk notes and notes comments insertion.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2024-02-19

SELECT /* Notes-processAPI */ CURRENT_TIMESTAMP AS Processing,
  COUNT(1) Qty, 'current notes - before' AS Text
FROM notes;

DO /* Notes-processAPI-insertNotes */
$$
 DECLARE
  r RECORD;
  m_closed_time VARCHAR(100);
  m_lastupdate TIMESTAMP;
  m_stmt VARCHAR(200);
 BEGIN
  SELECT /* Notes-processAPI */ timestamp
   INTO m_lastupdate
  FROM max_note_timestamp;

  FOR r IN
   SELECT /* Notes-processAPI */ note_id, latitude, longitude, created_at,
     closed_at, status
   FROM notes_api
   ORDER BY created_at
  LOOP
   m_closed_time := QUOTE_NULLABLE(r.closed_at);

   INSERT INTO logs (message) VALUES (r.note_id || ' - created:'
    || r.created_at || ',last:' || m_lastupdate || ',closed:'
    || m_closed_time || '.');

   m_stmt := 'CALL insert_note (' || r.note_id || ', ' || r.latitude || ', '
     || r.longitude || ', ' || 'TO_TIMESTAMP(''' || r.created_at
     || ''', ''YYYY-MM-DD HH24:MI:SS'')' || ', $PROCESS_ID' || ')';
   --RAISE NOTICE 'Note % (%) %.', r.note_id, m_stmt, m_lastupdate;
   EXECUTE m_stmt;
   INSERT INTO logs (message) VALUES (r.note_id || ' - Note inserted.');
  END LOOP;
 END;
$$;

SELECT /* Notes-processAPI */ CURRENT_TIMESTAMP AS Processing,
  'Statistics on notes' AS Text;
ANALYZE notes;

SELECT /* Notes-processAPI */ CURRENT_TIMESTAMP AS Processing,
  COUNT(1) AS Qty, 'current notes - after' AS Text
FROM notes;

SELECT /* Notes-processAPI */ CURRENT_TIMESTAMP AS Processing,
  COUNT(1) AS Qty, 'current comments - before' AS Text
FROM note_comments;

DO /* Notes-processAPI-insertComments */
$$
 DECLARE
  r RECORD;
  m_created_time VARCHAR(100);
  m_lastupdate TIMESTAMP;
  m_stmt VARCHAR(200);
 BEGIN
  SELECT /* Notes-processAPI */ timestamp
   INTO m_lastupdate
  FROM max_note_timestamp;

  FOR r IN
   SELECT /* Notes-processAPI */ note_id, event, created_at, id_user,
    username
   FROM note_comments_api
   ORDER BY created_at, sequence_action
  LOOP
   IF (r.created_at <= m_lastupdate) THEN
    INSERT INTO logs (message) VALUES (r.note_id || ' - Comment - created:'
     || r.created_at || ',last:' || m_lastupdate || ',event:' || r.event
     || '.');
    -- Rejects all comments before the latest processed.
    INSERT INTO logs (message) VALUES (r.note_id || ' - Comment skipped.');
    CONTINUE;
   END IF;

   IF (r.id_user IS NOT NULL) THEN
    m_stmt := 'CALL insert_note_comment (' || r.note_id || ', '
      || '''' || r.event || '''::note_event_enum, '
      || 'TO_TIMESTAMP(''' || r.created_at
      || ''', ''YYYY-MM-DD HH24:MI:SS''), '
      || r.id_user || ', '
      || QUOTE_NULLABLE(r.username) || ', $PROCESS_ID' || ')';
   ELSE
    m_stmt := 'CALL insert_note_comment (' || r.note_id || ', '
      || '''' || r.event || '''::note_event_enum, '
      || 'TO_TIMESTAMP(''' || r.created_at
      || ''', ''YYYY-MM-DD HH24:MI:SS''), '
      || 'NULL, '
      || QUOTE_NULLABLE(r.username) || ', $PROCESS_ID' || ')';
   END IF;
   RAISE NOTICE 'Comment % (%).', m_stmt, m_lastupdate;
   EXECUTE m_stmt;
   INSERT INTO logs (message) VALUES (r.note_id
     || ' - Comment for note inserted.');
  END LOOP;
 END;
$$;

SELECT /* Notes-processAPI */ CURRENT_TIMESTAMP AS Processing,
  'Statistics on comments' AS Text;
ANALYZE note_comments;
SELECT /* Notes-processAPI */ CURRENT_TIMESTAMP AS Processing,
  COUNT(1) AS Qty, 'current comments - after' AS Qty
FROM note_comments;
