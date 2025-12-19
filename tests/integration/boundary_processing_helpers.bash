#!/usr/bin/env bash

# Common helper functions for boundary processing integration tests
# Author: Andres Gomez (AngocA)
# Version: 2025-12-15

# =============================================================================
# Setup and Teardown Helpers
# =============================================================================

__setup_boundary_test() {
 # Setup test environment
 # Force fallback mode for tests (use /tmp, not /var/log)
 export FORCE_FALLBACK_MODE="true"
 if [[ -z "${SCRIPT_BASE_DIRECTORY:-}" ]]; then
  export SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
 fi
 export TMP_DIR="$(mktemp -d)"
 export TEST_DIR="${TMP_DIR}"
 export BASENAME="test_boundary_processing"

 # Ensure TMP_DIR exists and is writable
 if [[ ! -d "${TMP_DIR}" ]]; then
  mkdir -p "${TMP_DIR}"
 fi

 # Set up test environment variables
 export DBNAME="${TEST_DBNAME:-test_db}"
 export BASHPID=$$
 export TEST_MODE="true"
 export LOG_LEVEL="DEBUG"
 export __log_level="DEBUG"

 # Mock external dependencies
 export OVERPASS_RETRIES_PER_ENDPOINT=2
 export OVERPASS_BACKOFF_SECONDS=1
 export DOWNLOAD_MAX_THREADS=2

 # Source the functions
 source "${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh" 2>/dev/null || true

 # Setup mock logger functions
 __setup_mock_loggers
}

__teardown_boundary_test() {
 # Cleanup test environment
 if [[ -n "${TMP_DIR:-}" ]] && [[ -d "${TMP_DIR}" ]]; then
  rm -rf "${TMP_DIR}"
 fi
}

# =============================================================================
# Mock Logger Functions
# =============================================================================

__setup_mock_loggers() {
 function __log_start() { echo "LOG_START: $*"; }
 function __log_finish() { echo "LOG_FINISH: $*"; }
 function __logi() { echo "INFO: $*"; }
 function __loge() { echo "ERROR: $*"; }
 function __logw() { echo "WARN: $*"; }
 function __logd() { echo "DEBUG: $*"; }
 export -f __log_start __log_finish __logi __loge __logw __logd
}

# =============================================================================
# Mock Script Helpers
# =============================================================================

__create_mock_script() {
 local SCRIPT_FILE="$1"
 local SCRIPT_CONTENT="$2"

 cat > "${SCRIPT_FILE}" << EOF
#!/bin/bash
${SCRIPT_CONTENT}
EOF
 chmod +x "${SCRIPT_FILE}"
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

