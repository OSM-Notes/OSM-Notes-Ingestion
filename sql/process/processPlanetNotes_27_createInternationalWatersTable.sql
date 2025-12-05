-- Creates table for known international waters and special points.
-- This allows early detection of points that don't belong to any country,
-- avoiding expensive spatial queries.
--
-- Strategy:
-- 1. Define known international waters areas (polygons)
-- 2. Define special points (like Null Island 0,0)
-- 3. Check these first before searching all countries
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-12-05

-- Table for international waters and special points
CREATE TABLE IF NOT EXISTS international_waters (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  description TEXT,
  geom GEOMETRY(POLYGON, 4326),
  point_coords GEOMETRY(POINT, 4326),
  -- Special flag for known points (like Null Island)
  is_special_point BOOLEAN DEFAULT FALSE
);
COMMENT ON TABLE international_waters IS
  'Known international waters and special points that don''t belong to any country';
COMMENT ON COLUMN international_waters.name IS
  'Name of the international waters area or special point';
COMMENT ON COLUMN international_waters.description IS
  'Description of the area or point';
COMMENT ON COLUMN international_waters.geom IS
  'Polygon geometry for international waters areas';
COMMENT ON COLUMN international_waters.point_coords IS
  'Point coordinates for special points (like Null Island). Uses SRID 4326 (WGS84) for proper map display.';
COMMENT ON COLUMN international_waters.is_special_point IS
  'True if this is a special point (not a polygon area)';

-- Create spatial index for polygon areas
CREATE INDEX IF NOT EXISTS international_waters_geom_gist ON international_waters
  USING GIST (geom)
  WHERE geom IS NOT NULL;
COMMENT ON INDEX international_waters_geom_gist IS
  'Spatial index for international waters polygons';

-- Create index for special points
CREATE INDEX IF NOT EXISTS international_waters_point_gist ON international_waters
  USING GIST (point_coords)
  WHERE point_coords IS NOT NULL;
COMMENT ON INDEX international_waters_point_gist IS
  'Spatial index for special points';

-- Insert known special points
-- Null Island (0, 0) - Gulf of Guinea
INSERT INTO international_waters (name, description, point_coords, is_special_point)
VALUES (
  'Null Island',
  'Point 0,0 in Gulf of Guinea - commonly used as placeholder for missing coordinates',
  ST_SetSRID(ST_MakePoint(0, 0), 4326),
  TRUE
) ON CONFLICT DO NOTHING;

-- You can add more known international waters areas here
-- Example: Large ocean areas far from any country
-- INSERT INTO international_waters (name, description, geom)
-- VALUES (
--   'Central Pacific Ocean',
--   'Central Pacific Ocean far from any country',
--   ST_SetSRID(ST_MakeEnvelope(-150, -20, -100, 20, 4326), 4326)
-- ) ON CONFLICT DO NOTHING;

COMMENT ON TABLE international_waters IS
  'Known international waters and special points. Check this table first before searching all countries.';

