#!/usr/bin/env bats

# Unit tests for Checksum Validation Functions
# Test file: checksum_validation.test.bats
# Author: Andres Gomez (AngocA)
# Version: 2025-12-07

load "../../test_helper.bash"

setup() {
  # Ensure SCRIPT_BASE_DIRECTORY is set
  if [[ -z "${SCRIPT_BASE_DIRECTORY:-}" ]]; then
    export SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
  fi

  # Load logging functions first if not already loaded
  if ! declare -f __log_start > /dev/null 2>&1; then
    if [[ -f "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/commonFunctions.sh" ]]; then
      source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/commonFunctions.sh"
    fi
  fi

  # Source the validation functions
  source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/validationFunctions.sh"
  
  # Disable TEST_MODE and HYBRID_MOCK_MODE for checksum validation tests
  # These tests specifically need to validate checksums, not skip validation
  unset TEST_MODE
  unset HYBRID_MOCK_MODE
  
  # Ensure CLEAN is not set to true, as it might cause automatic cleanup
  # We want to preserve test files during validation
  export CLEAN=false
  
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
  # Create test file and checksum in a way that persists across sub-shells
  local test_file="/tmp/test_checksum_file.txt"
  local test_md5="/tmp/test_checksum_file.md5"
  
  # Clean up any existing files first
  rm -f "${test_file}" "${test_md5}"
  
  # Create test file
  echo "test content for checksum validation" > "${test_file}"
  
  # Verify test file exists before creating checksum
  [ -f "${test_file}" ]
  
  # Create checksum file
  md5sum "${test_file}" > "${test_md5}"
  
  # Verify both files exist before validation
  [ -f "${test_file}" ]
  [ -f "${test_md5}" ]
  
  # Verify file is still readable
  [ -r "${test_file}" ]
  [ -r "${test_md5}" ]
  
  # Test validation - don't use sub-shell, use the function directly
  # The function is already loaded in setup()
  run __validate_file_checksum_from_file "${test_file}" "${test_md5}" "md5"
  echo "DEBUG: status=$status, output='$output'" >&2
  echo "DEBUG: test_file exists: $([ -f "${test_file}" ] && echo yes || echo no)" >&2
  echo "DEBUG: test_md5 exists: $([ -f "${test_md5}" ] && echo yes || echo no)" >&2
  [ "$status" -eq 0 ]
}

@test "checksum validation should work with non-matching filename (Planet Notes scenario)" {
  # Create test file with different name than checksum file expects
  local test_planet_file="/tmp/OSM-notes-planet.xml.bz2"
  local test_planet_md5="/tmp/OSM-notes-planet.xml.bz2.md5"
  
  # Clean up any existing files first
  rm -f "${test_planet_file}" "${test_planet_md5}"
  
  # Create test file
  echo "fake planet content for testing" > "${test_planet_file}"
  
  # Verify test file exists before creating checksum
  [ -f "${test_planet_file}" ]
  
  # Create MD5 file with different filename (simulating Planet Notes scenario)
  ACTUAL_CHECKSUM=$(md5sum "${test_planet_file}" | cut -d' ' -f1)
  echo "${ACTUAL_CHECKSUM}  planet-notes-latest.osn.bz2" > "${test_planet_md5}"
  
  # Verify files exist before validation
  [ -f "${test_planet_file}" ]
  [ -f "${test_planet_md5}" ]
  [ -r "${test_planet_file}" ]
  [ -r "${test_planet_md5}" ]
  
  # Test validation - don't use sub-shell, use the function directly
  run __validate_file_checksum_from_file "${test_planet_file}" "${test_planet_md5}" "md5"
  echo "DEBUG: status=$status, output='$output'" >&2
  echo "DEBUG: test_planet_file exists: $([ -f "${test_planet_file}" ] && echo yes || echo no)" >&2
  echo "DEBUG: test_planet_md5 exists: $([ -f "${test_planet_md5}" ] && echo yes || echo no)" >&2
  [ "$status" -eq 0 ]
  # The main thing is that it succeeds despite filename mismatch
}

@test "checksum validation should fail with corrupted file" {
  # Create test file and checksum
  local test_file="/tmp/test_checksum_file.txt"
  local test_md5="/tmp/test_checksum_file.md5"
  
  # Clean up any existing files first
  rm -f "${test_file}" "${test_md5}"
  
  # Create test file
  echo "original content" > "${test_file}"
  
  # Verify test file exists before creating checksum
  [ -f "${test_file}" ]
  
  # Create checksum file
  md5sum "${test_file}" > "${test_md5}"
  
  # Verify files exist
  [ -f "${test_file}" ]
  [ -f "${test_md5}" ]
  
  # Modify file content (corrupt it) - but keep the file readable
  echo "modified content" > "${test_file}"
  
  # Verify file still exists and is readable after modification
  [ -f "${test_file}" ]
  [ -r "${test_file}" ]
  [ -f "${test_md5}" ]
  [ -r "${test_md5}" ]
  
  # Test validation - don't use sub-shell, use the function directly
  run __validate_file_checksum_from_file "${test_file}" "${test_md5}" "md5"
  echo "DEBUG: status=$status, output='$output'" >&2
  echo "DEBUG: test_file exists: $([ -f "${test_file}" ] && echo yes || echo no)" >&2
  echo "DEBUG: test_md5 exists: $([ -f "${test_md5}" ] && echo yes || echo no)" >&2
  [ "$status" -eq 1 ]
  # Accept various error messages about checksum mismatch
  [[ "$output" == *"Checksum mismatch"* ]] || \
   [[ "$output" == *"checksum validation failed"* ]] || \
   [[ "$output" == *"mismatch"* ]] || \
   [[ "$output" == *"checksum validation failed"* ]]
}

