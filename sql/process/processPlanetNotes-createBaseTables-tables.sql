-- Create base tables and some indexes.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-10-25
  
CREATE TABLE IF NOT EXISTS users(
 user_id INTEGER NOT NULL,
 username VARCHAR(256) NOT NULL
);

CREATE TABLE IF NOT EXISTS notes (
 note_id INTEGER NOT NULL, -- id
 latitude DECIMAL NOT NULL,
 longitude DECIMAL NOT NULL,
 created_at TIMESTAMP NOT NULL,
 status note_status_enum,
 closed_at TIMESTAMP,
 id_country INTEGER
);

-- ToDo Crear un mecanismo que identificque la secuencia de comentario
CREATE TABLE IF NOT EXISTS note_comments (
 note_id INTEGER NOT NULL,
 event note_event_enum NOT NULL,
 processing_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
 created_at TIMESTAMP NOT NULL,
 id_user INTEGER
);
COMMENT ON TABLE note_comments IS 'Stores all comments associated to notes';
COMMENT ON COLUMN note_comments.note_id IS
  'Id of the associated note of this comment';
COMMENT ON COLUMN note_comments.event IS
  'Type of operation performed on the note';
COMMENT ON COLUMN note_comments.processing_time IS
  'Registers when this was inserted in the database. Automatic value';
COMMENT ON COLUMN note_comments.created_at IS
  'Timestamps when the comment/action was done';
COMMENT ON COLUMN note_comments.id_user IS
  'OSM id of the user who performed the action';

CREATE TABLE IF NOT EXISTS logs (
 id SERIAL,
 timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
 message VARCHAR(1000)
);

CREATE INDEX IF NOT EXISTS usernames ON users (username);
CREATE INDEX IF NOT EXISTS notes_closed ON notes (closed_at);
CREATE INDEX IF NOT EXISTS notes_created ON notes (created_at);
CREATE INDEX IF NOT EXISTS notes_countries ON notes (id_country);
CREATE INDEX IF NOT EXISTS note_comments_id ON note_comments (note_id);
CREATE INDEX IF NOT EXISTS note_comments_users ON note_comments (id_user);
CREATE INDEX IF NOT EXISTS note_comments_created ON note_comments (created_at);
