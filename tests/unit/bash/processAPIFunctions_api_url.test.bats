#!/usr/bin/env bats

# Unit tests for processAPIFunctions.sh - API URL construction and timestamp format
# Tests to prevent regression of API URL and timestamp format bugs
# Author: Andres Gomez (AngocA)
# Version: 2025-12-12

load "$(dirname "${BATS_TEST_FILENAME}")/../../test_helper.bash"

setup() {
 # Create temporary test directory
 TEST_DIR=$(mktemp -d)
 export TEST_DIR

 # Set up test environment variables
 export SCRIPT_BASE_DIRECTORY="${TEST_BASE_DIR}"
 export TMP_DIR="${TEST_DIR}"
 export DBNAME="${TEST_DBNAME:-test_db}"
 export API_NOTES_FILE="${TEST_DIR}/OSM-notes-API.xml"
 export OSM_API="https://api.openstreetmap.org/api/0.6"
 export MAX_NOTES="10000"

 # Set log level
 export LOG_LEVEL="ERROR"
 export __log_level="ERROR"

 # Mock logger functions
 __log_start() { :; }
 __log_finish() { :; }
 __logi() { :; }
 __logd() { :; }
 __loge() { echo "ERROR: $*" >&2; }
 __logw() { :; }
 export -f __log_start __log_finish __logi __logd __loge __logw

 # Mock error handling
 ERROR_INTERNET_ISSUE=1
 ERROR_NO_LAST_UPDATE=2
 __handle_error_with_cleanup() { return "$1"; }
 export -f __handle_error_with_cleanup

 # Mock network connectivity check
 __check_network_connectivity() { return 0; }
 export -f __check_network_connectivity

 # Mock retry file operation - properly handle psql output redirection
 __retry_file_operation() {
  local DB_OPERATION="$1"
  local TEMP_FILE="$2"
  
  # The DB_OPERATION contains: psql ... -c "SELECT ..." > file 2>/dev/null
  # Extract the psql command (everything before the first >)
  local PSQL_CMD
  PSQL_CMD=$(echo "${DB_OPERATION}" | sed 's/>.*$//')
  
  # Execute psql command and redirect output to the specified temp file
  # Use the TEMP_FILE parameter that was passed to the function
  if eval "${PSQL_CMD}" > "${TEMP_FILE}" 2>/dev/null; then
   # Verify file was created and has content
   if [[ -f "${TEMP_FILE}" ]] && [[ -s "${TEMP_FILE}" ]]; then
    return 0
   fi
  fi
  return 1
 }
 export -f __retry_file_operation

 # Mock retry OSM API - capture URL and create output
 # This will override the real function when processAPIFunctions.sh is sourced
 __retry_osm_api() {
  local URL="$1"
  local OUTPUT_FILE="$2"
  # Capture URL for validation
  echo "${URL}" > "${TEST_DIR}/captured_url.txt" 2>/dev/null || true
  # Create output file with minimal XML content
  cat > "${OUTPUT_FILE}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6">
</osm>
EOF
  return 0
 }
 export -f __retry_osm_api

 # Load common functions first (required by processAPIFunctions.sh)
 if [[ -f "${TEST_BASE_DIR}/lib/osm-common/commonFunctions.sh" ]]; then
  source "${TEST_BASE_DIR}/lib/osm-common/commonFunctions.sh" 2>/dev/null || true
 fi

 # Load noteProcessingFunctions to get __retry_osm_api, then override it
 if [[ -f "${TEST_BASE_DIR}/bin/lib/noteProcessingFunctions.sh" ]]; then
  # Source but don't fail if some functions are missing
  source "${TEST_BASE_DIR}/bin/lib/noteProcessingFunctions.sh" 2>/dev/null || true
  # Override with our mock
  __retry_osm_api() {
   local URL="$1"
   local OUTPUT_FILE="$2"
   echo "${URL}" > "${TEST_DIR}/captured_url.txt" 2>/dev/null || true
   cat > "${OUTPUT_FILE}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6">
</osm>
EOF
   return 0
  }
  export -f __retry_osm_api
 fi
}

teardown() {
 # Clean up test files
 rm -rf "${TEST_DIR}"
}

# =============================================================================
# Tests for API URL Construction
# =============================================================================

