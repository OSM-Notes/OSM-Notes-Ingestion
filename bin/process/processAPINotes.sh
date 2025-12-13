#!/bin/bash

# Process API Notes - Incremental synchronization from OSM Notes API
# Downloads, processes, and synchronizes new/updated notes from OSM API
#
# For detailed documentation, see:
#   - docs/Process_API.md (complete workflow, architecture, troubleshooting)
#   - docs/Documentation.md (system overview, data flow)
#   - bin/README.md (usage examples, parameters)
#
# Quick Reference:
#   Usage: ./processAPINotes.sh [--help]
#   Examples: export LOG_LEVEL=DEBUG ; ./processAPINotes.sh
#   Monitor: tail -40f $(ls -1rtd /tmp/processAPINotes_* | tail -1)/processAPINotes.log
#
# Error Codes: See docs/Troubleshooting_Guide.md for complete list and solutions
#   1) Help message displayed
#   238) Previous execution failed (see docs/Troubleshooting_Guide.md#failed-execution)
#   241) Library or utility missing
#   242) Invalid argument
#   243) Logger utility is missing
#   245) No last update (run processPlanetNotes.sh --base first)
#   246) Planet process is currently running
#   248) Error executing Planet dump
#
# Failed Execution Mechanism: See docs/Process_API.md#failed-execution
#   - Creates marker file at /tmp/processAPINotes_failed_execution
#   - Sends immediate email alerts (if SEND_ALERT_EMAIL=true)
#   - Prevents subsequent executions until resolved
#
# Configuration (optional environment variables):
#   - ADMIN_EMAIL: Email for alerts (default: root@localhost)
#   - SEND_ALERT_EMAIL: Enable/disable email (default: true)
#   - LOG_LEVEL: Logging level (TRACE, DEBUG, INFO, WARN, ERROR, FATAL)
#
# Dependencies: PostgreSQL, AWK, wget, lib/osm-common/
#
# For contributing: shellcheck -x -o all processAPINotes.sh && shfmt -w -i 1 -sr -bn processAPINotes.sh
#
# Author: Andres Gomez (AngocA)
# Version: 2025-12-13
VERSION="2025-12-13"

#set -xv
# Fails when a variable is not initialized.
set -u
# Fails with a non-zero return code.
set -e
# Fails if the commands of a pipe return non-zero.
set -o pipefail
# Fails if an internal function fails.
set -E

# Auto-restart with setsid if not already in a new session
# This protects against SIGHUP when terminal closes or session ends
if [[ -z "${RUNNING_IN_SETSID:-}" ]] && command -v setsid > /dev/null 2>&1; then
 # Only show message if there's a TTY (not from cron)
 if [[ -t 1 ]]; then
  RESTART_MESSAGE=$(date '+%Y%m%d_%H:%M:%S' || true)
  echo "${RESTART_MESSAGE} INFO: Auto-restarting with setsid for SIGHUP protection" >&2
  unset RESTART_MESSAGE
 fi
 export RUNNING_IN_SETSID=1
 # Get the script name and all arguments
 SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
 # Re-execute with setsid to create new session (immune to SIGHUP)
 exec setsid -w "${SCRIPT_PATH}" "$@"
fi

# Ignore SIGHUP signal (terminal hangup) - belt and suspenders approach
trap '' HUP

# If all generated files should be deleted. In case of an error, this could be
# disabled.
# You can define when calling: export CLEAN=false
# CLEAN is now defined in etc/properties.sh, no need to declare it here

# Logger levels: TRACE, DEBUG, INFO, WARN, ERROR, FATAL.
declare LOG_LEVEL="${LOG_LEVEL:-ERROR}"

# Base directory for the project.
# Only define if not already set (e.g., when sourced from daemon)
if [[ -z "${SCRIPT_BASE_DIRECTORY:-}" ]]; then
 declare SCRIPT_BASE_DIRECTORY
 SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." \
  &> /dev/null && pwd)"
 readonly SCRIPT_BASE_DIRECTORY
fi

# Loads the global properties.
# All database connections must be controlled by the properties file.
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh"

# Mask for the files and directories.
umask 0000

# Only define if not already set (e.g., when sourced from daemon)
if [[ -z "${BASENAME:-}" ]]; then
 declare BASENAME
 BASENAME=$(basename -s .sh "${0}")
 readonly BASENAME
fi

# Set PostgreSQL application name for monitoring
# This allows monitoring tools to identify which script is using the database
export PGAPPNAME="${BASENAME}"

# Temporary directory for all files.
# Only define if not already set (e.g., when sourced from daemon)
if [[ -z "${TMP_DIR:-}" ]]; then
 declare TMP_DIR
 TMP_DIR=$(mktemp -d "/tmp/${BASENAME}_XXXXXX")
 readonly TMP_DIR
 chmod 777 "${TMP_DIR}"
fi

# Log file for output.
# Only define if not already set (e.g., when sourced from daemon)
if [[ -z "${LOG_FILENAME:-}" ]]; then
 declare LOG_FILENAME
 LOG_FILENAME="${TMP_DIR}/${BASENAME}.log"
 readonly LOG_FILENAME
fi

# Lock file for single execution.
# Only define if not already set (e.g., when sourced from daemon)
if [[ -z "${LOCK:-}" ]]; then
 declare LOCK
 LOCK="/tmp/${BASENAME}.lock"
 readonly LOCK
fi

# Original process start time and PID (to preserve in lock file).
# Only define if not already set (e.g., when sourced from daemon)
if [[ -z "${PROCESS_START_TIME:-}" ]]; then
 declare PROCESS_START_TIME
 PROCESS_START_TIME=$(date '+%Y-%m-%d %H:%M:%S')
 readonly PROCESS_START_TIME
fi
if [[ -z "${ORIGINAL_PID:-}" ]]; then
 declare -r ORIGINAL_PID=$$
fi

# Type of process to run in the script.
if [[ -z "${PROCESS_TYPE:-}" ]]; then
 declare -r PROCESS_TYPE=${1:-}
fi

# Total notes count.
declare -i TOTAL_NOTES=-1

# XML Schema of the API notes file.
# (Declared in processAPIFunctions.sh)
# AWK extraction scripts are defined in awk/ directory

# Script to process notes from Planet.
declare -r PROCESS_PLANET_NOTES_SCRIPT="processPlanetNotes.sh"
# Script to synchronize the notes with the Planet.
declare -r NOTES_SYNC_SCRIPT="${SCRIPT_BASE_DIRECTORY}/bin/process/${PROCESS_PLANET_NOTES_SCRIPT}"

# PostgreSQL SQL script files.
# (Declared in processAPIFunctions.sh)

# Temporary file that contains the downloaded notes from the API.
# (Declared in processAPIFunctions.sh)

# Location of the common functions.

# Error codes are already defined in functionsProcess.sh

# Output files for processing
# (Declared in processAPIFunctions.sh)
# FAILED_EXECUTION_FILE is already defined in functionsProcess.sh

# Control variables for functionsProcess.sh
export GENERATE_FAILED_FILE=true
export ONLY_EXECUTION="no"

###########
# FUNCTIONS

# Load common functions
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/commonFunctions.sh"

# Load API-specific functions
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/bin/lib/processAPIFunctions.sh"

# Load validation functions
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/validationFunctions.sh"

# Load error handling functions
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/errorHandlingFunctions.sh"

# Load alert functions for failed execution notifications
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/alertFunctions.sh"

# Load process functions (includes PostgreSQL variables)
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh"

