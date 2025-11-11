#!/bin/bash

# Boundary Processing Functions for OSM-Notes-profile
# Author: Andres Gomez (AngocA)
# Version: 2025-11-11

VERSION="2025-11-11"

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
  MAX_RETRIES_LOCAL="${OVERPASS_CONTINUE_MAX_RETRIES_PER_ENDPOINT:-1}"
  BASE_DELAY_LOCAL="${OVERPASS_CONTINUE_BASE_DELAY:-5}"
 fi

 # Retry logic for download with validation
 # This includes downloading and validating JSON structure
 local DOWNLOAD_VALIDATION_RETRIES=3
 if [[ "${RUNNING_UNDER_TEST}" == "true" ]]; then
  DOWNLOAD_VALIDATION_RETRIES="${OVERPASS_TEST_VALIDATION_RETRIES:-1}"
 elif [[ "${CONTINUE_ON_OVERPASS_ERROR:-false}" == "true" ]]; then
  DOWNLOAD_VALIDATION_RETRIES="${OVERPASS_CONTINUE_VALIDATION_RETRIES:-1}"
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

 # Special handling for Taiwan (ID: 16239) - remove problematic tags to avoid oversized records
 if [[ "${ID}" -eq 16239 ]]; then
  __log_taiwan_special_handling "${ID}"
  if [[ -f "${GEOJSON_FILE}" ]]; then
   grep -v "official_name" "${GEOJSON_FILE}" \
    | grep -v "alt_name" > "${GEOJSON_FILE}-new"
   mv "${GEOJSON_FILE}-new" "${GEOJSON_FILE}"
  fi
 fi

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

 # Always use field selection to avoid row size issues
 __logd "Using field-selected import for boundary ${ID} to avoid row size issues"

 local IMPORT_OPERATION
 if [[ "${ID}" -eq 16239 ]]; then
  # Austria - use ST_Buffer to fix topology issues
  __logd "Using special handling for Austria (ID: 16239)"
  IMPORT_OPERATION="ogr2ogr -f PostgreSQL PG:dbname=${DBNAME} -nln import -overwrite -skipfailures -nlt Geometry -lco GEOMETRY_NAME=geometry -select name,admin_level,type ${GEOJSON_FILE}"
 else
  # Standard import with field selection to avoid row size issues
  __log_field_selected_import "${ID}"
  IMPORT_OPERATION="ogr2ogr -f PostgreSQL PG:dbname=${DBNAME} -nln import -overwrite -skipfailures -mapFieldType StringList=String -nlt Geometry -lco GEOMETRY_NAME=geometry -select name,admin_level,type ${GEOJSON_FILE}"
 fi

 local IMPORT_CLEANUP="rmdir ${PROCESS_LOCK} 2>/dev/null || true"

 if ! __retry_file_operation "${IMPORT_OPERATION}" 2 5 "${IMPORT_CLEANUP}"; then
  __loge "Failed to import boundary ${ID} into database after retries"
  __handle_error_with_cleanup "${ERROR_GENERAL}" "Database import failed for boundary ${ID}" \
   "rm -f ${JSON_FILE} ${GEOJSON_FILE} 2>/dev/null || true; rmdir ${PROCESS_LOCK} 2>/dev/null || true"
  __log_finish
  return 1
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
  GEOM_CHECK_QUERY="SELECT ST_Union(ST_Buffer(geometry, 0.0)) IS NOT NULL AS has_geom FROM import"
 else
  __logd "Using standard processing with ST_MakeValid for boundary ${ID}"
  GEOM_CHECK_QUERY="SELECT ST_Union(ST_makeValid(geometry)) IS NOT NULL AS has_geom FROM import"
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

  local ALT_QUERY="SELECT ST_Collect(ST_MakeValid(geometry)) IS NOT NULL AS has_geom FROM import"
  local HAS_COLLECT
  HAS_COLLECT=$(psql -d "${DBNAME}" -Atq -c "${ALT_QUERY}" 2> /dev/null || echo "f")

  if [[ "${HAS_COLLECT}" == "t" ]]; then
   __logw "ST_Collect works but not ST_Union - using ST_Collect as alternative"
   if [[ "${ID}" -eq 16239 ]]; then
    PROCESS_OPERATION="psql -d ${DBNAME} -c \"INSERT INTO countries (country_id, country_name, country_name_es, country_name_en, geom) SELECT ${SANITIZED_ID}, '${NAME}', '${NAME_ES}', '${NAME_EN}', ST_Collect(ST_Buffer(geometry, 0.0)) FROM import GROUP BY 1;\""
   else
    PROCESS_OPERATION="psql -d ${DBNAME} -c \"INSERT INTO countries (country_id, country_name, country_name_es, country_name_en, geom) SELECT ${SANITIZED_ID}, '${NAME}', '${NAME_ES}', '${NAME_EN}', ST_Collect(ST_makeValid(geometry)) FROM import GROUP BY 1;\""
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
   local BUFFER_QUERY="SELECT ST_Buffer(ST_MakeValid(geometry), 0.0001) IS NOT NULL AS has_geom FROM import"
   local HAS_BUFFER
   HAS_BUFFER=$(psql -d "${DBNAME}" -Atq -c "${BUFFER_QUERY}" 2> /dev/null || echo "f")

   if [[ "${HAS_BUFFER}" == "t" ]]; then
    __logw "Buffer strategy works - applying buffered geometries"
    PROCESS_OPERATION="psql -d ${DBNAME} -c \"INSERT INTO countries (country_id, country_name, country_name_es, country_name_en, geom) SELECT ${SANITIZED_ID}, '${NAME}', '${NAME_ES}', '${NAME_EN}', ST_Union(ST_Buffer(ST_MakeValid(geometry), 0.0001)) FROM import GROUP BY 1;\""

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
  PROCESS_OPERATION="psql -d ${DBNAME} -c \"INSERT INTO countries (country_id, country_name, country_name_es, country_name_en, geom) SELECT ${SANITIZED_ID}, '${NAME}', '${NAME_ES}', '${NAME_EN}', ST_Union(ST_Buffer(geometry, 0.0)) FROM import GROUP BY 1;\""
 else
  __logd "Preparing to insert boundary ${ID} with standard processing"
  PROCESS_OPERATION="psql -d ${DBNAME} -c \"INSERT INTO countries (country_id, country_name, country_name_es, country_name_en, geom) SELECT ${SANITIZED_ID}, '${NAME}', '${NAME_ES}', '${NAME_EN}', ST_Union(ST_makeValid(geometry)) FROM import GROUP BY 1;\""
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

