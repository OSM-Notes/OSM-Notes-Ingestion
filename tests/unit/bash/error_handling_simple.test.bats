#!/usr/bin/env bats

# Simplified tests for error handling functions
# Author: Andres Gomez (AngocA)
# Version: 2025-08-12

load "${BATS_TEST_DIRNAME}/../../test_helper"

setup() {
 # Create temporary test directory
 TEST_DIR=$(mktemp -d)
 export TEST_DIR
}

teardown() {
 # Clean up test files
 rm -rf "${TEST_DIR}"
}

@test "check_network_connectivity should succeed with internet" {
 # Mock curl to simulate successful connectivity check
 cat > "${TEST_DIR}/curl" << 'EOF'
#!/bin/bash
if [[ "$*" == *"timeout"* ]]; then
 exit 0
fi
exit 1
EOF
 chmod +x "${TEST_DIR}/curl"
 export PATH="${TEST_DIR}:${PATH}"

 run __check_network_connectivity 5
 [ "$status" -eq 0 ]
 [[ "$output" == *"Network connectivity confirmed"* ]]
}

@test "handle_error_with_cleanup should execute cleanup commands" {
 # Test error handling with cleanup
 # Use absolute paths to ensure cleanup commands work in function context
 local CLEANUP1="${TEST_DIR}/cleanup1.txt"
 local CLEANUP2="${TEST_DIR}/cleanup2.txt"
 
 # Ensure TEST_MODE is set for this test
 export TEST_MODE="true"
 
 # Set BATS environment variables explicitly
 export BATS_TEST_DIRNAME="test"
 export BATS_ROOT="test"
 export BATS_VERSION="test"
 
 # Ensure CLEAN is set to true for this test
 export CLEAN="true"
 
 # Debug: show what we're testing
 echo "Testing cleanup with files: ${CLEANUP1} and ${CLEANUP2}"
 echo "TEST_DIR: ${TEST_DIR}"
 echo "Current working directory: $(pwd)"
 echo "CLEAN: ${CLEAN}"
 
 run __handle_error_with_cleanup 255 "Test error" "echo 'cleanup1' > '${CLEANUP1}'" "echo 'cleanup2' > '${CLEANUP2}'"
 echo "Function exit code: ${status}"
 echo "Function output: ${output}"
 
 [ "$status" -eq 255 ]
 [ -f "${CLEANUP1}" ]
 [ -f "${CLEANUP2}" ]
 [[ "$(cat "${CLEANUP1}")" == "cleanup1" ]]
 [[ "$(cat "${CLEANUP2}")" == "cleanup2" ]]
}

@test "error handling functions should be available" {
 # Test that all error handling functions exist
 run declare -f __check_network_connectivity
 [ "$status" -eq 0 ]
 [[ "$output" == *"__check_network_connectivity"* ]]

 run declare -f __handle_error_with_cleanup
 [ "$status" -eq 0 ]
 [[ "$output" == *"__handle_error_with_cleanup"* ]]

 run declare -f __retry_file_operation
 [ "$status" -eq 0 ]
 [[ "$output" == *"__retry_file_operation"* ]]

 run declare -f __validate_input_file
 [ "$status" -eq 0 ]
 [[ "$output" == *"__validate_input_file"* ]]

 run declare -f __validate_sql_structure
 [ "$status" -eq 0 ]
 [[ "$output" == *"__validate_sql_structure"* ]]

 run declare -f __validate_xml_dates
 [ "$status" -eq 0 ]
 [[ "$output" == *"__validate_xml_dates"* ]]
}

@test "retry_file_operation should succeed with valid operation" {
 # Test successful file operation
 run __retry_file_operation "echo 'test' > ${TEST_DIR}/test.txt"
 [ "$status" -eq 0 ]
 [ -f "${TEST_DIR}/test.txt" ]
}

@test "retry_file_operation should fail with invalid operation" {
 # Test file operation that fails
 run __retry_file_operation "false" 2>&1
 [ "$status" -eq 1 ]
 [[ "$output" == *"File operation failed"* ]]
}

@test "validate_input_file should succeed with existing file" {
  # Create a test file
  echo "test content" > "${TEST_DIR}/test_file.txt"
  
  run __validate_input_file "${TEST_DIR}/test_file.txt" "Test file"
  [ "$status" -eq 0 ]
}

@test "validate_input_file should fail with non-existent file" {
  run __validate_input_file "${TEST_DIR}/nonexistent.txt" "Test file"
  [ "$status" -eq 1 ]
}

@test "validate_sql_structure should succeed with valid SQL" {
  # Create a test SQL file
  cat > "${TEST_DIR}/test.sql" << 'EOF'
CREATE TABLE test_table (
  id INTEGER PRIMARY KEY,
  name VARCHAR(100)
);
INSERT INTO test_table VALUES (1, 'test');
EOF
  
  run __validate_sql_structure "${TEST_DIR}/test.sql"
  [ "$status" -eq 0 ]
}

@test "validate_xml_dates should succeed with valid XML" {
 # Create a test XML file with valid dates in the expected format
 cat > "${TEST_DIR}/test.xml" << 'EOF'
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
 
 run __validate_xml_dates "${TEST_DIR}/test.xml"
 [ "$status" -eq 0 ]
} 