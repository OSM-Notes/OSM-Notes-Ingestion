#!/usr/bin/env bats

# Unit tests for CLEAN flag handling in error functions
# Test file: clean_flag_handling.test.bats
# Author: Andres Gomez (AngocA)
# Version: 2025-12-29

load "../../test_helper.bash"

setup() {
  # Ensure SCRIPT_BASE_DIRECTORY is set
  if [[ -z "${SCRIPT_BASE_DIRECTORY:-}" ]]; then
    export SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
  fi
  
  # Source the functions
  # Note: functionsProcess.sh already loads errorHandlingFunctions.sh and noteProcessingFunctions.sh
  # Don't reload errorHandlingFunctions.sh as it would override the version from noteProcessingFunctions.sh
  # that accepts multiple cleanup commands
  source "${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh"
  
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
  # Note: functionsProcess.sh loads noteProcessingFunctions.sh which uses plural "commands"
  # but errorHandlingFunctions.sh uses singular "command", so we check for both
  [[ "$output" == *"Skipping cleanup commands due to CLEAN=false"* ]] || \
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
  
  # Ensure we're in test mode so the function returns instead of exiting
  export TEST_MODE=true
  export BATS_TEST_NAME="test"
  
  # Create test files fresh for this test
  echo "content1" > "${TEST_FILE_1}"
  echo "content2" > "${TEST_FILE_2}"
  
  # Verify files exist
  [ -f "${TEST_FILE_1}" ]
  [ -f "${TEST_FILE_2}" ]
  
  # Source noteProcessingFunctions.sh directly to ensure we have the version that accepts multiple cleanup commands
  # This version uses shift 2 and accepts multiple cleanup commands as separate arguments
  if [[ -f "${SCRIPT_BASE_DIRECTORY}/bin/lib/noteProcessingFunctions.sh" ]]; then
    source "${SCRIPT_BASE_DIRECTORY}/bin/lib/noteProcessingFunctions.sh"
  fi
  
  # Test the functionsProcess version of error handling with multiple cleanup commands
  # The version from noteProcessingFunctions.sh accepts multiple cleanup commands
  run __handle_error_with_cleanup "247" "Test integrity check failed" "rm -f ${TEST_FILE_1}" "rm -f ${TEST_FILE_2}"
  
  echo "DEBUG: status=$status, output='$output'" >&2
  echo "DEBUG: TEST_FILE_1 exists: $([ -f "${TEST_FILE_1}" ] && echo yes || echo no)" >&2
  echo "DEBUG: TEST_FILE_2 exists: $([ -f "${TEST_FILE_2}" ] && echo yes || echo no)" >&2
  
  # Files should still exist because CLEAN=false
  [ -f "${TEST_FILE_1}" ]
  [ -f "${TEST_FILE_2}" ]
  
  # Output should indicate cleanup was skipped (noteProcessingFunctions.sh uses plural "commands")
  [[ "$output" == *"Skipping cleanup commands due to CLEAN=false"* ]] || \
   [[ "$output" == *"Skipping cleanup command due to CLEAN=false"* ]]
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
  # Test that processPlanetNotes documents CLEAN flag in its comments
  run grep -q "CLEAN could be set to false, to left all created files" "${SCRIPT_BASE_DIRECTORY}/bin/process/processPlanetNotes.sh"
  
  # Should find the CLEAN documentation comment
  [ "$status" -eq 0 ]
}



