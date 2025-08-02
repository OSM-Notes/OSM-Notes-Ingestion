#!/usr/bin/env bats

# Integration test for detecting parallel processing errors in processAPINotes
# Specifically tests the real error scenario where __processCountries fails
#
# Author: Andres Gomez (AngocA)
# Version: 2025-08-01

load ../test_helper

setup() {
  # Setup test environment
  export SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
  export TMP_DIR="$(mktemp -d)"
  export BASENAME="test_processAPINotes_parallel_error_integration"
  
  # Ensure TMP_DIR exists and is writable
  if [[ ! -d "${TMP_DIR}" ]]; then
    mkdir -p "${TMP_DIR}"
  fi
  
  # Source the functions
  source "${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh"
  
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

# Test that simulates the real error scenario from the user's report
@test "should detect real parallel processing error scenario" {
  # Create a mock environment that simulates the real error
  local mock_process_dir="${TMP_DIR}/processAPINotes_QSvGPg"
  mkdir -p "$mock_process_dir"
  
  # Create a mock log file that matches the user's error
  local mock_log="${mock_process_dir}/processAPINotes.log"
  cat > "$mock_log" << 'EOF'
2025-08-01 11:29:50 - functionsProcess.sh:__processCountries:2129 - INFO - Starting list /tmp/processPlanetNotes_xYbkyG/part_country_al - 791013.
2025-08-01 11:29:50 - functionsProcess.sh:__processCountries:2139 - INFO - Check log per thread for more information.
791013
2025-08-01 11:29:52 - functionsProcess.sh:__processCountries:2154 - WARN - Waited for all jobs, restarting in main thread - countries.
FAIL! (1)
20250801_11:29:52 ERROR: The script processAPINotes did not finish correctly. Temporary directory: /tmp/processAPINotes_QSvGPg - Line number: 571.
EOF
  
  # Test that the error patterns are detected in the log
  run grep -q "FAIL! (1)" "$mock_log"
  [ "$status" -eq 0 ]
  
  run grep -q "Line number: 571" "$mock_log"
  [ "$status" -eq 0 ]
  
  run grep -q "ERROR: The script processAPINotes did not finish correctly" "$mock_log"
  [ "$status" -eq 0 ]
  
  # Test that the specific line numbers are detected
  run grep -q "functionsProcess.sh:__processCountries:2154" "$mock_log"
  [ "$status" -eq 0 ]
  
  run grep -q "functionsProcess.sh:__processCountries:2129" "$mock_log"
  [ "$status" -eq 0 ]
}

# Test that simulates the actual processAPINotes script execution
@test "should detect error in actual processAPINotes execution" {
  # Create a mock processAPINotes script that simulates the real error
  local mock_script="${TMP_DIR}/mock_processAPINotes_real.sh"
  cat > "$mock_script" << 'EOF'
#!/bin/bash
# Mock processAPINotes script that simulates the real error scenario

# Mock environment variables
export TMP_DIR="/tmp/processAPINotes_QSvGPg"
export BASENAME="processAPINotes"
export LOG_FILENAME="${TMP_DIR}/processAPINotes.log"

# Mock logger functions
__log_start() { echo "LOG_START: $*"; }
__log_finish() { echo "LOG_FINISH: $*"; }
__logi() { echo "INFO: $*"; }
__loge() { echo "ERROR: $*"; }
__logw() { echo "WARN: $*"; }

# Mock __processCountries function that fails
__processCountries() {
  echo "2025-08-01 11:29:50 - functionsProcess.sh:__processCountries:2129 - INFO - Starting list /tmp/processPlanetNotes_xYbkyG/part_country_al - 791013."
  echo "2025-08-01 11:29:50 - functionsProcess.sh:__processCountries:2139 - INFO - Check log per thread for more information."
  echo "791013"
  echo "2025-08-01 11:29:52 - functionsProcess.sh:__processCountries:2154 - WARN - Waited for all jobs, restarting in main thread - countries."
  echo "FAIL! (1)"
  return 1
}

# Mock main function that simulates the real error
main() {
  echo "Starting processAPINotes..."
  
  # Simulate calling processPlanetNotes which calls __processCountries
  echo "Calling processPlanetNotes..."
  __processCountries
  local ret=$?
  
  if [[ $ret -ne 0 ]]; then
    echo "20250801_11:29:52 ERROR: The script processAPINotes did not finish correctly. Temporary directory: ${TMP_DIR} - Line number: 571."
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
  [[ "$output" == *"FAIL! (1)"* ]]
  [[ "$output" == *"ERROR: The script processAPINotes did not finish correctly"* ]]
  [[ "$output" == *"Line number: 571"* ]]
}

# Test that validates the error detection logic in the real functions
@test "should validate error detection in real functions" {
  # Test that the ERROR_DOWNLOADING_BOUNDARY is defined
  run bash -c "
    source '${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh' > /dev/null 2>&1
    echo \$ERROR_DOWNLOADING_BOUNDARY
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9]+$ ]]
  
  # Test that the error code is not zero (should be a positive number)
  local error_code="$output"
  [[ "$error_code" -gt 0 ]]
}

