#!/usr/bin/env bats

# Note Processing Location Tests
# Tests for location processing and data gap logging
# Author: Andres Gomez (AngocA)
# Version: 2025-12-07

load "${BATS_TEST_DIRNAME}/../../test_helper"

setup() {
 # Create temporary test directory
 TEST_DIR=$(mktemp -d)
 export TEST_DIR

 # Set up test environment variables
 export SCRIPT_BASE_DIRECTORY="${TEST_BASE_DIR}"
 export TMP_DIR="${TEST_DIR}"
 export DBNAME="${TEST_DBNAME:-test_db}"
 export RATE_LIMIT="${RATE_LIMIT:-8}"
 export BASHPID=$$

 # Set log level to DEBUG to capture all log output
 export LOG_LEVEL="DEBUG"
 export __log_level="DEBUG"

 # Load note processing functions
 source "${TEST_BASE_DIR}/bin/lib/noteProcessingFunctions.sh"
}

teardown() {
 # Clean up test files
 rm -rf "${TEST_DIR}"
}

# =============================================================================
# Tests for __log_data_gap
# =============================================================================

@test "__log_data_gap should log gap to file" {
 local GAP_FILE="/tmp/processAPINotes_gaps.log"
 rm -f "${GAP_FILE}"

 # Mock psql to succeed
 psql() {
  return 0
 }
 export -f psql

 run __log_data_gap "test_gap" "10" "100" "test details"
 [[ "${status}" -eq 0 ]]
 [[ -f "${GAP_FILE}" ]]
 [[ "$(grep -c "test_gap" "${GAP_FILE}")" -gt 0 ]]
}

@test "__log_data_gap should calculate percentage" {
 local GAP_FILE="/tmp/processAPINotes_gaps.log"
 rm -f "${GAP_FILE}"

 # Mock psql
 psql() {
  return 0
 }
 export -f psql

 run __log_data_gap "test_gap" "25" "100" "test"
 [[ "${status}" -eq 0 ]]
 [[ "$(grep -c "25%" "${GAP_FILE}")" -gt 0 ]]
}

@test "__log_data_gap should handle database errors gracefully" {
 local GAP_FILE="/tmp/processAPINotes_gaps.log"
 rm -f "${GAP_FILE}"

 # Mock psql to fail
 psql() {
  return 1
 }
 export -f psql

 run __log_data_gap "test_gap" "10" "100" "test"
 # Should still succeed even if database insert fails
 [[ "${status}" -eq 0 ]]
 [[ -f "${GAP_FILE}" ]]
}

# =============================================================================
# Tests for __getLocationNotes_impl (Basic tests - complex function)
# =============================================================================

@test "__getLocationNotes_impl should handle TEST_MODE" {
 export TEST_MODE="true"
 export HYBRID_MOCK_MODE=""
 export DBNAME="test_db"

 # Mock psql to return 0 notes
 psql() {
  if [[ "$5" == *"COUNT(*)"* ]]; then
   echo "0"
   return 0
  fi
  return 0
 }
 export -f psql

 run __getLocationNotes_impl
 # Should succeed and skip processing
 [[ "${status}" -eq 0 ]]
}

@test "__getLocationNotes_impl should handle notes without country" {
 export TEST_MODE="true"
 export HYBRID_MOCK_MODE=""
 export DBNAME="test_db"

 local CALL_COUNT=0
 # Mock psql to return notes count then succeed on update
 psql() {
  CALL_COUNT=$((CALL_COUNT + 1))
  if [[ ${CALL_COUNT} -eq 1 ]]; then
   # First call: COUNT query
   echo "5"
   return 0
  elif [[ ${CALL_COUNT} -eq 2 ]]; then
   # Second call: UPDATE query
   return 0
  fi
  return 0
 }
 export -f psql

 run __getLocationNotes_impl
 # Should succeed
 [[ "${status}" -eq 0 ]]
}

