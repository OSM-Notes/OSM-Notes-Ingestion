-- Procedure to insert a note. Even if the current status of the note is closed,
-- the note is inserted as opened. Then, when the comment that closes the note
-- is processed, the note will be updated to closed.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2024-02-16

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

  SELECT /* Notes-base */ COUNT(1)
   INTO m_qty
  FROM notes
  WHERE note_id = m_note_id;

  IF (m_qty = 0) THEN
   INSERT INTO logs (message) VALUES ('Inserting note: ' || m_note_id);
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
   INSERT INTO logs (message) VALUES ('Note is already inserted: ' || m_note_id);
   m_id_country := get_country(m_longitude, m_latitude, m_note_id);
  END IF;
 END
$proc$
;
COMMENT ON PROCEDURE insert_note IS
  'Inserts a note in as opened the database, validating it does not already exist';
