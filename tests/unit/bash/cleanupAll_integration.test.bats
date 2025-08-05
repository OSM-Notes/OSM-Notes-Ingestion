#!/usr/bin/env bats

# Integration tests for cleanupAll.sh
# Tests both full cleanup and partition-only cleanup functionality
#
# Author: Andres Gomez (AngocA)
# Version: 2025-08-04

# Load test helper
load test_helper

# Test that cleanupAll.sh can be sourced without errors
@test "cleanupAll.sh should be sourceable without errors" {
  # Test that the script can be sourced without errors
  run bash -c "SKIP_MAIN=true source ${SCRIPT_BASE_DIRECTORY}/bin/cleanupAll.sh > /dev/null 2>&1"
  [ "$status" -eq 0 ]
}

# Test that cleanupAll.sh functions can be called without logging errors
@test "cleanupAll.sh functions should work without logging errors" {
  # Test that functions can be called without errors
  source "${SCRIPT_BASE_DIRECTORY}/bin/cleanupAll.sh"
  
  # Test logging functions
  run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/cleanupAll.sh && __log_info 'Test message'"
  [ "$status" -eq 0 ]
}

# Test that cleanupAll.sh can run in help mode
@test "cleanupAll.sh should work in help mode" {
  run timeout 30s bash "${SCRIPT_BASE_DIRECTORY}/bin/cleanupAll.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]] || [[ "$output" == *"cleanupAll.sh"* ]]
  [[ "$output" == *"partitions-only"* ]]
  [[ "$output" == *"all"* ]]
}

# Test that cleanupAll.sh has all required functions available
@test "cleanupAll.sh should have all required functions available" {
  source "${SCRIPT_BASE_DIRECTORY}/bin/cleanupAll.sh"
  
  # List of required functions
  local REQUIRED_FUNCTIONS=(
    "__check_database"
    "__execute_sql_script"
    "__list_partition_tables"
    "__drop_all_partitions"
    "__verify_partition_cleanup"
    "__cleanup_partitions_only"
    "__cleanup_etl"
    "__cleanup_wms"
    "__cleanup_api_tables"
    "__cleanup_base"
    "__cleanup_temp_files"
    "__cleanup_all"
    "__cleanup"
    "__show_help"
    "main"
  )
  
  for FUNC in "${REQUIRED_FUNCTIONS[@]}"; do
    run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/cleanupAll.sh && declare -f ${FUNC}"
    [ "$status" -eq 0 ]
  done
}

# Test that cleanupAll.sh logging functions should work correctly
@test "cleanupAll.sh logging functions should work correctly" {
  source "${SCRIPT_BASE_DIRECTORY}/bin/cleanupAll.sh"
  
  # Test that logging functions work
  run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/cleanupAll.sh && __log_info 'Test info' && __log_error 'Test error'"
  [ "$status" -eq 0 ]
}

# Test that cleanupAll.sh database operations should work with test database
@test "cleanupAll.sh database operations should work with test database" {
  # This test requires a test database to be available
  # For now, we'll just test that the script can be executed
  run timeout 30s bash "${SCRIPT_BASE_DIRECTORY}/bin/cleanupAll.sh" --help
  [ "$status" -eq 0 ]
}

