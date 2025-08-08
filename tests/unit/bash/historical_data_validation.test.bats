#!/usr/bin/env bats

# Unit tests for historical data validation in processAPI
# Author: Andres Gomez (AngocA)
# Version: 2025-08-07

load "$(dirname "$BATS_TEST_FILENAME")/../../test_helper.bash"

# =============================================================================
# Test setup and teardown
# =============================================================================

setup() {
    # Set up required environment variables
    export BASENAME="test"
    export TMP_DIR="/tmp/test_$$"
    export DBNAME="${TEST_DBNAME:-test_db}"
    export SCRIPT_BASE_DIRECTORY="${TEST_BASE_DIR}"
    export LOG_FILENAME="/tmp/test.log"
    export LOCK="/tmp/test.lock"
    export MAX_THREADS="2"
    
    # Create test directory
    mkdir -p "${TMP_DIR}"
    
    # Set up logging functions if not available
    if ! declare -f __logd >/dev/null; then
        __logd() { echo "[DEBUG] $*"; }
        __logi() { echo "[INFO] $*"; }
        __logw() { echo "[WARN] $*"; }
        __loge() { echo "[ERROR] $*"; }
    fi
    
    # Set up additional logging functions from bash_logger
    if ! declare -f __log_start >/dev/null; then
        __log_start() { echo "[START] Function started"; }
        __log_finish() { echo "[FINISH] Function finished"; }
    fi
    
    # Extract only the checkHistoricalData function to avoid loading the entire script
    extract_historical_data_function
}

teardown() {
    # Clean up test files
    rm -rf "${TMP_DIR}" 2>/dev/null || true
}

# =============================================================================
# Helper functions
# =============================================================================

# Extract only the __checkHistoricalData function without loading the entire script
extract_historical_data_function() {
    # Extract the __checkHistoricalData function
    sed -n '/^function __checkHistoricalData/,/^}/p' "${TEST_BASE_DIR}/bin/functionsProcess.sh" > "${TMP_DIR}/historical_function.sh"
    
    # Source the extracted function
    source "${TMP_DIR}/historical_function.sh"
    
    # Set the required constant
    export POSTGRES_11_CHECK_HISTORICAL_DATA="${TEST_BASE_DIR}/sql/functionsProcess_11_checkHistoricalData.sql"
}

# =============================================================================
# Test historical data validation function
# =============================================================================

@test "test_checkHistoricalData_function_exists" {
    # Verify function exists
    type __checkHistoricalData
}

@test "test_checkHistoricalData_with_mock_database" {
    # Skip if we don't have a test database
    if [[ -z "${TEST_DBNAME}" ]]; then
        skip "No test database available"
    fi
    
    # Mock psql to simulate successful historical data validation
    psql() {
        echo "Mock psql executed with args: $*"
        if [[ "$*" =~ "checkHistoricalData" ]]; then
            echo "NOTICE: Historical data validation passed: Found notes from 2020-01-01 and comments from 2020-01-01"
            return 0
        fi
        return 0
    }
    
    # Test the function
    run __checkHistoricalData
    
    echo "Exit code: $status"
    echo "Output: $output"
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Validating historical data" ]]
    [[ "$output" =~ "Historical data validation passed" ]]
}

@test "test_checkHistoricalData_fails_with_empty_tables" {
    # Skip if we don't have a test database
    if [[ -z "${TEST_DBNAME}" ]]; then
        skip "No test database available"
    fi
    
    # Mock psql to simulate empty tables
    psql() {
        echo "Mock psql executed with args: $*"
        if [[ "$*" =~ "checkHistoricalData" ]]; then
            echo "ERROR: Historical data validation failed: notes table is empty"
            return 1
        fi
        return 0
    }
    
    # Test the function
    run __checkHistoricalData
    
    echo "Exit code: $status"
    echo "Output: $output"
    
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Historical data validation failed" ]]
    [[ "$output" =~ "Please run processPlanetNotes.sh first" ]]
}

