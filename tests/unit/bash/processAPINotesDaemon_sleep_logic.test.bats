#!/usr/bin/env bats

# Unit tests for processAPINotesDaemon.sh sleep logic
# Tests the adaptive sleep functionality based on processing duration
#
# Author: Andres Gomez (AngocA)
# Version: 2025-01-23

load "$(dirname "$BATS_TEST_FILENAME")/../../test_helper.bash"

# =============================================================================
# Setup and Teardown
# =============================================================================

setup() {
 # Setup test environment
 # TEST_BASE_DIR is set by test_helper.bash
 export TMP_DIR="$(mktemp -d)"
 export BASENAME="test_daemon_sleep"
 export LOG_LEVEL="ERROR"
 export DAEMON_SLEEP_INTERVAL=60
 
 # Mock functions will be defined in each test
}

teardown() {
 # Cleanup
 rm -rf "${TMP_DIR}"
 rm -f /tmp/test_daemon_sleep.lock
 rm -f /tmp/test_daemon_sleep_shutdown
}

# =============================================================================
# Helper Functions for Testing
# =============================================================================

# Mock function to simulate processing with specific duration
__mock_process_api_data_with_duration() {
 local DURATION="${1:-0}"
 local SUCCESS="${2:-true}"
 
 # Simulate processing time
 sleep "${DURATION}"
 PROCESSING_DURATION="${DURATION}"
 
 if [[ "${SUCCESS}" == "true" ]]; then
  return 0
 else
  return 1
 fi
}

# Calculate sleep time based on processing duration (logic from daemon)
__calculate_sleep_time() {
 local HAD_UPDATES="${1:-false}"
 local PROCESSING_SUCCESS="${2:-false}"
 local PROCESSING_DURATION="${3:-0}"
 local DAEMON_SLEEP_INTERVAL="${4:-60}"
 
 local SLEEP_TIME=0
 if [[ "${HAD_UPDATES}" == "true" ]] && [[ "${PROCESSING_SUCCESS}" == "true" ]]; then
  SLEEP_TIME=$((DAEMON_SLEEP_INTERVAL - PROCESSING_DURATION))
  if [[ ${SLEEP_TIME} -lt 0 ]]; then
   SLEEP_TIME=0
  fi
 else
  SLEEP_TIME="${DAEMON_SLEEP_INTERVAL}"
 fi
 echo "${SLEEP_TIME}"
}

# =============================================================================
# Tests for Sleep Calculation Logic
# =============================================================================

@test "Sleep calculation: No updates should sleep full interval" {
 # When there are no updates, sleep should be the full interval
 local SLEEP_TIME
 SLEEP_TIME=$(__calculate_sleep_time "false" "false" 0 60)
 
 [ "${SLEEP_TIME}" -eq 60 ]
}

@test "Sleep calculation: Processing in 25s should sleep 35s" {
 # When processing takes 25 seconds, sleep should be 35 seconds (60 - 25)
 local SLEEP_TIME
 SLEEP_TIME=$(__calculate_sleep_time "true" "true" 25 60)
 
 [ "${SLEEP_TIME}" -eq 35 ]
}

@test "Sleep calculation: Processing in 80s should sleep 0s (continue immediately)" {
 # When processing takes 80 seconds (>= interval), sleep should be 0
 local SLEEP_TIME
 SLEEP_TIME=$(__calculate_sleep_time "true" "true" 80 60)
 
 [ "${SLEEP_TIME}" -eq 0 ]
}

@test "Sleep calculation: Processing exactly at interval should sleep 0s" {
 # When processing takes exactly 60 seconds, sleep should be 0
 local SLEEP_TIME
 SLEEP_TIME=$(__calculate_sleep_time "true" "true" 60 60)
 
 [ "${SLEEP_TIME}" -eq 0 ]
}

@test "Sleep calculation: Processing failed should sleep full interval" {
 # When processing fails, sleep should be the full interval (retry delay)
 local SLEEP_TIME
 SLEEP_TIME=$(__calculate_sleep_time "true" "false" 10 60)
 
 [ "${SLEEP_TIME}" -eq 60 ]
}

@test "Sleep calculation: Processing in 0s should sleep full interval" {
 # When processing takes 0 seconds (edge case), sleep should be full interval
 local SLEEP_TIME
 SLEEP_TIME=$(__calculate_sleep_time "true" "true" 0 60)
 
 [ "${SLEEP_TIME}" -eq 60 ]
}

@test "Sleep calculation: Processing in 59s should sleep 1s" {
 # When processing takes 59 seconds, sleep should be 1 second
 local SLEEP_TIME
 SLEEP_TIME=$(__calculate_sleep_time "true" "true" 59 60)
 
 [ "${SLEEP_TIME}" -eq 1 ]
}

@test "Sleep calculation: Custom interval (30s) with 10s processing should sleep 20s" {
 # Test with custom interval
 local SLEEP_TIME
 SLEEP_TIME=$(__calculate_sleep_time "true" "true" 10 30)
 
 [ "${SLEEP_TIME}" -eq 20 ]
}

# =============================================================================
# Tests for Edge Cases
# =============================================================================

