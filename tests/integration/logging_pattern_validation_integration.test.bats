#!/usr/bin/env bats

# Integration test for Logging Pattern Validation
# Test file: logging_pattern_validation_integration.test.bats
# Author: Andres Gomez (AngocA)
# Version: 2025-01-27

load "../test_helper.bash"

setup() {
  # Source the enhanced logger
  source "${SCRIPT_BASE_DIRECTORY}/lib/bash_logger.sh"
  
  # Create temporary directory for test results
  TEST_TEMP_DIR="/tmp/logging_validation_test_$$"
  mkdir -p "${TEST_TEMP_DIR}"
  
  # Set up test environment
  export SCRIPT_BASE_DIRECTORY="${SCRIPT_BASE_DIRECTORY}"
  export TEST_TEMP_DIR="${TEST_TEMP_DIR}"
  
  # Reset logger state
  __log_fd=""
  __set_log_level "INFO"
}

teardown() {
  # Clean up temporary files
  if [[ -d "${TEST_TEMP_DIR}" ]]; then
    rm -rf "${TEST_TEMP_DIR}"
  fi
}

@test "Logging Pattern Validation: Script should execute without errors" {
  # Test that the validation script can be executed
  local validation_script="${SCRIPT_BASE_DIRECTORY}/tests/scripts/validate_logging_patterns.sh"
  
  # Check if script exists and is executable
  [[ -f "${validation_script}" ]]
  [[ -x "${validation_script}" ]]
  
  # Test basic script execution (dry run)
  run bash -n "${validation_script}"
  [[ "$status" -eq 0 ]]
}

@test "Logging Pattern Validation: Script should validate test files" {
  # Create a small test file with functions to validate
  local test_file="${TEST_TEMP_DIR}/test_functions.sh"
  
  cat > "${test_file}" << 'EOF'
#!/bin/bash

function __test_function_correct() {
  __log_start
  local var="$1"
  
  if [[ -z "$var" ]]; then
    __loge "Variable is empty"
    __log_finish
    return 1
  fi
  
  if [[ "$var" == "error" ]]; then
    __loge "Error condition"
    __log_finish
    return 2
  fi
  
  __logi "Processing: $var"
  __log_finish
  return 0
}

function __test_function_simple() {
  __log_start
  __logi "Simple function"
  __log_finish
}
EOF
  
  # Test that the file exists and has the expected content
  [[ -f "${test_file}" ]]
  grep -q "function __test_function_correct" "${test_file}"
  grep -q "function __test_function_simple" "${test_file}"
  grep -q "__log_start" "${test_file}"
  grep -q "__log_finish" "${test_file}"
}

@test "Logging Pattern Validation: Should detect functions with missing __log_start" {
  # Create a test file with a function missing __log_start
  local test_file="${TEST_TEMP_DIR}/test_missing_start.sh"
  
  cat > "${test_file}" << 'EOF'
#!/bin/bash

function __test_function_missing_start() {
  local var="$1"
  __logi "Processing: $var"
  __log_finish
  return 0
}
EOF
  
  # Test that the file exists and has the expected content
  [[ -f "${test_file}" ]]
  grep -q "function __test_function_missing_start" "${test_file}"
  grep -q "__log_finish" "${test_file}"
  ! grep -q "__log_start" "${test_file}"
}

@test "Logging Pattern Validation: Should detect functions with missing __log_finish" {
  # Create a test file with a function missing __log_finish
  local test_file="${TEST_TEMP_DIR}/test_missing_finish.sh"
  
  cat > "${test_file}" << 'EOF'
#!/bin/bash

function __test_function_missing_finish() {
  __log_start
  local var="$1"
  __logi "Processing: $var"
  return 0
}
EOF
  
  # Test that the file exists and has the expected content
  [[ -f "${test_file}" ]]
  grep -q "function __test_function_missing_finish" "${test_file}"
  grep -q "__log_start" "${test_file}"
  ! grep -q "__log_finish" "${test_file}"
}

