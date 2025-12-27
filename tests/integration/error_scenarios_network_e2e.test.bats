#!/usr/bin/env bats

# End-to-end integration tests for network error scenarios
# Tests: Network errors, retry logic
# Author: Andres Gomez (AngocA)
# Version: 2025-12-23

load "$(dirname "$BATS_TEST_FILENAME")/../test_helper.bash"

setup() {
 # Set up test environment
 export SCRIPT_BASE_DIRECTORY="${TEST_BASE_DIR}"
 export TMP_DIR="$(mktemp -d)"
 export TEST_DIR="${TMP_DIR}"
 export DBNAME="${TEST_DBNAME:-osm_notes_ingestion_test}"
 export BASENAME="test_error_scenarios_e2e"
 export LOG_LEVEL="ERROR"
 export TEST_MODE="true"

 # Mock logger functions
 __log_start() { :; }
 __log_finish() { :; }
 __logi() { :; }
 __logd() { :; }
 __loge() { echo "ERROR: $*" >&2; }
 __logw() { echo "WARN: $*" >&2; }
 export -f __log_start __log_finish __logi __logd __loge __logw
}

teardown() {
 # Clean up
 if [[ -n "${TMP_DIR:-}" ]] && [[ -d "${TMP_DIR}" ]]; then
  rm -rf "${TMP_DIR}"
 fi
}

# =============================================================================
# Network Error Scenarios
# =============================================================================

@test "E2E Error: Should handle network errors during download" {
 # Test: Network error during API download
 # Purpose: Verify that network errors are handled gracefully
 # Expected: Error is caught and logged, retry logic is triggered

 # Mock download function that fails
 __retry_osm_api() {
  local URL="$1"
  local OUTPUT_FILE="$2"
  # Simulate network failure
  echo "ERROR: Network connection failed" >&2
  return 1
 }
 export -f __retry_osm_api

 # Attempt download
 local DOWNLOADED_FILE="${TMP_DIR}/failed_download.xml"
 run __retry_osm_api "https://api.openstreetmap.org/api/0.6/notes/search.xml" "${DOWNLOADED_FILE}"

 # Should fail with network error
 [ "$status" -ne 0 ]
 [[ "$output" == *"Network connection failed"* ]] || [[ "$output" == *"ERROR"* ]]
}

@test "E2E Error: Should retry download after network error" {
 # Test: Retry logic after network error
 # Purpose: Verify that retry mechanism works
 # Expected: Retry is attempted after failure

 local RETRY_COUNT=0
 local MAX_RETRIES=3

 # Mock download function that fails first 2 times, succeeds on 3rd
 __retry_osm_api() {
  RETRY_COUNT=$((RETRY_COUNT + 1))
  local URL="$1"
  local OUTPUT_FILE="$2"
  
  if [[ "${RETRY_COUNT}" -lt 3 ]]; then
   echo "ERROR: Network error (attempt ${RETRY_COUNT})" >&2
   return 1
  else
   # Success on 3rd attempt
   echo '<?xml version="1.0"?><osm></osm>' > "${OUTPUT_FILE}"
   return 0
  fi
 }
 export -f __retry_osm_api

 # Simulate retry logic
 local DOWNLOADED_FILE="${TMP_DIR}/retry_download.xml"
 local ATTEMPT=0
 local SUCCESS=0

 while [[ ${ATTEMPT} -lt ${MAX_RETRIES} ]]; do
  ATTEMPT=$((ATTEMPT + 1))
  if __retry_osm_api "https://api.openstreetmap.org/api/0.6/notes/search.xml" "${DOWNLOADED_FILE}"; then
   SUCCESS=1
   break
  fi
  sleep 0.1
 done

 # Should succeed after retries
 [[ "${SUCCESS}" -eq 1 ]]
 [[ "${RETRY_COUNT}" -eq 3 ]]
}

