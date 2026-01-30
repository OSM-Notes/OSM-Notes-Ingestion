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
#   Monitor: tail -f /var/log/osm-notes-ingestion/processing/processAPINotes.log
#   (or /tmp/osm-notes-ingestion/logs/processing/processAPINotes.log in fallback mode)
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
# Dependencies: PostgreSQL, AWK, curl, lib/osm-common/
#
# For contributing: shellcheck -x -o all processAPINotes.sh && shfmt -w -i 1 -sr -bn processAPINotes.sh
#
# Author: Andres Gomez (AngocA)
# Version: 2026-01-17
VERSION="2026-01-17"

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
# Skip setsid re-execution if script is being sourced (not executed directly)
# When sourced, ${BASH_SOURCE[0]} != ${0}
if [[ "${BASH_SOURCE[0]}" == "${0}" ]] \
 && [[ -z "${RUNNING_IN_SETSID:-}" ]] \
 && command -v setsid > /dev/null 2>&1; then
 # Only show message if there's a TTY (not from cron)
 if [[ -t 1 ]]; then
  RESTART_MESSAGE=$(date '+%Y%m%d_%H:%M:%S' || true)
  echo "${RESTART_MESSAGE} INFO: Auto-restarting with setsid for SIGHUP protection" >&2
  unset RESTART_MESSAGE
 fi
 export RUNNING_IN_SETSID=1
 # Ensure PATH is exported before re-execution (critical for hybrid mock mode)
 # This is especially important in hybrid mock mode where PATH contains mock commands
 export PATH="${PATH}"
 # Get the script name and all arguments
 SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
 # Re-execute with setsid to create new session (immune to SIGHUP)
 # setsid preserves environment variables, but we explicitly export PATH to ensure
 # mock commands in hybrid mode are available after re-execution
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

# Load path configuration functions
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/bin/lib/pathConfigurationFunctions.sh"

# Initialize all directories (logs, temp, locks)
# Only if not already set (e.g., when sourced from daemon)
if [[ -z "${TMP_DIR:-}" ]]; then
 __init_directories "${BASENAME}"
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
##
# Shows help information for processAPINotes.sh script
# Displays script version, description, usage instructions, and environment variable
# configuration options. Exits with ERROR_HELP_MESSAGE after displaying help.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   Exits with ERROR_HELP_MESSAGE after displaying help
#
# Error codes:
#   ERROR_HELP_MESSAGE: Success - Help displayed successfully (exits script)
#
# Error conditions:
#   ERROR_HELP_MESSAGE: Success - Help displayed and script exited
#
# Context variables:
#   Reads:
#     - VERSION: Script version (required)
#     - ERROR_HELP_MESSAGE: Error code for help message (defined in calling script)
#   Sets: None
#   Modifies: None
#
# Side effects:
#   - Writes help text to stdout
#   - Exits script with ERROR_HELP_MESSAGE
#   - No file, database, or network operations
#
# Notes:
#   - Displays script version and description
#   - Shows usage instructions (no parameters for regular execution)
#   - Documents environment variables (CLEAN, LOG_LEVEL)
#   - Mentions processPlanetNotes.sh integration
#   - Exits script after displaying help (does not return)
#   - Used when script is called with --help or -h
#
# Example:
#   __show_help
#   # Displays help and exits with ERROR_HELP_MESSAGE
#
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
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

##
# Checks prerequisites to run the script
# Validates script parameters, checks required commands, validates SQL script files,
# validates notes sync script, and validates XML dates (if validation enabled). Exits
# script with ERROR_INVALID_ARGUMENT if invalid parameter, ERROR_MISSING_LIBRARY if
# required files missing. Part of script initialization workflow.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   Exits with ERROR_INVALID_ARGUMENT if invalid parameter
#   Exits with ERROR_MISSING_LIBRARY if required files missing
#   Returns 0 if all prerequisites validated successfully
#
# Error codes:
#   0: Success - All prerequisites validated successfully
#   ERROR_INVALID_ARGUMENT: Failure - Invalid PROCESS_TYPE parameter (exits script)
#   ERROR_MISSING_LIBRARY: Failure - Required command, SQL file, or script missing (exits script)
#
# Error conditions:
#   0: Success - All prerequisites validated successfully
#   ERROR_INVALID_ARGUMENT: Invalid PROCESS_TYPE - Must be empty string, --help, or -h (exits script)
#   ERROR_MISSING_LIBRARY: Required command missing - __checkPrereqsCommands failed (exits script)
#   ERROR_MISSING_LIBRARY: SQL file missing - __validate_sql_structure failed (exits script)
#   ERROR_MISSING_LIBRARY: Notes sync script missing - __validate_input_file failed (exits script)
#   ERROR_MISSING_LIBRARY: XML date validation failed - __validate_xml_dates failed (exits script)
#
# Context variables:
#   Reads:
#     - PROCESS_TYPE: Process type parameter (required, must be empty, --help, or -h)
#     - NOTES_SYNC_SCRIPT: Path to notes sync script (required)
#     - POSTGRES_12_DROP_API_TABLES: Path to SQL script (required)
#     - POSTGRES_21_CREATE_API_TABLES: Path to SQL script (required)
#     - POSTGRES_23_CREATE_PROPERTIES_TABLE: Path to SQL script (required)
#     - POSTGRES_31_LOAD_API_NOTES: Path to SQL script (required)
#     - POSTGRES_32_INSERT_NEW_NOTES_AND_COMMENTS: Path to SQL script (required)
#     - POSTGRES_33_INSERT_NEW_TEXT_COMMENTS: Path to SQL script (required)
#     - POSTGRES_34_UPDATE_LAST_VALUES: Path to SQL script (required)
#     - API_NOTES_FILE: Path to API notes XML file (optional, validated if exists)
#     - SKIP_XML_VALIDATION: If "true", skips XML validation (optional)
#     - ERROR_INVALID_ARGUMENT: Error code for invalid arguments (defined in calling script)
#     - ERROR_MISSING_LIBRARY: Error code for missing files (defined in calling script)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies: None
#
# Side effects:
#   - Validates PROCESS_TYPE parameter
#   - Checks required commands (__checkPrereqsCommands)
#   - Validates SQL script files (__validate_sql_structure)
#   - Validates notes sync script (__validate_input_file)
#   - Validates XML dates if file exists and validation enabled (__validate_xml_dates)
#   - Writes log messages to stderr
#   - Exits script with error code on failure
#   - Temporarily disables set -e during command checks
#   - No file, database, or network operations (validation only)
#
# Notes:
#   - Validates all required files before script execution
#   - SQL script validation ensures files are readable and have valid structure
#   - XML date validation is optional (skipped if SKIP_XML_VALIDATION=true)
#   - Critical function: Part of script initialization workflow
#   - Should be called early in script execution (before processing starts)
#   - Exits script immediately on validation failure
#
# Example:
#   export PROCESS_TYPE=""
#   export NOTES_SYNC_SCRIPT="/path/to/processPlanetNotes.sh"
#   export ERROR_INVALID_ARGUMENT=1
#   export ERROR_MISSING_LIBRARY=2
#   __checkPrereqs
#   # Validates all prerequisites, exits on failure
#
# Related: __checkPrereqsCommands() (checks required commands)
# Related: __validate_sql_structure() (validates SQL files)
# Related: __validate_input_file() (validates script files)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
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
 __logd "Checking required commands..."
 __checkPrereqsCommands
 __logd "Required commands check passed"

 ##
 # Detects and recovers from data gaps in recent notes
 # Checks for notes without comments in the last 7 days (potential data integrity issue).
 # Queries database to find notes created after max_note_timestamp minus 7 days that have
 # no associated comments. Logs gap details and optionally triggers recovery. Returns error
 # if large gaps detected (>100 notes).
 #
 # Parameters:
 #   None (uses environment variables)
 #
 # Returns:
 #   0: Success - No gaps detected or gaps are manageable (<100 notes)
 #   1: Failure - Large gaps detected (>100 notes) or query execution failed
 #
 # Error codes:
 #   0: Success - No gaps detected or gaps are manageable
 #   0: Success - max_note_timestamp table does not exist (skips check)
 #   1: Failure - Large gaps detected (>100 notes, requires manual intervention)
 #   1: Failure - Gap query execution failed after retries
 #
 # Error conditions:
 #   0: Success - No gaps detected in recent data
 #   0: Success - Gaps detected but manageable (<100 notes)
 #   0: Success - max_note_timestamp table does not exist (skips check gracefully)
 #   1: Large gaps detected - >100 notes without comments (requires manual intervention)
 #   1: Query execution failed - Database query failed after retries
 #
 # Context variables:
 #   Reads:
 #     - DBNAME: PostgreSQL database name (required)
 #     - PGAPPNAME: PostgreSQL application name (optional)
 #     - TMP_DIR: Temporary directory for temp files (optional, default: /tmp)
 #     - LOG_LEVEL: Controls logging verbosity
 #   Sets: None
 #   Modifies: None
 #
 # Side effects:
 #   - Queries database to check max_note_timestamp table existence
 #   - Queries database to find notes without comments in last 7 days
 #   - Queries database to get sample gap details (up to 10 notes)
 #   - Creates temporary files for query results
 #   - Writes log messages to stderr
 #   - No file, database, or network modifications
 #
 # Notes:
 #   - Checks for notes without comments in last 7 days (data integrity check)
 #   - Uses max_note_timestamp table to determine recent data window
 #   - Skips check gracefully if max_note_timestamp table does not exist
 #   - Logs sample gap details (up to 10 notes) for debugging
 #   - Returns error if large gaps detected (>100 notes)
 #   - Critical function: Part of data integrity validation workflow
 #   - Used before processing API notes to detect data quality issues
 #
 # Example:
 #   export DBNAME="osm_notes"
 #   __recover_from_gaps
 #   # Checks for gaps, logs details, returns 0 if manageable or 1 if large gaps
 #
 # Related: __checkHistoricalData() (validates historical data exists)
 # Related: __validateHistoricalDataAndRecover() (validates and recovers from gaps)
 # Related: STANDARD_ERROR_CODES.md (error code definitions)
 ##
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
 __logd "Validating sync script: ${NOTES_SYNC_SCRIPT}"
 # shellcheck disable=SC2310
 # Function is invoked in if condition intentionally
 if ! __validate_input_file "${NOTES_SYNC_SCRIPT}" "Notes sync script"; then
  __loge "ERROR: Notes sync script validation failed: ${NOTES_SYNC_SCRIPT}"
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 __logd "Sync script validation passed"

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
  __logd "Validating SQL file: ${SQL_FILE}"
  # shellcheck disable=SC2310
  # Function is invoked in if condition intentionally
  if ! __validate_sql_structure "${SQL_FILE}"; then
   __loge "ERROR: SQL file validation failed: ${SQL_FILE}"
   __loge "File path: ${SQL_FILE}"
   __loge "File exists: $([[ -f "${SQL_FILE}" ]] && echo 'yes' || echo 'no')"
   exit "${ERROR_MISSING_LIBRARY}"
  fi
  __logd "SQL file validation passed: ${SQL_FILE}"
 done

 # Validate dates in API notes file if it exists (only if validation is enabled)
 if [[ "${SKIP_XML_VALIDATION}" != "true" ]]; then
  __logi "Validating dates in API notes file..."
  if [[ -f "${API_NOTES_FILE}" ]]; then
   # shellcheck disable=SC2310
   # Function is invoked in if condition intentionally
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
##
# Drops API-related tables from database
# Executes SQL script to drop tables used for API notes processing (notes_api,
# note_comments_api, note_comments_text_api). Uses --pset pager=off to prevent
# blocking on long output. Used during cleanup or before recreating API tables.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   0: Success - API tables dropped successfully
#   Non-zero: Failure - psql command failed
#
# Error codes:
#   0: Success - API tables dropped successfully
#   Non-zero: psql command failed (SQL error, connection error, etc.)
#
# Error conditions:
#   0: Success - SQL script executed successfully
#   Non-zero: psql execution failed (check psql error message)
#
# Context variables:
#   Reads:
#     - DBNAME: PostgreSQL database name (required)
#     - PGAPPNAME: PostgreSQL application name (optional)
#     - POSTGRES_12_DROP_API_TABLES: Path to SQL script (required)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies: None
#
# Side effects:
#   - Executes psql to drop API tables (notes_api, note_comments_api, note_comments_text_api)
#   - Drops all dependent objects (indexes, constraints, etc.)
#   - Writes log messages to stderr
#   - No file or network operations
#
# Notes:
#   - Uses --pset pager=off to prevent blocking on long output
#   - Drops all API-related tables and dependent objects (CASCADE)
#   - Used during cleanup or before recreating API tables
#   - Part of API processing workflow (cleanup after processing)
#   - API tables are temporary staging tables (used only during API processing)
#
# Example:
#   export DBNAME="osm_notes"
#   export POSTGRES_12_DROP_API_TABLES="/path/to/drop_api_tables.sql"
#   __dropApiTables
#
# Related: __createApiTables() (creates API tables)
# Related: __prepareApiTables() (truncates or creates API tables)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
function __dropApiTables {
 __log_start
 __logi "=== DROPPING API TABLES ==="
 __logd "Executing SQL file: ${POSTGRES_12_DROP_API_TABLES}"
 # Use --pset pager=off to prevent opening vi/less for long output
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" --pset pager=off -f "${POSTGRES_12_DROP_API_TABLES}"
 __logi "=== API TABLES DROPPED SUCCESSFULLY ==="
 __log_finish
}

