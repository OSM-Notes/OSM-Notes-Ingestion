-- Optimizes spatial indexes for countries table to improve bounding box queries.
-- Creates functional index on bounding boxes for faster ST_Intersects queries.
--
-- Problem: Current query uses ST_MakeEnvelope(ST_XMin(geom), ...) which requires
-- calculating bounding box for each row, preventing efficient index usage.
--
-- Solution: Create functional index on bounding box geometry for faster lookups.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-11-28

-- Create functional index on bounding box geometry
-- This allows PostgreSQL to use the index for ST_Intersects queries with points
-- Index: countries_bbox_gist (ST_MakeEnvelope(...)) - GIST Functional Index
-- Benefits: Ingestion (optimizes queries using ST_Intersects with points, faster country lookups by bounding box)
-- Used by: Queries that use bounding boxes for country intersection checks, optimizes get_country() function
CREATE INDEX IF NOT EXISTS countries_bbox_gist ON countries
  USING GIST (
    ST_MakeEnvelope(
      ST_XMin(geom),
      ST_YMin(geom),
      ST_XMax(geom),
      ST_YMax(geom),
      4326
    )
  );
COMMENT ON INDEX countries_bbox_gist IS
  'Spatial index on bounding boxes for faster ST_Intersects queries with points. Used by: Ingestion (get_country() bounding box optimization)';

-- Alternative: Create expression index using ST_Envelope (bounding box as geometry)
-- This is more efficient than full geometry and works with GIST
-- ST_Envelope returns the bounding box as a polygon geometry
-- Index: countries_bbox_box2d (ST_Envelope(geom)) - GIST Expression Index
-- Benefits: Ingestion (additional optimization for queries using Box2D operators, faster bounding box intersection searches)
-- Used by: Queries using Box2D intersection operators, alternative optimization for bounding box queries
CREATE INDEX IF NOT EXISTS countries_bbox_box2d ON countries
  USING GIST (ST_Envelope(geom));
COMMENT ON INDEX countries_bbox_box2d IS
  'Spatial index on bounding boxes using ST_Envelope for faster ST_Intersects queries. Used by: Ingestion (Box2D operator optimization)';

-- Update table statistics to help query planner
ANALYZE countries;

