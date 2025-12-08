#!/usr/bin/env bats

# Extended Validation Database Tests
# Tests for database connection, tables, and extensions validation
# Author: Andres Gomez (AngocA)
# Version: 2025-11-26

setup() {
 # Load test helper functions
 load "${BATS_TEST_DIRNAME}/../../test_helper.bash"

 # Ensure SCRIPT_BASE_DIRECTORY is set
 if [[ -z "${SCRIPT_BASE_DIRECTORY:-}" ]]; then
   export SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
 fi

 # Ensure TEST_BASE_DIR is set (used by some tests)
 if [[ -z "${TEST_BASE_DIR:-}" ]]; then
   export TEST_BASE_DIR="${SCRIPT_BASE_DIRECTORY}"
 fi

 # Load test properties (not production properties)
 if [[ -f "${SCRIPT_BASE_DIRECTORY}/etc/properties_test.sh" ]]; then
  source "${SCRIPT_BASE_DIRECTORY}/etc/properties_test.sh"
 else
  # Fallback to production properties if test properties not found
  source "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh"
 fi
 source "${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh"
 source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/validationFunctions.sh"

 # Create temporary test files
 TEST_DIR=$(mktemp -d)
}

teardown() {
 # Clean up temporary files
 rm -rf "${TEST_DIR}"
}

@test "validate_database_connection simple test" {
 # Simple test to isolate the problem
 echo "DEBUG: Simple database connection test"

 # Test with a command that should definitely fail
 run psql -h localhost -p 5434 -U test_user -d test_db -c "SELECT 1;" 2>&1
 echo "DEBUG: psql direct command status: ${status}"
 echo "DEBUG: psql direct command output: ${output}"

 # This should fail
 [[ "${status}" -ne 0 ]]
}

@test "validate_database_connection with invalid database" {
 # Test with clearly invalid parameters that should fail
 # Using a valid port but no PostgreSQL service on it
 # Note: We can't unset TEST_* variables as they're set by test_helper.bash
 run __validate_database_connection "test_db" "test_user" "localhost" "5434"
 [[ "${status}" -eq 1 ]]
}

@test "validate_database_tables with missing parameters" {
 # Unset any existing database variables
 unset DBNAME DB_USER DBHOST DBPORT

 run __validate_database_tables
 [[ "${status}" -eq 1 ]]
}

@test "validate_database_tables with missing tables" {
 # Unset any existing database variables
 unset DBNAME DB_USER DBHOST DBPORT

 run __validate_database_tables "testdb" "testuser" "localhost" "5432"
 [[ "${status}" -eq 1 ]]
}

@test "validate_database_extensions with missing parameters" {
 # Unset any existing database variables
 unset DBNAME DB_USER DBHOST DBPORT

 run __validate_database_extensions
 [[ "${status}" -eq 1 ]]
}

@test "validate_database_extensions with missing extensions" {
 # Unset any existing database variables
 unset DBNAME DB_USER DBHOST DBPORT

 run __validate_database_extensions "testdb" "testuser" "localhost" "5432"
 [[ "${status}" -eq 1 ]]
}

@test "validate_database_extensions with specific extensions" {
 # Test with clearly invalid parameters that should fail
 # Using a valid port but no PostgreSQL service on it
 # Note: We can't unset TEST_* variables as they're set by test_helper.bash
 run __validate_database_extensions "test_db" "test_user" "localhost" "5434" "postgis" "btree_gist"
 [[ "${status}" -eq 1 ]]
}


