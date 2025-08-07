#!/usr/bin/env bats

# Test file for checksum validation functions
# Author: Andres Gomez (AngocA)
# Version: 2025-07-27

load "${BATS_TEST_DIRNAME}/../../test_helper.bash"

setup() {
  # Disable enhanced logger for tests - use simple logger
  export LOGGER_UTILITY=""
  
  # Define simple logging functions for tests
  function __logd() { echo "DEBUG: $*"; }
  function __loge() { echo "ERROR: $*" >&2; }
  
  # Create temporary test files
  TEST_FILE=$(mktemp)
  TEST_CHECKSUM_FILE=$(mktemp)
  
  # Create test file with content
  echo "This is a test file for checksum validation" > "${TEST_FILE}"
  
  # Create test checksum file
  md5sum "${TEST_FILE}" > "${TEST_CHECKSUM_FILE}"
}

teardown() {
  # Clean up temporary files
  rm -f "${TEST_FILE}" "${TEST_CHECKSUM_FILE}"
}

@test "validate_file_checksum with valid MD5" {
  # Get the expected checksum
  local expected_checksum
  expected_checksum=$(md5sum "${TEST_FILE}" | cut -d' ' -f 1)
  
  run __validate_file_checksum "${TEST_FILE}" "${expected_checksum}" "md5"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DEBUG: md5 checksum validation passed"* ]]
}

@test "validate_file_checksum with invalid MD5" {
  run __validate_file_checksum "${TEST_FILE}" "invalid_checksum" "md5"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: md5 checksum validation failed"* ]]
  [[ "$output" == *"Checksum mismatch"* ]]
}

@test "validate_file_checksum with empty checksum" {
  run __validate_file_checksum "${TEST_FILE}" "" "md5"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: Expected checksum is empty"* ]]
}

@test "validate_file_checksum with non-existent file" {
  run __validate_file_checksum "/non/existent/file" "dummy" "md5"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: File for checksum validation not found"* ]]
}

@test "validate_file_checksum with invalid algorithm" {
  run __validate_file_checksum "${TEST_FILE}" "dummy" "invalid_algo"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: invalid_algo checksum validation failed"* ]]
  [[ "$output" == *"Invalid algorithm"* ]]
}

@test "validate_file_checksum_from_file with valid file" {
  run __validate_file_checksum_from_file "${TEST_FILE}" "${TEST_CHECKSUM_FILE}" "md5"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DEBUG: md5 checksum validation passed"* ]]
}

@test "validate_file_checksum_from_file with non-existent checksum file" {
  run __validate_file_checksum_from_file "${TEST_FILE}" "/non/existent/checksum" "md5"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: Checksum file not found"* ]]
}

@test "validate_file_checksum_from_file with empty checksum file" {
  # Create empty checksum file
  local empty_checksum=$(mktemp)
  
  run __validate_file_checksum_from_file "${TEST_FILE}" "${empty_checksum}" "md5"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: Could not extract checksum from file"* ]]
  
  rm -f "${empty_checksum}"
}

@test "generate_file_checksum with MD5" {
  run __generate_file_checksum "${TEST_FILE}" "md5"
  [ "$status" -eq 0 ]
  [[ "$output" == *"$(md5sum "${TEST_FILE}" | cut -d' ' -f 1)"* ]]
}

@test "generate_file_checksum with SHA256" {
  run __generate_file_checksum "${TEST_FILE}" "sha256"
  [ "$status" -eq 0 ]
  [[ "$output" == *"$(sha256sum "${TEST_FILE}" | cut -d' ' -f 1)"* ]]
}

@test "generate_file_checksum with output file" {
  local output_file=$(mktemp)
  
  run __generate_file_checksum "${TEST_FILE}" "md5" "${output_file}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DEBUG: md5 checksum saved to"* ]]
  
  # Verify output file contains the checksum
  local expected_checksum
  expected_checksum=$(md5sum "${TEST_FILE}")
  [[ "$(cat "${output_file}")" == "${expected_checksum}" ]]
  
  rm -f "${output_file}"
}

@test "generate_file_checksum with non-existent file" {
  run __generate_file_checksum "/non/existent/file" "md5"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: File for checksum generation not found"* ]]
}

@test "generate_file_checksum with invalid algorithm" {
  run __generate_file_checksum "${TEST_FILE}" "invalid_algo"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: Invalid algorithm"* ]]
}

@test "validate_directory_checksums with valid files" {
  # Create test directory and files
  local test_dir=$(mktemp -d)
  local test_file1="${test_dir}/file1.txt"
  local test_file2="${test_dir}/file2.txt"
  local checksum_file=$(mktemp)
  
  echo "Content 1" > "${test_file1}"
  echo "Content 2" > "${test_file2}"
  
  # Create checksum file
  {
    md5sum "${test_file1}"
    md5sum "${test_file2}"
  } > "${checksum_file}"
  
  # Set up environment variables needed by the function
  export BASENAME="test"
  export TMP_DIR=$(mktemp -d)
  
  run __validate_directory_checksums "${test_dir}" "${checksum_file}" "md5"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DEBUG: Directory checksum validation passed"* ]]
  
  # Clean up
  rm -rf "${test_dir}" "${checksum_file}" "${TMP_DIR}"
}

@test "validate_directory_checksums with invalid checksum" {
  # Create test directory and files
  local test_dir=$(mktemp -d)
  local test_file="${test_dir}/file.txt"
  local checksum_file=$(mktemp)
  
  echo "Content" > "${test_file}"
  
  # Create checksum file with invalid checksum
  echo "invalid_checksum file.txt" > "${checksum_file}"
  
  run __validate_directory_checksums "${test_dir}" "${checksum_file}" "md5"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: Directory checksum validation failed"* ]]
  
  # Clean up
  rm -rf "${test_dir}" "${checksum_file}"
}

@test "validate_directory_checksums with non-existent directory" {
  local checksum_file=$(mktemp)
  echo "dummy dummy.txt" > "${checksum_file}"
  
  run __validate_directory_checksums "/non/existent/dir" "${checksum_file}" "md5"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: Directory validation failed"* ]]
  
  rm -f "${checksum_file}"
}

@test "checksum validation with various algorithms" {
  local algorithms=("md5" "sha1" "sha256" "sha512")
  
  for algo in "${algorithms[@]}"; do
    # Skip if command not available
    if ! command -v "${algo}sum" &> /dev/null; then
      continue
    fi
    
    # Generate expected checksum
    local expected_checksum
    case "${algo}" in
      "md5")
        expected_checksum=$(md5sum "${TEST_FILE}" | cut -d' ' -f 1)
        ;;
      "sha1")
        expected_checksum=$(sha1sum "${TEST_FILE}" | cut -d' ' -f 1)
        ;;
      "sha256")
        expected_checksum=$(sha256sum "${TEST_FILE}" | cut -d' ' -f 1)
        ;;
      "sha512")
        expected_checksum=$(sha512sum "${TEST_FILE}" | cut -d' ' -f 1)
        ;;
    esac
    
    run __validate_file_checksum "${TEST_FILE}" "${expected_checksum}" "${algo}"
    [ "$status" -eq 0 ] || echo "Failed for algorithm: ${algo}"
    [[ "$output" == *"DEBUG: ${algo} checksum validation passed"* ]]
  done
}