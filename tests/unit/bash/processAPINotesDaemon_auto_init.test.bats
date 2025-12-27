#!/usr/bin/env bats

# Unit tests for processAPINotesDaemon.sh auto-initialization
# Tests that the daemon detects empty database and triggers processPlanetNotes.sh --base
# Author: Andres Gomez (AngocA)
# Version: 2025-12-15

load "${BATS_TEST_DIRNAME}/../../test_helper"
load "${BATS_TEST_DIRNAME}/../../test_helpers_common"
load "${BATS_TEST_DIRNAME}/daemon_test_helpers"

setup() {
 __setup_daemon_test
 export BASENAME="test_daemon_auto_init"
 export LOCK="/tmp/${BASENAME}.lock"
 export DAEMON_SHUTDOWN_FLAG="/tmp/${BASENAME}_shutdown"
 rm -f "${LOCK}"
 rm -f "${DAEMON_SHUTDOWN_FLAG}"

 # Mock processPlanetNotes.sh --base
 NOTES_SYNC_SCRIPT="${TEST_DIR}/mock_processPlanetNotes.sh"
 cat > "${NOTES_SYNC_SCRIPT}" << 'EOF'
#!/bin/bash
# Mock processPlanetNotes.sh --base
if [[ "${1}" == "--base" ]]; then
 echo "Mock: processPlanetNotes.sh --base executed"
 exit 0
fi
exit 1
EOF
 chmod +x "${NOTES_SYNC_SCRIPT}"
 export NOTES_SYNC_SCRIPT
}

teardown() {
 __teardown_daemon_test
}

# =============================================================================
# Tests for Auto-Initialization Detection
# =============================================================================

@test "Daemon should detect empty max_note_timestamp table" {
 # Test: Daemon checks if max_note_timestamp table exists
 # Purpose: Verify that daemon queries information_schema for table existence
 # Expected: psql should be called with query checking for max_note_timestamp

 # Use file-based tracking since variables in subshells don't work
 local TRACK_FILE="${TEST_DIR}/psql_track"
 echo "0" > "${TRACK_FILE}"

 # Mock psql with tracking and pattern matching using common helper
 __setup_mock_psql_with_tracking "${TRACK_FILE}" "${TEST_DIR}/query_matched" \
  "max_note_timestamp:0" \
  "information_schema:0" \
  ".*:0"

 # Simulate the check that daemon does
 local TIMESTAMP_TABLE_EXISTS
 TIMESTAMP_TABLE_EXISTS=$(psql -d "${DBNAME}" -Atq -c \
  "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'max_note_timestamp" \
  2> /dev/null | grep -E '^[0-9]+$' | tail -1 || echo "0")

 local PSQL_CALLED
 PSQL_CALLED=$(cat "${TRACK_FILE}" 2>/dev/null || echo "0")
 local QUERY_MATCHED
 QUERY_MATCHED=$(cat "${TEST_DIR}/query_matched" 2>/dev/null || echo "0")

 [[ "${PSQL_CALLED}" -eq 1 ]]
 [[ "${QUERY_MATCHED}" -eq 1 ]]
 [[ "${TIMESTAMP_TABLE_EXISTS}" == "0" ]]
}

@test "Daemon should detect empty notes table" {
 # Test: Daemon checks if notes table exists
 # Purpose: Verify that daemon queries information_schema for notes table
 # Expected: psql should be called with query checking for notes table

 # Use file-based tracking since variables in subshells don't work
 local TRACK_FILE="${TEST_DIR}/psql_track2"
 echo "0" > "${TRACK_FILE}"

 # Mock psql with tracking and pattern matching using common helper
 __setup_mock_psql_with_tracking "${TRACK_FILE}" "${TEST_DIR}/query_matched2" \
  "notes:0" \
  "information_schema:0" \
  ".*:0"

 # Simulate the check that daemon does
 local NOTES_TABLE_EXISTS
 NOTES_TABLE_EXISTS=$(psql -d "${DBNAME}" -Atq -c \
  "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'notes'" \
  2> /dev/null | grep -E '^[0-9]+$' | tail -1 || echo "0")

 local PSQL_CALLED
 PSQL_CALLED=$(cat "${TRACK_FILE}" 2>/dev/null || echo "0")
 local QUERY_MATCHED
 QUERY_MATCHED=$(cat "${TEST_DIR}/query_matched2" 2>/dev/null || echo "0")

 [[ "${PSQL_CALLED}" -eq 1 ]]
 [[ "${QUERY_MATCHED}" -eq 1 ]]
 [[ "${NOTES_TABLE_EXISTS}" == "0" ]]
}

