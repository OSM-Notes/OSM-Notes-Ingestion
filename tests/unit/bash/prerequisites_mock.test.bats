#!/usr/bin/env bats

# Prerequisites Mock Tests
# Tests for prerequisites checking with mock dependencies
# Author: Andres Gomez (AngocA)
# Version: 2026-01-02

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
# Mock function tests
# =============================================================================

@test "mock prerequisites check should work without external dependencies" {
 # Skip this test if running on host (not in Docker)
 if [[ ! -f "/app/bin/functionsProcess.sh" ]]; then
  skip "Function not available in test environment"
 fi

 # Set required environment variables
 export DBNAME="${DBNAME:-test_db}"
 export DB_USER="${DB_USER:-test_user}"
 export SKIP_XML_VALIDATION="true"

 # Create mock versions of required tools
 local mock_dir="${TEST_BASE_DIR}/tests/tmp/mock_tools"
 mkdir -p "${mock_dir}"

 # Mock psql to handle all cases
 cat > "${mock_dir}/psql" << 'EOF'
#!/bin/bash
if [[ "$1" == "--version" ]]; then
    echo "psql (PostgreSQL) 15.1"
    exit 0
elif [[ "$1" == "-lqt" ]]; then
    # Mock database list
    echo "test_db"
    exit 0
elif [[ "$1" == "-U" ]] && [[ "$3" == "-d" ]]; then
    # Mock user and database connection
    exit 0
elif [[ "$1" == "-d" ]]; then
    # Mock direct database connection
    exit 0
else
    exit 0
fi
EOF
 chmod +x "${mock_dir}/psql"

 # Mock curl
 cat > "${mock_dir}/curl" << 'EOF'
#!/bin/bash
if [[ "$1" == "--version" ]]; then
    echo "curl 7.68.0"
    exit 0
elif [[ "$1" == "-s" ]] || [[ "$1" == "--max-time" ]]; then
    echo "HTTP/1.1 200 OK"
    exit 0
else
    echo "HTTP/1.1 200 OK"
    exit 0
fi
EOF
 chmod +x "${mock_dir}/curl"

 # Mock all other required commands
 for cmd in aria2c osmtogeojson ajv flock mutt bzip2 xmllint ogr2ogr; do
  cat > "${mock_dir}/${cmd}" << 'EOF'
#!/bin/bash
if [[ "$1" == "--version" ]] || [[ "$1" == "-v" ]] || [[ "$1" == "--help" ]] || [[ "$1" == "help" ]]; then
    echo "mock ${cmd} version 1.0"
    exit 0
else
    exit 0
fi
EOF
  chmod +x "${mock_dir}/${cmd}"
 done

 # Mock other commands
 for cmd in awk curl grep free uptime ulimit prlimit bc timeout jq gdalinfo cut tail head; do
  cat > "${mock_dir}/${cmd}" << 'EOF'
#!/bin/bash
exit 0
EOF
  chmod +x "${mock_dir}/${cmd}"
 done

 # Create mock required files
 mkdir -p "${mock_dir}/data" "${mock_dir}/sql" "${mock_dir}/xsd" "${mock_dir}/json"
 touch "${mock_dir}/data/noteLocation.csv.zip"
 touch "${mock_dir}/sql/test.sql"
 touch "${mock_dir}/xsd/test.xsd"
 touch "${mock_dir}/json/test.json"
 touch "${mock_dir}/json/test.geojson"

 # Set variables to point to mock files
 export CSV_BACKUP_NOTE_LOCATION_COMPRESSED="${mock_dir}/data/noteLocation.csv.zip"
 export POSTGRES_32_UPLOAD_NOTE_LOCATION="${mock_dir}/sql/test.sql"
 export XMLSCHEMA_PLANET_NOTES="${mock_dir}/xsd/test.xsd"
 export JSON_SCHEMA_OVERPASS="${mock_dir}/json/test.json"
 export JSON_SCHEMA_GEOJSON="${mock_dir}/json/test.geojson"
 export GEOJSON_TEST="${mock_dir}/json/test.geojson"

 # Temporarily replace PATH with mock tools
 local original_path="${PATH}"
 export PATH="${mock_dir}:${PATH}"

 # Test with mocks
 run __checkPrereqsCommands
 [ "$status" -eq 0 ]

 # Restore original PATH
 export PATH="${original_path}"
 rm -rf "${mock_dir}"
}
