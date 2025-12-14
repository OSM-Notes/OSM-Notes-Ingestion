#!/bin/bash

# OSM Notes API Processing Daemon
# Maintains continuous connection and processes data when available
#
# This daemon runs continuously, checking the OSM API periodically for new notes.
# When data is available, it processes it immediately. When no data is available,
# it sleeps for a short interval before checking again.
#
# Usage:
#   ./processAPINotesDaemon.sh [--help]
#
# Configuration (environment variables):
#   - DAEMON_SLEEP_INTERVAL: Seconds between API checks (default: 60)
#   - LOG_LEVEL: Logging level (TRACE, DEBUG, INFO, WARN, ERROR, FATAL)
#
# Integration:
#   - systemd: See examples/systemd/osm-notes-api-daemon.service (recommended)
#
# Author: Andres Gomez (AngocA)
# Version: 2025-12-14
VERSION="2025-12-14"

#set -xv
set -u
set -e
set -o pipefail
set -E

# Auto-restart with setsid if not already in a new session
if [[ -z "${RUNNING_IN_SETSID:-}" ]] && command -v setsid > /dev/null 2>&1; then
 if [[ -t 1 ]]; then
  RESTART_MESSAGE=$(date '+%Y%m%d_%H:%M:%S' || true)
  echo "${RESTART_MESSAGE} INFO: Auto-restarting with setsid for SIGHUP protection" >&2
  unset RESTART_MESSAGE
 fi
 export RUNNING_IN_SETSID=1
 SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
 exec setsid -w "${SCRIPT_PATH}" "$@"
fi

# Ignore SIGHUP signal
trap '' HUP

# Logger levels
declare LOG_LEVEL="${LOG_LEVEL:-ERROR}"

# Base directory
declare SCRIPT_BASE_DIRECTORY
SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." \
 &> /dev/null && pwd)"
readonly SCRIPT_BASE_DIRECTORY

# Load properties
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh"

umask 0000

declare BASENAME
BASENAME=$(basename -s .sh "${0}")
readonly BASENAME

export PGAPPNAME="${BASENAME}"

# Temporary directory (persistent for daemon)
declare TMP_DIR
TMP_DIR=$(mktemp -d "/tmp/${BASENAME}_XXXXXX")
readonly TMP_DIR
chmod 777 "${TMP_DIR}"

# Log file
declare LOG_FILENAME
LOG_FILENAME="${TMP_DIR}/${BASENAME}.log"
readonly LOG_FILENAME

# Lock file
declare LOCK
LOCK="/tmp/${BASENAME}.lock"
readonly LOCK

# Daemon configuration
declare -i DAEMON_SLEEP_INTERVAL="${DAEMON_SLEEP_INTERVAL:-60}"
declare DAEMON_SHUTDOWN_FLAG="/tmp/${BASENAME}_shutdown"
declare -i DAEMON_START_TIME
DAEMON_START_TIME=$(date +%s)
declare LAST_PROCESSED_TIMESTAMP=""
declare -i PROCESSING_DURATION=0

# Control variables
export GENERATE_FAILED_FILE=true
export ONLY_EXECUTION="no"

###########
# FUNCTIONS

# Load common functions
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/commonFunctions.sh"

# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/bin/lib/processAPIFunctions.sh"

# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/validationFunctions.sh"

# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/errorHandlingFunctions.sh"

# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/alertFunctions.sh"

# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh"

# Load processAPINotes.sh to get processing functions
# The script detects when it's being sourced and only loads functions, doesn't execute main
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/bin/process/processAPINotes.sh"

# Shows help information
function __show_help {
 echo "${0} version ${VERSION}."
 echo
 echo "OSM Notes API Processing Daemon"
 echo "Maintains continuous connection and processes data when available."
 echo
 echo "Usage:"
 echo "  ${0} [--help]"
 echo
 echo "Environment Variables:"
 echo "  DAEMON_SLEEP_INTERVAL  Seconds between API checks (default: 60)"
 echo "  LOG_LEVEL              Logging level (TRACE, DEBUG, INFO, WARN, ERROR, FATAL)"
 echo "  CLEAN                  Delete temporary files (true/false)"
 echo
 echo "Integration:"
 echo "  - systemd: Use provided service file (see docs/Daemon_Design.md)"
 echo "  - cron: Use startAPINotesDaemon.sh wrapper"
 echo
 echo "Signals:"
 echo "  SIGTERM/SIGINT  Graceful shutdown"
 echo "  SIGHUP          Reload configuration"
 echo "  SIGUSR1         Show status"
 echo
 echo "Written by: Andres Gomez (AngocA)."
 exit "${ERROR_HELP_MESSAGE}"
}

