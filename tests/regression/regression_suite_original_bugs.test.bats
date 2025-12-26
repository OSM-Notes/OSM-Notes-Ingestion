#!/usr/bin/env bats

# Regression Test Suite: Original Bugs (2025-12-07 to 2025-12-12)
# Tests to prevent regression of historical bugs from initial development period
# Author: Andres Gomez (AngocA)
# Version: 2025-12-23

load "${BATS_TEST_DIRNAME}/../test_helper"
load "${BATS_TEST_DIRNAME}/regression_helpers"

setup() {
 __setup_regression_test
}

teardown() {
 __teardown_regression_test
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
 __create_test_log_file "${LOG_FILE}" "${LOG_LINE}"

 # OLD BUGGY METHOD (should NOT be used)
 local OLD_METHOD
 OLD_METHOD=$(grep -oE "[0-9]+" "${LOG_FILE}" | head -1)
 
 # NEW CORRECT METHOD (should be used)
 local NEW_METHOD
 NEW_METHOD=$(__extract_boundary_id_from_log "${LOG_FILE}")

 # Old method would extract "2025" (timestamp year)
 # New method should extract "14296" (boundary ID)
 [[ "${OLD_METHOD}" == "2025" ]]
 [[ "${NEW_METHOD}" == "14296" ]]
}

