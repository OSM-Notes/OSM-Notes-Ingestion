-- Bulk notes and notes comments insertion.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-10-25
  
  SELECT CURRENT_TIMESTAMP, COUNT(1), 'current notes - before' as qty
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
    LOOP
     IF (r.created_at = m_lastupdate OR r.closed_at = m_lastupdate) THEN
      CONTINUE;
     END IF;
     m_closed_time := 'TO_TIMESTAMP(''' || r.closed_at
       || ''', ''YYYY-MM-DD HH24:MI:SS'')';
     EXECUTE 'CALL insert_note (' || r.note_id || ', ' || r.latitude || ', '
       || r.longitude || ', '
       || 'TO_TIMESTAMP(''' || r.created_at
       || ''', ''YYYY-MM-DD HH24:MI:SS''), '
       || COALESCE (m_closed_time, 'NULL') -- TODO || ','
       -- TODO || '''' || r.status || '''::note_status_enum'
       || ')';
    END LOOP;
   END;
  $$;
  SELECT CURRENT_TIMESTAMP, 'Statistics on notes' as text;
  ANALYZE notes;
  SELECT CURRENT_TIMESTAMP, COUNT(1), 'current notes - after' as qty
  FROM notes;

  SELECT CURRENT_TIMESTAMP, COUNT(1), 'current comments - before' as qty
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
    LOOP
     IF (r.created_at = m_lastupdate) THEN
      CONTINUE;
     END IF;
     EXECUTE 'CALL insert_note_comment (' || r.note_id || ', '
       || '''' || r.event || '''::note_event_enum, '
       || 'TO_TIMESTAMP(''' || r.created_at
       || ''', ''YYYY-MM-DD HH24:MI:SS''), '
       || COALESCE(r.id_user || '', 'NULL') || ', '
       || QUOTE_NULLABLE('''' || r.username || '''') || ')';
       -- TODO Quitar comillas en la funcion QUOTE_NULLABLE en todo el codigo.
    END LOOP;
   END;
  $$;
  SELECT CURRENT_TIMESTAMP, 'Statistics on comments' as text;
  ANALYZE note_comments;
  SELECT CURRENT_TIMESTAMP, COUNT(1), 'current comments - after' as qty
  FROM note_comments;
