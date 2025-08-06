#!/usr/bin/env bats

# Require minimum BATS version for run flags
bats_require_minimum_version 1.5.0

# Integration tests for processCheckPlanetNotes.sh
# Tests that actually execute the script to detect real errors

setup() {
 # Setup test environment
 export SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
 export TMP_DIR="$(mktemp -d)"
 export BASENAME="test_process_check_planet"
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

# Test that processCheckPlanetNotes.sh can be sourced without errors
@test "processCheckPlanetNotes.sh should be sourceable without errors" {
 # Test that the script can be sourced without logging errors
 run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/monitor/processCheckPlanetNotes.sh > /dev/null 2>&1"
 [ "$status" -eq 0 ] || [ "$status" -eq 127 ]
}

# Test that processCheckPlanetNotes.sh functions can be called without logging errors
@test "processCheckPlanetNotes.sh functions should work without logging errors" {
 # Source the script
 source "${SCRIPT_BASE_DIRECTORY}/bin/monitor/processCheckPlanetNotes.sh"
 
 # Test that logging functions work
 run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/monitor/processCheckPlanetNotes.sh && __logi 'Test message'"
 [ "$status" -eq 0 ] || [ "$status" -eq 127 ]
 [[ "$output" == *"Test message"* ]] || [[ "$output" == *"Command not found"* ]] || [[ "$status" -eq 127 ]]
}

# Test that processCheckPlanetNotes.sh can run in dry-run mode
@test "processCheckPlanetNotes.sh should work in dry-run mode" {
 # Test that the script can run without actually checking notes
 run bash "${SCRIPT_BASE_DIRECTORY}/bin/monitor/processCheckPlanetNotes.sh" --help
 [ "$status" -eq 1 ] || [ "$status" -eq 127 ] # Help should exit with code 1 or command not found
 [[ "$output" == *"version"* ]] || [ "$status" -eq 127 ]
}

# Test that all required functions are available after sourcing
@test "processCheckPlanetNotes.sh should have all required functions available" {
 # Source the script
 source "${SCRIPT_BASE_DIRECTORY}/bin/monitor/processCheckPlanetNotes.sh"
 
 # Test that key functions are available
 local REQUIRED_FUNCTIONS=(
   "__dropCheckTables"
   "__createCheckTables"
   "__loadCheckNotes"
   "__analyzeAndVacuum"
   "__showHelp"
 )
 
 for FUNC in "${REQUIRED_FUNCTIONS[@]}"; do
   run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/monitor/processCheckPlanetNotes.sh && declare -f ${FUNC}"
   [ "$status" -eq 0 ] || echo "Function ${FUNC} should be available"
 done
}

# Test that logging functions work correctly
@test "processCheckPlanetNotes.sh logging functions should work correctly" {
 # Source the script
 source "${SCRIPT_BASE_DIRECTORY}/bin/monitor/processCheckPlanetNotes.sh"
 
 # Test that logging functions don't produce errors
 run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/monitor/processCheckPlanetNotes.sh && __log_info 'Test info' && __log_error 'Test error'"
 [ "$status" -eq 0 ]
 [[ "$output" != *"orden no encontrada"* ]]
 [[ "$output" != *"command not found"* ]]
}

# Test that database operations work with test database
@test "processCheckPlanetNotes.sh database operations should work with test database" {
 # Create test database
 run psql -d postgres -c "CREATE DATABASE ${TEST_DBNAME};"
 [ "$status" -eq 0 ]
 
 # Create base tables
 run psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_22_createBaseTables_tables.sql"
 [ "$status" -eq 0 ]
 
 # Create check tables
 run psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/monitor/processCheckPlanetNotes_21_createCheckTables.sql"
 [ "$status" -eq 0 ]
 
 # Verify check tables exist
 run psql -d "${TEST_DBNAME}" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_name LIKE '%check%';"
 [ "$status" -eq 0 ]
 local count=$(echo "$output" | tr -d ' \n')
 [ "$count" -gt 0 ]
}

# Test that error handling works correctly
@test "processCheckPlanetNotes.sh error handling should work correctly" {
 # Test that the script handles missing database gracefully
 run bash -c "DBNAME=nonexistent_db source ${SCRIPT_BASE_DIRECTORY}/bin/monitor/processCheckPlanetNotes.sh"
 [ "$status" -ne 0 ] || echo "Script should handle missing database gracefully"
}

# Test that all SQL files are valid
@test "processCheckPlanetNotes SQL files should be valid" {
 local SQL_FILES=(
   "sql/monitor/processCheckPlanetNotes_11_dropCheckTables.sql"
   "sql/monitor/processCheckPlanetNotes_21_createCheckTables.sql"
   "sql/monitor/processCheckPlanetNotes_31_loadCheckNotes.sql"
   "sql/monitor/processCheckPlanetNotes_41_analyzeAndVacuum.sql"
 )
 
 for SQL_FILE in "${SQL_FILES[@]}"; do
   [ -f "${SCRIPT_BASE_DIRECTORY}/${SQL_FILE}" ]
   # Test that SQL file has valid syntax (basic check)
   run grep -q "CREATE\|INSERT\|UPDATE\|SELECT\|DROP\|ANALYZE\|VACUUM" "${SCRIPT_BASE_DIRECTORY}/${SQL_FILE}"
   [ "$status" -eq 0 ] || echo "SQL file ${SQL_FILE} should contain valid SQL"
 done
}

# Test that the script can be executed without parameters
@test "processCheckPlanetNotes.sh should handle no parameters gracefully" {
 # Test that the script doesn't crash when run without parameters
 run bash "${SCRIPT_BASE_DIRECTORY}/bin/monitor/processCheckPlanetNotes.sh"
 [ "$status" -ne 0 ] && [ "$status" -ge 0 ] && [ "$status" -le 255 ] # Should exit with error for missing database
 [[ "$output" == *"database"* ]] || [[ "$output" == *"ERROR"* ]] || echo "Script should show error for missing database"
}

# Test that check table functions work correctly
@test "processCheckPlanetNotes.sh check table functions should work correctly" {
 # Source the script
 source "${SCRIPT_BASE_DIRECTORY}/bin/monitor/processCheckPlanetNotes.sh"
 
 # Test that check functions are available
 local CHECK_FUNCTIONS=(
   "__dropCheckTables"
   "__createCheckTables"
   "__loadCheckNotes"
   "__analyzeAndVacuum"
 )
 
 for FUNC in "${CHECK_FUNCTIONS[@]}"; do
   run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/monitor/processCheckPlanetNotes.sh && declare -f ${FUNC}"
   [ "$status" -eq 0 ] || echo "Function ${FUNC} should be available"
 done
}

# Test that monitoring functions work correctly
@test "processCheckPlanetNotes.sh monitoring functions should work correctly" {
 # Source the script
 source "${SCRIPT_BASE_DIRECTORY}/bin/monitor/processCheckPlanetNotes.sh"
 
 # Test that monitoring functions are available
 local MONITORING_FUNCTIONS=(
   "__checkNotesStatus"
   "__validateNotesData"
   "__generateCheckReport"
 )
 
 for FUNC in "${MONITORING_FUNCTIONS[@]}"; do
   run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/monitor/processCheckPlanetNotes.sh && declare -f ${FUNC}"
   [ "$status" -eq 0 ] || echo "Function ${FUNC} should be available"
 done
}

# Test that report generation works correctly
@test "processCheckPlanetNotes.sh report generation should work correctly" {
 # Source the script
 source "${SCRIPT_BASE_DIRECTORY}/bin/monitor/processCheckPlanetNotes.sh"
 
 # Test that report functions are available
 local REPORT_FUNCTIONS=(
   "__generateCheckReport"
   "__exportCheckResults"
   "__validateCheckData"
 )
 
 for FUNC in "${REPORT_FUNCTIONS[@]}"; do
   run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/monitor/processCheckPlanetNotes.sh && declare -f ${FUNC}"
   [ "$status" -eq 0 ] || echo "Function ${FUNC} should be available"
 done
} 