#!/usr/bin/env bats

# Note Processing Common Tests
# Tests for function existence and error handling
# Author: Andres Gomez (AngocA)
# Version: 2025-12-07

load "${BATS_TEST_DIRNAME}/../../test_helper"

setup() {
 # Create temporary test directory
 TEST_DIR=$(mktemp -d)
 export TEST_DIR

 # Set up test environment variables
 export SCRIPT_BASE_DIRECTORY="${TEST_BASE_DIR}"
 export TMP_DIR="${TEST_DIR}"
 export DBNAME="${TEST_DBNAME:-test_db}"
 export RATE_LIMIT="${RATE_LIMIT:-8}"
 export BASHPID=$$

 # Set log level to DEBUG to capture all log output
 export LOG_LEVEL="DEBUG"
 export __log_level="DEBUG"

 # Load note processing functions
 source "${TEST_BASE_DIR}/bin/lib/noteProcessingFunctions.sh"
}

teardown() {
 # Clean up test files
 rm -rf "${TEST_DIR}"
}

# =============================================================================
# Function Existence Tests
# =============================================================================

@test "All note processing functions should be available" {
 # Test that all note processing functions exist
 run declare -f __getLocationNotes_impl
 [[ "${status}" -eq 0 ]]

 run declare -f __validate_xml_coordinates
 [[ "${status}" -eq 0 ]]

 run declare -f __check_network_connectivity
 [[ "${status}" -eq 0 ]]

 run declare -f __handle_error_with_cleanup
 [[ "${status}" -eq 0 ]]

 run declare -f __acquire_download_slot
 [[ "${status}" -eq 0 ]]

 run declare -f __release_download_slot
 [[ "${status}" -eq 0 ]]

 run declare -f __cleanup_stale_slots
 [[ "${status}" -eq 0 ]]

 run declare -f __wait_for_download_slot
 [[ "${status}" -eq 0 ]]

 run declare -f __get_download_ticket
 [[ "${status}" -eq 0 ]]

 run declare -f __queue_prune_stale_locks
 [[ "${status}" -eq 0 ]]

 run declare -f __wait_for_download_turn
 [[ "${status}" -eq 0 ]]

 run declare -f __release_download_ticket
 [[ "${status}" -eq 0 ]]

 run declare -f __retry_file_operation
 [[ "${status}" -eq 0 ]]

 run declare -f __check_overpass_status
 [[ "${status}" -eq 0 ]]

 run declare -f __retry_network_operation
 [[ "${status}" -eq 0 ]]

 run declare -f __retry_overpass_api
 [[ "${status}" -eq 0 ]]

 run declare -f __retry_osm_api
 [[ "${status}" -eq 0 ]]

 run declare -f __retry_geoserver_api
 [[ "${status}" -eq 0 ]]

 run declare -f __retry_database_operation
 [[ "${status}" -eq 0 ]]

 run declare -f __log_data_gap
 [[ "${status}" -eq 0 ]]
}

# =============================================================================
# Tests for __handle_error_with_cleanup
# =============================================================================

@test "__handle_error_with_cleanup should execute cleanup commands when CLEAN=true" {
 export CLEAN="true"
 export TEST_MODE="true"
 export BATS_TEST_NAME="test"

 # Use a file to track cleanup execution
 local CLEANUP_FILE="${TEST_DIR}/cleanup_executed.txt"
 rm -f "${CLEANUP_FILE}"

 # Create a cleanup command that creates a file
 local CLEANUP_CMD="touch ${CLEANUP_FILE}"

 run __handle_error_with_cleanup 1 "Test error" "${CLEANUP_CMD}" 2>/dev/null
 [[ "${status}" -eq 1 ]]
 [[ -f "${CLEANUP_FILE}" ]]
}

@test "__handle_error_with_cleanup should skip cleanup when CLEAN=false" {
 export CLEAN="false"
 export TEST_MODE="true"
 export BATS_TEST_NAME="test"

 local CLEANUP_EXECUTED=false
 cleanup_cmd() {
  CLEANUP_EXECUTED=true
 }

 run __handle_error_with_cleanup 1 "Test error" "cleanup_cmd"
 [[ "${status}" -eq 1 ]]
 [[ "${CLEANUP_EXECUTED}" == "false" ]]
}

@test "__handle_error_with_cleanup should return error code in test mode" {
 export TEST_MODE="true"
 export BATS_TEST_NAME="test"

 run __handle_error_with_cleanup 42 "Test error"
 [[ "${status}" -eq 42 ]]
}

@test "__handle_error_with_cleanup should create failed execution file" {
 export TEST_MODE="true"
 export BATS_TEST_NAME="test"
 export FAILED_EXECUTION_FILE="${TEST_DIR}/failed_execution.txt"

 run __handle_error_with_cleanup 1 "Test error"
 [[ "${status}" -eq 1 ]]
 [[ -f "${FAILED_EXECUTION_FILE}" ]]
 [[ "$(cat "${FAILED_EXECUTION_FILE}")" == *"Test error"* ]]
}

