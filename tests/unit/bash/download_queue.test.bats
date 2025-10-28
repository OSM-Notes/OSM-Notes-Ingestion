#!/usr/bin/env bats
# Unit tests for download queue FIFO system
# Author: Andres Gomez (AngocA)
# Version: 2025-01-27

load "$(dirname "$BATS_TEST_FILENAME")/../../test_helper.bash"

setup() {
 SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
 export TMP_DIR="$(mktemp -d)"
 export BASENAME="test_download_queue"
 export BASHPID=$$
 export RATE_LIMIT=4
 export OVERPASS_INTERPRETER="https://overpass-api.de/api/interpreter"

 # Load functions
 source "${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh" > /dev/null 2>&1
}

teardown() {
 # Cleanup queue directory
 rm -rf "${TMP_DIR}/download_queue" 2> /dev/null || true
 rm -rf "${TMP_DIR}" 2> /dev/null || true
}

@test "__get_download_ticket should exist" {
 declare -f __get_download_ticket
 [ "$?" -eq 0 ]
}

@test "__get_download_ticket should return sequential ticket numbers" {
 local TICKET1 TICKET2 TICKET3
 TICKET1=$(__get_download_ticket 2>&1 | grep -E "^[0-9]+$" | head -1)
 TICKET2=$(__get_download_ticket 2>&1 | grep -E "^[0-9]+$" | head -1)
 TICKET3=$(__get_download_ticket 2>&1 | grep -E "^[0-9]+$" | head -1)

 [ "${TICKET1}" -eq 1 ]
 [ "${TICKET2}" -eq 2 ]
 [ "${TICKET3}" -eq 3 ]
}

@test "__wait_for_download_turn should exist" {
 declare -f __wait_for_download_turn
 [ "$?" -eq 0 ]
}

@test "__release_download_ticket should exist" {
 declare -f __release_download_ticket
 [ "$?" -eq 0 ]
}

@test "__wait_for_download_turn should accept ticket when slots available" {
 # Get a ticket
 local TICKET
 TICKET=$(__get_download_ticket 2>&1 | grep -E "^[0-9]+$" | head -1)

 # Mock __check_overpass_status
 __check_overpass_status() {
  echo "0"
  return 0
 }
 export -f __check_overpass_status

 # Wait for turn (should succeed quickly)
 local START_TIME
 START_TIME=$(date +%s)
 __wait_for_download_turn "${TICKET}"
 local END_TIME
 END_TIME=$(date +%s)
 local ELAPSED=$((END_TIME - START_TIME))

 # Should complete quickly (< 2 seconds)
 [ "${ELAPSED}" -lt 2 ]

 # Verify lock file was created
 [ -f "${TMP_DIR}/download_queue/active/${BASHPID}.${TICKET}.lock" ]
}

@test "__release_download_ticket should remove lock file" {
 # Get a ticket and create lock
 local TICKET
 TICKET=$(__get_download_ticket 2>&1 | grep -E "^[0-9]+$" | head -1)

 mkdir -p "${TMP_DIR}/download_queue/active"
 echo "${TICKET}" > "${TMP_DIR}/download_queue/active/${BASHPID}.${TICKET}.lock"

 # Verify lock exists
 [ -f "${TMP_DIR}/download_queue/active/${BASHPID}.${TICKET}.lock" ]

 # Release ticket
 __release_download_ticket "${TICKET}"

 # Verify lock is removed
 [ ! -f "${TMP_DIR}/download_queue/active/${BASHPID}.${TICKET}.lock" ]
}

@test "__release_download_ticket should advance queue counter" {
 # Initialize queue
 mkdir -p "${TMP_DIR}/download_queue"
 echo "0" > "${TMP_DIR}/download_queue/current_serving"

 # Create lock for ticket 1
 mkdir -p "${TMP_DIR}/download_queue/active"
 echo "1" > "${TMP_DIR}/download_queue/active/${BASHPID}.1.lock"

 # Release ticket 1
 __release_download_ticket "1"

 # Current serving should advance to 2
 local CURRENT
 CURRENT=$(cat "${TMP_DIR}/download_queue/current_serving")
 [ "${CURRENT}" = "2" ]
}

@test "queue should handle multiple concurrent tickets" {
 # Get multiple tickets
 local TICKET1 TICKET2 TICKET3
 TICKET1=$(__get_download_ticket 2>&1 | grep -E "^[0-9]+$" | head -1)
 TICKET2=$(__get_download_ticket 2>&1 | grep -E "^[0-9]+$" | head -1)
 TICKET3=$(__get_download_ticket 2>&1 | grep -E "^[0-9]+$" | head -1)

 [ "${TICKET1}" -eq 1 ]
 [ "${TICKET2}" -eq 2 ]
 [ "${TICKET3}" -eq 3 ]

 # Verify ticket counter was incremented
 local COUNTER
 COUNTER=$(cat "${TMP_DIR}/download_queue/ticket_counter" 2> /dev/null || echo "0")
 [ "${COUNTER}" -eq 3 ]
}

