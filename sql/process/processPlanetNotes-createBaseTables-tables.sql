-- Create base tables and some indexes.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-10-25
  
CREATE TABLE IF NOT EXISTS users(
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
COMMENT ON COLUMN note_comments.event IS
  'Type of action was performed on the note';
COMMENT ON COLUMN note_comments.processing_time IS
  'Registers when this comment was inserted in the database. Automatic value';
COMMENT ON COLUMN note_comments.created_at IS
  'Timestamps when the comment/action was done';
COMMENT ON COLUMN note_comments.id_user IS
  'OSM id of the user who performed the action';

CREATE TABLE IF NOT EXISTS logs (
 id SERIAL,
 timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
 message VARCHAR(1000)
);
COMMENT ON TABLE logs IS 'Messages during the operations';
COMMENT ON COLUMN logs.id IS 'Sequential generated id';
COMMENT ON COLUMN logs.timestamp IS 'Timestamp when the event was recorded';
COMMENT ON COLUMN logs.message IS 'Text of the event';
