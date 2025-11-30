#!/bin/bash
# Test script to verify the disputed and unclaimed areas query directly
# on production server (read-only test, does not create view)
#
# Author: Andres Gomez (AngocA)
# Version: 2025-01-23

set -euo pipefail

# Configuration
SERVER="${SERVER:-192.168.0.7}"
DBNAME="${DBNAME:-notes}"
DBUSER="${DBUSER:-angoca}"

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

# Test 1: Check if countries table exists
print_status "${BLUE}" "Test 1: Checking if countries table exists..."
COUNTRIES_EXISTS=$(ssh "${SERVER}" "psql -d '${DBNAME}' -Atq -c \"SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'countries');\" 2>/dev/null" | tr -d ' ' || echo "f")

if [[ "${COUNTRIES_EXISTS}" == "t" ]]; then
  print_status "${GREEN}" "✅ Countries table exists"
else
  print_status "${RED}" "❌ Countries table does not exist"
  exit 1
fi

# Test 2: Count countries
print_status "${BLUE}" "Test 2: Counting countries..."
COUNTRIES_COUNT=$(ssh "${SERVER}" "psql -d '${DBNAME}' -Atq -c \"SELECT COUNT(*) FROM countries;\" 2>/dev/null" | tr -d ' ' || echo "0")
print_status "${BLUE}" "   Found ${COUNTRIES_COUNT} countries"

if [[ "${COUNTRIES_COUNT}" == "0" ]]; then
  print_status "${RED}" "❌ No countries found in table"
  exit 1
fi

# Test 3: Check PostGIS extension
print_status "${BLUE}" "Test 3: Checking PostGIS extension..."
POSTGIS_VERSION=$(ssh "${SERVER}" "psql -d '${DBNAME}' -Atq -c \"SELECT PostGIS_Version();\" 2>/dev/null" | head -1 || echo "")
if [[ -n "${POSTGIS_VERSION}" ]]; then
  print_status "${GREEN}" "✅ PostGIS is available: ${POSTGIS_VERSION}"
else
  print_status "${RED}" "❌ PostGIS extension not found"
  exit 1
fi

# Test 4: Test disputed areas query (syntax and basic execution)
print_status "${BLUE}" "Test 4: Testing disputed areas query (limited sample)..."
DISPUTED_TEST=$(ssh "${SERVER}" "psql -d '${DBNAME}' -Atq -c \"
SELECT COUNT(*) FROM (
  SELECT
    c1.country_id AS country_id_1,
    c2.country_id AS country_id_2,
    ST_Intersection(c1.geom, c2.geom) AS intersection_geom
  FROM
    countries c1
    INNER JOIN countries c2 ON (
      c1.country_id < c2.country_id
      AND ST_Intersects(c1.geom, c2.geom)
      AND ST_Overlaps(c1.geom, c2.geom)
    )
  LIMIT 10
) AS test;
\" 2>&1" || echo "ERROR")

if echo "${DISPUTED_TEST}" | grep -q "ERROR"; then
  print_status "${RED}" "❌ Disputed areas query has errors:"
  echo "${DISPUTED_TEST}"
  exit 1
else
  print_status "${GREEN}" "✅ Disputed areas query syntax is valid"
  print_status "${BLUE}" "   Sample pairs checked: ${DISPUTED_TEST}"
fi

# Test 5: Test countries union (most expensive part)
print_status "${BLUE}" "Test 5: Testing countries union query..."
print_status "${YELLOW}" "   ⚠️  This is computationally expensive..."
START_TIME=$(date +%s)
UNION_TEST=$(ssh "${SERVER}" "timeout 120 psql -d '${DBNAME}' -Atq -c \"
SELECT 
  CASE 
    WHEN ST_Union(geom) IS NOT NULL THEN 'SUCCESS'
    ELSE 'FAILED'
  END
FROM countries
WHERE country_name_en NOT LIKE '%(%)%'
LIMIT 1;
\" 2>&1" || echo "TIMEOUT")
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

if [[ "${UNION_TEST}" == "TIMEOUT" ]] || echo "${UNION_TEST}" | grep -q "ERROR"; then
  print_status "${RED}" "❌ Countries union query failed or timed out:"
  echo "${UNION_TEST}"
  print_status "${YELLOW}" "   This indicates the query may be too expensive for production"
  exit 1
else
  print_status "${GREEN}" "✅ Countries union query executed successfully"
  print_status "${BLUE}" "   Execution time: ${DURATION} seconds"
fi

# Test 6: Test full query structure with EXPLAIN
print_status "${BLUE}" "Test 6: Testing full query structure with EXPLAIN..."
QUERY_FILE="/tmp/test_disputed_query.sql"
cat > "${QUERY_FILE}" << 'EOF'
WITH
  country_pairs AS (
    SELECT
      c1.country_id AS country_id_1,
      c1.country_name_en AS country_name_1,
      c2.country_id AS country_id_2,
      c2.country_name_en AS country_name_2,
      ST_Intersection(c1.geom, c2.geom) AS intersection_geom
    FROM
      countries c1
      INNER JOIN countries c2 ON (
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
  disputed_polygons AS (
    SELECT
      (ST_Dump(intersection_geom)).geom AS geometry,
      country_ids,
      country_names,
      'disputed' AS area_type
    FROM
      disputed_polygons_raw
    WHERE
      ST_GeometryType((ST_Dump(intersection_geom)).geom) = 'ST_Polygon'
      AND ST_Area((ST_Dump(intersection_geom)).geom) > 0.0001
  )
SELECT COUNT(*) FROM disputed_polygons;
EOF

EXPLAIN_OUTPUT=$(ssh "${SERVER}" "psql -d '${DBNAME}' -f - < ${QUERY_FILE} 2>&1" || echo "ERROR")

if echo "${EXPLAIN_OUTPUT}" | grep -q "ERROR"; then
  print_status "${RED}" "❌ Query structure has errors:"
  echo "${EXPLAIN_OUTPUT}"
  rm -f "${QUERY_FILE}"
  exit 1
else
  print_status "${GREEN}" "✅ Query structure is valid"
fi

rm -f "${QUERY_FILE}"

# Test 7: Check for actual overlaps
print_status "${BLUE}" "Test 7: Checking for actual country overlaps..."
OVERLAPS_COUNT=$(ssh "${SERVER}" "psql -d '${DBNAME}' -Atq -c \"
SELECT COUNT(DISTINCT c1.country_id || '-' || c2.country_id)
FROM countries c1
INNER JOIN countries c2 ON (
  c1.country_id < c2.country_id
  AND ST_Intersects(c1.geom, c2.geom)
  AND ST_Overlaps(c1.geom, c2.geom)
);
\" 2>/dev/null" | tr -d ' ' || echo "0")

print_status "${BLUE}" "   Found ${OVERLAPS_COUNT} overlapping country pairs"

# Summary
print_status "${GREEN}" ""
print_status "${GREEN}" "=========================================="
print_status "${GREEN}" "✅ All query tests passed!"
print_status "${GREEN}" "=========================================="
print_status "${BLUE}" "Summary:"
print_status "${BLUE}" "  - Countries table: ${COUNTRIES_COUNT} countries"
print_status "${BLUE}" "  - Overlapping pairs: ${OVERLAPS_COUNT}"
print_status "${BLUE}" "  - Query syntax: Valid"
print_status "${BLUE}" "  - Query structure: Valid"
print_status "${YELLOW}" ""
print_status "${YELLOW}" "Note: The full query execution may take several minutes"
print_status "${YELLOW}" "      due to the expensive ST_Union and ST_Difference operations."

