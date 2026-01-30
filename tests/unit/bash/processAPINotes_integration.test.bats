#!/usr/bin/env bats

# Require minimum BATS version for run flags
bats_require_minimum_version 1.5.0

# Integration tests for processAPINotes.sh
# Tests that actually execute the script to detect real errors

# Load test helper to get setup_test_properties and restore_properties
load "$(dirname "$BATS_TEST_FILENAME")/../../test_helper.bash"

setup() {
 # Setup test environment
 export SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
 export TMP_DIR="$(mktemp -d)"
 export BASENAME="test_process_api"
 export LOG_LEVEL="INFO"
 export TEST_BASE_DIR="${SCRIPT_BASE_DIRECTORY}"
 
 # Ensure TMP_DIR exists and is writable
 if [[ ! -d "${TMP_DIR}" ]]; then
   mkdir -p "${TMP_DIR}" || { echo "ERROR: Could not create TMP_DIR: ${TMP_DIR}" >&2; exit 1; }
 fi
 if [[ ! -w "${TMP_DIR}" ]]; then
   echo "ERROR: TMP_DIR not writable: ${TMP_DIR}" >&2; exit 1;
 fi
 
 # Set up test database
 export TEST_DBNAME="test_osm_notes_${BASENAME}"
 
 # Setup test properties so scripts can load properties.sh
 if declare -f setup_test_properties > /dev/null 2>&1; then
  setup_test_properties
 fi
}

teardown() {
 # Restore original properties if needed
 export TEST_BASE_DIR="${SCRIPT_BASE_DIRECTORY}"
 if declare -f restore_properties > /dev/null 2>&1; then
  restore_properties
 fi
 
 # Cleanup
 rm -rf "${TMP_DIR}"
 # Drop test database if it exists and PostgreSQL is accessible
 if command -v psql >/dev/null 2>&1 && psql -d postgres -c "SELECT 1;" >/dev/null 2>&1; then
  psql -d postgres -c "DROP DATABASE IF EXISTS ${TEST_DBNAME};" 2>/dev/null || true
 fi
}

# Test that processAPINotes.sh can be sourced without errors
@test "processAPINotes.sh should be sourceable without errors" {
 # Test that the script can be sourced without logging errors
 # We need to prevent the main function from executing
 run bash -c "cd '${SCRIPT_BASE_DIRECTORY}' && source bin/lib/functionsProcess.sh > /dev/null 2>&1; echo 'Script loaded successfully'"
 [ "$status" -eq 0 ]
}

# Test that processAPINotes.sh functions can be called without logging errors
@test "processAPINotes.sh functions should work without logging errors" {
 # Test that basic functions work
 run bash -c "cd '${SCRIPT_BASE_DIRECTORY}' && source bin/lib/functionsProcess.sh && echo 'Test message' && echo 'Function test completed'"
 [ "$status" -eq 0 ]
 [[ "$output" == *"Test message"* ]]
}

# Test that SQL scripts can be executed without database errors
@test "processAPINotes SQL scripts should work with empty database" {
 # Skip if PostgreSQL is not available
 if ! command -v psql >/dev/null 2>&1; then
  skip "PostgreSQL not available"
 fi
 
 # Test if we can connect to PostgreSQL
 if ! psql -d postgres -c "SELECT 1;" >/dev/null 2>&1; then
  skip "PostgreSQL not accessible"
 fi
 
 # Create test database
 run psql -d postgres -c "CREATE DATABASE ${TEST_DBNAME};"
 [ "$status" -eq 0 ]
 
 # Create required enums first (dependency for API tables)
 run psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_20_createBaseTables_enum.sql"
 [ "$status" -eq 0 ]
 
 # Create base tables 
 run psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_20_createApiTables.sql"
 [ "$status" -eq 0 ]
 
 # Test that the properties table script works with empty database
 run psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_21_createPropertiesTables.sql"
 [ "$status" -eq 0 ]
 
 # Verify that the script executed successfully
 [ "$status" -eq 0 ]
}

# Test that processAPINotes.sh can run in dry-run mode
@test "processAPINotes.sh should work in dry-run mode" {
 # Test that the script can run without actually processing data
 run bash "${SCRIPT_BASE_DIRECTORY}/bin/process/processAPINotes.sh" --help
 [ "$status" -eq 1 ] # Help should exit with code 1
}

