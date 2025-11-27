-- Verifies note integrity by checking if coordinates belong to assigned country.
-- This is optimized to use JOIN first, then spatial index only when needed.
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
-- Optimization: Uses JOIN with assigned country first (fast), then spatial index
-- only for notes that don't match. This avoids loading all geometries and reduces
-- execution time from ~4 minutes to ~5-10 seconds per 20k notes.

BEGIN;

-- Optimized integrity verification using JOIN + spatial index
-- Strategy:
-- 1. JOIN with assigned country to check if it still contains the point (fast path - 95% of cases)
-- 2. For notes that don't match, use LATERAL JOIN with spatial index to find actual country
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
-- Fast path: Check if assigned country still contains the point (uses primary key)
assigned_country_check AS (
  SELECT ntv.note_id,
         ntv.id_country AS current_country,
         ntv.longitude,
         ntv.latitude,
         CASE
           WHEN ST_Contains(c.geom, ST_SetSRID(ST_Point(ntv.longitude, ntv.latitude), 4326))
           THEN ntv.id_country
           ELSE NULL
         END AS verified_country
  FROM notes_to_verify ntv
  INNER JOIN countries c ON c.country_id = ntv.id_country
),
-- Slow path: For notes that don't match, use LATERAL JOIN with spatial index
verified AS (
  SELECT 
    acc.note_id,
    acc.current_country,
    COALESCE(
      acc.verified_country,
      -- Use spatial index via LATERAL JOIN (only executed for non-matching notes)
      COALESCE(spatial_find.country_id, -1)
    ) AS verified_country
  FROM assigned_country_check acc
  LEFT JOIN LATERAL (
    SELECT c.country_id
    FROM countries c
    WHERE ST_Contains(c.geom, ST_SetSRID(ST_Point(acc.longitude, acc.latitude), 4326))
    LIMIT 1
  ) spatial_find ON acc.verified_country IS NULL
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
