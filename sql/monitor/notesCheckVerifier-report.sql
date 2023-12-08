-- Generates a report of the differences between base tables and check tables.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-12-08
  
-- Shows the information of the latest note, which should be recent.
COPY
 (
  SELECT /* Notes-check */ *
  FROM notes
  WHERE note_id = (
   SELECT /* Notes-check */ MAX(note_id)
   FROM NOTES
  )
 )
 TO '${LAST_NOTE}' WITH DELIMITER ',' CSV HEADER
;

COPY
 (
  SELECT /* Notes-check */ *
  FROM note_comments
  WHERE note_id = (
   SELECT /* Notes-check */ MAX(note_id)
   FROM NOTES
  )
 )
 TO '${LAST_COMMENT}' WITH DELIMITER ',' CSV HEADER
;

-- Note ids that are not in the API DB, but are in the Planet.
-- If there are notes from the same date, it is probably that the sync script
-- had failed that day.
DROP TABLE IF EXISTS temp_diff_notes_id;

CREATE TABLE temp_diff_notes_id (
 note_id INTEGER
);
COMMENT ON TABLE temp_diff_notes_id IS
  'Temporal table for differences in note''s ids';
COMMENT ON COLUMN notes_check.note_id IS 'OSM note id';

INSERT INTO temp_diff_notes_id
 SELECT /* Notes-check */ note_id
 FROM notes_check 
 EXCEPT
 SELECT /* Notes-check */ note_id
 FROM notes
;

COPY
 (
  SELECT /* Notes-check */ notes_check.*
  FROM notes_check
  WHERE note_id IN (
   SELECT /* Notes-check */ note_id
   FROM temp_diff_notes_id
  )
  ORDER BY note_id, created_at
 )
 TO '${DIFFERENT_NOTE_IDS_FILE}' WITH DELIMITER ',' CSV HEADER
;

DROP TABLE IF EXISTS temp_diff_notes_id;

-- Comment notes id that are not in the API DB, but are in the Planet.
-- If there are comment from the same date, it is probably that the sync script
-- had failed that day.
DROP TABLE IF EXISTS temp_diff_comments_id;

CREATE TABLE temp_diff_comments_id (
 note_id INTEGER
);
COMMENT ON TABLE temp_diff_comments_id IS
  'Temporal table for differences in comment''s ids';
COMMENT ON COLUMN temp_diff_comments_id.note_id IS 'OSM note id';

INSERT INTO temp_diff_comments_id
 SELECT /* Notes-check */ note_id
 FROM note_comments_check 
 EXCEPT
 SELECT /* Notes-check */ note_id
 FROM note_comments
;

COPY
 (
  SELECT /* Notes-check */ note_comments_check.*
  FROM note_comments_check
  WHERE note_id IN (
   SELECT /* Notes-check */ note_id
   FROM temp_diff_comments_id
  )
  ORDER BY note_id, created_at
 )
 TO '${DIFFERENT_COMMENT_IDS_FILE}' WITH DELIMITER ',' CSV HEADER
;

DROP TABLE IF EXISTS temp_diff_comments_id;

-- Notes differences between the retrieved from API and the Planet.
DROP TABLE IF EXISTS temp_diff_notes;

CREATE TABLE temp_diff_notes (
 note_id INTEGER
);
COMMENT ON TABLE temp_diff_notes IS
  'Temporal table for differences in notes';
COMMENT ON COLUMN temp_diff_notes.note_id IS 'OSM note id';

INSERT INTO temp_diff_notes
 SELECT /* Notes-check */ note_id
 FROM (
  SELECT /* Notes-check */ note_id, latitude, longitude, created_at, status,
   closed_at
  FROM notes_check 
  EXCEPT
  SELECT /* Notes-check */ note_id, latitude, longitude, created_at, status,
   closed_at
  FROM notes
  WHERE (closed_at IS NULL OR closed_at < now()::date)
 ) AS t
 ORDER BY note_id
;

COPY
 (
  SELECT /* Notes-check */ *
  FROM (
   SELECT /* Notes-check */ 'Planet' AS source, note_id, latitude, longitude,
    created_at, status, closed_at
   FROM notes_check
   WHERE note_id IN (
    SELECT /* Notes-check */ note_id
    FROM temp_diff_notes
   )
   UNION
   SELECT /* Notes-check */ 'API   ' AS source, note_id, latitude, longitude,
    created_at, status, closed_at
   FROM notes
   WHERE note_id IN (
    SELECT /* Notes-check */ note_id
    FROM temp_diff_notes
   )
  ) AS T
  ORDER BY note_id, source
 )
 TO '${DIRRERENT_NOTES_FILE}' WITH DELIMITER ',' CSV HEADER
;

DROP TABLE IF EXISTS temp_diff_notes;

-- Comment differences between the retrieved from API and the Planet.
DROP TABLE IF EXISTS temp_diff_note_comments;

CREATE TABLE temp_diff_note_comments (
 note_id INTEGER
);
COMMENT ON TABLE temp_diff_note_comments IS
  'Temporal table for differences in comments';
COMMENT ON COLUMN temp_diff_note_comments.note_id IS 'OSM note id';

INSERT INTO temp_diff_note_comments
 SELECT /* Notes-check */ note_id
 FROM (
  SELECT /* Notes-check */ note_id, event, created_at, id_user
  FROM note_comments_check 
  EXCEPT
  SELECT /* Notes-check */ note_id, event, created_at, id_user
  FROM note_comments
  WHERE created_at < now()::date
 ) AS t
 ORDER BY note_id
;

COPY
 (
  SELECT /* Notes-check */ *
  FROM (
   SELECT /* Notes-check */ 'Planet' AS source, note_id, event, created_at,
    id_user
   FROM note_comments_check
   WHERE note_id IN (
    SELECT /* Notes-check */ note_id
    FROM temp_diff_note_comments
   )
   UNION
   SELECT /* Notes-check */ 'API   ' AS source, note_id, event, created_at,
    id_user
   FROM note_comments
   WHERE note_id IN (
    SELECT /* Notes-check */ note_id
    FROM temp_diff_note_comments
   )
   AND created_at < now()::date
  ) AS T
  ORDER BY note_id, created_at, source
 )
 TO '${DIRRERENT_COMMENTS_FILE}' WITH DELIMITER ',' CSV HEADER
;

DROP TABLE IF EXISTS temp_diff_note_comments;

-- Differences between comments and text
COPY (
 /* Notes-check */ *
 FROM (
  SELECT /* Notes-check */ COUNT(1) qty, c.note_id note_id
  FROM note_comments c
  GROUP BY c.note_id
  ORDER BY c.note_id
 ) AS c
 JOIN
 (
  SELECT /* Notes-check */ COUNT(1) qty, t.note_id note_id
  FROM note_comments_text t
  GROUP BY t.note_id
  ORDER BY t.note_id
 ) AS t
 ON c.note_id = t.note_id
 WHERE c.qty <> t.qty
 ORDER BY t.note_id
 )
 TO '${DIFFERENCES_TEXT_COMMENT}' WITH DELIMITER ',' CSV HEADER
;
