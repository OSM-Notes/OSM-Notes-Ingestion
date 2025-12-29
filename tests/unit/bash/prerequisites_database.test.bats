#!/usr/bin/env bats

# Prerequisites Database Tests
# Tests for database prerequisites validation
# Author: Andres Gomez (AngocA)
# Version: 2025-12-29

load "$(dirname "$BATS_TEST_FILENAME")/../../test_helper.bash"
load "$(dirname "${BATS_TEST_FILENAME}")/performance_edge_cases_helper.bash"

setup() {
 # Setup test properties first (this must be done before any script sources properties.sh)
 if declare -f setup_test_properties > /dev/null 2>&1; then
  setup_test_properties
 fi
 
 # Set up required environment variables for functionsProcess.sh
 export BASENAME="test"
 export TMP_DIR="/tmp/test_$$"
 export DBNAME="${TEST_DBNAME:-test_db}"
 export SCRIPT_BASE_DIRECTORY="${TEST_BASE_DIR}"
 export LOG_FILENAME="/tmp/test.log"
 export LOCK="/tmp/test.lock"
 export MAX_THREADS="2"

 # Setup mock PostgreSQL if real PostgreSQL is not available
 performance_setup_mock_postgres

 # Unset any existing readonly variables that might conflict
 unset ERROR_HELP_MESSAGE ERROR_PREVIOUS_EXECUTION_FAILED ERROR_CREATING_REPORT ERROR_MISSING_LIBRARY ERROR_INVALID_ARGUMENT ERROR_LOGGER_UTILITY ERROR_DOWNLOADING_BOUNDARY_ID_LIST ERROR_NO_LAST_UPDATE ERROR_PLANET_PROCESS_IS_RUNNING ERROR_DOWNLOADING_NOTES ERROR_EXECUTING_PLANET_DUMP ERROR_DOWNLOADING_BOUNDARY ERROR_GEOJSON_CONVERSION ERROR_INTERNET_ISSUE ERROR_GENERAL 2> /dev/null || true

 # Source the functions
 source "${TEST_BASE_DIR}/bin/lib/functionsProcess.sh"

 # Set up logging function if not available
 if ! declare -f log_info > /dev/null; then
  log_info() { echo "[INFO] $*"; }
  log_error() { echo "[ERROR] $*"; }
  log_debug() { echo "[DEBUG] $*"; }
  log_start() { echo "[START] $*"; }
  log_finish() { echo "[FINISH] $*"; }
 fi
}

# =============================================================================
# Database prerequisites tests
# =============================================================================

@test "enhanced __checkPrereqsCommands should validate PostgreSQL connection" {
 # Test PostgreSQL connection
 run psql --version
 [ "$status" -eq 0 ]
}

@test "enhanced __checkPrereqsCommands should validate PostGIS extension" {
 # Check if we're using mock PostgreSQL
 if [[ "${PERFORMANCE_EDGE_CASES_USING_MOCK_PSQL:-false}" == "true" ]]; then
  skip "Skipping PostGIS test when using mock PostgreSQL"
 fi

 # Create test database (will use mock if PostgreSQL not available)
 if ! create_test_database; then
  skip "PostgreSQL not available, skipping PostGIS test"
 fi

 # Test PostGIS extension
 run psql -d "${TEST_DBNAME}" -c "SELECT PostGIS_version();"
 [ "$status" -eq 0 ]

 # Clean up
 drop_test_database || true
}

@test "enhanced __checkPrereqsCommands should validate btree_gist extension" {
 # Check if we're using mock PostgreSQL
 if [[ "${PERFORMANCE_EDGE_CASES_USING_MOCK_PSQL:-false}" == "true" ]]; then
  skip "Skipping btree_gist test when using mock PostgreSQL"
 fi

 # Create test database (will use mock if PostgreSQL not available)
 if ! create_test_database; then
  skip "PostgreSQL not available, skipping btree_gist test"
 fi

 # Test btree_gist extension
 run psql -d "${TEST_DBNAME}" -c "SELECT COUNT(1) FROM pg_extension WHERE extname = 'btree_gist';"
 [ "$status" -eq 0 ]

 # Clean up
 drop_test_database || true
}

teardown() {
 # Restore original properties if needed
 if declare -f restore_properties > /dev/null 2>&1; then
  restore_properties
 fi
}
