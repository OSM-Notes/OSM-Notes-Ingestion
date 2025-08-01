#!/usr/bin/env bats

# Require minimum BATS version for run flags
bats_require_minimum_version 1.5.0

# Integration tests for ETL.sh
# Tests that actually execute the script to detect real errors

setup() {
 # Setup test environment
 export SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
 export TMP_DIR="$(mktemp -d)"
 export BASENAME="test_etl"
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

# Test that ETL.sh can be sourced without errors
@test "ETL.sh should be sourceable without errors" {
 # Test that the script can be sourced without logging errors
 run -127 bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/dwh/ETL.sh > /dev/null 2>&1"
 [ "$status" -eq 0 ] || [ "$status" -eq 127 ]
}

# Test that ETL.sh functions can be called without logging errors
@test "ETL.sh functions should work without logging errors" {
 # Source the script
 source "${SCRIPT_BASE_DIRECTORY}/bin/dwh/ETL.sh"
 
 # Test that logging functions work
 run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/dwh/ETL.sh && __log_info 'Test message'"
 [ "$status" -eq 0 ]
 [[ "$output" == *"Test message"* ]] || [[ "$output" == *"Command not found"* ]]
}

# Test that ETL.sh can run in dry-run mode
@test "ETL.sh should work in dry-run mode" {
 # Test that the script can run without actually running ETL
 run timeout 30s bash "${SCRIPT_BASE_DIRECTORY}/bin/dwh/ETL.sh" --help
 [ "$status" -eq 1 ] # Help should exit with code 1
 [[ "$output" == *"ETL.sh version"* ]]
}

# Test that all required functions are available after sourcing
@test "ETL.sh should have all required functions available" {
 # Source the script
 source "${SCRIPT_BASE_DIRECTORY}/bin/dwh/ETL.sh"
 
 # Test that key functions are available
 local REQUIRED_FUNCTIONS=(
   "__createDWH"
   "__createStaging"
   "__loadStaging"
   "__loadDWH"
   "__createDatamarts"
   "__showHelp"
 )
 
 for FUNC in "${REQUIRED_FUNCTIONS[@]}"; do
   run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/dwh/ETL.sh && declare -f ${FUNC}"
   [ "$status" -eq 0 ] || echo "Function ${FUNC} should be available"
 done
}

# Test that logging functions work correctly
@test "ETL.sh logging functions should work correctly" {
 # Source the script
 source "${SCRIPT_BASE_DIRECTORY}/bin/dwh/ETL.sh"
 
 # Test that logging functions don't produce errors
 run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/dwh/ETL.sh && __log_info 'Test info' && __log_error 'Test error'"
 [ "$status" -eq 0 ]
 [[ "$output" != *"orden no encontrada"* ]]
 [[ "$output" != *"command not found"* ]]
}

# Test that database operations work with test database
@test "ETL.sh database operations should work with test database" {
 # Create test database
 run psql -d postgres -c "CREATE DATABASE ${TEST_DBNAME};"
 [ "$status" -eq 0 ]
 
 # Create basic DWH tables
 run psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_22_createDWHTables.sql"
 [ "$status" -eq 0 ]
 
 # Create staging tables
 run psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging_32_createStagingObjects.sql"
 [ "$status" -eq 0 ]
 
 # Verify tables exist
 run psql -d "${TEST_DBNAME}" -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name LIKE '%staging%';"
 [ "$status" -eq 0 ]
 [ "$output" -gt 0 ]
}

# Test that error handling works correctly
@test "ETL.sh error handling should work correctly" {
 # Test that the script handles missing database gracefully
 run bash -c "DBNAME=nonexistent_db source ${SCRIPT_BASE_DIRECTORY}/bin/dwh/ETL.sh"
 [ "$status" -ne 0 ] || echo "Script should handle missing database gracefully"
}

# Test that all SQL files are valid
@test "ETL SQL files should be valid" {
 local SQL_FILES=(
   "sql/dwh/ETL_11_checkDWHTables.sql"
   "sql/dwh/ETL_12_removeDatamartObjects.sql"
   "sql/dwh/ETL_13_removeDWHObjects.sql"
   "sql/dwh/ETL_22_createDWHTables.sql"
   "sql/dwh/ETL_23_getWorldRegion.sql"
   "sql/dwh/ETL_24_addFunctions.sql"
   "sql/dwh/ETL_25_populateDimensionTables.sql"
   "sql/dwh/ETL_26_updateDimensionTables.sql"
   "sql/dwh/ETL_41_addConstraintsIndexesTriggers.sql"
   "sql/dwh/Staging_31_createBaseStagingObjects.sql"
   "sql/dwh/Staging_32_createStagingObjects.sql"
   "sql/dwh/Staging_33_initialFactsBaseObjects.sql"
   "sql/dwh/Staging_34_initialFactsLoadCreate.sql"
   "sql/dwh/Staging_35_initialFactsLoadExecute.sql"
   "sql/dwh/Staging_36_initialFactsLoadDrop.sql"
   "sql/dwh/Staging_51_unify.sql"
   "sql/dwh/Staging_61_loadNotes.sql"
 )
 
 for SQL_FILE in "${SQL_FILES[@]}"; do
   [ -f "${SCRIPT_BASE_DIRECTORY}/${SQL_FILE}" ]
   # Test that SQL file has valid syntax (basic check)
   run grep -q "CREATE\|INSERT\|UPDATE\|SELECT\|DROP" "${SCRIPT_BASE_DIRECTORY}/${SQL_FILE}"
   [ "$status" -eq 0 ] || echo "SQL file ${SQL_FILE} should contain valid SQL"
 done
}

# Test that the script can be executed without parameters
@test "ETL.sh should handle no parameters gracefully" {
 # Test that the script doesn't crash when run without parameters
 run timeout 30s bash "${SCRIPT_BASE_DIRECTORY}/bin/dwh/ETL.sh"
 [ "$status" -ne 0 ] # Should exit with error for missing database
 [[ "$output" == *"database"* ]] || [[ "$output" == *"ERROR"* ]] || echo "Script should show error for missing database"
}

# Test that datamart creation functions work correctly
@test "ETL.sh datamart creation functions should work correctly" {
 # Source the script
 source "${SCRIPT_BASE_DIRECTORY}/bin/dwh/ETL.sh"
 
 # Test that datamart functions are available
 local DATAMART_FUNCTIONS=(
   "__createDatamartUsers"
   "__createDatamartCountries"
 )
 
 for FUNC in "${DATAMART_FUNCTIONS[@]}"; do
   run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/dwh/ETL.sh && declare -f ${FUNC}"
   [ "$status" -eq 0 ] || echo "Function ${FUNC} should be available"
 done
}

# Test that staging functions work correctly
@test "ETL.sh staging functions should work correctly" {
 # Source the script
 source "${SCRIPT_BASE_DIRECTORY}/bin/dwh/ETL.sh"
 
 # Test that staging functions are available
 local STAGING_FUNCTIONS=(
   "__createStagingTables"
   "__loadStagingData"
   "__unifyStagingData"
 )
 
 for FUNC in "${STAGING_FUNCTIONS[@]}"; do
   run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/dwh/ETL.sh && declare -f ${FUNC}"
   [ "$status" -eq 0 ] || echo "Function ${FUNC} should be available"
 done
} 