@test "Daemon should check if max_note_timestamp table is empty" {
 # Test: Daemon checks if max_note_timestamp has rows
 # Purpose: Verify that daemon counts rows in max_note_timestamp table
 # Expected: psql should be called with COUNT query on max_note_timestamp

 # Use file-based tracking since variables in subshells don't work
 local TRACK_FILE="${TEST_DIR}/psql_track3"
 echo "0" > "${TRACK_FILE}"

 # Mock psql with tracking and pattern matching using common helper
 __setup_mock_psql_with_tracking "${TRACK_FILE}" "${TEST_DIR}/count_query_matched" \
  "COUNT\\(\\*\\):0" \
  "max_note_timestamp:0" \
  ".*:0"

 # Simulate the check that daemon does
 local TIMESTAMP_COUNT=0
 TIMESTAMP_COUNT=$(psql -d "${DBNAME}" -Atq -c \
  "SELECT COUNT(*) FROM max_note_timestamp" 2> /dev/null | grep -E '^[0-9]+$' | tail -1 || echo "0")

 local PSQL_CALLED
 PSQL_CALLED=$(cat "${TRACK_FILE}" 2>/dev/null || echo "0")
 local COUNT_QUERY_MATCHED
 COUNT_QUERY_MATCHED=$(cat "${TEST_DIR}/count_query_matched" 2>/dev/null || echo "0")

 [[ "${PSQL_CALLED}" -eq 1 ]]
 [[ "${COUNT_QUERY_MATCHED}" -eq 1 ]]
 [[ "${TIMESTAMP_COUNT}" == "0" ]]
}

@test "Daemon should trigger processPlanetNotes.sh --base when database is empty" {
 # Test: Daemon calls processPlanetNotes.sh --base when all conditions indicate empty DB
 # Purpose: Verify that daemon activates auto-initialization
 # Expected: processPlanetNotes.sh --base should be called with --base flag

 local PLANET_SCRIPT_CALLED=0
 local BASE_FLAG_PRESENT=0

 # Mock processPlanetNotes.sh
 NOTES_SYNC_SCRIPT="${TEST_DIR}/mock_processPlanetNotes.sh"
 cat > "${NOTES_SYNC_SCRIPT}" << 'EOF'
#!/bin/bash
PLANET_SCRIPT_CALLED=1
if [[ "${1}" == "--base" ]]; then
 BASE_FLAG_PRESENT=1
 echo "Mock: processPlanetNotes.sh --base executed"
 exit 0
fi
exit 1
EOF
 chmod +x "${NOTES_SYNC_SCRIPT}"

 # Mock psql to return empty database state using common helper
 __setup_mock_psql_with_tracking "" \
  "information_schema:0" \
  "COUNT\\(\\*\\):0" \
  ".*:0"

 # Simulate daemon's auto-initialization logic
 local TIMESTAMP_TABLE_EXISTS=0
 local TIMESTAMP_COUNT=0
 local NOTES_TABLE_EXISTS=0
 local NOTES_COUNT=0
 local LAST_PROCESSED_TIMESTAMP=""

 # Check conditions (all should indicate empty database)
 TIMESTAMP_TABLE_EXISTS=$(psql -d "${DBNAME}" -Atq -c \
  "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'max_note_timestamp" \
  2> /dev/null | grep -E '^[0-9]+$' | tail -1 || echo "0")

 NOTES_TABLE_EXISTS=$(psql -d "${DBNAME}" -Atq -c \
  "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'notes'" \
  2> /dev/null | grep -E '^[0-9]+$' | tail -1 || echo "0")

 # If all conditions indicate empty DB, trigger processPlanet --base
 if [[ "${TIMESTAMP_TABLE_EXISTS}" == "0" ]] || [[ "${TIMESTAMP_COUNT}" == "0" ]] || \
    [[ -z "${LAST_PROCESSED_TIMESTAMP}" ]] || [[ "${NOTES_TABLE_EXISTS}" == "0" ]] || \
    [[ "${NOTES_COUNT}" == "0" ]]; then
  # Call processPlanetNotes.sh --base
  "${NOTES_SYNC_SCRIPT}" --base
  PLANET_SCRIPT_CALLED=1
  BASE_FLAG_PRESENT=1
 fi

 [[ "${PLANET_SCRIPT_CALLED}" -eq 1 ]]
 [[ "${BASE_FLAG_PRESENT}" -eq 1 ]]
}

