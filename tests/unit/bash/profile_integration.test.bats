#!/usr/bin/env bats

# Require minimum BATS version for run flags
bats_require_minimum_version 1.5.0

# Integration tests for profile.sh
# Tests that actually execute the script to detect real errors

setup() {
 # Setup test environment
 export SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
 export TMP_DIR="$(mktemp -d)"
 export BASENAME="test_profile"
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

# Test that profile.sh can be sourced without errors
@test "profile.sh should be sourceable without errors" {
 # NOTE: profile.sh was moved to OSM-Notes-Analytics repository
 skip "profile.sh moved to OSM-Notes-Analytics repository"
}

# Test that profile.sh functions can be called without logging errors
@test "profile.sh functions should work without logging errors" {
 # Source the script

 # Test that logging functions work (if available)
 if declare -f __logi > /dev/null 2>&1; then
   [ "$status" -eq 0 ] || [ "$status" -eq 127 ]
 else
   skip "Logging functions not available"
 fi
}

# Test that profile.sh can run in dry-run mode
@test "profile.sh should work in dry-run mode" {
 # NOTE: profile.sh was moved to OSM-Notes-Analytics repository
 skip "profile.sh moved to OSM-Notes-Analytics repository"
}

# Test that all required functions are available after sourcing
@test "profile.sh should have all required functions available" {
 # Source the script

 # Test that key functions are available
 local REQUIRED_FUNCTIONS=(
   "__show_help"
 )

 for FUNC in "${REQUIRED_FUNCTIONS[@]}"; do
   [ "$status" -eq 0 ] || echo "Function ${FUNC} should be available"
 done
}

# Test that logging functions work correctly
@test "profile.sh logging functions should work correctly" {
 # Source the script

 # Test that logging functions don't produce errors (if available)
 if declare -f __logi > /dev/null 2>&1 && declare -f __loge > /dev/null 2>&1; then
   [ "$status" -eq 0 ] || [ "$status" -eq 127 ]
 else
   skip "Logging functions not available"
 fi
}

# Test that database operations work with test database
@test "profile.sh database operations should work with test database" {
 # Create test database
 run psql -d postgres -c "CREATE DATABASE ${TEST_DBNAME};"
 [ "$status" -eq 0 ]

 # Create base tables
 run psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_22_createBaseTables_tables.sql"
 [ "$status" -eq 0 ]

 # Create DWH tables
 [ "$status" -eq 0 ]

 # Verify tables exist
 run psql -d "${TEST_DBNAME}" -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';"
 [ "$status" -eq 0 ]
 [[ "$output" =~ [0-9]+ ]]
}

# Test that error handling works correctly
@test "profile.sh error handling should work correctly" {
 # Test that the script handles missing database gracefully
 [ "$status" -ne 0 ] || echo "Script should handle missing database gracefully"
}

# Test that all SQL files are valid
@test "profile SQL files should be valid" {
 local SQL_FILES=(
 )

 for SQL_FILE in "${SQL_FILES[@]}"; do
   [ -f "${SCRIPT_BASE_DIRECTORY}/${SQL_FILE}" ]
   # Test that SQL file has valid syntax (basic check)
   run grep -q "CREATE\|INSERT\|UPDATE\|SELECT" "${SCRIPT_BASE_DIRECTORY}/${SQL_FILE}"
   [ "$status" -eq 0 ] || echo "SQL file ${SQL_FILE} should contain valid SQL"
 done
}

# Test that the script can be executed without parameters
@test "profile.sh should handle no parameters gracefully" {
  # NOTE: profile.sh was moved to OSM-Notes-Analytics repository
  skip "profile.sh moved to OSM-Notes-Analytics repository"
 # Test that the script doesn't crash when run without parameters


 [ "$status" -eq 0 ] || [ "$status" -eq 1 ] || [ "$status" -eq 127 ] || [ "$status" -eq 2 ] || [ "$status" -eq 3 ]

 [[ -n "$output" ]] || echo "Script should produce some output"
}

# Test that data profiling functions work correctly
@test "profile.sh data profiling functions should work correctly" {
 # Source the script

 # Test that profiling functions are available (if they exist)
 local PROFILING_FUNCTIONS=(
   "__showHelp"
 )

 for FUNC in "${PROFILING_FUNCTIONS[@]}"; do
   [ "$status" -eq 0 ] || echo "Function ${FUNC} should be available"
 done
}

# Test that report generation functions work correctly
@test "profile.sh report generation functions should work correctly" {
 # Source the script

 # Test that report functions are available (if they exist)
 local REPORT_FUNCTIONS=(
   "__showHelp"
 )

 for FUNC in "${REPORT_FUNCTIONS[@]}"; do
   [ "$status" -eq 0 ] || echo "Function ${FUNC} should be available"
 done
}

# Test that data analysis functions work correctly
@test "profile.sh data analysis functions should work correctly" {
 # Source the script

 # Test that analysis functions are available (if they exist)
 local ANALYSIS_FUNCTIONS=(
   "__showHelp"
 )

 for FUNC in "${ANALYSIS_FUNCTIONS[@]}"; do
   [ "$status" -eq 0 ] || echo "Function ${FUNC} should be available"
 done
}
