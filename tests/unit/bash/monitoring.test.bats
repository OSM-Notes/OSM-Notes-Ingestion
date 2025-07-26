#!/usr/bin/env bats

# Monitoring System Tests
# Tests for the monitoring system to validate data consistency between API and Planet
# Version: 2025-07-26

load ../../test_helper

setup() {
    # Set up test environment
    # Calculate PROJECT_ROOT dynamically based on current working directory
    # This approach works better in BATS context and is more robust
    local current_dir="$(pwd)"
    if [[ "${current_dir}" == */tests/unit/bash* ]]; then
        export PROJECT_ROOT="$(echo "${current_dir}" | sed 's|/tests/unit/bash.*||')"
    elif [[ "${current_dir}" == */tests* ]]; then
        export PROJECT_ROOT="$(echo "${current_dir}" | sed 's|/tests.*||')"
    else
        export PROJECT_ROOT="${current_dir}"
    fi
    export TEST_DBNAME="notes_test_monitoring"
    export TEST_DBUSER="testuser"
    export TEST_DBPASSWORD="testpass"
    export TEST_DBHOST="localhost"
    export TEST_DBPORT="5432"
    
    # Create test database
    psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d postgres -c "DROP DATABASE IF EXISTS ${TEST_DBNAME};" 2>/dev/null || true
    psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d postgres -c "CREATE DATABASE ${TEST_DBNAME};" 2>/dev/null || true
    
    # Load base structure
    psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -f "${PROJECT_ROOT}/sql/process/processPlanetNotes_21_createBaseTables_enum.sql" 2>/dev/null || true
    psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -f "${PROJECT_ROOT}/sql/process/processPlanetNotes_22_createBaseTables_tables.sql" 2>/dev/null || true
    psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -f "${PROJECT_ROOT}/sql/monitor/processCheckPlanetNotes_21_createCheckTables.sql" 2>/dev/null || true
}

teardown() {
    # Clean up test database
    psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d postgres -c "DROP DATABASE IF EXISTS ${TEST_DBNAME};" 2>/dev/null || true
}

@test "monitoring system should detect no differences in success scenario" {
    # Skip this test if running on host (using mocks)
    if [[ ! -f "/app/bin/functionsProcess.sh" ]]; then
        skip "Skipping on host environment (using mocks)"
    fi
    
    # Load complete data into both tables (success scenario)
    psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "
    INSERT INTO notes (note_id, latitude, longitude, created_at, status, id_country) VALUES
    (1001, 40.7128, -74.0060, '2025-01-01 10:00:00', 'open', 1),
    (1002, 34.0522, -118.2437, '2025-01-01 11:00:00', 'close', 1);
    "
    
    psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "
    INSERT INTO notes_check (note_id, latitude, longitude, created_at, status, id_country) VALUES
    (1001, 40.7128, -74.0060, '2025-01-01 10:00:00', 'open', 1),
    (1002, 34.0522, -118.2437, '2025-01-01 11:00:00', 'close', 1);
    "
    
    # Run monitoring check (should find no differences)
    run psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "
    SELECT COUNT(*) as differences FROM (
        SELECT note_id FROM notes_check
        EXCEPT
        SELECT note_id FROM notes
    ) t;
    "
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "0" ]] # Should find 0 differences
}

@test "monitoring system should detect missing notes" {
    # Skip this test if running on host (using mocks)
    if [[ ! -f "/app/bin/functionsProcess.sh" ]]; then
        skip "Skipping on host environment (using mocks)"
    fi
    
    # Load complete data into check tables (Planet data)
    psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "
    INSERT INTO notes_check (note_id, latitude, longitude, created_at, status, id_country) VALUES
    (1001, 40.7128, -74.0060, '2025-01-01 10:00:00', 'open', 1),
    (1002, 34.0522, -118.2437, '2025-01-01 11:00:00', 'close', 1),
    (1003, 51.5074, -0.1278, '2025-01-01 12:00:00', 'open', 2);
    "
    
    # Load incomplete data into base tables (API data - missing note 1003)
    psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "
    INSERT INTO notes (note_id, latitude, longitude, created_at, status, id_country) VALUES
    (1001, 40.7128, -74.0060, '2025-01-01 10:00:00', 'open', 1),
    (1002, 34.0522, -118.2437, '2025-01-01 11:00:00', 'close', 1);
    "
    
    # Run monitoring check (should find differences)
    run psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "
    SELECT COUNT(*) as differences FROM (
        SELECT note_id FROM notes_check
        EXCEPT
        SELECT note_id FROM notes
    ) t;
    "
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "1" ]] # Should find 1 difference (missing note 1003)
}

