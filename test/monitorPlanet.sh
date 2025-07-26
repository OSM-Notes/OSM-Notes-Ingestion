#!/bin/bash

# Test script for the monitoring system to validate both success and failure scenarios.
# This script creates test scenarios to verify that the monitoring system correctly
# identifies when there are differences between API and Planet data.
#
# Test scenarios:
# 1. Success case: DB contains all data from API and matches Planet dump
# 2. Failure case: Missing notes in DB that should be present
# 3. Failure case: Missing comments in DB that should be present
# 4. Failure case: Missing text comments in DB that should be present
#
# Author: Andres Gomez (AngocA)
# Version: 2025-01-27
declare -r VERSION="2025-01-27"

#set -xv
# Fails when a variable is not initialized.
set -u
# Fails with a non-zero return code.
set -e
# Fails if the commands of a pipe return non-zero.
set -o pipefail
# Fails if an internal function fails.
set -E

# Logger levels: TRACE, DEBUG, INFO, WARN, ERROR, FATAL.
declare LOG_LEVEL="${LOG_LEVEL:-INFO}"

# Process type for this script (empty for normal execution).
declare PROCESS_TYPE="${1:-}"

# Base directory for the project.
declare SCRIPT_BASE_DIRECTORY
SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." \
 &> /dev/null && pwd)"
readonly SCRIPT_BASE_DIRECTORY

# Define database settings for testing
declare -r DBNAME="${TEST_DBNAME:-notes_test}"
declare -r DB_USER="${TEST_DBUSER:-testuser}"
declare -r DB_PASSWORD="${TEST_DBPASSWORD:-testpass}"
declare -r DB_HOST="${TEST_DBHOST:-localhost}"
declare -r DB_PORT="${TEST_DBPORT:-5432}"

# Define other required variables
declare -r EMAILS="test@example.com"
declare -r OSM_API="https://api.openstreetmap.org/api/0.6"
declare -r PLANET="https://planet.openstreetmap.org"
declare -r OVERPASS_INTERPRETER="https://overpass-api.de/api/interpreter"
declare -r SECONDS_TO_WAIT="30"
declare -r LOOP_SIZE="10000"
declare -r MAX_NOTES="10000"
declare MAX_THREADS="4"
MAX_THREADS=$(nproc)
readonly MAX_THREADS
declare -r CLEAN="false"

# Mask for the files and directories.
umask 0000

declare BASENAME
BASENAME=$(basename -s .sh "${0}")
readonly BASENAME
# Temporary directory for all files.
declare TMP_DIR
TMP_DIR=$(mktemp -d "/tmp/${BASENAME}_XXXXXX")
readonly TMP_DIR
chmod 777 "${TMP_DIR}"
# Log file for output.
declare LOG_FILENAME
LOG_FILENAME="${TMP_DIR}/${BASENAME}.log"
readonly LOG_FILENAME

# Test database name for isolated testing.
declare -r TEST_DBNAME="notes_test"
declare -r ORIGINAL_DBNAME="${DBNAME}"

# Location of the common functions.
declare -r FUNCTIONS_FILE="${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh"

# Monitoring scripts.
declare -r MONITOR_SCRIPT="${SCRIPT_BASE_DIRECTORY}/bin/monitor/notesCheckVerifier.sh"
declare -r PROCESS_CHECK_SCRIPT="${SCRIPT_BASE_DIRECTORY}/bin/monitor/processCheckPlanetNotes.sh"

###########
# FUNCTIONS

# shellcheck source=../bin/functionsProcess.sh
source "${FUNCTIONS_FILE}"

