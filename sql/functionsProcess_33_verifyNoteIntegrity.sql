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
-- Version: 2025-11-28
--
-- Note: Optimized to remove unnecessary self-join. Direct UPDATE with JOIN to countries.
-- All geometries in countries table have SRID 4326, so no SRID normalization needed.

DO $$
DECLARE
  invalidated_count INTEGER;
BEGIN
  -- Update notes that don't belong to assigned country
  -- Optimized: Direct UPDATE without self-join
  -- All countries.geom have SRID 4326, so use directly without SRID checks
  -- Only process notes with valid coordinates (longitude and latitude not NULL)
  UPDATE notes /* Notes-integrity check parallel */
  SET id_country = NULL
  FROM countries c
  WHERE notes.id_country = c.country_id
    AND notes.id_country IS NOT NULL
    AND notes.longitude IS NOT NULL
    AND notes.latitude IS NOT NULL
    AND ${SUB_START} <= notes.note_id AND notes.note_id < ${SUB_END}
    AND NOT ST_Contains(
      c.geom,
      ST_SetSRID(ST_Point(notes.longitude, notes.latitude), 4326)
    );
  
  -- Get count of affected rows
  GET DIAGNOSTICS invalidated_count = ROW_COUNT;
  
  -- Store in a temporary way to return it
  PERFORM set_config('app.invalidated_count', invalidated_count::text, false);
END $$;

-- Return the count
SELECT current_setting('app.invalidated_count')::INTEGER;
