#!/usr/bin/env bats

# Boundary Processing Common Tests
# Tests for function existence
# Author: Andres Gomez (AngocA)
# Version: 2025-12-08

load "${BATS_TEST_DIRNAME}/../../test_helper"

setup() {
 # Create temporary test directory
 TEST_DIR=$(mktemp -d)
 export TEST_DIR

 # Set up test environment variables
 export SCRIPT_BASE_DIRECTORY="${TEST_BASE_DIR}"
 export TMP_DIR="${TEST_DIR}"
 export DBNAME="${TEST_DBNAME:-test_db}"
 export BASHPID=$$

 # Set log level to DEBUG to capture all log output
 export LOG_LEVEL="DEBUG"
 export __log_level="DEBUG"

 # Load boundary processing functions
 source "${TEST_BASE_DIR}/bin/lib/boundaryProcessingFunctions.sh"
}

teardown() {
 # Clean up test files
 rm -rf "${TEST_DIR}"
}

# =============================================================================
# Function Existence Tests
# =============================================================================

@test "All boundary processing functions should be available" {
 # Test that all boundary processing functions exist
 run declare -f __log_download_start
 [[ "${status}" -eq 0 ]]

 run declare -f __log_json_validation_failure
 [[ "${status}" -eq 0 ]]

 run declare -f __log_download_success
 [[ "${status}" -eq 0 ]]

 run declare -f __log_geojson_conversion_start
 [[ "${status}" -eq 0 ]]

 run declare -f __log_geojson_retry_delay
 [[ "${status}" -eq 0 ]]

 run declare -f __log_import_start
 [[ "${status}" -eq 0 ]]

 run declare -f __log_field_selected_import
 [[ "${status}" -eq 0 ]]

 run declare -f __log_taiwan_special_handling
 [[ "${status}" -eq 0 ]]

 run declare -f __log_duplicate_columns_fixed
 [[ "${status}" -eq 0 ]]

 run declare -f __log_duplicate_columns_skip
 [[ "${status}" -eq 0 ]]

 run declare -f __log_process_complete
 [[ "${status}" -eq 0 ]]

 run declare -f __log_lock_acquired
 [[ "${status}" -eq 0 ]]

 run declare -f __log_lock_failed
 [[ "${status}" -eq 0 ]]

 run declare -f __log_import_completed
 [[ "${status}" -eq 0 ]]

 run declare -f __log_no_duplicate_columns
 [[ "${status}" -eq 0 ]]

 run declare -f __resolve_geojson_file
 [[ "${status}" -eq 0 ]]

 run declare -f __validate_capital_location
 [[ "${status}" -eq 0 ]]

 run declare -f __compareIdsWithBackup
 [[ "${status}" -eq 0 ]]

 run declare -f __processBoundary_impl
 [[ "${status}" -eq 0 ]]

 run declare -f __processCountries_impl
 [[ "${status}" -eq 0 ]]

 run declare -f __processMaritimes_impl
 [[ "${status}" -eq 0 ]]
}

