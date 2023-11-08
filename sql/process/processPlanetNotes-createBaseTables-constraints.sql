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

-- ToDo Primary key duplicated error. This is an API error because there is
-- no way to identify the order of the comments, other that by analyzing the
-- order of the retrieved comments.
--ALTER TABLE note_comments
-- ADD CONSTRAINT pk_note_comments
-- PRIMARY KEY (note_id, event, created_at);

ALTER TABLE note_comments
 ADD CONSTRAINT fk_notes
 FOREIGN KEY (note_id)
 REFERENCES notes (note_id);

ALTER TABLE note_comments
 ADD CONSTRAINT fk_users
 FOREIGN KEY (id_user)
 REFERENCES users (user_id);