# Shows the help information.
function __show_help {
 echo "${0} version ${VERSION}."
 echo
 echo "This script downloads the OSM notes from the OpenStreetMap API."
 echo "It requests the most recent ones and synchronizes them on a local"
 echo "database that holds the whole notes history."
 echo
 echo "It does not receive any parameter for regular execution. The only"
 echo "parameter allowed is to invoke the help message (-h|--help)."
 echo "This script should be configured in a crontab or similar scheduler."
 echo
 echo "Instead, it could be parametrized with the following environment"
 echo "variables."
 echo "* CLEAN={true|false/empty}: Deletes all generated files."
 echo "* LOG_LEVEL={TRACE|DEBUG|INFO|WARN|ERROR|FATAL}: Configures the"
 echo "  logger level."
 echo
 echo "This script could call processPlanetNotes.sh which use another"
 echo "environment variables. Please check the documentation of that script."
 echo
 echo "Written by: Andres Gomez (AngocA)."
 echo "OSM-LatAm, OSM-Colombia, MaptimeBogota."
 exit "${ERROR_HELP_MESSAGE}"
}

# Local wrapper for __common_create_failed_marker from alertFunctions.sh
# This adds the script-specific parameters (script name and failed file path)
# to the common alert function.
#
# Parameters:
#   $1 - error_code: The error code that triggered the failure
#   $2 - error_message: Description of what failed
#   $3 - required_action: (Optional) What action is needed to fix it
#
# Note: This wrapper allows existing code to continue using the simple 3-parameter
# interface while calling the common 5-parameter function in alertFunctions.sh
function __create_failed_marker() {
 # Call the common alert function with script-specific parameters
 # Format: script_name, error_code, error_message, required_action, failed_file
 __common_create_failed_marker "processAPINotes" "${1}" "${2}" \
  "${3:-Verify the issue and fix it manually}" "${FAILED_EXECUTION_FILE}"
}

# Checks prerequisites to run the script.
function __checkPrereqs {
 __log_start
 __logi "=== STARTING PREREQUISITES CHECK ==="
 __logd "Checking process type."
 if [[ "${PROCESS_TYPE}" != "" ]] && [[ "${PROCESS_TYPE}" != "--help" ]] \
  && [[ "${PROCESS_TYPE}" != "-h" ]]; then
  echo "ERROR: Invalid parameter. It should be:"
  echo " * Empty string (nothing)."
  echo " * --help"
  __loge "ERROR: Invalid parameter."
  exit "${ERROR_INVALID_ARGUMENT}"
 fi
 set +e
 # Checks prereqs.
 __checkPrereqsCommands

 # Function to detect and recover from data gaps
 __recover_from_gaps() {
  # shellcheck disable=SC2034
  local -r FUNCTION_NAME="__recover_from_gaps"
  __logd "Starting gap recovery process"

  # Check if max_note_timestamp table exists
  local CHECK_TABLE_QUERY="
   SELECT COUNT(*) FROM information_schema.tables
   WHERE table_schema = 'public' AND table_name = 'max_note_timestamp'
 "

  local TEMP_CHECK_FILE
  TEMP_CHECK_FILE=$(mktemp)

  if ! __retry_database_operation "${CHECK_TABLE_QUERY}" "${TEMP_CHECK_FILE}" 3 2; then
   __logw "Failed to check if max_note_timestamp table exists"
   rm -f "${TEMP_CHECK_FILE}"
   __logd "Skipping gap recovery check - table may not exist yet"
   return 0
  fi

  # Read from file and convert to integer directly
  local TABLE_COUNT=0
  if [[ -f "${TEMP_CHECK_FILE:-}" ]] && [[ -s "${TEMP_CHECK_FILE:-}" ]]; then
   # Extract only numeric value from file (psql may include connection messages)
   # Use grep to extract digits only, or take the last line which should be the count
   local FILE_CONTENT
   FILE_CONTENT=$(grep -E '^[0-9]+$' "${TEMP_CHECK_FILE}" 2> /dev/null | tail -1 || echo "0")
   # Temporarily disable set -u for arithmetic expansion to avoid issues
   set +u
   # Convert to integer - FILE_CONTENT is guaranteed to have a value
   TABLE_COUNT=$((${FILE_CONTENT:-0} + 0)) || TABLE_COUNT=0
   set -u
  fi
  rm -f "${TEMP_CHECK_FILE:-}"

  # Use numeric comparison
  if [[ ${TABLE_COUNT} -eq 0 ]]; then
   __logd "max_note_timestamp table does not exist, skipping gap recovery"
   return 0
  fi

  # Check for notes without comments in recent data
  local GAP_QUERY="
   SELECT COUNT(DISTINCT n.note_id) as gap_count
   FROM notes n
   LEFT JOIN note_comments nc ON nc.note_id = n.note_id
   WHERE n.created_at > (
     SELECT timestamp FROM max_note_timestamp
   ) - INTERVAL '7 days'
   AND nc.note_id IS NULL
 "

  local TEMP_GAP_FILE
  TEMP_GAP_FILE=$(mktemp)

  if ! __retry_database_operation "${GAP_QUERY}" "${TEMP_GAP_FILE}" 3 2; then
   __loge "Failed to execute gap query after retries"
   rm -f "${TEMP_GAP_FILE}"
   return 1
  fi

  # Read from file and convert to integer directly
  local GAP_COUNT=0
  if [[ -f "${TEMP_GAP_FILE:-}" ]] && [[ -s "${TEMP_GAP_FILE:-}" ]]; then
   # Extract only numeric value from file (psql may include connection messages)
   # Use grep to extract digits only, or take the last line which should be the count
   local GAP_CONTENT
   GAP_CONTENT=$(grep -E '^[0-9]+$' "${TEMP_GAP_FILE}" 2> /dev/null | tail -1 || echo "0")
   # Temporarily disable set -u for arithmetic expansion to avoid issues
   set +u
   # Convert to integer - GAP_CONTENT is guaranteed to have a value
   GAP_COUNT=$((${GAP_CONTENT:-0} + 0)) || GAP_COUNT=0
   set -u
  fi
  rm -f "${TEMP_GAP_FILE:-}"

  # Use numeric comparison
  if [[ ${GAP_COUNT} -gt 0 ]]; then
   __logw "Detected ${GAP_COUNT} notes without comments in last 7 days"
   __logw "This indicates a potential data integrity issue"

   # Log detailed gap information
   local GAP_DETAILS_QUERY="
      SELECT n.note_id, n.created_at, n.status
      FROM notes n
      LEFT JOIN note_comments nc ON nc.note_id = n.note_id
      WHERE n.created_at > (
        SELECT timestamp FROM max_note_timestamp
      ) - INTERVAL '7 days'
      AND nc.note_id IS NULL
      ORDER BY n.created_at DESC
      LIMIT 10
    "

   __logw "Sample of notes with gaps:"
   PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -Atq -c "${GAP_DETAILS_QUERY}" | while IFS= read -r line; do
    __logw "  ${line}"
   done

   # Optionally trigger a recovery process
   if [[ ${GAP_COUNT} -lt 100 ]]; then
    __logi "Gap count is manageable (${GAP_COUNT}), continuing with normal processing"
   else
    __loge "Large gap detected (${GAP_COUNT} notes), consider manual intervention"
    return 1
   fi
  else
   __logd "No gaps detected in recent data"
  fi

  return 0
 }

 ## Validate required files using centralized validation
 __logi "Validating required files..."

 # Validate sync script
 if ! __validate_input_file "${NOTES_SYNC_SCRIPT}" "Notes sync script"; then
  __loge "ERROR: Notes sync script validation failed: ${NOTES_SYNC_SCRIPT}"
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 ## Validate SQL script files using centralized validation
 __logi "Validating SQL script files..."

 # Create array of SQL files to validate
 local SQL_FILES=(
  "${POSTGRES_12_DROP_API_TABLES}"
  "${POSTGRES_21_CREATE_API_TABLES}"
  "${POSTGRES_23_CREATE_PROPERTIES_TABLE}"
  "${POSTGRES_31_LOAD_API_NOTES}"
  "${POSTGRES_32_INSERT_NEW_NOTES_AND_COMMENTS}"
  "${POSTGRES_33_INSERT_NEW_TEXT_COMMENTS}"
  "${POSTGRES_34_UPDATE_LAST_VALUES}"
 )

 # Validate each SQL file
 for SQL_FILE in "${SQL_FILES[@]}"; do
  if ! __validate_sql_structure "${SQL_FILE}"; then
   __loge "ERROR: SQL file validation failed: ${SQL_FILE}"
   exit "${ERROR_MISSING_LIBRARY}"
  fi
 done

 # Validate dates in API notes file if it exists (only if validation is enabled)
 if [[ "${SKIP_XML_VALIDATION}" != "true" ]]; then
  __logi "Validating dates in API notes file..."
  if [[ -f "${API_NOTES_FILE}" ]]; then
   if ! __validate_xml_dates "${API_NOTES_FILE}"; then
    __loge "ERROR: XML date validation failed: ${API_NOTES_FILE}"
    exit "${ERROR_MISSING_LIBRARY}"
   fi
  fi
 else
  __logw "Skipping date validation (SKIP_XML_VALIDATION=true)"
 fi

 # CSV files are generated during processing, no need to validate them here

 __checkPrereqs_functions
 __logi "=== PREREQUISITES CHECK COMPLETED SUCCESSFULLY ==="
 set -e
 __log_finish
}

