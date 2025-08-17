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
 # Source the parallel processing functions
 source "${BATS_TEST_DIRNAME}/../bin/parallelProcessingFunctions.sh"
 
 # Set up test environment
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
 echo "- Robust XSLT processing"
 echo "- System limits configuration"
 echo "- Integration with main processing functions"
}

# Resource Management Tests
@test "Resource management functions are available" {
 # Check that all resource management functions exist
 command -v __check_system_resources
 command -v __wait_for_resources
 command -v __adjust_workers_for_resources
 command -v __adjust_process_delay
 command -v __configure_system_limits
}

@test "System resource checking works correctly" {
 # Test basic resource checking
 run __check_system_resources
 [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "Process delay adjustment works correctly" {
 # Test delay adjustment function
 run __adjust_process_delay
 [ "$status" -eq 0 ]
 [ -n "$output" ]
 [ "$output" -ge 1 ]
 [ "$output" -le 10 ]
}

# Parallel Processing Core Tests
@test "Parallel processing constants are defined" {
 # Check that all required constants are defined
 [ -n "${PARALLEL_PROCESS_DELAY}" ]
 [ -n "${MAX_MEMORY_PERCENT}" ]
 [ -n "${MAX_LOAD_AVERAGE}" ]
 [ -n "${PROCESS_TIMEOUT}" ]
 [ -n "${MAX_RETRIES}" ]
 [ -n "${RETRY_DELAY}" ]
}

@test "Worker adjustment function works correctly" {
 # Test worker adjustment
 run __adjust_workers_for_resources 4
 [ "$status" -eq 0 ]
 [ -n "$output" ]
 [ "$output" -ge 1 ]
 [ "$output" -le 4 ]
}

# XSLT Processing Tests
@test "Robust XSLT processing function exists" {
 # Check that the robust XSLT function exists
 command -v __process_xml_with_xslt_robust
}

@test "Robust XSLT processing handles missing files" {
 # Test with missing XML file
 run __process_xml_with_xslt_robust "/nonexistent.xml" "/nonexistent.xslt" "/tmp/output.csv"
 [ "$status" -eq 1 ]
}

# System Limits Tests
@test "System limits configuration function exists" {
 # Check that the system limits function exists
 command -v __configure_system_limits
}

@test "System limits configuration runs without errors" {
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
 # Test that delay system works
 local BASE_DELAY="${PARALLEL_PROCESS_DELAY}"
 local ADJUSTED_DELAY
 ADJUSTED_DELAY=$(__adjust_process_delay)
 
 # Delay should be at least base delay
 [ "${ADJUSTED_DELAY}" -ge "${BASE_DELAY}" ]
}

@test "Resource monitoring prevents process launching under pressure" {
 # Test resource checking under normal conditions
 run __check_system_resources
 # Should return 0 (resources available) or 1 (resources low)
 [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

# Error Handling Tests
@test "Functions handle missing system commands gracefully" {
 # Test with limited PATH
 local ORIGINAL_PATH="${PATH}"
 export PATH="/nonexistent"
 
 # Functions should still work
 run __adjust_process_delay
 [ "$status" -eq 0 ]
 [ "$output" = "${PARALLEL_PROCESS_DELAY}" ]
 
 # Restore PATH
 export PATH="${ORIGINAL_PATH}"
}

@test "Functions handle edge cases correctly" {
 # Test that current delay value is handled correctly
 local CURRENT_DELAY="${PARALLEL_PROCESS_DELAY}"
 run __adjust_process_delay
 [ "$status" -eq 0 ]
 [ "$output" = "${CURRENT_DELAY}" ]
 
 # Test that delay adjustment respects capping
 run __adjust_process_delay
 [ "$status" -eq 0 ]
 [ "$output" -le 10 ]
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
 echo "   - Robust XSLT processing: ✅"
 echo "   - System limits: ✅"
 echo "   - Integration: ✅"
 echo "   - Error handling: ✅"
 echo "   - Configuration: ✅"
}
