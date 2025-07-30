-- Generates a report of the differences between base tables and check tables.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-07-29

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
  ORDER BY sequence_action
 )
 TO '${LAST_COMMENT}' WITH DELIMITER ',' CSV HEADER
;

-- Note ids that are not in the API DB, but are in the Planet.
-- Exclude notes created in the last 30 minutes to avoid false positives due to temporal gaps
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
 WHERE created_at < (NOW() - INTERVAL '30 minutes')  -- Exclude recent notes
 EXCEPT
 SELECT /* Notes-check */ note_id
 FROM notes
 WHERE created_at < (NOW() - INTERVAL '30 minutes')  -- Exclude recent notes
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
-- Exclude comments created in the last 30 minutes to avoid false positives due to temporal gaps
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
 WHERE created_at < (NOW() - INTERVAL '30 minutes')  -- Exclude recent comments
 EXCEPT
 SELECT /* Notes-check */ note_id
 FROM note_comments
 WHERE created_at < (NOW() - INTERVAL '30 minutes')  -- Exclude recent comments
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
  -- closed_at could be different from last comment. That's why it is not
  -- considered.
  SELECT /* Notes-check */ note_id, latitude, longitude, created_at, status
  FROM notes_check
  WHERE created_at < (NOW() - INTERVAL '30 minutes')  -- Exclude recent notes
  EXCEPT
  SELECT /* Notes-check */ note_id, latitude, longitude, created_at, status
  FROM notes
  WHERE (closed_at IS NULL OR closed_at < NOW()::DATE)  -- TODO no entiendo esto
    AND created_at < (NOW() - INTERVAL '30 minutes')  -- Exclude recent notes
 ) AS t
 ORDER BY note_id
;

COPY
 (
  SELECT /* Notes-check */ *
  FROM (
   -- closed_at, the API could close it before closing the comment.
   SELECT /* Notes-check */ 'Planet' AS source, note_id, latitude, longitude,
    created_at, status
   FROM notes_check
   WHERE note_id IN (
    SELECT /* Notes-check */ note_id
    FROM temp_diff_notes
   )
   UNION
   SELECT /* Notes-check */ 'API   ' AS source, note_id, latitude, longitude,
    created_at, status
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
  SELECT /* Notes-check */ note_id, sequence_action, event, created_at, id_user
  FROM note_comments_check
  WHERE created_at < (NOW() - INTERVAL '30 minutes')  -- Exclude recent comments
  EXCEPT
  SELECT /* Notes-check */ note_id, sequence_action, event, created_at, id_user
  FROM note_comments
  WHERE created_at < NOW()::DATE
    AND created_at < (NOW() - INTERVAL '30 minutes')  -- Exclude recent comments
 ) AS t
 ORDER BY note_id, sequence_action
;

COPY
 (
  SELECT /* Notes-check */ *
  FROM (
   SELECT /* Notes-check */ 'Planet' AS source, note_id, event, sequence_action,
    created_at, id_user
   FROM note_comments_check
   WHERE note_id IN (
    SELECT /* Notes-check */ note_id
    FROM temp_diff_note_comments
   )
   UNION
   SELECT /* Notes-check */ 'API   ' AS source, note_id, event, sequence_action,
    created_at, id_user
   FROM note_comments
   WHERE note_id IN (
    SELECT /* Notes-check */ note_id
    FROM temp_diff_note_comments
   )
   AND created_at < NOW()::DATE
  ) AS T
  ORDER BY note_id, sequence_action, source
 )
 TO '${DIRRERENT_COMMENTS_FILE}' WITH DELIMITER ',' CSV HEADER
;

DROP TABLE IF EXISTS temp_diff_note_comments;

-- Text comment differences between the retrieved from API and the Planet.
DROP TABLE IF EXISTS temp_diff_text_comments;

CREATE TABLE temp_diff_text_comments (
 note_id INTEGER
);
COMMENT ON TABLE temp_diff_text_comments IS
  'Temporal table for differences in text comments';
COMMENT ON COLUMN temp_diff_text_comments.note_id IS 'OSM note id';

INSERT INTO temp_diff_text_comments
 SELECT /* Notes-check */ note_id
 FROM (
  SELECT /* Notes-check */ note_id, sequence_action, body
  FROM note_comments_text_check
  EXCEPT
  SELECT /* Notes-check */ note_id, sequence_action, body
  FROM note_comments_text
  WHERE processing_time < NOW()::DATE
 ) AS t
 ORDER BY note_id, sequence_action
;

COPY
 (
  SELECT /* Notes-check */ *
  FROM (
   SELECT /* Notes-check */ 'Planet' AS source, note_id, sequence_action, body
   FROM note_comments_text_check
   WHERE note_id IN (
    SELECT /* Notes-check */ note_id
    FROM temp_diff_text_comments
   )
   UNION
   SELECT /* Notes-check */ 'API   ' AS source, note_id, sequence_action, body
   FROM note_comments_text
   WHERE note_id IN (
    SELECT /* Notes-check */ note_id
    FROM temp_diff_text_comments
   )
   AND processing_time < NOW()::DATE
  ) AS T
  ORDER BY note_id, sequence_action, source
 )
 TO '${DIFFERENT_TEXT_COMMENTS_FILE}' WITH DELIMITER ',' CSV HEADER
;

DROP TABLE IF EXISTS temp_diff_text_comments;

-- Differences between comments and text
COPY (
 SELECT /* Notes-check */ *
 FROM (
  SELECT /* Notes-check */ COUNT(1) qty, c.note_id note_id, c.sequence_action
  FROM note_comments c
  GROUP BY c.note_id, c.sequence_action
  ORDER BY c.note_id, c.sequence_action
 ) AS c
 JOIN
 (
  SELECT /* Notes-check */ COUNT(1) qty, t.note_id note_id, t.sequence_action
  FROM note_comments_text t
  GROUP BY t.note_id, t.sequence_action
  ORDER BY t.note_id, t.sequence_action
 ) AS t
 ON c.note_id = t.note_id AND c.sequence_action = t.sequence_action
 WHERE c.qty <> t.qty
 ORDER BY t.note_id, t.sequence_action
 )
 TO '${DIFFERENCES_TEXT_COMMENT}' WITH DELIMITER ',' CSV HEADER
;
