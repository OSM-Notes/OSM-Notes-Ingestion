-- Generates a report of the differences between base tables and check tables.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-10-21

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
-- Compare all historical data (excluding today) between API and Planet
DROP TABLE IF EXISTS temp_diff_notes_id;

CREATE TABLE temp_diff_notes_id (
 note_id INTEGER
);

INSERT INTO temp_diff_notes_id
 SELECT /* Notes-check */ note_id
 FROM notes_check
 WHERE DATE(created_at) < CURRENT_DATE  -- All history except today
 EXCEPT
 SELECT /* Notes-check */ note_id
 FROM notes
 WHERE DATE(created_at) < CURRENT_DATE  -- All history except today
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

-- Comment ids that are not in the API DB, but are in the Planet.
-- Compare all historical comments (excluding today) between API and Planet
DROP TABLE IF EXISTS temp_diff_comments_id;

CREATE TABLE temp_diff_comments_id (
 comment_id INTEGER
);

INSERT INTO temp_diff_comments_id
 SELECT /* Comments-check */ comment_id
 FROM note_comments_check
 WHERE DATE(created_at) < CURRENT_DATE  -- All history except today
 EXCEPT
 SELECT /* Comments-check */ comment_id
 FROM note_comments
 WHERE DATE(created_at) < CURRENT_DATE  -- All history except today
;

COPY
 (
  SELECT /* Notes-check */ note_comments_check.*
  FROM note_comments_check
  WHERE comment_id IN (
   SELECT /* Notes-check */ comment_id
   FROM temp_diff_comments_id
  )
  ORDER BY comment_id, created_at
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
  EXCEPT
  SELECT /* Notes-check */ note_id, latitude, longitude, created_at, status
  FROM notes
  -- Filter to exclude notes closed TODAY in API database.
  -- Rationale: The Planet dump (notes_check) is from yesterday (created at 5 UTC),
  -- so it does not contain notes that were closed today. To avoid false positives
  -- in the comparison, we exclude notes from the API (notes) that were closed today.
  -- This ensures a fair comparison between yesterday's Planet snapshot and API data.
  -- We include: 1) open notes (closed_at IS NULL), and
  --             2) notes closed before today (closed_at < NOW()::DATE)
  WHERE (closed_at IS NULL OR closed_at < NOW()::DATE)
 ) AS t
 ORDER BY note_id
;

-- Note differences between the retrieved from API and the Planet.
-- Compare complete note details for all history (excluding today)
\copy (
 SELECT /* Notes-check */ notes_check.*
 FROM notes_check
 WHERE note_id IN (
  SELECT /* Notes-check */ note_id
  FROM temp_diff_notes_id
 )
 AND DATE(created_at) < CURRENT_DATE  -- All history except today
 ORDER BY note_id, created_at
)
TO '${DIFFERENT_NOTES_FILE}' WITH DELIMITER ',' CSV HEADER
;

DROP TABLE IF EXISTS temp_diff_notes;

-- Comment differences between the retrieved from API and the Planet.
-- Compare complete comment details for all history (excluding today)
\copy (
 SELECT /* Comments-check */ note_comments_check.*
 FROM note_comments_check
 WHERE comment_id IN (
  SELECT /* Comments-check */ comment_id
  FROM temp_diff_comments_id
 )
 AND DATE(created_at) < CURRENT_DATE  -- All history except today
 ORDER BY comment_id, created_at
)
TO '${DIFFERENT_COMMENT_IDS_FILE}' WITH DELIMITER ',' CSV HEADER
;

DROP TABLE IF EXISTS temp_diff_note_comments;

-- Text comment ids that are not in the API DB, but are in the Planet.
-- Compare all historical text comments (excluding today) between API and Planet
DROP TABLE IF EXISTS temp_diff_text_comments_id;

CREATE TABLE temp_diff_text_comments_id (
 text_comment_id INTEGER
);

INSERT INTO temp_diff_text_comments_id
 SELECT /* Text-comments-check */ text_comment_id
 FROM note_comments_text_check
 WHERE DATE(created_at) < CURRENT_DATE  -- All history except today
 EXCEPT
 SELECT /* Text-comments-check */ text_comment_id
 FROM note_comments_text
 WHERE DATE(created_at) < CURRENT_DATE  -- All history except today
;

-- Text comment differences between the retrieved from API and the Planet.
-- Compare complete text comment details for all history (excluding today)
\copy (
 SELECT /* Text-comments-check */ note_comments_text_check.*
 FROM note_comments_text_check
 WHERE text_comment_id IN (
  SELECT /* Text-comments-check */ text_comment_id
  FROM temp_diff_text_comments_id
 )
 AND DATE(created_at) < CURRENT_DATE  -- All history except today
 ORDER BY text_comment_id, created_at
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
