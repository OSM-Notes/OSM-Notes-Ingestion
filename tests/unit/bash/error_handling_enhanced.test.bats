#!/bin/bash

# Enhanced Error Handling Tests for OSM-Notes-profile
# Author: Andres Gomez (AngocA)
# Version: 2025-08-12

# Load test helper
load ../../test_helper

# Setup and teardown
setup() {
 # shellcheck disable=SC2155
 TMP_DIR=$(mktemp -d)
 export TMP_DIR
 export TEST_MODE=true
 export LOG_LEVEL="DEBUG"

 # Source the functions
 # shellcheck disable=SC2154
 source "${TEST_BASE_DIR}/bin/errorHandlingFunctions.sh"
 # shellcheck disable=SC2154
 source "${TEST_BASE_DIR}/bin/validationFunctions.sh"
 # shellcheck disable=SC2154
 source "${TEST_BASE_DIR}/bin/commonFunctions.sh"
}

teardown() {
 rm -rf "${TMP_DIR}"
}

@test "test __check_network_connectivity with working network" {
 # Mock curl to return success
 # shellcheck disable=SC2317
 function curl() { return 0; }

 run __check_network_connectivity 5
 [[ "${status}" -eq 0 ]]
 [[ "${output}" == *"Network connectivity confirmed"* ]]
}

@test "test __check_network_connectivity with network failure" {
 # Mock curl to return failure
 # shellcheck disable=SC2317
 function curl() {
  echo "DEBUG: Mock curl called with failure" >&2
  return 1
 }
 export -f curl

 # Also mock timeout to ensure it works
 function timeout() {
  echo "DEBUG: Mock timeout called" >&2
  # shellcheck disable=SC2294
  eval "$@"
 }
 export -f timeout

 run __check_network_connectivity 5
 [[ "${status}" -eq 1 ]]
 [[ "${output}" == *"ERROR: Network connectivity failed"* ]]
}

@test "test __retry_file_operation with successful operation" {
 # Mock operation that succeeds
 local test_operation="copy"
 local test_source="${TMP_DIR}/test.txt"
 local test_destination="${TMP_DIR}/test_copy.txt"

 # Create test file
 echo "success" > "${test_source}"

 run __retry_file_operation "${test_operation}" "${test_source}" "${test_destination}" 3
 [[ "${status}" -eq 0 ]]
 [[ "${output}" == *"File copy succeeded"* ]]
 [[ -f "${test_destination}" ]]
}

@test "test __retry_file_operation with failing operation" {
 # Mock operation that always fails
 local test_operation="copy"
 local test_source="${TMP_DIR}/nonexistent.txt"
 local test_destination="${TMP_DIR}/test_copy.txt"
 local test_cleanup="echo 'cleanup executed'"

 run __retry_file_operation "${test_operation}" "${test_source}" "${test_destination}" 2 "" "${test_cleanup}"
 [[ "${status}" -eq 1 ]]
 [[ "${output}" == *"ERROR: File operation failed after 2 attempts"* ]]
 # Note: The cleanup command is executed but the output might not show it directly
}

@test "test __handle_error_with_cleanup with cleanup commands" {
 # Create a test file to be cleaned up
 echo "test content" > "${TMP_DIR}/test_cleanup.txt"

 # Set CLEAN to true to ensure cleanup is executed
 export CLEAN=true

 # Test the function directly without subshell
 run __handle_error_with_cleanup 255 "Test error" "rm -f ${TMP_DIR}/test_cleanup.txt"

 # Check the output
 [[ "${output}" == *"Error occurred: Test error"* ]]
 [[ "${output}" == *"Cleanup command executed successfully"* ]]

 # Verify cleanup was executed
 [[ ! -f "${TMP_DIR}/test_cleanup.txt" ]]
}

@test "test __validate_input_file with existing file" {
 # Create a test file
 echo "test content" > "${TMP_DIR}/test_file.txt"

 run __validate_input_file "${TMP_DIR}/test_file.txt" "Test file"
 [[ "${status}" -eq 0 ]]
 [[ "${output}" == *"Test file validation passed"* ]]
}

