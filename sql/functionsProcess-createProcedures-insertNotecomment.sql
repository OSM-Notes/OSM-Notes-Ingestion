-- Procedure to insert a note comment.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-10-25
  
 CREATE OR REPLACE PROCEDURE insert_note_comment (
   m_note_id INTEGER,
   m_event note_event_enum,
   m_created_at TIMESTAMP WITH TIME ZONE,
   m_id_user INTEGER,
   m_username VARCHAR(256)
 )
 LANGUAGE plpgsql
 AS $proc$
  BEGIN
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

    -- TODO Perform validation that the note is in open state.
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
   ) ON CONFLICT 
    DO NOTHING;

   IF (m_event = 'closed') THEN
    -- TODO Perform validation that the note is in open state.
    UPDATE notes
      SET status = 'close',
      closed_at = m_created_at
      WHERE note_id = m_note_id;
    INSERT INTO logs (message) VALUES ('Update to close note ' || m_note_id);
   ELSIF (m_event = 'reopened') THEN
    -- TODO Perform validation that the note is in close state.
    UPDATE notes
      SET status = 'open',
      closed_at = NULL
      WHERE note_id = m_note_id;
    INSERT INTO logs (message) VALUES ('Update to reopen note ' || m_note_id);
   --ELSE
   -- INSERT INTO logs (message) VALUES ('Another event ' || m_note_id || '-' || m_event);
   END IF;

   -- TODO Hacer algo en los conflictos, como registrar en otra tabla.
   -- TODO Insertar en otra tabla el usuario que hay que recalcular.
   -- TODO Insertar en otra tabla el país que hay que recalcular.
  END
 $proc$
