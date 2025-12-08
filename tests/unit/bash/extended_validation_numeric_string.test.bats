#!/usr/bin/env bats

# Extended Validation Numeric and String Tests
# Tests for numeric range and string pattern validation
# Author: Andres Gomez (AngocA)
# Version: 2025-11-26

setup() {
 # Load test helper functions
 load "${BATS_TEST_DIRNAME}/../../test_helper.bash"

 # Ensure SCRIPT_BASE_DIRECTORY is set
 if [[ -z "${SCRIPT_BASE_DIRECTORY:-}" ]]; then
   export SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
 fi

 # Ensure TEST_BASE_DIR is set (used by some tests)
 if [[ -z "${TEST_BASE_DIR:-}" ]]; then
   export TEST_BASE_DIR="${SCRIPT_BASE_DIRECTORY}"
 fi

 # Load test properties (not production properties)
 if [[ -f "${SCRIPT_BASE_DIRECTORY}/etc/properties_test.sh" ]]; then
  source "${SCRIPT_BASE_DIRECTORY}/etc/properties_test.sh"
 else
  # Fallback to production properties if test properties not found
  source "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh"
 fi
 source "${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh"
 source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/validationFunctions.sh"

 # Create temporary test files
 TEST_DIR=$(mktemp -d)
}

teardown() {
 # Clean up temporary files
 rm -rf "${TEST_DIR}"
}

# Test numeric range validation
@test "numeric range validation should work with valid values" {
 run __validate_numeric_range "50" "0" "100" "Test value"
 [[ "${status}" -eq 0 ]]
}

@test "numeric range validation should fail with value below minimum" {
 run __validate_numeric_range "-10" "0" "100" "Test value"
 [[ "${status}" -eq 1 ]]
}

@test "numeric range validation should fail with value above maximum" {
 run __validate_numeric_range "150" "0" "100" "Test value"
 [[ "${status}" -eq 1 ]]
}

@test "numeric range validation should fail with non-numeric value" {
 run __validate_numeric_range "abc" "0" "100" "Test value"
 [[ "${status}" -eq 1 ]]
}

# Test string pattern validation
@test "string pattern validation should work with valid patterns" {
 run __validate_string_pattern "test@example.com" "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$" "Email"
 [[ "${status}" -eq 0 ]]
}

@test "string pattern validation should fail with invalid patterns" {
 run __validate_string_pattern "invalid-email" "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$" "Email"
 [[ "${status}" -eq 1 ]]
}