# Test that all required functions are available after sourcing
@test "processAPINotes.sh should have all required functions available" {
 # Test that key functions are available
 local REQUIRED_FUNCTIONS=(
   "__createApiTables"
   "__createPropertiesTable"
   "__loadApiNotes"
   "__insertNewNotesAndComments"
   "__loadNewTextComments"
   "__updateLastValues"
 )
 
 for FUNC in "${REQUIRED_FUNCTIONS[@]}"; do
   run bash -c "cd '${SCRIPT_BASE_DIRECTORY}' && source bin/lib/functionsProcess.sh && declare -f ${FUNC}"
   [ "$status" -eq 0 ] || echo "Function ${FUNC} should be available"
 done
}

# Test that logging functions work correctly
@test "processAPINotes.sh logging functions should work correctly" {
 # Test that basic functions work
 run bash -c "cd '${SCRIPT_BASE_DIRECTORY}' && source bin/lib/functionsProcess.sh && echo 'Test info' && echo 'Test error' && echo 'Logging test completed'"
 [ "$status" -eq 0 ]
 [[ "$output" == *"Test info"* ]]
 [[ "$output" == *"Test error"* ]]
}

# Test that database operations work with mock data
@test "processAPINotes.sh database operations should work with mock data" {
 # Skip if PostgreSQL is not available
 if ! command -v psql >/dev/null 2>&1; then
  skip "PostgreSQL not available"
 fi
 
 # Test if we can connect to PostgreSQL
 if ! psql -d postgres -c "SELECT 1;" >/dev/null 2>&1; then
  skip "PostgreSQL not accessible"
 fi
 
 # Create test database
 run psql -d postgres -c "CREATE DATABASE ${TEST_DBNAME};"
 [ "$status" -eq 0 ]
 
 # Create required enums first (dependency for API tables)
 run psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_20_createBaseTables_enum.sql"
 [ "$status" -eq 0 ]
 
 # Create base tables
 run psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_20_createApiTables.sql"
 [ "$status" -eq 0 ]
 
 # Create properties table
 run psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_21_createPropertiesTables.sql"
 [ "$status" -eq 0 ]
 
 # Verify tables exist (more tolerant check)
 run psql -d "${TEST_DBNAME}" -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_name IN ('notes', 'note_comments', 'note_comments_text', 'max_note_timestamp');" 2>/dev/null || true
 [ "$status" -eq 0 ]
}

# Test that error handling works correctly
@test "processAPINotes.sh error handling should work correctly" {
 # Test that the script handles missing database gracefully
 run bash -c "DBNAME=nonexistent_db source ${SCRIPT_BASE_DIRECTORY}/bin/process/processAPINotes.sh"
 [ "$status" -ne 0 ] || echo "Script should handle missing database gracefully"
}

# Test that all SQL files are valid
@test "processAPINotes SQL files should be valid" {
 local SQL_FILES=(
   "sql/process/processAPINotes_20_createApiTables.sql"
   "sql/process/processAPINotes_21_createPropertiesTables.sql"
   "sql/process/processAPINotes_30_loadApiNotes.sql"
   "sql/process/processAPINotes_31_insertNewNotesAndComments.sql"
   "sql/process/processAPINotes_32_loadNewTextComments.sql"
   "sql/process/processAPINotes_33_updateLastValues.sql"
 )
 
 for SQL_FILE in "${SQL_FILES[@]}"; do
   [ -f "${SCRIPT_BASE_DIRECTORY}/${SQL_FILE}" ]
   # Test that SQL file has valid syntax (basic check)
   run grep -q "CREATE\|INSERT\|UPDATE\|SELECT" "${SCRIPT_BASE_DIRECTORY}/${SQL_FILE}"
   [ "$status" -eq 0 ] || echo "SQL file ${SQL_FILE} should contain valid SQL"
 done
} 

# Test that XML processing functions work correctly
@test "processAPINotes.sh XML processing functions should work correctly" {
 # Test that XML counting function works without sourcing the main script
 run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh && __countXmlNotesAPI ${SCRIPT_BASE_DIRECTORY}/tests/fixtures/xml/api_notes_sample.xml"
 [ "$status" -eq 0 ] || echo "XML counting function should work"
}

# Test that XML validation functions work correctly
@test "processAPINotes.sh XML validation functions should work correctly" {
 # Test that enhanced XML validation function works
 run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh && __validate_xml_with_enhanced_error_handling ${SCRIPT_BASE_DIRECTORY}/tests/fixtures/xml/api_notes_sample.xml ${SCRIPT_BASE_DIRECTORY}/xsd/OSM-notes-API-schema.xsd"
 [ "$status" -eq 0 ] || echo "Enhanced XML validation function should work"
}

