#!/usr/bin/env bats

# Author: Andres Gomez (AngocA)
# Version: 2025-10-30

# Mock test to verify failed marker creation behavior similar to processAPINotes.sh

setup() {
 load "${BATS_TEST_DIRNAME}/../../test_helper.bash"
 export SCRIPT_BASE_DIRECTORY
 export TMP_DIR="$(mktemp -d)"
 export FAILED_EXECUTION_FILE="${TMP_DIR}/processAPINotes_failed_execution"
 export GENERATE_FAILED_FILE=true
}

teardown() {
 rm -rf "${TMP_DIR}" 2>/dev/null || true
}

# Mock of the writing block used by processAPINotes.sh trap
mock_write_failed_marker() {
 local MAIN_SCRIPT_NAME="processAPINotes"
 local ERROR_LINE="123"
 local ERROR_COMMAND="failing_command"
 local ERROR_EXIT_CODE="1"
 {
  echo "Error occurred at $(date +%Y%m%d_%H:%M:%S)"
  echo "Script: ${MAIN_SCRIPT_NAME}"
  echo "Line number: ${ERROR_LINE}"
  echo "Failed command: ${ERROR_COMMAND}"
  echo "Exit code: ${ERROR_EXIT_CODE}"
  echo "Temporary directory: ${TMP_DIR:-unknown}"
  echo "Process ID: $$"
 } > "${FAILED_EXECUTION_FILE}"
}

@test "failed marker file is created on mock trap" {
 run bash -c "set -e; set -u; TMP_DIR='${TMP_DIR}'; FAILED_EXECUTION_FILE='${FAILED_EXECUTION_FILE}'; $(declare -f mock_write_failed_marker); mock_write_failed_marker; test -s '${FAILED_EXECUTION_FILE}'"
 [ "$status" -eq 0 ]
 [[ -f "${FAILED_EXECUTION_FILE}" ]]
 [[ -s "${FAILED_EXECUTION_FILE}" ]]
}

@test "failed marker contains expected fields" {
 # Create marker in this test's environment
 bash -c "set -e; set -u; TMP_DIR='${TMP_DIR}'; FAILED_EXECUTION_FILE='${FAILED_EXECUTION_FILE}'; $(declare -f mock_write_failed_marker); mock_write_failed_marker"
 run cat "${FAILED_EXECUTION_FILE}"
 [ "$status" -eq 0 ]
 [[ "$output" == *"Script:"* ]]
 [[ "$output" == *"Line number:"* ]]
 [[ "$output" == *"Failed command:"* ]]
 [[ "$output" == *"Exit code:"* ]]
 [[ "$output" == *"Temporary directory: ${TMP_DIR}"* ]]
}

@test "failed marker can be cleaned up for recovery" {
 # Create marker then remove
 bash -c "set -e; set -u; TMP_DIR='${TMP_DIR}'; FAILED_EXECUTION_FILE='${FAILED_EXECUTION_FILE}'; $(declare -f mock_write_failed_marker); mock_write_failed_marker"
 run bash -c "rm -f '${FAILED_EXECUTION_FILE}'; test ! -f '${FAILED_EXECUTION_FILE}'"
 [ "$status" -eq 0 ]
}