##
# Checks that no processPlanetNotes script is currently running
# Verifies that no instance of processPlanetNotes.sh is running to prevent conflicts
# during API processing. Uses pgrep to find running processes matching the script name.
# Exits script with ERROR_PLANET_PROCESS_IS_RUNNING if a Planet process is found.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   Exits with ERROR_PLANET_PROCESS_IS_RUNNING if Planet process is running
#   Returns 0 if no Planet process is running
#
# Error codes:
#   0: Success - No Planet process is running
#   ERROR_PLANET_PROCESS_IS_RUNNING: Failure - Planet process is currently running (exits script)
#
# Error conditions:
#   0: Success - No Planet process is running
#   ERROR_PLANET_PROCESS_IS_RUNNING: Planet process found - Another instance is running (exits script)
#
# Context variables:
#   Reads:
#     - PROCESS_PLANET_NOTES_SCRIPT: Path to processPlanetNotes.sh script (required)
#     - BASENAME: Script basename for logging (required)
#     - ERROR_PLANET_PROCESS_IS_RUNNING: Error code for Planet process conflict (defined in calling script)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies: None
#
# Side effects:
#   - Executes pgrep to find running Planet processes
#   - Writes log messages to stderr
#   - Exits script with ERROR_PLANET_PROCESS_IS_RUNNING if Planet process found
#   - No file, database, or network operations
#
# Notes:
#   - Prevents conflicts between API processing and Planet processing
#   - Uses pgrep to find processes matching script name (first 15 characters)
#   - Exits script immediately if Planet process is running
#   - Critical function: Prevents concurrent processing conflicts
#   - Should be called before starting API processing
#   - Uses set +e temporarily to handle pgrep errors gracefully
#
# Example:
#   export PROCESS_PLANET_NOTES_SCRIPT="/path/to/processPlanetNotes.sh"
#   export BASENAME="processAPINotes"
#   export ERROR_PLANET_PROCESS_IS_RUNNING=252
#   __checkNoProcessPlanet
#   # Exits if Planet process is running, continues if not
#
# Related: __setupLockFile() (prevents concurrent API processing)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
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

##
# Creates API tables for notes processing
# Creates temporary API tables (notes_api, note_comments_api, note_comments_text_api) used
# for processing incremental API notes. These tables are staging tables that hold API data
# before insertion into main production tables. Tables are created using SQL script.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   0: Success - API tables created successfully
#   Non-zero: Failure - psql command failed
#
# Error codes:
#   0: Success - API tables created successfully
#   Non-zero: psql execution failed (SQL error, connection error, etc.)
#
# Error conditions:
#   0: Success - SQL script executed successfully
#   Non-zero: psql execution failed (ON_ERROR_STOP=1 causes immediate failure)
#
# Context variables:
#   Reads:
#     - DBNAME: PostgreSQL database name (required)
#     - PGAPPNAME: PostgreSQL application name (optional)
#     - POSTGRES_21_CREATE_API_TABLES: Path to SQL script (required)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies: None
#
# Side effects:
#   - Executes psql to create API tables in database
#   - Creates tables: notes_api, note_comments_api, note_comments_text_api
#   - Writes log messages to stderr
#   - No file or network operations
#
# Notes:
#   - Creates temporary staging tables for API data
#   - Tables are used to hold API data before insertion into main tables
#   - Uses ON_ERROR_STOP=1 to fail immediately on SQL errors
#   - Uses --pset pager=off to prevent blocking on long output
#   - Critical function: Required before processing API notes
#   - Tables can be truncated and reused across cycles
#
# Example:
#   export DBNAME="osm_notes"
#   export POSTGRES_21_CREATE_API_TABLES="/path/to/create_api_tables.sql"
#   __createApiTables
#   # Creates notes_api, note_comments_api, note_comments_text_api tables
#
# Related: __prepareApiTables() (truncates or creates API tables)
# Related: __insertNewNotesAndComments() (inserts data from API tables to main tables)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
# Creates tables for notes from API.
##
# Creates temporary API tables for processing incremental API notes
# Creates temporary staging tables (notes_api, note_comments_api, note_comments_text_api)
# that receive incremental API note data before insertion into main tables. These tables
# are used to stage API downloads and process them before moving to production tables.
# Used during API processing workflow.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   0: Success - API tables created successfully
#   Non-zero: Failure - psql command failed
#
# Error codes:
#   0: Success - API tables created successfully
#   Non-zero: psql execution failed (SQL error, connection error, etc.)
#
# Error conditions:
#   0: Success - SQL script executed successfully
#   Non-zero: psql execution failed (ON_ERROR_STOP=1 causes immediate failure)
#
# Context variables:
#   Reads:
#     - DBNAME: PostgreSQL database name (required)
#     - PGAPPNAME: PostgreSQL application name (optional)
#     - POSTGRES_21_CREATE_API_TABLES: Path to SQL script (required)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies: None
#
# Side effects:
#   - Executes psql to create API staging tables (notes_api, note_comments_api, note_comments_text_api)
#   - Writes log messages to stderr
#   - Uses --pset pager=off to prevent blocking on SELECT output
#   - No file or network operations
#
# Notes:
#   - Creates temporary staging tables for API note processing
#   - Tables are truncated or dropped/recreated between processing cycles
#   - Used before downloading and processing incremental API notes
#   - Uses ON_ERROR_STOP=1 to fail immediately on SQL errors
#   - Critical function: Required for API processing workflow
#   - Tables are temporary and can be safely dropped/recreated
#
# Example:
#   export DBNAME="osm_notes"
#   export POSTGRES_21_CREATE_API_TABLES="/path/to/create_api_tables.sql"
#   __createApiTables
#
# Related: __prepareApiTables() (truncates or creates API tables)
# Related: __dropApiTables() (drops API tables)
# Related: __insertNewNotesAndComments() (moves data from API tables to main tables)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
function __createApiTables {
 __log_start
 __logi "=== CREATING API TABLES ==="
 __logd "Executing SQL file: ${POSTGRES_21_CREATE_API_TABLES}"
 # Use --pset pager=off to prevent opening vi/less for long output
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 --pset pager=off -f "${POSTGRES_21_CREATE_API_TABLES}"
 __logi "=== API TABLES CREATED SUCCESSFULLY ==="
 __log_finish
}

