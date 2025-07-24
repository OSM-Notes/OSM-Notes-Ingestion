#!/bin/bash

# Specific test script for monitoring system to validate different types of problems.
# This script creates specific test scenarios to verify that the monitoring system
# correctly identifies different types of data inconsistencies.
#
# Specific test scenarios:
# 1. Missing notes only
# 2. Missing comments only
# 3. Missing text comments only
# 4. Data corruption (different values)
# 5. Mixed problems (multiple issues)
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
declare -r TEST_DBNAME="notes_test_specific"
declare -r ORIGINAL_DBNAME="${DBNAME}"

# Location of the common functions.
declare -r FUNCTIONS_FILE="${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh"

# Monitoring scripts.
declare -r MONITOR_SCRIPT="${SCRIPT_BASE_DIRECTORY}/bin/monitor/notesCheckVerifier.sh"

###########
# FUNCTIONS

# shellcheck source=../functionsProcess.sh
source "${FUNCTIONS_FILE}"

# Shows the help information.
function __show_help {
 echo "${BASENAME} version ${VERSION}"
 echo "Specific test script for monitoring system to validate different types of problems."
 echo
 echo "Usage:"
 echo "  ${0} [--help|-h]"
 echo
 echo "This script creates specific test scenarios to verify that the monitoring system"
 echo "correctly identifies different types of data inconsistencies."
 echo
 echo "Specific test scenarios:"
 echo "  1. Missing notes only"
 echo "  2. Missing comments only"
 echo "  3. Missing text comments only"
 echo "  4. Data corruption (different values)"
 echo "  5. Mixed problems (multiple issues)"
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
 __checkPrereqs_functions
 __log_finish
 set -e
}

# Creates test database and loads base structure.
function __setupTestDatabase {
 __log_start
 __logi "Setting up test database: ${TEST_DBNAME}"

 # Create test database
 psql -d postgres -c "DROP DATABASE IF EXISTS ${TEST_DBNAME};"
 psql -d postgres -c "CREATE DATABASE ${TEST_DBNAME};"
 # Skip PostGIS extensions for test environment
 # psql -d "${TEST_DBNAME}" -c "CREATE EXTENSION postgis;"
 # psql -d "${TEST_DBNAME}" -c "CREATE EXTENSION btree_gist;"

 # Create base tables structure
 psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_21_createBaseTables_enum.sql"
 psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_22_createBaseTables_tables.sql"
 # Skip PostGIS constraints for test environment
 # psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_23_createBaseTables_constraints.sql"

 # Create check tables
 psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/monitor/processCheckPlanetNotes_21_createCheckTables.sql"

 __log_finish
}

# Test 1: Missing notes only
function __testMissingNotes {
 __log_start
 __logi "=== Test 1: Missing Notes Only ==="

 # Load complete data into check tables (Planet data)
 psql -d "${TEST_DBNAME}" -c "
 INSERT INTO notes_check (note_id, latitude, longitude, created_at, status, id_country) VALUES
 (1001, 40.7128, -74.0060, '2025-01-01 10:00:00', 'open', 1),
 (1002, 34.0522, -118.2437, '2025-01-01 11:00:00', 'close', 1),
 (1003, 51.5074, -0.1278, '2025-01-01 12:00:00', 'open', 2);
 "

 # Load incomplete data into base tables (API data - missing note 1003)
 psql -d "${TEST_DBNAME}" -c "
 INSERT INTO notes (note_id, latitude, longitude, created_at, status, id_country) VALUES
 (1001, 40.7128, -74.0060, '2025-01-01 10:00:00', 'open', 1),
 (1002, 34.0522, -118.2437, '2025-01-01 11:00:00', 'close', 1);
 "

 __runMonitoringTest "missing_notes_only" 1
 __log_finish
}

# Test 2: Missing comments only
function __testMissingComments {
 __log_start
 __logi "=== Test 2: Missing Comments Only ==="

 # Load complete data into check tables (Planet data)
 psql -d "${TEST_DBNAME}" -c "
 INSERT INTO notes_check (note_id, latitude, longitude, created_at, status, id_country) VALUES
 (1001, 40.7128, -74.0060, '2025-01-01 10:00:00', 'open', 1);
 "

 psql -d "${TEST_DBNAME}" -c "
 INSERT INTO note_comments_check (note_id, sequence_action, event, created_at, id_user) VALUES
 (1001, 1, 'opened', '2025-01-01 10:00:00', 12345),
 (1001, 2, 'commented', '2025-01-01 10:30:00', 67890),
 (1001, 3, 'closed', '2025-01-01 11:00:00', 12345);
 "

 # Load incomplete data into base tables (API data - missing comment sequence 2)
 psql -d "${TEST_DBNAME}" -c "
 INSERT INTO notes (note_id, latitude, longitude, created_at, status, id_country) VALUES
 (1001, 40.7128, -74.0060, '2025-01-01 10:00:00', 'open', 1);
 "

 psql -d "${TEST_DBNAME}" -c "
 INSERT INTO note_comments (note_id, sequence_action, event, created_at, id_user) VALUES
 (1001, 1, 'opened', '2025-01-01 10:00:00', 12345),
 (1001, 3, 'closed', '2025-01-01 11:00:00', 12345);
 "

 __runMonitoringTest "missing_comments_only" 1
 __log_finish
}

