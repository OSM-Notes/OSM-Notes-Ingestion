#!/usr/bin/env bats

# Overpass Functions Common Tests
# Tests for function existence and environment variables
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

