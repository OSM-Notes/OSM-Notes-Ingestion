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
  ORDER BY created_at
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
  ORDER BY created_at
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

INSERT INTO temp_diff_notes
 SELECT note_id FROM (
  SELECT note_id, latitude, longitude, created_at, status, closed_at FROM notes_check 
  EXCEPT
  SELECT note_id, latitude, longitude, created_at, status, closed_at FROM notes
 ) AS t
 ORDER BY note_id
;

COPY
 (
  SELECT *
  FROM (
   SELECT 'Planet', *
   FROM notes_check
   WHERE note_id IN (
    SELECT note_id
    FROM temp_diff_notes
   )
   UNION
   SELECT 'API   ', *
   FROM notes
   WHERE note_id IN (
    SELECT note_id
    FROM temp_diff_notes
   )
  ) AS T
  ORDER BY note_id
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

INSERT INTO temp_diff_note_comments
 SELECT note_id FROM (
  SELECT note_id, event, created_at, id_user FROM note_comments_check 
  EXCEPT
  SELECT note_id, event, created_at, id_user FROM note_comments
 ) AS t
 ORDER BY note_id
;

COPY
 (
  SELECT *
  FROM (
   SELECT 'Planet', note_id, event, created_at, id_user FROM note_comments_check
   WHERE note_id IN (
    SELECT note_id
    FROM temp_diff_note_comments
   )
   UNION
   SELECT 'API   ', note_id, event, created_at, id_user FROM note_comments
   WHERE note_id IN (
    SELECT note_id
    FROM temp_diff_note_comments
   )
  ) AS T
  ORDER BY note_id, created_at
 )
 TO '/tmp/differentNoteComments.csv' WITH DELIMITER ',' CSV HEADER
;

DROP TABLE temp_diff_note_comments;