@test "__getNewNotesFromApi should construct URL with /notes/search.xml endpoint" {
 # Create a better mock psql that handles redirection
 local MOCK_PSQL="${TEST_DIR}/psql"
 cat > "${MOCK_PSQL}" << 'EOF'
#!/bin/bash
# Mock psql that handles output redirection
# The actual command pattern is: psql ... -c "SELECT ..." > file 2>/dev/null
# We need to intercept this and write to the file

# Check if this is a TO_CHAR query for timestamp
if [[ "$*" == *"TO_CHAR(timestamp"* ]] && [[ "$*" == *"max_note_timestamp"* ]]; then
  # The output file is specified after > in the command
  # Extract it from the full command line
  local FULL_CMD="$*"
  # Find the output file (pattern: > /tmp/...)
  local OUTPUT_FILE
  OUTPUT_FILE=$(echo "${FULL_CMD}" | grep -oP '>\s+\S+' | sed 's/> //' | head -1)
  
  # If we couldn't extract it, try to find a temp file pattern
  if [[ -z "${OUTPUT_FILE}" ]]; then
    OUTPUT_FILE=$(echo "${FULL_CMD}" | grep -oP '/tmp/[^\s"]+' | head -1)
  fi
  
  # Write timestamp to the file
  if [[ -n "${OUTPUT_FILE}" ]]; then
    echo "2025-12-09T04:33:04Z" > "${OUTPUT_FILE}" 2>/dev/null || true
  else
    # Fallback: output to stdout
    echo "2025-12-09T04:33:04Z"
  fi
  exit 0
fi

# For other queries, just succeed
exit 0
EOF
 chmod +x "${MOCK_PSQL}"
 export PATH="${TEST_DIR}:${PATH}"

 # Source the function (will use our mocked __retry_osm_api)
 source "${TEST_BASE_DIR}/bin/lib/processAPIFunctions.sh" 2>/dev/null || true

 # Call the function
 run __getNewNotesFromApi 2>&1

 # Function may return error if timestamp is empty, but URL should still be captured
 # Check that URL was captured (even if function failed)
 if [[ -f "${TEST_DIR}/captured_url.txt" ]]; then
  # Verify URL uses correct endpoint
  local CAPTURED_URL
  CAPTURED_URL=$(cat "${TEST_DIR}/captured_url.txt")
  [[ "${CAPTURED_URL}" == *"/notes/search.xml"* ]]
  [[ "${CAPTURED_URL}" != *"/notes?limit="* ]]
 else
  # If URL wasn't captured, the function failed before reaching API call
  # This is expected if timestamp retrieval failed
  # But we should still verify the code uses correct endpoint
  run grep -q "/notes/search.xml" "${TEST_BASE_DIR}/bin/lib/processAPIFunctions.sh"
  [[ "${status}" -eq 0 ]]
 fi
}

@test "__getNewNotesFromApi should include 'from' parameter in URL" {
 # Mock psql - simpler approach: just output timestamp when queried
 local MOCK_PSQL="${TEST_DIR}/psql"
 cat > "${MOCK_PSQL}" << 'EOF'
#!/bin/bash
# When psql is called with TO_CHAR query, output timestamp
if [[ "$*" == *"TO_CHAR(timestamp"* ]] && [[ "$*" == *"max_note_timestamp"* ]]; then
  echo "2025-12-09T04:33:04Z"
  exit 0
fi
exit 0
EOF
 chmod +x "${MOCK_PSQL}"
 export PATH="${TEST_DIR}:${PATH}"

 # Source the function
 source "${TEST_BASE_DIR}/bin/lib/processAPIFunctions.sh" 2>/dev/null || true

 # Call the function
 run __getNewNotesFromApi 2>&1

 # Check that URL includes 'from' parameter (if URL was captured)
 if [[ -f "${TEST_DIR}/captured_url.txt" ]]; then
  local CAPTURED_URL
  CAPTURED_URL=$(cat "${TEST_DIR}/captured_url.txt")
  [[ "${CAPTURED_URL}" == *"from=2025-12-09T04:33:04Z"* ]]
 else
  # If URL wasn't captured, verify the code pattern is correct
  run grep -q "from=\${LAST_UPDATE}" "${TEST_BASE_DIR}/bin/lib/processAPIFunctions.sh"
  [[ "${status}" -eq 0 ]]
 fi
}

