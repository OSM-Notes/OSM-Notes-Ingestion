#!/bin/bash

# Boundary Processing Functions for OSM-Notes-profile
# Author: Andres Gomez (AngocA)
# Version: 2025-12-16
VERSION="2025-12-16"

# GitHub repository URL for boundaries data (can be overridden via environment variable)
# Only set if not already declared (e.g., when sourced from another script)
if ! declare -p DEFAULT_BOUNDARIES_DATA_REPO_URL > /dev/null 2>&1; then
 declare -r DEFAULT_BOUNDARIES_DATA_REPO_URL="https://raw.githubusercontent.com/OSMLatam/OSM-Notes-Data/main/data"
fi

# Directory lock for ogr2ogr imports
# Only set if not already declared (e.g., when sourced from another script)
if ! declare -p LOCK_OGR2OGR > /dev/null 2>&1; then
 declare -r LOCK_OGR2OGR="/tmp/ogr2ogr.lock"
fi

# Overpass query templates
# Only set if not already declared (e.g., when sourced from another script)
if ! declare -p OVERPASS_COUNTRIES > /dev/null 2>&1; then
 declare -r OVERPASS_COUNTRIES="${SCRIPT_BASE_DIRECTORY}/overpass/countries.op"
fi
if ! declare -p OVERPASS_MARITIMES > /dev/null 2>&1; then
 declare -r OVERPASS_MARITIMES="${SCRIPT_BASE_DIRECTORY}/overpass/maritimes.op"
fi

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
# Table name helper for safe updates
# ---------------------------------------------------------------------------

# Returns the name of the countries table to use (countries or countries_new)
# Based on USE_COUNTRIES_NEW environment variable
function __get_countries_table_name {
 if [[ "${USE_COUNTRIES_NEW:-false}" == "true" ]]; then
  echo "countries_new"
 else
  echo "countries"
 fi
}

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
 local FILE_NAME=""
 local DOWNLOAD_URL=""

 # Determine file name and download URL
 if [[ "${BASE_PATH}" == *.geojson ]]; then
  FILE_NAME=$(basename "${BASE_PATH}")
 else
  FILE_NAME=$(basename "${BASE_PATH}.geojson")
 fi

 # Default GitHub repository URL for boundaries data
 local BOUNDARIES_DATA_REPO_URL="${BOUNDARIES_DATA_REPO_URL:-https://raw.githubusercontent.com/OSMLatam/OSM-Notes-Data/main/data}"
 local BOUNDARIES_DATA_BRANCH="${BOUNDARIES_DATA_BRANCH:-main}"

 # Try local files first (for development or offline use)
 # If BASE_PATH already has .geojson extension, use it as-is
 if [[ "${BASE_PATH}" == *.geojson ]]; then
  if [[ -f "${BASE_PATH}" ]] && [[ -s "${BASE_PATH}" ]]; then
   RESOLVED_FILE="${BASE_PATH}"
   eval "${OUTPUT_VAR}=\"${RESOLVED_FILE}\""
   return 0
  elif [[ -f "${BASE_PATH}.gz" ]] && [[ -s "${BASE_PATH}.gz" ]]; then
   # Decompress to temporary location
   local TMP_DECOMPRESSED
   TMP_DECOMPRESSED="${TMP_DIR}/$(basename "${BASE_PATH}")"
   if gunzip -c "${BASE_PATH}.gz" > "${TMP_DECOMPRESSED}" 2> /dev/null; then
    RESOLVED_FILE="${TMP_DECOMPRESSED}"
    __logd "Decompressed ${BASE_PATH}.gz to ${RESOLVED_FILE}"
    eval "${OUTPUT_VAR}=\"${RESOLVED_FILE}\""
    return 0
   else
    __loge "Failed to decompress ${BASE_PATH}.gz"
   fi
  fi
 else
  # Try .geojson first, then .geojson.gz
  if [[ -f "${BASE_PATH}.geojson" ]] && [[ -s "${BASE_PATH}.geojson" ]]; then
   RESOLVED_FILE="${BASE_PATH}.geojson"
   eval "${OUTPUT_VAR}=\"${RESOLVED_FILE}\""
   return 0
  elif [[ -f "${BASE_PATH}.geojson.gz" ]] && [[ -s "${BASE_PATH}.geojson.gz" ]]; then
   # Decompress to temporary location
   local TMP_DECOMPRESSED
   TMP_DECOMPRESSED="${TMP_DIR}/$(basename "${BASE_PATH}.geojson")"
   if gunzip -c "${BASE_PATH}.geojson.gz" > "${TMP_DECOMPRESSED}" 2> /dev/null; then
    RESOLVED_FILE="${TMP_DECOMPRESSED}"
    __logd "Decompressed ${BASE_PATH}.geojson.gz to ${RESOLVED_FILE}"
    eval "${OUTPUT_VAR}=\"${RESOLVED_FILE}\""
    return 0
   else
    __loge "Failed to decompress ${BASE_PATH}.geojson.gz"
   fi
  fi
 fi

 # Local files not found, try downloading from GitHub
 __logd "Local file not found, attempting to download from GitHub repository..."

 # Try .geojson.gz first (compressed version is preferred for GitHub)
 DOWNLOAD_URL="${BOUNDARIES_DATA_REPO_URL}/${FILE_NAME}.gz"
 local DOWNLOADED_FILE="${TMP_DIR}/${FILE_NAME}.gz"
 local TMP_DECOMPRESSED="${TMP_DIR}/${FILE_NAME}"

 # Check if we have network operation function available
 if declare -f __retry_network_operation > /dev/null 2>&1; then
  if __retry_network_operation "${DOWNLOAD_URL}" "${DOWNLOADED_FILE}" 3 2 30; then
   __logd "Downloaded ${FILE_NAME}.gz from GitHub"
  else
   __logw "Failed to download ${FILE_NAME}.gz from GitHub, trying uncompressed version..."
   DOWNLOAD_URL="${BOUNDARIES_DATA_REPO_URL}/${FILE_NAME}"
   DOWNLOADED_FILE="${TMP_DIR}/${FILE_NAME}"
   TMP_DECOMPRESSED="${DOWNLOADED_FILE}"
   if ! __retry_network_operation "${DOWNLOAD_URL}" "${DOWNLOADED_FILE}" 3 2 30; then
    __loge "Failed to download ${FILE_NAME} from GitHub repository"
    return 1
   fi
   __logd "Downloaded ${FILE_NAME} from GitHub"
  fi
 else
  # Fallback to curl if __retry_network_operation is not available
  if curl -s -H "User-Agent: ${DOWNLOAD_USER_AGENT:-OSM-Notes-Ingestion/1.0}" -o "${DOWNLOADED_FILE}" "${DOWNLOAD_URL}" 2> /dev/null; then
   __logd "Downloaded ${FILE_NAME}.gz from GitHub"
  else
   __logw "Failed to download ${FILE_NAME}.gz from GitHub, trying uncompressed version..."
   DOWNLOAD_URL="${BOUNDARIES_DATA_REPO_URL}/${FILE_NAME}"
   DOWNLOADED_FILE="${TMP_DIR}/${FILE_NAME}"
   TMP_DECOMPRESSED="${DOWNLOADED_FILE}"
   if ! curl -s -H "User-Agent: ${DOWNLOAD_USER_AGENT:-OSM-Notes-Ingestion/1.0}" -o "${DOWNLOADED_FILE}" "${DOWNLOAD_URL}" 2> /dev/null; then
    __loge "Failed to download ${FILE_NAME} from GitHub repository"
    return 1
   fi
   __logd "Downloaded ${FILE_NAME} from GitHub"
  fi
 fi

 # Verify downloaded file
 if [[ ! -f "${DOWNLOADED_FILE}" ]] || [[ ! -s "${DOWNLOADED_FILE}" ]]; then
  __loge "Downloaded file is empty or missing"
  return 1
 fi

 # Decompress if needed
 if [[ "${DOWNLOADED_FILE}" == *.gz ]]; then
  if gunzip -c "${DOWNLOADED_FILE}" > "${TMP_DECOMPRESSED}" 2> /dev/null; then
   RESOLVED_FILE="${TMP_DECOMPRESSED}"
   __logd "Decompressed downloaded ${FILE_NAME}.gz to ${RESOLVED_FILE}"
   rm -f "${DOWNLOADED_FILE}" 2> /dev/null || true
  else
   __loge "Failed to decompress downloaded ${FILE_NAME}.gz"
   return 1
  fi
 else
  RESOLVED_FILE="${DOWNLOADED_FILE}"
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

