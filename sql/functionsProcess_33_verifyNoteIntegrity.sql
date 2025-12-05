-- Verifies note integrity by checking if coordinates belong to assigned country.
-- This directly verifies if coordinates belong to a specific country.
--
-- Parameters:
--   ${SUB_START} - Start of note_id range (inclusive)
--   ${SUB_END} - End of note_id range (exclusive)
--
-- Returns:
--   COUNT(*) of invalidated notes (notes that don't belong to assigned country)
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-12-05

DO $$
DECLARE
  invalidated_count INTEGER;
BEGIN
  -- Update notes that don't belong to assigned country
  -- OPTIMIZED: Use EXISTS with correlated subquery to force efficient lookup
  -- This approach:
  -- 1. Filters notes by range first (uses index on note_id)
  -- 2. For each note, looks up ONLY its assigned country using PK (very fast)
  -- 3. Evaluates ST_Contains only for that specific country geometry
  -- This avoids Hash Join which loads all 276 geometries (183 MB) into memory
  -- Optimized: geom already has SRID 4326, no need for ST_SetSRID
  -- Only ST_Point needs SRID set since it creates a point without SRID
  -- Performance: Should be 50-100x faster than Hash Join approach
  UPDATE notes /* Notes-integrity check parallel */
  SET id_country = NULL
  WHERE notes.id_country IS NOT NULL
    AND notes.longitude IS NOT NULL
    AND notes.latitude IS NOT NULL
    AND ${SUB_START} <= notes.note_id AND notes.note_id < ${SUB_END}
    AND EXISTS (
      SELECT 1
      FROM countries c
      WHERE c.country_id = notes.id_country
        AND NOT ST_Contains(
          c.geom,
          ST_SetSRID(ST_Point(notes.longitude, notes.latitude), 4326)
        )
    );
  
  -- Get count of affected rows
  GET DIAGNOSTICS invalidated_count = ROW_COUNT;
  
  -- Store in a temporary way to return it
  PERFORM set_config('app.invalidated_count', invalidated_count::text, false);
END $$;

-- Return the count
SELECT current_setting('app.invalidated_count')::INTEGER;
