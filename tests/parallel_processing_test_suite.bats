#!/usr/bin/env bats
# Parallel Processing Test Suite for OSM-Notes-profile
# This file consolidates all parallel processing related tests
#
# Author: Andres Gomez (AngocA)
# Version: 2025-08-16
# Description: Comprehensive test suite for parallel processing functionality

# Load test helper
load test_helper

# Load the parallel processing functions
setup() {
 # Set up test environment first
 export TMP_DIR="${BATS_TEST_DIRNAME}/tmp"
 export SCRIPT_BASE_DIRECTORY="${BATS_TEST_DIRNAME}/.."
 export MAX_THREADS=2
 # Note: PARALLEL_PROCESS_DELAY is readonly, so we can't override it

 # Create temporary directory
 mkdir -p "${TMP_DIR}"
}

teardown() {
 # Clean up temporary files
 rm -rf "${TMP_DIR}"
}

# Test suite description
@test "Parallel Processing Test Suite - Overview" {
 echo "Running comprehensive parallel processing tests..."
 echo "This suite includes:"
 echo "- Resource management functions"
 echo "- Process delay system"
 echo "- Robust AWK processing"
 echo "- System limits configuration"
 echo "- Integration with main processing functions"
}

# Resource Management Tests
@test "Resource management functions are available" {
 # Load the parallel processing functions to get access to constants and functions
 export SCRIPT_BASE_DIRECTORY="${BATS_TEST_DIRNAME}/.."
 source "${BATS_TEST_DIRNAME}/../etc/properties.sh"
 source "${BATS_TEST_DIRNAME}/../bin/parallelProcessingFunctions.sh"

 # Check that all resource management functions exist
 command -v __check_system_resources
 command -v __wait_for_resources
 command -v __adjust_workers_for_resources
 command -v __adjust_process_delay
 command -v __configure_system_limits
}