# Drop tables for notes from API.
function __dropApiTables {
 __log_start
 __logi "=== DROPPING API TABLES ==="
 __logd "Executing SQL file: ${POSTGRES_12_DROP_API_TABLES}"
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -f "${POSTGRES_12_DROP_API_TABLES}"
 __logi "=== API TABLES DROPPED SUCCESSFULLY ==="
 __log_finish
}

# Checks that no processPlanetNotes is running
function __checkNoProcessPlanet {
 __log_start
 __logi "=== CHECKING FOR RUNNING PLANET PROCESSES ==="
 local QTY
 set +e
 QTY="$(pgrep "${PROCESS_PLANET_NOTES_SCRIPT:0:15}" | wc -l)"
 set -e
 __logd "Found ${QTY} running planet processes"
 if [[ "${QTY}" -ne "0" ]]; then
  __loge "${BASENAME} is currently running."
  __logw "It is better to wait for it to finish."
  exit "${ERROR_PLANET_PROCESS_IS_RUNNING}"
 fi
 __logi "=== NO CONFLICTING PROCESSES FOUND ==="
 __log_finish
}

# Creates tables for notes from API.
function __createApiTables {
 __log_start
 __logi "=== CREATING API TABLES ==="
 __logd "Executing SQL file: ${POSTGRES_21_CREATE_API_TABLES}"
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_21_CREATE_API_TABLES}"
 __logi "=== API TABLES CREATED SUCCESSFULLY ==="
 __log_finish
}

# Creates table properties during the execution.
function __createPropertiesTable {
 __log_start
 __logi "=== CREATING PROPERTIES TABLE ==="
 __logd "Executing SQL file: ${POSTGRES_23_CREATE_PROPERTIES_TABLE}"
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_23_CREATE_PROPERTIES_TABLE}"
 __logi "=== PROPERTIES TABLE CREATED SUCCESSFULLY ==="
 __log_finish
}

# Ensures get_country function exists before creating procedures.
# The procedures (insert_note, insert_note_comment) require get_country to exist.
# This function checks if get_country exists and creates it if missing.
# If get_country exists but countries table does not, recreates the function as stub.
function __ensureGetCountryFunction {
 __log_start
 __logd "Checking if get_country function exists..."

 local FUNCTION_EXISTS
 FUNCTION_EXISTS=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM pg_proc WHERE proname = 'get_country' AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');" 2> /dev/null | grep -E '^[0-9]+$' | tail -1 || echo "0")
 local COUNTRIES_TABLE_EXISTS
 COUNTRIES_TABLE_EXISTS=$(psql -d "${DBNAME}" -Atq -c "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'countries');" 2> /dev/null | grep -E '^[tf]$' | tail -1 || echo "f")

 if [[ "${FUNCTION_EXISTS}" -eq "0" ]]; then
  __logw "get_country function not found, creating it..."
  __createFunctionToGetCountry
 else
  __logd "get_country function already exists"
  if [[ "${COUNTRIES_TABLE_EXISTS}" != "t" ]]; then
   __logw "WARNING: get_country function exists but countries table does not"
   __createFunctionToGetCountry
  fi
 fi
 __log_finish
}


# Validates API notes XML file completely (structure, dates, coordinates)
# Parameters:
#   None (uses global API_NOTES_FILE variable)
# Returns:
#   0 if all validations pass, exits with ERROR_DATA_VALIDATION if any validation fails
function __validateApiNotesXMLFileComplete {
 __log_start
 __logi "=== COMPLETE API NOTES XML VALIDATION ==="

 # Check if file exists
 if [[ ! -f "${API_NOTES_FILE}" ]]; then
  __loge "ERROR: API notes file not found: ${API_NOTES_FILE}"
  __create_failed_marker "${ERROR_DATA_VALIDATION}" \
   "API notes file not found after download" \
   "Check network connectivity and API availability. File expected at: ${API_NOTES_FILE}"
  exit "${ERROR_DATA_VALIDATION}"
 fi

 # Validate XML structure against schema with enhanced error handling
 __logi "Validating XML structure against schema..."
 if ! __validate_xml_with_enhanced_error_handling "${API_NOTES_FILE}" "${XMLSCHEMA_API_NOTES}"; then
  __loge "ERROR: XML structure validation failed: ${API_NOTES_FILE}"
  __create_failed_marker "${ERROR_DATA_VALIDATION}" \
   "XML structure validation failed - downloaded file does not match schema" \
   "Check if OSM API has changed. Verify file: ${API_NOTES_FILE} against schema: ${XMLSCHEMA_API_NOTES}"
  exit "${ERROR_DATA_VALIDATION}"
 fi

 # Validate dates in XML file
 __logi "Validating dates in XML file..."
 if ! __validate_xml_dates "${API_NOTES_FILE}"; then
  __loge "ERROR: XML date validation failed: ${API_NOTES_FILE}"
  __create_failed_marker "${ERROR_DATA_VALIDATION}" \
   "XML date validation failed - dates are not in expected format or invalid" \
   "Check dates in file: ${API_NOTES_FILE}. May indicate API data corruption or format change."
  exit "${ERROR_DATA_VALIDATION}"
 fi

 # Validate coordinates in XML file
 __logi "Validating coordinates in XML file..."
 if ! __validate_xml_coordinates "${API_NOTES_FILE}"; then
  __loge "ERROR: XML coordinate validation failed: ${API_NOTES_FILE}"
  __create_failed_marker "${ERROR_DATA_VALIDATION}" \
   "XML coordinate validation failed - coordinates are outside valid ranges" \
   "Check coordinates in file: ${API_NOTES_FILE}. May indicate API data corruption."
  exit "${ERROR_DATA_VALIDATION}"
 fi

 __logi "All API notes XML validations passed successfully"
 __log_finish
}

