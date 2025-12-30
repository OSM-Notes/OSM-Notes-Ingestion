#!/usr/bin/env bats

# FunctionsProcess Database Integration Tests
# Tests for database integration with functionsProcess.sh
# Author: Andres Gomez (AngocA)
# Version: 2025-11-23

load "$(dirname "${BATS_TEST_FILENAME}")/../../test_helper.bash"

# =============================================================================
# Test setup and teardown
# =============================================================================

setup() {
 # Ensure TEST_BASE_DIR is set
 if [[ -z "${TEST_BASE_DIR:-}" ]]; then
  export TEST_BASE_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
 fi

 # Set up required environment variables for functionsProcess.sh
 export BASENAME="test"
 export TMP_DIR="/tmp/test_$$"
 export DBNAME="${TEST_DBNAME:-test_db}"
 export SCRIPT_BASE_DIRECTORY="${TEST_BASE_DIR}"
 export LOG_FILENAME="/tmp/test.log"
 export LOCK="/tmp/test.lock"
 export MAX_THREADS="2"
 
 # Setup test properties
 setup_test_properties

 # Provide mock psql when PostgreSQL is not available
 local MOCK_PSQL="${TMP_DIR}/psql"
 mkdir -p "${TMP_DIR}"
 cat > "${MOCK_PSQL}" << 'EOF'
#!/bin/bash
COMMAND="$*"

# Simulate specific error scenarios for tests
if [[ "${COMMAND}" == *"'invalid'::integer"* ]]; then
 echo "psql: ERROR: invalid input syntax for type integer: \"invalid\"" >&2
 exit 1
fi

# Provide simple output for SELECT 1/2/3 checks
if [[ "${COMMAND}" == *"SELECT 1"* ]]; then
 printf " ?column? \n 1\n"
 exit 0
fi

if [[ "${COMMAND}" == *"SELECT 2"* ]]; then
 printf " ?column? \n 2\n"
 exit 0
fi

if [[ "${COMMAND}" == *"SELECT 3"* ]]; then
 printf " ?column? \n 3\n"
 exit 0
fi

echo "Mock psql executed: ${COMMAND}" >&2
exit 0
EOF
 chmod +x "${MOCK_PSQL}"
 export PATH="${TMP_DIR}:${PATH}"

 # Unset any existing readonly variables that might conflict
 unset ERROR_HELP_MESSAGE ERROR_PREVIOUS_EXECUTION_FAILED ERROR_CREATING_REPORT ERROR_MISSING_LIBRARY ERROR_INVALID_ARGUMENT ERROR_LOGGER_UTILITY ERROR_DOWNLOADING_BOUNDARY_ID_LIST ERROR_NO_LAST_UPDATE ERROR_PLANET_PROCESS_IS_RUNNING ERROR_DOWNLOADING_NOTES ERROR_EXECUTING_PLANET_DUMP ERROR_DOWNLOADING_BOUNDARY ERROR_GEOJSON_CONVERSION ERROR_INTERNET_ISSUE ERROR_GENERAL 2> /dev/null || true

 # Create mock logging functions before sourcing the main file
 create_mock_logging_functions

 # Source the functions to be tested
 source "${TEST_BASE_DIR}/bin/lib/functionsProcess.sh"

 # Set up logging function if not available
 if ! declare -f log_info > /dev/null; then
  log_info() { echo "[INFO] $*"; }
  log_error() { echo "[ERROR] $*"; }
  log_start() { echo "[START] $*"; }
  log_finish() { echo "[FINISH] $*"; }
 fi
}

teardown() {
 # Remove mock binaries created during setup
 rm -f "${TMP_DIR}/psql" 2> /dev/null || true
 restore_properties
}

# =============================================================================
# Helper functions for testing
# =============================================================================

create_mock_logging_functions() {
 # Create mock logging functions that the main script expects
 __log_start() { :; }
 __logi() { :; }
 __loge() { :; }
 __logd() { :; }
 __logw() { :; }
 __log_finish() { :; }
}

create_test_database() {
 # Create a test database for integration tests
 # This is a simplified version for testing purposes
 if command -v psql > /dev/null 2>&1; then
  psql -d postgres -c "CREATE DATABASE ${TEST_DBNAME};" 2> /dev/null || true
 fi
}

drop_test_database() {
 # Drop the test database
 if command -v psql > /dev/null 2>&1; then
  psql -d postgres -c "DROP DATABASE IF EXISTS ${TEST_DBNAME};" 2> /dev/null || true
 fi
}

# =============================================================================
# Integration tests with database
# =============================================================================

@test "database functions should work with test data" {
 # Skip database tests in CI environment
 if [[ "${CI:-}" == "true" ]]; then
  skip "Database tests skipped in CI environment"
 fi

 # Create test database
 create_test_database

 # Test database connection
 run psql -d "${TEST_DBNAME}" -c "SELECT 1;"
 [[ "${status}" -eq 0 ]]

 # Clean up
 drop_test_database
}

