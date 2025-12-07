-- Modifies Germany's geometry in hybrid test mode to ensure both validation
-- cases are tested (optimized path and full search).
-- This script should be run AFTER countries are loaded from backup.
--
-- Strategy:
--   - If notes are already assigned to Germany, modify based on note distribution
--   - If no notes yet, modify based on Germany's bounding box (will affect future assignments)
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-11-30

DO $$
DECLARE
  germany_exists INTEGER;
  notes_count INTEGER;
  germany_geom GEOMETRY;
BEGIN
  -- Check if Germany (country_id = 51477) exists
  SELECT COUNT(*) INTO germany_exists
  FROM countries
  WHERE country_id = 51477;
  
  IF germany_exists = 0 THEN
    -- Germany doesn't exist, skip modification
    RETURN;
  END IF;
  
  -- Get Germany's geometry
  SELECT geom INTO germany_geom
  FROM countries
  WHERE country_id = 51477;
  
  -- Check if there are notes assigned to Germany
  SELECT COUNT(*) INTO notes_count
  FROM notes
  WHERE id_country = 51477;
  
  IF notes_count > 0 THEN
    -- Modify geometry to cover ~80% of notes (based on their actual distribution)
    WITH note_bounds AS (
      SELECT 
        MIN(longitude) as min_lon,
        MIN(latitude) as min_lat,
        MAX(longitude) as max_lon,
        MAX(latitude) as max_lat,
        AVG(longitude) as center_lon,
        AVG(latitude) as center_lat
      FROM notes
      WHERE id_country = 51477
    )
    UPDATE countries
    SET 
      geom = ST_SetSRID(
        ST_MakeEnvelope(
          center_lon - (max_lon - min_lon) * 0.4,  -- Cover 80% width
          center_lat - (max_lat - min_lat) * 0.4,  -- Cover 80% height
          center_lon + (max_lon - min_lon) * 0.4,
          center_lat + (max_lat - min_lat) * 0.4,
          4326
        ),
        4326
      ),
      updated = TRUE
    FROM note_bounds
    WHERE country_id = 51477;
  ELSE
    -- No notes yet - modify based on Germany's bounding box
    -- Shrink the bounding box by 20% (centered)
    UPDATE countries
    SET 
      geom = ST_SetSRID(
        ST_MakeEnvelope(
          ST_XMin(germany_geom) + (ST_XMax(germany_geom) - ST_XMin(germany_geom)) * 0.1,
          ST_YMin(germany_geom) + (ST_YMax(germany_geom) - ST_YMin(germany_geom)) * 0.1,
          ST_XMax(germany_geom) - (ST_XMax(germany_geom) - ST_XMin(germany_geom)) * 0.1,
          ST_YMax(germany_geom) - (ST_YMax(germany_geom) - ST_YMin(germany_geom)) * 0.1,
          4326
        ),
        4326
      ),
      updated = TRUE
    WHERE country_id = 51477;
  END IF;
  
END $$;

