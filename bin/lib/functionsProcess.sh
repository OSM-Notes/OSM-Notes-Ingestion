#!/bin/bash

# OSM-Notes-profile - Common Functions
# This file serves as the main entry point for all common functions.
# It loads all function modules for use across the project.
#
# Author: Andres Gomez (AngocA)
# Version: 2025-12-29
VERSION="2025-12-29"

# shellcheck disable=SC2317,SC2155
# NOTE: SC2154 warnings are expected as many variables are defined in sourced files

# Define script base directory (only if not already defined)
if [[ -z "${SCRIPT_BASE_DIRECTORY:-}" ]]; then
 SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# Define common variables (only if not already defined)
if [[ -z "${BASENAME:-}" ]]; then
 BASENAME="$(basename "${BASH_SOURCE[0]}" .sh)"
fi

if [[ -z "${TMP_DIR:-}" ]]; then
 TMP_DIR="/tmp/${BASENAME}_$$"
fi

# Define query file variable (only if not already defined)
if [[ -z "${QUERY_FILE:-}" ]]; then
 QUERY_FILE="${TMP_DIR}/query.op"
fi

# Load all function modules
# This provides organized access to all project functions

# Load common functions (error codes, logger, prerequisites, etc.)
if [[ -f "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/commonFunctions.sh" ]]; then
 # shellcheck source=commonFunctions.sh
 source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/commonFunctions.sh"
else
 echo "ERROR: commonFunctions.sh not found"
 exit 1
fi

# Load validation functions
if [[ -f "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/validationFunctions.sh" ]]; then
 # shellcheck source=validationFunctions.sh
 source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/validationFunctions.sh"
else
 echo "ERROR: validationFunctions.sh not found"
 exit 1
fi

# Load security functions (SQL sanitization)
if [[ -f "${SCRIPT_BASE_DIRECTORY}/bin/lib/securityFunctions.sh" ]]; then
 # shellcheck source=securityFunctions.sh
 source "${SCRIPT_BASE_DIRECTORY}/bin/lib/securityFunctions.sh"
else
 echo "ERROR: securityFunctions.sh not found"
 exit 1
fi

# Load error handling functions
if [[ -f "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/errorHandlingFunctions.sh" ]]; then
 # shellcheck source=errorHandlingFunctions.sh
 source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/errorHandlingFunctions.sh"
else
 echo "ERROR: errorHandlingFunctions.sh not found"
 exit 1
fi

# Load Overpass helper functions
if [[ -f "${SCRIPT_BASE_DIRECTORY}/bin/lib/overpassFunctions.sh" ]]; then
 # shellcheck source=overpassFunctions.sh
 source "${SCRIPT_BASE_DIRECTORY}/bin/lib/overpassFunctions.sh"
fi

# ----------------------------------------------------------------------
# Overpass smart wait helpers (centralized definitions)
# ----------------------------------------------------------------------
: "${OVERPASS_RETRIES_PER_ENDPOINT:=7}"
: "${OVERPASS_BACKOFF_SECONDS:=20}"

# Retry file operations with exponential backoff and cleanup on failure.
##
# Executes a file operation command with retry logic, exponential backoff, and smart wait queue management
# Provides robust retry mechanism for file operations (downloads, API calls) with exponential backoff,
# output file verification, HTML error page detection, and optional smart wait queue integration for
# Overpass API rate limiting. Verifies output files exist and have content, detects HTML error pages
# returned as HTTP 200, and manages download slots for concurrent operations.
#
# Parameters:
#   $1: Operation command - Shell command to execute (required, e.g., "curl -o file.txt URL")
#   $2: Max retries - Maximum retry attempts (optional, default: OVERPASS_RETRIES_PER_ENDPOINT or 7)
#   $3: Base delay - Base delay in seconds for exponential backoff (optional, default: OVERPASS_BACKOFF_SECONDS or 20)
#   $4: Cleanup command - Command to execute on failure for cleanup (optional, e.g., "rm -f file.txt")
#   $5: Smart wait - Enable smart wait queue for Overpass API (optional, default: false, use "true" to enable)
#   $6: Smart wait endpoint - Explicit Overpass endpoint URL for smart wait (optional, auto-detected if command contains "/api/interpreter")
#
# Returns:
#   0: Success - Operation completed successfully and output file verified
#   1: Failure - Operation failed after all retries or output file verification failed
#
# Error codes:
#   0: Success - Command executed successfully, output file exists and has content, not HTML error page
#   1: Failure - Command failed after max retries, output file missing/empty, or HTML error page detected
#
# Context variables:
#   Reads:
#     - OVERPASS_RETRIES_PER_ENDPOINT: Default max retries (optional, default: 7)
#     - OVERPASS_BACKOFF_SECONDS: Default base delay (optional, default: 20)
#     - OVERPASS_INTERPRETER: Overpass API endpoint URL (required if smart_wait enabled)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies: None
#
# Side effects:
#   - Executes operation command via eval (use with caution, ensure command is trusted)
#   - Creates/verifies output files (extracted from -o or > redirection in command)
#   - Manages download slots via __wait_for_download_slot() and __release_download_slot() if smart_wait enabled
#   - Checks Overpass API status via __check_overpass_status() if smart_wait enabled
#   - Executes cleanup command on failure if provided
#   - Sets EXIT/INT/TERM traps for cleanup on smart wait operations
#   - Logs all operations and retry attempts to standard logger
#   - Sleeps between retries with exponential backoff (delay *= 1.5)
#
# Output file verification:
#   - Extracts output file path from command (-o or > redirection)
#   - Verifies file exists and is non-empty
#   - Detects HTML error pages (checks for <html>, <body>, <head>, <!DOCTYPE>)
#   - For aria2c commands, also checks -d directory option
#
# Example:
#   if __retry_file_operation "curl -s -o /tmp/data.json https://api.example.com/data" 5 10 "rm -f /tmp/data.json" "true"; then
#     echo "Download succeeded"
#   else
#     echo "Download failed"
#   fi
#
# Related: __wait_for_download_slot() (manages download queue)
# Related: __release_download_slot() (releases download slot)
# Related: __check_overpass_status() (checks API availability)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
function __retry_file_operation() {
 __log_start
 local OPERATION_COMMAND="$1"
 local MAX_RETRIES_LOCAL="${2:-${OVERPASS_RETRIES_PER_ENDPOINT:-7}}"
 local BASE_DELAY_LOCAL="${3:-${OVERPASS_BACKOFF_SECONDS:-20}}"
 local CLEANUP_COMMAND="${4:-}"
 local SMART_WAIT="${5:-false}"
 local SMART_WAIT_ENDPOINT="${6:-}"
 local RETRY_COUNT=0
 local EXPONENTIAL_DELAY="${BASE_DELAY_LOCAL}"

 __logd "Executing file operation with retry logic: ${OPERATION_COMMAND}"
 __logd "Max retries: ${MAX_RETRIES_LOCAL}, Base delay: ${BASE_DELAY_LOCAL}s, Smart wait: ${SMART_WAIT}"

 local EFFECTIVE_OVERPASS_FOR_WAIT="${SMART_WAIT_ENDPOINT:-}"
 if [[ -z "${EFFECTIVE_OVERPASS_FOR_WAIT}" ]] && [[ "${OPERATION_COMMAND}" == *"/api/interpreter"* ]]; then
  EFFECTIVE_OVERPASS_FOR_WAIT="${OVERPASS_INTERPRETER}"
 fi

 if [[ "${SMART_WAIT}" == "true" ]] && [[ -n "${EFFECTIVE_OVERPASS_FOR_WAIT}" ]]; then
  if ! __wait_for_download_slot; then
   __loge "Failed to obtain download slot after waiting"
   trap - EXIT INT TERM
   __log_finish
   return 1
  fi
  __logd "Download slot acquired, proceeding with download"

  # Probe Overpass status before continuing (non-blocking best effort)
  local STATUS_PROBE="0"
  set +e # Allow errors in wait
  local STATUS_OUTPUT
  # shellcheck disable=SC2310,SC2311
  # SC2310: Intentional: check return value explicitly
  # SC2311: Intentional: function in command substitution
  STATUS_OUTPUT=$(__check_overpass_status 2> /dev/null || echo "")
  STATUS_PROBE=$(echo "${STATUS_OUTPUT}" | tail -1 || echo "0")
  set -e
  __logd "Overpass status probe returned: ${STATUS_PROBE}"

  # shellcheck disable=SC2310,SC2317
  # SC2310: Intentional: cleanup failures should not stop execution
  # SC2317: Function is invoked indirectly via trap
  __cleanup_slot() {
   __release_download_slot > /dev/null 2>&1 || true
  }
  trap '__cleanup_slot' EXIT INT TERM
 fi

 while [[ ${RETRY_COUNT} -lt ${MAX_RETRIES_LOCAL} ]]; do
  __logd "Attempt $((RETRY_COUNT + 1))/${MAX_RETRIES_LOCAL}: Executing command"
  if eval "${OPERATION_COMMAND}"; then
   local CMD_EXIT_CODE=$?
   __logd "Command returned exit code: ${CMD_EXIT_CODE}"
   # Verify output file exists and has content (if command uses -o or > redirection)
   # Extract output file from command if it contains -o or > redirection
   local OUTPUT_FILE_CHECK=""
   local OUTPUT_DIR_CHECK=""
   if echo "${OPERATION_COMMAND}" | grep -qE '\s-o\s+[^ ]+'; then
    # Extract file after -o
    local GREP_RESULT
    GREP_RESULT=$(echo "${OPERATION_COMMAND}" | grep -oE '\s-o\s+[^ ]+' || echo "")
    local AWK_RESULT
    AWK_RESULT=$(echo "${GREP_RESULT}" | awk '{print $2}' || echo "")
    OUTPUT_FILE_CHECK=$(echo "${AWK_RESULT}" | head -1 || echo "")
    __logd "Extracted output file from -o: ${OUTPUT_FILE_CHECK}"
    # For aria2c, also check for -d option (output directory)
    if echo "${OPERATION_COMMAND}" | grep -qE '\s-d\s+[^ ]+'; then
     local GREP_RESULT_DIR
     GREP_RESULT_DIR=$(echo "${OPERATION_COMMAND}" | grep -oE '\s-d\s+[^ ]+' || echo "")
     local AWK_RESULT_DIR
     AWK_RESULT_DIR=$(echo "${GREP_RESULT_DIR}" | awk '{print $2}' || echo "")
     OUTPUT_DIR_CHECK=$(echo "${AWK_RESULT_DIR}" | head -1 || echo "")
     __logd "Extracted output directory from -d: ${OUTPUT_DIR_CHECK}"
    fi
   elif echo "${OPERATION_COMMAND}" | grep -qE '\s>\s+[^ ]+'; then
    # Extract file after >
    local GREP_RESULT_REDIRECT
    GREP_RESULT_REDIRECT=$(echo "${OPERATION_COMMAND}" | grep -oE '\s>\s+[^ ]+' || echo "")
    local AWK_RESULT_REDIRECT
    AWK_RESULT_REDIRECT=$(echo "${GREP_RESULT_REDIRECT}" | awk '{print $2}' || echo "")
    OUTPUT_FILE_CHECK=$(echo "${AWK_RESULT_REDIRECT}" | head -1 || echo "")
    __logd "Extracted output file from >: ${OUTPUT_FILE_CHECK}"
   fi

   # If we found an output file, verify it exists and has content
   if [[ -n "${OUTPUT_FILE_CHECK}" ]]; then
    # Expand variables in file path (e.g., ${TMP_DIR}/file.txt)
    local EXPANDED_OUTPUT_FILE
    if [[ -n "${OUTPUT_DIR_CHECK}" ]]; then
     # For aria2c with -d and -o, combine directory and file
     local EXPANDED_DIR
     EXPANDED_DIR=$(eval echo "${OUTPUT_DIR_CHECK}" 2> /dev/null || echo "${OUTPUT_DIR_CHECK}")
     local EXPANDED_FILE
     EXPANDED_FILE=$(eval echo "${OUTPUT_FILE_CHECK}" 2> /dev/null || echo "${OUTPUT_FILE_CHECK}")
     EXPANDED_OUTPUT_FILE="${EXPANDED_DIR}/${EXPANDED_FILE}"
     __logd "Combined output file path (aria2c -d -o): ${EXPANDED_OUTPUT_FILE}"
    else
     EXPANDED_OUTPUT_FILE=$(eval echo "${OUTPUT_FILE_CHECK}" 2> /dev/null || echo "${OUTPUT_FILE_CHECK}")
     __logd "Expanded output file path: ${EXPANDED_OUTPUT_FILE}"
    fi

    if [[ ! -f "${EXPANDED_OUTPUT_FILE}" ]]; then
     __logw "File operation reported success but output file does not exist: ${EXPANDED_OUTPUT_FILE}"
     # Continue to retry
    elif [[ ! -s "${EXPANDED_OUTPUT_FILE}" ]]; then
     __logw "File operation reported success but output file is empty: ${EXPANDED_OUTPUT_FILE}"
     # Continue to retry
    else
     # File exists and has content - validate it's not HTML error page
     # (Overpass may return HTML error pages with HTTP 200)
     local IS_HTML_ERROR=false
     if [[ "${OPERATION_COMMAND}" == *"/api/interpreter"* ]]; then
      # Check if file contains HTML error page
      local HEAD_RESULT
      HEAD_RESULT=$(head -5 "${EXPANDED_OUTPUT_FILE}" 2> /dev/null || echo "")
      if echo "${HEAD_RESULT}" | grep -qiE "<html|<body|<head|<!DOCTYPE" || false; then
       IS_HTML_ERROR=true
       __logw "Overpass returned HTML error page instead of expected format (CSV/JSON)"
       # Extract error message if available
       local ERROR_MSG=""
       local GREP_ERROR_RESULT
       GREP_ERROR_RESULT=$(grep -iE "error|timeout|too busy" "${EXPANDED_OUTPUT_FILE}" 2> /dev/null || echo "")
       local HEAD_ERROR_RESULT
       HEAD_ERROR_RESULT=$(echo "${GREP_ERROR_RESULT}" | head -1 || echo "")
       local SED_RESULT
       # shellcheck disable=SC2001
       # Using sed for regex pattern matching is necessary here
       SED_RESULT=$(echo "${HEAD_ERROR_RESULT}" | sed 's/<[^>]*>//g' || echo "")
       local TR_RESULT
       TR_RESULT=$(echo "${SED_RESULT}" | tr -d '\n' || echo "")
       local CUT_RESULT
       CUT_RESULT=$(echo "${TR_RESULT}" | cut -c1-100 || echo "")
       if [[ -n "${CUT_RESULT}" ]]; then
        ERROR_MSG="${CUT_RESULT}"
       fi
       if [[ -n "${ERROR_MSG}" ]]; then
        __logw "Error message: ${ERROR_MSG}"
       fi
      fi
     fi

     if [[ "${IS_HTML_ERROR}" == "true" ]]; then
      __logw "File operation returned HTML error - will retry (attempt $((RETRY_COUNT + 1))/${MAX_RETRIES_LOCAL})"
      # Continue to retry
     else
      # File exists, has content, and is not HTML error - operation truly succeeded
      local FILE_SIZE
      # shellcheck disable=SC2012
      # Using ls for human-readable file size is acceptable here
      local LS_RESULT
      LS_RESULT=$(ls -lh "${EXPANDED_OUTPUT_FILE}" 2> /dev/null || echo "")
      FILE_SIZE=$(echo "${LS_RESULT}" | awk '{print $5}' || echo "unknown")
      __logd "File operation succeeded on attempt $((RETRY_COUNT + 1)) (file verified: ${EXPANDED_OUTPUT_FILE}, size: ${FILE_SIZE})"
      if [[ "${SMART_WAIT}" == "true" ]] && [[ -n "${EFFECTIVE_OVERPASS_FOR_WAIT}" ]]; then
       # shellcheck disable=SC2310
       # Intentional: release failures should not stop execution
       __release_download_slot > /dev/null 2>&1 || true
      fi
      trap - EXIT INT TERM
      __log_finish
      return 0
     fi
    fi
   else
    # No output file to verify - assume success based on exit code
    __logd "File operation succeeded on attempt $((RETRY_COUNT + 1)) (no output file to verify)"
    if [[ "${SMART_WAIT}" == "true" ]] && [[ -n "${EFFECTIVE_OVERPASS_FOR_WAIT}" ]]; then
     __release_download_slot > /dev/null 2>&1 || true
    fi
    trap - EXIT INT TERM
    __log_finish
    return 0
   fi
  else
   if [[ "${OPERATION_COMMAND}" == *"/api/interpreter"* ]]; then
    __logw "Overpass API call failed on attempt $((RETRY_COUNT + 1))"
    if [[ -f "${OUTPUT_OVERPASS:-}" ]]; then
     local ERROR_LINE
     local GREP_ERROR_RESULT
     GREP_ERROR_RESULT=$(grep -i "error" "${OUTPUT_OVERPASS}" || echo "")
     ERROR_LINE=$(echo "${GREP_ERROR_RESULT}" | head -1 || echo "")
     if [[ -n "${ERROR_LINE}" ]]; then
      __logw "Overpass error detected: ${ERROR_LINE}"
     fi
    fi
   else
    __logw "File operation failed on attempt $((RETRY_COUNT + 1))"
   fi
  fi

  RETRY_COUNT=$((RETRY_COUNT + 1))

  if [[ ${RETRY_COUNT} -lt ${MAX_RETRIES_LOCAL} ]]; then
   __logw "Retrying operation in ${EXPONENTIAL_DELAY}s (remaining attempts: $((MAX_RETRIES_LOCAL - RETRY_COUNT)))"
   sleep "${EXPONENTIAL_DELAY}"
   EXPONENTIAL_DELAY=$((EXPONENTIAL_DELAY * 3 / 2))
  fi
 done

 if [[ -n "${CLEANUP_COMMAND}" ]]; then
  __logw "Executing cleanup command due to file operation failure"
  if eval "${CLEANUP_COMMAND}"; then
   __logd "Cleanup command executed successfully"
  else
   __logw "Cleanup command failed"
  fi
 fi

 __loge "File operation failed after ${MAX_RETRIES_LOCAL} attempts"
 if [[ "${SMART_WAIT}" == "true" ]] && [[ -n "${EFFECTIVE_OVERPASS_FOR_WAIT}" ]]; then
  # shellcheck disable=SC2310
  # Intentional: release failures should not stop execution
  __release_download_slot > /dev/null 2>&1 || true
 fi
 trap - EXIT INT TERM
 __log_finish
 return 1
}

# Check Overpass API status and wait time.
# Returns:
#  - echoes 0 when slots are available immediately.
#  - echoes wait time in seconds when busy.
##
# Checks Overpass API status and returns wait time if busy
# Queries Overpass API status endpoint to determine if slots are available.
# Returns wait time in seconds if API is busy, or 0 if slots are available now.
#
# Parameters:
#   None (uses OVERPASS_INTERPRETER environment variable)
#
# Returns:
#   Exit code: 0 (always succeeds)
#   Output: Wait time in seconds (0 if available now, >0 if busy)
#
# Error codes:
#   0: Always succeeds (even if status check fails, assumes available)
#   Output value: 0 = available now, >0 = wait time in seconds
#
# Error conditions:
#   - Network failure: Returns 0 (assumes available) with warning log
#   - Parse failure: Returns 0 (assumes available) with warning log
#   - API busy: Returns wait time > 0
#   - API available: Returns 0
#
# Context variables:
#   Reads:
#     - OVERPASS_INTERPRETER: Overpass API endpoint URL (required, e.g., https://overpass-api.de/api/interpreter)
#     - DOWNLOAD_USER_AGENT: User-Agent header for HTTP requests (optional, default: OSM-Notes-Ingestion/1.0)
#     - RATE_LIMIT: Maximum concurrent slots (for logging, optional, default: 4)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies: None
#
# Side effects:
#   - Queries Overpass API status endpoint via HTTP GET
#   - Parses status page HTML to extract slot availability
#   - Outputs wait time to stdout (use command substitution to capture)
#   - Logs status check results to standard logger
#   - No file or database operations
#
# Output format:
#   - Single integer on stdout: wait time in seconds
#   - 0: Slots available now
#   - >0: Minimum wait time until next slot available
#
# Example:
#   WAIT_TIME=$(__check_overpass_status)
#   if [[ ${WAIT_TIME} -eq 0 ]]; then
#     echo "API available now"
#   else
#     echo "Wait ${WAIT_TIME} seconds"
#   fi
#
# Related: __wait_for_download_slot() (uses this to check status)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
function __check_overpass_status() {
 __log_start
 local BASE_URL="${OVERPASS_INTERPRETER%/api/interpreter}"
 BASE_URL="${BASE_URL%/}"
 local STATUS_URL="${BASE_URL}/status"
 local STATUS_OUTPUT
 local AVAILABLE_SLOTS
 local WAIT_TIME

 __logd "Checking Overpass API status at ${STATUS_URL}..."

 if ! STATUS_OUTPUT=$(curl -s -H "User-Agent: ${DOWNLOAD_USER_AGENT:-OSM-Notes-Ingestion/1.0}" "${STATUS_URL}" 2>&1); then
  __logw "Could not reach Overpass API status page, assuming available"
  __log_finish
  echo "0"
  return 0
 fi

 local SLOTS_LINE
 local GREP_SLOTS_RESULT
 GREP_SLOTS_RESULT=$(echo "${STATUS_OUTPUT}" | grep -o '[0-9]* slots available now' || echo "")
 SLOTS_LINE=$(echo "${GREP_SLOTS_RESULT}" | head -1 || echo "")
 AVAILABLE_SLOTS=$(echo "${SLOTS_LINE}" | grep -o '[0-9]*' || echo "0")

 if [[ -n "${AVAILABLE_SLOTS}" ]] && [[ "${AVAILABLE_SLOTS}" -gt 0 ]]; then
  __logd "Overpass API has ${AVAILABLE_SLOTS} slot(s) available now"
  __log_finish
  echo "0"
  return 0
 fi

 local ALL_WAIT_TIMES
 local WAIT_LINES
 WAIT_LINES=$(echo "${STATUS_OUTPUT}" | grep -o 'in [0-9]* seconds' || echo "")
 ALL_WAIT_TIMES=$(echo "${WAIT_LINES}" | grep -o '[0-9]*' || echo "")

 if [[ -n "${ALL_WAIT_TIMES}" ]]; then
  local SORTED_TIMES
  SORTED_TIMES=$(echo "${ALL_WAIT_TIMES}" | sort -n || echo "")
  WAIT_TIME=$(echo "${SORTED_TIMES}" | head -1 || echo "0")
  if [[ -n "${WAIT_TIME}" ]] && [[ ${WAIT_TIME} -gt 0 ]]; then
   __logd "Overpass API busy, next slot available in ${WAIT_TIME} seconds (from ${RATE_LIMIT:-4} slots)"
   __log_finish
   echo "${WAIT_TIME}"
   return 0
  fi
 fi

 __logd "Could not determine Overpass API status, assuming available"
 __log_finish
 echo "0"
 return 0
}

# Load boundary processing helper functions
if [[ -f "${SCRIPT_BASE_DIRECTORY}/bin/lib/boundaryProcessingFunctions.sh" ]]; then
 # shellcheck source=boundaryProcessingFunctions.sh
 source "${SCRIPT_BASE_DIRECTORY}/bin/lib/boundaryProcessingFunctions.sh"
fi

# Load note processing helper functions
if [[ -f "${SCRIPT_BASE_DIRECTORY}/bin/lib/noteProcessingFunctions.sh" ]]; then
 # shellcheck source=noteProcessingFunctions.sh
 source "${SCRIPT_BASE_DIRECTORY}/bin/lib/noteProcessingFunctions.sh"
fi

# Load API-specific functions if needed
if [[ -f "${SCRIPT_BASE_DIRECTORY}/bin/lib/processAPIFunctions.sh" ]]; then
 # shellcheck source=processAPIFunctions.sh
 source "${SCRIPT_BASE_DIRECTORY}/bin/lib/processAPIFunctions.sh"
fi

# Load Planet-specific functions if needed
if [[ -f "${SCRIPT_BASE_DIRECTORY}/bin/lib/processPlanetFunctions.sh" ]]; then
 # shellcheck source=processPlanetFunctions.sh
 source "${SCRIPT_BASE_DIRECTORY}/bin/lib/processPlanetFunctions.sh"
fi

# Load consolidated parallel processing functions (must be loaded AFTER wrapper functions)
if [[ -f "${SCRIPT_BASE_DIRECTORY}/bin/lib/parallelProcessingFunctions.sh" ]]; then
 # shellcheck source=parallelProcessingFunctions.sh
 source "${SCRIPT_BASE_DIRECTORY}/bin/lib/parallelProcessingFunctions.sh"
