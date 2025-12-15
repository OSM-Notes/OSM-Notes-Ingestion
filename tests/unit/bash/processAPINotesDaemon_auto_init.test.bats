#!/usr/bin/env bats

# Unit tests for processAPINotesDaemon.sh auto-initialization
# Tests that the daemon detects empty database and triggers processPlanetNotes.sh --base
#
# Author: Andres Gomez (AngocA)
# Version: 2025-12-15

load "$(dirname "$BATS_TEST_FILENAME")/../../test_helper.bash"

# =============================================================================
# Setup and Teardown
# =============================================================================

setup() {
 # Setup test environment
 # TEST_BASE_DIR is set by test_helper.bash
 export TMP_DIR="$(mktemp -d)"
 export BASENAME="test_daemon_auto_init"
 export LOG_LEVEL="ERROR"
 export DAEMON_SLEEP_INTERVAL=60
 export TEST_MODE="true"
 
 # Create mock lock file location
 export LOCK="/tmp/${BASENAME}.lock"
 export DAEMON_SHUTDOWN_FLAG="/tmp/${BASENAME}_shutdown"
 
 # Clean up any existing locks
 rm -f "${LOCK}"
 rm -f "${DAEMON_SHUTDOWN_FLAG}"
}

teardown() {
 # Cleanup
 rm -rf "${TMP_DIR}"
 rm -f "${LOCK}"
 rm -f "${DAEMON_SHUTDOWN_FLAG}"
 rm -f /tmp/processAPINotesDaemon*.lock
 rm -f /tmp/processAPINotesDaemon*_shutdown
}

# =============================================================================
# Tests for Auto-Initialization Detection
# =============================================================================

@test "Daemon should detect empty max_note_timestamp table" {
 # Verify that daemon checks for max_note_timestamp table existence
 run grep -q "max_note_timestamp.*table.*exists\|information_schema.tables.*max_note_timestamp" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

@test "Daemon should detect empty notes table" {
 # Verify that daemon checks for notes table existence
 run grep -q "information_schema.tables.*table_name = 'notes'" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

@test "Daemon should check if max_note_timestamp table is empty" {
 # Verify that daemon checks if max_note_timestamp has rows
 run grep -q "COUNT.*FROM max_note_timestamp\|TIMESTAMP_COUNT.*==.*0" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

@test "Daemon should check if notes table is empty" {
 # Verify that daemon checks if notes table has rows
 run grep -q "COUNT.*FROM notes\|NOTES_COUNT.*==.*0" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

@test "Daemon should trigger processPlanetNotes.sh --base when database is empty" {
 # Verify that daemon calls processPlanetNotes.sh --base when DB is empty
 run grep -q "processPlanetNotes\.sh.*--base\|NOTES_SYNC_SCRIPT.*--base" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

@test "Daemon should log auto-initialization activation" {
 # Verify that daemon logs when activating processPlanet --base
 run grep -q "Activating processPlanetNotes\.sh --base\|Database appears to be empty" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

@test "Daemon should skip API table creation when base tables are missing" {
 # Verify that daemon skips API table creation if base tables don't exist
 run grep -q "Skipping API tables preparation.*base tables missing\|BASE_TABLES_EXIST.*-ne.*0" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

@test "Daemon should skip properties table creation when base tables are missing" {
 # Verify that daemon skips properties table creation if base tables don't exist
 run grep -q "Skipping properties table.*base tables missing" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

@test "Daemon should check table existence before counting rows" {
 # Verify that daemon checks table existence before attempting to count rows
 # This prevents SQL errors when tables don't exist
 run grep -q "information_schema.tables.*table_name.*max_note_timestamp" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

@test "Daemon should handle empty LAST_PROCESSED_TIMESTAMP" {
 # Verify that daemon checks for empty LAST_PROCESSED_TIMESTAMP
 run grep -q "LAST_PROCESSED_TIMESTAMP.*empty\|-z.*LAST_PROCESSED_TIMESTAMP" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

@test "Daemon should update timestamp after Planet base load" {
 # Verify that daemon updates timestamp after successful Planet base load
 run grep -q "Updating timestamp after Planet base load\|__updateLastValue" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

@test "Daemon should continue normally after auto-initialization" {
 # Verify that daemon continues with normal processing after auto-initialization
 run grep -q "Database initialized.*Next cycle will process\|processPlanet.*--base.*completed successfully" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

@test "Daemon should handle Planet base load failure gracefully" {
 # Verify that daemon handles Planet base load failure
 run grep -q "Planet base load failed\|PLANET_BASE_EXIT_CODE" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

@test "Daemon should clean stale lock files before Planet base load" {
 # Verify that daemon cleans stale lock files before calling processPlanet --base
 run grep -q "Removing stale lock file\|PLANET_LOCK_FILE" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

@test "Daemon should set required environment variables for Planet base load" {
 # Verify that daemon sets required environment variables before calling processPlanet --base
 run grep -q "export.*SKIP_XML_VALIDATION\|export.*LOG_LEVEL.*DBNAME" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

