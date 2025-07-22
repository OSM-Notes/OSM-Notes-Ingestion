#!/bin/bash

# Test script for partition tables creation function
# Tests that partition tables are created correctly with proper verification
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-20

set -euo pipefail

# Define required variables
BASENAME="testPartitionTablesCreation"
TMP_DIR="/tmp/${BASENAME}_$$"
mkdir -p "${TMP_DIR}"

# Simple logging functions for testing
function log_info() {
 echo "$(date '+%Y-%m-%d %H:%M:%S') - INFO - $*"
}

function log_error() {
 echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR - $*" >&2
}

# Mock function to simulate __createPartitionTables
function create_partition_tables() {
 local DBNAME="${1}"
 local MAX_THREADS="${2:-4}"
 local SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
 local CREATE_PARTITIONS_SCRIPT="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_22_createPartitions.sql"

 log_info "Creating partition tables with MAX_THREADS=${MAX_THREADS}"

 if [[ ! -f "${CREATE_PARTITIONS_SCRIPT}" ]]; then
  log_error "Create partitions script not found: ${CREATE_PARTITIONS_SCRIPT}"
  return 1
 fi

 # Set app.max_threads and create partitions
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -c "SET app.max_threads = '${MAX_THREADS}';" \
  -f "${CREATE_PARTITIONS_SCRIPT}"

 log_info "Partition tables creation completed"

 # Verify that partition tables were created
 log_info "Verifying partition tables creation..."
 psql -d "${DBNAME}" -c "
 SELECT table_name, COUNT(*) as count 
 FROM information_schema.tables 
 WHERE table_name LIKE '%_part_%' 
 GROUP BY table_name 
 ORDER BY table_name;
 "

 log_info "Partition tables creation and verification completed"
}