fi

# Output CSV files for processed data
# Only set if not already declared (e.g., when sourced from another script)
# shellcheck disable=SC2034
if ! declare -p OUTPUT_NOTES_CSV_FILE > /dev/null 2>&1; then
 declare -r OUTPUT_NOTES_CSV_FILE="${TMP_DIR}/output-notes.csv"
fi
# shellcheck disable=SC2034
if ! declare -p OUTPUT_NOTE_COMMENTS_CSV_FILE > /dev/null 2>&1; then
 declare -r OUTPUT_NOTE_COMMENTS_CSV_FILE="${TMP_DIR}/output-note_comments.csv"
fi
# shellcheck disable=SC2034
if ! declare -p OUTPUT_TEXT_COMMENTS_CSV_FILE > /dev/null 2>&1; then
 declare -r OUTPUT_TEXT_COMMENTS_CSV_FILE="${TMP_DIR}/output-text_comments.csv"
fi

# PostgreSQL SQL script files
# Check base tables.
# Only set if not already declared (e.g., when sourced from another script)
if ! declare -p POSTGRES_11_CHECK_BASE_TABLES > /dev/null 2>&1; then
 declare -r POSTGRES_11_CHECK_BASE_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_10_checkBaseTables.sql"
fi
if ! declare -p POSTGRES_11_CHECK_HISTORICAL_DATA > /dev/null 2>&1; then
 declare -r POSTGRES_11_CHECK_HISTORICAL_DATA="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_11_checkHistoricalData.sql"
fi
if ! declare -p POSTGRES_12_DROP_GENERIC_OBJECTS > /dev/null 2>&1; then
 declare -r POSTGRES_12_DROP_GENERIC_OBJECTS="${SCRIPT_BASE_DIRECTORY}/sql/consolidated_cleanup.sql"
fi
if ! declare -p POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY > /dev/null 2>&1; then
 declare -r POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_20_createFunctionToGetCountry.sql"
fi
if ! declare -p POSTGRES_22_CREATE_PROC_INSERT_NOTE > /dev/null 2>&1; then
 declare -r POSTGRES_22_CREATE_PROC_INSERT_NOTE="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_21_createProcedure_insertNote.sql"
fi
if ! declare -p POSTGRES_23_CREATE_PROC_INSERT_NOTE_COMMENT > /dev/null 2>&1; then
 declare -r POSTGRES_23_CREATE_PROC_INSERT_NOTE_COMMENT="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_22_createProcedure_insertNoteComment.sql"
fi
if ! declare -p POSTGRES_31_ORGANIZE_AREAS > /dev/null 2>&1; then
 declare -r POSTGRES_31_ORGANIZE_AREAS="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_30_organizeAreas_2DGrid.sql"
fi
if ! declare -p POSTGRES_32_UPLOAD_NOTE_LOCATION > /dev/null 2>&1; then
 declare -r POSTGRES_32_UPLOAD_NOTE_LOCATION="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_31_loadsBackupNoteLocation.sql"
fi
if ! declare -p POSTGRES_33_VERIFY_NOTE_INTEGRITY > /dev/null 2>&1; then
 declare -r POSTGRES_33_VERIFY_NOTE_INTEGRITY="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_33_verifyNoteIntegrity.sql"
fi
if ! declare -p POSTGRES_36_REASSIGN_AFFECTED_NOTES > /dev/null 2>&1; then
 declare -r POSTGRES_36_REASSIGN_AFFECTED_NOTES="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_36_reassignAffectedNotes.sql"
fi
if ! declare -p POSTGRES_37_ASSIGN_COUNTRY_TO_NOTES_CHUNK > /dev/null 2>&1; then
 declare -r POSTGRES_37_ASSIGN_COUNTRY_TO_NOTES_CHUNK="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_32_assignCountryToNotesChunk.sql"
fi
if ! declare -p POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY_STUB > /dev/null 2>&1; then
 declare -r POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY_STUB="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_20_createFunctionToGetCountry_stub.sql"
fi

if [[ -z "${COUNTRIES_BOUNDARY_IDS_FILE:-}" ]]; then
 declare -r COUNTRIES_BOUNDARY_IDS_FILE="${TMP_DIR}/countries_boundary_ids.csv"
fi

if [[ -z "${MARITIME_BOUNDARY_IDS_FILE:-}" ]]; then
 declare -r MARITIME_BOUNDARY_IDS_FILE="${TMP_DIR}/maritime_boundary_ids.csv"
fi

# Configuration variables (if not already defined)
# MAX_NOTES is now defined in etc/properties.sh, no need to declare it here
# Just validate if it's set (only if it's defined)
if [[ -n "${MAX_NOTES:-}" ]] && [[ ! "${MAX_NOTES}" =~ ^[1-9][0-9]*$ ]]; then
 __loge "ERROR: MAX_NOTES must be a positive integer, got: ${MAX_NOTES}"
 # Don't exit in test environment, just log the error
 if [[ -z "${BATS_TEST_NAME:-}" ]]; then
  exit 1
 fi
fi

if [[ -z "${GENERATE_FAILED_FILE:-}" ]]; then
 declare -r GENERATE_FAILED_FILE="false"
fi

if [[ -z "${LOG_FILENAME:-}" ]]; then
 declare -r LOG_FILENAME="${TMP_DIR}/${BASENAME}.log"
fi

# Now uses functions loaded from parallelProcessingFunctions.sh at script startup
function __processXmlPartsParallel() {
 __log_start
 # Check if the consolidated function is available
 if ! declare -f __processXmlPartsParallelConsolidated > /dev/null 2>&1; then
  __loge "ERROR: Consolidated parallel processing functions not available. Please ensure parallelProcessingFunctions.sh was loaded."
  __log_finish
  return 1
 fi
 # Call the consolidated function
 __processXmlPartsParallelConsolidated "$@"
 local RETURN_CODE=$?
 __log_finish
 return "${RETURN_CODE}"
}

# Wrapper function: Split XML for parallel processing (consolidated implementation)
# Now uses functions loaded from parallelProcessingFunctions.sh at script startup
function __splitXmlForParallelSafe() {
 # This is a wrapper function that will be overridden by the real implementation
 # in parallelProcessingFunctions.sh if that file is sourced after this one.
 # If you see this error, it means parallelProcessingFunctions.sh wasn't loaded.
 __loge "ERROR: This is a wrapper function. parallelProcessingFunctions.sh must be sourced to override this with the real implementation."
 __loge "ERROR: Please ensure parallelProcessingFunctions.sh is loaded AFTER functionsProcess.sh"
 return 1
}

# Error codes are defined in commonFunctions.sh

# Common variables are defined in commonFunctions.sh
# Additional variables specific to functionsProcess.sh

# Note location backup file
# Only set if not already declared (e.g., when sourced from another script)
if ! declare -p CSV_BACKUP_NOTE_LOCATION > /dev/null 2>&1; then
 declare -r CSV_BACKUP_NOTE_LOCATION="/tmp/noteLocation.csv"
fi
if ! declare -p CSV_BACKUP_NOTE_LOCATION_COMPRESSED > /dev/null 2>&1; then
 declare -r CSV_BACKUP_NOTE_LOCATION_COMPRESSED="${SCRIPT_BASE_DIRECTORY}/data/noteLocation.csv.zip"
fi

# GitHub repository URL for note location backup (can be overridden via environment variable)
# Only set if not already declared (e.g., when sourced from another script)
if ! declare -p DEFAULT_NOTE_LOCATION_DATA_REPO_URL > /dev/null 2>&1; then
 declare -r DEFAULT_NOTE_LOCATION_DATA_REPO_URL="${DEFAULT_NOTE_LOCATION_DATA_REPO_URL:-https://raw.githubusercontent.com/OSM-Notes/OSM-Notes-Data/main/data}"
fi

# ogr2ogr GeoJSON test file.
# Only set if not already declared (e.g., when sourced from another script)
if ! declare -p GEOJSON_TEST > /dev/null 2>&1; then
 declare -r GEOJSON_TEST="${SCRIPT_BASE_DIRECTORY}/json/map.geojson"
fi

###########
# FUNCTIONS

### Note Location Backup Resolution

##
# Resolves note location backup file, downloading from GitHub if not found locally
# Locates or downloads note location backup CSV file (noteLocation.csv.zip). Checks
# local file first, then downloads from GitHub if not found. Uses retry logic for
# network operations. Similar to __resolve_geojson_file but for note location data.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   0: Success - Backup file found locally or downloaded successfully
#   1: Failure - Download failed (network error, timeout, etc.)
#
# Error codes:
#   0: Success - Backup file found locally or downloaded successfully
#   1: Failure - Download failed (network error, timeout, file not found on GitHub)
#
# Error conditions:
#   0: Success - Local file found and is non-empty
#   0: Success - File downloaded successfully from GitHub
#   1: Download failed - Network error, timeout, or file not found on GitHub
#
# Context variables:
#   Reads:
#     - CSV_BACKUP_NOTE_LOCATION_COMPRESSED: Expected path to compressed backup file (required)
#     - TMP_DIR: Temporary directory for downloads (optional, default: /tmp)
#     - NOTE_LOCATION_DATA_REPO_URL: GitHub repository URL (optional, uses DEFAULT_NOTE_LOCATION_DATA_REPO_URL)
#     - DEFAULT_NOTE_LOCATION_DATA_REPO_URL: Default GitHub repository URL (required)
#     - DOWNLOAD_USER_AGENT: User agent for HTTP requests (optional)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies:
#     - Downloads file to CSV_BACKUP_NOTE_LOCATION_COMPRESSED if not found locally
#
# Side effects:
#   - Checks local file existence and size
#   - Downloads file from GitHub if not found locally
#   - Creates directory structure if needed
#   - Moves downloaded file to expected location
#   - Writes log messages to stderr
#   - Network operations: HTTP download from GitHub
#   - File operations: File download, move, directory creation
#   - No database operations
#
# Notes:
#   - Checks local file first (faster, no network required)
#   - Downloads from GitHub if local file not found
#   - Uses __retry_network_operation if available (with retry logic)
#   - Falls back to direct curl if retry function not available
#   - Creates directory structure if needed (mkdir -p)
#   - File name: noteLocation.csv.zip
#   - Used by __getLocationNotes_impl() for fast country assignment
#   - Critical function: Required for production mode country assignment
#
# Example:
#   export CSV_BACKUP_NOTE_LOCATION_COMPRESSED="/path/to/noteLocation.csv.zip"
#   export DEFAULT_NOTE_LOCATION_DATA_REPO_URL="https://raw.githubusercontent.com/OSM-Notes/OSM-Notes-Data/main/data"
#   __resolve_note_location_backup
#   # File found locally or downloaded from GitHub
#
# Related: __resolve_geojson_file() (similar function for GeoJSON files)
# Related: __getLocationNotes_impl() (uses backup file for country assignment)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
function __resolve_note_location_backup() {
 __log_start
 # shellcheck disable=SC2034
 # RESOLVED_FILE is used via eval to set OUTPUT_VAR dynamically
 local RESOLVED_FILE=""
 # TMP_DIR may already be defined as readonly (e.g., in
 # updateCountries.sh). Only use default if not already defined.
 # If TMP_DIR is readonly, we can't redeclare it, but we can still use
 # it.
 if [[ -z "${TMP_DIR:-}" ]]; then
  local TMP_DIR="/tmp"
 fi

 # Default GitHub repository URL for note location data
 local NOTE_LOCATION_DATA_REPO_URL="${NOTE_LOCATION_DATA_REPO_URL:-${DEFAULT_NOTE_LOCATION_DATA_REPO_URL}}"
 local NOTE_LOCATION_DATA_BRANCH="${NOTE_LOCATION_DATA_BRANCH:-main}"

 # Try local file first
 if [[ -f "${CSV_BACKUP_NOTE_LOCATION_COMPRESSED}" ]] && [[ -s "${CSV_BACKUP_NOTE_LOCATION_COMPRESSED}" ]]; then
  __logd "Using local note location backup: ${CSV_BACKUP_NOTE_LOCATION_COMPRESSED}"
  __log_finish
  return 0
 fi

 # Local file not found, try downloading from GitHub
 __logi "Local note location backup not found, attempting to download from GitHub..."

 local FILE_NAME="noteLocation.csv.zip"
 local DOWNLOAD_URL="${NOTE_LOCATION_DATA_REPO_URL}/${FILE_NAME}"
 local DOWNLOADED_FILE="${TMP_DIR}/${FILE_NAME}"

 # Use __retry_network_operation if available, otherwise use curl directly
 if declare -f __retry_network_operation > /dev/null 2>&1; then
  if __retry_network_operation "${DOWNLOAD_URL}" "${DOWNLOADED_FILE}" 3 2 30; then
   # Move downloaded file to expected location
   mkdir -p "$(dirname "${CSV_BACKUP_NOTE_LOCATION_COMPRESSED}")"
   mv "${DOWNLOADED_FILE}" "${CSV_BACKUP_NOTE_LOCATION_COMPRESSED}"
   __logi "Successfully downloaded note location backup from GitHub: ${DOWNLOAD_URL}"
   __log_finish
   return 0
  else
   __loge "Failed to download note location backup from GitHub: ${DOWNLOAD_URL}"
   __log_finish
   return 1
  fi
 else
  # Fallback to direct curl if __retry_network_operation is not available
  if curl -s --connect-timeout 30 --max-time 30 -H "User-Agent: ${DOWNLOAD_USER_AGENT:-OSM-Notes-Ingestion/1.0}" -o "${DOWNLOADED_FILE}" "${DOWNLOAD_URL}" 2> /dev/null; then
   mkdir -p "$(dirname "${CSV_BACKUP_NOTE_LOCATION_COMPRESSED}")"
   mv "${DOWNLOADED_FILE}" "${CSV_BACKUP_NOTE_LOCATION_COMPRESSED}"
   __logi "Successfully downloaded note location backup from GitHub: ${DOWNLOAD_URL}"
   __log_finish
   return 0
  else
   __loge "Failed to download note location backup from GitHub: ${DOWNLOAD_URL}"
   __log_finish
   return 1
  fi
 fi
}

### Logger

# Shows if there is another executing process.
function __validation {
 __log_start
 if [[ -n "${ONLY_EXECUTION:-}" ]] && [[ "${ONLY_EXECUTION}" == "no" ]]; then
  echo " There is another process already in execution"
 else
  if [[ "${GENERATE_FAILED_FILE}" = true ]]; then
   __logw "Generating file for failed execution."
   # shellcheck disable=SC2154
   # FAILED_EXECUTION_FILE is defined in processAPINotes.sh or environment
   touch "${FAILED_EXECUTION_FILE}"
  else
   __logi "Do not generate file for failed execution."
  fi
 fi
 __log_finish
}

# Counts notes in XML file (API format)
# Parameters:
#   $1: Input XML file path
# Returns:
#   TOTAL_NOTES: Number of notes found (exported variable)
##
# Counts notes in XML file (API format)
# Counts the number of <note> elements in an API-format XML file using lightweight grep.
# Performs XML structure validation before counting (if enabled). Exports the count as
# TOTAL_NOTES environment variable for use by calling scripts. Handles edge cases like
# empty files, XML validation, grep exit codes, and invalid output.
#
# Parameters:
#   $1: XML file path - Path to API-format XML file to count (required)
#
# Returns:
#   0: Success - Note count completed (even if count is 0)
#   1: Failure - File not found, invalid XML structure, or counting error
#
# Error codes:
#   0: Success - Notes counted successfully (TOTAL_NOTES exported, 0 is valid)
#   1: Failure - File not found or not readable
#   1: Failure - File does not appear to be XML (missing <?xml declaration)
#   1: Failure - Severe XML structural issue (missing closing tags)
#   1: Failure - grep command failed (unexpected exit code)
#   1: Failure - Invalid or non-numeric count returned by grep
#
# Error conditions:
#   0: Success - Notes counted and TOTAL_NOTES exported (0 is valid count)
#   1: File not found - XML file path does not exist
#   1: Not XML - File does not contain XML declaration (<?xml)
#   1: XML structure error - Severe structural issue (missing closing tags for <note> elements)
#   1: Grep error - grep returned unexpected exit code (not 0 or 1)
#   1: Invalid count - grep output is not a valid number
#
# Context variables:
#   Reads:
#     - SKIP_XML_VALIDATION: If "true", skips XML structure validation (optional, default: false)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets:
#     - TOTAL_NOTES: Number of notes found (exported for calling scripts)
#   Modifies: None
#
# Side effects:
#   - Reads XML file using grep and xmllint (if validation enabled)
#   - Executes xmllint for XML structure validation (if SKIP_XML_VALIDATION != true)
#   - Exports TOTAL_NOTES environment variable
#   - Writes log messages to stderr
#   - No file modifications, database, or network operations
#
# Notes:
#   - Performs XML structure validation before counting (if SKIP_XML_VALIDATION != true)
#   - Uses grep -c for fast counting (suitable for large files)
#   - Handles grep exit codes: 0 (matches found) and 1 (no matches) are both valid
#   - 0 notes is a valid result (not an error)
#   - Empty XML files (<osm></osm>) are valid and return 0 notes
#   - Validates that count is numeric before exporting
#   - Cleans whitespace from grep output to avoid parsing issues
#   - TOTAL_NOTES is exported for use by calling scripts
#   - API format: counts '<note ' pattern (matches <note ...> with attributes)
#   - More robust than Planet version: includes XML validation
#
# Example:
#   __countXmlNotesAPI "${API_NOTES_FILE}"
#   echo "Found ${TOTAL_NOTES} notes"
#
#   if [[ "${TOTAL_NOTES}" -gt 0 ]]; then
#     echo "Processing ${TOTAL_NOTES} notes"
#   fi
#
# Related: __countXmlNotesPlanet() (Planet format counting, no XML validation)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
function __countXmlNotesAPI() {
 local XML_FILE="${1}"

 __log_start
 __logi "Counting notes in XML file (API format) ${XML_FILE}"

 # Check if file exists
 if [[ ! -f "${XML_FILE}" ]]; then
  __loge "File not found: ${XML_FILE}"
  TOTAL_NOTES=0
  export TOTAL_NOTES
  __log_finish
  return 1
 fi

 # Validate XML structure first (only if XML validation is enabled)
 # Only validate if the file is suspected to be malformed and validation is not skipped
 # Empty XML files with valid structure (no notes) are valid and should not cause errors
 if [[ "${SKIP_XML_VALIDATION}" != "true" ]] && command -v xmllint > /dev/null 2>&1; then
  # Check if the file contains basic XML structure
  if ! grep -q "<?xml" "${XML_FILE}" 2> /dev/null; then
   __loge "File does not appear to be XML: ${XML_FILE}"
   TOTAL_NOTES=0
   export TOTAL_NOTES
   __log_finish
   return 1
  fi

  # Try to validate XML structure - fail only on severe structural issues
  # Empty XML files (<osm></osm>) are valid and should pass validation
  if ! xmllint --noout "${XML_FILE}" > /dev/null 2>&1; then
   # Check if it's a severe structural issue (missing closing tags, etc.)
   # But allow empty XML files (no <note> elements) as they are valid
   if grep -q "<note" "${XML_FILE}" 2> /dev/null && ! grep -q "</note>" "${XML_FILE}" 2> /dev/null; then
    __loge "Severe XML structural issue in file: ${XML_FILE}"
    TOTAL_NOTES=0
    export TOTAL_NOTES
    __log_finish
    return 1
   else
    # Empty XML files or minor validation issues are OK - continue counting
    __logd "XML structure validation had minor issues for file: ${XML_FILE}, but continuing with counting (empty files are valid)"
   fi
  fi
 fi

 # Count notes using grep (fast and reliable)
 # Clean output immediately to avoid newline issues
 local GREP_OUTPUT
 GREP_OUTPUT=$(grep -c '<note ' "${XML_FILE}" 2> /dev/null)
 local GREP_STATUS=$?
 TOTAL_NOTES=$(echo "${GREP_OUTPUT}" | tr -d '[:space:]' || echo "0")
 TOTAL_NOTES="${TOTAL_NOTES:-0}"

 # grep returns 0 when matches found or no matches (which is valid)
 # grep returns 1 when no matches found in some versions (also valid)
 if [[ ${GREP_STATUS} -ne 0 ]] && [[ ${GREP_STATUS} -ne 1 ]]; then
  __loge "Error counting notes in XML file (exit code ${GREP_STATUS}): ${XML_FILE}"
  TOTAL_NOTES=0
  export TOTAL_NOTES
  __log_finish
  return 1
 fi

 # Remove any remaining whitespace and ensure it's a single integer
 TOTAL_NOTES=$(printf '%s' "${TOTAL_NOTES}" | tr -d '[:space:]' | head -1 || true)
 TOTAL_NOTES="${TOTAL_NOTES:-0}"

 # Ensure it's numeric, default to 0 if not
 if [[ -z "${TOTAL_NOTES}" ]] || [[ ! "${TOTAL_NOTES}" =~ ^[0-9]+$ ]]; then
  __loge "Invalid or empty note count returned by grep: '${TOTAL_NOTES}'"
  TOTAL_NOTES=0
 fi

 if [[ "${TOTAL_NOTES}" -eq 0 ]]; then
  __logi "No notes found in XML file (0 notes is a valid scenario)"
 else
  __logi "Total notes found: ${TOTAL_NOTES}"
 fi

 # Export the variable so it's available to calling scripts
 export TOTAL_NOTES

 # Always return 0 (success) when counting completes, even if count is 0
 # 0 notes is a valid scenario and should not be treated as an error
 __log_finish
 return 0
}

##
# Counts notes in XML file (Planet format)
# Counts the number of <note> elements in a Planet-format XML file using lightweight grep.
# Exports the count as TOTAL_NOTES environment variable for use by calling scripts.
# Handles edge cases like empty files, grep exit codes, and invalid output.
#
# Parameters:
#   $1: XML file path - Path to Planet-format XML file to count (required)
#
# Returns:
#   0: Success - Note count completed (even if count is 0)
#   1: Failure - File not found or counting error
#
# Error codes:
#   0: Success - Notes counted successfully (TOTAL_NOTES exported)
#   1: Failure - File not found or not readable
#   1: Failure - grep command failed (unexpected exit code)
#   1: Failure - Invalid or non-numeric count returned by grep
#
# Error conditions:
#   0: Success - Notes counted and TOTAL_NOTES exported (0 is valid count)
#   1: File not found - XML file path does not exist
#   1: Grep error - grep returned unexpected exit code (not 0 or 1)
#   1: Invalid count - grep output is not a valid number
#
# Context variables:
#   Reads:
#     - LOG_LEVEL: Controls logging verbosity
#   Sets:
#     - TOTAL_NOTES: Number of notes found (exported for calling scripts)
#   Modifies: None
#
# Side effects:
#   - Reads XML file using grep -c (counts <note pattern)
#   - Exports TOTAL_NOTES environment variable
#   - Writes log messages to stderr
#   - No file modifications, database, or network operations
#
# Notes:
#   - Uses grep -c for fast counting (suitable for large files)
#   - Handles grep exit codes: 0 (matches found) and 1 (no matches) are both valid
#   - 0 notes is a valid result (not an error)
#   - Validates that count is numeric before exporting
#   - Safe integer conversion (avoids base prefix issues with large numbers)
#   - TOTAL_NOTES is exported for use by calling scripts
#   - Planet format: counts '<note' pattern (matches <note> and <note ...>)
#
# Example:
#   __countXmlNotesPlanet "${PLANET_NOTES_FILE}"
#   echo "Found ${TOTAL_NOTES} notes"
#
#   if [[ "${TOTAL_NOTES}" -gt 0 ]]; then
#     echo "Processing ${TOTAL_NOTES} notes"
#   fi
#
# Related: __countXmlNotesAPI() (API format counting)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
function __countXmlNotesPlanet() {
 local XML_FILE="${1}"

 __log_start
 __logi "Counting notes in XML file (Planet format) ${XML_FILE}"

 # Check if file exists
 if [[ ! -f "${XML_FILE}" ]]; then
  __loge "File not found: ${XML_FILE}"
  TOTAL_NOTES=0
  export TOTAL_NOTES
  __log_finish
  return 1
 fi

 # Get total number of notes for Planet format using lightweight grep
 TOTAL_NOTES=$(grep -c '<note' "${XML_FILE}" 2> /dev/null)
 local GREP_STATUS=$?

 # grep returns 0 when no matches found, which is not an error
 # grep returns 1 when no matches found in some versions, which is also not an error
 if [[ ${GREP_STATUS} -ne 0 ]] && [[ ${GREP_STATUS} -ne 1 ]]; then
  __loge "Error counting notes in XML file (exit code ${GREP_STATUS}): ${XML_FILE}"
  TOTAL_NOTES=0
  export TOTAL_NOTES
  __log_finish
  return 1
 fi

 # grep returns "0" when no matches found, which is valid
 # No need to handle special exit codes

 # Ensure TOTAL_NOTES is treated as a decimal number and is valid
 # Note: grep returns "0" when no matches found, which is valid
 if [[ -z "${TOTAL_NOTES}" ]] || [[ ! "${TOTAL_NOTES}" =~ ^[0-9]+$ ]]; then
  __loge "Invalid or empty note count returned by grep: '${TOTAL_NOTES}'"
  TOTAL_NOTES=0
  export TOTAL_NOTES
  __log_finish
  return 1
 fi

 # Convert to integer safely - avoid 10# prefix for large numbers that look like dates
 if [[ "${TOTAL_NOTES}" =~ ^[0-9]+$ ]]; then
  # Safe integer conversion without base prefix for large numbers
  TOTAL_NOTES=$((TOTAL_NOTES + 0))
 else
  __loge "Invalid note count format: '${TOTAL_NOTES}'"
  TOTAL_NOTES=0
  export TOTAL_NOTES
  __log_finish
  return 1
 fi

 if [[ "${TOTAL_NOTES}" -eq 0 ]]; then
  __logi "No notes found in XML file"
 else
  __logi "Total notes found: ${TOTAL_NOTES}"
 fi

 # Export the variable so it's available to calling scripts
 export TOTAL_NOTES

 __log_finish
}