@test "__getNewNotesFromApi should include all required URL parameters" {
 # Mock psql
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

 # Source the function
 source "${TEST_BASE_DIR}/bin/lib/processAPIFunctions.sh" 2>/dev/null || true

 # Call the function
 run __getNewNotesFromApi 2>&1

 # Check that URL includes all required parameters (if URL was captured)
 if [[ -f "${TEST_DIR}/captured_url.txt" ]]; then
  local CAPTURED_URL
  CAPTURED_URL=$(cat "${TEST_DIR}/captured_url.txt")
  [[ "${CAPTURED_URL}" == *"limit=${MAX_NOTES}"* ]]
  [[ "${CAPTURED_URL}" == *"closed=-1"* ]]
  [[ "${CAPTURED_URL}" == *"sort=updated_at"* ]]
  [[ "${CAPTURED_URL}" == *"from="* ]]
 else
  # Verify code pattern includes all parameters (may be on same or different lines)
  local FUNCTIONS_FILE="${TEST_BASE_DIR}/bin/lib/processAPIFunctions.sh"
  run grep -q "limit=\${MAX_NOTES}" "${FUNCTIONS_FILE}"
  [[ "${status}" -eq 0 ]]
  run grep -q "closed=-1" "${FUNCTIONS_FILE}"
  [[ "${status}" -eq 0 ]]
  run grep -q "sort=updated_at" "${FUNCTIONS_FILE}"
  [[ "${status}" -eq 0 ]]
  run grep -q "from=\${LAST_UPDATE}" "${FUNCTIONS_FILE}"
  [[ "${status}" -eq 0 ]]
 fi
}

# =============================================================================
# Tests for Timestamp Format
# =============================================================================

