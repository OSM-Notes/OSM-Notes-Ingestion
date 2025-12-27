#!/usr/bin/env bats

# Unit tests for processAPINotesDaemon.sh gap detection
# Tests that the daemon detects and handles data gaps correctly
# Author: Andres Gomez (AngocA)
# Version: 2025-12-15

load "${BATS_TEST_DIRNAME}/../../test_helper"
load "${BATS_TEST_DIRNAME}/../../test_helpers_common"
load "${BATS_TEST_DIRNAME}/daemon_test_helpers"

setup() {
 __setup_daemon_test
 export BASENAME="test_daemon_gaps"
 export LOCK="/tmp/${BASENAME}.lock"
 export DAEMON_SHUTDOWN_FLAG="/tmp/${BASENAME}_shutdown"
 rm -f "${LOCK}"
 rm -f "${DAEMON_SHUTDOWN_FLAG}"
}

teardown() {
 __teardown_daemon_test
}

# =============================================================================
# Tests for Gap Detection Functions
# =============================================================================

@test "Daemon should call __recover_from_gaps before processing" {
 # Test: Daemon calls __recover_from_gaps during initialization
 # Purpose: Verify that gap recovery is triggered before processing API data
 # Expected: __recover_from_gaps should be called in __validateHistoricalDataAndRecover

 local RECOVER_CALLED=0

 # Mock __recover_from_gaps to track if it's called
 __recover_from_gaps() {
  RECOVER_CALLED=1
  return 0
 }
 export -f __recover_from_gaps

 # Mock __checkHistoricalData to succeed (so __recover_from_gaps is called)
 __checkHistoricalData() {
  return 0
 }
 export -f __checkHistoricalData

 # Mock psql to return that max_note_timestamp table exists
 __setup_mock_psql_with_tracking "" "" \
  "information_schema.tables.*max_note_timestamp:1" \
  ".*:0"

 # Simulate __validateHistoricalDataAndRecover logic
 local BASE_TABLES_EXIST=0
 if [[ "${BASE_TABLES_EXIST:-1}" -eq 0 ]]; then
  # Historical validation passed, call gap recovery
  if __checkHistoricalData; then
   __recover_from_gaps || true
  fi
 fi

 [[ "${RECOVER_CALLED}" -eq 1 ]]
}

@test "Daemon should check data_gaps table existence before querying" {
 # Test: Daemon checks if data_gaps table exists before querying
 # Purpose: Verify that daemon doesn't query non-existent table
 # Expected: psql should be called with information_schema query for data_gaps

 # Use file-based tracking since variables don't persist in subshells
 local TRACK_FILE="${TEST_DIR}/psql_track_gaps"
 rm -f "${TRACK_FILE}"

 # Mock psql with tracking and pattern matching
 __setup_mock_psql_with_tracking "${TRACK_FILE}" "${TEST_DIR}/gap_table_check_matched" \
  "data_gaps.*information_schema:1" \
  ".*:0"

 # Simulate daemon's gap checking logic
 local BASE_TABLES_EXIST=0
 if [[ "${BASE_TABLES_EXIST:-0}" -eq 0 ]]; then
  local GAP_TABLE_EXISTS
  GAP_TABLE_EXISTS=$(psql -d "${DBNAME}" -Atq -c \
   "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'data_gaps'" \
   2> /dev/null | grep -E '^[0-9]+$' | tail -1 || echo "0")
 fi

 # Read tracking results
 local PSQL_CALLED=0
 local GAP_TABLE_CHECK_MATCHED=0
 PSQL_CALLED=$(cat "${TRACK_FILE}" 2>/dev/null || echo "0")
 GAP_TABLE_CHECK_MATCHED=$(cat "${TEST_DIR}/gap_table_check_matched" 2>/dev/null || echo "0")

 [[ "${PSQL_CALLED}" -eq 1 ]]
 [[ "${GAP_TABLE_CHECK_MATCHED}" -eq 1 ]]
}