@test "checksum validation should handle single-line MD5 files" {
  # Create test file
  local test_file="/tmp/test_checksum_file.txt"
  local test_md5="/tmp/test_checksum_file.md5"
  
  # Clean up any existing files first
  rm -f "${test_file}" "${test_md5}"
  
  # Create test file
  echo "test content for single line" > "${test_file}"
  
  # Verify test file exists before creating checksum
  [ -f "${test_file}" ]
  
  # Calculate expected checksum (must be done after file is created and before it's modified)
  EXPECTED_CHECKSUM=$(md5sum "${test_file}" | cut -d' ' -f1)
  
  # Create MD5 file with just the checksum (no filename)
  echo "${EXPECTED_CHECKSUM}" > "${test_md5}"
  
  # Verify files exist before validation
  [ -f "${test_file}" ]
  [ -f "${test_md5}" ]
  [ -r "${test_file}" ]
  [ -r "${test_md5}" ]
  
  # Verify the checksum in the MD5 file matches what we expect
  local checksum_in_file
  checksum_in_file=$(cat "${test_md5}" | tr -d ' \n\r')
  [ "${checksum_in_file}" = "${EXPECTED_CHECKSUM}" ]
  
  # Test validation - don't use sub-shell, use the function directly
  run __validate_file_checksum_from_file "${test_file}" "${test_md5}" "md5"
  echo "DEBUG: status=$status, output='$output'" >&2
  echo "DEBUG: test_file exists: $([ -f "${test_file}" ] && echo yes || echo no)" >&2
  echo "DEBUG: test_md5 exists: $([ -f "${test_md5}" ] && echo yes || echo no)" >&2
  echo "DEBUG: EXPECTED_CHECKSUM=${EXPECTED_CHECKSUM}" >&2
  echo "DEBUG: checksum_in_file=${checksum_in_file}" >&2
  [ "$status" -eq 0 ]
}

@test "checksum validation should handle MD5 files with multiple spaces" {
  # Create test file
  local test_file="/tmp/test_checksum_file.txt"
  local test_md5="/tmp/test_checksum_file.md5"
  
  # Clean up any existing files first
  rm -f "${test_file}" "${test_md5}"
  
  # Create test file
  echo "test content with multiple spaces" > "${test_file}"
  EXPECTED_CHECKSUM=$(md5sum "${test_file}" | cut -d' ' -f1)
  
  # Create MD5 file with multiple spaces (like Planet Notes)
  echo "${EXPECTED_CHECKSUM}  $(basename "${test_file}")" > "${test_md5}"
  
  # Verify files exist
  [ -f "${test_file}" ]
  [ -f "${test_md5}" ]
  
  # Test validation - don't use sub-shell, use the function directly
  run __validate_file_checksum_from_file "${test_file}" "${test_md5}" "md5"
  [ "$status" -eq 0 ]
}

@test "checksum validation should fail with empty MD5 file" {
  # Create test file
  local test_file="/tmp/test_checksum_file.txt"
  local test_md5="/tmp/test_checksum_file.md5"
  
  # Clean up any existing files first
  rm -f "${test_file}" "${test_md5}"
  
  # Create test file
  echo "test content" > "${test_file}"
  
  # Create empty MD5 file
  touch "${test_md5}"
  
  # Verify files exist
  [ -f "${test_file}" ]
  [ -f "${test_md5}" ]
  
  # Test validation - should fail
  run __validate_file_checksum_from_file "${test_file}" "${test_md5}" "md5"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Could not extract checksum from file"* ]] || \
   [[ "$output" == *"Could not extract checksum"* ]] || \
   [[ "$output" == *"extract checksum"* ]]
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
  local test_file="/tmp/test_checksum_file.txt"
  local test_md5="/tmp/test_checksum_file.md5"
  
  # Clean up any existing files first
  rm -f "${test_file}" "${test_md5}"
  
  # Create test file
  echo "test content for algorithms" > "${test_file}"
  
  # Verify file exists
  [ -f "${test_file}" ]
  
  # Test SHA256
  sha256sum "${test_file}" > "${test_md5}"
  [ -f "${test_file}" ]
  [ -f "${test_md5}" ]
  run __validate_file_checksum_from_file "${test_file}" "${test_md5}" "sha256"
  [ "$status" -eq 0 ]
  
  # Test SHA1
  sha1sum "${test_file}" > "${test_md5}"
  [ -f "${test_file}" ]
  [ -f "${test_md5}" ]
  run __validate_file_checksum_from_file "${test_file}" "${test_md5}" "sha1"
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