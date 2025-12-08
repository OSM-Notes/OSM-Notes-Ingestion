#!/usr/bin/env bats

# Overpass Functions Tests
# Comprehensive tests for Overpass API logging functions
# Author: Andres Gomez (AngocA)
# Version: 2025-01-15

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
# Function Existence Tests
# =============================================================================

@test "All overpass functions should be available" {
 # Test that all overpass functions exist
 run declare -f __log_overpass_attempt
 [[ "${status}" -eq 0 ]]

 run declare -f __log_overpass_success
 [[ "${status}" -eq 0 ]]

 run declare -f __log_overpass_failure
 [[ "${status}" -eq 0 ]]

 run declare -f __log_json_validation_start
 [[ "${status}" -eq 0 ]]

 run declare -f __log_json_validation_success
 [[ "${status}" -eq 0 ]]

 run declare -f __log_geojson_conversion_attempt
 [[ "${status}" -eq 0 ]]

 run declare -f __log_geojson_conversion_success
 [[ "${status}" -eq 0 ]]

 run declare -f __log_geojson_validation
 [[ "${status}" -eq 0 ]]

 run declare -f __log_geojson_validation_success
 [[ "${status}" -eq 0 ]]

 run declare -f __log_geojson_conversion_failure
 [[ "${status}" -eq 0 ]]
}

# =============================================================================
# Tests for __log_overpass_attempt
# =============================================================================

@test "__log_overpass_attempt should log attempt with boundary ID" {
 # Capture log output
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_overpass_attempt "12345" "1" "3" 2>&1)
 
 # Should contain boundary ID
 [[ "${LOG_OUTPUT}" == *"12345"* ]]
 # Should contain attempt number
 [[ "${LOG_OUTPUT}" == *"1"* ]]
 # Should contain max attempts
 [[ "${LOG_OUTPUT}" == *"3"* ]]
 # Should contain "attempt" text
 [[ "${LOG_OUTPUT}" == *"attempt"* ]]
}

@test "__log_overpass_attempt should handle different boundary IDs" {
 # Test with different boundary IDs
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_overpass_attempt "99999" "2" "5" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"99999"* ]]
 [[ "${LOG_OUTPUT}" == *"2/5"* ]]
}

@test "__log_overpass_attempt should handle first attempt" {
 # Test first attempt
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_overpass_attempt "123" "1" "7" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"1/7"* ]]
}

@test "__log_overpass_attempt should handle last attempt" {
 # Test last attempt
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_overpass_attempt "123" "7" "7" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"7/7"* ]]
}

# =============================================================================
# Tests for __log_overpass_success
# =============================================================================

@test "__log_overpass_success should log success with boundary ID" {
 # Capture log output
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_overpass_success "12345" "1" 2>&1)
 
 # Should contain boundary ID
 [[ "${LOG_OUTPUT}" == *"12345"* ]]
 # Should contain "Successfully" text
 [[ "${LOG_OUTPUT}" == *"Successfully"* ]]
 # Should contain attempt number
 [[ "${LOG_OUTPUT}" == *"1"* ]]
}

@test "__log_overpass_success should handle different attempt numbers" {
 # Test with different attempt numbers
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_overpass_success "99999" "3" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"99999"* ]]
 [[ "${LOG_OUTPUT}" == *"3"* ]]
}

@test "__log_overpass_success should contain Overpass API text" {
 # Test that it mentions Overpass API
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_overpass_success "123" "1" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"Overpass API"* ]]
}

# =============================================================================
# Tests for __log_overpass_failure
# =============================================================================

@test "__log_overpass_failure should log failure with all parameters" {
 # Capture log output
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_overpass_failure "12345" "3" "7" "45" 2>&1)
 
 # Should contain boundary ID
 [[ "${LOG_OUTPUT}" == *"12345"* ]]
 # Should contain attempt numbers
 [[ "${LOG_OUTPUT}" == *"3/7"* ]]
 # Should contain elapsed time
 [[ "${LOG_OUTPUT}" == *"45"* ]]
 # Should contain "Failed" text
 [[ "${LOG_OUTPUT}" == *"Failed"* ]]
}

