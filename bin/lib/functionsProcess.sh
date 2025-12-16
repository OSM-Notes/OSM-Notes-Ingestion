#!/bin/bash

# OSM-Notes-profile - Common Functions
# This file serves as the main entry point for all common functions.
# It loads all function modules for use across the project.
#
# Author: Andres Gomez (AngocA)
# Version: 2025-12-07
VERSION="2025-12-07"

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
# Parameters:
#  $1 - operation_command
#  $2 - max_retries (defaults to OVERPASS_RETRIES_PER_ENDPOINT or 7)
#  $3 - base_delay (defaults to OVERPASS_BACKOFF_SECONDS or 20)
#  $4 - cleanup_command (optional)
#  $5 - smart_wait flag (true/false)
#  $6 - explicit Overpass endpoint for smart wait (optional)
# Returns:
#  0 on success, 1 on failure after retries.
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
  STATUS_PROBE=$(__check_overpass_status 2> /dev/null || echo "0")
  set -e
  __logd "Overpass status probe returned: ${STATUS_PROBE}"

  __cleanup_slot() {
   __release_download_slot > /dev/null 2>&1 || true
  }
  trap '__cleanup_slot' EXIT INT TERM
 fi

 while [[ ${RETRY_COUNT} -lt ${MAX_RETRIES_LOCAL} ]]; do
  if eval "${OPERATION_COMMAND}"; then
   __logd "File operation succeeded on attempt $((RETRY_COUNT + 1))"
   if [[ "${SMART_WAIT}" == "true" ]] && [[ -n "${EFFECTIVE_OVERPASS_FOR_WAIT}" ]]; then
    __release_download_slot > /dev/null 2>&1 || true
   fi
   trap - EXIT INT TERM
   __log_finish
   return 0
  else
   if [[ "${OPERATION_COMMAND}" == *"/api/interpreter"* ]]; then
    __logw "Overpass API call failed on attempt $((RETRY_COUNT + 1))"
    if [[ -f "${OUTPUT_OVERPASS:-}" ]]; then
     local ERROR_LINE
     ERROR_LINE=$(grep -i "error" "${OUTPUT_OVERPASS}" | head -1 || echo "")
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

 AVAILABLE_SLOTS=$(echo "${STATUS_OUTPUT}" | grep -o '[0-9]* slots available now' | head -1 | grep -o '[0-9]*' || echo "0")

 if [[ -n "${AVAILABLE_SLOTS}" ]] && [[ "${AVAILABLE_SLOTS}" -gt 0 ]]; then
  __logd "Overpass API has ${AVAILABLE_SLOTS} slot(s) available now"
  __log_finish
  echo "0"
  return 0
 fi

 local ALL_WAIT_TIMES
 ALL_WAIT_TIMES=$(echo "${STATUS_OUTPUT}" | grep -o 'in [0-9]* seconds' | grep -o '[0-9]*' || echo "")

 if [[ -n "${ALL_WAIT_TIMES}" ]]; then
  WAIT_TIME=$(echo "${ALL_WAIT_TIMES}" | sort -n | head -1)
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
 declare -r POSTGRES_11_CHECK_BASE_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_11_checkBaseTables.sql"
fi
if ! declare -p POSTGRES_11_CHECK_HISTORICAL_DATA > /dev/null 2>&1; then
 declare -r POSTGRES_11_CHECK_HISTORICAL_DATA="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_11_checkHistoricalData.sql"
fi
if ! declare -p POSTGRES_12_DROP_GENERIC_OBJECTS > /dev/null 2>&1; then
 declare -r POSTGRES_12_DROP_GENERIC_OBJECTS="${SCRIPT_BASE_DIRECTORY}/sql/consolidated_cleanup.sql"
fi
if ! declare -p POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY > /dev/null 2>&1; then
 declare -r POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_21_createFunctionToGetCountry.sql"
