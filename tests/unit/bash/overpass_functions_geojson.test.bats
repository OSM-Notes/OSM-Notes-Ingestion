#!/usr/bin/env bats

# Overpass Functions GeoJSON Tests
# Tests for GeoJSON conversion and validation logging functions
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

