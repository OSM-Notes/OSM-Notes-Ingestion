-- Installs the method to synchronize notes data with the tables used for WMS.
-- Also creates the view for disputed and unclaimed areas.
--
-- This script assumes that all database objects have been created, including
-- the countries table (i.e., processAPI/processPlanet have been executed).
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-11-30

-- Check if PostGIS extension is available
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'postgis') THEN
    RAISE EXCEPTION 'PostGIS extension is required but not installed. Please install PostGIS first.';
  END IF;
END $$;

-- Check if required columns exist in notes table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'notes' 
    AND column_name IN ('note_id', 'created_at', 'closed_at', 'lon', 'lat')
  ) THEN
    RAISE EXCEPTION 'Required columns (note_id, created_at, closed_at, lon, lat) not found in notes table.';
  END IF;
END $$;

-- Creates an independent schema for all objects related to WMS.
CREATE SCHEMA IF NOT EXISTS wms;
COMMENT ON SCHEMA wms IS 'Objects to publish the WMS layer';

-- Creates another table with only the necessary columns for WMS.
-- Use a more efficient approach with WHERE clause to avoid processing all records
CREATE TABLE IF NOT EXISTS wms.notes_wms AS
 SELECT /* Notes-WMS */
  note_id,
  extract(year from created_at) AS year_created_at,
  extract (year from closed_at) AS year_closed_at,
  ST_SetSRID(ST_MakePoint(lon, lat), 4326) AS geometry
 FROM notes
 WHERE lon IS NOT NULL AND lat IS NOT NULL  -- Only include notes with valid coordinates
;
COMMENT ON TABLE wms.notes_wms IS
  'Locations of the notes and its opening and closing year';
COMMENT ON COLUMN wms.notes_wms.note_id IS 'OSM note id';
COMMENT ON COLUMN wms.notes_wms.year_created_at IS
  'Year when the note was created';
COMMENT ON COLUMN wms.notes_wms.year_closed_at IS
  'Year when the note was closed';
COMMENT ON COLUMN wms.notes_wms.geometry IS 'Location of the note';

-- Index for open notes. The most important.
CREATE INDEX IF NOT EXISTS notes_open ON wms.notes_wms (year_created_at);
COMMENT ON INDEX wms.notes_open IS 'Queries based on creation year';

-- Index for closed notes.
CREATE INDEX IF NOT EXISTS notes_closed ON wms.notes_wms (year_closed_at);
COMMENT ON INDEX wms.notes_closed IS 'Queries based on closed year';

-- Add spatial index for better performance
CREATE INDEX IF NOT EXISTS notes_wms_geometry_idx ON wms.notes_wms USING GIST (geometry);
COMMENT ON INDEX wms.notes_wms_geometry_idx IS 'Spatial index for geometry queries';

-- Function for trigger when inserting new notes.
CREATE OR REPLACE FUNCTION wms.insert_new_notes()
  RETURNS TRIGGER AS
 $$
 BEGIN
  -- Only insert if coordinates are valid
  IF NEW.lon IS NOT NULL AND NEW.lat IS NOT NULL THEN
    INSERT INTO wms.notes_wms
     VALUES
     (
      NEW.note_id,
      EXTRACT(YEAR FROM NEW.created_at),
      EXTRACT(YEAR FROM NEW.closed_at),
      ST_SetSRID(ST_MakePoint(NEW.lon, NEW.lat), 4326)
     )
    ;
  END IF;
  RETURN NEW;
 END;
 $$ LANGUAGE plpgsql
;
COMMENT ON FUNCTION wms.insert_new_notes IS 'Insert new notes for the WMS';

-- Function for trigger when updating notes. This applies for 2 cases:
-- * From open to close (solving).
-- * From close to open (reopening).
-- It is not used when adding a comment.
CREATE OR REPLACE FUNCTION wms.update_notes()
  RETURNS TRIGGER AS
 $$
 BEGIN
  UPDATE wms.notes_wms
   SET year_closed_at = extract (year from NEW.closed_at)
   WHERE note_id = NEW.note_id
  ;
  RETURN NEW;
 END;
 $$ LANGUAGE plpgsql
;
COMMENT ON FUNCTION wms.update_notes IS
  'Updates the closing year of a note when solved';

-- Trigger for new notes.
CREATE OR REPLACE TRIGGER insert_new_notes
  AFTER INSERT ON notes
  FOR EACH ROW
  EXECUTE FUNCTION wms.insert_new_notes()
;
COMMENT ON TRIGGER insert_new_notes ON notes IS
  'Replicates the insertion of a note in the WMS';

