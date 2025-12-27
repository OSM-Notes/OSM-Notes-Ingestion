#!/usr/bin/env bash

# Common helper functions for boundary processing integration tests
# Author: Andres Gomez (AngocA)
# Version: 2025-12-23

# Load common helpers
if [[ -n "${BATS_TEST_FILENAME:-}" ]]; then
 # Try relative path first, then absolute path
 if [[ -f "$(dirname "$BATS_TEST_FILENAME")/../test_helpers_common.bash" ]]; then
  load "$(dirname "$BATS_TEST_FILENAME")/../test_helpers_common.bash"
 elif [[ -f "$(dirname "$BATS_TEST_FILENAME")/../../test_helpers_common.bash" ]]; then
  load "$(dirname "$BATS_TEST_FILENAME")/../../test_helpers_common.bash"
 fi
else
 if [[ -f "$(dirname "${BASH_SOURCE[0]}")/../test_helpers_common.bash" ]]; then
  source "$(dirname "${BASH_SOURCE[0]}")/../test_helpers_common.bash"
 elif [[ -f "$(dirname "${BASH_SOURCE[0]}")/../../test_helpers_common.bash" ]]; then
  source "$(dirname "${BASH_SOURCE[0]}")/../../test_helpers_common.bash"
 fi
fi

# =============================================================================
# Setup and Teardown Helpers
# =============================================================================

__setup_boundary_test() {
 # Use common setup function
 __common_setup_test_dir "test_boundary_processing"

 # Set boundary-specific environment variables
 export BASHPID=$$
 export OVERPASS_RETRIES_PER_ENDPOINT=2
 export OVERPASS_BACKOFF_SECONDS=1
 export DOWNLOAD_MAX_THREADS=2

 # Source the functions
 source "${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh" 2>/dev/null || true

 # Setup mock logger functions
 __common_setup_mock_loggers
}

__teardown_boundary_test() {
 # Use common teardown function
 __common_teardown_test_dir
}

# =============================================================================
# Mock Logger Functions
# =============================================================================

# Use common mock logger function (alias for backward compatibility)
__setup_mock_loggers() {
 __common_setup_mock_loggers
}

# =============================================================================
# Mock Script Helpers
# =============================================================================

# Use common mock script creation function (alias for backward compatibility)
__create_mock_script() {
 __common_create_mock_script "$@"
}

# =============================================================================
# Validation Helpers
# =============================================================================

__verify_query_file_defined() {
 run bash -c "
    source '${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh' > /dev/null 2>&1
    if [[ -n \"\${QUERY_FILE:-}\" ]]; then
      echo \"QUERY_FILE is defined: \${QUERY_FILE}\"
      exit 0
    else
      echo \"QUERY_FILE is not defined\"
      exit 1
    fi
  "
 [[ "$status" -eq 0 ]]
 [[ "$output" == *"QUERY_FILE is defined:"* ]]
}