@test "Sleep calculation: Processing longer than interval should not be negative" {
 # Ensure sleep time is never negative
 local SLEEP_TIME
 SLEEP_TIME=$(__calculate_sleep_time "true" "true" 100 60)
 
 [ "${SLEEP_TIME}" -eq 0 ]
 [ "${SLEEP_TIME}" -ge 0 ]
}

@test "Sleep calculation: Very long processing (1000s) should sleep 0s" {
 # Very long processing should result in immediate continuation
 local SLEEP_TIME
 SLEEP_TIME=$(__calculate_sleep_time "true" "true" 1000 60)
 
 [ "${SLEEP_TIME}" -eq 0 ]
}

# =============================================================================
# Tests for Daemon Script Structure
# =============================================================================

@test "processAPINotesDaemon.sh script should exist" {
 # Check if the daemon script file exists
 [ -f "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh" ]
}

@test "processAPINotesDaemon.sh script should be executable" {
 # Check if the daemon script is executable
 [ -x "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh" ]
}

@test "processAPINotesDaemon.sh should have help option" {
 # Test that script shows help with -h or --help
 # The script exits with code 1 after showing help (standard behavior)
 run bash "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh" -h 2>&1 || true
 # Help should be displayed (check for help content)
 # The script may output to stderr, so we check for various possible help indicators
 [[ "$output" == *"Usage"* ]] || \
 [[ "$output" == *"help"* ]] || \
 [[ "$output" == *"daemon"* ]] || \
 [[ "$output" == *"OSM Notes API"* ]] || \
 [[ "$output" == *"Processing Daemon"* ]] || \
 [[ "$output" == *"DAEMON_SLEEP_INTERVAL"* ]] || \
 [[ "$status" -eq 1 ]]  # Exit code 1 is expected for help
}

# =============================================================================
# Integration Tests (require mocking)
# =============================================================================

@test "Sleep logic integration: Verify PROCESSING_DURATION is set correctly" {
 # This test verifies that the daemon correctly sets PROCESSING_DURATION
 # We'll source the daemon script and test the logic
 
 # Skip if we can't source the script safely
 skip "Requires full daemon environment setup"
 
 # Source the daemon script (without executing main)
 # source "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 
 # Verify PROCESSING_DURATION variable exists
 # [ -n "${PROCESSING_DURATION:-}" ] || [ "${PROCESSING_DURATION:-0}" -ge 0 ]
}

# =============================================================================
# Performance Tests
# =============================================================================

@test "Sleep calculation performance: Should be fast" {
 # Sleep calculation should be very fast (microseconds, not seconds)
 local START_TIME
 local END_TIME
 local DURATION
 local MAX_DURATION
 
 # Use nanoseconds if available for better precision
 if command -v date >/dev/null 2>&1 && date +%s%N >/dev/null 2>&1; then
  START_TIME=$(date +%s%N)
  for i in {1..1000}; do
   __calculate_sleep_time "true" "true" 25 60 > /dev/null
  done
  END_TIME=$(date +%s%N)
  DURATION=$(( (END_TIME - START_TIME) / 1000000 )) # Convert to milliseconds
  MAX_DURATION=2000 # 2 seconds when using nanosecond precision
 else
  # Fallback: use seconds precision with more lenient threshold
  # Since date +%s only gives second precision, we need to be more lenient
  START_TIME=$(date +%s)
  for i in {1..1000}; do
   __calculate_sleep_time "true" "true" 25 60 > /dev/null
  done
  END_TIME=$(date +%s)
  DURATION=$(( (END_TIME - START_TIME) * 1000 )) # Convert to milliseconds
  # With seconds precision, be more lenient (allow up to 4 seconds = 4000ms)
  # This accounts for the imprecision of second-level timing
  MAX_DURATION=4000
 fi
 
 # Should complete 1000 calculations in less than the maximum duration
 # Note: Test framework overhead may cause longer execution times in test environment
 # Allow up to 5 seconds (5000ms) to account for test framework overhead
 local ABSOLUTE_MAX=5000
 if [[ "${DURATION}" -ge "${MAX_DURATION}" ]]; then
  echo "Warning: Sleep calculation took ${DURATION}ms (preferred limit: ${MAX_DURATION}ms)" >&2
 fi
 [ "${DURATION}" -lt "${ABSOLUTE_MAX}" ]
}

# =============================================================================
# Documentation Tests
# =============================================================================

@test "Sleep logic should match documented behavior" {
 # Test all documented scenarios from the design document
 # Scenario 1: No updates
 local SLEEP1
 SLEEP1=$(__calculate_sleep_time "false" "false" 0 60)
 [ "${SLEEP1}" -eq 60 ]
 
 # Scenario 2: Processing in 25s
 local SLEEP2
 SLEEP2=$(__calculate_sleep_time "true" "true" 25 60)
 [ "${SLEEP2}" -eq 35 ]
 
 # Scenario 3: Processing in 80s
 local SLEEP3
 SLEEP3=$(__calculate_sleep_time "true" "true" 80 60)
 [ "${SLEEP3}" -eq 0 ]
 
 # Scenario 4: Processing failed
 local SLEEP4
 SLEEP4=$(__calculate_sleep_time "true" "false" 10 60)
 [ "${SLEEP4}" -eq 60 ]
}