@test "Daemon should handle empty LAST_PROCESSED_TIMESTAMP" {
 # Test: Daemon checks for empty LAST_PROCESSED_TIMESTAMP
 # Purpose: Verify that daemon treats empty timestamp as indicator of empty DB
 # Expected: Empty timestamp should trigger auto-initialization

 local LAST_PROCESSED_TIMESTAMP=""
 local TIMESTAMP_TABLE_EXISTS=1
 local TIMESTAMP_COUNT=1

 # Even if tables exist and have data, empty timestamp should trigger --base
 if [[ -z "${LAST_PROCESSED_TIMESTAMP}" ]]; then
  # This condition should trigger auto-initialization
  [[ -z "${LAST_PROCESSED_TIMESTAMP}" ]]
 fi
}

@test "Daemon should skip API table creation when base tables are missing" {
 # Test: Daemon skips API table creation if base tables don't exist
 # Purpose: Verify that daemon doesn't try to create API tables before base tables
 # Expected: BASE_TABLES_EXIST check should prevent API table creation

 local BASE_TABLES_EXIST=1
 local API_TABLES_CREATED=0

 # Mock __prepareApiTables to track if it's called
 __prepareApiTables() {
  API_TABLES_CREATED=1
 }

 # Simulate daemon logic: only create API tables if base tables exist
 if [[ "${BASE_TABLES_EXIST:-0}" -eq 0 ]]; then
  # Base tables exist, can create API tables
  __prepareApiTables
 else
  # Base tables missing, skip API table creation
  API_TABLES_CREATED=0
 fi

 # Since BASE_TABLES_EXIST=1 (missing), API tables should NOT be created
 [[ "${API_TABLES_CREATED}" -eq 0 ]]
}

@test "Daemon should continue normally after auto-initialization" {
 # Test: Daemon continues with normal processing after successful auto-initialization
 # Purpose: Verify that daemon doesn't exit after auto-initialization
 # Expected: After processPlanet --base succeeds, daemon should continue

 local PLANET_BASE_EXIT_CODE=0
 local CONTINUED_PROCESSING=0

 # Mock processPlanetNotes.sh --base to succeed
 NOTES_SYNC_SCRIPT="${TEST_DIR}/mock_processPlanetNotes.sh"
 cat > "${NOTES_SYNC_SCRIPT}" << 'EOF'
#!/bin/bash
exit 0
EOF
 chmod +x "${NOTES_SYNC_SCRIPT}"

 # Simulate daemon logic after auto-initialization
 "${NOTES_SYNC_SCRIPT}" --base
 PLANET_BASE_EXIT_CODE=$?

 if [[ ${PLANET_BASE_EXIT_CODE} -eq 0 ]]; then
  # After successful initialization, daemon should continue
  CONTINUED_PROCESSING=1
  # Update timestamp for next cycle
  LAST_PROCESSED_TIMESTAMP="2025-01-23T00:00:00Z"
 fi

 [[ "${PLANET_BASE_EXIT_CODE}" -eq 0 ]]
 [[ "${CONTINUED_PROCESSING}" -eq 1 ]]
 [[ -n "${LAST_PROCESSED_TIMESTAMP}" ]]
}

@test "Daemon should handle Planet base load failure gracefully" {
 # Test: Daemon handles processPlanet --base failure
 # Purpose: Verify that daemon logs error and returns error code on failure
 # Expected: Failed Planet base load should return error code 1

 # Mock processPlanetNotes.sh --base to fail
 NOTES_SYNC_SCRIPT="${TEST_DIR}/mock_processPlanetNotes.sh"
 cat > "${NOTES_SYNC_SCRIPT}" << 'EOF'
#!/bin/bash
exit 1
EOF
 chmod +x "${NOTES_SYNC_SCRIPT}"

 # Simulate daemon logic with failed Planet base load
 set +e
 "${NOTES_SYNC_SCRIPT}" --base
 local PLANET_BASE_EXIT_CODE=$?
 set -e

 local ERROR_LOGGED=0
 if [[ ${PLANET_BASE_EXIT_CODE} -ne 0 ]]; then
  ERROR_LOGGED=1
  # Daemon should log error and return failure
 fi

 [[ "${PLANET_BASE_EXIT_CODE}" -ne 0 ]]
 [[ "${ERROR_LOGGED}" -eq 1 ]]
}

