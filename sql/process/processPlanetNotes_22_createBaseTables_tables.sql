-- Create base tables and some indexes.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2024-02-20

CREATE TABLE IF NOT EXISTS users (
 user_id INTEGER NOT NULL PRIMARY KEY,
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
  -- Multiple actions at the same time.
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
 key VARCHAR(32) PRIMARY KEY,
 value VARCHAR(32),
 updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
COMMENT ON TABLE properties IS 'Properties table for base load';
COMMENT ON COLUMN properties.key IS 'Property name';
COMMENT ON COLUMN properties.value IS 'Property value';

-- Insert properties only for the initial load.
INSERT INTO properties (key, value) VALUES
  ('initialLoadNotes', 'true'),
  ('initialLoadComments', 'true');

-- Create trigger to update timestamp on properties table
CREATE OR REPLACE FUNCTION update_properties_timestamp()
  RETURNS TRIGGER AS
 $$
 BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
 END;
 $$ LANGUAGE plpgsql
;

CREATE OR REPLACE TRIGGER update_properties_timestamp_trigger
  BEFORE UPDATE ON properties
  FOR EACH ROW
  EXECUTE FUNCTION update_properties_timestamp()
;

CREATE OR REPLACE PROCEDURE put_lock (
  m_id VARCHAR(32)
 )
 LANGUAGE plpgsql
 AS $proc$
 DECLARE
  m_qty SMALLINT;
  m_current_lock VARCHAR(32);
  m_lock_timeout INTEGER := 300; -- 5 minutes timeout
  m_start_time TIMESTAMP := NOW();
 BEGIN
  -- Check if there's already a lock
  SELECT /* Notes-base */ COUNT(1)
   INTO m_qty
  FROM properties
  WHERE key = 'lock';
  
  IF (m_qty = 0) THEN
   -- No lock exists, try to insert one
   BEGIN
    INSERT INTO properties VALUES ('lock', m_id);
    RAISE NOTICE 'Lock inserted %.', m_id;
   EXCEPTION
    WHEN unique_violation THEN
     -- Another process inserted the lock first
     SELECT value INTO m_current_lock
     FROM properties
     WHERE key = 'lock';
     RAISE EXCEPTION 'Lock was acquired by another process: %.', m_current_lock;
   END;
  ELSE
   -- Lock exists, check if it's stale (older than timeout)
   SELECT value INTO m_current_lock
   FROM properties
   WHERE key = 'lock';
   
   -- Check if lock is older than timeout
   IF EXISTS (
    SELECT 1 FROM properties 
    WHERE key = 'lock' 
    AND updated_at < (NOW() - INTERVAL '5 minutes')
   ) THEN
    -- Remove stale lock and try to acquire new one
    DELETE FROM properties WHERE key = 'lock';
    INSERT INTO properties VALUES ('lock', m_id);
    RAISE NOTICE 'Stale lock removed and new lock inserted %.', m_id;
   ELSE
    RAISE EXCEPTION 'There is an active lock on the table. Shell id %.', m_current_lock;
   END IF;
  END IF;
 END
$proc$
;
COMMENT ON PROCEDURE put_lock IS
  'Tries to put a lock for only one process inserting notes and comments. Otherwise it raise error';

CREATE OR REPLACE PROCEDURE remove_lock (
  m_id VARCHAR(32)
 )
 LANGUAGE plpgsql
 AS $proc$
 DECLARE
  m_qty SMALLINT;
  m_current_id VARCHAR(32);
 BEGIN
  SELECT /* Notes-base */ count(1)
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
    WHERE key = 'lock';
    RAISE NOTICE 'Lock removed %.', m_id;
   ELSE
    RAISE EXCEPTION 'Lock is hold by another app: %, current app: %.',
      m_current_id, m_id;
   END IF;
  ELSE
   RAISE NOTICE 'No lock to remove.';
  END IF;
 END
$proc$
;
COMMENT ON PROCEDURE remove_lock IS
  'Removes the lock';

CREATE OR REPLACE FUNCTION log_insert_note()
  RETURNS TRIGGER AS
 $$
 BEGIN
  INSERT INTO logs (message) VALUES (NEW.note_id || ' - Note inserted.');

  RETURN NEW;
 END;
 $$ LANGUAGE plpgsql
;
COMMENT ON FUNCTION log_insert_note IS
  'Updates the notes according the new comments';

CREATE OR REPLACE TRIGGER log_insert_note
  AFTER INSERT ON notes
  FOR EACH ROW
  EXECUTE FUNCTION log_insert_note()
;
COMMENT ON TRIGGER log_insert_note ON notes IS
  'Updates the notes according the new comments';

CREATE OR REPLACE FUNCTION update_note()
  RETURNS TRIGGER AS
 $$
 DECLARE
  m_status note_status_enum;
 BEGIN
   -- Gets the current status of the note.
   -- The real status of the note could be closed, but it is inserted as open.
  SELECT /* Notes-base */ status
   INTO m_status
  FROM notes
  WHERE note_id = NEW.note_id;

  -- Possible comment actions depending the current note state.
  IF (m_status = 'open') THEN
   -- The note is currently open.

   IF (NEW.event = 'closed') THEN
    INSERT INTO logs (message) VALUES (NEW.note_id
      || ' - Update to close note.');
    UPDATE notes /* trigger update note */
      SET status = 'close',
      -- This date could differ between notes and comments, sometimes several
      -- seconds before.
      closed_at = NEW.created_at
      WHERE note_id = NEW.note_id;
   ELSIF (NEW.event = 'reopened') THEN
    -- There are some known issues in the API, and cannot be strictly validated.
    -- Consecutives reopens.

    -- Invalid operation for an open note.
    INSERT INTO logs (message) VALUES (NEW.note_id
      || ' - Trying to reopen an opened note ' || NEW.event || '.');
    RAISE NOTICE 'Trying to reopen an opened note: % - % %.', NEW.note_id,
      m_status, NEW.event;
   ELSIF (NEW.event = 'hidden') THEN
    INSERT INTO logs (message) VALUES (NEW.note_id
      || ' - Update to hide open note.');
    UPDATE notes /* trigger update note */
      SET status = 'hidden',
      closed_at = NEW.created_at
      WHERE note_id = NEW.note_id;
   END IF;
  ELSE
   -- The note is currently closed.

   IF (NEW.event = 'reopened') THEN
    INSERT INTO logs (message) VALUES (NEW.note_id
      || ' - Update to reopen note.');
    UPDATE notes /* trigger update note */
      SET status = 'open',
      closed_at = NULL
      WHERE note_id = NEW.note_id;
   ELSIF (NEW.event = 'closed') THEN
    -- There are some known issues in the API, and this cannot be strictly
    -- validated. Consecutives closes.

    -- Invalid operation for a closed note.
    INSERT INTO logs (message) VALUES (NEW.note_id
      || ' - Trying to close a closed note ' || NEW.event || '.');
    RAISE NOTICE 'Trying to close a closed note: % - % %.', NEW.note_id,
      m_status, NEW.event;
   ELSIF (NEW.event = 'hidden') THEN
    INSERT INTO logs (message) VALUES (NEW.note_id
      || ' - Update to hide close note.');
    UPDATE notes /* trigger update note */
      SET status = 'hidden',
      closed_at = NEW.created_at
      WHERE note_id = NEW.note_id;
   END IF;
  END IF;

  RETURN NEW;
 END;
 $$ LANGUAGE plpgsql
;
COMMENT ON FUNCTION update_note IS
  'Updates the notes according the new comments';

CREATE OR REPLACE TRIGGER update_note
  AFTER INSERT ON note_comments
  FOR EACH ROW
  EXECUTE FUNCTION update_note()
;
COMMENT ON TRIGGER update_note ON note_comments IS
  'Updates the notes according the new comments';
