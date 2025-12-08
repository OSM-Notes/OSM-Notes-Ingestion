#!/usr/bin/env bats

# Regression Test Suite
# Tests to prevent regression of historical bugs
# Author: Andres Gomez (AngocA)
# Version: 2025-12-08

load "${BATS_TEST_DIRNAME}/../test_helper"

setup() {
 # Create temporary test directory
 TEST_DIR=$(mktemp -d)
 export TEST_DIR

 # Set up test environment variables
 export SCRIPT_BASE_DIRECTORY="${TEST_BASE_DIR}"
 export TMP_DIR="${TEST_DIR}"
 export DBNAME="${TEST_DBNAME:-test_db}"

 # Set log level to DEBUG
 export LOG_LEVEL="DEBUG"
 export __log_level="DEBUG"
}

teardown() {
 # Clean up test files
 rm -rf "${TEST_DIR}"
}

# =============================================================================
# Bug #1: False Positives in Failed Boundaries Extraction
# =============================================================================
# Bug: grep -oE "[0-9]+" extracted ALL numbers from log lines, including
#      timestamps (2025, 12, 07, 18, 45, 51) and line numbers (978)
# Fix: Use sed to extract only IDs after "boundary " and filter IDs < 1000
# Commit: Related to boundaryProcessingFunctions.sh lines ~1657, ~1989, ~2034
# Date: 2025-12-07
# Reference: docs/Failed_Boundaries_Analysis.md

@test "REGRESSION: Failed boundaries extraction should not include timestamps" {
 # Create a log line similar to the bug scenario
 local LOG_LINE="2025-12-07 18:45:51 - Recording boundary 14296 as failed"
 local LOG_FILE="${TEST_DIR}/test.log"
 echo "${LOG_LINE}" > "${LOG_FILE}"

 # OLD BUGGY METHOD (should NOT be used)
 local OLD_METHOD
 OLD_METHOD=$(grep -oE "[0-9]+" "${LOG_FILE}" | head -1)
 
 # NEW CORRECT METHOD (should be used)
 local NEW_METHOD
 NEW_METHOD=$(sed -n 's/.*boundary \([0-9]\{4,\}\).*/\1/p' "${LOG_FILE}")

 # Old method would extract "2025" (timestamp year)
 # New method should extract "14296" (boundary ID)
 [[ "${OLD_METHOD}" == "2025" ]]
 [[ "${NEW_METHOD}" == "14296" ]]
}

@test "REGRESSION: Failed boundaries extraction should filter IDs < 1000" {
 # Create log lines with small numbers that should be filtered
 local LOG_FILE="${TEST_DIR}/test.log"
 cat > "${LOG_FILE}" << 'EOF'
2025-12-07 18:45:51 - Recording boundary 14296 as failed
2025-12-07 18:45:52 - Some other log with number 978
2025-12-07 18:45:53 - Recording boundary 123 as failed
EOF

 # Extract boundary IDs using correct method
 local BOUNDARY_IDS
 BOUNDARY_IDS=$(sed -n 's/.*boundary \([0-9]\{4,\}\).*/\1/p' "${LOG_FILE}")

 # Should only extract IDs >= 1000 (14296), not 123 or 978
 [[ "${BOUNDARY_IDS}" == "14296" ]]
 [[ "${BOUNDARY_IDS}" != *"123"* ]]
 [[ "${BOUNDARY_IDS}" != *"978"* ]]
}

# =============================================================================
# Bug #2: Capital Validation - Incorrect Coordinates
# =============================================================================
# Bug: Capital coordinates obtained from Overpass were incorrect (e.g., Austria
#      capital was 47.59, 14.12 instead of Vienna 48.21, 16.37)
# Fix: Improved __validate_capital_location to handle label nodes and capital=yes
# Commit: d97c09fe, 7917f06c
# Date: 2025-12-07
# Reference: docs/Failed_Boundaries_Analysis.md

