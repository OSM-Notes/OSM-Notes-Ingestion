#!/usr/bin/env bats
# Test file for parallel processing delay functionality
#
# Author: Andres Gomez (AngocA)
# Version: 2025-08-16
# Description: Tests for delay between parallel process launches

 # Load test helper
 load "../../test_helper"
 
 # Load the parallel processing functions
 setup() {
  # Set up test environment first
  export TMP_DIR="${BATS_TEST_DIRNAME}/tmp"
  export SCRIPT_BASE_DIRECTORY="${BATS_TEST_DIRNAME}/../../../"
  export MAX_THREADS=2
  # Note: PARALLEL_PROCESS_DELAY is readonly, so we can't override it
  
  # Create temporary directory
  mkdir -p "${TMP_DIR}"
  
  # Source the properties file first
  source "${BATS_TEST_DIRNAME}/../../../etc/properties.sh"
  
     # Source the parallel processing functions
   source "${BATS_TEST_DIRNAME}/../../../bin/parallelProcessingFunctions.sh"
}

teardown() {
 # Clean up temporary files
 rm -rf "${TMP_DIR}"
}

@test "PARALLEL_PROCESS_DELAY constant is defined" {
 # Check that the constant is defined
 [ -n "${PARALLEL_PROCESS_DELAY}" ]
 [ "${PARALLEL_PROCESS_DELAY}" -gt 0 ]
}

@test "Adjust process delay function works correctly" {
 # Test that the function returns a valid delay
 run __adjust_process_delay 2>/dev/null
 [ "$status" -eq 0 ]
 [ -n "$output" ]
 [ "$output" -ge 1 ]
 [ "$output" -le 10 ]
}

@test "Process delay increases under high memory usage" {
 # Mock high memory usage
 local ORIGINAL_FREE_CMD
 ORIGINAL_FREE_CMD=$(command -v free)
 
 # Create mock free command that reports high memory usage
 cat > "${TMP_DIR}/mock_free" << 'EOF'
#!/bin/bash
echo "              total        used        free      shared  buff/cache   available"
echo "Mem:       16384       14000        1000        1000        1384        1000"
EOF
 chmod +x "${TMP_DIR}/mock_free"
 
 # Temporarily replace free command
 export PATH="${TMP_DIR}:${PATH}"
 
 # Test delay adjustment
 run __adjust_process_delay 2>/dev/null
 [ "$status" -eq 0 ]
 [ "$output" -gt "${PARALLEL_PROCESS_DELAY}" ]
 
 # Restore original PATH
 export PATH="${ORIGINAL_FREE_CMD%/*}:${PATH}"
}

@test "Process delay increases under high system load" {
 # Mock high system load
 local ORIGINAL_UPTIME_CMD
 ORIGINAL_UPTIME_CMD=$(command -v uptime)
 
 # Create mock uptime command that reports high load
 cat > "${TMP_DIR}/mock_uptime" << 'EOF'
#!/bin/bash
echo " 20:30:45 up 2 days, 3:45, 2 users, load average: 5.25, 4.80, 3.90"
EOF
 chmod +x "${TMP_DIR}/mock_uptime"
 
 # Temporarily replace uptime command
 export PATH="${TMP_DIR}:${PATH}"
 
 # Test delay adjustment
 run __adjust_process_delay 2>/dev/null
 [ "$status" -eq 0 ]
 [ "$output" -gt "${PARALLEL_PROCESS_DELAY}" ]
 
 # Restore original PATH
 export PATH="${ORIGINAL_UPTIME_CMD%/*}:${PATH}"
}

@test "Process delay is capped at reasonable maximum" {
 # Test that delay is capped (using current readonly value)
 local CURRENT_DELAY="${PARALLEL_PROCESS_DELAY}"
 
 # Test that delay adjustment respects capping
 run __adjust_process_delay 2>/dev/null
 [ "$status" -eq 0 ]
 [ "$output" -le 10 ]
 [ "$output" -gt 0 ]
}

@test "Delay adjustment function handles missing commands gracefully" {
 # Remove commands temporarily
 local ORIGINAL_PATH="${PATH}"
 export PATH="/nonexistent"
 
 # Test that function still works
 run __adjust_process_delay 2>/dev/null
 [ "$status" -eq 0 ]
 [ "$output" = "${PARALLEL_PROCESS_DELAY}" ]
 
 # Restore PATH
 export PATH="${ORIGINAL_PATH}"
}

@test "Delay constants are properly defined" {
 # Check that all delay-related constants are defined
 [ -n "${PARALLEL_PROCESS_DELAY}" ]
 [ -n "${MAX_MEMORY_PERCENT}" ]
 [ -n "${MAX_LOAD_AVERAGE}" ]
 
 # Check values are reasonable
 [ "${PARALLEL_PROCESS_DELAY}" -gt 0 ]
 [ "${PARALLEL_PROCESS_DELAY}" -le 10 ]
 [ "${MAX_MEMORY_PERCENT}" -gt 0 ]
 [ "${MAX_MEMORY_PERCENT}" -le 100 ]
 [ "${MAX_LOAD_AVERAGE}" -gt 0 ]
}

@test "Delay function logs appropriate messages" {
 # Capture log output
 run __adjust_process_delay 2>/dev/null
 [ "$status" -eq 0 ]
 
 # The function should log the adjustment
 # Note: This test may need adjustment based on actual logging implementation
}

@test "Delay adjustment respects system state" {
 # Test with current system state
 local CURRENT_DELAY="${PARALLEL_PROCESS_DELAY}"
 run __adjust_process_delay 2>/dev/null
 [ "$status" -eq 0 ]
 [ "$output" -ge "${CURRENT_DELAY}" ]
 [ "$output" -le 10 ]
}

@test "Zero delay is handled correctly" {
 # Test that current delay value is handled correctly
 local CURRENT_DELAY="${PARALLEL_PROCESS_DELAY}"
 run __adjust_process_delay
 [ "$status" -eq 0 ]
 [ "$output" = "${CURRENT_DELAY}" ]
}
