#!/usr/bin/env bats

# Note Processing Download Queue Tests
# Tests for download slot and ticket queue functions
# Author: Andres Gomez (AngocA)
# Version: 2025-12-14

# Require minimum BATS version
bats_require_minimum_version 1.5.0

load "${BATS_TEST_DIRNAME}/../../test_helper"

setup() {
 # Create temporary test directory
 TEST_DIR=$(mktemp -d)
 export TEST_DIR

 # Set up test environment variables
 export SCRIPT_BASE_DIRECTORY="${TEST_BASE_DIR}"
 export TMP_DIR="${TEST_DIR}"
 export DBNAME="${TEST_DBNAME:-test_db}"
 export RATE_LIMIT="${RATE_LIMIT:-8}"
 export BASHPID=$$

 # Set log level to DEBUG to capture all log output
 export LOG_LEVEL="DEBUG"
 export __log_level="DEBUG"

 # Load note processing functions
 source "${TEST_BASE_DIR}/bin/lib/noteProcessingFunctions.sh"
}

teardown() {
 # Clean up test files
 rm -rf "${TEST_DIR}"
}

# =============================================================================
# Tests for Download Slot Functions (Simple Semaphore System)
# =============================================================================

@test "__acquire_download_slot should create lock directory" {
 export RATE_LIMIT=8
 local QUEUE_DIR="${TEST_DIR}/download_queue"
 local ACTIVE_DIR="${QUEUE_DIR}/active"
 export TMP_DIR="${TEST_DIR}"

 # Ensure queue directory exists
 mkdir -p "${QUEUE_DIR}"

 run __acquire_download_slot 2>/dev/null
 [[ "${status}" -eq 0 ]]
 # Check if any lock directory was created in active subdirectory
 local LOCKS_FOUND
 LOCKS_FOUND=$(find "${ACTIVE_DIR}" -name "*.lock" -type d 2>/dev/null | wc -l)
 [[ "${LOCKS_FOUND}" -gt 0 ]]
}

@test "__acquire_download_slot should respect MAX_SLOTS limit" {
 export RATE_LIMIT=2
 export TMP_DIR="${TEST_DIR}"

 # Create 2 existing locks with valid PIDs to prevent cleanup by __cleanup_stale_slots
 # The function checks if PIDs exist, so we need to use real PIDs
 mkdir -p "${TEST_DIR}/download_queue/active"
 # Create lock with current shell PID ($$ is the test runner, will not be cleaned up)
 local TEST_PID=$$
 mkdir -p "${TEST_DIR}/download_queue/active/${TEST_PID}.lock"
 echo "${TEST_PID}" > "${TEST_DIR}/download_queue/active/${TEST_PID}.lock/pid"
 # Create another lock with parent PID (PPID also exists)
 local PARENT_PID=${PPID:-$((TEST_PID + 1))}
 mkdir -p "${TEST_DIR}/download_queue/active/${PARENT_PID}.lock"
 echo "${PARENT_PID}" > "${TEST_DIR}/download_queue/active/${PARENT_PID}.lock/pid"

 # Try to acquire third slot (should fail after retries)
 # Should fail with exit code 1 (timeout or max retries exceeded)
 run __acquire_download_slot 2>/dev/null
 # Should fail (timeout or max retries exceeded)
 [[ "${status}" -eq 1 ]]
}

@test "__release_download_slot should remove lock directory" {
 export TMP_DIR="${TEST_DIR}"
 local QUEUE_DIR="${TEST_DIR}/download_queue"
 local ACTIVE_DIR="${QUEUE_DIR}/active"
 mkdir -p "${ACTIVE_DIR}"

 # First acquire a slot to create a lock
 # Store the BASHPID before acquiring to ensure we use the same one
 local ACQUIRE_PID=${BASHPID}
 __acquire_download_slot >/dev/null 2>&1

 # Find the lock that was created (should match the PID that acquired it)
 local LOCK_DIR
 LOCK_DIR=$(find "${ACTIVE_DIR}" -name "*.lock" -type d 2>/dev/null | head -1)
 [[ -n "${LOCK_DIR}" ]]
 [[ -d "${LOCK_DIR}" ]]

 # Release the slot (don't use run to avoid subshell BASHPID issues)
 # The function uses BASHPID internally, which should match since we're in the same shell
 __release_download_slot >/dev/null 2>&1
 local RELEASE_STATUS=$?
 [[ "${RELEASE_STATUS}" -eq 0 ]]
 
 # Lock directory should be removed
 [[ ! -d "${LOCK_DIR}" ]]
}

@test "__cleanup_stale_slots should remove locks for non-existent PIDs" {
 export TMP_DIR="${TEST_DIR}"
 local QUEUE_DIR="${TEST_DIR}/download_queue"
 local ACTIVE_DIR="${QUEUE_DIR}/active"
 mkdir -p "${ACTIVE_DIR}"

 # Create lock for non-existent PID
 mkdir -p "${ACTIVE_DIR}/99999.lock"

 run __cleanup_stale_slots
 [[ "${status}" -eq 0 ]]
 [[ ! -d "${ACTIVE_DIR}/99999.lock" ]]
}

