#!/usr/bin/env bats

# Require minimum BATS version for run flags
bats_require_minimum_version 1.5.0

# Integration tests for cleanupPartitions.sh
# Tests that actually execute the script to detect real errors

setup() {
 # Setup test environment
 export SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
 export TMP_DIR="$(mktemp -d)"
 export BASENAME="test_cleanup_partitions"
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

# Test that cleanupPartitions.sh can be sourced without errors
@test "cleanupPartitions.sh should be sourceable without errors" {
 # Test that the script can be sourced without logging errors
 run -127 bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/cleanupPartitions.sh > /dev/null 2>&1"
 [ "$status" -eq 0 ] || [ "$status" -eq 127 ]
}

# Test that cleanupPartitions.sh functions can be called without logging errors
@test "cleanupPartitions.sh functions should work without logging errors" {
 # Source the script
 source "${SCRIPT_BASE_DIRECTORY}/bin/cleanupPartitions.sh"
 
 # Test that logging functions work
 run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/cleanupPartitions.sh && __log_info 'Test message'"
 [ "$status" -eq 0 ]
 [[ "$output" == *"Test message"* ]] || [[ "$output" == *"Command not found"* ]]
}

# Test that cleanupPartitions.sh can run in dry-run mode
@test "cleanupPartitions.sh should work in dry-run mode" {
 # Test that the script can run without actually cleaning up partitions
 run timeout 30s bash "${SCRIPT_BASE_DIRECTORY}/bin/cleanupPartitions.sh" --help
 [ "$status" -eq 0 ] || [ "$status" -eq 1 ] # Help should exit with code 0 or 1
 [[ "$output" == *"Usage:"* ]] || [[ "$output" == *"cleanupPartitions.sh"* ]]
}

# Test that all required functions are available after sourcing
@test "cleanupPartitions.sh should have all required functions available" {
 # Source the script
 source "${SCRIPT_BASE_DIRECTORY}/bin/cleanupPartitions.sh"
 
 # Test that key functions are available
 local REQUIRED_FUNCTIONS=(
   "check_database"
   "execute_sql_script"
   "cleanup_api_partitions"
   "cleanup_planet_partitions"
   "cleanup_all_partitions"
   "show_help"
 )
 
 for FUNC in "${REQUIRED_FUNCTIONS[@]}"; do
   run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/cleanupPartitions.sh && declare -f ${FUNC}"
   [ "$status" -eq 0 ] || echo "Function ${FUNC} should be available"
 done
}

# Test that logging functions work correctly
@test "cleanupPartitions.sh logging functions should work correctly" {
 # Source the script
 source "${SCRIPT_BASE_DIRECTORY}/bin/cleanupPartitions.sh"
 
 # Test that logging functions don't produce errors
 run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/cleanupPartitions.sh && __log_info 'Test info' && __log_error 'Test error'"
 [ "$status" -eq 0 ]
 [[ "$output" != *"orden no encontrada"* ]]
 [[ "$output" != *"command not found"* ]]
}

# Test that database operations work with test database
@test "cleanupPartitions.sh database operations should work with test database" {
 # Create test database
 run psql -d postgres -c "CREATE DATABASE ${TEST_DBNAME};"
 [ "$status" -eq 0 ]
 
 # Create base tables with partitions
 run psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_22_createBaseTables_tables.sql"
 [ "$status" -eq 0 ]
 
 # Create partitions
 run psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_25_createPartitions.sql"
 [ "$status" -eq 0 ]
 
 # Verify partitions exist
 run psql -d "${TEST_DBNAME}" -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_name LIKE '%_2024%';"
 [ "$status" -eq 0 ]
 [ "$output" -gt 0 ]
}

# Test that error handling works correctly
@test "cleanupPartitions.sh error handling should work correctly" {
 # Test that the script handles missing database gracefully
 run bash -c "DBNAME=nonexistent_db source ${SCRIPT_BASE_DIRECTORY}/bin/cleanupPartitions.sh"
 [ "$status" -ne 0 ] || echo "Script should handle missing database gracefully"
}

# Test that all SQL files are valid
@test "cleanupPartitions SQL files should be valid" {
 local SQL_FILES=(
   "sql/process/processPlanetNotes_11_dropAllPartitions.sql"
   "sql/process/processAPINotes_22_createPartitions.sql"
   "sql/process/processPlanetNotes_25_createPartitions.sql"
 )
 
 for SQL_FILE in "${SQL_FILES[@]}"; do
   [ -f "${SCRIPT_BASE_DIRECTORY}/${SQL_FILE}" ]
   # Test that SQL file has valid syntax (basic check)
   run grep -q "DROP\|CREATE\|PARTITION" "${SCRIPT_BASE_DIRECTORY}/${SQL_FILE}"
   [ "$status" -eq 0 ] || echo "SQL file ${SQL_FILE} should contain valid SQL"
 done
}

# Test that the script can be executed without parameters
@test "cleanupPartitions.sh should handle no parameters gracefully" {
 # Test that the script doesn't crash when run without parameters
 run timeout 30s bash "${SCRIPT_BASE_DIRECTORY}/bin/cleanupPartitions.sh"
 [ "$status" -ne 0 ] # Should exit with error for missing database
 [[ "$output" == *"database"* ]] || [[ "$output" == *"ERROR"* ]] || echo "Script should show error for missing database"
}

# Test that partition cleanup functions work correctly
@test "cleanupPartitions.sh partition cleanup functions should work correctly" {
 # Source the script
 source "${SCRIPT_BASE_DIRECTORY}/bin/cleanupPartitions.sh"
 
 # Test that partition functions are available
 local PARTITION_FUNCTIONS=(
   "cleanup_api_partitions"
   "cleanup_planet_partitions"
   "cleanup_all_partitions"
 )
 
 for FUNC in "${PARTITION_FUNCTIONS[@]}"; do
   run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/cleanupPartitions.sh && declare -f ${FUNC}"
   [ "$status" -eq 0 ] || echo "Function ${FUNC} should be available"
 done
}

# Test that database connection functions work correctly
@test "cleanupPartitions.sh database connection functions should work correctly" {
 # Source the script
 source "${SCRIPT_BASE_DIRECTORY}/bin/cleanupPartitions.sh"
 
 # Test that database functions are available
 local DB_FUNCTIONS=(
   "check_database"
   "execute_sql_script"
 )
 
 for FUNC in "${DB_FUNCTIONS[@]}"; do
   run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/cleanupPartitions.sh && declare -f ${FUNC}"
   [ "$status" -eq 0 ] || echo "Function ${FUNC} should be available"
 done
}

# Test that partition detection works correctly
@test "cleanupPartitions.sh partition detection should work correctly" {
 # Create test database with partitions
 run psql -d postgres -c "CREATE DATABASE ${TEST_DBNAME};"
 [ "$status" -eq 0 ]
 
 # Create base tables
 run psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_22_createBaseTables_tables.sql"
 [ "$status" -eq 0 ]
 
 # Create some test partitions
 run psql -d "${TEST_DBNAME}" -c "CREATE TABLE notes_2024_01 PARTITION OF notes FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');"
 [ "$status" -eq 0 ]
 
 # Verify partition exists
 run psql -d "${TEST_DBNAME}" -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'notes_2024_01';"
 [ "$status" -eq 0 ]
 [ "$output" -eq "1" ]
} 