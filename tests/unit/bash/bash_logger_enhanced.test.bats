#!/usr/bin/env bats

# Unit tests for Enhanced Bash Logger 
# Test file: bash_logger_enhanced.test.bats
# Author: Andres Gomez (AngocA)
# Version: 2025-08-13

load "../../test_helper.bash"

setup() {
  # Source the enhanced logger
  source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/bash_logger.sh"
  
  # Create temporary log file for tests
  TEST_LOG_FILE="/tmp/logger_test_$$.log"
  
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

@test "Enhanced Logger: Basic logging functionality works" {
  run __logi "Test message"
  [ "$status" -eq 0 ]
  [[ "$output" == *"INFO"* ]]
  [[ "$output" == *"Test message"* ]]
}

@test "Enhanced Logger: Log level validation works" {
  # Valid levels should work
  __set_log_level "DEBUG"
  [[ "$__log_level" == "DEBUG" ]]
  
  __set_log_level "TRACE"
  [[ "$__log_level" == "TRACE" ]]
  
  __set_log_level "ERROR"
  [[ "$__log_level" == "ERROR" ]]
  
  # Invalid level should default to INFO
  # Test invalid level - should default to INFO
  
  __set_log_level "INVALID" >&1 2>/dev/null || true
  [[ "$__log_level" == "INFO" ]]
}

@test "Enhanced Logger: Log level filtering works correctly" {
  __set_log_level "WARN"
  
  # Messages below WARN should not appear
  run __logi "Info message"
  [[ "$output" == "" ]]
  
  run __logd "Debug message"
  [[ "$output" == "" ]]
  
  # WARN and above should appear
  run __logw "Warning message"
  [[ "$output" == *"WARN"* ]]
  [[ "$output" == *"Warning message"* ]]
  
  run __loge "Error message"
  [[ "$output" == *"ERROR"* ]]
}

@test "Enhanced Logger: File logging works" {
  __set_log_file "$TEST_LOG_FILE"
  
  __logi "Message to file"
  __logw "Warning to file" 
  __loge "Error to file"
  
  [[ -f "$TEST_LOG_FILE" ]]
  
  local content
  content=$(cat "$TEST_LOG_FILE")
  [[ "$content" == *"INFO"* ]]
  [[ "$content" == *"Message to file"* ]]
  [[ "$content" == *"WARN"* ]]
  [[ "$content" == *"Warning to file"* ]]
  [[ "$content" == *"ERROR"* ]]
  [[ "$content" == *"Error to file"* ]]
}

@test "Enhanced Logger: Function timing works" {
  timed_test_function() {
    __log_start
    sleep 0.1
    __log_finish
  }
  
  run timed_test_function
  [[ "$output" == *"STARTED TIMED_TEST_FUNCTION"* ]]
  [[ "$output" == *"FINISHED TIMED_TEST_FUNCTION"* ]] 
  [[ "$output" == *"Took:"* ]]
}

@test "Enhanced Logger: All log level aliases work" {
  __set_log_level "TRACE"
  
  run __logt "Trace test"
  [[ "$output" == *"TRACE"* ]]
  
  run __logd "Debug test"
  [[ "$output" == *"DEBUG"* ]]
  
  run __logi "Info test"
  [[ "$output" == *"INFO"* ]]
  
  run __logw "Warn test"
  [[ "$output" == *"WARN"* ]]
  
  run __loge "Error test"
  [[ "$output" == *"ERROR"* ]]
  
  run __logf "Fatal test"
  [[ "$output" == *"FATAL"* ]]
}

@test "Enhanced Logger: Multiple parameters work" {
  run __logi "Message with" "multiple" "parameters"
  [[ "$output" == *"Message with multiple parameters"* ]]
}

@test "Enhanced Logger: Environment variable LOG_LEVEL is respected" {
  # Test with LOG_LEVEL set before sourcing
  result=$(LOG_LEVEL=DEBUG bash -c "source ${SCRIPT_BASE_DIRECTORY}/lib/osm-common/bash_logger.sh && echo \$__log_level")
  [[ "$result" == *"DEBUG"* ]]
}

@test "Enhanced Logger: Invalid log file returns error" {
  run __set_log_file "/nonexistent/impossible/path/test.log"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not possible to create"* ]]
}

@test "Enhanced Logger: Log messages include proper format" {
  run __logi "Format test"
  # Should include: timestamp, location info, level, message
  [[ "$output" == *"$(date '+%Y-%m-%d')"* ]]
  [[ "$output" == *"INFO"* ]]
  [[ "$output" == *"Format test"* ]]
  [[ "$output" == *":"* ]]  # Should contain location separators
}

@test "Enhanced Logger: Backwards compatibility maintained" {
  # Test that old function names still work
  run __log "Default log test"
  [[ "$output" == *"Default log test"* ]]
}

@test "Enhanced Logger: Error and Fatal logs go to stderr" {
  # Error should go to stderr
  result=$(bash -c "source ${SCRIPT_BASE_DIRECTORY}/lib/osm-common/bash_logger.sh && __loge 'Error test' 2>&1 1>/dev/null")
  [[ "$result" == *"ERROR"* ]]
  [[ "$result" == *"Error test"* ]]
  
  # Fatal should go to stderr  
  result=$(bash -c "source ${SCRIPT_BASE_DIRECTORY}/lib/osm-common/bash_logger.sh && __logf 'Fatal test' 2>&1 1>/dev/null")
  [[ "$result" == *"FATAL"* ]]
  [[ "$result" == *"Fatal test"* ]]
}

@test "Enhanced Logger: Integration with OSM Notes scripts" {
  # Test that logger works when sourced by actual project scripts
  run bash -c "source ${SCRIPT_BASE_DIRECTORY}/lib/osm-common/commonFunctions.sh 2>/dev/null && echo 'Integration test passed'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Integration test passed"* ]]
}

