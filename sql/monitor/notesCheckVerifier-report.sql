-- Generates a report of the differences between base tables and check tables.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2026-01-03

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

-- Comments that are not in the API DB, but are in the Planet.
-- Compare all historical comments (excluding today) between API and Planet
-- IMPORTANT: Compare by (note_id, sequence_action) instead of id, because
-- API inserts use nextval() which generates different IDs than Planet dumps.
-- This prevents false positives when comments exist with same logical content
-- but different sequential IDs.
DROP TABLE IF EXISTS temp_diff_comments_id;

CREATE TABLE temp_diff_comments_id (
 note_id INTEGER,
 sequence_action INTEGER
);

INSERT INTO temp_diff_comments_id
 SELECT /* Comments-check */ note_id, sequence_action
 FROM note_comments_check
 WHERE DATE(created_at) < CURRENT_DATE  -- All history except today
   AND sequence_action IS NOT NULL  -- Only compare comments with sequence_action
 EXCEPT
 SELECT /* Comments-check */ note_id, sequence_action
 FROM note_comments
 WHERE DATE(created_at) < CURRENT_DATE  -- All history except today
   AND sequence_action IS NOT NULL  -- Only compare comments with sequence_action
;

COPY
 (
  SELECT /* Notes-check */ note_comments_check.*
  FROM note_comments_check
  WHERE (note_id, sequence_action) IN (
   SELECT /* Notes-check */ note_id, sequence_action
   FROM temp_diff_comments_id
  )
  AND DATE(created_at) < CURRENT_DATE  -- All history except today
  ORDER BY note_id, sequence_action, created_at
 )
 TO '${DIFFERENT_COMMENT_IDS_FILE}' WITH DELIMITER ',' CSV HEADER
;

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
COPY (
 SELECT /* Notes-check */ notes_check.*
 FROM notes_check
 WHERE note_id IN (
  SELECT /* Notes-check */ note_id
  FROM temp_diff_notes
 )
 AND DATE(created_at) < CURRENT_DATE  -- All history except today
 ORDER BY note_id, created_at
)
TO '${DIFFERENT_NOTES_FILE}' WITH DELIMITER ',' CSV HEADER
;

DROP TABLE IF EXISTS temp_diff_notes;

-- Comment differences between the retrieved from API and the Planet.
-- Compare complete comment details for all history (excluding today)
-- Note: The COPY statement above already handles this correctly using
-- (note_id, sequence_action) comparison. This section is kept for documentation.

-- Clean up temporary tables (moved to end after all uses)

-- Text comment ids that are not in the API DB, but are in the Planet.
-- Compare all historical text comments (excluding today) between API and Planet
DROP TABLE IF EXISTS temp_diff_text_comments_id;

CREATE TABLE temp_diff_text_comments_id (
 text_comment_id INTEGER
);

INSERT INTO temp_diff_text_comments_id
 SELECT /* Text-comments-check */ id
 FROM note_comments_text_check
 WHERE (note_id, sequence_action) IN (
  SELECT /* Text-comments-check */ note_id, sequence_action
  FROM note_comments_text_check
  EXCEPT
  SELECT /* Text-comments-check */ note_id, sequence_action
  FROM note_comments_text
 )
 EXCEPT
 SELECT /* Text-comments-check */ id
 FROM note_comments_text
 WHERE (note_id, sequence_action) IN (
  SELECT /* Text-comments-check */ note_id, sequence_action
  FROM note_comments_text_check
  EXCEPT
  SELECT /* Text-comments-check */ note_id, sequence_action
  FROM note_comments_text
 )
;

-- Text comment differences between the retrieved from API and the Planet.
-- Compare complete text comment details for all history (excluding today)
COPY (
 SELECT /* Text-comments-check */ note_comments_text_check.*
 FROM note_comments_text_check
 WHERE id IN (
  SELECT /* Text-comments-check */ text_comment_id
  FROM temp_diff_text_comments_id
 )
 ORDER BY id, note_id, sequence_action
)
TO '${DIFFERENT_TEXT_COMMENTS_FILE}' WITH DELIMITER ',' CSV HEADER
;

DROP TABLE IF EXISTS temp_diff_text_comments;

-- Note ids that are in the API DB but NOT in the Planet.
-- These are notes that were created before the initial planet dump used to
-- populate the database, and were later hidden. Since hidden notes don't
-- appear in planet dumps, they exist in our system but not in the planet.
-- Compare all historical data (excluding today) between API and Planet
DROP TABLE IF EXISTS temp_notes_in_main_not_in_check;

CREATE TABLE temp_notes_in_main_not_in_check (
 note_id INTEGER
);
COMMENT ON TABLE temp_notes_in_main_not_in_check IS
  'Temporal table for notes that exist in main table but not in check table';
COMMENT ON COLUMN temp_notes_in_main_not_in_check.note_id IS 'OSM note id';

INSERT INTO temp_notes_in_main_not_in_check
 SELECT /* Notes-check */ note_id
 FROM notes
 WHERE DATE(created_at) < CURRENT_DATE  -- All history except today
 EXCEPT
 SELECT /* Notes-check */ note_id
 FROM notes_check
 WHERE DATE(created_at) < CURRENT_DATE  -- All history except today
;

-- Notes that are in main table but not in check table
COPY
 (
  SELECT /* Notes-check */ notes.*
  FROM notes
  WHERE note_id IN (
   SELECT /* Notes-check */ note_id
   FROM temp_notes_in_main_not_in_check
  )
  ORDER BY note_id, created_at
 )
 TO '${NOTES_IN_MAIN_NOT_IN_CHECK_FILE}' WITH DELIMITER ',' CSV HEADER
;

DROP TABLE IF EXISTS temp_notes_in_main_not_in_check;

-- Differences between comments and text
COPY (
 SELECT /* Notes-check */ *
 FROM (
  SELECT /* Notes-check */ COUNT(1) qty, c.note_id note_id, c.sequence_action
  FROM note_comments c
  GROUP BY c.note_id, c.sequence_action
  ORDER BY c.note_id, c.sequence_action
 ) AS c
 JOIN (
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

-- Clean up temporary tables used for comment comparison
DROP TABLE IF EXISTS temp_diff_comments_id;
DROP TABLE IF EXISTS temp_diff_note_comments;
