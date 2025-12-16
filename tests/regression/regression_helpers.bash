#!/usr/bin/env bash

# Common helper functions for regression tests
# Author: Andres Gomez (AngocA)
# Version: 2025-12-15

# =============================================================================
# Setup and Teardown Helpers
# =============================================================================

__setup_regression_test() {
 # Create temporary test directory
 TEST_DIR=$(mktemp -d)
 export TEST_DIR

 # Set up test environment variables
 export SCRIPT_BASE_DIRECTORY="${TEST_BASE_DIR}"
 export TMP_DIR="${TEST_DIR}"
 export DBNAME="${TEST_DBNAME:-test_db}"

 # Set log level to DEBUG
 export LOG_LEVEL="DEBUG"
 export __log_level="DEBUG"
}

__teardown_regression_test() {
 # Clean up test files
 if [[ -n "${TEST_DIR:-}" ]] && [[ -d "${TEST_DIR}" ]]; then
  rm -rf "${TEST_DIR}"
 fi
}

# =============================================================================
# File Verification Helpers
# =============================================================================

__verify_file_exists() {
 local FILE_PATH="$1"
 local SKIP_MSG="${2:-File not found}"

 if [[ ! -f "${FILE_PATH}" ]]; then
  skip "${SKIP_MSG}"
 fi
}

__verify_pattern_in_file() {
 local FILE_PATH="$1"
 local PATTERN="$2"
 local ERROR_MSG="${3:-Pattern not found}"

 __verify_file_exists "${FILE_PATH}"

 run grep -qE "${PATTERN}" "${FILE_PATH}"
 [[ "${status}" -eq 0 ]] || echo "${ERROR_MSG}"
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

__create_test_log_file() {
 local LOG_FILE="$1"
 shift
 local LOG_LINES=("$@")

 printf '%s\n' "${LOG_LINES[@]}" > "${LOG_FILE}"
}

# =============================================================================
# SQL Verification Helpers
# =============================================================================

__verify_sql_pattern() {
 local SQL_FILE="$1"
 local PATTERN="$2"
 local ERROR_MSG="${3:-SQL pattern not found}"

 __verify_file_exists "${SQL_FILE}"

 run grep -qE "${PATTERN}" "${SQL_FILE}"
 [[ "${status}" -eq 0 ]] || echo "${ERROR_MSG}"
}

# =============================================================================
# Script Verification Helpers
# =============================================================================

__verify_script_pattern() {
 local SCRIPT_FILE="$1"
 local PATTERN="$2"
 local ERROR_MSG="${3:-Script pattern not found}"

 __verify_file_exists "${SCRIPT_FILE}"

 run grep -qE "${PATTERN}" "${SCRIPT_FILE}"
 [[ "${status}" -eq 0 ]] || echo "${ERROR_MSG}"
}

# =============================================================================
# Mock Helpers
# =============================================================================

__mock_psql_false() {
 psql() {
  if [[ "$1" == "-d" ]] && [[ "$3" == "-Atq" ]]; then
   echo "false"
   return 0
  fi
  return 0
 }
 export -f psql
}

__mock_psql_empty() {
 psql() {
  if [[ "$1" == "-d" ]] && [[ "$3" == "-Atq" ]]; then
   echo ""
   return 0
  fi
  return 0
 }
 export -f psql
}