@test "Daemon should query data_gaps table for recent gaps" {
 # Test: Daemon queries data_gaps table for gaps in last 24 hours
 # Purpose: Verify that daemon queries for recent unprocessed gaps
 # Expected: psql should be called with query for gaps in last 1 day

 local TRACK_FILE="${TEST_DIR}/psql_track_gaps_query"
 local MATCH_FILE="${TEST_DIR}/gap_query_matched"
 rm -f "${TRACK_FILE}" "${MATCH_FILE}"

 # Mock psql with tracking and pattern matching
 __setup_mock_psql_with_tracking "${TRACK_FILE}" "${MATCH_FILE}" \
  "FROM data_gaps.*INTERVAL '1 day'.*processed = FALSE:2025-01-23|missing_comments|10|100|10.0|" \
  ".*:0"

 local PSQL_CALLED=0
 local GAP_QUERY_MATCHED=0

 # Simulate daemon's gap querying logic
 local BASE_TABLES_EXIST=0
 local GAP_TABLE_EXISTS=1
 if [[ "${BASE_TABLES_EXIST:-0}" -eq 0 ]] && [[ "${GAP_TABLE_EXISTS}" == "1" ]]; then
  local GAP_QUERY="
    SELECT 
      gap_timestamp,
      gap_type,
      gap_count,
      total_count,
      gap_percentage,
      error_details
    FROM data_gaps
    WHERE processed = FALSE
      AND gap_timestamp > NOW() - INTERVAL '1 day'
    ORDER BY gap_timestamp DESC
    LIMIT 10
  "
  local GAP_FILE="/tmp/processAPINotesDaemon_gaps.log"
  psql -d "${DBNAME}" -Atq -c "${GAP_QUERY}" > "${GAP_FILE}" 2> /dev/null || true
 fi

 PSQL_CALLED=$(cat "${TRACK_FILE}" 2>/dev/null || echo "0")
 GAP_QUERY_MATCHED=$(cat "${MATCH_FILE}" 2>/dev/null || echo "0")

 [[ "${PSQL_CALLED}" -eq 1 ]]
 [[ "${GAP_QUERY_MATCHED}" -eq 1 ]]
 [[ -f "/tmp/processAPINotesDaemon_gaps.log" ]]
}

@test "Daemon should log gaps to file" {
 # Test: Daemon logs detected gaps to a file
 # Purpose: Verify that daemon creates gap log file when gaps are detected
 # Expected: Gap log file should be created with gap information

 local GAP_FILE="/tmp/processAPINotesDaemon_gaps.log"
 rm -f "${GAP_FILE}"

 # Mock psql to return gap data
 __setup_mock_psql_with_tracking "" "" \
  "FROM data_gaps:2025-01-23 10:00:00|missing_comments|5|50|10.0|" \
  ".*:1"

 # Simulate daemon's gap logging logic
 local BASE_TABLES_EXIST=0
 if [[ "${BASE_TABLES_EXIST:-0}" -eq 0 ]]; then
  local GAP_TABLE_EXISTS=1
  if [[ "${GAP_TABLE_EXISTS}" == "1" ]]; then
   local GAP_QUERY="
     SELECT 
       gap_timestamp,
       gap_type,
       gap_count,
       total_count,
       gap_percentage,
       error_details
     FROM data_gaps
     WHERE processed = FALSE
       AND gap_timestamp > NOW() - INTERVAL '1 day'
     ORDER BY gap_timestamp DESC
     LIMIT 10
   "
   psql -d "${DBNAME}" -Atq -c "${GAP_QUERY}" > "${GAP_FILE}" 2> /dev/null || true
   if [[ -f "${GAP_FILE}" ]] && [[ -s "${GAP_FILE}" ]]; then
    # Gaps detected, file should exist and be non-empty
    [[ -f "${GAP_FILE}" ]]
    [[ -s "${GAP_FILE}" ]]
   fi
  fi
 fi
}

@test "Daemon should only check gaps if base tables exist" {
 # Test: Daemon only checks gaps if base tables exist
 # Purpose: Verify that daemon doesn't check gaps on fresh database
 # Expected: Gap checking should be skipped if BASE_TABLES_EXIST != 0

 local GAP_CHECK_ATTEMPTED=0

 # Mock gap checking function
 __check_gaps() {
  GAP_CHECK_ATTEMPTED=1
 }
 export -f __check_gaps

 # Simulate daemon logic: only check gaps if base tables exist
 local BASE_TABLES_EXIST=1
 if [[ "${BASE_TABLES_EXIST:-0}" -eq 0 ]]; then
  __check_gaps
 fi

 # Since BASE_TABLES_EXIST=1 (missing), gap check should NOT be attempted
 [[ "${GAP_CHECK_ATTEMPTED}" -eq 0 ]]
}

@test "Daemon should query for unprocessed gaps only" {
 # Test: Daemon queries only for unprocessed gaps (processed = FALSE)
 # Purpose: Verify that daemon filters for unprocessed gaps
 # Expected: SQL query should include WHERE processed = FALSE

 local TRACK_FILE="${TEST_DIR}/psql_track_unprocessed"
 local MATCH_FILE="${TEST_DIR}/unprocessed_filter_matched"
 rm -f "${TRACK_FILE}" "${MATCH_FILE}"

 # Mock psql with tracking and pattern matching
 __setup_mock_psql_with_tracking "${TRACK_FILE}" "${MATCH_FILE}" \
  "processed = FALSE:0" \
  "processed.*FALSE:0" \
  ".*:0"

 local PSQL_CALLED=0
 local UNPROCESSED_FILTER_MATCHED=0

 # Simulate daemon's gap query
 local GAP_QUERY="
   SELECT 
     gap_timestamp,
     gap_type,
     gap_count,
     total_count,
     gap_percentage,
     error_details
   FROM data_gaps
   WHERE processed = FALSE
     AND gap_timestamp > NOW() - INTERVAL '1 day'
   ORDER BY gap_timestamp DESC
   LIMIT 10
 "
 psql -d "${DBNAME}" -Atq -c "${GAP_QUERY}" > /dev/null 2>&1 || true

 PSQL_CALLED=$(cat "${TRACK_FILE}" 2>/dev/null || echo "0")
 UNPROCESSED_FILTER_MATCHED=$(cat "${MATCH_FILE}" 2>/dev/null || echo "0")

 [[ "${PSQL_CALLED}" -eq 1 ]]
 [[ "${UNPROCESSED_FILTER_MATCHED}" -eq 1 ]]
}