# Acquires lock file for daemon singleton
function __acquire_lock {
 __log_start
 __logd "Acquiring daemon lock..."

 if [[ -f "${LOCK}" ]]; then
  local EXISTING_PID
  EXISTING_PID=$(head -1 "${LOCK}" 2> /dev/null | grep -o 'PID: [0-9]*' | awk '{print $2}' || echo "")

  if [[ -n "${EXISTING_PID}" ]] && ps -p "${EXISTING_PID}" > /dev/null 2>&1; then
   __loge "Daemon already running (PID: ${EXISTING_PID})"
   __log_finish
   return 1
  else
   __logw "Stale lock file found, removing it"
   rm -f "${LOCK}" || {
    __loge "Failed to remove stale lock file, trying to remove as user"
    # Try to remove with proper permissions
    if [[ -w "${LOCK}" ]]; then
     rm -f "${LOCK}"
    else
     __loge "Lock file exists but is not writable: ${LOCK}"
     __log_finish
     return 1
    fi
   }
  fi
 fi

 # Create lock file with flock
 # Use append mode to avoid permission issues if file exists
 exec 8>> "${LOCK}"
 if ! flock -n 8; then
  __loge "Failed to acquire lock file (may be locked by another process)"
  exec 8>&-
  __log_finish
  return 1
 fi
 # Truncate file after acquiring lock
 : > "${LOCK}"

 cat > "${LOCK}" << EOF
PID: $$
Process: ${BASENAME}
Started: $(date '+%Y-%m-%d %H:%M:%S')
Temporary directory: ${TMP_DIR}
Daemon sleep interval: ${DAEMON_SLEEP_INTERVAL}
Main script: ${0}
EOF

 __logd "Lock file acquired: ${LOCK}"
 __log_finish
 return 0
}

# Releases lock file
function __release_lock {
 __log_start
 if [[ -f "${LOCK}" ]]; then
  exec 8>&-
  rm -f "${LOCK}"
  __logd "Lock file released"
 fi
 __log_finish
}

# Setup signal handlers
function __setup_signal_handlers {
 __log_start
 trap '__daemon_shutdown' TERM INT
 trap '__daemon_reload_config' HUP
 trap '__daemon_status' USR1
 __log_finish
}

# Graceful shutdown
function __daemon_shutdown {
 __logi "Received shutdown signal, cleaning up..."
 touch "${DAEMON_SHUTDOWN_FLAG}"
 # Don't exit here, let the main loop detect the flag
}

# Reload configuration
function __daemon_reload_config {
 __logi "Received reload signal, reloading configuration..."
 # Recargar properties
 # shellcheck disable=SC1091
 source "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh"

 # Actualizar intervalo si cambió
 if [[ -n "${DAEMON_SLEEP_INTERVAL_NEW:-}" ]]; then
  DAEMON_SLEEP_INTERVAL="${DAEMON_SLEEP_INTERVAL_NEW}"
 fi

 __logi "Configuration reloaded (sleep interval: ${DAEMON_SLEEP_INTERVAL}s)"
}

