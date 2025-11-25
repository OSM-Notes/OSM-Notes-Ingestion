-- Assigns countries to a chunk of notes by their IDs.
-- Used for parallel processing of note country assignment.
--
-- Parameters:
--   ${NOTE_IDS} - Comma-separated list of note IDs (e.g., "123,456,789")
--
-- Returns:
--   COUNT(*) of notes that were successfully assigned a country
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-11-25

WITH target AS (
  SELECT UNNEST(ARRAY[${NOTE_IDS}])::BIGINT AS note_id
),
updated AS (
  UPDATE notes AS n /* Notes-assign chunk */
  SET id_country = get_country(n.longitude, n.latitude, n.note_id)
  FROM target t
  WHERE n.note_id = t.note_id
  AND n.id_country IS NULL
  RETURNING n.note_id
)
SELECT COUNT(*) FROM updated;

