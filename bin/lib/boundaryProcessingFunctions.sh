#!/bin/bash

# Boundary Processing Functions for OSM-Notes-profile
# Author: Andres Gomez (AngocA)
# Version: 2025-12-05
VERSION="2025-12-05"

# Directory lock for ogr2ogr imports
declare -r LOCK_OGR2OGR="/tmp/ogr2ogr.lock"

# Overpass query templates
declare -r OVERPASS_COUNTRIES="${SCRIPT_BASE_DIRECTORY}/overpass/countries.op"
declare -r OVERPASS_MARITIMES="${SCRIPT_BASE_DIRECTORY}/overpass/maritimes.op"

# shellcheck disable=SC2317,SC2155,SC2034

# Ensure logging and error handling helpers exist
if ! declare -f __log_start > /dev/null 2>&1; then
 if [[ -f "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/commonFunctions.sh" ]]; then
  # shellcheck disable=SC1091
  source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/commonFunctions.sh"
 fi
fi

if ! declare -f __handle_error_with_cleanup > /dev/null 2>&1; then
 if [[ -f "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/errorHandlingFunctions.sh" ]]; then
  # shellcheck disable=SC1091
  source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/errorHandlingFunctions.sh"
 fi
fi

# Ensure Overpass helpers are available
if ! declare -f __log_overpass_attempt > /dev/null 2>&1; then
 if [[ -f "${SCRIPT_BASE_DIRECTORY}/bin/lib/overpassFunctions.sh" ]]; then
  # shellcheck disable=SC1091
  source "${SCRIPT_BASE_DIRECTORY}/bin/lib/overpassFunctions.sh"
 fi
fi

# ---------------------------------------------------------------------------
# Boundary logging helpers (previously inline in __processBoundary)
# ---------------------------------------------------------------------------

function __log_download_start() {
 local BOUNDARY_ID="${1}"
 local TOTAL="${2}"
 __logi "Starting download attempts for boundary ${BOUNDARY_ID} (max retries: ${TOTAL}, CONTINUE_ON_OVERPASS_ERROR: ${CONTINUE_ON_OVERPASS_ERROR:-false})"
}

function __log_json_validation_failure() {
 local BOUNDARY_ID="${1}"
 __loge "JSON validation failed for boundary ${BOUNDARY_ID} - will retry download"
}

function __log_download_success() {
 local BOUNDARY_ID="${1}"
 local TOTAL_TIME="${2}"
 __logi "Download and validation completed successfully for boundary ${BOUNDARY_ID} (total time: ${TOTAL_TIME}s)"
}

function __log_geojson_conversion_start() {
 local BOUNDARY_ID="${1}"
 local MAX_RETRIES="${2}"
 __logi "Converting into GeoJSON for boundary ${BOUNDARY_ID} with validation and retry logic (max retries: ${MAX_RETRIES})..."
}

function __log_geojson_retry_delay() {
 local BOUNDARY_ID="${1}"
 local DELAY="${2}"
 local ATTEMPT="${3}"
 __logw "Waiting ${DELAY}s before GeoJSON retry attempt ${ATTEMPT} for boundary ${BOUNDARY_ID}..."
}

function __log_import_start() {
 local BOUNDARY_ID="${1}"
 __logi "Importing into Postgres for boundary ${BOUNDARY_ID}."
}

# ---------------------------------------------------------------------------
# GeoJSON file handling helpers
# ---------------------------------------------------------------------------

# Resolves a GeoJSON file path, handling compressed files (.geojson.gz)
# If a .geojson.gz file exists, it will be decompressed to a temporary
# location and the path to the decompressed file will be returned.
# Parameters:
#   $1: Base path (without extension) or full path to .geojson file
#   $2: (optional) Output variable name for the resolved file path
# Returns:
#   0 if file found and ready, 1 otherwise
# Sets:
#   ${2} (or GEOJSON_RESOLVED_FILE) to the resolved file path
function __resolve_geojson_file() {
 local BASE_PATH="${1}"
 local OUTPUT_VAR="${2:-GEOJSON_RESOLVED_FILE}"
 local RESOLVED_FILE=""

 # If BASE_PATH already has .geojson extension, use it as-is
 if [[ "${BASE_PATH}" == *.geojson ]]; then
  if [[ -f "${BASE_PATH}" ]] && [[ -s "${BASE_PATH}" ]]; then
   RESOLVED_FILE="${BASE_PATH}"
  elif [[ -f "${BASE_PATH}.gz" ]] && [[ -s "${BASE_PATH}.gz" ]]; then
   # Decompress to temporary location
   local TMP_DECOMPRESSED="${TMP_DIR}/$(basename "${BASE_PATH}")"
   if gunzip -c "${BASE_PATH}.gz" > "${TMP_DECOMPRESSED}" 2> /dev/null; then
    RESOLVED_FILE="${TMP_DECOMPRESSED}"
    __logd "Decompressed ${BASE_PATH}.gz to ${RESOLVED_FILE}"
   else
    __loge "Failed to decompress ${BASE_PATH}.gz"
    return 1
   fi
  else
   return 1
  fi
 else
  # Try .geojson first, then .geojson.gz
  if [[ -f "${BASE_PATH}.geojson" ]] && [[ -s "${BASE_PATH}.geojson" ]]; then
   RESOLVED_FILE="${BASE_PATH}.geojson"
  elif [[ -f "${BASE_PATH}.geojson.gz" ]] && [[ -s "${BASE_PATH}.geojson.gz" ]]; then
   # Decompress to temporary location
   local TMP_DECOMPRESSED="${TMP_DIR}/$(basename "${BASE_PATH}.geojson")"
   if gunzip -c "${BASE_PATH}.geojson.gz" > "${TMP_DECOMPRESSED}" 2> /dev/null; then
    RESOLVED_FILE="${TMP_DECOMPRESSED}"
    __logd "Decompressed ${BASE_PATH}.geojson.gz to ${RESOLVED_FILE}"
   else
    __loge "Failed to decompress ${BASE_PATH}.geojson.gz"
    return 1
   fi
  else
   return 1
  fi
 fi

 # Set output variable
 eval "${OUTPUT_VAR}=\"${RESOLVED_FILE}\""
 return 0
}

# ---------------------------------------------------------------------------
# Boundary import helpers
# ---------------------------------------------------------------------------

function __log_field_selected_import() {
 local BOUNDARY_ID="${1}"
 __logd "Using field-selected import for boundary ${BOUNDARY_ID}"
}

function __log_taiwan_special_handling() {
 local BOUNDARY_ID="${1}"
 __logi "Special handling for Taiwan (ID: ${BOUNDARY_ID}) - removing problematic tags"
}

function __log_duplicate_columns_fixed() {
 local BOUNDARY_ID="${1}"
 __logd "Duplicate columns fixed for boundary ${BOUNDARY_ID}"
}

function __log_duplicate_columns_skip() {
 local BOUNDARY_ID="${1}"
 local REASON="${2}"
 __logd "Auto-heal skipped for boundary ${BOUNDARY_ID}: ${REASON}"
}

function __log_process_complete() {
 local BOUNDARY_ID="${1}"
 __logd "Data processing completed for boundary ${BOUNDARY_ID}"
}

function __log_lock_acquired() {
 local BOUNDARY_ID="${1}"
 __logd "Lock acquired for boundary ${BOUNDARY_ID}"
}

function __log_lock_failed() {
 local BOUNDARY_ID="${1}"
 __loge "Failed to acquire lock for boundary ${BOUNDARY_ID}"
}

function __log_import_completed() {
 local BOUNDARY_ID="${1}"
 __logd "Database import completed for boundary ${BOUNDARY_ID}"
}

function __log_no_duplicate_columns() {
 local BOUNDARY_ID="${1}"
 __logd "No duplicate columns detected for boundary ${BOUNDARY_ID}"
}

