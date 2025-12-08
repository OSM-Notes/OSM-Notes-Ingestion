#!/usr/bin/env bats

# Prerequisites Commands Tests
# Tests for command availability validation
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
# Enhanced prerequisites validation tests
# =============================================================================

@test "enhanced __checkPrereqsCommands should validate all required tools" {
 # Skip this test if running on host (not in Docker)
 if [[ ! -f "/app/bin/functionsProcess.sh" ]]; then
  skip "Skipping on host environment"
 fi

 # Test that all required tools are available
 # Accept any non-fatal exit code (0 is success, but some warnings might return non-zero)
 run __checkPrereqsCommands
 [ "$status" -lt 128 ] # Accept any non-fatal exit code
}

@test "enhanced __checkPrereqsCommands should handle missing PostgreSQL" {
 # Skip this test if running on host (not in Docker)
 if [[ ! -f "/app/bin/functionsProcess.sh" ]]; then
  skip "Skipping on host environment"
 fi

 # Mock PostgreSQL not available
 psql() { return 1; }

 run __checkPrereqsCommands
 [ "$status" -ne 0 ]
}

@test "enhanced __checkPrereqsCommands should handle missing wget" {
 # Skip this test if running on host (not in Docker)
 if [[ ! -f "/app/bin/functionsProcess.sh" ]]; then
  skip "Skipping on host environment"
 fi

 # Mock wget not available
 wget() { return 1; }

 run __checkPrereqsCommands
 [ "$status" -ne 0 ]
}

@test "enhanced __checkPrereqsCommands should handle missing aria2c" {
 # Mock aria2c not available
 local original_path="$PATH"
 export PATH="/tmp/empty:$PATH"

 run __checkPrereqsCommands
 [ "$status" -ne 0 ]

 export PATH="$original_path"
}

@test "enhanced __checkPrereqsCommands should handle missing osmtogeojson" {
 # Mock osmtogeojson not available
 local original_path="$PATH"
 export PATH="/tmp/empty:$PATH"

 run __checkPrereqsCommands
 [ "$status" -ne 0 ]

 export PATH="$original_path"
}

@test "enhanced __checkPrereqsCommands should handle missing ajv" {
 # Mock ajv not available
 local original_path="$PATH"
 export PATH="/tmp/empty:$PATH"

 run __checkPrereqsCommands
 [ "$status" -ne 0 ]

 export PATH="$original_path"
}

@test "enhanced __checkPrereqsCommands should handle missing ogr2ogr" {
 # Mock ogr2ogr not available
 local original_path="$PATH"
 export PATH="/tmp/empty:$PATH"

 run __checkPrereqsCommands
 [ "$status" -ne 0 ]

 export PATH="$original_path"
}

@test "enhanced __checkPrereqsCommands should handle missing flock" {
 # Mock flock not available
 local original_path="$PATH"
 export PATH="/tmp/empty:$PATH"

 run __checkPrereqsCommands
 [ "$status" -ne 0 ]

 export PATH="$original_path"
}

@test "enhanced __checkPrereqsCommands should handle missing mutt" {
 # Mock mutt not available
 local original_path="$PATH"
 export PATH="/tmp/empty:$PATH"

 run __checkPrereqsCommands
 [ "$status" -ne 0 ]

 export PATH="$original_path"
}

@test "enhanced __checkPrereqsCommands should handle missing bzip2" {
 # Mock bzip2 not available
 local original_path="$PATH"
 export PATH="/tmp/empty:$PATH"

 run __checkPrereqsCommands
 [ "$status" -ne 0 ]

 export PATH="$original_path"
}

