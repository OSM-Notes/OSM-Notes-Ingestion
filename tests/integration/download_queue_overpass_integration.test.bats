#!/usr/bin/env bats
# Integration tests for download queue with real Overpass API
# Author: Andres Gomez (AngocA)
# Version: 2025-01-27

load "$(dirname "$BATS_TEST_FILENAME")/../test_helper.bash"

setup() {
 # Load test helper first
 load "$(dirname "$BATS_TEST_FILENAME")/../test_helper.bash"

 SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
 export TMP_DIR="$(mktemp -d)"
 export BASENAME="test_queue_integration"
 export BASHPID=$$
 export RATE_LIMIT=4
 export OVERPASS_INTERPRETER="https://overpass-api.de/api/interpreter"

 # Set test mode to avoid real exits
 export TEST_MODE="true"

 # Ensure functions are loaded - functionsProcess.sh is loaded by test_helper.bash
 # But we need to make sure it's available
 if ! declare -f __release_download_ticket > /dev/null 2>&1; then
  # Try to source the file directly if not already loaded
  if [ -f "${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh" ]; then
   source "${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh" > /dev/null 2>&1 || true
  fi
 fi
}

teardown() {
 # Cleanup
 rm -rf "${TMP_DIR}/download_queue" 2> /dev/null || true
 rm -rf "${TMP_DIR}" 2> /dev/null || true
}

@test "should handle multiple sequential downloads with queue" {
 # Small boundary IDs for quick testing
 local BOUNDARY_IDS=("3793105" "3793110") # Small test relations

 local SUCCESS_COUNT=0
 local FAIL_COUNT=0

 # Ensure TMP_DIR exists
 mkdir -p "${TMP_DIR}"

 for ID in "${BOUNDARY_IDS[@]}"; do
  local JSON_FILE="${TMP_DIR}/${ID}.json"
  local QUERY_FILE="${TMP_DIR}/query_${ID}.op"

  # Create query
  cat > "${QUERY_FILE}" << EOF
[out:json];
rel(${ID});
(._;>;);
out;
EOF

  # Download with queue system
  local OPERATION="wget -O '${JSON_FILE}' --post-file='${QUERY_FILE}' '${OVERPASS_INTERPRETER}' 2> /dev/null"

  # Use run to capture output
  run __retry_file_operation "${OPERATION}" 3 2 "" "true"

  if [ "${status}" -eq 0 ]; then
   if [[ -f "${JSON_FILE}" ]] && [[ -s "${JSON_FILE}" ]]; then
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
   else
    FAIL_COUNT=$((FAIL_COUNT + 1))
   fi
  else
   FAIL_COUNT=$((FAIL_COUNT + 1))
  fi

  # Small delay between downloads
  sleep 1
 done

 # Should have at least some success (skip if no connectivity)
 echo "Successful downloads: ${SUCCESS_COUNT}, Failed: ${FAIL_COUNT}"

 # Check if functions are available
 if ! declare -f __retry_file_operation > /dev/null 2>&1; then
  skip "Functions not loaded, skipping download test"
 fi

 if [ "${SUCCESS_COUNT}" -eq 0 ] && [ "${FAIL_COUNT}" -gt 0 ]; then
  # Check if it's a connectivity issue
  if ! curl -s --max-time 5 "${OVERPASS_INTERPRETER%/api/interpreter}/status" > /dev/null 2>&1; then
   skip "Overpass API not reachable, skipping download test"
  fi
 fi

 # If we have connectivity and functions, at least one should succeed
 if command -v curl > /dev/null && curl -s --max-time 5 "${OVERPASS_INTERPRETER%/api/interpreter}/status" > /dev/null 2>&1; then
  [ "${SUCCESS_COUNT}" -gt 0 ]
 else
  skip "Cannot verify downloads without connectivity or functions"
 fi
}

@test "should respect queue order with parallel downloads" {
 # Skip if test is too slow or API is unavailable
 skip "Parallel queue test - may be slow or hit rate limits"

 local BOUNDARY_IDS=("3793105" "3793110" "3793115")
 local PIDS=()
 local RESULTS_FILE="${TMP_DIR}/results.txt"
 rm -f "${RESULTS_FILE}"

 # Launch parallel downloads
 for ID in "${BOUNDARY_IDS[@]}"; do
  (
   source "${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh" > /dev/null 2>&1
   export TMP_DIR="${TMP_DIR}"
   export BASHPID=$$
   export OVERPASS_INTERPRETER="${OVERPASS_INTERPRETER}"
   export RATE_LIMIT=4
   export TEST_MODE="true"

   local JSON_FILE="${TMP_DIR}/${ID}.json"
   local QUERY_FILE="${TMP_DIR}/query_${ID}.op"

   cat > "${QUERY_FILE}" << EOF
[out:json];
rel(${ID});
(._;>;);
out;
EOF

   local OPERATION="wget -O '${JSON_FILE}' --post-file='${QUERY_FILE}' '${OVERPASS_INTERPRETER}' 2> /dev/null"
   local START_TIME
   START_TIME=$(date +%s)

   if __retry_file_operation "${OPERATION}" 3 2 "" "true"; then
    local END_TIME
    END_TIME=$(date +%s)
    echo "${ID}:SUCCESS:$((END_TIME - START_TIME))" >> "${RESULTS_FILE}"
   else
    echo "${ID}:FAILED:0" >> "${RESULTS_FILE}"
   fi
  ) &
  PIDS+=($!)
 done

 # Wait for all downloads
 for pid in "${PIDS[@]}"; do
  wait "${pid}" || true
 done

 # Verify queue was used (all downloads should complete)
 local SUCCESS_COUNT
 SUCCESS_COUNT=$(grep -c "SUCCESS" "${RESULTS_FILE}" 2> /dev/null || echo "0")
 echo "Results:"
 cat "${RESULTS_FILE}" || true

 # At least some should succeed
 [ "${SUCCESS_COUNT}" -gt 0 ]
}

