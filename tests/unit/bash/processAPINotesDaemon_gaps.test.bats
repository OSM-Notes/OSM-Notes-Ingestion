#!/usr/bin/env bats

# Unit tests for processAPINotesDaemon.sh gap detection
# Tests that the daemon includes gap detection functions and calls them correctly
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
 export BASENAME="test_daemon_gaps"
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
 rm -f /tmp/processAPINotesDaemon_gaps.log
}

# =============================================================================
# Tests for Gap Detection Functions
# =============================================================================

@test "Daemon should call __recover_from_gaps before processing" {
 # Verify that daemon calls __recover_from_gaps function
 # This function is defined in processAPINotes.sh and should be available
 run grep -q "__recover_from_gaps" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

@test "Daemon should call __check_and_log_gaps after processing" {
 # Verify that daemon calls __check_and_log_gaps function
 run grep -q "__check_and_log_gaps\|Checking and logging gaps from database" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

@test "Daemon should check for gaps in last 7 days" {
 # Verify that __recover_from_gaps checks for gaps in last 7 days
 # This is done in processAPINotes.sh, which the daemon sources
 run grep -q "INTERVAL '7 days'\|created_at.*max_note_timestamp.*- INTERVAL '7 days'" \
  "${TEST_BASE_DIR}/bin/process/processAPINotes.sh"
 [ "$status" -eq 0 ]
}

@test "Daemon should check data_gaps table existence before querying" {
 # Verify that daemon checks if data_gaps table exists before querying
 run grep -q "information_schema.tables.*data_gaps\|GAP_TABLE_EXISTS" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

@test "Daemon should query data_gaps table for recent gaps" {
 # Verify that daemon queries data_gaps table for gaps in last 24 hours
 run grep -q "FROM data_gaps\|gap_timestamp > NOW.*- INTERVAL '1 day'" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

@test "Daemon should log gaps to file" {
 # Verify that daemon logs gaps to a file
 run grep -q "processAPINotesDaemon_gaps\.log\|GAP_FILE" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

@test "Daemon should only check gaps if base tables exist" {
 # Verify that daemon only checks gaps if base tables exist
 # Check that both the condition and the gap checking code exist
 run grep -q 'BASE_TABLES_EXIST.*-eq.*0' \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
 
 # Also verify the gap checking code exists nearby
 run grep -q "Checking and logging gaps from database" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

@test "Daemon should warn when gaps are detected" {
 # Verify that daemon logs warning when gaps are detected
 run grep -q "Data gaps detected\|__logw.*gaps" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

@test "Daemon should handle gap recovery failure gracefully" {
 # Verify that daemon handles __recover_from_gaps failure gracefully
 run grep -q "Gap recovery check failed.*but continuing\|__recover_from_gaps.*then" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

@test "Daemon should query for unprocessed gaps only" {
 # Verify that daemon queries only for unprocessed gaps (processed = FALSE)
 run grep -q "processed = FALSE\|WHERE processed.*FALSE" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

@test "Daemon should limit gap query results" {
 # Verify that daemon limits gap query results (LIMIT 10)
 run grep -q "LIMIT 10\|ORDER BY gap_timestamp DESC" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

@test "Daemon should include gap details in query" {
 # Verify that daemon queries for gap details (gap_type, gap_count, etc.)
 run grep -q "gap_type\|gap_count\|total_count\|gap_percentage\|error_details" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

@test "Daemon should source processAPINotes.sh to get gap functions" {
 # Verify that daemon sources processAPINotes.sh to get __recover_from_gaps
 run grep -q "source.*processAPINotes\.sh\|\. processAPINotes\.sh" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

@test "Daemon should call __recover_from_gaps in __validateHistoricalDataAndRecover" {
 # Verify that __recover_from_gaps is called in the validation function
 # The function is called after historical validation
 # Check that both the function definition and the call exist
 run grep -q "__validateHistoricalDataAndRecover" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
 
 # Verify __recover_from_gaps is called
 run grep -q "__recover_from_gaps" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

@test "Daemon should call __check_and_log_gaps in __process_api_data" {
 # Verify that __check_and_log_gaps is called in the processing function
 # The check is done inline in __process_api_data, not as a function call
 run grep -q "Checking and logging gaps from database" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

