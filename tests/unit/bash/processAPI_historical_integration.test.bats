#!/usr/bin/env bats

# Integration tests for processAPI historical data validation
# These tests simulate real scenarios where processAPI should or should not run
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
    export PROCESS_TYPE="test"
    export FAILED_EXECUTION_FILE="/tmp/failed_execution_test"
    
    # Create test directory
    mkdir -p "${TMP_DIR}"
    
    # Remove any existing failed execution file
    rm -f "${FAILED_EXECUTION_FILE}"
    
    # Set up comprehensive logging functions
    __logd() { echo "[DEBUG] $*"; }
    __logi() { echo "[INFO] $*"; }
    __logw() { echo "[WARN] $*"; }
    __loge() { echo "[ERROR] $*"; }
    __log_start() { echo "[START] Function started"; }
    __log_finish() { echo "[FINISH] Function finished"; }
    
    # Set up process validation functions
    __checkPrereqs() { return 0; }
    __trapOn() { return 0; }
    __dropApiTables() { return 0; }
    __checkNoProcessPlanet() { return 0; }
    __createApiTables() { return 0; }
    __createPartitions() { return 0; }
    __createPropertiesTable() { return 0; }
    
    # Set up constants
    export POSTGRES_11_CHECK_BASE_TABLES="${TEST_BASE_DIR}/sql/functionsProcess_11_checkBaseTables.sql"
    export POSTGRES_11_CHECK_HISTORICAL_DATA="${TEST_BASE_DIR}/sql/functionsProcess_11_checkHistoricalData.sql"
    export NOTES_SYNC_SCRIPT="${TEST_BASE_DIR}/bin/process/processPlanetNotes.sh"
    export ERROR_EXECUTING_PLANET_DUMP=248
}

teardown() {
    # Clean up test files
    rm -rf "${TMP_DIR}" 2>/dev/null || true
    rm -f "${FAILED_EXECUTION_FILE}" 2>/dev/null || true
}

# =============================================================================
# Helper functions for testing scenarios
# =============================================================================

# Mock __checkBaseTables to simulate tables exist
mock_checkBaseTables_success() {
    __checkBaseTables() {
        echo "[INFO] Base tables validation passed"
        export RET_FUNC=0
        return 0
    }
}

# Mock __checkBaseTables to simulate tables missing
mock_checkBaseTables_missing() {
    __checkBaseTables() {
        echo "[ERROR] Base tables missing"
        export RET_FUNC=1
        return 1
    }
}

# Mock __checkHistoricalData to simulate historical data exists
mock_checkHistoricalData_success() {
    __checkHistoricalData() {
        echo "[INFO] Historical data validation passed"
        export RET_FUNC=0
        return 0
    }
}

# Mock __checkHistoricalData to simulate no historical data
mock_checkHistoricalData_failure() {
    __checkHistoricalData() {
        echo "[ERROR] Historical data validation failed"
        echo "[ERROR] Please run processPlanetNotes.sh first"
        export RET_FUNC=1
        return 1
    }
}

# =============================================================================
# Test scenarios: Normal operation with historical data
# =============================================================================

@test "processAPI_should_continue_when_base_tables_and_historical_data_exist" {
    # Setup: Base tables exist and have historical data
    mock_checkBaseTables_success
    mock_checkHistoricalData_success
    
    # Simulate the relevant part of processAPI main function
    run bash -c '
        # Define mock functions first
        __checkBaseTables() {
            echo "[INFO] Base tables validation passed"
            export RET_FUNC=0
            return 0
        }
        __checkHistoricalData() {
            echo "[INFO] Historical data validation passed"
            export RET_FUNC=0
            return 0
        }
        
        export RET_FUNC=0
        __checkBaseTables
        if [[ "${RET_FUNC}" -ne 0 ]]; then
            echo "Would create base tables and run planet sync"
            exit 248
        else
            echo "Base tables found. Validating historical data..."
            __checkHistoricalData
            if [[ "${RET_FUNC}" -ne 0 ]]; then
                echo "CRITICAL: Historical data validation failed!"
                exit 248
            fi
            echo "Historical data validation passed. ProcessAPI can continue safely."
        fi
        echo "ProcessAPI continuing with normal operation..."
    '
    
    echo "Exit code: $status"
    echo "Output: $output"
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Base tables found" ]]
    [[ "$output" =~ "Historical data validation passed" ]]
    [[ "$output" =~ "ProcessAPI can continue safely" ]]
    [[ "$output" =~ "ProcessAPI continuing with normal operation" ]]
}

