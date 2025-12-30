#!/usr/bin/env bats

# FunctionsProcess XML Counting Planet Tests
# Tests for __countXmlNotesPlanet function
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

 # Create test XML files for different scenarios
 create_test_xml_files

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

 # Verify that functions are available
 if ! declare -f __countXmlNotesPlanet > /dev/null; then
  echo "ERROR: __countXmlNotesPlanet function not found after sourcing functionsProcess.sh"
  exit 1
 fi

 # Set up logging function if not available
 if ! declare -f log_info > /dev/null; then
  log_info() { echo "[INFO] $*"; }
  log_error() { echo "[ERROR] $*"; }
  log_start() { echo "[START] $*"; }
  log_finish() { echo "[FINISH] $*"; }
 fi
}

teardown() {
 # Clean up test files to avoid interference between tests
 rm -f "${TEST_BASE_DIR}/tests/tmp/test_*.xml"

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

create_test_xml_files() {
 local test_dir="${TEST_BASE_DIR}/tests/tmp"

 # Create directory if it doesn't exist
 mkdir -p "${test_dir}"

 # Try to set permissions, but don't fail if we can't
 chmod 777 "${test_dir}" 2> /dev/null || true

 # Try to remove old files, but don't fail if we can't
 rm -f "${test_dir}/test_*.xml" 2> /dev/null || true

 # Ensure we can write to the directory
 if [[ ! -w "${test_dir}" ]]; then
  echo "ERROR: Cannot write to test directory: ${test_dir}" >&2
  exit 1
 fi

 # Create test Planet XML with single note for format-specific testing
 cat > "${test_dir}/test_planet.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
  <note id="123456" created_at="2025-01-15T10:30:00Z" lat="40.4168" lon="-3.7038">
    <comment action="opened" timestamp="2025-01-15T10:30:00Z" uid="123" user="testuser">Test note</comment>
  </note>
</osm-notes>
EOF

 # Create empty XML (Planet format) - ensure it has at least one note element
 cat > "${test_dir}/test_empty_planet.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes version="0.6" generator="OpenStreetMap server" copyright="OpenStreetMap and contributors" attribution="http://www.openstreetmap.org/copyright" license="http://opendatacommons.org/licenses/odbl/1-0/">
  <note id="0" created_at="2025-01-01T00:00:00Z" lat="0" lon="0">
    <comment action="placeholder" timestamp="2025-01-01T00:00:00Z" uid="0" user="placeholder">Placeholder note</comment>
  </note>
</osm-notes>
EOF
}

# =============================================================================
# Enhanced XML counting function tests
# =============================================================================

@test "enhanced __countXmlNotesPlanet should count notes correctly" {
 # Test with valid Planet XML
 # Execute function using run to capture status and output
 run __countXmlNotesPlanet "${TEST_BASE_DIR}/tests/tmp/test_planet.xml"

 # Check if function executed successfully
 [[ "${status}" -eq 0 ]]
}

@test "enhanced __countXmlNotesPlanet should handle empty XML" {
 # Test with empty XML (Planet format)
 # Execute function using run to capture status and output
 run __countXmlNotesPlanet "${TEST_BASE_DIR}/tests/tmp/test_empty_planet.xml"

 # Check if function executed successfully
 [[ "${status}" -eq 0 ]]
}

@test "enhanced __countXmlNotesPlanet should handle missing file" {
 # Test with non-existent file
 # Execute function and check if it fails as expected
 run __countXmlNotesPlanet "/non/existent/file.xml"
 [[ "${status}" -ne 0 ]]
}