# Show daemon status
function __daemon_status {
 local UPTIME
 UPTIME=$(($(date +%s) - DAEMON_START_TIME))
 local UPTIME_HOURS=$((UPTIME / 3600))
 local UPTIME_MINS=$(((UPTIME % 3600) / 60))
 local UPTIME_SECS=$((UPTIME % 60))

 __logi "=== DAEMON STATUS ==="
 __logi "PID: $$"
 __logi "Uptime: ${UPTIME_HOURS}h ${UPTIME_MINS}m ${UPTIME_SECS}s"
 __logi "Sleep interval: ${DAEMON_SLEEP_INTERVAL} seconds"
 __logi "Last processed: ${LAST_PROCESSED_TIMESTAMP:-unknown}"

 local DB_TIMESTAMP
 DB_TIMESTAMP=$(psql -d "${DBNAME}" -Atq -c \
  "SELECT TO_CHAR(timestamp, 'YYYY-MM-DD HH24:MI:SS') FROM max_note_timestamp" \
  2> /dev/null | head -1 || echo "unknown")
 __logi "Last DB timestamp: ${DB_TIMESTAMP}"

 # Mostrar últimas líneas del log
 if [[ -f "${LOG_FILENAME}" ]]; then
  __logi "Recent log entries:"
  tail -5 "${LOG_FILENAME}" | while IFS= read -r line; do
   __logi "  ${line}"
  done
 fi
}

# Check prerequisites for daemon
# Only define if not already set (e.g., when sourced from processAPINotes.sh)
if ! declare -f __checkPrereqs > /dev/null 2>&1; then
 function __checkPrereqs {
  __log_start
  # Checks prereqs.
  __checkPrereqsCommands
  __checkPrereqs_functions
  __log_finish
 }
fi

# Check if processPlanetNotes is running
function __checkNoProcessPlanet {
 __log_start
 if pgrep -f "processPlanetNotes" > /dev/null 2>&1; then
  __loge "ERROR: processPlanetNotes.sh is currently running. Cannot start daemon."
  __loge "Please wait for processPlanetNotes.sh to finish before starting the daemon."
  __log_finish
  exit "${ERROR_EXECUTING_PLANET_DUMP}"
 fi
 __log_finish
}

# Creates table properties during the execution.
# Only define if not already set (e.g., when sourced from processAPINotes.sh)
if ! declare -f __createPropertiesTable > /dev/null 2>&1; then
 function __createPropertiesTable {
  __log_start
  __logi "=== CREATING PROPERTIES TABLE ==="
  __logd "Executing SQL file: ${POSTGRES_23_CREATE_PROPERTIES_TABLE}"
  PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
   -f "${POSTGRES_23_CREATE_PROPERTIES_TABLE}"
  __logi "=== PROPERTIES TABLE CREATED SUCCESSFULLY ==="
  __log_finish
 }
fi