##
# Creates properties table (max_note_timestamp)
# Creates or updates the max_note_timestamp table which stores the most recent timestamp
# of processed notes. This table is used to determine the starting point for incremental
# API downloads. The table has a single row (id=1) with a timestamp constraint.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   0: Success - Properties table created/updated successfully
#   Non-zero: Failure - psql command failed
#
# Error codes:
#   0: Success - Properties table created/updated successfully
#   Non-zero: psql execution failed (SQL error, connection error, etc.)
#
# Error conditions:
#   0: Success - SQL script executed successfully
#   Non-zero: psql execution failed (ON_ERROR_STOP=1 causes immediate failure)
#
# Context variables:
#   Reads:
#     - DBNAME: PostgreSQL database name (required)
#     - PGAPPNAME: PostgreSQL application name (optional)
#     - POSTGRES_23_CREATE_PROPERTIES_TABLE: Path to SQL script (required)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies: None
#
# Side effects:
#   - Executes psql to create/update max_note_timestamp table
#   - Creates table if it doesn't exist
#   - Updates timestamp if table exists (uses max from notes/note_comments tables)
#   - Inserts default timestamp if base tables don't exist (empty database scenario)
#   - Writes log messages to stderr
#   - No file or network operations
#
# Notes:
#   - Creates single-row table with id=1 constraint
#   - Timestamp is calculated from max(created_at, closed_at) from notes and note_comments
#   - Handles empty database scenario (sets default timestamp if base tables don't exist)
#   - Uses ON_ERROR_STOP=1 to fail immediately on SQL errors
#   - Uses --pset pager=off to prevent blocking on SELECT output
#   - Critical function: Required for incremental API sync (determines download start point)
#   - Table can be created independently of base tables
#
# Example:
#   export DBNAME="osm_notes"
#   export POSTGRES_23_CREATE_PROPERTIES_TABLE="/path/to/create_properties_table.sql"
#   __createPropertiesTable
#   # Creates/updates max_note_timestamp table
#
# Related: __updateLastValue() (updates timestamp after processing)
# Related: __getNewNotesFromApi() (uses timestamp for API download)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
# Creates table properties during the execution.
function __createPropertiesTable {
 __log_start
 __logi "=== CREATING PROPERTIES TABLE ==="
 __logd "Executing SQL file: ${POSTGRES_23_CREATE_PROPERTIES_TABLE}"
 # Use --pset pager=off to prevent opening vi/less for long output
 # This prevents blocking when SELECT statements produce output
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 --pset pager=off \
  -f "${POSTGRES_23_CREATE_PROPERTIES_TABLE}"
 __logi "=== PROPERTIES TABLE CREATED SUCCESSFULLY ==="
 __log_finish
}

##
# Ensures get_country function exists before creating procedures
# Checks if get_country function exists in database and creates it if missing. The procedures
# (insert_note, insert_note_comment) require get_country to exist. If get_country exists but
# countries table does not, recreates the function as stub to prevent procedure creation failures.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   0: Success - get_country function exists or was created successfully
#   Non-zero: Failure - Function creation failed
#
# Error codes:
#   0: Success - get_country function exists or was created successfully
#   Non-zero: Function creation failed (__createFunctionToGetCountry returned error)
#
# Error conditions:
#   0: Success - Function exists or was created successfully
#   Non-zero: Function creation failed (check __createFunctionToGetCountry logs)
#
# Context variables:
#   Reads:
#     - DBNAME: PostgreSQL database name (required)
#     - PGAPPNAME: PostgreSQL application name (optional)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies: None
#
# Side effects:
#   - Queries database to check if get_country function exists
#   - Queries database to check if countries table exists
#   - Creates get_country function if missing (via __createFunctionToGetCountry)
#   - Recreates get_country function as stub if countries table missing
#   - Writes log messages to stderr
#   - Database operations: Queries pg_proc and information_schema
#   - No file or network operations
#
# Notes:
#   - Required before creating procedures (insert_note, insert_note_comment)
#   - Handles missing countries table scenario (creates stub function)
#   - Critical function: Prevents procedure creation failures
#   - Used in both API processing and Planet processing workflows
#   - Function can be created as stub if countries table doesn't exist yet
#
# Example:
#   export DBNAME="osm_notes"
#   __ensureGetCountryFunction
#   # Ensures get_country function exists before creating procedures
#
# Related: __createFunctionToGetCountry() (creates get_country function)
# Related: __createProcedures() (requires get_country to exist)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
# Ensures get_country function exists before creating procedures.
# The procedures (insert_note, insert_note_comment) require get_country to exist.
# This function checks if get_country exists and creates it if missing.
# If get_country exists but countries table does not, recreates the function as stub.
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

# Validates API notes XML file completely (structure, dates, coordinates)
# Parameters:
#   None (uses global API_NOTES_FILE variable)
# Returns:
#   0 if all validations pass, exits with ERROR_DATA_VALIDATION if any validation fails
##
# Performs complete validation of API notes XML file
# Validates XML structure against schema, dates, and coordinates. Performs comprehensive
# validation to ensure downloaded API file is valid before processing. Exits script
# with ERROR_DATA_VALIDATION if any validation fails.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   Exits with ERROR_DATA_VALIDATION if any validation fails
#   Returns 0 if all validations pass
#
# Error codes:
#   0: Success - All validations passed (structure, dates, coordinates)
#   ERROR_DATA_VALIDATION: Failure - File not found, structure invalid, dates invalid, or coordinates invalid (exits script)
#
# Error conditions:
#   0: Success - All validations passed successfully
#   ERROR_DATA_VALIDATION: File not found - API_NOTES_FILE does not exist
#   ERROR_DATA_VALIDATION: Structure invalid - XML does not match schema
#   ERROR_DATA_VALIDATION: Dates invalid - Dates are not in expected format or invalid
#   ERROR_DATA_VALIDATION: Coordinates invalid - Coordinates are missing or invalid
#
# Context variables:
#   Reads:
#     - API_NOTES_FILE: Path to API notes XML file (required)
#     - XMLSCHEMA_API_NOTES: Path to XML schema file (required)
#     - FAILED_EXECUTION_FILE: Path to failed execution marker file (required)
#     - LOG_LEVEL: Controls logging verbosity
#     - ERROR_DATA_VALIDATION: Error code for validation failures (defined in calling script)
#   Sets: None
#   Modifies: None
#
# Side effects:
#   - Validates XML structure against schema (using xmllint)
#   - Validates dates in XML file (ISO 8601 format)
#   - Validates coordinates in XML file (lat/lon attributes)
#   - Creates failed execution marker if validation fails
#   - Writes log messages to stderr
#   - Exits script with ERROR_DATA_VALIDATION if validation fails
#   - No file modifications or database operations
#
# Notes:
#   - Performs three validation steps: structure, dates, coordinates
#   - Uses __validate_xml_with_enhanced_error_handling for structure validation
#   - Uses __validate_xml_dates for date validation
#   - Uses __validate_xml_coordinates for coordinate validation
#   - All validations must pass for function to succeed
#   - Critical function: exits script on failure (does not return)
#   - Used before processing API notes to ensure data quality
#
# Example:
#   export API_NOTES_FILE="/tmp/api_notes.xml"
#   export XMLSCHEMA_API_NOTES="/path/to/schema.xsd"
#   export FAILED_EXECUTION_FILE="/tmp/failed_execution"
#   __validateApiNotesXMLFileComplete
#   # All validations passed - file is valid
#
# Related: __validateApiNotesFile() (basic file existence check)
# Related: __validate_xml_with_enhanced_error_handling() (XML structure validation)
# Related: __validate_xml_dates() (date validation)
# Related: __validate_xml_coordinates() (coordinate validation)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
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
 # shellcheck disable=SC2310
 # Function is invoked in if condition intentionally
 if ! __validate_xml_with_enhanced_error_handling "${API_NOTES_FILE}" "${XMLSCHEMA_API_NOTES}"; then
  __loge "ERROR: XML structure validation failed: ${API_NOTES_FILE}"
  __create_failed_marker "${ERROR_DATA_VALIDATION}" \
   "XML structure validation failed - downloaded file does not match schema" \
   "Check if OSM API has changed. Verify file: ${API_NOTES_FILE} against schema: ${XMLSCHEMA_API_NOTES}"
  exit "${ERROR_DATA_VALIDATION}"
 fi

 # Validate dates in XML file
 __logi "Validating dates in XML file..."
 # shellcheck disable=SC2310
 # Function is invoked in if condition intentionally
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

##
# Processes API XML file or triggers Planet synchronization based on note count
# Decides whether to process API XML sequentially or trigger full Planet synchronization
# based on the number of notes. If note count exceeds MAX_NOTES threshold, triggers
# Planet sync script. Otherwise, processes API XML file sequentially.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   0: Success - Processing completed successfully
#   1: Failure - Sequential processing failed
#   Non-zero: Failure - Planet sync script failed
#
# Error codes:
#   0: Success - Processing completed (sequential or Planet sync)
#   1: Failure - Sequential API XML processing failed
#   Non-zero: Failure - Planet sync script failed (exit code from sync script)
#
# Error conditions:
#   0: Success - Notes processed successfully (sequential or Planet sync)
#   1: Sequential processing failed - __processApiXmlSequential failed
#   Non-zero: Planet sync failed - NOTES_SYNC_SCRIPT returned non-zero exit code
#
# Context variables:
#   Reads:
#     - TOTAL_NOTES: Number of notes to process (required)
#     - MAX_NOTES: Threshold for triggering Planet sync (required)
#     - API_NOTES_FILE: Path to API XML file (required for sequential processing)
#     - NOTES_SYNC_SCRIPT: Path to Planet sync script (required for Planet sync)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies: None
#
# Side effects:
#   - Executes NOTES_SYNC_SCRIPT if TOTAL_NOTES >= MAX_NOTES (Planet synchronization)
#   - Calls __processApiXmlSequential if TOTAL_NOTES < MAX_NOTES (sequential processing)
#   - Writes log messages to stderr
#   - No direct database operations (delegated to sub-functions)
#
# Notes:
#   - Decision logic: if TOTAL_NOTES >= MAX_NOTES, run Planet sync; else process sequentially
#   - Planet sync is triggered for large note counts (full synchronization)
#   - Sequential processing is used for smaller note counts (incremental updates)
#   - Planet sync can take several minutes (large operation)
#   - Sequential processing uses AWK for fast XML extraction
#   - If TOTAL_NOTES is 0, skips processing (no notes to process)
#
# Example:
#   export TOTAL_NOTES=5000
#   export MAX_NOTES=10000
#   export API_NOTES_FILE="/tmp/api_notes.xml"
#   export NOTES_SYNC_SCRIPT="/path/to/processPlanetNotes.sh"
#   __processXMLorPlanet
#
# Related: __processApiXmlSequential() (sequential API processing)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
##
# Decides between sequential API XML processing and full Planet synchronization
# Determines processing strategy based on note count. If TOTAL_NOTES >= MAX_NOTES,
# triggers full Planet synchronization (more efficient for large datasets). Otherwise,
# processes API XML file sequentially using AWK extraction. Handles empty files gracefully.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   0: Success - Processing completed successfully (or no notes to process)
#   Non-zero: Failure - Sequential processing failed or Planet sync failed
#
# Error codes:
#   0: Success - Processing completed successfully
#   0: Success - No notes found (valid scenario)
#   Non-zero: Sequential processing failed (__processApiXmlSequential returned error)
#   Non-zero: Planet sync failed (NOTES_SYNC_SCRIPT returned error)
#
# Error conditions:
#   0: Success - Processing completed successfully
#   0: Success - No notes found (skips processing)
#   Non-zero: Sequential processing failed - AWK extraction or CSV loading failed
#   Non-zero: Planet sync failed - processPlanetNotes.sh returned error
#
# Context variables:
#   Reads:
#     - TOTAL_NOTES: Total number of notes in XML file (required)
#     - MAX_NOTES: Maximum notes threshold for Planet sync (required)
#     - API_NOTES_FILE: Path to API notes XML file (required for sequential processing)
#     - NOTES_SYNC_SCRIPT: Path to Planet sync script (required if TOTAL_NOTES >= MAX_NOTES)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies: None
#
# Side effects:
#   - Executes Planet sync script if TOTAL_NOTES >= MAX_NOTES
#   - Processes API XML sequentially if TOTAL_NOTES < MAX_NOTES
#   - Writes log messages to stderr
#   - No direct database operations (delegated to called functions/scripts)
#   - No file or network operations (delegated to called functions/scripts)
#
# Notes:
#   - Decision logic: TOTAL_NOTES >= MAX_NOTES → Planet sync, else → Sequential processing
#   - Planet sync is more efficient for large datasets (avoids processing many small API files)
#   - Sequential processing uses AWK extraction (fast, dependency-free)
#   - Handles empty files gracefully (no notes, skips processing)
#   - Critical function: Determines processing strategy for API notes
#   - Planet sync can take several minutes (full synchronization)
#
# Example:
#   export TOTAL_NOTES=15000
#   export MAX_NOTES=10000
#   export NOTES_SYNC_SCRIPT="/path/to/processPlanetNotes.sh"
#   __processXMLorPlanet
#   # Triggers Planet sync (TOTAL_NOTES >= MAX_NOTES)
#
# Related: __processApiXmlSequential() (sequential API XML processing)
# Related: processPlanetNotes.sh (full Planet synchronization)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
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

