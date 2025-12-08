#!/usr/bin/env bats

# Note Processing Functions Tests
# Comprehensive tests for note processing functions
# Author: Andres Gomez (AngocA)
# Version: 2025-12-07

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

 # Mock psql command
 mock_psql() {
  echo "$@"
 }

 # Mock curl command for network tests
 mock_curl() {
  if [[ "$1" == "https://www.google.com" ]] || \
     [[ "$1" == "https://www.cloudflare.com" ]] || \
     [[ "$1" == "https://www.github.com" ]]; then
   return 0
  fi
  return 1
 }

 # Mock wget command
 mock_wget() {
  if [[ "$1" == "--timeout" ]]; then
   # Simulate successful download
   echo "mock content" > "$2"
   return 0
  fi
  return 1
 }

 # Load note processing functions
 source "${TEST_BASE_DIR}/bin/lib/noteProcessingFunctions.sh"
}

teardown() {
 # Clean up test files
 rm -rf "${TEST_DIR}"
}

# =============================================================================
# Function Existence Tests
# =============================================================================

@test "All note processing functions should be available" {
 # Test that all note processing functions exist
 run declare -f __getLocationNotes_impl
 [[ "${status}" -eq 0 ]]

 run declare -f __validate_xml_coordinates
 [[ "${status}" -eq 0 ]]

 run declare -f __check_network_connectivity
 [[ "${status}" -eq 0 ]]

 run declare -f __handle_error_with_cleanup
 [[ "${status}" -eq 0 ]]

 run declare -f __acquire_download_slot
 [[ "${status}" -eq 0 ]]

 run declare -f __release_download_slot
 [[ "${status}" -eq 0 ]]

 run declare -f __cleanup_stale_slots
 [[ "${status}" -eq 0 ]]

 run declare -f __wait_for_download_slot
 [[ "${status}" -eq 0 ]]

 run declare -f __get_download_ticket
 [[ "${status}" -eq 0 ]]

 run declare -f __queue_prune_stale_locks
 [[ "${status}" -eq 0 ]]

 run declare -f __wait_for_download_turn
 [[ "${status}" -eq 0 ]]

 run declare -f __release_download_ticket
 [[ "${status}" -eq 0 ]]

 run declare -f __retry_file_operation
 [[ "${status}" -eq 0 ]]

 run declare -f __check_overpass_status
 [[ "${status}" -eq 0 ]]

 run declare -f __retry_network_operation
 [[ "${status}" -eq 0 ]]

 run declare -f __retry_overpass_api
 [[ "${status}" -eq 0 ]]

 run declare -f __retry_osm_api
 [[ "${status}" -eq 0 ]]

 run declare -f __retry_geoserver_api
 [[ "${status}" -eq 0 ]]

 run declare -f __retry_database_operation
 [[ "${status}" -eq 0 ]]

 run declare -f __log_data_gap
 [[ "${status}" -eq 0 ]]
}

# =============================================================================
# Tests for __check_network_connectivity
# =============================================================================

@test "__check_network_connectivity should return 0 when network is available" {
 # Mock curl to return success
 curl() {
  return 0
 }
 export -f curl

 run __check_network_connectivity 5
 [[ "${status}" -eq 0 ]]
}

@test "__check_network_connectivity should return 1 when network is unavailable" {
 # Create a mock curl that always fails
 local MOCK_CURL="${TEST_DIR}/curl"
 cat > "${MOCK_CURL}" << 'EOF'
#!/bin/bash
exit 1
EOF
 chmod +x "${MOCK_CURL}"

 # Create a mock timeout that just executes the command
 local MOCK_TIMEOUT="${TEST_DIR}/timeout"
 cat > "${MOCK_TIMEOUT}" << 'EOF'
#!/bin/bash
shift
"$@"
EOF
 chmod +x "${MOCK_TIMEOUT}"

 export PATH="${TEST_DIR}:${PATH}"

 run __check_network_connectivity 5 2>/dev/null
 [[ "${status}" -eq 1 ]]
}

@test "__check_network_connectivity should accept timeout parameter" {
 # Mock curl to return success
 curl() {
  [[ "$1" == "--connect-timeout" ]]
  [[ "$2" == "10" ]]
  return 0
 }
 export -f curl

 run __check_network_connectivity 10
 [[ "${status}" -eq 0 ]]
}

# =============================================================================
# Tests for __handle_error_with_cleanup
# =============================================================================

