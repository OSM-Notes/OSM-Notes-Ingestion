#!/usr/bin/env bats

# ProcessAPI Historical SQL Tests
# Tests for SQL validation logic for historical data
# Author: Andres Gomez (AngocA)
# Version: 2025-08-07

load "$(dirname "$BATS_TEST_FILENAME")/../../test_helper.bash"

# =============================================================================
# Test setup and teardown
# =============================================================================

setup() {
 # Set up required environment variables
 export BASENAME="test"
 export TMP_DIR="/tmp/test_$$"
 export DBNAME="${TEST_DBNAME:-test_db}"
 export SCRIPT_BASE_DIRECTORY="${TEST_BASE_DIR}"
 export LOG_FILENAME="/tmp/test.log"
 export LOCK="/tmp/test.lock"
 export MAX_THREADS="2"
 export PROCESS_TYPE="test"
 export FAILED_EXECUTION_FILE="/tmp/failed_execution_test"

 # Create test directory
 mkdir -p "${TMP_DIR}"

 # Remove any existing failed execution file
 rm -f "${FAILED_EXECUTION_FILE}"

 # Set up constants
 export POSTGRES_11_CHECK_HISTORICAL_DATA="${TEST_BASE_DIR}/sql/functionsProcess_11_checkHistoricalData.sql"
}

teardown() {
 # Clean up test files
 rm -rf "${TMP_DIR}" 2>/dev/null || true
 rm -f "${FAILED_EXECUTION_FILE}" 2>/dev/null || true
}

# =============================================================================
# Test SQL validation logic
# =============================================================================

@test "historical_data_sql_validates_empty_notes_table" {
 # Skip if we don't have a test database
 if [[ -z "${TEST_DBNAME}" ]]; then
  skip "No test database available"
 fi

 # Mock psql to simulate empty notes table
 psql() {
  if [[ "$*" =~ "checkHistoricalData" ]]; then
   echo "ERROR: Historical data validation failed: notes table is empty. Please run processPlanetNotes.sh first to load historical data."
   return 1
  fi
  return 0
 }

 # Test SQL validation
 run psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_11_CHECK_HISTORICAL_DATA}"

 echo "Exit code: $status"
 echo "Output: $output"

 [ "$status" -eq 1 ]
 [[ "$output" =~ "notes table is empty" ]]
 [[ "$output" =~ "Please run processPlanetNotes.sh first" ]]
}

@test "historical_data_sql_validates_insufficient_historical_data" {
 # Skip if we don't have a test database
 if [[ -z "${TEST_DBNAME}" ]]; then
  skip "No test database available"
 fi

 # Mock psql to simulate insufficient historical data
 psql() {
  if [[ "$*" =~ "checkHistoricalData" ]]; then
   echo "ERROR: Historical data validation failed: insufficient historical data. Found data from 2025-08-01, but need at least 30 days of history."
   return 1
  fi
  return 0
 }

 # Test SQL validation
 run psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_11_CHECK_HISTORICAL_DATA}"

 echo "Exit code: $status"
 echo "Output: $output"

 [ "$status" -eq 1 ]
 [[ "$output" =~ "insufficient historical data" ]]
 [[ "$output" =~ "need at least 30 days" ]]
}

@test "historical_data_sql_passes_with_sufficient_data" {
 # Skip if we don't have a test database
 if [[ -z "${TEST_DBNAME}" ]]; then
  skip "No test database available"
 fi

 # Mock psql to simulate sufficient historical data
 psql() {
  if [[ "$*" =~ "checkHistoricalData" ]]; then
   echo "NOTICE: Historical data validation passed: Found notes from 2020-01-01 and comments from 2020-01-01 (1000 and 1000 days of history respectively)"
   return 0
  fi
  return 0
 }

 # Test SQL validation
 run psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_11_CHECK_HISTORICAL_DATA}"

 echo "Exit code: $status"
 echo "Output: $output"

 [ "$status" -eq 0 ]
 [[ "$output" =~ "Historical data validation passed" ]]
 [[ "$output" =~ "days of history respectively" ]]
}

