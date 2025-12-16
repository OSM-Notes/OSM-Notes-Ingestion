#!/usr/bin/env bash

# Common helper functions for daemon tests
# Author: Andres Gomez (AngocA)
# Version: 2025-12-15

# =============================================================================
# Setup and Teardown Helpers
# =============================================================================

__setup_daemon_test() {
 # Create temporary test directory
 TEST_DIR=$(mktemp -d)
 export TEST_DIR

 # Set up test environment variables
 export SCRIPT_BASE_DIRECTORY="${TEST_BASE_DIR}"
 export TMP_DIR="${TEST_DIR}"
 export DBNAME="${TEST_DBNAME:-test_db}"
 export BASENAME="test_daemon"
 export LOG_LEVEL="DEBUG"
 export __log_level="DEBUG"
 export TEST_MODE="true"
 export DAEMON_SLEEP_INTERVAL=60

 # Create mock lock file location
 export LOCK="/tmp/${BASENAME}.lock"
 export DAEMON_SHUTDOWN_FLAG="/tmp/${BASENAME}_shutdown"

 # Clean up any existing locks
 rm -f "${LOCK}"
 rm -f "${DAEMON_SHUTDOWN_FLAG}"

 # Mock psql to simulate database state
 __setup_mock_psql

 # Load daemon functions
 source "${TEST_BASE_DIR}/bin/lib/functionsProcess.sh" 2>/dev/null || true
}

__teardown_daemon_test() {
 # Clean up test files
 if [[ -n "${TEST_DIR:-}" ]] && [[ -d "${TEST_DIR}" ]]; then
  rm -rf "${TEST_DIR}"
 fi
 rm -f "${LOCK:-}"
 rm -f "${DAEMON_SHUTDOWN_FLAG:-}"
 rm -f /tmp/processAPINotesDaemon*.lock
 rm -f /tmp/processAPINotesDaemon*_shutdown
 rm -f /tmp/processAPINotesDaemon*.log
}

# =============================================================================
# Mock Helpers
# =============================================================================

__setup_mock_psql() {
 psql() {
  local ARGS=("$@")
  local CMD=""
  local I=0
  # Parse arguments to find -c command
  while [[ $I -lt ${#ARGS[@]} ]]; do
   if [[ "${ARGS[$I]}" == "-c" ]] && [[ $((I + 1)) -lt ${#ARGS[@]} ]]; then
    CMD="${ARGS[$((I + 1))]}"
    break
   fi
   I=$((I + 1))
  done

  # Default: return empty result
  echo "0"
  return 0
 }
 export -f psql
}