# Shows the help information.
function __show_help {
 echo "${BASENAME} version ${VERSION}"
 echo "Test script for the monitoring system to validate both success and failure scenarios."
 echo
 echo "Usage:"
 echo "  ${0} [--help|-h]"
 echo
 echo "This script creates test scenarios to verify that the monitoring system correctly"
 echo "identifies when there are differences between API and Planet data."
 echo
 echo "Test scenarios:"
 echo "  1. Success case: DB contains all data from API and matches Planet dump"
 echo "  2. Failure case: Missing notes in DB that should be present"
 echo "  3. Failure case: Missing comments in DB that should be present"
 echo "  4. Failure case: Missing text comments in DB that should be present"
 echo
 echo "Written by: Andres Gomez (AngocA)"
 echo "OSM-LatAm, OSM-Colombia, MaptimeBogota."
 exit "${ERROR_HELP_MESSAGE}"
}

# Checks prerequisites to run the script.
function __checkPrereqs {
 __log_start
 if [[ "${PROCESS_TYPE}" != "" ]] && [[ "${PROCESS_TYPE}" != "--help" ]] \
  && [[ "${PROCESS_TYPE}" != "-h" ]]; then
  echo "ERROR: Invalid parameter. It should be:"
  echo " * Empty string, nothing."
  echo " * --help"
  exit "${ERROR_INVALID_ARGUMENT}"
 fi
 set +e
 # Checks prereqs.
 # Skip PostGIS check for test environment
 if [[ -z "${TEST_DBNAME:-}" ]]; then
  __checkPrereqsCommands
 fi

 ## Checks required files.
 if [[ ! -r "${MONITOR_SCRIPT}" ]]; then
  __loge "ERROR: Monitor script is missing at ${MONITOR_SCRIPT}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${PROCESS_CHECK_SCRIPT}" ]]; then
  __loge "ERROR: Process check script is missing at ${PROCESS_CHECK_SCRIPT}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 __checkPrereqs_functions
 __log_finish
 set -e
}

# Creates test database and loads sample data.
function __setupTestDatabase {
 __log_start
 __logi "Setting up test database: ${TEST_DBNAME}"

 # Create test database
 psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d postgres -c "DROP DATABASE IF EXISTS ${TEST_DBNAME};"
 psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d postgres -c "CREATE DATABASE ${TEST_DBNAME};"
 # Skip PostGIS extensions for test environment
 # psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "CREATE EXTENSION postgis;"
 # psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "CREATE EXTENSION btree_gist;"

 # Create base tables structure
 psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_21_createBaseTables_enum.sql"
 psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_22_createBaseTables_tables.sql"
 # Skip PostGIS constraints for test environment
 # psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_23_createBaseTables_constraints.sql"

 # Create check tables
 psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/monitor/processCheckPlanetNotes_21_createCheckTables.sql"

 __log_finish
}

# Loads sample data for success scenario (complete data).
function __loadSuccessScenario {
 __log_start
 __logi "Loading success scenario data"

 # Insert sample notes (complete data)
 psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "
 INSERT INTO notes (note_id, latitude, longitude, created_at, status, id_country) VALUES
 (1001, 40.7128, -74.0060, '2025-01-01 10:00:00', 'open', 1),
 (1002, 34.0522, -118.2437, '2025-01-01 11:00:00', 'close', 1),
 (1003, 51.5074, -0.1278, '2025-01-01 12:00:00', 'open', 2);
 "

 # Insert sample comments
 psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "
 INSERT INTO note_comments (note_id, sequence_action, event, created_at, id_user) VALUES
 (1001, 1, 'opened', '2025-01-01 10:00:00', 12345),
 (1001, 2, 'commented', '2025-01-01 10:30:00', 67890),
 (1002, 1, 'opened', '2025-01-01 11:00:00', 12345),
 (1002, 2, 'closed', '2025-01-01 11:30:00', 67890),
 (1003, 1, 'opened', '2025-01-01 12:00:00', 12345);
 "

 # Insert sample text comments
 psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "
 INSERT INTO note_comments_text (note_id, sequence_action, body) VALUES
 (1001, 1, 'Note opened for testing'),
 (1001, 2, 'This is a test comment'),
 (1002, 1, 'Another test note'),
 (1002, 2, 'Note closed'),
 (1003, 1, 'Third test note');
 "

 # Insert same data into check tables (simulating Planet data)
 psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "
 INSERT INTO notes_check (note_id, latitude, longitude, created_at, status, id_country) VALUES
 (1001, 40.7128, -74.0060, '2025-01-01 10:00:00', 'open', 1),
 (1002, 34.0522, -118.2437, '2025-01-01 11:00:00', 'close', 1),
 (1003, 51.5074, -0.1278, '2025-01-01 12:00:00', 'open', 2);
 "

 psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "
 INSERT INTO note_comments_check (note_id, sequence_action, event, created_at, id_user) VALUES
 (1001, 1, 'opened', '2025-01-01 10:00:00', 12345),
 (1001, 2, 'commented', '2025-01-01 10:30:00', 67890),
 (1002, 1, 'opened', '2025-01-01 11:00:00', 12345),
 (1002, 2, 'closed', '2025-01-01 11:30:00', 67890),
 (1003, 1, 'opened', '2025-01-01 12:00:00', 12345);
 "

 psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "
 INSERT INTO note_comments_text_check (note_id, sequence_action, body) VALUES
 (1001, 1, 'Note opened for testing'),
 (1001, 2, 'This is a test comment'),
 (1002, 1, 'Another test note'),
 (1002, 2, 'Note closed'),
 (1003, 1, 'Third test note');
 "

 __log_finish
}

