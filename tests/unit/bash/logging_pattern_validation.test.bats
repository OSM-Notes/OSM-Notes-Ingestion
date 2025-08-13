#!/usr/bin/env bats

# Unit tests for Logging Pattern Validation
# Test file: logging_pattern_validation.test.bats
# Author: Andres Gomez (AngocA)
# Version: 2025-08-13

load "../../test_helper.bash"

setup() {
  # Source the enhanced logger
  source "${SCRIPT_BASE_DIRECTORY}/lib/bash_logger.sh"
  
  # Create temporary log file for tests
  TEST_LOG_FILE="/tmp/logging_pattern_test_$$.log"
  
  # Reset logger state
  __log_fd=""
  __set_log_level "INFO"
}

teardown() {
  # Clean up temporary files
  if [[ -f "$TEST_LOG_FILE" ]]; then
    rm -f "$TEST_LOG_FILE"
  fi
}

@test "Logging Pattern: Functions should have __log_start at beginning" {
  # Test a function that follows the pattern correctly
  test_function_with_log_start() {
    __log_start
    __logi "Function body"
    __log_finish
  }
  
  run test_function_with_log_start
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"STARTED TEST_FUNCTION_WITH_LOG_START"* ]]
  [[ "$output" == *"FINISHED TEST_FUNCTION_WITH_LOG_START"* ]]
}

@test "Logging Pattern: Functions should have __log_finish before each return" {
  # Test a function with multiple returns
  test_function_with_multiple_returns() {
    __log_start
    local condition="${1:-false}"
    
    if [[ "$condition" == "true" ]]; then
      __logi "Early return condition met"
      __log_finish
      return 0
    fi
    
    __logi "Normal execution path"
    __log_finish
    return 1
  }
  
  # Test early return
  run test_function_with_multiple_returns "true"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"STARTED TEST_FUNCTION_WITH_MULTIPLE_RETURNS"* ]]
  [[ "$output" == *"FINISHED TEST_FUNCTION_WITH_MULTIPLE_RETURNS"* ]]
  
  # Test normal return
  run test_function_with_multiple_returns "false"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"STARTED TEST_FUNCTION_WITH_MULTIPLE_RETURNS"* ]]
  [[ "$output" == *"FINISHED TEST_FUNCTION_WITH_MULTIPLE_RETURNS"* ]]
}

@test "Logging Pattern: Functions should have __log_finish at the end" {
  # Test a function that follows the pattern correctly
  test_function_with_log_finish() {
    __log_start
    __logi "Function body"
    __log_finish
  }
  
  run test_function_with_log_finish
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"FINISHED TEST_FUNCTION_WITH_LOG_FINISH"* ]]
}

@test "Logging Pattern: Functions without __log_start should be detected" {
  # Test a function missing __log_start
  test_function_missing_log_start() {
    __logi "Function body without start"
    __log_finish
  }
  
  run test_function_missing_log_start
  [[ "$status" -eq 0 ]]
  # Should not have STARTED message
  [[ "$output" != *"STARTED TEST_FUNCTION_MISSING_LOG_START"* ]]
  # Should still have FINISHED message
  [[ "$output" == *"FINISHED TEST_FUNCTION_MISSING_LOG_START"* ]]
}

@test "Logging Pattern: Functions without __log_finish should be detected" {
  # Test a function missing __log_finish
  test_function_missing_log_finish() {
    __log_start
    __logi "Function body without finish"
  }
  
  run test_function_missing_log_finish
  [[ "$status" -eq 0 ]]
  # Should have STARTED message
  [[ "$output" == *"STARTED TEST_FUNCTION_MISSING_LOG_FINISH"* ]]
  # Should not have FINISHED message
  [[ "$output" != *"FINISHED TEST_FUNCTION_MISSING_LOG_FINISH"* ]]
}

