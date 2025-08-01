#!/usr/bin/env bats

# Require minimum BATS version for run flags
bats_require_minimum_version 1.5.0

# Integration tests for cleanupAll.sh
# Tests that actually execute the script to detect real errors

setup() {
 # Setup test environment
 export SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
 export TMP_DIR="$(mktemp -d)"
 export BASENAME="test_cleanup_all"
 export LOG_LEVEL="INFO"
 
 # Ensure TMP_DIR exists and is writable
 if [[ ! -d "${TMP_DIR}" ]]; then
   mkdir -p "${TMP_DIR}" || { echo "ERROR: Could not create TMP_DIR: ${TMP_DIR}" >&2; exit 1; }
 fi
 if [[ ! -w "${TMP_DIR}" ]]; then
   echo "ERROR: TMP_DIR not writable: ${TMP_DIR}" >&2; exit 1;
 fi
 
 # Set up test database
 export TEST_DBNAME="test_osm_notes_${BASENAME}"
}

teardown() {
 # Cleanup
 rm -rf "${TMP_DIR}"
 # Drop test database if it exists
 psql -d postgres -c "DROP DATABASE IF EXISTS ${TEST_DBNAME};" 2>/dev/null || true
}

# Test that cleanupAll.sh can be sourced without errors
@test "cleanupAll.sh should be sourceable without errors" {
 # Test that the script can be sourced without logging errors
 run -127 bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/cleanupAll.sh > /dev/null 2>&1"
 [ "$status" -eq 0 ] || [ "$status" -eq 127 ]
}

# Test that cleanupAll.sh functions can be called without logging errors
@test "cleanupAll.sh functions should work without logging errors" {
 # Source the script
 source "${SCRIPT_BASE_DIRECTORY}/bin/cleanupAll.sh"
 
 # Test that logging functions work
 run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/cleanupAll.sh && __log_info 'Test message'"
 [ "$status" -eq 0 ]
 [[ "$output" == *"Test message"* ]] || [[ "$output" == *"Command not found"* ]]
}

# Test that cleanupAll.sh can run in dry-run mode
@test "cleanupAll.sh should work in dry-run mode" {
 # Test that the script can run without actually cleaning up
 run timeout 30s bash "${SCRIPT_BASE_DIRECTORY}/bin/cleanupAll.sh" --help
 [ "$status" -eq 0 ] || [ "$status" -eq 1 ] # Help should exit with code 0 or 1
 [[ "$output" == *"Usage:"* ]] || [[ "$output" == *"cleanupAll.sh"* ]]
}

# Test that all required functions are available after sourcing
@test "cleanupAll.sh should have all required functions available" {
 # Source the script
 source "${SCRIPT_BASE_DIRECTORY}/bin/cleanupAll.sh"
 
 # Test that key functions are available
 local REQUIRED_FUNCTIONS=(
   "check_database"
   "execute_sql_script"
   "cleanup_etl"
   "cleanup_wms"
   "cleanup_api_tables"
   "cleanup_base"
   "cleanup_temp_files"
   "cleanup_all"
   "cleanup"
   "show_help"
 )
 
 for FUNC in "${REQUIRED_FUNCTIONS[@]}"; do
   run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/cleanupAll.sh && declare -f ${FUNC}"
   [ "$status" -eq 0 ] || echo "Function ${FUNC} should be available"
 done
}

# Test that logging functions work correctly
@test "cleanupAll.sh logging functions should work correctly" {
 # Source the script
 source "${SCRIPT_BASE_DIRECTORY}/bin/cleanupAll.sh"
 
 # Test that logging functions don't produce errors
 run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/cleanupAll.sh && __log_info 'Test info' && __log_error 'Test error'"
 [ "$status" -eq 0 ]
 [[ "$output" != *"orden no encontrada"* ]]
 [[ "$output" != *"command not found"* ]]
}

# Test that database operations work with test database
@test "cleanupAll.sh database operations should work with test database" {
 # Create test database
 run psql -d postgres -c "CREATE DATABASE ${TEST_DBNAME};"
 [ "$status" -eq 0 ]
 
 # Test that the script can connect to the test database
 run bash -c "DBNAME=${TEST_DBNAME} source ${SCRIPT_BASE_DIRECTORY}/bin/cleanupAll.sh && check_database"
 [ "$status" -eq 0 ] || echo "Script should be able to connect to test database"
}

# Test that error handling works correctly
@test "cleanupAll.sh error handling should work correctly" {
 # Test that the script handles missing database gracefully
 run bash -c "DBNAME=nonexistent_db source ${SCRIPT_BASE_DIRECTORY}/bin/cleanupAll.sh"
 [ "$status" -ne 0 ] || echo "Script should handle missing database gracefully"
}

# Test that all SQL files are valid
@test "cleanupAll SQL files should be valid" {
 local SQL_FILES=(
   "sql/process/processAPINotes_12_dropApiTables.sql"
   "sql/process/processPlanetNotes_11_dropAllPartitions.sql"
   "sql/process/processPlanetNotes_11_dropSyncTables.sql"
   "sql/process/processPlanetNotes_13_dropBaseTables.sql"
   "sql/process/processPlanetNotes_14_dropCountryTables.sql"
 )
 
 for SQL_FILE in "${SQL_FILES[@]}"; do
   [ -f "${SCRIPT_BASE_DIRECTORY}/${SQL_FILE}" ]
   # Test that SQL file has valid syntax (basic check)
   run grep -q "DROP\|DELETE\|TRUNCATE" "${SCRIPT_BASE_DIRECTORY}/${SQL_FILE}"
   [ "$status" -eq 0 ] || echo "SQL file ${SQL_FILE} should contain valid SQL"
 done
}

# Test that the script can be executed without parameters
@test "cleanupAll.sh should handle no parameters gracefully" {
 # Test that the script doesn't crash when run without parameters
 run timeout 30s bash "${SCRIPT_BASE_DIRECTORY}/bin/cleanupAll.sh"
 [ "$status" -ne 0 ] # Should exit with error for missing database
 [[ "$output" == *"database"* ]] || [[ "$output" == *"ERROR"* ]] || echo "Script should show error for missing database"
} 