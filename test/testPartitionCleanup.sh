#!/bin/bash

# Test script for partition cleanup functionality
# Tests that partition tables are properly dropped during cleanup
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-23

set -euo pipefail

# Define required variables
declare BASENAME="testPartitionCleanup"
declare TMP_DIR="/tmp/${BASENAME}_$$"
mkdir -p "${TMP_DIR}"

# Simple logging functions for testing
function log_info() {
 echo "$(date '+%Y-%m-%d %H:%M:%S') - INFO - $*"
}

function log_error() {
 echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR - $*" >&2
}

function log_warn() {
 echo "$(date '+%Y-%m-%d %H:%M:%S') - WARN - $*"
}

# Test function to create partition tables
function create_test_partitions() {
 local DBNAME="${1}"
 local MAX_THREADS="${2}"

 log_info "Creating test partition tables in database: ${DBNAME}"

 # Create test partition tables
 psql -d "${DBNAME}" -c "
 DO \$\$
 DECLARE
   max_threads INTEGER := ${MAX_THREADS};
   i INTEGER;
   partition_name TEXT;
 BEGIN
   -- Create partitions for notes_sync
   FOR i IN 1..max_threads LOOP
     partition_name := 'notes_sync_part_' || i;
     EXECUTE format('CREATE TABLE IF NOT EXISTS %I (
       note_id INTEGER,
       latitude DECIMAL,
       longitude DECIMAL,
       created_at TIMESTAMP,
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
       note_id INTEGER,
       sequence_action INTEGER,
       event TEXT,
       created_at TIMESTAMP,
       id_user INTEGER,
       username VARCHAR(256),
       part_id INTEGER DEFAULT %s
     )', partition_name, i);
   END LOOP;
   
   -- Create partitions for note_comments_text_sync
   FOR i IN 1..max_threads LOOP
     partition_name := 'note_comments_text_sync_part_' || i;
     EXECUTE format('CREATE TABLE IF NOT EXISTS %I (
       note_id INTEGER,
       body TEXT,
       part_id INTEGER DEFAULT %s
     )', partition_name, i);
   END LOOP;
   
   RAISE NOTICE 'Created % test partition tables', max_threads * 3;
 END \$\$;
 "
}

