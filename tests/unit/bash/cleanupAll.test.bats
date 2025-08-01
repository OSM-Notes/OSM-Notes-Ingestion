#!/usr/bin/env bats

# Test file for cleanupAll.sh script
# Tests basic functionality of the cleanup script

# Global script path
SCRIPT_PATH="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)/bin/cleanupAll.sh"

# Test 1: Script should exist
@test "cleanupAll script should exist" {
 [[ -f "${SCRIPT_PATH}" ]]
}

# Test 2: Script should be executable
@test "cleanupAll script should be executable" {
 [[ -x "${SCRIPT_PATH}" ]]
}

# Test 3: Script should have correct shebang
@test "cleanupAll script should have correct shebang" {
 run head -n 1 "${SCRIPT_PATH}"
 [[ "${output}" == "#!/bin/bash" ]]
}

# Test 4: Script should have help function
@test "cleanupAll script should have help function" {
 run grep -c "show_help" "${SCRIPT_PATH}"
 [[ "${output}" -gt 0 ]]
}

# Test 5: Script should have main function
@test "cleanupAll script should have main function" {
 run grep -c "main()" "${SCRIPT_PATH}"
 [[ "${output}" -gt 0 ]]
}

# Test 6: Script should have cleanup functions
@test "cleanupAll script should have cleanup functions" {
 run grep -c "cleanup_" "${SCRIPT_PATH}"
 [[ "${output}" -gt 0 ]]
}

# Test 7: Script should handle validation functions
@test "cleanupAll script should load validation functions" {
 run grep -c "validationFunctions.sh" "${SCRIPT_PATH}"
 [[ "${output}" -gt 0 ]]
}

# Test 8: Script should have proper error handling
@test "cleanupAll script should have proper error handling" {
 run grep -c "trap" "${SCRIPT_PATH}"
 [[ "${output}" -gt 0 ]]
}

# Test 9: Script should have logging functions
@test "cleanupAll script should have logging functions" {
 run grep -c "__log" "${SCRIPT_PATH}"
 [[ "${output}" -gt 0 ]]
}

# Test 10: Script should have database validation
@test "cleanupAll script should have database validation" {
 run grep -c "check_database" "${SCRIPT_PATH}"
 [[ "${output}" -gt 0 ]]
} 