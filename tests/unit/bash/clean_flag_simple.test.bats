#!/usr/bin/env bats

# Simple tests for CLEAN flag handling
# Test file: clean_flag_simple.test.bats
# Author: Andres Gomez (AngocA)
# Version: 2025-08-14

load "../../test_helper.bash"

setup() {
 # Create temporary test files
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

@test "CLEAN flag should be documented in processPlanetNotes" {
 # Check that CLEAN is documented in the script
 grep -q "CLEAN.*false.*left all created files" "${SCRIPT_BASE_DIRECTORY}/bin/process/processPlanetNotes.sh"
}

@test "CLEAN=false should be respected in error functions" {
 # Set CLEAN to false for this test
 # shellcheck disable=SC2030
 export CLEAN=false

 # Create test files
 echo "content1" > /tmp/cleanup_test1.txt
 echo "content2" > /tmp/cleanup_test2.txt

 # Verify files exist before cleanup
 [[ -f "/tmp/cleanup_test1.txt" ]]
 [[ -f "/tmp/cleanup_test2.txt" ]]

 # Define basic logging functions to avoid errors
 # shellcheck disable=SC2317
 __start_logger() { :; }
 # shellcheck disable=SC2317
 __logd() { :; }
 # shellcheck disable=SC2317
 __logi() { :; }
 # shellcheck disable=SC2317
 __logw() { :; }
 # shellcheck disable=SC2317
 __loge() { echo "ERROR: $*" >&2; }
 # shellcheck disable=SC2317
 __log_finish() { :; }

 # Source the error handling functions
 source "${SCRIPT_BASE_DIRECTORY}/bin/errorHandlingFunctions.sh"

 # Mock exit function to prevent script termination
 # shellcheck disable=SC2317
 exit() {
  echo "EXIT_CALLED: $1"
  return "$1"
 }

 # Call error function with cleanup
 __handle_error_with_cleanup "1" "Test error" "rm -f /tmp/cleanup_test1.txt /tmp/cleanup_test2.txt" || true

 # Files should still exist because CLEAN=false
 [[ -f "/tmp/cleanup_test1.txt" ]]
 [[ -f "/tmp/cleanup_test2.txt" ]]

 # Clean up test files
 rm -f /tmp/cleanup_test1.txt /tmp/cleanup_test2.txt
}

@test "CLEAN=true should execute cleanup in error functions" {
 # Set CLEAN to true for this test
 # shellcheck disable=SC2031
 export CLEAN=true

 # Create test files
 echo "content1" > /tmp/cleanup_test1.txt
 echo "content2" > /tmp/cleanup_test2.txt

 # Verify files exist before cleanup
 [[ -f "/tmp/cleanup_test1.txt" ]]
 [[ -f "/tmp/cleanup_test2.txt" ]]

 # Define basic logging functions to avoid errors
 # shellcheck disable=SC2317
 __start_logger() { :; }
 # shellcheck disable=SC2317
 __logd() { :; }
 # shellcheck disable=SC2317
 __logi() { :; }
 # shellcheck disable=SC2317
 __logw() { :; }
 # shellcheck disable=SC2317
 __loge() { echo "ERROR: $*" >&2; }
 # shellcheck disable=SC2317
 __log_finish() { :; }

 # Source the error handling functions
 source "${SCRIPT_BASE_DIRECTORY}/bin/errorHandlingFunctions.sh"

 # Mock exit function to prevent script termination
 # shellcheck disable=SC2317
 exit() {
  echo "EXIT_CALLED: $1"
  return "$1"
 }

 # Call error function with cleanup
 __handle_error_with_cleanup "1" "Test error" "rm -f /tmp/cleanup_test1.txt /tmp/cleanup_test2.txt" || true

 # Files should be deleted because CLEAN=true
 [[ ! -f "/tmp/cleanup_test1.txt" ]]
 [[ ! -f "/tmp/cleanup_test2.txt" ]]
}

@test "Planet Notes checksum validation issue should be fixed" {
 # Test the exact scenario that was failing
 # shellcheck disable=SC2031
 source "${SCRIPT_BASE_DIRECTORY}/bin/validationFunctions.sh"

 # Create mock Planet file and MD5
 echo "mock planet content" > /tmp/OSM-notes-planet.xml.bz2
 # shellcheck disable=SC2312
 CHECKSUM=$(md5sum /tmp/OSM-notes-planet.xml.bz2 | cut -d' ' -f1)
 echo "${CHECKSUM}  planet-notes-latest.osn.bz2" > /tmp/OSM-notes-planet.xml.bz2.md5

 # This should now succeed (it used to fail with "Could not extract checksum")
 run __validate_file_checksum_from_file "/tmp/OSM-notes-planet.xml.bz2" "/tmp/OSM-notes-planet.xml.bz2.md5" "md5"
 [[ "${status}" -eq 0 ]]

 # Clean up
 rm -f /tmp/OSM-notes-planet.xml.bz2 /tmp/OSM-notes-planet.xml.bz2.md5
}

@test "Original Planet Notes problem scenario should work" {
 # Simulate the exact failing scenario from the user's logs
 # shellcheck disable=SC2031
 source "${SCRIPT_BASE_DIRECTORY}/bin/validationFunctions.sh"

 # Create the exact filename scenario
 echo "f451953cfcb4450a48a779d0a63dde5c  planet-notes-latest.osn.bz2" > /tmp/real_planet.md5

 # Create a dummy file with the local name
 echo "dummy content" > /tmp/OSM-notes-planet.xml.bz2

 # This should use fallback logic and not fail with "Could not extract checksum"
 # (It will fail with checksum mismatch, but that's expected with dummy content)
 run __validate_file_checksum_from_file "/tmp/OSM-notes-planet.xml.bz2" "/tmp/real_planet.md5" "md5"

 # Should not fail with "Could not extract checksum" error
 [[ "${output}" != *"Could not extract checksum from file"* ]]

 # Clean up
 rm -f /tmp/real_planet.md5 /tmp/OSM-notes-planet.xml.bz2
}