fi
if ! declare -p POSTGRES_22_CREATE_PROC_INSERT_NOTE > /dev/null 2>&1; then
 declare -r POSTGRES_22_CREATE_PROC_INSERT_NOTE="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_22_createProcedure_insertNote.sql"
fi
if ! declare -p POSTGRES_23_CREATE_PROC_INSERT_NOTE_COMMENT > /dev/null 2>&1; then
 declare -r POSTGRES_23_CREATE_PROC_INSERT_NOTE_COMMENT="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_23_createProcedure_insertNoteComment.sql"
fi
if ! declare -p POSTGRES_31_ORGANIZE_AREAS > /dev/null 2>&1; then
 declare -r POSTGRES_31_ORGANIZE_AREAS="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_31_organizeAreas.sql"
fi
if ! declare -p POSTGRES_32_UPLOAD_NOTE_LOCATION > /dev/null 2>&1; then
 declare -r POSTGRES_32_UPLOAD_NOTE_LOCATION="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_32_loadsBackupNoteLocation.sql"
fi
if ! declare -p POSTGRES_33_VERIFY_NOTE_INTEGRITY > /dev/null 2>&1; then
 declare -r POSTGRES_33_VERIFY_NOTE_INTEGRITY="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_33_verifyNoteIntegrity.sql"
fi
if ! declare -p POSTGRES_36_REASSIGN_AFFECTED_NOTES > /dev/null 2>&1; then
 declare -r POSTGRES_36_REASSIGN_AFFECTED_NOTES="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_36_reassignAffectedNotes.sql"
fi
if ! declare -p POSTGRES_37_ASSIGN_COUNTRY_TO_NOTES_CHUNK > /dev/null 2>&1; then
 declare -r POSTGRES_37_ASSIGN_COUNTRY_TO_NOTES_CHUNK="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_37_assignCountryToNotesChunk.sql"
fi
if ! declare -p POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY_STUB > /dev/null 2>&1; then
 declare -r POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY_STUB="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_21_createFunctionToGetCountry_stub.sql"
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
 declare -r DEFAULT_NOTE_LOCATION_DATA_REPO_URL="${DEFAULT_NOTE_LOCATION_DATA_REPO_URL:-https://raw.githubusercontent.com/OSMLatam/OSM-Notes-Data/main/data}"
fi

# ogr2ogr GeoJSON test file.
# Only set if not already declared (e.g., when sourced from another script)
if ! declare -p GEOJSON_TEST > /dev/null 2>&1; then
 declare -r GEOJSON_TEST="${SCRIPT_BASE_DIRECTORY}/json/map.geojson"
fi

###########
# FUNCTIONS

### Note Location Backup Resolution

