-- Procedure to insert a note comment.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2024-02-18

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
  m_process_id_db INTEGER;
 BEGIN
  SELECT value
    INTO m_process_id_db
  FROM properties
  WHERE key = 'lock';
  IF (m_process_id_db IS NULL) THEN
   RAISE EXCEPTION 'This call does not have a lock.';
  ELSIF (m_process_id_bash <> m_process_id_db) THEN
   RAISE EXCEPTION 'The process that holds the lock (%) is different from the current one (%).',
     m_process_id_db, m_process_id_bash;
  END IF;

  INSERT INTO logs (message) VALUES (m_note_id || ' - Inserting comment - '
    || m_event || '.');

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

  INSERT INTO note_comments (
   id,
   note_id,
   event,
   created_at,
   id_user
  ) VALUES (
   nextval('note_comments_id_seq'),
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
