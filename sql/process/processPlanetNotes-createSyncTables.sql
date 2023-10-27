-- Creates syn tables based on base tables.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-10-25
  
  CREATE TABLE notes_sync (
   LIKE notes
  );

  CREATE TABLE note_comments_sync (
   LIKE note_comments
  );

  ALTER TABLE note_comments_sync ADD COLUMN username VARCHAR(256);