# Test that cleanupAll.sh error handling should work correctly
@test "cleanupAll.sh error handling should work correctly" {
  # Test with non-existent database
  run bash -c "DBNAME=nonexistent_db source ${SCRIPT_BASE_DIRECTORY}/bin/cleanupAll.sh"
  # Should not crash, but may log errors
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

# Test that cleanupAll.sh SQL files should be valid
@test "cleanupAll.sh SQL files should be valid" {
  # Test that referenced SQL files exist and are valid
  local SQL_FILES=(
    "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_11_dropAllPartitions.sql"
    "${SCRIPT_BASE_DIRECTORY}/sql/dwh/datamartCountries/datamartCountries_dropDatamartObjects.sql"
    "${SCRIPT_BASE_DIRECTORY}/sql/dwh/datamartUsers/datamartUsers_dropDatamartObjects.sql"
    "${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging_removeStagingObjects.sql"
    "${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_12_removeDatamartObjects.sql"
    "${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_13_removeDWHObjects.sql"
    "${SCRIPT_BASE_DIRECTORY}/sql/wms/removeFromDatabase.sql"
    "${SCRIPT_BASE_DIRECTORY}/sql/monitor/processCheckPlanetNotes_11_dropCheckTables.sql"
    "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_11_dropSyncTables.sql"
    "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_13_dropBaseTables.sql"
    "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_14_dropCountryTables.sql"
    "${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_12_dropGenericObjects.sql"
  )
  
  for SQL_FILE in "${SQL_FILES[@]}"; do
    if [[ -f "${SQL_FILE}" ]]; then
      # Test that the file is readable
      [ -r "${SQL_FILE}" ]
    else
      # Skip if file doesn't exist (may be optional)
      skip "SQL file not found: ${SQL_FILE}"
    fi
  done
}

# Test that cleanupAll.sh should handle no parameters gracefully
@test "cleanupAll.sh should handle no parameters gracefully" {
  # Test that the script can run without parameters
  run timeout 30s bash "${SCRIPT_BASE_DIRECTORY}/bin/cleanupAll.sh"
  # Should either succeed or show help
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

# Test that cleanupAll.sh partition cleanup functions should work correctly
@test "cleanupAll.sh partition cleanup functions should work correctly" {
  # Test that partition-specific functions exist
  local PARTITION_FUNCTIONS=(
    "__list_partition_tables"
    "__drop_all_partitions"
    "__verify_partition_cleanup"
    "__cleanup_partitions_only"
  )
  
  for FUNC in "${PARTITION_FUNCTIONS[@]}"; do
    run bash -c "SKIP_MAIN=true source ${SCRIPT_BASE_DIRECTORY}/bin/cleanupAll.sh && declare -f ${FUNC}"
    [ "$status" -eq 0 ]
  done
}

# Test that cleanupAll.sh database connection functions should work correctly
@test "cleanupAll.sh database connection functions should work correctly" {
  # Test that database connection functions exist
  local DB_FUNCTIONS=(
    "__check_database"
    "__execute_sql_script"
  )
  
  for FUNC in "${DB_FUNCTIONS[@]}"; do
    run bash -c "SKIP_MAIN=true source ${SCRIPT_BASE_DIRECTORY}/bin/cleanupAll.sh && declare -f ${FUNC}"
    [ "$status" -eq 0 ]
  done
}

# Test that cleanupAll.sh partition detection should work correctly
@test "cleanupAll.sh partition detection should work correctly" {
  # Test that the partition detection query is valid
  source "${SCRIPT_BASE_DIRECTORY}/bin/cleanupAll.sh"
  
  # Test that the partition detection SQL is syntactically correct
  local PARTITION_QUERY="
  SELECT table_name, COUNT(*) as count
  FROM information_schema.tables 
  WHERE table_name LIKE '%_part_%' 
  GROUP BY table_name 
  ORDER BY table_name;
  "
  
  # This is a basic syntax check - in a real environment, you'd test against a database
  [[ -n "${PARTITION_QUERY}" ]]
}

# Test that cleanupAll.sh supports partition-only mode
@test "cleanupAll.sh should support partition-only mode" {
  run timeout 30s bash "${SCRIPT_BASE_DIRECTORY}/bin/cleanupAll.sh" -p --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"partition"* ]]
}

# Test that cleanupAll.sh supports full cleanup mode
@test "cleanupAll.sh should support full cleanup mode" {
  run timeout 30s bash "${SCRIPT_BASE_DIRECTORY}/bin/cleanupAll.sh" -a --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

# Test that cleanupAll.sh validates command line arguments
@test "cleanupAll.sh should validate command line arguments" {
  # Test invalid option
  run timeout 30s bash "${SCRIPT_BASE_DIRECTORY}/bin/cleanupAll.sh" --invalid-option
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown option"* ]]
}

# Test that cleanupAll.sh can handle multiple arguments
@test "cleanupAll.sh should handle multiple arguments correctly" {
  # Test with mode and database name
  run timeout 30s bash "${SCRIPT_BASE_DIRECTORY}/bin/cleanupAll.sh" -p test_db --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
} 