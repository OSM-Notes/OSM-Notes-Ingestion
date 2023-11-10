-- Create constraints in base tables.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-10-25
  
ALTER TABLE notes
 ADD CONSTRAINT pk_notes
 PRIMARY KEY (note_id);

ALTER TABLE users
 ADD CONSTRAINT pk_users
 PRIMARY KEY (user_id);

-- The API does not provide an identifier for the comments, therefore, this
-- project implemented another column for the id. However, the execution cannot
-- be parallelized.
-- https://api.openstreetmap.org/api/0.6/notes/3750896
ALTER TABLE note_comments
 ADD CONSTRAINT pk_note_comments
 PRIMARY KEY (id);

ALTER TABLE note_comments
 ADD CONSTRAINT fk_notes
 FOREIGN KEY (note_id)
 REFERENCES notes (note_id);

ALTER TABLE note_comments
 ADD CONSTRAINT fk_users
 FOREIGN KEY (id_user)
 REFERENCES users (user_id);