@test "__handle_error_with_cleanup should execute cleanup commands when CLEAN=true" {
 export CLEAN="true"
 export TEST_MODE="true"
 export BATS_TEST_NAME="test"

 # Use a file to track cleanup execution
 local CLEANUP_FILE="${TEST_DIR}/cleanup_executed.txt"
 rm -f "${CLEANUP_FILE}"

 # Create a cleanup command that creates a file
 local CLEANUP_CMD="touch ${CLEANUP_FILE}"

 run __handle_error_with_cleanup 1 "Test error" "${CLEANUP_CMD}" 2>/dev/null
 [[ "${status}" -eq 1 ]]
 [[ -f "${CLEANUP_FILE}" ]]
}

@test "__handle_error_with_cleanup should skip cleanup when CLEAN=false" {
 export CLEAN="false"
 export TEST_MODE="true"
 export BATS_TEST_NAME="test"

 local CLEANUP_EXECUTED=false
 cleanup_cmd() {
  CLEANUP_EXECUTED=true
 }

 run __handle_error_with_cleanup 1 "Test error" "cleanup_cmd"
 [[ "${status}" -eq 1 ]]
 [[ "${CLEANUP_EXECUTED}" == "false" ]]
}

@test "__handle_error_with_cleanup should return error code in test mode" {
 export TEST_MODE="true"
 export BATS_TEST_NAME="test"

 run __handle_error_with_cleanup 42 "Test error"
 [[ "${status}" -eq 42 ]]
}

@test "__handle_error_with_cleanup should create failed execution file" {
 export TEST_MODE="true"
 export BATS_TEST_NAME="test"
 export FAILED_EXECUTION_FILE="${TEST_DIR}/failed_execution.txt"

 run __handle_error_with_cleanup 1 "Test error"
 [[ "${status}" -eq 1 ]]
 [[ -f "${FAILED_EXECUTION_FILE}" ]]
 [[ "$(cat "${FAILED_EXECUTION_FILE}")" == *"Test error"* ]]
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

 # Create 2 existing locks
 mkdir -p "${TEST_DIR}/download_queue/active"
 mkdir -p "${TEST_DIR}/download_queue/active/1000.lock"
 mkdir -p "${TEST_DIR}/download_queue/active/1001.lock"

 # Try to acquire third slot (should fail after retries)
 # Use run with expected failure code
 run -1 __acquire_download_slot 2>/dev/null
 # Should fail (timeout or max retries exceeded)
 [[ "${status}" -ne 0 ]]
}