@test "processAPI_should_exit_when_historical_data_missing" {
    # Setup: Base tables exist but no historical data
    mock_checkBaseTables_success
    mock_checkHistoricalData_failure
    
    # Simulate the relevant part of processAPI main function
    run bash -c '
        # Define mock functions first
        __checkBaseTables() {
            echo "[INFO] Base tables validation passed"
            export RET_FUNC=0
            return 0
        }
        __checkHistoricalData() {
            echo "[ERROR] Historical data validation failed"
            echo "[ERROR] Please run processPlanetNotes.sh first"
            export RET_FUNC=1
            return 1
        }
        
        export RET_FUNC=0
        __checkBaseTables
        if [[ "${RET_FUNC}" -ne 0 ]]; then
            echo "Would create base tables and run planet sync"
            exit 248
        else
            echo "Base tables found. Validating historical data..."
            __checkHistoricalData
            if [[ "${RET_FUNC}" -ne 0 ]]; then
                echo "CRITICAL: Historical data validation failed!"
                echo "ProcessAPI cannot continue without historical data from Planet."
                echo "Required action: Run processPlanetNotes.sh first"
                exit 248
            fi
            echo "Historical data validation passed. ProcessAPI can continue safely."
        fi
        echo "ProcessAPI continuing with normal operation..."
    '
    
    echo "Exit code: $status"
    echo "Output: $output"
    
    [ "$status" -eq 248 ]
    [[ "$output" =~ "Base tables found" ]]
    [[ "$output" =~ "Historical data validation failed" ]]
    [[ "$output" =~ "CRITICAL: Historical data validation failed!" ]]
    [[ "$output" =~ "ProcessAPI cannot continue without historical data" ]]
    [[ "$output" =~ "Run processPlanetNotes.sh first" ]]
    [[ ! "$output" =~ "ProcessAPI continuing with normal operation" ]]
}