# Resolves note location backup file, downloading from GitHub if not found locally.
# Similar to __resolve_geojson_file but for noteLocation.csv.zip
# Sets CSV_BACKUP_NOTE_LOCATION_COMPRESSED to the resolved file path.
function __resolve_note_location_backup() {
 __log_start
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
  if ! xmllint --noout "${XML_FILE}" > /dev/null 2>&1; then
   # Check if it's a severe structural issue (missing closing tags, etc.)
   if grep -q "<note" "${XML_FILE}" 2> /dev/null && ! grep -q "</note>" "${XML_FILE}" 2> /dev/null; then
    __loge "Severe XML structural issue in file: ${XML_FILE}"
    TOTAL_NOTES=0
    export TOTAL_NOTES
    __log_finish
    return 1
   else
    __logw "XML structure validation failed for file: ${XML_FILE}, but continuing with counting"
   fi
  fi
 fi

 # Count notes using grep (fast and reliable)
 # Clean output immediately to avoid newline issues
 TOTAL_NOTES=$(grep -c '<note ' "${XML_FILE}" 2> /dev/null | tr -d '[:space:]' || echo "0")
 local GREP_STATUS=$?

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
 TOTAL_NOTES=$(printf '%s' "${TOTAL_NOTES}" | tr -d '[:space:]' | head -1 || echo "0")

 # Ensure it's numeric, default to 0 if not
 if [[ -z "${TOTAL_NOTES}" ]] || [[ ! "${TOTAL_NOTES}" =~ ^[0-9]+$ ]]; then
  __loge "Invalid or empty note count returned by grep: '${TOTAL_NOTES}'"
  TOTAL_NOTES=0
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

# Counts notes in XML file (Planet format)
# Parameters:
#   $1: Input XML file path
# Returns:
#   TOTAL_NOTES: Number of notes found (exported variable)
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
 PART_NUM=$(echo "${BASENAME_PART}" | sed 's/.*_part_//' | sed 's/^0*//')

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
 __logd "  Notes: ${OUTPUT_NOTES_PART} ($(wc -l < "${OUTPUT_NOTES_PART}" || echo 0) lines)" || true
 __logd "  Comments: ${OUTPUT_COMMENTS_PART} ($(wc -l < "${OUTPUT_COMMENTS_PART}" || echo 0) lines)" || true
 __logd "  Text: ${OUTPUT_TEXT_PART} ($(wc -l < "${OUTPUT_TEXT_PART}" || echo 0) lines)" || true

 # Validate CSV files structure and content before loading
 __logd "Validating CSV files structure and enum compatibility..."

 # Validate structure first
 if ! __validate_csv_structure "${OUTPUT_NOTES_PART}" "notes"; then
  __loge "ERROR: Notes CSV structure validation failed for part ${PART_NUM}"
  __log_finish
  return 1
 fi

 # Then validate enum values
 if ! __validate_csv_for_enum_compatibility "${OUTPUT_NOTES_PART}" "notes"; then
  __loge "ERROR: Notes CSV enum validation failed for part ${PART_NUM}"
  __log_finish
  return 1
 fi

 # Validate comments structure
 if ! __validate_csv_structure "${OUTPUT_COMMENTS_PART}" "comments"; then
  __loge "ERROR: Comments CSV structure validation failed for part ${PART_NUM}"
  __log_finish
  return 1
 fi

 # Validate comments enum
 if ! __validate_csv_for_enum_compatibility "${OUTPUT_COMMENTS_PART}" "comments"; then
  __loge "ERROR: Comments CSV enum validation failed for part ${PART_NUM}"
  __log_finish
  return 1
 fi

 # Validate text structure (most prone to quote/escape issues)
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
 # shellcheck disable=SC2016
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -c "SET app.part_id = '${PART_NUM}'; SET app.max_threads = '${MAX_THREADS}';"
 # shellcheck disable=SC2154
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -c "$(envsubst '$OUTPUT_NOTES_PART,$OUTPUT_COMMENTS_PART,$OUTPUT_TEXT_PART,$PART_ID' \
   < "${POSTGRES_31_LOAD_API_NOTES}" || true)"

 __logi "=== API XML PART ${PART_NUM} PROCESSING COMPLETED SUCCESSFULLY ==="
 __log_finish
 __log_finish
}

# Processes a single XML part for Planet notes using AWK extraction
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
 PART_NUM=$(echo "${BASENAME_PART}" | sed 's/.*_part_//' | sed 's/^0*//')

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
 __logd "  Notes: ${OUTPUT_NOTES_PART} ($(wc -l < "${OUTPUT_NOTES_PART}" || echo 0) lines)"
 __logd "  Comments: ${OUTPUT_COMMENTS_PART} ($(wc -l < "${OUTPUT_COMMENTS_PART}" || echo 0) lines)"
 __logd "  Text: ${OUTPUT_TEXT_PART} ($(wc -l < "${OUTPUT_TEXT_PART}" || echo 0) lines)"

 # Load into database with partition ID and MAX_THREADS
 __logi "=== LOADING PART ${PART_NUM} INTO DATABASE ==="
 __logd "Database: ${DBNAME}"
 __logd "Partition ID: ${PART_NUM}"
 __logd "Max threads: ${MAX_THREADS}"
 __logd "Notes CSV: ${OUTPUT_NOTES_PART}"
 __logd "Comments CSV: ${OUTPUT_COMMENTS_PART}"
 __logd "Text CSV: ${OUTPUT_TEXT_PART}"
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