@test "Logging Pattern: Functions with exit should have __log_finish before exit" {
  # Test a function that uses exit
  test_function_with_exit() {
    __log_start
    local condition="${1:-false}"
    
    if [[ "$condition" == "true" ]]; then
      __loge "Critical error, exiting"
      __log_finish
      exit 1
    fi
    
    __logi "Normal execution"
    __log_finish
  }
  
  # Test normal execution (should not exit)
  run test_function_with_exit "false"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"STARTED TEST_FUNCTION_WITH_EXIT"* ]]
  [[ "$output" == *"FINISHED TEST_FUNCTION_WITH_EXIT"* ]]
  
  # Test exit condition (should exit with status 1)
  run test_function_with_exit "true"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"STARTED TEST_FUNCTION_WITH_EXIT"* ]]
  [[ "$output" == *"FINISHED TEST_FUNCTION_WITH_EXIT"* ]]
}

@test "Logging Pattern: Functions with error handling should follow pattern" {
  # Test a function with error handling
  test_function_with_error_handling() {
    __log_start
    local input="${1:-}"
    
    if [[ -z "$input" ]]; then
      __loge "Input is required"
      __log_finish
      return 1
    fi
    
    if [[ "$input" == "error" ]]; then
      __loge "Simulated error"
      __log_finish
      return 2
    fi
    
    __logi "Processing input: $input"
    __log_finish
    return 0
  }
  
  # Test missing input
  run test_function_with_error_handling
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"STARTED TEST_FUNCTION_WITH_ERROR_HANDLING"* ]]
  [[ "$output" == *"FINISHED TEST_FUNCTION_WITH_ERROR_HANDLING"* ]]
  
  # Test error condition
  run test_function_with_error_handling "error"
  [[ "$status" -eq 2 ]]
  [[ "$output" == *"STARTED TEST_FUNCTION_WITH_ERROR_HANDLING"* ]]
  [[ "$output" == *"FINISHED TEST_FUNCTION_WITH_ERROR_HANDLING"* ]]
  
  # Test success
  run test_function_with_error_handling "success"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"STARTED TEST_FUNCTION_WITH_ERROR_HANDLING"* ]]
  [[ "$output" == *"FINISHED TEST_FUNCTION_WITH_ERROR_HANDLING"* ]]
}

@test "Logging Pattern: Functions should handle nested function calls correctly" {
  # Test nested function calls
  inner_function() {
    __log_start
    __logi "Inner function executing"
    __log_finish
  }
  
  outer_function() {
    __log_start
    __logi "Outer function calling inner"
    inner_function
    __logi "Outer function continuing"
    __log_finish
  }
  
  run outer_function
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"STARTED OUTER_FUNCTION"* ]]
  [[ "$output" == *"STARTED INNER_FUNCTION"* ]]
  [[ "$output" == *"FINISHED INNER_FUNCTION"* ]]
  [[ "$output" == *"FINISHED OUTER_FUNCTION"* ]]
}

@test "Logging Pattern: Functions should handle parallel execution correctly" {
  # Test function that could be called in parallel
  parallel_safe_function() {
    __log_start
    local job_id="${1:-$$}"
    __logi "Executing parallel job: $job_id"
    
    # Simulate some work
    sleep 0.01
    
    __log_finish
  }
  
  # Test single execution
  run parallel_safe_function "test1"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"STARTED PARALLEL_SAFE_FUNCTION"* ]]
  [[ "$output" == *"FINISHED PARALLEL_SAFE_FUNCTION"* ]]
}

@test "Logging Pattern: Functions should handle cleanup scenarios" {
  # Test function with cleanup
  test_function_with_cleanup() {
    __log_start
    local temp_file="/tmp/test_cleanup_$$.tmp"
    
    # Create temporary file
    echo "test" > "$temp_file"
    
    # Check if cleanup is needed
    if [[ ! -f "$temp_file" ]]; then
      __loge "Failed to create temp file"
      __log_finish
      return 1
    fi
    
    # Cleanup
    rm -f "$temp_file"
    
    if [[ -f "$temp_file" ]]; then
      __loge "Failed to cleanup temp file"
      __log_finish
      return 1
    fi
    
    __logi "Cleanup completed successfully"
    __log_finish
    return 0
  }
  
  run test_function_with_cleanup
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"STARTED TEST_FUNCTION_WITH_CLEANUP"* ]]
  [[ "$output" == *"FINISHED TEST_FUNCTION_WITH_CLEANUP"* ]]
}
