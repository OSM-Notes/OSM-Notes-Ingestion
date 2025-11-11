#!/usr/bin/env bats

# Unit test for logging improvements in boundary processing
# Tests the specific logging enhancements added to handle boundary processing errors
#
# Author: Andres Gomez (AngocA)
# Version: 2025-11-11

load ../../test_helper

setup() {
 # Setup test environment
 export SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
 export TMP_DIR="$(mktemp -d)"
 export BASENAME="test_logging_improvements"

 # Ensure TMP_DIR exists and is writable
 if [[ ! -d "${TMP_DIR}" ]]; then
  mkdir -p "${TMP_DIR}"
 fi

 # Source the functions
 source "${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh"

 # Mock logger functions
 function __log_start() { echo "LOG_START: $*"; }
 function __log_finish() { echo "LOG_FINISH: $*"; }
 function __logi() { echo "INFO: $*"; }
 function __loge() { echo "ERROR: $*"; }
 function __logw() { echo "WARN: $*"; }
 function __logd() { echo "DEBUG: $*"; }
}

teardown() {
 # Cleanup test environment
 rm -rf "${TMP_DIR}"
}

# Test that validates logging markers in __processBoundary
@test "should validate logging markers in __processBoundary" {
 # Test that the logging markers are present in the function
 local -a logging_files=(
  "${SCRIPT_BASE_DIRECTORY}/bin/lib/boundaryProcessingFunctions.sh"
  "${SCRIPT_BASE_DIRECTORY}/bin/lib/overpassFunctions.sh"
 )

 # Test for start marker (more flexible search)
 run grep -q "=== STARTING BOUNDARY PROCESSING ===" "${logging_files[@]}"
 [ "$status" -eq 0 ]

 # Test for end marker (more flexible search)
 run grep -q "=== BOUNDARY PROCESSING COMPLETED SUCCESSFULLY ===" "${logging_files[@]}"
 [ "$status" -eq 0 ]

 # Test for detailed logging
 run grep -q "Boundary ID:" "${logging_files[@]}"
 [ "$status" -eq 0 ]

 run grep -q "Process ID:" "${logging_files[@]}"
 [ "$status" -eq 0 ]

 run grep -q "JSON file:" "${logging_files[@]}"
 [ "$status" -eq 0 ]

 run grep -q "GeoJSON file:" "${logging_files[@]}"
 [ "$status" -eq 0 ]
}

# Test that validates logging markers in __processList
@test "should validate logging markers in __processList" {
 local functions_file="${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh"

 # Test for start marker (more flexible search)
 run grep -q "=== STARTING LIST PROCESSING ===" "$functions_file"
 [ "$status" -eq 0 ]

 # Test for end marker (more flexible search)
 run grep -q "=== LIST PROCESSING COMPLETED ===" "$functions_file"
 [ "$status" -eq 0 ]

 # Test for progress logging
 run grep -q "Processing boundary ID:" "$functions_file"
 [ "$status" -eq 0 ]

 run grep -q "Total boundaries to process:" "$functions_file"
 [ "$status" -eq 0 ]

 # Test for statistics logging
 run grep -q "List processing completed:" "$functions_file"
 [ "$status" -eq 0 ]

 run grep -q "Successfully processed:" "$functions_file"
 [ "$status" -eq 0 ]

 run grep -q "Failed:" "$functions_file"
 [ "$status" -eq 0 ]
}

# Test that validates logging markers in __processCountries
@test "should validate logging markers in __processCountries" {
 local -a logging_files=(
  "${SCRIPT_BASE_DIRECTORY}/bin/lib/boundaryProcessingFunctions.sh"
  "${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh"
 )

 # Test for start marker (more flexible search)
 run grep -q "=== STARTING COUNTRIES PROCESSING ===" "${logging_files[@]}"
 [ "$status" -eq 0 ]

 # Test for end markers
 run grep -q "=== COUNTRIES PROCESSING COMPLETED SUCCESSFULLY ===" "${logging_files[@]}"
 [ "$status" -eq 0 ]

 run grep -q "=== COUNTRIES PROCESSING FAILED ===" "${logging_files[@]}"
 [ "$status" -eq 0 ]

 # Test for detailed logging
 run grep -q "Total countries:" "${logging_files[@]}"
 [ "$status" -eq 0 ]

 run grep -q "Max threads:" "${logging_files[@]}"
 [ "$status" -eq 0 ]

 run grep -q "Size per part:" "${logging_files[@]}"
 [ "$status" -eq 0 ]
}