# Processes XML files with AWK extraction.
# The CSV file structure for notes is:
# 3451247,29.6141093,-98.4844977,"2022-11-22 02:13:03 UTC",,"open"
# 3451210,39.7353700,-104.9626400,"2022-11-22 01:30:39 UTC","2022-11-22 02:09:32 UTC","close"
#
# The CSV file structure for comments is:
# 3450803,'opened','2022-11-21 17:13:10 UTC',17750622,'Juanmiguelrizogonzalez'
# 3450803,'closed','2022-11-22 02:06:53 UTC',15422751,'GHOSTsama2503'
# 3450803,'reopened','2022-11-22 02:06:58 UTC',15422751,'GHOSTsama2503'
# 3450803,'commented','2022-11-22 02:07:24 UTC',15422751,'GHOSTsama2503'
#
# The CSV file structure for text comment is:
# 3450803,'Iglesia pentecostal Monte de Sion aquí es donde está realmente'
# 3450803,'Existe otra iglesia sin nombre cercana a la posición de la nota, ¿es posible que se trate de un error, o hay una al lado de la otra?'
# 3451247,'If you are in the area, could you please survey a more exact location for Nothing Bundt Cakes and move the node to that location? Thanks!'

# Checks if the quantity of notes requires synchronization with Planet
function __processXMLorPlanet {
 __log_start

 if [[ "${TOTAL_NOTES}" -ge "${MAX_NOTES}" ]]; then
  __logw "Starting full synchronization from Planet."
  __logi "This could take several minutes."
  "${NOTES_SYNC_SCRIPT}"
  __logw "Finished full synchronization from Planet."
 else
  # Check if there are notes to process
  if [[ "${TOTAL_NOTES}" -gt 0 ]]; then
   __logi "Processing ${TOTAL_NOTES} notes sequentially"
   __processApiXmlSequential "${API_NOTES_FILE}"
  else
   __logi "No notes found in XML file, skipping processing."
  fi
 fi

 __log_finish
}

# Processes API XML file sequentially for small datasets
# Parameters:
#   $1: XML file path
function __processApiXmlSequential {
 __log_start
 __logi "=== PROCESSING API XML SEQUENTIALLY ==="

 local XML_FILE="${1}"
 local SEQ_OUTPUT_NOTES_FILE="${TMP_DIR}/output-notes-sequential.csv"
 local SEQ_OUTPUT_COMMENTS_FILE="${TMP_DIR}/output-comments-sequential.csv"
 local SEQ_OUTPUT_TEXT_FILE="${TMP_DIR}/output-text-sequential.csv"

 # Process notes with AWK (fast and dependency-free)
 __logd "Processing notes with AWK: ${XML_FILE} -> ${SEQ_OUTPUT_NOTES_FILE}"
 awk -f "${SCRIPT_BASE_DIRECTORY}/awk/extract_notes.awk" "${XML_FILE}" > "${SEQ_OUTPUT_NOTES_FILE}"
 if [[ ! -f "${SEQ_OUTPUT_NOTES_FILE}" ]]; then
  __loge "Notes CSV file was not created: ${SEQ_OUTPUT_NOTES_FILE}"
  __log_finish
  return 1
 fi

 # Process comments with AWK (fast and dependency-free)
 __logd "Processing comments with AWK: ${XML_FILE} -> ${SEQ_OUTPUT_COMMENTS_FILE}"
 awk -f "${SCRIPT_BASE_DIRECTORY}/awk/extract_comments.awk" "${XML_FILE}" > "${SEQ_OUTPUT_COMMENTS_FILE}"
 if [[ ! -f "${SEQ_OUTPUT_COMMENTS_FILE}" ]]; then
  __loge "Comments CSV file was not created: ${SEQ_OUTPUT_COMMENTS_FILE}"
  __log_finish
  return 1
 fi

 # Process text comments with AWK (fast and dependency-free)
 __logd "Processing text comments with AWK: ${XML_FILE} -> ${SEQ_OUTPUT_TEXT_FILE}"
 awk -f "${SCRIPT_BASE_DIRECTORY}/awk/extract_comment_texts.awk" "${XML_FILE}" > "${SEQ_OUTPUT_TEXT_FILE}"
 if [[ ! -f "${SEQ_OUTPUT_TEXT_FILE}" ]]; then
  __logw "Text comments CSV file was not created, generating empty file to continue: ${SEQ_OUTPUT_TEXT_FILE}"
  : > "${SEQ_OUTPUT_TEXT_FILE}"
 fi

 # Debug: Show generated CSV files and their sizes
 __logd "Generated CSV files:"
 __logd "  Notes: ${SEQ_OUTPUT_NOTES_FILE} ($(wc -l < "${SEQ_OUTPUT_NOTES_FILE}" || echo 0) lines)" || true
 __logd "  Comments: ${SEQ_OUTPUT_COMMENTS_FILE} ($(wc -l < "${SEQ_OUTPUT_COMMENTS_FILE}" || echo 0) lines)" || true
 __logd "  Text: ${SEQ_OUTPUT_TEXT_FILE} ($(wc -l < "${SEQ_OUTPUT_TEXT_FILE}" || echo 0) lines)" || true

 # Validate CSV files structure and content before loading (optional)
 if [[ "${SKIP_CSV_VALIDATION:-true}" != "true" ]]; then
  __logd "Validating CSV files structure and enum compatibility..."

  # Validate notes
  if ! __validate_csv_structure "${SEQ_OUTPUT_NOTES_FILE}" "notes"; then
   __loge "ERROR: Notes CSV structure validation failed"
   __log_finish
   return 1
  fi

  if ! __validate_csv_for_enum_compatibility "${SEQ_OUTPUT_NOTES_FILE}" "notes"; then
   __loge "ERROR: Notes CSV enum validation failed"
   __log_finish
   return 1
  fi

  # Validate comments
  if ! __validate_csv_structure "${SEQ_OUTPUT_COMMENTS_FILE}" "comments"; then
   __loge "ERROR: Comments CSV structure validation failed"
   __log_finish
   return 1
  fi

  if ! __validate_csv_for_enum_compatibility "${SEQ_OUTPUT_COMMENTS_FILE}" "comments"; then
   __loge "ERROR: Comments CSV enum validation failed"
   __log_finish
   return 1
  fi

  # Validate text
  if ! __validate_csv_structure "${SEQ_OUTPUT_TEXT_FILE}" "text"; then
   __loge "ERROR: Text CSV structure validation failed"
   __log_finish
   return 1
  fi
 else
  __logw "WARNING: CSV validation SKIPPED (SKIP_CSV_VALIDATION=true)"
 fi

 __logi "✓ All CSV validations passed for sequential processing"

 __logi "=== LOADING SEQUENTIAL DATA INTO DATABASE ==="
 __logd "Database: ${DBNAME}"

 # Load into database
 __logd "Removing part_id column from CSV files for API (last column with trailing comma)"
 local SEQ_OUTPUT_NOTES_CLEANED="${SEQ_OUTPUT_NOTES_FILE}.cleaned"
 local SEQ_OUTPUT_COMMENTS_CLEANED="${SEQ_OUTPUT_COMMENTS_FILE}.cleaned"
 local SEQ_OUTPUT_TEXT_CLEANED="${SEQ_OUTPUT_TEXT_FILE}.cleaned"
 # Remove last column (part_id) from each CSV
 sed 's/,$//' "${SEQ_OUTPUT_NOTES_FILE}" > "${SEQ_OUTPUT_NOTES_CLEANED}"
 sed 's/,$//' "${SEQ_OUTPUT_COMMENTS_FILE}" > "${SEQ_OUTPUT_COMMENTS_CLEANED}"
 sed 's/,$//' "${SEQ_OUTPUT_TEXT_FILE}" > "${SEQ_OUTPUT_TEXT_CLEANED}"
 # Create temporary SQL file with variables substituted
 local TEMP_SQL
 TEMP_SQL=$(mktemp)
 # Replace variables in SQL file using sed (point to cleaned files)
 sed "s|\${OUTPUT_NOTES_PART}|${SEQ_OUTPUT_NOTES_CLEANED}|g; \
      s|\${OUTPUT_COMMENTS_PART}|${SEQ_OUTPUT_COMMENTS_CLEANED}|g; \
      s|\${OUTPUT_TEXT_PART}|${SEQ_OUTPUT_TEXT_CLEANED}|g" \
  < "${POSTGRES_31_LOAD_API_NOTES}" > "${TEMP_SQL}" || true
 # Execute SQL file
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${TEMP_SQL}"
 # Clean up temp files
 rm -f "${TEMP_SQL}" "${SEQ_OUTPUT_NOTES_CLEANED}" "${SEQ_OUTPUT_COMMENTS_CLEANED}" "${SEQ_OUTPUT_TEXT_CLEANED}"

 __logi "=== SEQUENTIAL API XML PROCESSING COMPLETED SUCCESSFULLY ==="
 __log_finish
}

