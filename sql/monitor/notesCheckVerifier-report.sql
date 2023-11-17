-- Generates a report of the differences between base tables and check tables.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-10-25
  
-- Muestra la información de la última nota, la cual debe ser reciente.
COPY
 (
  SELECT *
  FROM notes
  WHERE note_id = (
   SELECT MAX(note_id)
   FROM NOTES
  )
 )
 TO '/tmp/lastNote.csv' WITH DELIMITER ',' CSV HEADER
;

COPY
 (
  SELECT *
  FROM note_comments
  WHERE note_id = (
   SELECT MAX(note_id)
   FROM NOTES
  )
 )
 TO '/tmp/lastNoteComment.csv' WITH DELIMITER ',' CSV HEADER
;

-- Ids de notas que no están en la DB de API, pero si en la de Planet.
-- Si hay varias notas de la misma fecha, es probable que haya fallado el
-- script maestro ese día.
DROP TABLE IF EXISTS temp_diff_notes_id;

CREATE TABLE temp_diff_notes_id (
 note_id INTEGER
);
COMMENT ON TABLE temp_diff_notes_id IS
  'Temporal table for differences in note''s ids';
COMMENT ON COLUMN notes_check.note_id IS 'OSM note id';

INSERT INTO temp_diff_notes_id
 SELECT note_id
 FROM notes_check 
 EXCEPT
 SELECT note_id
 FROM notes
;

COPY
 (
  SELECT notes_check.*
  FROM notes_check
  WHERE note_id IN (
   SELECT note_id
   FROM temp_diff_notes_id
  )
  ORDER BY note_id, created_at
 )
 TO '/tmp/differentNoteIds.csv' WITH DELIMITER ',' CSV HEADER
;

DROP TABLE temp_diff_notes_id;

-- Ids de comentarios que no están en la DB de API, pero si en la de Planet.
-- Si hay varios comentarios de la misma fecha, es probable que haya fallado el
-- script maestro ese día.
DROP TABLE IF EXISTS temp_diff_comments_id;

CREATE TABLE temp_diff_comments_id (
 note_id INTEGER
);
COMMENT ON TABLE temp_diff_comments_id IS
  'Temporal table for differences in comment''s ids';
COMMENT ON COLUMN notes_check.temp_diff_comments_id IS 'OSM note id';

INSERT INTO temp_diff_comments_id
 SELECT note_id
 FROM note_comments_check 
 EXCEPT
 SELECT note_id
 FROM note_comments
;

COPY
 (
  SELECT note_comments_check.*
  FROM note_comments_check
  WHERE note_id IN (
   SELECT note_id
   FROM temp_diff_comments_id
  )
  ORDER BY note_id, created_at
 )
 TO '/tmp/differentNoteCommentIds.csv' WITH DELIMITER ',' CSV HEADER
;

DROP TABLE temp_diff_comments_id;

-- Notas diferentes entre las recuperadas por el API y las del Planet.
-- Si hay varias notas de la misma fecha, es probable que haya fallado el
-- script maestro ese día.
DROP TABLE IF EXISTS temp_diff_notes;

CREATE TABLE temp_diff_notes (
 note_id INTEGER
);
COMMENT ON TABLE temp_diff_notes IS
  'Temporal table for differences in notes';
COMMENT ON COLUMN temp_diff_notes.note_id IS 'OSM note id';

INSERT INTO temp_diff_notes
 SELECT note_id FROM (
  SELECT note_id, latitude, longitude, created_at, status, closed_at
  FROM notes_check 
  EXCEPT
  SELECT note_id, latitude, longitude, created_at, status, closed_at
  FROM notes
  WHERE (closed_at IS NULL OR closed_at < now()::date)
 ) AS t
 ORDER BY note_id
;

COPY
 (
  SELECT *
  FROM (
   SELECT 'Planet' as source, note_id, latitude, longitude, created_at, status, closed_at
   FROM notes_check
   WHERE note_id IN (
    SELECT note_id
    FROM temp_diff_notes
   )
   UNION
   SELECT 'API   ' as source, note_id, latitude, longitude, created_at, status, closed_at
   FROM notes
   WHERE note_id IN (
    SELECT note_id
    FROM temp_diff_notes
   )
  ) AS T
  ORDER BY note_id, source
 )
 TO '/tmp/differentNotes.csv' WITH DELIMITER ',' CSV HEADER
;

DROP TABLE temp_diff_notes;

-- Comentarios diferentes entre los recuperadas por el API y los del Planet.
-- Si hay varios comentarios de la misma fecha, es probable que haya fallado el
-- script maestro ese día.
DROP TABLE IF EXISTS temp_diff_note_comments;

CREATE TABLE temp_diff_note_comments (
 note_id INTEGER
);
COMMENT ON TABLE temp_diff_note_comments IS
  'Temporal table for differences in comments';
COMMENT ON COLUMN temp_diff_note_comments.note_id IS 'OSM note id';

INSERT INTO temp_diff_note_comments
 SELECT note_id FROM (
  SELECT note_id, event, created_at, id_user FROM note_comments_check 
  EXCEPT
  SELECT note_id, event, created_at, id_user FROM note_comments
  WHERE created_at < now()::date
 ) AS t
 ORDER BY note_id
;

COPY
 (
  SELECT *
  FROM (
   SELECT 'Planet'as source, note_id, event, created_at, id_user
   FROM note_comments_check
   WHERE note_id IN (
    SELECT note_id
    FROM temp_diff_note_comments
   )
   UNION
   SELECT 'API   ' as source, note_id, event, created_at, id_user
   FROM note_comments
   WHERE note_id IN (
    SELECT note_id
    FROM temp_diff_note_comments
   )
   AND created_at < now()::date
  ) AS T
  ORDER BY note_id, created_at, source
 )
 TO '/tmp/differentNoteComments.csv' WITH DELIMITER ',' CSV HEADER
;

DROP TABLE temp_diff_note_comments;

