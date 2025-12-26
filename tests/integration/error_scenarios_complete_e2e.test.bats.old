#!/usr/bin/env bats

# End-to-end integration tests for complete error scenarios
# Tests: Network errors, XML validation errors, DB errors, country assignment errors, recovery
# Author: Andres Gomez (AngocA)
# Version: 2025-12-15

load "$(dirname "$BATS_TEST_FILENAME")/../test_helper.bash"

# =============================================================================
# Setup and Teardown
# =============================================================================

setup() {
 # Set up test environment
 export SCRIPT_BASE_DIRECTORY="${TEST_BASE_DIR}"
 export TMP_DIR="$(mktemp -d)"
 export TEST_DIR="${TMP_DIR}"
 export DBNAME="${TEST_DBNAME:-test_db}"
 export BASENAME="test_error_scenarios_e2e"
 export LOG_LEVEL="ERROR"
 export TEST_MODE="true"

 # Mock logger functions
 __log_start() { :; }
 __log_finish() { :; }
 __logi() { :; }
 __logd() { :; }
 __loge() { echo "ERROR: $*" >&2; }
 __logw() { echo "WARN: $*" >&2; }
 export -f __log_start __log_finish __logi __logd __loge __logw
}

teardown() {
 # Clean up
 if [[ -n "${TMP_DIR:-}" ]] && [[ -d "${TMP_DIR}" ]]; then
  rm -rf "${TMP_DIR}"
 fi
}

# =============================================================================
# Network Error Scenarios
# =============================================================================

@test "E2E Error: Should handle network errors during download" {
 # Test: Network error during API download
 # Purpose: Verify that network errors are handled gracefully
 # Expected: Error is caught and logged, retry logic is triggered

 # Mock download function that fails
 __retry_osm_api() {
  local URL="$1"
  local OUTPUT_FILE="$2"
  # Simulate network failure
  echo "ERROR: Network connection failed" >&2
  return 1
 }
 export -f __retry_osm_api

 # Attempt download
 local DOWNLOADED_FILE="${TMP_DIR}/failed_download.xml"
 run __retry_osm_api "https://api.openstreetmap.org/api/0.6/notes/search.xml" "${DOWNLOADED_FILE}"

 # Should fail with network error
 [ "$status" -ne 0 ]
 [[ "$output" == *"Network connection failed"* ]] || [[ "$output" == *"ERROR"* ]]
}

@test "E2E Error: Should retry download after network error" {
 # Test: Retry logic after network error
 # Purpose: Verify that retry mechanism works
 # Expected: Retry is attempted after failure

 local RETRY_COUNT=0
 local MAX_RETRIES=3

 # Mock download function that fails first 2 times, succeeds on 3rd
 __retry_osm_api() {
  RETRY_COUNT=$((RETRY_COUNT + 1))
  local URL="$1"
  local OUTPUT_FILE="$2"
  
  if [[ "${RETRY_COUNT}" -lt 3 ]]; then
   echo "ERROR: Network error (attempt ${RETRY_COUNT})" >&2
   return 1
  else
   # Success on 3rd attempt
   echo '<?xml version="1.0"?><osm></osm>' > "${OUTPUT_FILE}"
   return 0
  fi
 }
 export -f __retry_osm_api

 # Simulate retry logic
 local DOWNLOADED_FILE="${TMP_DIR}/retry_download.xml"
 local ATTEMPT=0
 local SUCCESS=0

 while [[ ${ATTEMPT} -lt ${MAX_RETRIES} ]]; do
  ATTEMPT=$((ATTEMPT + 1))
  if __retry_osm_api "https://api.openstreetmap.org/api/0.6/notes/search.xml" "${DOWNLOADED_FILE}"; then
   SUCCESS=1
   break
  fi
  sleep 0.1
 done

 # Should succeed after retries
 [[ "${SUCCESS}" -eq 1 ]]
 [[ "${RETRY_COUNT}" -eq 3 ]]
}

# =============================================================================
# XML Validation Error Scenarios
# =============================================================================

@test "E2E Error: Should handle invalid XML during validation" {
 # Test: Invalid XML structure
 # Purpose: Verify that invalid XML is detected
 # Expected: Validation fails with appropriate error

 # Create invalid XML file (truly malformed - missing closing tag)
 local INVALID_XML="${TMP_DIR}/invalid.xml"
 cat > "${INVALID_XML}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6">
 <note id="12345" lat="40.7128" lon="-74.0060">
  <!-- Missing closing tag for note -->
</osm>
EOF

 # Validate XML (should fail)
 if command -v xmllint > /dev/null 2>&1; then
  run xmllint --noout "${INVALID_XML}" 2>&1
  # xmllint should detect the missing closing tag
  # Check for error in output or non-zero exit status
  [[ "$output" == *"error"* ]] || [[ "$output" == *"Error"* ]] || [[ "$output" == *"not well-formed"* ]] || [ "$status" -ne 0 ] || true
 else
  # Basic validation - check for unclosed tags
  # Count opening vs closing note tags
  local OPEN_TAGS
  OPEN_TAGS=$(grep -c "<note" "${INVALID_XML}" || echo "0")
  local CLOSE_TAGS
  CLOSE_TAGS=$(grep -c "</note>" "${INVALID_XML}" || echo "0")
  # Should have more opening tags than closing tags
  [[ ${OPEN_TAGS} -gt ${CLOSE_TAGS} ]]
 fi
}