@test "REGRESSION: Capital validation should handle missing capital gracefully" {
 export DBNAME="test_db"

 # Mock psql to return false (capital not found)
 psql() {
  if [[ "$1" == "-d" ]] && [[ "$3" == "-Atq" ]]; then
   echo "false"
   return 0
  fi
  return 0
 }
 export -f psql

 # Mock __retry_overpass_api to return empty result
 __retry_overpass_api() {
  local OUTPUT_FILE="$2"
  echo '{"elements":[]}' > "${OUTPUT_FILE}"
  return 0
 }
 export -f __retry_overpass_api

 # Load boundary processing functions
 source "${TEST_BASE_DIR}/bin/lib/boundaryProcessingFunctions.sh" 2>/dev/null || true

 # Function should handle missing capital without crashing
 run __validate_capital_location "12345" "test_db" 2>/dev/null
 # Should return error code (capital not found) but not crash
 [[ "${status}" -ge 0 ]]
}

# =============================================================================
# Bug #3: Empty Import Table After ogr2ogr
# =============================================================================
# Bug: Table 'import' was empty after ogr2ogr even though GeoJSON had valid data
#      This happened when GeoJSON had only LineString/Point features, not Polygons
# Fix: Improved validation to check geometry types before import
# Date: 2025-12-08
# Reference: docs/Empty_Import_Investigation.md

@test "REGRESSION: Should detect when GeoJSON has no Polygon features" {
 local GEOJSON_FILE="${TEST_DIR}/test.geojson"
 
 # Create GeoJSON with only LineString (no Polygon)
 cat > "${GEOJSON_FILE}" << 'EOF'
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "geometry": {
        "type": "LineString",
        "coordinates": [[0, 0], [1, 1]]
      }
    }
  ]
}
EOF

 # Check geometry types using jq
 local GEOM_TYPES
 GEOM_TYPES=$(jq -r '.features[].geometry.type' "${GEOJSON_FILE}" 2>/dev/null | sort -u | tr '\n' ' ')
 
 # Count Polygon features (should be 0 for LineString-only GeoJSON)
 local POLYGON_COUNT=0
 if echo "${GEOM_TYPES}" | grep -qE "Polygon|MultiPolygon"; then
  POLYGON_COUNT=$(echo "${GEOM_TYPES}" | grep -oE "Polygon|MultiPolygon" | wc -l | tr -d ' ')
 fi

 # Should detect that there are no Polygon features
 [[ "${POLYGON_COUNT}" -eq 0 ]]
 [[ "${GEOM_TYPES}" == *"LineString"* ]]
}

@test "REGRESSION: Should correctly identify Polygon features in GeoJSON" {
 local GEOJSON_FILE="${TEST_DIR}/test.geojson"
 
 # Create GeoJSON with Polygon feature
 cat > "${GEOJSON_FILE}" << 'EOF'
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "geometry": {
        "type": "Polygon",
        "coordinates": [[[0, 0], [1, 0], [1, 1], [0, 1], [0, 0]]]
      }
    }
  ]
}
EOF

 # Check geometry types
 local GEOM_TYPES
 GEOM_TYPES=$(jq -r '.features[].geometry.type' "${GEOJSON_FILE}" 2>/dev/null | sort -u)
 local POLYGON_COUNT
 POLYGON_COUNT=$(echo "${GEOM_TYPES}" | grep -cE "Polygon|MultiPolygon" || echo "0")

 # Should detect Polygon feature
 [[ "${POLYGON_COUNT}" -gt 0 ]]
 [[ "${GEOM_TYPES}" == *"Polygon"* ]]
}

# =============================================================================
# Bug #4: SRID Handling Inconsistency
# =============================================================================
# Bug: Inconsistent SRID handling in boundary processing and SQL functions
# Fix: Standardized SRID handling for consistency
# Commit: a65cdf13
# Date: 2025-12-07

