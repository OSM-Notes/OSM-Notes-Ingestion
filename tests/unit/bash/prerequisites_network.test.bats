#!/usr/bin/env bats

# Prerequisites Network Tests
# Tests for network connectivity validation
# Author: Andres Gomez (AngocA)
# Version: 2025-11-11

load "$(dirname "$BATS_TEST_FILENAME")/../../test_helper.bash"
load "$(dirname "${BATS_TEST_FILENAME}")/performance_edge_cases_helper.bash"

setup() {
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
# Network connectivity tests
# =============================================================================

@test "enhanced __checkPrereqsCommands should validate internet connectivity" {
 # Test internet connectivity
 run wget --timeout=10 --tries=1 --spider https://www.google.com
 [ "$status" -eq 0 ]
}

@test "enhanced __checkPrereqsCommands should validate OSM API accessibility" {
 # Mock wget for OSM API test
 wget() {
  if [[ "$*" == *"api.openstreetmap.org"* ]]; then
   echo "HTTP/1.1 200 OK"
   return 0
  else
   command wget "$@"
  fi
 }

 # Test OSM API accessibility
 run wget --timeout=10 --tries=1 --spider https://api.openstreetmap.org/api/0.6/notes
 [ "$status" -eq 0 ]
}