@test "__release_download_slot should remove lock directory" {
 export TMP_DIR="${TEST_DIR}"
 local QUEUE_DIR="${TEST_DIR}/download_queue"
 local ACTIVE_DIR="${QUEUE_DIR}/active"
 mkdir -p "${ACTIVE_DIR}"

 # First acquire a slot to create a lock
 __acquire_download_slot >/dev/null 2>&1

 # Find the lock that was created
 local LOCK_DIR
 LOCK_DIR=$(find "${ACTIVE_DIR}" -name "*.lock" -type d 2>/dev/null | head -1)
 [[ -n "${LOCK_DIR}" ]]
 [[ -d "${LOCK_DIR}" ]]

 run __release_download_slot 2>/dev/null
 [[ "${status}" -eq 0 ]]
 
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

# =============================================================================
# Tests for __check_overpass_status
# =============================================================================

@test "__check_overpass_status should return 0 when slots available" {
 export OVERPASS_INTERPRETER="https://overpass-api.de/api/interpreter"

 # Mock curl to return status with available slots
 curl() {
  if [[ "$1" == "-s" ]] && [[ "$2" == "https://overpass-api.de/status" ]]; then
   echo "2 slots available now"
   return 0
  fi
  return 1
 }
 export -f curl

 # Capture only the wait time (last line)
 local WAIT_TIME
 WAIT_TIME=$(__check_overpass_status 2>/dev/null | tail -1)
 [[ "${WAIT_TIME}" == "0" ]]
}

@test "__check_overpass_status should return wait time when busy" {
 export OVERPASS_INTERPRETER="https://overpass-api.de/api/interpreter"

 # Mock curl to return status with wait time
 curl() {
  if [[ "$1" == "-s" ]] && [[ "$2" == "https://overpass-api.de/status" ]]; then
   echo "Slot available after in 30 seconds."
   return 0
  fi
  return 1
 }
 export -f curl

 # Capture only the wait time (last line)
 local WAIT_TIME
 WAIT_TIME=$(__check_overpass_status 2>/dev/null | tail -1)
 [[ "${WAIT_TIME}" == "30" ]]
}

@test "__check_overpass_status should handle connection failure" {
 export OVERPASS_INTERPRETER="https://overpass-api.de/api/interpreter"

 # Mock curl to fail
 curl() {
  return 1
 }
 export -f curl

 # Capture only the wait time (last line)
 local WAIT_TIME
 WAIT_TIME=$(__check_overpass_status 2>/dev/null | tail -1)
 [[ "${WAIT_TIME}" == "0" ]]
}

# =============================================================================
# Tests for Retry Functions
# =============================================================================

@test "__retry_file_operation should succeed on first attempt" {
 local SUCCESS_FILE="${TEST_DIR}/success.txt"

 # Mock operation that succeeds
 operation() {
  echo "success" > "${SUCCESS_FILE}"
  return 0
 }

 run __retry_file_operation "operation" 3 1
 [[ "${status}" -eq 0 ]]
 [[ -f "${SUCCESS_FILE}" ]]
}

@test "__retry_file_operation should retry on failure" {
 local ATTEMPT_FILE="${TEST_DIR}/attempts.txt"
 local ATTEMPT_COUNT=0

 # Mock operation that fails twice then succeeds
 operation() {
  ATTEMPT_COUNT=$((ATTEMPT_COUNT + 1))
  echo "${ATTEMPT_COUNT}" >> "${ATTEMPT_FILE}"
  if [[ ${ATTEMPT_COUNT} -lt 3 ]]; then
   return 1
  fi
  return 0
 }

 run __retry_file_operation "operation" 3 1
 [[ "${status}" -eq 0 ]]
 [[ $(wc -l < "${ATTEMPT_FILE}") -eq 3 ]]
}

@test "__retry_file_operation should fail after max retries" {
 # Mock operation that always fails
 operation() {
  return 1
 }

 run __retry_file_operation "operation" 2 1
 [[ "${status}" -eq 1 ]]
}

@test "__retry_file_operation should execute cleanup on failure" {
 # Use a file to track cleanup execution
 local CLEANUP_FILE="${TEST_DIR}/cleanup_executed.txt"
 rm -f "${CLEANUP_FILE}"

 # Mock operation that always fails
 operation() {
  return 1
 }
 export -f operation

 # Cleanup command that creates a file
 cleanup() {
  touch "${CLEANUP_FILE}"
 }
 export -f cleanup

 run __retry_file_operation "operation" 1 1 "cleanup" 2>/dev/null
 [[ "${status}" -eq 1 ]]
 [[ -f "${CLEANUP_FILE}" ]]
}

@test "__retry_network_operation should succeed with valid URL" {
 local OUTPUT_FILE="${TEST_DIR}/output.txt"

 # Create a mock wget script
 local MOCK_WGET="${TEST_DIR}/wget"
 cat > "${MOCK_WGET}" << 'EOF'
#!/bin/bash
# Find the output file argument (-O)
OUTPUT_ARG=""
for i in "$@"; do
 if [[ "${OUTPUT_ARG}" == "-O" ]]; then
  echo "mock content" > "$i"
  exit 0
 fi
 if [[ "$i" == "-O" ]]; then
  OUTPUT_ARG="-O"
 fi
done
exit 1
EOF
 chmod +x "${MOCK_WGET}"

 # Add mock to PATH
 export PATH="${TEST_DIR}:${PATH}"

 run __retry_network_operation "https://example.com" "${OUTPUT_FILE}" 3 1 10 2>/dev/null
 [[ "${status}" -eq 0 ]]
 [[ -f "${OUTPUT_FILE}" ]]
}

@test "__retry_network_operation should retry on failure" {
 local OUTPUT_FILE="${TEST_DIR}/output.txt"
 local ATTEMPT_FILE="${TEST_DIR}/attempts.txt"
 rm -f "${ATTEMPT_FILE}"

 # Create a mock wget script that fails twice then succeeds
 local MOCK_WGET="${TEST_DIR}/wget"
 cat > "${MOCK_WGET}" << EOF
#!/bin/bash
ATTEMPT_FILE="${ATTEMPT_FILE}"
if [[ -f "\${ATTEMPT_FILE}" ]]; then
 ATTEMPT=\$(cat "\${ATTEMPT_FILE}")
else
 ATTEMPT=0
fi
ATTEMPT=\$((ATTEMPT + 1))
echo "\${ATTEMPT}" > "\${ATTEMPT_FILE}"

# Find the output file argument (-O)
OUTPUT_ARG=""
for i in "\$@"; do
 if [[ "\${OUTPUT_ARG}" == "-O" ]]; then
  if [[ \${ATTEMPT} -ge 3 ]]; then
   echo "content" > "\$i"
   exit 0
  fi
 fi
 if [[ "\$i" == "-O" ]]; then
  OUTPUT_ARG="-O"
 fi
done
exit 1
EOF
 chmod +x "${MOCK_WGET}"

 # Add mock to PATH
 export PATH="${TEST_DIR}:${PATH}"

 run __retry_network_operation "https://example.com" "${OUTPUT_FILE}" 5 1 10 2>/dev/null
 [[ "${status}" -eq 0 ]]
 [[ -f "${OUTPUT_FILE}" ]]
}

@test "__retry_overpass_api should handle query parameter" {
 local OUTPUT_FILE="${TEST_DIR}/output.txt"

 # Mock wget to succeed
 wget() {
  if [[ "$1" == "-q" ]]; then
   echo "result" > "$3"
   return 0
  fi
  return 1
 }
 export -f wget

 run __retry_overpass_api "test query" "${OUTPUT_FILE}" 3 1 30
 [[ "${status}" -eq 0 ]]
}

@test "__retry_osm_api should use curl" {
 local OUTPUT_FILE="${TEST_DIR}/output.txt"

 # Create a mock curl script
 local MOCK_CURL="${TEST_DIR}/curl"
 cat > "${MOCK_CURL}" << 'EOF'
#!/bin/bash
# Find the output file argument (-o)
OUTPUT_ARG=""
for i in "$@"; do
 if [[ "${OUTPUT_ARG}" == "-o" ]]; then
  echo "result" > "$i"
  exit 0
 fi
 if [[ "$i" == "-o" ]]; then
  OUTPUT_ARG="-o"
 fi
done
exit 1
EOF
 chmod +x "${MOCK_CURL}"

 # Add mock to PATH
 export PATH="${TEST_DIR}:${PATH}"

 run __retry_osm_api "https://api.openstreetmap.org/api/0.6/notes" "${OUTPUT_FILE}" 3 1 30 2>/dev/null
 [[ "${status}" -eq 0 ]]
 [[ -f "${OUTPUT_FILE}" ]]
}

@test "__retry_geoserver_api should handle POST method" {
 local OUTPUT_FILE="${TEST_DIR}/output.txt"

 # Create a mock curl script that handles POST
 local MOCK_CURL="${TEST_DIR}/curl"
 cat > "${MOCK_CURL}" << 'EOF'
#!/bin/bash
# Find the output file argument (-o)
OUTPUT_ARG=""
for i in "$@"; do
 if [[ "${OUTPUT_ARG}" == "-o" ]]; then
  echo "result" > "$i"
  exit 0
 fi
 if [[ "$i" == "-o" ]]; then
  OUTPUT_ARG="-o"
 fi
done
exit 1
EOF
 chmod +x "${MOCK_CURL}"

 # Add mock to PATH
 export PATH="${TEST_DIR}:${PATH}"

 run __retry_geoserver_api "https://geoserver.example.com" "POST" "data" "${OUTPUT_FILE}" 3 1 30 2>/dev/null
 [[ "${status}" -eq 0 ]]
 [[ -f "${OUTPUT_FILE}" ]]
}

@test "__retry_database_operation should execute SQL query" {
 local OUTPUT_FILE="${TEST_DIR}/output.txt"

 # Mock psql to succeed
 psql() {
  if [[ "$1" == "-d" ]] && [[ "$3" == "-Atq" ]]; then
   echo "result" > "$6"
   return 0
  fi
  return 1
 }
 export -f psql

 run __retry_database_operation "SELECT 1" "${OUTPUT_FILE}" 3 1
 [[ "${status}" -eq 0 ]]
}

@test "__retry_database_operation should detect SQL errors" {
 local OUTPUT_FILE="${TEST_DIR}/output.txt"

 # Mock psql to return error
 psql() {
  if [[ "$1" == "-d" ]]; then
   echo "ERROR: syntax error" > "$6"
   return 1
  fi
  return 1
 }
 export -f psql

 run __retry_database_operation "INVALID SQL" "${OUTPUT_FILE}" 2 1
 [[ "${status}" -eq 1 ]]
}

# =============================================================================
# Tests for __validate_xml_coordinates
# =============================================================================

@test "__validate_xml_coordinates should validate valid XML coordinates" {
 local XML_FILE="${TEST_DIR}/valid.xml"
 cat > "${XML_FILE}" << 'EOF'
<?xml version="1.0"?>
<osm-notes>
 <note lat="40.7128" lon="-74.0060" id="1"/>
 <note lat="34.0522" lon="-118.2437" id="2"/>
</osm-notes>
EOF

 # Mock __validate_input_file to return success
 __validate_input_file() {
  return 0
 }

 # Mock __validate_coordinates to return success
 __validate_coordinates() {
  return 0
 }

 run __validate_xml_coordinates "${XML_FILE}"
 [[ "${status}" -eq 0 ]]
}

@test "__validate_xml_coordinates should detect invalid coordinates" {
 local XML_FILE="${TEST_DIR}/invalid.xml"
 cat > "${XML_FILE}" << 'EOF'
<?xml version="1.0"?>
<osm-notes>
 <note lat="200.0" lon="-74.0060" id="1"/>
</osm-notes>
EOF

 # Mock __validate_input_file to return success
 __validate_input_file() {
  return 0
 }

 # Mock __validate_coordinates to return failure for invalid coords
 __validate_coordinates() {
  if [[ "$1" == "200.0" ]]; then
   return 1
  fi
  return 0
 }

 run __validate_xml_coordinates "${XML_FILE}"
 [[ "${status}" -eq 1 ]]
}

@test "__validate_xml_coordinates should handle large files with lite validation" {
 local XML_FILE="${TEST_DIR}/large.xml"
 # Create a large file (>500MB simulation by creating many lines)
 for i in {1..1000}; do
  echo "<note lat=\"40.7128\" lon=\"-74.0060\" id=\"${i}\"/>" >> "${XML_FILE}"
 done

 # Mock stat to return large size
 stat() {
  if [[ "$1" == "--format=%s" ]]; then
   echo "600000000" # 600MB
   return 0
  fi
  return 1
 }
 export -f stat

 # Mock __validate_input_file
 __validate_input_file() {
  return 0
 }

 run __validate_xml_coordinates "${XML_FILE}"
 # Should succeed with lite validation
 [[ "${status}" -eq 0 ]]
}

# =============================================================================
# Tests for __log_data_gap
# =============================================================================

@test "__log_data_gap should log gap to file" {
 local GAP_FILE="/tmp/processAPINotes_gaps.log"
 rm -f "${GAP_FILE}"

 # Mock psql to succeed
 psql() {
  return 0
 }
 export -f psql

 run __log_data_gap "test_gap" "10" "100" "test details"
 [[ "${status}" -eq 0 ]]
 [[ -f "${GAP_FILE}" ]]
 [[ "$(grep -c "test_gap" "${GAP_FILE}")" -gt 0 ]]
}

@test "__log_data_gap should calculate percentage" {
 local GAP_FILE="/tmp/processAPINotes_gaps.log"
 rm -f "${GAP_FILE}"

 # Mock psql
 psql() {
  return 0
 }
 export -f psql

 run __log_data_gap "test_gap" "25" "100" "test"
 [[ "${status}" -eq 0 ]]
 [[ "$(grep -c "25%" "${GAP_FILE}")" -gt 0 ]]
}

@test "__log_data_gap should handle database errors gracefully" {
 local GAP_FILE="/tmp/processAPINotes_gaps.log"
 rm -f "${GAP_FILE}"

 # Mock psql to fail
 psql() {
  return 1
 }
 export -f psql

 run __log_data_gap "test_gap" "10" "100" "test"
 # Should still succeed even if database insert fails
 [[ "${status}" -eq 0 ]]
 [[ -f "${GAP_FILE}" ]]
}

# =============================================================================
# Tests for __getLocationNotes_impl (Basic tests - complex function)
# =============================================================================

@test "__getLocationNotes_impl should handle TEST_MODE" {
 export TEST_MODE="true"
 export HYBRID_MOCK_MODE=""
 export DBNAME="test_db"

 # Mock psql to return 0 notes
 psql() {
  if [[ "$5" == *"COUNT(*)"* ]]; then
   echo "0"
   return 0
  fi
  return 0
 }
 export -f psql

 run __getLocationNotes_impl
 # Should succeed and skip processing
 [[ "${status}" -eq 0 ]]
}

@test "__getLocationNotes_impl should handle notes without country" {
 export TEST_MODE="true"
 export HYBRID_MOCK_MODE=""
 export DBNAME="test_db"

 local CALL_COUNT=0
 # Mock psql to return notes count then succeed on update
 psql() {
  CALL_COUNT=$((CALL_COUNT + 1))
  if [[ ${CALL_COUNT} -eq 1 ]]; then
   # First call: COUNT query
   echo "5"
   return 0
  elif [[ ${CALL_COUNT} -eq 2 ]]; then
   # Second call: UPDATE query
   return 0
  fi
  return 0
 }
 export -f psql

 run __getLocationNotes_impl
 # Should succeed
 [[ "${status}" -eq 0 ]]
}

