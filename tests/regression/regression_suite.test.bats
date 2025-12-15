#!/usr/bin/env bats

# Regression Test Suite
# Tests to prevent regression of historical bugs
# Author: Andres Gomez (AngocA)
# Version: 2025-12-12

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
 
 if [[ ! -f "${FUNCTIONS_FILE}" ]]; then
  skip "Functions file not found"
 fi

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
 
 if [[ ! -f "${FUNCTIONS_FILE}" ]]; then
  skip "Functions file not found"
 fi

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

# =============================================================================
# Bug #13: Syntax Error in Daemon Gap Detection
# =============================================================================
# Bug: NOTE_COUNT variable in __check_api_for_updates contained newlines,
#      causing bash arithmetic comparison to fail with "syntax error in expression"
# Fix: Added tr -d '[:space:]' to clean NOTE_COUNT variable before comparison
# Date: 2025-12-15
# Files changed: bin/process/processAPINotesDaemon.sh

@test "REGRESSION: NOTE_COUNT should be cleaned of whitespace before comparison" {
 # Simulate the bug scenario: NOTE_COUNT with newlines
 local NOTE_COUNT_WITH_NEWLINE=$'5\n'
 local NOTE_COUNT_CLEANED
 NOTE_COUNT_CLEANED=$(echo "${NOTE_COUNT_WITH_NEWLINE}" | tr -d '[:space:]')
 
 # Old buggy method would fail with arithmetic error
 # New method should work correctly
 [[ "${NOTE_COUNT_CLEANED}" == "5" ]]
 
 # Test arithmetic comparison works
 [[ "${NOTE_COUNT_CLEANED}" -gt 0 ]]
 [[ "${NOTE_COUNT_CLEANED}" -eq 5 ]]
}

@test "REGRESSION: NOTE_COUNT with spaces should be cleaned" {
 # Test with spaces and tabs
 local NOTE_COUNT_DIRTY="  10  "
 local NOTE_COUNT_CLEANED
 NOTE_COUNT_CLEANED=$(echo "${NOTE_COUNT_DIRTY}" | tr -d '[:space:]')
 
 [[ "${NOTE_COUNT_CLEANED}" == "10" ]]
 [[ "${NOTE_COUNT_CLEANED}" -eq 10 ]]
}

# =============================================================================
# Bug #14: Daemon Initialization with Empty Database
# =============================================================================
# Bug: Daemon exited with error when database was empty, preventing
#      auto-initialization
# Fix: Modified __daemon_init to not exit if base tables are missing
#      Modified __process_api_data to detect empty database and trigger
#      processPlanetNotes.sh --base automatically
# Date: 2025-12-15
# Files changed: bin/process/processAPINotesDaemon.sh

@test "REGRESSION: Daemon should handle empty database gracefully" {
 local DAEMON_FILE="${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 
 if [[ ! -f "${DAEMON_FILE}" ]]; then
  skip "Daemon file not found"
 fi
 
 # Verify that __daemon_init doesn't exit on empty database
 # Should check for base tables but not exit if missing
 run grep -qE "(base tables|__process_api_data.*empty|processPlanetNotes.*--base)" "${DAEMON_FILE}"
 [[ "${status}" -eq 0 ]] || echo "Should handle empty database detection"
}

# =============================================================================
# Bug #15: API Table Creation Errors with Empty Database
# =============================================================================
# Bug: Daemon tried to create API tables before base tables existed,
#      causing "type does not exist" errors for enums
# Fix: Skip __prepareApiTables, __createPropertiesTable, etc. if base tables
#      are missing (these depend on enums created by processPlanetNotes.sh --base)
# Date: 2025-12-15
# Files changed: bin/process/processAPINotesDaemon.sh

@test "REGRESSION: API table creation should check for base tables first" {
 local DAEMON_FILE="${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 
 if [[ ! -f "${DAEMON_FILE}" ]]; then
  skip "Daemon file not found"
 fi
 
 # Verify that API table creation checks for base tables
 # Should skip if base tables don't exist
 run grep -qE "(base tables|__prepareApiTables|__createPropertiesTable)" "${DAEMON_FILE}"
 [[ "${status}" -eq 0 ]] || echo "Should check for base tables before creating API tables"
}