# Loads sample data for failure scenario (missing data).
function __loadFailureScenario {
 __log_start
 __logi "Loading failure scenario data"

 # Insert sample notes (missing some data)
 psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "
 INSERT INTO notes (note_id, latitude, longitude, created_at, status, id_country) VALUES
 (1001, 40.7128, -74.0060, '2025-01-01 10:00:00', 'open', 1),
 (1002, 34.0522, -118.2437, '2025-01-01 11:00:00', 'close', 1);
 -- Note 1003 is missing from API data
 "

 # Insert sample comments (missing some data)
 psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "
 INSERT INTO note_comments (note_id, sequence_action, event, created_at, id_user) VALUES
 (1001, 1, 'opened', '2025-01-01 10:00:00', 12345),
 (1001, 2, 'commented', '2025-01-01 10:30:00', 67890),
 (1002, 1, 'opened', '2025-01-01 11:00:00', 12345);
 -- Comment for note 1002 sequence 2 is missing from API data
 "

 # Insert sample text comments (missing some data)
 psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "
 INSERT INTO note_comments_text (note_id, sequence_action, body) VALUES
 (1001, 1, 'Note opened for testing'),
 (1001, 2, 'This is a test comment');
 -- Text comments for note 1002 are missing from API data
 "

 # Insert complete data into check tables (simulating Planet data)
 psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "
 INSERT INTO notes_check (note_id, latitude, longitude, created_at, status, id_country) VALUES
 (1001, 40.7128, -74.0060, '2025-01-01 10:00:00', 'open', 1),
 (1002, 34.0522, -118.2437, '2025-01-01 11:00:00', 'close', 1),
 (1003, 51.5074, -0.1278, '2025-01-01 12:00:00', 'open', 2);
 "

 psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "
 INSERT INTO note_comments_check (note_id, sequence_action, event, created_at, id_user) VALUES
 (1001, 1, 'opened', '2025-01-01 10:00:00', 12345),
 (1001, 2, 'commented', '2025-01-01 10:30:00', 67890),
 (1002, 1, 'opened', '2025-01-01 11:00:00', 12345),
 (1002, 2, 'closed', '2025-01-01 11:30:00', 67890),
 (1003, 1, 'opened', '2025-01-01 12:00:00', 12345);
 "

 psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "
 INSERT INTO note_comments_text_check (note_id, sequence_action, body) VALUES
 (1001, 1, 'Note opened for testing'),
 (1001, 2, 'This is a test comment'),
 (1002, 1, 'Another test note'),
 (1002, 2, 'Note closed'),
 (1003, 1, 'Third test note');
 "

 __log_finish
}