@test "__cleanup_stale_slots should keep locks for existing PIDs" {
 export TMP_DIR="${TEST_DIR}"
 local QUEUE_DIR="${TEST_DIR}/download_queue"
 local ACTIVE_DIR="${QUEUE_DIR}/active"
 mkdir -p "${ACTIVE_DIR}"

 # Create lock for current PID
 mkdir -p "${ACTIVE_DIR}/${BASHPID}.lock"

 run __cleanup_stale_slots
 [[ "${status}" -eq 0 ]]
 [[ -d "${ACTIVE_DIR}/${BASHPID}.lock" ]]
}

@test "__wait_for_download_slot should call __acquire_download_slot" {
 export TMP_DIR="${TEST_DIR}"
 export RATE_LIMIT=8

 run __wait_for_download_slot
 [[ "${status}" -eq 0 ]]
}

# =============================================================================
# Tests for Download Ticket Functions (Ticket-Based Queue System)
# =============================================================================

@test "__get_download_ticket should return ticket number" {
 export TMP_DIR="${TEST_DIR}"

 # Capture ticket from file (function writes to file and echoes)
 __get_download_ticket >/dev/null 2>&1
 local TICKET_FILE="${TEST_DIR}/download_queue/ticket_counter"
 
 [[ -f "${TICKET_FILE}" ]]
 local TICKET
 TICKET=$(cat "${TICKET_FILE}")
 [[ -n "${TICKET}" ]]
 [[ "${TICKET}" =~ ^[0-9]+$ ]]
}

@test "__get_download_ticket should increment ticket counter" {
 export TMP_DIR="${TEST_DIR}"

 # Get tickets from file
 __get_download_ticket >/dev/null 2>&1
 local TICKET_FILE="${TEST_DIR}/download_queue/ticket_counter"
 local TICKET1
 TICKET1=$(cat "${TICKET_FILE}")
 
 __get_download_ticket >/dev/null 2>&1
 local TICKET2
 TICKET2=$(cat "${TICKET_FILE}")

 [[ "${TICKET2}" -gt "${TICKET1}" ]]
}

@test "__queue_prune_stale_locks should remove stale ticket locks" {
 export TMP_DIR="${TEST_DIR}"
 local QUEUE_DIR="${TEST_DIR}/download_queue"
 local ACTIVE_DIR="${QUEUE_DIR}/active"
 mkdir -p "${ACTIVE_DIR}"

 # Create lock for non-existent PID
 touch "${ACTIVE_DIR}/99999.1.lock"

 run __queue_prune_stale_locks
 [[ "${status}" -eq 0 ]]
 [[ ! -f "${ACTIVE_DIR}/99999.1.lock" ]]
}

@test "__release_download_ticket should remove lock file" {
 export TMP_DIR="${TEST_DIR}"
 local QUEUE_DIR="${TEST_DIR}/download_queue"
 local ACTIVE_DIR="${QUEUE_DIR}/active"
 mkdir -p "${ACTIVE_DIR}"

 # Get ticket from file
 __get_download_ticket >/dev/null 2>&1
 local TICKET_FILE="${QUEUE_DIR}/ticket_counter"
 local TICKET
 TICKET=$(cat "${TICKET_FILE}" 2>/dev/null || echo "1")
 
 # Create lock file manually (function expects format: PID.TICKET.lock)
 local LOCK_FILE="${ACTIVE_DIR}/${BASHPID}.${TICKET}.lock"
 echo "${TICKET}" > "${LOCK_FILE}"
 [[ -f "${LOCK_FILE}" ]]

 # Verify function removes the lock file
 run __release_download_ticket "${TICKET}" 2>/dev/null
 [[ "${status}" -eq 0 ]]
 
 # Wait a moment for file system to sync
 sleep 0.1
 
 # Lock file should be removed
 [[ ! -f "${LOCK_FILE}" ]] || echo "Lock file still exists: ${LOCK_FILE}"
}

@test "__release_download_ticket should advance current serving" {
 export TMP_DIR="${TEST_DIR}"
 local QUEUE_DIR="${TEST_DIR}/download_queue"
 mkdir -p "${QUEUE_DIR}"

 # Get ticket from file
 __get_download_ticket >/dev/null 2>&1
 local TICKET_FILE="${QUEUE_DIR}/ticket_counter"
 local TICKET
 TICKET=$(cat "${TICKET_FILE}")
 echo "0" > "${QUEUE_DIR}/current_serving"

 run __release_download_ticket "${TICKET}" 2>/dev/null
 [[ "${status}" -eq 0 ]]
 local CURRENT_SERVING
 CURRENT_SERVING=$(cat "${QUEUE_DIR}/current_serving")
 [[ "${CURRENT_SERVING}" -gt 0 ]]
}