# Inserts new notes and comments into the database
function __insertNewNotesAndComments {
 __log_start

 # Generate unique process ID with timestamp to avoid conflicts
 local PROCESS_ID
 PROCESS_ID="${$}_$(date +%s)_${RANDOM}"

 # Set lock with retry logic and better error handling
 local LOCK_RETRY_COUNT=0
 local LOCK_MAX_RETRIES=3
 local LOCK_RETRY_DELAY=2

 while [[ ${LOCK_RETRY_COUNT} -lt ${LOCK_MAX_RETRIES} ]]; do
  if echo "CALL put_lock('${PROCESS_ID}'::VARCHAR)" | PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1; then
   __logd "Lock acquired successfully: ${PROCESS_ID}"
   break
  else
   LOCK_RETRY_COUNT=$((LOCK_RETRY_COUNT + 1))
   __logw "Lock acquisition failed, attempt ${LOCK_RETRY_COUNT}/${LOCK_MAX_RETRIES}"

   if [[ ${LOCK_RETRY_COUNT} -lt ${LOCK_MAX_RETRIES} ]]; then
    sleep "${LOCK_RETRY_DELAY}"
   fi
  fi
 done

 if [[ ${LOCK_RETRY_COUNT} -eq ${LOCK_MAX_RETRIES} ]]; then
  __loge "Failed to acquire lock after ${LOCK_MAX_RETRIES} attempts"
  __log_finish
  return 1
 fi

 export PROCESS_ID
 local PROCESS_ID_INTEGER
 PROCESS_ID_INTEGER=$$

 # Prepare SQL file with process_id substitution
 local TEMP_SQL_FILE
 TEMP_SQL_FILE=$(mktemp)
 local SQL_CMD
 SQL_CMD=$(envsubst "\$PROCESS_ID" < "${POSTGRES_32_INSERT_NEW_NOTES_AND_COMMENTS}" || true)

 # Create SQL file with SET command and main SQL
 # Include updateLastValues in the same connection to preserve app.integrity_check_passed
 # This ensures the variable set in insertNewNotesAndComments is available in updateLastValues
 cat > "${TEMP_SQL_FILE}" << EOF
SET app.process_id = '${PROCESS_ID_INTEGER}';
${SQL_CMD}
EOF

 # Append updateLastValues SQL to the same file
 cat "${POSTGRES_34_UPDATE_LAST_VALUES}" >> "${TEMP_SQL_FILE}"

 # Execute insertion and timestamp update in the same connection
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${TEMP_SQL_FILE}"

 rm -f "${TEMP_SQL_FILE}"

 # Remove lock on success
 if ! echo "CALL remove_lock('${PROCESS_ID}'::VARCHAR)" | PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1; then
  __loge "Failed to remove lock"
  __log_finish
  return 1
 fi

 __log_finish
 return 0
}

# Inserts the new text comments.
function __loadApiTextComments {
 __log_start
 export OUTPUT_TEXT_COMMENTS_FILE
 local SQL_CMD
 SQL_CMD=$(envsubst "\$OUTPUT_TEXT_COMMENTS_FILE" \
  < "${POSTGRES_33_INSERT_NEW_TEXT_COMMENTS}" || true)
 # shellcheck disable=SC2016
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -c "${SQL_CMD}"
 __log_finish
}


# Updates the refreshed value.
function __updateLastValue {
 __log_start
 __logi "Updating last update time."
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_34_UPDATE_LAST_VALUES}"
 __log_finish
}

# Clean files generated during the process.
function __cleanNotesFiles {
 __log_start
 if [[ -n "${CLEAN:-}" ]] && [[ "${CLEAN}" = true ]]; then
  rm -f "${API_NOTES_FILE}" "${OUTPUT_NOTES_FILE}" \
   "${OUTPUT_NOTE_COMMENTS_FILE}" "${OUTPUT_TEXT_COMMENTS_FILE}"
 fi
 __log_finish
}

# Validates that the API notes file was downloaded successfully.
# Checks file existence and non-empty content.
# Exits with error if validation fails.
function __validateApiNotesFile {
 __log_start
 __logd "Validating API notes file: ${API_NOTES_FILE}"

 if [[ ! -f "${API_NOTES_FILE}" ]]; then
  __loge "ERROR: API notes file was not downloaded: ${API_NOTES_FILE}"
  __create_failed_marker "${ERROR_INTERNET_ISSUE}" \
   "API notes file was not downloaded" \
   "This may be temporary. Check network connectivity and OSM API status. If temporary, delete this file and retry: ${FAILED_EXECUTION_FILE}. Expected file: ${API_NOTES_FILE}"
  exit "${ERROR_INTERNET_ISSUE}"
 fi

 if [[ ! -s "${API_NOTES_FILE}" ]]; then
  __loge "ERROR: API notes file is empty: ${API_NOTES_FILE}"
  __create_failed_marker "${ERROR_INTERNET_ISSUE}" \
   "API notes file is empty - no data received from OSM API" \
   "This may indicate API issues or no new notes. Check OSM API status. If temporary, delete this file and retry: ${FAILED_EXECUTION_FILE}. File: ${API_NOTES_FILE}"
  exit "${ERROR_INTERNET_ISSUE}"
 fi

 __logi "API notes file downloaded successfully: ${API_NOTES_FILE}"
 __log_finish
}

# Validates and processes the API notes XML file.
# Performs XML validation (if enabled), counts notes, and processes them.
function __validateAndProcessApiXml {
 __log_start
 declare -i RESULT
 RESULT=$(wc -l < "${API_NOTES_FILE}")
 if [[ "${RESULT}" -ne 0 ]]; then
  if [[ "${SKIP_XML_VALIDATION}" != "true" ]]; then
   __validateApiNotesXMLFileComplete
  else
   __logw "WARNING: XML validation SKIPPED (SKIP_XML_VALIDATION=true)"
  fi
  __countXmlNotesAPI "${API_NOTES_FILE}"
  __processXMLorPlanet
  __insertNewNotesAndComments
  __loadApiTextComments
 fi
 __log_finish
}

