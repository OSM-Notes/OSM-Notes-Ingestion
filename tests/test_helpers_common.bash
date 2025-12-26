#!/usr/bin/env bash

# Common helper functions shared across all test suites
# Author: Andres Gomez (AngocA)
# Version: 2025-12-23

# =============================================================================
# Common Setup and Teardown Functions
# =============================================================================

# Common test directory setup
# Usage: __common_setup_test_dir [BASENAME]
__common_setup_test_dir() {
 local BASENAME="${1:-test}"
 
 # Create temporary test directory
 TEST_DIR=$(mktemp -d)
 export TEST_DIR
 export TMP_DIR="${TEST_DIR}"
 
 # Set up common test environment variables
 export SCRIPT_BASE_DIRECTORY="${TEST_BASE_DIR:-${SCRIPT_BASE_DIRECTORY:-$(cd "$(dirname "${BATS_TEST_FILENAME:-${BASH_SOURCE[1]}}")/../.." && pwd)}}"
 export DBNAME="${TEST_DBNAME:-test_db}"
 export BASENAME="${BASENAME}"
 export TEST_MODE="true"
 
 # Set log level to DEBUG for tests
 export LOG_LEVEL="${LOG_LEVEL:-DEBUG}"
 export __log_level="${__log_level:-DEBUG}"
 
 # Force fallback mode for tests (use /tmp, not /var/log)
 export FORCE_FALLBACK_MODE="true"
 
 # Ensure TMP_DIR exists and is writable
 if [[ ! -d "${TMP_DIR}" ]]; then
  mkdir -p "${TMP_DIR}"
 fi
}

# Common test directory teardown
# Usage: __common_teardown_test_dir [ADDITIONAL_PATTERNS...]
__common_teardown_test_dir() {
 # Clean up test directory
 if [[ -n "${TMP_DIR:-}" ]] && [[ -d "${TMP_DIR}" ]]; then
  rm -rf "${TMP_DIR}" 2> /dev/null || true
 fi
 
 # Clean up any additional patterns provided
 while [[ $# -gt 0 ]]; do
  local PATTERN="$1"
  shift
  if [[ -n "${PATTERN}" ]]; then
   rm -f ${PATTERN} 2> /dev/null || true
  fi
 done
}

# =============================================================================
# Common Mock Logger Functions
# =============================================================================

# Setup mock logger functions for tests
# Usage: __common_setup_mock_loggers
__common_setup_mock_loggers() {
 function __log_start() { echo "LOG_START: $*"; }
 function __log_finish() { echo "LOG_FINISH: $*"; }
 function __logi() { echo "INFO: $*"; }
 function __loge() { echo "ERROR: $*"; }
 function __logw() { echo "WARN: $*"; }
 function __logd() { echo "DEBUG: $*"; }
 function __logt() { echo "TRACE: $*"; }
 function __logf() { echo "FATAL: $*"; }
 export -f __log_start __log_finish __logi __loge __logw __logd __logt __logf
}

# =============================================================================
# Common Mock PostgreSQL Functions
# =============================================================================

# Setup basic mock psql that returns empty/zero results
# Usage: __common_setup_mock_psql [DEFAULT_RETURN_VALUE]
__common_setup_mock_psql() {
 local DEFAULT_RETURN="${1:-0}"
 
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

  # Default: return specified value
  echo "${DEFAULT_RETURN}"
  return 0
 }
 export -f psql
}

# Mock psql that returns false
# Usage: __common_mock_psql_false
__common_mock_psql_false() {
 __common_setup_mock_psql "false"
}

# Mock psql that returns empty string
# Usage: __common_mock_psql_empty
__common_mock_psql_empty() {
 __common_setup_mock_psql ""
}

# =============================================================================
# Common File Verification Functions
# =============================================================================

# Verify file exists, skip test if not found
# Usage: __common_verify_file_exists FILE_PATH [SKIP_MESSAGE]
__common_verify_file_exists() {
 local FILE_PATH="$1"
 local SKIP_MSG="${2:-File not found}"

 if [[ ! -f "${FILE_PATH}" ]]; then
  skip "${SKIP_MSG}"
 fi
}

# Verify pattern exists in file
# Usage: __common_verify_pattern_in_file FILE_PATH PATTERN [ERROR_MESSAGE]
__common_verify_pattern_in_file() {
 local FILE_PATH="$1"
 local PATTERN="$2"
 local ERROR_MSG="${3:-Pattern not found}"

 __common_verify_file_exists "${FILE_PATH}"

 run grep -qE "${PATTERN}" "${FILE_PATH}"
 [[ "${status}" -eq 0 ]] || echo "${ERROR_MSG}"
}

# Verify pattern exists in SQL file
# Usage: __common_verify_sql_pattern SQL_FILE PATTERN [ERROR_MESSAGE]
__common_verify_sql_pattern() {
 local SQL_FILE="$1"
 local PATTERN="$2"
 local ERROR_MSG="${3:-SQL pattern not found}"

 __common_verify_file_exists "${SQL_FILE}"

 run grep -qE "${PATTERN}" "${SQL_FILE}"
 [[ "${status}" -eq 0 ]] || echo "${ERROR_MSG}"
}

# Verify pattern exists in script file
# Usage: __common_verify_script_pattern SCRIPT_FILE PATTERN [ERROR_MESSAGE]
__common_verify_script_pattern() {
 local SCRIPT_FILE="$1"
 local PATTERN="$2"
 local ERROR_MSG="${3:-Script pattern not found}"

 __common_verify_file_exists "${SCRIPT_FILE}"

 run grep -qE "${PATTERN}" "${SCRIPT_FILE}"
 [[ "${status}" -eq 0 ]] || echo "${ERROR_MSG}"
}

# =============================================================================
# Common Test Data Creation Functions
# =============================================================================

# Create mock script file
# Usage: __common_create_mock_script SCRIPT_FILE SCRIPT_CONTENT
__common_create_mock_script() {
 local SCRIPT_FILE="$1"
 local SCRIPT_CONTENT="$2"

 cat > "${SCRIPT_FILE}" << EOF
#!/bin/bash
${SCRIPT_CONTENT}
EOF
 chmod +x "${SCRIPT_FILE}"
}

# Create test log file with lines
# Usage: __common_create_test_log_file LOG_FILE LINE1 [LINE2 ...]
__common_create_test_log_file() {
 local LOG_FILE="$1"
 shift
 local LOG_LINES=("$@")

 printf '%s\n' "${LOG_LINES[@]}" > "${LOG_FILE}"
}

# =============================================================================
# Common Environment Detection Functions
# =============================================================================

# Detect if running in Docker container
# Usage: __common_is_docker
__common_is_docker() {
 [[ -f "/app/bin/functionsProcess.sh" ]]
}

# Get test base directory
# Usage: __common_get_test_base_dir
__common_get_test_base_dir() {
 if __common_is_docker; then
  echo "/app"
 else
  echo "$(cd "$(dirname "${BATS_TEST_FILENAME:-${BASH_SOURCE[1]}}")/../.." && pwd)"
 fi
}

