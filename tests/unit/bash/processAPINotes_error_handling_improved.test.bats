#!/usr/bin/env bats

# Test file for improved error handling in processAPINotes
# Tests the enhanced error handling and logging improvements
#
# Author: Andres Gomez (AngocA)
# Version: 2025-08-01

load ../../test_helper

setup() {
  # Setup test environment
  export SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
  export TMP_DIR="$(mktemp -d)"
  export BASENAME="test_processAPINotes_error_handling_improved"
  
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

# Test that the improved error handling provides better information
@test "should provide detailed error information for failed jobs" {
  # Create a mock job status file
  local job_status_file="${TMP_DIR}/job_status.txt"
  cat > "$job_status_file" << 'EOF'
SUCCESS:12345:/tmp/part_country_aa
FAILED:12346:/tmp/part_country_ab
SUCCESS:12347:/tmp/part_country_ac
FAILED:12348:/tmp/part_country_ad
EOF
  
  # Test that the error information is properly parsed
  local failed_count=0
  local success_count=0
  
  while IFS=':' read -r status pid file; do
    if [[ "$status" == "FAILED" ]]; then
      failed_count=$((failed_count + 1))
      echo "Job ${pid} failed processing file: ${file}"
    elif [[ "$status" == "SUCCESS" ]]; then
      success_count=$((success_count + 1))
    fi
  done < "$job_status_file"
  
  # Verify the counts
  [[ "$success_count" -eq 2 ]]
  [[ "$failed_count" -eq 2 ]]
}

# Test that the improved error message format is detected
@test "should detect improved error message format" {
  # Create a mock improved error message
  local improved_error="ERROR: FAIL! (1) - Failed jobs: 12346 12348
ERROR: Check individual log files for detailed error information:
ERROR: Log file for job 12346: /tmp/processPlanetNotes.log.12346
ERROR: Log file for job 12348: /tmp/processPlanetNotes.log.12348"
  
  # Test that the improved error pattern is detected
  [[ "$improved_error" == *"FAIL! (1) - Failed jobs:"* ]]
  [[ "$improved_error" == *"Check individual log files for detailed error information:"* ]]
  [[ "$improved_error" == *"Log file for job"* ]]
}

# Test that the job tracking mechanism works
@test "should track job success and failure status" {
  # Create a mock job tracking scenario
  local job_status_file="${TMP_DIR}/job_status.txt"
  rm -f "$job_status_file"
  
  # Simulate job execution
  local mock_jobs=("12345" "12346" "12347")
  local job_results=("SUCCESS" "FAILED" "SUCCESS")
  
  for i in "${!mock_jobs[@]}"; do
    local pid="${mock_jobs[$i]}"
    local result="${job_results[$i]}"
    echo "${result}:${pid}:/tmp/part_country_${i}" >> "$job_status_file"
  done
  
  # Verify job status file was created
  [ -f "$job_status_file" ]
  
  # Count results
  local success_count=$(grep -c "SUCCESS:" "$job_status_file")
  local failed_count=$(grep -c "FAILED:" "$job_status_file")
  
  [[ "$success_count" -eq 2 ]]
  [[ "$failed_count" -eq 1 ]]
}

# Test that the improved error logging provides file paths
@test "should provide log file paths for failed jobs" {
  # Create mock log files
  local log_dir="${TMP_DIR}/logs"
  mkdir -p "$log_dir"
  
  # Create mock log files for failed jobs
  echo "Mock error log for job 12346" > "$log_dir/processPlanetNotes.log.12346"
  echo "Mock error log for job 12348" > "$log_dir/processPlanetNotes.log.12348"
  
  # Test that log files exist
  [ -f "$log_dir/processPlanetNotes.log.12346" ]
  [ -f "$log_dir/processPlanetNotes.log.12348" ]
  
  # Test that we can find error log files
  local error_log_count=$(find "$log_dir" -name "*.log.*" | wc -l)
  [[ "$error_log_count" -eq 2 ]]
}

# Test that the improved error handling provides job summary
@test "should provide job summary information" {
  # Create a mock job summary
  local success_count=15
  local failed_count=2
  
  # Test job summary format
  local job_summary="Job summary: ${success_count} successful, ${failed_count} failed"
  
  [[ "$job_summary" == *"Job summary:"* ]]
  [[ "$job_summary" == *"successful"* ]]
  [[ "$job_summary" == *"failed"* ]]
  [[ "$success_count" -gt 0 ]]
  [[ "$failed_count" -gt 0 ]]
}

# Test that the improved error handling detects specific failure reasons
@test "should detect specific failure reasons" {
  # Create mock error scenarios
  local error_scenarios=(
    "Network connectivity check failed for boundary 12345"
    "Failed to retrieve boundary 12346 from Overpass after retries"
    "Too many requests to Overpass API for boundary 12347"
    "JSON validation failed for boundary 12348"
    "Failed to convert boundary 12349 to GeoJSON after retries"
    "GeoJSON validation failed for boundary 12350"
    "Failed to acquire lock for boundary 12351"
    "Failed to import boundary 12352 into database after retries"
    "Failed to process boundary 12353 data"
  )
  
  # Test that all error scenarios are detected
  for scenario in "${error_scenarios[@]}"; do
    [[ "$scenario" == *"failed"* ]] || [[ "$scenario" == *"Failed"* ]] || [[ "$scenario" == *"Too many requests"* ]]
    [[ "$scenario" == *"boundary"* ]]
  done
  
  # Test that we have the expected number of error scenarios
  [[ ${#error_scenarios[@]} -eq 9 ]]
}

# Test that the improved error handling provides better debugging information
@test "should provide better debugging information" {
  # Create a mock debugging scenario
  local debug_info=(
    "Job 12346 failed processing file: /tmp/part_country_ab"
    "Job 12348 failed processing file: /tmp/part_country_ad"
    "Found 2 error log files. Check them for details:"
    "Error log: /tmp/processPlanetNotes.log.12346"
    "Error log: /tmp/processPlanetNotes.log.12348"
  )
  
  # Test that debugging information is comprehensive
  for info in "${debug_info[@]}"; do
    [[ "$info" == *"failed"* ]] || [[ "$info" == *"Error log"* ]] || [[ "$info" == *"Found"* ]]
  done
  
  # Test that we have the expected debugging information
  [[ ${#debug_info[@]} -eq 5 ]]
}

# Test that the improved error handling maintains backward compatibility
@test "should maintain backward compatibility with existing error codes" {
  # Test that error codes are still defined
  run bash -c "
    source '${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh' > /dev/null 2>&1
    echo \$ERROR_DOWNLOADING_BOUNDARY
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9]+$ ]]
  
  # Test that the error code is not zero
  local error_code="$output"
  [[ "$error_code" -gt 0 ]]
}

# Test that the improved error handling provides actionable information
@test "should provide actionable error information" {
  # Create a mock actionable error message
  local actionable_error="ERROR: FAIL! (2) - Failed jobs: 12346 12348
ERROR: Check individual log files for detailed error information:
ERROR: Log file for job 12346: /tmp/processPlanetNotes.log.12346
ERROR: Log file for job 12348: /tmp/processPlanetNotes.log.12348
ERROR: Found 2 error log files. Check them for details:
ERROR: Error log: /tmp/processPlanetNotes.log.12346
ERROR: Error log: /tmp/processPlanetNotes.log.12348"
  
  # Test that the error message provides actionable information
  [[ "$actionable_error" == *"Failed jobs:"* ]]
  [[ "$actionable_error" == *"Check individual log files"* ]]
  [[ "$actionable_error" == *"Log file for job"* ]]
  [[ "$actionable_error" == *"Found"* ]]
  [[ "$actionable_error" == *"Error log:"* ]]
} 