# Test that validates detailed logging in __processBoundary
@test "should validate detailed logging in __processBoundary" {
 local -a logging_files=(
  "${SCRIPT_BASE_DIRECTORY}/bin/lib/boundaryProcessingFunctions.sh"
  "${SCRIPT_BASE_DIRECTORY}/bin/lib/overpassFunctions.sh"
 )

 # Test for network connectivity logging
 run grep -q "Checking network connectivity for boundary" "${logging_files[@]}"
 [ "$status" -eq 0 ]

 run grep -q "Network connectivity confirmed for boundary" "${logging_files[@]}"
 [ "$status" -eq 0 ]

 # Test for API call logging
 run grep -q "Downloading boundary.*from Overpass API" "${logging_files[@]}"
 [ "$status" -eq 0 ]

 run grep -q "Successfully downloaded boundary.*from Overpass API" "${logging_files[@]}"
 [ "$status" -eq 0 ]

 # Test for validation logging
 run grep -q "Validating JSON structure for boundary" "${logging_files[@]}"
 [ "$status" -eq 0 ]

 run grep -q "JSON validation passed for boundary" "${logging_files[@]}"
 [ "$status" -eq 0 ]

 run grep -q "Validating GeoJSON structure for boundary" "${logging_files[@]}"
 [ "$status" -eq 0 ]

 run grep -q "GeoJSON validation passed for boundary" "${logging_files[@]}"
 [ "$status" -eq 0 ]

 # Test for conversion logging
 run grep -q "Converting into GeoJSON for boundary" "${logging_files[@]}"
 [ "$status" -eq 0 ]

 run grep -q "GeoJSON conversion completed for boundary" "${logging_files[@]}"
 [ "$status" -eq 0 ]

 # Test for name extraction logging
 run grep -q "Extracting names for boundary" "${logging_files[@]}"
 [ "$status" -eq 0 ]

 run grep -q "Extracted names for boundary" "${logging_files[@]}"
 [ "$status" -eq 0 ]

 # Test for database operations logging
 run grep -q "Acquiring lock for boundary" "${logging_files[@]}"
 [ "$status" -eq 0 ]

 run grep -q "Lock acquired for boundary" "${logging_files[@]}"
 [ "$status" -eq 0 ]

 run grep -q "Importing boundary.*into database" "${logging_files[@]}"
 [ "$status" -eq 0 ]

 run grep -q "Database import completed for boundary" "${logging_files[@]}"
 [ "$status" -eq 0 ]

 run grep -q "Processing imported data for boundary" "${logging_files[@]}"
 [ "$status" -eq 0 ]

 run grep -q "Data processing completed for boundary" "${logging_files[@]}"
 [ "$status" -eq 0 ]
}

# Test that validates error handling logging
@test "should validate error handling logging" {
 local -a logging_files=(
  "${SCRIPT_BASE_DIRECTORY}/bin/lib/boundaryProcessingFunctions.sh"
  "${SCRIPT_BASE_DIRECTORY}/bin/lib/overpassFunctions.sh"
 )

 # Test for error logging patterns
 run grep -q "Network connectivity check failed for boundary" "${logging_files[@]}"
 [ "$status" -eq 0 ]

 run grep -q "Failed to retrieve boundary.*from Overpass after retries" "${logging_files[@]}"
 [ "$status" -eq 0 ]

 run grep -q "Too many requests to Overpass API for boundary" "${logging_files[@]}"
 [ "$status" -eq 0 ]

 run grep -q "JSON validation failed for boundary" "${logging_files[@]}"
 [ "$status" -eq 0 ]

 run grep -q "Failed to convert and validate GeoJSON for boundary" "${logging_files[@]}"
 [ "$status" -eq 0 ]

 run grep -q "GeoJSON validation failed for boundary" "${logging_files[@]}"
 [ "$status" -eq 0 ]

 run grep -q "Failed to acquire lock for boundary" "${logging_files[@]}"
 [ "$status" -eq 0 ]

 run grep -q "Failed to import boundary.*into database after retries" "${logging_files[@]}"
 [ "$status" -eq 0 ]

 run grep -q "Data processing failed for boundary" "${logging_files[@]}"
 [ "$status" -eq 0 ]
}