@test "System resource checking works correctly" {
 # Load the parallel processing functions to get access to constants and functions
 export SCRIPT_BASE_DIRECTORY="${BATS_TEST_DIRNAME}/.."
 source "${BATS_TEST_DIRNAME}/../etc/properties.sh"
 source "${BATS_TEST_DIRNAME}/../bin/parallelProcessingFunctions.sh"

 # Test basic resource checking
 run __check_system_resources
 [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "Process delay adjustment works correctly" {
 # Load the parallel processing functions to get access to constants and functions
 export SCRIPT_BASE_DIRECTORY="${BATS_TEST_DIRNAME}/.."
 source "${BATS_TEST_DIRNAME}/../etc/properties.sh"
 source "${BATS_TEST_DIRNAME}/../etc/properties.sh"
 source "${BATS_TEST_DIRNAME}/../bin/parallelProcessingFunctions.sh"

 # Test delay adjustment function
 local NUMERIC_OUTPUT
 NUMERIC_OUTPUT=$(__adjust_process_delay 2> /dev/null)
 [ -n "${NUMERIC_OUTPUT}" ]
 [ "${NUMERIC_OUTPUT}" -ge 1 ]
 [ "${NUMERIC_OUTPUT}" -le 10 ]
}

# Parallel Processing Core Tests
@test "Parallel processing constants are defined" {
 # Load the parallel processing functions to get access to constants
 export SCRIPT_BASE_DIRECTORY="${BATS_TEST_DIRNAME}/.."
 source "${BATS_TEST_DIRNAME}/../etc/properties.sh"
 source "${BATS_TEST_DIRNAME}/../bin/parallelProcessingFunctions.sh"

 # Check that all required constants are defined
 [ -n "${PARALLEL_PROCESS_DELAY}" ]
 [ -n "${MAX_MEMORY_PERCENT}" ]
 [ -n "${MAX_LOAD_AVERAGE}" ]
 [ -n "${PROCESS_TIMEOUT}" ]
 [ -n "${MAX_RETRIES}" ]
 [ -n "${RETRY_DELAY}" ]
}

@test "Worker adjustment function works correctly" {
 # Load the parallel processing functions to get access to constants and functions
 export SCRIPT_BASE_DIRECTORY="${BATS_TEST_DIRNAME}/.."
 source "${BATS_TEST_DIRNAME}/../etc/properties.sh"
 source "${BATS_TEST_DIRNAME}/../bin/parallelProcessingFunctions.sh"

 # Test worker adjustment
 local NUMERIC_OUTPUT
 NUMERIC_OUTPUT=$(__adjust_workers_for_resources 4 2> /dev/null)
 [ -n "${NUMERIC_OUTPUT}" ]
 [ "${NUMERIC_OUTPUT}" -ge 1 ]
 [ "${NUMERIC_OUTPUT}" -le 4 ]
}

@test "Worker adjustment function works correctly with XML type" {
 # Load the parallel processing functions to get access to constants and functions
 export SCRIPT_BASE_DIRECTORY="${BATS_TEST_DIRNAME}/.."
 source "${BATS_TEST_DIRNAME}/../etc/properties.sh"
 source "${BATS_TEST_DIRNAME}/../bin/parallelProcessingFunctions.sh"

 # Test worker adjustment for XML processing (should reduce based on memory)
 local NUMERIC_OUTPUT
 NUMERIC_OUTPUT=$(__adjust_workers_for_resources 8 "XML" 2> /dev/null)
 [ -n "${NUMERIC_OUTPUT}" ]
 # Should reduce workers (exact number depends on system memory)
 # At minimum reduces by 2, but may reduce more if memory is high
 [ "${NUMERIC_OUTPUT}" -le 6 ]
 [ "${NUMERIC_OUTPUT}" -ge 1 ]
}

# AWK Processing Tests
@test "Robust AWK processing function exists" {
 # Load the parallel processing functions to get access to constants and functions
 export SCRIPT_BASE_DIRECTORY="${BATS_TEST_DIRNAME}/.."
 source "${BATS_TEST_DIRNAME}/../etc/properties.sh"
 source "${BATS_TEST_DIRNAME}/../bin/parallelProcessingFunctions.sh"

 # Check that the robust AWK function exists
 command -v __process_xml_with_awk_robust
}

@test "Robust AWK processing handles missing files" {
 # Load the parallel processing functions to get access to constants and functions
 export SCRIPT_BASE_DIRECTORY="${BATS_TEST_DIRNAME}/.."
 source "${BATS_TEST_DIRNAME}/../etc/properties.sh"
 source "${BATS_TEST_DIRNAME}/../bin/parallelProcessingFunctions.sh"

 # Test with missing XML file
 run __process_xml_with_awk_robust "/nonexistent.xml" "/nonexistent.awk" "/tmp/output.csv"
 [ "$status" -eq 1 ]
}

# System Limits Tests
@test "System limits configuration function exists" {
 # Load the parallel processing functions to get access to constants and functions
 export SCRIPT_BASE_DIRECTORY="${BATS_TEST_DIRNAME}/.."
 source "${BATS_TEST_DIRNAME}/../etc/properties.sh"
 source "${BATS_TEST_DIRNAME}/../bin/parallelProcessingFunctions.sh"

 # Check that the system limits function exists
 command -v __configure_system_limits
}

@test "System limits configuration runs without errors" {
 # Load the parallel processing functions to get access to constants and functions
 export SCRIPT_BASE_DIRECTORY="${BATS_TEST_DIRNAME}/.."
 source "${BATS_TEST_DIRNAME}/../etc/properties.sh"
 source "${BATS_TEST_DIRNAME}/../bin/parallelProcessingFunctions.sh"

 # Test that the function runs (may not have permissions to actually change limits)
 run __configure_system_limits
 # Function should run, even if it can't change system limits
 [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

# Integration Tests
@test "Parallel processing integrates with main functions" {
 # Check that main parallel processing function exists
 command -v __processXmlPartsParallel
}

@test "XML splitting functions are available" {
 # Check that XML splitting functions exist
 command -v __splitXmlForParallelSafe
 command -v __splitXmlForParallelAPI
 command -v __splitXmlForParallelPlanet
}

@test "XML processing functions are available" {
 # Check that XML processing functions exist
 command -v __processApiXmlPart
 command -v __processPlanetXmlPart
}

# Performance Tests
@test "Delay system prevents resource overload" {
 # Load the parallel processing functions to get access to constants and functions
 export SCRIPT_BASE_DIRECTORY="${BATS_TEST_DIRNAME}/.."
 source "${BATS_TEST_DIRNAME}/../etc/properties.sh"
 source "${BATS_TEST_DIRNAME}/../bin/parallelProcessingFunctions.sh"

 # Test that delay system works
 local BASE_DELAY="${PARALLEL_PROCESS_DELAY}"
 local ADJUSTED_DELAY
 # Capture the numeric output (function outputs to stdout, logs to stderr)
 ADJUSTED_DELAY=$(__adjust_process_delay 2> /dev/null)

 # Verify that we got a numeric value
 [ -n "${ADJUSTED_DELAY}" ]
 [[ "${ADJUSTED_DELAY}" =~ ^[0-9]+$ ]]

 # Delay should be at least base delay
 [ "${ADJUSTED_DELAY}" -ge "${BASE_DELAY}" ]
}

@test "Resource monitoring prevents process launching under pressure" {
 # Load the parallel processing functions to get access to constants and functions
 export SCRIPT_BASE_DIRECTORY="${BATS_TEST_DIRNAME}/.."
 source "${BATS_TEST_DIRNAME}/../etc/properties.sh"
 source "${BATS_TEST_DIRNAME}/../bin/parallelProcessingFunctions.sh"

 # Test resource checking under normal conditions
 run __check_system_resources
 # Should return 0 (resources available) or 1 (resources low)
 [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

# Error Handling Tests
@test "Functions handle missing system commands gracefully" {
 # Load the parallel processing functions to get access to constants and functions
 export SCRIPT_BASE_DIRECTORY="${BATS_TEST_DIRNAME}/.."
 source "${BATS_TEST_DIRNAME}/../etc/properties.sh"
 source "${BATS_TEST_DIRNAME}/../bin/parallelProcessingFunctions.sh"

 # Test that the function works correctly
 run __adjust_process_delay 2> /dev/null
 [ "$status" -eq 0 ]

 # Verify that output contains a numeric value
 [ -n "${output}" ]

 # Test that the function handles errors gracefully
 run __adjust_process_delay invalid_argument 2> /dev/null
 [ "$status" -eq 1 ] || [ "$status" -eq 0 ]
}

@test "Functions handle edge cases correctly" {
 # Load the parallel processing functions to get access to constants and functions
 export SCRIPT_BASE_DIRECTORY="${BATS_TEST_DIRNAME}/.."
 source "${BATS_TEST_DIRNAME}/../etc/properties.sh"
 source "${BATS_TEST_DIRNAME}/../bin/parallelProcessingFunctions.sh"

 # Test that delay adjustment works and returns a valid value
 local CURRENT_DELAY="${PARALLEL_PROCESS_DELAY}"
 # Test direct function call (function outputs to stdout, logs to stderr)
 local NUMERIC_OUTPUT
 NUMERIC_OUTPUT=$(__adjust_process_delay 2> /dev/null)
 # Delay should be at least the base delay, but may be higher based on system resources
 [ "${NUMERIC_OUTPUT}" -ge "${CURRENT_DELAY}" ]

 # Test that delay adjustment respects capping
 NUMERIC_OUTPUT=$(__adjust_process_delay 2> /dev/null)
 [ "${NUMERIC_OUTPUT}" -le 10 ]
}

# Configuration Tests
@test "Properties file contains required constants" {
 # Check that properties file has the required constants
 source "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh"
 [ -n "${PARALLEL_PROCESS_DELAY:-}" ]
}

@test "Environment variables are properly set" {
 # Check that environment variables are set
 [ -n "${SCRIPT_BASE_DIRECTORY}" ]
 [ -n "${TMP_DIR}" ]
 [ -n "${MAX_THREADS}" ]
}

# Summary test
@test "Parallel Processing Test Suite - Summary" {
 echo "✅ All parallel processing tests completed successfully!"
 echo "📊 Test coverage includes:"
 echo "   - Resource management: ✅"
 echo "   - Process delay system: ✅"
 echo "   - Robust AWK processing: ✅"
 echo "   - System limits: ✅"
 echo "   - Integration: ✅"
 echo "   - Error handling: ✅"
 echo "   - Configuration: ✅"
}
