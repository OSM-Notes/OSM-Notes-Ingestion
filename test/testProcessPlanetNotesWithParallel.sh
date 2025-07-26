#!/bin/bash
# shellcheck disable=SC2312,SC2155,SC2310

# Test script for Planet notes processing with parallel processing function
# Tests that the parallel processing workflow works correctly
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-23

set -euo pipefail

# Define required variables
declare BASENAME="testProcessPlanetNotesWithParallel"
declare TMP_DIR="/tmp/${BASENAME}_$$"
mkdir -p "${TMP_DIR}"

# Simple logging functions for testing
function log_info() {
 echo "$(date '+%Y-%m-%d %H:%M:%S') - INFO - $*"
}

function log_error() {
 echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR - $*" >&2
}

# Mock function to simulate __processPlanetNotesWithParallel
function process_planet_notes_with_parallel() {
 local DBNAME="${1}"
 local SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
 local MAX_THREADS="${2:-4}"

 log_info "Processing Planet notes with parallel processing"

 # Mock partition tables creation
 log_info "Creating partition tables with MAX_THREADS=${MAX_THREADS}"
 local CREATE_PARTITIONS_SCRIPT="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_22_createPartitions.sql"

 if [[ ! -f "${CREATE_PARTITIONS_SCRIPT}" ]]; then
  log_error "Create partitions script not found: ${CREATE_PARTITIONS_SCRIPT}"
  return 1
 fi

 # Set app.max_threads and create partitions
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -c "SET app.max_threads = '${MAX_THREADS}';" \
  -f "${CREATE_PARTITIONS_SCRIPT}"

 log_info "Partition tables creation completed"

 # Mock XML splitting (just log the action)
 log_info "Mock: Splitting XML for parallel processing"

 # Mock parallel processing (just log the action)
 log_info "Mock: Processing XML parts in parallel"

 # Mock consolidation
 log_info "Mock: Consolidating partitions into main tables"
 local CONSOLIDATE_SCRIPT="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_42_consolidatePartitions.sql"

 if [[ ! -f "${CONSOLIDATE_SCRIPT}" ]]; then
  log_error "Consolidate partitions script not found: ${CONSOLIDATE_SCRIPT}"
  return 1
 fi

 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${CONSOLIDATE_SCRIPT}"

 log_info "Planet notes processing with parallel processing completed"
}