# Ensures get_country function exists before creating procedures.
# The procedures (insert_note, insert_note_comment) require get_country to exist.
# This function checks if get_country exists and creates it if missing.
# If get_country exists but countries table does not, recreates the function as stub.
function __ensureGetCountryFunction {
 __log_start
 __logd "Ensuring get_country function exists..."

 # Check if countries table exists
 local COUNTRIES_EXIST
 COUNTRIES_EXIST=$(PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'countries';" 2> /dev/null | grep -E '^[0-9]+$' | tail -1 || echo "0")

 # Check if get_country function exists
 local FUNCTION_EXISTS
 FUNCTION_EXISTS=$(PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname = 'public' AND p.proname = 'get_country';" 2> /dev/null | grep -E '^[0-9]+$' | tail -1 || echo "0")

 if [[ "${FUNCTION_EXISTS}" -eq "0" ]]; then
  __logi "get_country function does not exist, creating it..."
  if [[ "${COUNTRIES_EXIST}" -eq "0" ]]; then
   __logw "countries table does not exist, creating stub function"
   PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -c "
    CREATE OR REPLACE FUNCTION get_country(geom geometry)
    RETURNS text
    LANGUAGE plpgsql
    AS \$\$
    BEGIN
     RETURN NULL;
    END;
    \$\$;
   " || {
    __loge "Failed to create stub get_country function"
    __log_finish
    return 1
   }
  else
   __logd "Executing SQL file: ${POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY}"
   PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
    -f "${POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY}" || {
    __loge "Failed to create get_country function"
    __log_finish
    return 1
   }
  fi
  __logi "get_country function created successfully"
 else
  __logd "get_country function already exists"
 fi

 __log_finish
}

# Validate historical data and recover if needed
function __validateHistoricalDataAndRecover {
 __log_start
 __logd "Validating historical data consistency..."
 # For daemon mode, we skip historical validation on startup
 # Historical data validation is handled during normal processing
 __logd "Historical data validation skipped in daemon mode"
 __log_finish
}

# Clean temporary notes files
function __cleanNotesFiles {
 __log_start
 __logd "Cleaning temporary notes files..."
 rm -f "${API_NOTES_FILE}" "${OUTPUT_NOTES_FILE}" \
  "${OUTPUT_NOTE_COMMENTS_FILE}" "${OUTPUT_TEXT_COMMENTS_FILE}" 2> /dev/null || true
 __logd "Temporary files cleaned"
 __log_finish
}

# Validate API notes file
function __validateApiNotesFile {
 __log_start
 __logd "Validating API notes file: ${API_NOTES_FILE}"

 # Check if file exists
 if [[ ! -f "${API_NOTES_FILE}" ]]; then
  __loge "ERROR: API notes file not found: ${API_NOTES_FILE}"
  __log_finish
  return 1
 fi

 # Check if file is not empty
 if [[ ! -s "${API_NOTES_FILE}" ]]; then
  __loge "ERROR: API notes file is empty: ${API_NOTES_FILE}"
  __log_finish
  return 1
 fi

 # Skip XML validation if SKIP_XML_VALIDATION is set
 if [[ "${SKIP_XML_VALIDATION:-false}" != "true" ]]; then
  __logd "Validating XML structure..."
  if ! __validate_xml_with_enhanced_error_handling "${API_NOTES_FILE}" "${XMLSCHEMA_API_NOTES}"; then
   __loge "ERROR: XML structure validation failed"
   __log_finish
   return 1
  fi
 else
  __logd "XML validation skipped (SKIP_XML_VALIDATION=true)"
 fi

 __logd "API notes file validation passed"
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
    {
     echo "Error occurred at $(date +%Y%m%d_%H:%M:%S)"
     echo "Script: ${MAIN_SCRIPT_NAME}"
     echo "Line number: ${ERROR_LINE}"
     echo "Failed command: ${ERROR_COMMAND}"
     echo "Exit code: ${ERROR_EXIT_CODE}"
     echo "Temporary directory: ${TMP_DIR:-unknown}"
     echo "Process ID: $$"
    } > "${FAILED_EXECUTION_FILE}"
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
   {
    echo "Script terminated at $(date +%Y%m%d_%H:%M:%S)"
    echo "Script: ${MAIN_SCRIPT_NAME}" 
    echo "Temporary directory: ${TMP_DIR:-unknown}"
    echo "Process ID: $$"
    echo "Signal: SIGTERM/SIGINT"
   } > "${FAILED_EXECUTION_FILE}"
  fi;
  exit ${ERROR_GENERAL};
 }' SIGINT SIGTERM
 __log_finish
}

