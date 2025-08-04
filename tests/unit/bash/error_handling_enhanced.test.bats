#!/usr/bin/env bats

# Test file for enhanced error handling functions
# Tests the new error handling functions added to functionsProcess.sh
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-29

load ../../test_helper

setup() {
  # Setup test environment
  export SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
  export TMP_DIR="$(mktemp -d)"
  export BASENAME="test_error_handling"
  
  # Ensure TMP_DIR exists and is writable
  if [[ ! -d "${TMP_DIR}" ]]; then
    mkdir -p "${TMP_DIR}"
  fi
  
  # Source the functions
  source "${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh"
  
  # Mock logger functions
  function __log_start() { echo "LOG_START: $*"; }
  function __log_finish() { echo "LOG_FINISH: $*"; }
  function __logi() { echo "INFO: $*"; }
  function __loge() { echo "ERROR: $*"; }
  function __logw() { echo "WARN: $*"; }
  function __logd() { echo "DEBUG: $*"; }
}

teardown() {
  # Cleanup test environment
  rm -rf "${TMP_DIR}"
}

@test "test __check_network_connectivity with working network" {
  # Mock curl to return success
  function curl() { return 0; }
  
  run __check_network_connectivity 5
  [ "$status" -eq 0 ]
  [[ "$output" == *"DEBUG: Network connectivity confirmed"* ]]
}

@test "test __check_network_connectivity with network failure" {
  # Mock curl to return failure
  function curl() { 
    echo "DEBUG: Mock curl called with failure" >&2
    return 1; 
  }
  export -f curl
  
  # Also mock timeout to ensure it works
  function timeout() {
    echo "DEBUG: Mock timeout called" >&2
    eval "$@"
  }
  export -f timeout
  
  run __check_network_connectivity 5
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: Network connectivity check failed"* ]]
}

@test "test __retry_file_operation with successful operation" {
  # Mock operation that succeeds
  local test_operation="echo 'success' > ${TMP_DIR}/test.txt"
  local test_cleanup="rm -f ${TMP_DIR}/test.txt"
  
  run __retry_file_operation "${test_operation}" 3 1 "${test_cleanup}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DEBUG: File operation succeeded"* ]]
  [ -f "${TMP_DIR}/test.txt" ]
}

@test "test __retry_file_operation with failing operation" {
  # Mock operation that always fails
  local test_operation="false"
  local test_cleanup="echo 'cleanup executed'"
  
  run __retry_file_operation "${test_operation}" 2 1 "${test_cleanup}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: File operation failed after 2 attempts"* ]]
  [[ "$output" == *"cleanup executed"* ]]
}

@test "test __handle_error_with_cleanup with cleanup commands" {
  # Create a test file to be cleaned up
  echo "test content" > "${TMP_DIR}/test_cleanup.txt"
  
  # Mock exit to prevent actual exit
  function exit() { echo "EXIT: $1"; return 0; }
  
  run __handle_error_with_cleanup 255 "Test error" "rm -f ${TMP_DIR}/test_cleanup.txt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ERROR: Error occurred: Test error"* ]]
  [[ "$output" == *"DEBUG: Cleanup command succeeded"* ]]
  [[ "$output" == *"EXIT: 255"* ]]
  
  # Verify cleanup was executed
  [ ! -f "${TMP_DIR}/test_cleanup.txt" ]
}

@test "test __validate_input_file with existing file" {
  # Create a test file
  echo "test content" > "${TMP_DIR}/test_file.txt"
  
  run __validate_input_file "${TMP_DIR}/test_file.txt" "Test file"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DEBUG: Test file validation passed"* ]]
}

@test "test __validate_input_file with non-existent file" {
  run __validate_input_file "${TMP_DIR}/nonexistent.txt" "Test file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: Test file validation failed"* ]]
  [[ "$output" == *"File does not exist"* ]]
}

@test "test __validate_sql_structure with valid SQL file" {
  # Create a test SQL file
  cat > "${TMP_DIR}/test.sql" << 'EOF'
CREATE TABLE test_table (
  id INTEGER PRIMARY KEY,
  name VARCHAR(100)
);
INSERT INTO test_table VALUES (1, 'test');
EOF
  
  run __validate_sql_structure "${TMP_DIR}/test.sql"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DEBUG: SQL structure validation passed"* ]]
}

@test "test __validate_sql_structure with invalid SQL file" {
  # Create an invalid SQL file
  echo "This is not SQL content" > "${TMP_DIR}/invalid.sql"
  
  run __validate_sql_structure "${TMP_DIR}/invalid.sql"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: SQL structure validation failed"* ]]
}

