#!/bin/bash

# Test script for moving data from sync tables to main tables
# Tests that data is correctly moved from sync to main tables
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-23

set -euo pipefail

# Define required variables
declare BASENAME="testMoveSyncToMain"
declare TMP_DIR="/tmp/${BASENAME}_$$"
mkdir -p "${TMP_DIR}"

# Simple logging functions for testing
function log_info() {
 echo "$(date '+%Y-%m-%d %H:%M:%S') - INFO - $*"
}

function log_error() {
 echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR - $*" >&2
}

# Test function to create main tables
function create_main_tables() {
 local DBNAME="${1}"
 local SCRIPT_BASE_DIRECTORY
 SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

 log_info "Creating main tables"

 # Create base tables first
 local CREATE_BASE_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_22_createBaseTables_tables.sql"

 if [[ -f "${CREATE_BASE_TABLES}" ]]; then
  psql -d "${DBNAME}" -f "${CREATE_BASE_TABLES}"
  log_info "Main tables created successfully"
 else
  log_error "Create base tables script not found"
  return 1
 fi
}

# Test function to create sync tables
function create_sync_tables() {
 local DBNAME="${1}"
 local SCRIPT_BASE_DIRECTORY
 SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

 log_info "Creating sync tables"

 local CREATE_SYNC_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_24_createSyncTables.sql"

 if [[ -f "${CREATE_SYNC_TABLES}" ]]; then
  psql -d "${DBNAME}" -f "${CREATE_SYNC_TABLES}"
  log_info "Sync tables created successfully"
 else
  log_error "Create sync tables script not found"
  return 1
 fi
}

# Test function to insert sample data into sync tables
function insert_sample_sync_data() {
 local DBNAME="${1}"

 log_info "Inserting sample data into sync tables"

 # Insert sample data into notes_sync
 psql -d "${DBNAME}" -c "
 INSERT INTO notes_sync (note_id, latitude, longitude, created_at, status, closed_at, id_country) VALUES
 (123, 40.7128, -74.0060, '2013-04-28T02:39:27Z', 'close', '2013-04-29T10:15:30Z', NULL),
 (456, 34.0522, -118.2437, '2013-04-30T15:20:45Z', 'open', NULL, NULL),
 (789, 51.5074, -0.1278, '2013-05-01T12:30:15Z', 'close', '2013-05-02T09:45:20Z', NULL);
 "

 # Insert sample data into note_comments_sync
 psql -d "${DBNAME}" -c "
 INSERT INTO note_comments_sync (id, note_id, sequence_action, event, created_at, id_user, username) VALUES
 (1, 123, 1, 'opened', '2013-04-28T02:39:27Z', 123, 'user1'),
 (2, 123, 2, 'closed', '2013-04-29T10:15:30Z', 456, 'user2'),
 (3, 456, 1, 'opened', '2013-04-30T15:20:45Z', 789, 'user3'),
 (4, 789, 1, 'opened', '2013-05-01T12:30:15Z', 123, 'user1'),
 (5, 789, 2, 'closed', '2013-05-02T09:45:20Z', 456, 'user2');
 "

 # Insert sample data into note_comments_text_sync
 psql -d "${DBNAME}" -c "
 INSERT INTO note_comments_text_sync (note_id, body) VALUES
 (123, 'This is a test comment for note 123'),
 (456, 'This is a test comment for note 456'),
 (789, 'This is a test comment for note 789');
 "

 log_info "Sample data inserted into sync tables"
}

# Test function to move data from sync to main
function move_sync_to_main() {
 local DBNAME="${1}"
 local SCRIPT_BASE_DIRECTORY
 SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

 log_info "Moving data from sync tables to main tables"

 local MOVE_SYNC_SCRIPT="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_43_moveSyncToMain.sql"

 if [[ ! -f "${MOVE_SYNC_SCRIPT}" ]]; then
  log_error "Move sync to main script not found: ${MOVE_SYNC_SCRIPT}"
  return 1
 fi

 psql -d "${DBNAME}" -f "${MOVE_SYNC_SCRIPT}"

 log_info "Data moved from sync to main tables"
}