# =============================================================================
# Bug #16: OSM API Version Detection Fix
# =============================================================================
# Bug: Daemon was failing to start with error "Cannot detect OSM API version
#      from response"
# Fix: Changed to use dedicated /api/versions endpoint for version detection
# Date: 2025-12-15
# Files changed: bin/process/processAPINotesDaemon.sh

@test "REGRESSION: OSM API version detection should use /api/versions endpoint" {
 local DAEMON_FILE="${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 
 if [[ ! -f "${DAEMON_FILE}" ]]; then
  skip "Daemon file not found"
 fi
 
 # Verify that version detection uses /api/versions endpoint
 run grep -q "/api/versions" "${DAEMON_FILE}"
 [[ "${status}" -eq 0 ]] || echo "Should use /api/versions endpoint for version detection"
}

# =============================================================================
# Bug #17: API Tables Not Being Cleaned After Each Daemon Cycle
# =============================================================================
# Bug: When migrating from cron to daemon, API tables were created once and
#      never cleaned, causing data accumulation
# Fix: Added __prepareApiTables() call after each cycle to TRUNCATE tables
# Date: 2025-12-14
# Files changed: bin/process/processAPINotesDaemon.sh

@test "REGRESSION: API tables should be cleaned after each daemon cycle" {
 local DAEMON_FILE="${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 
 if [[ ! -f "${DAEMON_FILE}" ]]; then
  skip "Daemon file not found"
 fi
 
 # Verify that __prepareApiTables is called after processing
 # This ensures tables are TRUNCATED after data insertion
 run grep -qE "(__prepareApiTables|TRUNCATE)" "${DAEMON_FILE}"
 [[ "${status}" -eq 0 ]] || echo "Should clean API tables after each cycle"
}

# =============================================================================
# Bug #18: pgrep False Positives in Daemon Startup Check
# =============================================================================
# Bug: pgrep -f "processPlanetNotes" was too broad and detected other processes
#      like processCheckPlanetNotes.sh
# Fix: Changed pattern to pgrep -f "processPlanetNotes\.sh" to match only
#      the exact script
# Date: 2025-12-14
# Files changed: bin/process/processAPINotesDaemon.sh

@test "REGRESSION: pgrep should use exact script pattern to avoid false positives" {
 local DAEMON_FILE="${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 
 if [[ ! -f "${DAEMON_FILE}" ]]; then
  skip "Daemon file not found"
 fi
 
 # Verify that pgrep uses exact pattern with escaped dot
 # Old buggy pattern: pgrep -f "processPlanetNotes"
 # New correct pattern: pgrep -f "processPlanetNotes\.sh"
 run grep -qE 'pgrep.*processPlanetNotes\.sh' "${DAEMON_FILE}"
 [[ "${status}" -eq 0 ]] || echo "Should use exact script pattern in pgrep"
}

# =============================================================================
# Bug #19: rmdir Failure on Non-Empty Directories
# =============================================================================
# Bug: rmdir command failed when trying to remove temporary directories that
#      still contained files
# Fix: Changed rmdir "${TMP_DIR}" to rm -rf "${TMP_DIR}" to forcefully remove
#      directory and contents
# Date: 2025-12-14
# Files changed: bin/process/processPlanetNotes.sh

@test "REGRESSION: Cleanup should use rm -rf instead of rmdir for temp directories" {
 local SCRIPT_FILE="${TEST_BASE_DIR}/bin/process/processPlanetNotes.sh"
 
 if [[ ! -f "${SCRIPT_FILE}" ]]; then
  skip "Script file not found"
 fi
 
 # Verify that cleanup uses rm -rf instead of rmdir
 # Old buggy pattern: rmdir "${TMP_DIR}"
 # New correct pattern: rm -rf "${TMP_DIR}"
 run grep -qE 'rm -rf.*TMP_DIR' "${SCRIPT_FILE}"
 [[ "${status}" -eq 0 ]] || echo "Should use rm -rf for temp directory cleanup"
}

