-- Create constraints in base tables for Docker environment (without PostGIS)
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-08-04

-- Users table already has PRIMARY KEY defined in CREATE TABLE
-- ALTER TABLE users
--  ADD CONSTRAINT pk_users
--  PRIMARY KEY (user_id);

-- Add primary key only if it doesn't exist
DO $$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'pk_notes') THEN
  ALTER TABLE notes ADD CONSTRAINT pk_notes PRIMARY KEY (note_id);
 END IF;
END $$;

-- The API does not provide an identifier for the comments, therefore, this
-- project implemented another column for the id. However, the execution cannot
-- be parallelized. With the sequence, the order the comments were inserted can
-- be identified.
DO $$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'pk_note_comments') THEN
  ALTER TABLE note_comments ADD CONSTRAINT pk_note_comments PRIMARY KEY (id);
 END IF;
END $$;

DO $$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'pk_text_comments') THEN
  ALTER TABLE note_comments_text ADD CONSTRAINT pk_text_comments PRIMARY KEY (id);
 END IF;
END $$;

DO $$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_notes') THEN
  ALTER TABLE note_comments ADD CONSTRAINT fk_notes FOREIGN KEY (note_id) REFERENCES notes (note_id);
 END IF;
END $$;

DO $$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_users') THEN
  ALTER TABLE note_comments ADD CONSTRAINT fk_users FOREIGN KEY (id_user) REFERENCES users (user_id);
 END IF;
END $$;

CREATE INDEX IF NOT EXISTS usernames ON users (username);
COMMENT ON INDEX usernames IS 'To query by username';

CREATE INDEX IF NOT EXISTS notes_closed ON notes (closed_at);
COMMENT ON INDEX notes_closed IS 'To query by closed time';
CREATE INDEX IF NOT EXISTS notes_created ON notes (created_at);
COMMENT ON INDEX notes_created IS 'To query by opening time';
CREATE INDEX IF NOT EXISTS notes_countries ON notes (id_country);
COMMENT ON INDEX notes_countries IS 'To query by location of the note';

-- Spatial index without PostGIS functions for Docker environment
CREATE INDEX IF NOT EXISTS notes_spatial ON notes
  USING BTREE (id_country, note_id, longitude, latitude);
COMMENT ON INDEX notes_spatial IS 'Spatial index (simplified for Docker)';

CREATE INDEX IF NOT EXISTS note_comments_id ON note_comments (note_id);
COMMENT ON INDEX note_comments_id IS 'To query by the associated note';
CREATE INDEX IF NOT EXISTS note_comments_users ON note_comments (id_user);
COMMENT ON INDEX note_comments_users IS
  'To query by the user who performed the action';
CREATE INDEX IF NOT EXISTS note_comments_created ON note_comments (created_at);
COMMENT ON INDEX note_comments_created IS 'To query by the time of the action';
CREATE INDEX IF NOT EXISTS note_comments_id_event ON note_comments (note_id, event);
COMMENT ON INDEX note_comments_id_event IS 'To query by the id and event';
CREATE INDEX IF NOT EXISTS note_comments_id_created ON note_comments (note_id, created_at);
COMMENT ON INDEX note_comments_id_created IS 'To query by the id and creation time';

CREATE INDEX IF NOT EXISTS note_comments_id_text ON note_comments_text (note_id);
COMMENT ON INDEX note_comments_id_text IS 'To query by the note id';

DO $$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'username_uniq') THEN
  CREATE UNIQUE INDEX username_uniq ON users (username);
  COMMENT ON INDEX username_uniq IS 'Username is unique';
 END IF;
END $$; 