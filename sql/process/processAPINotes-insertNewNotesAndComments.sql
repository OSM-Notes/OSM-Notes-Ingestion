-- Bulk notes and notes comments insertion.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-10-25
  
SELECT CURRENT_TIMESTAMP AS Processing, COUNT(1) Qty,
 'current notes - before' as Text
FROM notes;

DO
$$
 DECLARE
  r RECORD;
  m_closed_time VARCHAR(100);
  m_lastupdate TIMESTAMP;
 BEGIN
  SELECT timestamp INTO m_lastupdate
   FROM max_note_timestamp;

  FOR r IN
   SELECT note_id, latitude, longitude, created_at, closed_at, status
   FROM notes_api
   ORDER BY created_at
  LOOP
   m_closed_time := QUOTE_NULLABLE(r.closed_at);

   INSERT INTO logs (message) VALUES ('Note:' || r.note_id || ',created:'
    || r.created_at || ',last:' || m_lastupdate || ',closed:'
    || m_closed_time);

   EXECUTE 'CALL insert_note (' || r.note_id || ', ' || r.latitude || ', '
     || r.longitude || ', '
     || 'TO_TIMESTAMP(''' || r.created_at
     || ''', ''YYYY-MM-DD HH24:MI:SS''), '
     || ')';
   INSERT INTO logs (message) VALUES ('Inserted');
  END LOOP;
  COMMIT;
 END;
$$;

SELECT CURRENT_TIMESTAMP AS Processing, 'Statistics on notes' as Text;
ANALYZE notes;

SELECT CURRENT_TIMESTAMP AS Processing, COUNT(1) AS Qty,
 'current notes - after' as Text
FROM notes;

SELECT CURRENT_TIMESTAMP AS Processing, COUNT(1) AS Qty,
 'current comments - before' as Text
FROM note_comments;

DO
$$
 DECLARE
  r RECORD;
  m_created_time VARCHAR(100);
  m_lastupdate TIMESTAMP;
 BEGIN
  SELECT timestamp INTO m_lastupdate
   FROM max_note_timestamp;
  FOR r IN
   SELECT note_id, event, created_at, id_user, username
   FROM note_comments_api
   ORDER BY id
  LOOP
   IF (r.created_at <= m_lastupdate) THEN
    INSERT INTO logs (message) VALUES ('Comment:' || r.note_id || ',created:'
     || r.created_at || ',last:' || m_lastupdate || ',event:' || r.event);
    -- Rejects all comments before the latest processed.
    INSERT INTO logs (message) VALUES ('Skipped');
    CONTINUE;
   END IF;

   IF (r.id_user IS NOT NULL) THEN
    EXECUTE 'CALL insert_note_comment (' || r.note_id || ', '
      || '''' || r.event || '''::note_event_enum, '
      || 'TO_TIMESTAMP(''' || r.created_at
      || ''', ''YYYY-MM-DD HH24:MI:SS''), '
      || r.id_user || ', '
      || QUOTE_NULLABLE(r.username) || ')';
   ELSE
    EXECUTE 'CALL insert_note_comment (' || r.note_id || ', '
      || '''' || r.event || '''::note_event_enum, '
      || 'TO_TIMESTAMP(''' || r.created_at
      || ''', ''YYYY-MM-DD HH24:MI:SS''), '
      || 'NULL, '
      || QUOTE_NULLABLE(r.username) || ')';
   END IF;
   INSERT INTO logs (message) VALUES ('Inserted');
  END LOOP;
  COMMIT;
 END;
$$;

SELECT CURRENT_TIMESTAMP AS Processing, 'Statistics on comments' as Text;
ANALYZE note_comments;
SELECT CURRENT_TIMESTAMP AS Processing, COUNT(1) AS Qty,
 'current comments - after' as Qty
FROM note_comments;
