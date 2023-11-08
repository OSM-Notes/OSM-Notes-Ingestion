-- Procedure to insert a note.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-10-25
  
 CREATE OR REPLACE PROCEDURE insert_note (
   m_note_id INTEGER,
   m_latitude DECIMAL,
   m_longitude DECIMAL,
   m_created_at TIMESTAMP WITH TIME ZONE,
   m_closed_at TIMESTAMP WITH TIME ZONE--,
   --TODO m_status note_status_enum
 )
 LANGUAGE plpgsql
 AS $proc$
  DECLARE
   id_country INTEGER;
  BEGIN
   INSERT INTO logs (message) VALUES ('Inserting note: ' || m_note_id);
   id_country := get_country(m_longitude, m_latitude, m_note_id);

   INSERT INTO notes (
    note_id,
    latitude,
    longitude,
    created_at,
    closed_at,
    status,
    id_country
   ) VALUES (
    m_note_id,
    m_latitude,
    m_longitude,
    m_created_at,
    m_closed_at,
    'open',-- TODO Debe ser siempre open al insertar m_status,
    id_country
   );
  END
 $proc$
