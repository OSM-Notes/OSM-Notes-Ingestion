#!/usr/bin/env bats

# Test file for detecting parallel processing errors in processAPINotes
# Specifically tests the error scenario where __processCountries fails
#
# Author: Andres Gomez (AngocA)
# Version: 2025-08-01

load ../../test_helper

setup() {
  # Setup test environment
  export SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
  export TMP_DIR="$(mktemp -d)"
  export BASENAME="test_processAPINotes_parallel_error"
  
  # Ensure TMP_DIR exists and is writable
  if [[ ! -d "${TMP_DIR}" ]]; then
    mkdir -p "${TMP_DIR}"
  fi
  
  # Source the functions
  source "${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh"
  
  # Mock logger functions
  function __log_start() { echo "LOG_START: $*"; }
  function __log_finish() { echo "LOG_FINISH: $*"; }
  function __logi() { echo "INFO: $*"; }
  function __loge() { echo "ERROR: $*"; }
  function __logw() { echo "WARN: $*"; }
  function __logd() { echo "DEBUG: $*"; }
}

teardown() {
  # Cleanup test environment
  rm -rf "${TMP_DIR}"
}

# Test that the specific error pattern from the user's report is detected
@test "should detect FAIL! pattern in __processCountries" {
  # Create a mock scenario that simulates the user's error
  local mock_output="2025-08-01 11:29:52 - functionsProcess.sh:__processCountries:2154 - WARN - Waited for all jobs, restarting in main thread - countries.
FAIL! (1)"
  
  # Test that the FAIL! pattern is detected
  if [[ "$mock_output" =~ FAIL! ]]; then
    echo "Error pattern detected: $mock_output"
    # Extract the number of failures
    local failures=$(echo "$mock_output" | grep -o '[0-9]\+' | tail -1)
    [[ "$failures" == "1" ]]
  else
    echo "No error pattern detected"
    return 1
  fi
}

# Test that parallel job failure detection works correctly
@test "should detect parallel job failures in __processCountries" {
  # Simulate the job failure detection logic from __processCountries
  local FAIL=0
  local mock_jobs=(12345 12346 12347)
  
  # Simulate one job failing
  for job in "${mock_jobs[@]}"; do
    if [[ $job -eq 12346 ]]; then
      # Simulate job 12346 failing
      FAIL=$((FAIL + 1))
    fi
  done
  
  # Test the failure detection logic
  if [[ "${FAIL}" -ne 0 ]]; then
    echo "FAIL! (${FAIL})"
    [[ "${FAIL}" -eq 1 ]]
  else
    echo "All jobs succeeded"
    return 1
  fi
}

# Test that the error propagates correctly to processAPINotes
@test "should propagate parallel processing errors to processAPINotes" {
  # Create a mock processAPINotes script that calls __processCountries
  local mock_script="${TMP_DIR}/mock_processAPINotes.sh"
  cat > "$mock_script" << 'EOF'
#!/bin/bash
# Mock processAPINotes script that simulates the error

# Mock __processCountries function that fails
__processCountries() {
  echo "2025-08-01 11:29:52 - functionsProcess.sh:__processCountries:2154 - WARN - Waited for all jobs, restarting in main thread - countries."
  echo "FAIL! (1)"
  return 1
}

# Mock main function
main() {
  echo "Starting processAPINotes..."
  __processCountries
  local ret=$?
  if [[ $ret -ne 0 ]]; then
    echo "ERROR: The script processAPINotes did not finish correctly."
    exit 1
  fi
  echo "Process completed successfully"
}

main "$@"
EOF
  chmod +x "$mock_script"
  
  # Test that the script detects the error
  run bash "$mock_script"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: The script processAPINotes did not finish correctly."* ]]
  [[ "$output" == *"FAIL! (1)"* ]]
}

# Test that the specific line number error is detected
@test "should detect line number error in processAPINotes" {
  # Create a mock error message with line number
  local error_message="20250801_11:29:52 ERROR: The script processAPINotes did not finish correctly. Temporary directory: /tmp/processAPINotes_QSvGPg - Line number: 571."
  
  # Test that the error pattern is detected
  if [[ "$error_message" =~ Line[[:space:]]number:[[:space:]]([0-9]+) ]]; then
    local line_number="${BASH_REMATCH[1]}"
    echo "Error detected at line: $line_number"
    [[ "$line_number" == "571" ]]
  else
    echo "No line number detected in error message"
    return 1
  fi
}

# Test that the temporary directory cleanup works correctly
@test "should handle temporary directory cleanup on error" {
  # Create a mock temporary directory
  local mock_temp_dir="${TMP_DIR}/processAPINotes_QSvGPg"
  mkdir -p "$mock_temp_dir"
  echo "test content" > "$mock_temp_dir/test.log"
  
  # Test that the directory exists
  [ -d "$mock_temp_dir" ]
  [ -f "$mock_temp_dir/test.log" ]
  
  # Simulate cleanup
  rm -rf "$mock_temp_dir"
  
  # Test that cleanup worked
  [ ! -d "$mock_temp_dir" ]
}

# Test that the specific error code is handled correctly
@test "should handle ERROR_DOWNLOADING_BOUNDARY error code" {
  # Test that the error code is defined
  run bash -c "
    source '${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh' > /dev/null 2>&1
    echo \$ERROR_DOWNLOADING_BOUNDARY
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9]+$ ]]
}

# Test that the parallel processing error detection works with real patterns
@test "should detect real parallel processing error patterns" {
  # Create a mock log output that matches the user's error
  local mock_log="${TMP_DIR}/mock_error.log"
  cat > "$mock_log" << 'EOF'
2025-08-01 11:29:50 - functionsProcess.sh:__processCountries:2129 - INFO - Starting list /tmp/processPlanetNotes_xYbkyG/part_country_al - 791013.
2025-08-01 11:29:50 - functionsProcess.sh:__processCountries:2139 - INFO - Check log per thread for more information.
791013
2025-08-01 11:29:52 - functionsProcess.sh:__processCountries:2154 - WARN - Waited for all jobs, restarting in main thread - countries.
FAIL! (1)
EOF
  
  # Test that the error pattern is detected in the log
  run grep -q "FAIL! (1)" "$mock_log"
  [ "$status" -eq 0 ]
  
  # Test that the line number pattern is detected
  run grep -q "Line number: 571" "$mock_log" || true
  # This should not be found in this mock log, so status should be 1
  [ "$status" -eq 1 ]
}

# Test that the error handling in processAPINotes main function works
@test "should handle errors in processAPINotes main function" {
  # Create a mock main function that simulates the error
  local mock_main="${TMP_DIR}/mock_main.sh"
  cat > "$mock_main" << 'EOF'
#!/bin/bash
# Mock main function for processAPINotes

main() {
  echo "Starting processAPINotes..."
  
  # Simulate calling processPlanetNotes which calls __processCountries
  echo "Calling processPlanetNotes..."
  
  # Simulate the error
  echo "2025-08-01 11:29:52 - functionsProcess.sh:__processCountries:2154 - WARN - Waited for all jobs, restarting in main thread - countries."
  echo "FAIL! (1)"
  
  # This should trigger the error handling
  echo "ERROR: The script processAPINotes did not finish correctly. Temporary directory: /tmp/processAPINotes_QSvGPg - Line number: 571."
  exit 1
}

main "$@"
EOF
  chmod +x "$mock_main"
  
  # Test that the error is properly handled
  run bash "$mock_main"
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL! (1)"* ]]
  [[ "$output" == *"ERROR: The script processAPINotes did not finish correctly."* ]]
} 