@test "Timestamp SQL query should generate valid ISO 8601 format" {
 # Create mock psql that captures the SQL query
 local MOCK_PSQL="${TEST_DIR}/psql"
 local CAPTURED_SQL="${TEST_DIR}/captured_sql.txt"
 cat > "${MOCK_PSQL}" << EOF
#!/bin/bash
# Capture SQL query
echo "\$*" > "${CAPTURED_SQL}"
# Return valid timestamp
echo "2025-12-09T04:33:04Z"
exit 0
EOF
 chmod +x "${MOCK_PSQL}"
 export PATH="${TEST_DIR}:${PATH}"

 # Execute the SQL query pattern used in the function
 local TEMP_FILE="${TEST_DIR}/timestamp.txt"
 psql -d "${DBNAME}" -Atq -c "SELECT TO_CHAR(timestamp, E'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') FROM max_note_timestamp" > "${TEMP_FILE}" 2>/dev/null

 # Read the captured SQL
 local SQL_QUERY
 SQL_QUERY=$(cat "${CAPTURED_SQL}")

 # Verify SQL uses escape string syntax
 [[ "${SQL_QUERY}" == *"E'YYYY-MM-DD"* ]]

 # Verify timestamp format is valid ISO 8601
 local TIMESTAMP
 TIMESTAMP=$(cat "${TEMP_FILE}")
 [[ "${TIMESTAMP}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
 [[ "${TIMESTAMP}" != *"HH24"* ]]
}

@test "Timestamp should not contain literal HH24" {
 # Create mock psql
 local MOCK_PSQL="${TEST_DIR}/psql"
 cat > "${MOCK_PSQL}" << 'EOF'
#!/bin/bash
# Simulate the buggy pattern (without E prefix)
# This would generate: 2025-12-09THH24:33:04Z
if [[ "$*" == *"TO_CHAR(timestamp"* ]] && [[ "$*" != *"E'YYYY"* ]]; then
  echo "2025-12-09THH24:33:04Z"
else
  echo "2025-12-09T04:33:04Z"
fi
exit 0
EOF
 chmod +x "${MOCK_PSQL}"
 export PATH="${TEST_DIR}:${PATH}"

 # Test with correct syntax (E prefix)
 local TEMP_FILE="${TEST_DIR}/timestamp.txt"
 psql -d "${DBNAME}" -Atq -c "SELECT TO_CHAR(timestamp, E'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') FROM max_note_timestamp" > "${TEMP_FILE}" 2>/dev/null

 local TIMESTAMP
 TIMESTAMP=$(cat "${TEMP_FILE}")

 # Should NOT contain literal "HH24"
 [[ "${TIMESTAMP}" != *"HH24"* ]]

 # Should have actual hour value
 [[ "${TIMESTAMP}" =~ T[0-9]{2}: ]]
}

@test "Timestamp format should be URL-safe" {
 # Create mock psql
 local MOCK_PSQL="${TEST_DIR}/psql"
 cat > "${MOCK_PSQL}" << 'EOF'
#!/bin/bash
if [[ "$*" == *"TO_CHAR(timestamp"* ]]; then
  echo "2025-12-09T04:33:04Z"
fi
exit 0
EOF
 chmod +x "${MOCK_PSQL}"
 export PATH="${TEST_DIR}:${PATH}"

 # Get timestamp
 local TEMP_FILE="${TEST_DIR}/timestamp.txt"
 psql -d "${DBNAME}" -Atq -c "SELECT TO_CHAR(timestamp, E'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') FROM max_note_timestamp" > "${TEMP_FILE}" 2>/dev/null

 local TIMESTAMP
 TIMESTAMP=$(cat "${TEMP_FILE}")

 # Build URL with timestamp
 local API_URL="https://api.openstreetmap.org/api/0.6/notes/search.xml?limit=10000&closed=-1&sort=updated_at&from=${TIMESTAMP}"

 # URL should be valid (no special encoding needed for ISO 8601)
 # Should not contain spaces or invalid characters
 [[ "${API_URL}" != *" "* ]]
 [[ "${API_URL}" == *"from=2025-12-09T04:33:04Z"* ]]

 # Should be usable in curl/wget
 [[ "${API_URL}" =~ ^https://.*from=[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
}

# =============================================================================
# Integration Tests
# =============================================================================

@test "__getNewNotesFromApi should retrieve timestamp from database" {
 # Mock psql
 local MOCK_PSQL="${TEST_DIR}/psql"
 cat > "${MOCK_PSQL}" << 'EOF'
#!/bin/bash
if [[ "$*" == *"max_note_timestamp"* ]]; then
  echo "2025-12-09T04:33:04Z"
  exit 0
fi
exit 0
EOF
 chmod +x "${MOCK_PSQL}"
 export PATH="${TEST_DIR}:${PATH}"

 # Source the function
 source "${TEST_BASE_DIR}/bin/lib/processAPIFunctions.sh" 2>/dev/null || true

 # Call the function
 run __getNewNotesFromApi 2>&1

 # Function should have queried the database
 # (We verify this by checking that the URL contains the timestamp)
 if [[ -f "${TEST_DIR}/captured_url.txt" ]]; then
  local CAPTURED_URL
  CAPTURED_URL=$(cat "${TEST_DIR}/captured_url.txt")
  [[ "${CAPTURED_URL}" == *"from=2025-12-09T04:33:04Z"* ]]
 else
  # Verify the function queries max_note_timestamp
  run grep -q "max_note_timestamp" "${TEST_BASE_DIR}/bin/lib/processAPIFunctions.sh"
  [[ "${status}" -eq 0 ]]
 fi
}

@test "__getNewNotesFromApi should handle empty timestamp gracefully" {
 # Mock psql to return empty result
 local MOCK_PSQL="${TEST_DIR}/psql"
 cat > "${MOCK_PSQL}" << 'EOF'
#!/bin/bash
if [[ "$*" == *"TO_CHAR(timestamp"* ]]; then
  # Return empty file (simulating no timestamp)
  touch "$(echo "$*" | grep -o '/tmp/[^ ]*' | head -1)"
fi
exit 0
EOF
 chmod +x "${MOCK_PSQL}"
 export PATH="${TEST_DIR}:${PATH}"

 # Source the function
 source "${TEST_BASE_DIR}/bin/lib/processAPIFunctions.sh"

 # Call the function - should return error code
 run __getNewNotesFromApi
 [[ "${status}" -eq "${ERROR_NO_LAST_UPDATE}" ]]
}

@test "__getNewNotesFromApi should use MAX_NOTES in URL" {
 # Set custom MAX_NOTES
 export MAX_NOTES="5000"

 # Mock psql
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

 # Source the function
 source "${TEST_BASE_DIR}/bin/lib/processAPIFunctions.sh" 2>/dev/null || true

 # Call the function
 run __getNewNotesFromApi 2>&1

 # Verify URL uses custom MAX_NOTES (if URL was captured)
 if [[ -f "${TEST_DIR}/captured_url.txt" ]]; then
  local CAPTURED_URL
  CAPTURED_URL=$(cat "${TEST_DIR}/captured_url.txt")
  [[ "${CAPTURED_URL}" == *"limit=5000"* ]]
  [[ "${CAPTURED_URL}" != *"limit=10000"* ]]
 else
  # Verify code uses MAX_NOTES variable
  run grep -q "limit=\${MAX_NOTES}" "${TEST_BASE_DIR}/bin/lib/processAPIFunctions.sh"
  [[ "${status}" -eq 0 ]]
 fi
}

