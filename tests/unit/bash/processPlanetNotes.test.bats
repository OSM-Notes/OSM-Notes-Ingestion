#!/usr/bin/env bats

# Unit tests for processPlanetNotes.sh
# Author: Andres Gomez (AngocA)
# Version: 2025-07-20

load "$(dirname "$BATS_TEST_FILENAME")/../../test_helper.bash"

@test "processPlanetNotes script should exist" {
  # Check if the script file exists
  [ -f "${TEST_BASE_DIR}/bin/process/processPlanetNotes.sh" ]
}

@test "processPlanetNotes script should be executable" {
  # Check if the script is executable
  [ -x "${TEST_BASE_DIR}/bin/process/processPlanetNotes.sh" ]
}

@test "processPlanetNotes should exit with error for invalid parameters" {
  # Test that script exits with error for invalid parameters
  run bash "bin/process/processPlanetNotes.sh" --invalid
  [ "$status" -ne 0 ]
}

@test "processPlanetNotes should exit with error for help parameters" {
  # Test that script exits with error for help parameters
  run bash "bin/process/processPlanetNotes.sh" -h
  [ "$status" -eq 1 ]
  
  run bash "bin/process/processPlanetNotes.sh" --help
  [ "$status" -eq 1 ]
}

@test "SQL files should exist" {
  # Check if required SQL files exist
  [ -f "${TEST_BASE_DIR}/sql/process/processPlanetNotes_11_dropSyncTables.sql" ]
  [ -f "${TEST_BASE_DIR}/sql/process/processPlanetNotes_21_createBaseTables_enum.sql" ]
  [ -f "${TEST_BASE_DIR}/sql/process/processPlanetNotes_22_createBaseTables_tables.sql" ]
  [ -f "${TEST_BASE_DIR}/sql/process/processPlanetNotes_23_createBaseTables_constraints.sql" ]
  [ -f "${TEST_BASE_DIR}/sql/process/processPlanetNotes_24_createSyncTables.sql" ]
  [ -f "${TEST_BASE_DIR}/sql/process/processPlanetNotes_25_createPartitions.sql" ]
  [ -f "${TEST_BASE_DIR}/sql/process/processPlanetNotes_42_consolidatePartitions.sql" ]
  [ -f "${TEST_BASE_DIR}/sql/process/processPlanetNotes_43_moveSyncToMain.sql" ]
}

@test "XSLT files should exist" {
  # Check if required XSLT files exist
  [ -f "${TEST_BASE_DIR}/xslt/notes-Planet-csv.xslt" ]
  [ -f "${TEST_BASE_DIR}/xslt/note_comments-Planet-csv.xslt" ]
  [ -f "${TEST_BASE_DIR}/xslt/note_comments_text-Planet-csv.xslt" ]
}

@test "XML schema files should exist" {
  # Check if required XML schema files exist
  [ -f "${TEST_BASE_DIR}/xsd/OSM-notes-planet-schema.xsd" ]
}

@test "test database should be created for processPlanetNotes" {
  # Test database creation
  run create_test_database
  [ "$status" -eq 0 ]
  
  # Clean up
  run drop_test_database
  [ "$status" -eq 0 ]
}

@test "base tables can be created" {
  # Create test database
  create_test_database
  
  # Create enums first (ignore errors if they already exist)
  mock_psql -d "${TEST_DBNAME}" -f "sql/process/processPlanetNotes_21_createBaseTables_enum.sql" 2>/dev/null || true
  
  # Then create tables (ignore notices about existing tables)
  mock_psql -d "${TEST_DBNAME}" -f "sql/process/processPlanetNotes_22_createBaseTables_tables.sql" 2>/dev/null || true
  
  # Check if tables were created
  table_exists "notes" "${TEST_DBNAME}"
  [ $? -eq 0 ]
  
  table_exists "note_comments" "${TEST_DBNAME}"
  [ $? -eq 0 ]
  
  table_exists "note_comments_text" "${TEST_DBNAME}"
  [ $? -eq 0 ]
  
  table_exists "users" "${TEST_DBNAME}"
  [ $? -eq 0 ]
  
  # Clean up
  drop_test_database
}

@test "sync tables can be created" {
  # Create test database
  create_test_database
  
  # Create enums first (ignore errors if they already exist)
  mock_psql -d "${TEST_DBNAME}" -f "sql/process/processPlanetNotes_21_createBaseTables_enum.sql" 2>/dev/null || true
  
  # Create base tables first
  mock_psql -d "${TEST_DBNAME}" -f "sql/process/processPlanetNotes_22_createBaseTables_tables.sql" 2>/dev/null || true
  
  # Try to create sync tables (ignore notices about existing tables)
  mock_psql -d "${TEST_DBNAME}" -f "sql/process/processPlanetNotes_24_createSyncTables.sql" 2>/dev/null || true
  
  # Check if sync tables were created
  table_exists "notes_sync" "${TEST_DBNAME}"
  [ $? -eq 0 ]
  
  table_exists "note_comments_sync" "${TEST_DBNAME}"
  [ $? -eq 0 ]
  
  table_exists "note_comments_text_sync" "${TEST_DBNAME}"
  [ $? -eq 0 ]
  
  # Clean up
  drop_test_database
} 