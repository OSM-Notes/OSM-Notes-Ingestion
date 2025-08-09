#!/usr/bin/env bats

# Unit tests for CLEAN flag handling in error functions
# Test file: clean_flag_handling.test.bats
# Author: Andres Gomez (AngocA)
# Version: 2025-01-23

load "../../test_helper.bash"

setup() {
  # Source the functions
  source "${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh"
  source "${SCRIPT_BASE_DIRECTORY}/bin/errorHandlingFunctions.sh"
  
  # Create temporary test files for cleanup testing
  TEST_FILE_1="/tmp/test_cleanup_file1.txt"
  TEST_FILE_2="/tmp/test_cleanup_file2.txt"
  
  # Create test files
  echo "test content 1" > "${TEST_FILE_1}"
  echo "test content 2" > "${TEST_FILE_2}"
}

teardown() {
  # Clean up test files
  rm -f "${TEST_FILE_1}" "${TEST_FILE_2}"
  unset CLEAN
}

@test "error handling should respect CLEAN=false and preserve files" {
  # Set CLEAN to false
  export CLEAN=false
  
  # Verify files exist before test
  [ -f "${TEST_FILE_1}" ]
  [ -f "${TEST_FILE_2}" ]
  
  # Test the error handling function from errorHandlingFunctions.sh
  # This should NOT delete the files because CLEAN=false
  CLEANUP_COMMAND="rm -f ${TEST_FILE_1} ${TEST_FILE_2}"
  
  # Run the function and expect it to NOT execute cleanup
  run __handle_error_with_cleanup "1" "Test error message" "${CLEANUP_COMMAND}"
  
  # Function should exit with error code 1
  [ "$status" -eq 1 ]
  
  # But files should still exist because CLEAN=false
  [ -f "${TEST_FILE_1}" ]
  [ -f "${TEST_FILE_2}" ]
  
  # Output should indicate cleanup was skipped
  [[ "$output" == *"Skipping cleanup command due to CLEAN=false"* ]]
}

@test "error handling should execute cleanup when CLEAN=true" {
  # Set CLEAN to true (default behavior)
  export CLEAN=true
  
  # Verify files exist before test
  [ -f "${TEST_FILE_1}" ]
  [ -f "${TEST_FILE_2}" ]
  
  # Test the error handling function
  CLEANUP_COMMAND="rm -f ${TEST_FILE_1} ${TEST_FILE_2}"
  
  # Run the function and expect it to execute cleanup
  run __handle_error_with_cleanup "1" "Test error message" "${CLEANUP_COMMAND}"
  
  # Function should exit with error code 1
  [ "$status" -eq 1 ]
  
  # Files should be deleted because CLEAN=true
  [ ! -f "${TEST_FILE_1}" ]
  [ ! -f "${TEST_FILE_2}" ]
  
  # Output should indicate cleanup was executed
  [[ "$output" == *"Executing cleanup command"* ]]
}

@test "error handling should default to CLEAN=true when not set" {
  # Don't set CLEAN variable (should default to true)
  unset CLEAN
  
  # Verify files exist before test
  [ -f "${TEST_FILE_1}" ]
  [ -f "${TEST_FILE_2}" ]
  
  # Test the error handling function
  CLEANUP_COMMAND="rm -f ${TEST_FILE_1} ${TEST_FILE_2}"
  
  # Run the function and expect it to execute cleanup (default behavior)
  run __handle_error_with_cleanup "1" "Test error message" "${CLEANUP_COMMAND}"
  
  # Function should exit with error code 1
  [ "$status" -eq 1 ]
  
  # Files should be deleted because default is CLEAN=true
  [ ! -f "${TEST_FILE_1}" ]
  [ ! -f "${TEST_FILE_2}" ]
}

@test "functionsProcess error handling should respect CLEAN=false" {
  # Set CLEAN to false
  export CLEAN=false
  
  # Create test files
  echo "content1" > "${TEST_FILE_1}"
  echo "content2" > "${TEST_FILE_2}"
  
  # Verify files exist
  [ -f "${TEST_FILE_1}" ]
  [ -f "${TEST_FILE_2}" ]
  
  # Mock the exit command to prevent test termination
  exit() { echo "EXIT_CALLED_WITH_CODE: $1"; return "$1"; }
  export -f exit
  
  # Test the functionsProcess version of error handling
  run __handle_error_with_cleanup "247" "Test integrity check failed" "rm -f ${TEST_FILE_1}" "rm -f ${TEST_FILE_2}"
  
  # Files should still exist because CLEAN=false
  [ -f "${TEST_FILE_1}" ]
  [ -f "${TEST_FILE_2}" ]
  
  # Output should indicate cleanup was skipped
  [[ "$output" == *"Skipping cleanup commands due to CLEAN=false"* ]]
}

@test "Planet Notes scenario with CLEAN=false should preserve downloaded files" {
  # Set CLEAN to false (like user reported)
  export CLEAN=false
  
  # Create mock Planet Notes files
  MOCK_PLANET="/tmp/OSM-notes-planet.xml.bz2"
  MOCK_MD5="/tmp/OSM-notes-planet.xml.bz2.md5"
  
  echo "mock planet content" > "${MOCK_PLANET}"
  echo "mock md5 content" > "${MOCK_MD5}"
  
  # Verify files exist
  [ -f "${MOCK_PLANET}" ]
  [ -f "${MOCK_MD5}" ]
  
  # Mock the exit command
  exit() { echo "EXIT_CALLED_WITH_CODE: $1"; return "$1"; }
  export -f exit
  
  # Simulate the exact cleanup command from Planet Notes processing
  CLEANUP_CMD="rm -f ${MOCK_PLANET} ${MOCK_MD5} 2>/dev/null || true"
  
  # Run error handling
  run __handle_error_with_cleanup "247" "File integrity check failed" "${CLEANUP_CMD}"
  
  # Files should be preserved
  [ -f "${MOCK_PLANET}" ]
  [ -f "${MOCK_MD5}" ]
  
  # Clean up
  rm -f "${MOCK_PLANET}" "${MOCK_MD5}"
}

@test "CLEAN flag should be documented in help messages" {
  # Test that processPlanetNotes mentions CLEAN flag
  run bash -c 'source "${SCRIPT_BASE_DIRECTORY}/bin/process/processPlanetNotes.sh" --help 2>/dev/null || true'
  
  # Should mention CLEAN in help or show_help function
  [[ "$output" == *"CLEAN"* ]] || [[ "$output" == *"left all created files"* ]]
}
