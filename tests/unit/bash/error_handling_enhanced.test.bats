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
  function curl() { return 1; }
  
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
  # Create a test XML file with valid dates
  cat > "${TMP_DIR}/test.xml" << 'EOF'
<?xml version="1.0"?>
<osm-notes>
  <note id="1" created_at="2023-01-01T12:00:00Z" closed_at="2023-01-02T12:00:00Z">
    <comment timestamp="2023-01-01T13:00:00Z" />
  </note>
</osm-notes>
EOF
  
  # Mock xmlstarlet to return valid dates
  function xmlstarlet() {
    echo "2023-01-01T12:00:00Z"
    echo "2023-01-02T12:00:00Z"
    echo "2023-01-01T13:00:00Z"
  }
  
  run __validate_xml_dates "${TMP_DIR}/test.xml"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DEBUG: XML date validation passed"* ]]
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
  
  # Test the scenario where network connectivity fails
  run __getNewNotesFromApi
  [ "$status" -eq 0 ]
  [[ "$output" == *"ERROR: Network connectivity check failed"* ]]
  [[ "$output" == *"EXIT: 251"* ]]  # ERROR_INTERNET_ISSUE
}

@test "test integration of error handling in Planet download scenario" {
  # Mock network check to fail
  function __check_network_connectivity() { return 1; }
  
  # Mock exit to prevent actual exit
  function exit() { echo "EXIT: $1"; return 0; }
  
  # Test the scenario where network connectivity fails during Planet download
  run __downloadPlanetNotes
  [ "$status" -eq 0 ]
  [[ "$output" == *"ERROR: Network connectivity check failed"* ]]
  [[ "$output" == *"EXIT: 251"* ]]  # ERROR_INTERNET_ISSUE
} 