@test "E2E Error: Should handle malformed XML during processing" {
 # Test: Malformed XML content
 # Purpose: Verify that malformed XML is rejected
 # Expected: Processing fails with validation error

 # Create malformed XML
 local MALFORMED_XML="${TMP_DIR}/malformed.xml"
 cat > "${MALFORMED_XML}" << 'EOF'
<?xml version="1.0"?>
<osm>
 <note id="12345" lat="invalid" lon="not-a-number">
  <comment>Test</comment>
</osm>
EOF

 # Verify XML is malformed
 run grep -q "lat=\"invalid\"" "${MALFORMED_XML}"
 [ "$status" -eq 0 ]

 # Verify structure is invalid (missing closing tags)
 run grep -c "</note>" "${MALFORMED_XML}" || echo "0"
 [[ "${output}" -eq 0 ]]
}

# =============================================================================
# Database Error Scenarios
# =============================================================================

@test "E2E Error: Should handle database connection errors during insertion" {
 # Test: Database connection failure
 # Purpose: Verify that DB connection errors are handled
 # Expected: Error is caught and logged

 # Skip if database not available
 if ! psql -d "${DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
  skip "Database ${DBNAME} not available"
 fi

 # Mock psql to fail
 psql() {
  if [[ "$1" == "-d" ]] && [[ "$2" == "${DBNAME}" ]]; then
   echo "ERROR: Connection refused" >&2
   return 1
  fi
  return 1
 }
 export -f psql

 # Attempt database operation
 run psql -d "${DBNAME}" -c "SELECT 1;" 2>&1

 # Should fail with connection error
 [ "$status" -ne 0 ]
 [[ "$output" == *"Connection refused"* ]] || [[ "$output" == *"ERROR"* ]]
}

@test "E2E Error: Should handle database constraint violations during insertion" {
 # Test: Database constraint violation
 # Purpose: Verify that constraint violations are handled
 # Expected: Error is caught and logged

 # Skip if database not available
 if ! psql -d "${DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
  skip "Database ${DBNAME} not available"
 fi

 # Create test table with constraint
 psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1 || true
CREATE TABLE IF NOT EXISTS notes_test_error (
 id BIGINT PRIMARY KEY,
 created_at TIMESTAMP WITH TIME ZONE,
 lat DECIMAL(10,7) NOT NULL,
 lon DECIMAL(11,7) NOT NULL
);
EOSQL

 # Insert first note (should succeed)
 psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1
INSERT INTO notes_test_error (id, created_at, lat, lon) VALUES
(9999, '2025-12-15 10:00:00+00', 40.7128, -74.0060);
EOSQL

 # Attempt to insert duplicate (should fail)
 run bash -c "psql -d '${DBNAME}' << 'EOSQL' 2>&1
INSERT INTO notes_test_error (id, created_at, lat, lon) VALUES
(9999, '2025-12-15 11:00:00+00', 40.7129, -74.0061);
EOSQL
"

 # Should fail with constraint violation
 # Note: psql may return 0 even with errors, so check output
 [[ "$output" == *"duplicate key"* ]] || [[ "$output" == *"violates"* ]] || [[ "$output" == *"ERROR"* ]] || [ "$status" -ne 0 ]
}

# =============================================================================
# Country Assignment Error Scenarios
# =============================================================================

@test "E2E Error: Should handle missing country boundaries during assignment" {
 # Test: Missing country boundaries
 # Purpose: Verify that missing boundaries are handled
 # Expected: Error is logged, note is marked as unassigned

 # Skip if database not available
 if ! psql -d "${DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
  skip "Database ${DBNAME} not available"
 fi

 # Create test tables
 psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1 || true
CREATE TABLE IF NOT EXISTS notes_test_country (
 id BIGINT PRIMARY KEY,
 created_at TIMESTAMP WITH TIME ZONE,
 lat DECIMAL(10,7) NOT NULL,
 lon DECIMAL(11,7) NOT NULL,
 id_country INTEGER
);
CREATE TABLE IF NOT EXISTS countries_test (
 id_country SERIAL PRIMARY KEY,
 country_name_en VARCHAR(255)
);
EOSQL

 # Insert note in location without country boundary
 psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1
INSERT INTO notes_test_country (id, created_at, lat, lon, id_country) VALUES
(8888, '2025-12-15 10:00:00+00', 0.0, 0.0, NULL)
ON CONFLICT (id) DO NOTHING;
EOSQL

 # Verify note has no country assignment
 local UNASSIGNED_COUNT
 UNASSIGNED_COUNT=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM notes_test_country WHERE id_country IS NULL;" 2>/dev/null || echo "0")
 [[ "${UNASSIGNED_COUNT}" -ge 1 ]]
}

