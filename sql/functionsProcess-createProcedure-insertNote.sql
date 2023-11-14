-- Procedure to insert a note.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-10-25

CREATE OR REPLACE PROCEDURE insert_note (
  m_note_id INTEGER,
  m_latitude DECIMAL,
  m_longitude DECIMAL,
  m_created_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
AS $proc$
 DECLARE
  id_country INTEGER;
  qty INTEGER;
 BEGIN
  SELECT COUNT(1)
   INTO qty
  FROM notes
  WHERE note_id = m_note_id;

  IF (qty = 0) THEN
   INSERT INTO logs (message) VALUES ('Inserting note: ' || m_note_id);
   id_country := get_country(m_longitude, m_latitude, m_note_id);

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
    id_country
   ) ON CONFLICT DO NOTHING;
  ELSE
   INSERT INTO logs (message) VALUES ('Note is already inserted: ' || m_note_id);
   id_country := get_country(m_longitude, m_latitude, m_note_id);
  END IF;
 END
$proc$
