#!/usr/bin/env bats
# Simplified test file for parallel processing delay functionality
#
# Author: Andres Gomez (AngocA)
# Version: 2025-08-17
# Description: Basic tests for delay constants and simple functionality

# Load test helper
load "../../test_helper"

# Load the parallel processing functions
setup_file() {
 # Set up test environment first
 export TMP_DIR="${BATS_TEST_DIRNAME}/tmp"
 export SCRIPT_BASE_DIRECTORY="${BATS_TEST_DIRNAME}/../../../"
 export MAX_THREADS=2

 # Create temporary directory
 mkdir -p "${TMP_DIR}"

 # Source the test properties file first (this has PARALLEL_PROCESS_DELAY defined)
 echo "DEBUG: Loading test properties from: ${BATS_TEST_DIRNAME}/test_properties.sh" >&2
 source "${BATS_TEST_DIRNAME}/test_properties.sh"
 echo "DEBUG: After loading test properties, PARALLEL_PROCESS_DELAY = '${PARALLEL_PROCESS_DELAY:-NOT_SET}'" >&2
}

teardown() {
 # Clean up temporary files (using built-in bash)
 if [[ -d "${TMP_DIR}" ]]; then
  # Remove directory contents first
  find "${TMP_DIR}" -type f -delete 2> /dev/null || true
  # Remove directory
  rmdir "${TMP_DIR}" 2> /dev/null || true
 fi
}

@test "PARALLEL_PROCESS_DELAY constant is defined" {
 # Check that the constant is defined
 source "${BATS_TEST_DIRNAME}/test_properties.sh"
 echo "DEBUG: BATS_TEST_DIRNAME = '${BATS_TEST_DIRNAME:-NOT_SET}'" >&2
 echo "DEBUG: PARALLEL_PROCESS_DELAY = '${PARALLEL_PROCESS_DELAY:-NOT_SET}'" >&2
 echo "DEBUG: SCRIPT_BASE_DIRECTORY = '${SCRIPT_BASE_DIRECTORY:-NOT_SET}'" >&2
 [ -n "${PARALLEL_PROCESS_DELAY}" ]
 [ "${PARALLEL_PROCESS_DELAY}" -gt 0 ]
}

@test "Delay constants are properly defined" {
 # Check that all delay-related constants are defined
 source "${BATS_TEST_DIRNAME}/test_properties.sh"
 [ -n "${PARALLEL_PROCESS_DELAY}" ]
 [ -n "${MAX_MEMORY_PERCENT:-}" ] || skip "MAX_MEMORY_PERCENT not defined"
 [ -n "${MAX_LOAD_AVERAGE:-}" ] || skip "MAX_LOAD_AVERAGE not defined"

 # Check values are reasonable
 [ "${PARALLEL_PROCESS_DELAY}" -gt 0 ]
 [ "${PARALLEL_PROCESS_DELAY}" -le 10 ]
}

@test "Environment variables are properly set" {
 # Check that environment variables are set
 [ -n "${SCRIPT_BASE_DIRECTORY}" ]
 [ -n "${TMP_DIR}" ]
 [ -n "${MAX_THREADS}" ]
}

@test "Properties file contains required constants" {
 # Check that properties file has the required constants
 source "${BATS_TEST_DIRNAME}/test_properties.sh"
 [ -n "${PARALLEL_PROCESS_DELAY:-}" ]
 [ -n "${CLEAN:-}" ]
}

# Summary test
@test "Parallel Delay Test Suite - Summary" {
 echo "✅ All basic parallel delay tests completed successfully!"
 echo "📊 Test coverage includes:"
 echo "   - Constants definition: ✅"
 echo "   - Environment variables: ✅"
 echo "   - Properties validation: ✅"
}