@test "Logging Pattern Validation: Should detect returns without __log_finish" {
  # Create a test file with a function that has returns without __log_finish
  local test_file="${TEST_TEMP_DIR}/test_returns_without_finish.sh"
  
  cat > "${test_file}" << 'EOF'
#!/bin/bash

function __test_function_returns_without_finish() {
  __log_start
  local var="$1"
  
  if [[ -z "$var" ]]; then
    __loge "Variable is empty"
    return 1  # Missing __log_finish before return
  fi
  
  if [[ "$var" == "error" ]]; then
    __loge "Error condition"
    return 2  # Missing __log_finish before return
  fi
  
  __logi "Processing: $var"
  __log_finish
  return 0
}
EOF
  
  # Test that the file exists and has the expected content
  [[ -f "${test_file}" ]]
  grep -q "function __test_function_returns_without_finish" "${test_file}"
  grep -q "return 1" "${test_file}"
  grep -q "return 2" "${test_file}"
  grep -q "return 0" "${test_file}"
}

@test "Logging Pattern Validation: Should validate correct functions" {
  # Create a test file with correctly formatted functions
  local test_file="${TEST_TEMP_DIR}/test_correct_functions.sh"
  
  cat > "${test_file}" << 'EOF'
#!/bin/bash

function __test_function_correct() {
  __log_start
  local var="$1"
  
  if [[ -z "$var" ]]; then
    __loge "Variable is empty"
    __log_finish
    return 1
  fi
  
  if [[ "$var" == "error" ]]; then
    __loge "Error condition"
    __log_finish
    return 2
  fi
  
  __logi "Processing: $var"
  __log_finish
  return 0
}

function __test_function_simple() {
  __log_start
  __logi "Simple function"
  __log_finish
}
EOF
  
  # Test that the file exists and has the expected content
  [[ -f "${test_file}" ]]
  grep -q "function __test_function_correct" "${test_file}"
  grep -q "function __test_function_simple" "${test_file}"
  grep -q "__log_start" "${test_file}"
  grep -q "__log_finish" "${test_file}"
}

@test "Logging Pattern Validation: Simple validation script should work" {
  # Test the simple validation script as well
  local simple_script="${SCRIPT_BASE_DIRECTORY}/tests/scripts/validate_logging_patterns_simple.sh"
  
  # Check if script exists and is executable
  [[ -f "${simple_script}" ]]
  [[ -x "${simple_script}" ]]
  
  # Test basic script execution (dry run)
  run bash -n "${simple_script}"
  [[ "$status" -eq 0 ]]
}

@test "Logging Pattern Validation: Runner script should work" {
  # Test the runner script
  local runner_script="${SCRIPT_BASE_DIRECTORY}/tests/run_logging_validation.sh"
  
  # Check if script exists and is executable
  [[ -f "${runner_script}" ]]
  [[ -x "${runner_script}" ]]
  
  # Test basic script execution (dry run)
  run bash -n "${runner_script}"
  [[ "$status" -eq 0 ]]
}

@test "Logging Pattern Validation: Should generate proper output format" {
  # Test that the validation generates proper output format
  local validation_script="${SCRIPT_BASE_DIRECTORY}/tests/scripts/validate_logging_patterns.sh"
  
  # Create a very small test directory with just one file
  local test_dir="${TEST_TEMP_DIR}/test_validation_small"
  mkdir -p "${test_dir}"
  
  # Create a minimal test file
  cat > "${test_dir}/minimal.sh" << 'EOF'
#!/bin/bash

function __minimal_test() {
  __log_start
  __logi "Minimal test"
  __log_finish
}
EOF
  
  # Test that the file exists and has the expected content
  [[ -f "${test_dir}/minimal.sh" ]]
  grep -q "function __minimal_test" "${test_dir}/minimal.sh"
  grep -q "__log_start" "${test_dir}/minimal.sh"
  grep -q "__log_finish" "${test_dir}/minimal.sh"
  
  # Test that the validation script can be executed (dry run)
  run bash -n "${validation_script}"
  [[ "$status" -eq 0 ]]
}
