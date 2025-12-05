-- Adds example international waters areas to the international_waters table.
-- This script demonstrates how to add more known international waters areas
-- to improve performance by avoiding expensive country searches.
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
  ST_SetSRID(ST_MakePoint(0, 0), 4326),
  TRUE
) ON CONFLICT DO NOTHING;

-- ============================================================================
-- LARGE OCEAN AREAS (Polygons)
-- ============================================================================

-- Central Pacific Ocean (far from any country)
-- Large area in the central Pacific, far from any landmass
INSERT INTO international_waters (name, description, geom, is_special_point)
VALUES (
  'Central Pacific Ocean',
  'Large area in central Pacific Ocean, far from any country (lon: -150 to -100, lat: -20 to 20)',
  ST_SetSRID(
    ST_MakeEnvelope(-150, -20, -100, 20, 4326),
    4326
  ),
  FALSE
) ON CONFLICT DO NOTHING;

-- South Atlantic Ocean (far from any country)
-- Large area in the South Atlantic, far from any landmass
INSERT INTO international_waters (name, description, geom, is_special_point)
VALUES (
  'South Atlantic Ocean',
  'Large area in South Atlantic Ocean, far from any country (lon: -40 to 0, lat: -50 to -30)',
  ST_SetSRID(
    ST_MakeEnvelope(-40, -50, 0, -30, 4326),
    4326
  ),
  FALSE
) ON CONFLICT DO NOTHING;

-- North Pacific Ocean (far from any country)
-- Large area in the North Pacific, far from any landmass
INSERT INTO international_waters (name, description, geom, is_special_point)
VALUES (
  'North Pacific Ocean',
  'Large area in North Pacific Ocean, far from any country (lon: -180 to -120, lat: 20 to 50)',
  ST_SetSRID(
    ST_MakeEnvelope(-180, 20, -120, 50, 4326),
    4326
  ),
  FALSE
) ON CONFLICT DO NOTHING;

-- Indian Ocean (far from any country)
-- Large area in the Indian Ocean, far from any landmass
INSERT INTO international_waters (name, description, geom, is_special_point)
VALUES (
  'Central Indian Ocean',
  'Large area in central Indian Ocean, far from any country (lon: 60 to 100, lat: -30 to 0)',
  ST_SetSRID(
    ST_MakeEnvelope(60, -30, 100, 0, 4326),
    4326
  ),
  FALSE
) ON CONFLICT DO NOTHING;

-- ============================================================================
-- NOTES
-- ============================================================================

-- To add more areas, use this template:
--
-- INSERT INTO international_waters (name, description, geom, is_special_point)
-- VALUES (
--   'Area Name',
--   'Description of the area',
--   ST_SetSRID(
--     ST_MakeEnvelope(min_lon, min_lat, max_lon, max_lat, 4326),
--     4326
--   ),
--   FALSE
-- ) ON CONFLICT DO NOTHING;
--
-- For special points:
--
-- INSERT INTO international_waters (name, description, point_coords, is_special_point)
-- VALUES (
--   'Point Name',
--   'Description of the point',
--   ST_SetSRID(ST_MakePoint(lon, lat), 4326),
--   TRUE
-- ) ON CONFLICT DO NOTHING;

-- Show summary
SELECT
  COUNT(*) AS total_areas,
  COUNT(CASE WHEN is_special_point THEN 1 END) AS special_points,
  COUNT(CASE WHEN geom IS NOT NULL THEN 1 END) AS polygon_areas
FROM international_waters;