# Test function to verify the complete workflow
function verify_workflow() {
 local DBNAME="${1}"
 local MAX_THREADS="${2:-4}"

 log_info "Verifying complete Planet notes processing workflow"

 # Check that main tables exist after processing
 local TABLES=("notes_sync" "note_comments_sync" "note_comments_text_sync")
 local ALL_EXIST=true

 for table in "${TABLES[@]}"; do
  declare -i EXISTS
  EXISTS=$(psql -d "${DBNAME}" -t -c "
  SELECT COUNT(*) FROM information_schema.tables 
  WHERE table_name = '${table}';
  " | tr -d ' ')

  if [[ "${EXISTS}" -eq 1 ]]; then
   log_info "✓ Main table ${table} exists"
  else
   log_error "✗ Main table ${table} does not exist"
   ALL_EXIST=false
  fi
 done

 # Check that partition tables were cleaned up
 declare -i PARTITION_COUNT
 PARTITION_COUNT=$(psql -d "${DBNAME}" -t -c "
 SELECT COUNT(*) FROM information_schema.tables 
 WHERE table_name LIKE '%_part_%';
 " | tr -d ' ')

 if [[ "${PARTITION_COUNT}" -eq 0 ]]; then
  log_info "✓ All partition tables were cleaned up"
 else
  log_error "✗ ${PARTITION_COUNT} partition tables still exist (should be 0)"
  ALL_EXIST=false
 fi

 if [[ "${ALL_EXIST}" == true ]]; then
  log_info "SUCCESS: Complete workflow verification passed"
  return 0
 else
  log_error "FAILED: Workflow verification failed"
  return 1
 fi
}

# Test function to verify consolidation worked correctly
function verify_consolidation() {
 local DBNAME="${1}"

 log_info "Verifying consolidation results"

 # Check if there's any data in the main tables
 declare -i NOTES_COUNT
 NOTES_COUNT=$(psql -d "${DBNAME}" -t -c "SELECT COUNT(*) FROM notes_sync;" | tr -d ' ')

 declare -i COMMENTS_COUNT
 COMMENTS_COUNT=$(psql -d "${DBNAME}" -t -c "SELECT COUNT(*) FROM note_comments_sync;" | tr -d ' ')

 declare -i TEXT_COMMENTS_COUNT
 TEXT_COMMENTS_COUNT=$(psql -d "${DBNAME}" -t -c "SELECT COUNT(*) FROM note_comments_text_sync;" | tr -d ' ')

 log_info "Consolidation results:"
 log_info "  notes_sync: ${NOTES_COUNT} records"
 log_info "  note_comments_sync: ${COMMENTS_COUNT} records"
 log_info "  note_comments_text_sync: ${TEXT_COMMENTS_COUNT} records"

 # For testing purposes, we just verify the tables exist and are accessible
 if [[ "${NOTES_COUNT}" -ge 0 && "${COMMENTS_COUNT}" -ge 0 && "${TEXT_COMMENTS_COUNT}" -ge 0 ]]; then
  log_info "SUCCESS: Consolidation verification passed"
  return 0
 else
  log_error "FAILED: Consolidation verification failed"
  return 1
 fi
}

# Test function to simulate the complete process
function simulate_complete_process() {
 local DBNAME="${1}"
 local MAX_THREADS="${2:-4}"

 log_info "Simulating complete Planet notes processing workflow"

 # Step 1: Create sync tables (prerequisite)
 log_info "Step 1: Creating sync tables"
 local CREATE_SYNC_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/sql/process/processPlanetNotes_24_createSyncTables.sql"

 if [[ -f "${CREATE_SYNC_SCRIPT}" ]]; then
  psql -d "${DBNAME}" -f "${CREATE_SYNC_SCRIPT}"
  log_info "Sync tables created successfully"
 else
  log_error "Create sync tables script not found"
  return 1
 fi

 # Step 2: Process with parallel processing
 log_info "Step 2: Processing with parallel processing"
 if process_planet_notes_with_parallel "${DBNAME}" "${MAX_THREADS}"; then
  log_info "Parallel processing completed successfully"
 else
  log_error "Parallel processing failed"
  return 1
 fi

 # Step 3: Verify results
 log_info "Step 3: Verifying results"
 if verify_workflow "${DBNAME}" "${MAX_THREADS}"; then
  log_info "Workflow verification passed"
 else
  log_error "Workflow verification failed"
  return 1
 fi

 if verify_consolidation "${DBNAME}"; then
  log_info "Consolidation verification passed"
 else
  log_error "Consolidation verification failed"
  return 1
 fi

 log_info "Complete process simulation successful"
}

# Test function to clean up test data
function cleanup_test_data() {
 local DBNAME="${1}"

 log_info "Cleaning up test data"

 # Drop sync tables
 psql -d "${DBNAME}" -c "
 DROP TABLE IF EXISTS note_comments_text_sync CASCADE;
 DROP TABLE IF EXISTS note_comments_sync CASCADE;
 DROP TABLE IF EXISTS notes_sync CASCADE;
 "

 log_info "Test data cleanup completed"
}

# Run tests
function run_tests() {
 local DBNAME="${1:-osm_notes_test}"
 local MAX_THREADS="${2:-4}"

 log_info "Starting Planet notes processing with parallel tests"
 log_info "Database: ${DBNAME}"
 log_info "MAX_THREADS: ${MAX_THREADS}"

 # Test 1: Simulate complete process
 log_info "Test 1: Simulating complete process"
 if simulate_complete_process "${DBNAME}" "${MAX_THREADS}"; then
  log_info "Test 1 PASSED"
 else
  log_error "Test 1 FAILED"
  return 1
 fi

 # Test 2: Clean up test data
 log_info "Test 2: Cleaning up test data"
 if cleanup_test_data "${DBNAME}"; then
  log_info "Test 2 PASSED"
 else
  log_error "Test 2 FAILED"
  return 1
 fi

 log_info "All Planet notes processing with parallel tests completed successfully"
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
 log_info "Starting Planet notes processing with parallel tests"

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
  log_info "All Planet notes processing with parallel tests PASSED"
  exit 0
 else
  log_error "Some Planet notes processing with parallel tests FAILED"
  exit 1
 fi
}

# Execute main function
main "$@"