# Validates that the imported geometry contains the country's capital city.
# This prevents cross-contamination where a country gets another country's geometry.
# Parameters:
#   $1: Boundary ID (country relation ID)
#   $2: Database name
# Returns: 0 if validation passes, 1 if it fails or capital cannot be found
function __validate_capital_location() {
 local -i BOUNDARY_ID="${1}"
 local DB_NAME="${2}"
 local CAPITAL_JSON_FILE
 CAPITAL_JSON_FILE=$(mktemp)
 local CAPITAL_FOUND=false
 local CAPITAL_LAT
 local CAPITAL_LON

 # Query Overpass for capital city: try capital=yes first, then label node as fallback
 # capital=yes is the most reliable as it's the actual capital city
 # label node is just a reference point for map labeling, not necessarily the capital
 # Use URL encoding for Overpass API query parameter
 local CAPITAL_QUERY_CAPITAL
 CAPITAL_QUERY_CAPITAL="[out:json][timeout:25];(relation(${BOUNDARY_ID});node(r)[capital=yes];);out center;"
 # URL encode the query (basic encoding for Overpass API)
 CAPITAL_QUERY_CAPITAL=$(printf '%s' "${CAPITAL_QUERY_CAPITAL}" | python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.stdin.read()))" 2> /dev/null || printf '%s' "${CAPITAL_QUERY_CAPITAL}" | sed "s/ /%20/g" | sed "s/\[/%5B/g" | sed "s/\]/%5D/g" | sed "s/(/%28/g" | sed "s/)/%29/g" | sed "s/:/%3A/g" | sed "s/\"/%22/g" | sed "s/;/%3B/g" | sed "s/,/%2C/g" | sed "s/=/=%3D/g")

 # Try to get capital from capital=yes node first (most reliable)
 if __retry_overpass_api "${CAPITAL_QUERY_CAPITAL}" "${CAPITAL_JSON_FILE}" 2 3 30; then
  if [[ -s "${CAPITAL_JSON_FILE}" ]]; then
   # Extract lat/lon from capital=yes node
   CAPITAL_LAT=$(jq -r '.elements[] | select(.type=="node") | .lat' "${CAPITAL_JSON_FILE}" 2> /dev/null | head -1)
   CAPITAL_LON=$(jq -r '.elements[] | select(.type=="node") | .lon' "${CAPITAL_JSON_FILE}" 2> /dev/null | head -1)
   if [[ -n "${CAPITAL_LAT}" ]] && [[ -n "${CAPITAL_LON}" ]] && [[ "${CAPITAL_LAT}" != "null" ]] && [[ "${CAPITAL_LON}" != "null" ]]; then
    CAPITAL_FOUND=true
   fi
  fi
 fi

 # If capital=yes not found, try label node as fallback (some countries may not have capital=yes)
 if [[ "${CAPITAL_FOUND}" == "false" ]]; then
  local CAPITAL_QUERY_LABEL
  CAPITAL_QUERY_LABEL="[out:json][timeout:25];(relation(${BOUNDARY_ID});node(r:\"label\"););out center;"
  # URL encode the query (basic encoding for Overpass API)
  CAPITAL_QUERY_LABEL=$(printf '%s' "${CAPITAL_QUERY_LABEL}" | python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.stdin.read()))" 2> /dev/null || printf '%s' "${CAPITAL_QUERY_LABEL}" | sed "s/ /%20/g" | sed "s/\[/%5B/g" | sed "s/\]/%5D/g" | sed "s/(/%28/g" | sed "s/)/%29/g" | sed "s/:/%3A/g" | sed "s/\"/%22/g" | sed "s/;/%3B/g" | sed "s/,/%2C/g")
  if __retry_overpass_api "${CAPITAL_QUERY_LABEL}" "${CAPITAL_JSON_FILE}" 2 3 30; then
   if [[ -s "${CAPITAL_JSON_FILE}" ]]; then
    # Extract lat/lon from label node
    CAPITAL_LAT=$(jq -r '.elements[] | select(.type=="node") | .lat' "${CAPITAL_JSON_FILE}" 2> /dev/null | head -1)
    CAPITAL_LON=$(jq -r '.elements[] | select(.type=="node") | .lon' "${CAPITAL_JSON_FILE}" 2> /dev/null | head -1)
    if [[ -n "${CAPITAL_LAT}" ]] && [[ -n "${CAPITAL_LON}" ]] && [[ "${CAPITAL_LAT}" != "null" ]] && [[ "${CAPITAL_LON}" != "null" ]]; then
     CAPITAL_FOUND=true
    fi
   fi
  fi
 fi

 rm -f "${CAPITAL_JSON_FILE}" 2> /dev/null || true

 # If capital not found, log warning but don't fail (some countries may not have capital in OSM)
 if [[ "${CAPITAL_FOUND}" == "false" ]]; then
  __logw "Capital city not found for boundary ${BOUNDARY_ID} - skipping validation"
  return 0
 fi

 # Validate that capital is within the imported geometry
 __logd "Validating capital location for boundary ${BOUNDARY_ID}: lat=${CAPITAL_LAT}, lon=${CAPITAL_LON}"

 # First, verify that the import table has polygon geometries
 local POLYGON_COUNT
 POLYGON_COUNT=$(PGAPPNAME="${PGAPPNAME}" psql -d "${DB_NAME}" -Atq -c "SELECT COUNT(*) FROM import WHERE ST_GeometryType(geometry) IN ('ST_Polygon', 'ST_MultiPolygon') AND NOT ST_IsEmpty(geometry);" 2> /dev/null || echo "0")

 if [[ "${POLYGON_COUNT}" -eq 0 ]]; then
  __loge "CRITICAL: No polygon geometries found in import table for boundary ${BOUNDARY_ID}"
  __loge "Cannot validate capital location - import table is empty or contains no valid polygons"
  return 1
 fi

 __logd "Found ${POLYGON_COUNT} polygon geometries in import table for boundary ${BOUNDARY_ID}"

 # Check geometry validity before validation
 local INVALID_GEOM_COUNT
 INVALID_GEOM_COUNT=$(PGAPPNAME="${PGAPPNAME}" psql -d "${DB_NAME}" -Atq -c "SELECT COUNT(*) FROM import WHERE ST_GeometryType(geometry) IN ('ST_Polygon', 'ST_MultiPolygon') AND NOT ST_IsValid(geometry);" 2> /dev/null || echo "0")

 if [[ "${INVALID_GEOM_COUNT}" -gt "0" ]]; then
  __logw "Found ${INVALID_GEOM_COUNT} invalid geometries in import table for boundary ${BOUNDARY_ID} - will use ST_MakeValid"
  # Log validity reason for first invalid geometry
  local VALIDITY_REASON
  VALIDITY_REASON=$(PGAPPNAME="${PGAPPNAME}" psql -d "${DB_NAME}" -Atq -c "SELECT ST_IsValidReason(geometry) FROM import WHERE ST_GeometryType(geometry) IN ('ST_Polygon', 'ST_MultiPolygon') AND NOT ST_IsValid(geometry) LIMIT 1;" 2> /dev/null || echo "Unknown")
  __logd "Validity reason: ${VALIDITY_REASON}"
 fi

 # Validate using ST_MakeValid to handle invalid geometries (self-intersections, etc.)
 # CRITICAL: Use the same geometry processing strategies as insertion
 # The insertion process tries multiple strategies if ST_Union fails:
 # 1. ST_Union(ST_MakeValid(geometry)) - standard
 # 2. ST_Collect(ST_MakeValid(geometry)) + ST_UnaryUnion - if ST_Union fails
 # 3. ST_Buffer(ST_MakeValid(geometry), 0.0001) + ST_Union - buffer strategy
 # Validation must use the same strategies to match insertion results
 local VALIDATION_RESULT
 local VALIDATION_ERROR_LOG
 VALIDATION_ERROR_LOG=$(mktemp)

 # Strategy 1: Try standard ST_Union(ST_MakeValid) - matches standard insertion
 VALIDATION_RESULT=$(
  PGAPPNAME="${PGAPPNAME}" psql -d "${DB_NAME}" -Atq << EOF 2> "${VALIDATION_ERROR_LOG}" || echo "false"
SELECT ST_Contains(
  ST_SetSRID(ST_Union(ST_MakeValid(geometry)), 4326),
  ST_SetSRID(ST_MakePoint(${CAPITAL_LON}, ${CAPITAL_LAT}), 4326)
)
FROM import
WHERE ST_GeometryType(geometry) IN ('ST_Polygon', 'ST_MultiPolygon')
  AND NOT ST_IsEmpty(geometry);
EOF
 )

 # Check if there was a SQL error or if result is NULL/false
 local SQL_ERROR=""
 if [[ -s "${VALIDATION_ERROR_LOG}" ]]; then
  SQL_ERROR=$(cat "${VALIDATION_ERROR_LOG}" 2> /dev/null | head -5 || echo "Unknown SQL error")
  __logw "SQL error during ST_Union validation for boundary ${BOUNDARY_ID}: ${SQL_ERROR}"
 fi

 # If ST_Union validation failed or returned NULL, try alternative strategies (matching insertion logic)
 if [[ "${VALIDATION_RESULT}" != "t" ]] && [[ "${VALIDATION_RESULT}" != "true" ]]; then
  __logd "ST_Union validation failed for boundary ${BOUNDARY_ID}, trying alternative strategies (matching insertion process)"

  # Strategy 2: Try ST_Collect + ST_UnaryUnion (matching insertion alternative)
  VALIDATION_RESULT=$(
   PGAPPNAME="${PGAPPNAME}" psql -d "${DB_NAME}" -Atq << EOF 2> "${VALIDATION_ERROR_LOG}" || echo "false"
SELECT ST_Contains(
  ST_SetSRID(ST_UnaryUnion(ST_Collect(ST_MakeValid(geometry))), 4326),
  ST_SetSRID(ST_MakePoint(${CAPITAL_LON}, ${CAPITAL_LAT}), 4326)
)
FROM import
WHERE ST_GeometryType(geometry) IN ('ST_Polygon', 'ST_MultiPolygon')
  AND NOT ST_IsEmpty(geometry);
EOF
  )

  if [[ "${VALIDATION_RESULT}" == "t" ]] || [[ "${VALIDATION_RESULT}" == "true" ]]; then
   __logd "Capital validation passed for boundary ${BOUNDARY_ID} (using ST_Collect + ST_UnaryUnion)"
   rm -f "${VALIDATION_ERROR_LOG}" 2> /dev/null || true
   return 0
  fi

  # Strategy 3: Try ST_Buffer strategy (matching insertion buffer strategy)
  VALIDATION_RESULT=$(
   PGAPPNAME="${PGAPPNAME}" psql -d "${DB_NAME}" -Atq << EOF 2> "${VALIDATION_ERROR_LOG}" || echo "false"
SELECT ST_Contains(
  ST_SetSRID(ST_Union(ST_Buffer(ST_MakeValid(geometry), 0.0001)), 4326),
  ST_SetSRID(ST_MakePoint(${CAPITAL_LON}, ${CAPITAL_LAT}), 4326)
)
FROM import
WHERE ST_GeometryType(geometry) IN ('ST_Polygon', 'ST_MultiPolygon')
  AND NOT ST_IsEmpty(geometry);
EOF
  )

  if [[ "${VALIDATION_RESULT}" == "t" ]] || [[ "${VALIDATION_RESULT}" == "true" ]]; then
   __logd "Capital validation passed for boundary ${BOUNDARY_ID} (using ST_Buffer strategy)"
   rm -f "${VALIDATION_ERROR_LOG}" 2> /dev/null || true
   return 0
  fi

  # All strategies failed, try ST_Intersects as final fallback (more tolerant)
  __logw "All geometry processing strategies failed for boundary ${BOUNDARY_ID}, trying ST_Intersects as final fallback"
  local INTERSECTS_RESULT
  INTERSECTS_RESULT=$(PGAPPNAME="${PGAPPNAME}" psql -d "${DB_NAME}" -Atq -c "SELECT ST_Intersects(ST_SetSRID(ST_Union(ST_MakeValid(geometry)), 4326), ST_SetSRID(ST_MakePoint(${CAPITAL_LON}, ${CAPITAL_LAT}), 4326)) FROM import WHERE ST_GeometryType(geometry) IN ('ST_Polygon', 'ST_MultiPolygon') AND NOT ST_IsEmpty(geometry);" 2> /dev/null || echo "false")

  if [[ "${INTERSECTS_RESULT}" == "t" ]] || [[ "${INTERSECTS_RESULT}" == "true" ]]; then
   __logw "Capital validation passed with ST_Intersects fallback for boundary ${BOUNDARY_ID}"
   __logw "Capital (${CAPITAL_LAT}, ${CAPITAL_LON}) intersects but may be on boundary edge"
   rm -f "${VALIDATION_ERROR_LOG}" 2> /dev/null || true
   return 0
  fi

  # All validation strategies failed
  __loge "CRITICAL: Capital validation FAILED for boundary ${BOUNDARY_ID}"
  __loge "Capital (${CAPITAL_LAT}, ${CAPITAL_LON}) is NOT within the imported geometry"
  __loge "All geometry processing strategies (ST_Union, ST_Collect+UnaryUnion, ST_Buffer) failed"
  if [[ -n "${SQL_ERROR}" ]]; then
   __loge "SQL error details: ${SQL_ERROR}"
  fi
  rm -f "${VALIDATION_ERROR_LOG}" 2> /dev/null || true
  return 1
 fi

 # Standard ST_Union validation passed
 __logd "Capital validation passed for boundary ${BOUNDARY_ID} (using ST_Union(ST_MakeValid))"
 rm -f "${VALIDATION_ERROR_LOG}" 2> /dev/null || true
 return 0
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

 # Initialize IS_MARITIME variable (defaults to false for countries)
 local IS_MARITIME_VALUE="${IS_MARITIME:-false}"
 if [[ "${IS_MARITIME_VALUE}" == "true" ]]; then
  IS_MARITIME_VALUE="true"
 else
  IS_MARITIME_VALUE="false"
 fi

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

  # CRITICAL: Verify that the GeoJSON file actually has features and is not empty
  # This prevents importing empty GeoJSON files that would leave the import table empty
  local GEOJSON_FEATURE_COUNT
  GEOJSON_FEATURE_COUNT=$(jq '.features | length' "${GEOJSON_FILE}" 2> /dev/null || echo "0")
  if [[ "${GEOJSON_FEATURE_COUNT}" -eq 0 ]] || [[ "${GEOJSON_FEATURE_COUNT}" == "null" ]]; then
   __loge "GeoJSON validation failed for boundary ${ID}: file has no features (count: ${GEOJSON_FEATURE_COUNT})"
   __loge "This indicates the conversion from JSON to GeoJSON produced an empty file"
   GEOJSON_VALIDATION_RETRY_COUNT=$((GEOJSON_VALIDATION_RETRY_COUNT + 1))
   continue
  fi

  # Verify that at least some features have valid polygon geometries
  local GEOJSON_POLYGON_COUNT
  GEOJSON_POLYGON_COUNT=$(jq '[.features[] | select(.geometry.type == "Polygon" or .geometry.type == "MultiPolygon")] | length' "${GEOJSON_FILE}" 2> /dev/null || echo "0")
  if [[ "${GEOJSON_POLYGON_COUNT}" -eq 0 ]] || [[ "${GEOJSON_POLYGON_COUNT}" == "null" ]]; then
   __logw "GeoJSON validation warning for boundary ${ID}: file has ${GEOJSON_FEATURE_COUNT} features but no polygon geometries"
   __logw "This may indicate a problem with the conversion or the source data"
   # Don't fail here, but log the warning - capital validation will fail later if needed
  else
   __logd "GeoJSON has ${GEOJSON_FEATURE_COUNT} features, ${GEOJSON_POLYGON_COUNT} with polygon geometries"
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

 # Import only geometry column from GeoJSON
 # Using -select geometry to avoid column mismatch errors when different features
 # have different properties (e.g., alt_name:gd, alt_name:cs, etc.).
 # Note: We use -select geometry instead of -select name,admin_level,type to avoid
 # column mismatch errors. The skipfailures flag handles errors gracefully.
 # For boundaries requiring mapFieldType StringList=String, we use -select geometry.
 # Only geometry is needed since we extract names separately from the GeoJSON file.
 # -skipfailures allows ogr2ogr to continue even if some features fail
 # For large boundaries, we use skipfailures with mapFieldType StringList=String
 # to prevent row size errors (though we use -select geometry instead of field selection)
 # Check if DB import should be skipped (for download-only mode)
 if [[ "${SKIP_DB_IMPORT:-false}" == "true" ]]; then
  __logi "SKIP_DB_IMPORT=true - Skipping database import for boundary ${ID}"
  __logi "GeoJSON file saved at: ${GEOJSON_FILE}"
  rmdir "${PROCESS_LOCK}" 2> /dev/null || true
  __log_finish
  return 0
 fi

 __logd "Importing all features from GeoJSON for boundary ${ID}"

 # CRITICAL: Explicitly truncate import table to prevent cross-contamination
 # between parallel processes. ogr2ogr -overwrite should do this, but explicit
 # truncation ensures no residual data from previous failed imports.
 __logd "Truncating import table to prevent cross-contamination for boundary ${ID}..."
 if ! PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -c "TRUNCATE TABLE import" > /dev/null 2>&1; then
  __logw "Warning: Failed to truncate import table (may not exist yet)"
 fi

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
  # Use -select geometry to avoid column mismatch errors (alt_name:gd, etc.)
  # Note: We use -select geometry instead of -select name,admin_level,type
  # The skipfailures flag with mapFieldType StringList=String handling is not needed
  # since we only import geometry column
  __logd "Using PG_USE_COPY NO to allow TOAST for large rows"
  IMPORT_OPERATION="ogr2ogr -f PostgreSQL PG:dbname=${DBNAME} -nln import -overwrite -skipfailures -nlt PROMOTE_TO_MULTI -a_srs EPSG:4326 -lco GEOMETRY_NAME=geometry -select geometry --config PG_USE_COPY NO ${GEOJSON_FILE} 2> ${OGR_ERROR_LOG}"
 elif [[ "${ID}" -eq 16239 ]]; then
  # Austria - use ST_Buffer to fix topology issues
  __logd "Using special handling for Austria (ID: 16239)"
  # Import only geometry column to avoid column mismatch errors
  # Geometry will be filtered in SQL
  IMPORT_OPERATION="ogr2ogr -f PostgreSQL PG:dbname=${DBNAME} -nln import -overwrite -skipfailures -nlt PROMOTE_TO_MULTI -a_srs EPSG:4326 -lco GEOMETRY_NAME=geometry -select geometry --config PG_USE_COPY YES ${GEOJSON_FILE} 2> ${OGR_ERROR_LOG}"
 else
  # Standard import - import only geometry column
  # Note: We use -select geometry instead of -select name,admin_level,type
  # The skipfailures flag handles errors, and mapFieldType StringList=String is not needed
  # since we only import geometry column
  __logd "Standard import with field selection for boundary ${ID}"
  __logd "Importing geometry only for boundary ${ID} (avoiding column mismatch errors)"
  # Import only geometry to avoid column mismatch errors (alt_name:gd, etc.)
  # Geometry will be filtered in SQL
  IMPORT_OPERATION="ogr2ogr -f PostgreSQL PG:dbname=${DBNAME} -nln import -overwrite -skipfailures -nlt PROMOTE_TO_MULTI -a_srs EPSG:4326 -lco GEOMETRY_NAME=geometry -select geometry --config PG_USE_COPY YES ${GEOJSON_FILE} 2> ${OGR_ERROR_LOG}"
 fi

 local IMPORT_CLEANUP="rmdir ${PROCESS_LOCK} 2>/dev/null || true"

 if ! __retry_file_operation "${IMPORT_OPERATION}" 2 5 "${IMPORT_CLEANUP}"; then
  # Check for specific error types that require different strategies
  local HAS_ROW_TOO_BIG=false
  local HAS_GEOMETRY_FIELD_ERROR=false
  if [[ -f "${OGR_ERROR_LOG}" ]]; then
   if grep -q "row is too big" "${OGR_ERROR_LOG}" 2> /dev/null; then
    HAS_ROW_TOO_BIG=true
    __logw "Detected 'row is too big' error for boundary ${ID} - retrying with PG_USE_COPY NO"
   fi
   if grep -qi "Field 'geometry' not found\|Field.*geometry.*not found" "${OGR_ERROR_LOG}" 2> /dev/null; then
    HAS_GEOMETRY_FIELD_ERROR=true
    __logw "Detected 'Field geometry not found' error for boundary ${ID} - GeoJSON may have different field name"
   fi
  fi

  # If "Field 'geometry' not found", try without -select (import all fields)
  # This handles GeoJSON files where the geometry field has a different name
  if [[ "${HAS_GEOMETRY_FIELD_ERROR}" == "true" ]]; then
   __logw "Retrying import for boundary ${ID} without -select geometry (importing all fields)"
   if [[ "${ID}" -eq 16239 ]]; then
    IMPORT_OPERATION="ogr2ogr -f PostgreSQL PG:dbname=${DBNAME} -nln import -overwrite -skipfailures -nlt PROMOTE_TO_MULTI -a_srs EPSG:4326 -lco GEOMETRY_NAME=geometry --config PG_USE_COPY YES ${GEOJSON_FILE} 2> ${OGR_ERROR_LOG}"
   else
    IMPORT_OPERATION="ogr2ogr -f PostgreSQL PG:dbname=${DBNAME} -nln import -overwrite -skipfailures -nlt PROMOTE_TO_MULTI -a_srs EPSG:4326 -lco GEOMETRY_NAME=geometry --config PG_USE_COPY YES ${GEOJSON_FILE} 2> ${OGR_ERROR_LOG}"
   fi

   if ! __retry_file_operation "${IMPORT_OPERATION}" 2 5 "${IMPORT_CLEANUP}"; then
    __loge "Failed to import boundary ${ID} even without -select geometry"
    if [[ -f "${OGR_ERROR_LOG}" ]]; then
     local REAL_ERRORS
     REAL_ERRORS=$(grep -v "Field 'admin_level' not found" "${OGR_ERROR_LOG}" 2> /dev/null | grep -v "^$" || true)
     if [[ -n "${REAL_ERRORS}" ]]; then
      __loge "ogr2ogr errors for boundary ${ID}:"
      echo "${REAL_ERRORS}" | while IFS= read -r line; do
       __loge "  ${line}"
      done
     fi
     rm -f "${OGR_ERROR_LOG}" 2> /dev/null || true
    fi
    if [[ "${CONTINUE_ON_OVERPASS_ERROR:-false}" == "true" ]]; then
     echo "${ID}" >> "${TMP_DIR}/failed_boundaries.txt"
     __logw "Recording boundary ${ID} as failed and continuing (CONTINUE_ON_OVERPASS_ERROR=true)"
     rmdir "${PROCESS_LOCK}" 2> /dev/null || true
     __log_finish
     return 1
    else
     __handle_error_with_cleanup "${ERROR_GENERAL}" "Database import failed for boundary ${ID}" \
      "rm -f ${JSON_FILE} ${GEOJSON_FILE} ${OGR_ERROR_LOG} 2>/dev/null || true; rmdir ${PROCESS_LOCK} 2>/dev/null || true"
     __log_finish
     return 1
    fi
   else
    __logi "Successfully imported boundary ${ID} without -select geometry"
   fi
  # If "row is too big", retry with PG_USE_COPY NO (allows TOAST)
  # Note: Afghanistan (303427) and Taiwan (449220) already use PG_USE_COPY NO
  # from the start, so this is only for other countries that unexpectedly hit
  # this error
  elif [[ "${HAS_ROW_TOO_BIG}" == "true" ]]; then
   __logd "Retrying import for boundary ${ID} without COPY (using TOAST)"
   if [[ "${ID}" -eq 16239 ]]; then
    # Austria - use ST_Buffer to fix topology issues
    # Import only geometry column to avoid column mismatch errors
    IMPORT_OPERATION="ogr2ogr -f PostgreSQL PG:dbname=${DBNAME} -nln import -overwrite -skipfailures -nlt PROMOTE_TO_MULTI -a_srs EPSG:4326 -lco GEOMETRY_NAME=geometry -select geometry --config PG_USE_COPY NO ${GEOJSON_FILE} 2> ${OGR_ERROR_LOG}"
   else
    # Standard import without COPY (slower but allows TOAST for large rows)
    # Note: We use -select geometry instead of -select name,admin_level,type
    # The skipfailures flag with mapFieldType StringList=String handling is used
    # to prevent row size errors for large boundaries
    __logd "Standard import with field selection for boundary ${ID}"
    # Import only geometry column to avoid column mismatch errors
    IMPORT_OPERATION="ogr2ogr -f PostgreSQL PG:dbname=${DBNAME} -nln import -overwrite -skipfailures -nlt PROMOTE_TO_MULTI -a_srs EPSG:4326 -lco GEOMETRY_NAME=geometry -select geometry --config PG_USE_COPY NO ${GEOJSON_FILE} 2> ${OGR_ERROR_LOG}"
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

 # CRITICAL: Verify that import table has data after ogr2ogr
 # This validation prevents cross-contamination where an empty import table could lead
 # to inserting incorrect geometries from a previous boundary
 __logd "Verifying import table has data for boundary ${ID}..."
 local IMPORT_COUNT_AFTER
 IMPORT_COUNT_AFTER=$(PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM import" 2> /dev/null || echo "0")
 local IMPORT_POLYGON_COUNT
 IMPORT_POLYGON_COUNT=$(PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM import WHERE ST_GeometryType(geometry) IN ('ST_Polygon', 'ST_MultiPolygon') AND NOT ST_IsEmpty(geometry);" 2> /dev/null || echo "0")

 # Get the expected feature count from the GeoJSON file for comparison
 local EXPECTED_FEATURE_COUNT
 EXPECTED_FEATURE_COUNT=$(jq '.features | length' "${GEOJSON_FILE}" 2> /dev/null || echo "0")

 if [[ "${IMPORT_COUNT_AFTER}" -eq 0 ]]; then
  __loge "CRITICAL ERROR: Import table is completely empty after ogr2ogr for boundary ${ID}"
  __loge "This indicates ogr2ogr failed to import the GeoJSON, which could lead to data corruption"
  __loge "Possible causes:"
  __loge "  1. GeoJSON file is invalid or empty"
  __loge "  2. ogr2ogr could not find the 'geometry' field"
  __loge "  3. All geometries were rejected by ogr2ogr"
  __loge "  4. ogr2ogr failed silently (check ogr2ogr logs)"

  # Check if GeoJSON file exists and has content
  if [[ -f "${GEOJSON_FILE}" ]]; then
   local GEOJSON_SIZE
   GEOJSON_SIZE=$(stat -f%z "${GEOJSON_FILE}" 2> /dev/null || stat -c%s "${GEOJSON_FILE}" 2> /dev/null || echo "0")
   __loge "GeoJSON file size: ${GEOJSON_SIZE} bytes"

   # Check if GeoJSON has features and what types
   if command -v jq > /dev/null 2>&1; then
    local FEATURE_COUNT
    FEATURE_COUNT=$(jq '.features | length' "${GEOJSON_FILE}" 2> /dev/null || echo "0")
    __loge "GeoJSON features count: ${FEATURE_COUNT} (expected to import ${FEATURE_COUNT} rows, but got 0)"

    # Check geometry types in GeoJSON
    local GEOM_TYPES
    GEOM_TYPES=$(jq -r '.features[].geometry.type' "${GEOJSON_FILE}" 2> /dev/null | sort -u | tr '\n' ',' | sed 's/,$//' || echo "Unknown")
    __loge "Geometry types in GeoJSON: ${GEOM_TYPES}"

    # Try to identify why ogr2ogr failed - check if geometries are valid
    local INVALID_GEOM_COUNT
    INVALID_GEOM_COUNT=$(jq '[.features[] | select(.geometry == null or .geometry.coordinates == null)] | length' "${GEOJSON_FILE}" 2> /dev/null || echo "0")
    if [[ "${INVALID_GEOM_COUNT}" -gt 0 ]]; then
     __loge "Found ${INVALID_GEOM_COUNT} features with null or invalid geometries in GeoJSON"
    fi
   fi

   # Check ogr2ogr error log for clues
   if [[ -f "${OGR_ERROR_LOG}" ]] && [[ -s "${OGR_ERROR_LOG}" ]]; then
    __loge "ogr2ogr error log contents:"
    while IFS= read -r line; do
     __loge "  ${line}"
    done < "${OGR_ERROR_LOG}" | head -20
   fi
  else
   __loge "GeoJSON file not found: ${GEOJSON_FILE}"
  fi

  # CRITICAL: Never continue if import table is empty - this would cause data corruption
  # The import table being empty means no data was imported, so we should not proceed
  # with validation or insertion, as this could lead to inserting wrong geometries
  __loge "CRITICAL: Rejecting boundary ${ID} - cannot proceed with empty import table"
  __loge "This prevents data corruption where wrong geometries might be inserted"

  if [[ "${CONTINUE_ON_OVERPASS_ERROR:-false}" == "true" ]]; then
   echo "${ID}" >> "${TMP_DIR}/failed_boundaries.txt"
   __logw "Recording boundary ${ID} as failed and continuing (CONTINUE_ON_OVERPASS_ERROR=true)"
   rmdir "${PROCESS_LOCK}" 2> /dev/null || true
   __log_finish
   return 1
  else
   __handle_error_with_cleanup "${ERROR_GENERAL}" "Import table is empty after ogr2ogr for boundary ${ID} - rejecting to prevent data corruption" \
    "rm -f ${JSON_FILE} ${GEOJSON_FILE} 2>/dev/null || true; rmdir ${PROCESS_LOCK} 2>/dev/null || true"
   __log_finish
   return 1
  fi
 elif [[ "${EXPECTED_FEATURE_COUNT}" -gt 0 ]] && [[ "${IMPORT_COUNT_AFTER}" -lt $((EXPECTED_FEATURE_COUNT / 2)) ]]; then
  # If we imported less than half of the expected features, this is suspicious
  # It could indicate a partial import failure
  __logw "WARNING: Imported ${IMPORT_COUNT_AFTER} rows but GeoJSON has ${EXPECTED_FEATURE_COUNT} features"
  __logw "This suggests a partial import failure - some features were not imported"
  # Log this but continue - some features might be non-geometry or invalid
 elif [[ "${IMPORT_POLYGON_COUNT}" -eq 0 ]]; then
  # CRITICAL: Table has data but no polygons - this is a critical error for boundary processing
  # Boundary processing requires polygon geometries for capital validation and insertion
  __loge "CRITICAL ERROR: Import table has ${IMPORT_COUNT_AFTER} rows but no polygon geometries for boundary ${ID}"
  __loge "This means the GeoJSON was imported but contains only non-polygon geometries (LineString, Point, etc.)"
  __loge "Boundary processing requires polygon geometries - cannot proceed with validation or insertion"

  # Check what geometry types were imported
  local IMPORTED_GEOM_TYPES
  IMPORTED_GEOM_TYPES=$(psql -d "${DBNAME}" -Atq -c "SELECT DISTINCT ST_GeometryType(geometry) FROM import ORDER BY ST_GeometryType(geometry);" 2> /dev/null | tr '\n' ',' | sed 's/,$//' || echo "Unknown")
  __loge "Imported geometry types: ${IMPORTED_GEOM_TYPES}"

  # Check what geometry types are in the GeoJSON
  if [[ -f "${GEOJSON_FILE}" ]] && command -v jq > /dev/null 2>&1; then
   local GEOJSON_GEOM_TYPES
   GEOJSON_GEOM_TYPES=$(jq -r '.features[].geometry.type' "${GEOJSON_FILE}" 2> /dev/null | sort -u | tr '\n' ',' | sed 's/,$//' || echo "Unknown")
   __loge "GeoJSON geometry types: ${GEOJSON_GEOM_TYPES}"

   # Check if GeoJSON has polygons that weren't imported
   local GEOJSON_POLYGON_COUNT
   GEOJSON_POLYGON_COUNT=$(jq '[.features[] | select(.geometry.type == "Polygon" or .geometry.type == "MultiPolygon")] | length' "${GEOJSON_FILE}" 2> /dev/null || echo "0")
   if [[ "${GEOJSON_POLYGON_COUNT}" -gt 0 ]]; then
    __loge "CRITICAL: GeoJSON has ${GEOJSON_POLYGON_COUNT} polygon features but none were imported!"
    __loge "This indicates ogr2ogr failed to import polygon geometries - possible data corruption"
   fi
  fi

  # Reject this boundary - cannot proceed without polygon geometries
  if [[ "${CONTINUE_ON_OVERPASS_ERROR:-false}" == "true" ]]; then
   echo "${ID}" >> "${TMP_DIR}/failed_boundaries.txt"
   __logw "Recording boundary ${ID} as failed and continuing (CONTINUE_ON_OVERPASS_ERROR=true)"
   rmdir "${PROCESS_LOCK}" 2> /dev/null || true
   __log_finish
   return 1
  else
   __handle_error_with_cleanup "${ERROR_GENERAL}" "Import table has no polygon geometries for boundary ${ID} - rejecting to prevent data corruption" \
    "rm -f ${JSON_FILE} ${GEOJSON_FILE} 2>/dev/null || true; rmdir ${PROCESS_LOCK} 2>/dev/null || true"
   __log_finish
   return 1
  fi
 fi

 # Log successful import with details
 __logd "Import table has ${IMPORT_COUNT_AFTER} total rows (${IMPORT_POLYGON_COUNT} polygons) for boundary ${ID}"
 if [[ "${EXPECTED_FEATURE_COUNT}" -gt 0 ]]; then
  __logd "GeoJSON had ${EXPECTED_FEATURE_COUNT} features - imported ${IMPORT_COUNT_AFTER} rows"
 fi

 # CRITICAL: Validate capital location to prevent cross-contamination
 # This ensures the imported geometry corresponds to the correct country
 if ! __validate_capital_location "${ID}" "${DBNAME}"; then
  __loge "Capital validation failed for boundary ${ID} - rejecting import"
  if [[ "${CONTINUE_ON_OVERPASS_ERROR:-false}" == "true" ]]; then
   echo "${ID}" >> "${TMP_DIR}/failed_boundaries.txt"
   __logw "Recording boundary ${ID} as failed and continuing (CONTINUE_ON_OVERPASS_ERROR=true)"
   rmdir "${PROCESS_LOCK}" 2> /dev/null || true
   __log_finish
   return 1
  else
   __handle_error_with_cleanup "${ERROR_GENERAL}" "Capital validation failed for boundary ${ID}" \
    "rm -f ${JSON_FILE} ${GEOJSON_FILE} 2>/dev/null || true; rmdir ${PROCESS_LOCK} 2>/dev/null || true"
   __log_finish
   return 1
  fi
 fi

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
   # Determine is_maritime value for ON CONFLICT clause (if not already set)
   if [[ -z "${IS_MARITIME_CONFLICT_VALUE:-}" ]]; then
    if [[ "${IS_MARITIME_VALUE}" == "true" ]]; then
     IS_MARITIME_CONFLICT_VALUE="TRUE"
    else
     IS_MARITIME_CONFLICT_VALUE="EXCLUDED.is_maritime"
    fi
   fi
   # Determine which table to use
   local COUNTRIES_TABLE
   COUNTRIES_TABLE=$(__get_countries_table_name)

   if [[ "${ID}" -eq 16239 ]]; then
    # Collect only Polygons/MultiPolygons, ignore Points/LineStrings
    # Only update if new geometry is better (larger area) than existing
    # Note: ST_Collect groups geometries but doesn't union them. Use ST_UnaryUnion to union after collect
    # For countries_new, skip existing_area check
    if [[ "${COUNTRIES_TABLE}" == "countries_new" ]]; then
     PROCESS_OPERATION="psql -d ${DBNAME} -c \"WITH collected AS (SELECT ST_Collect(ST_Buffer(geometry, 0.0)) AS geom FROM import WHERE ST_GeometryType(geometry) IN ('ST_Polygon', 'ST_MultiPolygon')), new_geom AS (SELECT ST_SetSRID(ST_UnaryUnion(geom), 4326) AS geom FROM collected), new_area AS (SELECT ST_Area(geom::geography) AS area FROM new_geom WHERE geom IS NOT NULL) INSERT INTO ${COUNTRIES_TABLE} (country_id, country_name, country_name_es, country_name_en, geom, is_maritime) SELECT ${SANITIZED_ID}, '${NAME}', '${NAME_ES}', '${NAME_EN}', new_geom.geom, ${IS_MARITIME_VALUE} FROM new_geom WHERE new_geom.geom IS NOT NULL AND (SELECT area FROM new_area) IS NOT NULL AND (SELECT area FROM new_area) > 1000 ON CONFLICT (country_id) DO UPDATE SET country_name = EXCLUDED.country_name, country_name_es = EXCLUDED.country_name_es, country_name_en = EXCLUDED.country_name_en, is_maritime = ${IS_MARITIME_CONFLICT_VALUE}, geom = ST_SetSRID(EXCLUDED.geom, 4326);\""
    else
     PROCESS_OPERATION="psql -d ${DBNAME} -c \"WITH collected AS (SELECT ST_Collect(ST_Buffer(geometry, 0.0)) AS geom FROM import WHERE ST_GeometryType(geometry) IN ('ST_Polygon', 'ST_MultiPolygon')), new_geom AS (SELECT ST_SetSRID(ST_UnaryUnion(geom), 4326) AS geom FROM collected), new_area AS (SELECT ST_Area(geom::geography) AS area FROM new_geom WHERE geom IS NOT NULL), existing_area AS (SELECT ST_Area(geom::geography) AS area FROM ${COUNTRIES_TABLE} WHERE country_id = ${SANITIZED_ID}) INSERT INTO ${COUNTRIES_TABLE} (country_id, country_name, country_name_es, country_name_en, geom, is_maritime) SELECT ${SANITIZED_ID}, '${NAME}', '${NAME_ES}', '${NAME_EN}', new_geom.geom, ${IS_MARITIME_VALUE} FROM new_geom WHERE new_geom.geom IS NOT NULL AND (SELECT area FROM new_area) IS NOT NULL AND ((SELECT area FROM new_area) > 1000 OR (SELECT area FROM existing_area) IS NULL) ON CONFLICT (country_id) DO UPDATE SET country_name = EXCLUDED.country_name, country_name_es = EXCLUDED.country_name_es, country_name_en = EXCLUDED.country_name_en, is_maritime = ${IS_MARITIME_CONFLICT_VALUE}, geom = CASE WHEN (SELECT area FROM new_area) IS NOT NULL AND (SELECT area FROM new_area) > COALESCE((SELECT area FROM existing_area), 0) * 0.5 THEN ST_SetSRID(EXCLUDED.geom, 4326) ELSE ${COUNTRIES_TABLE}.geom END WHERE (SELECT area FROM new_area) IS NOT NULL AND ((SELECT area FROM new_area) > COALESCE((SELECT area FROM existing_area), 0) * 0.5 OR (SELECT area FROM existing_area) IS NULL);\""
    fi
   else
    # Collect only Polygons/MultiPolygons, ignore Points/LineStrings
    # Only update if new geometry is better (larger area) than existing
    # Note: ST_Collect groups geometries but doesn't union them. Use ST_UnaryUnion to union after collect
    # For countries_new, skip existing_area check
    if [[ "${COUNTRIES_TABLE}" == "countries_new" ]]; then
     PROCESS_OPERATION="psql -d ${DBNAME} -c \"WITH collected AS (SELECT ST_Collect(ST_makeValid(geometry)) AS geom FROM import WHERE ST_GeometryType(geometry) IN ('ST_Polygon', 'ST_MultiPolygon')), new_geom AS (SELECT ST_SetSRID(ST_UnaryUnion(geom), 4326) AS geom FROM collected), new_area AS (SELECT ST_Area(geom::geography) AS area FROM new_geom WHERE geom IS NOT NULL) INSERT INTO ${COUNTRIES_TABLE} (country_id, country_name, country_name_es, country_name_en, geom, is_maritime) SELECT ${SANITIZED_ID}, '${NAME}', '${NAME_ES}', '${NAME_EN}', new_geom.geom, ${IS_MARITIME_VALUE} FROM new_geom WHERE new_geom.geom IS NOT NULL AND (SELECT area FROM new_area) IS NOT NULL AND (SELECT area FROM new_area) > 1000 ON CONFLICT (country_id) DO UPDATE SET country_name = EXCLUDED.country_name, country_name_es = EXCLUDED.country_name_es, country_name_en = EXCLUDED.country_name_en, is_maritime = ${IS_MARITIME_CONFLICT_VALUE}, geom = ST_SetSRID(EXCLUDED.geom, 4326);\""
    else
     PROCESS_OPERATION="psql -d ${DBNAME} -c \"WITH collected AS (SELECT ST_Collect(ST_makeValid(geometry)) AS geom FROM import WHERE ST_GeometryType(geometry) IN ('ST_Polygon', 'ST_MultiPolygon')), new_geom AS (SELECT ST_SetSRID(ST_UnaryUnion(geom), 4326) AS geom FROM collected), new_area AS (SELECT ST_Area(geom::geography) AS area FROM new_geom WHERE geom IS NOT NULL), existing_area AS (SELECT ST_Area(geom::geography) AS area FROM ${COUNTRIES_TABLE} WHERE country_id = ${SANITIZED_ID}) INSERT INTO ${COUNTRIES_TABLE} (country_id, country_name, country_name_es, country_name_en, geom, is_maritime) SELECT ${SANITIZED_ID}, '${NAME}', '${NAME_ES}', '${NAME_EN}', new_geom.geom, ${IS_MARITIME_VALUE} FROM new_geom WHERE new_geom.geom IS NOT NULL AND (SELECT area FROM new_area) IS NOT NULL AND ((SELECT area FROM new_area) > 1000 OR (SELECT area FROM existing_area) IS NULL) ON CONFLICT (country_id) DO UPDATE SET country_name = EXCLUDED.country_name, country_name_es = EXCLUDED.country_name_es, country_name_en = EXCLUDED.country_name_en, is_maritime = ${IS_MARITIME_CONFLICT_VALUE}, geom = CASE WHEN (SELECT area FROM new_area) IS NOT NULL AND (SELECT area FROM new_area) > COALESCE((SELECT area FROM existing_area), 0) * 0.5 THEN ST_SetSRID(EXCLUDED.geom, 4326) ELSE ${COUNTRIES_TABLE}.geom END WHERE (SELECT area FROM new_area) IS NOT NULL AND ((SELECT area FROM new_area) > COALESCE((SELECT area FROM existing_area), 0) * 0.5 OR (SELECT area FROM existing_area) IS NULL);\""
    fi
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
    # Determine is_maritime value for ON CONFLICT clause (if not already set)
    if [[ -z "${IS_MARITIME_CONFLICT_VALUE:-}" ]]; then
     if [[ "${IS_MARITIME_VALUE}" == "true" ]]; then
      IS_MARITIME_CONFLICT_VALUE="TRUE"
     else
      IS_MARITIME_CONFLICT_VALUE="EXCLUDED.is_maritime"
     fi
    fi
    # Buffer and union only Polygons/MultiPolygons
    # Determine which table to use
    local COUNTRIES_TABLE
    COUNTRIES_TABLE=$(__get_countries_table_name)
    # For countries_new, skip existing_area check
    if [[ "${COUNTRIES_TABLE}" == "countries_new" ]]; then
     PROCESS_OPERATION="psql -d ${DBNAME} -c \"WITH new_geom AS (SELECT ST_SetSRID(ST_Union(ST_Buffer(ST_MakeValid(geometry), 0.0001)), 4326) AS geom FROM import WHERE ST_GeometryType(geometry) IN ('ST_Polygon', 'ST_MultiPolygon')), new_area AS (SELECT ST_Area(geom::geography) AS area FROM new_geom WHERE geom IS NOT NULL) INSERT INTO ${COUNTRIES_TABLE} (country_id, country_name, country_name_es, country_name_en, geom, is_maritime) SELECT ${SANITIZED_ID}, '${NAME}', '${NAME_ES}', '${NAME_EN}', new_geom.geom, ${IS_MARITIME_VALUE} FROM new_geom WHERE new_geom.geom IS NOT NULL AND (SELECT area FROM new_area) IS NOT NULL AND (SELECT area FROM new_area) > 1000 ON CONFLICT (country_id) DO UPDATE SET country_name = EXCLUDED.country_name, country_name_es = EXCLUDED.country_name_es, country_name_en = EXCLUDED.country_name_en, is_maritime = ${IS_MARITIME_CONFLICT_VALUE}, geom = ST_SetSRID(EXCLUDED.geom, 4326);\""
    else
     PROCESS_OPERATION="psql -d ${DBNAME} -c \"WITH new_geom AS (SELECT ST_SetSRID(ST_Union(ST_Buffer(ST_MakeValid(geometry), 0.0001)), 4326) AS geom FROM import WHERE ST_GeometryType(geometry) IN ('ST_Polygon', 'ST_MultiPolygon')), new_area AS (SELECT ST_Area(geom::geography) AS area FROM new_geom WHERE geom IS NOT NULL), existing_area AS (SELECT ST_Area(geom::geography) AS area FROM ${COUNTRIES_TABLE} WHERE country_id = ${SANITIZED_ID}) INSERT INTO ${COUNTRIES_TABLE} (country_id, country_name, country_name_es, country_name_en, geom, is_maritime) SELECT ${SANITIZED_ID}, '${NAME}', '${NAME_ES}', '${NAME_EN}', new_geom.geom, ${IS_MARITIME_VALUE} FROM new_geom WHERE new_geom.geom IS NOT NULL AND (SELECT area FROM new_area) IS NOT NULL AND ((SELECT area FROM new_area) > 1000 OR (SELECT area FROM existing_area) IS NULL) ON CONFLICT (country_id) DO UPDATE SET country_name = EXCLUDED.country_name, country_name_es = EXCLUDED.country_name_es, country_name_en = EXCLUDED.country_name_en, is_maritime = ${IS_MARITIME_CONFLICT_VALUE}, geom = CASE WHEN (SELECT area FROM new_area) IS NOT NULL AND (SELECT area FROM new_area) > COALESCE((SELECT area FROM existing_area), 0) * 0.5 THEN ST_SetSRID(EXCLUDED.geom, 4326) ELSE ${COUNTRIES_TABLE}.geom END WHERE (SELECT area FROM new_area) IS NOT NULL AND ((SELECT area FROM new_area) > COALESCE((SELECT area FROM existing_area), 0) * 0.5 OR (SELECT area FROM existing_area) IS NULL);\""
    fi

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
 # Determine which table to use (countries or countries_new)
 local COUNTRIES_TABLE
 COUNTRIES_TABLE=$(__get_countries_table_name)

 # Verify table exists before attempting insert
 __logd "Verifying ${COUNTRIES_TABLE} table exists before insert for boundary ${ID}..."
 local TABLE_EXISTS
 TABLE_EXISTS=$(psql -d "${DBNAME}" -Atq -c "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = '${COUNTRIES_TABLE}')" 2> /dev/null || echo "f")

 if [[ "${TABLE_EXISTS}" != "t" ]]; then
  __loge "CRITICAL: ${COUNTRIES_TABLE} table does not exist in database ${DBNAME}"
  __loge "Attempted to insert boundary ${ID} (${NAME})"
  __loge "Thread PID: ${BASHPID}, Parent PID: $$"
  __loge "This indicates a serious database issue"
  __handle_error_with_cleanup "${ERROR_GENERAL}" "Table ${COUNTRIES_TABLE} not found in database ${DBNAME}" \
   "rm -f ${JSON_FILE} ${GEOJSON_FILE} 2>/dev/null || true; rmdir ${PROCESS_LOCK} 2>/dev/null || true"
  __log_finish
  return 1
 fi
 __logd "Confirmed: ${COUNTRIES_TABLE} table exists in database ${DBNAME}"

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

 # Determine is_maritime value for ON CONFLICT clause
 # For maritime boundaries, always use TRUE explicitly
 local IS_MARITIME_CONFLICT_VALUE
 if [[ "${IS_MARITIME_VALUE}" == "true" ]]; then
  IS_MARITIME_CONFLICT_VALUE="TRUE"
 else
  IS_MARITIME_CONFLICT_VALUE="EXCLUDED.is_maritime"
 fi

 # Build SQL with dynamic table name
 # Note: For countries_new, we don't check existing_area from countries table
 # since we're building a fresh table. We only validate minimum area.
 local COUNTRIES_TABLE
 COUNTRIES_TABLE=$(__get_countries_table_name)

 local PROCESS_OPERATION
 if [[ "${ID}" -eq 16239 ]]; then
  __logd "Preparing to insert boundary ${ID} with ST_Buffer processing into ${COUNTRIES_TABLE}"
  # For countries_new, skip existing_area check (table is being built fresh)
  if [[ "${COUNTRIES_TABLE}" == "countries_new" ]]; then
   PROCESS_OPERATION="psql -d ${DBNAME} -c \"WITH new_geom AS (SELECT ST_SetSRID(ST_Union(ST_Buffer(geometry, 0.0)), 4326) AS geom FROM import WHERE ST_GeometryType(geometry) IN ('ST_Polygon', 'ST_MultiPolygon')), new_area AS (SELECT ST_Area(geom::geography) AS area FROM new_geom WHERE geom IS NOT NULL) INSERT INTO ${COUNTRIES_TABLE} (country_id, country_name, country_name_es, country_name_en, geom, is_maritime) SELECT ${SANITIZED_ID}, '${NAME}', '${NAME_ES}', '${NAME_EN}', new_geom.geom, ${IS_MARITIME_VALUE} FROM new_geom WHERE new_geom.geom IS NOT NULL AND (SELECT area FROM new_area) IS NOT NULL AND (SELECT area FROM new_area) > 1000 ON CONFLICT (country_id) DO UPDATE SET country_name = EXCLUDED.country_name, country_name_es = EXCLUDED.country_name_es, country_name_en = EXCLUDED.country_name_en, is_maritime = ${IS_MARITIME_CONFLICT_VALUE}, geom = ST_SetSRID(EXCLUDED.geom, 4326);\""
  else
   # Original logic for countries table (checks existing area)
   PROCESS_OPERATION="psql -d ${DBNAME} -c \"WITH new_geom AS (SELECT ST_SetSRID(ST_Union(ST_Buffer(geometry, 0.0)), 4326) AS geom FROM import WHERE ST_GeometryType(geometry) IN ('ST_Polygon', 'ST_MultiPolygon')), new_area AS (SELECT ST_Area(geom::geography) AS area FROM new_geom WHERE geom IS NOT NULL), existing_area AS (SELECT ST_Area(geom::geography) AS area FROM ${COUNTRIES_TABLE} WHERE country_id = ${SANITIZED_ID}) INSERT INTO ${COUNTRIES_TABLE} (country_id, country_name, country_name_es, country_name_en, geom, is_maritime) SELECT ${SANITIZED_ID}, '${NAME}', '${NAME_ES}', '${NAME_EN}', new_geom.geom, ${IS_MARITIME_VALUE} FROM new_geom WHERE new_geom.geom IS NOT NULL AND (SELECT area FROM new_area) IS NOT NULL AND ((SELECT area FROM new_area) > 1000 OR (SELECT area FROM existing_area) IS NULL) ON CONFLICT (country_id) DO UPDATE SET country_name = EXCLUDED.country_name, country_name_es = EXCLUDED.country_name_es, country_name_en = EXCLUDED.country_name_en, is_maritime = ${IS_MARITIME_CONFLICT_VALUE}, geom = CASE WHEN (SELECT area FROM new_area) IS NOT NULL AND (SELECT area FROM new_area) > COALESCE((SELECT area FROM existing_area), 0) * 0.5 THEN ST_SetSRID(EXCLUDED.geom, 4326) ELSE ${COUNTRIES_TABLE}.geom END WHERE (SELECT area FROM new_area) IS NOT NULL AND ((SELECT area FROM new_area) > COALESCE((SELECT area FROM existing_area), 0) * 0.5 OR (SELECT area FROM existing_area) IS NULL);\""
  fi
 else
  __logd "Preparing to insert boundary ${ID} with standard processing into ${COUNTRIES_TABLE}"
  # For countries_new, skip existing_area check (table is being built fresh)
  if [[ "${COUNTRIES_TABLE}" == "countries_new" ]]; then
   PROCESS_OPERATION="psql -d ${DBNAME} -c \"WITH new_geom AS (SELECT ST_SetSRID(ST_Union(ST_makeValid(geometry)), 4326) AS geom FROM import WHERE ST_GeometryType(geometry) IN ('ST_Polygon', 'ST_MultiPolygon')), new_area AS (SELECT ST_Area(geom::geography) AS area FROM new_geom WHERE geom IS NOT NULL) INSERT INTO ${COUNTRIES_TABLE} (country_id, country_name, country_name_es, country_name_en, geom, is_maritime) SELECT ${SANITIZED_ID}, '${NAME}', '${NAME_ES}', '${NAME_EN}', new_geom.geom, ${IS_MARITIME_VALUE} FROM new_geom WHERE new_geom.geom IS NOT NULL AND (SELECT area FROM new_area) IS NOT NULL AND (SELECT area FROM new_area) > 1000 ON CONFLICT (country_id) DO UPDATE SET country_name = EXCLUDED.country_name, country_name_es = EXCLUDED.country_name_es, country_name_en = EXCLUDED.country_name_en, is_maritime = ${IS_MARITIME_CONFLICT_VALUE}, geom = ST_SetSRID(EXCLUDED.geom, 4326);\""
  else
   # Original logic for countries table (checks existing area)
   PROCESS_OPERATION="psql -d ${DBNAME} -c \"WITH new_geom AS (SELECT ST_SetSRID(ST_Union(ST_makeValid(geometry)), 4326) AS geom FROM import WHERE ST_GeometryType(geometry) IN ('ST_Polygon', 'ST_MultiPolygon')), new_area AS (SELECT ST_Area(geom::geography) AS area FROM new_geom WHERE geom IS NOT NULL), existing_area AS (SELECT ST_Area(geom::geography) AS area FROM ${COUNTRIES_TABLE} WHERE country_id = ${SANITIZED_ID}) INSERT INTO ${COUNTRIES_TABLE} (country_id, country_name, country_name_es, country_name_en, geom, is_maritime) SELECT ${SANITIZED_ID}, '${NAME}', '${NAME_ES}', '${NAME_EN}', new_geom.geom, ${IS_MARITIME_VALUE} FROM new_geom WHERE new_geom.geom IS NOT NULL AND (SELECT area FROM new_area) IS NOT NULL AND ((SELECT area FROM new_area) > 1000 OR (SELECT area FROM existing_area) IS NULL) ON CONFLICT (country_id) DO UPDATE SET country_name = EXCLUDED.country_name, country_name_es = EXCLUDED.country_name_es, country_name_en = EXCLUDED.country_name_en, is_maritime = ${IS_MARITIME_CONFLICT_VALUE}, geom = CASE WHEN (SELECT area FROM new_area) IS NOT NULL AND (SELECT area FROM new_area) > COALESCE((SELECT area FROM existing_area), 0) * 0.5 THEN ST_SetSRID(EXCLUDED.geom, 4326) ELSE ${COUNTRIES_TABLE}.geom END WHERE (SELECT area FROM new_area) IS NOT NULL AND ((SELECT area FROM new_area) > COALESCE((SELECT area FROM existing_area), 0) * 0.5 OR (SELECT area FROM existing_area) IS NULL);\""
  fi
 fi

 __logd "Executing insert operation for boundary ${ID} (country: ${NAME}) into ${COUNTRIES_TABLE}"
 if ! __retry_file_operation "${PROCESS_OPERATION}" 2 3 ""; then
  __loge "Failed to insert boundary ${ID} into ${COUNTRIES_TABLE} table"
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

# Downloads a boundary JSON and converts it to GeoJSON only (no DB import)
# Parameters:
#   $1: Boundary ID
# Returns: 0 on success, 1 on failure
function __downloadBoundary_json_geojson_only() {
 __log_start
 local BOUNDARY_ID="${1}"
 local LOCAL_JSON_FILE="${TMP_DIR}/${BOUNDARY_ID}.json"
 local LOCAL_GEOJSON_FILE="${TMP_DIR}/${BOUNDARY_ID}.geojson"
 local QUERY_FILE_LOCAL="${TMP_DIR}/query.${BOUNDARY_ID}.op"

 __logi "Downloading boundary ${BOUNDARY_ID} (JSON + GeoJSON only, no DB import)"

 # Create query file
 cat << EOF > "${QUERY_FILE_LOCAL}"
[out:json];
rel(${BOUNDARY_ID});
(._;>;);
out;
EOF

 # Download JSON
 local OUTPUT_OVERPASS="${TMP_DIR}/output.${BOUNDARY_ID}"
 local MAX_RETRIES_LOCAL="${OVERPASS_RETRIES_PER_ENDPOINT:-7}"
 local BASE_DELAY_LOCAL="${OVERPASS_BACKOFF_SECONDS:-20}"

 if ! __overpass_download_with_endpoints "${QUERY_FILE_LOCAL}" "${LOCAL_JSON_FILE}" "${OUTPUT_OVERPASS}" "${MAX_RETRIES_LOCAL}" "${BASE_DELAY_LOCAL}"; then
  __loge "Failed to download JSON for boundary ${BOUNDARY_ID}"
  rm -f "${LOCAL_JSON_FILE}" "${OUTPUT_OVERPASS}" "${QUERY_FILE_LOCAL}" 2> /dev/null || true
  __log_finish
  return 1
 fi
 rm -f "${OUTPUT_OVERPASS}"

 # Validate JSON
 if ! __validate_json_with_element "${LOCAL_JSON_FILE}" "elements"; then
  __loge "Invalid JSON for boundary ${BOUNDARY_ID}"
  rm -f "${LOCAL_JSON_FILE}" "${QUERY_FILE_LOCAL}" 2> /dev/null || true
  __log_finish
  return 1
 fi

 # Convert to GeoJSON
 if ! osmtogeojson "${LOCAL_JSON_FILE}" > "${LOCAL_GEOJSON_FILE}" 2> /dev/null; then
  __loge "Failed to convert to GeoJSON for boundary ${BOUNDARY_ID}"
  rm -f "${LOCAL_JSON_FILE}" "${LOCAL_GEOJSON_FILE}" "${QUERY_FILE_LOCAL}" 2> /dev/null || true
  __log_finish
  return 1
 fi

 # Validate GeoJSON
 if ! __validate_json_with_element "${LOCAL_GEOJSON_FILE}" "features"; then
  __loge "Invalid GeoJSON for boundary ${BOUNDARY_ID}"
  rm -f "${LOCAL_JSON_FILE}" "${LOCAL_GEOJSON_FILE}" "${QUERY_FILE_LOCAL}" 2> /dev/null || true
  __log_finish
  return 1
 fi

 # Verify GeoJSON has features
 local FEATURE_COUNT
 FEATURE_COUNT=$(jq '.features | length' "${LOCAL_GEOJSON_FILE}" 2> /dev/null || echo "0")
 if [[ "${FEATURE_COUNT}" -eq 0 ]] || [[ "${FEATURE_COUNT}" == "null" ]]; then
  __loge "GeoJSON has no features for boundary ${BOUNDARY_ID}"
  rm -f "${LOCAL_JSON_FILE}" "${LOCAL_GEOJSON_FILE}" "${QUERY_FILE_LOCAL}" 2> /dev/null || true
  __log_finish
  return 1
 fi

 __logi "Successfully downloaded and converted boundary ${BOUNDARY_ID} to GeoJSON"
 rm -f "${QUERY_FILE_LOCAL}" 2> /dev/null || true
 __log_finish
 return 0
}

# Imports a GeoJSON file to database with simplified validations
# Parameters:
#   $1: Boundary ID
#   $2: GeoJSON file path
# Returns: 0 on success, 1 on failure
function __importBoundary_simplified() {
 __log_start
 local BOUNDARY_ID="${1}"
 local GEOJSON_FILE="${2}"

 __logi "Importing boundary ${BOUNDARY_ID} with simplified validations"

 # Extract names
 set +o pipefail
 local NAME_RAW
 NAME_RAW=$(grep "\"name\":" "${GEOJSON_FILE}" | head -1 | awk -F\" '{print $4}' || echo "")
 local NAME_ES_RAW
 NAME_ES_RAW=$(grep "\"name:es\":" "${GEOJSON_FILE}" | head -1 | awk -F\" '{print $4}' || echo "")
 local NAME_EN_RAW
 NAME_EN_RAW=$(grep "\"name:en\":" "${GEOJSON_FILE}" | head -1 | awk -F\" '{print $4}' || echo "")
 set -o pipefail
 set -e

 # Sanitize names (handle empty strings)
 local NAME
 NAME=$(__sanitize_sql_string "${NAME_RAW}" 2> /dev/null || echo "")
 local NAME_ES
 NAME_ES=$(__sanitize_sql_string "${NAME_ES_RAW}" 2> /dev/null || echo "")
 local NAME_EN
 NAME_EN=$(__sanitize_sql_string "${NAME_EN_RAW}" 2> /dev/null || echo "")
 NAME_EN="${NAME_EN:-No English name}"

 # Initialize IS_MARITIME
 local IS_MARITIME_VALUE="${IS_MARITIME:-false}"
 if [[ "${IS_MARITIME_VALUE}" == "true" ]]; then
  IS_MARITIME_VALUE="true"
 else
  IS_MARITIME_VALUE="false"
 fi

 # Sanitize ID (must succeed for valid boundary ID)
 local SANITIZED_ID
 SANITIZED_ID=$(__sanitize_sql_integer "${BOUNDARY_ID}" 2> /dev/null)
 if [[ -z "${SANITIZED_ID}" ]]; then
  __loge "Failed to sanitize boundary ID: ${BOUNDARY_ID}"
  __log_finish
  return 1
 fi

 # Truncate import table
 if ! psql -d "${DBNAME}" -c "TRUNCATE TABLE import" > /dev/null 2>&1; then
  __logw "Warning: Failed to truncate import table (may not exist yet)"
 fi

 # Import GeoJSON with ogr2ogr
 local OGR_ERROR_LOG="${TMP_DIR}/ogr_error.${BOUNDARY_ID}.log"
 local IMPORT_OPERATION

 if [[ "${BOUNDARY_ID}" -eq 16239 ]]; then
  # Austria - special handling
  IMPORT_OPERATION="ogr2ogr -f PostgreSQL PG:dbname=${DBNAME} -nln import -overwrite -skipfailures -nlt PROMOTE_TO_MULTI -a_srs EPSG:4326 -lco GEOMETRY_NAME=geometry -select geometry --config PG_USE_COPY YES ${GEOJSON_FILE} 2> ${OGR_ERROR_LOG}"
 else
  IMPORT_OPERATION="ogr2ogr -f PostgreSQL PG:dbname=${DBNAME} -nln import -overwrite -skipfailures -nlt PROMOTE_TO_MULTI -a_srs EPSG:4326 -lco GEOMETRY_NAME=geometry -select geometry --config PG_USE_COPY YES ${GEOJSON_FILE} 2> ${OGR_ERROR_LOG}"
 fi

 if ! eval "${IMPORT_OPERATION}"; then
  # Try with PG_USE_COPY NO
  __logw "Retrying import with PG_USE_COPY NO for boundary ${BOUNDARY_ID}"
  IMPORT_OPERATION="ogr2ogr -f PostgreSQL PG:dbname=${DBNAME} -nln import -overwrite -skipfailures -nlt PROMOTE_TO_MULTI -a_srs EPSG:4326 -lco GEOMETRY_NAME=geometry -select geometry --config PG_USE_COPY NO ${GEOJSON_FILE} 2> ${OGR_ERROR_LOG}"
  if ! eval "${IMPORT_OPERATION}"; then
   __loge "Failed to import GeoJSON for boundary ${BOUNDARY_ID}"
   rm -f "${OGR_ERROR_LOG}" 2> /dev/null || true
   __log_finish
   return 1
  fi
 fi

 # Verify import has polygons
 local POLYGON_COUNT
 POLYGON_COUNT=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM import WHERE ST_GeometryType(geometry) IN ('ST_Polygon', 'ST_MultiPolygon') AND NOT ST_IsEmpty(geometry);" 2> /dev/null || echo "0")

 if [[ "${POLYGON_COUNT}" -eq 0 ]]; then
  __loge "No polygon geometries found in import table for boundary ${BOUNDARY_ID}"
  rm -f "${OGR_ERROR_LOG}" 2> /dev/null || true
  __log_finish
  return 1
 fi

 # Determine is_maritime value for ON CONFLICT clause
 # For maritime boundaries, always use TRUE explicitly
 local IS_MARITIME_CONFLICT_VALUE
 if [[ "${IS_MARITIME_VALUE}" == "true" ]]; then
  IS_MARITIME_CONFLICT_VALUE="TRUE"
 else
  IS_MARITIME_CONFLICT_VALUE="EXCLUDED.is_maritime"
 fi

 # Insert into countries table - SIMPLIFIED (no area validation)
 # Determine which table to use
 local COUNTRIES_TABLE
 COUNTRIES_TABLE=$(__get_countries_table_name)

 local INSERT_OPERATION
 if [[ "${BOUNDARY_ID}" -eq 16239 ]]; then
  # Austria - use ST_Buffer
  INSERT_OPERATION="psql -d ${DBNAME} -c \"INSERT INTO ${COUNTRIES_TABLE} (country_id, country_name, country_name_es, country_name_en, geom, is_maritime) SELECT ${SANITIZED_ID}, '${NAME}', '${NAME_ES}', '${NAME_EN}', ST_SetSRID(ST_Union(ST_Buffer(geometry, 0.0)), 4326), ${IS_MARITIME_VALUE} FROM import WHERE ST_GeometryType(geometry) IN ('ST_Polygon', 'ST_MultiPolygon') ON CONFLICT (country_id) DO UPDATE SET country_name = EXCLUDED.country_name, country_name_es = EXCLUDED.country_name_es, country_name_en = EXCLUDED.country_name_en, is_maritime = ${IS_MARITIME_CONFLICT_VALUE}, geom = ST_SetSRID(EXCLUDED.geom, 4326);\""
 else
  INSERT_OPERATION="psql -d ${DBNAME} -c \"INSERT INTO ${COUNTRIES_TABLE} (country_id, country_name, country_name_es, country_name_en, geom, is_maritime) SELECT ${SANITIZED_ID}, '${NAME}', '${NAME_ES}', '${NAME_EN}', ST_SetSRID(ST_Union(ST_MakeValid(geometry)), 4326), ${IS_MARITIME_VALUE} FROM import WHERE ST_GeometryType(geometry) IN ('ST_Polygon', 'ST_MultiPolygon') ON CONFLICT (country_id) DO UPDATE SET country_name = EXCLUDED.country_name, country_name_es = EXCLUDED.country_name_es, country_name_en = EXCLUDED.country_name_en, is_maritime = ${IS_MARITIME_CONFLICT_VALUE}, geom = ST_SetSRID(EXCLUDED.geom, 4326);\""
 fi

 if ! eval "${INSERT_OPERATION}"; then
  __loge "Failed to insert boundary ${BOUNDARY_ID} into ${COUNTRIES_TABLE} table"
  rm -f "${OGR_ERROR_LOG}" 2> /dev/null || true
  __log_finish
  return 1
 fi

 # Verify insert succeeded
 local COUNTRIES_TABLE
 COUNTRIES_TABLE=$(__get_countries_table_name)
 local INSERTED_COUNT
 INSERTED_COUNT=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM ${COUNTRIES_TABLE} WHERE country_id = ${SANITIZED_ID} AND geom IS NOT NULL;" 2> /dev/null || echo "0")

 if [[ "${INSERTED_COUNT}" -eq 0 ]]; then
  __loge "Insert verification failed: boundary ${BOUNDARY_ID} not found in ${COUNTRIES_TABLE} table after insert"
  rm -f "${OGR_ERROR_LOG}" 2> /dev/null || true
  __log_finish
  return 1
 fi

 __logi "Successfully imported boundary ${BOUNDARY_ID} to database"
 rm -f "${OGR_ERROR_LOG}" 2> /dev/null || true
 __log_finish
 return 0
}

# Downloads a single maritime boundary (JSON + GeoJSON only, no DB import)
# Parameters:
#   $1: Maritime boundary ID
# Returns: 0 on success, 1 on failure
function __downloadMaritime_json_geojson_only() {
 __log_start
 local BOUNDARY_ID="${1}"
 local LOCAL_JSON_FILE="${TMP_DIR}/${BOUNDARY_ID}.json"
 local LOCAL_GEOJSON_FILE="${TMP_DIR}/${BOUNDARY_ID}.geojson"
 local QUERY_FILE_LOCAL="${TMP_DIR}/query.${BOUNDARY_ID}.op"

 __logi "Downloading maritime boundary ${BOUNDARY_ID} (JSON + GeoJSON only, no DB import)"

 # Create query file
 cat << EOF > "${QUERY_FILE_LOCAL}"
[out:json];
rel(${BOUNDARY_ID});
(._;>;);
out;
EOF

 # Download JSON
 local OUTPUT_OVERPASS="${TMP_DIR}/output.${BOUNDARY_ID}"
 local MAX_RETRIES_LOCAL="${OVERPASS_RETRIES_PER_ENDPOINT:-7}"
 local BASE_DELAY_LOCAL="${OVERPASS_BACKOFF_SECONDS:-20}"

 if ! __overpass_download_with_endpoints "${QUERY_FILE_LOCAL}" "${LOCAL_JSON_FILE}" "${OUTPUT_OVERPASS}" "${MAX_RETRIES_LOCAL}" "${BASE_DELAY_LOCAL}"; then
  __loge "Failed to download JSON for maritime boundary ${BOUNDARY_ID}"
  rm -f "${LOCAL_JSON_FILE}" "${OUTPUT_OVERPASS}" "${QUERY_FILE_LOCAL}" 2> /dev/null || true
  __log_finish
  return 1
 fi
 rm -f "${OUTPUT_OVERPASS}"

 # Validate JSON
 if ! __validate_json_with_element "${LOCAL_JSON_FILE}" "elements"; then
  __loge "Invalid JSON for maritime boundary ${BOUNDARY_ID}"
  rm -f "${LOCAL_JSON_FILE}" "${QUERY_FILE_LOCAL}" 2> /dev/null || true
  __log_finish
  return 1
 fi

 # Convert to GeoJSON
 if ! osmtogeojson "${LOCAL_JSON_FILE}" > "${LOCAL_GEOJSON_FILE}" 2> /dev/null; then
  __loge "Failed to convert to GeoJSON for maritime boundary ${BOUNDARY_ID}"
  rm -f "${LOCAL_JSON_FILE}" "${LOCAL_GEOJSON_FILE}" "${QUERY_FILE_LOCAL}" 2> /dev/null || true
  __log_finish
  return 1
 fi

 # Validate GeoJSON
 if ! __validate_json_with_element "${LOCAL_GEOJSON_FILE}" "features"; then
  __loge "Invalid GeoJSON for maritime boundary ${BOUNDARY_ID}"
  rm -f "${LOCAL_JSON_FILE}" "${LOCAL_GEOJSON_FILE}" "${QUERY_FILE_LOCAL}" 2> /dev/null || true
  __log_finish
  return 1
 fi

 # Verify GeoJSON has features
 local FEATURE_COUNT
 FEATURE_COUNT=$(jq '.features | length' "${LOCAL_GEOJSON_FILE}" 2> /dev/null || echo "0")
 if [[ "${FEATURE_COUNT}" -eq 0 ]] || [[ "${FEATURE_COUNT}" == "null" ]]; then
  __loge "GeoJSON has no features for maritime boundary ${BOUNDARY_ID}"
  rm -f "${LOCAL_JSON_FILE}" "${LOCAL_GEOJSON_FILE}" "${QUERY_FILE_LOCAL}" 2> /dev/null || true
  __log_finish
  return 1
 fi

 __logi "Successfully downloaded and converted maritime boundary ${BOUNDARY_ID} to GeoJSON"
 rm -f "${QUERY_FILE_LOCAL}" 2> /dev/null || true
 __log_finish
 return 0
}

# Imports a maritime boundary GeoJSON file to database with simplified validations
# Parameters:
#   $1: Maritime boundary ID
#   $2: GeoJSON file path
# Returns: 0 on success, 1 on failure
function __importMaritime_simplified() {
 __log_start
 local BOUNDARY_ID="${1}"
 local GEOJSON_FILE="${2}"

 __logi "Importing maritime boundary ${BOUNDARY_ID} with simplified validations"

 # Extract names
 set +o pipefail
 local NAME_RAW
 NAME_RAW=$(grep "\"name\":" "${GEOJSON_FILE}" | head -1 | awk -F\" '{print $4}' || echo "")
 local NAME_ES_RAW
 NAME_ES_RAW=$(grep "\"name:es\":" "${GEOJSON_FILE}" | head -1 | awk -F\" '{print $4}' || echo "")
 local NAME_EN_RAW
 NAME_EN_RAW=$(grep "\"name:en\":" "${GEOJSON_FILE}" | head -1 | awk -F\" '{print $4}' || echo "")
 set -o pipefail
 set -e

 # Sanitize names (handle empty strings)
 local NAME
 NAME=$(__sanitize_sql_string "${NAME_RAW}" 2> /dev/null || echo "")
 local NAME_ES
 NAME_ES=$(__sanitize_sql_string "${NAME_ES_RAW}" 2> /dev/null || echo "")
 local NAME_EN
 NAME_EN=$(__sanitize_sql_string "${NAME_EN_RAW}" 2> /dev/null || echo "")
 NAME_EN="${NAME_EN:-No English name}"

 # Maritime boundaries always have is_maritime = true
 local IS_MARITIME_VALUE="true"

 # Sanitize ID (must succeed for valid boundary ID)
 local SANITIZED_ID
 SANITIZED_ID=$(__sanitize_sql_integer "${BOUNDARY_ID}" 2> /dev/null)
 if [[ -z "${SANITIZED_ID}" ]]; then
  __loge "Failed to sanitize maritime boundary ID: ${BOUNDARY_ID}"
  __log_finish
  return 1
 fi

 # Truncate import table
 if ! psql -d "${DBNAME}" -c "TRUNCATE TABLE import" > /dev/null 2>&1; then
  __logw "Warning: Failed to truncate import table (may not exist yet)"
 fi

 # Import GeoJSON with ogr2ogr
 local OGR_ERROR_LOG="${TMP_DIR}/ogr_error.${BOUNDARY_ID}.log"
 local IMPORT_OPERATION
 IMPORT_OPERATION="ogr2ogr -f PostgreSQL PG:dbname=${DBNAME} -nln import -overwrite -skipfailures -nlt PROMOTE_TO_MULTI -a_srs EPSG:4326 -lco GEOMETRY_NAME=geometry -select geometry --config PG_USE_COPY YES ${GEOJSON_FILE} 2> ${OGR_ERROR_LOG}"

 if ! eval "${IMPORT_OPERATION}"; then
  # Try with PG_USE_COPY NO
  __logw "Retrying import with PG_USE_COPY NO for maritime boundary ${BOUNDARY_ID}"
  IMPORT_OPERATION="ogr2ogr -f PostgreSQL PG:dbname=${DBNAME} -nln import -overwrite -skipfailures -nlt PROMOTE_TO_MULTI -a_srs EPSG:4326 -lco GEOMETRY_NAME=geometry -select geometry --config PG_USE_COPY NO ${GEOJSON_FILE} 2> ${OGR_ERROR_LOG}"
  if ! eval "${IMPORT_OPERATION}"; then
   __loge "Failed to import GeoJSON for maritime boundary ${BOUNDARY_ID}"
   rm -f "${OGR_ERROR_LOG}" 2> /dev/null || true
   __log_finish
   return 1
  fi
 fi

 # Verify import has polygons
 local POLYGON_COUNT
 POLYGON_COUNT=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM import WHERE ST_GeometryType(geometry) IN ('ST_Polygon', 'ST_MultiPolygon') AND NOT ST_IsEmpty(geometry);" 2> /dev/null || echo "0")

 if [[ "${POLYGON_COUNT}" -eq 0 ]]; then
  __loge "No polygon geometries found in import table for maritime boundary ${BOUNDARY_ID}"
  rm -f "${OGR_ERROR_LOG}" 2> /dev/null || true
  __log_finish
  return 1
 fi

 # Insert into countries table - SIMPLIFIED (no area validation, always is_maritime=true)
 # Maritime boundaries always have is_maritime = TRUE, even on conflict
 # Determine which table to use
 local COUNTRIES_TABLE
 COUNTRIES_TABLE=$(__get_countries_table_name)

 local INSERT_OPERATION
 INSERT_OPERATION="psql -d ${DBNAME} -c \"INSERT INTO ${COUNTRIES_TABLE} (country_id, country_name, country_name_es, country_name_en, geom, is_maritime) SELECT ${SANITIZED_ID}, '${NAME}', '${NAME_ES}', '${NAME_EN}', ST_SetSRID(ST_Union(ST_MakeValid(geometry)), 4326), ${IS_MARITIME_VALUE} FROM import WHERE ST_GeometryType(geometry) IN ('ST_Polygon', 'ST_MultiPolygon') ON CONFLICT (country_id) DO UPDATE SET country_name = EXCLUDED.country_name, country_name_es = EXCLUDED.country_name_es, country_name_en = EXCLUDED.country_name_en, is_maritime = TRUE, geom = ST_SetSRID(EXCLUDED.geom, 4326);\""

 if ! eval "${INSERT_OPERATION}"; then
  __loge "Failed to insert maritime boundary ${BOUNDARY_ID} into countries table"
  rm -f "${OGR_ERROR_LOG}" 2> /dev/null || true
  __log_finish
  return 1
 fi

 # Verify insert succeeded
 local INSERTED_COUNT
 local COUNTRIES_TABLE
 COUNTRIES_TABLE=$(__get_countries_table_name)
 INSERTED_COUNT=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM ${COUNTRIES_TABLE} WHERE country_id = ${SANITIZED_ID} AND geom IS NOT NULL AND is_maritime = true;" 2> /dev/null || echo "0")

 if [[ "${INSERTED_COUNT}" -eq 0 ]]; then
  __loge "Insert verification failed: maritime boundary ${BOUNDARY_ID} not found in countries table after insert"
  rm -f "${OGR_ERROR_LOG}" 2> /dev/null || true
  __log_finish
  return 1
 fi

 __logi "Successfully imported maritime boundary ${BOUNDARY_ID} to database"
 rm -f "${OGR_ERROR_LOG}" 2> /dev/null || true
 __log_finish
 return 0
}

# Downloads maritime boundaries in parallel (JSON + GeoJSON only, no DB import)
# Parameters:
#   $1: File containing maritime boundary IDs (one per line)
# Returns: 0 on success, 1 on failure
function __downloadMaritimes_parallel_new() {
 __log_start
 local BOUNDARIES_FILE="${1}"
 local DOWNLOAD_THREADS="${DOWNLOAD_MAX_THREADS:-4}"

 __logi "Starting parallel download of maritime boundaries (threads: ${DOWNLOAD_THREADS})"

 local TOTAL_LINES
 TOTAL_LINES=$(wc -l < "${BOUNDARIES_FILE}")
 __logi "Total maritime boundaries to download: ${TOTAL_LINES}"

 # Split file into parts (only if more than 1 line)
 if [[ "${TOTAL_LINES}" -gt 0 ]]; then
  local SIZE=$((TOTAL_LINES / DOWNLOAD_THREADS))
  if [[ "${SIZE}" -eq 0 ]]; then
   SIZE=1
  else
   SIZE=$((SIZE + 1))
  fi
  split -l"${SIZE}" "${BOUNDARIES_FILE}" "${TMP_DIR}/download_maritime_part_"
 else
  __loge "Empty maritime boundaries file provided"
  __log_finish
  return 1
 fi

 # Track downloads
 local SUCCESS_FILE="${TMP_DIR}/download_maritime_success.txt"
 local FAILED_FILE="${TMP_DIR}/download_maritime_failed.txt"
 rm -f "${SUCCESS_FILE}" "${FAILED_FILE}"

 # Download in parallel with separate logs per thread
 local JOB_COUNT=0
 local PART_NUM=0
 for PART_FILE in "${TMP_DIR}"/download_maritime_part_??; do
  PART_NUM=$((PART_NUM + 1))
  (
   local PART_PID="${BASHPID}"
   local PART_LOG_FILE="${TMP_DIR}/download_maritime_part_${PART_NUM}.log"
   local PART_SUCCESS=0
   local PART_FAILED=0

   # Redirect all output to part-specific log file
   exec 1>> "${PART_LOG_FILE}" 2>&1

   # Get part file name for logging
   local PART_NAME
   PART_NAME=$(basename "${PART_FILE}")

   echo "=== MARITIME DOWNLOAD PART ${PART_NUM} (PID: ${PART_PID}) ==="
   echo "Part file: ${PART_NAME}"
   echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
   echo ""

   while read -r LINE; do
    local ID
    ID=$(echo "${LINE}" | awk '{print $1}')

    echo "[PART ${PART_NUM}] Downloading maritime boundary ${ID}..."
    if __downloadMaritime_json_geojson_only "${ID}" 2>&1; then
     echo "${ID}" >> "${SUCCESS_FILE}"
     PART_SUCCESS=$((PART_SUCCESS + 1))
     echo "[PART ${PART_NUM}] ✓ Successfully downloaded ${ID}"
    else
     echo "${ID}" >> "${FAILED_FILE}"
     PART_FAILED=$((PART_FAILED + 1))
     echo "[PART ${PART_NUM}] ✗ Failed to download ${ID}"
    fi
   done < "${PART_FILE}"

   echo ""
   echo "=== MARITIME DOWNLOAD PART ${PART_NUM} COMPLETED ==="
   echo "Part ${PART_NUM} (PID ${PART_PID}): ${PART_SUCCESS} succeeded, ${PART_FAILED} failed"
   echo "Finished: $(date '+%Y-%m-%d %H:%M:%S')"

   # Also log to main log (append)
   echo "$(date '+%Y-%m-%d %H:%M:%S') - Maritime download part ${PART_NUM} (PID ${PART_PID}): ${PART_SUCCESS} succeeded, ${PART_FAILED} failed" >> "${TMP_DIR}/updateCountries.log"
  ) &
  JOB_COUNT=$((JOB_COUNT + 1))
  sleep 1
 done

 # Wait for all downloads
 __logi "Waiting for ${JOB_COUNT} maritime download jobs to complete..."
 wait

 local SUCCESS_COUNT=0
 local FAILED_COUNT=0
 if [[ -f "${SUCCESS_FILE}" ]]; then
  SUCCESS_COUNT=$(wc -l < "${SUCCESS_FILE}" | tr -d ' ')
 fi
 if [[ -f "${FAILED_FILE}" ]]; then
  FAILED_COUNT=$(wc -l < "${FAILED_FILE}" | tr -d ' ')
 fi

 __logi "Maritime download completed: ${SUCCESS_COUNT} succeeded, ${FAILED_COUNT} failed"

 # Cleanup
 rm -f "${TMP_DIR}"/download_maritime_part_??

 if [[ "${FAILED_COUNT}" -gt 0 ]]; then
  __logw "Some maritime downloads failed. Failed IDs in: ${FAILED_FILE}"
  __log_finish
  return 1
 fi

 __log_finish
 return 0
}

# Imports maritime boundaries sequentially from downloaded GeoJSON files
# Parameters:
#   $1: File containing maritime boundary IDs that were successfully downloaded
# Returns: 0 on success, 1 on failure
function __importMaritimes_sequential_new() {
 __log_start
 local SUCCESS_FILE="${1}"

 __logi "Starting sequential import of maritime boundaries"

 local TOTAL_LINES
 TOTAL_LINES=$(wc -l < "${SUCCESS_FILE}")
 __logi "Total maritime boundaries to import: ${TOTAL_LINES}"

 local IMPORT_SUCCESS=0
 local IMPORT_FAILED=0
 local FAILED_IDS_FILE="${TMP_DIR}/import_maritime_failed.txt"
 rm -f "${FAILED_IDS_FILE}"

 local CURRENT=0
 while read -r ID; do
  CURRENT=$((CURRENT + 1))
  local GEOJSON_FILE="${TMP_DIR}/${ID}.geojson"

  __logi "Importing maritime boundary ${ID} (${CURRENT}/${TOTAL_LINES})"

  if [[ ! -f "${GEOJSON_FILE}" ]]; then
   __loge "GeoJSON file not found for maritime boundary ${ID}"
   echo "${ID}" >> "${FAILED_IDS_FILE}"
   IMPORT_FAILED=$((IMPORT_FAILED + 1))
   continue
  fi

  if __importMaritime_simplified "${ID}" "${GEOJSON_FILE}"; then
   IMPORT_SUCCESS=$((IMPORT_SUCCESS + 1))
  else
   __loge "Failed to import maritime boundary ${ID}"
   echo "${ID}" >> "${FAILED_IDS_FILE}"
   IMPORT_FAILED=$((IMPORT_FAILED + 1))
  fi
 done < "${SUCCESS_FILE}"

 __logi "Import completed: ${IMPORT_SUCCESS} succeeded, ${IMPORT_FAILED} failed"

 if [[ "${IMPORT_FAILED}" -gt 0 ]]; then
  __logw "Some maritime imports failed. Failed IDs in: ${FAILED_IDS_FILE}"
  __log_finish
  return 1
 fi

 __log_finish
 return 0
}

# Downloads countries in parallel (JSON + GeoJSON only, no DB import)
# Parameters:
#   $1: File containing boundary IDs (one per line)
# Returns: 0 on success, 1 on failure
function __downloadCountries_parallel_new() {
 __log_start
 local BOUNDARIES_FILE="${1}"
 local DOWNLOAD_THREADS="${DOWNLOAD_MAX_THREADS:-4}"

 __logi "Starting parallel download of countries (threads: ${DOWNLOAD_THREADS})"

 local TOTAL_LINES
 TOTAL_LINES=$(wc -l < "${BOUNDARIES_FILE}")
 __logi "Total countries to download: ${TOTAL_LINES}"

 # Split file into parts (only if more than 1 line)
 if [[ "${TOTAL_LINES}" -gt 0 ]]; then
  local SIZE=$((TOTAL_LINES / DOWNLOAD_THREADS))
  if [[ "${SIZE}" -eq 0 ]]; then
   SIZE=1
  else
   SIZE=$((SIZE + 1))
  fi
  split -l"${SIZE}" "${BOUNDARIES_FILE}" "${TMP_DIR}/download_part_"
 else
  __loge "Empty boundaries file provided"
  __log_finish
  return 1
 fi

 # Track downloads
 local SUCCESS_FILE="${TMP_DIR}/download_success.txt"
 local FAILED_FILE="${TMP_DIR}/download_failed.txt"
 rm -f "${SUCCESS_FILE}" "${FAILED_FILE}"

 # Download in parallel with separate logs per thread
 local JOB_COUNT=0
 local PART_NUM=0
 for PART_FILE in "${TMP_DIR}"/download_part_??; do
  PART_NUM=$((PART_NUM + 1))
  (
   local PART_PID="${BASHPID}"
   local PART_LOG_FILE="${TMP_DIR}/download_part_${PART_NUM}.log"
   local PART_SUCCESS=0
   local PART_FAILED=0

   # Redirect all output to part-specific log file
   exec 1>> "${PART_LOG_FILE}" 2>&1

   # Get part file name for logging
   local PART_NAME
   PART_NAME=$(basename "${PART_FILE}")

   echo "=== DOWNLOAD PART ${PART_NUM} (PID: ${PART_PID}) ==="
   echo "Part file: ${PART_NAME}"
   echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
   echo ""

   while read -r LINE; do
    local ID
    ID=$(echo "${LINE}" | awk '{print $1}')

    echo "[PART ${PART_NUM}] Downloading boundary ${ID}..."
    if __downloadBoundary_json_geojson_only "${ID}" 2>&1; then
     echo "${ID}" >> "${SUCCESS_FILE}"
     PART_SUCCESS=$((PART_SUCCESS + 1))
     echo "[PART ${PART_NUM}] ✓ Successfully downloaded ${ID}"
    else
     echo "${ID}" >> "${FAILED_FILE}"
     PART_FAILED=$((PART_FAILED + 1))
     echo "[PART ${PART_NUM}] ✗ Failed to download ${ID}"
    fi
   done < "${PART_FILE}"

   echo ""
   echo "=== DOWNLOAD PART ${PART_NUM} COMPLETED ==="
   echo "Part ${PART_NUM} (PID ${PART_PID}): ${PART_SUCCESS} succeeded, ${PART_FAILED} failed"
   echo "Finished: $(date '+%Y-%m-%d %H:%M:%S')"

   # Also log to main log (append)
   echo "$(date '+%Y-%m-%d %H:%M:%S') - Download part ${PART_NUM} (PID ${PART_PID}): ${PART_SUCCESS} succeeded, ${PART_FAILED} failed" >> "${TMP_DIR}/updateCountries.log"
  ) &
  JOB_COUNT=$((JOB_COUNT + 1))
  sleep 1
 done

 # Wait for all downloads
 __logi "Waiting for ${JOB_COUNT} download jobs to complete..."
 wait

 local SUCCESS_COUNT=0
 local FAILED_COUNT=0
 if [[ -f "${SUCCESS_FILE}" ]]; then
  SUCCESS_COUNT=$(wc -l < "${SUCCESS_FILE}" | tr -d ' ')
 fi
 if [[ -f "${FAILED_FILE}" ]]; then
  FAILED_COUNT=$(wc -l < "${FAILED_FILE}" | tr -d ' ')
 fi

 __logi "Download completed: ${SUCCESS_COUNT} succeeded, ${FAILED_COUNT} failed"

 # Cleanup
 rm -f "${TMP_DIR}"/download_part_??

 if [[ "${FAILED_COUNT}" -gt 0 ]]; then
  __logw "Some downloads failed. Failed IDs in: ${FAILED_FILE}"
  __log_finish
  return 1
 fi

 __log_finish
 return 0
}

# Imports countries sequentially from downloaded GeoJSON files
# Parameters:
#   $1: File containing boundary IDs that were successfully downloaded
# Returns: 0 on success, 1 on failure
function __importCountries_sequential_new() {
 __log_start
 local SUCCESS_FILE="${1}"

 __logi "Starting sequential import of countries"

 local TOTAL_LINES
 TOTAL_LINES=$(wc -l < "${SUCCESS_FILE}")
 __logi "Total countries to import: ${TOTAL_LINES}"

 local IMPORT_SUCCESS=0
 local IMPORT_FAILED=0
 local FAILED_IDS_FILE="${TMP_DIR}/import_failed.txt"
 rm -f "${FAILED_IDS_FILE}"

 local CURRENT=0
 while read -r ID; do
  CURRENT=$((CURRENT + 1))
  local GEOJSON_FILE="${TMP_DIR}/${ID}.geojson"

  __logi "Importing country ${ID} (${CURRENT}/${TOTAL_LINES})"

  if [[ ! -f "${GEOJSON_FILE}" ]]; then
   __loge "GeoJSON file not found for boundary ${ID}"
   echo "${ID}" >> "${FAILED_IDS_FILE}"
   IMPORT_FAILED=$((IMPORT_FAILED + 1))
   continue
  fi

  if __importBoundary_simplified "${ID}" "${GEOJSON_FILE}"; then
   IMPORT_SUCCESS=$((IMPORT_SUCCESS + 1))
  else
   __loge "Failed to import boundary ${ID}"
   echo "${ID}" >> "${FAILED_IDS_FILE}"
   IMPORT_FAILED=$((IMPORT_FAILED + 1))
  fi
 done < "${SUCCESS_FILE}"

 __logi "Import completed: ${IMPORT_SUCCESS} succeeded, ${IMPORT_FAILED} failed"

 if [[ "${IMPORT_FAILED}" -gt 0 ]]; then
  __logw "Some imports failed. Failed IDs in: ${FAILED_IDS_FILE}"
  __log_finish
  return 1
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
 COUNTRIES_DOWNLOAD_OPERATION="curl -s -H \"User-Agent: ${DOWNLOAD_USER_AGENT:-OSM-Notes-Ingestion/1.0}\" -o ${COUNTRIES_BOUNDARY_IDS_FILE} --data-binary @${COUNTRIES_QUERY_FILE} ${OVERPASS_INTERPRETER} 2> ${COUNTRIES_OUTPUT_FILE}"
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
 
 # Validate it's not HTML (Overpass may return HTML error pages)
 if head -5 "${COUNTRIES_BOUNDARY_IDS_FILE}" | grep -qiE "<html|<body|<head|<!DOCTYPE"; then
  __loge "ERROR: Country list file contains HTML instead of CSV. Overpass returned an error page."
  __loge "This usually means Overpass API is too busy or timed out."
  local FIRST_LINES
  FIRST_LINES=$(head -3 "${COUNTRIES_BOUNDARY_IDS_FILE}" | tr '\n' ' ')
  __loge "First lines of response: ${FIRST_LINES}"
  # Check for specific error messages
  if grep -qi "timeout\|too busy" "${COUNTRIES_BOUNDARY_IDS_FILE}"; then
   __loge "Overpass API timeout detected. Please wait a few minutes and try again."
  fi
  __handle_error_with_cleanup "${ERROR_DOWNLOADING_BOUNDARY_ID_LIST}" \
   "Country list download returned HTML error page" \
   "__preserve_failed_boundary_artifacts '${COUNTRIES_BOUNDARY_IDS_FILE}'"
  local HANDLER_RETURN_CODE=$?
  __log_finish
  return "${HANDLER_RETURN_CODE}"
 fi
 
 # Validate it's CSV format (should start with @id or have at least one line with numbers)
 if ! head -1 "${COUNTRIES_BOUNDARY_IDS_FILE}" | grep -qE "^@id|^[0-9]+"; then
  __loge "ERROR: Country list file is not in expected CSV format"
  __loge "First line of file: $(head -1 "${COUNTRIES_BOUNDARY_IDS_FILE}")"
  __handle_error_with_cleanup "${ERROR_DOWNLOADING_BOUNDARY_ID_LIST}" \
   "Country list file format validation failed" \
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
       # Countries have is_maritime = false
       local COUNTRIES_TABLE
       COUNTRIES_TABLE=$(__get_countries_table_name)
       if psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -c "INSERT INTO ${COUNTRIES_TABLE} (country_id, country_name, country_name_es, country_name_en, geom, is_maritime) SELECT country_id, country_name, country_name_es, country_name_en, ST_SetSRID(geom, 4326), FALSE FROM ${TEMP_TABLE} WHERE country_id IN (${IDS_LIST}) ON CONFLICT (country_id) DO UPDATE SET country_name = EXCLUDED.country_name, country_name_es = EXCLUDED.country_name_es, country_name_en = EXCLUDED.country_name_en, is_maritime = EXCLUDED.is_maritime, geom = ST_SetSRID(EXCLUDED.geom, 4326); DROP TABLE ${TEMP_TABLE};" >> "${OGR_ERROR}" 2>&1; then
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

 # Check if new download flow is enabled
 if [[ "${USE_NEW_DOWNLOAD_FLOW:-true}" == "true" ]]; then
  __logi "Using NEW download flow: parallel download + sequential import"
  __logi "Download threads: ${DOWNLOAD_MAX_THREADS:-4}"

  # Phase 1: Download in parallel
  if ! __downloadCountries_parallel_new "${COUNTRIES_BOUNDARY_IDS_FILE}"; then
   __logw "Some downloads failed, but continuing with successful ones"
  fi

  # Phase 2: Import sequentially
  local SUCCESS_FILE="${TMP_DIR}/download_success.txt"
  if [[ -f "${SUCCESS_FILE}" ]] && [[ -s "${SUCCESS_FILE}" ]]; then
   local SUCCESS_COUNT
   SUCCESS_COUNT=$(wc -l < "${SUCCESS_FILE}" | tr -d ' ')
   __logi "Importing ${SUCCESS_COUNT} successfully downloaded countries sequentially"
   if ! __importCountries_sequential_new "${SUCCESS_FILE}"; then
    __logw "Some imports failed, but continuing"
   fi
  else
   __loge "No successful downloads to import"
   __log_finish
   return 1
  fi

  __logi "New download flow completed"
  __log_finish
  return 0
 fi

 # OLD FLOW: Parallel processing (download + import together)
 __logi "Using OLD download flow: parallel processing"
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
     # Use sed to extract only the ID that comes after "boundary " (avoiding false positives from timestamps, etc.)
     grep -hE "Failed to process boundary [0-9]+|Recording boundary [0-9]+ as failed" "${ERROR_LOG}" 2> /dev/null \
      | sed -E 's/.*boundary ([0-9]+).*/\1/' \
      | while read -r FAILED_ID; do
       if [[ -n "${FAILED_ID}" ]] && [[ "${FAILED_ID}" =~ ^[0-9]+$ ]] && [[ "${FAILED_ID}" -ge 1000 ]]; then
        # Only accept IDs >= 1000 to filter out false positives (real OSM relation IDs are much larger)
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
  # Import backup to temporary table first, then insert with is_maritime = TRUE
  # This ensures all maritime boundaries have is_maritime = TRUE explicitly
  __logd "Importing backup using ogr2ogr to temporary table..."
  local OGR_ERROR
  OGR_ERROR=$(mktemp)
  local TEMP_TABLE="maritimes_backup_import_$$"
  if ogr2ogr -f "PostgreSQL" "PG:dbname=${DBNAME}" "${RESOLVED_BACKUP}" \
   -nln "${TEMP_TABLE}" -nlt PROMOTE_TO_MULTI -a_srs EPSG:4326 \
   -lco GEOMETRY_NAME=geom -lco FID=country_id \
   --config PG_USE_COPY YES 2> "${OGR_ERROR}"; then
   # Insert from temporary table with is_maritime = TRUE explicitly
   # All boundaries from maritime backup are maritime by definition
   local COUNTRIES_TABLE
   COUNTRIES_TABLE=$(__get_countries_table_name)
   if psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -c "INSERT INTO ${COUNTRIES_TABLE} (country_id, country_name, country_name_es, country_name_en, geom, is_maritime) SELECT country_id, country_name, country_name_es, country_name_en, ST_SetSRID(geom, 4326), TRUE FROM ${TEMP_TABLE} ON CONFLICT (country_id) DO UPDATE SET country_name = EXCLUDED.country_name, country_name_es = EXCLUDED.country_name_es, country_name_en = EXCLUDED.country_name_en, is_maritime = TRUE, geom = ST_SetSRID(EXCLUDED.geom, 4326); DROP TABLE ${TEMP_TABLE};" >> "${OGR_ERROR}" 2>&1; then
    __logi "Successfully imported maritime boundaries from backup and set is_maritime = true"
    rm -f "${OGR_ERROR}"
    __log_finish
    return 0
   else
    __loge "Failed to insert maritime boundaries from temporary table"
    __logd "SQL error output: $(cat "${OGR_ERROR}" 2> /dev/null || echo 'No error output')"
    psql -d "${DBNAME}" -c "DROP TABLE IF EXISTS ${TEMP_TABLE};" > /dev/null 2>&1 || true
    rm -f "${OGR_ERROR}"
    __log_finish
    return 1
   fi
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
 curl -s -H "User-Agent: ${DOWNLOAD_USER_AGENT:-OSM-Notes-Ingestion/1.0}" -o "${MARITIME_BOUNDARY_IDS_FILE}" \
  --data-binary "@${OVERPASS_MARITIMES}" "${OVERPASS_INTERPRETER}"
 RET=${?}
 set -e
 if [[ "${RET}" -ne 0 ]]; then
  __loge "ERROR: Maritime border list could not be downloaded."
  __log_finish
  return "${ERROR_DOWNLOADING_BOUNDARY_ID_LIST}"
 fi

 # Validate the downloaded CSV file has content
 if [[ ! -s "${MARITIME_BOUNDARY_IDS_FILE}" ]]; then
  __loge "ERROR: Maritime border list file is empty after download."
  __log_finish
  return "${ERROR_DOWNLOADING_BOUNDARY_ID_LIST}"
 fi

 # Validate it's not HTML (Overpass may return HTML error pages)
 if head -5 "${MARITIME_BOUNDARY_IDS_FILE}" | grep -qiE "<html|<body|<head|<!DOCTYPE"; then
  __loge "ERROR: Maritime border list file contains HTML instead of CSV. Overpass returned an error page."
  __loge "This usually means Overpass API is too busy or timed out."
  local FIRST_LINES
  FIRST_LINES=$(head -3 "${MARITIME_BOUNDARY_IDS_FILE}" | tr '\n' ' ')
  __loge "First lines of response: ${FIRST_LINES}"
  # Check for specific error messages
  if grep -qi "timeout\|too busy" "${MARITIME_BOUNDARY_IDS_FILE}"; then
   __loge "Overpass API timeout detected. Please wait a few minutes and try again."
  fi
  __log_finish
  return "${ERROR_DOWNLOADING_BOUNDARY_ID_LIST}"
 fi

 # Validate it's CSV format (should start with @id or have at least one line with numbers)
 if ! head -1 "${MARITIME_BOUNDARY_IDS_FILE}" | grep -qE "^@id|^[0-9]+"; then
  __loge "ERROR: Maritime border list file is not in expected CSV format"
  __loge "First line of file: $(head -1 "${MARITIME_BOUNDARY_IDS_FILE}")"
  __log_finish
  return "${ERROR_DOWNLOADING_BOUNDARY_ID_LIST}"
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
   # Import backup to temporary table first, then insert with is_maritime = TRUE
   # This ensures all maritime boundaries have is_maritime = TRUE explicitly
   __logd "Importing backup using ogr2ogr to temporary table..."
   local OGR_ERROR
   OGR_ERROR=$(mktemp)
   local TEMP_TABLE="maritimes_backup_import_$$"
   if ogr2ogr -f "PostgreSQL" "PG:dbname=${DBNAME}" "${RESOLVED_MARITIMES_BACKUP}" \
    -nln "${TEMP_TABLE}" -nlt PROMOTE_TO_MULTI -a_srs EPSG:4326 \
    -lco GEOMETRY_NAME=geom -lco FID=country_id \
    --config PG_USE_COPY YES 2> "${OGR_ERROR}"; then
    # Insert from temporary table with is_maritime = TRUE explicitly
    # All boundaries from maritime backup are maritime by definition
    local COUNTRIES_TABLE
    COUNTRIES_TABLE=$(__get_countries_table_name)
    if psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -c "INSERT INTO ${COUNTRIES_TABLE} (country_id, country_name, country_name_es, country_name_en, geom, is_maritime) SELECT country_id, country_name, country_name_es, country_name_en, ST_SetSRID(geom, 4326), TRUE FROM ${TEMP_TABLE} ON CONFLICT (country_id) DO UPDATE SET country_name = EXCLUDED.country_name, country_name_es = EXCLUDED.country_name_es, country_name_en = EXCLUDED.country_name_en, is_maritime = TRUE, geom = ST_SetSRID(EXCLUDED.geom, 4326); DROP TABLE ${TEMP_TABLE};" >> "${OGR_ERROR}" 2>&1; then
     __logi "Successfully imported maritime boundaries from backup and set is_maritime = true"
     rm -f "${OGR_ERROR}"
     __log_finish
     return 0
    else
     __loge "Failed to insert maritime boundaries from temporary table"
     __logd "SQL error output: $(cat "${OGR_ERROR}" 2> /dev/null || echo 'No error output')"
     psql -d "${DBNAME}" -c "DROP TABLE IF EXISTS ${TEMP_TABLE};" > /dev/null 2>&1 || true
     rm -f "${OGR_ERROR}"
     __log_finish
     return 1
    fi
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
       # Maritime boundaries have is_maritime = true
       local COUNTRIES_TABLE
       COUNTRIES_TABLE=$(__get_countries_table_name)
       if psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -c "INSERT INTO ${COUNTRIES_TABLE} (country_id, country_name, country_name_es, country_name_en, geom, is_maritime) SELECT country_id, country_name, country_name_es, country_name_en, ST_SetSRID(geom, 4326), TRUE FROM ${TEMP_TABLE} WHERE country_id IN (${IDS_LIST}) ON CONFLICT (country_id) DO UPDATE SET country_name = EXCLUDED.country_name, country_name_es = EXCLUDED.country_name_es, country_name_en = EXCLUDED.country_name_en, is_maritime = TRUE, geom = ST_SetSRID(EXCLUDED.geom, 4326); DROP TABLE ${TEMP_TABLE};" >> "${OGR_ERROR}" 2>&1; then
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

 # Check if new download flow is enabled (default: true, same as countries)
 if [[ "${USE_NEW_DOWNLOAD_FLOW_MARITIMES:-true}" == "true" ]]; then
  __logi "Using NEW download flow for maritimes: parallel download + sequential import"
  __logi "Download threads: ${DOWNLOAD_MAX_THREADS:-4}"

  # Phase 1: Download in parallel
  if ! __downloadMaritimes_parallel_new "${MARITIME_BOUNDARY_IDS_FILE}"; then
   __logw "Some maritime downloads failed, but continuing with successful ones"
  fi

  # Phase 2: Import sequentially
  local SUCCESS_FILE="${TMP_DIR}/download_maritime_success.txt"
  if [[ -f "${SUCCESS_FILE}" ]] && [[ -s "${SUCCESS_FILE}" ]]; then
   local SUCCESS_COUNT
   SUCCESS_COUNT=$(wc -l < "${SUCCESS_FILE}" | tr -d ' ')
   __logi "Importing ${SUCCESS_COUNT} successfully downloaded maritime boundaries sequentially"
   if ! __importMaritimes_sequential_new "${SUCCESS_FILE}"; then
    __logw "Some maritime imports failed, but continuing"
   fi
  else
   __loge "No successful maritime downloads to import"
   __log_finish
   return 1
  fi

  __logi "New maritime download flow completed"
  __log_finish
  return 0
 fi

 # OLD FLOW: Parallel processing (download + import together)
 __logi "Using OLD download flow for maritimes: parallel processing"
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
   export IS_MARITIME="true"
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
     # Use sed to extract only the ID that comes after "boundary " (avoiding false positives from timestamps, etc.)
     grep -hE "Failed to process boundary [0-9]+|Recording boundary [0-9]+ as failed" "${JOB_LOG}" 2> /dev/null \
      | sed -E 's/.*boundary ([0-9]+).*/\1/' \
      | while read -r FAILED_ID; do
       if [[ -n "${FAILED_ID}" ]] && [[ "${FAILED_ID}" =~ ^[0-9]+$ ]] && [[ "${FAILED_ID}" -ge 1000 ]]; then
        # Only accept IDs >= 1000 to filter out false positives (real OSM relation IDs are much larger)
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
     # Use sed to extract only the ID that comes after "boundary " (avoiding false positives from timestamps, etc.)
     grep -hE "Failed to process boundary [0-9]+|Recording boundary [0-9]+ as failed" "${ERROR_LOG}" 2> /dev/null \
      | sed -E 's/.*boundary ([0-9]+).*/\1/' \
      | while read -r FAILED_ID; do
       if [[ -n "${FAILED_ID}" ]] && [[ "${FAILED_ID}" =~ ^[0-9]+$ ]] && [[ "${FAILED_ID}" -ge 1000 ]]; then
        # Only accept IDs >= 1000 to filter out false positives (real OSM relation IDs are much larger)
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
