-- Creates syn tables based on base tables.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-10-25
  
CREATE TABLE notes_sync (
 LIKE notes
);
CREATE TABLE note_comments_sync (
 note_id INTEGER NOT NULL,
 event note_event_enum NOT NULL,
 created_at TIMESTAMP NOT NULL,
 id_user INTEGER,
 username VARCHAR(256)
);
COMMENT ON TABLE note_comments IS 'Temporal table for note comments from Planet';
COMMENT ON COLUMN note_comments.note_id IS
  'OSM Note Id associated to this comment';
COMMENT ON COLUMN note_comments.event IS
  'Type of action was performed on the note';
COMMENT ON COLUMN note_comments.created_at IS
  'Timestamps when the comment/action was done';
COMMENT ON COLUMN note_comments.id_user IS
  'OSM id of the user who performed the action';
COMMENT ON COLUMN note_comments.username IS
  'OSM username who perfomed the action';
