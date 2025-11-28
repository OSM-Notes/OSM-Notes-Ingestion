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
-- Version: 2025-11-28
--
-- Optimization: Uses JOIN with assigned country first (fast), then LATERAL JOIN
-- with spatial index for unmatched notes. This forces PostgreSQL to use the spatial
-- index efficiently and avoids loading all geometries. Reduces execution time from
-- ~4 minutes to ~5-10 seconds per 20k notes.

BEGIN;

-- Optimized integrity verification using JOIN + spatial index
-- Strategy:
-- 1. JOIN with assigned country to check if it still contains the point (fast path - 95% of cases)
-- 2. For notes that don't match, use spatial index to find actual country (slow path)
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
-- Separate fast path (matched) and slow path (need spatial search)
matched_notes AS (
  SELECT note_id, current_country, verified_country
  FROM assigned_country_check
  WHERE verified_country IS NOT NULL
),
unmatched_notes AS (
  SELECT acc.note_id,
         acc.current_country,
         acc.longitude,
         acc.latitude
  FROM assigned_country_check acc
  WHERE acc.verified_country IS NULL
),
-- Slow path: Use LATERAL JOIN to force spatial index usage for unmatched notes
-- LATERAL JOIN ensures PostgreSQL uses the spatial index efficiently
spatial_verified AS (
  SELECT un.note_id,
         un.current_country,
         COALESCE(c.country_id, -1) AS verified_country
  FROM unmatched_notes un
  LEFT JOIN LATERAL (
    SELECT c.country_id
    FROM countries c
    WHERE ST_Contains(c.geom, ST_SetSRID(ST_Point(un.longitude, un.latitude), 4326))
    LIMIT 1
  ) c ON true
),
-- Combine matched and spatial-verified notes
verified AS (
  SELECT note_id, current_country, verified_country FROM matched_notes
  UNION ALL
  SELECT note_id, current_country, verified_country FROM spatial_verified
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