-- Trigger for updated notes.
CREATE OR REPLACE TRIGGER update_notes
  AFTER UPDATE ON notes
  FOR EACH ROW
  WHEN (OLD.closed_at IS DISTINCT FROM NEW.closed_at)
  EXECUTE FUNCTION wms.update_notes()
;
COMMENT ON TRIGGER update_notes ON notes IS
  'Replicates the update of a note in the WMS when closed';

-- =============================================================================
-- Create view for disputed and unclaimed areas
-- =============================================================================
-- This view identifies areas where countries overlap (disputed) or gaps
-- between countries (unclaimed).
-- This view is created assuming that the countries table already exists
-- (WMS installation happens after processAPI/processPlanet execution).

-- Check if countries table exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'countries'
  ) THEN
    RAISE EXCEPTION 'Table countries does not exist. Please run processPlanet or processAPI first to create country data.';
  END IF;
END $$;

-- Drop view if exists
DROP VIEW IF EXISTS wms.disputed_and_unclaimed_areas CASCADE;

-- Create materialized view for disputed and unclaimed areas
-- This view is materialized because the query is computationally expensive
-- (ST_Union over all countries, ST_Difference operations).
-- The view should be refreshed after countries are updated (monthly).
-- Use: REFRESH MATERIALIZED VIEW CONCURRENTLY wms.disputed_and_unclaimed_areas;
-- Or run: sql/wms/refreshDisputedAreasView.sql
DROP MATERIALIZED VIEW IF EXISTS wms.disputed_and_unclaimed_areas CASCADE;

CREATE MATERIALIZED VIEW wms.disputed_and_unclaimed_areas AS
WITH
  -- Step 1: Filter valid countries (fix SRID and geometry type issues)
  -- Some countries have SRID 0 or invalid geometry types (GeometryCollection)
  -- Filter and fix these before processing
  valid_countries AS (
    SELECT
      country_id,
      country_name_en,
      CASE
        WHEN ST_SRID(geom) = 0 OR ST_SRID(geom) IS NULL THEN
          ST_SetSRID(geom, 4326)
        ELSE
          geom
      END AS geom
    FROM
      countries
    WHERE
      ST_GeometryType(geom) IN ('ST_Polygon', 'ST_MultiPolygon')
      AND geom IS NOT NULL
      AND NOT ST_IsEmpty(geom)
  ),
  -- Step 2: Find all overlapping areas (disputed zones)
  -- This finds intersections where 2 or more countries overlap
  -- Using a self-join to find pairs of overlapping countries
  -- Optimized: Calculate ST_Intersection only once
  country_pairs AS (
    SELECT
      c1.country_id AS country_id_1,
      c1.country_name_en AS country_name_1,
      c2.country_id AS country_id_2,
      c2.country_name_en AS country_name_2,
      ST_Intersection(c1.geom, c2.geom) AS intersection_geom
    FROM
      valid_countries c1
      INNER JOIN valid_countries c2 ON (
        c1.country_id < c2.country_id
        AND ST_Intersects(c1.geom, c2.geom)
        AND ST_Overlaps(c1.geom, c2.geom)
      )
  ),
  -- Step 3: Extract individual polygons from intersections
  -- Optimized: Filter using the already calculated intersection_geom
  disputed_polygons_raw AS (
    SELECT
      intersection_geom,
      ARRAY[country_id_1, country_id_2] AS country_ids,
      ARRAY[country_name_1, country_name_2] AS country_names
    FROM
      country_pairs
    WHERE
      intersection_geom IS NOT NULL
      AND NOT ST_IsEmpty(intersection_geom)
  ),
  disputed_polygons_dumped AS (
    SELECT
      (ST_Dump(intersection_geom)).geom AS geometry,
      country_ids,
      country_names
    FROM
      disputed_polygons_raw
  ),
  disputed_polygons AS (
    SELECT
      geometry,
      country_ids,
      country_names,
      'disputed' AS area_type
    FROM
      disputed_polygons_dumped
    WHERE
      ST_GeometryType(geometry) = 'ST_Polygon'
      AND ST_Area(geometry) > 0.0001
  ),
  -- Step 4: Create a world bounding box as base polygon
  -- This covers the entire world extent
  world_bounds AS (
    SELECT
      ST_MakeEnvelope(-180, -90, 180, 90, 4326) AS geom
  ),
  -- Step 5: Union all country geometries to get total coverage
  -- Exclude maritime zones (those with parentheses in name) for unclaimed
  -- calculation, as they are intentionally not claimed
  -- Use valid_countries CTE to ensure only valid geometries
  all_countries_union AS (
    SELECT
      ST_Union(
        CASE
          WHEN ST_SRID(geom) = 0 OR ST_SRID(geom) IS NULL THEN
            ST_SetSRID(geom, 4326)
          ELSE
            geom
        END
      ) AS geom
    FROM
      countries
    WHERE
      country_name_en NOT LIKE '%(%)%'  -- Exclude maritime zones
      AND ST_GeometryType(geom) IN ('ST_Polygon', 'ST_MultiPolygon')
      AND geom IS NOT NULL
      AND NOT ST_IsEmpty(geom)
  ),
  -- Step 6: Find unclaimed areas (gaps)
  -- Optimized: Calculate ST_Difference only once, then reuse
  unclaimed_difference_raw AS (
    SELECT
      ST_Difference(
        wb.geom,
        COALESCE(acu.geom, ST_GeomFromText('POLYGON EMPTY', 4326))
      ) AS geom
    FROM
      world_bounds wb
      CROSS JOIN all_countries_union acu
  ),
  unclaimed_difference AS (
    SELECT
      geom
    FROM
      unclaimed_difference_raw
    WHERE
      geom IS NOT NULL
      AND NOT ST_IsEmpty(geom)
  ),
  unclaimed_polygons_dumped AS (
    SELECT
      (ST_Dump(ud.geom)).geom AS geometry
    FROM
      unclaimed_difference ud
  ),
  unclaimed_polygons AS (
    SELECT
      geometry,
      ARRAY[]::INTEGER[] AS country_ids,
      ARRAY[]::VARCHAR[] AS country_names,
      'unclaimed' AS area_type
    FROM
      unclaimed_polygons_dumped
    WHERE
      ST_GeometryType(geometry) = 'ST_Polygon'
      AND ST_Area(geometry) > 0.0001
  ),
  -- Step 7: Combine disputed and unclaimed areas
  all_areas AS (
    SELECT
      geometry,
      country_ids,
      country_names,
      area_type
    FROM
      disputed_polygons
    UNION ALL
    SELECT
      geometry,
      country_ids,
      country_names,
      area_type
    FROM
      unclaimed_polygons
  )
