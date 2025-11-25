#!/usr/bin/env bats

# Unit test for progress logging in note processing functions
# Tests that progress logging works correctly during integrity verification
# Author: Andres Gomez (AngocA)
# Version: 2025-11-25

load ../../test_helper

setup() {
 # Setup test environment
 export SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
 export TMP_DIR="$(mktemp -d)"
 export BASENAME="test_progress_logging"
 export LOG_LEVEL="INFO"
 export DBNAME="${TEST_DBNAME:-test_osm_notes}"

 # Ensure TMP_DIR exists and is writable
 if [[ ! -d "${TMP_DIR}" ]]; then
  mkdir -p "${TMP_DIR}"
 fi

 # Create test log file
 export LOG_FILE="${TMP_DIR}/test_progress.log"

 # Source the functions
 source "${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh"

 # Mock logger functions that write to log file
 function __log_start() {
  echo "[START] $*" >> "${LOG_FILE}"
 }
 function __log_finish() {
  echo "[FINISH] $*" >> "${LOG_FILE}"
 }
 function __logi() {
  echo "[INFO] $*" >> "${LOG_FILE}"
  echo "[INFO] $*" # Also output to stdout for test visibility
 }
 function __loge() {
  echo "[ERROR] $*" >> "${LOG_FILE}"
  echo "[ERROR] $*"
 }
 function __logw() {
  echo "[WARN] $*" >> "${LOG_FILE}"
 }
 function __logd() {
  echo "[DEBUG] $*" >> "${LOG_FILE}"
 }

 # Mock CSV backup file (only set if not already readonly)
 if ! declare -p CSV_BACKUP_NOTE_LOCATION_COMPRESSED &>/dev/null || [[ "$(declare -p CSV_BACKUP_NOTE_LOCATION_COMPRESSED 2>/dev/null)" != *"declare -r"* ]]; then
  export CSV_BACKUP_NOTE_LOCATION_COMPRESSED="${TMP_DIR}/backup_note_location.csv.gz"
 fi
 if ! declare -p CSV_BACKUP_NOTE_LOCATION &>/dev/null || [[ "$(declare -p CSV_BACKUP_NOTE_LOCATION 2>/dev/null)" != *"declare -r"* ]]; then
  export CSV_BACKUP_NOTE_LOCATION="${TMP_DIR}/backup_note_location.csv"
 fi
 # Create empty backup file
 touch "${CSV_BACKUP_NOTE_LOCATION:-${TMP_DIR}/backup_note_location.csv}"
 gzip -c "${CSV_BACKUP_NOTE_LOCATION:-${TMP_DIR}/backup_note_location.csv}" > "${CSV_BACKUP_NOTE_LOCATION_COMPRESSED:-${TMP_DIR}/backup_note_location.csv.gz}" 2>/dev/null || true
}

teardown() {
 # Cleanup test environment
 rm -rf "${TMP_DIR}"
}

# Test that progress logging messages are present in the code
@test "should have progress logging messages in __getLocationNotes_impl" {
 local functions_file="${SCRIPT_BASE_DIRECTORY}/bin/lib/noteProcessingFunctions.sh"

 # Test for progress message format
 run grep -q "Progress:.*chunks completed" "${functions_file}"
 [ "$status" -eq 0 ]

 # Test for heartbeat message
 run grep -q "Still processing" "${functions_file}"
 [ "$status" -eq 0 ]

 # Test for percentage calculation
 run grep -q "PERCENTAGE.*COMPLETED_CHUNKS.*100.*TOTAL_CHUNKS" "${functions_file}"
 [ "$status" -eq 0 ]

 # Test for estimated time remaining
 run grep -q "Estimated remaining" "${functions_file}"
 [ "$status" -eq 0 ]

 # Test for progress file usage
 run grep -q "PROGRESS_FILE" "${functions_file}"
 [ "$status" -eq 0 ]

 # Test for progress monitor background process
 run grep -q "PROGRESS_MONITOR_PID" "${functions_file}"
 [ "$status" -eq 0 ]
}

