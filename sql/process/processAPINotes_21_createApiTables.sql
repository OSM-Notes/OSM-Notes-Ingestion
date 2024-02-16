-- Create API tables.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2024-01-11

CREATE TABLE notes_api (
 note_id INTEGER NOT NULL,
 latitude DECIMAL NOT NULL,
 longitude DECIMAL NOT NULL,
 created_at TIMESTAMP NOT NULL,
 closed_at TIMESTAMP,
 status note_status_enum,
 id_country INTEGER
);
COMMENT ON TABLE notes_api IS 'Stores notes downloaded from API call';
COMMENT ON COLUMN notes_api.note_id IS 'OSM note id';
COMMENT ON COLUMN notes_api.latitude IS 'Latitude';
COMMENT ON COLUMN notes_api.longitude IS 'Longitude';
COMMENT ON COLUMN notes_api.created_at IS
  'Timestamp of the creation of the note';
COMMENT ON COLUMN notes_api.status IS
  'Current status of the note (opened, closed; hidden is not possible)';
COMMENT ON COLUMN notes_api.closed_at IS 'Timestamp when the note was closed';
COMMENT ON COLUMN notes_api.id_country IS
  'Country id where the note is located';

CREATE TABLE note_comments_api (
 id SERIAL,
 note_id INTEGER NOT NULL,
 sequence_action INTEGER,
 event note_event_enum NOT NULL,
 processing_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
 created_at TIMESTAMP NOT NULL,
 id_user INTEGER,
 username VARCHAR(256)
);
COMMENT ON TABLE note_comments_api IS
  'Stores comments downloaded from API call.';
COMMENT ON COLUMN note_comments_api.id IS
  'Generated ID to keep track of the comments order';
COMMENT ON COLUMN note_comments_api.note_id IS
  'Id of the associated note of this comment';
COMMENT ON COLUMN note_comments_api.sequence_action IS
  'Comment sequence generated from this tool';
COMMENT ON COLUMN note_comments_api.event IS
  'Type of action was performed on the note';
COMMENT ON COLUMN note_comments_api.processing_time IS
  'Registers when this comment was inserted in the database. Automatic value';
COMMENT ON COLUMN note_comments_api.created_at IS
  'Timestamps when the comment/action was done';
COMMENT ON COLUMN note_comments_api.id_user IS
  'OSM id of the user who performed the action';

CREATE TABLE IF NOT EXISTS note_comments_text_api (
 id SERIAL,
 note_id INTEGER NOT NULL,
 sequence_action INTEGER,
 processing_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
 body TEXT
);
COMMENT ON TABLE note_comments_text_api IS
  'Stores all text associated with comment notes';
COMMENT ON COLUMN note_comments_text_api.id IS
  'ID of the comment. Same value from the other table';
COMMENT ON COLUMN note_comments_text_api.note_id IS
  'OSM Note Id associated to this comment';
COMMENT ON COLUMN note_comments_text_api.sequence_action IS
  'Comment sequence, first is open, then any action in the creation order';
COMMENT ON COLUMN note_comments_text_api.processing_time IS
  'Registers when this comment was inserted in the database. Automatic value';
COMMENT ON COLUMN note_comments_text_api.body IS
  'Text of the note comment';