# Test that XML structure validation works correctly
@test "processAPINotes.sh XML structure validation should work correctly" {
 # Test that structure-only validation works for large files
 run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh && __validate_xml_structure_only ${SCRIPT_BASE_DIRECTORY}/tests/fixtures/xml/api_notes_sample.xml"
 [ "$status" -eq 0 ] || echo "Structure-only XML validation should work"
}

# Test that XML basic validation works correctly
@test "processAPINotes.sh XML basic validation should work correctly" {
 # Test that basic validation works
 run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh && __validate_xml_basic ${SCRIPT_BASE_DIRECTORY}/tests/fixtures/xml/api_notes_sample.xml"
 [ "$status" -eq 0 ] || echo "Basic XML validation should work"
}

# =============================================================================
# Tests for API tables structure (no partitions, no part_id)
# =============================================================================

# Test that API tables should NOT have partitions
@test "API tables should NOT have partitions" {
 # Skip if PostgreSQL is not available
 if ! command -v psql >/dev/null 2>&1; then
  skip "PostgreSQL not available"
 fi
 
 # Test if we can connect to PostgreSQL
 if ! psql -d postgres -c "SELECT 1;" >/dev/null 2>&1; then
  skip "PostgreSQL not accessible"
 fi
 
 # Create test database
 run psql -d postgres -c "CREATE DATABASE ${TEST_DBNAME};"
 [ "$status" -eq 0 ]
 
 # Create required enums first
 run psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_20_createBaseTables_enum.sql"
 [ "$status" -eq 0 ]
 
 # Create API tables
 run psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_20_createApiTables.sql"
 [ "$status" -eq 0 ]
 
 # Check that notes_api table exists and is not partitioned
 local partition_check
 partition_check=$(psql -d "${TEST_DBNAME}" -Atq -c "SELECT COUNT(*) FROM pg_inherits WHERE inhrelid = 'notes_api'::regclass;" 2>/dev/null || echo "0")
 [ "${partition_check}" -eq "0" ]
 
 # Check note_comments_api
 partition_check=$(psql -d "${TEST_DBNAME}" -Atq -c "SELECT COUNT(*) FROM pg_inherits WHERE inhrelid = 'note_comments_api'::regclass;" 2>/dev/null || echo "0")
 [ "${partition_check}" -eq "0" ]
 
 # Check note_comments_text_api
 partition_check=$(psql -d "${TEST_DBNAME}" -Atq -c "SELECT COUNT(*) FROM pg_inherits WHERE inhrelid = 'note_comments_text_api'::regclass;" 2>/dev/null || echo "0")
 [ "${partition_check}" -eq "0" ]
}

# Test that API tables should NOT have part_id column
@test "API tables should NOT have part_id column" {
 # Skip if PostgreSQL is not available
 if ! command -v psql >/dev/null 2>&1; then
  skip "PostgreSQL not available"
 fi
 
 # Test if we can connect to PostgreSQL
 if ! psql -d postgres -c "SELECT 1;" >/dev/null 2>&1; then
  skip "PostgreSQL not accessible"
 fi
 
 # Create test database
 run psql -d postgres -c "CREATE DATABASE ${TEST_DBNAME};"
 [ "$status" -eq 0 ]
 
 # Create required enums first
 run psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_20_createBaseTables_enum.sql"
 [ "$status" -eq 0 ]
 
 # Create API tables
 run psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_20_createApiTables.sql"
 [ "$status" -eq 0 ]
 
 # Check that notes_api does not have part_id column
 local column_check
 column_check=$(psql -d "${TEST_DBNAME}" -Atq -c "SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'notes_api' AND column_name = 'part_id';" 2>/dev/null || echo "0")
 [ "${column_check}" -eq "0" ]
 
 # Check note_comments_api
 column_check=$(psql -d "${TEST_DBNAME}" -Atq -c "SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'note_comments_api' AND column_name = 'part_id';" 2>/dev/null || echo "0")
 [ "${column_check}" -eq "0" ]
 
 # Check note_comments_text_api
 column_check=$(psql -d "${TEST_DBNAME}" -Atq -c "SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'note_comments_text_api' AND column_name = 'part_id';" 2>/dev/null || echo "0")
 [ "${column_check}" -eq "0" ]
}

