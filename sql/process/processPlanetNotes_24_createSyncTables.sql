-- Creates syn tables based on base tables.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-12-08

CREATE TABLE notes_sync (
 note_id INTEGER NOT NULL, -- id
 latitude DECIMAL NOT NULL,
 longitude DECIMAL NOT NULL,
 created_at TIMESTAMP NOT NULL,
 status note_status_enum,
 closed_at TIMESTAMP,
 id_country INTEGER
);
COMMENT ON TABLE notes_sync IS 'Stores notes to sync';
COMMENT ON COLUMN notes_sync.note_id IS 'OSM note id';
COMMENT ON COLUMN notes_sync.latitude IS 'Latitude';
COMMENT ON COLUMN notes_sync.longitude IS 'Longitude';
COMMENT ON COLUMN notes_sync.created_at IS
  'Timestamp of the creation of the note';
COMMENT ON COLUMN notes_sync.status IS
  'Current status of the note (opened, closed; hidden is not possible)';
COMMENT ON COLUMN notes_sync.closed_at IS 'Timestamp when the note was closed';
COMMENT ON COLUMN notes_sync.id_country IS
  'Country id where the note is located';

CREATE TABLE note_comments_sync (
 id SERIAL,
 note_id INTEGER NOT NULL,
 sequence_action INTEGER,
 event note_event_enum NOT NULL,
 created_at TIMESTAMP NOT NULL,
 id_user INTEGER,
 username VARCHAR(256)
);
COMMENT ON TABLE note_comments_sync IS
  'Temporal table for note comments from Planet';
COMMENT ON COLUMN note_comments_sync.id IS
  'Generated ID to keep track of the comments order';
COMMENT ON COLUMN note_comments_sync.note_id IS
  'OSM Note Id associated to this comment';
COMMENT ON COLUMN note_comments_sync.sequence_action IS
  'Comment sequence generated from this tool';
COMMENT ON COLUMN note_comments_sync.event IS
  'Type of action was performed on the note';
COMMENT ON COLUMN note_comments_sync.created_at IS
  'Timestamps when the comment/action was done';
COMMENT ON COLUMN note_comments_sync.id_user IS
  'OSM id of the user who performed the action';
COMMENT ON COLUMN note_comments_sync.username IS
  'OSM username who perfomed the action';

CREATE TABLE note_comments_text_sync (
 id SERIAL,
 note_id INTEGER NOT NULL,
 sequence_action INTEGER,
 body TEXT
);
COMMENT ON TABLE note_comments_text_sync IS
  'Temporal table for note comments text from Planet';
COMMENT ON COLUMN note_comments_text_sync.id IS
  'Generated ID to keep track of the text comments order';
COMMENT ON COLUMN note_comments_text_sync.note_id IS
  'OSM Note Id associated to this comment';
COMMENT ON COLUMN note_comments_text_sync.sequence_action IS
  'Comment sequence generated from this tool';
COMMENT ON COLUMN note_comments_text_sync.body IS
  'Text content of the comment';