@test "__log_overpass_failure should handle elapsed time in seconds" {
 # Test elapsed time formatting
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_overpass_failure "123" "5" "7" "120" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"120s"* ]]
}

@test "__log_overpass_failure should log after all retries" {
 # Test final failure after all retries
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_overpass_failure "999" "7" "7" "300" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"7/7"* ]]
 [[ "${LOG_OUTPUT}" == *"after retries"* ]]
}

# =============================================================================
# Tests for __log_json_validation_start
# =============================================================================

@test "__log_json_validation_start should log validation start" {
 # Capture log output
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_json_validation_start "12345" 2>&1)
 
 # Should contain boundary ID
 [[ "${LOG_OUTPUT}" == *"12345"* ]]
 # Should contain "Validating" text
 [[ "${LOG_OUTPUT}" == *"Validating"* ]]
 # Should contain "JSON" text
 [[ "${LOG_OUTPUT}" == *"JSON"* ]]
}

@test "__log_json_validation_start should handle different boundary IDs" {
 # Test with different boundary IDs
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_json_validation_start "99999" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"99999"* ]]
 [[ "${LOG_OUTPUT}" == *"JSON structure"* ]]
}

# =============================================================================
# Tests for __log_json_validation_success
# =============================================================================

@test "__log_json_validation_success should log validation success" {
 # Capture log output
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_json_validation_success "12345" 2>&1)
 
 # Should contain boundary ID
 [[ "${LOG_OUTPUT}" == *"12345"* ]]
 # Should contain "validation passed" text
 [[ "${LOG_OUTPUT}" == *"validation passed"* ]]
 # Should contain "JSON" text
 [[ "${LOG_OUTPUT}" == *"JSON"* ]]
}

@test "__log_json_validation_success should handle different boundary IDs" {
 # Test with different boundary IDs
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_json_validation_success "99999" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"99999"* ]]
 [[ "${LOG_OUTPUT}" == *"passed"* ]]
}

# =============================================================================
# Tests for __log_geojson_conversion_attempt
# =============================================================================

@test "__log_geojson_conversion_attempt should log conversion attempt" {
 # Capture log output
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_geojson_conversion_attempt "12345" "1" "3" 2>&1)
 
 # Should contain boundary ID
 [[ "${LOG_OUTPUT}" == *"12345"* ]]
 # Should contain attempt numbers
 [[ "${LOG_OUTPUT}" == *"1/3"* ]]
 # Should contain "GeoJSON" text
 [[ "${LOG_OUTPUT}" == *"GeoJSON"* ]]
 # Should contain "conversion" text
 [[ "${LOG_OUTPUT}" == *"conversion"* ]]
}

@test "__log_geojson_conversion_attempt should handle different attempt numbers" {
 # Test with different attempt numbers
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_geojson_conversion_attempt "123" "2" "5" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"2/5"* ]]
}

# =============================================================================
# Tests for __log_geojson_conversion_success
# =============================================================================

@test "__log_geojson_conversion_success should log conversion success" {
 # Capture log output
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_geojson_conversion_success "12345" "1" 2>&1)
 
 # Should contain boundary ID
 [[ "${LOG_OUTPUT}" == *"12345"* ]]
 # Should contain attempt number
 [[ "${LOG_OUTPUT}" == *"1"* ]]
 # Should contain "GeoJSON conversion completed" text
 [[ "${LOG_OUTPUT}" == *"GeoJSON conversion completed"* ]]
}

@test "__log_geojson_conversion_success should handle different attempt numbers" {
 # Test with different attempt numbers
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_geojson_conversion_success "999" "3" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"999"* ]]
 [[ "${LOG_OUTPUT}" == *"3"* ]]
}

# =============================================================================
# Tests for __log_geojson_validation
# =============================================================================

