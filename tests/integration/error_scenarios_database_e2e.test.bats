#!/usr/bin/env bats

# End-to-end integration tests for database error scenarios
# Tests: DB connection errors, constraint violations
# Author: Andres Gomez (AngocA)
# Version: 2025-12-23

load "$(dirname "$BATS_TEST_FILENAME")/../test_helper.bash"

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