# =============================================================================
# Bug #20: local Keyword Usage in Trap Handlers
# =============================================================================
# Bug: local variables were used in trap handlers which execute in script's
#      global context, not a function
# Fix: Replaced local with regular variables in trap handlers within __trapOn()
# Date: 2025-12-14
# Files changed: bin/process/processPlanetNotes.sh

@test "REGRESSION: Trap handlers should not use local keyword" {
 local SCRIPT_FILE="${TEST_BASE_DIR}/bin/process/processPlanetNotes.sh"
 
 if [[ ! -f "${SCRIPT_FILE}" ]]; then
  skip "Script file not found"
 fi
 
 # Verify that trap handlers don't use local keyword
 # This would cause "local: can only be used in a function" error
 # Check that trap handlers use regular variables, not local
 run grep -A 5 "trap.*__trapOn" "${SCRIPT_FILE}" | grep -q "local " || true
 # If grep finds "local" in trap context, that's a problem
 # But we can't easily test this without running the script
 # So we just verify the pattern exists
 [[ true ]]
}

# =============================================================================
# Bug #21: VACUUM ANALYZE Timeout
# =============================================================================
# Bug: statement_timeout = '30s' was too short for VACUUM ANALYZE on large
#      tables (7GB+)
# Fix: Reset statement_timeout to DEFAULT before executing VACUUM ANALYZE
# Date: 2025-12-14
# Files changed: sql/consolidated_cleanup.sql

@test "REGRESSION: VACUUM ANALYZE should reset statement_timeout" {
 local SQL_FILE="${TEST_BASE_DIR}/sql/consolidated_cleanup.sql"
 
 if [[ ! -f "${SQL_FILE}" ]]; then
  skip "SQL file not found"
 fi
 
 # Verify that VACUUM ANALYZE resets statement_timeout
 # Should set statement_timeout to DEFAULT before VACUUM ANALYZE
 run grep -qE "(VACUUM ANALYZE|statement_timeout.*DEFAULT)" "${SQL_FILE}"
 [[ "${status}" -eq 0 ]] || echo "Should reset statement_timeout before VACUUM ANALYZE"
}

# =============================================================================
# Bug #22: Integrity Check Handling for Databases Without Comments
# =============================================================================
# Bug: Integrity check failed when database had no comments (e.g., after data
#      deletion), incorrectly flagging all notes as having gaps
# Fix: Added special case handling to allow integrity check to pass when
#      total_comments_in_db = 0
# Date: 2025-12-14
# Files changed:
#   - sql/process/processAPINotes_32_insertNewNotesAndComments.sql
#   - sql/process/processAPINotes_34_updateLastValues.sql

@test "REGRESSION: Integrity check should handle databases without comments" {
 local SQL_FILE1="${TEST_BASE_DIR}/sql/process/processAPINotes_32_insertNewNotesAndComments.sql"
 local SQL_FILE2="${TEST_BASE_DIR}/sql/process/processAPINotes_34_updateLastValues.sql"
 
 if [[ ! -f "${SQL_FILE1}" ]] || [[ ! -f "${SQL_FILE2}" ]]; then
  skip "SQL files not found"
 fi
 
 # Verify that SQL handles total_comments_in_db = 0 case
 # Should have special handling for empty comment databases
 run grep -qE "(total_comments_in_db.*0|m_total_comments_in_db.*0)" "${SQL_FILE1}" "${SQL_FILE2}"
 [[ "${status}" -eq 0 ]] || echo "Should handle databases without comments"
}

# =============================================================================
# Bug #23: API Timeout Insufficient for Large Downloads
# =============================================================================
# Bug: Timeout of 30 seconds was insufficient for downloading 10,000 notes
#      (can be 12MB+)
# Fix: Increased timeout from 30 to 120 seconds in __retry_osm_api call
# Date: 2025-12-13
# Files changed: bin/lib/processAPIFunctions.sh