@test "__log_geojson_validation should log validation start" {
 # Capture log output
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_geojson_validation "12345" 2>&1)
 
 # Should contain boundary ID
 [[ "${LOG_OUTPUT}" == *"12345"* ]]
 # Should contain "Validating" text
 [[ "${LOG_OUTPUT}" == *"Validating"* ]]
 # Should contain "GeoJSON" text
 [[ "${LOG_OUTPUT}" == *"GeoJSON"* ]]
}

@test "__log_geojson_validation should handle different boundary IDs" {
 # Test with different boundary IDs
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_geojson_validation "99999" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"99999"* ]]
 [[ "${LOG_OUTPUT}" == *"GeoJSON structure"* ]]
}

# =============================================================================
# Tests for __log_geojson_validation_success
# =============================================================================

@test "__log_geojson_validation_success should log validation success" {
 # Capture log output
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_geojson_validation_success "12345" 2>&1)
 
 # Should contain boundary ID
 [[ "${LOG_OUTPUT}" == *"12345"* ]]
 # Should contain "validation passed" text
 [[ "${LOG_OUTPUT}" == *"validation passed"* ]]
 # Should contain "GeoJSON" text
 [[ "${LOG_OUTPUT}" == *"GeoJSON"* ]]
}

@test "__log_geojson_validation_success should handle different boundary IDs" {
 # Test with different boundary IDs
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_geojson_validation_success "99999" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"99999"* ]]
 [[ "${LOG_OUTPUT}" == *"passed"* ]]
}

# =============================================================================
# Tests for __log_geojson_conversion_failure
# =============================================================================

@test "__log_geojson_conversion_failure should log failure with all parameters" {
 # Capture log output
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_geojson_conversion_failure "12345" "3" "7" "60" 2>&1)
 
 # Should contain boundary ID
 [[ "${LOG_OUTPUT}" == *"12345"* ]]
 # Should contain attempt numbers
 [[ "${LOG_OUTPUT}" == *"3/7"* ]]
 # Should contain elapsed time
 [[ "${LOG_OUTPUT}" == *"60"* ]]
 # Should contain "Failed" text
 [[ "${LOG_OUTPUT}" == *"Failed"* ]]
 # Should contain "GeoJSON" text
 [[ "${LOG_OUTPUT}" == *"GeoJSON"* ]]
}

@test "__log_geojson_conversion_failure should handle elapsed time in seconds" {
 # Test elapsed time formatting
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_geojson_conversion_failure "123" "5" "7" "180" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"180s"* ]]
}

@test "__log_geojson_conversion_failure should log after all retries" {
 # Test final failure after all retries
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_geojson_conversion_failure "999" "7" "7" "420" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"7/7"* ]]
 [[ "${LOG_OUTPUT}" == *"after retries"* ]]
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

# =============================================================================
# Variable Defaults Tests
# =============================================================================

@test "Environment variables should have defaults set" {
 # Test that default variables are set
 [[ -n "${OVERPASS_RETRIES_PER_ENDPOINT:-}" ]]
 [[ -n "${OVERPASS_BACKOFF_SECONDS:-}" ]]
 
 # Defaults should be reasonable values
 [[ "${OVERPASS_RETRIES_PER_ENDPOINT}" -gt 0 ]]
 [[ "${OVERPASS_BACKOFF_SECONDS}" -gt 0 ]]
}

@test "Environment variables can be overridden" {
 # Test that variables can be overridden
 export OVERPASS_RETRIES_PER_ENDPOINT=10
 export OVERPASS_BACKOFF_SECONDS=30
 
 # Reload functions to pick up new values
 source "${TEST_BASE_DIR}/bin/lib/overpassFunctions.sh"
 
 [[ "${OVERPASS_RETRIES_PER_ENDPOINT}" -eq 10 ]]
 [[ "${OVERPASS_BACKOFF_SECONDS}" -eq 30 ]]
}

