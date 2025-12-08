#!/usr/bin/env bats

# Boundary Processing Logging Tests
# Tests for logging functions
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
# Tests for Logging Functions
# =============================================================================

@test "__log_download_start should log download start message" {
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_download_start "12345" "3" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"12345"* ]]
 [[ "${LOG_OUTPUT}" == *"3"* ]]
 [[ "${LOG_OUTPUT}" == *"download"* ]]
}

@test "__log_json_validation_failure should log validation failure" {
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_json_validation_failure "12345" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"12345"* ]]
 [[ "${LOG_OUTPUT}" == *"JSON validation failed"* ]]
}

@test "__log_download_success should log download success" {
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_download_success "12345" "10" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"12345"* ]]
 [[ "${LOG_OUTPUT}" == *"10s"* ]]
 [[ "${LOG_OUTPUT}" == *"successfully"* ]]
}

@test "__log_geojson_conversion_start should log conversion start" {
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_geojson_conversion_start "12345" "5" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"12345"* ]]
 [[ "${LOG_OUTPUT}" == *"GeoJSON"* ]]
 [[ "${LOG_OUTPUT}" == *"5"* ]]
}

@test "__log_geojson_retry_delay should log retry delay" {
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_geojson_retry_delay "12345" "5" "2" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"12345"* ]]
 [[ "${LOG_OUTPUT}" == *"5s"* ]]
 [[ "${LOG_OUTPUT}" == *"2"* ]]
}

@test "__log_import_start should log import start" {
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_import_start "12345" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"12345"* ]]
 [[ "${LOG_OUTPUT}" == *"Importing"* ]]
}

@test "__log_field_selected_import should log field selected import" {
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_field_selected_import "12345" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"12345"* ]]
 [[ "${LOG_OUTPUT}" == *"field-selected"* ]]
}

@test "__log_taiwan_special_handling should log Taiwan handling" {
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_taiwan_special_handling "16239" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"16239"* ]]
 [[ "${LOG_OUTPUT}" == *"Taiwan"* ]]
}

@test "__log_duplicate_columns_fixed should log duplicate columns fixed" {
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_duplicate_columns_fixed "12345" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"12345"* ]]
 [[ "${LOG_OUTPUT}" == *"Duplicate columns fixed"* ]]
}

@test "__log_duplicate_columns_skip should log duplicate columns skip" {
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_duplicate_columns_skip "12345" "test reason" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"12345"* ]]
 [[ "${LOG_OUTPUT}" == *"test reason"* ]]
}

@test "__log_process_complete should log process complete" {
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_process_complete "12345" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"12345"* ]]
 [[ "${LOG_OUTPUT}" == *"completed"* ]]
}

@test "__log_lock_acquired should log lock acquired" {
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_lock_acquired "12345" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"12345"* ]]
 [[ "${LOG_OUTPUT}" == *"Lock acquired"* ]]
}

@test "__log_lock_failed should log lock failed" {
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_lock_failed "12345" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"12345"* ]]
 [[ "${LOG_OUTPUT}" == *"Failed to acquire lock"* ]]
}

@test "__log_import_completed should log import completed" {
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_import_completed "12345" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"12345"* ]]
 [[ "${LOG_OUTPUT}" == *"Database import completed"* ]]
}

@test "__log_no_duplicate_columns should log no duplicate columns" {
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_no_duplicate_columns "12345" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"12345"* ]]
 [[ "${LOG_OUTPUT}" == *"No duplicate columns"* ]]
}

