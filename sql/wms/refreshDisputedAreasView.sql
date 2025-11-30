-- Refresh materialized view for disputed and unclaimed areas
-- This script should be executed after countries are updated
-- (typically monthly when updateCountries.sh runs)
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-11-30

-- Check if materialized view exists before refreshing
-- If it doesn't exist, the refresh will fail with a clear error message
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_matviews
    WHERE schemaname = 'wms'
    AND matviewname = 'disputed_and_unclaimed_areas'
  ) THEN
    RAISE EXCEPTION 'Materialized view wms.disputed_and_unclaimed_areas does not exist. Please run sql/wms/prepareDatabase.sql first.';
  END IF;
END $$;

-- Refresh the materialized view
-- This operation may take several minutes due to expensive ST_Union operations
REFRESH MATERIALIZED VIEW CONCURRENTLY wms.disputed_and_unclaimed_areas;

-- Update statistics for better query planning
ANALYZE wms.disputed_and_unclaimed_areas;