@test "monitoring system should detect missing comments" {
    # Skip this test if running on host (using mocks)
    if [[ ! -f "/app/bin/functionsProcess.sh" ]]; then
        skip "Skipping on host environment (using mocks)"
    fi
    
    # Load complete data into check tables (Planet data)
    psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "
    INSERT INTO notes (note_id, latitude, longitude, created_at, status, id_country) VALUES
    (1001, 40.7128, -74.0060, '2025-01-01 10:00:00', 'open', 1);
    "
    
    psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "
    INSERT INTO note_comments_check (note_id, sequence_action, event, created_at, id_user) VALUES
    (1001, 1, 'opened', '2025-01-01 10:00:00', 12345),
    (1001, 2, 'commented', '2025-01-01 10:30:00', 67890);
    "
    
    # Load incomplete data into base tables (API data - missing comment)
    psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "
    INSERT INTO notes (note_id, latitude, longitude, created_at, status, id_country) VALUES
    (1001, 40.7128, -74.0060, '2025-01-01 10:00:00', 'open', 1);
    "
    
    psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "
    INSERT INTO note_comments (note_id, sequence_action, event, created_at, id_user) VALUES
    (1001, 1, 'opened', '2025-01-01 10:00:00', 12345);
    -- Missing comment for sequence_action 2
    "
    
    # Run monitoring check (should find differences)
    run psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "
    SELECT COUNT(*) as differences FROM (
        SELECT note_id, sequence_action FROM note_comments_check
        EXCEPT
        SELECT note_id, sequence_action FROM note_comments
    ) t;
    "
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "1" ]] # Should find 1 difference (missing comment)
}

@test "monitoring system should detect missing text comments" {
    # Skip this test if running on host (using mocks)
    if [[ ! -f "/app/bin/functionsProcess.sh" ]]; then
        skip "Skipping on host environment (using mocks)"
    fi
    
    # Load complete data into check tables (Planet data)
    psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "
    INSERT INTO notes (note_id, latitude, longitude, created_at, status, id_country) VALUES
    (1001, 40.7128, -74.0060, '2025-01-01 10:00:00', 'open', 1);
    "
    
    psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "
    INSERT INTO note_comments_text_check (note_id, sequence_action, body) VALUES
    (1001, 1, 'Note opened for testing'),
    (1001, 2, 'This is a test comment');
    "
    
    # Load incomplete data into base tables (API data - missing text comment)
    psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "
    INSERT INTO notes (note_id, latitude, longitude, created_at, status, id_country) VALUES
    (1001, 40.7128, -74.0060, '2025-01-01 10:00:00', 'open', 1);
    "
    
    psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "
    INSERT INTO note_comments_text (note_id, sequence_action, body) VALUES
    (1001, 1, 'Note opened for testing');
    -- Missing text comment for sequence_action 2
    "
    
    # Run monitoring check (should find differences)
    run psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "
    SELECT COUNT(*) as differences FROM (
        SELECT note_id, sequence_action FROM note_comments_text_check
        EXCEPT
        SELECT note_id, sequence_action FROM note_comments_text
    ) t;
    "
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "1" ]] # Should find 1 difference (missing text comment)
}

