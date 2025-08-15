#!/usr/bin/env bats

# Unit tests for Logging Pattern Validation
# Test file: logging_pattern_validation.test.bats
# Author: Andres Gomez (AngocA)
# Version: 2025-08-13

load "../../test_helper.bash"

setup() {
 # Source the enhanced logger
 # shellcheck disable=SC2154
 source "${SCRIPT_BASE_DIRECTORY}/lib/bash_logger.sh"

 # Create temporary log file for tests
 TEST_LOG_FILE="/tmp/logging_pattern_test_$$.log"

 # Reset logger state
 __log_fd=""
 __set_log_level "INFO"
}

teardown() {
 # Clean up temporary files
 if [[ -f "${TEST_LOG_FILE}" ]]; then
  rm -f "${TEST_LOG_FILE}"
 fi
}

@test "Logging Pattern: Functions should have __log_start at beginning" {
 # Test a function that follows the pattern correctly
 test_function_with_log_start() {
  __log_start
  local condition="true"
  if [[ "${condition}" == "true" ]]; then
   echo "Function executed successfully"
  fi
  __log_finish
 }

 run test_function_with_log_start
 [[ "${status}" -eq 0 ]]
 [[ "${output}" == *"STARTED TEST_FUNCTION_WITH_LOG_START"* ]]
 [[ "${output}" == *"FINISHED TEST_FUNCTION_WITH_LOG_START"* ]]
}

@test "Logging Pattern: Functions should have __log_finish before each return" {
 # Test a function with multiple returns that follows the pattern
 test_function_with_multiple_returns() {
  __log_start
  local condition="$1"
  if [[ "${condition}" == "true" ]]; then
   echo "Returning early"
   __log_finish
   return 0
  fi
  echo "Continuing execution"
  __log_finish
  return 1
 }

 # Test successful path
 run test_function_with_multiple_returns "true"
 [[ "${status}" -eq 0 ]]
 [[ "${output}" == *"STARTED TEST_FUNCTION_WITH_MULTIPLE_RETURNS"* ]]
 [[ "${output}" == *"FINISHED TEST_FUNCTION_WITH_MULTIPLE_RETURNS"* ]]

 # Test error path
 run test_function_with_multiple_returns "false"
 [[ "${status}" -eq 1 ]]
 [[ "${output}" == *"STARTED TEST_FUNCTION_WITH_MULTIPLE_RETURNS"* ]]
 [[ "${output}" == *"FINISHED TEST_FUNCTION_WITH_MULTIPLE_RETURNS"* ]]
}

@test "Logging Pattern: Functions should have __log_finish at the end" {
 # Test a function that follows the pattern correctly
 test_function_with_log_finish() {
  __log_start
  echo "Function executed successfully"
  __log_finish
 }

 run test_function_with_log_finish
 [[ "${status}" -eq 0 ]]
 [[ "${output}" == *"FINISHED TEST_FUNCTION_WITH_LOG_FINISH"* ]]
}

@test "Logging Pattern: Functions without __log_start should be detected" {
 # Test a function that doesn't follow the pattern
 test_function_missing_log_start() {
  echo "Function executed without __log_start"
  __log_finish
 }

 run test_function_missing_log_start
 [[ "${status}" -eq 0 ]]
 # Should not have STARTED message
 [[ "${output}" != *"STARTED TEST_FUNCTION_MISSING_LOG_START"* ]]
 # Should still have FINISHED message
 [[ "${output}" == *"FINISHED TEST_FUNCTION_MISSING_LOG_START"* ]]
}

@test "Logging Pattern: Functions without __log_finish should be detected" {
 # Test a function that doesn't follow the pattern
 test_function_missing_log_finish() {
  __log_start
  echo "Function executed without __log_finish"
 }

 run test_function_missing_log_finish
 [[ "${status}" -eq 0 ]]
 # Should have STARTED message
 [[ "${output}" == *"STARTED TEST_FUNCTION_MISSING_LOG_FINISH"* ]]
 # Should not have FINISHED message
 [[ "${output}" != *"FINISHED TEST_FUNCTION_MISSING_LOG_FINISH"* ]]
}

@test "Logging Pattern: Functions with exit should have __log_finish before exit" {
 # Test a function that exits and follows the pattern
 test_function_with_exit() {
  __log_start
  local condition="$1"
  if [[ "${condition}" == "true" ]]; then
   echo "Exiting early"
   __log_finish
   exit 0
  fi
  echo "Continuing execution"
  __log_finish
  exit 1
 }

 # Test successful path
 run test_function_with_exit "true"
 [[ "${status}" -eq 0 ]]
 [[ "${output}" == *"STARTED TEST_FUNCTION_WITH_EXIT"* ]]
 [[ "${output}" == *"FINISHED TEST_FUNCTION_WITH_EXIT"* ]]

 # Test error path
 run test_function_with_exit "false"
 [[ "${status}" -eq 1 ]]
 [[ "${output}" == *"STARTED TEST_FUNCTION_WITH_EXIT"* ]]
 [[ "${output}" == *"FINISHED TEST_FUNCTION_WITH_EXIT"* ]]
}