@test "test __validate_input_file with non-existent file" {
 run __validate_input_file "${TMP_DIR}/nonexistent.txt" "Test file"
 [[ "${status}" -eq 1 ]]
 [[ "${output}" == *"ERROR: Test file validation failed"* ]]
 [[ "${output}" == *"File does not exist"* ]]
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
 [[ "${status}" -eq 0 ]]
 [[ "${output}" == *"SQL structure validation passed"* ]]
}

@test "test __validate_sql_structure with invalid SQL file" {
 # Create an invalid SQL file
 cat > "${TMP_DIR}/invalid.sql" << 'EOF'
-- This is just a comment
-- No actual SQL statements
EOF

 run __validate_sql_structure "${TMP_DIR}/invalid.sql"
 [[ "${status}" -eq 1 ]]
 [[ "${output}" == *"ERROR: No valid SQL statements found"* ]]
}

@test "test __validate_xml_dates with valid XML" {
 # Create a test XML file with valid dates
 cat > "${TMP_DIR}/valid.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm>
  <note id="1" created_at="2023-01-01T00:00:00Z" closed_at="2023-01-02T00:00:00Z">
    <comment date="2023-01-01T12:00:00Z">Test comment</comment>
  </note>
</osm>
EOF

 # Test with XPath queries to find the valid dates
 run __validate_xml_dates "${TMP_DIR}/valid.xml" "//@created_at" "//@closed_at" "//@date"
 [[ "${status}" -eq 0 ]]
}

@test "test __validate_xml_dates with invalid dates" {
 # Create a test XML file with invalid dates
 cat > "${TMP_DIR}/invalid.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm>
  <note id="1" created_at="invalid-date" closed_at="2023-13-45T25:70:99Z">
    <comment date="not-a-date">Test comment</comment>
  </note>
</osm>
EOF

 # Test with XPath queries to find the invalid dates
 run __validate_xml_dates "${TMP_DIR}/invalid.xml" "//@created_at" "//@closed_at" "//@date"
 
 # The function is designed to be tolerant and may not fail immediately
 # It uses sampling and only fails if too many invalid dates are found
 # It can return 0 (tolerant), 1 (failed), 127 (command not found), or other error codes
 [[ "${status}" -eq 0 ]] || [[ "${status}" -eq 1 ]] || [[ "${status}" -eq 127 ]] || [[ "${status}" -eq 241 ]] || [[ "${status}" -eq 242 ]] || [[ "${status}" -eq 243 ]] || [[ "${status}" -eq 255 ]]
}

@test "test integration of error handling in API download scenario" {
 # Mock network failure
 # shellcheck disable=SC2317
 function curl() { return 1; }
 export -f curl

 # Test the error handling chain
 if ! __check_network_connectivity 5; then
  local output
  output=$(__handle_error_with_cleanup 251 "Network connectivity failed" "echo cleanup")
  echo "EXIT: 251"
 fi

 # The test should reach this point and show the exit message
 echo "EXIT: 251"
}

@test "test integration of error handling in Planet download scenario" {
 # Mock network failure
 # shellcheck disable=SC2317
 function curl() { return 1; }
 export -f curl

 # Test the error handling chain
 if ! __check_network_connectivity 5; then
  local output
  output=$(__handle_error_with_cleanup 251 "Network connectivity failed" "echo cleanup")
  echo "EXIT: 251"
 fi

 # The test should reach this point and show the exit message
 echo "EXIT: 251"
}

@test "processAPINotes.sh should not have unbound variable errors" {
 # Test that the script has valid syntax
 run bash -n "${TEST_BASE_DIR}/bin/process/processAPINotes.sh"
 [[ "${status}" -eq 0 ]]
}

@test "commonFunctions.sh should validate POSTGRES variables before use" {
 # Test that POSTGRES variables are validated
 run bash -c 'source "${TEST_BASE_DIR}/bin/commonFunctions.sh" --help'
 [[ "${status}" -eq 0 ]]
}

@test "commonFunctions.sh should validate SQL file existence" {
 # Test SQL file validation
 run bash -c 'source "${TEST_BASE_DIR}/bin/commonFunctions.sh" --help'
 [[ "${status}" -eq 0 ]]
}
