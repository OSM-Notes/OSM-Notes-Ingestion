#!/usr/bin/env bats

# End-to-end integration tests for processAPI historical data validation
# These tests simulate real database scenarios
# Author: Andres Gomez (AngocA)
# Version: 2025-10-22

load "$(dirname "$BATS_TEST_FILENAME")/../test_helper.bash"

# =============================================================================
# Test setup and teardown
# =============================================================================

setup() {
    # Set up test environment
    export TEST_INTEGRATION_DB="${TEST_DBNAME}_integration"
    export TMP_DIR="/tmp/test_integration_$$"
    mkdir -p "${TMP_DIR}"
    
    # Skip if no database available
    if [[ -z "${TEST_DBNAME}" ]]; then
        skip "No test database available for integration tests"
    fi
}

teardown() {
    # Clean up
    rm -rf "${TMP_DIR}" 2>/dev/null || true
}

# =============================================================================
# Test with real database scenarios
# =============================================================================

@test "integration_historical_validation_with_empty_database" {
    # Create empty test tables to simulate fresh installation
    run bash -c "
        # Create minimal tables structure without data
        psql -d '${TEST_DBNAME}' << 'EOSQL'
        DROP TABLE IF EXISTS notes_test, note_comments_test, countries_test, logs_test, tries_test;
        
        CREATE TABLE notes_test (
            id BIGINT PRIMARY KEY,
            created_at TIMESTAMP,
            lat DECIMAL(10,7),
            lon DECIMAL(11,7),
            status VARCHAR(20)
        );
        
        CREATE TABLE note_comments_test (
            id BIGINT PRIMARY KEY,
            note_id BIGINT,
            created_at TIMESTAMP,
            action VARCHAR(20)
        );
        
        -- Test the historical validation SQL directly using external script
        -- For tests tables, reuse the official script by mapping names or keep a minimal inline DO with correct delimiters
        DO \$\$
        DECLARE
         qty INT;
        BEGIN
         SELECT COUNT(*) INTO qty FROM notes_test;
         IF (qty = 0) THEN
          RAISE EXCEPTION 'Historical data validation failed: notes table is empty';
         END IF;
        END;
        \$\$;
EOSQL
    "
    
    echo "Exit code: $status"
    echo "Output: $output"
    
    # Should fail because tables are empty
    # Note: psql returns 0 even when SQL raises exceptions, so we check the output
    [[ "$output" =~ "notes table is empty" ]] || [[ "$output" =~ "Historical data validation failed" ]]
}

@test "integration_historical_validation_with_recent_data_only" {
    # Create tables with recent data only (insufficient historical data)
    run bash -c "
        psql -d '${TEST_DBNAME}' << 'EOSQL'
        DROP TABLE IF EXISTS notes_test, note_comments_test;
        
        CREATE TABLE notes_test (
            id BIGINT PRIMARY KEY,
            created_at TIMESTAMP,
            lat DECIMAL(10,7),
            lon DECIMAL(11,7),
            status VARCHAR(20)
        );
        
        CREATE TABLE note_comments_test (
            id BIGINT PRIMARY KEY,
            note_id BIGINT,
            created_at TIMESTAMP,
            action VARCHAR(20)
        );
        
        -- Insert only recent data (last 5 days)
        INSERT INTO notes_test (id, created_at, lat, lon, status) VALUES
        (1, CURRENT_DATE - INTERVAL '1 day', 40.7128, -74.0060, 'open'),
        (2, CURRENT_DATE - INTERVAL '2 days', 40.7129, -74.0061, 'open'),
        (3, CURRENT_DATE - INTERVAL '3 days', 40.7130, -74.0062, 'closed');
        
        INSERT INTO note_comments_test (id, note_id, created_at, action) VALUES
        (1, 1, CURRENT_DATE - INTERVAL '1 day', 'opened'),
        (2, 2, CURRENT_DATE - INTERVAL '2 days', 'opened'),
        (3, 3, CURRENT_DATE - INTERVAL '3 days', 'opened');
        
        -- Test the historical validation logic
        DO \$\$
        DECLARE
         qty INT;
         oldest_note_date DATE;
         current_date_check DATE := CURRENT_DATE;
         min_historical_days INT := 30;
        BEGIN
         SELECT COUNT(*) INTO qty FROM notes_test;
         IF (qty = 0) THEN
          RAISE EXCEPTION 'Historical data validation failed: notes table is empty';
         END IF;

         SELECT MIN(created_at::DATE) INTO oldest_note_date FROM notes_test;
         IF (current_date_check - oldest_note_date < min_historical_days) THEN
          RAISE EXCEPTION 'Historical data validation failed: insufficient historical data. Found data from %, but need at least % days of history',
           oldest_note_date, min_historical_days;
         END IF;
        END;
        \$\$;
EOSQL
    "
    
    echo "Exit code: $status"
    echo "Output: $output"
    
    # Should fail because data is too recent
    # Note: psql returns 0 even when SQL raises exceptions, so we check the output
    [[ "$output" =~ "insufficient historical data" ]] || [[ "$output" =~ "need at least 30 days" ]]
}