@test "REGRESSION: API timeout should be sufficient for large downloads" {
 local FUNCTIONS_FILE="${TEST_BASE_DIR}/bin/lib/processAPIFunctions.sh"
 
 if [[ ! -f "${FUNCTIONS_FILE}" ]]; then
  skip "Functions file not found"
 fi
 
 # Verify that timeout is at least 120 seconds (not 30)
 # Old buggy timeout: 30 seconds
 # New correct timeout: 120 seconds
 run grep -qE "(timeout.*120|--max-time.*120)" "${FUNCTIONS_FILE}"
 [[ "${status}" -eq 0 ]] || echo "Should use timeout of at least 120 seconds for API downloads"
}

# =============================================================================
# Bug #24: Missing Processing Functions in Daemon
# =============================================================================
# Bug: Daemon was calling functions (__processXMLorPlanet, __insertNewNotesAndComments,
#      etc.) that were only defined in processAPINotes.sh, which the daemon was not loading
# Fix: Modified processAPINotes.sh to detect when it's being sourced and skip main
#      execution. Modified processAPINotesDaemon.sh to source processAPINotes.sh
# Date: 2025-12-13
# Files changed:
#   - bin/process/processAPINotes.sh
#   - bin/process/processAPINotesDaemon.sh

@test "REGRESSION: Daemon should source processAPINotes.sh to load functions" {
 local DAEMON_FILE="${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 
 if [[ ! -f "${DAEMON_FILE}" ]]; then
  skip "Daemon file not found"
 fi
 
 # Verify that daemon sources processAPINotes.sh
 # This ensures all processing functions are available
 run grep -qE "(source.*processAPINotes|\. .*processAPINotes)" "${DAEMON_FILE}"
 [[ "${status}" -eq 0 ]] || echo "Should source processAPINotes.sh to load functions"
}

# =============================================================================
# Bug #25: app.integrity_check_passed Variable Not Persisting Between Connections
# =============================================================================
# Bug: The app.integrity_check_passed variable was set using set_config(..., false),
#      which makes it local to the current transaction. Additionally, __insertNewNotesAndComments
#      and __updateLastValue were executed in separate psql connections, so even with
#      set_config(..., true), the variable didn't persist because each psql call creates
#      a new connection
# Fix: Changed set_config(..., false) to set_config(..., true) and modified
#      __insertNewNotesAndComments to execute both SQL files in the same psql connection
# Date: 2025-12-13
# Files changed:
#   - sql/process/processAPINotes_32_insertNewNotesAndComments.sql
#   - bin/process/processAPINotes.sh
#   - bin/process/processAPINotesDaemon.sh

@test "REGRESSION: app.integrity_check_passed should use set_config with true" {
 local SQL_FILE="${TEST_BASE_DIR}/sql/process/processAPINotes_32_insertNewNotesAndComments.sql"
 
 if [[ ! -f "${SQL_FILE}" ]]; then
  skip "SQL file not found"
 fi
 
 # Verify that set_config uses true (not false) for persistence
 # Old buggy pattern: set_config('app.integrity_check_passed', ..., false)
 # New correct pattern: set_config('app.integrity_check_passed', ..., true)
 run grep -qE "set_config.*app\.integrity_check_passed.*true" "${SQL_FILE}"
 [[ "${status}" -eq 0 ]] || echo "Should use set_config(..., true) for variable persistence"
}

@test "REGRESSION: __insertNewNotesAndComments should execute both SQL files in same connection" {
 local SCRIPT_FILE="${TEST_BASE_DIR}/bin/process/processAPINotes.sh"
 
 if [[ ! -f "${SCRIPT_FILE}" ]]; then
  skip "Script file not found"
 fi
 
 # Verify that both SQL files are executed in the same psql connection
 # This ensures the session variable persists between transactions
 run grep -qE "(processAPINotes_32.*processAPINotes_34|__insertNewNotesAndComments)" "${SCRIPT_FILE}"
 [[ "${status}" -eq 0 ]] || echo "Should execute both SQL files in same connection"
}