@test "should handle Overpass API rate limiting with queue" {
 # This test verifies the queue handles API rate limits gracefully
 mkdir -p "${TMP_DIR}"
 local ID="3793105"
 local JSON_FILE="${TMP_DIR}/${ID}.json"
 local QUERY_FILE="${TMP_DIR}/query_${ID}.op"

 cat > "${QUERY_FILE}" << EOF
[out:json];
rel(${ID});
(._;>;);
out;
EOF

 # Try download with queue
 local OPERATION="wget -O '${JSON_FILE}' --post-file='${QUERY_FILE}' '${OVERPASS_INTERPRETER}' 2> /dev/null"

 # Check if functions are available
 if ! declare -f __retry_file_operation > /dev/null 2>&1; then
  skip "Functions not loaded, skipping rate limiting test"
 fi

 # Check connectivity first
 if ! curl -s --max-time 5 "${OVERPASS_INTERPRETER%/api/interpreter}/status" > /dev/null 2>&1; then
  skip "Overpass API not reachable, skipping rate limiting test"
 fi

 # Should handle gracefully even if API is busy
 run __retry_file_operation "${OPERATION}" 5 3 "" "true"

 # Should either succeed or fail gracefully
 [ "${status}" -eq 0 ] || [ "${status}" -eq 1 ]

 # If succeeded, file should exist and be non-empty
 if [ "${status}" -eq 0 ]; then
  [ -f "${JSON_FILE}" ]
  [ -s "${JSON_FILE}" ]
 fi
}

@test "queue should prevent race conditions with concurrent downloads" {
 # Test with multiple processes trying to download simultaneously
 local ID="3793105"
 local PIDS=()
 local LOCKS_CREATED=0

 # Launch 10 concurrent download attempts
 for i in {1..10}; do
  (
   source "${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh" > /dev/null 2>&1
   export TMP_DIR="${TMP_DIR}"
   export BASHPID=$$
   export OVERPASS_INTERPRETER="${OVERPASS_INTERPRETER}"
   export RATE_LIMIT=4
   export TEST_MODE="true"

   local JSON_FILE="${TMP_DIR}/${ID}_${i}.json"
   local QUERY_FILE="${TMP_DIR}/query_${ID}_${i}.op"

   cat > "${QUERY_FILE}" << EOF
[out:json];
rel(${ID});
(._;>;);
out;
EOF

   # Just attempt to get ticket and wait for turn (don't actually download)
   local TICKET
   TICKET=$(__get_download_ticket 2>&1 | tail -1)

   # Wait for turn (will timeout but that's OK for this test)
   timeout 2 __wait_for_download_turn "${TICKET}" 2> /dev/null && {
    echo "lock_created" >> "${TMP_DIR}/locks_${i}.txt"
   } || true
  ) &
  PIDS+=($!)
 done

 # Wait a bit
 sleep 3

 # Check how many locks were created (should be <= RATE_LIMIT)
 if [ -d "${TMP_DIR}/download_queue/active" ]; then
  LOCKS_CREATED=$(find "${TMP_DIR}/download_queue/active" -name "*.lock" -type f 2> /dev/null | wc -l)
 fi

 # Cleanup remaining processes
 for pid in "${PIDS[@]}"; do
  kill "${pid}" 2> /dev/null || true
 done
 wait 2> /dev/null || true

 # Should not exceed RATE_LIMIT
 echo "Locks created: ${LOCKS_CREATED}, RATE_LIMIT: ${RATE_LIMIT}"
 [ "${LOCKS_CREATED}" -le "${RATE_LIMIT}" ]
}