# Validates JSON file structure and contains expected element
# Parameters:
#   $1: JSON file path
#   $2: Expected element name (e.g., "elements" for OSM JSON, "features" for GeoJSON)
# Returns:
#   0 if valid and contains expected element, 1 if invalid or missing element
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

 if ! psql -lqt 2> /dev/null | cut -d \| -f 1 | grep -qw "${DBNAME}"; then
  __loge "ERROR: Database '${DBNAME}' does not exist."
  __loge "To create the database, run the following commands:"
  __loge "  createdb ${DBNAME}"
  __loge "  psql -d ${DBNAME} -c 'CREATE EXTENSION postgis;'"
  __loge "  psql -d ${DBNAME} -c 'CREATE EXTENSION btree_gist;'"
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
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Aria2c
 __logd "Checking aria2c."
 if ! aria2c --version > /dev/null 2>&1; then
  __loge "ERROR: Aria2c is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## jq (required for JSON/GeoJSON validation)
 __logd "Checking jq."
 if ! jq --version > /dev/null 2>&1; then
  __loge "ERROR: jq is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## osmtogeojson
 __logd "Checking osmtogeojson."
 if ! osmtogeojson --version > /dev/null 2>&1; then
  __loge "ERROR: osmtogeojson is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## JSON validator
 __logd "Checking ajv."
 if ! ajv help > /dev/null 2>&1; then
  __loge "ERROR: ajv is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## gdal ogr2ogr
 __logd "Checking ogr2ogr."
 if ! ogr2ogr --version > /dev/null 2>&1; then
  __loge "ERROR: ogr2ogr is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 ## flock
 __logd "Checking flock."
 if ! flock --version > /dev/null 2>&1; then
  __loge "ERROR: flock is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Mutt
 __logd "Checking mutt."
 if ! mutt -v > /dev/null 2>&1; then
  __loge "ERROR: mutt is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 # Verify mutt has SMTP support compiled in
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
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## XML lint (optional, only for strict validation)
 if [[ "${SKIP_XML_VALIDATION}" != "true" ]]; then
  __logd "Checking XML lint."
  if ! xmllint --version > /dev/null 2>&1; then
   __loge "ERROR: XMLlint is missing (required for XML validation)."
   __loge "To skip validation, set: export SKIP_XML_VALIDATION=true"
   exit "${ERROR_MISSING_LIBRARY}"
  fi
 fi

 ## Bash 4 or greater.
 __logd "Checking Bash version."
 if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  __loge "ERROR: Requires Bash 4+."
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 __logd "Checking files."
 # Resolve note location backup file (download from GitHub if not found locally)
 # Note: __resolve_note_location_backup is defined earlier in this file
 if declare -f __resolve_note_location_backup > /dev/null 2>&1; then
  if ! __resolve_note_location_backup; then
   __logw "Warning: Failed to resolve note location backup file. Will continue without backup."
  fi
 fi
 if [[ ! -r "${CSV_BACKUP_NOTE_LOCATION_COMPRESSED}" ]]; then
  __logw "Warning: Backup file is missing at ${CSV_BACKUP_NOTE_LOCATION_COMPRESSED}. Processing will continue without backup (slower)."
 fi
 if [[ ! -r "${POSTGRES_32_UPLOAD_NOTE_LOCATION}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_32_UPLOAD_NOTE_LOCATION}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_33_VERIFY_NOTE_INTEGRITY}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_33_VERIFY_NOTE_INTEGRITY}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_36_REASSIGN_AFFECTED_NOTES}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_36_REASSIGN_AFFECTED_NOTES}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_37_ASSIGN_COUNTRY_TO_NOTES_CHUNK}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_37_ASSIGN_COUNTRY_TO_NOTES_CHUNK}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY_STUB}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY_STUB}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 # XML Schema file (only required if validation is enabled)
 if [[ "${SKIP_XML_VALIDATION}" != "true" ]]; then
  if [[ ! -r "${XMLSCHEMA_PLANET_NOTES}" ]]; then
   __loge "ERROR: XML schema file is missing at ${XMLSCHEMA_PLANET_NOTES}."
   __loge "To skip validation, set: export SKIP_XML_VALIDATION=true"
   exit "${ERROR_MISSING_LIBRARY}"
  fi
 fi
 if [[ ! -r "${JSON_SCHEMA_OVERPASS}" ]]; then
  __loge "ERROR: File is missing at ${JSON_SCHEMA_OVERPASS}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${JSON_SCHEMA_GEOJSON}" ]]; then
  __loge "ERROR: File is missing at ${JSON_SCHEMA_GEOJSON}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${GEOJSON_TEST}" ]]; then
  __loge "ERROR: File is missing at ${GEOJSON_TEST}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 ## ogr2ogr import without password
 __logd "Checking ogr2ogr import into postgres without password."
 # shellcheck disable=SC2154
 if ! ogr2ogr -f "PostgreSQL" PG:"dbname=${DBNAME} user=${DB_USER}" \
  "${GEOJSON_TEST}" -nln import -overwrite; then
  __loge "ERROR: ogr2ogr cannot access the database '${DBNAME}' with user '${DB_USER}'."
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 ## Network connectivity and external service access
 __logd "Checking network connectivity and external service access."

 # Check internet connectivity
 if ! __check_network_connectivity 10; then
  __loge "ERROR: Internet connectivity check failed."
  __loge "The system cannot access the internet, which is required for OSM data downloads."
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
 if ! timeout 15 curl -s --max-time 15 "${API_VERSIONS_URL}" > "${TEMP_API_RESPONSE}" 2>/dev/null; then
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
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Checks postgres scripts.
 if [[ ! -r "${POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Checks postgres scripts.
 if [[ ! -r "${POSTGRES_22_CREATE_PROC_INSERT_NOTE}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_22_CREATE_PROC_INSERT_NOTE}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Checks postgres scripts.
 if [[ ! -r "${POSTGRES_23_CREATE_PROC_INSERT_NOTE_COMMENT}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_23_CREATE_PROC_INSERT_NOTE_COMMENT}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Checks postgres scripts.
 if [[ ! -r "${POSTGRES_31_ORGANIZE_AREAS}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_31_ORGANIZE_AREAS}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 __log_finish
}

# Checks the base tables if exist.
# Returns: 0 if all base tables exist, non-zero if tables are missing or error occurs
# Distinguishes between "tables missing" (should run --base) vs "connection/other errors"
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
# Returns:
#   0 if enough space is available
#   1 if insufficient space
#
# Example:
#   __check_disk_space "/tmp" "15.5" "Planet download"
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
 AVAILABLE_MB=$(df -BM "${DIRECTORY}" | awk 'NR==2 {print $4}' | sed 's/M//')

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
  REQUIRED_MB=$(echo "${REQUIRED_GB} * 1024" | bc | cut -d. -f1)
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
 if (($(echo "${USAGE_PERCENT} > 80" | bc -l 2> /dev/null || echo 0))); then
  __logw "WARNING: Operation will use ${USAGE_PERCENT}% of available disk space"
  __logw "Consider freeing up more space for safety margin"
 else
  __logi "✓ Sufficient disk space available (${USAGE_PERCENT}% will be used)"
 fi

 __log_finish
 return 0
}

# Downloads the notes from the planet.
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
 if ! __check_disk_space "${TMP_DIR}" "20" "Planet notes download and processing"; then
  __loge "Cannot proceed with Planet download due to insufficient disk space"
  __handle_error_with_cleanup "${ERROR_GENERAL}" "Insufficient disk space for Planet download" \
   "echo 'No cleanup needed - download not started'"
 fi

 # Check network connectivity before proceeding
 __logi "Checking network connectivity..."
 if ! __check_network_connectivity 15; then
  __loge "Network connectivity check failed"
  __handle_error_with_cleanup "${ERROR_INTERNET_ISSUE}" "Network connectivity failed" \
   "rm -f ${PLANET_NOTES_FILE}.bz2 ${PLANET_NOTES_FILE}.bz2.md5 2>/dev/null || true"
 fi

 # Download Planet notes with retry logic
 __logw "Retrieving Planet notes file..."
 local DOWNLOAD_OPERATION="aria2c -d ${TMP_DIR} -o ${PLANET_NOTES_NAME}.bz2 -x 8 ${PLANET}/notes/${PLANET_NOTES_NAME}.bz2"
 local DOWNLOAD_CLEANUP="rm -f ${TMP_DIR}/${PLANET_NOTES_NAME}.bz2 2>/dev/null || true"

 if ! __retry_file_operation "${DOWNLOAD_OPERATION}" 3 10 "${DOWNLOAD_CLEANUP}"; then
  __loge "Failed to download Planet notes after retries"
  __handle_error_with_cleanup "${ERROR_DOWNLOADING_NOTES}" "Planet download failed" \
   "rm -f ${TMP_DIR}/${PLANET_NOTES_NAME}.bz2 2>/dev/null || true"
 fi

 # Move downloaded file to expected location
 if [[ -f "${TMP_DIR}/${PLANET_NOTES_NAME}.bz2" ]]; then
  mv "${TMP_DIR}/${PLANET_NOTES_NAME}.bz2" "${PLANET_NOTES_FILE}.bz2"
  __logi "Moved downloaded file to expected location: ${PLANET_NOTES_FILE}.bz2"
 else
  __loge "ERROR: Downloaded file not found at expected location"
  __handle_error_with_cleanup "${ERROR_DOWNLOADING_NOTES}" "Downloaded file not found" \
   "rm -f ${TMP_DIR}/${PLANET_NOTES_NAME}.bz2 2>/dev/null || true"
 fi

 # Download MD5 file with retry logic
 local MD5_OPERATION="curl -s -H \"User-Agent: ${DOWNLOAD_USER_AGENT:-OSM-Notes-Ingestion/1.0}\" -o ${PLANET_NOTES_FILE}.bz2.md5 ${PLANET}/notes/${PLANET_NOTES_NAME}.bz2.md5"
 local MD5_CLEANUP="rm -f ${PLANET_NOTES_FILE}.bz2.md5 2>/dev/null || true"

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

 # Verify file exists before extraction
 if [[ ! -f "${BZIP2_FILE}" ]]; then
  __loge "ERROR: Compressed file not found: ${BZIP2_FILE}"
  __handle_error_with_cleanup "${ERROR_DOWNLOADING_NOTES}" "Compressed file not found" \
   "rm -f \"${BZIP2_FILE}\" \"${PLANET_NOTES_FILE}\" 2>/dev/null || true"
 fi

 # Execute bzip2 extraction
 # Use set +e to prevent script exit on bzip2 errors
 # We verify success by checking if the XML file exists, not by exit code
 set +e
 { bzip2 -d "${BZIP2_FILE}"; } > /dev/null 2>&1
 set -e

 # Check if extraction was successful by verifying the XML file exists
 # bzip2 may return non-zero if file was already extracted, but that's OK
 if [[ ! -f "${PLANET_NOTES_FILE}" ]]; then
  __loge "ERROR: Extracted file not found: ${PLANET_NOTES_FILE}"
  __handle_error_with_cleanup "${ERROR_DOWNLOADING_NOTES}" "Extracted file not found" \
   "rm -f \"${BZIP2_FILE}\" \"${PLANET_NOTES_FILE}\" 2>/dev/null || true"
 fi

 __logi "Successfully extracted Planet notes: \"${PLANET_NOTES_FILE}\""

 __log_finish
}

# Creates a function that performs basic triage according to longitude:
# * -180 - -30: Americas.
# * -30 - 25: West Europe and West Africa.
# * 25 - 65: Middle East, East Africa and Russia.
# * 65 - 180: Southeast Asia and Oceania.
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
  PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY_STUB}" || true
  __log_finish
  return 0
 fi

 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY}"
 __log_finish
}

# Creates procedures to insert notes and comments.
function __createProcedures {
 __log_start
 __logd "Creating procedures."

 # Validate that POSTGRES_22_CREATE_PROC_INSERT_NOTE is defined
 if [[ -z "${POSTGRES_22_CREATE_PROC_INSERT_NOTE:-}" ]]; then
  __loge "ERROR: POSTGRES_22_CREATE_PROC_INSERT_NOTE variable is not defined. This variable should be defined in the calling script"
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 # Validate that POSTGRES_23_CREATE_PROC_INSERT_NOTE_COMMENT is defined
 if [[ -z "${POSTGRES_23_CREATE_PROC_INSERT_NOTE_COMMENT:-}" ]]; then
  __loge "ERROR: POSTGRES_23_CREATE_PROC_INSERT_NOTE_COMMENT variable is not defined. This variable should be defined in the calling script"
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 # Validate that the SQL files exist
 if [[ ! -f "${POSTGRES_22_CREATE_PROC_INSERT_NOTE}" ]]; then
  __loge "ERROR: SQL file not found: ${POSTGRES_22_CREATE_PROC_INSERT_NOTE}"
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 if [[ ! -f "${POSTGRES_23_CREATE_PROC_INSERT_NOTE_COMMENT}" ]]; then
  __loge "ERROR: SQL file not found: ${POSTGRES_23_CREATE_PROC_INSERT_NOTE_COMMENT}"
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

# Assigns a value to each area to find it easily.
# This function organizes countries into geographic areas for efficient
# country lookup. It requires the countries table to exist and have data.
function __organizeAreas {
 __log_start
 __logd "Organizing areas."

 # Validate that POSTGRES_31_ORGANIZE_AREAS is defined
 if [[ -z "${POSTGRES_31_ORGANIZE_AREAS:-}" ]]; then
  __loge "ERROR: POSTGRES_31_ORGANIZE_AREAS variable is not defined"
  __loge "ERROR: This variable should be defined in the calling script"
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 # Validate that the SQL file exists
 if [[ ! -f "${POSTGRES_31_ORGANIZE_AREAS}" ]]; then
  __loge "ERROR: SQL file not found: ${POSTGRES_31_ORGANIZE_AREAS}"
  exit "${ERROR_MISSING_LIBRARY}"
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
}

# Processes a specific boundary ID.
# Parameters:
#   $1: Query file path (optional, uses global QUERY_FILE if not provided)
function __processBoundary {
 __processBoundary_impl "$@"
}

# Download using Overpass with fallback across multiple endpoints and validate JSON
# Parameters:
#   $1: Query file path
#   $2: Output JSON file path
#   $3: Output capture/stderr file for Overpass tool (used by retry function)
#   $4: Max retries used by underlying retry function
#   $5: Base delay used by underlying retry function
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
  if __retry_file_operation "${OP}" "${LOCAL_MAX_RETRIES}" "${LOCAL_BASE_DELAY}" "${CL}" "true" "${ACTIVE_OVERPASS}"; then
   __logd "Download succeeded from endpoint=${ENDPOINT}"
   # Validate JSON has elements key
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
   QUOTE_COUNT=$(echo "${line}" | tr -cd '"' | wc -c)
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
   EVENT=$(echo "${line}" | cut -d',' -f3 | tr -d '"' 2> /dev/null)

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
   STATUS=$(echo "${line}" | cut -d',' -f5 | tr -d '"' 2> /dev/null)

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