# Test 3: Missing text comments only
function __testMissingTextComments {
 __log_start
 __logi "=== Test 3: Missing Text Comments Only ==="

 # Load complete data into check tables (Planet data)
 psql -d "${TEST_DBNAME}" -c "
 INSERT INTO notes_check (note_id, latitude, longitude, created_at, status, id_country) VALUES
 (1001, 40.7128, -74.0060, '2025-01-01 10:00:00', 'open', 1);
 "

 psql -d "${TEST_DBNAME}" -c "
 INSERT INTO note_comments_check (note_id, sequence_action, event, created_at, id_user) VALUES
 (1001, 1, 'opened', '2025-01-01 10:00:00', 12345),
 (1001, 2, 'commented', '2025-01-01 10:30:00', 67890);
 "

 psql -d "${TEST_DBNAME}" -c "
 INSERT INTO note_comments_text_check (note_id, sequence_action, body) VALUES
 (1001, 1, 'Note opened for testing'),
 (1001, 2, 'This is a test comment');
 "

 # Load incomplete data into base tables (API data - missing text comment for sequence 2)
 psql -d "${TEST_DBNAME}" -c "
 INSERT INTO notes (note_id, latitude, longitude, created_at, status, id_country) VALUES
 (1001, 40.7128, -74.0060, '2025-01-01 10:00:00', 'open', 1);
 "

 psql -d "${TEST_DBNAME}" -c "
 INSERT INTO note_comments (note_id, sequence_action, event, created_at, id_user) VALUES
 (1001, 1, 'opened', '2025-01-01 10:00:00', 12345),
 (1001, 2, 'commented', '2025-01-01 10:30:00', 67890);
 "

 psql -d "${TEST_DBNAME}" -c "
 INSERT INTO note_comments_text (note_id, sequence_action, body) VALUES
 (1001, 1, 'Note opened for testing');
 -- Missing text comment for sequence 2
 "

 __runMonitoringTest "missing_text_comments_only" 1
 __log_finish
}

# Test 4: Data corruption (different values)
function __testDataCorruption {
 __log_start
 __logi "=== Test 4: Data Corruption (Different Values) ==="

 # Load data into check tables (Planet data)
 psql -d "${TEST_DBNAME}" -c "
 INSERT INTO notes_check (note_id, latitude, longitude, created_at, status, id_country) VALUES
 (1001, 40.7128, -74.0060, '2025-01-01 10:00:00', 'open', 1);
 "

 psql -d "${TEST_DBNAME}" -c "
 INSERT INTO note_comments_check (note_id, sequence_action, event, created_at, id_user) VALUES
 (1001, 1, 'opened', '2025-01-01 10:00:00', 12345);
 "

 psql -d "${TEST_DBNAME}" -c "
 INSERT INTO note_comments_text_check (note_id, sequence_action, body) VALUES
 (1001, 1, 'Note opened for testing');
 "

 # Load corrupted data into base tables (API data - different values)
 psql -d "${TEST_DBNAME}" -c "
 INSERT INTO notes (note_id, latitude, longitude, created_at, status, id_country) VALUES
 (1001, 40.7129, -74.0061, '2025-01-01 10:00:00', 'open', 1);
 -- Different coordinates
 "

 psql -d "${TEST_DBNAME}" -c "
 INSERT INTO note_comments (note_id, sequence_action, event, created_at, id_user) VALUES
 (1001, 1, 'opened', '2025-01-01 10:00:00', 12345);
 "

 psql -d "${TEST_DBNAME}" -c "
 INSERT INTO note_comments_text (note_id, sequence_action, body) VALUES
 (1001, 1, 'Note opened for testing with different text');
 -- Different text content
 "

 __runMonitoringTest "data_corruption" 1
 __log_finish
}