# Sets up the lock file for single execution.
# Creates lock file descriptor and writes lock file content.
function __setupLockFile {
 __log_start
 __logw "Validating single execution."
 exec 8> "${LOCK}"
 ONLY_EXECUTION="no"
 if ! flock -n 8; then
  __loge "Another instance of ${BASENAME} is already running."
  __loge "Lock file: ${LOCK}"
  if [[ -f "${LOCK}" ]]; then
   __loge "Lock file contents:"
   cat "${LOCK}" >&2 || true
  fi
  exit 1
 fi
 ONLY_EXECUTION="yes"

 cat > "${LOCK}" << EOF
PID: ${ORIGINAL_PID}
Process: ${BASENAME}
Started: ${PROCESS_START_TIME}
Temporary directory: ${TMP_DIR}
Process type: ${PROCESS_TYPE}
Main script: ${0}
EOF
 __logd "Lock file content written to: ${LOCK}"
 __log_finish
}

# Validates historical data and recovers from gaps if needed.
# Called when base tables exist (RET_FUNC == 0).
function __validateHistoricalDataAndRecover {
 __log_start
 __logi "Base tables found. Validating historical data..."
 __checkHistoricalData
 if [[ "${RET_FUNC}" -ne 0 ]]; then
  __create_failed_marker "${ERROR_EXECUTING_PLANET_DUMP}" \
   "Historical data validation failed - base tables exist but contain no historical data" \
   "Run processPlanetNotes.sh to load historical data: ${SCRIPT_BASE_DIRECTORY}/bin/process/processPlanetNotes.sh"
  exit "${ERROR_EXECUTING_PLANET_DUMP}"
 fi
 __logi "Historical data validation passed. ProcessAPI can continue safely."

 if ! __recover_from_gaps; then
  __loge "Gap recovery check failed, aborting processing"
  __handle_error_with_cleanup "${ERROR_GENERAL}" "Gap recovery failed" \
   "echo 'Gap recovery failed - manual intervention may be required'"
 fi
 __log_finish
}

# Creates base structure by executing processPlanetNotes.sh --base.
# Verifies geographic data was loaded and re-acquires lock after completion.
#
# Note: This function temporarily releases the lock file to allow child processes
# (processPlanetNotes.sh) to run. After completion, it re-acquires the lock
# and updates the lock file content. This is intentional behavior to prevent
# lock conflicts with child processes. The lock file modification timestamp
# will change when re-acquired, which is expected and normal.
function __createBaseStructure {
 __log_start
 __logd "Releasing lock before spawning child processes"
 exec 8>&-

 __logi "Step 1/2: Creating base database structure and loading historical data..."
 if ! "${NOTES_SYNC_SCRIPT}" --base; then
  __loge "ERROR: Failed to create base structure. Stopping process."
  __create_failed_marker "${ERROR_EXECUTING_PLANET_DUMP}" \
   "Failed to create base database structure and load historical data (Step 1/2)" \
   "Check database permissions and disk space. Verify processPlanetNotes.sh can run with --base flag. Script: ${NOTES_SYNC_SCRIPT}"
  exit "${ERROR_EXECUTING_PLANET_DUMP}"
 fi
 __logw "Base structure created successfully."

 __logi "Step 2/2: Verifying geographic data (countries and maritimes)..."
 local COUNTRIES_COUNT
 COUNTRIES_COUNT=$(PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM countries;" 2> /dev/null | grep -E '^[0-9]+$' | tail -1 || echo "0")

 if [[ "${COUNTRIES_COUNT:-0}" -eq 0 ]]; then
  __logw "No geographic data found after processPlanetNotes.sh --base"
  __logw "processPlanetNotes.sh should have loaded countries automatically via __processGeographicData()"

  local UPDATE_COUNTRIES_LOCK="/tmp/updateCountries.lock"
  if [[ -f "${UPDATE_COUNTRIES_LOCK}" ]]; then
   local LOCK_PID
   LOCK_PID=$(grep "^PID:" "${UPDATE_COUNTRIES_LOCK}" 2> /dev/null | awk '{print $2}' || echo "")
   if [[ -n "${LOCK_PID}" ]] && ps -p "${LOCK_PID}" > /dev/null 2>&1; then
    __loge "updateCountries.sh is still running (PID: ${LOCK_PID}). Cannot proceed with base setup."
    __loge "This script runs every 15 minutes and will retry automatically."
    __loge "Current execution will exit. Next execution will check again."
    exit "${ERROR_EXECUTING_PLANET_DUMP}"
   else
    __logw "Stale lock file found. Removing it."
    rm -f "${UPDATE_COUNTRIES_LOCK}"
   fi
  fi

  COUNTRIES_COUNT=$(PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM countries;" 2> /dev/null | grep -E '^[0-9]+$' | tail -1 || echo "0")
  if [[ "${COUNTRIES_COUNT:-0}" -eq 0 ]]; then
   __loge "ERROR: Geographic data not loaded after processPlanetNotes.sh --base"
   __loge "processPlanetNotes.sh should have loaded countries automatically via __processGeographicData()"
   __loge "Check processPlanetNotes.sh logs for errors in updateCountries.sh execution"
   __create_failed_marker "${ERROR_EXECUTING_PLANET_DUMP}" \
    "Geographic data not loaded after processPlanetNotes.sh --base (Step 2/2)" \
    "Check processPlanetNotes.sh logs. It should have called updateCountries.sh automatically via __processGeographicData(). If needed, run manually: ${SCRIPT_BASE_DIRECTORY}/bin/process/updateCountries.sh --base"
   exit "${ERROR_EXECUTING_PLANET_DUMP}"
  fi
 else
  __logi "Geographic data verified (${COUNTRIES_COUNT} countries/maritimes found)"
 fi

 __logw "Complete setup finished successfully."
 __logi "System is now ready for regular API processing."
 __logi "Historical data was loaded by processPlanetNotes.sh --base in Step 1"

 __logd "Re-acquiring lock after child processes (this will update lock file timestamp)"
 exec 8> "${LOCK}"
 if ! flock -n 8; then
  __loge "ERROR: Failed to re-acquire lock after child processes"
  __loge "Another process may have acquired the lock"
  exit 1
 fi

 # Update lock file content to reflect current process state
 # This is intentional - the lock file is updated after child processes complete
 cat > "${LOCK}" << EOF
PID: ${ORIGINAL_PID}
Process: ${BASENAME}
Started: ${PROCESS_START_TIME}
Temporary directory: ${TMP_DIR}
Process type: ${PROCESS_TYPE}
Main script: ${0}
Lock re-acquired: $(date '+%Y-%m-%d %H:%M:%S')
EOF
 __logd "Lock file content updated after child processes: ${LOCK}"
 __log_finish
}

function __check_and_log_gaps() {
 __log_start

 # Query database for recent gaps
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

 # Log gaps to file
 local GAP_FILE="/tmp/processAPINotes_gaps.log"
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -Atq -c "${GAP_QUERY}" > "${GAP_FILE}" 2> /dev/null || true

 __logd "Checked and logged gaps from database"
 __log_finish
}

# Function that activates the error trap.
function __trapOn() {
 __log_start
 trap '{ 
  local ERROR_LINE="${LINENO}"
  local ERROR_COMMAND="${BASH_COMMAND}"
  local ERROR_EXIT_CODE="$?"
  
  # Only report actual errors, not successful returns
  if [[ "${ERROR_EXIT_CODE}" -ne 0 ]]; then
   # Get the main script name (the one that was executed, not the library)
   local MAIN_SCRIPT_NAME
   MAIN_SCRIPT_NAME=$(basename "${0}" .sh)
   
   printf "%s ERROR: The script %s did not finish correctly. Temporary directory: ${TMP_DIR:-} - Line number: %d.\n" "$(date +%Y%m%d_%H:%M:%S)" "${MAIN_SCRIPT_NAME}" "${ERROR_LINE}";
   printf "ERROR: Failed command: %s (exit code: %d)\n" "${ERROR_COMMAND}" "${ERROR_EXIT_CODE}";
   if [[ "${GENERATE_FAILED_FILE}" = true ]]; then
    # Determine the failed execution file path
    local FAILED_FILE_PATH="${FAILED_EXECUTION_FILE:-/tmp/${MAIN_SCRIPT_NAME}_failed_execution}"
    # Attempt to create the failed execution file
    # Use a subshell with error handling to prevent trap recursion
    (
     {
      echo "Error occurred at $(date +%Y%m%d_%H:%M:%S)"
      echo "Script: ${MAIN_SCRIPT_NAME}"
      echo "Line number: ${ERROR_LINE}"
      echo "Failed command: ${ERROR_COMMAND}"
      echo "Exit code: ${ERROR_EXIT_CODE}"
      echo "Temporary directory: ${TMP_DIR:-unknown}"
      echo "Process ID: $$"
      echo "ONLY_EXECUTION was: ${ONLY_EXECUTION:-not set}"
     } > "${FAILED_FILE_PATH}" 2>/dev/null || {
      # If writing to primary location fails, try /tmp as fallback
      printf "%s ERROR: Failed to write failed execution file to %s\n" "$(date +%Y%m%d_%H:%M:%S)" "${FAILED_FILE_PATH}" > "/tmp/${MAIN_SCRIPT_NAME}_failed_execution_fallback" 2>/dev/null || true
     }
    ) || true
   fi;
   exit "${ERROR_EXIT_CODE}";
  fi;
  }' ERR
 trap '{
  # Get the main script name (the one that was executed, not the library)
  local MAIN_SCRIPT_NAME
  MAIN_SCRIPT_NAME=$(basename "${0}" .sh)
  
  printf "%s WARN: The script %s was terminated. Temporary directory: ${TMP_DIR:-}\n" "$(date +%Y%m%d_%H:%M:%S)" "${MAIN_SCRIPT_NAME}";
  if [[ "${GENERATE_FAILED_FILE}" = true ]]; then
   # Determine the failed execution file path
   local FAILED_FILE_PATH="${FAILED_EXECUTION_FILE:-/tmp/${MAIN_SCRIPT_NAME}_failed_execution}"
   # Attempt to create the failed execution file
   # Use a subshell with error handling to prevent trap recursion
   (
    {
     echo "Script terminated at $(date +%Y%m%d_%H:%M:%S)"
     echo "Script: ${MAIN_SCRIPT_NAME}" 
     echo "Temporary directory: ${TMP_DIR:-unknown}"
     echo "Process ID: $$"
     echo "Signal: SIGTERM/SIGINT"
     echo "ONLY_EXECUTION was: ${ONLY_EXECUTION:-not set}"
    } > "${FAILED_FILE_PATH}" 2>/dev/null || {
     # If writing to primary location fails, try /tmp as fallback
     printf "%s WARN: Script terminated but failed to write failed execution file to %s\n" "$(date +%Y%m%d_%H:%M:%S)" "${FAILED_FILE_PATH}" > "/tmp/${MAIN_SCRIPT_NAME}_failed_execution_fallback" 2>/dev/null || true
    }
   ) || true
  fi;
  exit ${ERROR_GENERAL};
 }' SIGINT SIGTERM
 __log_finish
}

