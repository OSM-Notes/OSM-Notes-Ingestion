#!/usr/bin/env bash

# Common helper functions for regression tests
# Author: Andres Gomez (AngocA)
# Version: 2025-12-23

# Load common helpers
if [[ -n "${BATS_TEST_FILENAME:-}" ]]; then
 load "$(dirname "$BATS_TEST_FILENAME")/../test_helpers_common.bash"
else
 source "$(dirname "${BASH_SOURCE[0]}")/../test_helpers_common.bash"
fi

# =============================================================================
# Setup and Teardown Helpers
# =============================================================================

__setup_regression_test() {
 # Use common setup function
 __common_setup_test_dir "test_regression"
}

__teardown_regression_test() {
 # Use common teardown function
 __common_teardown_test_dir
}

# =============================================================================
# File Verification Helpers
# =============================================================================

# Use common verification functions (aliases for backward compatibility)
__verify_file_exists() {
 __common_verify_file_exists "$@"
}

__verify_pattern_in_file() {
 __common_verify_pattern_in_file "$@"
}

# =============================================================================
# Log Processing Helpers
# =============================================================================

__extract_boundary_id_from_log() {
 local LOG_FILE="$1"
 local BOUNDARY_ID

 # Extract boundary ID using correct method (not timestamps)
 BOUNDARY_ID=$(sed -n 's/.*boundary \([0-9]\{4,\}\).*/\1/p' "${LOG_FILE}")

 echo "${BOUNDARY_ID}"
}

# Use common test log file creation function (alias for backward compatibility)
__create_test_log_file() {
 __common_create_test_log_file "$@"
}

# =============================================================================
# SQL Verification Helpers
# =============================================================================

# Use common SQL verification function (alias for backward compatibility)
__verify_sql_pattern() {
 __common_verify_sql_pattern "$@"
}

# =============================================================================
# Script Verification Helpers
# =============================================================================

# Use common script verification function (alias for backward compatibility)
__verify_script_pattern() {
 __common_verify_script_pattern "$@"
}

# =============================================================================
# Mock Helpers
# =============================================================================

# Use common mock psql functions (aliases for backward compatibility)
__mock_psql_false() {
 __common_mock_psql_false
}

__mock_psql_empty() {
 __common_mock_psql_empty
}

