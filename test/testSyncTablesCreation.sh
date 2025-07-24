#!/bin/bash

# Test script for sync tables creation
# Tests that all sync tables are created correctly
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-23

set -euo pipefail

# Define required variables
declare BASENAME="testSyncTablesCreation"
declare TMP_DIR="/tmp/${BASENAME}_$$"
mkdir -p "${TMP_DIR}"

# Simple logging functions for testing
function log_info() {
 echo "$(date '+%Y-%m-%d %H:%M:%S') - INFO - $*"
}

function log_error() {
 echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR - $*" >&2
}

# Test function to create sync tables
function create_sync_tables() {
 local DBNAME="${1}"
 local SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
 local CREATE_SYNC_SCRIPT="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_24_createSyncTables.sql"

 log_info "Creating sync tables using script: ${CREATE_SYNC_SCRIPT}"

 if [[ ! -f "${CREATE_SYNC_SCRIPT}" ]]; then
  log_error "Create sync tables script not found: ${CREATE_SYNC_SCRIPT}"
  return 1
 fi

 psql -d "${DBNAME}" -f "${CREATE_SYNC_SCRIPT}"

 log_info "Sync tables creation completed"
}

# Test function to verify sync tables exist
function verify_sync_tables() {
 local DBNAME="${1}"

 log_info "Verifying that all sync tables exist"

 # Check each table
 declare TABLES=("notes_sync" "note_comments_sync" "note_comments_text_sync")
 declare ALL_EXIST=true

 for table in "${TABLES[@]}"; do
  declare -i EXISTS
  EXISTS=$(psql -d "${DBNAME}" -t -c "
  SELECT COUNT(*) FROM information_schema.tables 
  WHERE table_name = '${table}';
  " | tr -d ' ')

  if [[ "${EXISTS}" -eq 1 ]]; then
   log_info "✓ Table ${table} exists"
  else
   log_error "✗ Table ${table} does not exist"
   ALL_EXIST=false
  fi
 done

 if [[ "${ALL_EXIST}" == true ]]; then
  log_info "SUCCESS: All sync tables exist"
  return 0
 else
  log_error "FAILED: Some sync tables are missing"
  return 1
 fi
}

# Test function to verify table structure
function verify_table_structure() {
 local DBNAME="${1}"

 log_info "Verifying table structure"

 # Check notes_sync structure
 log_info "Checking notes_sync structure:"
 psql -d "${DBNAME}" -c "
 SELECT column_name, data_type, is_nullable 
 FROM information_schema.columns 
 WHERE table_name = 'notes_sync' 
 ORDER BY ordinal_position;
 "

 # Check note_comments_sync structure
 log_info "Checking note_comments_sync structure:"
 psql -d "${DBNAME}" -c "
 SELECT column_name, data_type, is_nullable 
 FROM information_schema.columns 
 WHERE table_name = 'note_comments_sync' 
 ORDER BY ordinal_position;
 "

 # Check note_comments_text_sync structure
 log_info "Checking note_comments_text_sync structure:"
 psql -d "${DBNAME}" -c "
 SELECT column_name, data_type, is_nullable 
 FROM information_schema.columns 
 WHERE table_name = 'note_comments_text_sync' 
 ORDER BY ordinal_position;
 "

 log_info "Table structure verification completed"
}

# Test function to insert sample data
function test_sample_data() {
 local DBNAME="${1}"

 log_info "Testing sample data insertion"

 # Insert sample data into notes_sync
 psql -d "${DBNAME}" -c "
 INSERT INTO notes_sync (note_id, latitude, longitude, created_at, status, closed_at, id_country) VALUES
 (123, 40.7128, -74.0060, '2013-04-28T02:39:27Z', 'close', '2013-04-29T10:15:30Z', NULL),
 (456, 34.0522, -118.2437, '2013-04-30T15:20:45Z', 'open', NULL, NULL);
 "

 # Insert sample data into note_comments_sync
 psql -d "${DBNAME}" -c "
 INSERT INTO note_comments_sync (note_id, sequence_action, event, created_at, id_user, username) VALUES
 (123, 1, 'opened', '2013-04-28T02:39:27Z', 123, 'user1'),
 (123, 2, 'closed', '2013-04-29T10:15:30Z', 456, 'user2');
 "

 # Insert sample data into note_comments_text_sync
 psql -d "${DBNAME}" -c "
 INSERT INTO note_comments_text_sync (note_id, body) VALUES
 (123, 'This is a test comment'),
 (456, 'Another test comment');
 "

 # Verify data was inserted
 declare -i NOTES_COUNT
 NOTES_COUNT=$(psql -d "${DBNAME}" -t -c "SELECT COUNT(*) FROM notes_sync;" | tr -d ' ')

 declare -i COMMENTS_COUNT
 COMMENTS_COUNT=$(psql -d "${DBNAME}" -t -c "SELECT COUNT(*) FROM note_comments_sync;" | tr -d ' ')

 declare -i TEXT_COMMENTS_COUNT
 TEXT_COMMENTS_COUNT=$(psql -d "${DBNAME}" -t -c "SELECT COUNT(*) FROM note_comments_text_sync;" | tr -d ' ')

 log_info "Sample data inserted:"
 log_info "  notes_sync: ${NOTES_COUNT} records"
 log_info "  note_comments_sync: ${COMMENTS_COUNT} records"
 log_info "  note_comments_text_sync: ${TEXT_COMMENTS_COUNT} records"

 if [[ "${NOTES_COUNT}" -eq 2 && "${COMMENTS_COUNT}" -eq 2 && "${TEXT_COMMENTS_COUNT}" -eq 2 ]]; then
  log_info "SUCCESS: All sample data inserted correctly"
  return 0
 else
  log_error "FAILED: Sample data insertion failed"
  return 1
 fi
}

# Run tests
function run_tests() {
 local DBNAME="${1:-osm_notes_test}"

 log_info "Starting sync tables creation tests"
 log_info "Database: ${DBNAME}"

 # Test 1: Create sync tables
 log_info "Test 1: Creating sync tables"
 if create_sync_tables "${DBNAME}"; then
  log_info "Test 1 PASSED"
 else
  log_error "Test 1 FAILED"
  return 1
 fi

 # Test 2: Verify tables exist
 log_info "Test 2: Verifying tables exist"
 if verify_sync_tables "${DBNAME}"; then
  log_info "Test 2 PASSED"
 else
  log_error "Test 2 FAILED"
  return 1
 fi

 # Test 3: Verify table structure
 log_info "Test 3: Verifying table structure"
 if verify_table_structure "${DBNAME}"; then
  log_info "Test 3 PASSED"
 else
  log_error "Test 3 FAILED"
  return 1
 fi

 # Test 4: Test sample data
 log_info "Test 4: Testing sample data insertion"
 if test_sample_data "${DBNAME}"; then
  log_info "Test 4 PASSED"
 else
  log_error "Test 4 FAILED"
  return 1
 fi

 log_info "All sync tables creation tests completed successfully"
}

# Cleanup function
function cleanup() {
 if [[ -d "${TMP_DIR}" ]]; then
  rm -rf "${TMP_DIR}"
 fi
}

# Main execution
function main() {
 log_info "Starting sync tables creation tests"

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
  log_info "All sync tables creation tests PASSED"
  exit 0
 else
  log_error "Some sync tables creation tests FAILED"
  exit 1
 fi
}

# Execute main function
main "$@"