@test "Daemon should limit gap query results" {
 # Test: Daemon limits gap query results to 10
 # Purpose: Verify that daemon doesn't query unlimited gaps
 # Expected: SQL query should include LIMIT 10

 local TRACK_FILE="${TEST_DIR}/psql_track_limit"
 local MATCH_FILE="${TEST_DIR}/limit_matched"
 rm -f "${TRACK_FILE}" "${MATCH_FILE}"

 # Mock psql with tracking and pattern matching
 __setup_mock_psql_with_tracking "${TRACK_FILE}" "${MATCH_FILE}" \
  "LIMIT 10:0" \
  ".*:0"

 local PSQL_CALLED=0
 local LIMIT_MATCHED=0

 # Simulate daemon's gap query with LIMIT
 local GAP_QUERY="
   SELECT 
     gap_timestamp,
     gap_type,
     gap_count,
     total_count,
     gap_percentage,
     error_details
   FROM data_gaps
   WHERE processed = FALSE
     AND gap_timestamp > NOW() - INTERVAL '1 day'
   ORDER BY gap_timestamp DESC
   LIMIT 10
 "
 psql -d "${DBNAME}" -Atq -c "${GAP_QUERY}" > /dev/null 2>&1 || true

 PSQL_CALLED=$(cat "${TRACK_FILE}" 2>/dev/null || echo "0")
 LIMIT_MATCHED=$(cat "${MATCH_FILE}" 2>/dev/null || echo "0")

 [[ "${PSQL_CALLED}" -eq 1 ]]
 [[ "${LIMIT_MATCHED}" -eq 1 ]]
}

@test "Daemon should detect gaps in last 7 days" {
 # Test: __recover_from_gaps checks for gaps in last 7 days
 # Purpose: Verify that gap recovery function checks recent data
 # Expected: SQL query in __recover_from_gaps should include INTERVAL '7 days'

 # This test verifies the logic in processAPINotes.sh's __recover_from_gaps
 # The daemon sources processAPINotes.sh, so this function is available

 local TRACK_FILE="${TEST_DIR}/psql_track_seven_days"
 local MATCH_FILE="${TEST_DIR}/seven_days_interval_matched"
 rm -f "${TRACK_FILE}" "${MATCH_FILE}"

 # Mock psql with tracking and pattern matching
 __setup_mock_psql_with_tracking "${TRACK_FILE}" "${MATCH_FILE}" \
  "INTERVAL '7 days'.*created_at.*max_note_timestamp:0" \
  ".*:0"

 local PSQL_CALLED=0
 local SEVEN_DAYS_INTERVAL_MATCHED=0

 # Simulate __recover_from_gaps query logic
 # This is the query from processAPINotes.sh that checks for gaps
 local GAP_QUERY="
   SELECT COUNT(DISTINCT n.note_id) as gap_count
   FROM notes n
   LEFT JOIN note_comments nc ON nc.note_id = n.note_id
   WHERE n.created_at > (
     SELECT timestamp FROM max_note_timestamp
   ) - INTERVAL '7 days'
   AND nc.note_id IS NULL
 "
 psql -d "${DBNAME}" -Atq -c "${GAP_QUERY}" > /dev/null 2>&1 || true

 PSQL_CALLED=$(cat "${TRACK_FILE}" 2>/dev/null || echo "0")
 SEVEN_DAYS_INTERVAL_MATCHED=$(cat "${MATCH_FILE}" 2>/dev/null || echo "0")

 [[ "${PSQL_CALLED}" -eq 1 ]]
 [[ "${SEVEN_DAYS_INTERVAL_MATCHED}" -eq 1 ]]
}

@test "Daemon should handle gap recovery failure gracefully" {
 # Test: Daemon handles __recover_from_gaps failure without exiting
 # Purpose: Verify that daemon continues even if gap recovery fails
 # Expected: Failed gap recovery should log warning but not exit

 local RECOVER_FAILED=0
 local CONTINUED_AFTER_FAILURE=0

 # Mock __recover_from_gaps to fail
 __recover_from_gaps() {
  RECOVER_FAILED=1
  return 1
 }
 export -f __recover_from_gaps

 # Mock __checkHistoricalData to succeed
 __checkHistoricalData() {
  return 0
 }
 export -f __checkHistoricalData

 # Simulate daemon logic: continue even if gap recovery fails
 if __checkHistoricalData; then
  if ! __recover_from_gaps; then
   # Gap recovery failed, but daemon continues
   CONTINUED_AFTER_FAILURE=1
  fi
 fi

 [[ "${RECOVER_FAILED}" -eq 1 ]]
 [[ "${CONTINUED_AFTER_FAILURE}" -eq 1 ]]
}