######
# MAIN

function main() {
 # Enable bash debug mode if BASH_DEBUG environment variable is set
 if [[ "${BASH_DEBUG:-}" == "true" ]] || [[ "${BASH_DEBUG:-}" == "1" ]]; then
  set -xv
 fi

 __log_start
 __logi "Preparing environment."
 __logd "Output saved at: ${TMP_DIR}."
 __logi "Process ID: ${$}"
 __logi "Processing: '${PROCESS_TYPE}'."

 if [[ "${PROCESS_TYPE}" == "-h" ]] || [[ "${PROCESS_TYPE}" == "--help" ]]; then
  __show_help
 fi
 # Check for failed execution file, but verify if it's still a real problem
 if [[ -f "${FAILED_EXECUTION_FILE}" ]]; then
  # Check if the failure was due to network issues
  if grep -q "Network connectivity\|API download failed\|Internet issues" "${FAILED_EXECUTION_FILE}" 2> /dev/null; then
   __logw "Previous execution failed due to network issues. Verifying connectivity..."
   # Verify network connectivity before blocking
   if __check_network_connectivity 10; then
    __logi "Network connectivity restored. Removing failed execution marker and continuing..."
    rm -f "${FAILED_EXECUTION_FILE}"
   else
    __loge "Network connectivity still unavailable. Exiting to prevent data corruption."
    echo "Previous execution failed due to network issues. Network is still unavailable."
    echo "Please verify connectivity and remove this file when resolved:"
    echo "   ${FAILED_EXECUTION_FILE}"
    exit "${ERROR_PREVIOUS_EXECUTION_FAILED}"
   fi
  else
   # Non-network error: require manual intervention
   __loge "Previous execution failed (non-network error). Manual intervention required."
   echo "Previous execution failed. Please verify the data and then remove the"
   echo "next file:"
   echo "   ${FAILED_EXECUTION_FILE}"
   exit "${ERROR_PREVIOUS_EXECUTION_FAILED}"
  fi
 fi
 __checkPrereqs
 __logw "Process started."

 # Sets the trap in case of any signal.
 __trapOn
 __setupLockFile

 __dropApiTables
 set +E
 set +e
 # Temporarily disable ERR trap to avoid exiting when __checkBaseTables returns non-zero
 trap '' ERR
 __checkNoProcessPlanet
 export RET_FUNC=0
 __logd "Before calling __checkBaseTables, RET_FUNC=${RET_FUNC}"
 __checkBaseTables || true
 local CHECK_BASE_TABLES_EXIT_CODE=$?
 # CRITICAL: Immediately re-read RET_FUNC from environment after function call
 # The function exports RET_FUNC, but we need to ensure we're reading the updated value
 # Try multiple methods to get the correct value:
 # 1. Read from temp file (most reliable)
 # 2. Read from environment
 # 3. Fall back to current value
 local RET_FUNC_FILE="${TMP_DIR:-/tmp}/.ret_func_$$"
 if [[ -f "${RET_FUNC_FILE}" ]]; then
  local FILE_RET_FUNC
  FILE_RET_FUNC=$(cat "${RET_FUNC_FILE}" 2> /dev/null | head -1 || echo "")
  if [[ -n "${FILE_RET_FUNC}" ]] && [[ "${FILE_RET_FUNC}" =~ ^[0-9]+$ ]]; then
   RET_FUNC="${FILE_RET_FUNC}"
   export RET_FUNC="${RET_FUNC}"
   __logi "After __checkBaseTables, RET_FUNC=${RET_FUNC} (read from temp file)"
   rm -f "${RET_FUNC_FILE}" 2> /dev/null || true
  else
   __logw "Invalid value in temp file, trying environment..."
   local ENV_RET_FUNC
   ENV_RET_FUNC=$(env | grep "^RET_FUNC=" | cut -d= -f2 || echo "0")
   if [[ -n "${ENV_RET_FUNC}" ]] && [[ "${ENV_RET_FUNC}" =~ ^[0-9]+$ ]]; then
    RET_FUNC="${ENV_RET_FUNC}"
    export RET_FUNC="${RET_FUNC}"
    __logi "After __checkBaseTables, RET_FUNC=${RET_FUNC} (read from environment)"
   else
    __logw "RET_FUNC not found, using current value: ${RET_FUNC}"
   fi
  fi
 else
  # No temp file, try environment
  local ENV_RET_FUNC
  ENV_RET_FUNC=$(env | grep "^RET_FUNC=" | cut -d= -f2 || echo "0")
  if [[ -n "${ENV_RET_FUNC}" ]] && [[ "${ENV_RET_FUNC}" =~ ^[0-9]+$ ]]; then
   RET_FUNC="${ENV_RET_FUNC}"
   export RET_FUNC="${RET_FUNC}"
   __logi "After __checkBaseTables, RET_FUNC=${RET_FUNC} (read from environment)"
  else
   __logw "RET_FUNC not found, using current value: ${RET_FUNC}"
  fi
 fi
 # Re-enable ERR trap (restore the one from __trapOn)
 set -E
 set +e
 # Don't re-enable set -e here, do it later before operations that need it
 trap '{
  local ERROR_LINE="${LINENO}"
  local ERROR_COMMAND="${BASH_COMMAND}"
  local ERROR_EXIT_CODE="$?"
  if [[ "${ERROR_EXIT_CODE}" -ne 0 ]]; then
   local MAIN_SCRIPT_NAME
   MAIN_SCRIPT_NAME=$(basename "${0}" .sh)
   printf "%s ERROR: The script %s did not finish correctly. Temporary directory: ${TMP_DIR:-} - Line number: %d.\n" "$(date +%Y%m%d_%H:%M:%S)" "${MAIN_SCRIPT_NAME}" "${ERROR_LINE}";
   printf "ERROR: Failed command: %s (exit code: %d)\n" "${ERROR_COMMAND}" "${ERROR_EXIT_CODE}";
   if [[ "${GENERATE_FAILED_FILE}" = true ]]; then
    # Determine the failed execution file path
    local FAILED_FILE_PATH="${FAILED_EXECUTION_FILE:-/tmp/${MAIN_SCRIPT_NAME}_failed_execution}"
    # Attempt to create the failed execution file
    # Use a subshell with error handling to prevent trap recursion
    (
     {
      echo "Error occurred at $(date +%Y%m%d_%H:%M:%S)"
      echo "Script: ${MAIN_SCRIPT_NAME}"
      echo "Line number: ${ERROR_LINE}"
      echo "Failed command: ${ERROR_COMMAND}"
      echo "Exit code: ${ERROR_EXIT_CODE}"
      echo "Temporary directory: ${TMP_DIR:-unknown}"
      echo "Process ID: $$"
      echo "ONLY_EXECUTION was: ${ONLY_EXECUTION:-not set}"
     } > "${FAILED_FILE_PATH}" 2>/dev/null || {
      # If writing to primary location fails, try /tmp as fallback
      printf "%s ERROR: Failed to write failed execution file to %s\n" "$(date +%Y%m%d_%H:%M:%S)" "${FAILED_FILE_PATH}" > "/tmp/${MAIN_SCRIPT_NAME}_failed_execution_fallback" 2>/dev/null || true
     }
    ) || true
   fi;
   exit "${ERROR_EXIT_CODE}";
  fi; }' ERR
 __logi "After calling __checkBaseTables, RET_FUNC=${RET_FUNC}"
 __logd "__checkBaseTables exit code: ${CHECK_BASE_TABLES_EXIT_CODE}"
 # Double-check RET_FUNC is set correctly
 # IMPORTANT: Re-read RET_FUNC from environment in case export didn't propagate
 # This handles cases where the function was called in a subshell or variable scope issue
 if [[ -z "${RET_FUNC:-}" ]]; then
  __loge "CRITICAL: RET_FUNC is empty after __checkBaseTables!"
  __loge "This should never happen. Forcing safe exit (RET_FUNC=2)"
  export RET_FUNC=2
 else
  # Force re-export to ensure it's available in current scope
  export RET_FUNC="${RET_FUNC}"
  __logd "Re-exported RET_FUNC=${RET_FUNC} to ensure it's in current scope"
 fi

 __logi "Final RET_FUNC value before case statement: ${RET_FUNC}"

 case "${RET_FUNC}" in
 1)
  # Tables are missing - safe to run --base
  __logw "Base tables missing (RET_FUNC=1). Creating base structure and geographic data."
  __logi "This will take approximately 1-2 hours for complete setup."
  ;;
 2)
  # Connection or other error - DO NOT run --base
  __loge "ERROR: Cannot verify base tables due to database/system error (RET_FUNC=2)"
  __loge "This is NOT a 'tables missing' situation - manual investigation required"
  __loge "Do NOT executing --base (would delete all data)"
  __create_failed_marker "${ERROR_EXECUTING_PLANET_DUMP}" \
   "Cannot verify base tables due to database/system error" \
   "Check database connectivity and permissions. Check logs for details. Script exited to prevent data loss."
  exit "${ERROR_EXECUTING_PLANET_DUMP}"
  ;;
 0)
  # Tables exist - continue normally
  __logd "Base tables verified (RET_FUNC=0) - continuing with normal processing"
  ;;
 *)
  # Unknown error code
  __loge "ERROR: Unknown return code from __checkBaseTables: ${RET_FUNC}"
  __loge "Do NOT executing --base (would delete all data)"
  __create_failed_marker "${ERROR_EXECUTING_PLANET_DUMP}" \
   "Unknown error checking base tables (code: ${RET_FUNC})" \
   "Check logs for details. Script exited to prevent data loss."
  exit "${ERROR_EXECUTING_PLANET_DUMP}"
  ;;
 esac

 if [[ "${RET_FUNC}" -eq 1 ]]; then
  __createBaseStructure
 fi

 if [[ "${RET_FUNC}" -eq 0 ]]; then
  __validateHistoricalDataAndRecover
 fi