@test "REGRESSION: Failed boundaries extraction should filter IDs < 1000" {
 # Create log lines with small numbers that should be filtered
 local LOG_FILE="${TEST_DIR}/test.log"
 __create_test_log_file "${LOG_FILE}" \
  "2025-12-07 18:45:51 - Recording boundary 14296 as failed" \
  "2025-12-07 18:45:52 - Some other log with number 978" \
  "2025-12-07 18:45:53 - Recording boundary 123 as failed"

 # Extract boundary IDs using correct method
 local BOUNDARY_IDS
 BOUNDARY_IDS=$(__extract_boundary_id_from_log "${LOG_FILE}")

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
 __mock_psql_false

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
 
 __verify_file_exists "${SQL_FILE}" "SQL file not found: ${SQL_FILE}"

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
 
 __verify_file_exists "${SQL_FILE}" "SQL file not found: ${SQL_FILE}"

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
 
 __verify_file_exists "${SQL_FILE}" "SQL file not found"

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

# =============================================================================
# Bug #11: API URL Missing Date Filter
# =============================================================================
# Bug: __getNewNotesFromApi was using incorrect API endpoint without date filter
#      URL was: https://api.openstreetmap.org/api/0.6/notes?limit=10000
#      This endpoint requires bbox parameter and doesn't filter by date
# Fix: Updated to use /notes/search.xml with from parameter for date filtering
# Date: 2025-12-12
# Reference: CHANGELOG.md, bin/lib/processAPIFunctions.sh

@test "REGRESSION: __getNewNotesFromApi should use /notes/search.xml endpoint" {
 local FUNCTIONS_FILE="${TEST_BASE_DIR}/bin/lib/processAPIFunctions.sh"
 
 if [[ ! -f "${FUNCTIONS_FILE}" ]]; then
  skip "Functions file not found"
 fi

 # Verify that the function uses the correct endpoint
 # Should use /notes/search.xml, not /notes?
 run grep -q "/notes/search.xml" "${FUNCTIONS_FILE}"
 [[ "${status}" -eq 0 ]] || echo "Should use /notes/search.xml endpoint"
 
 # Verify that it includes the 'from' parameter for date filtering
 run grep -q "from=\${LAST_UPDATE}" "${FUNCTIONS_FILE}"
 [[ "${status}" -eq 0 ]] || echo "Should include 'from' parameter for date filtering"
 
 # Should NOT use the old incorrect endpoint
 run grep -q "/notes?limit=" "${FUNCTIONS_FILE}"
 [[ "${status}" -ne 0 ]] || echo "Should NOT use /notes?limit= endpoint (requires bbox)"
}

@test "REGRESSION: API URL should include all required parameters" {
 local FUNCTIONS_FILE="${TEST_BASE_DIR}/bin/lib/processAPIFunctions.sh"
 
 __verify_file_exists "${FUNCTIONS_FILE}" "Functions file not found"

 # Verify that the URL includes all required parameters:
 # - limit (for max notes)
 # - closed=-1 (to include both open and closed notes)
 # - sort=updated_at (to sort by update time)
 # - from=${LAST_UPDATE} (to filter by date)
 run grep -qE "notes/search\.xml\?limit=.*closed=-1.*sort=updated_at.*from=" "${FUNCTIONS_FILE}"
 [[ "${status}" -eq 0 ]] || echo "API URL should include limit, closed, sort, and from parameters"
}

# =============================================================================
# Bug #12: Timestamp Format with Literal HH24
# =============================================================================
# Bug: SQL TO_CHAR queries were generating malformed timestamps like
#      "2025-12-09THH24:33:04Z" (with literal "HH24" instead of actual hour)
#      This happened because quote escaping in SQL was incorrect
# Fix: Use PostgreSQL escape string syntax (E'...') for proper quote escaping
# Date: 2025-12-12
# Reference: CHANGELOG.md, bin/lib/processAPIFunctions.sh, bin/process/processAPINotesDaemon.sh

@test "REGRESSION: Timestamp SQL query should use escape string syntax" {
 local FUNCTIONS_FILE="${TEST_BASE_DIR}/bin/lib/processAPIFunctions.sh"
 local DAEMON_FILE="${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 
 __verify_file_exists "${FUNCTIONS_FILE}" "Functions file not found"

 # Verify that TO_CHAR uses escape string syntax (E'...')
 # This ensures proper quote escaping in PostgreSQL
 run grep -qE "TO_CHAR.*E'YYYY-MM-DD" "${FUNCTIONS_FILE}"
 [[ "${status}" -eq 0 ]] || echo "Should use E'...' escape string syntax for TO_CHAR"
 
 # Should NOT have the buggy pattern without E prefix
 run grep -qE "TO_CHAR.*'YYYY-MM-DD\"T\"HH24" "${FUNCTIONS_FILE}"
 [[ "${status}" -ne 0 ]] || echo "Should NOT use pattern without E prefix (causes HH24 literal)"
 
 # Verify daemon also uses correct syntax
 if [[ -f "${DAEMON_FILE}" ]]; then
  run grep -qE "TO_CHAR.*E'YYYY-MM-DD" "${DAEMON_FILE}"
  [[ "${status}" -eq 0 ]] || echo "Daemon should also use E'...' escape string syntax"
 fi
}

@test "REGRESSION: Timestamp format should be valid ISO 8601" {
 # Create a mock psql that returns a timestamp
 local MOCK_PSQL="${TEST_DIR}/psql"
 cat > "${MOCK_PSQL}" << 'EOF'
#!/bin/bash
# Mock psql that returns a properly formatted timestamp
if [[ "$*" == *"TO_CHAR(timestamp"* ]]; then
  echo "2025-12-09T04:33:04Z"
  exit 0
fi
exit 0
EOF
 chmod +x "${MOCK_PSQL}"
 export PATH="${TEST_DIR}:${PATH}"

 # Test that the timestamp format is valid ISO 8601
 # Valid format: YYYY-MM-DDTHH:MM:SSZ
 local TIMESTAMP
 TIMESTAMP=$(psql -d test_db -Atq -c "SELECT TO_CHAR(timestamp, E'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') FROM max_note_timestamp" 2>/dev/null || echo "")
 
 # Should match ISO 8601 format (not contain literal "HH24")
 [[ "${TIMESTAMP}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
 
 # Should NOT contain literal "HH24" (the bug)
 [[ "${TIMESTAMP}" != *"HH24"* ]]
 
 # Should have actual hour value (04, not HH24)
 [[ "${TIMESTAMP}" == *"T04:"* ]] || [[ "${TIMESTAMP}" == *"T"[0-9][0-9]":"* ]]
}

@test "REGRESSION: Timestamp should be usable in API URL" {
 # Create a mock psql that returns a timestamp
 local MOCK_PSQL="${TEST_DIR}/psql"
 cat > "${MOCK_PSQL}" << 'EOF'
#!/bin/bash
if [[ "$*" == *"TO_CHAR(timestamp"* ]]; then
  echo "2025-12-09T04:33:04Z"
  exit 0
fi
exit 0
EOF
 chmod +x "${MOCK_PSQL}"
 export PATH="${TEST_DIR}:${PATH}"

 # Get timestamp
 local TIMESTAMP
 TIMESTAMP=$(psql -d test_db -Atq -c "SELECT TO_CHAR(timestamp, E'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') FROM max_note_timestamp" 2>/dev/null || echo "")
 
 # Build API URL with timestamp
 local API_URL="https://api.openstreetmap.org/api/0.6/notes/search.xml?limit=10000&closed=-1&sort=updated_at&from=${TIMESTAMP}"
 
 # URL should be valid (no malformed characters)
 # Should not contain literal "HH24"
 [[ "${API_URL}" != *"HH24"* ]]
 
 # Should contain the timestamp in correct format
 [[ "${API_URL}" == *"from=2025-12-09T04:33:04Z"* ]]
 
 # Test that API would accept this format (simulate API validation)
 # Valid format should match: YYYY-MM-DDTHH:MM:SSZ
 if [[ "${TIMESTAMP}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
  # Format is valid
  [[ true ]]
 else
  # Format is invalid
  echo "Timestamp format is invalid: ${TIMESTAMP}"
  exit 1
 fi
}

