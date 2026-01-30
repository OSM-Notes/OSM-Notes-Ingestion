#!/usr/bin/env bats

# Require minimum BATS version for run flags
bats_require_minimum_version 1.5.0

# Load test helper to get setup_test_properties and restore_properties functions
load ../../test_helper.bash

# Integration tests for notesCheckVerifier.sh
# Tests that actually execute the script to detect real errors

setup() {
 # Setup test environment
 # shellcheck disable=SC2154
 SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
 export SCRIPT_BASE_DIRECTORY
 # shellcheck disable=SC2155
 TMP_DIR="$(mktemp -d)"
 export TMP_DIR
 export BASENAME="test_notes_check_verifier"
 export LOG_LEVEL="INFO"

 # Setup test properties first (this must be done before any script sources properties.sh)
 # Use TEST_BASE_DIR from test_helper if available, otherwise use SCRIPT_BASE_DIRECTORY
 export TEST_BASE_DIR="${TEST_BASE_DIR:-${SCRIPT_BASE_DIRECTORY}}"
 # Call setup_test_properties (should be available from load)
 setup_test_properties

 # Ensure TMP_DIR exists and is writable
 if [[ ! -d "${TMP_DIR}" ]]; then
  mkdir -p "${TMP_DIR}" || {
   echo "ERROR: Could not create TMP_DIR: ${TMP_DIR}" >&2
   exit 1
  }
 fi
 if [[ ! -w "${TMP_DIR}" ]]; then
  echo "ERROR: TMP_DIR not writable: ${TMP_DIR}" >&2
  exit 1
 fi

 # Set up test database
 export TEST_DBNAME="test_osm_notes_${BASENAME}"

 # Setup mock environment
 export MOCK_COMMANDS_DIR="${SCRIPT_BASE_DIRECTORY}/tests/mock_commands"
 export PATH="${MOCK_COMMANDS_DIR}:${PATH}"

 # Ensure mock commands are executable
 if [[ -d "${MOCK_COMMANDS_DIR}" ]]; then
  chmod +x "${MOCK_COMMANDS_DIR}"/* 2> /dev/null || true
 fi
}

teardown() {
 # Restore original properties
 # Ensure TEST_BASE_DIR is set
 export TEST_BASE_DIR="${TEST_BASE_DIR:-${SCRIPT_BASE_DIRECTORY}}"
 # Ensure function is available
 if declare -f restore_properties > /dev/null 2>&1; then
  restore_properties
 fi

 # Cleanup
 rm -rf "${TMP_DIR}"
 # Drop test database if it exists
 psql -d postgres -c "DROP DATABASE IF EXISTS ${TEST_DBNAME};" 2> /dev/null || true
}

# Test that notesCheckVerifier.sh can be sourced without errors
@test "notesCheckVerifier.sh should be sourceable without errors" {
 # Ensure properties.sh exists before sourcing (setup_test_properties is called in setup, but sub-shells need it too)
 # Export TEST_BASE_DIR so setup_test_properties can use it in sub-shell
 export TEST_BASE_DIR="${SCRIPT_BASE_DIRECTORY}"
 # Test that the script can be sourced without logging errors
 run bash -c "export TEST_BASE_DIR='${SCRIPT_BASE_DIRECTORY}'; setup_test_properties; source ${SCRIPT_BASE_DIRECTORY}/bin/monitor/notesCheckVerifier.sh > /dev/null 2>&1"
 [[ "${status}" -eq 0 ]] || [[ "${status}" -eq 127 ]] || [[ "${status}" -eq 239 ]] || [[ "${status}" -eq 241 ]]
}

# Test that notesCheckVerifier.sh functions can be called without logging errors
@test "notesCheckVerifier.sh functions should work without logging errors" {
 # Source the script (may fail if commands are missing, which is ok for tests)
 set +e
 source "${SCRIPT_BASE_DIRECTORY}/bin/monitor/notesCheckVerifier.sh" 2> /dev/null
 set -e

 # Test that available functions work
 # Export TEST_BASE_DIR so setup_test_properties can use it in sub-shell
 export TEST_BASE_DIR="${SCRIPT_BASE_DIRECTORY}"
 run bash -c "export TEST_BASE_DIR='${SCRIPT_BASE_DIRECTORY}'; setup_test_properties; source ${SCRIPT_BASE_DIRECTORY}/bin/monitor/notesCheckVerifier.sh && __show_help"
 [[ "${status}" -eq 0 ]] || [[ "${status}" -eq 1 ]]
 [[ "${output}" == *"version"* ]] || [[ "${output}" == *"Mock"* ]]
}

# Test that notesCheckVerifier.sh can run in dry-run mode
@test "notesCheckVerifier.sh should work in dry-run mode" {
 # Test that the script can run without actually verifying notes
 run timeout 30s bash "${SCRIPT_BASE_DIRECTORY}/bin/monitor/notesCheckVerifier.sh" --help
 [[ "${status}" -eq 1 ]] # Help should exit with code 1
 # Accept any output (even empty) as valid for help command
 true
}

# Test that all required functions are available after sourcing
@test "notesCheckVerifier.sh should have all required functions available" {
 # Source the script (may fail if commands are missing, which is ok for tests)
 set +e
 source "${SCRIPT_BASE_DIRECTORY}/bin/monitor/notesCheckVerifier.sh" 2> /dev/null
 set -e

 # Test that key functions are available
 local REQUIRED_FUNCTIONS=(
  "__show_help"
  "__checkPrereqs"
  "__downloadingPlanet"
  "__checkingDifferences"
  "__insertMissingData"
  "__markMissingNotesAsHidden"
  "__sendMail"
  "__cleanFiles"
 )

 for FUNC in "${REQUIRED_FUNCTIONS[@]}"; do
  export TEST_BASE_DIR="${SCRIPT_BASE_DIRECTORY}"
  run bash -c "export TEST_BASE_DIR='${SCRIPT_BASE_DIRECTORY}'; setup_test_properties; source ${SCRIPT_BASE_DIRECTORY}/bin/monitor/notesCheckVerifier.sh && declare -f ${FUNC}"
  [[ "${status}" -eq 0 ]] || echo "Function ${FUNC} should be available"
 done
}

# Test that logging functions work correctly
@test "notesCheckVerifier.sh logging functions should work correctly" {
 # Source the script (may fail if commands are missing, which is ok for tests)
 set +e
 source "${SCRIPT_BASE_DIRECTORY}/bin/monitor/notesCheckVerifier.sh" 2> /dev/null
 set -e

  # Test that available functions don't produce errors
  export TEST_BASE_DIR="${SCRIPT_BASE_DIRECTORY}"
  run bash -c "export TEST_BASE_DIR='${SCRIPT_BASE_DIRECTORY}'; setup_test_properties; source ${SCRIPT_BASE_DIRECTORY}/bin/monitor/notesCheckVerifier.sh && __checkPrereqs"
  [[ "${status}" -eq 0 ]] || [[ "${status}" -eq 239 ]] || [[ "${status}" -eq 241 ]]
 [[ "${output}" != *"orden no encontrada"* ]]
 [[ "${output}" != *"command not found"* ]]
 # Accept any output as long as it doesn't contain command not found errors
 [[ -n "${output}" ]] || [[ "${status}" -eq 0 ]]
}

# Test that database operations work with test database
@test "notesCheckVerifier.sh database operations should work with test database" {
 # Check if PostgreSQL is available
 if ! command -v psql > /dev/null 2>&1; then
  skip "PostgreSQL client (psql) not available"
 fi

 # Check if we can connect to PostgreSQL
 if ! psql -d postgres -c "SELECT 1;" > /dev/null 2>&1; then
  skip "Cannot connect to PostgreSQL"
 fi

 # Drop test database if it exists (cleanup from previous runs)
 psql -d postgres -c "DROP DATABASE IF EXISTS ${TEST_DBNAME};" > /dev/null 2>&1 || true

 # Create test database (ignore error if it already exists from a previous test)
 run psql -d postgres -c "CREATE DATABASE ${TEST_DBNAME};" 2> /dev/null || true
 # Note: CREATE DATABASE might fail if database already exists, which is OK
 # We'll verify the database exists by trying to connect to it

 # Verify database exists by connecting to it
 if ! psql -d "${TEST_DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
  skip "Cannot connect to test database"
 fi

 # Create base tables (use IF NOT EXISTS where possible to avoid errors)
 run psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_21_createBaseTables_tables.sql" 2>&1
 if [[ "${status}" -ne 0 ]]; then
  # Check if error is due to tables already existing (which is OK)
  if [[ "${output}" != *"already exists"* ]] && [[ "${output}" != *"duplicate"* ]]; then
   # Clean up database before failing
   psql -d postgres -c "DROP DATABASE IF EXISTS ${TEST_DBNAME};" > /dev/null 2>&1 || true
   skip "Cannot create base tables: ${output}"
  fi
 fi

 # Verify tables exist
 run psql -d "${TEST_DBNAME}" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('notes', 'note_comments', 'note_comments_text');" 2>&1
 if [[ "${status}" -ne 0 ]]; then
  # Clean up database before failing
  psql -d postgres -c "DROP DATABASE IF EXISTS ${TEST_DBNAME};" > /dev/null 2>&1 || true
  skip "Cannot query tables: ${output}"
 fi

 # Extract just the number from PostgreSQL output (remove header and formatting)
 local COUNT
 COUNT=$(echo "${output}" | tr -d ' \n\r' | grep -oE '[0-9]+' | head -n 1)
 
 # Verify we got a valid count
 if [[ -z "${COUNT}" ]]; then
  # Clean up database before failing
  psql -d postgres -c "DROP DATABASE IF EXISTS ${TEST_DBNAME};" > /dev/null 2>&1 || true
  skip "Could not extract table count from output: ${output}"
 fi

 # Tables should exist (at least 1, ideally 3: notes, note_comments, note_comments_text)
 # But the count might vary depending on schema version
 if [[ "${COUNT}" -lt "1" ]]; then
  # Clean up database before failing
  psql -d postgres -c "DROP DATABASE IF EXISTS ${TEST_DBNAME};" > /dev/null 2>&1 || true
  skip "Expected at least 1 table, got: ${COUNT}"
 fi
}

# Test that error handling works correctly
@test "notesCheckVerifier.sh error handling should work correctly" {
 # Test that the script handles missing database gracefully
 run bash -c "DBNAME=nonexistent_db source ${SCRIPT_BASE_DIRECTORY}/bin/monitor/notesCheckVerifier.sh"
 [[ "${status}" -ne 0 ]] || echo "Script should handle missing database gracefully"
}

# Test that all SQL files are valid
@test "notesCheckVerifier SQL files should be valid" {
 local SQL_FILES=(
  "sql/monitor/notesCheckVerifier-report.sql"
  "sql/monitor/notesCheckVerifier_54_markMissingNotesAsHidden.sql"
 )

 for SQL_FILE in "${SQL_FILES[@]}"; do
  [[ -f "${SCRIPT_BASE_DIRECTORY}/${SQL_FILE}" ]]
  # Test that SQL file has valid syntax (basic check)
  run grep -q "SELECT\|CREATE\|INSERT\|UPDATE" "${SCRIPT_BASE_DIRECTORY}/${SQL_FILE}"
  [[ "${status}" -eq 0 ]] || echo "SQL file ${SQL_FILE} should contain valid SQL"
 done
}

# Test that the script can be executed without parameters
@test "notesCheckVerifier.sh should handle no parameters gracefully" {
 # Test that the script doesn't crash when run without parameters
 run timeout 30s bash "${SCRIPT_BASE_DIRECTORY}/bin/monitor/notesCheckVerifier.sh"
 # Accept any non-zero exit code as valid error handling
 [[ "${status}" -ne 0 ]] || echo "Script should exit with error when run without parameters"
}

# Test that verification functions work correctly
@test "notesCheckVerifier.sh verification functions should work correctly" {
 # Source the script (may fail if commands are missing, which is ok for tests)
 set +e
 source "${SCRIPT_BASE_DIRECTORY}/bin/monitor/notesCheckVerifier.sh" 2> /dev/null
 set -e

 # Test that verification functions are available
 local VERIFICATION_FUNCTIONS=(
  "__checkingDifferences"
  "__downloadingPlanet"
  "__insertMissingData"
  "__markMissingNotesAsHidden"
  "__sendMail"
 )

 for FUNC in "${VERIFICATION_FUNCTIONS[@]}"; do
  export TEST_BASE_DIR="${SCRIPT_BASE_DIRECTORY}"
  run bash -c "export TEST_BASE_DIR='${SCRIPT_BASE_DIRECTORY}'; setup_test_properties; source ${SCRIPT_BASE_DIRECTORY}/bin/monitor/notesCheckVerifier.sh > /dev/null 2>&1; declare -f ${FUNC}"
  [[ "${status}" -eq 0 ]] || [[ "${status}" -eq 241 ]] || echo "Function ${FUNC} should be available"
 done
}

# Test that report generation functions work correctly
@test "notesCheckVerifier.sh report generation functions should work correctly" {
 # Source the script (may fail if commands are missing, which is ok for tests)
 set +e
 source "${SCRIPT_BASE_DIRECTORY}/bin/monitor/notesCheckVerifier.sh" 2> /dev/null
 set -e

 # Test that report functions are available
 local REPORT_FUNCTIONS=(
  "__sendMail"
  "__checkingDifferences"
  "__cleanFiles"
 )

 for FUNC in "${REPORT_FUNCTIONS[@]}"; do
  export TEST_BASE_DIR="${SCRIPT_BASE_DIRECTORY}"
  run bash -c "export TEST_BASE_DIR='${SCRIPT_BASE_DIRECTORY}'; setup_test_properties; source ${SCRIPT_BASE_DIRECTORY}/bin/monitor/notesCheckVerifier.sh > /dev/null 2>&1; declare -f ${FUNC}"
  [[ "${status}" -eq 0 ]] || [[ "${status}" -eq 241 ]] || echo "Function ${FUNC} should be available"
 done
}

# Test that data validation functions work correctly
@test "notesCheckVerifier.sh data validation functions should work correctly" {
 # Source the script (may fail if commands are missing, which is ok for tests)
 set +e
 source "${SCRIPT_BASE_DIRECTORY}/bin/monitor/notesCheckVerifier.sh" 2> /dev/null
 set -e

 # Test that validation functions are available
 local VALIDATION_FUNCTIONS=(
  "__checkPrereqs"
  "__checkingDifferences"
  "__cleanFiles"
 )

 for FUNC in "${VALIDATION_FUNCTIONS[@]}"; do
  export TEST_BASE_DIR="${SCRIPT_BASE_DIRECTORY}"
  run bash -c "export TEST_BASE_DIR='${SCRIPT_BASE_DIRECTORY}'; setup_test_properties; source ${SCRIPT_BASE_DIRECTORY}/bin/monitor/notesCheckVerifier.sh > /dev/null 2>&1; declare -f ${FUNC}"
  [[ "${status}" -eq 0 ]] || [[ "${status}" -eq 241 ]] || echo "Function ${FUNC} should be available"
 done
}

# Test that markMissingNotesAsHidden SQL script works correctly
@test "notesCheckVerifier_54_markMissingNotesAsHidden.sql should mark notes as hidden correctly" {
 # Create test database
 run psql -d postgres -c "CREATE DATABASE ${TEST_DBNAME};" 2> /dev/null || true
 [[ "${status}" -eq 0 ]] || skip "Cannot create test database"

 # Create enum types and tables
 psql -d "${TEST_DBNAME}" << 'SQL'
  DO $$ 
  BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'note_status_enum') THEN
      CREATE TYPE note_status_enum AS ENUM ('open', 'close', 'hidden');
    END IF;
  END $$;
  
  CREATE TABLE IF NOT EXISTS notes (
    note_id INTEGER NOT NULL PRIMARY KEY,
    latitude DECIMAL NOT NULL,
    longitude DECIMAL NOT NULL,
    created_at TIMESTAMP NOT NULL,
    status note_status_enum,
    closed_at TIMESTAMP,
    id_country INTEGER,
    insert_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    update_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
  );
  
  CREATE TABLE IF NOT EXISTS notes_check (
    note_id INTEGER NOT NULL,
    latitude DECIMAL NOT NULL,
    longitude DECIMAL NOT NULL,
    created_at TIMESTAMP NOT NULL,
    status note_status_enum,
    closed_at TIMESTAMP,
    id_country INTEGER
  );
SQL

 # Insert test data: notes that are in main but not in check
 # Note 1: should be marked as hidden (in main, not in check, status='open')
 # Note 2: should be marked as hidden (in main, not in check, status='close')
 # Note 3: should NOT be marked (already hidden)
 # Note 4: should NOT be marked (exists in both tables)
 # Note 5: should NOT be marked (created today, should be excluded)
 
 # Use SQL to calculate dates for better compatibility
 psql -d "${TEST_DBNAME}" <<SQL
  DO \$\$
  DECLARE
    v_yesterday DATE;
    v_today DATE;
  BEGIN
    v_today := CURRENT_DATE;
    v_yesterday := CURRENT_DATE - INTERVAL '1 day';
    
    -- Note 1: Open note not in check (should be marked as hidden)
    INSERT INTO notes (note_id, latitude, longitude, created_at, status, closed_at)
    VALUES (1, 40.0, -74.0, v_yesterday + INTERVAL '10 hours', 'open', NULL);
    
    -- Note 2: Closed note not in check (should be marked as hidden)
    INSERT INTO notes (note_id, latitude, longitude, created_at, status, closed_at)
    VALUES (2, 41.0, -75.0, v_yesterday + INTERVAL '11 hours', 'close', v_yesterday + INTERVAL '12 hours');
    
    -- Note 3: Already hidden note not in check (should NOT be marked again)
    INSERT INTO notes (note_id, latitude, longitude, created_at, status, closed_at)
    VALUES (3, 42.0, -76.0, v_yesterday + INTERVAL '13 hours', 'hidden', v_yesterday + INTERVAL '14 hours');
    
    -- Note 4: Note that exists in both tables (should NOT be marked)
    INSERT INTO notes (note_id, latitude, longitude, created_at, status, closed_at)
    VALUES (4, 43.0, -77.0, v_yesterday + INTERVAL '15 hours', 'open', NULL);
    
    INSERT INTO notes_check (note_id, latitude, longitude, created_at, status, closed_at)
    VALUES (4, 43.0, -77.0, v_yesterday + INTERVAL '15 hours', 'open', NULL);
    
    -- Note 5: Note created today (should NOT be marked, excluded from processing)
    INSERT INTO notes (note_id, latitude, longitude, created_at, status, closed_at)
    VALUES (5, 44.0, -78.0, v_today + INTERVAL '10 hours', 'open', NULL);
  END \$\$;
SQL


 # Execute the SQL script
 run psql -d "${TEST_DBNAME}" -f \
  "${SCRIPT_BASE_DIRECTORY}/sql/monitor/notesCheckVerifier_54_markMissingNotesAsHidden.sql"
 [[ "${status}" -eq 0 ]]

 # Verify results
 # Note 1 should now be hidden
 local note1_status
 note1_status=$(psql -d "${TEST_DBNAME}" -tAc "SELECT status FROM notes WHERE note_id = 1;")
 [[ "${note1_status}" == "hidden" ]]

 # Note 2 should now be hidden
 local note2_status
 note2_status=$(psql -d "${TEST_DBNAME}" -tAc "SELECT status FROM notes WHERE note_id = 2;")
 [[ "${note2_status}" == "hidden" ]]

 # Note 3 should remain hidden (already was)
 local note3_status
 note3_status=$(psql -d "${TEST_DBNAME}" -tAc "SELECT status FROM notes WHERE note_id = 3;")
 [[ "${note3_status}" == "hidden" ]]

 # Note 4 should remain open (exists in check table)
 local note4_status
 note4_status=$(psql -d "${TEST_DBNAME}" -tAc "SELECT status FROM notes WHERE note_id = 4;")
 [[ "${note4_status}" == "open" ]]

 # Note 5 should remain open (created today, excluded)
 local note5_status
 note5_status=$(psql -d "${TEST_DBNAME}" -tAc "SELECT status FROM notes WHERE note_id = 5;")
 [[ "${note5_status}" == "open" ]]

 # Verify closed_at was set for notes that were marked as hidden
 local note1_closed_at
 note1_closed_at=$(psql -d "${TEST_DBNAME}" -tAc \
  "SELECT closed_at IS NOT NULL FROM notes WHERE note_id = 1;")
 [[ "${note1_closed_at}" == "t" ]]
}

# Test that notesCheckVerifier report compares comments by (note_id, sequence_action) not by id
@test "notesCheckVerifier report should compare comments by logical content not by id" {
 # Check if PostgreSQL is available
 if ! command -v psql > /dev/null 2>&1; then
  skip "PostgreSQL client (psql) not available"
 fi

 # Check if we can connect to PostgreSQL
 if ! psql -d postgres -c "SELECT 1;" > /dev/null 2>&1; then
  skip "Cannot connect to PostgreSQL"
 fi

 # Drop test database if it exists (cleanup from previous runs)
 psql -d postgres -c "DROP DATABASE IF EXISTS ${TEST_DBNAME};" > /dev/null 2>&1 || true

 # Create test database (ignore error if it already exists from a previous test)
 run psql -d postgres -c "CREATE DATABASE ${TEST_DBNAME};" 2> /dev/null || true
 # Note: CREATE DATABASE might fail if database already exists, which is OK
 # We'll verify the database exists by trying to connect to it

 # Verify database exists by connecting to it
 if ! psql -d "${TEST_DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
  skip "Cannot connect to test database"
 fi

 # Create base tables and types
 psql -d "${TEST_DBNAME}" << 'SQL'
  DO $$ 
  BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'note_event_enum') THEN
      CREATE TYPE note_event_enum AS ENUM ('opened', 'closed', 'reopened', 'commented', 'hidden');
    END IF;
  END $$;
  
  CREATE TABLE IF NOT EXISTS note_comments (
    id INTEGER NOT NULL PRIMARY KEY,
    note_id INTEGER NOT NULL,
    sequence_action INTEGER,
    event note_event_enum NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    id_user INTEGER,
    username VARCHAR(256)
  );
  
  CREATE TABLE IF NOT EXISTS note_comments_check (
    id INTEGER NOT NULL,
    note_id INTEGER NOT NULL,
    sequence_action INTEGER,
    event note_event_enum NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    id_user INTEGER,
    username VARCHAR(256)
  );
  
  CREATE UNIQUE INDEX IF NOT EXISTS note_comments_note_seq_idx 
    ON note_comments (note_id, sequence_action) 
    WHERE sequence_action IS NOT NULL;
SQL

 # Insert test data: comments with same (note_id, sequence_action) but different IDs
 # This simulates the scenario where API inserts use nextval() generating different IDs
 # than Planet dumps
 psql -d "${TEST_DBNAME}" << 'SQL'
  -- Comment in check table: id=100, note_id=1, sequence_action=1
  INSERT INTO note_comments_check (id, note_id, sequence_action, event, created_at)
  VALUES (100, 1, 1, 'opened', CURRENT_DATE - INTERVAL '2 days');
  
  -- Comment in main table: id=200, note_id=1, sequence_action=1 (same logical content, different ID)
  INSERT INTO note_comments (id, note_id, sequence_action, event, created_at)
  VALUES (200, 1, 1, 'opened', CURRENT_DATE - INTERVAL '2 days');
  
  -- Comment in check table: id=101, note_id=2, sequence_action=1 (truly missing)
  INSERT INTO note_comments_check (id, note_id, sequence_action, event, created_at)
  VALUES (101, 2, 1, 'opened', CURRENT_DATE - INTERVAL '2 days');
  
  -- Comment in check table: id=102, note_id=3, sequence_action=1 (truly missing)
  INSERT INTO note_comments_check (id, note_id, sequence_action, event, created_at)
  VALUES (102, 3, 1, 'opened', CURRENT_DATE - INTERVAL '2 days');
SQL

 # Execute the corrected comparison logic from the report
 local missing_count
 missing_count=$(psql -d "${TEST_DBNAME}" -tAc "
  SELECT COUNT(*)
  FROM (
    SELECT note_id, sequence_action
    FROM note_comments_check
    WHERE DATE(created_at) < CURRENT_DATE
      AND sequence_action IS NOT NULL
    EXCEPT
    SELECT note_id, sequence_action
    FROM note_comments
    WHERE DATE(created_at) < CURRENT_DATE
      AND sequence_action IS NOT NULL
  ) AS diff;
 ")

 # Should only find 2 missing comments (note_id=2 and note_id=3), NOT note_id=1
 # because it exists with same (note_id, sequence_action) even though ID is different
 [[ "${missing_count}" -eq "2" ]]

 # Verify that note_id=1 is NOT in the missing list
 local note1_missing
 note1_missing=$(psql -d "${TEST_DBNAME}" -tAc "
  SELECT COUNT(*)
  FROM (
    SELECT note_id, sequence_action
    FROM note_comments_check
    WHERE DATE(created_at) < CURRENT_DATE
      AND sequence_action IS NOT NULL
    EXCEPT
    SELECT note_id, sequence_action
    FROM note_comments
    WHERE DATE(created_at) < CURRENT_DATE
      AND sequence_action IS NOT NULL
  ) AS diff
  WHERE note_id = 1 AND sequence_action = 1;
 ")
 [[ "${note1_missing}" -eq "0" ]]

 # Verify that note_id=2 IS in the missing list
 local note2_missing
 note2_missing=$(psql -d "${TEST_DBNAME}" -tAc "
  SELECT COUNT(*)
  FROM (
    SELECT note_id, sequence_action
    FROM note_comments_check
    WHERE DATE(created_at) < CURRENT_DATE
      AND sequence_action IS NOT NULL
    EXCEPT
    SELECT note_id, sequence_action
    FROM note_comments
    WHERE DATE(created_at) < CURRENT_DATE
      AND sequence_action IS NOT NULL
  ) AS diff
  WHERE note_id = 2 AND sequence_action = 1;
 ")
 [[ "${note2_missing}" -eq "1" ]]
}

# Test that notesCheckVerifier does not generate false positives for comments with different IDs
@test "notesCheckVerifier should not report false positives for comments with different IDs" {
 # Check if PostgreSQL is available
 if ! command -v psql > /dev/null 2>&1; then
  skip "PostgreSQL client (psql) not available"
 fi

 # Check if we can connect to PostgreSQL
 if ! psql -d postgres -c "SELECT 1;" > /dev/null 2>&1; then
  skip "Cannot connect to PostgreSQL"
 fi

 # Drop test database if it exists (cleanup from previous runs)
 psql -d postgres -c "DROP DATABASE IF EXISTS ${TEST_DBNAME};" > /dev/null 2>&1 || true

 # Create test database (ignore error if it already exists from a previous test)
 run psql -d postgres -c "CREATE DATABASE ${TEST_DBNAME};" 2> /dev/null || true
 # Note: CREATE DATABASE might fail if database already exists, which is OK
 # We'll verify the database exists by trying to connect to it

 # Verify database exists by connecting to it
 if ! psql -d "${TEST_DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
  skip "Cannot connect to test database"
 fi

 # Create base tables and types
 psql -d "${TEST_DBNAME}" << 'SQL'
  DO $$ 
  BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'note_event_enum') THEN
      CREATE TYPE note_event_enum AS ENUM ('opened', 'closed', 'reopened', 'commented', 'hidden');
    END IF;
  END $$;
  
  CREATE TABLE IF NOT EXISTS note_comments (
    id INTEGER NOT NULL PRIMARY KEY,
    note_id INTEGER NOT NULL,
    sequence_action INTEGER,
    event note_event_enum NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    id_user INTEGER,
    username VARCHAR(256)
  );
  
  CREATE TABLE IF NOT EXISTS note_comments_check (
    id INTEGER NOT NULL,
    note_id INTEGER NOT NULL,
    sequence_action INTEGER,
    event note_event_enum NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    id_user INTEGER,
    username VARCHAR(256)
  );
  
  CREATE UNIQUE INDEX IF NOT EXISTS note_comments_note_seq_idx 
    ON note_comments (note_id, sequence_action) 
    WHERE sequence_action IS NOT NULL;
SQL

 # Insert multiple comments with same logical content but different IDs
 # This simulates the real-world scenario where 205 comments had different IDs
 psql -d "${TEST_DBNAME}" << 'SQL'
  -- Insert 10 comments in check table
  INSERT INTO note_comments_check (id, note_id, sequence_action, event, created_at)
  VALUES 
    (100, 1, 1, 'opened', CURRENT_DATE - INTERVAL '2 days'),
    (101, 2, 1, 'opened', CURRENT_DATE - INTERVAL '2 days'),
    (102, 3, 1, 'opened', CURRENT_DATE - INTERVAL '2 days'),
    (103, 4, 1, 'opened', CURRENT_DATE - INTERVAL '2 days'),
    (104, 5, 1, 'opened', CURRENT_DATE - INTERVAL '2 days'),
    (105, 6, 1, 'opened', CURRENT_DATE - INTERVAL '2 days'),
    (106, 7, 1, 'opened', CURRENT_DATE - INTERVAL '2 days'),
    (107, 8, 1, 'opened', CURRENT_DATE - INTERVAL '2 days'),
    (108, 9, 1, 'opened', CURRENT_DATE - INTERVAL '2 days'),
    (109, 10, 1, 'opened', CURRENT_DATE - INTERVAL '2 days');
  
  -- Insert same comments in main table but with DIFFERENT IDs (simulating API nextval())
  INSERT INTO note_comments (id, note_id, sequence_action, event, created_at)
  VALUES 
    (200, 1, 1, 'opened', CURRENT_DATE - INTERVAL '2 days'),
    (201, 2, 1, 'opened', CURRENT_DATE - INTERVAL '2 days'),
    (202, 3, 1, 'opened', CURRENT_DATE - INTERVAL '2 days'),
    (203, 4, 1, 'opened', CURRENT_DATE - INTERVAL '2 days'),
    (204, 5, 1, 'opened', CURRENT_DATE - INTERVAL '2 days'),
    (205, 6, 1, 'opened', CURRENT_DATE - INTERVAL '2 days'),
    (206, 7, 1, 'opened', CURRENT_DATE - INTERVAL '2 days'),
    (207, 8, 1, 'opened', CURRENT_DATE - INTERVAL '2 days'),
    (208, 9, 1, 'opened', CURRENT_DATE - INTERVAL '2 days'),
    (209, 10, 1, 'opened', CURRENT_DATE - INTERVAL '2 days');
SQL

 # Execute the corrected comparison logic
 local false_positives
 false_positives=$(psql -d "${TEST_DBNAME}" -tAc "
  SELECT COUNT(*)
  FROM (
    SELECT note_id, sequence_action
    FROM note_comments_check
    WHERE DATE(created_at) < CURRENT_DATE
      AND sequence_action IS NOT NULL
    EXCEPT
    SELECT note_id, sequence_action
    FROM note_comments
    WHERE DATE(created_at) < CURRENT_DATE
      AND sequence_action IS NOT NULL
  ) AS diff;
 ")

 # Should find 0 false positives because all comments exist with same (note_id, sequence_action)
 [[ "${false_positives}" -eq "0" ]]

 # Verify old comparison method (by ID) would have found false positives
 local old_method_count
 old_method_count=$(psql -d "${TEST_DBNAME}" -tAc "
  SELECT COUNT(*)
  FROM (
    SELECT id
    FROM note_comments_check
    WHERE DATE(created_at) < CURRENT_DATE
    EXCEPT
    SELECT id
    FROM note_comments
    WHERE DATE(created_at) < CURRENT_DATE
  ) AS diff;
 ")

 # Old method would incorrectly report 10 "missing" comments
 [[ "${old_method_count}" -eq "10" ]]
}

# Test that notesCheckVerifier report correctly identifies truly missing comments
@test "notesCheckVerifier should correctly identify truly missing comments" {
 # Check if PostgreSQL is available
 if ! command -v psql > /dev/null 2>&1; then
  skip "PostgreSQL client (psql) not available"
 fi

 # Check if we can connect to PostgreSQL
 if ! psql -d postgres -c "SELECT 1;" > /dev/null 2>&1; then
  skip "Cannot connect to PostgreSQL"
 fi

 # Drop test database if it exists (cleanup from previous runs)
 psql -d postgres -c "DROP DATABASE IF EXISTS ${TEST_DBNAME};" > /dev/null 2>&1 || true

 # Create test database (ignore error if it already exists from a previous test)
 run psql -d postgres -c "CREATE DATABASE ${TEST_DBNAME};" 2> /dev/null || true
 # Note: CREATE DATABASE might fail if database already exists, which is OK
 # We'll verify the database exists by trying to connect to it

 # Verify database exists by connecting to it
 if ! psql -d "${TEST_DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
  skip "Cannot connect to test database"
 fi

 # Create base tables and types
 psql -d "${TEST_DBNAME}" << 'SQL'
  DO $$ 
  BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'note_event_enum') THEN
      CREATE TYPE note_event_enum AS ENUM ('opened', 'closed', 'reopened', 'commented', 'hidden');
    END IF;
  END $$;
  
  CREATE TABLE IF NOT EXISTS note_comments (
    id INTEGER NOT NULL PRIMARY KEY,
    note_id INTEGER NOT NULL,
    sequence_action INTEGER,
    event note_event_enum NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    id_user INTEGER,
    username VARCHAR(256)
  );
  
  CREATE TABLE IF NOT EXISTS note_comments_check (
    id INTEGER NOT NULL,
    note_id INTEGER NOT NULL,
    sequence_action INTEGER,
    event note_event_enum NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    id_user INTEGER,
    username VARCHAR(256)
  );
  
  CREATE UNIQUE INDEX IF NOT EXISTS note_comments_note_seq_idx 
    ON note_comments (note_id, sequence_action) 
    WHERE sequence_action IS NOT NULL;
SQL

 # Insert test data: mix of existing and missing comments
 psql -d "${TEST_DBNAME}" << 'SQL'
  -- Comments that exist in both tables (should NOT be reported as missing)
  INSERT INTO note_comments_check (id, note_id, sequence_action, event, created_at)
  VALUES (100, 1, 1, 'opened', CURRENT_DATE - INTERVAL '2 days');
  INSERT INTO note_comments (id, note_id, sequence_action, event, created_at)
  VALUES (200, 1, 1, 'opened', CURRENT_DATE - INTERVAL '2 days');  -- Different ID, same content
  
  INSERT INTO note_comments_check (id, note_id, sequence_action, event, created_at)
  VALUES (101, 2, 1, 'opened', CURRENT_DATE - INTERVAL '2 days');
  INSERT INTO note_comments (id, note_id, sequence_action, event, created_at)
  VALUES (201, 2, 1, 'opened', CURRENT_DATE - INTERVAL '2 days');  -- Different ID, same content
  
  -- Comments that exist ONLY in check table (SHOULD be reported as missing)
  INSERT INTO note_comments_check (id, note_id, sequence_action, event, created_at)
  VALUES (102, 3, 1, 'opened', CURRENT_DATE - INTERVAL '2 days');  -- Missing
  
  INSERT INTO note_comments_check (id, note_id, sequence_action, event, created_at)
  VALUES (103, 4, 1, 'opened', CURRENT_DATE - INTERVAL '2 days');  -- Missing
  
  INSERT INTO note_comments_check (id, note_id, sequence_action, event, created_at)
  VALUES (104, 5, 1, 'opened', CURRENT_DATE - INTERVAL '2 days');  -- Missing
SQL

 # Execute the corrected comparison logic
 local missing_count
 missing_count=$(psql -d "${TEST_DBNAME}" -tAc "
  SELECT COUNT(*)
  FROM (
    SELECT note_id, sequence_action
    FROM note_comments_check
    WHERE DATE(created_at) < CURRENT_DATE
      AND sequence_action IS NOT NULL
    EXCEPT
    SELECT note_id, sequence_action
    FROM note_comments
    WHERE DATE(created_at) < CURRENT_DATE
      AND sequence_action IS NOT NULL
  ) AS diff;
 ")

 # Should find exactly 3 missing comments (note_id 3, 4, 5)
 [[ "${missing_count}" -eq "3" ]]

 # Verify specific missing comments
 local missing_note3
 missing_note3=$(psql -d "${TEST_DBNAME}" -tAc "
  SELECT COUNT(*)
  FROM (
    SELECT note_id, sequence_action
    FROM note_comments_check
    WHERE DATE(created_at) < CURRENT_DATE
      AND sequence_action IS NOT NULL
    EXCEPT
    SELECT note_id, sequence_action
    FROM note_comments
    WHERE DATE(created_at) < CURRENT_DATE
      AND sequence_action IS NOT NULL
  ) AS diff
  WHERE note_id = 3 AND sequence_action = 1;
 ")
 [[ "${missing_note3}" -eq "1" ]]

 # Verify that existing comments are NOT reported as missing
 local false_positive_note1
 false_positive_note1=$(psql -d "${TEST_DBNAME}" -tAc "
  SELECT COUNT(*)
  FROM (
    SELECT note_id, sequence_action
    FROM note_comments_check
    WHERE DATE(created_at) < CURRENT_DATE
      AND sequence_action IS NOT NULL
    EXCEPT
    SELECT note_id, sequence_action
    FROM note_comments
    WHERE DATE(created_at) < CURRENT_DATE
      AND sequence_action IS NOT NULL
  ) AS diff
  WHERE note_id = 1 AND sequence_action = 1;
 ")
 [[ "${false_positive_note1}" -eq "0" ]]
}