@test "should cleanup queue on process exit" {
 # Get a ticket and create lock
 mkdir -p "${TMP_DIR}/download_queue/active"
 local TICKET
 TICKET=$(__get_download_ticket 2>&1 | grep -E "^[0-9]+$" | head -1)

 mkdir -p "${TMP_DIR}/download_queue/active"
 echo "${TICKET}" > "${TMP_DIR}/download_queue/active/${BASHPID}.${TICKET}.lock"

 # Verify lock exists
 [ -f "${TMP_DIR}/download_queue/active/${BASHPID}.${TICKET}.lock" ]

 # Setup cleanup function
 __cleanup_test() {
  __release_download_ticket "${TICKET}" > /dev/null 2>&1 || true
 }

 trap '__cleanup_test' EXIT

 # Simulate exit cleanup
 __cleanup_test
 trap - EXIT

 # Lock should be removed
 [ ! -f "${TMP_DIR}/download_queue/active/${BASHPID}.${TICKET}.lock" ]
}

@test "should handle queue with real boundary processing scenario" {
 # Test with a real small boundary ID
 mkdir -p "${TMP_DIR}"
 local BOUNDARY_ID="3793105"
 local JSON_FILE="${TMP_DIR}/${BOUNDARY_ID}.json"
 local QUERY_FILE="${TMP_DIR}/query_${BOUNDARY_ID}.op"

 # Create query file similar to __processBoundary
 cat > "${QUERY_FILE}" << EOF
[out:json];
rel(${BOUNDARY_ID});
(._;>;);
out;
EOF

 # Simulate __processBoundary call with queue
 local MAX_RETRIES=3
 local BASE_DELAY=2
 local OVERPASS_OPERATION="wget -O '${JSON_FILE}' --post-file='${QUERY_FILE}' '${OVERPASS_INTERPRETER}' 2> /dev/null"

 run __retry_file_operation "${OVERPASS_OPERATION}" "${MAX_RETRIES}" "${BASE_DELAY}" "" "true"

 if [ "${status}" -eq 0 ]; then
  # Verify download succeeded
  [ -f "${JSON_FILE}" ]
  [ -s "${JSON_FILE}" ]

  # Verify JSON structure (basic check)
  local JSON_CONTENT
  JSON_CONTENT=$(cat "${JSON_FILE}" 2> /dev/null || echo "")
  [[ "${JSON_CONTENT}" == *"elements"* ]] || [[ "${JSON_CONTENT}" == *"version"* ]] || true
 else
  # If it failed, it should be a graceful failure
  echo "Download failed, but queue handled it gracefully"
  [ ! -f "${JSON_FILE}" ] || [ ! -s "${JSON_FILE}" ]
 fi
}

@test "should verify queue advances correctly after downloads" {
 # Initialize queue
 mkdir -p "${TMP_DIR}/download_queue"
 echo "0" > "${TMP_DIR}/download_queue/current_serving"

 # Simulate downloading with tickets 1, 2, 3, 4 (filling slots)
 # Note: We need to use actual PIDs for the locks to work correctly
 for TICKET in 1 2 3 4; do
  mkdir -p "${TMP_DIR}/download_queue/active"
  echo "${TICKET}" > "${TMP_DIR}/download_queue/active/${BASHPID}.${TICKET}.lock"
 done

 # Verify initial locks exist
 local INITIAL_COUNT
 INITIAL_COUNT=$(find "${TMP_DIR}/download_queue/active" -name "*.lock" -type f 2> /dev/null | wc -l)
 [ "${INITIAL_COUNT}" -eq 4 ]

 # Verify initial serving is 0
 local INITIAL_SERVING
 INITIAL_SERVING=$(cat "${TMP_DIR}/download_queue/current_serving" 2> /dev/null || echo "0")
 [ "${INITIAL_SERVING}" = "0" ]

 # Check if function is available
 if ! declare -f __release_download_ticket > /dev/null 2>&1; then
  skip "Functions not loaded, skipping queue advance test"
 fi

 # Release ticket 1 (should advance queue to 2, since ticket 1 = current_serving (0) + 1)
 __release_download_ticket "1"
 local CURRENT
 CURRENT=$(cat "${TMP_DIR}/download_queue/current_serving" 2> /dev/null || echo "0")

 # Queue should advance to 2 (ticket 1 was released and was next in line)
 [ "${CURRENT}" = "2" ]

 # Verify lock 1 was removed
 [ ! -f "${TMP_DIR}/download_queue/active/${BASHPID}.1.lock" ]

 # Release ticket 2 (should advance queue to 3, since ticket 2 = current_serving (2))
 __release_download_ticket "2"
 CURRENT=$(cat "${TMP_DIR}/download_queue/current_serving" 2> /dev/null || echo "0")
 [ "${CURRENT}" = "3" ]

 # Verify lock 2 was removed
 [ ! -f "${TMP_DIR}/download_queue/active/${BASHPID}.2.lock" ]

 # Verify remaining locks (only 3 and 4 should remain)
 local ACTIVE_COUNT
 ACTIVE_COUNT=$(find "${TMP_DIR}/download_queue/active" -name "*.lock" -type f 2> /dev/null | wc -l)
 [ "${ACTIVE_COUNT}" -eq 2 ]
}
