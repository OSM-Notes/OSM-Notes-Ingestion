#!/usr/bin/env bats

# Overpass Functions JSON Tests
# Tests for JSON validation logging functions
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

