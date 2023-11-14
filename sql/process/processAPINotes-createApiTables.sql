-- Create API tables.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-10-25
  
CREATE TABLE notes_api (
 note_id INTEGER NOT NULL,
 latitude DECIMAL NOT NULL,
 longitude DECIMAL NOT NULL,
 created_at TIMESTAMP NOT NULL,
 closed_at TIMESTAMP,
 status note_status_enum,
 id_country INTEGER
);
-- TODO Add comments

CREATE TABLE note_comments_api (
 id SERIAL,
 note_id INTEGER NOT NULL,
 event note_event_enum NOT NULL,
 processing_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
 created_at TIMESTAMP NOT NULL,
 id_user INTEGER,
 username VARCHAR(256)
);
COMMENT ON TABLE note_comments_api IS 'Stores all comments associated to notes';
COMMENT ON COLUMN note_comments_api.id IS
  'Generated ID to keep track of the comments order';
COMMENT ON COLUMN note_comments_api.note_id IS
  'Id of the associated note of this comment';
COMMENT ON COLUMN note_comments_api.event IS
  'Type of action was performed on the note';
COMMENT ON COLUMN note_comments_api.processing_time IS
  'Registers when this comment was inserted in the database. Automatic value';
COMMENT ON COLUMN note_comments_api.created_at IS
  'Timestamps when the comment/action was done';
COMMENT ON COLUMN note_comments_api.id_user IS
  'OSM id of the user who performed the action';
