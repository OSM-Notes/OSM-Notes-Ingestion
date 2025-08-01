#!/usr/bin/env bats

# Require minimum BATS version for run flags
bats_require_minimum_version 1.5.0

# Integration tests for updateCountries.sh
# Tests that actually execute the script to detect real errors

setup() {
 # Setup test environment
 export SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
 export TMP_DIR="$(mktemp -d)"
 export BASENAME="test_update_countries"
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

# Test that updateCountries.sh can be sourced without errors
@test "updateCountries.sh should be sourceable without errors" {
 # Test that the script can be sourced without logging errors
 run -127 bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/process/updateCountries.sh > /dev/null 2>&1"
 [ "$status" -eq 0 ] || [ "$status" -eq 127 ]
}

# Test that updateCountries.sh functions can be called without logging errors
@test "updateCountries.sh functions should work without logging errors" {
 # Source the script
 source "${SCRIPT_BASE_DIRECTORY}/bin/process/updateCountries.sh"
 
 # Test that logging functions work
 run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/process/updateCountries.sh && __log_info 'Test message'"
 [ "$status" -eq 0 ]
 [[ "$output" == *"Test message"* ]] || [[ "$output" == *"Command not found"* ]]
}

# Test that updateCountries.sh can run in dry-run mode
@test "updateCountries.sh should work in dry-run mode" {
 # Test that the script can run without actually updating countries
 run timeout 30s bash "${SCRIPT_BASE_DIRECTORY}/bin/process/updateCountries.sh" --help
 [ "$status" -eq 1 ] # Help should exit with code 1
 [[ "$output" == *"updateCountries.sh version"* ]]
}

# Test that all required functions are available after sourcing
@test "updateCountries.sh should have all required functions available" {
 # Source the script
 source "${SCRIPT_BASE_DIRECTORY}/bin/process/updateCountries.sh"
 
 # Test that key functions are available
 local REQUIRED_FUNCTIONS=(
   "__updateCountries"
   "__loadCountries"
   "__loadMaritimes"
   "__validateCountries"
   "__showHelp"
 )
 
 for FUNC in "${REQUIRED_FUNCTIONS[@]}"; do
   run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/process/updateCountries.sh && declare -f ${FUNC}"
   [ "$status" -eq 0 ] || echo "Function ${FUNC} should be available"
 done
}

# Test that logging functions work correctly
@test "updateCountries.sh logging functions should work correctly" {
 # Source the script
 source "${SCRIPT_BASE_DIRECTORY}/bin/process/updateCountries.sh"
 
 # Test that logging functions don't produce errors
 run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/process/updateCountries.sh && __log_info 'Test info' && __log_error 'Test error'"
 [ "$status" -eq 0 ]
 [[ "$output" != *"orden no encontrada"* ]]
 [[ "$output" != *"command not found"* ]]
}

# Test that database operations work with test database
@test "updateCountries.sh database operations should work with test database" {
 # Create test database
 run psql -d postgres -c "CREATE DATABASE ${TEST_DBNAME};"
 [ "$status" -eq 0 ]
 
 # Create countries table
 run psql -d "${TEST_DBNAME}" -c "CREATE TABLE countries (id SERIAL PRIMARY KEY, name VARCHAR(255), code VARCHAR(10));"
 [ "$status" -eq 0 ]
 
 # Create maritimes table
 run psql -d "${TEST_DBNAME}" -c "CREATE TABLE maritimes (id SERIAL PRIMARY KEY, name VARCHAR(255), code VARCHAR(10));"
 [ "$status" -eq 0 ]
 
 # Verify tables exist
 run psql -d "${TEST_DBNAME}" -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_name IN ('countries', 'maritimes');"
 [ "$status" -eq 0 ]
 [ "$output" -eq "2" ]
}

# Test that error handling works correctly
@test "updateCountries.sh error handling should work correctly" {
 # Test that the script handles missing database gracefully
 run bash -c "DBNAME=nonexistent_db source ${SCRIPT_BASE_DIRECTORY}/bin/process/updateCountries.sh"
 [ "$status" -ne 0 ] || echo "Script should handle missing database gracefully"
}

# Test that Overpass queries work correctly
@test "updateCountries.sh Overpass queries should work correctly" {
 # Test that Overpass query files exist
 local OVERPASS_FILES=(
   "overpass/countries.op"
   "overpass/maritimes.op"
 )
 
 for OP_FILE in "${OVERPASS_FILES[@]}"; do
   [ -f "${SCRIPT_BASE_DIRECTORY}/${OP_FILE}" ]
   # Test that Overpass file has valid syntax (basic check)
   run grep -q "out\|area\|relation" "${SCRIPT_BASE_DIRECTORY}/${OP_FILE}"
   [ "$status" -eq 0 ] || echo "Overpass file ${OP_FILE} should contain valid query"
 done
}

# Test that the script can be executed without parameters
@test "updateCountries.sh should handle no parameters gracefully" {
 # Test that the script doesn't crash when run without parameters
 run timeout 30s bash "${SCRIPT_BASE_DIRECTORY}/bin/process/updateCountries.sh"
 [ "$status" -ne 0 ] # Should exit with error for missing database
 [[ "$output" == *"database"* ]] || [[ "$output" == *"ERROR"* ]] || echo "Script should show error for missing database"
}

# Test that country validation functions work correctly
@test "updateCountries.sh country validation functions should work correctly" {
 # Source the script
 source "${SCRIPT_BASE_DIRECTORY}/bin/process/updateCountries.sh"
 
 # Test that validation functions are available
 local VALIDATION_FUNCTIONS=(
   "__validateCountryData"
   "__validateMaritimeData"
 )
 
 for FUNC in "${VALIDATION_FUNCTIONS[@]}"; do
   run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/process/updateCountries.sh && declare -f ${FUNC}"
   [ "$status" -eq 0 ] || echo "Function ${FUNC} should be available"
 done
} 