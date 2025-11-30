#!/bin/bash
# Test script to verify the disputed and unclaimed areas view query
# on production server (read-only test)
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

# Test 1: Check if view exists
print_status "${BLUE}" "Test 1: Checking if view exists..."
VIEW_EXISTS=$(ssh "${SERVER}" "psql -d '${DBNAME}' -Atq -c \"SELECT EXISTS(SELECT 1 FROM information_schema.views WHERE table_schema = 'wms' AND table_name = 'disputed_and_unclaimed_areas');\" 2>/dev/null" | tr -d ' ' || echo "f")

if [[ "${VIEW_EXISTS}" == "t" ]]; then
  print_status "${GREEN}" "✅ View exists"
else
  print_status "${RED}" "❌ View does not exist"
  print_status "${YELLOW}" "The view needs to be created first using: sql/wms/prepareDatabase.sql"
  exit 1
fi

# Test 2: Check if countries table exists
print_status "${BLUE}" "Test 2: Checking if countries table exists..."
COUNTRIES_EXISTS=$(ssh "${SERVER}" "psql -d '${DBNAME}' -Atq -c \"SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'countries');\" 2>/dev/null" | tr -d ' ' || echo "f")

if [[ "${COUNTRIES_EXISTS}" == "t" ]]; then
  print_status "${GREEN}" "✅ Countries table exists"
else
  print_status "${RED}" "❌ Countries table does not exist"
  exit 1
fi

# Test 3: Count countries
print_status "${BLUE}" "Test 3: Counting countries..."
COUNTRIES_COUNT=$(ssh "${SERVER}" "psql -d '${DBNAME}' -Atq -c \"SELECT COUNT(*) FROM countries;\" 2>/dev/null" | tr -d ' ' || echo "0")
print_status "${BLUE}" "   Found ${COUNTRIES_COUNT} countries"

# Test 4: Test disputed areas query (limited to check syntax)
print_status "${BLUE}" "Test 4: Testing disputed areas query (syntax check)..."
DISPUTED_SYNTAX_OK=$(ssh "${SERVER}" "psql -d '${DBNAME}' -Atq -c \"SELECT COUNT(*) FROM (SELECT c1.country_id, c2.country_id FROM countries c1 INNER JOIN countries c2 ON (c1.country_id < c2.country_id AND ST_Intersects(c1.geom, c2.geom) AND ST_Overlaps(c1.geom, c2.geom)) LIMIT 1) AS test;\" 2>&1" | grep -c "ERROR" || echo "0")

if [[ "${DISPUTED_SYNTAX_OK}" == "0" ]]; then
  print_status "${GREEN}" "✅ Disputed areas query syntax is valid"
else
  print_status "${RED}" "❌ Disputed areas query has syntax errors"
  exit 1
fi

# Test 5: Test full view query (with EXPLAIN to check performance, no execution)
print_status "${BLUE}" "Test 5: Testing view query with EXPLAIN (performance check)..."
EXPLAIN_OUTPUT=$(ssh "${SERVER}" "psql -d '${DBNAME}' -Atq -c \"EXPLAIN SELECT COUNT(*) FROM wms.disputed_and_unclaimed_areas;\" 2>&1" || echo "ERROR")

if echo "${EXPLAIN_OUTPUT}" | grep -q "ERROR"; then
  print_status "${RED}" "❌ View query has errors:"
  echo "${EXPLAIN_OUTPUT}"
  exit 1
else
  print_status "${GREEN}" "✅ View query is valid"
  print_status "${BLUE}" "   Query plan:"
  echo "${EXPLAIN_OUTPUT}" | head -20
fi

# Test 6: Count results (actual execution - may take time)
print_status "${BLUE}" "Test 6: Counting results from view (this may take a while)..."
print_status "${YELLOW}" "   ⚠️  This is a computationally expensive query..."
START_TIME=$(date +%s)
RESULTS_COUNT=$(ssh "${SERVER}" "timeout 300 psql -d '${DBNAME}' -Atq -c \"SELECT COUNT(*) FROM wms.disputed_and_unclaimed_areas;\" 2>&1" || echo "TIMEOUT")
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

if [[ "${RESULTS_COUNT}" == "TIMEOUT" ]] || echo "${RESULTS_COUNT}" | grep -q "ERROR"; then
  print_status "${RED}" "❌ Query execution failed or timed out:"
  echo "${RESULTS_COUNT}"
  exit 1
else
  print_status "${GREEN}" "✅ Query executed successfully"
  print_status "${BLUE}" "   Found ${RESULTS_COUNT} areas"
  print_status "${BLUE}" "   Execution time: ${DURATION} seconds"
fi

# Test 7: Count by type
print_status "${BLUE}" "Test 7: Counting by area type..."
DISPUTED_COUNT=$(ssh "${SERVER}" "psql -d '${DBNAME}' -Atq -c \"SELECT COUNT(*) FROM wms.disputed_and_unclaimed_areas WHERE zone_type = 'disputed';\" 2>/dev/null" | tr -d ' ' || echo "0")
UNCLAIMED_COUNT=$(ssh "${SERVER}" "psql -d '${DBNAME}' -Atq -c \"SELECT COUNT(*) FROM wms.disputed_and_unclaimed_areas WHERE zone_type = 'unclaimed';\" 2>/dev/null" | tr -d ' ' || echo "0")

print_status "${BLUE}" "   Disputed areas: ${DISPUTED_COUNT}"
print_status "${BLUE}" "   Unclaimed areas: ${UNCLAIMED_COUNT}"

# Test 8: Sample data check
print_status "${BLUE}" "Test 8: Sampling data structure..."
SAMPLE=$(ssh "${SERVER}" "psql -d '${DBNAME}' -Atq -F '|' -c \"SELECT id, zone_type, array_length(country_ids, 1) as num_countries FROM wms.disputed_and_unclaimed_areas LIMIT 5;\" 2>/dev/null" || echo "")

if [[ -n "${SAMPLE}" ]]; then
  print_status "${GREEN}" "✅ Sample data retrieved:"
  echo "${SAMPLE}" | while IFS='|' read -r id zone_type num_countries; do
    echo "   ID: ${id}, Type: ${zone_type}, Countries: ${num_countries}"
  done
else
  print_status "${YELLOW}" "⚠️  No sample data available (view might be empty)"
fi

print_status "${GREEN}" "✅ All tests completed successfully!"