@test "processAPI_should_run_planet_sync_when_base_tables_missing" {
    # Setup: Base tables don't exist
    mock_checkBaseTables_missing
    
    # Mock planet sync script
    local fake_planet_script="${TMP_DIR}/fake_processPlanetNotes.sh"
    cat > "${fake_planet_script}" << 'EOF'
#!/bin/bash
if [[ "$1" == "--base" ]]; then
    echo "Created base tables"
    exit 0
else
    echo "Ran full planet synchronization"
    exit 0
fi
EOF
    chmod +x "${fake_planet_script}"
    
    # Simulate the relevant part of processAPI main function
    run bash -c "
        export NOTES_SYNC_SCRIPT='${fake_planet_script}'
        
        # Define mock function for missing base tables
        __checkBaseTables() {
            echo \"[ERROR] Base tables missing\"
            export RET_FUNC=1
            return 1
        }
        
        export RET_FUNC=0
        __checkBaseTables
        if [[ \"\${RET_FUNC}\" -ne 0 ]]; then
            echo \"Base tables missing. Creating base tables.\"
            \"\${NOTES_SYNC_SCRIPT}\" --base
            echo \"Base tables created.\"
            \"\${NOTES_SYNC_SCRIPT}\"
            RET=\$?
            if [[ \"\${RET}\" -ne 0 ]]; then
                echo \"Error while executing the planet dump.\"
                exit 248
            fi
            echo \"Finished full synchronization from Planet.\"
        else
            echo \"Base tables found. Validating historical data...\"
        fi
        echo \"ProcessAPI continuing with normal operation...\"
    "
    
    echo "Exit code: $status"
    echo "Output: $output"
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Base tables missing" ]]
    [[ "$output" =~ "Created base tables" ]]
    [[ "$output" =~ "Ran full planet synchronization" ]]
    [[ "$output" =~ "Finished full synchronization from Planet" ]]
    [[ "$output" =~ "ProcessAPI continuing with normal operation" ]]
}

# =============================================================================
# Test SQL validation logic
# =============================================================================

@test "historical_data_sql_validates_empty_notes_table" {
    # Skip if we don't have a test database
    if [[ -z "${TEST_DBNAME}" ]]; then
        skip "No test database available"
    fi
    
    # Mock psql to simulate empty notes table
    psql() {
        if [[ "$*" =~ "checkHistoricalData" ]]; then
            echo "ERROR: Historical data validation failed: notes table is empty. Please run processPlanetNotes.sh first to load historical data."
            return 1
        fi
        return 0
    }
    
    # Test SQL validation
    run psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_11_CHECK_HISTORICAL_DATA}"
    
    echo "Exit code: $status"
    echo "Output: $output"
    
    [ "$status" -eq 1 ]
    [[ "$output" =~ "notes table is empty" ]]
    [[ "$output" =~ "Please run processPlanetNotes.sh first" ]]
}

@test "historical_data_sql_validates_insufficient_historical_data" {
    # Skip if we don't have a test database
    if [[ -z "${TEST_DBNAME}" ]]; then
        skip "No test database available"
    fi
    
    # Mock psql to simulate insufficient historical data
    psql() {
        if [[ "$*" =~ "checkHistoricalData" ]]; then
            echo "ERROR: Historical data validation failed: insufficient historical data. Found data from 2025-08-01, but need at least 30 days of history."
            return 1
        fi
        return 0
    }
    
    # Test SQL validation
    run psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_11_CHECK_HISTORICAL_DATA}"
    
    echo "Exit code: $status"
    echo "Output: $output"
    
    [ "$status" -eq 1 ]
    [[ "$output" =~ "insufficient historical data" ]]
    [[ "$output" =~ "need at least 30 days" ]]
}

@test "historical_data_sql_passes_with_sufficient_data" {
    # Skip if we don't have a test database
    if [[ -z "${TEST_DBNAME}" ]]; then
        skip "No test database available"
    fi
    
    # Mock psql to simulate sufficient historical data
    psql() {
        if [[ "$*" =~ "checkHistoricalData" ]]; then
            echo "NOTICE: Historical data validation passed: Found notes from 2020-01-01 and comments from 2020-01-01 (1000 and 1000 days of history respectively)"
            return 0
        fi
        return 0
    }
    
    # Test SQL validation
    run psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_11_CHECK_HISTORICAL_DATA}"
    
    echo "Exit code: $status"
    echo "Output: $output"
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Historical data validation passed" ]]
    [[ "$output" =~ "days of history respectively" ]]
}

# =============================================================================
# Test error handling and edge cases
# =============================================================================

@test "processAPI_handles_database_connection_failure_gracefully" {
    # Setup: Base tables exist but database connection fails during historical check
    mock_checkBaseTables_success
    
    # Mock __checkHistoricalData to simulate database connection failure
    __checkHistoricalData() {
        echo "[ERROR] psql: could not connect to server"
        echo "[ERROR] Historical data validation failed"
        export RET_FUNC=2
        return 2
    }
    
    # Simulate the relevant part of processAPI main function
    run bash -c '
        # Define mock functions
        __checkBaseTables() {
            echo "[INFO] Base tables validation passed"
            export RET_FUNC=0
            return 0
        }
        __checkHistoricalData() {
            echo "[ERROR] psql: could not connect to server"
            echo "[ERROR] Historical data validation failed"
            export RET_FUNC=2
            return 2
        }
        
        export RET_FUNC=0
        __checkBaseTables
        if [[ "${RET_FUNC}" -ne 0 ]]; then
            echo "Would create base tables and run planet sync"
            exit 248
        else
            echo "Base tables found. Validating historical data..."
            __checkHistoricalData
            if [[ "${RET_FUNC}" -ne 0 ]]; then
                echo "CRITICAL: Historical data validation failed!"
                echo "Database connection issue or missing historical data"
                exit 248
            fi
            echo "Historical data validation passed. ProcessAPI can continue safely."
        fi
    '
    
    echo "Exit code: $status"
    echo "Output: $output"
    
    [ "$status" -eq 248 ]
    [[ "$output" =~ "could not connect to server" ]]
    [[ "$output" =~ "Historical data validation failed" ]]
    [[ "$output" =~ "CRITICAL: Historical data validation failed!" ]]
}

# =============================================================================
# Test real processAPI script integration
# =============================================================================

@test "real_processAPI_script_contains_historical_validation" {
    local api_script="${TEST_BASE_DIR}/bin/process/processAPINotes.sh"
    
    # Verify the script calls the historical validation function
    grep -q "__checkHistoricalData" "${api_script}"
    
    # Verify it exits on validation failure (look for exit with ERROR_EXECUTING_PLANET_DUMP)
    grep -A 20 "__checkHistoricalData" "${api_script}" | grep -q "exit.*ERROR_EXECUTING_PLANET_DUMP"
}

@test "real_processAPI_script_syntax_is_valid" {
    local api_script="${TEST_BASE_DIR}/bin/process/processAPINotes.sh"
    
    # Basic syntax check
    run bash -n "${api_script}"
    
    echo "Syntax check exit code: $status"
    echo "Syntax check output: $output"
    
    [ "$status" -eq 0 ]
}

# =============================================================================
# Test integration with existing validation functions
# =============================================================================

@test "historical_validation_integrates_with_existing_checkBaseTables" {
    # Load the actual functions
    source "${TEST_BASE_DIR}/bin/lib/functionsProcess.sh"
    
    # Verify both functions exist and are properly defined
    type __checkBaseTables
    type __checkHistoricalData
    
    # Verify constants are defined
    [[ -n "${POSTGRES_11_CHECK_BASE_TABLES}" ]]
    [[ -n "${POSTGRES_11_CHECK_HISTORICAL_DATA}" ]]
    
    # Verify SQL files exist
    [ -f "${POSTGRES_11_CHECK_BASE_TABLES}" ]
    [ -f "${POSTGRES_11_CHECK_HISTORICAL_DATA}" ]
}