@test "test __validate_xml_dates with valid XML" {
  # Create a test XML file with valid dates in the expected format
  cat > "${TMP_DIR}/test.xml" << 'EOF'
<?xml version="1.0"?>
<osm-notes>
  <note id="1" created_at="2023-01-01 12:00:00 UTC" closed_at="2023-01-02 12:00:00 UTC">
    <comment timestamp="2023-01-01 13:00:00 UTC" />
  </note>
</osm-notes>
EOF
  
  # Mock xmllint to return valid dates
  function xmllint() {
    if [[ "$*" == *"--xpath"* ]]; then
      echo "2023-01-01 12:00:00 UTC"
      echo "2023-01-02 12:00:00 UTC"
      echo "2023-01-01 13:00:00 UTC"
    else
      command xmllint "$@"
    fi
  }
  export -f xmllint
  
  run __validate_xml_dates "${TMP_DIR}/test.xml"
  [ "$status" -eq 0 ]
}

@test "test __validate_xml_dates with invalid dates" {
  # Create a test XML file with invalid dates
  cat > "${TMP_DIR}/test.xml" << 'EOF'
<?xml version="1.0"?>
<osm-notes>
  <note id="1" created_at="invalid-date" closed_at="2023-13-45T25:70:99Z">
    <comment timestamp="not-a-date" />
  </note>
</osm-notes>
EOF
  
  # Mock xmlstarlet to return invalid dates
  function xmlstarlet() {
    echo "invalid-date"
    echo "2023-13-45T25:70:99Z"
    echo "not-a-date"
  }
  
  run __validate_xml_dates "${TMP_DIR}/test.xml"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: XML date validation failed"* ]]
}

@test "test integration of error handling in API download scenario" {
  # Mock network check to fail
  function __check_network_connectivity() { return 1; }
  
  # Mock exit to prevent actual exit
  function exit() { echo "EXIT: $1"; return 0; }
  
  # Mock the function since it's not available in this test context
  function __getNewNotesFromApi() {
    if ! __check_network_connectivity 10; then
      __handle_error_with_cleanup 251 "Network connectivity check failed" "echo 'cleanup'"
    fi
    echo "API download successful"
  }
  
  # Test the scenario where network connectivity fails
  run __getNewNotesFromApi 2>&1
  [ "$status" -eq 0 ]
  [[ "$output" == *"ERROR: Error occurred: Network connectivity check failed"* ]]
  [[ "$output" == *"EXIT: 251"* ]]  # ERROR_INTERNET_ISSUE
}

@test "test integration of error handling in Planet download scenario" {
  # Mock network check to fail
  function __check_network_connectivity() { return 1; }
  
  # Mock exit to prevent actual exit
  function exit() { echo "EXIT: $1"; return 0; }
  
  # Mock the function since it's not available in this test context
  function __downloadPlanetNotes() {
    if ! __check_network_connectivity 10; then
      __handle_error_with_cleanup 251 "Network connectivity check failed" "echo 'cleanup'"
    fi
    echo "Planet download successful"
  }
  
  # Test the scenario where network connectivity fails during Planet download
  run __downloadPlanetNotes 2>&1
  [ "$status" -eq 0 ]
  [[ "$output" == *"ERROR: Error occurred: Network connectivity check failed"* ]]
  [[ "$output" == *"EXIT: 251"* ]]  # ERROR_INTERNET_ISSUE
} 

@test "processAPINotes.sh should not have unbound variable errors" {
 # Test that processAPINotes.sh loads without unbound variable errors
 # We'll just check the sourcing part without running the full script
 run bash -c "cd /home/angoca/github/OSM-Notes-profile && bash -n bin/process/processAPINotes.sh"
 [ "$status" -eq 0 ]
 
 # Also test that the script can be sourced without unbound variable errors
 run bash -c "cd /home/angoca/github/OSM-Notes-profile && timeout 5 bash -c 'source bin/process/processAPINotes.sh' 2>&1 || true"
 [[ "$output" != *"unbound variable"* ]]
 [[ "$output" != *"POSTGRES_11_CHECK_BASE_TABLES: unbound variable"* ]]
}

@test "commonFunctions.sh should validate POSTGRES variables before use" {
 # Test that POSTGRES variables are defined in functionsProcess.sh
 run bash -c "cd /home/angoca/github/OSM-Notes-profile && source bin/functionsProcess.sh && echo \"POSTGRES_11_CHECK_BASE_TABLES: \${POSTGRES_11_CHECK_BASE_TABLES:-NOT_SET}\""
 [ "$status" -eq 0 ]
 [[ "$output" == *"POSTGRES_11_CHECK_BASE_TABLES:"* ]]
 [[ "$output" != *"NOT_SET"* ]]
}

@test "commonFunctions.sh should validate SQL file existence" {
 # Test that SQL files exist
 run bash -c "cd /home/angoca/github/OSM-Notes-profile && source bin/functionsProcess.sh && ls -la \${POSTGRES_11_CHECK_BASE_TABLES}"
 [ "$status" -eq 0 ]
 [[ "$output" == *"functionsProcess_11_checkBaseTables.sql"* ]]
} 