# Functions __splitXmlForParallelAPI and __splitXmlForParallelPlanet
# are defined in parallelProcessingFunctions.sh and will override these stubs
# if that file is sourced after this one (which it is)
function __splitXmlForParallelAPI() {
 __loge "ERROR: parallelProcessingFunctions.sh must be sourced before calling this function"
 return 1
}

function __splitXmlForParallelPlanet() {
 __loge "ERROR: parallelProcessingFunctions.sh must be sourced before calling this function"
 return 1
}

##
# Processes a single XML part for API notes using AWK extraction
# Extracts notes, comments, and text comments from a single API XML part file into CSV files
# using AWK. Extracts part number from filename, adjusts for PostgreSQL 1-based partitions,
# adds part_id to CSV files, and loads data into database partition tables. Used during
# parallel processing of API notes.
#
# Parameters:
#   $1: XML_PART - Path to API XML part file (required, format: api_part_N.xml)
#
# Returns:
#   0: Success - XML part processed and loaded successfully
#   1: Failure - Invalid part number, CSV creation failed, or database load failed
#
# Error codes:
#   0: Success - XML part processed and loaded successfully
#   1: Failure - Invalid part number extracted from filename
#   1: Failure - Notes CSV file creation failed
#   1: Failure - Comments CSV file creation failed
#   1: Failure - Database load failed (SQL execution error)
#
# Error conditions:
#   0: Success - All CSV files created and loaded successfully
#   1: Invalid filename - Part number cannot be extracted or is invalid
#   1: AWK extraction failed - Notes or comments CSV not created
#   1: Database load failed - SQL execution failed (check logs)
#
# Context variables:
#   Reads:
#     - TMP_DIR: Temporary directory for CSV files (required)
#     - SCRIPT_BASE_DIRECTORY: Base directory for AWK scripts (required)
#     - DBNAME: PostgreSQL database name (required)
#     - PGAPPNAME: PostgreSQL application name (optional)
#     - POSTGRES_41_LOAD_PARTITIONED_SYNC_NOTES: Path to SQL script template (required)
#     - MAX_THREADS: Maximum threads for parallel operations (optional)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies:
#     - Creates CSV files in TMP_DIR (notes, comments, text comments)
#     - Loads data into database partition tables
#
# Side effects:
#   - Extracts part number from filename (api_part_N.xml -> N)
#   - Adjusts part number for PostgreSQL 1-based partitions (N+1)
#   - Processes XML part with AWK (extract_notes.awk, extract_comments.awk, extract_comment_texts.awk)
#   - Creates CSV files (output-notes-part-N.csv, output-comments-part-N.csv, output-text-part-N.csv)
#   - Adds part_id column to CSV files
#   - Loads CSV files into database partition tables (via SQL script)
#   - Writes log messages to stderr
#   - File operations: Creates CSV files, reads XML file
#   - Database operations: Loads data into partition tables
#   - No network operations
#
# Notes:
#   - Part number extraction: api_part_N.xml -> N (0-based)
#   - PostgreSQL partition adjustment: N+1 (1-based partitions)
#   - Uses AWK for fast extraction (no external dependencies)
#   - Adds part_id to CSV files for partition assignment
#   - Loads data into partition tables (notes_sync_part_N, etc.)
#   - Used during parallel processing (called by GNU parallel or sequentially)
#   - Critical function: Part of parallel processing workflow
#   - Handles empty text comments gracefully (creates empty file)
#
# Example:
#   export TMP_DIR="/tmp"
#   export DBNAME="osm_notes"
#   __processApiXmlPart "/tmp/api_part_0.xml"
#   # Processes part 0, creates CSVs, loads into partition 1
#
# Related: __splitXmlForParallelSafe() (splits XML into parts)
# Related: __processPlanetXmlPart() (processes Planet XML parts)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
# Processes a single XML part for API notes using AWK extraction
# Parameters:
#   $1: XML part file path
function __processApiXmlPart() {
 __log_start
 local XML_PART="${1}"
 local PART_NUM
 local BASENAME_PART

 __logi "=== STARTING API XML PART PROCESSING (AWK) ==="
 __logd "Input XML part: ${XML_PART}"

 # Debug: Show environment variables
 __logd "Environment check in subshell:"
 __logd "  XML_PART: '${XML_PART}'"
 __logd "  TMP_DIR: '${TMP_DIR:-NOT_SET}'"
 __logd "  SCRIPT_BASE_DIRECTORY: '${SCRIPT_BASE_DIRECTORY:-NOT_SET}'"
 __logd "  DBNAME: '${DBNAME:-NOT_SET}'"

 BASENAME_PART=$(basename "${XML_PART}" .xml)
 # Extract number from api_part_N or planet_part_N format
 PART_NUM=$(echo "${BASENAME_PART}" | sed 's/.*_part_//' | sed 's/^0*//' || true)
 PART_NUM="${PART_NUM:-}"

 # Handle case where part number is just "0"
 if [[ -z "${PART_NUM}" ]]; then
  PART_NUM="0"
 fi

 # PostgreSQL partitions are 1-based (part_1, part_2, ..., part_N)
 # But file names are 0-based (part_0, part_1, ..., part_N-1)
 # So we need to add 1 to match PostgreSQL partition names
 PART_NUM=$((PART_NUM + 1))

 # Debug: Show extraction process
 __logd "Extracting part number from: ${XML_PART}"
 __logd "Basename: ${BASENAME_PART}"
 __logd "Part number: ${PART_NUM} (adjusted for PostgreSQL 1-based partitions)"

 # Validate part number
 if [[ ! "${PART_NUM}" =~ ^[0-9]+$ ]] || [[ ${PART_NUM} -lt 1 ]]; then
  __loge "Invalid part number extracted: '${PART_NUM}' from file: ${XML_PART}"
  __log_finish
  return 1
 fi

 __logi "Processing API XML part ${PART_NUM}: ${XML_PART}"

 # Convert XML part to CSV using AWK
 local OUTPUT_NOTES_PART
 local OUTPUT_COMMENTS_PART
 local OUTPUT_TEXT_PART
 OUTPUT_NOTES_PART="${TMP_DIR}/output-notes-part-${PART_NUM}.csv"
 OUTPUT_COMMENTS_PART="${TMP_DIR}/output-comments-part-${PART_NUM}.csv"
 OUTPUT_TEXT_PART="${TMP_DIR}/output-text-part-${PART_NUM}.csv"

 # Process notes with AWK (fast and dependency-free)
 __logd "Processing notes with AWK: ${XML_PART} -> ${OUTPUT_NOTES_PART}"
 awk -f "${SCRIPT_BASE_DIRECTORY}/awk/extract_notes.awk" "${XML_PART}" > "${OUTPUT_NOTES_PART}"
 if [[ ! -f "${OUTPUT_NOTES_PART}" ]]; then
  __loge "Notes CSV file was not created: ${OUTPUT_NOTES_PART}"
  __log_finish
  return 1
 fi

 # Process comments with AWK (fast and dependency-free)
 __logd "Processing comments with AWK: ${XML_PART} -> ${OUTPUT_COMMENTS_PART}"
 awk -f "${SCRIPT_BASE_DIRECTORY}/awk/extract_comments.awk" "${XML_PART}" > "${OUTPUT_COMMENTS_PART}"
 if [[ ! -f "${OUTPUT_COMMENTS_PART}" ]]; then
  __loge "Comments CSV file was not created: ${OUTPUT_COMMENTS_PART}"
  __log_finish
  return 1
 fi

 # Process text comments with AWK (fast and dependency-free)
 __logd "Processing text comments with AWK: ${XML_PART} -> ${OUTPUT_TEXT_PART}"
 awk -f "${SCRIPT_BASE_DIRECTORY}/awk/extract_comment_texts.awk" "${XML_PART}" > "${OUTPUT_TEXT_PART}"
 if [[ ! -f "${OUTPUT_TEXT_PART}" ]]; then
  __logw "Text comments CSV file was not created, generating empty file to continue: ${OUTPUT_TEXT_PART}"
  : > "${OUTPUT_TEXT_PART}"
 fi

 # Add id_country (empty) and part_id to the end of each line for notes
 __logd "Adding id_country (empty) and part_id ${PART_NUM} to notes CSV"
 awk -v part_id="${PART_NUM}" '{print $0 ",," part_id}' "${OUTPUT_NOTES_PART}" > "${OUTPUT_NOTES_PART}.tmp" && mv "${OUTPUT_NOTES_PART}.tmp" "${OUTPUT_NOTES_PART}"

 # Add part_id to the end of each line for comments
 __logd "Adding part_id ${PART_NUM} to comments CSV"
 awk -v part_id="${PART_NUM}" '{gsub(/,$/, ""); print $0 "," part_id}' "${OUTPUT_COMMENTS_PART}" > "${OUTPUT_COMMENTS_PART}.tmp" && mv "${OUTPUT_COMMENTS_PART}.tmp" "${OUTPUT_COMMENTS_PART}"

 # Add part_id to the end of each line for text comments
 __logd "Adding part_id ${PART_NUM} to text comments CSV"
 if [[ -s "${OUTPUT_TEXT_PART}" ]]; then
  awk -v part_id="${PART_NUM}" '{gsub(/,$/, ""); print $0 "," part_id}' "${OUTPUT_TEXT_PART}" > "${OUTPUT_TEXT_PART}.tmp" && mv "${OUTPUT_TEXT_PART}.tmp" "${OUTPUT_TEXT_PART}"
 else
  __logw "Text comments CSV is empty for part ${PART_NUM}; skipping part_id append"
 fi

 # Debug: Show generated CSV files and their sizes
 __logd "Generated CSV files for part ${PART_NUM}:"
 # shellcheck disable=SC2310
 # Intentional: logging failures should not stop execution
 __logd "  Notes: ${OUTPUT_NOTES_PART} ($(wc -l < "${OUTPUT_NOTES_PART}" || echo 0) lines)" || true
 # shellcheck disable=SC2310
 # Intentional: logging failures should not stop execution
 __logd "  Comments: ${OUTPUT_COMMENTS_PART} ($(wc -l < "${OUTPUT_COMMENTS_PART}" || echo 0) lines)" || true
 # shellcheck disable=SC2310
 # Intentional: logging failures should not stop execution
 __logd "  Text: ${OUTPUT_TEXT_PART} ($(wc -l < "${OUTPUT_TEXT_PART}" || echo 0) lines)" || true

 # Validate CSV files structure and content before loading
 __logd "Validating CSV files structure and enum compatibility..."

 # Validate structure first
 # shellcheck disable=SC2310
 # Intentional: check return value explicitly
 if ! __validate_csv_structure "${OUTPUT_NOTES_PART}" "notes"; then
  __loge "ERROR: Notes CSV structure validation failed for part ${PART_NUM}"
  __log_finish
  return 1
 fi

 # Then validate enum values
 # shellcheck disable=SC2310
 # Intentional: check return value explicitly
 if ! __validate_csv_for_enum_compatibility "${OUTPUT_NOTES_PART}" "notes"; then
  __loge "ERROR: Notes CSV enum validation failed for part ${PART_NUM}"
  __log_finish
  return 1
 fi

 # Validate comments structure
 # shellcheck disable=SC2310
 # Intentional: check return value explicitly
 if ! __validate_csv_structure "${OUTPUT_COMMENTS_PART}" "comments"; then
  __loge "ERROR: Comments CSV structure validation failed for part ${PART_NUM}"
  __log_finish
  return 1
 fi

 # Validate comments enum
 # shellcheck disable=SC2310
 # Intentional: check return value explicitly
 if ! __validate_csv_for_enum_compatibility "${OUTPUT_COMMENTS_PART}" "comments"; then
  __loge "ERROR: Comments CSV enum validation failed for part ${PART_NUM}"
  __log_finish
  return 1
 fi

 # Validate text structure (most prone to quote/escape issues)
 # shellcheck disable=SC2310
 # Intentional: check return value explicitly
 if ! __validate_csv_structure "${OUTPUT_TEXT_PART}" "text"; then
  __loge "ERROR: Text CSV structure validation failed for part ${PART_NUM}"
  __log_finish
  return 1
 fi

 __logi "=== LOADING PART ${PART_NUM} INTO DATABASE ==="
 __logd "Database: ${DBNAME}"
 __logd "Part ID: ${PART_NUM}"
 __logd "Max threads: ${MAX_THREADS}"

 # Load into database with partition ID and MAX_THREADS
 export OUTPUT_NOTES_PART
 export OUTPUT_COMMENTS_PART
 export OUTPUT_TEXT_PART
 export PART_ID="${PART_NUM}"
 export MAX_THREADS
 # shellcheck disable=SC2016,SC2154
 # PGAPPNAME is defined in etc/properties.sh or environment
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -c "SET app.part_id = '${PART_NUM}'; SET app.max_threads = '${MAX_THREADS}';"
 # shellcheck disable=SC2154,SC2016
 # SC2016: envsubst requires single quotes to prevent shell expansion
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -c "$(envsubst '$OUTPUT_NOTES_PART,$OUTPUT_COMMENTS_PART,$OUTPUT_TEXT_PART,$PART_ID' \
   < "${POSTGRES_31_LOAD_API_NOTES}" || true)"

 __logi "=== API XML PART ${PART_NUM} PROCESSING COMPLETED SUCCESSFULLY ==="
 __log_finish
 __log_finish
}