# Test function to verify data was moved correctly
function verify_data_movement() {
 local DBNAME="${1}"

 log_info "Verifying data movement from sync to main tables"

 # Check notes count
 declare -i SYNC_NOTES_COUNT
 SYNC_NOTES_COUNT=$(psql -d "${DBNAME}" -t -c "SELECT COUNT(*) FROM notes_sync;" | tr -d ' ')

 declare -i MAIN_NOTES_COUNT
 MAIN_NOTES_COUNT=$(psql -d "${DBNAME}" -t -c "SELECT COUNT(*) FROM notes;" | tr -d ' ')

 # Check comments count
 declare -i SYNC_COMMENTS_COUNT
 SYNC_COMMENTS_COUNT=$(psql -d "${DBNAME}" -t -c "SELECT COUNT(*) FROM note_comments_sync;" | tr -d ' ')

 declare -i MAIN_COMMENTS_COUNT
 MAIN_COMMENTS_COUNT=$(psql -d "${DBNAME}" -t -c "SELECT COUNT(*) FROM note_comments;" | tr -d ' ')

 # Check text comments count
 declare -i SYNC_TEXT_COMMENTS_COUNT
 SYNC_TEXT_COMMENTS_COUNT=$(psql -d "${DBNAME}" -t -c "SELECT COUNT(*) FROM note_comments_text_sync;" | tr -d ' ')

 declare -i MAIN_TEXT_COMMENTS_COUNT
 MAIN_TEXT_COMMENTS_COUNT=$(psql -d "${DBNAME}" -t -c "SELECT COUNT(*) FROM note_comments_text;" | tr -d ' ')

 log_info "Data movement results:"
 log_info "  notes_sync: ${SYNC_NOTES_COUNT} records"
 log_info "  notes: ${MAIN_NOTES_COUNT} records"
 log_info "  note_comments_sync: ${SYNC_COMMENTS_COUNT} records"
 log_info "  note_comments: ${MAIN_COMMENTS_COUNT} records"
 log_info "  note_comments_text_sync: ${SYNC_TEXT_COMMENTS_COUNT} records"
 log_info "  note_comments_text: ${MAIN_TEXT_COMMENTS_COUNT} records"

 # Verify that data was moved correctly
 if [[ "${SYNC_NOTES_COUNT}" -eq "${MAIN_NOTES_COUNT}" &&
  "${SYNC_COMMENTS_COUNT}" -eq "${MAIN_COMMENTS_COUNT}" &&
  "${SYNC_TEXT_COMMENTS_COUNT}" -eq "${MAIN_TEXT_COMMENTS_COUNT}" ]]; then
  log_info "SUCCESS: All data moved correctly from sync to main tables"
  return 0
 else
  log_error "FAILED: Data movement verification failed"
  return 1
 fi
}

