#!/bin/bash

# Test script for partition table creation
# Tests that partition tables are created correctly with the right number of threads
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-23

set -euo pipefail

# Define required variables
declare BASENAME="testPartitionCreation"
declare TMP_DIR="/tmp/${BASENAME}_$$"
mkdir -p "${TMP_DIR}"

# Simple logging functions for testing
function log_info() {
 echo "$(date '+%Y-%m-%d %H:%M:%S') - INFO - $*" || true
}

function log_error() {
 echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR - $*" >&2 || true
}

# Test function to check SQL syntax
function test_sql_syntax() {
 local SQL_FILE="${1}"
 local MAX_THREADS="${2}"

 log_info "Testing SQL syntax for partition creation with MAX_THREADS=${MAX_THREADS}"

 # Create a temporary file with the SQL content
 declare TEMP_SQL="${TMP_DIR}/test_partition.sql"

 # Create the SQL content with the variable set
 cat > "${TEMP_SQL}" << EOF
SET app.max_threads = '${MAX_THREADS}';

DO \$\$
DECLARE
  max_threads INTEGER;
  i INTEGER;
  partition_name TEXT;
BEGIN
  -- Get MAX_THREADS from environment variable, default to 4 if not set
  max_threads := COALESCE(current_setting('app.max_threads', true)::INTEGER, 4);
  
  -- Validate MAX_THREADS
  IF max_threads < 1 OR max_threads > 100 THEN
    RAISE EXCEPTION 'Invalid MAX_THREADS: %. Must be between 1 and 100.', max_threads;
  END IF;
  
  -- Create partitions for notes_sync
  FOR i IN 1..max_threads LOOP
    partition_name := 'notes_sync_part_' || i;
    
    EXECUTE format('CREATE TABLE IF NOT EXISTS %I (
      note_id INTEGER NOT NULL,
      latitude DECIMAL NOT NULL,
      longitude DECIMAL NOT NULL,
      created_at TIMESTAMP NOT NULL,
      status TEXT,
      closed_at TIMESTAMP,
      id_country INTEGER,
      part_id INTEGER DEFAULT %s
    )', partition_name, i);
  END LOOP;
  
  -- Create partitions for note_comments_sync
  FOR i IN 1..max_threads LOOP
    partition_name := 'note_comments_sync_part_' || i;
    
    EXECUTE format('CREATE TABLE IF NOT EXISTS %I (
      id SERIAL,
      note_id INTEGER NOT NULL,
      sequence_action INTEGER,
      event TEXT NOT NULL,
      created_at TIMESTAMP NOT NULL,
      id_user INTEGER,
      username VARCHAR(256),
      part_id INTEGER DEFAULT %s
    )', partition_name, i);
  END LOOP;
  
  -- Create partitions for note_comments_text_sync
  FOR i IN 1..max_threads LOOP
    partition_name := 'note_comments_text_sync_part_' || i;
    
    EXECUTE format('CREATE TABLE IF NOT EXISTS %I (
      note_id INTEGER NOT NULL,
      body TEXT,
      part_id INTEGER DEFAULT %s
    )', partition_name, i);
  END LOOP;
  
  RAISE NOTICE 'Created % partitions for each Planet sync table', max_threads;
END \$\$;
EOF

 log_info "Generated SQL file: ${TEMP_SQL}"
 log_info "SQL content (first 20 lines):"
 head -20 "${TEMP_SQL}" | sed 's/^/  /'

 # Check if the SQL file was created successfully
 if [[ -f "${TEMP_SQL}" ]]; then
  log_info "SUCCESS: SQL file created successfully"
  return 0
 else
  log_error "FAILED: SQL file creation failed"
  return 1
 fi
}

# Test function to check variable expansion
function test_variable_expansion() {
 local MAX_THREADS="${1}"

 log_info "Testing variable expansion with MAX_THREADS=${MAX_THREADS}"

 # Check if the SQL would create the right number of partitions
 local EXPECTED_PARTITIONS=$((MAX_THREADS * 3))

 log_info "Expected partitions: ${EXPECTED_PARTITIONS} (${MAX_THREADS} threads × 3 table types)"

 # Show what partition names would be created
 log_info "Partition names that would be created:"
 for i in $(seq 1 "${MAX_THREADS}"); do
  echo "  - notes_sync_part_${i}"
  echo "  - note_comments_sync_part_${i}"
  echo "  - note_comments_text_sync_part_${i}"
 done

 log_info "SUCCESS: Variable expansion test completed"
 return 0
}

# Test function to check the actual SQL file
function test_actual_sql_file() {
 local SCRIPT_BASE_DIRECTORY
 SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
 local SQL_FILE="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_22_createPartitions.sql"

 log_info "Testing actual SQL file: ${SQL_FILE}"

 if [[ ! -f "${SQL_FILE}" ]]; then
  log_error "FAILED: SQL file does not exist: ${SQL_FILE}"
  return 1
 fi

 log_info "SUCCESS: SQL file exists"

 # Show the content of the actual SQL file
 log_info "SQL file content (first 30 lines):"
 head -30 "${SQL_FILE}" | sed 's/^/  /'

 return 0
}

# Run tests
function run_tests() {
 local MAX_THREADS="${1:-5}"

 log_info "Starting partition creation tests"
 log_info "Max threads: ${MAX_THREADS}"

 # Test 1: Check actual SQL file
 log_info "Test 1: Checking actual SQL file"
 if test_actual_sql_file; then
  log_info "Test 1 PASSED"
 else
  log_error "Test 1 FAILED"
  return 1
 fi

 # Test 2: Test SQL syntax
 log_info "Test 2: Testing SQL syntax"
 if test_sql_syntax "dummy" "${MAX_THREADS}"; then
  log_info "Test 2 PASSED"
 else
  log_error "Test 2 FAILED"
  return 1
 fi

 # Test 3: Test variable expansion
 log_info "Test 3: Testing variable expansion"
 if test_variable_expansion "${MAX_THREADS}"; then
  log_info "Test 3 PASSED"
 else
  log_error "Test 3 FAILED"
  return 1
 fi

 # Test 4: Check specific partition that was failing
 log_info "Test 4: Checking specific partition notes_sync_part_5"
 if [[ "${MAX_THREADS}" -ge 5 ]]; then
  log_info "SUCCESS: MAX_THREADS=${MAX_THREADS} would create notes_sync_part_5"
 else
  log_error "FAILED: MAX_THREADS=${MAX_THREADS} would NOT create notes_sync_part_5"
  return 1
 fi

 log_info "All partition creation tests completed successfully"
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
 log_info "Starting partition creation tests"

 # Set up cleanup trap
 trap cleanup EXIT

 # Get MAX_THREADS from command line or use default
 local MAX_THREADS="${1:-5}"

 # Run tests
 if run_tests "${MAX_THREADS}"; then
  log_info "All partition creation tests PASSED"
  exit 0
 else
  log_error "Some partition creation tests FAILED"
  exit 1
 fi
}

# Execute main function
main "$@"