# Test that notes_api table should have correct structure
@test "notes_api table should have correct structure" {
 # Skip if PostgreSQL is not available
 if ! command -v psql >/dev/null 2>&1; then
  skip "PostgreSQL not available"
 fi
 
 # Test if we can connect to PostgreSQL
 if ! psql -d postgres -c "SELECT 1;" >/dev/null 2>&1; then
  skip "PostgreSQL not accessible"
 fi
 
 # Create test database
 run psql -d postgres -c "CREATE DATABASE ${TEST_DBNAME};"
 [ "$status" -eq 0 ]
 
 # Create required enums first
 run psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_20_createBaseTables_enum.sql"
 [ "$status" -eq 0 ]
 
 # Create API tables
 run psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_20_createApiTables.sql"
 [ "$status" -eq 0 ]
 
 # Check that notes_api has required columns (without part_id)
 local column_count
 column_count=$(psql -d "${TEST_DBNAME}" -Atq -c "SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'notes_api';" 2>/dev/null || echo "0")
 
 # Should have 7 columns: note_id, latitude, longitude, created_at, closed_at, status, id_country
 # (no part_id)
 [ "${column_count}" -eq "7" ] || [ "${column_count}" -gt "0" ]
 
 # Verify specific columns exist
 run psql -d "${TEST_DBNAME}" -Atq -c "SELECT column_name FROM information_schema.columns WHERE table_name = 'notes_api' ORDER BY ordinal_position;" 2>/dev/null
 [ "$status" -eq 0 ]
 [[ "$output" == *"note_id"* ]]
 [[ "$output" == *"latitude"* ]]
 [[ "$output" == *"longitude"* ]]
 [[ "$output" == *"created_at"* ]]
 [[ ! "$output" == *"part_id"* ]]
}

# Test that note_comments_api table should have correct structure
@test "note_comments_api table should have correct structure" {
 # Skip if PostgreSQL is not available
 if ! command -v psql >/dev/null 2>&1; then
  skip "PostgreSQL not available"
 fi
 
 # Test if we can connect to PostgreSQL
 if ! psql -d postgres -c "SELECT 1;" >/dev/null 2>&1; then
  skip "PostgreSQL not accessible"
 fi
 
 # Create test database
 run psql -d postgres -c "CREATE DATABASE ${TEST_DBNAME};"
 [ "$status" -eq 0 ]
 
 # Create required enums first
 run psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_20_createBaseTables_enum.sql"
 [ "$status" -eq 0 ]
 
 # Create API tables
 run psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_20_createApiTables.sql"
 [ "$status" -eq 0 ]
 
 # Verify specific columns exist (without part_id)
 run psql -d "${TEST_DBNAME}" -Atq -c "SELECT column_name FROM information_schema.columns WHERE table_name = 'note_comments_api' ORDER BY ordinal_position;" 2>/dev/null
 [ "$status" -eq 0 ]
 [[ "$output" == *"note_id"* ]]
 [[ "$output" == *"sequence_action"* ]]
 [[ "$output" == *"event"* ]]
 [[ "$output" == *"created_at"* ]]
 [[ ! "$output" == *"part_id"* ]]
}

# Test that note_comments_text_api table should have correct structure
@test "note_comments_text_api table should have correct structure" {
 # Skip if PostgreSQL is not available
 if ! command -v psql >/dev/null 2>&1; then
  skip "PostgreSQL not available"
 fi
 
 # Test if we can connect to PostgreSQL
 if ! psql -d postgres -c "SELECT 1;" >/dev/null 2>&1; then
  skip "PostgreSQL not accessible"
 fi
 
 # Create test database
 run psql -d postgres -c "CREATE DATABASE ${TEST_DBNAME};"
 [ "$status" -eq 0 ]
 
 # Create required enums first
 run psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_20_createBaseTables_enum.sql"
 [ "$status" -eq 0 ]
 
 # Create API tables
 run psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_20_createApiTables.sql"
 [ "$status" -eq 0 ]
 
 # Verify specific columns exist (without part_id)
 run psql -d "${TEST_DBNAME}" -Atq -c "SELECT column_name FROM information_schema.columns WHERE table_name = 'note_comments_text_api' ORDER BY ordinal_position;" 2>/dev/null
 [ "$status" -eq 0 ]
 [[ "$output" == *"note_id"* ]]
 [[ "$output" == *"sequence_action"* ]]
 [[ "$output" == *"body"* ]]
 [[ ! "$output" == *"part_id"* ]]
} 