@test "Logging Pattern: Functions with error handling should follow pattern" {
 # Test a function with error handling that follows the pattern
 test_function_with_error_handling() {
  __log_start
  local input="$1"

  if [[ -z "${input}" ]]; then
   __loge "Input is empty"
   __log_finish
   return 1
  fi

  if [[ "${input}" == "error" ]]; then
   __loge "Input is error"
   __log_finish
   return 2
  fi

  __logi "Processing input: ${input}"
  echo "Input processed successfully: ${input}"
  __log_finish
  return 0
 }

 # Test error path 1
 run test_function_with_error_handling ""
 [[ "${status}" -eq 1 ]]
 [[ "${output}" == *"STARTED TEST_FUNCTION_WITH_ERROR_HANDLING"* ]]
 [[ "${output}" == *"FINISHED TEST_FUNCTION_WITH_ERROR_HANDLING"* ]]

 # Test error path 2
 run test_function_with_error_handling "error"
 [[ "${status}" -eq 2 ]]
 [[ "${output}" == *"STARTED TEST_FUNCTION_WITH_ERROR_HANDLING"* ]]
 [[ "${output}" == *"FINISHED TEST_FUNCTION_WITH_ERROR_HANDLING"* ]]

 # Test success path
 run test_function_with_error_handling "valid"
 [[ "${status}" -eq 0 ]]
 [[ "${output}" == *"STARTED TEST_FUNCTION_WITH_ERROR_HANDLING"* ]]
 [[ "${output}" == *"FINISHED TEST_FUNCTION_WITH_ERROR_HANDLING"* ]]
}

@test "Logging Pattern: Functions should handle nested function calls correctly" {
 # Test nested function calls with logging
 outer_function() {
  __log_start
  echo "Outer function started"
  inner_function
  echo "Outer function finished"
  __log_finish
 }

 inner_function() {
  __log_start
  echo "Inner function executed"
  __log_finish
 }

 run outer_function
 [[ "${status}" -eq 0 ]]
 [[ "${output}" == *"STARTED OUTER_FUNCTION"* ]]
 [[ "${output}" == *"STARTED INNER_FUNCTION"* ]]
 [[ "${output}" == *"FINISHED INNER_FUNCTION"* ]]
 [[ "${output}" == *"FINISHED OUTER_FUNCTION"* ]]
}

@test "Logging Pattern: Functions should handle parallel execution correctly" {
 # Test function that is safe for parallel execution
 parallel_safe_function() {
  __log_start
  local job_id="$1"
  __logi "Executing parallel job: ${job_id}"
  echo "Job ${job_id} completed"
  __log_finish
 }

 run parallel_safe_function "123"
 [[ "${status}" -eq 0 ]]
 [[ "${output}" == *"STARTED PARALLEL_SAFE_FUNCTION"* ]]
 [[ "${output}" == *"FINISHED PARALLEL_SAFE_FUNCTION"* ]]
}

@test "Logging Pattern: Functions should handle cleanup scenarios" {
 # Test function with cleanup that follows the pattern
 test_function_with_cleanup() {
  __log_start
  local temp_file="/tmp/test_cleanup_$$"

  # Create temporary file
  echo "test" > "${temp_file}"

  # Verify file exists
  if [[ ! -f "${temp_file}" ]]; then
   __loge "Failed to create temp file"
   __log_finish
   return 1
  fi

  # Cleanup
  rm -f "${temp_file}"

  # Verify cleanup
  if [[ -f "${temp_file}" ]]; then
   __loge "Failed to cleanup temp file"
   __log_finish
   return 1
  fi

  echo "Cleanup completed successfully"
  __log_finish
 }

 run test_function_with_cleanup
 [[ "${status}" -eq 0 ]]
 [[ "${output}" == *"STARTED TEST_FUNCTION_WITH_CLEANUP"* ]]
 [[ "${output}" == *"FINISHED TEST_FUNCTION_WITH_CLEANUP"* ]]
}

@test "Logging Pattern: Special functions like __show_help should not require logging" {
 # Test that help functions don't require logging
 test_help_function() {
  echo "Help information"
  echo "Usage: script.sh [options]"
 }

 run test_help_function
 [[ "${status}" -eq 0 ]]
 [[ "${output}" == *"Help information"* ]]
 [[ "${output}" == *"Usage: script.sh [options]"* ]]
}

@test "Logging Pattern: Logger initialization functions should not require logging" {
 # Test that logger setup functions can exist without logging
 test_logger_init_function() {
  # These functions should not fail even if logging is not fully configured
  __logi "Logger initialized" || true
  __logd "Debug level enabled" || true
  echo "Function completed successfully"
 }

 run test_logger_init_function
 [[ "${status}" -eq 0 ]]
 [[ "${output}" == *"Function completed successfully"* ]]
}

@test "Logging Pattern: Wrapper functions should not require logging" {
 # Test that wrapper functions can exist without logging
 test_wrapper_function() {
  if [[ -f "/tmp/test_file" ]]; then
   source "/tmp/test_file"
   test_wrapper_function "$@"
  else
   echo "Wrapped function not available"
   return 1
  fi
 }

 run test_wrapper_function
 [[ "${status}" -eq 1 ]]
 [[ "${output}" == *"Wrapped function not available"* ]]
}