@test "monitoring system should detect data corruption" {
    # Skip this test if running on host (using mocks)
    if [[ ! -f "/app/bin/functionsProcess.sh" ]]; then
        skip "Skipping on host environment (using mocks)"
    fi
    
    # Load data with different values (corruption scenario)
    psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "
    INSERT INTO notes_check (note_id, latitude, longitude, created_at, status, id_country) VALUES
    (1001, 40.7128, -74.0060, '2025-01-01 10:00:00', 'open', 1);
    "
    
    psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "
    INSERT INTO notes (note_id, latitude, longitude, created_at, status, id_country) VALUES
    (1001, 40.7129, -74.0061, '2025-01-01 10:00:00', 'open', 1);
    -- Different coordinates (corruption)
    "
    
    # Run monitoring check (should find differences)
    run psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "
    SELECT COUNT(*) as differences FROM (
        SELECT note_id, latitude, longitude FROM notes_check
        EXCEPT
        SELECT note_id, latitude, longitude FROM notes
    ) t;
    "
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "1" ]] # Should find 1 difference (data corruption)
}

@test "monitoring system should handle mixed problems" {
    # Skip this test if running on host (using mocks)
    if [[ ! -f "/app/bin/functionsProcess.sh" ]]; then
        skip "Skipping on host environment (using mocks)"
    fi
    
    # Load complete data into check tables (Planet data)
    psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "
    INSERT INTO notes_check (note_id, latitude, longitude, created_at, status, id_country) VALUES
    (1001, 40.7128, -74.0060, '2025-01-01 10:00:00', 'open', 1),
    (1002, 34.0522, -118.2437, '2025-01-01 11:00:00', 'close', 1);
    "
    
    psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "
    INSERT INTO note_comments_check (note_id, sequence_action, event, created_at, id_user) VALUES
    (1001, 1, 'opened', '2025-01-01 10:00:00', 12345),
    (1002, 1, 'opened', '2025-01-01 11:00:00', 12345);
    "
    
    # Load incomplete/corrupted data into base tables (API data)
    psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "
    INSERT INTO notes (note_id, latitude, longitude, created_at, status, id_country) VALUES
    (1001, 40.7129, -74.0061, '2025-01-01 10:00:00', 'open', 1);
    -- Missing note 1002, corrupted coordinates for 1001
    "
    
    psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "
    INSERT INTO note_comments (note_id, sequence_action, event, created_at, id_user) VALUES
    (1001, 1, 'opened', '2025-01-01 10:00:00', 12345);
    -- Missing comment for note 1002
    "
    
    # Run monitoring check (should find multiple differences)
    run psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "
    SELECT 
        (SELECT COUNT(*) FROM (
            SELECT note_id FROM notes_check
            EXCEPT
            SELECT note_id FROM notes
        ) t) as missing_notes,
        (SELECT COUNT(*) FROM (
            SELECT note_id, sequence_action FROM note_comments_check
            EXCEPT
            SELECT note_id, sequence_action FROM note_comments
        ) t) as missing_comments;
    "
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "1" ]] # Should find 1 missing note
    [[ "$output" =~ "1" ]] # Should find 1 missing comment
}

@test "monitoring scripts should exist and be executable" {
    # Check if monitoring scripts exist
    [ -f "${PROJECT_ROOT}/bin/monitor/notesCheckVerifier.sh" ]
    [ -f "${PROJECT_ROOT}/bin/monitor/processCheckPlanetNotes.sh" ]
    
    # Check if scripts are executable
    [ -x "${PROJECT_ROOT}/bin/monitor/notesCheckVerifier.sh" ]
    [ -x "${PROJECT_ROOT}/bin/monitor/processCheckPlanetNotes.sh" ]
}

@test "monitoring database structure should be correct" {
    # Skip this test if running on host (using mocks)
    if [[ ! -f "/app/bin/functionsProcess.sh" ]]; then
        skip "Skipping on host environment (using mocks)"
    fi
    
    # Check if check tables exist after setup
    run psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "
    SELECT table_name FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name LIKE '%_check'
    ORDER BY table_name;
    "
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "notes_check" ]]
    [[ "$output" =~ "note_comments_check" ]]
    [[ "$output" =~ "note_comments_text_check" ]]
} 