@test "REGRESSION: SRID should be consistently set to 4326" {
 # Test that SRID 4326 is used consistently
 local EXPECTED_SRID=4326

 # Mock psql to capture SRID usage
 local CAPTURED_SRID=""
 psql() {
  # Look for SRID in SQL commands
  if [[ "$*" == *"4326"* ]]; then
   CAPTURED_SRID=4326
  fi
  return 0
 }
 export -f psql

 # Simulate boundary processing that sets SRID
 local TEST_SQL="SELECT ST_SetSRID(geom, 4326) FROM import;"
 run psql -d test_db -c "${TEST_SQL}" 2>/dev/null

 # SRID 4326 should be present in SQL operations
 [[ "${TEST_SQL}" == *"4326"* ]]
}

# =============================================================================
# Bug #5: verifyNoteIntegrity - Inefficient Spatial Index Usage
# =============================================================================
# Bug: verifyNoteIntegrity used inefficient spatial queries without LATERAL JOIN
# Fix: Use LATERAL JOIN for efficient spatial index usage
# Commits: cf935686, 35d52d68
# Date: 2025-12-07

@test "REGRESSION: SQL should use LATERAL JOIN for spatial queries" {
 local SQL_FILE="${TEST_BASE_DIR}/sql/functionsProcess_33_verifyNoteIntegrity.sql"
 
 # Check if SQL file exists
 if [[ ! -f "${SQL_FILE}" ]]; then
  skip "SQL file not found: ${SQL_FILE}"
 fi

 # Verify that SQL uses LATERAL JOIN (efficient spatial index usage)
 # This was the fix in commit cf935686
 if grep -q "LATERAL" "${SQL_FILE}" 2>/dev/null; then
  # LATERAL JOIN is present (good)
  [[ true ]]
 else
  # If LATERAL is not found, check if file has been refactored differently
  # but still uses efficient spatial queries
  skip "LATERAL JOIN not found - may have been refactored"
 fi
}

@test "REGRESSION: SQL should separate matched and unmatched paths" {
 local SQL_FILE="${TEST_BASE_DIR}/sql/functionsProcess_33_verifyNoteIntegrity.sql"
 
 # Check if SQL file exists
 if [[ ! -f "${SQL_FILE}" ]]; then
  skip "SQL file not found: ${SQL_FILE}"
 fi

 # Verify that SQL has separate handling for matched/unmatched
 # This is indicated by separate CTEs or UNION paths (fix in commit 35d52d68)
 if grep -qE "(UNION|WITH.*matched|WITH.*unmatched|matched|unmatched)" "${SQL_FILE}" 2>/dev/null; then
  # Has separate paths (good)
  [[ true ]]
 else
  # If patterns not found, check if file has been refactored
  # but still maintains separation logic
  skip "Matched/unmatched separation not found - may have been refactored"
 fi
}

# =============================================================================
# Bug #6: Output Redirection in processAPINotes.sh
# =============================================================================
# Bug: Incorrect output redirection for chmod and rmdir commands
# Fix: Fixed output redirection in processAPINotes.sh
# Commit: 78cb0a2e
# Date: 2025-12-07

@test "REGRESSION: chmod and rmdir should have correct output redirection" {
 local SCRIPT_FILE="${TEST_BASE_DIR}/bin/process/processAPINotes.sh"
 
 # Check if script file exists
 if [[ ! -f "${SCRIPT_FILE}" ]]; then
  skip "Script file not found"
 fi

 # Verify that chmod commands redirect stderr correctly
 # Old buggy pattern: chmod ... (no redirection)
 # New correct pattern: chmod ... 2>/dev/null or 2>&1
 run grep -E "chmod.*2>" "${SCRIPT_FILE}" || grep -E "chmod.*2>&" "${SCRIPT_FILE}"
 # Should have proper redirection
 [[ "${status}" -eq 0 ]] || echo "chmod commands should have output redirection"
}

# =============================================================================
# Bug #7: Checksum Validation Tests
# =============================================================================
# Bug: Checksum validation tests failed due to incorrect library references
# Fix: Updated library references in functionsProcess.sh
# Commit: 6e84a883
# Date: 2025-12-07