# Test function to verify partition tables exist
function verify_partition_tables() {
 local DBNAME="${1}"
 local MAX_THREADS="${2:-4}"

 log_info "Verifying that partition tables exist for MAX_THREADS=${MAX_THREADS}"

 # Check each type of partition table
 local TABLE_TYPES=("notes_sync" "note_comments_sync" "note_comments_text_sync")
 local ALL_EXIST=true
 local TOTAL_PARTITIONS=0

 for table_type in "${TABLE_TYPES[@]}"; do
  for i in $(seq 1 "${MAX_THREADS}"); do
   local partition_name="${table_type}_part_${i}"
   local EXISTS
   EXISTS=$(psql -d "${DBNAME}" -t -c "
   SELECT COUNT(*) FROM information_schema.tables 
   WHERE table_name = '${partition_name}';
   " | tr -d ' ')

   if [[ "${EXISTS}" -eq 1 ]]; then
    log_info "✓ Partition table ${partition_name} exists"
    TOTAL_PARTITIONS=$((TOTAL_PARTITIONS + 1))
   else
    log_error "✗ Partition table ${partition_name} does not exist"
    ALL_EXIST=false
   fi
  done
 done

 local EXPECTED_PARTITIONS=$((MAX_THREADS * 3)) # 3 types of tables
 log_info "Found ${TOTAL_PARTITIONS} partition tables (expected: ${EXPECTED_PARTITIONS})"

 if [[ "${ALL_EXIST}" == true ]] && [[ "${TOTAL_PARTITIONS}" -eq "${EXPECTED_PARTITIONS}" ]]; then
  log_info "SUCCESS: All partition tables exist"
  return 0
 else
  log_error "FAILED: Some partition tables are missing"
  return 1
 fi
}

# Test function to verify partition table structure
function verify_partition_structure() {
 local DBNAME="${1}"
 local MAX_THREADS="${2:-4}"

 log_info "Verifying partition table structure"

 # Check structure of first partition of each type
 local TABLE_TYPES=("notes_sync" "note_comments_sync" "note_comments_text_sync")

 for table_type in "${TABLE_TYPES[@]}"; do
  local partition_name="${table_type}_part_1"
  log_info "Checking ${partition_name} structure:"
  psql -d "${DBNAME}" -c "
  SELECT column_name, data_type, is_nullable 
  FROM information_schema.columns 
  WHERE table_name = '${partition_name}' 
  ORDER BY ordinal_position;
  "
 done

 log_info "Partition table structure verification completed"
}

# Test function to insert sample data into partitions
function test_partition_data() {
 local DBNAME="${1}"
 local MAX_THREADS="${2:-4}"

 log_info "Testing sample data insertion into partitions"

 # Insert sample data into first partition of each type
 psql -d "${DBNAME}" -c "
 INSERT INTO notes_sync_part_1 (note_id, latitude, longitude, created_at, status, closed_at, id_country, part_id) VALUES
 (123, 40.7128, -74.0060, '2013-04-28T02:39:27Z', 'close', '2013-04-29T10:15:30Z', NULL, 1);
 "

 psql -d "${DBNAME}" -c "
 INSERT INTO note_comments_sync_part_1 (id, note_id, sequence_action, event, created_at, id_user, username, part_id) VALUES
 (1, 123, 1, 'opened', '2013-04-28T02:39:27Z', 123, 'user1', 1);
 "

 psql -d "${DBNAME}" -c "
 INSERT INTO note_comments_text_sync_part_1 (note_id, body, part_id) VALUES
 (123, 'This is a test comment', 1);
 "

 # Verify data was inserted
 local NOTES_COUNT
 NOTES_COUNT=$(psql -d "${DBNAME}" -t -c "SELECT COUNT(*) FROM notes_sync_part_1;" | tr -d ' ')

 local COMMENTS_COUNT
 COMMENTS_COUNT=$(psql -d "${DBNAME}" -t -c "SELECT COUNT(*) FROM note_comments_sync_part_1;" | tr -d ' ')

 local TEXT_COMMENTS_COUNT
 TEXT_COMMENTS_COUNT=$(psql -d "${DBNAME}" -t -c "SELECT COUNT(*) FROM note_comments_text_sync_part_1;" | tr -d ' ')

 log_info "Sample data inserted into partitions:"
 log_info "  notes_sync_part_1: ${NOTES_COUNT} records"
 log_info "  note_comments_sync_part_1: ${COMMENTS_COUNT} records"
 log_info "  note_comments_text_sync_part_1: ${TEXT_COMMENTS_COUNT} records"

 if [[ "${NOTES_COUNT}" -eq 1 && "${COMMENTS_COUNT}" -eq 1 && "${TEXT_COMMENTS_COUNT}" -eq 1 ]]; then
  log_info "SUCCESS: All sample data inserted correctly into partitions"
  return 0
 else
  log_error "FAILED: Sample data insertion into partitions failed"
  return 1
 fi
}

# Test function to clean up partition tables
function cleanup_partition_tables() {
 local DBNAME="${1}"
 local MAX_THREADS="${2:-4}"

 log_info "Cleaning up partition tables"

 # Drop partition tables
 local TABLE_TYPES=("notes_sync" "note_comments_sync" "note_comments_text_sync")

 for table_type in "${TABLE_TYPES[@]}"; do
  for i in $(seq 1 "${MAX_THREADS}"); do
   local partition_name="${table_type}_part_${i}"
   psql -d "${DBNAME}" -c "DROP TABLE IF EXISTS ${partition_name};"
   log_info "Dropped partition table: ${partition_name}"
  done
 done

 log_info "Partition tables cleanup completed"
}

# Run tests
function run_tests() {
 local DBNAME="${1:-osm_notes_test}"
 local MAX_THREADS="${2:-4}"

 log_info "Starting partition tables creation tests"
 log_info "Database: ${DBNAME}"
 log_info "MAX_THREADS: ${MAX_THREADS}"

 # Test 1: Create partition tables
 log_info "Test 1: Creating partition tables"
 if create_partition_tables "${DBNAME}" "${MAX_THREADS}"; then
  log_info "Test 1 PASSED"
 else
  log_error "Test 1 FAILED"
  return 1
 fi

 # Test 2: Verify partition tables exist
 log_info "Test 2: Verifying partition tables exist"
 if verify_partition_tables "${DBNAME}" "${MAX_THREADS}"; then
  log_info "Test 2 PASSED"
 else
  log_error "Test 2 FAILED"
  return 1
 fi

 # Test 3: Verify partition table structure
 log_info "Test 3: Verifying partition table structure"
 if verify_partition_structure "${DBNAME}" "${MAX_THREADS}"; then
  log_info "Test 3 PASSED"
 else
  log_error "Test 3 FAILED"
  return 1
 fi

 # Test 4: Test sample data insertion
 log_info "Test 4: Testing sample data insertion into partitions"
 if test_partition_data "${DBNAME}" "${MAX_THREADS}"; then
  log_info "Test 4 PASSED"
 else
  log_error "Test 4 FAILED"
  return 1
 fi

 # Test 5: Clean up partition tables
 log_info "Test 5: Cleaning up partition tables"
 if cleanup_partition_tables "${DBNAME}" "${MAX_THREADS}"; then
  log_info "Test 5 PASSED"
 else
  log_error "Test 5 FAILED"
  return 1
 fi

 log_info "All partition tables creation tests completed successfully"
}

# Cleanup function
function cleanup() {
 if [[ -d "${TMP_DIR}" ]]; then
  rm -rf "${TMP_DIR}"
 fi
}

# Main execution
function main() {
 log_info "Starting partition tables creation tests"

 # Set up cleanup trap
 trap cleanup EXIT

 # Check if database name is provided
 local DBNAME="${1:-}"
 local MAX_THREADS="${2:-4}"

 if [[ -z "${DBNAME}" ]]; then
  log_error "Usage: $0 <database_name> [max_threads]"
  log_error "Example: $0 osm_notes_test 4"
  exit 1
 fi

 # Run tests
 if run_tests "${DBNAME}" "${MAX_THREADS}"; then
  log_info "All partition tables creation tests PASSED"
  exit 0
 else
  log_error "Some partition tables creation tests FAILED"
  exit 1
 fi
}

# Execute main function
main "$@"
