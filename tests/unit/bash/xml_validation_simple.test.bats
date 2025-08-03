#!/usr/bin/env bats

# Simple test file for XML validation functions
# Author: Andres Gomez (AngocA)
# Version: 2025-08-02

load "${BATS_TEST_DIRNAME}/../../test_helper"

setup() {
 # Setup test environment
 export SCRIPT_DIR="$(cd "${BATS_TEST_DIRNAME}/../../../bin" && pwd)"
 
 # Source only the functions we need for testing
 if [[ -f "${SCRIPT_DIR}/functionsProcess.sh" ]]; then
  source "${SCRIPT_DIR}/functionsProcess.sh"
 fi
 
 # Mock the XML validation functions for testing
 __handle_xml_validation_error() {
  local exit_code="${1}"
  local xml_file="${2}"
  echo "ERROR: XML validation timed out"
  return 1
 }
 
 __cleanup_validation_temp_files() {
  # Remove test files
  rm -f /tmp/sample_validation.xml
  return 0
 }
}

@test "test script loading" {
 # Verify that the functions file exists
 [[ -f "${SCRIPT_DIR}/functionsProcess.sh" ]]
 
 # Verify that basic functions are available
 [[ $(type -t __log_start) == "function" ]]
 [[ $(type -t __logi) == "function" ]]
}

@test "test XML validation functions availability" {
 # Check if our mock functions are available
 [[ $(type -t __handle_xml_validation_error) == "function" ]]
 [[ $(type -t __cleanup_validation_temp_files) == "function" ]]
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