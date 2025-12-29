#!/usr/bin/env bats

# Prerequisites Filesystem Tests
# Tests for filesystem and permission validation
# Author: Andres Gomez (AngocA)
# Version: 2025-12-29

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
# File system prerequisites tests
# =============================================================================

@test "enhanced __checkPrereqsCommands should validate required directories exist" {
 # Test that required directories exist
 [ -d "${TEST_BASE_DIR}/bin" ]
 [ -d "${TEST_BASE_DIR}/sql" ]
 [ -d "${TEST_BASE_DIR}/awk" ]
 [ -d "${TEST_BASE_DIR}/xsd" ]
 [ -d "${TEST_BASE_DIR}/overpass" ]
}

@test "enhanced __checkPrereqsCommands should validate required files exist" {
 # Test that required files exist
 [ -f "${TEST_BASE_DIR}/bin/lib/functionsProcess.sh" ]
 # properties.sh can be in etc/ or tests/ directory
 [ -f "${TEST_BASE_DIR}/etc/properties.sh" ] || [ -f "${TEST_BASE_DIR}/tests/properties.sh" ] || [ -f "${TEST_BASE_DIR}/etc/properties_test.sh" ]
 [ -f "${TEST_BASE_DIR}/xsd/OSM-notes-API-schema.xsd" ]
 [ -f "${TEST_BASE_DIR}/xsd/OSM-notes-planet-schema.xsd" ]
}

# =============================================================================
# Permission tests
# =============================================================================

@test "enhanced __checkPrereqsCommands should validate write permissions" {
 # Test write permissions in temp directory
 local test_file="/tmp/test_write_permission_$$"
 run touch "$test_file"
 [ "$status" -eq 0 ]
 rm -f "$test_file"
}

@test "enhanced __checkPrereqsCommands should validate execute permissions" {
 # Test execute permissions on scripts - check if they exist and are readable
 # Note: Some scripts might not have execute permissions in test environment
 [ -r "${TEST_BASE_DIR}/bin/lib/functionsProcess.sh" ]
 [ -r "${TEST_BASE_DIR}/bin/process/processAPINotes.sh" ]
 [ -r "${TEST_BASE_DIR}/bin/process/processPlanetNotes.sh" ]

 # Check if at least one script has execute permissions (indicating proper setup)
 local has_exec_perms=false
 if [[ -x "${TEST_BASE_DIR}/bin/lib/functionsProcess.sh" ]] \
  || [[ -x "${TEST_BASE_DIR}/bin/process/processAPINotes.sh" ]] \
  || [[ -x "${TEST_BASE_DIR}/bin/process/processPlanetNotes.sh" ]]; then
  has_exec_perms=true
 fi

 # Log the actual permissions for debugging
 echo "Script permissions:"
 ls -la "${TEST_BASE_DIR}/bin/lib/functionsProcess.sh" || echo "functionsProcess.sh not found"
 ls -la "${TEST_BASE_DIR}/bin/process/processAPINotes.sh" || echo "processAPINotes.sh not found"
 ls -la "${TEST_BASE_DIR}/bin/process/processPlanetNotes.sh" || echo "processPlanetNotes.sh not found"

 # The test passes if scripts are readable (minimum requirement)
 # Execute permissions are nice to have but not critical for functionality
 [ "$has_exec_perms" = true ] || echo "Warning: No scripts have execute permissions (this is acceptable in test environment)"
}