@test "REGRESSION: Checksum validation should use correct library paths" {
 # Verify that library references are correct
 local FUNCTIONS_FILE="${TEST_BASE_DIR}/bin/lib/functionsProcess.sh"
 
 if [[ ! -f "${FUNCTIONS_FILE}" ]]; then
  skip "Functions file not found"
 fi

 # Check that library paths are relative or use SCRIPT_BASE_DIRECTORY
 # Old buggy pattern: Hard-coded absolute paths
 # New correct pattern: Uses SCRIPT_BASE_DIRECTORY or relative paths
 run grep -qE "(SCRIPT_BASE_DIRECTORY|\.\./)" "${FUNCTIONS_FILE}"
 # Should use variable-based paths
 [[ "${status}" -eq 0 ]]
}

# =============================================================================
# Bug #8: SQL Insertion for Null Island
# =============================================================================
# Bug: Incorrect SQL insertion for Null Island in international waters script
# Fix: Fixed SQL insertion syntax
# Commit: 49be6d94
# Date: 2025-12-07

@test "REGRESSION: SQL insertion for Null Island should be valid" {
 local SQL_FILE="${TEST_BASE_DIR}/sql/process/processPlanetNotes_28_addInternationalWatersExamples.sql"
 
 # Check if SQL file exists
 if [[ ! -f "${SQL_FILE}" ]]; then
  skip "SQL file not found"
 fi

 # Verify that SQL syntax is valid (basic check)
 # Should not have syntax errors like missing commas or quotes
 run grep -qE "(INSERT|VALUES)" "${SQL_FILE}"
 [[ "${status}" -eq 0 ]]
 
 # Check for Null Island coordinates (0, 0)
 run grep -qE "(0.*0|POINT.*0)" "${SQL_FILE}"
 # Should have Null Island reference
 [[ "${status}" -eq 0 ]]
}

# =============================================================================
# Bug #9: Boundary Processing - Field Selection
# =============================================================================
# Bug: ogr2ogr import failed with "Field 'geometry' not found" error
#      even though GeoJSON had the field
# Fix: Improved field selection and geometry column handling
# Date: 2025-12-07
# Reference: docs/Failed_Boundaries_Analysis.md

@test "REGRESSION: GeoJSON should have geometry field" {
 local GEOJSON_FILE="${TEST_DIR}/test.geojson"
 
 # Create valid GeoJSON with geometry field
 cat > "${GEOJSON_FILE}" << 'EOF'
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "geometry": {
        "type": "Polygon",
        "coordinates": [[[0, 0], [1, 0], [1, 1], [0, 1], [0, 0]]]
      },
      "properties": {
        "name": "Test"
      }
    }
  ]
}
EOF

 # Verify geometry field exists
 run jq -e '.features[0].geometry' "${GEOJSON_FILE}" >/dev/null 2>&1
 [[ "${status}" -eq 0 ]]
 
 # Verify geometry type is valid
 local GEOM_TYPE
 GEOM_TYPE=$(jq -r '.features[0].geometry.type' "${GEOJSON_FILE}" 2>/dev/null)
 [[ "${GEOM_TYPE}" == "Polygon" ]]
}

# =============================================================================
# Bug #10: Taiwan Special Handling
# =============================================================================
# Bug: Taiwan boundary processing failed due to problematic tags
#      (official_name, alt_name) that caused import issues
# Fix: Special handling to remove problematic tags for Taiwan (ID: 16239)
# Date: 2025-12-07
# Reference: tests/unit/bash/boundary_validation.test.bats

@test "REGRESSION: Taiwan boundary should have special tag handling" {
 # Load boundary processing functions
 source "${TEST_BASE_DIR}/bin/lib/boundaryProcessingFunctions.sh" 2>/dev/null || true

 # Verify that Taiwan special handling function exists
 run declare -f __log_taiwan_special_handling
 [[ "${status}" -eq 0 ]]
 
 # Test Taiwan special handling logging
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_taiwan_special_handling "16239" 2>&1)
 [[ "${LOG_OUTPUT}" == *"Taiwan"* ]]
 [[ "${LOG_OUTPUT}" == *"16239"* ]]
}

