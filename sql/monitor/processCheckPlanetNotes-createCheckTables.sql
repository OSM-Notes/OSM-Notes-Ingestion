-- Creates check tables.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-10-25
  
CREATE TABLE notes_check (
 note_id INTEGER NOT NULL,
 latitude DECIMAL NOT NULL,
 longitude DECIMAL NOT NULL,
 created_at TIMESTAMP NOT NULL,
 status note_status_enum,
 closed_at TIMESTAMP,
 id_country INTEGER
);
COMMENT ON TABLE notes_check IS 'Stores all notes to check against base table';
COMMENT ON COLUMN notes_check.note_id IS 'OSM note id';
COMMENT ON COLUMN notes_check.latitude IS 'Latitude';
COMMENT ON COLUMN notes_check.longitude IS 'Longitude';
COMMENT ON COLUMN notes_check.created_at IS
  'Timestamp of the creation of the note';
COMMENT ON COLUMN notes_check.status IS 
  'Current status of the note (opened, closed; hidden is not possible)';
COMMENT ON COLUMN notes_check.closed_at IS
  'Timestamp when the note was closed';
COMMENT ON COLUMN notes_check.id_country IS
  'Country id where the note is located';

CREATE TABLE note_comments_check (
 note_id INTEGER NOT NULL,
 event note_event_enum NOT NULL,
 created_at TIMESTAMP NOT NULL,
 id_user INTEGER,
 username VARCHAR(256)
);
COMMENT ON TABLE note_comments_check IS
  'Stores all comments to check agains base table';
COMMENT ON COLUMN note_comments_check.note_id IS
  'OSM Note Id associated to this comment';
COMMENT ON COLUMN note_comments_check.event IS
  'Type of action was performed on the note';
COMMENT ON COLUMN note_comments_check.created_at IS
  'Timestamps when the comment/action was done';
COMMENT ON COLUMN note_comments_check.id_user IS
  'OSM id of the user who performed the action';
COMMENT ON COLUMN note_comments_check.username IS
  'OSM username at the moment of the dump';
