#!/usr/bin/env bats

# Overpass Functions Edge Cases and Integration Tests
# Tests for edge cases and integration scenarios
# Author: Andres Gomez (AngocA)
# Version: 2025-12-08

load "${BATS_TEST_DIRNAME}/../../test_helper"

setup() {
 # Create temporary test directory
 TEST_DIR=$(mktemp -d)
 export TEST_DIR

 # Set up test environment variables
 export SCRIPT_BASE_DIRECTORY="${TEST_BASE_DIR}"
 export OVERPASS_RETRIES_PER_ENDPOINT=7
 export OVERPASS_BACKOFF_SECONDS=20

 # Set log level to DEBUG to capture all log output
 export LOG_LEVEL="DEBUG"
 export __log_level="DEBUG"

 # Load overpass functions
 source "${TEST_BASE_DIR}/bin/lib/overpassFunctions.sh"
}

teardown() {
 # Clean up test files
 rm -rf "${TEST_DIR}"
}

# =============================================================================
# Edge Cases and Boundary Tests
# =============================================================================

@test "Edge case: __log_overpass_attempt with zero boundary ID" {
 # Test with zero as boundary ID
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_overpass_attempt "0" "1" "3" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"0"* ]]
}

@test "Edge case: __log_overpass_attempt with large attempt numbers" {
 # Test with large numbers
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_overpass_attempt "123" "100" "200" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"100/200"* ]]
}

@test "Edge case: __log_overpass_failure with zero elapsed time" {
 # Test with zero elapsed time
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_overpass_failure "123" "1" "7" "0" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"0s"* ]]
}

@test "Edge case: __log_overpass_failure with very large elapsed time" {
 # Test with very large elapsed time
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_overpass_failure "123" "7" "7" "3600" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"3600s"* ]]
}

@test "Edge case: __log_geojson_conversion_failure with zero elapsed time" {
 # Test with zero elapsed time
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_geojson_conversion_failure "123" "1" "7" "0" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"0s"* ]]
}

# =============================================================================
# Integration Tests: Function Call Sequences
# =============================================================================

@test "Integration: Complete Overpass download sequence logging" {
 # Simulate a complete download sequence
 local BOUNDARY_ID="12345"
 
 # Start attempt
 local LOG1
 LOG1=$(__log_overpass_attempt "${BOUNDARY_ID}" "1" "3" 2>&1)
 [[ "${LOG1}" == *"${BOUNDARY_ID}"* ]]
 
 # Success
 local LOG2
 LOG2=$(__log_overpass_success "${BOUNDARY_ID}" "1" 2>&1)
 [[ "${LOG2}" == *"${BOUNDARY_ID}"* ]]
 [[ "${LOG2}" == *"Successfully"* ]]
}

@test "Integration: Complete Overpass failure sequence logging" {
 # Simulate a complete failure sequence
 local BOUNDARY_ID="99999"
 
 # Start attempt
 local LOG1
 LOG1=$(__log_overpass_attempt "${BOUNDARY_ID}" "1" "3" 2>&1)
 [[ "${LOG1}" == *"${BOUNDARY_ID}"* ]]
 
 # Failure after retries
 local LOG2
 LOG2=$(__log_overpass_failure "${BOUNDARY_ID}" "3" "3" "90" 2>&1)
 [[ "${LOG2}" == *"${BOUNDARY_ID}"* ]]
 [[ "${LOG2}" == *"Failed"* ]]
}

@test "Integration: Complete GeoJSON conversion sequence logging" {
 # Simulate a complete GeoJSON conversion sequence
 local BOUNDARY_ID="54321"
 
 # Start validation
 local LOG1
 LOG1=$(__log_json_validation_start "${BOUNDARY_ID}" 2>&1)
 [[ "${LOG1}" == *"${BOUNDARY_ID}"* ]]
 
 # Validation success
 local LOG2
 LOG2=$(__log_json_validation_success "${BOUNDARY_ID}" 2>&1)
 [[ "${LOG2}" == *"${BOUNDARY_ID}"* ]]
 
 # Conversion attempt
 local LOG3
 LOG3=$(__log_geojson_conversion_attempt "${BOUNDARY_ID}" "1" "3" 2>&1)
 [[ "${LOG3}" == *"${BOUNDARY_ID}"* ]]
 
 # Conversion success
 local LOG4
 LOG4=$(__log_geojson_conversion_success "${BOUNDARY_ID}" "1" 2>&1)
 [[ "${LOG4}" == *"${BOUNDARY_ID}"* ]]
 
 # Validation
 local LOG5
 LOG5=$(__log_geojson_validation "${BOUNDARY_ID}" 2>&1)
 [[ "${LOG5}" == *"${BOUNDARY_ID}"* ]]
 
 # Validation success
 local LOG6
 LOG6=$(__log_geojson_validation_success "${BOUNDARY_ID}" 2>&1)
 [[ "${LOG6}" == *"${BOUNDARY_ID}"* ]]
}

@test "Integration: GeoJSON conversion failure sequence logging" {
 # Simulate a GeoJSON conversion failure sequence
 local BOUNDARY_ID="11111"
 
 # Conversion attempt
 local LOG1
 LOG1=$(__log_geojson_conversion_attempt "${BOUNDARY_ID}" "1" "3" 2>&1)
 [[ "${LOG1}" == *"${BOUNDARY_ID}"* ]]
 
 # Conversion failure after retries
 local LOG2
 LOG2=$(__log_geojson_conversion_failure "${BOUNDARY_ID}" "3" "3" "120" 2>&1)
 [[ "${LOG2}" == *"${BOUNDARY_ID}"* ]]
 [[ "${LOG2}" == *"Failed"* ]]
}

