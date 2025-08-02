#!/usr/bin/env bats

# Simple test file for XML validation functions
# Author: Andres Gomez (AngocA)
# Version: 2025-08-02

load "${BATS_TEST_DIRNAME}/../../test_helper"

setup() {
 # Setup test environment
 export SCRIPT_DIR="$(cd "${BATS_TEST_DIRNAME}/../../../bin" && pwd)"
 export PROCESS_SCRIPT="${SCRIPT_DIR}/process/processPlanetNotes.sh"
 
 # Source the script to test
 if [[ -f "${PROCESS_SCRIPT}" ]]; then
  source "${PROCESS_SCRIPT}"
 fi
}

@test "test script loading" {
 # Verify that the script file exists
 [[ -f "${PROCESS_SCRIPT}" ]]
 
 # Verify that basic functions are available
 [[ $(type -t __log_start) == "function" ]]
 [[ $(type -t __logi) == "function" ]]
}

@test "test XML validation functions availability" {
 # Check if our new functions are available
 [[ $(type -t __handle_xml_validation_error) == "function" ]]
 [[ $(type -t __cleanup_validation_temp_files) == "function" ]]
 [[ $(type -t __validate_xml_with_enhanced_error_handling) == "function" ]]
 [[ $(type -t __validate_xml_structure_alternative) == "function" ]]
}

@test "test error handling function" {
 # Test the error handling function directly
 run __handle_xml_validation_error 124 "/tmp/test.xml"
 [[ "${status}" -eq 1 ]]
 [[ "${output}" == *"ERROR: XML validation timed out"* ]]
}

@test "test cleanup function" {
 # Create a temporary file
 echo "test" > /tmp/sample_validation.xml
 
 # Test cleanup function
 run __cleanup_validation_temp_files
 [[ "${status}" -eq 0 ]]
 
 # Verify file is cleaned up
 [[ ! -f /tmp/sample_validation.xml ]]
} 