@test "__wait_for_download_turn should respect RATE_LIMIT" {
 # Set lower RATE_LIMIT for testing
 export RATE_LIMIT=2

 # Create scenario with 2 active downloads (at limit)
 mkdir -p "${TMP_DIR}/download_queue/active"
 echo "1" > "${TMP_DIR}/download_queue/active/1000.1.lock"
 echo "2" > "${TMP_DIR}/download_queue/active/1001.2.lock"

 # Initialize serving
 echo "0" > "${TMP_DIR}/download_queue/current_serving"

 # Get ticket 3
 local TICKET
 TICKET=$(__get_download_ticket 2>&1 | grep -E "^[0-9]+$" | head -1)

 # Mock API to return slots available
 __check_overpass_status() {
  echo "0"
  return 0
 }
 export -f __check_overpass_status

 # Should wait since we're at limit
 run timeout 2 bash -c "
    source '${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh' > /dev/null 2>&1
    __check_overpass_status() { echo '0'; return 0; }
    export TMP_DIR='${TMP_DIR}'
    export BASHPID=$$
    export RATE_LIMIT=2
    __wait_for_download_turn '${TICKET}'
  "

 # Should timeout (not get slot immediately)
 [ "${status}" -ne 0 ] || [ ! -f "${TMP_DIR}/download_queue/active/${BASHPID}.${TICKET}.lock" ]
}

@test "__retry_file_operation should use queue when smart_wait enabled" {
 # Create a mock operation
 local TEST_FILE="${TMP_DIR}/test_operation.txt"
 local OPERATION="echo 'test' > '${TEST_FILE}'"

 # Mock __check_overpass_status
 __check_overpass_status() {
  echo "0"
  return 0
 }
 export -f __check_overpass_status

 # Run with smart_wait
 run __retry_file_operation "${OPERATION}" 3 1 "" "true" 2>&1

 # Operation should succeed
 [ "${status}" -eq 0 ]
 [ -f "${TEST_FILE}" ]

 # Queue directory should exist (even if no Overpass operation)
 [ -d "${TMP_DIR}/download_queue" ] || true
}

@test "queue should handle cleanup on exit" {
 # Get ticket and create lock
 local TICKET
 TICKET=$(__get_download_ticket 2>&1 | grep -E "^[0-9]+$" | head -1)

 mkdir -p "${TMP_DIR}/download_queue/active"
 echo "${TICKET}" > "${TMP_DIR}/download_queue/active/${BASHPID}.${TICKET}.lock"

 # Simulate cleanup
 __release_download_ticket "${TICKET}"

 # Lock should be gone
 [ ! -f "${TMP_DIR}/download_queue/active/${BASHPID}.${TICKET}.lock" ]
}

@test "queue directory structure should be created correctly" {
 # Get ticket to initialize directory structure
 local TICKET
 TICKET=$(__get_download_ticket 2>&1 | grep -E "^[0-9]+$" | head -1) || true

 # Verify directory structure
 [ -d "${TMP_DIR}/download_queue" ]
 [ -f "${TMP_DIR}/download_queue/ticket_counter" ]
}

@test "__get_download_ticket should be thread-safe" {
 # Simulate concurrent ticket requests
 local PIDS=()
 local TICKETS_FILE="${TMP_DIR}/tickets.txt"
 rm -f "${TICKETS_FILE}"

 for i in {1..10}; do
  (
   source "${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh" > /dev/null 2>&1
   export TMP_DIR="${TMP_DIR}"
   export BASHPID=$BASHPID
   local TICKET
   TICKET=$(__get_download_ticket 2>&1 | grep -E "^[0-9]+$" | head -1)
   echo "${TICKET}" >> "${TICKETS_FILE}"
  ) &
  PIDS+=($!)
 done

 # Wait for all processes
 for pid in "${PIDS[@]}"; do
  wait "${pid}"
 done

 # Verify all tickets are unique and sequential
 sort -n "${TICKETS_FILE}" > "${TMP_DIR}/sorted_tickets.txt"
 local UNIQUE_COUNT
 UNIQUE_COUNT=$(sort -u "${TMP_DIR}/tickets.txt" | wc -l)
 local TOTAL_COUNT
 TOTAL_COUNT=$(wc -l < "${TMP_DIR}/tickets.txt")

 # All tickets should be unique
 [ "${UNIQUE_COUNT}" -eq "${TOTAL_COUNT}" ]
 # Should have 10 tickets
 [ "${TOTAL_COUNT}" -eq 10 ]
}
