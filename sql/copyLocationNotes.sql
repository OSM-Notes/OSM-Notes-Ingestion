-- When running the whole planet process, it could fail to assign the new notes
-- location. If you copy the locations ids of a previous execution, you can
-- reuse these locations after recreating the tables.
-- CREATE TABLE notes_bkp AS SELECT * FROM notes;
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-10-22

-- ====
-- Method 1
-- Creates a new tables for notes.
-- To run before the new execution.
CREATE TABLE notes_new AS
  SELECT n.note_id, n.latitude, n.longitude, n.created_at, n.status,
  n.closed_at, b.id_country
  FROM notes n
  LEFT JOIN notes_bkp b
  ON n.note_id = b.note_id;

-- To run after the new execution.
ALTER TABLE notes RENAME TO notes_orig;
DROP INDEX notes_countries;
DROP INDEX notes_created;
DROP INDEX notes_closed;
ALTER TABLE note_comments DROP CONSTRAINT fk_notes;
ALTER TABLE notes_orig DROP CONSTRAINT pk_notes;

ALTER TABLE notes_new ADD CONSTRAINT pk_notes PRIMARY KEY (note_id);
ALTER TABLE note_comments
   ADD CONSTRAINT fk_notes
   FOREIGN KEY (note_id)
   REFERENCES notes_new (note_id);
CREATE INDEX IF NOT EXISTS notes_closed ON notes_new (closed_at);
CREATE INDEX IF NOT EXISTS notes_created ON notes_new (created_at);
CREATE INDEX IF NOT EXISTS notes_countries ON notes_new (id_country);
ALTER TABLE notes_new RENAME TO notes;

-- To release space.
DROP TABLE notes_orig;

-- To update new notes without location.
UPDATE notes
  SET id_country = get_country(longitude, latitude, note_id)
  WHERE id_country IS NULL;

-- ====
-- Method 2
-- Copy the note_id and location.
-- To run before the new execution.
CREATE TABLE backup_note_country (
  note_id INTEGER,
  id_country INTEGER
);
INSERT INTO backup_note_country
  SELECT note_id, id_country
  FROM notes;

-- To run after the new execution.
UPDATE notes as n
SET id_country = b.id_country
FROM backup_note_country as b
WHERE b.note_id = n.note_id;

-- To release space.
DROP TABLE backup_note_country;
