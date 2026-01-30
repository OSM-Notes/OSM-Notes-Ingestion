-- Re-assigns countries for notes affected by boundary geometry changes.
-- Processes one batch of notes (called repeatedly from bash script).
-- Only processes notes within bounding boxes of countries that were updated.
--
-- Strategy:
-- 1. Finds countries with updated = TRUE
-- 2. Uses ST_Intersects with bounding box to find potentially affected notes
-- 3. Processes one batch (LIMIT) and returns count of processed notes
-- 4. Called repeatedly from bash until no more notes to process
-- 5. Calls get_country() which checks current country first (95% hit rate)
-- 6. OPTIMIZATION: Only updates notes where country actually changed
--
-- Parameters:
--   ${BATCH_SIZE} - Number of notes to process in this batch (default: 1000)
--
-- Returns:
--   Number of notes processed in this batch (0 when done)
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-12-12

DO $$
DECLARE
 batch_size INTEGER := COALESCE(NULLIF(current_setting('app.batch_size', TRUE), ''), '1000')::INTEGER;
 processed_count BIGINT;
BEGIN
 -- Process one batch of notes
 -- OPTIMIZATION: Only update notes where country actually changed
 -- get_country() already checks current country first (95% hit rate),
 -- but we avoid unnecessary UPDATE operations when country didn't change
 WITH batch_notes AS (
  SELECT n.note_id, n.longitude, n.latitude, n.id_country as current_country
  FROM notes n
  WHERE EXISTS (
    SELECT 1
    FROM countries c
    WHERE c.updated = TRUE
      AND ST_Intersects(
        ST_MakeEnvelope(
          ST_XMin(c.geom), ST_YMin(c.geom),
          ST_XMax(c.geom), ST_YMax(c.geom),
          4326
        ),
        ST_SetSRID(ST_MakePoint(n.longitude, n.latitude), 4326)
      )
  )
  ORDER BY n.note_id
  LIMIT batch_size
  FOR UPDATE SKIP LOCKED
 ),
 notes_with_new_country AS (
  SELECT bn.note_id,
         get_country(bn.longitude, bn.latitude, bn.note_id) as new_country,
         bn.current_country
  FROM batch_notes bn
 )
 UPDATE notes n
 SET id_country = nwc.new_country
 FROM notes_with_new_country nwc
 WHERE n.note_id = nwc.note_id
   AND (nwc.current_country IS DISTINCT FROM nwc.new_country);

 GET DIAGNOSTICS processed_count = ROW_COUNT;
 
 -- Output result for bash script to read
 RAISE NOTICE 'PROCESSED_COUNT:%', processed_count;
END $$;