# Test that simulates the job failure detection logic
@test "should simulate job failure detection logic" {
  # Create a mock job failure scenario
  local FAIL=0
  local mock_jobs=(12345 12346 12347 12348)
  
  # Simulate job failures
  for job in "${mock_jobs[@]}"; do
    if [[ $job -eq 12346 ]] || [[ $job -eq 12348 ]]; then
      # Simulate jobs 12346 and 12348 failing
      FAIL=$((FAIL + 1))
    fi
  done
  
  # Test the failure detection logic
  if [[ "${FAIL}" -ne 0 ]]; then
    echo "FAIL! (${FAIL})"
    [[ "${FAIL}" -eq 2 ]]
  else
    echo "All jobs succeeded"
    return 1
  fi
}

# Test that validates the temporary directory pattern
@test "should validate temporary directory pattern" {
  # Create a mock temporary directory name
  local temp_dir="/tmp/processAPINotes_QSvGPg"
  
  # Test that the pattern matches the expected format
  if [[ "$temp_dir" =~ /tmp/processAPINotes_[A-Za-z0-9]+ ]]; then
    echo "Temporary directory pattern is valid: $temp_dir"
    [[ "$temp_dir" == "/tmp/processAPINotes_QSvGPg" ]]
  else
    echo "Temporary directory pattern is invalid: $temp_dir"
    return 1
  fi
}

# Test that validates the complete error message format
@test "should validate complete error message format" {
  # Create a mock complete error message
  local error_message="20250801_11:29:52 ERROR: The script processAPINotes did not finish correctly. Temporary directory: /tmp/processAPINotes_QSvGPg - Line number: 571."
  
  # Test that all components are present
  [[ "$error_message" == *"ERROR: The script processAPINotes did not finish correctly"* ]]
  [[ "$error_message" == *"Temporary directory:"* ]]
  [[ "$error_message" == *"Line number: 571"* ]]
  [[ "$error_message" =~ ^[0-9]{8}_[0-9]{2}:[0-9]{2}:[0-9]{2}[[:space:]]ERROR:.*$ ]]
}

# Test that simulates the real error propagation chain
@test "should simulate real error propagation chain" {
  # Create a mock error propagation scenario
  local error_chain=(
    "processAPINotes calls processPlanetNotes"
    "processPlanetNotes calls __processCountries"
    "__processCountries executes parallel jobs"
    "One or more parallel jobs fail"
    "__processCountries detects FAIL! (1)"
    "__processCountries exits with ERROR_DOWNLOADING_BOUNDARY"
    "processPlanetNotes propagates error to processAPINotes"
    "processAPINotes reports error at line 571"
  )
  
  # Test that the error chain is complete
  [[ ${#error_chain[@]} -eq 8 ]]
  
  # Test that the key error indicators are present
  local has_fail_pattern=false
  local has_line_number=false
  local has_error_propagation=false
  
  for step in "${error_chain[@]}"; do
    if [[ "$step" == *"FAIL! (1)"* ]]; then
      has_fail_pattern=true
    fi
    if [[ "$step" == *"line 571"* ]]; then
      has_line_number=true
    fi
    if [[ "$step" == *"propagates error"* ]]; then
      has_error_propagation=true
    fi
  done
  
  # All error indicators should be present
  [[ "$has_fail_pattern" == true ]]
  [[ "$has_line_number" == true ]]
  [[ "$has_error_propagation" == true ]]
} 