# Test function to verify partition tables exist
function verify_partitions_exist() {
 local DBNAME="${1}"
 local MAX_THREADS="${2}"
 declare -i EXPECTED_COUNT=$((MAX_THREADS * 3))

 log_info "Verifying that ${EXPECTED_COUNT} partition tables exist"

 declare -i ACTUAL_COUNT
 ACTUAL_COUNT=$(psql -d "${DBNAME}" -t -c "
 SELECT COUNT(*) FROM information_schema.tables 
 WHERE table_name LIKE '%_part_%' 
 AND table_name IN (
   'notes_sync_part_1', 'notes_sync_part_2', 'notes_sync_part_3', 'notes_sync_part_4',
   'note_comments_sync_part_1', 'note_comments_sync_part_2', 'note_comments_sync_part_3', 'note_comments_sync_part_4',
   'note_comments_text_sync_part_1', 'note_comments_text_sync_part_2', 'note_comments_text_sync_part_3', 'note_comments_text_sync_part_4'
 );
 " | tr -d ' ')

 if [[ "${ACTUAL_COUNT}" -eq "${EXPECTED_COUNT}" ]]; then
  log_info "SUCCESS: Found ${ACTUAL_COUNT} partition tables (expected: ${EXPECTED_COUNT})"
  return 0
 else
  log_error "FAILED: Found ${ACTUAL_COUNT} partition tables (expected: ${EXPECTED_COUNT})"
  return 1
 fi
}

# Test function to run cleanup script
function run_cleanup_script() {
 local DBNAME="${1}"
 local SCRIPT_FILE="${2}"

 log_info "Running cleanup script: ${SCRIPT_FILE}"

 psql -d "${DBNAME}" -f "${SCRIPT_FILE}"

 if [[ ${?} -eq 0 ]]; then
  log_info "SUCCESS: Cleanup script executed successfully"
  return 0
 else
  log_error "FAILED: Cleanup script execution failed"
  return 1
 fi
}

# Test function to verify partition tables are dropped
function verify_partitions_dropped() {
 local DBNAME="${1}"

 log_info "Verifying that all partition tables have been dropped"

 declare -i REMAINING_COUNT
 REMAINING_COUNT=$(psql -d "${DBNAME}" -t -c "
 SELECT COUNT(*) FROM information_schema.tables 
 WHERE table_name LIKE '%_part_%' 
 AND table_name IN (
   'notes_sync_part_1', 'notes_sync_part_2', 'notes_sync_part_3', 'notes_sync_part_4',
   'note_comments_sync_part_1', 'note_comments_sync_part_2', 'note_comments_sync_part_3', 'note_comments_sync_part_4',
   'note_comments_text_sync_part_1', 'note_comments_text_sync_part_2', 'note_comments_text_sync_part_3', 'note_comments_text_sync_part_4'
 );
 " | tr -d ' ')

 if [[ "${REMAINING_COUNT}" -eq 0 ]]; then
  log_info "SUCCESS: All partition tables have been dropped"
  return 0
 else
  log_error "FAILED: ${REMAINING_COUNT} partition tables still exist"
  return 1
 fi
}

# Run tests
function run_tests() {
 local DBNAME="${1:-osm_notes_test}"
 local MAX_THREADS="${2:-4}"
 local SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

 log_info "Starting partition cleanup tests"
 log_info "Database: ${DBNAME}"
 log_info "Max threads: ${MAX_THREADS}"

 # Test 1: Create partition tables
 log_info "Test 1: Creating test partition tables"
 if create_test_partitions "${DBNAME}" "${MAX_THREADS}"; then
  log_info "Test 1 PASSED"
 else
  log_error "Test 1 FAILED"
  return 1
 fi

 # Test 2: Verify partitions exist
 log_info "Test 2: Verifying partition tables exist"
 if verify_partitions_exist "${DBNAME}" "${MAX_THREADS}"; then
  log_info "Test 2 PASSED"
 else
  log_error "Test 2 FAILED"
  return 1
 fi

 # Test 3: Run cleanup script
 log_info "Test 3: Running cleanup script"
 local CLEANUP_SCRIPT="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_11_dropSyncTables.sql"
 if run_cleanup_script "${DBNAME}" "${CLEANUP_SCRIPT}"; then
  log_info "Test 3 PASSED"
 else
  log_error "Test 3 FAILED"
  return 1
 fi

 # Test 4: Verify partitions are dropped
 log_info "Test 4: Verifying partition tables are dropped"
 if verify_partitions_dropped "${DBNAME}"; then
  log_info "Test 4 PASSED"
 else
  log_error "Test 4 FAILED"
  return 1
 fi

 log_info "All partition cleanup tests completed successfully"
}

# Cleanup function
function cleanup() {
 if [[ -d "${TMP_DIR}" ]]; then
  rm -rf "${TMP_DIR}"
 fi
}

# Main execution
function main() {
 log_info "Starting partition cleanup tests"

 # Set up cleanup trap
 trap cleanup EXIT

 # Check if database name is provided
 local DBNAME="${1:-}"
 if [[ -z "${DBNAME}" ]]; then
  log_error "Usage: $0 <database_name> [max_threads]"
  log_error "Example: $0 osm_notes_test 4"
  exit 1
 fi

 local MAX_THREADS="${2:-4}"

 # Run tests
 if run_tests "${DBNAME}" "${MAX_THREADS}"; then
  log_info "All partition cleanup tests PASSED"
  exit 0
 else
  log_error "Some partition cleanup tests FAILED"
  exit 1
 fi
}

# Execute main function
main "$@"