# Processes a single XML part for Planet notes using AWK extraction
##
# Processes a single Planet XML part file using AWK extraction
# Processes a single XML part file from Planet dump. Extracts notes, comments, and
# text comments using AWK scripts, converts to CSV format, adds partition ID to each
# CSV file, and loads data into database partition tables. Used by parallel processing
# workers to process individual XML parts concurrently.
#
# Parameters:
#   $1: XML_PART - Path to XML part file (e.g., planet_part_0.xml) (required)
#
# Returns:
#   0: Success - Part processed and loaded successfully
#   1: Failure - Invalid part number, CSV file creation failed, or database load failed
#
# Error codes:
#   0: Success - Part processed and loaded successfully
#   1: Failure - Invalid part number extracted from filename
#   1: Failure - Notes CSV file was not created
#   1: Failure - Comments CSV file was not created
#   1: Failure - SQL file does not exist
#   1: Failure - envsubst failed or produced empty SQL
#   1: Failure - PostgreSQL session variable setting failed
#   1: Failure - Database load failed (COPY command failed)
#
# Error conditions:
#   0: Success - Part processed and loaded successfully
#   1: Invalid part number - Cannot extract valid part number from filename
#   1: Notes CSV creation failed - AWK script failed or file not created
#   1: Comments CSV creation failed - AWK script failed or file not created
#   1: SQL file missing - POSTGRES_41_LOAD_PARTITIONED_SYNC_NOTES does not exist
#   1: envsubst failure - Variable substitution failed or produced empty SQL
#   1: Database load failure - COPY command failed or psql returned error
#
# Context variables:
#   Reads:
#     - TMP_DIR: Temporary directory for CSV files (required)
#     - SCRIPT_BASE_DIRECTORY: Base directory for AWK scripts (required)
#     - DBNAME: PostgreSQL database name (required)
#     - PGAPPNAME: PostgreSQL application name (optional)
#     - MAX_THREADS: Maximum number of threads (required)
#     - POSTGRES_41_LOAD_PARTITIONED_SYNC_NOTES: Path to SQL script template (required)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets:
#     - OUTPUT_NOTES_PART: Path to notes CSV file (exported)
#     - OUTPUT_COMMENTS_PART: Path to comments CSV file (exported)
#     - OUTPUT_TEXT_PART: Path to text comments CSV file (exported)
#     - PART_ID: Partition ID (exported for envsubst)
#     - MAX_THREADS: Exported for envsubst
#   Modifies:
#     - Creates CSV files in TMP_DIR
#     - Loads data into database partition tables
#
# Side effects:
#   - Extracts notes from XML using AWK (extract_notes.awk)
#   - Extracts comments from XML using AWK (extract_comments.awk)
#   - Extracts text comments from XML using AWK (extract_comment_texts.awk)
#   - Adds partition ID to each CSV file (part_id column)
#   - Sets PostgreSQL session variables (app.part_id, app.max_threads)
#   - Executes COPY commands to load CSV data into partition tables
#   - Writes log messages to stderr
#   - Creates temporary CSV files in TMP_DIR
#   - Database operations: COPY into partition tables
#   - No network operations
#
# Notes:
#   - Part number extraction: Extracts number from filename (planet_part_N.xml -> N)
#   - PostgreSQL partitions are 1-based (part_1, part_2, ...), file names are 0-based (part_0, part_1, ...)
#   - Adds 1 to part number to match PostgreSQL partition names
#   - Uses AWK scripts for fast, dependency-free XML extraction
#   - Adds part_id column to each CSV file for partition identification
#   - Uses envsubst to substitute file paths and partition ID in SQL template
#   - Critical function: Used by parallel processing workers
#   - Performance: AWK extraction is fast and memory-efficient
#   - Each worker processes one XML part independently
#
# Example:
#   export TMP_DIR="/tmp"
#   export DBNAME="osm_notes"
#   export MAX_THREADS=8
#   __processPlanetXmlPart "/tmp/parts/planet_part_0.xml"
#   # Processes part 0, creates CSVs, loads into partition 1
#
# Related: __splitXmlForParallelSafe() (splits XML into parts)
# Related: __processPlanetNotesWithParallel() (orchestrates parallel processing)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
# Processes a single XML part for Planet notes using AWK extraction
# Extracts notes, comments, and text comments from a single Planet XML part file into CSV files
# using AWK. Extracts part number from filename, adjusts for PostgreSQL 1-based partitions,
# adds part_id to CSV files, and loads data into database partition tables. Used during
# parallel processing of Planet notes.
#
# Parameters:
#   $1: XML_PART - Path to Planet XML part file (required, format: planet_part_N.xml)
#
# Returns:
#   0: Success - XML part processed and loaded successfully
#   1: Failure - Invalid part number, CSV creation failed, or database load failed
#
# Error codes:
#   0: Success - XML part processed and loaded successfully
#   1: Failure - Invalid part number extracted from filename
#   1: Failure - Notes CSV file creation failed
#   1: Failure - Comments CSV file creation failed
#   1: Failure - Database load failed (SQL execution error)
#
# Error conditions:
#   0: Success - All CSV files created and loaded successfully
#   1: Invalid filename - Part number cannot be extracted or is invalid
#   1: AWK extraction failed - Notes or comments CSV not created
#   1: Database load failed - SQL execution failed (check logs)
#
# Context variables:
#   Reads:
#     - TMP_DIR: Temporary directory for CSV files (required)
#     - SCRIPT_BASE_DIRECTORY: Base directory for AWK scripts (required)
#     - DBNAME: PostgreSQL database name (required)
#     - PGAPPNAME: PostgreSQL application name (optional)
#     - POSTGRES_41_LOAD_PARTITIONED_SYNC_NOTES: Path to SQL script template (required)
#     - MAX_THREADS: Maximum threads for parallel operations (optional)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies:
#     - Creates CSV files in TMP_DIR (notes, comments, text comments)
#     - Loads data into database partition tables
#
# Side effects:
#   - Extracts part number from filename (planet_part_N.xml -> N)
#   - Adjusts part number for PostgreSQL 1-based partitions (N+1)
#   - Processes XML part with AWK (extract_notes.awk, extract_comments.awk, extract_comment_texts.awk)
#   - Creates CSV files (output-notes-part-N.csv, output-comments-part-N.csv, output-text-part-N.csv)
#   - Adds id_country (empty) and part_id columns to CSV files
#   - Loads CSV files into database partition tables (via SQL script)
#   - Writes log messages to stderr
#   - File operations: Creates CSV files, reads XML file
#   - Database operations: Loads data into partition tables
#   - No network operations
#
# Notes:
#   - Part number extraction: planet_part_N.xml -> N (0-based)
#   - PostgreSQL partition adjustment: N+1 (1-based partitions)
#   - Uses AWK for fast extraction (no external dependencies)
#   - Adds id_country (empty) and part_id to CSV files for partition assignment
#   - Loads data into partition tables (notes_sync_part_N, etc.)
#   - Used during parallel processing (called by GNU parallel or sequentially)
#   - Critical function: Part of parallel processing workflow
#   - Handles empty text comments gracefully (creates empty file)
#   - Similar to __processApiXmlPart() but for Planet format
#
# Example:
#   export TMP_DIR="/tmp"
#   export DBNAME="osm_notes"
#   __processPlanetXmlPart "/tmp/planet_part_0.xml"
#   # Processes part 0, creates CSVs, loads into partition 1
#
# Related: __splitXmlForParallelSafe() (splits XML into parts)
# Related: __processApiXmlPart() (processes API XML parts)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
# Parameters:
#   $1: XML part file path
function __processPlanetXmlPart() {
 __log_start
 local XML_PART="${1}"
 local PART_NUM
 local BASENAME_PART

 __logi "=== STARTING PLANET XML PART PROCESSING (AWK) ==="
 __logd "Input XML part: ${XML_PART}"

 # Debug: Show environment variables
 __logd "Environment check in subshell:"
 __logd "  XML_PART: '${XML_PART}'"
 __logd "  TMP_DIR: '${TMP_DIR:-NOT_SET}'"
 __logd "  SCRIPT_BASE_DIRECTORY: '${SCRIPT_BASE_DIRECTORY:-NOT_SET}'"
 __logd "  DBNAME: '${DBNAME:-NOT_SET}'"

 BASENAME_PART=$(basename "${XML_PART}" .xml)
 # Extract number from planet_part_N or api_part_N format
 PART_NUM=$(echo "${BASENAME_PART}" | sed 's/.*_part_//' | sed 's/^0*//' || true)
 PART_NUM="${PART_NUM:-}"

 # Handle case where part number is just "0"
 if [[ -z "${PART_NUM}" ]]; then
  PART_NUM="0"
 fi

 # PostgreSQL partitions are 1-based (part_1, part_2, ..., part_N)
 # But file names are 0-based (part_0, part_1, ..., part_N-1)
 # So we need to add 1 to match PostgreSQL partition names
 PART_NUM=$((PART_NUM + 1))

 # Debug: Show extraction process
 __logd "Extracting part number from: ${XML_PART}"
 __logd "Basename: ${BASENAME_PART}"
 __logd "Part number: ${PART_NUM} (adjusted for PostgreSQL 1-based partitions)"

 # Validate part number
 if [[ ! "${PART_NUM}" =~ ^[0-9]+$ ]] || [[ ${PART_NUM} -lt 1 ]]; then
  __loge "Invalid part number extracted: '${PART_NUM}' from file: ${XML_PART}"
  __log_finish
  return 1
 fi

 __logi "Processing Planet XML part ${PART_NUM}: ${XML_PART}"

 # Convert XML part to CSV using AWK (faster, no external dependencies)
 local OUTPUT_NOTES_PART
 local OUTPUT_COMMENTS_PART
 local OUTPUT_TEXT_PART
 OUTPUT_NOTES_PART="${TMP_DIR}/output-notes-part-${PART_NUM}.csv"
 OUTPUT_COMMENTS_PART="${TMP_DIR}/output-comments-part-${PART_NUM}.csv"
 OUTPUT_TEXT_PART="${TMP_DIR}/output-text-part-${PART_NUM}.csv"

 # Process notes with AWK (fast and dependency-free)
 __logd "Processing notes with AWK: ${XML_PART} -> ${OUTPUT_NOTES_PART}"
 awk -f "${SCRIPT_BASE_DIRECTORY}/awk/extract_notes.awk" "${XML_PART}" > "${OUTPUT_NOTES_PART}"
 if [[ ! -f "${OUTPUT_NOTES_PART}" ]]; then
  __loge "Notes CSV file was not created: ${OUTPUT_NOTES_PART}"
  __log_finish
  return 1
 fi

 # Add id_country (empty) and part_id to the end of each line
 __logd "Adding id_country (empty) and part_id ${PART_NUM} to notes CSV"
 sed "s/,,$/,,""${PART_NUM}""/" "${OUTPUT_NOTES_PART}" > "${OUTPUT_NOTES_PART}.tmp" && mv "${OUTPUT_NOTES_PART}.tmp" "${OUTPUT_NOTES_PART}"

 # Process comments with AWK (fast and dependency-free)
 __logd "Processing comments with AWK: ${XML_PART} -> ${OUTPUT_COMMENTS_PART}"
 awk -f "${SCRIPT_BASE_DIRECTORY}/awk/extract_comments.awk" "${XML_PART}" > "${OUTPUT_COMMENTS_PART}"
 if [[ ! -f "${OUTPUT_COMMENTS_PART}" ]]; then
  __loge "Comments CSV file was not created: ${OUTPUT_COMMENTS_PART}"
  __log_finish
  return 1
 fi

 # Add part_id to the end of each line
 __logd "Adding part_id ${PART_NUM} to comments CSV"
 awk -v part_id="${PART_NUM}" '{gsub(/,$/, ""); print $0 "," part_id}' "${OUTPUT_COMMENTS_PART}" > "${OUTPUT_COMMENTS_PART}.tmp" && mv "${OUTPUT_COMMENTS_PART}.tmp" "${OUTPUT_COMMENTS_PART}"

 # Process text comments with AWK (fast and dependency-free)
 __logd "Processing text comments with AWK: ${XML_PART} -> ${OUTPUT_TEXT_PART}"
 awk -f "${SCRIPT_BASE_DIRECTORY}/awk/extract_comment_texts.awk" "${XML_PART}" > "${OUTPUT_TEXT_PART}"
 if [[ ! -f "${OUTPUT_TEXT_PART}" ]]; then
  __logw "Text comments CSV file was not created, generating empty file to continue: ${OUTPUT_TEXT_PART}"
  : > "${OUTPUT_TEXT_PART}"
 fi

 # Add part_id to the end of each line
 __logd "Adding part_id ${PART_NUM} to text comments CSV"
 if [[ -s "${OUTPUT_TEXT_PART}" ]]; then
  awk -v part_id="${PART_NUM}" '{gsub(/,$/, ""); print $0 "," part_id}' "${OUTPUT_TEXT_PART}" > "${OUTPUT_TEXT_PART}.tmp" && mv "${OUTPUT_TEXT_PART}.tmp" "${OUTPUT_TEXT_PART}"
 else
  __logw "Text comments CSV is empty for part ${PART_NUM}; skipping part_id append"
 fi

 # Debug: Show generated CSV files and their sizes
 __logd "Generated CSV files for part ${PART_NUM}:"
 local NOTES_LINES
 NOTES_LINES=$(wc -l < "${OUTPUT_NOTES_PART}" 2> /dev/null || echo "0")
 __logd "  Notes: ${OUTPUT_NOTES_PART} (${NOTES_LINES} lines)"
 local COMMENTS_LINES
 COMMENTS_LINES=$(wc -l < "${OUTPUT_COMMENTS_PART}" 2> /dev/null || echo "0")
 __logd "  Comments: ${OUTPUT_COMMENTS_PART} (${COMMENTS_LINES} lines)"
 local TEXT_LINES
 TEXT_LINES=$(wc -l < "${OUTPUT_TEXT_PART}" 2> /dev/null || echo "0")
 __logd "  Text: ${OUTPUT_TEXT_PART} (${TEXT_LINES} lines)"

 # Load into database with partition ID and MAX_THREADS
 __logi "=== LOADING PART ${PART_NUM} INTO DATABASE ==="
 __logd "Database: ${DBNAME}"
 __logd "Partition ID: ${PART_NUM}"
 __logd "Max threads: ${MAX_THREADS}"
 __logd "Notes CSV: ${OUTPUT_NOTES_PART}"
 __logd "Comments CSV: ${OUTPUT_COMMENTS_PART}"
 __logd "Text CSV: ${OUTPUT_TEXT_PART}"
 # shellcheck disable=SC2154
 # POSTGRES_41_LOAD_PARTITIONED_SYNC_NOTES is defined in pathConfigurationFunctions.sh
 __logd "SQL file: ${POSTGRES_41_LOAD_PARTITIONED_SYNC_NOTES}"

 # Verify CSV files exist and have content
 if [[ ! -f "${OUTPUT_NOTES_PART}" ]]; then
  __loge "ERROR: Notes CSV file does not exist: ${OUTPUT_NOTES_PART}"
  __log_finish
  return 1
 fi
 if [[ ! -s "${OUTPUT_NOTES_PART}" ]]; then
  __logw "WARNING: Notes CSV file is empty: ${OUTPUT_NOTES_PART}"
 fi

 if [[ ! -f "${OUTPUT_COMMENTS_PART}" ]]; then
  __loge "ERROR: Comments CSV file does not exist: ${OUTPUT_COMMENTS_PART}"
  __log_finish
  return 1
 fi
 if [[ ! -s "${OUTPUT_COMMENTS_PART}" ]]; then
  __logw "WARNING: Comments CSV file is empty: ${OUTPUT_COMMENTS_PART}"
 fi

 # Verify SQL file exists
 # shellcheck disable=SC2154
 # POSTGRES_41_LOAD_PARTITIONED_SYNC_NOTES is defined in pathConfigurationFunctions.sh
 if [[ ! -f "${POSTGRES_41_LOAD_PARTITIONED_SYNC_NOTES}" ]]; then
  __loge "ERROR: SQL file does not exist: ${POSTGRES_41_LOAD_PARTITIONED_SYNC_NOTES}"
  __log_finish
  return 1
 fi

 # Export variables for envsubst
 export OUTPUT_NOTES_PART
 export OUTPUT_COMMENTS_PART
 export OUTPUT_TEXT_PART
 export PART_ID="${PART_NUM}"
 export MAX_THREADS

 __logd "Variables exported for envsubst:"
 __logd "  OUTPUT_NOTES_PART=${OUTPUT_NOTES_PART}"
 __logd "  OUTPUT_COMMENTS_PART=${OUTPUT_COMMENTS_PART}"
 __logd "  OUTPUT_TEXT_PART=${OUTPUT_TEXT_PART}"
 __logd "  PART_ID=${PART_ID}"
 __logd "  MAX_THREADS=${MAX_THREADS}"

 # Generate SQL command with envsubst
 __logd "Generating SQL command from template..."
 local SQL_CMD
 # shellcheck disable=SC2016
 # SC2016: envsubst requires single quotes to prevent shell expansion
 SQL_CMD=$(envsubst '$OUTPUT_NOTES_PART,$OUTPUT_COMMENTS_PART,$OUTPUT_TEXT_PART,$PART_ID' \
  < "${POSTGRES_41_LOAD_PARTITIONED_SYNC_NOTES}" 2>&1)
 local ENVSUBST_EXIT_CODE=$?

 if [[ ${ENVSUBST_EXIT_CODE} -ne 0 ]]; then
  __loge "ERROR: envsubst failed with exit code ${ENVSUBST_EXIT_CODE}"
  __loge "envsubst output: ${SQL_CMD}"
  __log_finish
  return 1
 fi

 if [[ -z "${SQL_CMD}" ]]; then
  __loge "ERROR: envsubst produced empty SQL command"
  __log_finish
  return 1
 fi

 __logd "SQL command generated successfully (length: ${#SQL_CMD} characters)"
 __logd "First 200 characters of SQL: ${SQL_CMD:0:200}..."

 # Execute PostgreSQL commands
 __logd "Setting PostgreSQL session variables..."
 # shellcheck disable=SC2312
 # Intentional: psql output is piped to while loop, return value is checked
 if ! PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -c "SET app.part_id = '${PART_NUM}'; SET app.max_threads = '${MAX_THREADS}';" 2>&1 | while IFS= read -r line; do
  __logd "psql SET: ${line}"
 done; then
  __loge "ERROR: Failed to set PostgreSQL session variables"
  __log_finish
  return 1
 fi

 __logd "Executing COPY commands to load data into database..."
 local PSQL_OUTPUT
 local PSQL_EXIT_CODE
 PSQL_OUTPUT=$(PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -c "${SQL_CMD}" 2>&1)
 PSQL_EXIT_CODE=$?

 if [[ ${PSQL_EXIT_CODE} -ne 0 ]]; then
  __loge "ERROR: psql COPY command failed with exit code ${PSQL_EXIT_CODE}"
  __loge "psql output:"
  echo "${PSQL_OUTPUT}" | while IFS= read -r line; do
   __loge "  ${line}"
  done
  __log_finish
  return 1
 fi

 __logd "psql COPY command output:"
 echo "${PSQL_OUTPUT}" | while IFS= read -r line; do
  __logd "  ${line}"
 done

 # Verify data was loaded
 __logd "Verifying data was loaded into partition ${PART_NUM}..."
 local NOTES_COUNT
 local COMMENTS_COUNT
 NOTES_COUNT=$(PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM notes_sync_part_${PART_NUM};" 2> /dev/null || echo "0")
 COMMENTS_COUNT=$(PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM note_comments_sync_part_${PART_NUM};" 2> /dev/null || echo "0")

 __logi "Data loaded into partition ${PART_NUM}:"
 __logi "  Notes: ${NOTES_COUNT} rows"
 __logi "  Comments: ${COMMENTS_COUNT} rows"

 if [[ "${NOTES_COUNT}" -eq 0 ]]; then
  __logw "WARNING: No notes were loaded into partition ${PART_NUM}"
 fi

 __logi "=== PLANET XML PART ${PART_NUM} PROCESSING COMPLETED SUCCESSFULLY ==="
 __log_finish
}

# Function to validate input files and directories

# Function to validate multiple input files
# Parameters:
#   $@: List of file paths to validate
# Returns:
#   0 if all valid, 1 if any invalid

# Validate XML structure (delegates to lib/osm-common/validationFunctions.sh)
# Parameters:
#   $1: XML file path
#   $2: Expected root element (optional)
# Returns:
#   0 if valid, 1 if invalid

# Function to validate CSV file structure
# Parameters:
#   $1: CSV file path
#   $2: Expected number of columns (optional)
# Returns:
#   0 if valid, 1 if invalid

# Function to validate SQL file structure
# Parameters:
#   $1: SQL file path
# Returns:
#   0 if valid, 1 if invalid

# Function to validate configuration file
# Parameters:
#   $1: Config file path
# Returns:
#   0 if valid, 1 if invalid

# Validates JSON file structure and syntax
# Parameters:
#   $1: JSON file path
#   $2: Optional expected root element name (e.g., "osm-notes")
# Returns:
#   0 if valid, 1 if invalid

##
# Validates JSON file structure and verifies it contains expected element
# Performs two-stage validation: first validates JSON syntax, then checks for required element.
# Used to ensure downloaded Overpass API responses and GeoJSON files have correct structure.
#
# Parameters:
#   $1: JSON file path - Path to JSON file to validate (required)
#   $2: Expected element name - Name of required element (optional, e.g., "elements" for OSM JSON, "features" for GeoJSON)
#
# Returns:
#   0: Success - JSON is valid and contains expected element (if specified)
#   1: Failure - JSON invalid, element missing, or element is empty
#   2: Invalid argument - JSON file path is empty
#   3: Missing dependency - jq command not found (required for element validation)
#   7: File error - JSON file not found or cannot be read
#
# Error codes:
#   0: Success - JSON syntax valid and element exists and is non-empty
#   1: Failure - JSON syntax invalid, element missing, or element is null/empty
#   2: Invalid argument - JSON file path parameter is empty
#   3: Missing dependency - jq command not available (required when element specified)
#   7: File error - JSON file does not exist or cannot be read
#
# Context variables:
#   Reads:
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies: None
#
# Side effects:
#   - Reads JSON file from filesystem
#   - Executes jq command for element validation (if element specified)
#   - Logs validation results to standard logger
#   - No file modifications or network operations
#
# Example:
#   if __validate_json_with_element "/tmp/data.json" "elements"; then
#     echo "Valid OSM JSON with elements"
#   else
#     echo "Validation failed with code: $?"
#   fi
#
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
function __validate_json_with_element {
 __log_start
 local JSON_FILE="${1}"
 local EXPECTED_ELEMENT="${2:-}"

 # First validate basic JSON structure
 if ! __validate_json_structure "${JSON_FILE}"; then
  __loge "Basic JSON validation failed for: ${JSON_FILE}"
  __log_finish
  return 1
 fi

 # If expected element is provided, check it exists
 if [[ -n "${EXPECTED_ELEMENT}" ]]; then
  if ! command -v jq > /dev/null 2>&1; then
   __loge "ERROR: jq command not available for element validation"
   __log_finish
   return 1
  fi

  # Check if expected element exists and is not empty
  local ELEMENT_COUNT
  ELEMENT_COUNT=$(jq -r ".${EXPECTED_ELEMENT} | length" "${JSON_FILE}" 2> /dev/null || echo "0")

  # Check if element exists and has content
  if ! jq -e ".${EXPECTED_ELEMENT} != null" "${JSON_FILE}" > /dev/null 2>&1; then
   __loge "ERROR: JSON file does not contain expected element '${EXPECTED_ELEMENT}': ${JSON_FILE}"
   __log_finish
   return 1
  fi

  # Check if element is not empty (for arrays, length > 0; for objects, not null)
  if [[ "${ELEMENT_COUNT}" == "0" ]] || [[ "${ELEMENT_COUNT}" == "null" ]]; then
   __loge "ERROR: JSON file element '${EXPECTED_ELEMENT}' is empty: ${JSON_FILE}"
   __log_finish
   return 1
  fi

  __logd "JSON contains expected element '${EXPECTED_ELEMENT}'"
 fi

 __logd "JSON validation with element check passed: ${JSON_FILE}"
 __log_finish
 return 0
}

# Validates database connection and basic functionality
# Parameters:
#   $1: Database name (optional, uses DBNAME if not provided)
#   $2: Database user (optional, uses DB_USER if not provided)
#   $3: Database host (optional, uses DBHOST if not provided)
#   $4: Database port (optional, uses DBPORT if not provided)
# Returns:
#   0 if connection successful, 1 if failed

# Validates database table existence and structure
# Parameters:
#   $1: Database name (optional, uses DBNAME if not provided)
#   $2: Database user (optional, uses DB_USER if not provided)
#   $3: Database host (optional, uses DBHOST if not provided)
#   $4: Database port (optional, uses DBPORT if not provided)
#   $5+: List of required table names
# Returns:
#   0 if all tables exist, 1 if any missing

# Validates database schema and extensions
# Parameters:
#   $1: Database name (optional, uses DBNAME if not provided)
#   $2: Database user (optional, uses DB_USER if not provided)
#   $3: Database host (optional, uses DBHOST if not provided)
#   $4: Database port (optional, uses DBPORT if not provided)
#   $5+: List of required extensions
# Returns:
#   0 if all extensions exist, 1 if any missing

# Validates all properties from etc/properties.sh configuration file.
# Ensures all required parameters have valid values and proper types.
#
# Validates:
#   - Database configuration (DBNAME, DB_USER)
#   - Email configuration (EMAILS format, ADMIN_EMAIL format)
#   - URLs (OSM_API, PLANET, OVERPASS_INTERPRETER)
#   - Numeric parameters (LOOP_SIZE, MAX_NOTES, MAX_THREADS, MIN_NOTES_FOR_PARALLEL)
#   - Boolean parameters (CLEAN, SKIP_XML_VALIDATION, SEND_ALERT_EMAIL)
#
# Returns:
#   0 if all properties are valid
#
# Exits:
#   ERROR_GENERAL (1) if any property is invalid
function __validate_properties {
 __log_start
 __logi "Validating properties from configuration file"

 local -i PROPERTY_ERROR_COUNT=0

 # Validate DBNAME (required, non-empty string)
 if [[ -z "${DBNAME:-}" ]]; then
  __loge "ERROR: DBNAME is not set or empty"
  ((PROPERTY_ERROR_COUNT++))
 else
  __logd "✓ DBNAME: ${DBNAME}"
 fi

 # Validate DB_USER (required, non-empty string)
 if [[ -z "${DB_USER:-}" ]]; then
  __loge "ERROR: DB_USER is not set or empty"
  ((PROPERTY_ERROR_COUNT++))
 else
  __logd "✓ DB_USER: ${DB_USER}"
 fi

 # Validate EMAILS (basic email format check)
 if [[ -n "${EMAILS:-}" ]]; then
  # Basic email regex: contains @ and . after @
  if [[ ! "${EMAILS}" =~ ^[^@]+@[^@]+\.[^@]+$ ]]; then
   __logw "WARNING: EMAILS may have invalid format: ${EMAILS}"
   __logw "Expected format: user@domain.com"
  else
   __logd "✓ EMAILS: ${EMAILS}"
  fi
 fi

 # Validate OSM_API (URL format)
 if [[ -n "${OSM_API:-}" ]]; then
  if [[ ! "${OSM_API}" =~ ^https?:// ]]; then
   __loge "ERROR: OSM_API must be a valid HTTP/HTTPS URL, got: ${OSM_API}"
   ((PROPERTY_ERROR_COUNT++))
  else
   __logd "✓ OSM_API: ${OSM_API}"
  fi
 fi

 # Validate PLANET (URL format)
 if [[ -n "${PLANET:-}" ]]; then
  if [[ ! "${PLANET}" =~ ^https?:// ]]; then
   __loge "ERROR: PLANET must be a valid HTTP/HTTPS URL, got: ${PLANET}"
   ((PROPERTY_ERROR_COUNT++))
  else
   __logd "✓ PLANET: ${PLANET}"
  fi
 fi

 # Validate OVERPASS_INTERPRETER (URL format)
 if [[ -n "${OVERPASS_INTERPRETER:-}" ]]; then
  if [[ ! "${OVERPASS_INTERPRETER}" =~ ^https?:// ]]; then
   __loge "ERROR: OVERPASS_INTERPRETER must be a valid HTTP/HTTPS URL, got: ${OVERPASS_INTERPRETER}"
   ((PROPERTY_ERROR_COUNT++))
  else
   __logd "✓ OVERPASS_INTERPRETER: ${OVERPASS_INTERPRETER}"
  fi
 fi

 # Validate LOOP_SIZE (positive integer)
 if [[ -n "${LOOP_SIZE:-}" ]]; then
  if [[ ! "${LOOP_SIZE}" =~ ^[1-9][0-9]*$ ]]; then
   __loge "ERROR: LOOP_SIZE must be a positive integer, got: ${LOOP_SIZE}"
   ((PROPERTY_ERROR_COUNT++))
  else
   __logd "✓ LOOP_SIZE: ${LOOP_SIZE}"
  fi
 fi

 # Validate MAX_NOTES (positive integer)
 if [[ -n "${MAX_NOTES:-}" ]]; then
  if [[ ! "${MAX_NOTES}" =~ ^[1-9][0-9]*$ ]]; then
   __loge "ERROR: MAX_NOTES must be a positive integer, got: ${MAX_NOTES}"
   ((PROPERTY_ERROR_COUNT++))
  else
   __logd "✓ MAX_NOTES: ${MAX_NOTES}"
  fi
 fi

 # Validate MAX_THREADS (positive integer, reasonable limit)
 if [[ -n "${MAX_THREADS:-}" ]]; then
  if [[ ! "${MAX_THREADS}" =~ ^[1-9][0-9]*$ ]]; then
   __loge "ERROR: MAX_THREADS must be a positive integer, got: ${MAX_THREADS}"
   ((PROPERTY_ERROR_COUNT++))
  elif [[ "${MAX_THREADS}" -gt 100 ]]; then
   __logw "WARNING: MAX_THREADS=${MAX_THREADS} exceeds recommended maximum (100)"
   __logw "This may cause excessive resource usage"
  elif [[ "${MAX_THREADS}" -lt 1 ]]; then
   __loge "ERROR: MAX_THREADS must be at least 1, got: ${MAX_THREADS}"
   ((PROPERTY_ERROR_COUNT++))
  else
   __logd "✓ MAX_THREADS: ${MAX_THREADS}"
  fi
 fi

 # Validate MIN_NOTES_FOR_PARALLEL (positive integer)
 if [[ -n "${MIN_NOTES_FOR_PARALLEL:-}" ]]; then
  if [[ ! "${MIN_NOTES_FOR_PARALLEL}" =~ ^[1-9][0-9]*$ ]]; then
   __loge "ERROR: MIN_NOTES_FOR_PARALLEL must be a positive integer, got: ${MIN_NOTES_FOR_PARALLEL}"
   ((PROPERTY_ERROR_COUNT++))
  else
   __logd "✓ MIN_NOTES_FOR_PARALLEL: ${MIN_NOTES_FOR_PARALLEL}"
  fi
 fi

 # Validate CLEAN (boolean: true or false)
 if [[ -n "${CLEAN:-}" ]]; then
  if [[ "${CLEAN}" != "true" && "${CLEAN}" != "false" ]]; then
   __loge "ERROR: CLEAN must be 'true' or 'false', got: ${CLEAN}"
   ((PROPERTY_ERROR_COUNT++))
  else
   __logd "✓ CLEAN: ${CLEAN}"
  fi
 fi

 # Validate SKIP_XML_VALIDATION (boolean: true or false)
 if [[ -n "${SKIP_XML_VALIDATION:-}" ]]; then
  if [[ "${SKIP_XML_VALIDATION}" != "true" && "${SKIP_XML_VALIDATION}" != "false" ]]; then
   __loge "ERROR: SKIP_XML_VALIDATION must be 'true' or 'false', got: ${SKIP_XML_VALIDATION}"
   ((PROPERTY_ERROR_COUNT++))
  else
   __logd "✓ SKIP_XML_VALIDATION: ${SKIP_XML_VALIDATION}"
  fi
 fi

 # Validate ADMIN_EMAIL (email format check)
 if [[ -n "${ADMIN_EMAIL:-}" ]]; then
  # Basic email regex: contains @ and . after @
  if [[ ! "${ADMIN_EMAIL}" =~ ^[^@]+@[^@]+\.[^@]+$ ]]; then
   __logw "WARNING: ADMIN_EMAIL may have invalid format: ${ADMIN_EMAIL}"
   __logw "Expected format: user@domain.com"
   __logw "Email alerts may not work correctly"
  else
   __logd "✓ ADMIN_EMAIL: ${ADMIN_EMAIL}"
  fi
 else
  __logd "✓ ADMIN_EMAIL: using default (root@localhost)"
 fi

 # Validate SEND_ALERT_EMAIL (boolean: true or false)
 if [[ -n "${SEND_ALERT_EMAIL:-}" ]]; then
  if [[ "${SEND_ALERT_EMAIL}" != "true" && "${SEND_ALERT_EMAIL}" != "false" ]]; then
   __loge "ERROR: SEND_ALERT_EMAIL must be 'true' or 'false', got: ${SEND_ALERT_EMAIL}"
   ((PROPERTY_ERROR_COUNT++))
  else
   __logd "✓ SEND_ALERT_EMAIL: ${SEND_ALERT_EMAIL}"
  fi
 fi

 # Check for validation errors
 if [[ ${PROPERTY_ERROR_COUNT} -gt 0 ]]; then
  __loge "Properties validation failed with ${PROPERTY_ERROR_COUNT} error(s)"
  __loge "Please check your etc/properties.sh configuration file"
  __log_finish
  # shellcheck disable=SC2154
  exit "${ERROR_GENERAL}"
 fi

 __logi "✓ All properties validated successfully"
 __log_finish
 return 0
}

# Checks prerequisites commands to run the script.
# Validates that all required tools and libraries are available.
function __checkPrereqsCommands {
 __log_start
 # Check if prerequisites have already been verified in this execution.
 if [[ "${PREREQS_CHECKED}" = true ]]; then
  __logd "Prerequisites already checked in this execution, skipping verification."
  __log_finish
  return 0
 fi

 # Validate properties first (fail-fast on configuration errors)
 __validate_properties

 set +e
 ## PostgreSQL
 __logd "Checking PostgreSQL."
 if ! psql --version > /dev/null 2>&1; then
  __loge "ERROR: PostgreSQL is missing."
  # shellcheck disable=SC2154
  # ERROR_MISSING_LIBRARY is defined in lib/osm-common/commonFunctions.sh
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Database existence
 __logd "Checking if database '${DBNAME}' exists."
 # shellcheck disable=SC2154
 # Export PGHOST/PGPORT if DB_HOST/DB_PORT are set (for Docker support)
 # If not set, psql will use peer authentication (socket Unix)
 if [[ -n "${DB_HOST:-}" ]]; then
  export PGHOST="${DB_HOST}"
 else
  unset PGHOST
 fi
 if [[ -n "${DB_PORT:-}" ]]; then
  export PGPORT="${DB_PORT}"
 else
  unset PGPORT
 fi
 if [[ -n "${DB_USER:-}" ]]; then
  export PGUSER="${DB_USER}"
 fi

 # shellcheck disable=SC2312
 # Intentional: pipeline return value is checked by if statement
 if ! psql -lqt 2> /dev/null | cut -d \| -f 1 | grep -qw "${DBNAME}"; then
  __loge "ERROR: Database '${DBNAME}' does not exist."
  __loge "To create the database, run the following commands:"
  __loge "  createdb ${DBNAME}"
  __loge "  psql -d ${DBNAME} -c 'CREATE EXTENSION postgis;'"
  __loge "  psql -d ${DBNAME} -c 'CREATE EXTENSION btree_gist;'"
  # shellcheck disable=SC2154
  # ERROR_MISSING_LIBRARY is defined in lib/osm-common/commonFunctions.sh
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Database connectivity with specified user
 __logd "Checking database connectivity with user '${DB_USER}'."
 # shellcheck disable=SC2154
 # PGHOST/PGPORT/PGUSER already exported above
 if ! PGAPPNAME="${PGAPPNAME}" psql -U "${DB_USER}" -d "${DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
  __loge "ERROR: Cannot connect to database '${DBNAME}' with user '${DB_USER}'."
  __loge "PostgreSQL authentication failed. Possible solutions:"
  __loge "  1. If user '${DB_USER}' doesn't exist, create it:"
  __loge "     sudo -u postgres createuser -d -P ${DB_USER}"
  __loge "  2. Grant access to the database:"
  __loge "     sudo -u postgres psql -c \"GRANT ALL PRIVILEGES ON DATABASE \\\"${DBNAME}\\\" TO ${DB_USER};\""
  __loge "  3. Configure PostgreSQL authentication in /etc/postgresql/*/main/pg_hba.conf:"
  __loge "     Change 'peer' to 'md5' or 'trust' for local connections"
  __loge "     Example: local   all   ${DB_USER}   md5"
  __loge "     Then reload: sudo systemctl reload postgresql"
  __loge "  4. Or use the current system user instead of '${DB_USER}'"
  # shellcheck disable=SC2154
  # ERROR_MISSING_LIBRARY is defined in lib/osm-common/commonFunctions.sh
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## PostGIS
 __logd "Checking PostGIS."
 # shellcheck disable=SC2154
 # PGHOST/PGPORT/PGUSER already exported above
 PGAPPNAME="${PGAPPNAME}" psql -U "${DB_USER}" -d "${DBNAME}" -v ON_ERROR_STOP=1 > /dev/null 2>&1 << EOF
SELECT /* Notes-base */ PostGIS_version();
EOF
 RET=${?}
 if [[ "${RET}" -ne 0 ]]; then
  __loge "ERROR: PostGIS extension is missing in database '${DBNAME}'."
  __loge "To enable PostGIS, run: psql -U ${DB_USER} -d ${DBNAME} -c 'CREATE EXTENSION postgis;'"
  # shellcheck disable=SC2154
  # ERROR_MISSING_LIBRARY is defined in lib/osm-common/commonFunctions.sh
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## btree gist
 # shellcheck disable=SC2154
 __logd "Checking btree gist."
 # PGHOST/PGPORT/PGUSER already exported above
 RESULT=$(PGAPPNAME="${PGAPPNAME}" psql -U "${DB_USER}" -t -A -c "SELECT COUNT(1) FROM pg_extension WHERE extname = 'btree_gist';" "${DBNAME}")
 if [[ "${RESULT}" -ne 1 ]]; then
  __loge "ERROR: btree_gist extension is missing in database '${DBNAME}'."
  __loge "To enable btree_gist, run: psql -U ${DB_USER} -d ${DBNAME} -c 'CREATE EXTENSION btree_gist;'"
  # shellcheck disable=SC2154
  # ERROR_MISSING_LIBRARY is defined in lib/osm-common/commonFunctions.sh
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Aria2c
 __logd "Checking aria2c."
 if ! aria2c --version > /dev/null 2>&1; then
  __loge "ERROR: Aria2c is missing."
  # shellcheck disable=SC2154
  # ERROR_MISSING_LIBRARY is defined in lib/osm-common/commonFunctions.sh
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## jq (required for JSON/GeoJSON validation)
 __logd "Checking jq."
 if ! jq --version > /dev/null 2>&1; then
  __loge "ERROR: jq is missing."
  # shellcheck disable=SC2154
  # ERROR_MISSING_LIBRARY is defined in lib/osm-common/commonFunctions.sh
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## osmtogeojson
 __logd "Checking osmtogeojson."
 if ! osmtogeojson --version > /dev/null 2>&1; then
  __loge "ERROR: osmtogeojson is missing."
  # shellcheck disable=SC2154
  # ERROR_MISSING_LIBRARY is defined in lib/osm-common/commonFunctions.sh
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## JSON validator
 __logd "Checking ajv."
 if ! ajv help > /dev/null 2>&1; then
  __loge "ERROR: ajv is missing."
  # shellcheck disable=SC2154
  # ERROR_MISSING_LIBRARY is defined in lib/osm-common/commonFunctions.sh
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## gdal ogr2ogr
 __logd "Checking ogr2ogr."
 if ! ogr2ogr --version > /dev/null 2>&1; then
  __loge "ERROR: ogr2ogr is missing."
  # shellcheck disable=SC2154
  # ERROR_MISSING_LIBRARY is defined in lib/osm-common/commonFunctions.sh
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 ## flock
 __logd "Checking flock."
 if ! flock --version > /dev/null 2>&1; then
  __loge "ERROR: flock is missing."
  # shellcheck disable=SC2154
  # ERROR_MISSING_LIBRARY is defined in lib/osm-common/commonFunctions.sh
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Mutt
 __logd "Checking mutt."
 if ! mutt -v > /dev/null 2>&1; then
  __loge "ERROR: mutt is missing."
  # shellcheck disable=SC2154
  # ERROR_MISSING_LIBRARY is defined in lib/osm-common/commonFunctions.sh
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 # Verify mutt has SMTP support compiled in
 # shellcheck disable=SC2312
 # Intentional: pipeline return value is checked by if statement
 if ! mutt -v 2>&1 | grep -qi "USE_SMTP\|+USE_SMTP"; then
  __logw "WARNING: mutt may not have SMTP support compiled in."
  __logw "Email alerts to external addresses may not work."
 fi
 # If ADMIN_EMAIL is configured, validate email format
 if [[ -n "${ADMIN_EMAIL:-}" ]] && [[ "${SEND_ALERT_EMAIL:-true}" == "true" ]]; then
  __logd "Email alerts enabled (ADMIN_EMAIL=${ADMIN_EMAIL})"
  # Note: Actual email sending capability cannot be validated without
  # sending a real email. Test manually if needed:
  # echo "Test" | mutt -s "Test" "${ADMIN_EMAIL}"
 fi
 ## Block-sorting file compressor
 __logd "Checking bzip2."
 if ! bzip2 --help > /dev/null 2>&1; then
  __loge "ERROR: bzip2 is missing."
  # shellcheck disable=SC2154
  # ERROR_MISSING_LIBRARY is defined in lib/osm-common/commonFunctions.sh
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## XML lint (optional, only for strict validation)
 if [[ "${SKIP_XML_VALIDATION}" != "true" ]]; then
  __logd "Checking XML lint."
  if ! xmllint --version > /dev/null 2>&1; then
   __loge "ERROR: XMLlint is missing (required for XML validation)."
   __loge "To skip validation, set: export SKIP_XML_VALIDATION=true"
   # shellcheck disable=SC2154
   # ERROR_MISSING_LIBRARY is defined in lib/osm-common/commonFunctions.sh
   exit "${ERROR_MISSING_LIBRARY}"
  fi
 fi

 ## Bash 4 or greater.
 __logd "Checking Bash version."
 if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  __loge "ERROR: Requires Bash 4+."
  # shellcheck disable=SC2154
  # ERROR_MISSING_LIBRARY is defined in lib/osm-common/commonFunctions.sh
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 __logd "Checking files."
 # Resolve note location backup file (download from GitHub if not found locally)
 # Note: __resolve_note_location_backup is defined earlier in this file
 if declare -f __resolve_note_location_backup > /dev/null 2>&1; then
  # shellcheck disable=SC2310
  # Intentional: check return value explicitly with if statement
  if ! __resolve_note_location_backup; then
   __logw "Warning: Failed to resolve note location backup file. Will continue without backup."
  fi
 fi
 if [[ ! -r "${CSV_BACKUP_NOTE_LOCATION_COMPRESSED}" ]]; then
  __logw "Warning: Backup file is missing at ${CSV_BACKUP_NOTE_LOCATION_COMPRESSED}. Processing will continue without backup (slower)."
 fi
 if [[ ! -r "${POSTGRES_32_UPLOAD_NOTE_LOCATION}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_32_UPLOAD_NOTE_LOCATION}."
  # shellcheck disable=SC2154
  # ERROR_MISSING_LIBRARY is defined in lib/osm-common/commonFunctions.sh
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_33_VERIFY_NOTE_INTEGRITY}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_33_VERIFY_NOTE_INTEGRITY}."
  # shellcheck disable=SC2154
  # ERROR_MISSING_LIBRARY is defined in lib/osm-common/commonFunctions.sh
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_36_REASSIGN_AFFECTED_NOTES}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_36_REASSIGN_AFFECTED_NOTES}."
  # shellcheck disable=SC2154
  # ERROR_MISSING_LIBRARY is defined in lib/osm-common/commonFunctions.sh
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_37_ASSIGN_COUNTRY_TO_NOTES_CHUNK}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_37_ASSIGN_COUNTRY_TO_NOTES_CHUNK}."
  # shellcheck disable=SC2154
  # ERROR_MISSING_LIBRARY is defined in lib/osm-common/commonFunctions.sh
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY_STUB}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY_STUB}."
  # shellcheck disable=SC2154
  # ERROR_MISSING_LIBRARY is defined in lib/osm-common/commonFunctions.sh
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 # XML Schema file (only required if validation is enabled)
 if [[ "${SKIP_XML_VALIDATION}" != "true" ]]; then
  # shellcheck disable=SC2154
  # XMLSCHEMA_PLANET_NOTES is set by the calling script or environment
  if [[ ! -r "${XMLSCHEMA_PLANET_NOTES}" ]]; then
   __loge "ERROR: XML schema file is missing at ${XMLSCHEMA_PLANET_NOTES}."
   __loge "To skip validation, set: export SKIP_XML_VALIDATION=true"
   # shellcheck disable=SC2154
   # ERROR_MISSING_LIBRARY is defined in lib/osm-common/commonFunctions.sh
   exit "${ERROR_MISSING_LIBRARY}"
  fi
 fi
 # shellcheck disable=SC2154
 # JSON_SCHEMA_OVERPASS is defined in pathConfigurationFunctions.sh
 if [[ ! -r "${JSON_SCHEMA_OVERPASS}" ]]; then
  __loge "ERROR: File is missing at ${JSON_SCHEMA_OVERPASS}."
  # shellcheck disable=SC2154
  # ERROR_MISSING_LIBRARY is defined in lib/osm-common/commonFunctions.sh
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 # shellcheck disable=SC2154
 # JSON_SCHEMA_GEOJSON is defined in pathConfigurationFunctions.sh
 if [[ ! -r "${JSON_SCHEMA_GEOJSON}" ]]; then
  __loge "ERROR: File is missing at ${JSON_SCHEMA_GEOJSON}."
  # shellcheck disable=SC2154
  # ERROR_MISSING_LIBRARY is defined in lib/osm-common/commonFunctions.sh
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${GEOJSON_TEST}" ]]; then
  __loge "ERROR: File is missing at ${GEOJSON_TEST}."
  # shellcheck disable=SC2154
  # ERROR_MISSING_LIBRARY is defined in lib/osm-common/commonFunctions.sh
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 ## ogr2ogr import without password
 __logd "Checking ogr2ogr import into postgres without password."
 # shellcheck disable=SC2154
 if ! ogr2ogr -f "PostgreSQL" PG:"dbname=${DBNAME} user=${DB_USER}" \
  "${GEOJSON_TEST}" -nln import -overwrite; then
  __loge "ERROR: ogr2ogr cannot access the database '${DBNAME}' with user '${DB_USER}'."
  # shellcheck disable=SC2154
  # ERROR_MISSING_LIBRARY is defined in lib/osm-common/commonFunctions.sh
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 ## Network connectivity and external service access
 __logd "Checking network connectivity and external service access."

 # Check internet connectivity
 if ! __check_network_connectivity 10; then
  __loge "ERROR: Internet connectivity check failed."
  __loge "The system cannot access the internet, which is required for OSM data downloads."
  # shellcheck disable=SC2154
  # ERROR_INTERNET_ISSUE is defined in lib/osm-common/commonFunctions.sh
  exit "${ERROR_INTERNET_ISSUE}"
 fi

 # Check Planet server access
 __logd "Checking Planet server access."
 # shellcheck disable=SC2154
 local PLANET_URL="${PLANET:-https://planet.openstreetmap.org}"
 if ! timeout 10 curl -s --max-time 10 -I "${PLANET_URL}/planet/notes/" > /dev/null 2>&1; then
  __loge "ERROR: Cannot access Planet server at ${PLANET_URL}."
  __loge "Please check your internet connection and firewall settings."
  exit "${ERROR_INTERNET_ISSUE}"
 fi
 __logd "Planet server is accessible."

 # Check OSM API access and version
 __logd "Checking OSM API access and version."
 # Use the /api/versions endpoint to get API version information
 local API_VERSIONS_URL="https://api.openstreetmap.org/api/versions"
 local TEMP_API_RESPONSE
 TEMP_API_RESPONSE=$(mktemp)

 # Download API versions response to check version
 if ! timeout 15 curl -s --max-time 15 "${API_VERSIONS_URL}" > "${TEMP_API_RESPONSE}" 2> /dev/null; then
  rm -f "${TEMP_API_RESPONSE}"
  __loge "ERROR: Cannot access OSM API at ${API_VERSIONS_URL}."
  __loge "Please check your internet connection and firewall settings."
  exit "${ERROR_INTERNET_ISSUE}"
 fi

 # Check if response contains valid XML
 if [[ ! -s "${TEMP_API_RESPONSE}" ]]; then
  rm -f "${TEMP_API_RESPONSE}"
  __loge "ERROR: OSM API returned empty response."
  exit "${ERROR_INTERNET_ISSUE}"
 fi

 # Extract version from XML response
 # The /api/versions endpoint returns: <api><version>0.6</version></api>
 local DETECTED_VERSION
 # shellcheck disable=SC2312
 # Intentional: grep may not find matches, default to empty string
 DETECTED_VERSION=$(grep -oP '<version>\K[0-9.]+' "${TEMP_API_RESPONSE}" | head -n 1 || echo "")
 rm -f "${TEMP_API_RESPONSE}"

 if [[ -z "${DETECTED_VERSION}" ]]; then
  __loge "ERROR: Cannot detect OSM API version from response."
  __loge "The API response may have changed format."
  exit "${ERROR_INTERNET_ISSUE}"
 fi

 if [[ "${DETECTED_VERSION}" != "0.6" ]]; then
  __loge "ERROR: OSM API version mismatch."
  __loge "Expected version: 0.6, detected version: ${DETECTED_VERSION}."
  __loge "The project is designed for API version 0.6."
  __loge "Please check OSM API announcements for version changes."
  exit "${ERROR_INTERNET_ISSUE}"
 fi
 __logd "OSM API version confirmed: ${DETECTED_VERSION}."

 # Check Overpass API access
 __logd "Checking Overpass API access."
 # shellcheck disable=SC2154
 local OVERPASS_URL="${OVERPASS_INTERPRETER:-https://overpass-api.de/api/interpreter}"
 # Use a minimal query to test Overpass accessibility
 local OVERPASS_TEST_QUERY="[out:json][timeout:5];node(1);out;"
 if ! timeout 15 curl -s --max-time 15 -X POST \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "data=${OVERPASS_TEST_QUERY}" \
  "${OVERPASS_URL}" > /dev/null 2>&1; then
  __loge "ERROR: Cannot access Overpass API at ${OVERPASS_URL}."
  __loge "Please check your internet connection and firewall settings."
  __loge "Note: Overpass access is required for downloading country boundaries."
  exit "${ERROR_INTERNET_ISSUE}"
 fi
 __logd "Overpass API is accessible."

 __logi "All network connectivity and external service checks passed."

 set -e
 # Mark prerequisites as checked for this execution
 PREREQS_CHECKED=true
 __log_finish
}

function __checkPrereqs_functions {
 __log_start
 ## Checks postgres scripts.
 if [[ ! -r "${POSTGRES_11_CHECK_BASE_TABLES}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_11_CHECK_BASE_TABLES}."
  # shellcheck disable=SC2154
  # ERROR_MISSING_LIBRARY is defined in lib/osm-common/commonFunctions.sh
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Checks postgres scripts.
 if [[ ! -r "${POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY}."
  # shellcheck disable=SC2154
  # ERROR_MISSING_LIBRARY is defined in lib/osm-common/commonFunctions.sh
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Checks postgres scripts.
 if [[ ! -r "${POSTGRES_22_CREATE_PROC_INSERT_NOTE}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_22_CREATE_PROC_INSERT_NOTE}."
  # shellcheck disable=SC2154
  # ERROR_MISSING_LIBRARY is defined in lib/osm-common/commonFunctions.sh
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Checks postgres scripts.
 if [[ ! -r "${POSTGRES_23_CREATE_PROC_INSERT_NOTE_COMMENT}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_23_CREATE_PROC_INSERT_NOTE_COMMENT}."
  # shellcheck disable=SC2154
  # ERROR_MISSING_LIBRARY is defined in lib/osm-common/commonFunctions.sh
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Checks postgres scripts.
 if [[ ! -r "${POSTGRES_31_ORGANIZE_AREAS}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_31_ORGANIZE_AREAS}."
  # shellcheck disable=SC2154
  # ERROR_MISSING_LIBRARY is defined in lib/osm-common/commonFunctions.sh
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 __log_finish
}

# Checks the base tables if exist.
# Returns: 0 if all base tables exist, non-zero if tables are missing or error occurs
# Distinguishes between "tables missing" (should run --base) vs "connection/other errors"
##
# Checks if base tables exist in database
# Verifies database connection and checks for existence of base tables (countries, notes,
# note_comments, logs). Distinguishes between missing tables (safe to run --base) and
# other errors (connection, permissions, etc.). Exports RET_FUNC for use by calling scripts.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   0: Success - Base tables exist
#   1: Failure - Base tables are missing (safe to run --base)
#   2: Failure - Database connection error or other system error (do NOT run --base)
#
# Error codes:
#   0: Success - All base tables exist (countries, notes, note_comments, logs)
#   1: Tables missing - Base tables are missing (expected on first run, safe to run --base)
#   2: Connection error - Cannot connect to database (do NOT run --base)
#   2: System error - Other error (permissions, SQL syntax, etc.) (do NOT run --base)
#
# Error conditions:
#   0: Success - All required base tables exist
#   1: Tables missing - One or more base tables missing (countries, notes, note_comments, logs)
#   2: Connection failure - Cannot connect to database
#   2: Unexpected error - psql failed but error is not about missing tables
#
# Context variables:
#   Reads:
#     - DBNAME: PostgreSQL database name (required)
#     - PGAPPNAME: PostgreSQL application name (optional)
#     - POSTGRES_11_CHECK_BASE_TABLES: Path to SQL script (required)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets:
#     - RET_FUNC: Return code exported for calling scripts (0, 1, or 2)
#   Modifies: None
#
# Side effects:
#   - Executes psql to verify database connection
#   - Executes psql to check table existence via SQL script
#   - Exports RET_FUNC environment variable
#   - Writes log messages to stderr
#   - No file or network operations
#   - Temporarily disables set -e (set +e) to handle errors gracefully
#
# Notes:
#   - First verifies database connection before checking tables
#   - Distinguishes between missing tables (code 1) and connection errors (code 2)
#   - Code 1 indicates safe to run --base mode (tables need to be created)
#   - Code 2 indicates system/database issue (do NOT run --base automatically)
#   - Checks for tables: countries, notes, note_comments, logs
#   - Uses SQL script to check table existence (more reliable than individual queries)
#   - Exports RET_FUNC for use by calling scripts
#
# Example:
#   export DBNAME="osm_notes"
#   export POSTGRES_11_CHECK_BASE_TABLES="/path/to/check_base_tables.sql"
#   __checkBaseTables
#   if [[ "${RET_FUNC}" -eq 1 ]]; then
#     echo "Tables missing, running --base mode"
#   elif [[ "${RET_FUNC}" -eq 2 ]]; then
#     echo "Database connection error, manual investigation required"
#   fi
#
# Related: __createBaseTables() (creates base tables)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
##
# Checks if base database tables exist and verifies database connectivity
# Verifies database connection and checks for existence of base tables (countries, notes,
# note_comments, logs). Uses SQL script to perform comprehensive table existence check.
# Distinguishes between "tables missing" (safe to run --base) and other errors (connection,
# permissions, SQL syntax) which require manual investigation.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   0: Success - Base tables exist
#   1: Tables missing - Base tables do not exist (safe to run --base)
#   2: Connection error - Cannot connect to database (do NOT run --base automatically)
#   Non-zero: Other error - SQL execution failed (do NOT run --base automatically)
#
# Error codes:
#   0: Success - Base tables exist and are accessible
#   1: Tables missing - Base tables do not exist (expected on first run, safe to run --base)
#   2: Connection error - Cannot connect to database (system issue, NOT missing tables)
#   Non-zero: Other error - SQL execution failed (permissions, syntax, etc., NOT missing tables)
#
# Error conditions:
#   0: Success - Base tables exist
#   1: Tables missing - SQL script detected missing tables (safe to run --base)
#   2: Connection error - psql connection failed (database down, wrong credentials, etc.)
#   Non-zero: Other error - SQL script failed for reasons other than missing tables
#
# Context variables:
#   Reads:
#     - DBNAME: PostgreSQL database name (required)
#     - PGAPPNAME: PostgreSQL application name (optional)
#     - POSTGRES_11_CHECK_BASE_TABLES: Path to SQL script (required)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets:
#     - RET_FUNC: Return code (exported, used by calling script)
#   Modifies: None
#
# Side effects:
#   - Verifies database connection (SELECT 1 query)
#   - Executes psql to check base table existence (via SQL script)
#   - Writes log messages to stderr
#   - Exports RET_FUNC for calling script to check
#   - Uses set +e temporarily to handle errors gracefully
#   - No file or network operations
#
# Notes:
#   - Distinguishes between "tables missing" and other errors (critical for auto-initialization)
#   - Returns code 1 for missing tables (safe to run --base)
#   - Returns code 2 for connection errors (do NOT run --base automatically)
#   - Returns non-zero for other errors (do NOT run --base automatically)
#   - Used by scripts to determine if --base mode should be triggered automatically
#   - Critical function: Prevents incorrect auto-initialization on connection/permission errors
#   - SQL script checks for: countries, notes, note_comments, logs tables
#   - Uses ON_ERROR_STOP=1 in SQL script to detect missing tables
#
# Example:
#   export DBNAME="osm_notes"
#   export POSTGRES_11_CHECK_BASE_TABLES="/path/to/check_base_tables.sql"
#   __checkBaseTables
#   RET_CODE=$?
#   if [[ ${RET_CODE} -eq 1 ]]; then
#     echo "Tables missing, running --base mode"
#   elif [[ ${RET_CODE} -eq 2 ]]; then
#     echo "Connection error, manual investigation required"
#   fi
#
# Related: __createBaseTables() (creates base tables)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
function __checkBaseTables {
 __log_start
 set +e

 # First, verify database connection works
 __logd "Verifying database connection..."
 if ! PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
  __loge "ERROR: Cannot connect to database '${DBNAME}'"
  __loge "This is NOT a 'tables missing' condition - do NOT run --base"
  RET=2 # Use code 2 for connection errors (not missing tables)
  # Don't enable set -e here as it might affect the calling script
  export RET_FUNC="${RET}"
  __log_finish
  return "${RET}"
 fi
 __logd "Database connection verified"

 # Now check if tables exist
 __logd "Checking for base tables: countries, notes, note_comments, logs"
 __logd "SQL file: ${POSTGRES_11_CHECK_BASE_TABLES}"
 local PSQL_OUTPUT
 local PSQL_ERROR
 PSQL_OUTPUT=$(PGAPPNAME="${PGAPPNAME}" psql -q -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_11_CHECK_BASE_TABLES}" 2>&1)
 RET=${?}
 PSQL_ERROR="${PSQL_OUTPUT}"

 __logd "psql exit code: ${RET}"
 __logd "psql output (first 500 chars): ${PSQL_ERROR:0:500}"

 if [[ "${RET}" -ne 0 ]]; then
  # Check if the error is specifically about missing tables
  # First verify we have error output to check
  if [[ -z "${PSQL_ERROR}" ]]; then
   __loge "ERROR: psql failed (exit code ${RET}) but produced no error output"
   __loge "This is unexpected - investigating required"
   RET=2
  elif echo "${PSQL_ERROR}" | grep -qi "Base tables are missing"; then
   __logw "Base tables are missing (this is expected on first run)"
   __logd "Error details: ${PSQL_ERROR}"
   RET=1 # Tables are missing - safe to run --base
  else
   # This is a different error (connection, permissions, SQL syntax, etc.)
   __loge "ERROR: Failed to check base tables, but NOT because tables are missing"
   __loge "psql exit code: ${RET}"
   __loge "Error output: ${PSQL_ERROR}"
   __loge "This indicates a system/database issue, NOT missing tables"
   __loge "Do NOT run --base automatically - manual investigation required"
   RET=2 # Use different exit code to distinguish from "tables missing"
  fi
 else
  # Script executed successfully - tables exist
  # Now verify get_country function exists (non-critical - will be created if missing)
  __logd "All base tables verified successfully"
  local FUNCTION_EXISTS
  # shellcheck disable=SC2312
  # Intentional: pipeline may fail, default to "0"
  FUNCTION_EXISTS=$(PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM pg_proc WHERE proname = 'get_country' AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');" 2> /dev/null | grep -E '^[0-9]+$' | tail -1 || echo "0")
  if [[ "${FUNCTION_EXISTS}" -eq "0" ]]; then
   __logw "get_country function is missing but tables exist - will be created automatically"
   # Return 0 (tables OK) - function will be created by __ensureGetCountryFunction
  else
   __logd "get_country function verified"
  fi
  RET=0
 fi

 # shellcheck disable=SC2034
 export RET_FUNC="${RET}"
 __logd "Setting RET_FUNC=${RET} (exported)"
 # Also write to a temp file as a backup method to ensure the value is propagated
 # This handles cases where export doesn't work due to subshell or scope issues
 local RET_FUNC_FILE="${TMP_DIR:-/tmp}/.ret_func_$$"
 echo "${RET}" > "${RET_FUNC_FILE}" 2> /dev/null || true
 __logd "Also wrote RET_FUNC=${RET} to ${RET_FUNC_FILE} as backup"
 __log_finish
 # Don't enable set -e here as it might affect the calling script
 # The calling script handles its own error handling
 return "${RET}"
}

# Verifies if the base tables contain historical data.
# This is critical for processAPI to ensure it doesn't run without historical context.
# Returns: 0 if historical data exists, non-zero if validation fails
##
# Validates that historical data exists in base tables
# Checks if base tables contain sufficient historical data (at least 30 days) by executing
# SQL validation script. Ensures ProcessAPI can continue safely with incremental updates.
# Returns error code via RET_FUNC export. Handles set -e gracefully to prevent script exit.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   0: Success - Historical data validation passed
#   1: Failure - Historical data validation failed (insufficient or missing data)
#
# Error codes:
#   0: Success - Historical data validation passed
#   1: Failure - Historical data validation failed (SQL script returned error or ERROR: in output)
#
# Error conditions:
#   0: Success - Historical data exists and is sufficient (at least 30 days)
#   1: Failure - Historical data is missing or insufficient (less than 30 days)
#   1: Failure - SQL script execution failed
#   1: Failure - SQL output contains ERROR: (treated as failure even if exit code is 0)
#
# Context variables:
#   Reads:
#     - DBNAME: PostgreSQL database name (required)
#     - PGAPPNAME: PostgreSQL application name (optional)
#     - TMP_DIR: Temporary directory for output file (optional, default: /tmp)
#     - POSTGRES_11_CHECK_HISTORICAL_DATA: Path to SQL validation script (required)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets:
#     - RET_FUNC: Return code (0 = success, 1 = failure, exported)
#   Modifies: None
#
# Side effects:
#   - Executes psql to run historical data validation SQL script
#   - Creates temporary output file for SQL results
#   - Writes log messages to stderr
#   - Exports RET_FUNC with return code
#   - Handles set -e gracefully (temporarily disables if enabled)
#   - No file, database, or network modifications
#
# Notes:
#   - Validates that base tables contain at least 30 days of historical data
#   - Required before ProcessAPI can process incremental updates
#   - Handles set -e gracefully to prevent script exit on validation failure
#   - Checks SQL output for ERROR: messages (treats as failure even if exit code is 0)
#   - Critical function: Prevents ProcessAPI from running without historical context
#   - Used by __validateHistoricalDataAndRecover() to ensure data integrity
#
# Example:
#   export DBNAME="osm_notes"
#   export POSTGRES_11_CHECK_HISTORICAL_DATA="/path/to/check_historical_data.sql"
#   __checkHistoricalData
#   # RET_FUNC=0 if validation passed, RET_FUNC=1 if failed
#
# Related: __validateHistoricalDataAndRecover() (validates and recovers from gaps)
# Related: processPlanetNotes.sh (loads historical data)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
function __checkHistoricalData {
 __log_start
 __logi "Validating historical data in base tables..."

 # Make this block resilient even when caller has 'set -e' enabled
 local ERREXIT_WAS_ON=false
 if [[ $- == *e* ]]; then
  ERREXIT_WAS_ON=true
  set +e
 fi

 local RET
 local HIST_OUT_FILE
 HIST_OUT_FILE="${TMP_DIR:-/tmp}/hist_check_$$.log"
 # Ensure directory exists
 mkdir -p "${TMP_DIR:-/tmp}" 2> /dev/null || true

 # Execute and capture output and exit code safely
 PGAPPNAME="${PGAPPNAME}" psql -q -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_11_CHECK_HISTORICAL_DATA}" > "${HIST_OUT_FILE}" 2>&1
 RET=$?

 # Restore errexit if it was previously on
 if [[ "${ERREXIT_WAS_ON}" == true ]]; then
  set -e
 fi

 # Read captured output
 local HIST_OUT=""
 if [[ -s "${HIST_OUT_FILE}" ]]; then
  HIST_OUT="$(cat "${HIST_OUT_FILE}")"
 fi
 rm -f "${HIST_OUT_FILE}" 2> /dev/null || true

 # If exit code is zero but output contains ERROR, treat as failure to be safe
 if [[ "${RET}" -eq 0 ]] && echo "${HIST_OUT}" | grep -q "ERROR:"; then
  RET=1
 fi

 # Note: We don't log HIST_OUT directly to avoid variable expansion issues
 # with pg_wrapper messages that may contain $ characters

 if [[ "${RET}" -eq 0 ]]; then
  __logi "Historical data validation passed"
 else
  # Consolidate error messages into a single, clear error log
  local ERROR_MESSAGE="CRITICAL: Historical data validation failed! ProcessAPI cannot continue without historical data from Planet. The system needs historical context to properly process incremental updates. Required action: Run processPlanetNotes.sh first to load historical data: ${SCRIPT_BASE_DIRECTORY}/bin/process/processPlanetNotes.sh. This will load the complete historical dataset from OpenStreetMap Planet dump."
  __loge "${ERROR_MESSAGE}"
 fi

 # shellcheck disable=SC2034
 RET_FUNC="${RET}"
 __log_finish
 return "${RET}"
}

# Drop generic objects.
##
# Drops generic database objects (functions, procedures, types, etc.)
# Executes SQL script to drop generic database objects that are not tables.
# Includes functions, procedures, types, sequences, and other database objects.
# Used during cleanup or database reset operations.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   0: Success - Generic objects dropped successfully
#   Non-zero: Failure - psql command failed
#
# Error codes:
#   0: Success - Generic objects dropped successfully
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
#     - POSTGRES_12_DROP_GENERIC_OBJECTS: Path to SQL script (required)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies: None
#
# Side effects:
#   - Executes psql to drop generic database objects
#   - Drops functions, procedures, types, sequences, etc.
#   - Writes log messages to stderr
#   - No file or network operations
#
# Notes:
#   - Drops non-table objects (functions, procedures, types, sequences)
#   - Used during cleanup or database reset operations
#   - Part of database cleanup workflow
#   - Does not drop tables (tables are dropped separately)
#   - May fail silently if objects don't exist (depends on SQL script)
#
# Example:
#   export DBNAME="osm_notes"
#   export POSTGRES_12_DROP_GENERIC_OBJECTS="/path/to/drop_generic_objects.sql"
#   __dropGenericObjects
#
# Related: __dropBaseTables() (drops base tables)
# Related: __dropSyncTables() (drops sync tables)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
function __dropGenericObjects {
 __log_start
 __logi "Dropping generic objects."
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -f "${POSTGRES_12_DROP_GENERIC_OBJECTS}"
 __log_finish
}

# Checks if there is enough disk space for an operation.
# This function validates available disk space before large downloads or
# file operations to prevent failures due to insufficient space.
#
# Parameters:
#   $1 - directory_path: Directory where files will be written
#   $2 - required_space_gb: Required space in GB (can be decimal)
#   $3 - operation_name: Name of operation for logging (optional)
#
##
# Checks available disk space in a directory
# Validates that sufficient disk space is available for an operation. Compares
# required space (in GB) with available space in the specified directory.
# Handles decimal values and provides detailed logging. Returns 0 if enough
# space is available, 1 if insufficient space. If disk space cannot be determined,
# logs warning and returns 0 (proceeds anyway).
#
# Parameters:
#   $1: DIRECTORY - Directory path to check disk space (required)
#   $2: REQUIRED_GB - Required disk space in GB (decimal supported, e.g., "15.5") (required)
#   $3: OPERATION_NAME - Name of operation for logging (optional, default: "file operation")
#
# Returns:
#   0: Success - Enough space available (or cannot determine, proceeds anyway)
#   1: Failure - Insufficient space or invalid parameters
#
# Error codes:
#   0: Success - Enough space available
#   1: Failure - Insufficient space, invalid directory, or missing required space parameter
#
# Error conditions:
#   0: Success - Enough space available
#   0: Warning - Cannot determine disk space (proceeds anyway)
#   1: Invalid directory - Directory parameter is empty or directory does not exist
#   1: Invalid required space - Required space parameter is empty
#   1: Insufficient space - Available space is less than required space
#
# Context variables:
#   Reads:
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies: None
#
# Side effects:
#   - Executes df command to check disk space
#   - Executes bc or awk for decimal calculations (if available)
#   - Writes log messages to stderr
#   - No file, database, or network operations
#
# Notes:
#   - Supports decimal values for required space (e.g., "15.5" GB)
#   - Uses df -BM to get available space in MB
#   - Converts GB to MB for comparison (1 GB = 1024 MB)
#   - Falls back to awk if bc is not available
#   - If disk space cannot be determined, logs warning and returns 0 (proceeds anyway)
#   - Provides detailed logging with directory, required, available, and shortfall
#   - Used before large file operations (downloads, extractions, etc.)
#   - Critical function: Prevents disk space issues during operations
#
# Example:
#   __check_disk_space "/tmp" "15.5" "Planet download"
#   # Checks if /tmp has at least 15.5 GB available
#
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
function __check_disk_space {
 __log_start
 local DIRECTORY="${1}"
 local REQUIRED_GB="${2}"
 local OPERATION_NAME="${3:-file operation}"

 # Validate parameters
 if [[ -z "${DIRECTORY}" ]]; then
  __loge "ERROR: Directory parameter is required"
  __log_finish
  return 1
 fi

 if [[ -z "${REQUIRED_GB}" ]]; then
  __loge "ERROR: Required space parameter is required"
  __log_finish
  return 1
 fi

 # Validate directory exists
 if [[ ! -d "${DIRECTORY}" ]]; then
  __loge "ERROR: Directory does not exist: ${DIRECTORY}"
  __log_finish
  return 1
 fi

 # Get available space in MB (df -BM outputs in MB)
 local AVAILABLE_MB
 # shellcheck disable=SC2312
 # Intentional: pipeline may fail, will be validated below
 AVAILABLE_MB=$(df -BM "${DIRECTORY}" | awk 'NR==2 {print $4}' | sed 's/M//' || echo "")

 # Validate we got a valid number
 if [[ ! "${AVAILABLE_MB}" =~ ^[0-9]+$ ]]; then
  __logw "WARNING: Could not determine available disk space, proceeding anyway"
  __log_finish
  return 0
 fi

 # Convert required GB to MB for comparison
 # Handle decimal values by using bc or awk
 local REQUIRED_MB
 if command -v bc > /dev/null 2>&1; then
  # shellcheck disable=SC2312
  # Intentional: bc calculation may fail, will be handled by fallback
  REQUIRED_MB=$(echo "${REQUIRED_GB} * 1024" | bc | cut -d. -f1 || echo "0")
 else
  # Fallback to awk if bc not available
  REQUIRED_MB=$(awk "BEGIN {printf \"%.0f\", ${REQUIRED_GB} * 1024}")
 fi

 # Convert to GB for logging
 local AVAILABLE_GB
 if command -v bc > /dev/null 2>&1; then
  AVAILABLE_GB=$(echo "scale=2; ${AVAILABLE_MB} / 1024" | bc)
 else
  AVAILABLE_GB=$(awk "BEGIN {printf \"%.2f\", ${AVAILABLE_MB} / 1024}")
 fi

 __logi "Disk space check for ${OPERATION_NAME}:"
 __logi "  Directory: ${DIRECTORY}"
 __logi "  Required: ${REQUIRED_GB} GB (${REQUIRED_MB} MB)"
 __logi "  Available: ${AVAILABLE_GB} GB (${AVAILABLE_MB} MB)"

 # Check if we have enough space
 if [[ ${AVAILABLE_MB} -lt ${REQUIRED_MB} ]]; then
  __loge "ERROR: Insufficient disk space for ${OPERATION_NAME}"
  __loge "  Required: ${REQUIRED_GB} GB"
  __loge "  Available: ${AVAILABLE_GB} GB"
  # shellcheck disable=SC2312
  # Intentional: bc calculation may fail, default to "unknown"
  __loge "  Shortfall: $(echo "scale=2; ${REQUIRED_GB} - ${AVAILABLE_GB}" | bc 2> /dev/null || echo "unknown") GB"
  __loge "Please free up disk space in ${DIRECTORY} before proceeding"
  __log_finish
  return 1
 fi

 # Calculate percentage of space that will be used
 local USAGE_PERCENT
 if command -v bc > /dev/null 2>&1; then
  USAGE_PERCENT=$(echo "scale=1; ${REQUIRED_MB} * 100 / ${AVAILABLE_MB}" | bc)
 else
  USAGE_PERCENT=$(awk "BEGIN {printf \"%.1f\", ${REQUIRED_MB} * 100 / ${AVAILABLE_MB}}")
 fi

 # Warn if we'll use more than 80% of available space
 # shellcheck disable=SC2312
 # Intentional: bc calculation may fail, default to 0
 if (($(echo "${USAGE_PERCENT} > 80" | bc -l 2> /dev/null || echo 0))); then
  __logw "WARNING: Operation will use ${USAGE_PERCENT}% of available disk space"
  __logw "Consider freeing up more space for safety margin"
 else
  __logi "✓ Sufficient disk space available (${USAGE_PERCENT}% will be used)"
 fi

 __log_finish
 return 0
}

##
# Downloads Planet notes file from OSM Planet server
# Downloads compressed Planet notes file (.bz2) and MD5 checksum file from OSM Planet server.
# Validates disk space (requires ~20 GB), checks network connectivity, downloads file with
# retry logic, and verifies MD5 checksum. Uses aria2c for multi-connection download.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   0: Success - File downloaded and MD5 verified successfully
#   Non-zero: Failure - Disk space, network, download, or MD5 verification failed
#   Exits with error code on critical failures
#
# Error codes:
#   0: Success - Planet notes file downloaded and MD5 verified
#   ERROR_GENERAL: Insufficient disk space (exits script)
#   ERROR_INTERNET_ISSUE: Network connectivity check failed (exits script)
#   ERROR_DOWNLOADING_NOTES: Download failed after retries (exits script)
#   Non-zero: MD5 verification failed (exits script)
#
# Error conditions:
#   0: Success - File downloaded, moved to expected location, and MD5 verified
#   ERROR_GENERAL: Insufficient disk space (<20 GB available)
#   ERROR_INTERNET_ISSUE: Network connectivity check failed
#   ERROR_DOWNLOADING_NOTES: aria2c download failed after 3 retries
#   ERROR_DOWNLOADING_NOTES: Downloaded file not found at expected location
#   Non-zero: MD5 checksum verification failed
#
# Context variables:
#   Reads:
#     - TMP_DIR: Temporary directory for download (required)
#     - PLANET: OSM Planet server base URL (required)
#     - PLANET_NOTES_NAME: Planet notes filename without extension (required, default: planet-notes-latest.osn)
#     - PLANET_NOTES_FILE: Expected location for downloaded file (required)
#     - DOWNLOAD_USER_AGENT: User agent string for HTTP requests (optional)
#     - LOG_LEVEL: Controls logging verbosity
#     - ERROR_GENERAL: Error code for general failures (defined in commonFunctions.sh)
#     - ERROR_INTERNET_ISSUE: Error code for network issues (defined in commonFunctions.sh)
#     - ERROR_DOWNLOADING_NOTES: Error code for download failures (defined in commonFunctions.sh)
#   Sets: None
#   Modifies: None
#
# Side effects:
#   - Executes disk space check (~20 GB required)
#   - Executes network connectivity check
#   - Downloads compressed file (.bz2) using aria2c (multi-connection, 8 connections)
#   - Downloads MD5 checksum file (.bz2.md5)
#   - Moves downloaded file to expected location (PLANET_NOTES_FILE.bz2)
#   - Verifies MD5 checksum of downloaded file
#   - Creates temporary files during download
#   - Writes log messages to stderr
#   - Exits script on critical failures (does not return)
#
# Notes:
#   - Requires ~20 GB disk space (compressed: ~2 GB, decompressed: ~10 GB, CSV: ~5 GB, margin: ~3 GB)
#   - Uses aria2c for multi-connection download (8 connections, faster than curl)
#   - Downloads to TMP_DIR first, then moves to PLANET_NOTES_FILE.bz2
#   - Verifies MD5 checksum to ensure file integrity
#   - Uses retry logic (3 retries, 10 second backoff) for download
#   - Network connectivity check uses 15 second timeout
#   - File size: compressed ~2 GB, decompressed ~10 GB
#   - Critical function: exits script on failure (does not return)
#
# Example:
#   export TMP_DIR="/tmp"
#   export PLANET="https://planet.openstreetmap.org"
#   export PLANET_NOTES_NAME="planet-notes-latest.osn"
#   export PLANET_NOTES_FILE="/tmp/planet_notes.xml"
#   __downloadPlanetNotes
#
# Related: __check_disk_space() (disk space validation)
# Related: __check_network_connectivity() (network connectivity check)
# Related: __retry_file_operation() (download retry logic)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
##
# Downloads Planet notes file from OSM Planet server
# Downloads compressed Planet notes file (.bz2) from OSM Planet server using aria2c with
# retry logic. Validates disk space (20 GB required), checks network connectivity,
# downloads MD5 checksum file, and validates file integrity. Moves downloaded file to
# expected location. Part of Planet processing workflow.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   0: Success - Planet notes downloaded and validated successfully
#   ERROR_GENERAL: Failure - Insufficient disk space
#   ERROR_INTERNET_ISSUE: Failure - Network connectivity check failed
#   ERROR_DOWNLOADING_NOTES: Failure - Download failed after retries or integrity check failed
#
# Error codes:
#   0: Success - Planet notes downloaded and validated successfully
#   ERROR_GENERAL: Insufficient disk space - Less than 20 GB available
#   ERROR_INTERNET_ISSUE: Network connectivity failed - Cannot reach Planet server
#   ERROR_DOWNLOADING_NOTES: Download failed - aria2c failed after 3 retries
#   ERROR_DOWNLOADING_NOTES: MD5 download failed - curl failed after 3 retries
#   ERROR_DOWNLOADING_NOTES: Integrity check failed - MD5 checksum mismatch
#   ERROR_DOWNLOADING_NOTES: File not readable - Downloaded file exists but is not readable
#
# Error conditions:
#   0: Success - File downloaded, MD5 validated, and file is readable
#   ERROR_GENERAL: Insufficient disk space - __check_disk_space returned error
#   ERROR_INTERNET_ISSUE: Network check failed - __check_network_connectivity returned error
#   ERROR_DOWNLOADING_NOTES: Download failed - aria2c failed after 3 retries (10 second delay)
#   ERROR_DOWNLOADING_NOTES: File not found - Downloaded file not at expected location
#   ERROR_DOWNLOADING_NOTES: MD5 download failed - curl failed after 3 retries (5 second delay)
#   ERROR_DOWNLOADING_NOTES: Integrity check failed - MD5 checksum mismatch
#   ERROR_DOWNLOADING_NOTES: File not readable - File exists but cannot be read
#
# Context variables:
#   Reads:
#     - TMP_DIR: Temporary directory for downloads (required)
#     - PLANET: OSM Planet server base URL (required)
#     - PLANET_NOTES_NAME: Planet notes filename without extension (required)
#     - PLANET_NOTES_FILE: Expected path for Planet notes file (required)
#     - DOWNLOAD_USER_AGENT: User agent for HTTP requests (optional)
#     - ERROR_GENERAL: Error code for general errors (defined in calling script)
#     - ERROR_INTERNET_ISSUE: Error code for network issues (defined in calling script)
#     - ERROR_DOWNLOADING_NOTES: Error code for download failures (defined in calling script)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies:
#     - Downloads Planet notes file (.bz2) to TMP_DIR
#     - Moves downloaded file to PLANET_NOTES_FILE.bz2
#     - Downloads MD5 checksum file (removed after validation)
#
# Side effects:
#   - Validates disk space (20 GB required)
#   - Checks network connectivity (15 second timeout)
#   - Downloads Planet notes file using aria2c (8 connections, retry logic)
#   - Downloads MD5 checksum file using curl (retry logic)
#   - Validates file integrity using MD5 checksum
#   - Moves downloaded file to expected location
#   - Removes MD5 file after validation
#   - Creates failed execution marker on error
#   - Writes log messages to stderr
#   - File operations: Downloads, moves, validates files
#   - Network operations: HTTP downloads from Planet server
#   - No database operations
#
# Notes:
#   - Disk space requirement: ~20 GB (compressed: 2 GB, decompressed: 10 GB, CSV: 5 GB, margin: 3.4 GB)
#   - Uses aria2c for fast download (8 connections, retry logic: 3 attempts, 10 second delay)
#   - Downloads MD5 checksum file for integrity validation
#   - Validates file integrity before proceeding (prevents corrupted downloads)
#   - Moves downloaded file to expected location (PLANET_NOTES_FILE.bz2)
#   - Critical function: Required for Planet processing workflow
#   - Used in base mode (--base) when loading Planet data from scratch
#   - File size: ~2 GB compressed, ~10 GB decompressed
#
# Example:
#   export TMP_DIR="/tmp"
#   export PLANET="https://planet.openstreetmap.org"
#   export PLANET_NOTES_NAME="planet-notes-latest.osn"
#   export PLANET_NOTES_FILE="/tmp/OSM-notes-planet.xml"
#   __downloadPlanetNotes
#   # Downloads Planet notes, validates integrity, moves to expected location
#
# Related: __check_disk_space() (validates disk space)
# Related: __check_network_connectivity() (validates network)
# Related: __validate_file_checksum_from_file() (validates file integrity)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
function __downloadPlanetNotes {
 __log_start

 # Check disk space before downloading
 # Planet notes file requirements:
 # - Compressed file (.bz2): ~2 GB
 # - Decompressed file (.xml): ~10 GB
 # - CSV files generated: ~5 GB
 # - Safety margin (20%): ~3.4 GB
 # Total estimated: ~20 GB
 __logi "Validating disk space for Planet notes download..."
 # shellcheck disable=SC2310
 # Intentional: check return value explicitly with if statement
 if ! __check_disk_space "${TMP_DIR}" "20" "Planet notes download and processing"; then
  __loge "Cannot proceed with Planet download due to insufficient disk space"
  __handle_error_with_cleanup "${ERROR_GENERAL}" "Insufficient disk space for Planet download" \
   "echo 'No cleanup needed - download not started'"
 fi

 # Check network connectivity before proceeding
 __logi "Checking network connectivity..."
 if ! __check_network_connectivity 15; then
  __loge "Network connectivity check failed"
  # shellcheck disable=SC2154
  # PLANET_NOTES_FILE is defined in processPlanetFunctions.sh
  __handle_error_with_cleanup "${ERROR_INTERNET_ISSUE}" "Network connectivity failed" \
   "rm -f ${PLANET_NOTES_FILE}.bz2 ${PLANET_NOTES_FILE}.bz2.md5 2>/dev/null || true"
 fi

 # Download Planet notes with retry logic
 __logw "Retrieving Planet notes file..."
 # shellcheck disable=SC2154
 # PLANET_NOTES_NAME is defined in processPlanetFunctions.sh
 local DOWNLOAD_OPERATION="aria2c -d ${TMP_DIR} -o ${PLANET_NOTES_NAME}.bz2 -x 8 ${PLANET}/notes/${PLANET_NOTES_NAME}.bz2"
 local DOWNLOAD_CLEANUP="rm -f ${TMP_DIR}/${PLANET_NOTES_NAME}.bz2 2>/dev/null || true"

 # shellcheck disable=SC2310
 # Intentional: check return value explicitly with if statement
 if ! __retry_file_operation "${DOWNLOAD_OPERATION}" 3 10 "${DOWNLOAD_CLEANUP}"; then
  __loge "Failed to download Planet notes after retries"
  # shellcheck disable=SC2154
  # ERROR_DOWNLOADING_NOTES is defined in lib/osm-common/commonFunctions.sh
  __handle_error_with_cleanup "${ERROR_DOWNLOADING_NOTES}" "Planet download failed" \
   "rm -f ${TMP_DIR}/${PLANET_NOTES_NAME}.bz2 2>/dev/null || true"
 fi

 # Move downloaded file to expected location
 __logi "DEBUG: Checking for downloaded file: ${TMP_DIR}/${PLANET_NOTES_NAME}.bz2"
 __logi "DEBUG: TMP_DIR: ${TMP_DIR}"
 __logi "DEBUG: PLANET_NOTES_NAME: ${PLANET_NOTES_NAME}"
 if [[ -f "${TMP_DIR}/${PLANET_NOTES_NAME}.bz2" ]]; then
  __logi "DEBUG: File exists, moving to: ${PLANET_NOTES_FILE}.bz2"
  mv "${TMP_DIR}/${PLANET_NOTES_NAME}.bz2" "${PLANET_NOTES_FILE}.bz2"
  __logi "Moved downloaded file to expected location: ${PLANET_NOTES_FILE}.bz2"
  local FILE_EXISTS_CHECK
  # shellcheck disable=SC2312
  # Intentional: test may fail, default to "no"
  FILE_EXISTS_CHECK=$([[ -f "${PLANET_NOTES_FILE}.bz2" ]] && echo "yes" || echo "no")
  __logi "DEBUG: Verifying moved file exists: ${FILE_EXISTS_CHECK}"
 else
  __loge "ERROR: Downloaded file not found at expected location: ${TMP_DIR}/${PLANET_NOTES_NAME}.bz2"
  __loge "DEBUG: Listing files in TMP_DIR:"
  # shellcheck disable=SC2012,SC2312
  # SC2012: Using ls for human-readable directory listing is acceptable here
  # SC2312: Intentional: ls may fail if no files found, handled by || clause
  ls -lh "${TMP_DIR}"/*.bz2 2> /dev/null | while IFS= read -r line; do
   __loge "  ${line}"
  done || __loge "  (no .bz2 files found)"
  __handle_error_with_cleanup "${ERROR_DOWNLOADING_NOTES}" "Downloaded file not found" \
   "rm -f ${TMP_DIR}/${PLANET_NOTES_NAME}.bz2 2>/dev/null || true"
  return "${ERROR_DOWNLOADING_NOTES}"
 fi

 # Download MD5 file with retry logic
 local MD5_OPERATION="curl -s -H \"User-Agent: ${DOWNLOAD_USER_AGENT:-OSM-Notes-Ingestion/1.0}\" -o ${PLANET_NOTES_FILE}.bz2.md5 ${PLANET}/notes/${PLANET_NOTES_NAME}.bz2.md5"
 local MD5_CLEANUP="rm -f ${PLANET_NOTES_FILE}.bz2.md5 2>/dev/null || true"

 # shellcheck disable=SC2310
 # Intentional: check return value explicitly with if statement
 if ! __retry_file_operation "${MD5_OPERATION}" 3 5 "${MD5_CLEANUP}"; then
  __loge "Failed to download MD5 file after retries"
  __handle_error_with_cleanup "${ERROR_DOWNLOADING_NOTES}" "MD5 download failed" \
   "rm -f ${PLANET_NOTES_FILE}.bz2 ${PLANET_NOTES_FILE}.bz2.md5 2>/dev/null || true"
 fi

 # Validate the download with the hash value md5 using centralized function
 __logi "Validating downloaded file integrity..."
 if ! __validate_file_checksum_from_file "${PLANET_NOTES_FILE}.bz2" "${PLANET_NOTES_FILE}.bz2.md5" "md5"; then
  __loge "ERROR: Planet file integrity check failed"
  __handle_error_with_cleanup "${ERROR_DOWNLOADING_NOTES}" "File integrity check failed" \
   "rm -f ${PLANET_NOTES_FILE}.bz2 ${PLANET_NOTES_FILE}.bz2.md5 2>/dev/null || true"
 fi

 rm "${PLANET_NOTES_FILE}.bz2.md5"

 if [[ ! -r "${PLANET_NOTES_FILE}.bz2" ]]; then
  __loge "ERROR: Downloaded notes file is not readable."
  __handle_error_with_cleanup "${ERROR_DOWNLOADING_NOTES}" "Downloaded file not readable" \
   "rm -f ${PLANET_NOTES_FILE}.bz2 2>/dev/null || true"
 fi

 # Extract file - simple and direct
 __logi "Extracting Planet notes..."
 local BZIP2_FILE="${PLANET_NOTES_FILE}.bz2"
 __logi "DEBUG: BZIP2_FILE path: ${BZIP2_FILE}"
 __logi "DEBUG: PLANET_NOTES_FILE: ${PLANET_NOTES_FILE}"

 # Verify file exists before extraction
 __logi "DEBUG: Checking if BZIP2 file exists: ${BZIP2_FILE}"
 if [[ ! -f "${BZIP2_FILE}" ]]; then
  __loge "ERROR: Compressed file not found: ${BZIP2_FILE}"
  __handle_error_with_cleanup "${ERROR_DOWNLOADING_NOTES}" "Compressed file not found" \
   "rm -f \"${BZIP2_FILE}\" \"${PLANET_NOTES_FILE}\" 2>/dev/null || true"
  return "${ERROR_DOWNLOADING_NOTES}"
 fi

 # Log file details for debugging
 __logi "BZIP2 file exists: ${BZIP2_FILE}"
 local FILE_SIZE
 local FILE_TYPE
 # shellcheck disable=SC2312
 # Intentional: stat/file may fail, default to "unknown"
 FILE_SIZE=$(stat -c%s "${BZIP2_FILE}" 2> /dev/null || echo "unknown")
 FILE_TYPE=$(file "${BZIP2_FILE}" 2> /dev/null || echo "unknown")
 __logi "BZIP2 file size: ${FILE_SIZE} bytes"
 __logi "BZIP2 file type: ${FILE_TYPE}"

 # Execute bzip2 extraction
 # Use set +e to prevent script exit on bzip2 errors
 # We verify success by checking if the XML file exists, not by exit code
 set +e
 local BZIP2_OUTPUT
 local BZIP2_EXIT_CODE
 BZIP2_OUTPUT=$(bzip2 -d "${BZIP2_FILE}" 2>&1)
 BZIP2_EXIT_CODE=$?
 set -e

 # Log bzip2 exit code and output for debugging
 __logi "bzip2 -d exit code: ${BZIP2_EXIT_CODE}"
 if [[ -n "${BZIP2_OUTPUT}" ]]; then
  __logi "bzip2 -d output: ${BZIP2_OUTPUT}"
 fi

 # Check if extraction was successful by verifying the XML file exists
 # bzip2 may return non-zero if file was already extracted, but that's OK
 if [[ ! -f "${PLANET_NOTES_FILE}" ]]; then
  __loge "ERROR: Extracted file not found: ${PLANET_NOTES_FILE}"
  local BZIP2_EXISTS_CHECK
  # shellcheck disable=SC2312
  # Intentional: test may fail, default to "no"
  BZIP2_EXISTS_CHECK=$([[ -f "${BZIP2_FILE}" ]] && echo "yes" || echo "no")
  __loge "BZIP2 file still exists: ${BZIP2_EXISTS_CHECK}"
  __loge "BZIP2 exit code was: ${BZIP2_EXIT_CODE}"
  if [[ -n "${BZIP2_OUTPUT}" ]]; then
   __loge "BZIP2 error output: ${BZIP2_OUTPUT}"
  fi
  __handle_error_with_cleanup "${ERROR_DOWNLOADING_NOTES}" "Extracted file not found" \
   "rm -f \"${BZIP2_FILE}\" \"${PLANET_NOTES_FILE}\" 2>/dev/null || true"
  # __handle_error_with_cleanup returns error code, so return here
  return "${ERROR_DOWNLOADING_NOTES}"
 fi

 __logi "Successfully extracted Planet notes: \"${PLANET_NOTES_FILE}\""

 __log_finish
 return 0
}

# Creates a function that performs basic triage according to longitude:
# * -180 - -30: Americas.
# * -30 - 25: West Europe and West Africa.
# * 25 - 65: Middle East, East Africa and Russia.
# * 65 - 180: Southeast Asia and Oceania.
##
# Creates or replaces the get_country PostgreSQL function
# Creates the get_country function used for country lookup by coordinates.
# If countries table exists, creates full function; otherwise creates stub function.
# The stub function returns NULL when countries table doesn't exist, allowing
# procedures to work without country assignment until countries table is loaded.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   0: Success - Function created successfully (full or stub)
#   1: Failure - SQL file not found or psql execution failed
#
# Error codes:
#   0: Success - get_country function created or replaced successfully
#   1: Failure - Required SQL file not found or psql command failed
#
# Error conditions:
#   0: Success - Function created successfully (checks countries table existence)
#   1: SQL file missing - POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY_STUB not found (when table missing)
#   1: SQL file missing - POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY not found (when table exists)
#   1: Database error - psql command failed (connection error, SQL syntax error, etc.)
#
# Context variables:
#   Reads:
#     - DBNAME: PostgreSQL database name (required)
#     - PGAPPNAME: PostgreSQL application name for connection identification (optional)
#     - POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY_STUB: Path to stub function SQL file (required if countries table missing)
#     - POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY: Path to full function SQL file (required if countries table exists)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies: None
#
# Side effects:
#   - Executes psql queries to check countries table existence
#   - Executes psql to create or replace get_country function in database
#   - Creates stub function (returns NULL) if countries table doesn't exist
#   - Creates full function (looks up country by coordinates) if countries table exists
#   - Writes log messages to stderr
#   - No file or network operations
#
# Notes:
#   - Checks countries table existence before deciding which function to create
#   - Stub function allows procedures to work without country assignment
#   - Full function requires countries table to be populated
#   - To create full function after stub, run updateCountries.sh --base first
#
# Example:
#   export DBNAME="osm_notes"
#   export POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY_STUB="/path/to/stub.sql"
#   export POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY="/path/to/full.sql"
#   __createFunctionToGetCountry
#
# Related: __organizeAreas() (organizes countries into geographic areas)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
function __createFunctionToGetCountry {
 __log_start
 # Check if countries table exists before creating get_country function
 local COUNTRIES_TABLE_EXISTS
 COUNTRIES_TABLE_EXISTS=$(PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -Atq -c "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'countries');" 2> /dev/null || echo "f")

 if [[ "${COUNTRIES_TABLE_EXISTS}" != "t" ]]; then
  __logw "Countries table does not exist. Creating stub get_country function."
  # Validate SQL file exists
  if [[ ! -f "${POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY_STUB}" ]]; then
   __loge "ERROR: SQL file does not exist: ${POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY_STUB}"
   __log_finish
   return 1
  fi
  # Create a stub function that returns NULL when countries table doesn't exist
  local STUB_PSQL_EXIT_CODE=0
  local STUB_PSQL_OUTPUT
  set +e
  STUB_PSQL_OUTPUT=$(PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY_STUB}" 2>&1) || STUB_PSQL_EXIT_CODE=$?
  set -e
  
  if [[ "${STUB_PSQL_EXIT_CODE}" -ne 0 ]]; then
   __logw "WARNING: Stub function creation had warnings (exit code: ${STUB_PSQL_EXIT_CODE}), but continuing..."
   __logd "Stub psql output: ${STUB_PSQL_OUTPUT}"
  fi
  __log_finish
  return 0
 fi

 if [[ ! -f "${POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY}" ]]; then
  __loge "ERROR: SQL file does not exist: ${POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY}"
  __log_finish
  return 1
 fi

 local PSQL_EXIT_CODE=0
 local PSQL_OUTPUT
 set +e
 PSQL_OUTPUT=$(PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY}" 2>&1) || PSQL_EXIT_CODE=$?
 set -e
 
 if [[ "${PSQL_EXIT_CODE}" -ne 0 ]]; then
  __loge "ERROR: Failed to create get_country function from ${POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY}"
  __loge "psql exit code: ${PSQL_EXIT_CODE}"
  __loge "psql output: ${PSQL_OUTPUT}"
  __log_finish
  return 1
 fi
 __log_finish
 return 0
}

##
# Creates PostgreSQL procedures for inserting notes and comments
# Creates two stored procedures: one for inserting OSM notes and one for inserting note comments.
# These procedures are used by the ingestion process to insert data into the database.
# Validates that required SQL files exist before execution.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   Exits with ERROR_MISSING_LIBRARY if required variables/files are missing
#   Returns 0 if procedures created successfully
#   Exits with psql exit code if SQL execution fails
#
# Error codes:
#   0: Success - Both procedures created successfully
#   ERROR_MISSING_LIBRARY: Required environment variable or SQL file missing
#   Non-zero: psql command failed (SQL syntax error, connection error, etc.)
#
# Error conditions:
#   0: Success - Both insert_note and insert_note_comment procedures created
#   ERROR_MISSING_LIBRARY: POSTGRES_22_CREATE_PROC_INSERT_NOTE variable not defined
#   ERROR_MISSING_LIBRARY: POSTGRES_23_CREATE_PROC_INSERT_NOTE_COMMENT variable not defined
#   ERROR_MISSING_LIBRARY: POSTGRES_22_CREATE_PROC_INSERT_NOTE SQL file not found
#   ERROR_MISSING_LIBRARY: POSTGRES_23_CREATE_PROC_INSERT_NOTE_COMMENT SQL file not found
#   Non-zero: psql execution failed (check psql error message)
#
# Context variables:
#   Reads:
#     - DBNAME: PostgreSQL database name (required)
#     - PGAPPNAME: PostgreSQL application name for connection identification (optional)
#     - POSTGRES_22_CREATE_PROC_INSERT_NOTE: Path to insert_note procedure SQL file (required)
#     - POSTGRES_23_CREATE_PROC_INSERT_NOTE_COMMENT: Path to insert_note_comment procedure SQL file (required)
#     - LOG_LEVEL: Controls logging verbosity
#     - ERROR_MISSING_LIBRARY: Error code for missing library/file (defined in commonFunctions.sh)
#   Sets: None
#   Modifies: None
#
# Side effects:
#   - Executes psql to create insert_note procedure in database
#   - Executes psql to create insert_note_comment procedure in database
#   - Exits script if required variables/files are missing (does not return)
#   - Writes log messages to stderr
#   - No file or network operations
#
# Notes:
#   - Uses ON_ERROR_STOP=1 to ensure SQL errors cause immediate failure
#   - Procedures are created in the public schema
#   - Procedures are used by note ingestion scripts
#   - Must be called after database schema is initialized
#
# Example:
#   export DBNAME="osm_notes"
#   export POSTGRES_22_CREATE_PROC_INSERT_NOTE="/path/to/insert_note.sql"
#   export POSTGRES_23_CREATE_PROC_INSERT_NOTE_COMMENT="/path/to/insert_comment.sql"
#   __createProcedures
#
# Related: __createFunctionToGetCountry() (creates get_country function)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
function __createProcedures {
 __log_start
 __logd "Creating procedures."

 # Validate that POSTGRES_22_CREATE_PROC_INSERT_NOTE is defined
 if [[ -z "${POSTGRES_22_CREATE_PROC_INSERT_NOTE:-}" ]]; then
  __loge "ERROR: POSTGRES_22_CREATE_PROC_INSERT_NOTE variable is not defined. This variable should be defined in the calling script"
  # shellcheck disable=SC2154
  # ERROR_MISSING_LIBRARY is defined in lib/osm-common/commonFunctions.sh
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 # Validate that POSTGRES_23_CREATE_PROC_INSERT_NOTE_COMMENT is defined
 if [[ -z "${POSTGRES_23_CREATE_PROC_INSERT_NOTE_COMMENT:-}" ]]; then
  __loge "ERROR: POSTGRES_23_CREATE_PROC_INSERT_NOTE_COMMENT variable is not defined. This variable should be defined in the calling script"
  # shellcheck disable=SC2154
  # ERROR_MISSING_LIBRARY is defined in lib/osm-common/commonFunctions.sh
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 # Validate that the SQL files exist
 if [[ ! -f "${POSTGRES_22_CREATE_PROC_INSERT_NOTE}" ]]; then
  __loge "ERROR: SQL file not found: ${POSTGRES_22_CREATE_PROC_INSERT_NOTE}"
  # shellcheck disable=SC2154
  # ERROR_MISSING_LIBRARY is defined in lib/osm-common/commonFunctions.sh
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 if [[ ! -f "${POSTGRES_23_CREATE_PROC_INSERT_NOTE_COMMENT}" ]]; then
  __loge "ERROR: SQL file not found: ${POSTGRES_23_CREATE_PROC_INSERT_NOTE_COMMENT}"
  # shellcheck disable=SC2154
  # ERROR_MISSING_LIBRARY is defined in lib/osm-common/commonFunctions.sh
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 # Creates a procedure that inserts a note.
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_22_CREATE_PROC_INSERT_NOTE}"

 # Creates a procedure that inserts a note comment.
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_23_CREATE_PROC_INSERT_NOTE_COMMENT}"
 __log_finish
}

##
# Organizes countries into geographic areas for efficient country lookup
# Assigns representative country values to each geographic area to optimize
# country lookup operations. Requires countries table to exist and have data.
# This function is used to improve performance of get_country function calls.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   0: Success - Areas organized successfully, or skipped if prerequisites not met
#   Exits with ERROR_MISSING_LIBRARY if required variable/file is missing
#   Returns psql exit code if SQL execution fails
#
# Error codes:
#   0: Success - Areas organized successfully or skipped (table missing/empty)
#   ERROR_MISSING_LIBRARY: Required environment variable or SQL file missing
#   Non-zero: psql command failed (SQL syntax error, connection error, etc.)
#
# Error conditions:
#   0: Success - Areas organized successfully
#   0: Skipped - Countries table does not exist (logged as warning, returns 0)
#   0: Skipped - Countries table is empty (logged as warning, returns 0)
#   ERROR_MISSING_LIBRARY: POSTGRES_31_ORGANIZE_AREAS variable not defined
#   ERROR_MISSING_LIBRARY: POSTGRES_31_ORGANIZE_AREAS SQL file not found
#   Non-zero: psql execution failed (check psql error message)
#
# Context variables:
#   Reads:
#     - DBNAME: PostgreSQL database name (required)
#     - PGAPPNAME: PostgreSQL application name for connection identification (optional)
#     - POSTGRES_31_ORGANIZE_AREAS: Path to organize_areas SQL file (required)
#     - LOG_LEVEL: Controls logging verbosity
#     - ERROR_MISSING_LIBRARY: Error code for missing library/file (defined in commonFunctions.sh)
#   Sets: None
#   Modifies: None
#
# Side effects:
#   - Executes psql queries to check countries table existence and data count
#   - Executes psql to run organize_areas SQL script (inserts representative countries)
#   - Exits script if required variable/file is missing (does not return)
#   - Writes log messages to stderr
#   - No file or network operations
#
# Notes:
#   - Gracefully skips if countries table doesn't exist or is empty
#   - Uses ON_ERROR_STOP=1 to ensure SQL errors cause immediate failure
#   - Must be called after countries table is populated
#   - Improves performance of get_country function by organizing countries into areas
#   - Run updateCountries.sh --base to create and populate countries table first
#
# Example:
#   export DBNAME="osm_notes"
#   export POSTGRES_31_ORGANIZE_AREAS="/path/to/organize_areas.sql"
#   __organizeAreas
#
# Related: __createFunctionToGetCountry() (creates get_country function)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
function __organizeAreas {
 __log_start
 __logd "Organizing areas."

 # Validate that POSTGRES_31_ORGANIZE_AREAS is defined
 if [[ -z "${POSTGRES_31_ORGANIZE_AREAS:-}" ]]; then
  __loge "ERROR: POSTGRES_31_ORGANIZE_AREAS variable is not defined"
  __loge "ERROR: This variable should be defined in the calling script"
  # shellcheck disable=SC2154
  # ERROR_MISSING_LIBRARY is defined in lib/osm-common/commonFunctions.sh
  __log_finish
  return "${ERROR_MISSING_LIBRARY}"
 fi

 # Validate that the SQL file exists
 if [[ ! -f "${POSTGRES_31_ORGANIZE_AREAS}" ]]; then
  __loge "ERROR: SQL file not found: ${POSTGRES_31_ORGANIZE_AREAS}"
  # shellcheck disable=SC2154
  # ERROR_MISSING_LIBRARY is defined in lib/osm-common/commonFunctions.sh
  __log_finish
  return "${ERROR_MISSING_LIBRARY}"
 fi

 # Check if countries table exists
 local COUNTRIES_TABLE_EXISTS
 COUNTRIES_TABLE_EXISTS=$(PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -Atq -c "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'countries');" 2> /dev/null || echo "f")

 if [[ "${COUNTRIES_TABLE_EXISTS}" != "t" ]]; then
  __logw "Countries table does not exist. Skipping areas organization."
  __logw "Areas organization requires countries table to be created first."
  __logw "Run updateCountries.sh --base to create countries table."
  __log_finish
  return 0
 fi

 # Check if countries table has data
 local COUNTRIES_COUNT
 COUNTRIES_COUNT=$(PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM countries;" 2> /dev/null || echo "0")

 if [[ "${COUNTRIES_COUNT}" -eq "0" ]]; then
  __logw "Countries table is empty. Skipping areas organization."
  __logw "Areas organization requires countries table to have data."
  __logw "Run updateCountries.sh --base to load countries data."
  __log_finish
  return 0
 fi

 set +e
 # Insert values for representative countries in each area.
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_31_ORGANIZE_AREAS}"
 RET=${?}
 set -e
 # shellcheck disable=SC2034
 RET_FUNC="${RET}"
 __log_finish
 if [[ "${RET}" -ne 0 ]]; then
  return "${RET}"
 fi
 return 0
}

# Processes a specific boundary ID.
# Parameters:
#   $1: Query file path (optional, uses global QUERY_FILE if not provided)
function __processBoundary {
 __processBoundary_impl "$@"
}

##
# Downloads boundary data from Overpass API with fallback across multiple endpoints
# Attempts download from each configured endpoint until one succeeds and validates JSON.
# Uses retry logic with exponential backoff and validates downloaded JSON structure.
#
# Parameters:
#   $1: Query file path - Path to Overpass query file (required)
#   $2: Output JSON file path - Path where downloaded JSON will be saved (required)
#   $3: Output capture/stderr file - Path for Overpass tool stderr output (required)
#   $4: Max retries - Maximum retry attempts per endpoint (optional, default: from OVERPASS_RETRIES_PER_ENDPOINT)
#   $5: Base delay - Base delay in seconds for exponential backoff (optional, default: from OVERPASS_BACKOFF_SECONDS)
#
# Returns:
#   0: Success - JSON downloaded and validated from at least one endpoint
#   1: Failure - All endpoints failed or downloaded JSON is invalid
#   2: Invalid argument - Missing required parameters (query file or output file)
#   3: Missing dependency - curl command not found
#   6: Network error - All endpoints unavailable or timeout
#   7: File error - Cannot create output file or write permissions denied
#   8: Validation error - Downloaded JSON is invalid or missing 'elements' key
#
# Error codes:
#   0: Success - Valid JSON downloaded from at least one endpoint
#   1: Failure - All endpoints exhausted or JSON validation failed
#   2: Invalid argument - Query file path is empty or output file path is empty
#   3: Missing dependency - curl command not available
#   6: Network error - All Overpass endpoints unavailable or connection timeout
#   7: File error - Cannot write to output file (disk full, permissions)
#   8: Validation error - JSON structure invalid or missing required 'elements' array
#
# Context variables:
#   Reads:
#     - OVERPASS_ENDPOINTS: Comma-separated list of Overpass API endpoints (optional, falls back to OVERPASS_INTERPRETER)
#     - OVERPASS_INTERPRETER: Default Overpass API endpoint URL (required if OVERPASS_ENDPOINTS not set)
#     - OVERPASS_RETRIES_PER_ENDPOINT: Max retries per endpoint (default: 7)
#     - OVERPASS_BACKOFF_SECONDS: Base delay for retries (default: 20)
#     - DOWNLOAD_USER_AGENT: User-Agent header for HTTP requests (optional, default: OSM-Notes-Ingestion/1.0)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets:
#     - CURRENT_OVERPASS_ENDPOINT: Currently active endpoint URL (exported)
#     - OVERPASS_ACTIVE_ENDPOINT: Currently active endpoint URL (exported)
#   Modifies: None
#
# Side effects:
#   - Downloads JSON file from Overpass API using curl
#   - Creates output JSON file and stderr capture file
#   - Validates JSON structure using __validate_json_with_element
#   - Exports CURRENT_OVERPASS_ENDPOINT and OVERPASS_ACTIVE_ENDPOINT environment variables
#   - Logs all operations to standard logger
#   - Cleans up output files before each endpoint attempt
#
# Example:
#   if __overpass_download_with_endpoints "/tmp/query.op" "/tmp/output.json" "/tmp/stderr.log" 5 10; then
#     echo "Download succeeded"
#   else
#     echo "Download failed with code: $?"
#   fi
#
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
function __overpass_download_with_endpoints() {
 __log_start
 local LOCAL_QUERY_FILE="$1"
 local LOCAL_JSON_FILE="$2"
 local LOCAL_OUTPUT_FILE="$3"
 local LOCAL_MAX_RETRIES="$4"
 local LOCAL_BASE_DELAY="$5"

 # Parse endpoints list
 local ENDPOINTS_RAW="${OVERPASS_ENDPOINTS:-${OVERPASS_INTERPRETER}}"
 IFS=',' read -r -a ENDPOINTS_ARRAY <<< "${ENDPOINTS_RAW}"

 # Keep original interpreter for reference, but avoid reassigning readonly globals
 local ORIGINAL_OVERPASS="${OVERPASS_INTERPRETER}"
 local ACTIVE_OVERPASS="${ORIGINAL_OVERPASS}"

 for ENDPOINT in "${ENDPOINTS_ARRAY[@]}"; do
  ENDPOINT="${ENDPOINT//[[:space:]]/}"
  if [[ -z "${ENDPOINT}" ]]; then
   continue
  fi
  __logw "[overpass] Trying endpoint=${ENDPOINT} for query download"

  # Select active endpoint for this attempt (do not modify readonly globals)
  ACTIVE_OVERPASS="${ENDPOINT}"
  export CURRENT_OVERPASS_ENDPOINT="${ACTIVE_OVERPASS}"
  export OVERPASS_ACTIVE_ENDPOINT="${ACTIVE_OVERPASS}"

  # Cleanup before each attempt
  rm -f "${LOCAL_JSON_FILE}" "${LOCAL_OUTPUT_FILE}" 2> /dev/null || true

  local OP
  __logd "Using User-Agent for Overpass: ${DOWNLOAD_USER_AGENT:-OSM-Notes-Ingestion/1.0}"
  OP="curl -s -H \"User-Agent: ${DOWNLOAD_USER_AGENT:-OSM-Notes-Ingestion/1.0}\" -o ${LOCAL_JSON_FILE} --data-binary @${LOCAL_QUERY_FILE} ${ACTIVE_OVERPASS} 2> ${LOCAL_OUTPUT_FILE}"
  local CL="rm -f ${LOCAL_JSON_FILE} ${LOCAL_OUTPUT_FILE} 2>/dev/null || true"
  # shellcheck disable=SC2310
  # Intentional: check return value explicitly with if statement
  if __retry_file_operation "${OP}" "${LOCAL_MAX_RETRIES}" "${LOCAL_BASE_DELAY}" "${CL}" "true" "${ACTIVE_OVERPASS}"; then
   __logd "Download succeeded from endpoint=${ENDPOINT}"
   # Validate JSON has elements key
   # shellcheck disable=SC2310
   # Intentional: check return value explicitly with if statement
   if __validate_json_with_element "${LOCAL_JSON_FILE}" "elements"; then
    __logd "JSON validation succeeded from endpoint=${ENDPOINT}"
    __log_finish
    return 0
   else
    __logw "Invalid JSON from endpoint=${ENDPOINT}; will try next endpoint"
   fi
  else
   __logw "Download failed from endpoint=${ENDPOINT}; will try next endpoint"
  fi
 done

 # Nothing to restore; we never modified global interpreter
 __log_finish
 return 1
}

# Processes the list of countries or maritime areas in the given file.
function __processList {
 __log_start
 __logi "=== STARTING LIST PROCESSING ==="
 __logd "Process ID: ${BASHPID}"
 __logd "Boundaries file: ${1}"

 BOUNDARIES_FILE="${1}"
 # Create a unique query file for this process
 local QUERY_FILE_LOCAL="${TMP_DIR}/query.${BASHPID}.op"
 __logi "Retrieving the country or maritime boundaries."
 local PROCESSED_COUNT=0
 local FAILED_COUNT=0
 local TOTAL_LINES
 TOTAL_LINES=$(wc -l < "${BOUNDARIES_FILE}")
 __logd "Total boundaries to process: ${TOTAL_LINES}"

 while read -r LINE; do
  ID=$(echo "${LINE}" | awk '{print $1}')
  JSON_FILE="${TMP_DIR}/${ID}.json"
  GEOJSON_FILE="${TMP_DIR}/${ID}.geojson"
  __logi "Processing boundary ID: ${ID} (${PROCESSED_COUNT}/${TOTAL_LINES})"
  __logd "Creating query file for boundary ${ID}..."
  cat << EOF > "${QUERY_FILE_LOCAL}"
   [out:json];
   rel(${ID});
   (._;>;);
   out;
EOF

  # shellcheck disable=SC2310
  # Intentional: check return value explicitly with if statement
  if __processBoundary "${QUERY_FILE_LOCAL}"; then
   PROCESSED_COUNT=$((PROCESSED_COUNT + 1))
   __logd "Successfully processed boundary ${ID}"
  else
   FAILED_COUNT=$((FAILED_COUNT + 1))
   __loge "Failed to process boundary ${ID}"
  fi

  if [[ -n "${CLEAN:-}" ]] && [[ "${CLEAN}" = true ]]; then
   rm -f "${JSON_FILE}" "${GEOJSON_FILE}" "${QUERY_FILE_LOCAL}"
  else
   # Only move files if they exist (may not exist if processing failed)
   if [[ -f "${JSON_FILE}" ]]; then
    mv "${JSON_FILE}" "${TMP_DIR}/${ID}.json.old" 2> /dev/null \
     || __logw "Failed to move JSON file for boundary ${ID}"
   else
    __logd "JSON file not found for boundary ${ID} (may have been cleaned up)"
   fi
   if [[ -f "${GEOJSON_FILE}" ]]; then
    mv "${GEOJSON_FILE}" "${TMP_DIR}/${ID}.geojson.old" 2> /dev/null \
     || __logw "Failed to move GeoJSON file for boundary ${ID}"
   else
    __logd "GeoJSON file not found for boundary ${ID} (may have been cleaned up)"
   fi
  fi
 done < "${BOUNDARIES_FILE}"

 __logi "List processing completed:"
 __logi "  Total boundaries: ${TOTAL_LINES}"
 __logi "  Successfully processed: ${PROCESSED_COUNT}"
 __logi "  Failed: ${FAILED_COUNT}"
 __logi "=== LIST PROCESSING COMPLETED ==="
 __log_finish
}

# Download the list of countries, then it downloads each country individually,
# converts the OSM JSON into a GeoJSON, and then it inserts the geometry of the
# country into the Postgres database with ogr2ogr.
function __preserve_failed_boundary_artifacts {
 __log_start
 local FAILED_ARTIFACTS="${1:-}"

 if [[ -n "${FAILED_ARTIFACTS}" ]]; then
  __logi "Preserving failed boundary artifacts: ${FAILED_ARTIFACTS}"
 else
  __logi "No failed boundary artifacts were specified."
 fi

 __log_finish
 return 0
}

# Download the list of countries, then it downloads each country individually,
# converts the OSM JSON into a GeoJSON, and then it inserts the geometry of the
# country into the Postgres database with ogr2ogr.
function __processCountries {
 local RETURN_CODE=0

 if __processCountries_impl "$@"; then
  return 0
 fi

 RETURN_CODE=$?
 # shellcheck disable=SC2154
 # ERROR_DOWNLOADING_BOUNDARY is defined in lib/osm-common/commonFunctions.sh
 __handle_error_with_cleanup "${ERROR_DOWNLOADING_BOUNDARY}" \
  "Country processing wrapper detected failure (exit code: ${RETURN_CODE})" \
  "__preserve_failed_boundary_artifacts 'wrapper-detected-failure'"

 return "${ERROR_DOWNLOADING_BOUNDARY}"
}

# Download the list of maritimes areas, then it downloads each area
# individually, converts the OSM JSON into a GeoJSON, and then it inserts the
# geometry of the maritime area into the Postgres database with ogr2ogr.
function __processMaritimes {
 __processMaritimes_impl "$@"
}

# Gets the area of each note.
##
# Assigns countries to notes using location data (wrapper function)
# Wrapper function that delegates to __getLocationNotes_impl() for country assignment.
# Supports two modes: production mode (loads backup CSV for speed) and hybrid/test mode
# (calculates countries directly). In production mode, loads note location backup CSV,
# imports to database, and verifies integrity using parallel processing. In hybrid/test
# mode, calculates countries only for notes without country assignment using get_country()
# function.
#
# Parameters:
#   $@: Optional arguments passed to implementation function (optional)
#
# Returns:
#   0: Success - Countries assigned successfully (or no notes to process)
#   1: Failure - Database error, file operation error, or verification failure
#
# Error codes:
#   0: Success - Countries assigned successfully
#   1: Failure - Database error, file operation error, or verification failure
#
# Context variables:
#   Reads:
#     - DBNAME: PostgreSQL database name (required)
#     - HYBRID_MOCK_MODE: If set, uses test mode (optional)
#     - TEST_MODE: If set, uses test mode (optional)
#     - CSV_BACKUP_NOTE_LOCATION_COMPRESSED: Path to compressed backup CSV (optional)
#     - POSTGRES_32_UPLOAD_NOTE_LOCATION: SQL script path (optional)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies:
#     - Updates id_country column in notes table
#
# Side effects:
#   - Delegates to __getLocationNotes_impl() for actual processing
#   - See __getLocationNotes_impl() for detailed side effects
#
# Example:
#   export DBNAME="osm_notes"
#   __getLocationNotes
#   # Assigns countries to notes using location data
#
# Related: __getLocationNotes_impl() (implementation function)
# Related: __createFunctionToGetCountry() (creates get_country function)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
function __getLocationNotes {
 __getLocationNotes_impl "$@"
}

# Validates comprehensive CSV file structure and content.
# This function performs detailed validation of CSV files before database load,
# including column count, quote escaping, multivalue fields, and data integrity.
#
# Parameters:
#   $1 - CSV file path
#   $2 - File type (notes, comments, text)
#
# Validations performed:
#   - File exists and is readable
#   - Correct number of columns per file type
#   - Properly escaped quotes (PostgreSQL CSV format)
#   - No unescaped delimiters in text fields
#   - Multivalue fields are properly formatted
#   - No malformed lines
#
# Returns:
#   0 if all validations pass
#   1 if any validation fails
#
# Example:
#   __validate_csv_structure "output-notes.csv" "notes"
function __validate_csv_structure {
 __log_start
 local CSV_FILE="${1}"
 local FILE_TYPE="${2}"

 # Validate parameters
 if [[ -z "${CSV_FILE}" ]]; then
  __loge "ERROR: CSV file path parameter is required"
  __log_finish
  return 1
 fi

 if [[ -z "${FILE_TYPE}" ]]; then
  __loge "ERROR: File type parameter is required"
  __log_finish
  return 1
 fi

 # Check file exists
 if [[ ! -f "${CSV_FILE}" ]]; then
  __loge "ERROR: CSV file not found: ${CSV_FILE}"
  __log_finish
  return 1
 fi

 # Check file is readable
 if [[ ! -r "${CSV_FILE}" ]]; then
  __loge "ERROR: CSV file is not readable: ${CSV_FILE}"
  __log_finish
  return 1
 fi

 # Skip validation for empty files
 if [[ ! -s "${CSV_FILE}" ]]; then
  __logw "WARNING: CSV file is empty: ${CSV_FILE}"
  __log_finish
  return 0
 fi

 __logi "Validating CSV structure: ${CSV_FILE} (type: ${FILE_TYPE})"

 # Define expected column counts for each file type
 local EXPECTED_COLUMNS
 case "${FILE_TYPE}" in
 "notes")
  # Structure: note_id,latitude,longitude,created_at,closed_at,status,id_country,part_id
  EXPECTED_COLUMNS=8
  ;;
 "comments")
  # Structure: note_id,sequence_action,event,created_at,id_user,username,part_id
  EXPECTED_COLUMNS=7
  ;;
 "text")
  # Structure: note_id,sequence_action,"body",part_id
  # Note: body is quoted, so comma count may vary, but we expect 3 commas = 4 fields
  EXPECTED_COLUMNS=4
  ;;
 *)
  __logw "WARNING: Unknown file type '${FILE_TYPE}', skipping column count validation"
  __log_finish
  return 0
  ;;
 esac

 # Sample first 100 lines for validation (performance optimization)
 local SAMPLE_SIZE=100
 local TOTAL_LINES
 TOTAL_LINES=$(wc -l < "${CSV_FILE}" 2> /dev/null || echo 0)

 __logd "CSV file has ${TOTAL_LINES} lines, validating first ${SAMPLE_SIZE} lines"

 # Validation counters
 local UNESCAPED_QUOTES=0
 local WRONG_COLUMNS=0
 local LINE_NUMBER=0

 # Read and validate sample lines
 while IFS= read -r line && [[ ${LINE_NUMBER} -lt ${SAMPLE_SIZE} ]]; do
  ((LINE_NUMBER++))

  # Skip empty lines
  if [[ -z "${line}" ]]; then
   continue
  fi

  # Count columns (accounting for quoted fields with commas)
  # For text files, use proper CSV parsing to handle commas inside quoted fields
  local COLUMN_COUNT
  if [[ "${FILE_TYPE}" == "text" ]]; then
   # For text files, parse CSV properly to handle commas inside quoted body field
   # Format: note_id,sequence_action,"body",part_id
   # Count commas that are NOT inside quotes (bash-only, no external dependencies)
   local TEMP_LINE="${line}"
   local IN_QUOTES=0
   local COMMA_COUNT=0
   local CHAR
   while IFS= read -r -n1 CHAR; do
    if [[ "${CHAR}" == '"' ]]; then
     IN_QUOTES=$((1 - IN_QUOTES))
    elif [[ "${CHAR}" == ',' ]] && [[ ${IN_QUOTES} -eq 0 ]]; then
     COMMA_COUNT=$((COMMA_COUNT + 1))
    fi
   done <<< "${TEMP_LINE}"
   COLUMN_COUNT=$((COMMA_COUNT + 1))
  else
   # For notes and comments, use standard field count
   COLUMN_COUNT=$(echo "${line}" | awk -F',' '{print NF}')
  fi

  # Validate exact column count (no longer allowing +/-1)
  if [[ ${COLUMN_COUNT} -ne ${EXPECTED_COLUMNS} ]]; then
   __loge "ERROR: Line ${LINE_NUMBER} has ${COLUMN_COUNT} columns, expected ${EXPECTED_COLUMNS}"
   __loge "This indicates a mismatch between AWK script output and SQL COPY command expectations"
   ((WRONG_COLUMNS++))
   # Only show first 3 examples
   if [[ ${WRONG_COLUMNS} -le 3 ]]; then
    __loge "  Line content (first 200 chars): ${line:0:200}"
   fi
  fi

  # Check for unescaped quotes in text fields
  # In PostgreSQL CSV format, quotes should be doubled: "" not \"
  # Look for patterns like: ," " or ,"text" that might indicate issues
  if [[ "${FILE_TYPE}" == "text" ]]; then
   # Text field can contain quotes, check if they are properly escaped
   # PostgreSQL CSV uses "" to escape quotes inside quoted fields
   # Check for single quotes that aren't at field boundaries
   if echo "${line}" | grep -qE "[^,]'[^,]" 2> /dev/null; then
    # This is actually OK - single quotes are fine in CSV
    :
   fi

   # Check for potential unescaped double quotes (simplified check)
   # Count quotes: should be even (each field starts and ends with quote)
   local QUOTE_COUNT
   # shellcheck disable=SC2312
   # Intentional: tr/wc may fail, default to 0
   QUOTE_COUNT=$(echo "${line}" | tr -cd '"' | wc -c || echo "0")
   if [[ $((QUOTE_COUNT % 2)) -ne 0 ]]; then
    __logd "WARNING: Line ${LINE_NUMBER} has odd number of quotes (${QUOTE_COUNT})"
    ((UNESCAPED_QUOTES++))
    if [[ ${UNESCAPED_QUOTES} -le 3 ]]; then
     __logd "  Line content (first 100 chars): ${line:0:100}"
    fi
   fi
  fi

 done < "${CSV_FILE}"

 # Report validation results
 __logd "CSV validation results for ${CSV_FILE}:"
 __logd "  Total lines checked: ${LINE_NUMBER}"
 __logd "  Wrong column count: ${WRONG_COLUMNS}"
 __logd "  Unescaped quotes: ${UNESCAPED_QUOTES}"

 # Determine if validation passed
 local VALIDATION_FAILED=0

 # Wrong columns is a critical error
 if [[ ${WRONG_COLUMNS} -gt $((LINE_NUMBER / 10)) ]]; then
  __loge "ERROR: Too many lines with wrong column count (${WRONG_COLUMNS} out of ${LINE_NUMBER})"
  __loge "More than 10% of lines have incorrect structure"
  VALIDATION_FAILED=1
 elif [[ ${WRONG_COLUMNS} -gt 0 ]]; then
  __logw "WARNING: Found ${WRONG_COLUMNS} lines with unexpected column count (may be OK if multivalue fields)"
 fi

 # Unescaped quotes is a warning, not critical (might be false positives)
 if [[ ${UNESCAPED_QUOTES} -gt 0 ]]; then
  __logw "WARNING: Found ${UNESCAPED_QUOTES} lines with potential quote issues"
  __logw "This may cause PostgreSQL COPY errors. Review the CSV if load fails."
 fi

 if [[ ${VALIDATION_FAILED} -eq 1 ]]; then
  __loge "CSV structure validation FAILED for ${CSV_FILE}"
  __log_finish
  return 1
 fi

 __logi "✓ CSV structure validation PASSED for ${CSV_FILE}"
 __log_finish
 return 0
}

# Validate CSV file for enum compatibility before database loading
# Parameters:
#   $1 - CSV file path
#   $2 - File type (notes, comments, text)
# Returns:
#   0 if validation passes, 1 if validation fails
function __validate_csv_for_enum_compatibility {
 __log_start
 local CSV_FILE="${1}"
 local FILE_TYPE="${2}"

 if [[ ! -f "${CSV_FILE}" ]]; then
  __loge "ERROR: CSV file not found: ${CSV_FILE}"
  __log_finish
  return 1
 fi

 __logd "Validating CSV file for enum compatibility: ${CSV_FILE} (${FILE_TYPE})"

 case "${FILE_TYPE}" in
 "comments")
  # Validate comment events against note_event_enum
  local INVALID_LINES=0
  local LINE_NUMBER=0

  while IFS= read -r line; do
   ((LINE_NUMBER++))

   # Skip empty lines
   if [[ -z "${line}" ]]; then
    continue
   fi

   # Extract event value (3rd field)
   local EVENT
   # shellcheck disable=SC2312
   # Intentional: cut/tr may fail, default to empty string
   EVENT=$(echo "${line}" | cut -d',' -f3 | tr -d '"' 2> /dev/null || echo "")

   # Check if event is empty or invalid
   if [[ -z "${EVENT}" ]]; then
    __logw "WARNING: Empty event value found in line ${LINE_NUMBER}: ${line}"
    ((INVALID_LINES++))
   elif [[ ! "${EVENT}" =~ ^(opened|closed|reopened|commented|hidden)$ ]]; then
    __logw "WARNING: Invalid event value '${EVENT}' found in line ${LINE_NUMBER}: ${line}"
    ((INVALID_LINES++))
   fi
  done < "${CSV_FILE}"

  if [[ "${INVALID_LINES}" -gt 0 ]]; then
   __loge "ERROR: Found ${INVALID_LINES} lines with invalid event values in ${CSV_FILE}"
   __log_finish
   return 1
  fi
  ;;

 "notes")
  # Validate note status against note_status_enum
  # CSV order: note_id,latitude,longitude,created_at,status,closed_at,id_country,part_id
  # Status is in the 5th field (after created_at)
  local INVALID_LINES=0
  local LINE_NUMBER=0

  while IFS= read -r line; do
   ((LINE_NUMBER++))

   # Skip empty lines
   if [[ -z "${line}" ]]; then
    continue
   fi

   # Extract status value (5th field)
   local STATUS
   # shellcheck disable=SC2312
   # Intentional: cut/tr may fail, default to empty string
   STATUS=$(echo "${line}" | cut -d',' -f5 | tr -d '"' 2> /dev/null || echo "")

   # Check if status is empty or invalid (status can be empty for open notes)
   if [[ -n "${STATUS}" ]] && [[ ! "${STATUS}" =~ ^(open|close|hidden)$ ]]; then
    __logw "WARNING: Invalid status value '${STATUS}' found in line ${LINE_NUMBER}: ${line}"
    ((INVALID_LINES++))
   fi
  done < "${CSV_FILE}"

  if [[ "${INVALID_LINES}" -gt 0 ]]; then
   __loge "ERROR: Found ${INVALID_LINES} lines with invalid status values in ${CSV_FILE}"
   __log_finish
   return 1
  fi
  ;;

 *)
  __logw "WARNING: Unknown file type '${FILE_TYPE}', skipping enum validation"
  __log_finish
  return 0
  ;;
 esac

 __logd "CSV enum validation passed for ${CSV_FILE}"
 __log_finish
 return 0
}

# Show help function
function __show_help() {
 echo "OSM-Notes-profile - Common Functions"
 echo "This file serves as the main entry point for all common functions."
 echo
 echo "Usage: source bin/lib/functionsProcess.sh"
 echo
 echo "This file loads the following function modules:"
 echo "  - commonFunctions.sh      - Common functions and error codes"
 echo "  - validationFunctions.sh  - Validation functions"
 echo "  - errorHandlingFunctions.sh - Error handling and retry functions"
 echo "  - processAPIFunctions.sh  - API processing functions"
 echo "  - processPlanetFunctions.sh - Planet processing functions"
 echo
 echo "Available functions (defined in various source files):"
 echo "  - __checkPrereqsCommands  - Check prerequisites"
 echo "  - __createFunctionToGetCountry - Create country function"
 echo "  - __createProcedures      - Create procedures"
 echo "  - __organizeAreas         - Organize areas"
 echo "  - __getLocationNotes      - Get location notes"
 echo
 echo "Author: Andres Gomez (AngocA)"
 echo "Version: ${VERSION}"
 exit 1
}

# Enhanced XML validation with error handling
# Function is defined in lib/osm-common/consolidatedValidationFunctions.sh
# Stub function to prevent undefined function errors
function __validate_xml_with_enhanced_error_handling() {
 __loge "ERROR: consolidatedValidationFunctions.sh must be loaded before calling this function"
 return 1
}

# Basic XML structure validation (lightweight)
# Function is defined in lib/osm-common/consolidatedValidationFunctions.sh
function __validate_xml_basic() {
 __loge "ERROR: consolidatedValidationFunctions.sh must be loaded before calling this function"
 return 1
}

# XML structure-only validation (very lightweight)
# Function is defined in lib/osm-common/consolidatedValidationFunctions.sh
function __validate_xml_structure_only() {
 __loge "ERROR: consolidatedValidationFunctions.sh must be loaded before calling this function"
 return 1
}