@test "Enhanced Logger: Date format is included in all messages" {
  local current_date
  current_date=$(date '+%Y-%m-%d')
  
  run __logi "Date test message"
  [[ "$output" == *"$current_date"* ]]
  
  run __logw "Date test warning"
  [[ "$output" == *"$current_date"* ]]
  
  run __loge "Date test error"
  [[ "$output" == *"$current_date"* ]]
}

@test "Enhanced Logger: Log start and finish include empty lines" {
  test_function_timing() {
    __log_start
    __log_finish
  }
  
  run test_function_timing
  # Check that output contains the expected format with empty lines
  [[ "$output" == *"STARTED TEST_FUNCTION_TIMING"* ]]
  [[ "$output" == *"FINISHED TEST_FUNCTION_TIMING"* ]]
  # The timing output should show time taken
  [[ "$output" == *"Took: 0h:0m:0s"* ]]
}

@test "Enhanced Logger: Original __log function works without level" {
  run __log "Message without explicit level"
  # Should show timestamp and location but no explicit level like INFO/DEBUG
  [[ "$output" == *"Message without explicit level"* ]]
  [[ "$output" == *"$(date '+%Y-%m-%d')"* ]]
  # Should NOT contain "INFO -" or other level markers
  [[ "$output" != *"INFO -"* ]]
  [[ "$output" != *"DEBUG -"* ]]
}

@test "Enhanced Logger: Call stack is shown for TRACE level" {
  __set_log_level "TRACE"
  
  outer_function() {
    inner_function
  }
  
  inner_function() {
    __logt "Trace message with stack"
  }
  
  run outer_function
  [[ "$output" == *"TRACE"* ]]
  [[ "$output" == *"Trace message with stack"* ]]
  [[ "$output" == *"Execution call stack:"* ]]
}

@test "Enhanced Logger: File descriptor syntax works correctly" {
  __set_log_file "$TEST_LOG_FILE"
  
  # Test that the log file descriptor is set (should be a number)
  [[ -n "$__log_fd" ]]
  [[ "$__log_fd" =~ ^[0-9]+$ ]]
  
  # Test that messages are written to file using file descriptor syntax
  __logi "Test file descriptor message"
  
  [[ -f "$TEST_LOG_FILE" ]]
  local content
  content=$(cat "$TEST_LOG_FILE")
  [[ "$content" == *"Test file descriptor message"* ]]
  [[ "$content" == *"INFO"* ]]
}
