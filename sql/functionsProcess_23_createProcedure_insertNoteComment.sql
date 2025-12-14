-- Procedure to insert a note comment.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-11-24

CREATE OR REPLACE PROCEDURE insert_note_comment (
  m_note_id INTEGER,
  m_event note_event_enum,
  m_created_at TIMESTAMP WITH TIME ZONE,
  m_id_user INTEGER,
  m_username VARCHAR(256),
  m_process_id_bash INTEGER,
  m_sequence_action INTEGER DEFAULT NULL
)
LANGUAGE plpgsql
AS $proc$
 DECLARE
  m_process_id_db VARCHAR(32);
  m_process_id_db_pid INTEGER;
  m_existing_count INTEGER;
 BEGIN
  -- Check the DB lock to validate it is from the same process.
  -- Note: lock is stored as VARCHAR (e.g., "130030_1762952513_24253")
  -- We need to extract the PID (first part before underscore) for comparison
  SELECT value
    INTO m_process_id_db
  FROM properties
  WHERE key = 'lock';
  IF (m_process_id_db IS NULL) THEN
   RAISE EXCEPTION 'This call does not have a lock.';
  END IF;
  
  -- Extract PID from lock (first part before underscore) and convert to INTEGER
  m_process_id_db_pid := SPLIT_PART(m_process_id_db, '_', 1)::INTEGER;
  
  IF (m_process_id_bash <> m_process_id_db_pid) THEN
   RAISE EXCEPTION 'The process that holds the lock (%) is different from the current one (%).',
     m_process_id_db, m_process_id_bash;
  END IF;

  -- Check if comment already exists (by note_id, event, and created_at)
  -- This prevents duplicate insertions when processing same notes multiple times
  SELECT COUNT(1)
    INTO m_existing_count
  FROM note_comments
  WHERE note_id = m_note_id
    AND event = m_event
    AND created_at = m_created_at;
  
  -- If comment already exists, skip insertion
  IF m_existing_count > 0 THEN
   INSERT INTO logs (message) VALUES (m_note_id || ' - Comment already exists, skipping insertion - '
     || m_event || '.');
   RETURN;
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

  -- Insert comment with exception handling for unique constraint violations
  -- The unique constraint is on (note_id, sequence_action) which is set by trigger
  -- If sequence_action is provided, use it; otherwise let trigger assign it
  BEGIN
   INSERT INTO note_comments (
    id,
    note_id,
    sequence_action,
    event,
    created_at,
    id_user
   ) VALUES (
    nextval('note_comments_id_seq'),
    m_note_id,
    m_sequence_action,  -- Use provided sequence_action or NULL (trigger will assign)
    m_event,
    m_created_at,
    m_id_user
   );
  EXCEPTION
   WHEN unique_violation THEN
    -- Comment with same (note_id, sequence_action) already exists
    INSERT INTO logs (message) VALUES (m_note_id || ' - Comment already exists (unique constraint), skipping - '
      || m_event || '.');
    RETURN;
  END;
 END
$proc$
;
COMMENT ON PROCEDURE insert_note_comment IS
  'Inserts a comment of a given note. It updates the note accordingly if closed';