##
# Processes API XML file sequentially using AWK extraction
# Extracts notes, comments, and text comments from API XML file into CSV files using AWK.
# Processes the entire XML file sequentially (not parallel). Validates CSV structure and
# enum compatibility if SKIP_CSV_VALIDATION is not true. Suitable for small to medium datasets.
#
# Parameters:
#   $1: XML file path - Path to API-format XML file to process (required)
#
# Returns:
#   0: Success - All CSV files created successfully
#   1: Failure - CSV file creation failed or validation failed
#
# Error codes:
#   0: Success - All CSV files created and validated (if validation enabled)
#   1: Failure - Notes CSV file was not created
#   1: Failure - Comments CSV file was not created
#   1: Failure - CSV structure validation failed
#   1: Failure - CSV enum compatibility validation failed
#
# Error conditions:
#   0: Success - Notes, comments, and text CSV files created successfully
#   1: Notes CSV missing - AWK extraction failed for notes
#   1: Comments CSV missing - AWK extraction failed for comments
#   1: CSV validation failed - Structure or enum validation failed
#
# Context variables:
#   Reads:
#     - TMP_DIR: Temporary directory for output CSV files (required)
#     - SCRIPT_BASE_DIRECTORY: Base directory for AWK scripts (required)
#     - SKIP_CSV_VALIDATION: If "true", skips CSV validation (optional, default: true)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies: None
#
# Side effects:
#   - Executes AWK scripts to extract notes, comments, and text comments
#   - Creates CSV files in TMP_DIR (output-notes-sequential.csv, output-comments-sequential.csv, output-text-sequential.csv)
#   - Validates CSV structure and enum compatibility (if SKIP_CSV_VALIDATION != true)
#   - Writes log messages to stderr
#   - No database or network operations
#
# Notes:
#   - Uses AWK for fast XML extraction (dependency-free, no external tools)
#   - Processes entire XML file sequentially (not split into parts)
#   - Creates three CSV files: notes, comments, text comments
#   - Text comments CSV is created as empty file if AWK extraction fails (non-fatal)
#   - CSV validation is optional (controlled by SKIP_CSV_VALIDATION)
#   - Suitable for datasets smaller than MAX_NOTES threshold
#   - AWK scripts: extract_notes.awk, extract_comments.awk, extract_comment_texts.awk
#
# Example:
#   __processApiXmlSequential "${API_NOTES_FILE}"
#   # CSV files created in TMP_DIR:
#   # - output-notes-sequential.csv
#   # - output-comments-sequential.csv
#   # - output-text-sequential.csv
#
# Related: __processXMLorPlanet() (decides sequential vs Planet sync)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
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
 local NOTES_LINES
 NOTES_LINES=$(wc -l < "${SEQ_OUTPUT_NOTES_FILE}" 2> /dev/null || echo 0)
 # shellcheck disable=SC2310
 # Function is invoked in || condition intentionally to prevent exit on error
 __logd "  Notes: ${SEQ_OUTPUT_NOTES_FILE} (${NOTES_LINES} lines)" || true
 local COMMENTS_LINES
 COMMENTS_LINES=$(wc -l < "${SEQ_OUTPUT_COMMENTS_FILE}" 2> /dev/null || echo 0)
 # shellcheck disable=SC2310
 # Function is invoked in || condition intentionally to prevent exit on error
 __logd "  Comments: ${SEQ_OUTPUT_COMMENTS_FILE} (${COMMENTS_LINES} lines)" || true
 local TEXT_LINES
 TEXT_LINES=$(wc -l < "${SEQ_OUTPUT_TEXT_FILE}" 2> /dev/null || echo 0)
 # shellcheck disable=SC2310
 # Function is invoked in || condition intentionally to prevent exit on error
 __logd "  Text: ${SEQ_OUTPUT_TEXT_FILE} (${TEXT_LINES} lines)" || true

 # Validate CSV files structure and content before loading (optional)
 if [[ "${SKIP_CSV_VALIDATION:-true}" != "true" ]]; then
  __logd "Validating CSV files structure and enum compatibility..."

  # Validate notes
  # shellcheck disable=SC2310
  # Function is invoked in if condition intentionally
  if ! __validate_csv_structure "${SEQ_OUTPUT_NOTES_FILE}" "notes"; then
   __loge "ERROR: Notes CSV structure validation failed"
   __log_finish
   return 1
  fi

  # shellcheck disable=SC2310
  # Function is invoked in if condition intentionally
  if ! __validate_csv_for_enum_compatibility "${SEQ_OUTPUT_NOTES_FILE}" "notes"; then
   __loge "ERROR: Notes CSV enum validation failed"
   __log_finish
   return 1
  fi

  # Validate comments
  # shellcheck disable=SC2310
  # Function is invoked in if condition intentionally
  if ! __validate_csv_structure "${SEQ_OUTPUT_COMMENTS_FILE}" "comments"; then
   __loge "ERROR: Comments CSV structure validation failed"
   __log_finish
   return 1
  fi

  # shellcheck disable=SC2310
  # Function is invoked in if condition intentionally
  if ! __validate_csv_for_enum_compatibility "${SEQ_OUTPUT_COMMENTS_FILE}" "comments"; then
   __loge "ERROR: Comments CSV enum validation failed"
   __log_finish
   return 1
  fi

  # Validate text
  # shellcheck disable=SC2310
  # Function is invoked in if condition intentionally
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
 # Remove trailing commas from CSV files (AWK outputs trailing commas for empty columns)
 __logd "Cleaning CSV files (removing trailing commas)"
 local SEQ_OUTPUT_NOTES_CLEANED="${SEQ_OUTPUT_NOTES_FILE}.cleaned"
 local SEQ_OUTPUT_COMMENTS_CLEANED="${SEQ_OUTPUT_COMMENTS_FILE}.cleaned"
 local SEQ_OUTPUT_TEXT_CLEANED="${SEQ_OUTPUT_TEXT_FILE}.cleaned"
 # Remove trailing commas (no part_id needed, tables are not partitioned)
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
 # Use --pset pager=off to prevent opening vi/less for long output
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 --pset pager=off -f "${TEMP_SQL}"
 # Clean up temp files
 rm -f "${TEMP_SQL}" "${SEQ_OUTPUT_NOTES_CLEANED}" "${SEQ_OUTPUT_COMMENTS_CLEANED}" "${SEQ_OUTPUT_TEXT_CLEANED}"

 __logi "=== SEQUENTIAL API XML PROCESSING COMPLETED SUCCESSFULLY ==="
 __log_finish
}

