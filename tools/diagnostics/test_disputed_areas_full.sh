#!/bin/bash
# Test the complete disputed and unclaimed areas view query
# on production server (read-only test)
#
# Author: Andres Gomez (AngocA)
# Version: 2025-01-23

set -euo pipefail

# Configuration
SERVER="${SERVER:-192.168.0.7}"
DBNAME="${DBNAME:-notes}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
  local COLOR=$1
  local MESSAGE=$2
  echo -e "${COLOR}${MESSAGE}${NC}"
}

# Create query file on remote server
ssh "${SERVER}" "cat > /tmp/test_view_query.sql << 'VIEWQUERY'
-- Test query for disputed and unclaimed areas
WITH
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
  world_bounds AS (
    SELECT
      ST_MakeEnvelope(-180, -90, 180, 90, 4326) AS geom
  ),
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
      country_name_en NOT LIKE '%(%)%'
      AND ST_GeometryType(geom) IN ('ST_Polygon', 'ST_MultiPolygon')
      AND geom IS NOT NULL
      AND NOT ST_IsEmpty(geom)
  ),
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
SELECT COUNT(*) FROM all_areas;
VIEWQUERY
" > /dev/null

print_status "${BLUE}" "Testing complete view query on production server..."
print_status "${YELLOW}" "⚠️  This may take several minutes due to expensive operations..."

START_TIME=$(date +%s)
RESULT=$(ssh "${SERVER}" "timeout 600 psql -d '${DBNAME}' -f /tmp/test_view_query.sql 2>&1" || echo "ERROR")
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

ssh "${SERVER}" "rm -f /tmp/test_view_query.sql" 2>/dev/null || true

if echo "${RESULT}" | grep -q "ERROR"; then
  print_status "${RED}" "❌ Query execution failed:"
  echo "${RESULT}"
  exit 1
else
  COUNT=$(echo "${RESULT}" | tail -1 | tr -d ' ')
  print_status "${GREEN}" "✅ Query executed successfully!"
  print_status "${BLUE}" "   Total areas found: ${COUNT}"
  print_status "${BLUE}" "   Execution time: ${DURATION} seconds"
  
  if [[ "${DURATION}" -gt 300 ]]; then
    print_status "${YELLOW}" "   ⚠️  Query took more than 5 minutes - consider using materialized view"
  fi
fi

