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

CREATE TABLE note_comments_api (
 note_id INTEGER NOT NULL,
 event note_event_enum NOT NULL,
 created_at TIMESTAMP NOT NULL,
 id_user INTEGER,
 username VARCHAR(256)
);
