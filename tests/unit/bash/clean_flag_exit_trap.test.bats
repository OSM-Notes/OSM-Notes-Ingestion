#!/usr/bin/env bats

# Unit tests for CLEAN flag handling with exit trap
# Test file: clean_flag_exit_trap.test.bats
# Author: Andres Gomez (AngocA)
# Version: 2025-08-13

load "../../test_helper.bash"

setup() {
  # Create a temporary directory for testing
  TEST_TMP_DIR=$(mktemp -d "/tmp/clean_flag_test_XXXXXX")
  
  # Create some test files
  touch "${TEST_TMP_DIR}/test_file1.txt"
  touch "${TEST_TMP_DIR}/test_file2.xml"
  mkdir -p "${TEST_TMP_DIR}/subdir"
  touch "${TEST_TMP_DIR}/subdir/nested_file.csv"
}

teardown() {
  # Clean up test directory if it still exists
  if [[ -d "${TEST_TMP_DIR}" ]]; then
    rm -rf "${TEST_TMP_DIR}"
  fi
}

@test "trap function __cleanup_on_exit exists in processPlanetNotes" {
  # Check that the cleanup function is defined
  grep -q "function __cleanup_on_exit" "${SCRIPT_BASE_DIRECTORY}/bin/process/processPlanetNotes.sh"
}

@test "trap is set for EXIT in processPlanetNotes" {
  # Check that the trap is properly set
  grep -q "trap '__cleanup_on_exit' EXIT" "${SCRIPT_BASE_DIRECTORY}/bin/process/processPlanetNotes.sh"
}

@test "__processCountries uses __handle_error_with_cleanup instead of direct exit" {
  # Check that __processCountries no longer uses direct exit
  ! grep -q "exit.*ERROR_DOWNLOADING_BOUNDARY" "${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh"
  
  # Check that it uses the error handler instead
  grep -q "__handle_error_with_cleanup.*ERROR_DOWNLOADING_BOUNDARY" "${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh"
}

@test "cleanup function respects CLEAN=true for error exits" {
  # Create a minimal test script that simulates the cleanup behavior
  cat > "${TEST_TMP_DIR}/test_cleanup_true.sh" << 'EOF'
#!/bin/bash
CLEAN="true"
TMP_DIR="${TEST_TMP_DIR}"

function __logw() { echo "WARN: $*"; }
function __logi() { echo "INFO: $*"; }

function __cleanup_on_exit() {
 local EXIT_CODE=$?
 
 if [[ "${CLEAN}" == "true" ]] && [[ $EXIT_CODE -ne 0 ]] && [[ -n "${TMP_DIR:-}" ]]; then
  __logw "Error detected (exit code: $EXIT_CODE), cleaning up temporary directory: ${TMP_DIR}"
  if [[ -d "${TMP_DIR}" ]]; then
   rm -rf "${TMP_DIR}" 2>/dev/null || true
   __logi "Temporary directory cleaned up: ${TMP_DIR}"
  fi
 elif [[ "${CLEAN}" == "false" ]] && [[ $EXIT_CODE -ne 0 ]]; then
  __logw "Error detected (exit code: $EXIT_CODE), but CLEAN=false - preserving temporary files in: ${TMP_DIR:-}"
 fi
 
 exit $EXIT_CODE
}

trap '__cleanup_on_exit' EXIT

# Simulate an error
exit 1
EOF

  chmod +x "${TEST_TMP_DIR}/test_cleanup_true.sh"
  
  # Replace TEST_TMP_DIR placeholder with actual path
  sed -i "s|\${TEST_TMP_DIR}|${TEST_TMP_DIR}|g" "${TEST_TMP_DIR}/test_cleanup_true.sh"
  
  # Run the test script (it should fail with exit 1, but clean up)
  run "${TEST_TMP_DIR}/test_cleanup_true.sh"
  [ "$status" -eq 1 ]
  
  # Directory should be cleaned up
  [ ! -d "${TEST_TMP_DIR}" ]
  
  # Recreate for teardown
  mkdir -p "${TEST_TMP_DIR}"
}

@test "cleanup function respects CLEAN=false for error exits" {
  # Create a minimal test script that simulates the cleanup behavior
  cat > "${TEST_TMP_DIR}/test_cleanup_false.sh" << 'EOF'
#!/bin/bash
CLEAN="false"
TMP_DIR="${TEST_TMP_DIR}"

function __logw() { echo "WARN: $*"; }
function __logi() { echo "INFO: $*"; }

function __cleanup_on_exit() {
 local EXIT_CODE=$?
 
 if [[ "${CLEAN}" == "true" ]] && [[ $EXIT_CODE -ne 0 ]] && [[ -n "${TMP_DIR:-}" ]]; then
  __logw "Error detected (exit code: $EXIT_CODE), cleaning up temporary directory: ${TMP_DIR}"
  if [[ -d "${TMP_DIR}" ]]; then
   rm -rf "${TMP_DIR}" 2>/dev/null || true
   __logi "Temporary directory cleaned up: ${TMP_DIR}"
  fi
 elif [[ "${CLEAN}" == "false" ]] && [[ $EXIT_CODE -ne 0 ]]; then
  __logw "Error detected (exit code: $EXIT_CODE), but CLEAN=false - preserving temporary files in: ${TMP_DIR:-}"
 fi
 
 exit $EXIT_CODE
}

trap '__cleanup_on_exit' EXIT

# Simulate an error
exit 1
EOF

  chmod +x "${TEST_TMP_DIR}/test_cleanup_false.sh"
  
  # Replace TEST_TMP_DIR placeholder with actual path
  sed -i "s|\${TEST_TMP_DIR}|${TEST_TMP_DIR}|g" "${TEST_TMP_DIR}/test_cleanup_false.sh"
  
  # Run the test script (it should fail with exit 1, but NOT clean up)
  run "${TEST_TMP_DIR}/test_cleanup_false.sh"
  [ "$status" -eq 1 ]
  
  # Check that output contains the preservation message
  [[ "$output" == *"CLEAN=false - preserving temporary files"* ]]
  
  # Directory should still exist
  [ -d "${TEST_TMP_DIR}" ]
  [ -f "${TEST_TMP_DIR}/test_file1.txt" ]
  [ -f "${TEST_TMP_DIR}/test_file2.xml" ]
  [ -f "${TEST_TMP_DIR}/subdir/nested_file.csv" ]
}



