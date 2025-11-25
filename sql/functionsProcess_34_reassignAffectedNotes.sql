-- Re-assigns countries for notes affected by boundary geometry changes.
-- This is much more efficient than re-processing all notes.
-- Only processes notes within bounding boxes of countries that were updated.
--
-- Strategy:
-- 1. Finds countries with updated = TRUE
-- 2. Uses ST_Intersects with bounding box to find potentially affected notes
-- 3. Calls get_country() which checks current country first (95% hit rate)
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-11-25

-- Re-assign country for notes that might be affected
-- The get_country function will check if note is still in current country first
UPDATE notes n
SET id_country = get_country(n.longitude, n.latitude, n.note_id)
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