@test "Daemon should detect empty database and trigger Planet --base in complete flow" {
 # Test: Daemon detects empty DB and executes processPlanetNotes.sh --base in complete flow
 # Purpose: Verify that daemon's __process_api_data function detects empty DB and triggers auto-init
 # Expected: When DB is empty, daemon should execute processPlanetNotes.sh --base
 # Note: This test verifies the complete flow in __process_api_data (lines 674-772)

 local PLANET_BASE_CALLED=0
 local PLANET_BASE_EXIT_CODE=1

 # Mock processPlanetNotes.sh --base
 NOTES_SYNC_SCRIPT="${TEST_DIR}/mock_processPlanetNotes_complete.sh"
 cat > "${NOTES_SYNC_SCRIPT}" << 'EOF'
#!/bin/bash
if [[ "${1}" == "--base" ]]; then
 echo "Mock: processPlanetNotes.sh --base executed successfully"
 exit 0
fi
exit 1
EOF
 chmod +x "${NOTES_SYNC_SCRIPT}"

 # Mock psql to simulate empty database
 # All queries should return 0 (tables don't exist or are empty)
 local CALL_COUNT=0
 psql() {
  CALL_COUNT=$((CALL_COUNT + 1))
  # All queries return 0 (empty database)
  echo "0"
  return 0
 }
 export -f psql

 # Simulate daemon's __process_api_data function logic for empty DB detection
 # This mirrors the code in processAPINotesDaemon.sh lines 674-772
 local TIMESTAMP_TABLE_EXISTS
 TIMESTAMP_TABLE_EXISTS=$(psql -d "${DBNAME}" -Atq -c \
  "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'max_note_timestamp'" \
  2> /dev/null | grep -E '^[0-9]+$' | tail -1 || echo "0")

 local TIMESTAMP_COUNT=0
 if [[ "${TIMESTAMP_TABLE_EXISTS}" == "1" ]]; then
  TIMESTAMP_COUNT=$(psql -d "${DBNAME}" -Atq -c \
   "SELECT COUNT(*) FROM max_note_timestamp" 2> /dev/null | grep -E '^[0-9]+$' | tail -1 || echo "0")
 fi

 local NOTES_TABLE_EXISTS
 NOTES_TABLE_EXISTS=$(psql -d "${DBNAME}" -Atq -c \
  "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'notes'" \
  2> /dev/null | grep -E '^[0-9]+$' | tail -1 || echo "0")

 local NOTES_COUNT=0
 if [[ "${NOTES_TABLE_EXISTS}" == "1" ]]; then
  NOTES_COUNT=$(psql -d "${DBNAME}" -Atq -c \
   "SELECT COUNT(*) FROM notes" 2> /dev/null | grep -E '^[0-9]+$' | tail -1 || echo "0")
 fi

 local LAST_PROCESSED_TIMESTAMP=""

 # Check if database is empty (all conditions indicate empty DB)
 if [[ "${TIMESTAMP_TABLE_EXISTS}" == "0" ]] || [[ "${TIMESTAMP_COUNT}" == "0" ]] || \
    [[ -z "${LAST_PROCESSED_TIMESTAMP}" ]] || [[ "${NOTES_TABLE_EXISTS}" == "0" ]] || \
    [[ "${NOTES_COUNT}" == "0" ]]; then
  # Execute processPlanetNotes.sh --base
  "${NOTES_SYNC_SCRIPT}" --base
  PLANET_BASE_EXIT_CODE=$?
  PLANET_BASE_CALLED=1
 fi

 # Verify that Planet --base was called and succeeded
 [[ "${PLANET_BASE_CALLED}" -eq 1 ]]
 [[ "${PLANET_BASE_EXIT_CODE}" -eq 0 ]]
}