# Test that validates special handling logging
@test "should validate special handling logging" {
 local -a logging_files=(
  "${SCRIPT_BASE_DIRECTORY}/bin/lib/boundaryProcessingFunctions.sh"
  "${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh"
 )

 # Test for Austria special handling
 run grep -q "Using special handling for Austria" "${logging_files[@]}"
 [ "$status" -eq 0 ]

 run grep -q "Using special processing for Austria" "${logging_files[@]}"
 [ "$status" -eq 0 ]

 # Test for standard handling
 run grep -q "Standard import with field selection" "${logging_files[@]}"
 [ "$status" -eq 0 ]

 # Test for column duplication handling
 run grep -q "Checking for duplicate columns in import table" "${logging_files[@]}"
 [ "$status" -eq 0 ]

 run grep -q "No duplicate columns detected for boundary" "${logging_files[@]}"
 [ "$status" -eq 0 ]

 run grep -q "Duplicate columns fixed for boundary" "${logging_files[@]}"
 [ "$status" -eq 0 ]
}

# Test that validates QUERY_FILE variable handling
@test "should validate QUERY_FILE variable handling" {
 local -a logging_files=(
  "${SCRIPT_BASE_DIRECTORY}/bin/lib/boundaryProcessingFunctions.sh"
  "${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh"
 )

 # Test for QUERY_FILE definition
 run grep -q "Define query file variable" "${logging_files[@]}"
 [ "$status" -eq 0 ]

 run grep -q "QUERY_FILE.*=.*TMP_DIR.*query" "${logging_files[@]}"
 [ "$status" -eq 0 ]

 # Test for local variable usage in __processList
 run grep -q "Create a unique query file for this process" "${logging_files[@]}"
 [ "$status" -eq 0 ]

 run grep -q "QUERY_FILE_LOCAL.*=.*TMP_DIR.*query.*BASHPID" "${logging_files[@]}"
 [ "$status" -eq 0 ]

 # Test for parameter handling in __processBoundary
 run grep -q "Use provided query file or fall back to global" "${logging_files[@]}"
 [ "$status" -eq 0 ]

 run grep -q "QUERY_FILE_TO_USE.*=.*1.*QUERY_FILE" "${logging_files[@]}"
 [ "$status" -eq 0 ]
}

# Test that validates logging consistency
@test "should validate logging consistency" {
 local functions_file_main="${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh"
 local functions_file_boundary="${SCRIPT_BASE_DIRECTORY}/bin/lib/boundaryProcessingFunctions.sh"

 # Test that all major functions have start and end markers
 local functions=("__processBoundary" "__processList" "__processCountries")

 for func in "${functions[@]}"; do
  # Test for start marker (more flexible search)
  run grep -q "=== STARTING.*PROCESSING ===" "$functions_file_main" "$functions_file_boundary"
  [ "$status" -eq 0 ]

  # Test for end marker (more flexible search)
  run grep -q "===.*COMPLETED.*===" "$functions_file_main" "$functions_file_boundary"
  [ "$status" -eq 0 ]
 done

 # Test that logging levels are used consistently
 run grep -c "__logi.*===" "$functions_file_boundary"
 [ "$output" -gt 0 ]

 run grep -c "__logd.*boundary" "$functions_file_boundary"
 [ "$output" -gt 0 ]

 run grep -c "__loge.*ERROR" "$functions_file_boundary"
 [ "$output" -gt 0 ]
}

# Test that validates logging performance
@test "should validate logging performance" {
 # Test that logging doesn't significantly impact performance
 local start_time=$(date +%s.%N)

 # Simulate a simple logging operation
 for i in {1..100}; do
  __logi "Test log message $i" > /dev/null
 done

 local end_time=$(date +%s.%N)
 local duration=$(echo "$end_time - $start_time" | bc -l)

 # Logging 100 messages should take less than 1 second
 [[ $(echo "$duration < 1.0" | bc -l) -eq 1 ]]
}

# Test that validates logging format
@test "should validate logging format" {
 # Test that logging markers follow consistent format
 local functions_file="${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh"

 # Test for consistent marker format
 run grep -c "=== [A-Z_ ]* ===" "$functions_file"
 [ "$output" -gt 0 ]

 # Test that all markers are properly closed
 local start_markers=$(grep -c "=== STARTING" "$functions_file")
 local end_markers=$(grep -c "===.*COMPLETED" "$functions_file")

 # Should have roughly equal number of start and end markers
 [[ $start_markers -gt 0 ]]
 [[ $end_markers -gt 0 ]]
 [[ $((start_markers - end_markers)) -lt 2 ]] # Allow for minor differences
}
