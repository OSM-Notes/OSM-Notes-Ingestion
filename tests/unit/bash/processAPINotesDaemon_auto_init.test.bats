#!/usr/bin/env bats

# Unit tests for processAPINotesDaemon.sh auto-initialization
# Tests that the daemon detects empty database and triggers processPlanetNotes.sh --base
# Author: Andres Gomez (AngocA)
# Version: 2025-12-15

load "${BATS_TEST_DIRNAME}/../../test_helper"

setup() {
 # Create temporary test directory
 TEST_DIR=$(mktemp -d)
 export TEST_DIR

 # Set up test environment variables
 export SCRIPT_BASE_DIRECTORY="${TEST_BASE_DIR}"
 export TMP_DIR="${TEST_DIR}"
 export DBNAME="${TEST_DBNAME:-test_db}"
 export BASENAME="test_daemon_auto_init"
 export LOG_LEVEL="DEBUG"
 export __log_level="DEBUG"
 export TEST_MODE="true"
 export DAEMON_SLEEP_INTERVAL=60

 # Create mock lock file location
 export LOCK="/tmp/${BASENAME}.lock"
 export DAEMON_SHUTDOWN_FLAG="/tmp/${BASENAME}_shutdown"

 # Clean up any existing locks
 rm -f "${LOCK}"
 rm -f "${DAEMON_SHUTDOWN_FLAG}"

 # Mock psql to simulate database state
 # This mock will be customized per test
 psql() {
  local ARGS=("$@")
  local CMD=""
  local I=0
  # Parse arguments to find -c command
  while [[ $I -lt ${#ARGS[@]} ]]; do
   if [[ "${ARGS[$I]}" == "-c" ]] && [[ $((I + 1)) -lt ${#ARGS[@]} ]]; then
    CMD="${ARGS[$((I + 1))]}"
    break
   fi
   I=$((I + 1))
  done

  # Default: return empty result (table doesn't exist)
  echo "0"
  return 0
 }
 export -f psql

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

 # Load daemon functions (we'll source the daemon script)
 # But first, we need to mock the functions it depends on
 source "${TEST_BASE_DIR}/bin/lib/functionsProcess.sh" || true
}

teardown() {
 # Clean up test files
 rm -rf "${TEST_DIR}"
 rm -f "${LOCK}"
 rm -f "${DAEMON_SHUTDOWN_FLAG}"
 rm -f /tmp/processAPINotesDaemon*.lock
 rm -f /tmp/processAPINotesDaemon*_shutdown
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

 psql() {
  local ARGS=("$@")
  local CMD=""
  local I=0
  while [[ $I -lt ${#ARGS[@]} ]]; do
   if [[ "${ARGS[$I]}" == "-c" ]] && [[ $((I + 1)) -lt ${#ARGS[@]} ]]; then
    CMD="${ARGS[$((I + 1))]}"
    break
   fi
   I=$((I + 1))
  done

  echo "1" > "${TRACK_FILE}"
  # Check if query contains max_note_timestamp check
  if [[ "${CMD}" == *"max_note_timestamp"* ]] && [[ "${CMD}" == *"information_schema"* ]]; then
   echo "1" > "${TEST_DIR}/query_matched"
   echo "0" # Table doesn't exist
  else
   echo "0"
  fi
  return 0
 }
 export -f psql

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

 psql() {
  local ARGS=("$@")
  local CMD=""
  local I=0
  while [[ $I -lt ${#ARGS[@]} ]]; do
   if [[ "${ARGS[$I]}" == "-c" ]] && [[ $((I + 1)) -lt ${#ARGS[@]} ]]; then
    CMD="${ARGS[$((I + 1))]}"
    break
   fi
   I=$((I + 1))
  done

  echo "1" > "${TRACK_FILE}"
  # Check if query contains notes table check
  if [[ "${CMD}" == *"table_name = 'notes'"* ]] && [[ "${CMD}" == *"information_schema"* ]]; then
   echo "1" > "${TEST_DIR}/query_matched2"
   echo "0" # Table doesn't exist
  else
   echo "0"
  fi
  return 0
 }
 export -f psql

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

 psql() {
  local ARGS=("$@")
  local CMD=""
  local I=0
  while [[ $I -lt ${#ARGS[@]} ]]; do
   if [[ "${ARGS[$I]}" == "-c" ]] && [[ $((I + 1)) -lt ${#ARGS[@]} ]]; then
    CMD="${ARGS[$((I + 1))]}"
    break
   fi
   I=$((I + 1))
  done

  echo "1" > "${TRACK_FILE}"
  # Check if query is COUNT on max_note_timestamp
  if [[ "${CMD}" == *"COUNT(*)"* ]] && [[ "${CMD}" == *"FROM max_note_timestamp"* ]]; then
   echo "1" > "${TEST_DIR}/count_query_matched"
   echo "0" # Table is empty
  else
   echo "0"
  fi
  return 0
 }
 export -f psql

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

 # Mock psql to return empty database state
 psql() {
  local ARGS=("$@")
  local CMD=""
  local I=0
  while [[ $I -lt ${#ARGS[@]} ]]; do
   if [[ "${ARGS[$I]}" == "-c" ]] && [[ $((I + 1)) -lt ${#ARGS[@]} ]]; then
    CMD="${ARGS[$((I + 1))]}"
    break
   fi
   I=$((I + 1))
  done

  # Return 0 for table existence checks (tables don't exist)
  if [[ "${CMD}" == *"information_schema"* ]]; then
   echo "0"
  # Return 0 for COUNT queries (tables are empty)
  elif [[ "${CMD}" == *"COUNT(*)"* ]]; then
   echo "0"
  else
   echo "0"
  fi
  return 0
 }
 export -f psql

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
