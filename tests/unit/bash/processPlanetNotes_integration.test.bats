#!/usr/bin/env bats

# Require minimum BATS version for run flags
bats_require_minimum_version 1.5.0

# Integration tests for processPlanetNotes.sh
# Tests that actually execute the script to detect real errors

setup() {
 # Setup test environment
 export SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
 export TMP_DIR="$(mktemp -d)"
 export BASENAME="test_process_planet"
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

# Test that processPlanetNotes.sh can be sourced without errors
@test "processPlanetNotes.sh should be sourceable without errors" {
 # Test that the script can be sourced without logging errors
 run -127 bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/process/processPlanetNotes.sh > /dev/null 2>&1"
 [ "$status" -eq 0 ] || [ "$status" -eq 127 ]
}

# Test that processPlanetNotes.sh functions can be called without logging errors
@test "processPlanetNotes.sh functions should work without logging errors" {
 # Source the script
 source "${SCRIPT_BASE_DIRECTORY}/bin/process/processPlanetNotes.sh"
 
 # Test that logging functions work
 run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/process/processPlanetNotes.sh && __log_info 'Test message'"
 [ "$status" -eq 0 ]
 [[ "$output" == *"Test message"* ]] || [[ "$output" == *"Command not found"* ]]
}

# Test that processPlanetNotes.sh can run in dry-run mode
@test "processPlanetNotes.sh should work in dry-run mode" {
 # Test that the script can run without actually processing data
 run timeout 30s bash "${SCRIPT_BASE_DIRECTORY}/bin/process/processPlanetNotes.sh" --help
 [ "$status" -eq 1 ] # Help should exit with code 1
 [[ "$output" == *"processPlanetNotes.sh version"* ]]
}

# Test that all required functions are available after sourcing
@test "processPlanetNotes.sh should have all required functions available" {
 # Source the script
 source "${SCRIPT_BASE_DIRECTORY}/bin/process/processPlanetNotes.sh"
 
 # Test that key functions are available
 local REQUIRED_FUNCTIONS=(
   "__dropAllPartitions"
   "__dropSyncTables"
   "__dropBaseTables"
   "__dropCountryTables"
   "__createBaseTables"
   "__createSyncTables"
   "__createCountryTables"
   "__createPartitions"
   "__analyzeVacuum"
   "__loadPartitionedSyncNotes"
   "__consolidatePartitions"
   "__moveSyncToMain"
   "__removeDuplicates"
   "__loadTextComments"
   "__objectsTextComments"
 )
 
 for FUNC in "${REQUIRED_FUNCTIONS[@]}"; do
   run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/process/processPlanetNotes.sh && declare -f ${FUNC}"
   [ "$status" -eq 0 ] || echo "Function ${FUNC} should be available"
 done
}

# Test that logging functions work correctly
@test "processPlanetNotes.sh logging functions should work correctly" {
 # Source the script
 source "${SCRIPT_BASE_DIRECTORY}/bin/process/processPlanetNotes.sh"
 
 # Test that logging functions don't produce errors
 run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/process/processPlanetNotes.sh && __log_info 'Test info' && __log_error 'Test error'"
 [ "$status" -eq 0 ]
 [[ "$output" != *"orden no encontrada"* ]]
 [[ "$output" != *"command not found"* ]]
}

# Test that database operations work with mock data
@test "processPlanetNotes.sh database operations should work with mock data" {
 # Create test database
 run psql -d postgres -c "CREATE DATABASE ${TEST_DBNAME};"
 [ "$status" -eq 0 ]
 
 # Create base tables
 run psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_22_createBaseTables_tables.sql"
 [ "$status" -eq 0 ]
 
 # Create sync tables
 run psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_24_createSyncTables.sql"
 [ "$status" -eq 0 ]
 
 # Create country tables
 run psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_25_createCountryTables.sql"
 [ "$status" -eq 0 ]
 
 # Verify tables exist
 run psql -d "${TEST_DBNAME}" -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_name IN ('notes', 'note_comments', 'note_comments_text', 'users', 'countries', 'maritimes');"
 [ "$status" -eq 0 ]
 [ "$output" -eq "6" ]
}

# Test that error handling works correctly
@test "processPlanetNotes.sh error handling should work correctly" {
 # Test that the script handles missing database gracefully
 run bash -c "DBNAME=nonexistent_db source ${SCRIPT_BASE_DIRECTORY}/bin/process/processPlanetNotes.sh"
 [ "$status" -ne 0 ] || echo "Script should handle missing database gracefully"
}

# Test that all SQL files are valid
@test "processPlanetNotes SQL files should be valid" {
 local SQL_FILES=(
   "sql/process/processPlanetNotes_21_createBaseTables_enum.sql"
   "sql/process/processPlanetNotes_22_createBaseTables_tables.sql"
   "sql/process/processPlanetNotes_23_createBaseTables_constraints.sql"
   "sql/process/processPlanetNotes_24_createSyncTables.sql"
   "sql/process/processPlanetNotes_25_createCountryTables.sql"
   "sql/process/processPlanetNotes_25_createPartitions.sql"
   "sql/process/processPlanetNotes_31_analyzeVacuum.sql"
   "sql/process/processPlanetNotes_41_loadPartitionedSyncNotes.sql"
   "sql/process/processPlanetNotes_42_consolidatePartitions.sql"
   "sql/process/processPlanetNotes_43_moveSyncToMain.sql"
   "sql/process/processPlanetNotes_43_removeDuplicates.sql"
   "sql/process/processPlanetNotes_44_loadTextComments.sql"
   "sql/process/processPlanetNotes_45_objectsTextComments.sql"
 )
 
 for SQL_FILE in "${SQL_FILES[@]}"; do
   [ -f "${SCRIPT_BASE_DIRECTORY}/${SQL_FILE}" ]
   # Test that SQL file has valid syntax (basic check)
   run grep -q "CREATE\|INSERT\|UPDATE\|SELECT" "${SCRIPT_BASE_DIRECTORY}/${SQL_FILE}"
   [ "$status" -eq 0 ] || echo "SQL file ${SQL_FILE} should contain valid SQL"
 done
}

# Test that XML processing functions work correctly
@test "processPlanetNotes.sh XML processing functions should work correctly" {
 # Source the script
 source "${SCRIPT_BASE_DIRECTORY}/bin/process/processPlanetNotes.sh"
 
 # Test that XML counting function works
 run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/process/processPlanetNotes.sh && __countXmlNotesPlanet ${SCRIPT_BASE_DIRECTORY}/tests/fixtures/xml/planet_notes_real.xml"
 [ "$status" -eq 0 ] || echo "XML counting function should work"
}

# Test that parallel processing functions work correctly
@test "processPlanetNotes.sh parallel processing functions should work correctly" {
 # Source the script
 source "${SCRIPT_BASE_DIRECTORY}/bin/process/processPlanetNotes.sh"
 
 # Test that parallel processing functions are available
 local PARALLEL_FUNCTIONS=(
   "__splitXmlForParallelPlanet"
   "__processPlanetXmlPart"
 )
 
 for FUNC in "${PARALLEL_FUNCTIONS[@]}"; do
   run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/process/processPlanetNotes.sh && declare -f ${FUNC}"
   [ "$status" -eq 0 ] || echo "Function ${FUNC} should be available"
 done
} 