# Test that progress file mechanism exists
@test "should use PROGRESS_FILE for tracking progress" {
 local functions_file="${SCRIPT_BASE_DIRECTORY}/bin/lib/noteProcessingFunctions.sh"

 # Test for progress file creation
 run grep -q "PROGRESS_FILE" "${functions_file}"
 [ "$status" -eq 0 ]

 # Test for progress file reading (cat or reading from file)
 run grep -q "cat.*PROGRESS_FILE\|COMPLETED_CHUNKS.*cat\|PROGRESS_FILE.*cat" "${functions_file}"
 [ "$status" -eq 0 ]

 # Test for progress file locking (lock file or flock usage)
 run grep -q "PROGRESS_FILE.lock\|\.lock\|flock" "${functions_file}"
 [ "$status" -eq 0 ]
}

# Test that heartbeat mechanism exists
@test "should have heartbeat mechanism for progress reporting" {
 local functions_file="${SCRIPT_BASE_DIRECTORY}/bin/lib/noteProcessingFunctions.sh"

 # Test for heartbeat interval
 run grep -q "HEARTBEAT_INTERVAL" "${functions_file}"
 [ "$status" -eq 0 ]

 # Test for heartbeat check
 run grep -q "LAST_HEARTBEAT" "${functions_file}"
 [ "$status" -eq 0 ]

 # Test for elapsed time calculation
 run grep -q "ELAPSED.*CURRENT_TIME.*START_TIME" "${functions_file}"
 [ "$status" -eq 0 ]
}

# Test that progress monitor runs in background
@test "should start progress monitor in background" {
 local functions_file="${SCRIPT_BASE_DIRECTORY}/bin/lib/noteProcessingFunctions.sh"

 # Test for background process start (subshell with & or background process)
 run grep -q "PROGRESS_MONITOR_PID" "${functions_file}"
 [ "$status" -eq 0 ]

 # Test for progress monitor cleanup or wait
 run grep -q "kill.*PROGRESS_MONITOR_PID\|wait.*PROGRESS_MONITOR_PID" "${functions_file}"
 [ "$status" -eq 0 ]
}

# Test that progress logging includes required information
@test "should log progress with required information" {
 local functions_file="${SCRIPT_BASE_DIRECTORY}/bin/lib/noteProcessingFunctions.sh"

 # Test for chunks completed/total
 run grep -q "COMPLETED_CHUNKS.*TOTAL_CHUNKS" "${functions_file}"
 [ "$status" -eq 0 ]

 # Test for percentage
 run grep -q "PERCENTAGE" "${functions_file}"
 [ "$status" -eq 0 ]

 # Test for processed notes count
 run grep -q "PROCESSED_NOTES" "${functions_file}"
 [ "$status" -eq 0 ]

 # Test for estimated time remaining
 run grep -q "ESTIMATED_REMAINING\|Estimated remaining" "${functions_file}"
 [ "$status" -eq 0 ]
}

# Test that SQL file for integrity verification exists
@test "should have SQL file for integrity verification" {
 local sql_file="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_33_verifyNoteIntegrity.sql"

 [ -f "${sql_file}" ]

 # Test that SQL file contains expected content
 run grep -q "verifyNoteIntegrity\|ST_Contains" "${sql_file}"
 [ "$status" -eq 0 ]
}

# Test that progress reporting interval is reasonable
@test "should have reasonable progress reporting interval" {
 local functions_file="${SCRIPT_BASE_DIRECTORY}/bin/lib/noteProcessingFunctions.sh"

 # Test for report interval (should be around 30 seconds)
 run grep -q "REPORT_INTERVAL.*30" "${functions_file}"
 [ "$status" -eq 0 ]

 # Test for heartbeat interval (should be around 300 seconds / 5 minutes)
 run grep -q "HEARTBEAT_INTERVAL.*300" "${functions_file}"
 [ "$status" -eq 0 ]
}

# Test that function can be called (without actual execution)
@test "__getLocationNotes_impl should be available" {
 # Just check that the function exists
 run declare -f __getLocationNotes_impl
 [ "$status" -eq 0 ]
 [[ "$output" == *"__getLocationNotes_impl"* ]]
}

# Test that progress file format is correct
@test "should use correct progress file format" {
 local functions_file="${SCRIPT_BASE_DIRECTORY}/bin/lib/noteProcessingFunctions.sh"

 # Test that progress file is written to (various patterns)
 run grep -q "COMPLETED_CHUNKS.*PROGRESS_FILE\|PROGRESS_FILE.*COMPLETED_CHUNKS\|>.*PROGRESS_FILE" "${functions_file}"
 [ "$status" -eq 0 ]
}

