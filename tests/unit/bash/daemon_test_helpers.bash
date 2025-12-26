#!/usr/bin/env bash

# Common helper functions for daemon tests
# Author: Andres Gomez (AngocA)
# Version: 2025-12-23

# Load common helpers
if [[ -n "${BATS_TEST_FILENAME:-}" ]]; then
 load "$(dirname "$BATS_TEST_FILENAME")/../../test_helpers_common.bash"
else
 source "$(dirname "${BASH_SOURCE[0]}")/../../test_helpers_common.bash"
fi

# =============================================================================
# Setup and Teardown Helpers
# =============================================================================

__setup_daemon_test() {
 # Use common setup function
 __common_setup_test_dir "test_daemon"

 # Set daemon-specific environment variables
 export DAEMON_SLEEP_INTERVAL=60

 # Create mock lock file location
 export LOCK="/tmp/${BASENAME}.lock"
 export DAEMON_SHUTDOWN_FLAG="/tmp/${BASENAME}_shutdown"

 # Clean up any existing locks
 rm -f "${LOCK}"
 rm -f "${DAEMON_SHUTDOWN_FLAG}"

 # Mock psql to simulate database state
 __common_setup_mock_psql

 # Load daemon functions
 source "${TEST_BASE_DIR}/bin/lib/functionsProcess.sh" 2>/dev/null || true
}

__teardown_daemon_test() {
 # Use common teardown function with additional patterns
 __common_teardown_test_dir \
  "${LOCK:-}" \
  "${DAEMON_SHUTDOWN_FLAG:-}" \
  "/tmp/processAPINotesDaemon*.lock" \
  "/tmp/processAPINotesDaemon*_shutdown" \
  "/tmp/processAPINotesDaemon*.log"
}

# =============================================================================
# Mock Helpers
# =============================================================================

# Use common mock psql function (alias for backward compatibility)
__setup_mock_psql() {
 __common_setup_mock_psql "0"
}

