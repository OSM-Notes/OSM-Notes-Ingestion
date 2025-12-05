-- Calculates and inserts international waters areas by computing the difference
-- between the world ocean and all country areas (terrestrial and maritime).
-- This creates precise polygons that exclude any land or claimed maritime zones.
--
-- Strategy:
-- 1. Create world bounding box (covers entire globe)
-- 2. Union all country geometries (terrestrial + maritime)
-- 3. Calculate difference (world - all countries) = international waters
-- 4. Filter large ocean areas (exclude small coastal gaps)
-- 5. Split into manageable polygons and insert
--
-- Usage:
--   psql -d notes -f sql/process/processPlanetNotes_28_addInternationalWatersExamples.sql
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-12-05

-- Ensure the table exists (for backward compatibility)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_name = 'international_waters'
  ) THEN
    RAISE EXCEPTION 'Table international_waters does not exist. Please run processPlanetNotes_27_createInternationalWatersTable.sql first.';
  END IF;
END $$;

-- ============================================================================
-- SPECIAL POINTS
-- ============================================================================

-- Null Island (0, 0) - Gulf of Guinea
-- Commonly used as placeholder for missing coordinates
INSERT INTO international_waters (name, description, point_coords, is_special_point)
VALUES (
  'Null Island',
  'Point 0,0 in Gulf of Guinea - commonly used as placeholder for missing coordinates',
  ST_SetSRID(ST_MakePoint(0, 0), 4326)::POINT,
  TRUE
) ON CONFLICT DO NOTHING;

-- ============================================================================
-- CALCULATE INTERNATIONAL WATERS (Precise polygons)
-- ============================================================================

-- Delete existing polygon areas (keep special points)
DELETE FROM international_waters
WHERE is_special_point = FALSE AND geom IS NOT NULL;

-- Calculate international waters as difference between world and all countries
-- This includes both terrestrial and maritime zones
WITH
  -- Step 1: Create world bounding box
  world_bounds AS (
    SELECT
      ST_SetSRID(ST_MakeEnvelope(-180, -90, 180, 90, 4326), 4326) AS geom
  ),
  -- Step 2: Get all valid country geometries (terrestrial + maritime)
  -- Fix SRID issues and filter valid geometries
  valid_countries AS (
    SELECT
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
  -- Step 3: Union all country geometries
  all_countries_union AS (
    SELECT
      ST_Union(geom) AS geom
    FROM
      valid_countries
  ),
  -- Step 4: Calculate international waters (world - all countries)
  international_waters_raw AS (
    SELECT
      ST_Difference(
        wb.geom,
        COALESCE(acu.geom, ST_GeomFromText('POLYGON EMPTY', 4326))
      ) AS geom
    FROM
      world_bounds wb
      CROSS JOIN all_countries_union acu
  ),
  -- Step 5: Extract individual polygons and filter by size
  -- Only keep large ocean areas (minimum 1 square degree)
  -- This excludes small coastal gaps and inland areas
  international_waters_dumped AS (
    SELECT
      (ST_Dump(geom)).geom AS polygon_geom
    FROM
      international_waters_raw
    WHERE
      geom IS NOT NULL
      AND NOT ST_IsEmpty(geom)
  ),
  international_waters_filtered AS (
    SELECT
      polygon_geom,
      ST_Area(polygon_geom::geography) / (111000.0 * 111000.0) AS area_sq_degrees
    FROM
      international_waters_dumped
    WHERE
      ST_GeometryType(polygon_geom) IN ('ST_Polygon', 'ST_MultiPolygon')
      AND ST_Area(polygon_geom::geography) > 111000.0 * 111000.0  -- Min 1 sq degree
  ),
  -- Step 6: Generate names and descriptions for each area
  international_waters_named AS (
    SELECT
      polygon_geom,
      area_sq_degrees,
      'International Waters ' || ROW_NUMBER() OVER (ORDER BY area_sq_degrees DESC) AS area_name,
      'International waters area calculated as difference between world ocean and all country areas (terrestrial and maritime). Area: ' ||
      ROUND(area_sq_degrees::numeric, 2) || ' square degrees.' AS area_description
    FROM
      international_waters_filtered
  )
-- Step 7: Insert into international_waters table
INSERT INTO international_waters (name, description, geom, is_special_point)
SELECT
  area_name,
  area_description,
  polygon_geom,
  FALSE
FROM
  international_waters_named
ORDER BY
  area_sq_degrees DESC;

-- ============================================================================
-- SUMMARY
-- ============================================================================

-- Show summary of inserted international waters
SELECT
  COUNT(*) AS total_areas,
  COUNT(CASE WHEN is_special_point THEN 1 END) AS special_points,
  COUNT(CASE WHEN geom IS NOT NULL THEN 1 END) AS polygon_areas,
  ROUND(SUM(CASE WHEN geom IS NOT NULL THEN ST_Area(geom::geography) / (111000.0 * 111000.0) ELSE 0 END)::numeric, 2) AS total_area_sq_degrees
FROM
  international_waters;