# Daemon initialization (runs once at startup)
function __daemon_init {
 __log_start
 __logi "=== DAEMON INITIALIZATION ==="

 # Check prerequisites (cached after first run)
 __logi "Checking prerequisites..."
 __checkPrereqs

 # Setup trap
 __trapOn

 # Check base tables
 set +e
 trap '' ERR
 __checkNoProcessPlanet
 export RET_FUNC=0
 __checkBaseTables || true
 local RET_FUNC_FILE="${TMP_DIR}/.ret_func_$$"
 if [[ -f "${RET_FUNC_FILE}" ]]; then
  local FILE_RET_FUNC
  FILE_RET_FUNC=$(cat "${RET_FUNC_FILE}" 2> /dev/null | head -1 || echo "")
  if [[ -n "${FILE_RET_FUNC}" ]] && [[ "${FILE_RET_FUNC}" =~ ^[0-9]+$ ]]; then
   RET_FUNC="${FILE_RET_FUNC}"
   export RET_FUNC="${RET_FUNC}"
   rm -f "${RET_FUNC_FILE}" 2> /dev/null || true
  fi
 fi
 set -E
 trap '{
  local ERROR_LINE="${LINENO}"
  local ERROR_COMMAND="${BASH_COMMAND}"
  local ERROR_EXIT_CODE="$?"
  if [[ "${ERROR_EXIT_CODE}" -ne 0 ]]; then
   local MAIN_SCRIPT_NAME
   MAIN_SCRIPT_NAME=$(basename "${0}" .sh)
   printf "%s ERROR: The script %s did not finish correctly. Temporary directory: ${TMP_DIR:-} - Line number: %d.\n" "$(date +%Y%m%d_%H:%M:%S)" "${MAIN_SCRIPT_NAME}" "${ERROR_LINE}";
   printf "ERROR: Failed command: %s (exit code: %d)\n" "${ERROR_COMMAND}" "${ERROR_EXIT_CODE}";
  fi; }' ERR

 if [[ "${RET_FUNC}" -eq 1 ]]; then
  __loge "Base tables missing. Please run processPlanetNotes.sh --base first"
  exit "${ERROR_EXECUTING_PLANET_DUMP}"
 fi

 if [[ "${RET_FUNC}" -eq 0 ]]; then
  __validateHistoricalDataAndRecover
 fi

 set -e
 set -E

 # Prepare API tables (create if needed, truncate if exist)
 __logi "Preparing API tables..."
 __prepareApiTables

 # Create partitions (only if needed)
 # Create properties table
 __logi "Checking properties table..."
 __createPropertiesTable

 # Ensure functions and procedures exist
 __logi "Checking functions and procedures..."
 __ensureGetCountryFunction
 __createProcedures

 # Get initial timestamp
 LAST_PROCESSED_TIMESTAMP=$(psql -d "${DBNAME}" -Atq -c \
  "SELECT TO_CHAR(timestamp, E'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') FROM max_note_timestamp" \
  2> /dev/null | head -1 || echo "")

 __logi "Daemon initialized successfully"
 __logi "Last processed timestamp: ${LAST_PROCESSED_TIMESTAMP:-none}"
 __log_finish
}

