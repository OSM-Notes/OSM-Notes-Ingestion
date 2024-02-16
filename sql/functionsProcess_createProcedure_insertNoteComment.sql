-- Procedure to insert a note comment.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2024-02-16

CREATE OR REPLACE PROCEDURE insert_note_comment (
  m_note_id INTEGER,
  m_event note_event_enum,
  m_created_at TIMESTAMP WITH TIME ZONE,
  m_id_user INTEGER,
  m_username VARCHAR(256),
  m_process_id_bash INTEGER
)
LANGUAGE plpgsql
AS $proc$
 DECLARE
  m_status note_status_enum;
  m_process_id_db INTEGER;
 BEGIN
  SELECT value
    INTO m_process_id_db
  FROM properties
  WHERE key = 'lock';
  IF (m_process_id_bash = m_process_id_db) THEN
    RAISE EXCEPTION 'The process that holds the lock (%) is different from the current one (%)',
      m_process_id_db, m_process_id_bash;
  END IF;

  INSERT INTO logs (message) VALUES ('Inserting comment: ' || m_note_id || '-'
    || m_event);

  -- Insert a new username, or update the username to an existing userid.
  IF (m_id_user IS NOT NULL AND m_username IS NOT NULL) THEN
   INSERT INTO users (
    user_id,
    username
   ) VALUES (
    m_id_user,
    m_username
   ) ON CONFLICT (user_id) DO UPDATE
    SET username = EXCLUDED.username;
  END IF;

   -- Gets the current status of the note.
   -- The real status of the note could be closed, but it is inserted as open.
  SELECT /* Notes-base */ status
   INTO m_status
  FROM notes
  WHERE note_id = m_note_id;

  -- Possible comment actions depending the current note state.
  IF (m_status = 'open') THEN
   -- The note is currently open.

   IF (m_event = 'closed') THEN
    INSERT INTO logs (message) VALUES ('Update to close note ' || m_note_id);
    UPDATE notes
      SET status = 'close',
      closed_at = m_created_at
      WHERE note_id = m_note_id;
   ELSIF (m_event = 'reopened') THEN
    -- Invalid operation for an open note.
    INSERT INTO logs (message) VALUES ('Trying to reopen an opened note '
      || m_note_id || '-' || m_event);
    RAISE EXCEPTION 'Trying to reopen an opened note: % - % %', m_note_id,
      m_status, m_event;
   END IF;
  ELSE
   -- The note is currently closed.

   IF (m_event = 'reopened') THEN
    INSERT INTO logs (message) VALUES ('Update to reopen note ' || m_note_id);
    UPDATE notes
      SET status = 'open',
      closed_at = NULL
      WHERE note_id = m_note_id;
   ELSIF (m_event = 'closed') THEN
    -- Invalid operation for a closed note.
    INSERT INTO logs (message) VALUES ('Trying to close a closed note '
      || m_note_id || '-' || m_event);
    RAISE EXCEPTION 'Trying to close a closed note: % - % %', m_note_id,
      m_status, m_event;
   END IF;
  END IF;

  INSERT INTO note_comments (
   note_id,
   event,
   created_at,
   id_user
  ) VALUES (
   m_note_id,
   m_event,
   m_created_at,
   m_id_user
  );
 END
$proc$
;
COMMENT ON PROCEDURE insert_note_comment IS
  'Inserts a comment of a given note. It updates the note accordingly if closed';
