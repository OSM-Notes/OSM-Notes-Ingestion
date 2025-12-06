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
  country_rec RECORD;
  notes_in_country INTEGER;
BEGIN
  invalidated_count := 0;
  
  -- OPTIMIZED: Process country by country to avoid loading all geometries
  -- Strategy:
  -- 1. Loop through each country that has notes in this range
  -- 2. For each country, get its geometry ONCE
  -- 3. Update all notes for that country in one batch
  -- 4. This avoids Hash Join and loads only one geometry at a time
  -- Performance: Much faster because we process by country, not by note
  
  FOR country_rec IN 
    SELECT DISTINCT c.country_id, c.geom
    FROM countries c
    INNER JOIN notes n ON n.id_country = c.country_id
    WHERE n.id_country IS NOT NULL
      AND n.longitude IS NOT NULL
      AND n.latitude IS NOT NULL
      AND ${SUB_START} <= n.note_id AND n.note_id < ${SUB_END}
  LOOP
    -- Update notes for this specific country
    -- This approach loads only ONE geometry at a time
    WITH notes_to_check AS (
      SELECT note_id, longitude, latitude
      FROM notes
      WHERE id_country = country_rec.country_id
        AND longitude IS NOT NULL
        AND latitude IS NOT NULL
        AND ${SUB_START} <= note_id AND note_id < ${SUB_END}
    )
    UPDATE notes
    SET id_country = NULL
    FROM notes_to_check ntc
    WHERE notes.note_id = ntc.note_id
      AND NOT ST_Contains(
        country_rec.geom,
        ST_SetSRID(ST_Point(ntc.longitude, ntc.latitude), 4326)
      );
    
    GET DIAGNOSTICS notes_in_country = ROW_COUNT;
    invalidated_count := invalidated_count + notes_in_country;
  END LOOP;
  
  -- invalidated_count already contains the total from the loop
  
  -- Store in a temporary way to return it
  PERFORM set_config('app.invalidated_count', invalidated_count::text, false);
END $$;

-- Return the count
SELECT current_setting('app.invalidated_count')::INTEGER;
