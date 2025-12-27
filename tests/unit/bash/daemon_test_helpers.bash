#!/usr/bin/env bash

# Common helper functions for daemon tests
# Provides setup, teardown, and mocking helpers for processAPINotesDaemon tests
# Author: Andres Gomez (AngocA)
# Version: 2025-12-27

# Load common helpers
if [[ -n "${BATS_TEST_FILENAME:-}" ]]; then
 load "$(dirname "$BATS_TEST_FILENAME")/../../test_helpers_common.bash"
else
 source "$(dirname "${BASH_SOURCE[0]}")/../../test_helpers_common.bash"
fi

# =============================================================================
# Setup and Teardown Helpers
# =============================================================================

# Setup function for daemon tests
# Usage: __setup_daemon_test
# Sets up: test directory, environment variables, mock psql, lock files
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

 # Setup mock loggers (from common helpers)
 __common_setup_mock_loggers

 # Mock psql to simulate database state (basic mock, can be overridden in tests)
 __common_setup_mock_psql "0"

 # Load daemon functions
 source "${TEST_BASE_DIR}/bin/lib/functionsProcess.sh" 2>/dev/null || true
}

# Teardown function for daemon tests
# Usage: __teardown_daemon_test
# Cleans up: test directory, lock files, daemon-specific files
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

# Setup basic mock psql (alias for backward compatibility)
# Usage: __setup_mock_psql
# Note: For more advanced mocking, use helpers from test_helpers_common.bash:
#   - __setup_mock_psql_for_query - for query-specific results
#   - __setup_mock_psql_boolean - for boolean results
#   - __setup_mock_psql_count - for count results
#   - __setup_mock_psql_with_tracking - for tracking calls and pattern matching
__setup_mock_psql() {
 __common_setup_mock_psql "0"
}