# Inserts new notes and comments into the database
##
# Inserts new notes and comments from API tables to main tables with locking
# Uses database locking mechanism to ensure single-process execution. Acquires lock,
# inserts new notes and comments from API tables (notes_api, note_comments_api) to
# main tables (notes, note_comments), updates last processed timestamp, and releases lock.
# Includes cleanup trap to ensure lock is always released.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   0: Success - Notes and comments inserted successfully
#   1: Failure - Lock acquisition failed or SQL execution failed
#
# Error codes:
#   0: Success - Notes and comments inserted, lock released
#   1: Failure - Failed to acquire lock after retries
#   1: Failure - SQL execution failed (insertion or timestamp update)
#   1: Failure - Failed to release lock
#
# Error conditions:
#   0: Success - All operations completed successfully
#   1: Lock acquisition failed - Could not acquire lock after MAX_RETRIES attempts
#   1: SQL execution failed - Insertion or timestamp update failed
#   1: Lock release failed - Failed to remove lock after successful insertion
#
# Context variables:
#   Reads:
#     - DBNAME: PostgreSQL database name (required)
#     - PGAPPNAME: PostgreSQL application name (optional)
#     - POSTGRES_32_INSERT_NEW_NOTES_AND_COMMENTS: Path to insertion SQL script (required)
#     - POSTGRES_34_UPDATE_LAST_VALUES: Path to timestamp update SQL script (required)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets:
#     - PROCESS_ID: Unique process identifier (exported for SQL scripts)
#   Modifies: None
#
# Side effects:
#   - Creates unique process ID (PID_timestamp_random)
#   - Executes psql to acquire database lock (put_lock procedure)
#   - Creates temporary SQL file with process_id substitution
#   - Executes psql to insert notes and comments (from API tables to main tables)
#   - Executes psql to update last processed timestamp (in same connection)
#   - Executes psql to release database lock (remove_lock procedure)
#   - Registers EXIT trap for lock cleanup
#   - Writes log messages to stderr
#   - No file or network operations (except temporary SQL file)
#
# Notes:
#   - Uses database locking (put_lock/remove_lock procedures) for single-process execution
#   - Lock retry logic: 3 attempts with 2 second delay
#   - Process ID format: ${$}_$(date +%s)_${RANDOM} (unique identifier)
#   - Combines insertion and timestamp update in single connection (preserves app variables)
#   - EXIT trap ensures lock is released even on error
#   - Lock cleanup happens both via trap and explicit removal
#   - Uses envsubst for process_id substitution in SQL
#   - Sets app.process_id in SQL for tracking
#
# Example:
#   export DBNAME="osm_notes"
#   export POSTGRES_32_INSERT_NEW_NOTES_AND_COMMENTS="/path/to/insert.sql"
#   export POSTGRES_34_UPDATE_LAST_VALUES="/path/to/update.sql"
#   __insertNewNotesAndComments
#
# Related: __loadApiTextComments() (loads text comments)
# Related: __updateLastValue() (updates timestamp separately)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
##
# Inserts new notes and comments from API tables to main tables
# Moves data from temporary API tables (notes_api, note_comments_api) to main production
# tables (notes, note_comments). Uses database locking to prevent concurrent insertions.
# Also updates the last processed timestamp in the same database connection. Handles lock
# acquisition with retry logic and ensures lock cleanup on exit (via trap).
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   0: Success - Notes and comments inserted successfully
#   1: Failure - Lock acquisition failed after retries
#   Non-zero: Failure - SQL execution failed or lock removal failed
#
# Error codes:
#   0: Success - Notes and comments inserted successfully
#   1: Failure - Lock acquisition failed after maximum retries
#   Non-zero: SQL execution failed (SQL error, connection error, etc.)
#   1: Failure - Lock removal failed
#
# Error conditions:
#   0: Success - Data inserted and timestamp updated successfully
#   1: Lock acquisition failed - Could not acquire lock after 3 attempts
#   Non-zero: SQL execution failed - Insertion or timestamp update failed
#   1: Lock removal failed - Could not remove lock after insertion
#
# Context variables:
#   Reads:
#     - DBNAME: PostgreSQL database name (required)
#     - PGAPPNAME: PostgreSQL application name (optional)
#     - POSTGRES_32_INSERT_NEW_NOTES_AND_COMMENTS: Path to SQL script template (required)
#     - POSTGRES_34_UPDATE_LAST_VALUES: Path to SQL script for timestamp update (required)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets:
#     - PROCESS_ID: Unique process ID (exported, used in SQL)
#   Modifies:
#     - Creates temporary SQL file (removed after use)
#     - Acquires database lock (put_lock)
#     - Removes database lock (remove_lock)
#
# Side effects:
#   - Generates unique process ID (PID_timestamp_random)
#   - Acquires database lock with retry logic (3 attempts, 2 second delay)
#   - Creates temporary SQL file with process_id substitution
#   - Executes SQL to insert notes and comments from API tables to main tables
#   - Updates last processed timestamp in same connection
#   - Removes database lock after completion
#   - Sets EXIT trap for lock cleanup (ensures lock removal on error)
#   - Writes log messages to stderr
#   - Database operations: Lock acquisition, INSERT from API tables, timestamp update
#   - File operations: Creates and removes temporary SQL file
#   - No network operations
#
# Notes:
#   - Uses database locking (put_lock/remove_lock) to prevent concurrent insertions
#   - Lock acquisition has retry logic (3 attempts, 2 second delay)
#   - Lock cleanup is guaranteed via EXIT trap (even on error)
#   - Updates timestamp in same connection as insertion (preserves app.integrity_check_passed)
#   - Uses envsubst for process_id substitution in SQL template
#   - Uses ON_ERROR_STOP=1 to fail immediately on SQL errors
#   - Uses --pset pager=off to prevent blocking on long output
#   - Critical function: Moves API data to production tables
#   - Must be called after data is loaded into API tables
#
# Example:
#   export DBNAME="osm_notes"
#   export POSTGRES_32_INSERT_NEW_NOTES_AND_COMMENTS="/path/to/insert.sql"
#   export POSTGRES_34_UPDATE_LAST_VALUES="/path/to/update_timestamp.sql"
#   __insertNewNotesAndComments
#   # Inserts notes/comments and updates timestamp
#
# Related: __loadApiTextComments() (loads text comments after insertion)
# Related: __processApiXmlSequential() (loads data into API tables)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
##
# Inserts new notes and comments from API tables to main tables with database locking
# Moves data from temporary API tables (notes_api, note_comments_api, note_comments_text_api)
# to main production tables (notes, note_comments, note_comments_text). Uses database locking
# (put_lock/remove_lock) to prevent concurrent insertions. Updates last processed timestamp
# in the same transaction. Ensures lock cleanup via EXIT trap even on errors.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   0: Success - Data inserted successfully and lock released
#   1: Failure - Lock acquisition failed, SQL execution failed, or lock removal failed
#
# Error codes:
#   0: Success - Data inserted successfully and lock released
#   1: Failure - Lock acquisition failed after retries
#   1: Failure - SQL execution failed (insertion or timestamp update)
#   1: Failure - Lock removal failed
#
# Error conditions:
#   0: Success - All operations completed successfully
#   1: Lock acquisition failed - Could not acquire lock after MAX_RETRIES attempts
#   1: SQL execution failed - INSERT or UPDATE operations failed
#   1: Lock removal failed - Could not release lock after insertion
#
# Context variables:
#   Reads:
#     - DBNAME: PostgreSQL database name (required)
#     - PGAPPNAME: PostgreSQL application name (optional)
#     - POSTGRES_32_INSERT_NEW_NOTES_AND_COMMENTS: Path to SQL script (required)
#     - POSTGRES_34_UPDATE_LAST_VALUES: Path to SQL script for timestamp update (required)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets:
#     - PROCESS_ID: Unique process identifier (exported, used by SQL)
#   Modifies:
#     - Inserts data from API tables to main tables
#     - Updates last processed timestamp in properties table
#
# Side effects:
#   - Generates unique process ID (PID + timestamp + random)
#   - Acquires database lock via put_lock() procedure (with retry logic)
#   - Creates temporary SQL file with process_id substitution
#   - Executes psql to insert notes/comments from API tables to main tables
#   - Executes psql to update last processed timestamp
#   - Releases database lock via remove_lock() procedure
#   - Sets EXIT trap for lock cleanup (ensures lock is released even on error)
#   - Writes log messages to stderr
#   - Uses --pset pager=off to prevent blocking on SELECT output
#   - Database operations: INSERT, UPDATE, stored procedure calls
#   - File operations: Creates temporary SQL file
#   - No network operations
#
# Notes:
#   - Uses database locking to prevent concurrent insertions (critical for daemon mode)
#   - Lock retry logic: 3 attempts with 2-second delay between retries
#   - EXIT trap ensures lock cleanup even if function fails or is interrupted
#   - Process ID is set as PostgreSQL session variable (app.process_id)
#   - Updates timestamp in same transaction as insertion (preserves app.integrity_check_passed)
#   - Critical function: Part of API processing workflow (final step before cleanup)
#   - Uses ON_ERROR_STOP=1 to fail immediately on SQL errors
#   - Lock cleanup is guaranteed via EXIT trap (prevents deadlocks)
#
# Example:
#   export DBNAME="osm_notes"
#   export POSTGRES_32_INSERT_NEW_NOTES_AND_COMMENTS="/path/to/insert.sql"
#   export POSTGRES_34_UPDATE_LAST_VALUES="/path/to/update_timestamp.sql"
#   __insertNewNotesAndComments
#   # Inserts data from API tables to main tables and updates timestamp
#
# Related: __createApiTables() (creates API staging tables)
# Related: __prepareApiTables() (prepares API tables for processing)
# Related: put_lock() (database lock procedure)
# Related: remove_lock() (database unlock procedure)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
function __insertNewNotesAndComments {
 __log_start

 # Generate unique process ID with timestamp to avoid conflicts
 local PROCESS_ID
 PROCESS_ID="${$}_$(date +%s)_${RANDOM}"

 # Set lock with retry logic and better error handling
 local LOCK_RETRY_COUNT=0
 local LOCK_MAX_RETRIES=3
 local LOCK_RETRY_DELAY=2
 local LOCK_ACQUIRED=0

 while [[ ${LOCK_RETRY_COUNT} -lt ${LOCK_MAX_RETRIES} ]]; do
  if echo "CALL put_lock('${PROCESS_ID}'::VARCHAR)" | PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1; then
   __logd "Lock acquired successfully: ${PROCESS_ID}"
   LOCK_ACQUIRED=1
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

 # Function to cleanup lock (always remove, even on error)
 __cleanup_insert_lock() {
  if [[ ${LOCK_ACQUIRED} -eq 1 ]] && [[ -n "${PROCESS_ID:-}" ]]; then
   __logd "Cleaning up lock: ${PROCESS_ID}"
   echo "CALL remove_lock('${PROCESS_ID}'::VARCHAR)" | PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=0 > /dev/null 2>&1 || true
  fi
 }

 # Register cleanup trap (will execute on function exit)
 trap '__cleanup_insert_lock' EXIT

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
 # Use --pset pager=off to prevent opening vi/less for long output
 local SQL_EXIT_CODE=0
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 --pset pager=off -f "${TEMP_SQL_FILE}" || SQL_EXIT_CODE=$?

 rm -f "${TEMP_SQL_FILE}"

 # Remove trap before explicit lock removal (normal path)
 trap - EXIT

 # Remove lock explicitly (normal success path)
 if ! echo "CALL remove_lock('${PROCESS_ID}'::VARCHAR)" | PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1; then
  __loge "Failed to remove lock"
  __log_finish
  return 1
 fi

 LOCK_ACQUIRED=0

 # Return error if SQL execution failed
 # Note: lock cleanup will happen via EXIT trap if we return here
 if [[ ${SQL_EXIT_CODE} -ne 0 ]]; then
  __loge "SQL execution failed with exit code: ${SQL_EXIT_CODE}"
  __log_finish
  # Remove trap since we're handling cleanup explicitly in error path
  trap - EXIT
  # Try to remove lock even on error (ignore failures)
  echo "CALL remove_lock('${PROCESS_ID}'::VARCHAR)" | PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=0 > /dev/null 2>&1 || true
  return "${SQL_EXIT_CODE}"
 fi

 __log_finish
 return 0
}