# Prepare API tables (truncate if exist, create if not)
function __prepareApiTables {
 __log_start
 __logi "=== PREPARING API TABLES ==="

 # Check if tables exist
 local TABLES_EXIST
 TABLES_EXIST=$(psql -d "${DBNAME}" -Atq -c "
  SELECT COUNT(*) 
  FROM information_schema.tables 
  WHERE table_schema = 'public' 
    AND table_name IN ('notes_api', 'note_comments_api', 'note_comments_text_api')
 " 2> /dev/null | grep -E '^[0-9]+$' | tail -1 || echo "0")

 if [[ "${TABLES_EXIST}" -eq "3" ]]; then
  # Tables exist: use TRUNCATE (faster)
  __logd "Tables exist, using TRUNCATE"
  psql -d "${DBNAME}" -v ON_ERROR_STOP=1 << EOF
    TRUNCATE TABLE notes_api CASCADE;
    TRUNCATE TABLE note_comments_api CASCADE;
    TRUNCATE TABLE note_comments_text_api CASCADE;
EOF
  __logi "API tables truncated successfully"
 else
  # Tables don't exist: create them
  __logd "Tables don't exist, creating them"
  __createApiTables
 fi

 __log_finish
}

# Check API for updates (lightweight check)
function __check_api_for_updates {
 __log_start
 __logd "Checking API for updates since: ${LAST_PROCESSED_TIMESTAMP:-none}"

 if [[ -z "${LAST_PROCESSED_TIMESTAMP}" ]]; then
  __logw "No last update timestamp, will download full dataset"
  __log_finish
  return 0 # Return true to trigger full download
 fi

 # Lightweight check: query API with limit=1 to see if there are updates
 local CHECK_URL="${OSM_API}/notes/search.xml?limit=1&closed=-1&sort=updated_at&from=${LAST_PROCESSED_TIMESTAMP}"
 local TEMP_CHECK_FILE="${TMP_DIR}/api_check_$$.xml"

 if wget -q --timeout=10 --tries=1 -O "${TEMP_CHECK_FILE}" "${CHECK_URL}" 2> /dev/null; then
  # Check if there are notes in the XML
  local NOTE_COUNT
  NOTE_COUNT=$(grep -c '<note ' "${TEMP_CHECK_FILE}" 2> /dev/null || echo "0")
  rm -f "${TEMP_CHECK_FILE}"

  if [[ "${NOTE_COUNT}" -gt 0 ]]; then
   __logd "Updates detected (${NOTE_COUNT} note(s) found)"
   __log_finish
   return 0 # There are updates
  else
   __logd "No updates detected"
   __log_finish
   return 1 # No updates
  fi
 else
  __logw "Failed to check API, will retry on next cycle"
  rm -f "${TEMP_CHECK_FILE}"
  __log_finish
  return 1 # Error, don't process this cycle
 fi
}

# Process API data
# Returns: 0 on success, 1 on error
# Sets global variable PROCESSING_DURATION with processing time in seconds
function __process_api_data {
 __log_start
 __logi "=== PROCESSING API DATA ==="

 local CYCLE_START_TIME
 CYCLE_START_TIME=$(date +%s)

 # Download data
 if ! __getNewNotesFromApi; then
  __loge "Failed to download notes from API"
  __log_finish
  return 1
 fi

 # Validate file
 __validateApiNotesFile

 # Count and process
 __countXmlNotesAPI "${API_NOTES_FILE}"

 if [[ "${TOTAL_NOTES}" -gt 0 ]]; then
  __logi "Processing ${TOTAL_NOTES} notes"

  if [[ "${TOTAL_NOTES}" -ge "${MAX_NOTES}" ]]; then
   __logw "Too many notes (${TOTAL_NOTES} >= ${MAX_NOTES}), triggering Planet sync"
   __logi "Executing: ${NOTES_SYNC_SCRIPT}"
   if "${NOTES_SYNC_SCRIPT}"; then
    __logi "Planet sync completed successfully"
    # After Planet sync, update timestamp to prevent infinite loop
    # processPlanetNotes.sh doesn't update max_note_timestamp, so we need to do it here
    __logi "Updating timestamp after Planet sync"
    __updateLastValue
   else
    local PLANET_SYNC_EXIT_CODE=$?
    __loge "Planet sync failed with exit code: ${PLANET_SYNC_EXIT_CODE}"
    __loge "Check processPlanetNotes.sh logs for details"
    __loge "Failed execution marker: /tmp/processPlanetNotes_failed_execution"
    return 1
   fi
  else
   # Process normally
   __processXMLorPlanet
   __insertNewNotesAndComments
   __loadApiTextComments
  fi
 else
  __logi "No notes to process"
 fi

 # Update last processed timestamp
 LAST_PROCESSED_TIMESTAMP=$(psql -d "${DBNAME}" -Atq -c \
  "SELECT TO_CHAR(timestamp, E'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') FROM max_note_timestamp" \
  2> /dev/null | head -1 || echo "")

 # Clean files
 if [[ "${CLEAN:-}" == "true" ]]; then
  __cleanNotesFiles
 fi

 local CYCLE_DURATION
 CYCLE_DURATION=$(($(date +%s) - CYCLE_START_TIME))
 PROCESSING_DURATION="${CYCLE_DURATION}"
 __logi "Processing completed in ${CYCLE_DURATION} seconds"
 __log_finish
 return 0
}

# Main daemon loop
function __daemon_loop {
 __log_start
 __logi "=== STARTING DAEMON LOOP ==="
 __logi "Sleep interval: ${DAEMON_SLEEP_INTERVAL} seconds"

 local CONSECUTIVE_ERRORS=0
 local MAX_CONSECUTIVE_ERRORS=5
 local CYCLE_NUMBER=0
 local HAD_UPDATES=false

 while true; do
  CYCLE_NUMBER=$((CYCLE_NUMBER + 1))
  __logi "=== CYCLE ${CYCLE_NUMBER} ==="

  # Check shutdown flag
  if [[ -f "${DAEMON_SHUTDOWN_FLAG}" ]]; then
   __logi "Shutdown flag detected, exiting gracefully"
   rm -f "${DAEMON_SHUTDOWN_FLAG}"
   break
  fi

  # Reset processing duration
  PROCESSING_DURATION=0
  HAD_UPDATES=false

  # Check API for updates
  local PROCESSING_SUCCESS=false
  if __check_api_for_updates; then
   HAD_UPDATES=true
   # Process data
   if __process_api_data; then
    CONSECUTIVE_ERRORS=0
    PROCESSING_SUCCESS=true
    PROCESSING_DURATION="${PROCESSING_DURATION:-0}"
    __logi "Cycle ${CYCLE_NUMBER} completed successfully in ${PROCESSING_DURATION} seconds"
   else
    CONSECUTIVE_ERRORS=$((CONSECUTIVE_ERRORS + 1))
    __loge "Cycle ${CYCLE_NUMBER} failed (${CONSECUTIVE_ERRORS}/${MAX_CONSECUTIVE_ERRORS})"

    if [[ ${CONSECUTIVE_ERRORS} -ge ${MAX_CONSECUTIVE_ERRORS} ]]; then
     __loge "Too many consecutive errors, exiting"
     __create_failed_marker "${ERROR_GENERAL}" \
      "Daemon exited after ${MAX_CONSECUTIVE_ERRORS} consecutive errors" \
      "Check logs and restart daemon"
     break
    fi
   fi
  else
   __logd "No updates available"
  fi

  # Calculate sleep time based on processing duration
  local SLEEP_TIME=0
  if [[ "${HAD_UPDATES}" == "true" ]] && [[ "${PROCESSING_SUCCESS}" == "true" ]]; then
   # Had updates and processing succeeded: sleep = DAEMON_SLEEP_INTERVAL - processing_time
   # If processing took >= DAEMON_SLEEP_INTERVAL, sleep = 0 (continue immediately)
   SLEEP_TIME=$((DAEMON_SLEEP_INTERVAL - PROCESSING_DURATION))
   if [[ ${SLEEP_TIME} -lt 0 ]]; then
    SLEEP_TIME=0
   fi
   if [[ ${SLEEP_TIME} -gt 0 ]]; then
    __logd "Processed in ${PROCESSING_DURATION}s, sleeping for ${SLEEP_TIME}s (remaining of ${DAEMON_SLEEP_INTERVAL}s interval)"
   else
    __logd "Processed in ${PROCESSING_DURATION}s (>= ${DAEMON_SLEEP_INTERVAL}s), continuing immediately"
   fi
  else
   # No updates or processing failed: sleep full interval
   SLEEP_TIME="${DAEMON_SLEEP_INTERVAL}"
   if [[ "${HAD_UPDATES}" == "true" ]]; then
    __logd "Processing failed, sleeping for ${SLEEP_TIME} seconds before retry"
   else
    __logd "No updates, sleeping for ${SLEEP_TIME} seconds"
   fi
  fi

  # Sleep before next cycle (if needed)
  if [[ ${SLEEP_TIME} -gt 0 ]]; then
   sleep "${SLEEP_TIME}"
  fi
 done

 __log_finish
}

# Cleanup on exit
function __daemon_cleanup {
 __log_start
 __logi "=== DAEMON CLEANUP ==="
 __release_lock
 rm -f "${DAEMON_SHUTDOWN_FLAG}"
 __logi "Daemon stopped"
 __log_finish
}

######
# MAIN

function main() {
 if [[ "${BASH_DEBUG:-}" == "true" ]] || [[ "${BASH_DEBUG:-}" == "1" ]]; then
  set -xv
 fi

 __log_start
 __logi "=== OSM NOTES API DAEMON STARTING ==="
 __logi "Version: ${VERSION}"
 __logi "Process ID: $$"
 __logi "Temporary directory: ${TMP_DIR}"

 if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
  __show_help
 fi

 # Acquire lock (singleton)
 if ! __acquire_lock; then
  __loge "Failed to acquire lock, daemon may already be running"
  exit 1
 fi

 # Initialize daemon (once)
 __daemon_init

 # Setup signal handlers
 __setup_signal_handlers

 # Setup exit trap for cleanup
 trap '__daemon_cleanup' EXIT

 # Main loop
 __daemon_loop

 __logw "Daemon finished."
 __log_finish
}

# Start logger
if [[ ! -t 1 ]]; then
 export LOG_FILE="${LOG_FILENAME}"
 {
  __start_logger
  main "$@"
 } >> "${LOG_FILENAME}" 2>&1
else
 __start_logger
 main "$@"
fi