# Test function to verify specific data integrity
function verify_data_integrity() {
 local DBNAME="${1}"

 log_info "Verifying data integrity"

 # Check specific note data
 declare -i NOTE_123_EXISTS
 NOTE_123_EXISTS=$(psql -d "${DBNAME}" -t -c "
 SELECT COUNT(*) FROM notes WHERE note_id = 123;
 " | tr -d ' ')

 declare -i NOTE_456_EXISTS
 NOTE_456_EXISTS=$(psql -d "${DBNAME}" -t -c "
 SELECT COUNT(*) FROM notes WHERE note_id = 456;
 " | tr -d ' ')

 declare -i NOTE_789_EXISTS
 NOTE_789_EXISTS=$(psql -d "${DBNAME}" -t -c "
 SELECT COUNT(*) FROM notes WHERE note_id = 789;
 " | tr -d ' ')

 # Check specific comment data
 declare -i COMMENT_1_EXISTS
 COMMENT_1_EXISTS=$(psql -d "${DBNAME}" -t -c "
 SELECT COUNT(*) FROM note_comments WHERE id = 1;
 " | tr -d ' ')

 # Check specific text comment data
 declare -i TEXT_COMMENT_123_EXISTS
 TEXT_COMMENT_123_EXISTS=$(psql -d "${DBNAME}" -t -c "
 SELECT COUNT(*) FROM note_comments_text WHERE note_id = 123;
 " | tr -d ' ')

 log_info "Data integrity check:"
 log_info "  Note 123 exists: ${NOTE_123_EXISTS}"
 log_info "  Note 456 exists: ${NOTE_456_EXISTS}"
 log_info "  Note 789 exists: ${NOTE_789_EXISTS}"
 log_info "  Comment 1 exists: ${COMMENT_1_EXISTS}"
 log_info "  Text comment for note 123 exists: ${TEXT_COMMENT_123_EXISTS}"

 if [[ "${NOTE_123_EXISTS}" -eq 1 &&
  "${NOTE_456_EXISTS}" -eq 1 &&
  "${NOTE_789_EXISTS}" -eq 1 &&
  "${COMMENT_1_EXISTS}" -eq 1 &&
  "${TEXT_COMMENT_123_EXISTS}" -eq 1 ]]; then
  log_info "SUCCESS: Data integrity verification passed"
  return 0
 else
  log_error "FAILED: Data integrity verification failed"
  return 1
 fi
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

 # Drop main tables
 psql -d "${DBNAME}" -c "
 DROP TABLE IF EXISTS note_comments_text CASCADE;
 DROP TABLE IF EXISTS note_comments CASCADE;
 DROP TABLE IF EXISTS notes CASCADE;
 "

 log_info "Test data cleanup completed"
}

# Run tests
function run_tests() {
 local DBNAME="${1:-osm_notes_test}"

 log_info "Starting move sync to main tests"
 log_info "Database: ${DBNAME}"

 # Test 1: Create tables
 log_info "Test 1: Creating tables"
 if create_main_tables "${DBNAME}"; then
  log_info "Test 1 PASSED"
 else
  log_error "Test 1 FAILED"
  return 1
 fi

 if create_sync_tables "${DBNAME}"; then
  log_info "Test 1 PASSED"
 else
  log_error "Test 1 FAILED"
  return 1
 fi

 # Test 2: Insert sample data
 log_info "Test 2: Inserting sample data"
 if insert_sample_sync_data "${DBNAME}"; then
  log_info "Test 2 PASSED"
 else
  log_error "Test 2 FAILED"
  return 1
 fi

 # Test 3: Move data from sync to main
 log_info "Test 3: Moving data from sync to main"
 if move_sync_to_main "${DBNAME}"; then
  log_info "Test 3 PASSED"
 else
  log_error "Test 3 FAILED"
  return 1
 fi

 # Test 4: Verify data movement
 log_info "Test 4: Verifying data movement"
 if verify_data_movement "${DBNAME}"; then
  log_info "Test 4 PASSED"
 else
  log_error "Test 4 FAILED"
  return 1
 fi

 # Test 5: Verify data integrity
 log_info "Test 5: Verifying data integrity"
 if verify_data_integrity "${DBNAME}"; then
  log_info "Test 5 PASSED"
 else
  log_error "Test 5 FAILED"
  return 1
 fi

 # Test 6: Clean up test data
 log_info "Test 6: Cleaning up test data"
 if cleanup_test_data "${DBNAME}"; then
  log_info "Test 6 PASSED"
 else
  log_error "Test 6 FAILED"
  return 1
 fi

 log_info "All move sync to main tests completed successfully"
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
 log_info "Starting move sync to main tests"

 # Set up cleanup trap
 trap cleanup EXIT

 # Check if database name is provided
 local DBNAME="${1:-}"

 if [[ -z "${DBNAME}" ]]; then
  log_error "Usage: $0 <database_name>"
  log_error "Example: $0 osm_notes_test"
  exit 1
 fi

 # Run tests
 if run_tests "${DBNAME}"; then
  log_info "All move sync to main tests PASSED"
  exit 0
 else
  log_error "Some move sync to main tests FAILED"
  exit 1
 fi
}

# Execute main function
main "$@"
