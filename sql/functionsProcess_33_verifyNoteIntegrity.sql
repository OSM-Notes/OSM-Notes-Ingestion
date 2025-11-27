-- Verifies note integrity by checking if coordinates belong to assigned country.
-- This is optimized to use spatial index directly instead of loading all geometries.
--
-- Parameters:
--   ${SUB_START} - Start of note_id range (inclusive)
--   ${SUB_END} - End of note_id range (exclusive)
--
-- Returns:
--   COUNT(*) of invalidated notes (notes that don't belong to assigned country)
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-11-27
--
-- Optimization: Uses spatial index (GIST) directly for each point instead of
-- loading all country geometries into memory. This reduces execution time from
-- ~4 minutes to ~5-10 seconds per 20k notes.

BEGIN;

-- Optimized integrity verification using spatial index directly
-- Strategy:
-- 1. For each note, first check if assigned country still contains the point (fast)
-- 2. If not, use spatial index to find which country contains the point
-- 3. Invalidate if country doesn't match or point is not in any country
WITH notes_to_verify AS (
  SELECT n.note_id,
         n.id_country,
         n.longitude,
         n.latitude
  FROM notes AS n
  WHERE n.id_country IS NOT NULL
    AND ${SUB_START} <= n.note_id AND n.note_id < ${SUB_END}
),
-- Verify each note using spatial index directly
-- First check if assigned country still contains the point (optimization)
-- Then use spatial index to find actual country if different
verified AS (
  SELECT ntv.note_id,
         ntv.id_country AS current_country,
         CASE
           -- Fast path: Check if assigned country still contains the point
           WHEN EXISTS (
             SELECT 1
             FROM countries c
             WHERE c.country_id = ntv.id_country
               AND ST_Contains(c.geom, ST_SetSRID(ST_Point(ntv.longitude, ntv.latitude), 4326))
           ) THEN ntv.id_country
           -- Slow path: Use spatial index to find which country contains the point
           ELSE COALESCE(
             (SELECT c.country_id
              FROM countries c
              WHERE ST_Contains(c.geom, ST_SetSRID(ST_Point(ntv.longitude, ntv.latitude), 4326))
              LIMIT 1),
             -1
           )
         END AS verified_country
  FROM notes_to_verify ntv
),
-- Invalidate notes where country doesn't match or point is not in any country
invalidated AS (
  UPDATE notes AS n /* Notes-integrity check parallel */
  SET id_country = NULL
  FROM verified v
  WHERE n.note_id = v.note_id
    AND (v.verified_country = -1 OR v.verified_country <> v.current_country)
  RETURNING n.note_id
)
SELECT COUNT(*) FROM invalidated;

COMMIT;
