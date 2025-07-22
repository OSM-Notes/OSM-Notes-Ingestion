#!/bin/bash

# Test script for consolidation script
# Tests that the consolidation script correctly merges partition data
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-20

set -euo pipefail

# Define required variables
BASENAME="testConsolidationScript"
TMP_DIR="/tmp/${BASENAME}_$$"
mkdir -p "${TMP_DIR}"

# Simple logging functions for testing
function log_info() {
 echo "$(date '+%Y-%m-%d %H:%M:%S') - INFO - $*"
}

function log_error() {
 echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR - $*" >&2
}

# Test function to create sample partition tables
function create_sample_partitions() {
 local DBNAME="${1}"
 local MAX_THREADS="${2}"

 log_info "Creating sample partition tables in database: ${DBNAME} with ${MAX_THREADS} threads"

 # Create main sync tables first
 psql -d "${DBNAME}" -c "
 CREATE TABLE IF NOT EXISTS notes_sync (
   note_id INTEGER NOT NULL,
   latitude DECIMAL NOT NULL,
   longitude DECIMAL NOT NULL,
   created_at TIMESTAMP NOT NULL,
   status TEXT,
   closed_at TIMESTAMP,
   id_country INTEGER
 );
 
 CREATE TABLE IF NOT EXISTS note_comments_sync (
   id SERIAL,
   note_id INTEGER NOT NULL,
   sequence_action INTEGER,
   event TEXT NOT NULL,
   created_at TIMESTAMP NOT NULL,
   id_user INTEGER,
   username VARCHAR(256)
 );
 
 CREATE TABLE IF NOT EXISTS note_comments_text_sync (
   note_id INTEGER NOT NULL,
   body TEXT
 );
 "

 # Create partition tables with sample data
 for i in $(seq 1 "${MAX_THREADS}"); do
  log_info "Creating partition ${i} with sample data"

  # Create notes partition
  psql -d "${DBNAME}" -c "
  CREATE TABLE IF NOT EXISTS notes_sync_part_${i} (
    note_id INTEGER NOT NULL,
    latitude DECIMAL NOT NULL,
    longitude DECIMAL NOT NULL,
    created_at TIMESTAMP NOT NULL,
    status TEXT,
    closed_at TIMESTAMP,
    id_country INTEGER,
    part_id INTEGER DEFAULT ${i}
  );
  
  INSERT INTO notes_sync_part_${i} (note_id, latitude, longitude, created_at, status, closed_at, id_country, part_id) VALUES
  (${i}00, 40.7128, -74.0060, '2013-04-28T02:39:27Z', 'close', '2013-04-29T10:15:30Z', NULL, ${i}),
  (${i}01, 34.0522, -118.2437, '2013-04-30T15:20:45Z', 'open', NULL, NULL, ${i});
  "

  # Create comments partition
  psql -d "${DBNAME}" -c "
  CREATE TABLE IF NOT EXISTS note_comments_sync_part_${i} (
    id SERIAL,
    note_id INTEGER NOT NULL,
    sequence_action INTEGER,
    event TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL,
    id_user INTEGER,
    username VARCHAR(256),
    part_id INTEGER DEFAULT ${i}
  );
  
  INSERT INTO note_comments_sync_part_${i} (note_id, sequence_action, event, created_at, id_user, username, part_id) VALUES
  (${i}00, 1, 'opened', '2013-04-28T02:39:27Z', 123, 'user1', ${i}),
  (${i}00, 2, 'closed', '2013-04-29T10:15:30Z', 456, 'user2', ${i});
  "

  # Create text comments partition
  psql -d "${DBNAME}" -c "
  CREATE TABLE IF NOT EXISTS note_comments_text_sync_part_${i} (
    note_id INTEGER NOT NULL,
    body TEXT,
    part_id INTEGER DEFAULT ${i}
  );
  
  INSERT INTO note_comments_text_sync_part_${i} (note_id, body, part_id) VALUES
  (${i}00, 'This is a test comment', ${i}),
  (${i}01, 'Another test comment', ${i});
  "
 done

 log_info "Sample partition tables created with data"
}

# Test function to run consolidation script
function run_consolidation() {
 local DBNAME="${1}"
 local MAX_THREADS="${2}"
 local SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
 local CONSOLIDATION_SCRIPT="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_42_consolidatePartitions.sql"

 log_info "Running consolidation script: ${CONSOLIDATION_SCRIPT}"

 if [[ ! -f "${CONSOLIDATION_SCRIPT}" ]]; then
  log_error "Consolidation script not found: ${CONSOLIDATION_SCRIPT}"
  return 1
 fi

 # Run consolidation with MAX_THREADS set
 psql -d "${DBNAME}" -c "SET app.max_threads = '${MAX_THREADS}';" -f "${CONSOLIDATION_SCRIPT}"

 log_info "Consolidation script completed"
}

