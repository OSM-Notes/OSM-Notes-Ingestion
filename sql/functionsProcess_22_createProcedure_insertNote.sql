-- Insert a new note into the database with country assignment
-- Inserts note as "opened" status (updated to "closed" when closing comment is processed)
--
-- Parameters:
--   m_note_id INTEGER: Note ID [requerido]
--   m_latitude DECIMAL: Note latitude [requerido]
--   m_longitude DECIMAL: Note longitude [requerido]
--   m_created_at TIMESTAMP WITH TIME ZONE: Note creation timestamp [requerido]
--   m_process_id_bash INTEGER: Process ID for lock validation [requerido]
--
-- Returns: None (procedure, not function)
--
-- Exceptions:
--   RAISE EXCEPTION 'This call does not have a lock': No process lock found
--   RAISE EXCEPTION 'The process that holds the lock...': Lock belongs to different process
--
-- Strategy: See docs/Process_API.md#note-insertion for complete workflow
--   1. Validates process lock (prevents concurrent execution)
--   2. Checks if note already exists
--   3. Automatically assigns country using get_country()
--   4. Inserts note as "opened" (status updated when closing comment is processed)
--
-- Performance: See docs/Process_API.md#performance
--   - Uses get_country() for efficient country assignment
--   - ON CONFLICT DO NOTHING prevents duplicate insertions
--
-- Examples:
--   CALL insert_note(12345, 40.7128, -74.006, NOW(), 123);
--
-- Related: docs/Process_API.md (complete API processing workflow)
-- Related Functions: get_country() (called for country assignment)

CREATE OR REPLACE PROCEDURE insert_note (
  m_note_id INTEGER,
  m_latitude DECIMAL,
  m_longitude DECIMAL,
  m_created_at TIMESTAMP WITH TIME ZONE,
  m_process_id_bash INTEGER
)
LANGUAGE plpgsql
AS $proc$
 DECLARE
  m_id_country INTEGER;
  m_qty INTEGER;
  m_process_id_db VARCHAR(32);
  m_process_id_db_pid INTEGER;
 BEGIN
  -- Check the DB lock to validate it is from the same process.
  -- Note: lock is stored as VARCHAR (e.g., "130030_1762952513_24253")
  -- We need to extract the PID (first part before underscore) for comparison
  SELECT /* Notes-base */ value
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

  SELECT /* Notes-base */ COUNT(1)
   INTO m_qty
  FROM notes
  WHERE note_id = m_note_id;

  IF (m_qty = 0) THEN
   INSERT INTO logs (message) VALUES (m_note_id || ' - Inserting note.');
   m_id_country := get_country(m_longitude, m_latitude, m_note_id);

   INSERT INTO notes (
    note_id,
    latitude,
    longitude,
    created_at,
    status,
    id_country
   ) VALUES (
    m_note_id,
    m_latitude,
    m_longitude,
    m_created_at,
    'open',
    m_id_country
   ) ON CONFLICT DO NOTHING;
  ELSE
   INSERT INTO logs (message) VALUES (m_note_id || 'Note is already inserted.');
   m_id_country := get_country(m_longitude, m_latitude, m_note_id);
  END IF;
 END
$proc$
;
COMMENT ON PROCEDURE insert_note IS
  'Inserts a note in as opened the database, validating it does not already exist';