@test "integration_historical_validation_with_sufficient_data" {
    # Create tables with sufficient historical data
    run bash -c "
        psql -d '${TEST_DBNAME}' << 'EOSQL'
        DROP TABLE IF EXISTS notes_test, note_comments_test;
        
        CREATE TABLE notes_test (
            id BIGINT PRIMARY KEY,
            created_at TIMESTAMP,
            lat DECIMAL(10,7),
            lon DECIMAL(11,7),
            status VARCHAR(20)
        );
        
        CREATE TABLE note_comments_test (
            id BIGINT PRIMARY KEY,
            note_id BIGINT,
            created_at TIMESTAMP,
            action VARCHAR(20)
        );
        
        -- Insert historical data (60 days ago)
        INSERT INTO notes_test (id, created_at, lat, lon, status) VALUES
        (1, CURRENT_DATE - INTERVAL '60 days', 40.7128, -74.0060, 'open'),
        (2, CURRENT_DATE - INTERVAL '45 days', 40.7129, -74.0061, 'open'),
        (3, CURRENT_DATE - INTERVAL '30 days', 40.7130, -74.0062, 'closed'),
        (4, CURRENT_DATE - INTERVAL '15 days', 40.7131, -74.0063, 'open'),
        (5, CURRENT_DATE - INTERVAL '1 day', 40.7132, -74.0064, 'open');
        
        INSERT INTO note_comments_test (id, note_id, created_at, action) VALUES
        (1, 1, CURRENT_DATE - INTERVAL '60 days', 'opened'),
        (2, 2, CURRENT_DATE - INTERVAL '45 days', 'opened'),
        (3, 3, CURRENT_DATE - INTERVAL '30 days', 'opened'),
        (4, 4, CURRENT_DATE - INTERVAL '15 days', 'opened'),
        (5, 5, CURRENT_DATE - INTERVAL '1 day', 'opened');
        
        -- Test the historical validation logic
        DO $$
        DECLARE
         qty INT;
         oldest_note_date DATE;
         oldest_comment_date DATE;
         current_date_check DATE := CURRENT_DATE;
         min_historical_days INT := 30;
        BEGIN
         SELECT COUNT(*) INTO qty FROM notes_test;
         IF (qty = 0) THEN
          RAISE EXCEPTION 'Historical data validation failed: notes table is empty';
         END IF;

         SELECT COUNT(*) INTO qty FROM note_comments_test;
         IF (qty = 0) THEN
          RAISE EXCEPTION 'Historical data validation failed: note_comments table is empty';
         END IF;

         SELECT MIN(created_at::DATE) INTO oldest_note_date FROM notes_test;
         IF (current_date_check - oldest_note_date < min_historical_days) THEN
          RAISE EXCEPTION 'Historical data validation failed: insufficient historical data';
         END IF;

         SELECT MIN(created_at::DATE) INTO oldest_comment_date FROM note_comments_test;
         IF (current_date_check - oldest_comment_date < min_historical_days) THEN
          RAISE EXCEPTION 'Historical data validation failed: insufficient historical comment data';
         END IF;

         RAISE NOTICE 'Historical data validation passed: Found notes from % and comments from %',
          oldest_note_date, oldest_comment_date;
        END;
        $$;
EOSQL
    "
    
    echo "Exit code: $status"
    echo "Output: $output"
    
    # Should succeed with sufficient historical data
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Historical data validation passed" ]]
}

# =============================================================================
# Test actual SQL script with real database
# =============================================================================

