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
-- Version: 2025-12-29
--
-- SOLUTION: Divide world into ocean regions to avoid precision issues
-- PostGIS ST_Difference can fail with very large global geometries
-- By calculating each ocean region separately, we ensure accurate results
-- Regions: Pacific (west/east/central), Atlantic (west/east), Indian, Arctic, Southern

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
  ST_SetSRID(ST_MakePoint(0, 0), 4326),
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
  -- Fix SRID issues, validate and repair geometries before union
  -- CRITICAL: ST_MakeValid ensures geometries are valid before ST_Union
  -- This prevents silent failures when invalid geometries cause union to fail
  valid_countries AS (
    SELECT
      ST_MakeValid(
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
      ST_GeometryType(geom) IN ('ST_Polygon', 'ST_MultiPolygon')
      AND geom IS NOT NULL
      AND NOT ST_IsEmpty(geom)
  ),
  -- Step 3: Union all country geometries
  -- CRITICAL FIX: Use ST_Collect + ST_UnaryUnion for better performance with large datasets
  -- This approach is more robust when dealing with many large geometries (maritime zones)
  -- ST_Collect groups geometries efficiently, then ST_UnaryUnion merges them
  -- This ensures all maritime zones (Australia, Colombia, South Africa, NZ, etc.)
  -- are properly included in the union before subtraction
  -- IMPORTANT: We collect ALL geometries first, then union them in one operation
  -- This prevents missing geometries when ST_Union fails with too many inputs
  all_countries_collected AS (
    SELECT
      ST_Collect(geom) AS geom
    FROM
      valid_countries
    WHERE
      geom IS NOT NULL
      AND NOT ST_IsEmpty(geom)
  ),
  all_countries_union AS (
    SELECT
      ST_MakeValid(ST_UnaryUnion(geom)) AS geom
    FROM
      all_countries_collected
    WHERE
      geom IS NOT NULL
  ),
  -- Step 4: Calculate international waters (world - all countries)
  -- CRITICAL FIX: Divide world into ocean regions to avoid precision issues
  -- PostGIS ST_Difference can fail silently with very large global geometries
  -- By splitting into ocean regions, we calculate each region separately
  -- This ensures all maritime zones are properly subtracted
  -- Define ocean regions - use fewer, larger regions for better performance
  -- Split only where necessary to avoid 180°/-180° meridian issues
  ocean_regions AS (
    SELECT 'pacific' AS region, ST_SetSRID(ST_MakeEnvelope(-180, -60, -70, 60, 4326), 4326) AS geom
    UNION ALL
    SELECT 'atlantic' AS region, ST_SetSRID(ST_MakeEnvelope(-100, -60, 20, 80, 4326), 4326) AS geom
    UNION ALL
    SELECT 'indian' AS region, ST_SetSRID(ST_MakeEnvelope(20, -60, 120, 30, 4326), 4326) AS geom
    UNION ALL
    SELECT 'pacific_east' AS region, ST_SetSRID(ST_MakeEnvelope(120, -60, -180, 60, 4326), 4326) AS geom
    UNION ALL
    SELECT 'arctic' AS region, ST_SetSRID(ST_MakeEnvelope(-180, 60, 180, 90, 4326), 4326) AS geom
    UNION ALL
    SELECT 'southern' AS region, ST_SetSRID(ST_MakeEnvelope(-180, -90, 180, -60, 4326), 4326) AS geom
  ),
  -- Calculate international waters for each region separately
  -- This avoids precision issues with very large global geometries
  -- Optimized: Calculate difference per region, validate only final result
  international_waters_by_region AS (
    SELECT
      or_reg.region,
      CASE
        WHEN acu.geom IS NULL OR ST_IsEmpty(acu.geom) OR NOT ST_Intersects(acu.geom, or_reg.geom) THEN
          or_reg.geom
        ELSE
          -- Calculate difference: region minus intersecting countries
          -- Intersect countries with region first to reduce complexity
          ST_MakeValid(
            ST_Difference(
              or_reg.geom,
              ST_Intersection(acu.geom, or_reg.geom)
            )
          )
      END AS geom
    FROM
      ocean_regions or_reg
      CROSS JOIN all_countries_union acu
    WHERE
      acu.geom IS NOT NULL
      AND NOT ST_IsEmpty(acu.geom)
  ),
  international_waters_raw AS (
    SELECT
      ST_Union(geom) AS geom
    FROM
      international_waters_by_region
    WHERE
      geom IS NOT NULL
      AND NOT ST_IsEmpty(geom)
  ),
  -- Step 5: Extract individual polygons from each region separately
  -- Process each region independently to avoid UNION issues with large geometries
  international_waters_by_region_dumped AS (
    SELECT
      iwr.region,
      (ST_Dump(iwr.geom)).geom AS polygon_geom
    FROM
      international_waters_by_region iwr
    WHERE
      iwr.geom IS NOT NULL
      AND NOT ST_IsEmpty(iwr.geom)
  ),
  international_waters_filtered AS (
    SELECT
      region,
      polygon_geom,
      ST_Area(polygon_geom::geography) / (111000.0 * 111000.0) AS area_sq_degrees
    FROM
      international_waters_by_region_dumped
    WHERE
      ST_GeometryType(polygon_geom) IN ('ST_Polygon', 'ST_MultiPolygon')
      -- Very small minimum size (0.01 square degrees) to capture all areas
      -- This ensures we don't lose important international waters areas
      -- Only filters out tiny slivers and precision artifacts
      AND ST_Area(polygon_geom::geography) > 111000.0 * 111000.0 * 0.01  -- Min 0.01 sq degree (~12,321 km²)
  ),
  -- Step 6: Generate names and descriptions for each area
  international_waters_named AS (
    SELECT
      region,
      polygon_geom,
      area_sq_degrees,
      'International Waters - ' || INITCAP(region) || ' ' || ROW_NUMBER() OVER (PARTITION BY region ORDER BY area_sq_degrees DESC) AS area_name,
      'International waters in ' || INITCAP(region) || ' Ocean. Calculated as difference between ocean region and all country areas (terrestrial and maritime). Area: ' ||
      ROUND(area_sq_degrees::numeric, 2) || ' square degrees.' AS area_description
    FROM
      international_waters_filtered
  )
-- Step 7: Insert into international_waters table
-- Insert each region separately to avoid UNION issues
INSERT INTO international_waters (name, description, geom, is_special_point)
SELECT
  area_name,
  area_description,
  polygon_geom,
  FALSE
FROM
  international_waters_named
ORDER BY
  region, area_sq_degrees DESC;

-- ============================================================================
-- DIAGNOSTICS
-- ============================================================================

-- Show diagnostic information about the calculation
DO $$
DECLARE
  v_country_count INTEGER;
  v_maritime_count INTEGER;
  v_union_area NUMERIC;
  v_world_area NUMERIC;
  v_international_area NUMERIC;
BEGIN
  -- Count countries and maritime zones
  SELECT COUNT(*) INTO v_country_count FROM countries WHERE geom IS NOT NULL;
  SELECT COUNT(*) INTO v_maritime_count FROM countries WHERE is_maritime = TRUE AND geom IS NOT NULL;
  
  -- Calculate union area using same method as in the query
  -- This verifies that the union calculation matches what's used in the CTE
  WITH valid_countries AS (
    SELECT ST_MakeValid(
      CASE
        WHEN ST_SRID(geom) = 0 OR ST_SRID(geom) IS NULL THEN
          ST_SetSRID(geom, 4326)
        ELSE
          geom
      END
    ) AS geom
    FROM countries
    WHERE ST_GeometryType(geom) IN ('ST_Polygon', 'ST_MultiPolygon')
      AND geom IS NOT NULL
      AND NOT ST_IsEmpty(geom)
  ),
  all_countries_collected AS (
    SELECT ST_Collect(geom) AS geom
    FROM valid_countries
    WHERE geom IS NOT NULL AND NOT ST_IsEmpty(geom)
  ),
  all_countries_union AS (
    SELECT ST_MakeValid(ST_UnaryUnion(geom)) AS geom
    FROM all_countries_collected
    WHERE geom IS NOT NULL
  )
  SELECT COALESCE(ST_Area(geom::geography) / (111000.0 * 111000.0), 0) INTO v_union_area
  FROM all_countries_union
  WHERE geom IS NOT NULL AND NOT ST_IsEmpty(geom);
  
  v_world_area := 360.0 * 180.0; -- World bounding box area in square degrees
  
  SELECT COALESCE(SUM(ST_Area(geom::geography) / (111000.0 * 111000.0)), 0) INTO v_international_area
  FROM international_waters
  WHERE geom IS NOT NULL AND is_special_point = FALSE;
  
  RAISE NOTICE '=== International Waters Calculation Diagnostics ===';
  RAISE NOTICE 'Total countries (terrestrial + maritime): %', v_country_count;
  RAISE NOTICE 'Maritime zones: %', v_maritime_count;
  RAISE NOTICE 'Union area (all countries): % square degrees', ROUND(v_union_area, 2);
  RAISE NOTICE 'World bounding box area: % square degrees', ROUND(v_world_area, 2);
  RAISE NOTICE 'Calculated international waters area: % square degrees', ROUND(v_international_area, 2);
  RAISE NOTICE 'Expected international waters (world - union): % square degrees', ROUND(v_world_area - v_union_area, 2);
  RAISE NOTICE 'Difference (missing area): % square degrees', ROUND((v_world_area - v_union_area) - v_international_area, 2);
  RAISE NOTICE '';
  RAISE NOTICE 'Calculation method: Ocean regions (Pacific, Atlantic, Indian, Arctic, Southern)';
  RAISE NOTICE 'This approach avoids precision issues with very large global geometries';
END $$;

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