# Runs the monitoring script and captures output.
function __runMonitoringTest {
 __log_start
 local SCENARIO_NAME="${1}"
 local EXPECTED_DIFFERENCES="${2}"

 __logi "Running monitoring test for scenario: ${SCENARIO_NAME}"

 # Create temporary files for monitoring output
 local MONITOR_OUTPUT="${TMP_DIR}/monitor_output_${SCENARIO_NAME}.log"
 local MONITOR_ERROR="${TMP_DIR}/monitor_error_${SCENARIO_NAME}.log"

 # Run monitoring script
 set +e
 "${MONITOR_SCRIPT}" > "${MONITOR_OUTPUT}" 2> "${MONITOR_ERROR}"
 local MONITOR_EXIT_CODE="${?}"
 set -e

 # Check if differences were found
 local DIFFERENCES_FOUND=0
 if grep -q "Summary of differences:" "${MONITOR_OUTPUT}"; then
  DIFFERENCES_FOUND=1
 fi

 # Validate results
 if [[ "${EXPECTED_DIFFERENCES}" -eq 1 ]] && [[ "${DIFFERENCES_FOUND}" -eq 1 ]]; then
  __logi "✓ SUCCESS: ${SCENARIO_NAME} - Differences correctly detected"
 elif [[ "${EXPECTED_DIFFERENCES}" -eq 0 ]] && [[ "${DIFFERENCES_FOUND}" -eq 0 ]]; then
  __logi "✓ SUCCESS: ${SCENARIO_NAME} - No differences correctly detected"
 else
  __loge "✗ FAILURE: ${SCENARIO_NAME} - Expected ${EXPECTED_DIFFERENCES} differences, found ${DIFFERENCES_FOUND}"
  __loge "Monitor output:"
  cat "${MONITOR_OUTPUT}"
  __loge "Monitor error:"
  cat "${MONITOR_ERROR}"
 fi

 __log_finish
}

# Cleans up test database.
function __cleanupTestDatabase {
 __log_start
 __logi "Cleaning up test database: ${TEST_DBNAME}"

 # Drop test database
 psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d postgres -c "DROP DATABASE IF EXISTS ${TEST_DBNAME};"

 __log_finish
}

# Runs all test scenarios.
function __runAllTests {
 __log_start
 __logi "Starting monitoring system tests"

 # Test 1: Success scenario (no differences)
 __logi "=== Test 1: Success Scenario ==="
 __setupTestDatabase
 __loadSuccessScenario
 __runMonitoringTest "success_scenario" 0

 # Test 2: Failure scenario (missing data)
 __logi "=== Test 2: Failure Scenario ==="
 __setupTestDatabase
 __loadFailureScenario
 __runMonitoringTest "failure_scenario" 1

 # Cleanup
 __cleanupTestDatabase

 __logi "All monitoring tests completed"
 __log_finish
}

######
# MAIN

function main() {
 __log_start
 __logi "Preparing environment."
 __logd "Output saved at: ${TMP_DIR}."

 if [[ "${PROCESS_TYPE}" == "-h" ]] || [[ "${PROCESS_TYPE}" == "--help" ]]; then
  __show_help
 fi

 __checkPrereqs
 __logw "Starting monitoring tests."

 # Sets the trap in case of any signal.
 # __trapOn

 __runAllTests

 __logw "Monitoring tests finished."
 __log_finish
}

# Allows other users to read the directory.
chmod go+x "${TMP_DIR}"

__start_logger
if [[ ! -t 1 ]]; then
 __set_log_file "${LOG_FILENAME}"
 main >> "${LOG_FILENAME}" 2>&1
 if [[ -n "${CLEAN}" ]] && [[ "${CLEAN}" = true ]]; then
  mv "${LOG_FILENAME}" "/tmp/${BASENAME}_$(date +%Y-%m-%d_%H-%M-%S || true).log"
  rmdir "${TMP_DIR}"
 fi
else
 main
fi
