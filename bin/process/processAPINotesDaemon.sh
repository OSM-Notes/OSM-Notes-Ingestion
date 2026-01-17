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
#   - systemd: See examples/systemd/osm-notes-ingestion-daemon.service (recommended)
#
# Author: Andres Gomez (AngocA)
# Version: 2026-01-16
VERSION="2026-01-16"

# IMPORTANT: This daemon sources processAPINotes.sh to reuse all its functions
# The daemon adds daemon-specific functionality (looping, signal handling, etc.)
# but uses the same processing logic as processAPINotes.sh to ensure consistency

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

# Load path configuration functions
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/bin/lib/pathConfigurationFunctions.sh"

# Initialize all directories (logs, temp, locks)
__init_directories "${BASENAME}"

# Daemon configuration
declare -i DAEMON_SLEEP_INTERVAL="${DAEMON_SLEEP_INTERVAL:-60}"
declare DAEMON_SHUTDOWN_FLAG="${LOCK_DIR}/${BASENAME}_shutdown"
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

 local START_DATE
 START_DATE=$(date '+%Y-%m-%d %H:%M:%S' 2> /dev/null || echo 'unknown')
 cat > "${LOCK}" << EOF
PID: $$
Process: ${BASENAME}
Started: ${START_DATE}
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
 # Check specifically for processPlanetNotes.sh (not processCheckPlanetNotes.sh)
 if pgrep -f "processPlanetNotes\.sh" > /dev/null 2>&1; then
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
# Only define if not already set (e.g., when sourced from processAPINotes.sh)
# This function uses __createFunctionToGetCountry from functionsProcess.sh
# which handles both stub and full function creation correctly.
if ! declare -f __ensureGetCountryFunction > /dev/null 2>&1; then
 function __ensureGetCountryFunction {
  __log_start
  __logd "Checking if get_country function exists..."

  local FUNCTION_EXISTS
  FUNCTION_EXISTS=$(PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM pg_proc WHERE proname = 'get_country' AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');" 2> /dev/null | grep -E '^[0-9]+$' | tail -1 || echo "0")
  local COUNTRIES_TABLE_EXISTS
  COUNTRIES_TABLE_EXISTS=$(PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -Atq -c "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'countries');" 2> /dev/null | grep -E '^[tf]$' | tail -1 || echo "f")

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
fi

# Validate historical data and recover if needed
# This function is equivalent to __validateHistoricalDataAndRecover in processAPINotes.sh
# It validates historical data and calls __recover_from_gaps if needed
function __validateHistoricalDataAndRecover {
 __log_start
 __logi "Base tables found. Validating historical data..."

 # Check if base tables exist before validating
 # BASE_TABLES_EXIST=0 means tables exist, 1 means missing
 if [[ "${BASE_TABLES_EXIST:-1}" -ne 0 ]]; then
  __logd "Base tables missing, skipping historical data validation"
  __log_finish
  return 0
 fi

 # Validate historical data (equivalent to __checkHistoricalData in processAPINotes.sh)
 # Note: __checkHistoricalData is defined in functionsProcess.sh and validates
 # that we have at least 30 days of historical data
 set +e
 trap '' ERR
 # shellcheck disable=SC2310
 # Function is invoked in if condition intentionally
 if ! __checkHistoricalData; then
  :
 fi
 local HIST_VALIDATION_RESULT=$?
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

 if [[ "${HIST_VALIDATION_RESULT}" -ne 0 ]]; then
  __logw "Historical data validation failed, but continuing in daemon mode"
  __logw "This may indicate a fresh database or incomplete historical data"
  __log_finish
  return 0
 fi

 __logi "Historical data validation passed. ProcessAPI can continue safely."

 # Recover from gaps (equivalent to __recover_from_gaps in processAPINotes.sh)
 # Note: __recover_from_gaps is defined in processAPINotes.sh and is available
 # since we source that script at line 123
 # shellcheck disable=SC2310
 # Function is invoked in if condition intentionally
 if ! __recover_from_gaps; then
  __logw "Gap recovery check failed, but continuing in daemon mode"
  __logw "This will be retried on next cycle"
 fi

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
  # shellcheck disable=SC2310
  # Function is invoked in if condition intentionally
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
 # shellcheck disable=SC2154
 # Variables are assigned dynamically within the trap handler
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
 # shellcheck disable=SC2154
 # ERROR_GENERAL is assigned dynamically
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
  exit "${ERROR_GENERAL}";
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
 # shellcheck disable=SC2310
 # Function is invoked in if condition intentionally
 if ! __checkBaseTables; then
  :
 fi
 local RET_FUNC_FILE="${TMP_DIR}/.ret_func_$$"
 if [[ -f "${RET_FUNC_FILE}" ]]; then
  local FILE_RET_FUNC
  FILE_RET_FUNC=$(head -1 "${RET_FUNC_FILE}" 2> /dev/null || echo "")
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
  __logw "Base tables missing. This may be a fresh database."
  __logw "Daemon will attempt to load initial data on first cycle."
  __logw "If this persists, check that processPlanetNotes.sh --base can run successfully."
  # Don't exit - allow daemon to continue and try to auto-initialize
  # The __process_api_data function will detect empty DB and activate processPlanet --base
 fi

 if [[ "${RET_FUNC}" -eq 0 ]]; then
  __validateHistoricalDataAndRecover
 fi

 set -e
 set -E

 # Create ENUMs first (needed for API tables, can be created independently)
 # ENUMs are created with IF NOT EXISTS, so safe to create even if they already exist
 # This matches processAPINotes.sh behavior (ENUMs are created by processPlanetNotes.sh --base,
 # but we create them here too to ensure API tables can be created even if base tables don't exist)
 __logi "Ensuring ENUMs exist (needed for API tables)..."
 local ENUMS_SCRIPT="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_21_createBaseTables_enum.sql"
 if [[ -f "${ENUMS_SCRIPT}" ]]; then
  PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
   -f "${ENUMS_SCRIPT}" 2> /dev/null || {
   __logw "Failed to create ENUMs (may already exist)"
  }
  __logi "ENUMs ensured (created or already exist)"
 else
  __logw "ENUMs script not found: ${ENUMS_SCRIPT}"
  __logw "API tables may fail if ENUMs don't exist"
 fi

 # Prepare API tables (create if needed, truncate if exist)
 # API tables need ENUMs (created above), but don't need base tables
 # This matches processAPINotes.sh behavior (always creates API tables)
 __logi "Preparing API tables..."
 __prepareApiTables

 # Create properties table (max_note_timestamp can be created independently)
 # max_note_timestamp is needed even if base tables don't exist yet
 # This matches processAPINotes.sh behavior (always creates properties table)
 __logi "Checking properties table..."
 __createPropertiesTable

 # Ensure functions and procedures exist
 # get_country can be created as stub if countries table doesn't exist
 # Procedures depend on base tables, but can be created (they'll fail at runtime if tables don't exist)
 # This matches processAPINotes.sh behavior (always creates functions and procedures)
 __logi "Checking functions and procedures..."
 __ensureGetCountryFunction
 __createProcedures

 # Get initial timestamp
 LAST_PROCESSED_TIMESTAMP=$(psql -d "${DBNAME}" -Atq -c \
  "SELECT TO_CHAR(timestamp, E'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') FROM max_note_timestamp" \
  2> /dev/null | head -1 || echo "")

 # Store RET_FUNC for use in daemon loop
 export BASE_TABLES_EXIST="${RET_FUNC}"

 __logi "Daemon initialized successfully"
 __logi "Last processed timestamp: ${LAST_PROCESSED_TIMESTAMP:-none}"
 __logi "Base tables exist: ${BASE_TABLES_EXIST}"
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

 if curl -s --connect-timeout 10 --max-time 10 -H "User-Agent: ${DOWNLOAD_USER_AGENT:-OSM-Notes-Ingestion/1.0}" -o "${TEMP_CHECK_FILE}" "${CHECK_URL}" 2> /dev/null; then
  # Check if there are notes in the XML
  local NOTE_COUNT
  NOTE_COUNT=$(grep -c '<note ' "${TEMP_CHECK_FILE}" 2> /dev/null || echo "0")
  # Remove any whitespace/newlines from the count
  NOTE_COUNT=$(echo "${NOTE_COUNT}" | tr -d '[:space:]')
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

 # Check if database is empty before attempting to download
 # This prevents errors and allows automatic activation of processPlanet --base
 # First check if tables exist, then check if they have data
 local TIMESTAMP_TABLE_EXISTS
 TIMESTAMP_TABLE_EXISTS=$(psql -d "${DBNAME}" -Atq -c \
  "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'max_note_timestamp'" \
  2> /dev/null | grep -E '^[0-9]+$' | tail -1 || echo "0")

 local TIMESTAMP_COUNT=0
 if [[ "${TIMESTAMP_TABLE_EXISTS}" == "1" ]]; then
  TIMESTAMP_COUNT=$(psql -d "${DBNAME}" -Atq -c \
   "SELECT COUNT(*) FROM max_note_timestamp" 2> /dev/null | grep -E '^[0-9]+$' | tail -1 || echo "0")
 fi

 local NOTES_TABLE_EXISTS
 NOTES_TABLE_EXISTS=$(psql -d "${DBNAME}" -Atq -c \
  "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'notes'" \
  2> /dev/null | grep -E '^[0-9]+$' | tail -1 || echo "0")

 local NOTES_COUNT=0
 if [[ "${NOTES_TABLE_EXISTS}" == "1" ]]; then
  NOTES_COUNT=$(psql -d "${DBNAME}" -Atq -c \
   "SELECT COUNT(*) FROM notes" 2> /dev/null | grep -E '^[0-9]+$' | tail -1 || echo "0")
 fi

 # Activate Planet --base if database is empty:
 # 1. max_note_timestamp table doesn't exist OR is empty (no rows), OR
 # 2. LAST_PROCESSED_TIMESTAMP is empty, OR
 # 3. notes table doesn't exist OR is empty (fresh database)
 if [[ "${TIMESTAMP_TABLE_EXISTS}" == "0" ]] || [[ "${TIMESTAMP_COUNT}" == "0" ]] || [[ -z "${LAST_PROCESSED_TIMESTAMP}" ]] || [[ "${NOTES_TABLE_EXISTS}" == "0" ]] || [[ "${NOTES_COUNT}" == "0" ]]; then
  __logw "Database appears to be empty (no max_note_timestamp or empty table)"
  __logw "Activating processPlanetNotes.sh --base to load initial data"
  __logi "Executing: ${NOTES_SYNC_SCRIPT} --base"

  # Clean up any stale lock files
  local PLANET_LOCK_FILE="${LOCK_DIR}/processPlanetNotes.lock"
  if [[ -f "${PLANET_LOCK_FILE}" ]]; then
   __logw "Removing stale lock file: ${PLANET_LOCK_FILE}"
   if ! rm -f "${PLANET_LOCK_FILE}" 2> /dev/null; then
    if command -v sudo > /dev/null 2>&1; then
     sudo rm -f "${PLANET_LOCK_FILE}" 2> /dev/null || true
    fi
   fi
  fi

  # Clear lock-related variables to allow processPlanetNotes.sh to initialize
  # its own lock file. This prevents conflicts when the daemon's lock file
  # is still active.
  unset LOCK
  unset LOCK_DIR
  unset TMP_DIR
  unset LOG_DIR
  unset LOG_FILENAME

  # Ensure required environment variables are set
  export SKIP_XML_VALIDATION="${SKIP_XML_VALIDATION:-true}"
  export LOG_LEVEL="${LOG_LEVEL:-ERROR}"
  export DBNAME="${DBNAME}"
  export DB_USER="${DB_USER:-}"
  export DB_HOST="${DB_HOST:-}"
  export DB_PORT="${DB_PORT:-}"

  # Execute processPlanetNotes.sh --base to load initial data
  "${NOTES_SYNC_SCRIPT}" --base
  local PLANET_BASE_EXIT_CODE=$?

  if [[ ${PLANET_BASE_EXIT_CODE} -eq 0 ]]; then
   __logi "Planet base load completed successfully"
   # Reinitialize directories after processPlanetNotes.sh execution
   # This is critical because we unset TMP_DIR, LOCK_DIR, etc. before
   # calling processPlanetNotes.sh to avoid lock conflicts, but these
   # variables are needed for the next cycle (e.g., __check_api_for_updates)
   __logd "Reinitializing directories after Planet base load"
   __init_directories "${BASENAME}"
   # Update DAEMON_SHUTDOWN_FLAG path after reinitializing LOCK_DIR
   DAEMON_SHUTDOWN_FLAG="${LOCK_DIR}/${BASENAME}_shutdown"
   # Ensure max_note_timestamp table exists after Planet load
   # This is critical because the table may not have been created during daemon_init
   # if base tables didn't exist at that time
   __logi "Ensuring max_note_timestamp table exists..."
   __createPropertiesTable
   # Ensure procedures exist after Planet load
   # Procedures are needed for API processing (insert_note, insert_note_comment)
   __logi "Ensuring procedures exist after Planet load..."
   __ensureGetCountryFunction
   __createProcedures
   __logi "Updating timestamp after Planet base load"
   __updateLastValue
   # Update LAST_PROCESSED_TIMESTAMP for next cycle
   LAST_PROCESSED_TIMESTAMP=$(psql -d "${DBNAME}" -Atq -c \
    "SELECT TO_CHAR(timestamp, E'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') FROM max_note_timestamp" \
    2> /dev/null | head -1 || echo "")
   __logi "Database initialized. Next cycle will process API updates."
   local CYCLE_DURATION
   CYCLE_DURATION=$(($(date +%s) - CYCLE_START_TIME))
   PROCESSING_DURATION="${CYCLE_DURATION}"
   __logi "Processing completed in ${CYCLE_DURATION} seconds"
   __log_finish
   return 0
  else
   __loge "Planet base load failed with exit code: ${PLANET_BASE_EXIT_CODE}"
   __loge "Check processPlanetNotes.sh logs for details"
   __loge "Failed execution marker: /tmp/processPlanetNotes_failed_execution"
   __log_finish
   return 1
  fi
 fi

 # Create API tables and procedures before processing (same as processAPINotes.sh)
 # This ensures tables and procedures exist before processing API data
 # This matches processAPINotes.sh behavior (lines 1296-1299)
 __logi "Ensuring API tables and procedures exist before processing..."
 __prepareApiTables
 __ensureGetCountryFunction
 __createProcedures

 # Download data (only if database is not empty)
 local API_DOWNLOAD_RESULT=0
 # shellcheck disable=SC2310
 # Function is invoked in if condition intentionally
 if ! __getNewNotesFromApi; then
  API_DOWNLOAD_RESULT=$?
 else
  API_DOWNLOAD_RESULT=0
 fi

 if [[ ${API_DOWNLOAD_RESULT} -ne 0 ]]; then
  __loge "Failed to download notes from API (error code: ${API_DOWNLOAD_RESULT})"
  __log_finish
  return 1
 fi

 # Validate file
 __validateApiNotesFile

 # Validate and process XML (equivalent to processAPINotes.sh flow)
 # This function handles: validation, counting, processing, insertion
 # It's equivalent to: __validateAndProcessApiXml in processAPINotes.sh
 declare -i RESULT
 RESULT=$(wc -l < "${API_NOTES_FILE}" 2> /dev/null || echo "0")
 if [[ "${RESULT}" -ne 0 ]]; then
  if [[ "${SKIP_XML_VALIDATION}" != "true" ]]; then
   __validateApiNotesXMLFileComplete
  else
   __logw "WARNING: XML validation SKIPPED (SKIP_XML_VALIDATION=true)"
  fi
  __countXmlNotesAPI "${API_NOTES_FILE}"

  if [[ "${TOTAL_NOTES}" -gt 0 ]]; then
   __logi "Processing ${TOTAL_NOTES} notes"

   if [[ "${TOTAL_NOTES}" -ge "${MAX_NOTES}" ]]; then
    __logw "Too many notes (${TOTAL_NOTES} >= ${MAX_NOTES}), triggering Planet sync"
    __logi "Executing: ${NOTES_SYNC_SCRIPT}"
    # Clean up any stale lock files from previous executions
    # This prevents permission issues when daemon (user: notes) tries to run
    # processPlanetNotes.sh that was previously run by another user
    local PLANET_LOCK_FILE="${LOCK_DIR}/processPlanetNotes.lock"
    if [[ -f "${PLANET_LOCK_FILE}" ]]; then
     __logw "Removing stale lock file: ${PLANET_LOCK_FILE}"
     # Try to remove with sudo if regular rm fails (permission issues)
     if ! rm -f "${PLANET_LOCK_FILE}" 2> /dev/null; then
      __logw "Could not remove lock file with regular rm, trying with sudo"
      if command -v sudo > /dev/null 2>&1; then
       sudo rm -f "${PLANET_LOCK_FILE}" 2> /dev/null || true
      else
       __logw "sudo not available, lock file may cause issues"
      fi
     fi
    fi

    # Clear lock-related variables to allow processPlanetNotes.sh to initialize
    # its own lock file. This prevents conflicts when the daemon's lock file
    # is still active.
    unset LOCK
    unset LOCK_DIR
    unset TMP_DIR
    unset LOG_DIR
    unset LOG_FILENAME

    # Ensure required environment variables are set for processPlanetNotes.sh
    # SKIP_XML_VALIDATION=true speeds up processing (validation is optional)
    export SKIP_XML_VALIDATION="${SKIP_XML_VALIDATION:-true}"
    # Preserve LOG_LEVEL from daemon
    export LOG_LEVEL="${LOG_LEVEL:-ERROR}"
    # Ensure DBNAME and other database variables are available
    export DBNAME="${DBNAME}"
    export DB_USER="${DB_USER:-}"
    export DB_HOST="${DB_HOST:-}"
    export DB_PORT="${DB_PORT:-}"
    # Execute processPlanetNotes.sh and capture exit code explicitly
    # This ensures we detect failures even if the script exits early
    "${NOTES_SYNC_SCRIPT}"
    local PLANET_SYNC_EXIT_CODE=$?
    if [[ ${PLANET_SYNC_EXIT_CODE} -eq 0 ]]; then
     __logi "Planet sync completed successfully"
     # Reinitialize directories after processPlanetNotes.sh execution
     # This is critical because we unset TMP_DIR, LOCK_DIR, etc. before
     # calling processPlanetNotes.sh to avoid lock conflicts, but these
     # variables are needed for the next cycle (e.g., __check_api_for_updates)
     __logd "Reinitializing directories after Planet sync"
     __init_directories "${BASENAME}"
     # Update DAEMON_SHUTDOWN_FLAG path after reinitializing LOCK_DIR
     DAEMON_SHUTDOWN_FLAG="${LOCK_DIR}/${BASENAME}_shutdown"
     # After Planet sync, update timestamp to prevent infinite loop
     # processPlanetNotes.sh doesn't update max_note_timestamp, so we need to do it here
     __logi "Updating timestamp after Planet sync"
     __updateLastValue
    else
     __loge "Planet sync failed with exit code: ${PLANET_SYNC_EXIT_CODE}"
     __loge "Check processPlanetNotes.sh logs for details"
     __loge "Failed execution marker: /tmp/processPlanetNotes_failed_execution"
     # Check if lock file permission issue was the cause
     if [[ -f "${PLANET_LOCK_FILE}" ]] && ! [[ -w "${PLANET_LOCK_FILE}" ]]; then
      __loge "Lock file permission issue detected: ${PLANET_LOCK_FILE}"
      local LOCK_OWNER
      LOCK_OWNER=$(stat -c '%U:%G' "${PLANET_LOCK_FILE}" 2> /dev/null || echo 'unknown')
      __loge "Lock file owner: ${LOCK_OWNER}"
      local CURRENT_USER
      CURRENT_USER=$(whoami 2> /dev/null || echo 'unknown')
      __loge "Current user: ${CURRENT_USER}"
     fi
     __log_finish
     return 1
    fi
   else
    # Process normally (equivalent to __processXMLorPlanet + insertion in processAPINotes.sh)
    __processXMLorPlanet
    __insertNewNotesAndComments
    __loadApiTextComments
   fi
  else
   __logi "No notes to process"
  fi
 else
  __logi "No notes file or file is empty"
 fi

 # Check and log gaps (equivalent to __check_and_log_gaps in processAPINotes.sh)
 # This helps identify data integrity issues
 # Only check if base tables exist (data_gaps table may not exist if tables are missing)
 if [[ "${BASE_TABLES_EXIST:-0}" -eq 0 ]]; then
  __logd "Checking and logging gaps from database"
  local GAP_TABLE_EXISTS
  GAP_TABLE_EXISTS=$(psql -d "${DBNAME}" -Atq -c \
   "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'data_gaps'" \
   2> /dev/null | grep -E '^[0-9]+$' | tail -1 || echo "0")

  if [[ "${GAP_TABLE_EXISTS}" == "1" ]]; then
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
   local GAP_FILE="${LOG_DIR}/processAPINotesDaemon_gaps.log"
   psql -d "${DBNAME}" -Atq -c "${GAP_QUERY}" > "${GAP_FILE}" 2> /dev/null || true
   if [[ -f "${GAP_FILE}" ]] && [[ -s "${GAP_FILE}" ]]; then
    __logw "Data gaps detected, see: ${GAP_FILE}"
   fi
  fi
 fi

 # Truncate API tables after data has been inserted into main tables
 # This prevents accumulation of data in API tables across cycles
 # IMPORTANT: This must be done BEFORE updating timestamp to ensure tables are always cleaned
 # even if there are errors in timestamp update
 # Note: Tables may not exist if processPlanetNotes.sh was executed (it drops API tables)
 # So we check if tables exist before attempting to truncate
 __logd "Truncating API tables after processing"
 local API_TABLES_EXIST
 API_TABLES_EXIST=$(psql -d "${DBNAME}" -Atq -c \
  "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('notes_api', 'note_comments_api', 'note_comments_text_api')" \
  2> /dev/null | grep -E '^[0-9]+$' | tail -1 || echo "0")

 if [[ "${API_TABLES_EXIST}" == "3" ]]; then
  psql -d "${DBNAME}" -v ON_ERROR_STOP=1 << EOF
    TRUNCATE TABLE notes_api CASCADE;
    TRUNCATE TABLE note_comments_api CASCADE;
    TRUNCATE TABLE note_comments_text_api CASCADE;
EOF
 else
  __logd "API tables do not exist (likely dropped by processPlanetNotes.sh), skipping truncate"
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

  # Prepare API tables at the start of each cycle
  # This ensures tables are clean before loading new data
  # This is critical to prevent data accumulation across cycles
  # Skip if base tables don't exist (they will be created by processPlanet --base)
  if [[ "${BASE_TABLES_EXIST:-1}" -eq 0 ]]; then
   __logd "Preparing API tables at start of cycle ${CYCLE_NUMBER}"
   __prepareApiTables
  else
   __logd "Skipping API tables preparation - base tables missing, will be created by processPlanet --base"
  fi

  # Check API for updates
  local PROCESSING_SUCCESS=false
  # shellcheck disable=SC2310
  # Function is invoked in if condition intentionally
  if __check_api_for_updates; then
   HAD_UPDATES=true
   # Process data
   # shellcheck disable=SC2310
   # Function is invoked in if condition intentionally
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
 # shellcheck disable=SC2310
 # Function is invoked in if condition intentionally
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

# Check for help option before starting logger (so help output is visible)
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
 __show_help
fi

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
