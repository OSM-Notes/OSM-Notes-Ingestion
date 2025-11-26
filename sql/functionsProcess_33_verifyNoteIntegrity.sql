-- Verifies note integrity by checking if coordinates belong to assigned country.
-- This is optimized to directly verify if coordinates belong to a specific country,
-- which is faster than searching for the country from scratch.
--
-- Parameters:
--   ${SUB_START} - Start of note_id range (inclusive)
--   ${SUB_END} - End of note_id range (exclusive)
--
-- Returns:
--   COUNT(*) of invalidated notes (notes that don't belong to assigned country)
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-11-25

BEGIN;

-- Optimized integrity verification: directly check if coordinates belong to assigned country
-- This is faster than calling get_country() because we already know the country
WITH notes_to_verify AS (
SELECT n.note_id,
       n.id_country,
       n.longitude,
       n.latitude
FROM notes AS n
WHERE n.id_country IS NOT NULL
AND ${SUB_START} <= n.note_id AND n.note_id < ${SUB_END}
),
verified AS (
SELECT ntv.note_id,
       ntv.id_country AS current_country,
       CASE
         WHEN ST_Contains(c.geom, ST_SetSRID(ST_Point(ntv.longitude, ntv.latitude), 4326))
         THEN ntv.id_country
         ELSE -1
       END AS verified_country
FROM notes_to_verify ntv
LEFT JOIN countries c ON c.country_id = ntv.id_country
),
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

