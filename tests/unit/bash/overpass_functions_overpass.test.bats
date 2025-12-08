#!/usr/bin/env bats

# Overpass Functions Overpass Tests
# Tests for Overpass API logging functions
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

