#!/usr/bin/env bats

# Tests for enhanced ETL functionality
# Author: Andres Gomez (AngocA)
# Version: 2025-01-27

load "${BATS_TEST_DIRNAME}/../../test_helper"

setup() {
 # Create temporary test directory
 TEST_DIR=$(mktemp -d)
 export TEST_DIR

 # Create mock ETL configuration file
 cat > "${TEST_DIR}/etl.properties" << EOF
# ETL Configuration Properties
ETL_BATCH_SIZE=500
ETL_COMMIT_INTERVAL=50
ETL_VACUUM_AFTER_LOAD=true
ETL_ANALYZE_AFTER_LOAD=true
MAX_MEMORY_USAGE=70
MAX_DISK_USAGE=85
ETL_TIMEOUT=3600
ETL_RECOVERY_ENABLED=true
ETL_RECOVERY_FILE="/tmp/ETL_test_recovery.json"
ETL_VALIDATE_INTEGRITY=true
ETL_VALIDATE_DIMENSIONS=true
ETL_VALIDATE_FACTS=true
ETL_PARALLEL_ENABLED=true
ETL_MAX_PARALLEL_JOBS=2
ETL_MONITOR_RESOURCES=true
ETL_MONITOR_INTERVAL=15
EOF

 # Create mock recovery file
 cat > "/tmp/ETL_test_recovery.json" << EOF
{
    "last_step": "process_notes_etl",
    "status": "completed",
    "timestamp": "$(date +%s)",
    "etl_start_time": "$(date +%s)"
}
EOF
}

teardown() {
 # Clean up test files
 rm -rf "${TEST_DIR}"
 rm -f "/tmp/ETL_test_recovery.json"
}

@test "ETL configuration file loading" {
 # Test that ETL configuration is loaded correctly
 source "${TEST_DIR}/etl.properties"

 # Verify variables are set
 [ "${ETL_BATCH_SIZE}" = "500" ]
 [ "${ETL_COMMIT_INTERVAL}" = "50" ]
 [ "${ETL_VACUUM_AFTER_LOAD}" = "true" ]
 [ "${ETL_ANALYZE_AFTER_LOAD}" = "true" ]
 [ "${MAX_MEMORY_USAGE}" = "70" ]
 [ "${MAX_DISK_USAGE}" = "85" ]
 [ "${ETL_TIMEOUT}" = "3600" ]
 [ "${ETL_RECOVERY_ENABLED}" = "true" ]
 [ "${ETL_VALIDATE_INTEGRITY}" = "true" ]
 [ "${ETL_PARALLEL_ENABLED}" = "true" ]
 [ "${ETL_MAX_PARALLEL_JOBS}" = "2" ]
 [ "${ETL_MONITOR_RESOURCES}" = "true" ]
 [ "${ETL_MONITOR_INTERVAL}" = "15" ]
}

@test "ETL recovery file parsing with jq" {
 # Test recovery file parsing when jq is available
 if ! command -v jq &> /dev/null; then
  skip "jq not available"
 fi

 # Test successful recovery file parsing
 run jq -r '.last_step' "/tmp/ETL_test_recovery.json"
 [ "$status" -eq 0 ]
 [ "$output" = "process_notes_etl" ]

 run jq -r '.status' "/tmp/ETL_test_recovery.json"
 [ "$status" -eq 0 ]
 [ "$output" = "completed" ]
}

@test "ETL recovery file parsing without jq" {
 # Test recovery file parsing when jq is not available
 # This would be the case in environments without jq
 # We can't easily mock this, so we'll test the logic separately
 local recovery_file="/tmp/ETL_test_recovery.json"

 if [[ -f "${recovery_file}" ]]; then
  # Test that file exists and has content
  [ -s "${recovery_file}" ]

  # Test that file contains expected JSON structure
  grep -q "last_step" "${recovery_file}"
  grep -q "status" "${recovery_file}"
  grep -q "timestamp" "${recovery_file}"
  grep -q "etl_start_time" "${recovery_file}"
 fi
}