SELECT
  ROW_NUMBER() OVER (ORDER BY area_type, geometry) AS id,
  geometry,
  area_type,
  country_ids,
  country_names,
  -- Helper field for SLD styling (simplified: same as area_type)
  area_type AS zone_type
FROM
  all_areas
WHERE
  geometry IS NOT NULL
  AND NOT ST_IsEmpty(geometry)
  AND ST_Area(geometry) > 0.0001  -- Filter out very small areas (increased threshold)
;

-- Create unique index for CONCURRENT refresh (required for REFRESH MATERIALIZED VIEW CONCURRENTLY)
CREATE UNIQUE INDEX IF NOT EXISTS idx_disputed_unclaimed_areas_id
  ON wms.disputed_and_unclaimed_areas (id);

-- Create index on materialized view for better query performance
CREATE INDEX IF NOT EXISTS idx_disputed_unclaimed_areas_zone_type
  ON wms.disputed_and_unclaimed_areas (zone_type);
CREATE INDEX IF NOT EXISTS idx_disputed_unclaimed_areas_geometry
  ON wms.disputed_and_unclaimed_areas USING GIST (geometry);

COMMENT ON MATERIALIZED VIEW wms.disputed_and_unclaimed_areas IS
  'Areas that are either disputed (overlapping countries) or unclaimed (gaps between countries). This is a materialized view that should be refreshed after countries are updated (monthly).';
COMMENT ON COLUMN wms.disputed_and_unclaimed_areas.id IS
  'Unique identifier for each area';
COMMENT ON COLUMN wms.disputed_and_unclaimed_areas.geometry IS
  'Polygon geometry of the disputed or unclaimed area';
COMMENT ON COLUMN wms.disputed_and_unclaimed_areas.area_type IS
  'Type of area: disputed (overlapping countries) or unclaimed (gaps)';
COMMENT ON COLUMN wms.disputed_and_unclaimed_areas.country_ids IS
  'Array of country IDs involved in the dispute (empty for unclaimed areas)';
COMMENT ON COLUMN wms.disputed_and_unclaimed_areas.country_names IS
  'Array of country names involved in the dispute (empty for unclaimed areas)';
COMMENT ON COLUMN wms.disputed_and_unclaimed_areas.zone_type IS
  'Helper field for SLD styling: disputed or unclaimed';

