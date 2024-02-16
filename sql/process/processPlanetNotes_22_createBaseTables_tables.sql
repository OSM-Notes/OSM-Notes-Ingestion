-- Create base tables and some indexes.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2024-02-16
  
CREATE TABLE IF NOT EXISTS users (
 user_id INTEGER NOT NULL,
 username VARCHAR(256) NOT NULL
);
COMMENT ON TABLE users IS 'OSM user id';
COMMENT ON COLUMN users.user_id IS 'OSM user id';
COMMENT ON COLUMN users.username IS
  'Name of the user for the last note action';

CREATE TABLE IF NOT EXISTS notes (
 note_id INTEGER NOT NULL, -- id
 latitude DECIMAL NOT NULL,
 longitude DECIMAL NOT NULL,
 created_at TIMESTAMP NOT NULL,
 status note_status_enum,
 closed_at TIMESTAMP,
 id_country INTEGER
);
COMMENT ON TABLE notes IS 'Stores all notes';
COMMENT ON COLUMN notes.note_id IS 'OSM note id';
COMMENT ON COLUMN notes.latitude IS 'Latitude';
COMMENT ON COLUMN notes.longitude IS 'Longitude';
COMMENT ON COLUMN notes.created_at IS 'Timestamp of the creation of the note';
COMMENT ON COLUMN notes.status IS 
  'Current status of the note (opened, closed; hidden is not possible)';
COMMENT ON COLUMN notes.closed_at IS 'Timestamp when the note was closed';
COMMENT ON COLUMN notes.id_country IS 'Country id where the note is located';

CREATE TABLE IF NOT EXISTS note_comments (
 id SERIAL,
 note_id INTEGER NOT NULL,
 sequence_action INTEGER,
 event note_event_enum NOT NULL,
 processing_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
 created_at TIMESTAMP NOT NULL,
 id_user INTEGER
);
COMMENT ON TABLE note_comments IS 'Stores all comments associated to notes';
COMMENT ON COLUMN note_comments.id IS
  'Generated ID to keep track of the comments order';
  -- Multiples actions at the same time.
COMMENT ON COLUMN note_comments.note_id IS
  'OSM Note Id associated to this comment';
COMMENT ON COLUMN note_comments.sequence_action IS
  'Comment sequence generated from this tool';
COMMENT ON COLUMN note_comments.event IS
  'Type of action was performed on the note';
COMMENT ON COLUMN note_comments.processing_time IS
  'Registers when this comment was inserted in the database. Automatic value';
COMMENT ON COLUMN note_comments.created_at IS
  'Timestamps when the comment/action was done';
COMMENT ON COLUMN note_comments.id_user IS
  'OSM id of the user who performed the action';

CREATE TABLE IF NOT EXISTS note_comments_text (
 id SERIAL,
 note_id INTEGER NOT NULL,
 sequence_action INTEGER,
 processing_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
 body TEXT 
);
COMMENT ON TABLE note_comments_text IS
  'Stores all text associated with comment notes';
COMMENT ON COLUMN note_comments_text.id IS
  'ID of the comment. Same value from the other table';
COMMENT ON COLUMN note_comments_text.note_id IS
  'OSM Note Id associated to this comment';
COMMENT ON COLUMN note_comments_text.sequence_action IS
  'Comment sequence, first is open, then any action in the creation order';
COMMENT ON COLUMN note_comments_text.processing_time IS
  'Registers when this comment was inserted in the database. Automatic value';
COMMENT ON COLUMN note_comments_text.body IS
  'Text of the note comment';

CREATE TABLE IF NOT EXISTS logs (
 id SERIAL,
 timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
 message VARCHAR(1000)
);
COMMENT ON TABLE logs IS 'Messages during the operations';
COMMENT ON COLUMN logs.id IS 'Sequential generated id';
COMMENT ON COLUMN logs.timestamp IS 'Timestamp when the event was recorded';
COMMENT ON COLUMN logs.message IS 'Text of the event';

CREATE TABLE IF NOT EXISTS properties (
 key VARCHAR(16),
 value VARCHAR(26)
);
COMMENT ON TABLE dwh.properties IS 'Properties table for base load';
COMMENT ON COLUMN dwh.properties.key IS 'Property name';
COMMENT ON COLUMN dwh.properties.value IS 'Property value';

CREATE OR REPLACE PROCEDURE put_lock (
  m_id CHAR(20)
 )
 LANGUAGE plpgsql
 AS $proc$
 DECLARE
  m_qty SMALLINT;
 BEGIN
  SELECT COUNT (1)
   INTO m_qty
  FROM properties;
  IF (m_qty = 0) THEN
   INSERT INTO properties VALUES ('lock', m_id);
  ELSE
   SELECT value
    INTO m_id
   FROM properties
   WHERE key = 'lock';
   RAISE EXCEPTION 'There is a lock on the table. Shell id %', m_id;
  END IF;
 END
$proc$
;
COMMENT ON PROCEDURE put_lock IS
  'Tries to put a lock for only one process inserting notes and comments. Otherwise it raise error';

CREATE OR REPLACE PROCEDURE remove_lock (
  m_id CHAR(20)
 )
 LANGUAGE plpgsql
 AS $proc$
 DECLARE
  m_qty SMALLINT;
  m_current_id SMALLINT;
 BEGIN
  SELECT count(1)
   INTO m_qty
  FROM properties
  WHERE key = 'lock';
  IF (m_qty = 1) THEN
   SELECT value
    INTO m_current_id
   FROM properties
   WHERE key = 'lock';
   IF (m_id = m_current_id) THEN
    DELETE FROM properties
    WHERE key = 'lock' AND value = 'm_id';
   ELSE
    RAISE EXCEPTION 'Lock is hold by another app: %, current app: %',
      m_current_id, m_id;
   END IF;
  ELSE
   RAISE NOTICE 'No lock to remove';
  END IF;
 END
$proc$
;
COMMENT ON PROCEDURE remove_lock IS
  'Removes the lock';