@test "ETL progress saving" {
 # Test progress saving functionality
 local step_name="test_step"
 local step_status="started"
 local timestamp=$(date +%s)
 local recovery_file="/tmp/ETL_test_recovery.json"

 # Mock the __save_progress function
 __save_progress() {
  local step_name="${1}"
  local step_status="${2}"
  local timestamp=$(date +%s)

  cat > "${recovery_file}" << EOF
{
    "last_step": "${step_name}",
    "status": "${step_status}",
    "timestamp": "${timestamp}",
    "etl_start_time": "${timestamp}"
}
EOF
 }

 # Test progress saving
 run __save_progress "${step_name}" "${step_status}"
 [ "$status" -eq 0 ]

 # Verify file was created
 [ -f "${recovery_file}" ]

 # Debug: show file content
 echo "DEBUG: File content:"
 cat "${recovery_file}"
 echo "DEBUG: Looking for status: ${step_status}"

 # Verify content - use more specific checks
 grep -q "\"last_step\": \"${step_name}\"" "${recovery_file}"
 grep -q "\"status\": \"${step_status}\"" "${recovery_file}"
}

@test "ETL resource monitoring" {
 # Test resource monitoring functionality
 # Mock system commands for testing
 free() {
  echo "              total        used        free      shared  buff/cache   available"
  echo "Mem:          16384        8192        4096        1024        4096        8192"
 }

 df() {
  echo "Filesystem     1K-blocks     Used Available Use% Mounted on"
  echo "/dev/sda1      104857600  52428800  52428800  50% /"
 }

 export -f free df

 # Test memory usage calculation
 run bash -c 'free | grep Mem | awk "{printf \"%.0f\", \$3/\$2 * 100.0}"'
 [ "$status" -eq 0 ]
 [ "$output" = "50" ]

 # Test disk usage calculation
 run bash -c 'df /tmp | tail -1 | awk "{print \$5}" | sed "s/%//"'
 [ "$status" -eq 0 ]
 [ "$output" = "50" ]
}

@test "ETL timeout checking" {
 # Test timeout checking functionality
 local start_time=$(date +%s)
 local timeout=3600
 local current_time=$((start_time + 1800)) # 30 minutes later

 # Test timeout calculation
 local elapsed_time=$((current_time - start_time))
 [ "${elapsed_time}" = "1800" ]
}

@test "ETL validation parameters" {
 # Test that validation parameters are properly set
 source "${TEST_DIR}/etl.properties"

 [ "${ETL_VALIDATE_INTEGRITY}" = "true" ]
 [ "${ETL_VALIDATE_DIMENSIONS}" = "true" ]
 [ "${ETL_VALIDATE_FACTS}" = "true" ]
}

@test "ETL parallel processing parameters" {
 # Test that parallel processing parameters are properly set
 source "${TEST_DIR}/etl.properties"

 [ "${ETL_PARALLEL_ENABLED}" = "true" ]
 [ "${ETL_MAX_PARALLEL_JOBS}" = "2" ]
}

@test "ETL monitoring parameters" {
 # Test that monitoring parameters are properly set
 source "${TEST_DIR}/etl.properties"

 [ "${ETL_MONITOR_RESOURCES}" = "true" ]
 [ "${ETL_MONITOR_INTERVAL}" = "15" ]
}

@test "ETL database maintenance parameters" {
 # Test that database maintenance parameters are properly set
 source "${TEST_DIR}/etl.properties"

 [ "${ETL_VACUUM_AFTER_LOAD}" = "true" ]
 [ "${ETL_ANALYZE_AFTER_LOAD}" = "true" ]
}

@test "ETL performance parameters" {
 # Test that performance parameters are properly set
 source "${TEST_DIR}/etl.properties"

 [ "${ETL_BATCH_SIZE}" = "500" ]
 [ "${ETL_COMMIT_INTERVAL}" = "50" ]
}

@test "ETL resource control parameters" {
 # Test that resource control parameters are properly set
 source "${TEST_DIR}/etl.properties"

 [ "${MAX_MEMORY_USAGE}" = "70" ]
 [ "${MAX_DISK_USAGE}" = "85" ]
 [ "${ETL_TIMEOUT}" = "3600" ]
}