function __processBoundary_impl {
 __log_start
 __logi "=== STARTING BOUNDARY PROCESSING ==="
 # Use provided query file or fall back to global
 local QUERY_FILE_TO_USE="${1:-${QUERY_FILE}}"
 local RUNNING_UNDER_TEST="false"
 if [[ -n "${BATS_TEST_NAME:-}" ]]; then
  RUNNING_UNDER_TEST="true"
 fi

 # Initialize IS_COMPLEX variable (defaults to false)
 local IS_COMPLEX="${IS_COMPLEX:-false}"

 __logd "Boundary ID: ${ID}"
 __logd "Process ID: ${BASHPID}"
 __logd "JSON file: ${JSON_FILE}"
 __logd "GeoJSON file: ${GEOJSON_FILE}"
 __logd "Query file: ${QUERY_FILE_TO_USE}"
 OUTPUT_OVERPASS="${TMP_DIR}/output.${BASHPID}"

 __logi "Retrieving shape ${ID}."

 # Check network connectivity before proceeding
 if [[ "${RUNNING_UNDER_TEST}" == "true" ]] && [[ "${SKIP_NETWORK_CHECK_FOR_TESTS:-true}" == "true" ]]; then
  __logd "Skipping network connectivity check in test mode (BATS_TEST_NAME detected)"
 elif [[ "${CONTINUE_ON_OVERPASS_ERROR:-false}" == "true" ]] && [[ "${SKIP_NETWORK_CHECK_ON_CONTINUE:-true}" == "true" ]]; then
  __logd "Skipping network connectivity check because CONTINUE_ON_OVERPASS_ERROR=true"
 else
  __logd "Checking network connectivity for boundary ${ID}..."
  if ! __check_network_connectivity 10; then
   __loge "Network connectivity check failed for boundary ${ID}"
   __handle_error_with_cleanup "${ERROR_INTERNET_ISSUE}" "Network connectivity failed for boundary ${ID}" \
    "rm -f ${JSON_FILE} ${GEOJSON_FILE} ${OUTPUT_OVERPASS} 2>/dev/null || true"
   __log_finish
   return 1
  fi
  __logd "Network connectivity confirmed for boundary ${ID}"
 fi

 # Use retry logic for Overpass API calls
 # Default retry settings sourced from properties/environment
 local MAX_RETRIES_LOCAL="${OVERPASS_RETRIES_PER_ENDPOINT:-7}"
 local BASE_DELAY_LOCAL="${OVERPASS_BACKOFF_SECONDS:-20}"
 if [[ "${RUNNING_UNDER_TEST}" == "true" ]]; then
  MAX_RETRIES_LOCAL="${OVERPASS_TEST_MAX_RETRIES:-1}"
  BASE_DELAY_LOCAL="${OVERPASS_TEST_BASE_DELAY:-1}"
 elif [[ "${CONTINUE_ON_OVERPASS_ERROR:-false}" == "true" ]]; then
  MAX_RETRIES_LOCAL="${OVERPASS_CONTINUE_MAX_RETRIES_PER_ENDPOINT:-3}"
  BASE_DELAY_LOCAL="${OVERPASS_CONTINUE_BASE_DELAY:-12}"
 fi

 # Retry logic for download with validation
 # This includes downloading and validating JSON structure
 local DOWNLOAD_VALIDATION_RETRIES=3
 if [[ "${RUNNING_UNDER_TEST}" == "true" ]]; then
  DOWNLOAD_VALIDATION_RETRIES="${OVERPASS_TEST_VALIDATION_RETRIES:-1}"
 elif [[ "${CONTINUE_ON_OVERPASS_ERROR:-false}" == "true" ]]; then
  DOWNLOAD_VALIDATION_RETRIES="${OVERPASS_CONTINUE_VALIDATION_RETRIES:-3}"
 fi
 local DOWNLOAD_VALIDATION_RETRY_COUNT=0
 local DOWNLOAD_SUCCESS=false
 local DOWNLOAD_START_TIME
 DOWNLOAD_START_TIME=$(date +%s)

 __log_download_start "${ID}" "${DOWNLOAD_VALIDATION_RETRIES}"

 while [[ ${DOWNLOAD_VALIDATION_RETRY_COUNT} -lt ${DOWNLOAD_VALIDATION_RETRIES} ]] && [[ "${DOWNLOAD_SUCCESS}" == "false" ]]; do
  local ATTEMPT_NUM=$((DOWNLOAD_VALIDATION_RETRY_COUNT + 1))
  local ELAPSED_TIME
  ELAPSED_TIME=$(($(date +%s) - DOWNLOAD_START_TIME))

  if [[ ${DOWNLOAD_VALIDATION_RETRY_COUNT} -gt 0 ]]; then
   __logw "Retrying download and validation for boundary ${ID} (attempt ${ATTEMPT_NUM}/${DOWNLOAD_VALIDATION_RETRIES}, elapsed: ${ELAPSED_TIME}s)"
   # Clean up previous failed attempt
   rm -f "${JSON_FILE}" "${OUTPUT_OVERPASS}" 2> /dev/null || true
   # Wait before retry with exponential backoff
   # Use BOUNDARY_RETRY_DELAY to avoid conflict with global readonly RETRY_DELAY
   local BOUNDARY_RETRY_DELAY=$((BASE_DELAY_LOCAL * DOWNLOAD_VALIDATION_RETRY_COUNT))
   if [[ "${RUNNING_UNDER_TEST}" == "true" ]]; then
    BOUNDARY_RETRY_DELAY=0
   else
    if [[ ${BOUNDARY_RETRY_DELAY} -gt 60 ]]; then
     BOUNDARY_RETRY_DELAY=60
    fi
    # Reduce delay if CONTINUE_ON_OVERPASS_ERROR is enabled
    if [[ "${CONTINUE_ON_OVERPASS_ERROR:-false}" == "true" ]] && [[ ${BOUNDARY_RETRY_DELAY} -gt 30 ]]; then
     BOUNDARY_RETRY_DELAY=30
     __logd "Reduced retry delay to ${BOUNDARY_RETRY_DELAY}s due to CONTINUE_ON_OVERPASS_ERROR=true"
    fi
   fi
   if [[ ${BOUNDARY_RETRY_DELAY} -gt 0 ]]; then
    __logw "Waiting ${BOUNDARY_RETRY_DELAY}s before retry attempt ${ATTEMPT_NUM} for boundary ${ID}..."
    sleep "${BOUNDARY_RETRY_DELAY}"
   else
    __logd "Skipping retry wait (test mode or zero delay) before attempt ${ATTEMPT_NUM}"
   fi
  else
   __logd "Starting download attempt ${ATTEMPT_NUM}/${DOWNLOAD_VALIDATION_RETRIES} for boundary ${ID}"
  fi

  # Attempt download with fallback among endpoints
  __log_overpass_attempt "${ID}" "${ATTEMPT_NUM}" "${DOWNLOAD_VALIDATION_RETRIES}"
  if ! __overpass_download_with_endpoints "${QUERY_FILE_TO_USE}" "${JSON_FILE}" "${OUTPUT_OVERPASS}" "${MAX_RETRIES_LOCAL}" "${BASE_DELAY_LOCAL}"; then
   local ELAPSED_NOW
   ELAPSED_NOW=$(($(date +%s) - DOWNLOAD_START_TIME))
   __log_overpass_failure "${ID}" "${ATTEMPT_NUM}" "${DOWNLOAD_VALIDATION_RETRIES}" "${ELAPSED_NOW}"
   DOWNLOAD_VALIDATION_RETRY_COUNT=$((DOWNLOAD_VALIDATION_RETRY_COUNT + 1))
   if [[ ${DOWNLOAD_VALIDATION_RETRY_COUNT} -lt ${DOWNLOAD_VALIDATION_RETRIES} ]]; then
    __logw "Will retry boundary ${ID} (remaining attempts: $((DOWNLOAD_VALIDATION_RETRIES - DOWNLOAD_VALIDATION_RETRY_COUNT)))"
   fi
   continue
  fi
  __log_overpass_success "${ID}" "${ATTEMPT_NUM}"

  # Check for specific Overpass errors
  __logd "Checking Overpass API response for errors..."
  cat "${OUTPUT_OVERPASS}"

  # Check for various Overpass API error codes
  local MANY_REQUESTS
  local GATEWAY_TIMEOUT
  local BAD_REQUEST
  local INTERNAL_SERVER_ERROR
  local SERVICE_UNAVAILABLE

  # Capture error counts and remove any trailing newlines
  MANY_REQUESTS=$(grep -c "ERROR 429" "${OUTPUT_OVERPASS}" 2> /dev/null || echo "0")
  MANY_REQUESTS=$(echo "${MANY_REQUESTS}" | tr -d '\n' | tr -d ' ')
  GATEWAY_TIMEOUT=$(grep -c "ERROR 504" "${OUTPUT_OVERPASS}" 2> /dev/null || echo "0")
  GATEWAY_TIMEOUT=$(echo "${GATEWAY_TIMEOUT}" | tr -d '\n' | tr -d ' ')
  BAD_REQUEST=$(grep -c "ERROR 400" "${OUTPUT_OVERPASS}" 2> /dev/null || echo "0")
  BAD_REQUEST=$(echo "${BAD_REQUEST}" | tr -d '\n' | tr -d ' ')
  INTERNAL_SERVER_ERROR=$(grep -c "ERROR 500" "${OUTPUT_OVERPASS}" 2> /dev/null || echo "0")
  INTERNAL_SERVER_ERROR=$(echo "${INTERNAL_SERVER_ERROR}" | tr -d '\n' | tr -d ' ')
  SERVICE_UNAVAILABLE=$(grep -c "ERROR 503" "${OUTPUT_OVERPASS}" 2> /dev/null || echo "0")
  SERVICE_UNAVAILABLE=$(echo "${SERVICE_UNAVAILABLE}" | tr -d '\n' | tr -d ' ')

  # Ensure all variables are clean numeric values (remove any non-digit characters)
  MANY_REQUESTS="${MANY_REQUESTS//[^0-9]/}"
  GATEWAY_TIMEOUT="${GATEWAY_TIMEOUT//[^0-9]/}"
  BAD_REQUEST="${BAD_REQUEST//[^0-9]/}"
  INTERNAL_SERVER_ERROR="${INTERNAL_SERVER_ERROR//[^0-9]/}"
  SERVICE_UNAVAILABLE="${SERVICE_UNAVAILABLE//[^0-9]/}"

  # Default to 0 if empty after cleaning
  MANY_REQUESTS="${MANY_REQUESTS:-0}"
  GATEWAY_TIMEOUT="${GATEWAY_TIMEOUT:-0}"
  BAD_REQUEST="${BAD_REQUEST:-0}"
  INTERNAL_SERVER_ERROR="${INTERNAL_SERVER_ERROR:-0}"
  SERVICE_UNAVAILABLE="${SERVICE_UNAVAILABLE:-0}"

  # If we have critical errors, retry the download
  local HAS_CRITICAL_ERROR=false
  if [[ "${MANY_REQUESTS}" -ne 0 ]] || [[ "${GATEWAY_TIMEOUT}" -ne 0 ]] || [[ "${BAD_REQUEST}" -ne 0 ]] \
   || [[ "${INTERNAL_SERVER_ERROR}" -ne 0 ]] || [[ "${SERVICE_UNAVAILABLE}" -ne 0 ]]; then
   HAS_CRITICAL_ERROR=true
   if [[ "${MANY_REQUESTS}" -ne 0 ]]; then
    __loge "ERROR 429: Too many requests to Overpass API for boundary ${ID} - IP may be rate-limited, will retry with longer delay"
    # If 429 detected, wait longer to avoid further rate limiting
    local RATE_LIMIT_DELAY=30
    __logw "Waiting ${RATE_LIMIT_DELAY}s due to rate limit (429) before retry..."
    sleep "${RATE_LIMIT_DELAY}"
   fi
   if [[ "${GATEWAY_TIMEOUT}" -ne 0 ]]; then
    __loge "ERROR 504: Gateway timeout from Overpass API for boundary ${ID} - will retry"
   fi
   if [[ "${BAD_REQUEST}" -ne 0 ]]; then
    __loge "ERROR 400: Bad request to Overpass API for boundary ${ID} - will retry"
   fi
   if [[ "${INTERNAL_SERVER_ERROR}" -ne 0 ]]; then
    __loge "ERROR 500: Internal server error from Overpass API for boundary ${ID} - will retry"
   fi
   if [[ "${SERVICE_UNAVAILABLE}" -ne 0 ]]; then
    __loge "ERROR 503: Service unavailable from Overpass API for boundary ${ID} - will retry"
   fi
  fi

  # Check for other errors (non-critical warnings)
  local OTHER_ERRORS
  OTHER_ERRORS=$(grep "ERROR" "${OUTPUT_OVERPASS}" || echo "")
  if [[ -n "${OTHER_ERRORS}" ]] && [[ "${HAS_CRITICAL_ERROR}" == "false" ]]; then
   __logw "Other Overpass API errors detected for boundary ${ID}:"
   echo "${OTHER_ERRORS}" | while IFS= read -r line; do
    __logw "  ${line}"
   done
  fi

  # If we have critical errors, retry the download
  if [[ "${HAS_CRITICAL_ERROR}" == "true" ]]; then
   DOWNLOAD_VALIDATION_RETRY_COUNT=$((DOWNLOAD_VALIDATION_RETRY_COUNT + 1))
   rm -f "${OUTPUT_OVERPASS}"
   continue
  fi

  __logd "No critical Overpass API errors detected for boundary ${ID}"
  rm -f "${OUTPUT_OVERPASS}"

  # Validate the JSON structure and ensure it contains elements
  __log_json_validation_start "${ID}"
  if ! __validate_json_with_element "${JSON_FILE}" "elements"; then
   __loge "JSON validation failed for boundary ${ID} - will retry download"
   DOWNLOAD_VALIDATION_RETRY_COUNT=$((DOWNLOAD_VALIDATION_RETRY_COUNT + 1))
   continue
  fi
  __log_json_validation_success "${ID}"

  # If we reach here, download and validation were successful
  DOWNLOAD_SUCCESS=true
 done

 # Check if download and validation succeeded
 if [[ "${DOWNLOAD_SUCCESS}" != "true" ]]; then
  local TOTAL_TIME
  TOTAL_TIME=$(($(date +%s) - DOWNLOAD_START_TIME))
  __loge "Failed to download and validate JSON for boundary ${ID} after ${DOWNLOAD_VALIDATION_RETRIES} attempts (total time: ${TOTAL_TIME}s)"
  if [[ "${CONTINUE_ON_OVERPASS_ERROR:-false}" == "true" ]]; then
   echo "${ID}" >> "${TMP_DIR}/failed_boundaries.txt"
   __logw "Recording boundary ${ID} as failed and continuing (CONTINUE_ON_OVERPASS_ERROR=true, total time: ${TOTAL_TIME}s)"
   rm -f "${JSON_FILE}" "${OUTPUT_OVERPASS}" 2> /dev/null || true
   __log_finish
   return 1
  else
   __handle_error_with_cleanup "${ERROR_DATA_VALIDATION}" "Invalid JSON structure for boundary ${ID} after retries (total time: ${TOTAL_TIME}s)" \
    "rm -f ${JSON_FILE} ${OUTPUT_OVERPASS} 2>/dev/null || true"
   __log_finish
   return 1
  fi
 fi
 local TOTAL_SUCCESS_TIME
 TOTAL_SUCCESS_TIME=$(($(date +%s) - DOWNLOAD_START_TIME))
 __log_download_success "${ID}" "${TOTAL_SUCCESS_TIME}"

 # Convert to GeoJSON with retry logic and validation
 # Retry conversion if validation fails
 local GEOJSON_VALIDATION_RETRIES=3
 local GEOJSON_VALIDATION_RETRY_COUNT=0
 local GEOJSON_SUCCESS=false
 local GEOJSON_START_TIME
 GEOJSON_START_TIME=$(date +%s)

 __log_geojson_conversion_start "${ID}" "${GEOJSON_VALIDATION_RETRIES}"

 while [[ ${GEOJSON_VALIDATION_RETRY_COUNT} -lt ${GEOJSON_VALIDATION_RETRIES} ]] && [[ "${GEOJSON_SUCCESS}" == "false" ]]; do
  local GEOJSON_ATTEMPT_NUM=$((GEOJSON_VALIDATION_RETRY_COUNT + 1))
  local GEOJSON_ELAPSED
  GEOJSON_ELAPSED=$(($(date +%s) - GEOJSON_START_TIME))

  if [[ ${GEOJSON_VALIDATION_RETRY_COUNT} -gt 0 ]]; then
   __logw "Retrying GeoJSON conversion and validation for boundary ${ID} (attempt ${GEOJSON_ATTEMPT_NUM}/${GEOJSON_VALIDATION_RETRIES}, elapsed: ${GEOJSON_ELAPSED}s)"
   # Clean up previous failed attempt
   rm -f "${GEOJSON_FILE}" 2> /dev/null || true
   # Wait before retry
   local GEOJSON_RETRY_DELAY=$((5 * GEOJSON_VALIDATION_RETRY_COUNT))
   if [[ ${GEOJSON_RETRY_DELAY} -gt 30 ]]; then
    GEOJSON_RETRY_DELAY=30
   fi
   __log_geojson_retry_delay "${ID}" "${GEOJSON_RETRY_DELAY}" "${GEOJSON_ATTEMPT_NUM}"
   sleep "${GEOJSON_RETRY_DELAY}"
  else
   __logd "Starting GeoJSON conversion attempt ${GEOJSON_ATTEMPT_NUM}/${GEOJSON_VALIDATION_RETRIES} for boundary ${ID}"
  fi

  local GEOJSON_OPERATION="osmtogeojson ${JSON_FILE} > ${GEOJSON_FILE}"
  local GEOJSON_CLEANUP="rm -f ${GEOJSON_FILE} 2>/dev/null || true"

  __log_geojson_conversion_attempt "${ID}" "${GEOJSON_ATTEMPT_NUM}" "${GEOJSON_VALIDATION_RETRIES}"
  if ! __retry_file_operation "${GEOJSON_OPERATION}" 2 5 "${GEOJSON_CLEANUP}"; then
   local GEOJSON_ELAPSED_NOW
   GEOJSON_ELAPSED_NOW=$(($(date +%s) - GEOJSON_START_TIME))
   __log_geojson_conversion_failure "${ID}" "${GEOJSON_ATTEMPT_NUM}" "${GEOJSON_VALIDATION_RETRIES}" "${GEOJSON_ELAPSED_NOW}"
   GEOJSON_VALIDATION_RETRY_COUNT=$((GEOJSON_VALIDATION_RETRY_COUNT + 1))
   if [[ ${GEOJSON_VALIDATION_RETRY_COUNT} -lt ${GEOJSON_VALIDATION_RETRIES} ]]; then
    __logw "Will retry GeoJSON conversion for boundary ${ID} (remaining attempts: $((GEOJSON_VALIDATION_RETRIES - GEOJSON_VALIDATION_RETRY_COUNT)))"
   fi
   continue
  fi
  __log_geojson_conversion_success "${ID}" "${GEOJSON_ATTEMPT_NUM}"

  # Validate the GeoJSON structure and ensure it contains features
  __log_geojson_validation "${ID}"
  if ! __validate_json_with_element "${GEOJSON_FILE}" "features"; then
   __loge "GeoJSON validation failed for boundary ${ID} - will retry conversion"
   GEOJSON_VALIDATION_RETRY_COUNT=$((GEOJSON_VALIDATION_RETRY_COUNT + 1))
   continue
  fi
  __log_geojson_validation_success "${ID}"

  # If we reach here, conversion and validation were successful
  GEOJSON_SUCCESS=true
 done

 # Check if GeoJSON conversion and validation succeeded
 if [[ "${GEOJSON_SUCCESS}" != "true" ]]; then
  local GEOJSON_TOTAL_TIME
  GEOJSON_TOTAL_TIME=$(($(date +%s) - GEOJSON_START_TIME))
  __loge "Failed to convert and validate GeoJSON for boundary ${ID} after ${GEOJSON_VALIDATION_RETRIES} attempts (total time: ${GEOJSON_TOTAL_TIME}s)"
  __handle_error_with_cleanup "${ERROR_GEOJSON_CONVERSION}" "Invalid GeoJSON structure for boundary ${ID} after retries (total time: ${GEOJSON_TOTAL_TIME}s)" \
   "rm -f ${JSON_FILE} ${GEOJSON_FILE} 2>/dev/null || true"
  __log_finish
  return 1
 fi
 local GEOJSON_TOTAL_SUCCESS_TIME
 GEOJSON_TOTAL_SUCCESS_TIME=$(($(date +%s) - GEOJSON_START_TIME))
 __logi "GeoJSON conversion and validation completed successfully for boundary ${ID} (total time: ${GEOJSON_TOTAL_SUCCESS_TIME}s)"

 # Extract names with error handling and sanitization
 __logd "Extracting names for boundary ${ID}..."
 set +o pipefail
 local NAME_RAW
 NAME_RAW=$(grep "\"name\":" "${GEOJSON_FILE}" | head -1 \
  | awk -F\" '{print $4}')
 local NAME_ES_RAW
 NAME_ES_RAW=$(grep "\"name:es\":" "${GEOJSON_FILE}" | head -1 \
  | awk -F\" '{print $4}')
 local NAME_EN_RAW
 NAME_EN_RAW=$(grep "\"name:en\":" "${GEOJSON_FILE}" | head -1 \
  | awk -F\" '{print $4}')
 set -o pipefail
 set -e

 # Sanitize all names using SQL sanitization function
 local NAME
 NAME=$(__sanitize_sql_string "${NAME_RAW}")
 local NAME_ES
 NAME_ES=$(__sanitize_sql_string "${NAME_ES_RAW}")
 local NAME_EN
 NAME_EN=$(__sanitize_sql_string "${NAME_EN_RAW}")
 NAME_EN="${NAME_EN:-No English name}"
 __logi "Name: ${NAME_EN:-}."
 __logd "Extracted names for boundary ${ID}:"
 __logd "  Name: ${NAME:-N/A}"
 __logd "  Name ES: ${NAME_ES:-N/A}"
 __logd "  Name EN: ${NAME_EN:-N/A}"

 # Import into Postgres with retry logic
 __log_import_start "${ID}"
 __logd "Acquiring lock for boundary ${ID}..."

 # Create a unique lock directory for this process
 local PROCESS_LOCK="${LOCK_OGR2OGR}.${BASHPID}"
 local LOCK_OPERATION="mkdir ${PROCESS_LOCK} 2> /dev/null"
 local LOCK_CLEANUP="rmdir ${PROCESS_LOCK} 2>/dev/null || true"

 if ! __retry_file_operation "${LOCK_OPERATION}" 3 2 "${LOCK_CLEANUP}"; then
  __log_lock_failed "${ID}"
  __handle_error_with_cleanup "${ERROR_GENERAL}" "Lock acquisition failed for boundary ${ID}" \
   "rm -f ${JSON_FILE} ${GEOJSON_FILE} 2>/dev/null || true"
  __log_finish
  return 1
 fi
 __log_lock_acquired "${ID}"

 # Import with ogr2ogr using retry logic with special handling for Austria
 __logd "Importing boundary ${ID} into database..."

 # Import ALL features from GeoJSON
 # Previous approach used -sql with SQLite dialect to select only geometry,
 # but this was causing incomplete imports (only partial features imported).
 # PostgreSQL TOAST automatically handles large rows, so we can import all fields
 # and filter by geometry type in SQL. This ensures all features are imported correctly.
 # -skipfailures allows ogr2ogr to continue even if some features fail
 # Check if DB import should be skipped (for download-only mode)
 if [[ "${SKIP_DB_IMPORT:-false}" == "true" ]]; then
  __logi "SKIP_DB_IMPORT=true - Skipping database import for boundary ${ID}"
  __logi "GeoJSON file saved at: ${GEOJSON_FILE}"
  rmdir "${PROCESS_LOCK}" 2> /dev/null || true
  __log_finish
  return 0
 fi

 __logd "Importing all features from GeoJSON for boundary ${ID}"

 local IMPORT_OPERATION
 local OGR_ERROR_LOG="${TMP_DIR}/ogr_error.${BASHPID}.log"

 # Special handling for Afghanistan (303427) and Taiwan (449220) - remove
 # problematic tags to avoid oversized records (historical solution from git)
 # These countries have many alt_name and official_name tags that cause "row too
 # big" errors
 if [[ "${ID}" -eq 303427 ]] || [[ "${ID}" -eq 449220 ]]; then
  if [[ "${ID}" -eq 303427 ]]; then
   __logi "Special handling for Afghanistan (ID: 303427) - removing problematic tags"
  else
   __logi "Special handling for Taiwan (ID: 449220) - removing problematic tags"
  fi
  if [[ -f "${GEOJSON_FILE}" ]]; then
   # Remove official_name and alt_name tags to reduce row size
   # This was the historical solution found in git history
   local GEOJSON_TEMP="${GEOJSON_FILE}.temp"
   grep -v "\"official_name\"" "${GEOJSON_FILE}" \
    | grep -v "\"alt_name\"" > "${GEOJSON_TEMP}" 2> /dev/null || cp "${GEOJSON_FILE}" "${GEOJSON_TEMP}"
   mv "${GEOJSON_TEMP}" "${GEOJSON_FILE}"
   __logd "Removed problematic tags from GeoJSON for boundary ${ID}"
  fi
  # Also use PG_USE_COPY NO to allow TOAST for large geometries
  __logd "Using PG_USE_COPY NO to allow TOAST for large rows"
  IMPORT_OPERATION="ogr2ogr -f PostgreSQL PG:dbname=${DBNAME} -nln import -overwrite -skipfailures -nlt PROMOTE_TO_MULTI -a_srs EPSG:4326 -lco GEOMETRY_NAME=geometry --config PG_USE_COPY NO ${GEOJSON_FILE} 2> ${OGR_ERROR_LOG}"
 elif [[ "${ID}" -eq 16239 ]]; then
  # Austria - use ST_Buffer to fix topology issues
  __logd "Using special handling for Austria (ID: 16239)"
  # Import all features, geometry will be filtered in SQL
  IMPORT_OPERATION="ogr2ogr -f PostgreSQL PG:dbname=${DBNAME} -nln import -overwrite -skipfailures -nlt PROMOTE_TO_MULTI -a_srs EPSG:4326 -lco GEOMETRY_NAME=geometry --config PG_USE_COPY YES ${GEOJSON_FILE} 2> ${OGR_ERROR_LOG}"
 else
  # Standard import - import ALL features
  __logd "Importing all features for boundary ${ID}"
  # Import all features, geometry will be filtered in SQL
  IMPORT_OPERATION="ogr2ogr -f PostgreSQL PG:dbname=${DBNAME} -nln import -overwrite -skipfailures -nlt PROMOTE_TO_MULTI -a_srs EPSG:4326 -lco GEOMETRY_NAME=geometry --config PG_USE_COPY YES ${GEOJSON_FILE} 2> ${OGR_ERROR_LOG}"
 fi

 local IMPORT_CLEANUP="rmdir ${PROCESS_LOCK} 2>/dev/null || true"

 if ! __retry_file_operation "${IMPORT_OPERATION}" 2 5 "${IMPORT_CLEANUP}"; then
  # Check if the error is "row is too big" - this requires a different strategy
  local HAS_ROW_TOO_BIG=false
  if [[ -f "${OGR_ERROR_LOG}" ]]; then
   if grep -q "row is too big" "${OGR_ERROR_LOG}" 2> /dev/null; then
    HAS_ROW_TOO_BIG=true
    __logw "Detected 'row is too big' error for boundary ${ID} - retrying with PG_USE_COPY NO"
   fi
  fi

  # If "row is too big", retry with PG_USE_COPY NO (allows TOAST)
  # Note: Afghanistan (303427) and Taiwan (449220) already use PG_USE_COPY NO
  # from the start, so this is only for other countries that unexpectedly hit
  # this error
  if [[ "${HAS_ROW_TOO_BIG}" == "true" ]]; then
   __logd "Retrying import for boundary ${ID} without COPY (using TOAST)"
   if [[ "${ID}" -eq 16239 ]]; then
    # Austria - use ST_Buffer to fix topology issues
    IMPORT_OPERATION="ogr2ogr -f PostgreSQL PG:dbname=${DBNAME} -nln import -overwrite -skipfailures -nlt PROMOTE_TO_MULTI -a_srs EPSG:4326 -lco GEOMETRY_NAME=geometry --config PG_USE_COPY NO ${GEOJSON_FILE} 2> ${OGR_ERROR_LOG}"
   else
    # Standard import without COPY (slower but allows TOAST for large rows)
    IMPORT_OPERATION="ogr2ogr -f PostgreSQL PG:dbname=${DBNAME} -nln import -overwrite -skipfailures -nlt PROMOTE_TO_MULTI -a_srs EPSG:4326 -lco GEOMETRY_NAME=geometry --config PG_USE_COPY NO ${GEOJSON_FILE} 2> ${OGR_ERROR_LOG}"
   fi

   if ! __retry_file_operation "${IMPORT_OPERATION}" 2 5 "${IMPORT_CLEANUP}"; then
    __loge "Failed to import boundary ${ID} even with PG_USE_COPY NO"
    # Check for real errors (not just missing field warnings)
    if [[ -f "${OGR_ERROR_LOG}" ]]; then
     local REAL_ERRORS
     REAL_ERRORS=$(grep -v "Field 'admin_level' not found" "${OGR_ERROR_LOG}" 2> /dev/null | grep -v "^$" || true)
     if [[ -n "${REAL_ERRORS}" ]]; then
      __loge "ogr2ogr errors for boundary ${ID}:"
      echo "${REAL_ERRORS}" | while IFS= read -r line; do
       __loge "  ${line}"
      done
     else
      __logd "Only expected warnings (missing admin_level field) for boundary ${ID}"
     fi
     rm -f "${OGR_ERROR_LOG}" 2> /dev/null || true
    fi
    __handle_error_with_cleanup "${ERROR_GENERAL}" "Database import failed for boundary ${ID}" \
     "rm -f ${JSON_FILE} ${GEOJSON_FILE} ${OGR_ERROR_LOG} 2>/dev/null || true; rmdir ${PROCESS_LOCK} 2>/dev/null || true"
    __log_finish
    return 1
   else
    __logi "Successfully imported boundary ${ID} using PG_USE_COPY NO (TOAST)"
   fi
  else
   # Other errors - log and fail
   __loge "Failed to import boundary ${ID} into database after retries"
   # Check for real errors (not just missing field warnings)
   if [[ -f "${OGR_ERROR_LOG}" ]]; then
    local REAL_ERRORS
    REAL_ERRORS=$(grep -v "Field 'admin_level' not found" "${OGR_ERROR_LOG}" 2> /dev/null | grep -v "^$" || true)
    if [[ -n "${REAL_ERRORS}" ]]; then
     __loge "ogr2ogr errors for boundary ${ID}:"
     echo "${REAL_ERRORS}" | while IFS= read -r line; do
      __loge "  ${line}"
     done
    else
     __logd "Only expected warnings (missing admin_level field) for boundary ${ID}"
    fi
    rm -f "${OGR_ERROR_LOG}" 2> /dev/null || true
   fi
   __handle_error_with_cleanup "${ERROR_GENERAL}" "Database import failed for boundary ${ID}" \
    "rm -f ${JSON_FILE} ${GEOJSON_FILE} ${OGR_ERROR_LOG} 2>/dev/null || true; rmdir ${PROCESS_LOCK} 2>/dev/null || true"
   __log_finish
   return 1
  fi
 fi
 # Check ogr2ogr output for warnings (missing fields are expected for some boundaries)
 if [[ -f "${OGR_ERROR_LOG}" ]]; then
  local REAL_ERRORS
  REAL_ERRORS=$(grep -v "Field 'admin_level' not found" "${OGR_ERROR_LOG}" 2> /dev/null | grep -v "^$" || true)
  if [[ -n "${REAL_ERRORS}" ]]; then
   __logw "ogr2ogr warnings for boundary ${ID} (non-critical):"
   echo "${REAL_ERRORS}" | while IFS= read -r line; do
    __logw "  ${line}"
   done
  fi
  rm -f "${OGR_ERROR_LOG}" 2> /dev/null || true
 fi
 __log_import_completed "${ID}"

 # Check for column duplication errors and handle them
 __logd "Checking for duplicate columns in import table for boundary ${ID}..."
 local COLUMN_CHECK_OPERATION="psql -d ${DBNAME} -c \"SELECT column_name, COUNT(*) FROM information_schema.columns WHERE table_name = 'import' GROUP BY column_name HAVING COUNT(*) > 1;\" 2>/dev/null"
 local COLUMN_CHECK_RESULT
 COLUMN_CHECK_RESULT=$(eval "${COLUMN_CHECK_OPERATION}" 2> /dev/null || echo "")

 if [[ -n "${COLUMN_CHECK_RESULT}" ]] && [[ "${COLUMN_CHECK_RESULT}" != *"0 rows"* ]]; then
  __logw "Detected duplicate columns in import table for boundary ${ID}"
  __logw "This is likely due to case-sensitive column names in the GeoJSON"
  __logd "Attempting to fix duplicate columns..."
  local FIX_COLUMNS_OPERATION="psql -d ${DBNAME} -c \"ALTER TABLE import DROP COLUMN IF EXISTS \\\"name:xx-XX\\\", DROP COLUMN IF EXISTS \\\"name:XX-xx\\\";\" 2>/dev/null"
  if ! eval "${FIX_COLUMNS_OPERATION}"; then
   __logw "Failed to fix duplicate columns, but continuing..."
  else
   __log_duplicate_columns_fixed "${ID}"
  fi
 else
  __log_no_duplicate_columns "${ID}"
 fi

 # Process the imported data with geometry validation
 __logd "Processing imported data for boundary ${ID}..."
 __logd "Validating geometry before insert for boundary ${ID}..."

 local SANITIZED_ID
 SANITIZED_ID=$(__sanitize_sql_integer "${ID}")

 local GEOM_CHECK_QUERY
 if [[ "${ID}" -eq 16239 ]]; then
  __logd "Using special processing for Austria (ID: 16239) with ST_Buffer"
  # Filter only Polygons/MultiPolygons for ST_Union (Points and LineStrings cannot be unioned)
  GEOM_CHECK_QUERY="SELECT ST_Union(ST_Buffer(geometry, 0.0)) IS NOT NULL AS has_geom FROM import WHERE ST_GeometryType(geometry) IN ('ST_Polygon', 'ST_MultiPolygon')"
 else
  __logd "Using standard processing with ST_MakeValid for boundary ${ID}"
  # Filter only Polygons/MultiPolygons for ST_Union (Points and LineStrings cannot be unioned)
  # This prevents ST_Union from failing on mixed geometry types and improves performance
  GEOM_CHECK_QUERY="SELECT ST_Union(ST_makeValid(geometry)) IS NOT NULL AS has_geom FROM import WHERE ST_GeometryType(geometry) IN ('ST_Polygon', 'ST_MultiPolygon')"
 fi

 local HAS_VALID_GEOM
 HAS_VALID_GEOM=$(psql -d "${DBNAME}" -Atq -c "${GEOM_CHECK_QUERY}" 2> /dev/null || echo "f")

 if [[ "${HAS_VALID_GEOM}" != "t" ]]; then
  __loge "ERROR: Cannot create valid geometry for boundary ${ID}"
  __loge "ST_Union returned NULL - possible causes:"
  __loge "  1. No geometries in import table"
  __loge "  2. All geometries are invalid even after ST_MakeValid"
  __loge "  3. Geometry union operation failed"

  local IMPORT_COUNT
  IMPORT_COUNT=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM import" 2> /dev/null || echo "0")
  __loge "Import table has ${IMPORT_COUNT} rows for boundary ${ID}"

  __logd "Analyzing geometry types in import table:"
  psql -d "${DBNAME}" -c "SELECT ST_GeometryType(geometry) AS geom_type, COUNT(*) FROM import GROUP BY geom_type ORDER BY geom_type" 2> /dev/null || true

  __logd "Sample geometry validity check:"
  psql -d "${DBNAME}" -c "SELECT ST_IsValid(geometry) AS is_valid, ST_IsValidReason(geometry) AS reason FROM import LIMIT 5" 2> /dev/null || true

  __logd "Checking for NULL geometries:"
  local NULL_COUNT
  NULL_COUNT=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM import WHERE geometry IS NULL" 2> /dev/null || echo "0")
  __logd "NULL geometries: ${NULL_COUNT}"

  local VALID_COUNT
  VALID_COUNT=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM import WHERE ST_IsValid(geometry)" 2> /dev/null || echo "0")
  __logd "Valid geometries: ${VALID_COUNT}"

  __logi "Attempting alternative geometry repair strategies..."

  # Try ST_Collect only on Polygons/MultiPolygons (not Points/LineStrings)
  local ALT_QUERY="SELECT ST_Collect(ST_MakeValid(geometry)) IS NOT NULL AS has_geom FROM import WHERE ST_GeometryType(geometry) IN ('ST_Polygon', 'ST_MultiPolygon')"
  local HAS_COLLECT
  HAS_COLLECT=$(psql -d "${DBNAME}" -Atq -c "${ALT_QUERY}" 2> /dev/null || echo "f")

  if [[ "${HAS_COLLECT}" == "t" ]]; then
   __logw "ST_Collect works but not ST_Union - using ST_Collect as alternative (Polygons only)"
   if [[ "${ID}" -eq 16239 ]]; then
    # Collect only Polygons/MultiPolygons, ignore Points/LineStrings
    # Only update if new geometry is better (larger area) than existing
    # Note: ST_Collect groups geometries but doesn't union them. Use ST_UnaryUnion to union after collect
    PROCESS_OPERATION="psql -d ${DBNAME} -c \"WITH collected AS (SELECT ST_Collect(ST_Buffer(geometry, 0.0)) AS geom FROM import WHERE ST_GeometryType(geometry) IN ('ST_Polygon', 'ST_MultiPolygon')), new_geom AS (SELECT ST_SetSRID(ST_UnaryUnion(geom), 4326) AS geom FROM collected), new_area AS (SELECT ST_Area(geom::geography) AS area FROM new_geom), existing_area AS (SELECT ST_Area(geom::geography) AS area FROM countries WHERE country_id = ${SANITIZED_ID}) INSERT INTO countries (country_id, country_name, country_name_es, country_name_en, geom) SELECT ${SANITIZED_ID}, '${NAME}', '${NAME_ES}', '${NAME_EN}', new_geom.geom FROM new_geom ON CONFLICT (country_id) DO UPDATE SET country_name = EXCLUDED.country_name, country_name_es = EXCLUDED.country_name_es, country_name_en = EXCLUDED.country_name_en, geom = CASE WHEN (SELECT area FROM new_area) > COALESCE((SELECT area FROM existing_area), 0) * 0.5 THEN ST_SetSRID(EXCLUDED.geom, 4326) ELSE countries.geom END WHERE (SELECT area FROM new_area) > COALESCE((SELECT area FROM existing_area), 0) * 0.5 OR (SELECT area FROM existing_area) IS NULL;\""
   else
    # Collect only Polygons/MultiPolygons, ignore Points/LineStrings
    # Only update if new geometry is better (larger area) than existing
    # Note: ST_Collect groups geometries but doesn't union them. Use ST_UnaryUnion to union after collect
    PROCESS_OPERATION="psql -d ${DBNAME} -c \"WITH collected AS (SELECT ST_Collect(ST_makeValid(geometry)) AS geom FROM import WHERE ST_GeometryType(geometry) IN ('ST_Polygon', 'ST_MultiPolygon')), new_geom AS (SELECT ST_SetSRID(ST_UnaryUnion(geom), 4326) AS geom FROM collected), new_area AS (SELECT ST_Area(geom::geography) AS area FROM new_geom), existing_area AS (SELECT ST_Area(geom::geography) AS area FROM countries WHERE country_id = ${SANITIZED_ID}) INSERT INTO countries (country_id, country_name, country_name_es, country_name_en, geom) SELECT ${SANITIZED_ID}, '${NAME}', '${NAME_ES}', '${NAME_EN}', new_geom.geom FROM new_geom ON CONFLICT (country_id) DO UPDATE SET country_name = EXCLUDED.country_name, country_name_es = EXCLUDED.country_name_es, country_name_en = EXCLUDED.country_name_en, geom = CASE WHEN (SELECT area FROM new_area) > COALESCE((SELECT area FROM existing_area), 0) * 0.5 THEN ST_SetSRID(EXCLUDED.geom, 4326) ELSE countries.geom END WHERE (SELECT area FROM new_area) > COALESCE((SELECT area FROM existing_area), 0) * 0.5 OR (SELECT area FROM existing_area) IS NULL;\""
   fi

   if ! __retry_file_operation "${PROCESS_OPERATION}" 2 3 ""; then
    __loge "Alternative ST_Collect also failed"
    __loge "Skipping boundary ${ID} due to geometry issues"
    rmdir "${PROCESS_LOCK}" 2> /dev/null || true
    __log_finish
    return 1
   fi
   __logi "✓ Successfully inserted boundary ${ID} using ST_Collect"
  else
   __logw "Trying buffer strategy for LineString geometries..."
   # Try buffer strategy only on Polygons/MultiPolygons
   local BUFFER_QUERY="SELECT ST_Buffer(ST_MakeValid(geometry), 0.0001) IS NOT NULL AS has_geom FROM import WHERE ST_GeometryType(geometry) IN ('ST_Polygon', 'ST_MultiPolygon')"
   local HAS_BUFFER
   HAS_BUFFER=$(psql -d "${DBNAME}" -Atq -c "${BUFFER_QUERY}" 2> /dev/null || echo "f")

   if [[ "${HAS_BUFFER}" == "t" ]]; then
    __logw "Buffer strategy works - applying buffered geometries (Polygons only)"
    # Buffer and union only Polygons/MultiPolygons
    PROCESS_OPERATION="psql -d ${DBNAME} -c \"INSERT INTO countries (country_id, country_name, country_name_es, country_name_en, geom) SELECT ${SANITIZED_ID}, '${NAME}', '${NAME_ES}', '${NAME_EN}', ST_SetSRID(ST_Union(ST_Buffer(ST_MakeValid(geometry), 0.0001)), 4326) FROM import WHERE ST_GeometryType(geometry) IN ('ST_Polygon', 'ST_MultiPolygon') ON CONFLICT (country_id) DO UPDATE SET country_name = EXCLUDED.country_name, country_name_es = EXCLUDED.country_name_es, country_name_en = EXCLUDED.country_name_en, geom = ST_SetSRID(EXCLUDED.geom, 4326);\""

    if ! __retry_file_operation "${PROCESS_OPERATION}" 2 3 ""; then
     __loge "Buffer strategy failed"
     __loge "Skipping boundary ${ID} due to geometry issues"
     rmdir "${PROCESS_LOCK}" 2> /dev/null || true
     __log_finish
     return 1
    fi
    __logi "✓ Successfully inserted boundary ${ID} using buffer strategy"
   else
    __loge "All repair strategies failed - skipping boundary ${ID}"
    rmdir "${PROCESS_LOCK}" 2> /dev/null || true
    __log_finish
    return 1
   fi
  fi

  rmdir "${PROCESS_LOCK}" 2> /dev/null || true
  __log_finish
  return 0
 fi

 __logi "✓ Geometry validation passed for boundary ${ID}"

 # Now perform the actual insert with validated geometry
 # Verify table exists before attempting insert
 __logd "Verifying countries table exists before insert for boundary ${ID}..."
 local TABLE_EXISTS
 TABLE_EXISTS=$(psql -d "${DBNAME}" -Atq -c "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'countries')" 2> /dev/null || echo "f")

 if [[ "${TABLE_EXISTS}" != "t" ]]; then
  __loge "CRITICAL: countries table does not exist in database ${DBNAME}"
  __loge "Attempted to insert boundary ${ID} (${NAME})"
  __loge "Thread PID: ${BASHPID}, Parent PID: $$"
  __loge "This indicates a serious database issue"
  __handle_error_with_cleanup "${ERROR_GENERAL}" "Table countries not found in database ${DBNAME}" \
   "rm -f ${JSON_FILE} ${GEOJSON_FILE} 2>/dev/null || true; rmdir ${PROCESS_LOCK} 2>/dev/null || true"
  __log_finish
  return 1
 fi
 __logd "Confirmed: countries table exists in database ${DBNAME}"

 __logd "Verifying database connection for boundary ${ID}..."
 local CONNECTION_TEST
 CONNECTION_TEST=$(psql -d "${DBNAME}" -Atq -c "SELECT 1" 2> /dev/null || echo "FAIL")

 if [[ "${CONNECTION_TEST}" != "1" ]]; then
  __loge "CRITICAL: Database connection failed for boundary ${ID}"
  __loge "Database: ${DBNAME}"
  __loge "Thread PID: ${BASHPID}, Parent PID: $$"
  __handle_error_with_cleanup "${ERROR_GENERAL}" "Database connection failed for ${DBNAME}" \
   "rm -f ${JSON_FILE} ${GEOJSON_FILE} 2>/dev/null || true; rmdir ${PROCESS_LOCK} 2>/dev/null || true"
  __log_finish
  return 1
 fi
 __logd "Database connection verified for boundary ${ID}"

 local PROCESS_OPERATION
 if [[ "${ID}" -eq 16239 ]]; then
  __logd "Preparing to insert boundary ${ID} with ST_Buffer processing"
  # Union only Polygons/MultiPolygons (Points and LineStrings are not part of country boundaries)
  # Only update if new geometry is better (larger area) than existing
  PROCESS_OPERATION="psql -d ${DBNAME} -c \"WITH new_geom AS (SELECT ST_SetSRID(ST_Union(ST_Buffer(geometry, 0.0)), 4326) AS geom FROM import WHERE ST_GeometryType(geometry) IN ('ST_Polygon', 'ST_MultiPolygon')), new_area AS (SELECT ST_Area(geom::geography) AS area FROM new_geom), existing_area AS (SELECT ST_Area(geom::geography) AS area FROM countries WHERE country_id = ${SANITIZED_ID}) INSERT INTO countries (country_id, country_name, country_name_es, country_name_en, geom) SELECT ${SANITIZED_ID}, '${NAME}', '${NAME_ES}', '${NAME_EN}', new_geom.geom FROM new_geom ON CONFLICT (country_id) DO UPDATE SET country_name = EXCLUDED.country_name, country_name_es = EXCLUDED.country_name_es, country_name_en = EXCLUDED.country_name_en, geom = CASE WHEN (SELECT area FROM new_area) > COALESCE((SELECT area FROM existing_area), 0) * 0.5 THEN ST_SetSRID(EXCLUDED.geom, 4326) ELSE countries.geom END WHERE (SELECT area FROM new_area) > COALESCE((SELECT area FROM existing_area), 0) * 0.5 OR (SELECT area FROM existing_area) IS NULL;\""
 else
  __logd "Preparing to insert boundary ${ID} with standard processing"
  # Union only Polygons/MultiPolygons (Points and LineStrings are not part of country boundaries)
  # This improves performance and prevents ST_Union from failing on mixed geometry types
  # Only update if new geometry is better (larger area) than existing - prevents overwriting with incomplete data
  PROCESS_OPERATION="psql -d ${DBNAME} -c \"WITH new_geom AS (SELECT ST_SetSRID(ST_Union(ST_makeValid(geometry)), 4326) AS geom FROM import WHERE ST_GeometryType(geometry) IN ('ST_Polygon', 'ST_MultiPolygon')), new_area AS (SELECT ST_Area(geom::geography) AS area FROM new_geom), existing_area AS (SELECT ST_Area(geom::geography) AS area FROM countries WHERE country_id = ${SANITIZED_ID}) INSERT INTO countries (country_id, country_name, country_name_es, country_name_en, geom) SELECT ${SANITIZED_ID}, '${NAME}', '${NAME_ES}', '${NAME_EN}', new_geom.geom FROM new_geom ON CONFLICT (country_id) DO UPDATE SET country_name = EXCLUDED.country_name, country_name_es = EXCLUDED.country_name_es, country_name_en = EXCLUDED.country_name_en, geom = CASE WHEN (SELECT area FROM new_area) > COALESCE((SELECT area FROM existing_area), 0) * 0.5 THEN ST_SetSRID(EXCLUDED.geom, 4326) ELSE countries.geom END WHERE (SELECT area FROM new_area) > COALESCE((SELECT area FROM existing_area), 0) * 0.5 OR (SELECT area FROM existing_area) IS NULL;\""
 fi

 __logd "Executing insert operation for boundary ${ID} (country: ${NAME})"
 if ! __retry_file_operation "${PROCESS_OPERATION}" 2 3 ""; then
  __loge "Failed to insert boundary ${ID} into countries table"
  __loge "Boundary details: ID=${ID}, Name=${NAME}"
  __loge "Database: ${DBNAME}, Thread PID: ${BASHPID}, Parent PID: $$"
  __handle_error_with_cleanup "${ERROR_GENERAL}" "Data processing failed for boundary ${ID}" \
   "rm -f ${JSON_FILE} ${GEOJSON_FILE} 2>/dev/null || true; rmdir ${PROCESS_LOCK} 2>/dev/null || true"
  __log_finish
  return 1
 fi
 __logd "Insert operation completed successfully for boundary ${ID}"
 __log_process_complete "${ID}"

 rmdir "${PROCESS_LOCK}" 2> /dev/null || true
 __logi "=== BOUNDARY PROCESSING COMPLETED SUCCESSFULLY ==="
 __log_finish
}

# Compares IDs from Overpass query with backup file IDs.
# Returns 0 if IDs match (backup can be used), 1 if different (need download).
function __compareIdsWithBackup {
 __log_start
 local OVERPASS_IDS_FILE="${1}"
 local BACKUP_FILE="${2}"
 local TYPE="${3}" # "countries" or "maritimes"

 if [[ ! -f "${OVERPASS_IDS_FILE}" ]] || [[ ! -s "${OVERPASS_IDS_FILE}" ]]; then
  __logw "Overpass IDs file not found or empty, cannot compare"
  __log_finish
  return 1
 fi

 # Resolve backup file (handles .geojson and .geojson.gz)
 local RESOLVED_BACKUP=""
 if ! __resolve_geojson_file "${BACKUP_FILE}" "RESOLVED_BACKUP" 2> /dev/null; then
  __logd "Backup file not found, comparison not possible"
  __log_finish
  return 1
 fi

 # Extract IDs from Overpass file (skip header, sort lexicographically for comm)
 local OVERPASS_IDS_SORTED
 OVERPASS_IDS_SORTED="${TMP_DIR}/overpass_ids_sorted.txt"
 tail -n +2 "${OVERPASS_IDS_FILE}" 2> /dev/null | sort > "${OVERPASS_IDS_SORTED}" || true

 # Extract IDs from backup GeoJSON (use resolved file, sort lexicographically for comm)
 local BACKUP_IDS_SORTED
 BACKUP_IDS_SORTED="${TMP_DIR}/backup_ids_sorted.txt"
 if command -v jq > /dev/null 2>&1; then
  jq -r '.features[].properties.country_id' "${RESOLVED_BACKUP}" 2> /dev/null \
   | sort > "${BACKUP_IDS_SORTED}" || true
 else
  # Fallback: use ogrinfo
  ogrinfo -al -so "${RESOLVED_BACKUP}" 2> /dev/null \
   | grep -E '^country_id \(' | awk '{print $3}' | sort > "${BACKUP_IDS_SORTED}" || true
 fi

 # Compare counts (for logging only)
 local OVERPASS_COUNT
 OVERPASS_COUNT=$(wc -l < "${OVERPASS_IDS_SORTED}" 2> /dev/null | tr -d ' ' || echo "0")
 local BACKUP_COUNT
 BACKUP_COUNT=$(wc -l < "${BACKUP_IDS_SORTED}" 2> /dev/null | tr -d ' ' || echo "0")

 __logd "Overpass ${TYPE} IDs: ${OVERPASS_COUNT}"
 __logd "Backup ${TYPE} IDs: ${BACKUP_COUNT}"

 if [[ "${OVERPASS_COUNT}" -eq 0 ]]; then
  __logw "No IDs found in Overpass file, cannot use backup"
  __log_finish
  return 1
 fi

 # Check if all Overpass IDs are present in backup
 # This allows using backup even if it has more countries than Overpass
 # Store missing IDs file path in a known location for caller to use
 MISSING_IDS_FILE="${TMP_DIR}/missing_${TYPE}_ids.txt"
 comm -23 "${OVERPASS_IDS_SORTED}" "${BACKUP_IDS_SORTED}" 2> /dev/null > "${MISSING_IDS_FILE}" || true
 local MISSING_IDS
 MISSING_IDS=$(wc -l < "${MISSING_IDS_FILE}" 2> /dev/null | tr -d ' ' || echo "0")

 # Also create file with IDs that exist in both (for filtering backup import)
 local EXISTING_IDS_FILE="${TMP_DIR}/existing_${TYPE}_ids.txt"
 comm -12 "${OVERPASS_IDS_SORTED}" "${BACKUP_IDS_SORTED}" 2> /dev/null > "${EXISTING_IDS_FILE}" || true
 export EXISTING_IDS_FILE

 if [[ "${MISSING_IDS}" -gt 0 ]]; then
  __logi "Some Overpass IDs are missing from backup (${MISSING_IDS} missing), will download only missing ones"
  # Export missing IDs file path for use by caller
  export MISSING_IDS_FILE
  __log_finish
  return 1
 fi

 # All Overpass IDs are in backup - can use backup
 if [[ "${OVERPASS_COUNT}" -eq "${BACKUP_COUNT}" ]]; then
  __logi "All Overpass IDs match backup exactly (${OVERPASS_COUNT} countries), can use backup file"
 else
  __logi "All Overpass IDs present in backup (Overpass: ${OVERPASS_COUNT}, Backup: ${BACKUP_COUNT}), can use backup file"
 fi
 __log_finish
 return 0
}

function __processCountries_impl {
 __log_start
 __logi "=== STARTING COUNTRIES PROCESSING ==="

 # Determine backup file location
 local REPO_COUNTRIES_BACKUP
 if [[ -n "${SCRIPT_BASE_DIRECTORY:-}" ]]; then
  REPO_COUNTRIES_BACKUP="${SCRIPT_BASE_DIRECTORY}/data/countries.geojson"
 else
  local SCRIPT_DIR
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." &> /dev/null && pwd || echo "")"
  if [[ -n "${SCRIPT_DIR}" ]]; then
   REPO_COUNTRIES_BACKUP="${SCRIPT_DIR}/data/countries.geojson"
  else
   REPO_COUNTRIES_BACKUP=""
  fi
 fi

 # Check disk space before downloading boundaries
 # Boundaries requirements:
 # - Country JSON files: ~1.5 GB (varies by number of countries)
 # - GeoJSON conversions: ~1 GB
 # - Temporary files: ~0.5 GB
 # - Safety margin (20%): ~0.6 GB
 # Total estimated: ~4 GB
 __logi "Validating disk space for boundaries download..."
 if ! __check_disk_space "${TMP_DIR}" "4" "Country boundaries download and processing"; then
  __loge "Cannot proceed with boundaries download due to insufficient disk space"
  __handle_error_with_cleanup "${ERROR_GENERAL}" \
   "Insufficient disk space for boundaries download" \
   "__preserve_failed_boundary_artifacts 'download-not-started'"
  local HANDLER_RETURN_CODE=$?
  __log_finish
  return "${HANDLER_RETURN_CODE}"
 fi

 # Extracts ids of all country relations into a CSV file.
 # Note: The Overpass query uses [out:csv(::id)] so it returns CSV, not JSON
 __logi "Obtaining the countries ids."
 # Use retry logic with longer delays for rate limiting (429 errors)
 # We use __retry_file_operation directly since we need CSV, not JSON validation
 local COUNTRIES_QUERY_FILE="${TMP_DIR}/countries_query.op"
 local COUNTRIES_OUTPUT_FILE="${TMP_DIR}/countries_output.log"
 cp "${OVERPASS_COUNTRIES}" "${COUNTRIES_QUERY_FILE}"
 local MAX_RETRIES_COUNTRIES="${OVERPASS_RETRIES_PER_ENDPOINT:-7}"
 local BASE_DELAY_COUNTRIES="${OVERPASS_BACKOFF_SECONDS:-20}"
 local COUNTRIES_DOWNLOAD_OPERATION
 if [[ -n "${DOWNLOAD_USER_AGENT:-}" ]]; then
  COUNTRIES_DOWNLOAD_OPERATION="wget -O ${COUNTRIES_BOUNDARY_IDS_FILE} --header=\"User-Agent: ${DOWNLOAD_USER_AGENT}\" --post-file=${COUNTRIES_QUERY_FILE} ${OVERPASS_INTERPRETER} 2> ${COUNTRIES_OUTPUT_FILE}"
 else
  COUNTRIES_DOWNLOAD_OPERATION="wget -O ${COUNTRIES_BOUNDARY_IDS_FILE} --post-file=${COUNTRIES_QUERY_FILE} ${OVERPASS_INTERPRETER} 2> ${COUNTRIES_OUTPUT_FILE}"
 fi
 local COUNTRIES_CLEANUP="rm -f ${COUNTRIES_BOUNDARY_IDS_FILE} ${COUNTRIES_OUTPUT_FILE} 2>/dev/null || true"
 if ! __retry_file_operation "${COUNTRIES_DOWNLOAD_OPERATION}" "${MAX_RETRIES_COUNTRIES}" "${BASE_DELAY_COUNTRIES}" "${COUNTRIES_CLEANUP}" "true" "${OVERPASS_INTERPRETER}"; then
  __loge "ERROR: Country list could not be downloaded after retries."
  # Check if it's a 429 error and suggest waiting
  if grep -q "429\|Too Many Requests" "${COUNTRIES_OUTPUT_FILE}" 2> /dev/null; then
   __loge "Rate limiting detected (429). Please wait a few minutes and try again."
   __loge "You may want to reduce MAX_THREADS or run during off-peak hours."
  fi
  __handle_error_with_cleanup "${ERROR_DOWNLOADING_BOUNDARY_ID_LIST}" \
   "Country list download failed" \
   "__preserve_failed_boundary_artifacts '${COUNTRIES_BOUNDARY_IDS_FILE}'"
  local HANDLER_RETURN_CODE=$?
  __log_finish
  return "${HANDLER_RETURN_CODE}"
 fi
 # Validate the downloaded CSV file has content (skip JSON validation for CSV)
 if [[ ! -s "${COUNTRIES_BOUNDARY_IDS_FILE}" ]]; then
  __loge "ERROR: Country list file is empty after download."
  __handle_error_with_cleanup "${ERROR_DOWNLOADING_BOUNDARY_ID_LIST}" \
   "Country list file is empty" \
   "__preserve_failed_boundary_artifacts '${COUNTRIES_BOUNDARY_IDS_FILE}'"
  local HANDLER_RETURN_CODE=$?
  __log_finish
  return "${HANDLER_RETURN_CODE}"
 fi
 # Validate it's CSV format (should start with @id or have at least one line with numbers)
 if ! head -1 "${COUNTRIES_BOUNDARY_IDS_FILE}" | grep -qE "^@id|^[0-9]+"; then
  __logw "Warning: Country list file may not be in expected CSV format"
  __logd "First line of file: $(head -1 "${COUNTRIES_BOUNDARY_IDS_FILE}")"
 fi

 tail -n +2 "${COUNTRIES_BOUNDARY_IDS_FILE}" > "${COUNTRIES_BOUNDARY_IDS_FILE}.tmp"
 mv "${COUNTRIES_BOUNDARY_IDS_FILE}.tmp" "${COUNTRIES_BOUNDARY_IDS_FILE}"

 # Areas not at country level.
 {
  # Adds the Gaza Strip
  echo "1703814"
  # Adds Judea and Samaria.
  echo "1803010"
  # Adds the Bhutan - China dispute.
  echo "12931402"
  # Adds Ilemi Triangle
  echo "192797"
  # Adds Neutral zone Burkina Faso - Benin
  echo "12940096"
  # Adds Bir Tawil
  echo "3335661"
  # Adds Jungholz, Austria
  echo "37848"
  # Adds Antarctica areas
  echo "3394112" # British Antarctic
  echo "3394110" # Argentine Antarctic
  echo "3394115" # Chilean Antarctic
  echo "3394113" # Ross dependency
  echo "3394111" # Australian Antarctic
  echo "3394114" # Adelia Land
  echo "3245621" # Queen Maud Land
  echo "2955118" # Peter I Island
  echo "2186646" # Antarctica continent
 } >> "${COUNTRIES_BOUNDARY_IDS_FILE}"

 # Compare IDs with backup before processing
 # Skip backup if FORCE_OVERPASS_DOWNLOAD is set (update mode detected changes)
 # Also skip backup if SKIP_DB_IMPORT is set (download-only mode - need individual GeoJSON files)
 local RESOLVED_BACKUP=""
 if [[ -z "${FORCE_OVERPASS_DOWNLOAD:-}" ]] && [[ -z "${SKIP_DB_IMPORT:-}" ]] && [[ -n "${REPO_COUNTRIES_BACKUP}" ]] && __resolve_geojson_file "${REPO_COUNTRIES_BACKUP}" "RESOLVED_BACKUP" 2> /dev/null; then
  __logi "Comparing country IDs with backup..."
  if __compareIdsWithBackup "${COUNTRIES_BOUNDARY_IDS_FILE}" "${RESOLVED_BACKUP}" "countries"; then
   __logi "Country IDs match backup, importing from backup..."
   # Import backup directly using ogr2ogr (don't use __processBoundary as it requires ID variable)
   # Note: Import without -sql to let ogr2ogr handle column mapping automatically
   # The GeoJSON already has the correct columns: country_id, country_name, country_name_es, country_name_en, geometry
   __logd "Importing backup using ogr2ogr..."
   local OGR_ERROR
   OGR_ERROR=$(mktemp)
   if ogr2ogr -f "PostgreSQL" "PG:dbname=${DBNAME}" "${RESOLVED_BACKUP}" \
    -nln "countries" -nlt PROMOTE_TO_MULTI -a_srs EPSG:4326 \
    -lco GEOMETRY_NAME=geom -lco FID=country_id \
    --config PG_USE_COPY YES 2> "${OGR_ERROR}"; then
    # Fix SRID: GeoJSON doesn't include CRS info, ogr2ogr may not set SRID correctly
    # This is critical for spatial queries to work (ST_Contains fails with mixed SRIDs)
    __logd "Ensuring SRID is set to 4326 for all geometries..."
    if psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -c "UPDATE countries SET geom = ST_SetSRID(geom, 4326) WHERE ST_SRID(geom) = 0 OR ST_SRID(geom) IS NULL;" >> "${OGR_ERROR}" 2>&1; then
     __logi "Successfully imported countries from backup and fixed SRID"
     rm -f "${OGR_ERROR}"
     __log_finish
     return 0
    else
     __logw "Import succeeded but SRID fix failed (non-critical)"
     __logd "SRID fix error: $(cat "${OGR_ERROR}" 2> /dev/null || echo 'No error output')"
     rm -f "${OGR_ERROR}"
     __log_finish
     return 0
    fi
   else
    __logw "Failed to import from backup, falling back to Overpass download"
    __logd "ogr2ogr error output: $(cat "${OGR_ERROR}" 2> /dev/null || echo 'No error output')"
    rm -f "${OGR_ERROR}"
   fi
  else
   __logi "Country IDs differ from backup, will import backup and download only missing countries..."
   # Get missing IDs file path (created by __compareIdsWithBackup)
   local MISSING_IDS_FILE="${TMP_DIR}/missing_countries_ids.txt"
   local EXISTING_IDS_FILE="${TMP_DIR}/existing_countries_ids.txt"

   # If FORCE_OVERPASS_DOWNLOAD or SKIP_DB_IMPORT is set, skip backup import and download all from Overpass
   if [[ -n "${FORCE_OVERPASS_DOWNLOAD:-}" ]] || [[ -n "${SKIP_DB_IMPORT:-}" ]]; then
    if [[ -n "${SKIP_DB_IMPORT:-}" ]]; then
     __logi "SKIP_DB_IMPORT is set, skipping backup import to generate individual GeoJSON files from Overpass"
    else
     __logi "FORCE_OVERPASS_DOWNLOAD is set, skipping backup import to get updated geometries from Overpass"
    fi
    unset MISSING_IDS_FILE
   else
    # Import backup first, but filter to only include countries that exist in Overpass
    local EXISTING_COUNT=0
    if [[ -f "${EXISTING_IDS_FILE}" ]] && [[ -s "${EXISTING_IDS_FILE}" ]]; then
     EXISTING_COUNT=$(wc -l < "${EXISTING_IDS_FILE}" | tr -d ' ' || echo "0")
    fi

    if [[ "${EXISTING_COUNT}" -gt 0 ]]; then
     __logi "Filtering backup to import only ${EXISTING_COUNT} countries that exist in Overpass..."
     # Create WHERE clause for ogr2ogr to filter by country_id
     # Convert IDs file to comma-separated list for SQL IN clause
     local IDS_LIST
     IDS_LIST=$(tr '\n' ',' < "${EXISTING_IDS_FILE}" | sed 's/,$//' || echo "")
     if [[ -n "${IDS_LIST}" ]]; then
      # Import filtered backup using ogr2ogr
      # Note: We need to filter by country_id, but ogr2ogr doesn't support WHERE directly
      # So we'll import to a temp table first, then filter and insert
      local OGR_ERROR
      OGR_ERROR=$(mktemp)
      local TEMP_TABLE="countries_backup_import"
      if ogr2ogr -f "PostgreSQL" "PG:dbname=${DBNAME}" "${RESOLVED_BACKUP}" \
       -nln "${TEMP_TABLE}" -nlt PROMOTE_TO_MULTI -a_srs EPSG:4326 \
       -lco GEOMETRY_NAME=geom -lco FID=country_id \
       --config PG_USE_COPY YES 2> "${OGR_ERROR}"; then
       # Filter and insert only countries that exist in Overpass
       # Use UPSERT to handle conflicts if boundary already exists
       # Fixed: Ensure SRID 4326 is preserved (GeoJSON doesn't include CRS info)
       if psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -c "INSERT INTO countries (country_id, country_name, country_name_es, country_name_en, geom) SELECT country_id, country_name, country_name_es, country_name_en, ST_SetSRID(geom, 4326) FROM ${TEMP_TABLE} WHERE country_id IN (${IDS_LIST}) ON CONFLICT (country_id) DO UPDATE SET country_name = EXCLUDED.country_name, country_name_es = EXCLUDED.country_name_es, country_name_en = EXCLUDED.country_name_en, geom = ST_SetSRID(EXCLUDED.geom, 4326); DROP TABLE ${TEMP_TABLE};" >> "${OGR_ERROR}" 2>&1; then
        rm -f "${OGR_ERROR}"
        __logi "Successfully imported ${EXISTING_COUNT} existing countries from backup"
        # Verify that all existing countries were imported successfully
        # Remove imported IDs from missing list to prevent duplicate processing
        if [[ -f "${MISSING_IDS_FILE:-}" ]] && [[ -s "${MISSING_IDS_FILE}" ]]; then
         local TEMP_MISSING
         TEMP_MISSING=$(mktemp)
         # Remove existing IDs from missing list
         comm -23 <(sort "${MISSING_IDS_FILE}") <(sort "${EXISTING_IDS_FILE}") > "${TEMP_MISSING}" 2> /dev/null || true
         if [[ -s "${TEMP_MISSING}" ]]; then
          mv "${TEMP_MISSING}" "${MISSING_IDS_FILE}"
         else
          rm -f "${TEMP_MISSING}"
          # No missing IDs remaining, unset the file to skip download
          unset MISSING_IDS_FILE
         fi
        fi
       else
        __logw "Failed to filter and insert from backup, will download all from Overpass"
        psql -d "${DBNAME}" -c "DROP TABLE IF EXISTS ${TEMP_TABLE};" > /dev/null 2>&1 || true
        __logd "SQL error output: $(cat "${OGR_ERROR}" 2> /dev/null || echo 'No error output')"
        rm -f "${OGR_ERROR}"
        unset MISSING_IDS_FILE
       fi
      else
       __logw "Failed to import backup, will download all from Overpass"
       __logd "ogr2ogr error output: $(cat "${OGR_ERROR}" 2> /dev/null || echo 'No error output')"
       rm -f "${OGR_ERROR}"
       unset MISSING_IDS_FILE
      fi
     else
      __logw "Could not create ID list for filtering, will download all from Overpass"
      unset MISSING_IDS_FILE
     fi
    else
     __logw "No existing countries found in backup, will download all from Overpass"
     unset MISSING_IDS_FILE
    fi
   fi

   # Skip the original import logic since we already imported filtered backup above
   # If import failed, MISSING_IDS_FILE was unset and we'll download all from Overpass

   # If FORCE_OVERPASS_DOWNLOAD is set, download ALL countries from Overpass (not just missing)
   if [[ -n "${FORCE_OVERPASS_DOWNLOAD:-}" ]]; then
    __logi "FORCE_OVERPASS_DOWNLOAD is set, will download all countries from Overpass to get updated geometries"
    # Use the full COUNTRIES_BOUNDARY_IDS_FILE (all countries from Overpass)
    # Don't filter by missing IDs - we want to update all geometries
   elif [[ -n "${MISSING_IDS_FILE:-}" ]] && [[ -f "${MISSING_IDS_FILE}" ]] && [[ -s "${MISSING_IDS_FILE}" ]]; then
    # If we have missing IDs file, filter COUNTRIES_BOUNDARY_IDS_FILE to only include missing ones
    local MISSING_COUNT
    MISSING_COUNT=$(wc -l < "${MISSING_IDS_FILE}" | tr -d ' ' || echo "0")
    if [[ "${MISSING_COUNT}" -gt 0 ]]; then
     __logi "Filtering to download only ${MISSING_COUNT} missing countries..."
     cp "${MISSING_IDS_FILE}" "${COUNTRIES_BOUNDARY_IDS_FILE}"
    else
     __logi "No missing countries to download, all are in backup"
     __log_finish
     return 0
    fi
   fi
  fi
 fi

 TOTAL_LINES=$(wc -l < "${COUNTRIES_BOUNDARY_IDS_FILE}")
 __logi "Total countries to process: ${TOTAL_LINES}"
 SIZE=$((TOTAL_LINES / MAX_THREADS))
 SIZE=$((SIZE + 1))
 __logd "Total countries: ${TOTAL_LINES}"
 __logd "Max threads: ${MAX_THREADS}"
 __logd "Size per part: ${SIZE}"
 split -l"${SIZE}" "${COUNTRIES_BOUNDARY_IDS_FILE}" "${TMP_DIR}/part_country_"
 if [[ -d "${LOCK_OGR2OGR}" ]]; then
  rm -f "${LOCK_OGR2OGR}/pid"
  rmdir "${LOCK_OGR2OGR}"
 fi
 __logw "Starting background process to process country boundaries..."

 # Create a file to track job status
 local JOB_STATUS_FILE="${TMP_DIR}/job_status.txt"
 rm -f "${JOB_STATUS_FILE}"

 for I in "${TMP_DIR}"/part_country_??; do
  (
   export PATH="${PATH}"
   local SUBSHELL_PID
   SUBSHELL_PID="${BASHPID}"
   __logi "Starting list ${I} - ${SUBSHELL_PID}."
   # shellcheck disable=SC2154
   local PROCESS_LIST_RET
   if __processList "${I}" >> "${LOG_FILENAME}.${SUBSHELL_PID}" 2>&1; then
    echo "SUCCESS:${SUBSHELL_PID}:${I}" >> "${JOB_STATUS_FILE}"
    PROCESS_LIST_RET=0
   else
    echo "FAILED:${SUBSHELL_PID}:${I}" >> "${JOB_STATUS_FILE}"
    PROCESS_LIST_RET=1
   fi
   __logi "Finished list ${I} - ${SUBSHELL_PID}."
   if [[ -n "${CLEAN:-}" ]] && [[ "${CLEAN}" = true ]]; then
    rm -f "${LOG_FILENAME}.${SUBSHELL_PID}"
   else
    mv "${LOG_FILENAME}.${SUBSHELL_PID}" "${TMP_DIR}/${BASENAME}.old.${SUBSHELL_PID}"
   fi
   exit "${PROCESS_LIST_RET}"
  ) &
  __logi "Check log per thread for more information."
  sleep 2
 done

 # Wait for all background jobs to complete
 __logw "Waiting for all background jobs to complete - countries."
 local TOTAL_JOBS
 TOTAL_JOBS=$(jobs -p | wc -l)
 __logi "Total jobs running: ${TOTAL_JOBS}"

 for JOB in $(jobs -p); do
  set +e # Allow errors in wait
  __logi "Waiting for job ${JOB} to complete..."
  wait "${JOB}"
  WAIT_EXIT_CODE=$?
  set -e
  if [[ ${WAIT_EXIT_CODE} -ne 0 ]]; then
   __logw "Thread ${JOB} exited with code ${WAIT_EXIT_CODE}"
  else
   __logi "Job ${JOB} completed successfully"
  fi
 done

 __logi "All jobs reported completion. Verifying job status..."

 # Check job status file for detailed error information
 local FAIL=0
 local FAILED_JOBS=()
 local FAILED_JOBS_INFO=""

 if [[ -f "${JOB_STATUS_FILE}" ]]; then
  local FAILED_COUNT=0
  local SUCCESS_COUNT=0
  local TOTAL_JOBS=0
  while IFS=':' read -r status pid file; do
   TOTAL_JOBS=$((TOTAL_JOBS + 1))
   if [[ "${status}" == "FAILED" ]]; then
    FAILED_COUNT=$((FAILED_COUNT + 1))
    FAIL=$((FAIL + 1))
    FAILED_JOBS+=("${pid}")
    if [[ -f "${TMP_DIR}/${BASENAME}.old.${pid}" ]]; then
     FAILED_JOBS_INFO="${FAILED_JOBS_INFO} ${pid}:${TMP_DIR}/${BASENAME}.old.${pid}"
    fi
    __loge "Job ${pid} failed processing file: ${file}"
   elif [[ "${status}" == "SUCCESS" ]]; then
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
   fi
  done < "${JOB_STATUS_FILE}"

  __logi "Job summary: ${SUCCESS_COUNT} successful, ${FAILED_COUNT} failed"
 fi

 if [[ "${FAIL}" -ne 0 ]]; then
  __loge "FAIL! (${FAIL}) - Failed jobs: ${FAILED_JOBS[*]}. Check individual log files for detailed error information:${FAILED_JOBS_INFO}"
  __loge "=== COUNTRIES PROCESSING FAILED ==="
  __loge "Continuing to allow remaining threads to finish..."
  # Return instead of exit to avoid killing child threads
  local ERROR_MESSAGE="Boundary processing failed for jobs: ${FAILED_JOBS[*]}"
  local CLEANUP_COMMAND="__preserve_failed_boundary_artifacts '${FAILED_JOBS_INFO}'"
  __handle_error_with_cleanup "${ERROR_DOWNLOADING_BOUNDARY}" \
   "${ERROR_MESSAGE}" "${CLEANUP_COMMAND}"
  __log_finish
  return "${ERROR_DOWNLOADING_BOUNDARY}"
 fi

 __logi "=== COUNTRIES PROCESSING COMPLETED SUCCESSFULLY ==="

 # If some of the threads generated an error.
 set +e
 QTY_LOGS=$(find "${TMP_DIR}" -maxdepth 1 -type f -name "${BASENAME}.log.*" | wc -l)
 set -e
 if [[ "${QTY_LOGS}" -ne 0 ]]; then
  __logw "Some threads generated errors."
  if [[ "${CONTINUE_ON_OVERPASS_ERROR:-false}" == "true" ]]; then
   __logw "CONTINUE_ON_OVERPASS_ERROR=true - Recording failed boundaries and continuing"
   # Extract failed boundary IDs from error logs and consolidate into failed_boundaries.txt
   local FAILED_BOUNDARIES_FILE="${TMP_DIR}/failed_boundaries.txt"
   # Ensure failed_boundaries.txt exists (may have been created by __processBoundary)
   touch "${FAILED_BOUNDARIES_FILE}" 2> /dev/null || true
   for ERROR_LOG in "${TMP_DIR}/${BASENAME}.old."* "${TMP_DIR}/${BASENAME}.log."*; do
    if [[ -f "${ERROR_LOG}" ]]; then
     # Extract boundary IDs that failed from the log file
     # Look for lines indicating failed boundaries:
     # - "Failed to process boundary ${ID}" from __processList
     # - "Recording boundary ${ID} as failed" from __processBoundary_impl
     grep -hE "Failed to process boundary [0-9]+|Recording boundary [0-9]+ as failed" "${ERROR_LOG}" 2> /dev/null \
      | grep -oE "[0-9]+" \
      | while read -r FAILED_ID; do
       if [[ -n "${FAILED_ID}" ]] && [[ "${FAILED_ID}" =~ ^[0-9]+$ ]]; then
        # Add to failed_boundaries.txt if not already present
        if ! grep -q "^${FAILED_ID}$" "${FAILED_BOUNDARIES_FILE}" 2> /dev/null; then
         echo "${FAILED_ID}" >> "${FAILED_BOUNDARIES_FILE}"
         __logd "Recorded failed country boundary ID: ${FAILED_ID}"
        fi
       fi
      done || true
    fi
   done
   # Also check if failed_boundaries.txt already exists from __processBoundary calls
   if [[ -f "${FAILED_BOUNDARIES_FILE}" ]]; then
    local FAILED_COUNT
    FAILED_COUNT=$(wc -l < "${FAILED_BOUNDARIES_FILE}" 2> /dev/null | tr -d ' ' || echo "0")
    if [[ "${FAILED_COUNT}" -gt 0 ]]; then
     __logw "Total failed country boundaries recorded: ${FAILED_COUNT}"
     __logw "Failed boundaries list: ${FAILED_BOUNDARIES_FILE}"
    fi
   fi
   local ERROR_LOGS
   ERROR_LOGS=$(find "${TMP_DIR}" -maxdepth 1 -type f -name "${BASENAME}.log.*" | tr '\n' ' ')
   __logw "Found ${QTY_LOGS} error log files. Check them for details: ${ERROR_LOGS}"
   __logw "Continuing despite error logs (CONTINUE_ON_OVERPASS_ERROR=true)"
  else
   local ERROR_LOGS
   ERROR_LOGS=$(find "${TMP_DIR}" -maxdepth 1 -type f -name "${BASENAME}.log.*" | tr '\n' ' ')
   __loge "Found ${QTY_LOGS} error log files. Check them for details: ${ERROR_LOGS}"
   __handle_error_with_cleanup "${ERROR_DOWNLOADING_BOUNDARY}" \
    "Thread error logs detected for boundary processing" \
    "__preserve_failed_boundary_artifacts '${ERROR_LOGS}'"
   __log_finish
   return "${ERROR_DOWNLOADING_BOUNDARY}"
  fi
 fi
 if [[ -d "${LOCK_OGR2OGR}" ]]; then
  rm -f "${LOCK_OGR2OGR}/pid"
  rmdir "${LOCK_OGR2OGR}"
 fi

 __log_finish
}

function __processMaritimes_impl {
 __log_start

 # Determine SCRIPT_BASE_DIRECTORY if not set
 local REPO_MARITIMES_BACKUP
 if [[ -n "${SCRIPT_BASE_DIRECTORY:-}" ]]; then
  REPO_MARITIMES_BACKUP="${SCRIPT_BASE_DIRECTORY}/data/maritimes.geojson"
 else
  # Fallback: try to determine from script location
  local SCRIPT_DIR
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." &> /dev/null && pwd || echo "")"
  if [[ -n "${SCRIPT_DIR}" ]]; then
   REPO_MARITIMES_BACKUP="${SCRIPT_DIR}/data/maritimes.geojson"
  else
   REPO_MARITIMES_BACKUP=""
  fi
 fi

 # Try to use repository backup first (faster, avoids Overpass download)
 # Skip backup if FORCE_OVERPASS_DOWNLOAD is set (update mode detected changes)
 # Also skip backup if SKIP_DB_IMPORT is set (download-only mode - need individual GeoJSON files)
 local RESOLVED_BACKUP=""
 if [[ -z "${FORCE_OVERPASS_DOWNLOAD:-}" ]] && [[ -z "${SKIP_DB_IMPORT:-}" ]] && [[ -n "${REPO_MARITIMES_BACKUP}" ]] && __resolve_geojson_file "${REPO_MARITIMES_BACKUP}" "RESOLVED_BACKUP" 2> /dev/null; then
  __logi "Using repository backup maritime boundaries from ${REPO_MARITIMES_BACKUP}"
  # Import backup directly using ogr2ogr (don't use __processBoundary as it requires ID variable)
  # Note: Import without -sql to let ogr2ogr handle column mapping automatically
  __logd "Importing backup using ogr2ogr..."
  local OGR_ERROR
  OGR_ERROR=$(mktemp)
  if ogr2ogr -f "PostgreSQL" "PG:dbname=${DBNAME}" "${RESOLVED_BACKUP}" \
   -nln "countries" -nlt PROMOTE_TO_MULTI -a_srs EPSG:4326 \
   -lco GEOMETRY_NAME=geom -lco FID=country_id \
   --config PG_USE_COPY YES 2> "${OGR_ERROR}"; then
   __logi "Successfully imported maritime boundaries from backup"
   rm -f "${OGR_ERROR}"
   __log_finish
   return 0
  else
   __logw "Failed to import from backup, falling back to Overpass download"
   __logd "ogr2ogr error output: $(cat "${OGR_ERROR}" 2> /dev/null || echo 'No error output')"
   rm -f "${OGR_ERROR}"
  fi
 fi

 # No backup available or backup import failed - proceed with Overpass download
 if [[ -n "${FORCE_OVERPASS_DOWNLOAD:-}" ]]; then
  __logi "FORCE_OVERPASS_DOWNLOAD is set, downloading from Overpass to get updated geometries..."
 else
  __logi "No backup found or backup import failed, downloading from Overpass..."
 fi

 # Check disk space before downloading maritime boundaries
 # Maritime boundaries requirements:
 # - Maritime JSON files: ~1 GB
 # - GeoJSON conversions: ~0.5 GB
 # - Temporary files: ~0.3 GB
 # - Safety margin (20%): ~0.4 GB
 # Total estimated: ~2.5 GB
 __logi "Validating disk space for maritime boundaries download..."
 if ! __check_disk_space "${TMP_DIR}" "2.5" "Maritime boundaries download and processing"; then
  __loge "Cannot proceed with maritime boundaries download due to insufficient disk space"
  __handle_error_with_cleanup "${ERROR_GENERAL}" "Insufficient disk space for maritime boundaries" \
   "echo 'No cleanup needed - download not started'"
 fi

 # Extracts ids of all EEZ relations into a JSON.
 __logi "Obtaining the eez ids."
 set +e
 if [[ -n "${DOWNLOAD_USER_AGENT:-}" ]]; then
  wget -O "${MARITIME_BOUNDARY_IDS_FILE}" --header="User-Agent: ${DOWNLOAD_USER_AGENT}" --post-file="${OVERPASS_MARITIMES}" \
   "${OVERPASS_INTERPRETER}"
 else
  wget -O "${MARITIME_BOUNDARY_IDS_FILE}" --post-file="${OVERPASS_MARITIMES}" \
   "${OVERPASS_INTERPRETER}"
 fi
 RET=${?}
 set -e
 if [[ "${RET}" -ne 0 ]]; then
  __loge "ERROR: Maritime border list could not be downloaded."
  exit "${ERROR_DOWNLOADING_BOUNDARY_ID_LIST}"
 fi

 tail -n +2 "${MARITIME_BOUNDARY_IDS_FILE}" > "${MARITIME_BOUNDARY_IDS_FILE}.tmp"
 mv "${MARITIME_BOUNDARY_IDS_FILE}.tmp" "${MARITIME_BOUNDARY_IDS_FILE}"

 # Compare IDs with backup before processing
 # Skip backup if FORCE_OVERPASS_DOWNLOAD is set (update mode detected changes)
 # Also skip backup if SKIP_DB_IMPORT is set (download-only mode - need individual GeoJSON files)
 local RESOLVED_MARITIMES_BACKUP=""
 if [[ -z "${FORCE_OVERPASS_DOWNLOAD:-}" ]] && [[ -z "${SKIP_DB_IMPORT:-}" ]] && [[ -n "${REPO_MARITIMES_BACKUP}" ]] && __resolve_geojson_file "${REPO_MARITIMES_BACKUP}" "RESOLVED_MARITIMES_BACKUP" 2> /dev/null; then
  __logi "Comparing maritime IDs with backup..."
  if __compareIdsWithBackup "${MARITIME_BOUNDARY_IDS_FILE}" "${RESOLVED_MARITIMES_BACKUP}" "maritimes"; then
   __logi "Maritime IDs match backup, importing from backup..."
   # Import backup directly using ogr2ogr (don't use __processBoundary as it requires ID variable)
   # Note: Import without -sql to let ogr2ogr handle column mapping automatically
   __logd "Importing backup using ogr2ogr..."
   local OGR_ERROR
   OGR_ERROR=$(mktemp)
   if ogr2ogr -f "PostgreSQL" "PG:dbname=${DBNAME}" "${RESOLVED_MARITIMES_BACKUP}" \
    -nln "countries" -nlt PROMOTE_TO_MULTI -a_srs EPSG:4326 \
    -lco GEOMETRY_NAME=geom -lco FID=country_id \
    --config PG_USE_COPY YES 2> "${OGR_ERROR}"; then
    __logi "Successfully imported maritime boundaries from backup"
    rm -f "${OGR_ERROR}"
    __log_finish
    return 0
   else
    __logw "Failed to import from backup, falling back to Overpass download"
    __logd "ogr2ogr error output: $(cat "${OGR_ERROR}" 2> /dev/null || echo 'No error output')"
    rm -f "${OGR_ERROR}"
   fi
  else
   __logi "Maritime IDs differ from backup, will import backup and download only missing maritimes..."
   # Get missing IDs file path (created by __compareIdsWithBackup)
   local MISSING_IDS_FILE="${TMP_DIR}/missing_maritimes_ids.txt"
   local EXISTING_IDS_FILE="${TMP_DIR}/existing_maritimes_ids.txt"

   # If FORCE_OVERPASS_DOWNLOAD or SKIP_DB_IMPORT is set, skip backup import and download all from Overpass
   if [[ -n "${FORCE_OVERPASS_DOWNLOAD:-}" ]] || [[ -n "${SKIP_DB_IMPORT:-}" ]]; then
    if [[ -n "${SKIP_DB_IMPORT:-}" ]]; then
     __logi "SKIP_DB_IMPORT is set, skipping backup import to generate individual GeoJSON files from Overpass"
    else
     __logi "FORCE_OVERPASS_DOWNLOAD is set, skipping backup import to get updated geometries from Overpass"
    fi
    unset MISSING_IDS_FILE
   else
    # Import backup first, but filter to only include maritimes that exist in Overpass
    local EXISTING_COUNT=0
    if [[ -f "${EXISTING_IDS_FILE}" ]] && [[ -s "${EXISTING_IDS_FILE}" ]]; then
     EXISTING_COUNT=$(wc -l < "${EXISTING_IDS_FILE}" | tr -d ' ' || echo "0")
    fi

    if [[ "${EXISTING_COUNT}" -gt 0 ]]; then
     __logi "Filtering backup to import only ${EXISTING_COUNT} maritime boundaries that exist in Overpass..."
     # Create WHERE clause for ogr2ogr to filter by country_id
     local IDS_LIST
     IDS_LIST=$(tr '\n' ',' < "${EXISTING_IDS_FILE}" | sed 's/,$//' || echo "")
     if [[ -n "${IDS_LIST}" ]]; then
      # Import to temp table first, then filter and insert
      local OGR_ERROR
      OGR_ERROR=$(mktemp)
      local TEMP_TABLE="maritimes_backup_import"
      if ogr2ogr -f "PostgreSQL" "PG:dbname=${DBNAME}" "${RESOLVED_MARITIMES_BACKUP}" \
       -nln "${TEMP_TABLE}" -nlt PROMOTE_TO_MULTI -a_srs EPSG:4326 \
       -lco GEOMETRY_NAME=geom -lco FID=country_id \
       --config PG_USE_COPY YES 2> "${OGR_ERROR}"; then
       # Filter and insert only maritimes that exist in Overpass
       # Use UPSERT to handle conflicts if boundary already exists
       # Fixed: Ensure SRID 4326 is preserved (GeoJSON doesn't include CRS info)
       if psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -c "INSERT INTO countries (country_id, country_name, country_name_es, country_name_en, geom) SELECT country_id, country_name, country_name_es, country_name_en, ST_SetSRID(geom, 4326) FROM ${TEMP_TABLE} WHERE country_id IN (${IDS_LIST}) ON CONFLICT (country_id) DO UPDATE SET country_name = EXCLUDED.country_name, country_name_es = EXCLUDED.country_name_es, country_name_en = EXCLUDED.country_name_en, geom = ST_SetSRID(EXCLUDED.geom, 4326); DROP TABLE ${TEMP_TABLE};" >> "${OGR_ERROR}" 2>&1; then
        __logi "Successfully imported ${EXISTING_COUNT} existing maritime boundaries from backup"
        rm -f "${OGR_ERROR}"
       else
        __logw "Failed to filter and insert from backup, will download all from Overpass"
        psql -d "${DBNAME}" -c "DROP TABLE IF EXISTS ${TEMP_TABLE};" > /dev/null 2>&1 || true
        __logd "SQL error output: $(cat "${OGR_ERROR}" 2> /dev/null || echo 'No error output')"
        rm -f "${OGR_ERROR}"
        unset MISSING_IDS_FILE
       fi
      else
       __logw "Failed to import backup, will download all from Overpass"
       __logd "ogr2ogr error output: $(cat "${OGR_ERROR}" 2> /dev/null || echo 'No error output')"
       rm -f "${OGR_ERROR}"
       unset MISSING_IDS_FILE
      fi
     else
      __logw "Could not create ID list for filtering, will download all from Overpass"
      unset MISSING_IDS_FILE
     fi
    else
     __logw "No existing maritime boundaries found in backup, will download all from Overpass"
     unset MISSING_IDS_FILE
    fi
   fi

   # Skip the original import logic since we already imported filtered backup above
   # If import failed, MISSING_IDS_FILE was unset and we'll download all from Overpass

   # If we have missing IDs file, filter MARITIME_BOUNDARY_IDS_FILE to only include missing ones
   if [[ -n "${MISSING_IDS_FILE:-}" ]] && [[ -f "${MISSING_IDS_FILE}" ]] && [[ -s "${MISSING_IDS_FILE}" ]]; then
    local MISSING_COUNT
    MISSING_COUNT=$(wc -l < "${MISSING_IDS_FILE}" | tr -d ' ' || echo "0")
    if [[ "${MISSING_COUNT}" -gt 0 ]]; then
     __logi "Filtering to download only ${MISSING_COUNT} missing maritime boundaries..."
     cp "${MISSING_IDS_FILE}" "${MARITIME_BOUNDARY_IDS_FILE}"
    else
     __logi "No missing maritime boundaries to download, all are in backup"
     __log_finish
     return 0
    fi
   fi
  fi
 fi

 TOTAL_LINES=$(wc -l < "${MARITIME_BOUNDARY_IDS_FILE}")
 __logi "Total maritime areas to process: ${TOTAL_LINES}"
 SIZE=$((TOTAL_LINES / MAX_THREADS))
 SIZE=$((SIZE + 1))
 split -l"${SIZE}" "${MARITIME_BOUNDARY_IDS_FILE}" "${TMP_DIR}/part_maritime_"
 if [[ -d "${LOCK_OGR2OGR}" ]]; then
  rm -f "${LOCK_OGR2OGR}/pid"
  rmdir "${LOCK_OGR2OGR}"
 fi
 __logw "Starting background process to process maritime boundaries..."
 for I in "${TMP_DIR}"/part_maritime_??; do
  (
   export PATH="${PATH}"
   __logi "Starting list ${I} - ${BASHPID}."
   __processList "${I}" >> "${LOG_FILENAME}.${BASHPID}" 2>&1
   __logi "Finished list ${I} - ${BASHPID}."
   if [[ -n "${CLEAN:-}" ]] && [[ "${CLEAN}" = true ]]; then
    rm -f "${LOG_FILENAME}.${BASHPID}"
   else
    mv "${LOG_FILENAME}.${BASHPID}" "${TMP_DIR}/${BASENAME}.old.${BASHPID}"
   fi
  ) &
  __logi "Check log per thread for more information."
  sleep 2
 done

 __logw "Waiting for all background jobs to complete - maritimes."
 local TOTAL_MARITIME_JOBS
 TOTAL_MARITIME_JOBS=$(jobs -p | wc -l)
 __logi "Total maritime jobs running: ${TOTAL_MARITIME_JOBS}"

 FAIL=0
 for JOB in $(jobs -p); do
  __logi "Waiting for maritime job ${JOB} to complete..."
  set +e
  wait "${JOB}"
  RET="${?}"
  set -e
  if [[ "${RET}" -ne 0 ]]; then
   FAIL=$((FAIL + 1))
   __logw "Maritime job ${JOB} exited with code ${RET}"
  else
   __logi "Maritime job ${JOB} completed successfully"
  fi
 done
 __logw "All maritime jobs reported completion."
 if [[ "${FAIL}" -ne 0 ]]; then
  __loge "FAIL! (${FAIL}) - Some maritime jobs failed"
  if [[ "${CONTINUE_ON_OVERPASS_ERROR:-false}" == "true" ]]; then
   __logw "CONTINUE_ON_OVERPASS_ERROR=true - Recording failed boundaries and continuing"
   # Extract failed boundary IDs from job logs and consolidate into failed_boundaries.txt
   local FAILED_BOUNDARIES_FILE="${TMP_DIR}/failed_boundaries.txt"
   # Ensure failed_boundaries.txt exists (may have been created by __processBoundary)
   touch "${FAILED_BOUNDARIES_FILE}" 2> /dev/null || true
   for JOB_LOG in "${TMP_DIR}/${BASENAME}.old."*; do
    if [[ -f "${JOB_LOG}" ]]; then
     # Extract boundary IDs that failed from the log file
     # Look for lines indicating failed boundaries:
     # - "Failed to process boundary ${ID}" from __processList
     # - "Recording boundary ${ID} as failed" from __processBoundary_impl
     grep -hE "Failed to process boundary [0-9]+|Recording boundary [0-9]+ as failed" "${JOB_LOG}" 2> /dev/null \
      | grep -oE "[0-9]+" \
      | while read -r FAILED_ID; do
       if [[ -n "${FAILED_ID}" ]] && [[ "${FAILED_ID}" =~ ^[0-9]+$ ]]; then
        # Add to failed_boundaries.txt if not already present
        if ! grep -q "^${FAILED_ID}$" "${FAILED_BOUNDARIES_FILE}" 2> /dev/null; then
         echo "${FAILED_ID}" >> "${FAILED_BOUNDARIES_FILE}"
         __logd "Recorded failed maritime boundary ID: ${FAILED_ID}"
        fi
       fi
      done || true
    fi
   done
   # Also check if failed_boundaries.txt already exists from __processBoundary calls
   if [[ -f "${FAILED_BOUNDARIES_FILE}" ]]; then
    local FAILED_COUNT
    FAILED_COUNT=$(wc -l < "${FAILED_BOUNDARIES_FILE}" 2> /dev/null | tr -d ' ' || echo "0")
    __logw "Total failed maritime boundaries recorded: ${FAILED_COUNT}"
    __logw "Failed boundaries list: ${FAILED_BOUNDARIES_FILE}"
   fi
   __logw "Continuing despite ${FAIL} failed maritime job(s) (CONTINUE_ON_OVERPASS_ERROR=true)"
  else
   __loge "CONTINUE_ON_OVERPASS_ERROR=false - Exiting due to failed maritime jobs"
   exit "${ERROR_DOWNLOADING_BOUNDARY}"
  fi
 fi

 # If some of the threads generated an error.
 set +e
 QTY_LOGS=$(find "${TMP_DIR}" -maxdepth 1 -type f -name "${BASENAME}.log.*" | wc -l)
 set -e
 if [[ "${QTY_LOGS}" -ne 0 ]]; then
  __logw "Some threads generated errors."
  if [[ "${CONTINUE_ON_OVERPASS_ERROR:-false}" == "true" ]]; then
   __logw "CONTINUE_ON_OVERPASS_ERROR=true - Continuing despite error logs"
   # Extract failed boundary IDs from error logs
   local FAILED_BOUNDARIES_FILE="${TMP_DIR}/failed_boundaries.txt"
   # Ensure failed_boundaries.txt exists (may have been created by __processBoundary)
   touch "${FAILED_BOUNDARIES_FILE}" 2> /dev/null || true
   for ERROR_LOG in "${TMP_DIR}/${BASENAME}.log."*; do
    if [[ -f "${ERROR_LOG}" ]]; then
     # Extract boundary IDs that failed from error log files
     # Look for lines indicating failed boundaries:
     # - "Failed to process boundary ${ID}" from __processList
     # - "Recording boundary ${ID} as failed" from __processBoundary_impl
     grep -hE "Failed to process boundary [0-9]+|Recording boundary [0-9]+ as failed" "${ERROR_LOG}" 2> /dev/null \
      | grep -oE "[0-9]+" \
      | while read -r FAILED_ID; do
       if [[ -n "${FAILED_ID}" ]] && [[ "${FAILED_ID}" =~ ^[0-9]+$ ]]; then
        if ! grep -q "^${FAILED_ID}$" "${FAILED_BOUNDARIES_FILE}" 2> /dev/null; then
         echo "${FAILED_ID}" >> "${FAILED_BOUNDARIES_FILE}"
         __logd "Recorded failed maritime boundary ID from error log: ${FAILED_ID}"
        fi
       fi
      done || true
    fi
   done
   if [[ -f "${FAILED_BOUNDARIES_FILE}" ]]; then
    local FAILED_COUNT
    FAILED_COUNT=$(wc -l < "${FAILED_BOUNDARIES_FILE}" 2> /dev/null | tr -d ' ' || echo "0")
    __logw "Total failed maritime boundaries recorded: ${FAILED_COUNT}"
   fi
  else
   __loge "CONTINUE_ON_OVERPASS_ERROR=false - Exiting due to error logs"
   exit "${ERROR_DOWNLOADING_BOUNDARY}"
  fi
 fi
 if [[ -d "${LOCK_OGR2OGR}" ]]; then
  rm -f "${LOCK_OGR2OGR}/pid"
  rmdir "${LOCK_OGR2OGR}"
 fi

 __logi "Calculating statistics on countries."
 echo "ANALYZE countries" | psql -d "${DBNAME}" -v ON_ERROR_STOP=1
 __log_finish
}