##
# Loads text comments from API table to main table
# Inserts text comments from note_comments_text_api to note_comments_text main table.
# Uses envsubst to substitute OUTPUT_TEXT_COMMENTS_FILE path in SQL template.
# Only inserts comments that have corresponding entries in note_comments (FK validation).
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   0: Success - Text comments loaded successfully
#   Non-zero: Failure - psql command failed
#
# Error codes:
#   0: Success - Text comments inserted successfully
#   Non-zero: psql command failed (SQL error, connection error, etc.)
#
# Error conditions:
#   0: Success - SQL script executed successfully
#   Non-zero: psql execution failed (ON_ERROR_STOP=1 causes immediate failure)
#
# Context variables:
#   Reads:
#     - DBNAME: PostgreSQL database name (required)
#     - PGAPPNAME: PostgreSQL application name (optional)
#     - OUTPUT_TEXT_COMMENTS_FILE: Path to text comments CSV file (required)
#     - POSTGRES_33_INSERT_NEW_TEXT_COMMENTS: Path to SQL script template (required)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies: None
#
# Side effects:
#   - Executes envsubst to substitute OUTPUT_TEXT_COMMENTS_FILE in SQL template
#   - Executes psql to insert text comments (from note_comments_text_api to note_comments_text)
#   - Writes log messages to stderr
#   - No file or network operations
#
# Notes:
#   - Uses envsubst for file path substitution in SQL template
#   - Only inserts comments with FK validation (must exist in note_comments)
#   - Prevents FK violations when duplicate comments are deduplicated
#   - Uses ON_ERROR_STOP=1 to fail immediately on SQL errors
#   - Text comments are loaded after notes and comments are inserted
#   - Sequence numbers are already generated by AWK extraction
#
# Example:
#   export DBNAME="osm_notes"
#   export OUTPUT_TEXT_COMMENTS_FILE="/tmp/note_comments_text.csv"
#   export POSTGRES_33_INSERT_NEW_TEXT_COMMENTS="/path/to/insert_text_comments.sql"
#   __loadApiTextComments
#
# Related: __insertNewNotesAndComments() (inserts notes and comments)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
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

##
# Updates the last processed timestamp in database
# Updates the max_note_timestamp table with the most recent timestamp from processed notes.
# This timestamp is used by __getNewNotesFromApi() to determine which notes to download
# in the next API sync cycle. Should be called after successfully inserting notes.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   0: Success - Timestamp updated successfully
#   Non-zero: Failure - psql command failed
#
# Error codes:
#   0: Success - Last update timestamp updated successfully
#   Non-zero: psql command failed (SQL error, connection error, etc.)
#
# Error conditions:
#   0: Success - SQL script executed successfully
#   Non-zero: psql execution failed (ON_ERROR_STOP=1 causes immediate failure)
#
# Context variables:
#   Reads:
#     - DBNAME: PostgreSQL database name (required)
#     - PGAPPNAME: PostgreSQL application name (optional)
#     - POSTGRES_34_UPDATE_LAST_VALUES: Path to SQL script (required)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies: None
#
# Side effects:
#   - Executes psql to update max_note_timestamp table
#   - Updates timestamp to most recent updated_at value from notes table
#   - Writes log messages to stderr
#   - No file or network operations
#
# Notes:
#   - Updates max_note_timestamp table with latest timestamp
#   - Used by __getNewNotesFromApi() to determine download range
#   - Should be called after successful note insertion
#   - Uses ON_ERROR_STOP=1 to fail immediately on SQL errors
#   - Critical for incremental API sync (determines next download start point)
#   - Note: This function is also called within __insertNewNotesAndComments() in same connection
#
# Example:
#   export DBNAME="osm_notes"
#   export POSTGRES_34_UPDATE_LAST_VALUES="/path/to/update_last_values.sql"
#   __updateLastValue
#
# Related: __getNewNotesFromApi() (uses timestamp for API download)
# Related: __insertNewNotesAndComments() (also updates timestamp)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
function __updateLastValue {
 __log_start
 __logi "Updating last update time."
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_34_UPDATE_LAST_VALUES}"
 __log_finish
}

# Clean files generated during the process.
##
# Cleans up files generated during API notes processing
# Removes temporary files created during API processing if CLEAN environment variable
# is set to true. Files removed include API XML file and generated CSV files.
# Used for cleanup after successful or failed processing.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   Always returns 0 (success) - cleanup function never fails
#
# Error codes:
#   None - Function always succeeds, only performs file removal
#
# Error conditions:
#   Always succeeds - File removal failures are ignored (rm -f)
#
# Context variables:
#   Reads:
#     - CLEAN: If "true", removes files; if "false" or unset, skips cleanup (optional, default: false)
#     - API_NOTES_FILE: Path to API XML file (required)
#     - OUTPUT_NOTES_FILE: Path to notes CSV file (required)
#     - OUTPUT_NOTE_COMMENTS_FILE: Path to comments CSV file (required)
#     - OUTPUT_TEXT_COMMENTS_FILE: Path to text comments CSV file (required)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies: None
#
# Side effects:
#   - Removes API XML file and CSV files if CLEAN=true
#   - Writes log messages to stderr
#   - No database or network operations
#   - File removal failures are ignored (rm -f)
#
# Notes:
#   - Only removes files if CLEAN environment variable is "true"
#   - Uses rm -f to ignore missing files (non-fatal)
#   - Safe to call multiple times (idempotent)
#   - Used for cleanup after processing (success or failure)
#   - Files are removed silently (no error if file doesn't exist)
#
# Example:
#   export CLEAN=true
#   export API_NOTES_FILE="/tmp/api_notes.xml"
#   export OUTPUT_NOTES_FILE="/tmp/notes.csv"
#   __cleanNotesFiles
#
# Related: __cleanPartial() (cleans partial processing files)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
function __cleanNotesFiles {
 __log_start
 if [[ -n "${CLEAN:-}" ]] && [[ "${CLEAN}" = true ]]; then
  rm -f "${API_NOTES_FILE}" "${OUTPUT_NOTES_FILE}" \
   "${OUTPUT_NOTE_COMMENTS_FILE}" "${OUTPUT_TEXT_COMMENTS_FILE}"
 fi
 __log_finish
}

##
# Validates that API notes file was downloaded successfully
# Checks file existence and handles empty files gracefully (0 notes is valid scenario).
# Empty files are valid when API returns no new notes. Exits with error only if file
# was not downloaded (download failure).
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   0: Success - File exists (empty or with content)
#   Exits with ERROR_INTERNET_ISSUE if file not found
#
# Error codes:
#   0: Success - File exists and is valid (empty files are valid)
#   ERROR_INTERNET_ISSUE: Failure - File was not downloaded (exits script)
#
# Error conditions:
#   0: Success - File exists (empty files indicate 0 notes, which is valid)
#   ERROR_INTERNET_ISSUE: File not found - Download failed or file not created
#
# Context variables:
#   Reads:
#     - API_NOTES_FILE: Path to API notes XML file (required)
#     - FAILED_EXECUTION_FILE: Path to failed execution marker file (required)
#     - LOG_LEVEL: Controls logging verbosity
#     - ERROR_INTERNET_ISSUE: Error code for network issues (defined in calling script)
#   Sets: None
#   Modifies: None
#
# Side effects:
#   - Checks file existence and size
#   - Creates failed execution marker if file not found
#   - Writes log messages to stderr
#   - Exits script with ERROR_INTERNET_ISSUE if file not found
#   - No file modifications, database, or network operations
#
# Notes:
#   - Empty files (0 bytes) are valid and indicate 0 notes scenario
#   - Only exits if file does not exist (download failure)
#   - Creates failed execution marker for troubleshooting
#   - Used after __getNewNotesFromApi() to verify download success
#   - Empty file is a normal case (no new notes available)
#
# Example:
#   export API_NOTES_FILE="/tmp/api_notes.xml"
#   export FAILED_EXECUTION_FILE="/tmp/failed_execution"
#   __validateApiNotesFile
#   # File exists (empty or with content) - validation passed
#
# Related: __getNewNotesFromApi() (downloads API notes file)
# Related: __validateApiNotesXMLFileComplete() (full XML validation)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
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

 # Empty file is valid when API returns 0 notes (no new notes scenario)
 # This is a normal case and should be handled gracefully, not as an error
 if [[ ! -s "${API_NOTES_FILE}" ]]; then
  __logi "API notes file is empty (0 notes) - this is valid when no new notes are available"
  __logi "API notes file downloaded successfully: ${API_NOTES_FILE} (empty - no new notes)"
  __log_finish
  return 0
 fi

 __logi "API notes file downloaded successfully: ${API_NOTES_FILE}"
 __log_finish
}