function __processCountries_impl {
 __log_start
 __logi "=== STARTING COUNTRIES PROCESSING ==="

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

 # Extracts ids of all country relations into a JSON.
 __logi "Obtaining the countries ids."
 set +e
 if [[ -n "${DOWNLOAD_USER_AGENT:-}" ]]; then
  wget -O "${COUNTRIES_BOUNDARY_IDS_FILE}" --header="User-Agent: ${DOWNLOAD_USER_AGENT}" --post-file="${OVERPASS_COUNTRIES}" \
   "${OVERPASS_INTERPRETER}"
 else
  wget -O "${COUNTRIES_BOUNDARY_IDS_FILE}" --post-file="${OVERPASS_COUNTRIES}" \
   "${OVERPASS_INTERPRETER}"
 fi
 RET=${?}
 set -e
 if [[ "${RET}" -ne 0 ]]; then
  __loge "ERROR: Country list could not be downloaded."
  __handle_error_with_cleanup "${ERROR_DOWNLOADING_BOUNDARY_ID_LIST}" \
   "Country list download failed" \
   "__preserve_failed_boundary_artifacts '${COUNTRIES_BOUNDARY_IDS_FILE}'"
  local HANDLER_RETURN_CODE=$?
  __log_finish
  return "${HANDLER_RETURN_CODE}"
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
  local ERROR_LOGS
  ERROR_LOGS=$(find "${TMP_DIR}" -maxdepth 1 -type f -name "${BASENAME}.log.*" | tr '\n' ' ')
  __loge "Found ${QTY_LOGS} error log files. Check them for details: ${ERROR_LOGS}"
  __handle_error_with_cleanup "${ERROR_DOWNLOADING_BOUNDARY}" \
   "Thread error logs detected for boundary processing" \
   "__preserve_failed_boundary_artifacts '${ERROR_LOGS}'"
  __log_finish
  return "${ERROR_DOWNLOADING_BOUNDARY}"
 fi
 if [[ -d "${LOCK_OGR2OGR}" ]]; then
  rm -f "${LOCK_OGR2OGR}/pid"
  rmdir "${LOCK_OGR2OGR}"
 fi

 __log_finish
}

function __processMaritimes_impl {
 __log_start

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
  echo "FAIL! (${FAIL})"
  exit "${ERROR_DOWNLOADING_BOUNDARY}"
 fi

 # If some of the threads generated an error.
 set +e
 QTY_LOGS=$(find "${TMP_DIR}" -maxdepth 1 -type f -name "${BASENAME}.log.*" | wc -l)
 set -e
 if [[ "${QTY_LOGS}" -ne 0 ]]; then
  __logw "Some threads generated errors."
  exit "${ERROR_DOWNLOADING_BOUNDARY}"
 fi
 if [[ -d "${LOCK_OGR2OGR}" ]]; then
  rm -f "${LOCK_OGR2OGR}/pid"
  rmdir "${LOCK_OGR2OGR}"
 fi

 __logi "Calculating statistics on countries."
 echo "ANALYZE countries" | psql -d "${DBNAME}" -v ON_ERROR_STOP=1
 __log_finish
}