@test "test_checkHistoricalData_fails_with_insufficient_history" {
    # Skip if we don't have a test database
    if [[ -z "${TEST_DBNAME}" ]]; then
        skip "No test database available"
    fi
    
    # Mock psql to simulate insufficient historical data
    psql() {
        echo "Mock psql executed with args: $*"
        if [[ "$*" =~ "checkHistoricalData" ]]; then
            echo "ERROR: Historical data validation failed: insufficient historical data"
            return 1
        fi
        return 0
    }
    
    # Test the function
    run __checkHistoricalData
    
    echo "Exit code: $status"
    echo "Output: $output"
    
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Historical data validation failed" ]]
    [[ "$output" =~ "ProcessAPI requires historical data" ]]
}

# =============================================================================
# Test SQL script existence and syntax
# =============================================================================

@test "test_historical_data_sql_script_exists" {
    [ -f "${TEST_BASE_DIR}/sql/functionsProcess_11_checkHistoricalData.sql" ]
}

@test "test_historical_data_sql_script_syntax" {
    # Basic syntax check for the SQL script
    local sql_file="${TEST_BASE_DIR}/sql/functionsProcess_11_checkHistoricalData.sql"
    
    # Check that the file contains expected keywords
    grep -q "DO" "${sql_file}"
    grep -q "DECLARE" "${sql_file}"
    grep -q "notes" "${sql_file}"
    grep -q "note_comments" "${sql_file}"
    grep -q "historical" "${sql_file}"
    grep -q "RAISE EXCEPTION" "${sql_file}"
}

@test "test_historical_data_sql_script_validation_logic" {
    local sql_file="${TEST_BASE_DIR}/sql/functionsProcess_11_checkHistoricalData.sql"
    
    # Check that the script validates notes table
    grep -q "FROM notes" "${sql_file}"
    
    # Check that the script validates note_comments table
    grep -q "FROM note_comments" "${sql_file}"
    
    # Check that it validates minimum historical days
    grep -q "min_historical_days" "${sql_file}"
    
    # Check that it has proper error messages
    grep -q "Please run processPlanetNotes.sh first" "${sql_file}"
}

# =============================================================================
# Test processAPI integration
# =============================================================================

@test "test_processAPI_calls_historical_validation" {
    local api_script="${TEST_BASE_DIR}/bin/process/processAPINotes.sh"
    
    # Check that processAPINotes.sh calls the historical data validation
    grep -q "__checkHistoricalData" "${api_script}"
}

@test "test_processAPI_exits_on_historical_validation_failure" {
    local api_script="${TEST_BASE_DIR}/bin/process/processAPINotes.sh"
    
    # Check that processAPINotes.sh exits when historical validation fails
    grep -A 15 "__checkHistoricalData" "${api_script}" | grep -q "exit"
}

@test "test_processAPI_provides_helpful_error_messages" {
    local api_script="${TEST_BASE_DIR}/bin/process/processAPINotes.sh"
    
    # Check that processAPINotes.sh provides helpful error messages
    grep -A 10 "Historical data validation failed" "${api_script}" | grep -q "ProcessAPI cannot continue"
    grep -A 10 "Historical data validation failed" "${api_script}" | grep -q "Run processPlanetNotes.sh first"
}

# =============================================================================
# Test error handling and edge cases
# =============================================================================

@test "test_checkHistoricalData_handles_database_connection_failure" {
    # Skip if we don't have a test database
    if [[ -z "${TEST_DBNAME}" ]]; then
        skip "No test database available"
    fi
    
    # Mock psql to simulate database connection failure
    psql() {
        echo "psql: could not connect to server"
        return 2
    }
    
    # Test the function
    run __checkHistoricalData
    
    echo "Exit code: $status"
    echo "Output: $output"
    
    [ "$status" -eq 2 ]
    [[ "$output" =~ "Historical data validation failed" ]]
}

@test "test_historical_validation_constants_defined" {
    # Check that the SQL file constant is properly defined
    source "${TEST_BASE_DIR}/bin/functionsProcess.sh"
    
    # Verify the constant is defined
    [[ -n "${POSTGRES_11_CHECK_HISTORICAL_DATA}" ]]
    
    # Verify it points to the correct file
    [[ "${POSTGRES_11_CHECK_HISTORICAL_DATA}" =~ "checkHistoricalData.sql" ]]
}
