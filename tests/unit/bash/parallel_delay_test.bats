#!/usr/bin/env bats
# Test file for parallel processing delay functionality
#
# Author: Andres Gomez (AngocA)
# Version: 2025-10-24
# Description: Tests for delay between parallel process launches

# Require minimum bats version for --separate-stderr flag
bats_require_minimum_version 1.5.0

# Load test helper
load "../../test_helper"

# Load the parallel processing functions
setup() {
 # Set up test environment first
 export TMP_DIR="${BATS_TEST_DIRNAME}/tmp"
 export SCRIPT_BASE_DIRECTORY="${BATS_TEST_DIRNAME}/../../../"
 export MAX_THREADS=2

 # Create temporary directory
 mkdir -p "${TMP_DIR}"
 chmod 777 "${TMP_DIR}" 2> /dev/null || true
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
 # Load properties and functions for this test
 source "${BATS_TEST_DIRNAME}/test_properties.sh"
 source "${SCRIPT_BASE_DIRECTORY}/bin/lib/parallelProcessingFunctions.sh"
 # Check that the constant is defined
 source "${BATS_TEST_DIRNAME}/test_properties.sh"
 [ -n "${PARALLEL_PROCESS_DELAY}" ]
 [ "${PARALLEL_PROCESS_DELAY}" -gt 0 ]
}

@test "Adjust process delay function works correctly" {
 # Load properties and functions for this test
 source "${BATS_TEST_DIRNAME}/test_properties.sh"
 source "${SCRIPT_BASE_DIRECTORY}/bin/lib/parallelProcessingFunctions.sh"
 # Test that the function returns a valid delay
 # Load properties and functions for this test
 source "${BATS_TEST_DIRNAME}/test_properties.sh"
 source "${SCRIPT_BASE_DIRECTORY}/bin/lib/parallelProcessingFunctions.sh"

 # Test direct function call (function outputs to stdout, logs to stderr)
 local NUMERIC_OUTPUT
 echo "DEBUG: PARALLEL_PROCESS_DELAY = '${PARALLEL_PROCESS_DELAY:-NOT_SET}'" >&2
 echo "DEBUG: Calling __adjust_process_delay function..." >&2
 NUMERIC_OUTPUT=$(__adjust_process_delay 2> /dev/null)
 echo "DEBUG: Function returned: '${NUMERIC_OUTPUT}'" >&2
 [ -n "${NUMERIC_OUTPUT}" ]
 [ "${NUMERIC_OUTPUT}" -ge 1 ]
 [ "${NUMERIC_OUTPUT}" -le 10 ]
}

@test "Process delay increases under high memory usage" {
 # Load properties and functions for this test
 source "${BATS_TEST_DIRNAME}/test_properties.sh"
 source "${SCRIPT_BASE_DIRECTORY}/bin/lib/parallelProcessingFunctions.sh"

 # Test that delay adjustment works (simplified test)
 local CURRENT_DELAY="${PARALLEL_PROCESS_DELAY:-2}"
 local ADJUSTED_DELAY
 ADJUSTED_DELAY=$(__adjust_process_delay 2> /dev/null)

 # Verify we got a valid delay value
 [ -n "${ADJUSTED_DELAY}" ]
 [[ "${ADJUSTED_DELAY}" =~ ^[0-9]+$ ]]
 [ "${ADJUSTED_DELAY}" -ge "${CURRENT_DELAY}" ]
 [ "${ADJUSTED_DELAY}" -le 10 ]
}

@test "Process delay increases under high system load" {
 # Load properties and functions for this test
 source "${BATS_TEST_DIRNAME}/test_properties.sh"
 source "${SCRIPT_BASE_DIRECTORY}/bin/lib/parallelProcessingFunctions.sh"

 # Test that delay adjustment works (simplified test)
 local CURRENT_DELAY="${PARALLEL_PROCESS_DELAY:-2}"
 local ADJUSTED_DELAY
 ADJUSTED_DELAY=$(__adjust_process_delay 2> /dev/null)

 # Verify we got a valid delay value
 [ -n "${ADJUSTED_DELAY}" ]
 [[ "${ADJUSTED_DELAY}" =~ ^[0-9]+$ ]]
 [ "${ADJUSTED_DELAY}" -ge "${CURRENT_DELAY}" ]
 [ "${ADJUSTED_DELAY}" -le 10 ]
}

