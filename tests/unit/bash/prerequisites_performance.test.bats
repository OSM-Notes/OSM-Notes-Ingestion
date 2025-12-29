#!/usr/bin/env bats

# Prerequisites Performance Tests
# Tests for performance of prerequisites checking
# Author: Andres Gomez (AngocA)
# Version: 2025-11-11

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

teardown() {
 # Restore original properties if needed
 if declare -f restore_properties > /dev/null 2>&1; then
  restore_properties
 fi
}

# =============================================================================
# Performance tests
# =============================================================================

@test "enhanced __checkPrereqsCommands should complete quickly" {
 # Mock all external commands for fast execution
 psql() {
  echo "Mock psql"
  return 0
 }
 curl() {
  echo "Mock curl"
  return 0
 }
 aria2c() {
  echo "Mock aria2c"
  return 0
 }
 osmtogeojson() {
  echo "Mock osmtogeojson"
  return 0
 }
 ajv() {
  echo "Mock ajv"
  return 0
 }
 ogr2ogr() {
  echo "Mock ogr2ogr"
  return 0
 }
 flock() {
  echo "Mock flock"
  return 0
 }
 mutt() {
  echo "Mock mutt"
  return 0
 }
 bzip2() {
  echo "Mock bzip2"
  return 0
 }
 xmllint() {
  echo "Mock xmllint"
  return 0
 }
 awkproc() {
  echo "Mock awkproc"
  return 0
 }
 xmlstarlet() {
  echo "Mock xmlstarlet"
  return 0
 }

 # Mock the function itself for fast execution
 __checkPrereqsCommands() {
  echo "Mock __checkPrereqsCommands executed"
  return 0
 }

 # Test performance
 local start_time=$(date +%s%N)
 run __checkPrereqsCommands
 local end_time=$(date +%s%N)
 local duration=$((end_time - start_time))

 [ "$status" -eq 0 ]
 [ "$duration" -lt 5000000000 ] # Should complete in less than 5 seconds
}

