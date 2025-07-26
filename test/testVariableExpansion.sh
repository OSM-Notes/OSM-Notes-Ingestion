#!/bin/bash

# Test script for variable expansion in SQL files
# Tests that PART_ID and other variables are properly expanded
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-23

set -euo pipefail

# Define required variables
declare BASENAME="testVariableExpansion"
declare TMP_DIR="/tmp/${BASENAME}_$$"
mkdir -p "${TMP_DIR}"

# Simple logging functions for testing
function log_info() {
 echo "$(date '+%Y-%m-%d %H:%M:%S') - INFO - $*" || true
}

function log_error() {
 echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR - $*" >&2 || true
}

# Test function to check variable expansion
function test_variable_expansion() {
 local PART_ID="${1}"
 local OUTPUT_NOTES_PART="${2}"
 local OUTPUT_COMMENTS_PART="${3}"
 local OUTPUT_TEXT_PART="${4}"
 local SQL_FILE="${5}"

 log_info "Testing variable expansion with PART_ID=${PART_ID}"

 # Export variables for envsubst
 export PART_ID
 export OUTPUT_NOTES_PART
 export OUTPUT_COMMENTS_PART
 export OUTPUT_TEXT_PART

 # Create a temporary file with expanded content
 declare EXPANDED_SQL="${TMP_DIR}/expanded_${PART_ID}.sql"

 # Use envsubst to expand variables
 envsubst "${OUTPUT_NOTES_PART},${OUTPUT_COMMENTS_PART},${OUTPUT_TEXT_PART},${PART_ID}" < "${SQL_FILE}" > "${EXPANDED_SQL}"

 # Check if expansion was successful
 if grep -q "notes_sync_part_${PART_ID}" "${EXPANDED_SQL}"; then
  log_info "SUCCESS: PART_ID variable expanded correctly"
  return 0
 else
  log_error "FAILED: PART_ID variable not expanded correctly"
  return 1
 fi
}

# Test function to check for unexpanded variables
function check_unexpanded_variables() {
 local EXPANDED_SQL="${1}"

 log_info "Checking for unexpanded variables in SQL"

 # Check for any remaining ${PART_ID} patterns
 if grep -q "\${PART_ID}" "${EXPANDED_SQL}"; then
  log_error "FAILED: Found unexpanded \${PART_ID} in SQL"
  return 1
 fi

 # Check for any remaining ${OUTPUT_*_PART} patterns
 if grep -q "\${OUTPUT_.*_PART}" "${EXPANDED_SQL}"; then
  log_error "FAILED: Found unexpanded \${OUTPUT_*_PART} in SQL"
  return 1
 fi

 log_info "SUCCESS: No unexpanded variables found"
 return 0
}

# Run tests
function run_tests() {
 local SCRIPT_BASE_DIRECTORY
 SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

 log_info "Starting variable expansion tests"

 # Test 1: Planet SQL file with PART_ID=1
 log_info "Test 1: Testing Planet SQL file with PART_ID=1"
 local PLANET_SQL="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_41_loadPartitionedSyncNotes.sql"
 local TEST_NOTES_PART="/tmp/test-notes-part-1.csv"
 local TEST_COMMENTS_PART="/tmp/test-comments-part-1.csv"
 local TEST_TEXT_PART="/tmp/test-text-part-1.csv"

 if test_variable_expansion "1" "${TEST_NOTES_PART}" "${TEST_COMMENTS_PART}" "${TEST_TEXT_PART}" "${PLANET_SQL}"; then
  log_info "Test 1 PASSED"

  # Check for unexpanded variables
  local EXPANDED_FILE="${TMP_DIR}/expanded_1.sql"
  if check_unexpanded_variables "${EXPANDED_FILE}"; then
   log_info "Test 1a PASSED (no unexpanded variables)"
  else
   log_error "Test 1a FAILED (found unexpanded variables)"
   return 1
  fi
 else
  log_error "Test 1 FAILED"
  return 1
 fi

 # Test 2: Planet SQL file with PART_ID=10
 log_info "Test 2: Testing Planet SQL file with PART_ID=10"
 if test_variable_expansion "10" "${TEST_NOTES_PART}" "${TEST_COMMENTS_PART}" "${TEST_TEXT_PART}" "${PLANET_SQL}"; then
  log_info "Test 2 PASSED"

  # Check for unexpanded variables
  local EXPANDED_FILE="${TMP_DIR}/expanded_10.sql"
  if check_unexpanded_variables "${EXPANDED_FILE}"; then
   log_info "Test 2a PASSED (no unexpanded variables)"
  else
   log_error "Test 2a FAILED (found unexpanded variables)"
   return 1
  fi
 else
  log_error "Test 2 FAILED"
  return 1
 fi

 # Test 3: Show expanded content for verification
 log_info "Test 3: Showing expanded SQL content for verification"
 local EXPANDED_FILE="${TMP_DIR}/expanded_1.sql"
 if [[ -f "${EXPANDED_FILE}" ]]; then
  log_info "Expanded SQL content (first 10 lines):"
  head -10 "${EXPANDED_FILE}" | sed 's/^/  /'
 else
  log_error "Expanded SQL file not found"
  return 1
 fi

 log_info "All variable expansion tests completed successfully"
}

# Cleanup function
# shellcheck disable=SC2317
function cleanup() {
 if [[ -d "${TMP_DIR}" ]]; then
  rm -rf "${TMP_DIR}"
 fi
}

# Main execution
function main() {
 log_info "Starting variable expansion tests"

 # Set up cleanup trap
 trap cleanup EXIT

 # Run tests
 if run_tests; then
  log_info "All variable expansion tests PASSED"
  exit 0
 else
  log_error "Some variable expansion tests FAILED"
  exit 1
 fi
}

# Execute main function
main "$@"