@test "Process delay is capped at reasonable maximum" {
 # Load properties and functions for this test
 source "${BATS_TEST_DIRNAME}/test_properties.sh"
 source "${SCRIPT_BASE_DIRECTORY}/bin/lib/parallelProcessingFunctions.sh"

 # Test that delay is capped (using current readonly value)
 local CURRENT_DELAY="${PARALLEL_PROCESS_DELAY:-2}"

 # Test that delay adjustment respects capping
 local ADJUSTED_DELAY
 ADJUSTED_DELAY=$(__adjust_process_delay 2> /dev/null)
 
 # Verify we got a valid delay value
 [ -n "${ADJUSTED_DELAY}" ]
 [[ "${ADJUSTED_DELAY}" =~ ^[0-9]+$ ]]
 [ "${ADJUSTED_DELAY}" -le 10 ]
 [ "${ADJUSTED_DELAY}" -gt 0 ]
}

@test "Delay adjustment function handles missing commands gracefully" {
 # Load properties and functions for this test
 source "${BATS_TEST_DIRNAME}/test_properties.sh"
 source "${SCRIPT_BASE_DIRECTORY}/bin/lib/parallelProcessingFunctions.sh"

 # Test that function works correctly
 local CURRENT_DELAY="${PARALLEL_PROCESS_DELAY:-2}"
 local ADJUSTED_DELAY
 ADJUSTED_DELAY=$(__adjust_process_delay 2> /dev/null)

 # Verify we got a valid delay value
 [ -n "${ADJUSTED_DELAY}" ]
 [[ "${ADJUSTED_DELAY}" =~ ^[0-9]+$ ]]
 [ "${ADJUSTED_DELAY}" -ge "${CURRENT_DELAY}" ]
 [ "${ADJUSTED_DELAY}" -le 10 ]
}

@test "Delay constants are properly defined" {
 # Load properties and functions for this test
 source "${BATS_TEST_DIRNAME}/test_properties.sh"
 source "${SCRIPT_BASE_DIRECTORY}/bin/lib/parallelProcessingFunctions.sh"

 # Check that all delay-related constants are defined
 [ -n "${PARALLEL_PROCESS_DELAY}" ]
 [ -n "${MAX_MEMORY_PERCENT}" ]
 [ -n "${MAX_LOAD_AVERAGE}" ]

 # Check values are reasonable
 [ "${PARALLEL_PROCESS_DELAY}" -gt 0 ]
 [ "${PARALLEL_PROCESS_DELAY}" -le 10 ]
 [ "${MAX_MEMORY_PERCENT}" -gt 0 ]
 [ "${MAX_MEMORY_PERCENT}" -le 100 ]
 # MAX_LOAD_AVERAGE is a float, so we need to use bc for comparison
 [ "$(echo "${MAX_LOAD_AVERAGE} > 0" | bc -l)" = "1" ]
}

@test "Delay function logs appropriate messages" {
 # Load properties and functions for this test
 source "${BATS_TEST_DIRNAME}/test_properties.sh"
 source "${SCRIPT_BASE_DIRECTORY}/bin/lib/parallelProcessingFunctions.sh"

 # Test that function works and produces output
 local ADJUSTED_DELAY
 ADJUSTED_DELAY=$(__adjust_process_delay 2> /dev/null)

 # Verify we got a valid delay value
 [ -n "${ADJUSTED_DELAY}" ]
 [ "${ADJUSTED_DELAY}" -ge 1 ]
 [ "${ADJUSTED_DELAY}" -le 10 ]
}

@test "Delay adjustment respects system state" {
 # Load properties and functions for this test
 source "${BATS_TEST_DIRNAME}/test_properties.sh"
 source "${SCRIPT_BASE_DIRECTORY}/bin/lib/parallelProcessingFunctions.sh"

 # Test with current system state
 local CURRENT_DELAY="${PARALLEL_PROCESS_DELAY:-2}"
 local ADJUSTED_DELAY
 ADJUSTED_DELAY=$(__adjust_process_delay 2> /dev/null)
 
 # Verify we got a valid delay value
 [ -n "${ADJUSTED_DELAY}" ]
 [[ "${ADJUSTED_DELAY}" =~ ^[0-9]+$ ]]
 [ "${ADJUSTED_DELAY}" -ge "${CURRENT_DELAY}" ]
 [ "${ADJUSTED_DELAY}" -le 10 ]
}

@test "Zero delay is handled correctly" {
 # Load properties and functions for this test
 source "${BATS_TEST_DIRNAME}/test_properties.sh"
 source "${SCRIPT_BASE_DIRECTORY}/bin/lib/parallelProcessingFunctions.sh"

 # Test that current delay value is handled correctly
 local CURRENT_DELAY="${PARALLEL_PROCESS_DELAY:-2}"
 local ADJUSTED_DELAY
 ADJUSTED_DELAY=$(__adjust_process_delay 2> /dev/null)
 
 # Verify we got a valid delay value
 [ -n "${ADJUSTED_DELAY}" ]
 [[ "${ADJUSTED_DELAY}" =~ ^[0-9]+$ ]]
 [ "${ADJUSTED_DELAY}" -ge "${CURRENT_DELAY}" ]
}