set -e
set -E
__createApiTables
__createPropertiesTable
 __ensureGetCountryFunction
 __createProcedures
 set +E
 __getNewNotesFromApi
 set -E

 __validateApiNotesFile
 __validateAndProcessApiXml
 __check_and_log_gaps
 __cleanNotesFiles

 rm -f "${LOCK}"

 __logw "Process finished."
 __log_finish
}
# Return value for several functions.
declare -i RET

# Allows to other users read the directory.
# Protect chmod from causing script exit if it fails (e.g., TMP_DIR doesn't exist)
chmod go+x "${TMP_DIR}" 2> /dev/null || true

# If running from cron (no TTY), redirect logger initialization
# Check if script is being sourced (not executed directly)
# When sourced, ${BASH_SOURCE[0]} != ${0}
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
 # Script is being executed directly, run main function
 # and main execution to the log file to keep cron silent
 if [[ ! -t 1 ]]; then
  export LOG_FILE="${LOG_FILENAME}"
  {
   __start_logger
   main
  } >> "${LOG_FILENAME}" 2>&1
  if [[ -n "${CLEAN:-}" ]] && [[ "${CLEAN}" = true ]]; then
   mv "${LOG_FILENAME}" "/tmp/${BASENAME}_$(date +%Y-%m-%d_%H-%M-%S || true).log"
   # Protect rmdir from causing script exit if it fails (e.g., TMP_DIR not empty or doesn't exist)
   rmdir "${TMP_DIR}" 2> /dev/null || true
  fi
 else
  __start_logger
  main
 fi
# else: script is being sourced, do nothing (just load functions)
fi