@test "integration_actual_historical_validation_sql_with_empty_tables" {
    # Create the actual base tables structure as empty
    run bash -c "
        # First create the base tables as expected by the system
        psql -d '${TEST_DBNAME}' << 'EOSQL'
        DROP TABLE IF EXISTS notes, note_comments, countries, logs, tries;
        
        CREATE TABLE notes (
            id BIGINT PRIMARY KEY,
            created_at TIMESTAMP WITH TIME ZONE,
            closed_at TIMESTAMP WITH TIME ZONE,
            lat DECIMAL(10,7) NOT NULL,
            lon DECIMAL(11,7) NOT NULL,
            status VARCHAR(20) NOT NULL
        );
        
        CREATE TABLE note_comments (
            id BIGINT PRIMARY KEY,
            note_id BIGINT REFERENCES notes(id),
            created_at TIMESTAMP WITH TIME ZONE NOT NULL,
            uid BIGINT,
            user_name VARCHAR(255),
            action VARCHAR(20) NOT NULL,
            text TEXT,
            html TEXT
        );
        
        CREATE TABLE countries (id SERIAL PRIMARY KEY, name VARCHAR(255));
        CREATE TABLE logs (id SERIAL PRIMARY KEY, message TEXT);
        CREATE TABLE tries (id SERIAL PRIMARY KEY, attempt_count INT);
        
        -- Insert minimal data to satisfy base table checks
        INSERT INTO countries (name) VALUES ('test_country');
        INSERT INTO logs (message) VALUES ('test_log');
        INSERT INTO tries (attempt_count) VALUES (1);
EOSQL
        
        # Now test the actual historical validation SQL
        psql -d '${TEST_DBNAME}' -v ON_ERROR_STOP=1 -f '${TEST_BASE_DIR}/sql/functionsProcess_11_checkHistoricalData.sql'
    "
    
    echo "Exit code: $status"
    echo "Output: $output"
    
    # Should fail because notes and note_comments are empty
    [ "$status" -ne 0 ]
    [[ "$output" =~ "notes table is empty" ]] || [[ "$output" =~ "Historical data validation failed" ]]
}

@test "integration_actual_historical_validation_sql_with_sufficient_data" {
    # Create base tables with sufficient historical data
    run bash -c "
        psql -d '${TEST_DBNAME}' << 'EOSQL'
        DROP TABLE IF EXISTS notes, note_comments, countries, logs, tries;
        
        CREATE TABLE notes (
            id BIGINT PRIMARY KEY,
            created_at TIMESTAMP WITH TIME ZONE,
            closed_at TIMESTAMP WITH TIME ZONE,
            lat DECIMAL(10,7) NOT NULL,
            lon DECIMAL(11,7) NOT NULL,
            status VARCHAR(20) NOT NULL
        );
        
        CREATE TABLE note_comments (
            id BIGINT PRIMARY KEY,
            note_id BIGINT REFERENCES notes(id),
            created_at TIMESTAMP WITH TIME ZONE NOT NULL,
            uid BIGINT,
            user_name VARCHAR(255),
            action VARCHAR(20) NOT NULL,
            text TEXT,
            html TEXT
        );
        
        CREATE TABLE countries (id SERIAL PRIMARY KEY, name VARCHAR(255));
        CREATE TABLE logs (id SERIAL PRIMARY KEY, message TEXT);
        CREATE TABLE tries (id SERIAL PRIMARY KEY, attempt_count INT);
        
        -- Insert sufficient historical data (60 days)
        INSERT INTO notes (id, created_at, lat, lon, status) VALUES
        (1, CURRENT_DATE - INTERVAL '60 days', 40.7128, -74.0060, 'open'),
        (2, CURRENT_DATE - INTERVAL '45 days', 40.7129, -74.0061, 'closed'),
        (3, CURRENT_DATE - INTERVAL '35 days', 40.7130, -74.0062, 'open');
        
        INSERT INTO note_comments (id, note_id, created_at, uid, user_name, action, text) VALUES
        (1, 1, CURRENT_DATE - INTERVAL '60 days', 1001, 'testuser1', 'opened', 'Test note 1'),
        (2, 2, CURRENT_DATE - INTERVAL '45 days', 1002, 'testuser2', 'opened', 'Test note 2'),
        (3, 2, CURRENT_DATE - INTERVAL '40 days', 1003, 'testuser3', 'closed', 'Closing note 2'),
        (4, 3, CURRENT_DATE - INTERVAL '35 days', 1004, 'testuser4', 'opened', 'Test note 3');
        
        -- Insert base data for other tables
        INSERT INTO countries (name) VALUES ('test_country');
        INSERT INTO logs (message) VALUES ('test_log');
        INSERT INTO tries (attempt_count) VALUES (1);
EOSQL
        
        # Test the actual historical validation SQL
        psql -d '${TEST_DBNAME}' -v ON_ERROR_STOP=1 -f '${TEST_BASE_DIR}/sql/functionsProcess_11_checkHistoricalData.sql'
    "
    
    echo "Exit code: $status"
    echo "Output: $output"
    
    # Should succeed with sufficient historical data
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Historical data validation passed" ]] || [[ "$output" =~ "days of history respectively" ]]
}
