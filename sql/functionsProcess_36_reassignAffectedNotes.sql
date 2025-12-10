-- Re-assigns countries for notes affected by boundary geometry changes.
-- Processes notes in batches with partial commits to avoid long transactions.
-- Only processes notes within bounding boxes of countries that were updated.
--
-- Strategy:
-- 1. Finds countries with updated = TRUE
-- 2. Uses ST_Intersects with bounding box to find potentially affected notes
-- 3. Processes notes in chunks (default: 1000 notes per batch)
-- 4. Commits each batch separately to allow partial progress
-- 5. Calls get_country() which checks current country first (95% hit rate)
--
-- Parameters:
--   ${BATCH_SIZE} - Number of notes to process per batch (default: 1000)
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-12-10

DO $$
DECLARE
 batch_size INTEGER := COALESCE(NULLIF(current_setting('app.batch_size', TRUE), ''), '1000')::INTEGER;
 total_affected BIGINT;
 processed_count BIGINT := 0;
 remaining_count BIGINT;
 batch_count INTEGER := 0;
BEGIN
 -- Get total count of potentially affected notes
 SELECT COUNT(*)
 INTO total_affected
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
 );

 -- If no notes affected, exit early
 IF total_affected = 0 THEN
  RAISE NOTICE 'No notes affected by boundary changes';
  RETURN;
 END IF;

 RAISE NOTICE 'Total notes to process: %', total_affected;
 remaining_count := total_affected;

 -- Process in batches until all notes are processed
 WHILE remaining_count > 0 LOOP
  batch_count := batch_count + 1;
  
  -- Process one batch and commit
  WITH batch_notes AS (
   SELECT n.note_id
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
  )
  UPDATE notes n
  SET id_country = get_country(n.longitude, n.latitude, n.note_id)
  FROM batch_notes bn
  WHERE n.note_id = bn.note_id;

  GET DIAGNOSTICS processed_count = ROW_COUNT;
  remaining_count := remaining_count - processed_count;

  RAISE NOTICE 'Batch %: Processed % notes, % remaining', batch_count, processed_count, remaining_count;

  -- Commit this batch (automatic in DO block, but explicit for clarity)
  -- In a DO block, we need to use explicit COMMIT
  COMMIT;
  
  -- If no rows were processed in this batch, exit to avoid infinite loop
  IF processed_count = 0 THEN
   RAISE WARNING 'No notes processed in batch %, exiting', batch_count;
   EXIT;
  END IF;
 END LOOP;

 RAISE NOTICE 'Completed: Processed % notes in % batches', total_affected, batch_count;
END $$;
