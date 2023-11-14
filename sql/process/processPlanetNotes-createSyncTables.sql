-- Creates syn tables based on base tables.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-10-25
  
CREATE TABLE notes_sync (
 note_id INTEGER NOT NULL, -- id
 latitude DECIMAL NOT NULL,
 longitude DECIMAL NOT NULL,
 created_at TIMESTAMP NOT NULL,
 status note_status_enum,
 closed_at TIMESTAMP,
 id_country INTEGER
);

CREATE TABLE note_comments_sync (
 note_id INTEGER NOT NULL,
 event note_event_enum NOT NULL,
 created_at TIMESTAMP NOT NULL,
 id_user INTEGER,
 username VARCHAR(256)
);
COMMENT ON TABLE note_comments_sync IS 'Temporal table for note comments from Planet';
COMMENT ON COLUMN note_comments_sync.note_id IS
  'OSM Note Id associated to this comment';
COMMENT ON COLUMN note_comments_sync.event IS
  'Type of action was performed on the note';
COMMENT ON COLUMN note_comments_sync.created_at IS
  'Timestamps when the comment/action was done';
COMMENT ON COLUMN note_comments_sync.id_user IS
  'OSM id of the user who performed the action';
COMMENT ON COLUMN note_comments_sync.username IS
  'OSM username who perfomed the action';
