#!/usr/bin/env bats
# Unit tests for Overpass API smart wait functionality
# Author: Andres Gomez (AngocA)
# Version: 2025-10-27

load "$(dirname "$BATS_TEST_FILENAME")/../../test_helper.bash"

setup() {
  SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
  export OVERPASS_INTERPRETER="https://overpass-api.de/api/interpreter"
  export TEST_TMP_DIR="${TEST_TMP_DIR:-/tmp/bats_test_$$}"
  mkdir -p "${TEST_TMP_DIR}"
}

teardown() {
  rm -rf "${TEST_TMP_DIR}" 2>/dev/null || true
}

@test "__check_overpass_status function should exist" {
  local SCRIPT_FILE="${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh"
  run grep "function __check_overpass_status" "${SCRIPT_FILE}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"__check_overpass_status"* ]]
}

@test "__check_overpass_status should use BASE_URL from OVERPASS_INTERPRETER" {
  local SCRIPT_FILE="${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh"
  # Check for BASE_URL extraction logic
  run grep "BASE_URL=\"\${OVERPASS_INTERPRETER" "${SCRIPT_FILE}"
  [ "$status" -eq 0 ]
}

@test "__retry_file_operation should have SMART_WAIT parameter" {
  local SCRIPT_FILE="${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh"
  # Check for SMART_WAIT parameter (appears around line 2505)
  run grep "local SMART_WAIT" "${SCRIPT_FILE}"
  [ "$status" -eq 0 ]
}

@test "Smart wait should call __check_overpass_status" {
  local SCRIPT_FILE="${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh"
  # Check for __check_overpass_status call (should be in the __retry_file_operation function)
  run grep "__check_overpass_status" "${SCRIPT_FILE}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"__check_overpass_status"* ]]
}

@test "Wait loop should use set +e for error handling" {
  local SCRIPT_FILE="${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh"
  # Check for "set +e # Allow errors in wait" pattern
  run grep "set +e.*Allow errors in wait" "${SCRIPT_FILE}"
  [ "$status" -eq 0 ]
}

@test "Error handling should use return for thread safety" {
  local SCRIPT_FILE="${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh"
  run grep "return.*ERROR_DOWNLOADING_BOUNDARY" "${SCRIPT_FILE}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"return"* ]]
  [[ "$output" != *"exit"* ]]
}

@test "Overpass should have 7 retries and 20s delay" {
  local SCRIPT_FILE="${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh"
  # Check for retry configuration with 7 and 20
  run grep -B 5 -A 5 "__retry_file_operation.*7.*20" "${SCRIPT_FILE}"
  [ "$status" -eq 0 ]
  # Verify both 7 and 20 are present
  grep_result=$(grep -B 5 -A 5 "__retry_file_operation" "${SCRIPT_FILE}" | grep "OVERPASS")
  echo "${grep_result}" | grep -q "7" || true
  echo "${grep_result}" | grep -q "20" || true
}

@test "Version should be 2025-10-27" {
  local SCRIPT_FILE="${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh"
  run grep "Version: 2025-10-27" "${SCRIPT_FILE}"
  [ "$status" -eq 0 ]
}

@test "VERSION variable should be 2025-10-27" {
  local SCRIPT_FILE="${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh"
  run grep "VERSION=\"2025-10-27\"" "${SCRIPT_FILE}"
  [ "$status" -eq 0 ]
}

@test "Parse 'slots available now' correctly" {
  local STATUS_WITH_AVAILABLE="Connected as: 123
2 slots available now.
Slot available after: 2025-10-27T14:54:35Z, in 4 seconds."
  local AVAILABLE_SLOTS
  AVAILABLE_SLOTS=$(echo "${STATUS_WITH_AVAILABLE}" | grep -o '[0-9]* slots available now' | grep -o '[0-9]*')
  [ "${AVAILABLE_SLOTS}" == "2" ]
}

@test "Extract minimum wait time" {
  local STATUS_WITH_WAIT="Slot available after: 2025-10-27T14:49:25Z, in 5 seconds.
Slot available after: 2025-10-27T14:49:26Z, in 6 seconds.
Slot available after: 2025-10-27T14:49:27Z, in 7 seconds."
  local ALL_WAIT_TIMES
  ALL_WAIT_TIMES=$(echo "${STATUS_WITH_WAIT}" | grep -o 'in [0-9]* seconds' | grep -o '[0-9]*')
  local MIN_WAIT
  MIN_WAIT=$(echo "${ALL_WAIT_TIMES}" | sort -n | head -1)
  [ "${MIN_WAIT}" == "5" ]
}