##
# Validates and processes API notes XML file
# Orchestrates validation and processing workflow for API notes XML file. Handles empty
# files gracefully (0 notes is valid). Counts notes first, then validates XML (if enabled),
# processes XML (sequential or Planet sync), and inserts notes/comments. Skips validation
# and processing if no notes found.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   0: Success - File processed successfully (or empty file, no notes)
#   Non-zero: Failure - Validation failed or processing failed (exits script on validation failure)
#
# Error codes:
#   0: Success - File processed successfully
#   0: Success - Empty file (0 notes, valid scenario)
#   ERROR_DATA_VALIDATION: XML validation failed (exits script)
#   Non-zero: Processing failed (sequential processing or Planet sync failed)
#
# Error conditions:
#   0: Success - File processed successfully
#   0: Success - Empty file (no notes to process)
#   0: Success - File has structure but no <note> elements (skips processing)
#   ERROR_DATA_VALIDATION: XML validation failed (exits script via __validateApiNotesXMLFileComplete)
#   Non-zero: Note counting failed (continues with TOTAL_NOTES=0)
#   Non-zero: Sequential processing failed (__processApiXmlSequential returned error)
#   Non-zero: Planet sync failed (NOTES_SYNC_SCRIPT returned error)
#
# Context variables:
#   Reads:
#     - API_NOTES_FILE: Path to API notes XML file (required)
#     - SKIP_XML_VALIDATION: If "true", skips XML validation (optional)
#     - TOTAL_NOTES: Total number of notes (set by __countXmlNotesAPI, exported)
#     - MAX_NOTES: Maximum notes threshold for Planet sync (required)
#     - NOTES_SYNC_SCRIPT: Path to Planet sync script (required if TOTAL_NOTES >= MAX_NOTES)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets:
#     - TOTAL_NOTES: Total number of notes (exported, set to 0 if empty or counting fails)
#   Modifies: None
#
# Side effects:
#   - Counts notes in XML file (__countXmlNotesAPI)
#   - Validates XML file (__validateApiNotesXMLFileComplete, if enabled)
#   - Processes XML file (__processXMLorPlanet)
#   - Inserts notes and comments (__insertNewNotesAndComments, if TOTAL_NOTES > 0)
#   - Loads text comments (__loadApiTextComments, if TOTAL_NOTES > 0)
#   - Writes log messages to stderr
#   - Exits script with ERROR_DATA_VALIDATION if validation fails
#   - No file or network operations (delegated to called functions)
#
# Notes:
#   - Handles empty files gracefully (0 notes is a valid scenario)
#   - Counts notes BEFORE validation to handle XML files with structure but no notes
#   - Skips validation and processing if no notes found (TOTAL_NOTES = 0)
#   - Temporarily disables set -e during note counting to handle errors gracefully
#   - Critical function: Main workflow for API notes processing
#   - Workflow: Count → Validate (if enabled) → Process → Insert
#   - Only inserts notes/comments if TOTAL_NOTES > 0
#
# Example:
#   export API_NOTES_FILE="/tmp/api_notes.xml"
#   export MAX_NOTES=10000
#   export SKIP_XML_VALIDATION="false"
#   __validateAndProcessApiXml
#
# Related: __countXmlNotesAPI() (counts notes in XML file)
# Related: __validateApiNotesXMLFileComplete() (validates XML file)
# Related: __processXMLorPlanet() (processes XML or triggers Planet sync)
# Related: __insertNewNotesAndComments() (inserts notes and comments)
# Related: __loadApiTextComments() (loads text comments)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
function __validateAndProcessApiXml {
 __log_start
 declare -i RESULT
 RESULT=$(wc -l < "${API_NOTES_FILE}")

 # Handle empty file case (0 notes scenario)
 if [[ "${RESULT}" -eq 0 ]] || [[ ! -s "${API_NOTES_FILE}" ]]; then
  __logi "API notes file is empty - no new notes to process"
  TOTAL_NOTES=0
  export TOTAL_NOTES
  __logi "No notes to insert, skipping insertion"
  __log_finish
  return 0
 fi

 # Count notes FIRST before validation to handle XML files with structure but no notes
 # This prevents validation errors when MOCK_NOTES_COUNT=0 generates valid but empty XML
 # Temporarily disable set -e to allow function to complete even if it returns non-zero
 # (though it should return 0 now, this is a safety measure)
 set +e
 __countXmlNotesAPI "${API_NOTES_FILE}"
 local COUNT_EXIT_CODE=$?
 set -e

 # If counting failed or no notes found, handle gracefully
 if [[ ${COUNT_EXIT_CODE} -ne 0 ]]; then
  __logw "Note counting encountered an issue (exit code ${COUNT_EXIT_CODE}), but continuing with processing"
  # Ensure TOTAL_NOTES is set even if function failed
  TOTAL_NOTES="${TOTAL_NOTES:-0}"
  export TOTAL_NOTES
 fi

 # If no notes found, skip validation and processing
 if [[ "${TOTAL_NOTES:-0}" -eq 0 ]]; then
  __logi "No notes found in XML file (file has structure but no <note> elements) - skipping validation and processing"
  __log_finish
  return 0
 fi

 # File has content with notes, process it
 if [[ "${SKIP_XML_VALIDATION}" != "true" ]]; then
  __validateApiNotesXMLFileComplete
 else
  __logw "WARNING: XML validation SKIPPED (SKIP_XML_VALIDATION=true)"
 fi
 __processXMLorPlanet
 # Only insert notes if there are notes to process (TOTAL_NOTES > 0)
 # TOTAL_NOTES is exported by __countXmlNotesAPI
 if [[ "${TOTAL_NOTES:-0}" -gt 0 ]]; then
  __insertNewNotesAndComments
  __loadApiTextComments
 else
  __logi "No notes to insert, skipping insertion"
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

##
# Validates historical data and recovers from gaps if needed
# Orchestrates historical data validation and gap recovery workflow. Validates that base
# tables contain sufficient historical data (at least 30 days). If validation fails,
# creates failed execution marker and exits script. If validation passes, attempts gap
# recovery. Called when base tables exist (RET_FUNC == 0).
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   Exits with ERROR_EXECUTING_PLANET_DUMP if historical data validation failed
#   Exits with ERROR_GENERAL if gap recovery failed
#   Returns 0 if validation and recovery completed successfully
#
# Error codes:
#   0: Success - Historical data validated and gaps recovered successfully
#   ERROR_EXECUTING_PLANET_DUMP: Failure - Historical data validation failed (exits script)
#   ERROR_GENERAL: Failure - Gap recovery failed (exits script via __handle_error_with_cleanup)
#
# Error conditions:
#   0: Success - Historical data validated and gaps recovered successfully
#   ERROR_EXECUTING_PLANET_DUMP: Historical data validation failed - Base tables exist but contain no historical data (exits script)
#   ERROR_GENERAL: Gap recovery failed - Large gaps detected or recovery query failed (exits script)
#
# Context variables:
#   Reads:
#     - RET_FUNC: Return code from __checkHistoricalData (required)
#     - SCRIPT_BASE_DIRECTORY: Base directory for scripts (required)
#     - ERROR_EXECUTING_PLANET_DUMP: Error code for Planet dump failures (defined in calling script)
#     - ERROR_GENERAL: Error code for general failures (defined in calling script)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies:
#     - Creates failed execution marker if validation fails
#
# Side effects:
#   - Validates historical data (__checkHistoricalData)
#   - Creates failed execution marker if validation fails
#   - Recovers from gaps (__recover_from_gaps)
#   - Handles errors with cleanup (__handle_error_with_cleanup)
#   - Writes log messages to stderr
#   - Exits script with error code on failure
#   - No file or network operations (delegated to called functions)
#
# Notes:
#   - Called when base tables exist (RET_FUNC == 0 from __checkBaseTables)
#   - Historical data validation ensures ProcessAPI has context for incremental updates
#   - Gap recovery detects and handles data integrity issues
#   - Creates failed execution marker to prevent repeated failures
#   - Critical function: Ensures data integrity before processing API notes
#   - Workflow: Validate historical data → Recover from gaps
#
# Example:
#   export RET_FUNC=0
#   export SCRIPT_BASE_DIRECTORY="/path/to/scripts"
#   export ERROR_EXECUTING_PLANET_DUMP=250
#   export ERROR_GENERAL=1
#   __validateHistoricalDataAndRecover
#   # Validates historical data, recovers from gaps, exits on failure
#
# Related: __checkHistoricalData() (validates historical data)
# Related: __recover_from_gaps() (recovers from data gaps)
# Related: __create_failed_marker() (creates failed execution marker)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
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

 # shellcheck disable=SC2310
 # Function is invoked in if condition intentionally
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
##
# Creates base database structure and loads initial data from Planet
# Executes processPlanetNotes.sh --base to create complete database structure and load
# historical data. Releases lock file before spawning child process, then re-acquires
# lock after completion. Verifies geographic data (countries/maritimes) was loaded.
# Two-step process: (1) Create base structure, (2) Verify geographic data.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   Exits with ERROR_EXECUTING_PLANET_DUMP if base structure creation failed
#   Exits with ERROR_EXECUTING_PLANET_DUMP if geographic data verification failed
#   Returns 0 if base structure created and geographic data verified successfully
#
# Error codes:
#   0: Success - Base structure created and geographic data verified
#   ERROR_EXECUTING_PLANET_DUMP: Failure - processPlanetNotes.sh --base failed (exits script)
#   ERROR_EXECUTING_PLANET_DUMP: Failure - Geographic data not loaded (exits script)
#   1: Failure - Failed to re-acquire lock after child processes (exits script)
#
# Error conditions:
#   0: Success - Base structure created and geographic data verified
#   ERROR_EXECUTING_PLANET_DUMP: processPlanetNotes.sh --base failed - Script execution failed
#   ERROR_EXECUTING_PLANET_DUMP: Geographic data missing - Countries table empty after base load
#   1: Lock re-acquisition failed - Another process acquired lock during child execution
#
# Context variables:
#   Reads:
#     - NOTES_SYNC_SCRIPT: Path to processPlanetNotes.sh script (required)
#     - LOCK: Path to lock file (required)
#     - ORIGINAL_PID: Original process ID (required)
#     - BASENAME: Script basename (required)
#     - PROCESS_START_TIME: Process start time (required)
#     - TMP_DIR: Temporary directory (required)
#     - PROCESS_TYPE: Process type (required)
#     - DBNAME: PostgreSQL database name (required)
#     - PGAPPNAME: PostgreSQL application name (optional)
#     - SKIP_AUTO_LOAD_COUNTRIES: If "true", skips geographic data verification (optional)
#     - HYBRID_MOCK_MODE: If set, skips geographic data verification (optional)
#     - TEST_MODE: If set, skips geographic data verification (optional)
#     - LOCK_DIR: Lock directory (required)
#     - SCRIPT_BASE_DIRECTORY: Base directory for scripts (required)
#     - ERROR_EXECUTING_PLANET_DUMP: Error code for Planet dump failures (defined in calling script)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies:
#     - Releases lock file descriptor (exec 8>&-)
#     - Re-acquires lock file after child processes
#     - Updates lock file content with re-acquisition timestamp
#
# Side effects:
#   - Releases lock file before spawning child process
#   - Executes processPlanetNotes.sh --base (creates base structure, loads historical data)
#   - Verifies geographic data (countries/maritimes) was loaded
#   - Checks for updateCountries.sh lock file (stale lock detection)
#   - Re-acquires lock file after child processes complete
#   - Updates lock file content with re-acquisition timestamp
#   - Creates failed execution marker if base structure creation fails
#   - Writes log messages to stderr
#   - Exits script with error code on failure
#   - Database operations: Queries countries table count
#   - File operations: Lock file management
#
# Notes:
#   - Two-step process: (1) Create base structure, (2) Verify geographic data
#   - Releases lock before child process to prevent lock conflicts
#   - Re-acquires lock after child process to maintain single execution guarantee
#   - Geographic data verification can be skipped in test/hybrid mode
#   - Checks for stale updateCountries.sh lock files
#   - Critical function: Initializes database for first-time use
#   - Takes approximately 1-2 hours for complete setup
#   - Used when base tables are missing (RET_FUNC=1 from __checkBaseTables)
#
# Example:
#   export NOTES_SYNC_SCRIPT="/path/to/processPlanetNotes.sh"
#   export LOCK="/tmp/processAPINotes.lock"
#   export ERROR_EXECUTING_PLANET_DUMP=250
#   __createBaseStructure
#   # Creates base structure, loads historical data, verifies geographic data
#
# Related: processPlanetNotes.sh (creates base structure)
# Related: __checkBaseTables() (checks if base tables exist)
# Related: __setupLockFile() (creates lock file)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
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
  # In hybrid/test mode with SKIP_AUTO_LOAD_COUNTRIES, countries may not be loaded automatically
  # This is expected behavior - the test will load countries separately if needed
  if [[ "${SKIP_AUTO_LOAD_COUNTRIES:-false}" == "true" ]] || [[ -n "${HYBRID_MOCK_MODE:-}" ]] || [[ -n "${TEST_MODE:-}" ]]; then
   __logw "No geographic data found after processPlanetNotes.sh --base"
   __logw "SKIP_AUTO_LOAD_COUNTRIES is enabled (hybrid/test mode) - countries will be loaded separately if needed"
   __logw "Continuing without geographic data verification (expected in test mode)"
  else
   __logw "No geographic data found after processPlanetNotes.sh --base"
   __logw "processPlanetNotes.sh should have loaded countries automatically via __processGeographicData()"

   local UPDATE_COUNTRIES_LOCK="${LOCK_DIR}/updateCountries.lock"
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
 local LOCK_REACQUIRED_TIME
 LOCK_REACQUIRED_TIME=$(date '+%Y-%m-%d %H:%M:%S' 2> /dev/null || echo 'unknown')
 cat > "${LOCK}" << EOF
PID: ${ORIGINAL_PID}
Process: ${BASENAME}
Started: ${PROCESS_START_TIME}
Temporary directory: ${TMP_DIR}
Process type: ${PROCESS_TYPE}
Main script: ${0}
Lock re-acquired: ${LOCK_REACQUIRED_TIME}
EOF
 __logd "Lock file content updated after child processes: ${LOCK}"
 __log_finish
}