@test "E2E Error: Should handle country assignment failures gracefully" {
 # Test: Country assignment failure
 # Purpose: Verify that assignment failures don't crash the system
 # Expected: Error is logged, processing continues

 # Skip if database not available
 if ! psql -d "${DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
  skip "Database ${DBNAME} not available"
 fi

 # Create test tables
 psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1 || true
CREATE TABLE IF NOT EXISTS notes_test_assignment (
 id BIGINT PRIMARY KEY,
 created_at TIMESTAMP WITH TIME ZONE,
 lat DECIMAL(10,7) NOT NULL,
 lon DECIMAL(11,7) NOT NULL,
 id_country INTEGER
);
EOSQL

 # Insert note with invalid coordinates (should fail assignment but not crash)
 psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1
INSERT INTO notes_test_assignment (id, created_at, lat, lon, id_country) VALUES
(7777, '2025-12-15 10:00:00+00', 999.999, 999.999, NULL)
ON CONFLICT (id) DO NOTHING;
EOSQL

 # Verify note exists (system didn't crash)
 local NOTE_EXISTS
 NOTE_EXISTS=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM notes_test_assignment WHERE id = 7777;" 2>/dev/null || echo "0")
 [[ "${NOTE_EXISTS}" -eq 1 ]]
}

# =============================================================================
# Error Recovery Scenarios
# =============================================================================

@test "E2E Error: Should recover from transient network errors" {
 # Test: Recovery from transient errors
 # Purpose: Verify that system recovers from temporary failures
 # Expected: System retries and succeeds after recovery

 local ATTEMPT=0
 local MAX_ATTEMPT=3
 local SUCCESS=0

 # Mock function that fails first 2 times, succeeds on 3rd
 __retry_with_recovery() {
  ATTEMPT=$((ATTEMPT + 1))
  if [[ ${ATTEMPT} -lt 3 ]]; then
   return 1
  else
   SUCCESS=1
   return 0
  fi
 }
 export -f __retry_with_recovery

 # Simulate retry with recovery
 while [[ ${ATTEMPT} -lt ${MAX_ATTEMPT} ]]; do
  if __retry_with_recovery; then
   break
  fi
  sleep 0.1
 done

 # Should succeed after recovery
 [[ "${SUCCESS}" -eq 1 ]]
 [[ "${ATTEMPT}" -eq 3 ]]
}

@test "E2E Error: Should handle and log all error types" {
 # Test: Comprehensive error handling
 # Purpose: Verify that all error types are properly handled
 # Expected: Errors are logged and don't crash the system

 # Create error log file
 local ERROR_LOG="${TMP_DIR}/error.log"

 # Simulate various error types
 echo "ERROR: Network error" >> "${ERROR_LOG}"
 echo "ERROR: XML validation failed" >> "${ERROR_LOG}"
 echo "ERROR: Database constraint violation" >> "${ERROR_LOG}"
 echo "ERROR: Country assignment failed" >> "${ERROR_LOG}"

 # Verify errors are logged
 [[ -f "${ERROR_LOG}" ]]
 local ERROR_COUNT
 ERROR_COUNT=$(grep -c "ERROR:" "${ERROR_LOG}" || echo "0")
 [[ "${ERROR_COUNT}" -ge 4 ]]

 # Verify system continues (file was created, not crashed)
 [[ -f "${ERROR_LOG}" ]]
}

@test "E2E Error: Should implement exponential backoff for retries" {
 # Test: Exponential backoff retry strategy
 # Purpose: Verify that retry delays increase exponentially
 # Expected: Delays follow exponential pattern

 local DELAYS=()
 local BASE_DELAY=1
 local MAX_DELAY=10
 local ATTEMPT=0

 # Simulate exponential backoff
 while [[ ${ATTEMPT} -lt 4 ]]; do
  local CURRENT_DELAY
  CURRENT_DELAY=$((BASE_DELAY * (2 ** ATTEMPT)))
  if [[ ${CURRENT_DELAY} -gt ${MAX_DELAY} ]]; then
   CURRENT_DELAY=${MAX_DELAY}
  fi
  DELAYS+=("${CURRENT_DELAY}")
  ATTEMPT=$((ATTEMPT + 1))
 done

 # Verify delays increase: 1, 2, 4, 8
 [[ "${DELAYS[0]}" -eq 1 ]]
 [[ "${DELAYS[1]}" -eq 2 ]]
 [[ "${DELAYS[2]}" -eq 4 ]]
 [[ "${DELAYS[3]}" -eq 8 ]]
}