# Test 5: Mixed problems (multiple issues)
function __testMixedProblems {
 __log_start
 __logi "=== Test 5: Mixed Problems (Multiple Issues) ==="

 # Load complete data into check tables (Planet data)
 psql -d "${TEST_DBNAME}" -c "
 INSERT INTO notes_check (note_id, latitude, longitude, created_at, status, id_country) VALUES
 (1001, 40.7128, -74.0060, '2025-01-01 10:00:00', 'open', 1),
 (1002, 34.0522, -118.2437, '2025-01-01 11:00:00', 'close', 1);
 "

 psql -d "${TEST_DBNAME}" -c "
 INSERT INTO note_comments_check (note_id, sequence_action, event, created_at, id_user) VALUES
 (1001, 1, 'opened', '2025-01-01 10:00:00', 12345),
 (1001, 2, 'commented', '2025-01-01 10:30:00', 67890),
 (1002, 1, 'opened', '2025-01-01 11:00:00', 12345);
 "

 psql -d "${TEST_DBNAME}" -c "
 INSERT INTO note_comments_text_check (note_id, sequence_action, body) VALUES
 (1001, 1, 'Note opened for testing'),
 (1001, 2, 'This is a test comment'),
 (1002, 1, 'Another test note');
 "

 # Load incomplete/corrupted data into base tables (API data)
 psql -d "${TEST_DBNAME}" -c "
 INSERT INTO notes (note_id, latitude, longitude, created_at, status, id_country) VALUES
 (1001, 40.7129, -74.0061, '2025-01-01 10:00:00', 'open', 1);
 -- Missing note 1002, different coordinates for 1001
 "

 psql -d "${TEST_DBNAME}" -c "
 INSERT INTO note_comments (note_id, sequence_action, event, created_at, id_user) VALUES
 (1001, 1, 'opened', '2025-01-01 10:00:00', 12345);
 -- Missing comment sequence 2 for note 1001, missing all comments for note 1002
 "

 psql -d "${TEST_DBNAME}" -c "
 INSERT INTO note_comments_text (note_id, sequence_action, body) VALUES
 (1001, 1, 'Note opened for testing with different text');
 -- Missing text comment for sequence 2, different text for sequence 1
 "

 __runMonitoringTest "mixed_problems" 1
 __log_finish
}

# Runs the monitoring script and validates results.
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

 # Extract specific counts if available
 local MISSING_NOTES=0
 local MISSING_COMMENTS=0
 local MISSING_TEXT_COMMENTS=0

 if grep -q "Missing notes:" "${MONITOR_OUTPUT}"; then
  MISSING_NOTES=$(grep "Missing notes:" "${MONITOR_OUTPUT}" | sed 's/.*Missing notes: \([0-9]*\).*/\1/')
 fi
 if grep -q "Missing comments:" "${MONITOR_OUTPUT}"; then
  MISSING_COMMENTS=$(grep "Missing comments:" "${MONITOR_OUTPUT}" | sed 's/.*Missing comments: \([0-9]*\).*/\1/')
 fi
 if grep -q "Missing text comments:" "${MONITOR_OUTPUT}"; then
  MISSING_TEXT_COMMENTS=$(grep "Missing text comments:" "${MONITOR_OUTPUT}" | sed 's/.*Missing text comments: \([0-9]*\).*/\1/')
 fi

 # Validate results
 if [[ "${EXPECTED_DIFFERENCES}" -eq 1 ]] && [[ "${DIFFERENCES_FOUND}" -eq 1 ]]; then
  __logi "✓ SUCCESS: ${SCENARIO_NAME} - Differences correctly detected"
  __logi "  - Missing notes: ${MISSING_NOTES}"
  __logi "  - Missing comments: ${MISSING_COMMENTS}"
  __logi "  - Missing text comments: ${MISSING_TEXT_COMMENTS}"
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
 psql -d postgres -c "DROP DATABASE IF EXISTS ${TEST_DBNAME};"

 __log_finish
}

# Runs all specific test scenarios.
function __runAllSpecificTests {
 __log_start
 __logi "Starting specific monitoring system tests"

 # Test 1: Missing notes only
 __setupTestDatabase
 __testMissingNotes
 __cleanupTestDatabase

 # Test 2: Missing comments only
 __setupTestDatabase
 __testMissingComments
 __cleanupTestDatabase

 # Test 3: Missing text comments only
 __setupTestDatabase
 __testMissingTextComments
 __cleanupTestDatabase

 # Test 4: Data corruption
 __setupTestDatabase
 __testDataCorruption
 __cleanupTestDatabase

 # Test 5: Mixed problems
 __setupTestDatabase
 __testMixedProblems
 __cleanupTestDatabase

 __logi "All specific monitoring tests completed"
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
 __logw "Starting specific monitoring tests."

 # Sets the trap in case of any signal.
 # __trapOn

 __runAllSpecificTests

 __logw "Specific monitoring tests finished."
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
