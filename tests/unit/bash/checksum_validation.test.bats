#!/usr/bin/env bats

# Unit tests for Checksum Validation Functions
# Test file: checksum_validation.test.bats
# Author: Andres Gomez (AngocA)
# Version: 2025-08-13

load "../../test_helper.bash"

setup() {
  # Source the validation functions
  source "${SCRIPT_BASE_DIRECTORY}/bin/validationFunctions.sh"
  
  # Create temporary test files
  TEST_FILE="/tmp/test_checksum_file.txt"
  TEST_MD5="/tmp/test_checksum_file.md5"
  TEST_PLANET_FILE="/tmp/OSM-notes-planet.xml.bz2"
  TEST_PLANET_MD5="/tmp/OSM-notes-planet.xml.bz2.md5"
  
  # Clean up any existing test files
  rm -f "${TEST_FILE}" "${TEST_MD5}" "${TEST_PLANET_FILE}" "${TEST_PLANET_MD5}"
}

teardown() {
  # Clean up test files
  rm -f "${TEST_FILE}" "${TEST_MD5}" "${TEST_PLANET_FILE}" "${TEST_PLANET_MD5}"
}

@test "checksum validation should work with matching filename" {
  # Create test file and checksum
  echo "test content for checksum validation" > "${TEST_FILE}"
  md5sum "${TEST_FILE}" > "${TEST_MD5}"
  
  # Test validation
  run __validate_file_checksum_from_file "${TEST_FILE}" "${TEST_MD5}" "md5"
  [ "$status" -eq 0 ]
}

@test "checksum validation should work with non-matching filename (Planet Notes scenario)" {
  # Create test file with different name than checksum file expects
  echo "fake planet content for testing" > "${TEST_PLANET_FILE}"
  
  # Create MD5 file with different filename (simulating Planet Notes scenario)
  ACTUAL_CHECKSUM=$(md5sum "${TEST_PLANET_FILE}" | cut -d' ' -f1)
  echo "${ACTUAL_CHECKSUM}  planet-notes-latest.osn.bz2" > "${TEST_PLANET_MD5}"
  
  # Test validation - should use fallback logic and succeed
  run __validate_file_checksum_from_file "${TEST_PLANET_FILE}" "${TEST_PLANET_MD5}" "md5"
  [ "$status" -eq 0 ]
  # The main thing is that it succeeds despite filename mismatch
}

@test "checksum validation should fail with corrupted file" {
  # Create test file and checksum
  echo "original content" > "${TEST_FILE}"
  md5sum "${TEST_FILE}" > "${TEST_MD5}"
  
  # Modify file content (corrupt it)
  echo "modified content" > "${TEST_FILE}"
  
  # Test validation - should fail
  run __validate_file_checksum_from_file "${TEST_FILE}" "${TEST_MD5}" "md5"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Checksum mismatch"* ]]
}

@test "checksum validation should handle single-line MD5 files" {
  # Create test file
  echo "test content for single line" > "${TEST_FILE}"
  EXPECTED_CHECKSUM=$(md5sum "${TEST_FILE}" | cut -d' ' -f1)
  
  # Create MD5 file with just the checksum (no filename)
  echo "${EXPECTED_CHECKSUM}" > "${TEST_MD5}"
  
  # Test validation
  run __validate_file_checksum_from_file "${TEST_FILE}" "${TEST_MD5}" "md5"
  [ "$status" -eq 0 ]
}

@test "checksum validation should handle MD5 files with multiple spaces" {
  # Create test file
  echo "test content with multiple spaces" > "${TEST_FILE}"
  EXPECTED_CHECKSUM=$(md5sum "${TEST_FILE}" | cut -d' ' -f1)
  
  # Create MD5 file with multiple spaces (like Planet Notes)
  echo "${EXPECTED_CHECKSUM}  $(basename "${TEST_FILE}")" > "${TEST_MD5}"
  
  # Test validation
  run __validate_file_checksum_from_file "${TEST_FILE}" "${TEST_MD5}" "md5"
  [ "$status" -eq 0 ]
}

@test "checksum validation should fail with empty MD5 file" {
  # Create test file
  echo "test content" > "${TEST_FILE}"
  
  # Create empty MD5 file
  touch "${TEST_MD5}"
  
  # Test validation - should fail
  run __validate_file_checksum_from_file "${TEST_FILE}" "${TEST_MD5}" "md5"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Could not extract checksum from file"* ]]
}

@test "checksum validation should fail with non-existent MD5 file" {
  # Create test file
  echo "test content" > "${TEST_FILE}"
  
  # Test validation with non-existent MD5 file
  run __validate_file_checksum_from_file "${TEST_FILE}" "/tmp/non_existent.md5" "md5"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Checksum file not found"* ]]
}

@test "checksum validation supports different algorithms" {
  # Create test file
  echo "test content for algorithms" > "${TEST_FILE}"
  
  # Test SHA256
  sha256sum "${TEST_FILE}" > "${TEST_MD5}"
  run __validate_file_checksum_from_file "${TEST_FILE}" "${TEST_MD5}" "sha256"
  [ "$status" -eq 0 ]
  
  # Test SHA1
  sha1sum "${TEST_FILE}" > "${TEST_MD5}"
  run __validate_file_checksum_from_file "${TEST_FILE}" "${TEST_MD5}" "sha1"
  [ "$status" -eq 0 ]
}

@test "checksum extraction should handle real Planet Notes MD5 format" {
  # Create a sample Planet Notes-style MD5 file
  echo "f451953cfcb4450a48a779d0a63dde5c  planet-notes-latest.osn.bz2" > "${TEST_MD5}"
  
  # Test extraction using the same logic as __validate_file_checksum_from_file
  EXPECTED_CHECKSUM=$(head -1 "${TEST_MD5}" | awk '{print $1}' 2>/dev/null)
  [ "${EXPECTED_CHECKSUM}" = "f451953cfcb4450a48a779d0a63dde5c" ]
  
  # Test with grep method (should fail for different filename)
  GREP_RESULT=$(grep "OSM-notes-planet.xml.bz2" "${TEST_MD5}" | awk '{print $1}' 2>/dev/null || echo "")
  [ -z "${GREP_RESULT}" ]
  
  # Test fallback method (should work)
  FALLBACK_RESULT=$(head -1 "${TEST_MD5}" | awk '{print $1}' 2>/dev/null)
  [ "${FALLBACK_RESULT}" = "f451953cfcb4450a48a779d0a63dde5c" ]
}