# Test function to verify consolidation results
function verify_consolidation() {
 local DBNAME="${1}"
 local MAX_THREADS="${2}"

 log_info "Verifying consolidation results"

 # Check notes_sync
 local NOTES_COUNT
 NOTES_COUNT=$(psql -d "${DBNAME}" -t -c "SELECT COUNT(*) FROM notes_sync;" | tr -d ' ')
 local EXPECTED_NOTES=$((MAX_THREADS * 2)) # 2 notes per partition

 log_info "Notes_sync: ${NOTES_COUNT} records (expected: ${EXPECTED_NOTES})"

 if [[ "${NOTES_COUNT}" -eq "${EXPECTED_NOTES}" ]]; then
  log_info "✓ Notes consolidation successful"
 else
  log_error "✗ Notes consolidation failed"
  return 1
 fi

 # Check note_comments_sync
 local COMMENTS_COUNT
 COMMENTS_COUNT=$(psql -d "${DBNAME}" -t -c "SELECT COUNT(*) FROM note_comments_sync;" | tr -d ' ')
 local EXPECTED_COMMENTS=$((MAX_THREADS * 2)) # 2 comments per partition

 log_info "Note_comments_sync: ${COMMENTS_COUNT} records (expected: ${EXPECTED_COMMENTS})"

 if [[ "${COMMENTS_COUNT}" -eq "${EXPECTED_COMMENTS}" ]]; then
  log_info "✓ Comments consolidation successful"
 else
  log_error "✗ Comments consolidation failed"
  return 1
 fi

 # Check note_comments_text_sync
 local TEXT_COMMENTS_COUNT
 TEXT_COMMENTS_COUNT=$(psql -d "${DBNAME}" -t -c "SELECT COUNT(*) FROM note_comments_text_sync;" | tr -d ' ')
 local EXPECTED_TEXT_COMMENTS=$((MAX_THREADS * 2)) # 2 text comments per partition

 log_info "Note_comments_text_sync: ${TEXT_COMMENTS_COUNT} records (expected: ${EXPECTED_TEXT_COMMENTS})"

 if [[ "${TEXT_COMMENTS_COUNT}" -eq "${EXPECTED_TEXT_COMMENTS}" ]]; then
  log_info "✓ Text comments consolidation successful"
 else
  log_error "✗ Text comments consolidation failed"
  return 1
 fi

 # Check that partition tables are cleaned up
 local PARTITION_COUNT
 PARTITION_COUNT=$(psql -d "${DBNAME}" -t -c "
 SELECT COUNT(*) FROM information_schema.tables 
 WHERE table_name LIKE '%_part_%';
 " | tr -d ' ')

 if [[ "${PARTITION_COUNT}" -eq 0 ]]; then
  log_info "✓ All partition tables cleaned up"
 else
  log_warn "⚠ ${PARTITION_COUNT} partition tables still exist"
 fi

 log_info "SUCCESS: All consolidation verifications passed"
 return 0
}

# Run tests
function run_tests() {
 local DBNAME="${1:-osm_notes_test}"
 local MAX_THREADS="${2:-3}"

 log_info "Starting consolidation script tests"
 log_info "Database: ${DBNAME}"
 log_info "Max threads: ${MAX_THREADS}"

 # Test 1: Create sample partition tables
 log_info "Test 1: Creating sample partition tables"
 if create_sample_partitions "${DBNAME}" "${MAX_THREADS}"; then
  log_info "Test 1 PASSED"
 else
  log_error "Test 1 FAILED"
  return 1
 fi

 # Test 2: Run consolidation script
 log_info "Test 2: Running consolidation script"
 if run_consolidation "${DBNAME}" "${MAX_THREADS}"; then
  log_info "Test 2 PASSED"
 else
  log_error "Test 2 FAILED"
  return 1
 fi

 # Test 3: Verify consolidation results
 log_info "Test 3: Verifying consolidation results"
 if verify_consolidation "${DBNAME}" "${MAX_THREADS}"; then
  log_info "Test 3 PASSED"
 else
  log_error "Test 3 FAILED"
  return 1
 fi

 log_info "All consolidation script tests completed successfully"
}

# Cleanup function
function cleanup() {
 if [[ -d "${TMP_DIR}" ]]; then
  rm -rf "${TMP_DIR}"
 fi
}

# Main execution
function main() {
 log_info "Starting consolidation script tests"

 # Set up cleanup trap
 trap cleanup EXIT

 # Check if database name is provided
 local DBNAME="${1:-}"
 if [[ -z "${DBNAME}" ]]; then
  log_error "Usage: $0 <database_name> [max_threads]"
  log_error "Example: $0 osm_notes_test 3"
  exit 1
 fi

 local MAX_THREADS="${2:-3}"

 # Run tests
 if run_tests "${DBNAME}" "${MAX_THREADS}"; then
  log_info "All consolidation script tests PASSED"
  exit 0
 else
  log_error "Some consolidation script tests FAILED"
  exit 1
 fi
}

# Execute main function
main "$@"