##
# Checks and logs data gaps from database to file
# Queries database for unprocessed gaps from the last 24 hours and writes them to a log file.
# Used for monitoring data integrity issues. Only queries gaps that haven't been processed
# (processed = FALSE). Writes up to 10 most recent gaps to log file.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   Always returns 0 (non-blocking, errors are logged but don't fail)
#
# Error codes:
#   0: Success - Gaps checked and logged (or no gaps found)
#
# Error conditions:
#   0: Success - Gaps checked and logged successfully
#   0: Success - No gaps found (valid scenario)
#   0: Success - Query failed (logged but doesn't fail function)
#
# Context variables:
#   Reads:
#     - DBNAME: PostgreSQL database name (required)
#     - PGAPPNAME: PostgreSQL application name (optional)
#     - LOG_DIR: Log directory (optional, default: /tmp)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies:
#     - Creates/updates gap log file (processAPINotes_gaps.log)
#
# Side effects:
#   - Queries database for unprocessed gaps (last 24 hours, limit 10)
#   - Writes gap information to log file
#   - Writes log messages to stderr
#   - Database operations: SELECT from data_gaps table
#   - File operations: Writes to gap log file
#   - No network operations
#
# Notes:
#   - Only queries gaps from last 24 hours (recent gaps)
#   - Only queries unprocessed gaps (processed = FALSE)
#   - Limits results to 10 most recent gaps
#   - Non-blocking function (errors don't cause function failure)
#   - Used for monitoring and troubleshooting data integrity issues
#   - Part of processing workflow (called after processing API notes)
#   - Gap log file: processAPINotes_gaps.log
#
# Example:
#   export DBNAME="osm_notes"
#   export LOG_DIR="/var/log/osm-notes"
#   __check_and_log_gaps
#   # Queries and logs gaps to /var/log/osm-notes/processAPINotes_gaps.log
#
# Related: __log_data_gap() (logs individual gaps to file and database)
# Related: __recover_from_gaps() (detects and recovers from gaps)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
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
 local GAP_FILE="${LOG_DIR:-/tmp}/processAPINotes_gaps.log"
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -Atq -c "${GAP_QUERY}" > "${GAP_FILE}" 2> /dev/null || true

 __logd "Checked and logged gaps from database"
 __log_finish
}

# Function that activates the error trap.
##
# Activates error and signal traps for error handling and cleanup
# Sets up ERR trap to catch errors and SIGINT/SIGTERM traps to handle termination.
# ERR trap logs error details, creates failed execution marker file, and exits with
# error code. SIGINT/SIGTERM trap logs termination message, creates failed execution
# marker, and exits with ERROR_GENERAL. Ensures lock file is removed on error/termination.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   Always returns 0 (trap setup is always successful)
#
# Error codes:
#   0: Success - Traps activated successfully
#
# Error conditions:
#   0: Success - Traps activated successfully
#
# Context variables:
#   Reads:
#     - GENERATE_FAILED_FILE: If "true", creates failed execution marker (optional, default: true)
#     - FAILED_EXECUTION_FILE: Path to failed execution marker file (optional)
#     - TMP_DIR: Temporary directory (optional)
#     - ONLY_EXECUTION: Execution status (optional)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies:
#     - Sets ERR trap for error handling
#     - Sets SIGINT/SIGTERM traps for termination handling
#
# Side effects:
#   - Sets ERR trap to catch command failures
#   - Sets SIGINT/SIGTERM traps to catch termination signals
#   - Creates failed execution marker file on error/termination (if GENERATE_FAILED_FILE=true)
#   - Writes log messages to stderr
#   - Exits script with error code on ERR trap
#   - Exits script with ERROR_GENERAL on SIGINT/SIGTERM
#   - No database or network operations
#
# Notes:
#   - ERR trap catches any command that returns non-zero exit code
#   - Trap handlers execute in subshell context (cannot use 'local' variables)
#   - Failed execution marker contains error details (timestamp, script, line, command, exit code)
#   - Lock file removal is handled by trap handlers
#   - Critical function: Ensures proper error handling and cleanup
#   - Trap handlers use printf for output (more reliable than echo in traps)
#   - Fallback failed execution file created if primary location fails
#
# Example:
#   export GENERATE_FAILED_FILE="true"
#   export FAILED_EXECUTION_FILE="/tmp/processAPINotes_failed_execution"
#   __trapOn
#   # Traps are now active, errors will be caught and logged
#
# Related: __setupLockFile() (creates lock file, removed by trap handlers)
# Related: __checkPreviousFailedExecution() (checks for failed execution marker)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
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
     } > "${FAILED_FILE_PATH}" 2> /dev/null || {
      # If writing to primary location fails, try /tmp as fallback
      printf "%s ERROR: Failed to write failed execution file to %s\n" "$(date +%Y%m%d_%H:%M:%S)" "${FAILED_FILE_PATH}" > "/tmp/${MAIN_SCRIPT_NAME}_failed_execution_fallback" 2> /dev/null || true
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
    } > "${FAILED_FILE_PATH}" 2> /dev/null || {
     # If writing to primary location fails, try /tmp as fallback
     printf "%s WARN: Script terminated but failed to write failed execution file to %s\n" "$(date +%Y%m%d_%H:%M:%S)" "${FAILED_FILE_PATH}" > "/tmp/${MAIN_SCRIPT_NAME}_failed_execution_fallback" 2> /dev/null || true
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
 # Only check when script is executed directly, not when sourced (for testing)
 if [[ "${BASH_SOURCE[0]}" == "${0}" ]] && [[ -f "${FAILED_EXECUTION_FILE}" ]]; then
  # Check if the failure was due to network issues
  if grep -q "Network connectivity\|API download failed\|Internet issues" "${FAILED_EXECUTION_FILE}" 2> /dev/null; then
   __logw "Previous execution failed due to network issues. Verifying connectivity..."
   # Verify network connectivity before blocking
   # shellcheck disable=SC2310
   # Function is invoked in if condition intentionally
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
 # shellcheck disable=SC2310
 # Function is invoked in if condition intentionally
 if ! __checkBaseTables; then
  :
 fi
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
  FILE_RET_FUNC=$(head -1 "${RET_FUNC_FILE}" 2> /dev/null || echo "")
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
     } > "${FAILED_FILE_PATH}" 2> /dev/null || {
      # If writing to primary location fails, try /tmp as fallback
      printf "%s ERROR: Failed to write failed execution file to %s\n" "$(date +%Y%m%d_%H:%M:%S)" "${FAILED_FILE_PATH}" > "/tmp/${MAIN_SCRIPT_NAME}_failed_execution_fallback" 2> /dev/null || true
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
# Return value for several functions (may be used externally or in future)
# shellcheck disable=SC2034
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
   mv "${LOG_FILENAME}" "${LOG_DIR}/${BASENAME}_$(date +%Y-%m-%d_%H-%M-%S || true).log"
   # Protect rmdir from causing script exit if it fails (e.g., TMP_DIR not empty or doesn't exist)
   rmdir "${TMP_DIR}" 2> /dev/null || true
  fi
 else
  __start_logger
  main
 fi
# else: script is being sourced, do nothing (just load functions)
fi
