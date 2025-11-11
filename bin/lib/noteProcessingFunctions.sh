#!/bin/bash

# Note Processing Functions for OSM-Notes-profile
# Author: Andres Gomez (AngocA)
# Version: 2025-11-11

VERSION="2025-11-11"

# shellcheck disable=SC2317,SC2155,SC2034

# Ensure logging helpers are available
if ! declare -f __log_start > /dev/null 2>&1; then
 if [[ -f "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/commonFunctions.sh" ]]; then
  # shellcheck disable=SC1091
  source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/commonFunctions.sh"
 fi
fi

# Ensure error handling helpers are available
if ! declare -f __handle_error_with_cleanup > /dev/null 2>&1; then
 if [[ -f "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/errorHandlingFunctions.sh" ]]; then
  # shellcheck disable=SC1091
  source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/errorHandlingFunctions.sh"
 fi
fi

function __getLocationNotes_impl {
 __log_start
 __logd "Assigning countries to notes."

 # Always import previous note locations to speed up the process
 __logi "Extracting notes backup."
 rm -f "${CSV_BACKUP_NOTE_LOCATION}"
 unzip "${CSV_BACKUP_NOTE_LOCATION_COMPRESSED}" -d /tmp
 chmod 666 "${CSV_BACKUP_NOTE_LOCATION}"

 __logi "Importing notes location."
 export CSV_BACKUP_NOTE_LOCATION
 # shellcheck disable=SC2016
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -c "$(envsubst '$CSV_BACKUP_NOTE_LOCATION' \
   < "${POSTGRES_32_UPLOAD_NOTE_LOCATION}" || true)"

 # Retrieves the max note for already location processed notes (from file.)
 # Use COALESCE to handle NULL results from MAX() when no rows match
 MAX_NOTE_ID_NOT_NULL=$(psql -d "${DBNAME}" -Atq -v ON_ERROR_STOP=1 \
  <<< "SELECT COALESCE(MAX(note_id), 0) FROM notes WHERE id_country IS NOT NULL")
 # Retrieves the max note.
 MAX_NOTE_ID=$(psql -d "${DBNAME}" -Atq -v ON_ERROR_STOP=1 \
  <<< "SELECT COALESCE(MAX(note_id), 0) FROM notes")

 # Ensure numeric values (handle empty strings from psql)
 MAX_NOTE_ID_NOT_NULL=${MAX_NOTE_ID_NOT_NULL:-0}
 MAX_NOTE_ID=${MAX_NOTE_ID:-0}

 __logd "Statistics: MAX_NOTE_ID=${MAX_NOTE_ID}, MAX_NOTE_ID_NOT_NULL=${MAX_NOTE_ID_NOT_NULL}"

 # Uses n-1 cores, if number of cores is greater than 1.
 # This prevents monopolization of the CPUs.
 if [[ "${MAX_THREADS}" -gt 1 ]]; then
  MAX_THREADS=$((MAX_THREADS - 1))
 fi

 # Verify integrity of imported note locations in parallel
 # Optimized: Parallelize verification by splitting data across threads (30min→5min for 4.8M notes)
 __logi "Verifying integrity of imported note locations (parallel)..."
 local -i TOTAL_NOTES_TO_INVALIDATE=0
 local -i VERIFY_THREAD_OVERRIDE=0
 if [[ -n "${VERIFY_THREADS:-}" ]]; then
  VERIFY_THREAD_OVERRIDE=${VERIFY_THREADS:-0}
 fi
 local -i VERIFY_THREAD_COUNT=${MAX_THREADS}
 if ((VERIFY_THREAD_OVERRIDE > 0)); then
  VERIFY_THREAD_COUNT=${VERIFY_THREAD_OVERRIDE}
 fi
 if ((VERIFY_THREAD_COUNT > MAX_THREADS)); then
  VERIFY_THREAD_COUNT=${MAX_THREADS}
 fi
 if ((VERIFY_THREAD_COUNT <= 0)); then
  VERIFY_THREAD_COUNT=1
 fi

 # If MAX_NOTE_ID_NOT_NULL is 0 but MAX_NOTE_ID > 0, it means there are notes
 # but none have country assigned (unlikely but handle it)
 # If MAX_NOTE_ID_NOT_NULL equals MAX_NOTE_ID, all notes have country assigned
 if [[ "${MAX_NOTE_ID_NOT_NULL}" -eq 0 ]] && [[ "${MAX_NOTE_ID}" -gt 0 ]]; then
  __logw "No notes with country found, but ${MAX_NOTE_ID} notes exist in DB. " \
   "Cannot verify integrity (no countries assigned)."
 elif [[ "${MAX_NOTE_ID_NOT_NULL}" -eq "${MAX_NOTE_ID}" ]] && [[ "${MAX_NOTE_ID}" -gt 0 ]]; then
  __logd "All ${MAX_NOTE_ID} notes have country assigned. Will verify integrity."
 fi

 local -i EFFECTIVE_VERIFY_CHUNK_SIZE
 EFFECTIVE_VERIFY_CHUNK_SIZE=${VERIFY_CHUNK_SIZE:-100000}
 if ((EFFECTIVE_VERIFY_CHUNK_SIZE <= 0)); then
  __logw "VERIFY_CHUNK_SIZE invalid (${EFFECTIVE_VERIFY_CHUNK_SIZE}), resetting to 100000."
  EFFECTIVE_VERIFY_CHUNK_SIZE=100000
 fi

 local -i SQL_BATCH_SIZE
 SQL_BATCH_SIZE=${VERIFY_SQL_BATCH_SIZE:-0}
 if ((SQL_BATCH_SIZE <= 0)); then
  SQL_BATCH_SIZE=5000
 fi
 if ((SQL_BATCH_SIZE > EFFECTIVE_VERIFY_CHUNK_SIZE)); then
  SQL_BATCH_SIZE=${EFFECTIVE_VERIFY_CHUNK_SIZE}
 fi

 __logd "Verification setup: threads=${VERIFY_THREAD_COUNT}, chunk=${EFFECTIVE_VERIFY_CHUNK_SIZE}, sub_chunk=${SQL_BATCH_SIZE}, max_note=${MAX_NOTE_ID_NOT_NULL}"

 # Skip verification if no notes to verify
 if [[ "${MAX_NOTE_ID_NOT_NULL}" -eq 0 ]]; then
  __logw "No notes with country assignment found. Skipping integrity verification."
  TOTAL_NOTES_TO_INVALIDATE=0
 else
  # Proceed with verification

  # Store counts from parallel threads in temp files
  local TEMP_COUNT_DIR
  TEMP_COUNT_DIR=$(mktemp -d)
  if [[ -z "${TEMP_COUNT_DIR:-}" ]]; then
   __loge "ERROR: Failed to create temporary directory for counts"
   __log_finish
   return 1
  fi

  local QUEUE_FILE
  QUEUE_FILE=$(mktemp)
  if [[ -z "${QUEUE_FILE:-}" ]]; then
   __loge "ERROR: Failed to create queue file for verification chunks"
   rm -rf "${TEMP_COUNT_DIR}"
   __log_finish
   return 1
  fi

  local CLEANUP_TEMP_DIR="${TEMP_COUNT_DIR}"
  local CLEANUP_QUEUE_FILE="${QUEUE_FILE}"
  # shellcheck disable=SC2064
  trap 'rm -rf "${CLEANUP_TEMP_DIR:-}"; rm -f "${CLEANUP_QUEUE_FILE:-}"' EXIT

  local -i CHUNK_START=0
  local -i MAX_NOTE_LIMIT=$((MAX_NOTE_ID_NOT_NULL + 1))
  while ((CHUNK_START < MAX_NOTE_LIMIT)); do
   local -i CHUNK_END=$((CHUNK_START + EFFECTIVE_VERIFY_CHUNK_SIZE))
   if ((CHUNK_END > MAX_NOTE_LIMIT)); then
    CHUNK_END=${MAX_NOTE_LIMIT}
   fi
   printf "%s %s\n" "${CHUNK_START}" "${CHUNK_END}" >> "${QUEUE_FILE}"
   CHUNK_START=${CHUNK_END}
  done

  exec {VERIFY_QUEUE_FD}<> "${QUEUE_FILE}"
  local -i TOTAL_CHUNKS
  TOTAL_CHUNKS=$(wc -l < "${QUEUE_FILE}")
  __logd "Verification queue ready: total_chunks=${TOTAL_CHUNKS}"

  for J in $(seq 1 1 "${VERIFY_THREAD_COUNT}"); do
   (
    local -i THREAD_ID=${J}
    __logd "Starting integrity verification thread ${THREAD_ID}."
    local -i THREAD_COUNT=0
    while true; do
     local RANGE_START RANGE_END
     if ! flock -x "${VERIFY_QUEUE_FD}"; then
      __loge "Thread ${THREAD_ID}: unable to acquire queue lock"
      break
     fi
     if ! IFS=' ' read -r RANGE_START RANGE_END <&"${VERIFY_QUEUE_FD}"; then
      flock -u "${VERIFY_QUEUE_FD}"
      break
     fi
     flock -u "${VERIFY_QUEUE_FD}"

     if [[ -z "${RANGE_START:-}" ]]; then
      break
     fi

     __logd "Thread ${THREAD_ID}: verifying ${RANGE_START}-${RANGE_END}"
     local -i RANGE_TOTAL=0
     local -i SUB_START=${RANGE_START}
     local -i RANGE_LIMIT=${RANGE_END}
     while ((SUB_START < RANGE_LIMIT)); do
      local -i SUB_END=$((SUB_START + SQL_BATCH_SIZE))
      if ((SUB_END > RANGE_LIMIT)); then
       SUB_END=${RANGE_LIMIT}
      fi

      local SUB_COUNT
      SUB_COUNT=$(
       psql -d "${DBNAME}" -Atq -v ON_ERROR_STOP=1 << EOF
CREATE TEMP TABLE temp_verify_batch ON COMMIT DROP AS
SELECT note_id
FROM notes
WHERE id_country IS NOT NULL
AND ${SUB_START} <= note_id AND note_id < ${SUB_END}
ORDER BY note_id;

WITH computed AS (
SELECT n.note_id,
       n.id_country,
       get_country(n.longitude, n.latitude, n.note_id) AS computed_country
FROM notes AS n
JOIN temp_verify_batch b ON b.note_id = n.note_id
),
invalidated AS (
UPDATE notes AS n /* Notes-integrity check parallel */
SET id_country = NULL
FROM computed c
WHERE n.note_id = c.note_id
AND (c.computed_country = -1 OR c.computed_country <> n.id_country)
RETURNING n.note_id
)
SELECT COUNT(*) FROM invalidated;

DISCARD ALL;
EOF
      )
      SUB_COUNT=$(echo "${SUB_COUNT}" | tr -d '[:space:]')
      if [[ -z "${SUB_COUNT}" ]]; then
       SUB_COUNT=0
      fi
      local -i SUB_COUNT_INT=${SUB_COUNT}

      RANGE_TOTAL=$((RANGE_TOTAL + SUB_COUNT_INT))
      __logd "Thread ${THREAD_ID}: subrange ${SUB_START}-${SUB_END}, invalidated ${SUB_COUNT_INT}"
      SUB_START=${SUB_END}
     done

     THREAD_COUNT=$((THREAD_COUNT + RANGE_TOTAL))
     __logd "Thread ${THREAD_ID}: range ${RANGE_START}-${RANGE_END}, invalidated ${RANGE_TOTAL}"
    done

    echo "${THREAD_COUNT}" > "${TEMP_COUNT_DIR}/count_${THREAD_ID}"
    __logd "Thread ${THREAD_ID}: total invalidated ${THREAD_COUNT}"
   ) &
  done

  # Wait for all verification threads to complete
  wait
  exec {VERIFY_QUEUE_FD}>&-

  # Sum up all counts
  for COUNT_FILE in "${TEMP_COUNT_DIR}"/count_*; do
   if [[ -f "${COUNT_FILE}" ]]; then
    local -i COUNT=0
    COUNT=$(cat "${COUNT_FILE}")
    TOTAL_NOTES_TO_INVALIDATE=$((TOTAL_NOTES_TO_INVALIDATE + COUNT))
   fi
  done

  # Clean up temp directory
  rm -rf "${TEMP_COUNT_DIR}"
  rm -f "${QUEUE_FILE}"
  CLEANUP_QUEUE_FILE=""
  CLEANUP_TEMP_DIR=""

  if [[ "${TOTAL_NOTES_TO_INVALIDATE}" -gt 0 ]]; then
   __logi "Found and invalidated ${TOTAL_NOTES_TO_INVALIDATE} notes with incorrect country assignments"
  else
   __logi "No incorrect country assignments found"
  fi
 fi

 # Check if there are any notes without country assignment
 local -i NOTES_WITHOUT_COUNTRY
 NOTES_WITHOUT_COUNTRY=$(psql -d "${DBNAME}" -Atq -v ON_ERROR_STOP=1 \
  <<< "SELECT COUNT(*) FROM notes WHERE id_country IS NULL")
 __logi "Notes without country assignment: ${NOTES_WITHOUT_COUNTRY}"

 if [[ "${NOTES_WITHOUT_COUNTRY}" -eq 0 ]]; then
  __logi "All notes already have country assignment. Skipping location processing."
  __log_finish
  return 0
 fi

 # Processes notes that still require country assignment.
 local -i ASSIGNABLE_NOTES
 ASSIGNABLE_NOTES=$(
  psql -d "${DBNAME}" -Atq -v ON_ERROR_STOP=1 << 'EOF'
SELECT COUNT(*)
FROM notes
WHERE id_country IS NULL
AND longitude IS NOT NULL
AND latitude IS NOT NULL;
EOF
 )

 local -i NOTES_WITHOUT_COORDS
 NOTES_WITHOUT_COORDS=$(
  psql -d "${DBNAME}" -Atq -v ON_ERROR_STOP=1 << 'EOF'
SELECT COUNT(*)
FROM notes
WHERE id_country IS NULL
AND (longitude IS NULL OR latitude IS NULL);
EOF
 )

 __logi "Notes pending assignment with coordinates: ${ASSIGNABLE_NOTES}"
 if ((NOTES_WITHOUT_COORDS > 0)); then
  __logw "Notes lacking coordinates pending: ${NOTES_WITHOUT_COORDS}"
 fi

 if ((ASSIGNABLE_NOTES == 0)); then
  __logi "No notes pending assignment. Skipping geolocation pass."
  __log_finish
  return 0
 fi

 local -i ASSIGN_THREADS=${VERIFY_THREAD_COUNT}
 if ((ASSIGN_THREADS <= 0)); then
  ASSIGN_THREADS=1
 fi

 local -i ASSIGN_CHUNK_SIZE
 ASSIGN_CHUNK_SIZE=${ASSIGN_CHUNK_SIZE:-5000}
 if ((ASSIGN_CHUNK_SIZE <= 0)); then
  __logw "ASSIGN_CHUNK_SIZE invalid (${ASSIGN_CHUNK_SIZE}); resetting to 5000."
  ASSIGN_CHUNK_SIZE=5000
 fi

 local ASSIGN_WORK_DIR
 ASSIGN_WORK_DIR=$(mktemp -d)
 if [[ -z "${ASSIGN_WORK_DIR:-}" ]]; then
  __loge "ERROR: Failed to create assignment workspace directory"
  __log_finish
  return 1
 fi

 local ASSIGN_SOURCE_FILE="${ASSIGN_WORK_DIR}/note_ids.list"
 local COPY_NOTES_SQL
 COPY_NOTES_SQL=$(
  cat << 'EOF'
COPY (
 SELECT note_id
 FROM notes
 WHERE id_country IS NULL
 AND longitude IS NOT NULL
 AND latitude IS NOT NULL
 ORDER BY note_id
) TO STDOUT
EOF
 )
 if ! psql -d "${DBNAME}" -Atq -v ON_ERROR_STOP=1 \
  -c "${COPY_NOTES_SQL}" > "${ASSIGN_SOURCE_FILE}"; then
  __loge "ERROR: Failed to export pending note ids for assignment"
  rm -rf "${ASSIGN_WORK_DIR}"
  __log_finish
  return 1
 fi

 if [[ ! -s "${ASSIGN_SOURCE_FILE}" ]]; then
  __logi "No note IDs exported for assignment. Skipping geolocation pass."
  rm -rf "${ASSIGN_WORK_DIR}"
  __log_finish
  return 0
 fi

 split -d -a 5 -l "${ASSIGN_CHUNK_SIZE}" "${ASSIGN_SOURCE_FILE}" \
  "${ASSIGN_WORK_DIR}/chunk_"

 local ASSIGN_QUEUE_FILE
 ASSIGN_QUEUE_FILE=$(mktemp)
 if [[ -z "${ASSIGN_QUEUE_FILE:-}" ]]; then
  __loge "ERROR: Failed to create assignment queue file"
  rm -rf "${ASSIGN_WORK_DIR}"
  __log_finish
  return 1
 fi

 for CHUNK_FILE in "${ASSIGN_WORK_DIR}"/chunk_*; do
  if [[ -s "${CHUNK_FILE}" ]]; then
   echo "${CHUNK_FILE}" >> "${ASSIGN_QUEUE_FILE}"
  fi
 done

 if [[ ! -s "${ASSIGN_QUEUE_FILE}" ]]; then
  __logi "Assignment queue empty. Skipping geolocation pass."
  rm -rf "${ASSIGN_WORK_DIR}"
  rm -f "${ASSIGN_QUEUE_FILE}"
  __log_finish
  return 0
 fi

 exec {ASSIGN_QUEUE_FD}<> "${ASSIGN_QUEUE_FILE}"
 local -i TOTAL_ASSIGN_CHUNKS
 TOTAL_ASSIGN_CHUNKS=$(wc -l < "${ASSIGN_QUEUE_FILE}")
 __logd "Assignment queue ready: total_chunks=${TOTAL_ASSIGN_CHUNKS}"

 local -i TOTAL_ASSIGNED=0
 for J in $(seq 1 1 "${ASSIGN_THREADS}"); do
  (
   local -i THREAD_ID=${J}
   local -i THREAD_ASSIGNED=0
   while true; do
    local CHUNK_PATH
    if ! flock -x "${ASSIGN_QUEUE_FD}"; then
     __loge "Assignment thread ${THREAD_ID}: queue lock failed"
     break
    fi
    if ! read -r CHUNK_PATH <&"${ASSIGN_QUEUE_FD}"; then
     flock -u "${ASSIGN_QUEUE_FD}"
     break
    fi
    flock -u "${ASSIGN_QUEUE_FD}"

    if [[ -z "${CHUNK_PATH:-}" ]] || [[ ! -s "${CHUNK_PATH}" ]]; then
     continue
    fi

    local NOTE_IDS
    NOTE_IDS=$(tr '\n' ',' < "${CHUNK_PATH}" | sed 's/,$//')
    if [[ -z "${NOTE_IDS:-}" ]]; then
     continue
    fi

    local CHUNK_ASSIGNED
    CHUNK_ASSIGNED=$(
     psql -d "${DBNAME}" -Atq -v ON_ERROR_STOP=1 << EOF
WITH target AS (
 SELECT UNNEST(ARRAY[${NOTE_IDS}])::BIGINT AS note_id
),
updated AS (
 UPDATE notes AS n /* Notes-assign chunk */
 SET id_country = get_country(n.longitude, n.latitude, n.note_id)
 FROM target t
 WHERE n.note_id = t.note_id
 AND n.id_country IS NULL
 RETURNING n.note_id
)
SELECT COUNT(*) FROM updated;
EOF
    )

    CHUNK_ASSIGNED=${CHUNK_ASSIGNED:-0}
    THREAD_ASSIGNED=$((THREAD_ASSIGNED + CHUNK_ASSIGNED))
    __logd "Assignment thread ${THREAD_ID}: ${CHUNK_PATH}, assigned ${CHUNK_ASSIGNED}"
   done

   echo "${THREAD_ASSIGNED}" > "${ASSIGN_WORK_DIR}/assigned_${THREAD_ID}"
   __logd "Assignment thread ${THREAD_ID}: total ${THREAD_ASSIGNED}"
  ) &
 done

 wait
 exec {ASSIGN_QUEUE_FD}>&-

 for ASSIGNED_FILE in "${ASSIGN_WORK_DIR}"/assigned_*; do
  if [[ -f "${ASSIGNED_FILE}" ]]; then
   local -i CHUNK_COUNT=0
   CHUNK_COUNT=$(cat "${ASSIGNED_FILE}")
   TOTAL_ASSIGNED=$((TOTAL_ASSIGNED + CHUNK_COUNT))
  fi
 done

 __logi "Notes assigned to countries in this pass: ${TOTAL_ASSIGNED}"

 rm -rf "${ASSIGN_WORK_DIR}"
 rm -f "${ASSIGN_QUEUE_FILE}"

 __log_finish
 return 0
}

# Validates XML content for coordinate attributes
# This is the unified implementation for both API and Planet XML coordinate validation.
# Supports auto-detection of XML format (Planet vs API) using grep/sed pattern matching.
#
# Parameters:
#   $1: XML file path
# Returns:
#   0 if all coordinates are valid, 1 if any invalid
#
# XML Format Support:
#   - Planet XML: Extracts lat/lon attributes from <note> elements
#   - API XML: Extracts lat/lon attributes from <note> elements
#   - Uses grep/sed for efficient pattern matching
function __validate_xml_coordinates() {
 __log_start
 local XML_FILE="${1}"
 local VALIDATION_ERRORS=()

 # Check if file exists and is readable
 if ! __validate_input_file "${XML_FILE}" "XML file"; then
  __log_finish
  return 1
 fi

 # Check file size to determine validation approach
 local FILE_SIZE
 FILE_SIZE=$(stat --format="%s" "${XML_FILE}" 2> /dev/null || echo "0")
 local FILE_SIZE_MB=$((FILE_SIZE / 1024 / 1024))

 # For large files (> 500MB), use lite validation with safer approach
 if [[ ${FILE_SIZE_MB} -gt 500 ]]; then
  __logi "Large file detected (${FILE_SIZE_MB}MB), using lite coordinate validation"

  # Lite validation: check first few lines only with multiple fallback strategies
  local SAMPLE_LATITUDES=""
  local SAMPLE_LONGITUDES=""
  local VALIDATION_STRATEGY="grep_safe"
  local SAMPLE_COUNT=0

  # Strategy 1: Use grep to find coordinates in first few lines (safest for very large files)
  __logd "Attempting grep-based validation for large file..."
  local HEAD_LINES=2000
  SAMPLE_LATITUDES=$(head -n "${HEAD_LINES}" "${XML_FILE}" | grep -o 'lat="[^"]*"' | head -50 | sed 's/lat="//;s/"//g' | grep -v '^$')
  SAMPLE_LONGITUDES=$(head -n "${HEAD_LINES}" "${XML_FILE}" | grep -o 'lon="[^"]*"' | head -50 | sed 's/lon="//;s/"//g' | grep -v '^$')

  if [[ -n "${SAMPLE_LATITUDES}" ]] && [[ -n "${SAMPLE_LONGITUDES}" ]]; then
   SAMPLE_COUNT=$(echo "${SAMPLE_LATITUDES}" | wc -l)
   __logd "Grep validation successful: found ${SAMPLE_COUNT} coordinate samples"
  else
   __logw "Grep validation failed, trying minimal validation..."
   VALIDATION_STRATEGY="minimal_validation"

   # Strategy 2: Minimal validation - just check if file contains coordinate patterns
   if grep -q 'lat="[^"]*"' "${XML_FILE}" && grep -q 'lon="[^"]*"' "${XML_FILE}"; then
    __logi "Minimal validation passed: coordinate patterns found in file"
    SAMPLE_COUNT=1 # Indicate success without actual validation
   else
    __loge "All validation strategies failed: no coordinate patterns found"
    __log_finish
    return 1
   fi
  fi

  # Report validation results
  if [[ ${SAMPLE_COUNT} -gt 0 ]]; then
   __logi "Lite coordinate validation passed using ${VALIDATION_STRATEGY}: ${SAMPLE_COUNT} samples validated"
   __log_finish
   return 0
  else
   __logw "No coordinates found in sample validation of large XML file"
   __log_finish
   return 0 # Don't fail validation for large files, just warn
  fi
 fi

 # For smaller files, extract coordinates using grep/sed
 local LATITUDES
 local LONGITUDES

 # Extract coordinates using grep and sed (works for all XML formats)
 LATITUDES=$(grep -o 'lat="[^"]*"' "${XML_FILE}" | sed 's/lat="//;s/"//g' | grep -v '^$')
 LONGITUDES=$(grep -o 'lon="[^"]*"' "${XML_FILE}" | sed 's/lon="//;s/"//g' | grep -v '^$')

 if [[ -z "${LATITUDES}" ]] || [[ -z "${LONGITUDES}" ]]; then
  __logw "No coordinates found in XML file"
  __log_finish
  return 0
 fi

 # Validate each coordinate pair
 local LINE_NUMBER=0
 while IFS= read -r LAT_VALUE; do
  ((LINE_NUMBER++))
  LON_VALUE=$(echo "${LONGITUDES}" | sed -n "${LINE_NUMBER}p")

  if [[ -n "${LON_VALUE}" ]]; then
   if ! __validate_coordinates "${LAT_VALUE}" "${LON_VALUE}"; then
    VALIDATION_ERRORS+=("Line ${LINE_NUMBER}: Invalid coordinates lat=${LAT_VALUE}, lon=${LON_VALUE}")
   fi
  fi
 done <<< "${LATITUDES}"

 # Report validation errors
 if [[ ${#VALIDATION_ERRORS[@]} -gt 0 ]]; then
  __loge "XML coordinate validation failed for ${XML_FILE}:"
  for ERROR in "${VALIDATION_ERRORS[@]}"; do
   echo "  - ${ERROR}" >&2
  done
  __log_finish
  return 1
 fi

 # Log success message
 __logi "XML coordinate validation passed: ${XML_FILE}"
 __log_finish
 return 0
}

# Validates CSV content for coordinate columns
# Parameters:
#   $1: CSV file path
#   $2: Latitude column number (optional, defaults to auto-detect)
#   $3: Longitude column number (optional, defaults to auto-detect)
# Returns:
#   0 if all coordinates are valid, 1 if any invalid

# Validates production database variables
# This function ensures that production database variables are properly set
# Parameters: None
# Returns: 0 if validation passes, 1 if validation fails

# Enhanced error handling and retry logic
# Author: Andres Gomez (AngocA)
# Version: 2025-08-17

# Enhanced retry with exponential backoff and jitter
# Parameters: command_to_execute [max_retries] [base_delay] [max_delay]

# Health check for network connectivity
# Parameters: [timeout_seconds]
# Returns: 0 if network is available, 1 if not
function __check_network_connectivity() {
 __log_start
 local TIMEOUT="${1:-10}"
 local TEST_URLS=("https://www.google.com" "https://www.cloudflare.com" "https://www.github.com")

 __logd "Checking network connectivity"

 for URL in "${TEST_URLS[@]}"; do
  if timeout "${TIMEOUT}" curl -s --connect-timeout 5 "${URL}" > /dev/null 2>&1; then
   __logi "Network connectivity confirmed via ${URL}"
   __log_finish
   return 0
  fi
 done

 __loge "Network connectivity check failed"
 __log_finish
 return 1
}

# Enhanced error recovery with automatic cleanup.
# Exits in production, returns in test environment.
#
# Parameters:
#   $1 - error_code: Exit/return code
#   $2 - error_message: Error description
#   $@ - cleanup_commands: Commands to execute before exit/return
#
# Environment Variables:
#   TEST_MODE: If "true", uses return instead of exit
#   BATS_TEST_NAME: If set, uses return instead of exit (BATS testing)
#
# Returns:
#   In production: Exits with error_code
#   In test environment: Returns with error_code
function __handle_error_with_cleanup() {
 __log_start
 local ERROR_CODE="$1"
 local ERROR_MESSAGE="$2"
 shift 2
 local CLEANUP_COMMANDS=("$@")

 __loge "Error occurred: ${ERROR_MESSAGE} (code: ${ERROR_CODE})"

 # Create failed execution file to prevent re-execution
 if [[ -n "${FAILED_EXECUTION_FILE:-}" ]]; then
  __loge "Creating failed execution file: ${FAILED_EXECUTION_FILE}"
  echo "Error occurred at $(date): ${ERROR_MESSAGE} (code: ${ERROR_CODE})" > "${FAILED_EXECUTION_FILE}"
  echo "Stack trace: $(caller 0)" >> "${FAILED_EXECUTION_FILE}"
  echo "Temporary directory: ${TMP_DIR:-unknown}" >> "${FAILED_EXECUTION_FILE}"
 fi

 # Execute cleanup commands only if CLEAN is true
 if [[ "${CLEAN:-true}" == "true" ]]; then
  for CMD in "${CLEANUP_COMMANDS[@]}"; do
   if [[ -n "${CMD}" ]]; then
    echo "Executing cleanup command: ${CMD}"
    __logd "Executing cleanup command: ${CMD}"
    if eval "${CMD}"; then
     __logd "Cleanup command succeeded: ${CMD}"
    else
     echo "WARNING: Cleanup command failed: ${CMD}" >&2
    fi
   fi
  done
 else
  echo "Skipping cleanup commands due to CLEAN=false"
  __logd "Skipping cleanup commands due to CLEAN=false"
 fi

 # Log error details for debugging
 __loge "Error details - Code: ${ERROR_CODE}, Message: ${ERROR_MESSAGE}"
 __loge "Stack trace: $(caller 0)"
 __loge "Failed execution file created: ${FAILED_EXECUTION_FILE:-none}"

 __log_finish
 # Use exit in production, return in test environment
 # Detect test environment via TEST_MODE or BATS_TEST_NAME variables
 if [[ "${TEST_MODE:-false}" == "true" ]] || [[ -n "${BATS_TEST_NAME:-}" ]]; then
  __logd "Test environment detected, using return instead of exit"
  return "${ERROR_CODE}"
 else
  __logd "Production environment detected, using exit"
  exit "${ERROR_CODE}"
 fi
}

# Download queue management functions
# These functions implement a simple semaphore system to limit concurrent
# downloads to Overpass API, preventing rate limiting issues.
# Simpler than ticket-based queue: only limits concurrency, no ordering.
# Version: 2025-10-29
#
# Alternative implementation: Simple semaphore (no tickets, no ordering)
# Functions: __acquire_download_slot, __release_download_slot,
# __cleanup_stale_slots, __wait_for_download_slot
#
# Legacy ticket-based queue system (deprecated but kept for compatibility):
# Functions: __get_download_ticket, __wait_for_download_turn,
# __release_download_ticket, __queue_prune_stale_locks

# =============================================================================
# Simple Semaphore System (Recommended)
# =============================================================================

# Acquire a download slot (simple FIFO - minimal wait, max 8 concurrent)
# Overpass has 2 servers × 4 slots = 8 total slots
# Returns: 0 on success, 1 on timeout/error
# Side effect: Creates a lock directory in active/ directory (atomic mkdir)
function __acquire_download_slot() {
 __log_start
 local QUEUE_DIR="${TMP_DIR}/download_queue"
 local ACTIVE_DIR="${QUEUE_DIR}/active"
 # Overpass has 2 servers × 4 slots = 8 total concurrent slots
 local MAX_SLOTS="${RATE_LIMIT:-8}"
 local MY_LOCK_DIR="${ACTIVE_DIR}/${BASHPID}.lock"
 local MAX_WAIT_TIME=60
 local CHECK_INTERVAL=0.5
 local MAX_RETRIES=10

 mkdir -p "${ACTIVE_DIR}"

 local RETRY_COUNT=0
 local START_TIME
 START_TIME=$(date +%s)

 # Clean up stale locks first
 __cleanup_stale_slots || true

 while [[ ${RETRY_COUNT} -lt ${MAX_RETRIES} ]]; do
  # Try to acquire slot atomically (all operations inside flock)
  (
   flock -x 200
   # Count active downloads inside flock to prevent race conditions
   local ACTIVE_NOW=0
   if [[ -d "${ACTIVE_DIR}" ]]; then
    ACTIVE_NOW=$(find "${ACTIVE_DIR}" -name "*.lock" -type d 2> /dev/null | wc -l)
   fi

   # Try to create lock only if we're under the limit
   if [[ ${ACTIVE_NOW} -lt ${MAX_SLOTS} ]]; then
    # Use mkdir for atomic lock creation (mkdir is atomic in Linux)
    if ! [[ -d "${MY_LOCK_DIR}" ]]; then
     if mkdir "${MY_LOCK_DIR}" 2> /dev/null; then
      # Write PID to a file inside the lock dir for reference
      echo "${BASHPID}" > "${MY_LOCK_DIR}/pid" 2> /dev/null || true
      # Re-count to verify we didn't exceed limit
      local ACTIVE_AFTER=0
      if [[ -d "${ACTIVE_DIR}" ]]; then
       ACTIVE_AFTER=$(find "${ACTIVE_DIR}" -name "*.lock" -type d 2> /dev/null | wc -l)
      fi
      # Only succeed if we didn't exceed the limit
      if [[ ${ACTIVE_AFTER} -le ${MAX_SLOTS} ]]; then
       local ELAPSED
       ELAPSED=$(($(date +%s) - START_TIME))
       if [[ ${ELAPSED} -gt 1 ]]; then
        __logd "Download slot acquired (active: ${ACTIVE_AFTER}/${MAX_SLOTS}, waited: ${ELAPSED}s)"
       fi
       exit 0
      else
       # We exceeded the limit (shouldn't happen with mkdir, but handle it)
       rmdir "${MY_LOCK_DIR}" 2> /dev/null || true
       exit 1
      fi
     fi
    else
     # Lock already exists (shouldn't happen, but handle gracefully)
     exit 0
    fi
   fi
   exit 1
  ) 200> "${QUEUE_DIR}/semaphore_lock"

  if [[ $? -eq 0 ]]; then
   __log_finish
   return 0
  fi

  # Minimal wait - queries don't take long, so we can retry quickly
  sleep ${CHECK_INTERVAL}
  RETRY_COUNT=$((RETRY_COUNT + 1))
 done

 local TOTAL_WAIT
 TOTAL_WAIT=$(($(date +%s) - START_TIME))
 __loge "ERROR: Timeout waiting for download slot (waited: ${TOTAL_WAIT}s, max retries: ${MAX_RETRIES})"
 __log_finish
 return 1
}

# Release a download slot
# Returns: 0 on success, 1 on error
function __release_download_slot() {
 __log_start
 local QUEUE_DIR="${TMP_DIR}/download_queue"
 local ACTIVE_DIR="${QUEUE_DIR}/active"
 local MY_LOCK_DIR="${ACTIVE_DIR}/${BASHPID}.lock"
 local MY_LOCK_FILE="${ACTIVE_DIR}/${BASHPID}.lock"

 # Remove lock directory (atomic operation)
 if [[ -d "${MY_LOCK_DIR}" ]]; then
  rm -rf "${MY_LOCK_DIR}" || true
 elif [[ -f "${MY_LOCK_FILE}" ]]; then
  # Legacy support: if it's a file instead of directory, remove it
  rm -f "${MY_LOCK_FILE}" || true
 fi

 # Count remaining active slots
 local ACTIVE_COUNT=0
 if [[ -d "${ACTIVE_DIR}" ]]; then
  # Count both directories and files for backward compatibility
  ACTIVE_COUNT=$(find "${ACTIVE_DIR}" -name "*.lock" \( -type d -o -type f \) 2> /dev/null | wc -l)
 fi
 __logd "Download slot released (active: ${ACTIVE_COUNT}/${RATE_LIMIT:-4})"

 __log_finish
 return 0
}

# Clean up stale lock files (processes that are no longer running)
# Returns: 0 on success
function __cleanup_stale_slots() {
 __log_start
 local QUEUE_DIR="${TMP_DIR}/download_queue"
 local ACTIVE_DIR="${QUEUE_DIR}/active"

 if [[ ! -d "${ACTIVE_DIR}" ]]; then
  __log_finish
  return 0
 fi

 local CLEANED_COUNT=0
 local LOCK_ITEM
 # Handle both directories and files (for backward compatibility)
 for LOCK_ITEM in "${ACTIVE_DIR}"/*.lock; do
  [[ -e "${LOCK_ITEM}" ]] || continue
  local LOCK_BASENAME
  LOCK_BASENAME=$(basename "${LOCK_ITEM}")
  local PID_PART
  PID_PART=${LOCK_BASENAME%%.*}
  if [[ "${PID_PART}" =~ ^[0-9]+$ ]]; then
   if ! ps -p "${PID_PART}" > /dev/null 2>&1; then
    __logw "Removing stale lock (pid not running): ${LOCK_ITEM}"
    if [[ -d "${LOCK_ITEM}" ]]; then
     rm -rf "${LOCK_ITEM}" || true
    else
     rm -f "${LOCK_ITEM}" || true
    fi
    CLEANED_COUNT=$((CLEANED_COUNT + 1))
   fi
  fi
 done

 if [[ ${CLEANED_COUNT} -gt 0 ]]; then
  __logd "Cleaned up ${CLEANED_COUNT} stale lock(s)"
 fi

 __log_finish
 return 0
}

# Wait for a download slot (wrapper that combines acquire)
# Returns: 0 on success, 1 on timeout/error
function __wait_for_download_slot() {
 __acquire_download_slot
 return $?
}

# =============================================================================
# Legacy Ticket-Based Queue System (Deprecated)
# =============================================================================

# Get the next ticket number in the queue
# Returns: ticket number (integer)
# Side effect: increments the ticket counter atomically
function __get_download_ticket() {
 __log_start
 local QUEUE_DIR="${TMP_DIR}/download_queue"
 local TICKET_FILE="${QUEUE_DIR}/ticket_counter"
 local TICKET=0

 # Create queue directory if it doesn't exist
 mkdir -p "${QUEUE_DIR}"

 # Get ticket using atomic file operation (flock)
 # Use a temporary file to ensure atomic increment
 (
  flock -x 200
  if [[ -f "${TICKET_FILE}" ]]; then
   TICKET=$(cat "${TICKET_FILE}")
  fi
  TICKET=$((TICKET + 1))
  echo "${TICKET}" > "${TICKET_FILE}"
  echo "${TICKET}"
 ) 200> "${QUEUE_DIR}/ticket_lock"

 __log_finish
 return 0
}

# Prunes stale lock files in the active queue directory.
# Any lock file named as <pid>.<ticket>.lock whose PID is not running
# will be removed to prevent deadlocks.
function __queue_prune_stale_locks() {
 __log_start
 local QUEUE_DIR="${TMP_DIR}/download_queue"
 local ACTIVE_DIR="${QUEUE_DIR}/active"

 if [[ ! -d "${ACTIVE_DIR}" ]]; then
  __log_finish
  return 0
 fi

 local LOCK_FILE
 for LOCK_FILE in "${ACTIVE_DIR}"/*.lock; do
  [[ -e "${LOCK_FILE}" ]] || continue
  # Filename format: <pid>.<ticket>.lock
  local LOCK_BASENAME
  LOCK_BASENAME=$(basename "${LOCK_FILE}")
  local PID_PART
  PID_PART=${LOCK_BASENAME%%.*}
  if [[ "${PID_PART}" =~ ^[0-9]+$ ]]; then
   if ! ps -p "${PID_PART}" > /dev/null 2>&1; then
    __logw "Removing stale lock (pid not running): ${LOCK_FILE}"
    rm -f "${LOCK_FILE}" || true
   fi
  fi
 done
 __log_finish
 return 0
}

# Wait for download turn based on ticket number
# Parameters: ticket_number
# Returns: 0 when it's the turn, 1 on error
function __wait_for_download_turn() {
 __log_start
 local MY_TICKET="${1}"
 local QUEUE_DIR="${TMP_DIR}/download_queue"
 local CURRENT_SERVING_FILE="${QUEUE_DIR}/current_serving"
 local TICKET_FILE="${QUEUE_DIR}/ticket_counter"
 local MAX_SLOTS="${RATE_LIMIT:-4}"
 local CHECK_INTERVAL=1
 # Reduce wait time if CONTINUE_ON_OVERPASS_ERROR is enabled to avoid blocking
 local MAX_WAIT_TIME=3600
 if [[ "${CONTINUE_ON_OVERPASS_ERROR:-false}" == "true" ]]; then
  MAX_WAIT_TIME=600
  __logd "Reduced max wait time to ${MAX_WAIT_TIME}s due to CONTINUE_ON_OVERPASS_ERROR=true"
 fi
 # Safety window to auto-heal the queue when no one is active
 local AUTO_HEAL_AFTER=300
 local WAIT_COUNT=0
 local START_TIME
 START_TIME=$(date +%s)

 if [[ -z "${MY_TICKET}" ]]; then
  __loge "ERROR: Ticket number is required"
  __log_finish
  return 1
 fi

 __logd "Waiting for download turn (ticket: ${MY_TICKET}, max slots: ${MAX_SLOTS}, max wait: ${MAX_WAIT_TIME}s)"

 # Initialize current serving if not exists
 if [[ ! -f "${CURRENT_SERVING_FILE}" ]]; then
  echo "0" > "${CURRENT_SERVING_FILE}"
 fi

 while [[ ${WAIT_COUNT} -lt ${MAX_WAIT_TIME} ]]; do
  # Read current serving number atomically
  local CURRENT_SERVING=0
  (
   flock -s 200
   if [[ -f "${CURRENT_SERVING_FILE}" ]]; then
    CURRENT_SERVING=$(cat "${CURRENT_SERVING_FILE}" 2> /dev/null || echo "0")
   fi
  ) 200> "${QUEUE_DIR}/ticket_lock"

  # Calculate how many slots are currently in use
  local ACTIVE_DOWNLOADS=0
  if [[ -d "${QUEUE_DIR}/active" ]]; then
   ACTIVE_DOWNLOADS=$(find "${QUEUE_DIR}/active" -name "*.lock" -type f 2> /dev/null | wc -l)
  fi

  # Periodically prune stale locks to avoid deadlocks (every ~30s)
  if [[ $((WAIT_COUNT % 30)) -eq 0 ]]; then
   __queue_prune_stale_locks || true
  fi

  # Auto-heal: if no active downloads and tickets progressed beyond current,
  # and we've waited long enough, advance current_serving to the latest ticket.
  # More aggressive auto-heal when current_serving is stuck at 0 with high tickets
  local TICKET_COUNTER=0
  if [[ -f "${TICKET_FILE}" ]]; then
   TICKET_COUNTER=$(cat "${TICKET_FILE}" 2> /dev/null || echo "0")
  fi
  local TICKETS_WAITING=$((TICKET_COUNTER - CURRENT_SERVING))

  # Reduce auto-heal delay when current_serving is 0 and many tickets are waiting
  local EFFECTIVE_AUTO_HEAL_AFTER="${AUTO_HEAL_AFTER}"
  if [[ ${CURRENT_SERVING} -eq 0 ]] && [[ ${TICKETS_WAITING} -gt 10 ]] && [[ ${ACTIVE_DOWNLOADS} -eq 0 ]]; then
   # More aggressive: 30s instead of 300s when stuck at 0 with many tickets
   EFFECTIVE_AUTO_HEAL_AFTER=30
   if [[ $((WAIT_COUNT % 60)) -eq 0 ]] && [[ ${WAIT_COUNT} -ge 60 ]]; then
    __logw "Detected queue stuck (current_serving: ${CURRENT_SERVING}, tickets waiting: ${TICKETS_WAITING}), using aggressive auto-heal (${EFFECTIVE_AUTO_HEAL_AFTER}s)"
   fi
  fi

  if [[ ${WAIT_COUNT} -ge ${EFFECTIVE_AUTO_HEAL_AFTER} ]] && [[ ${ACTIVE_DOWNLOADS} -eq 0 ]]; then
   if [[ ${TICKET_COUNTER} -gt ${CURRENT_SERVING} ]]; then
    (
     flock -x 200
     local CUR=0
     if [[ -f "${CURRENT_SERVING_FILE}" ]]; then
      CUR=$(cat "${CURRENT_SERVING_FILE}" 2> /dev/null || echo "0")
     fi
     # Re-check after lock and only advance if still safe (no active)
     local ACTIVE_NOW=0
     if [[ -d "${QUEUE_DIR}/active" ]]; then
      ACTIVE_NOW=$(find "${QUEUE_DIR}/active" -name "*.lock" -type f 2> /dev/null | wc -l)
     fi
     if [[ ${ACTIVE_NOW} -eq 0 ]] && [[ ${TICKET_COUNTER} -gt ${CUR} ]]; then
      echo "${TICKET_COUNTER}" > "${CURRENT_SERVING_FILE}"
      __logw "Auto-heal advanced queue (current_serving: ${CUR} -> ${TICKET_COUNTER}, tickets waiting: ${TICKETS_WAITING}, waited: ${WAIT_COUNT}s)"
     elif [[ ${ACTIVE_NOW} -gt 0 ]]; then
      __logd "Auto-heal skipped: active downloads detected (${ACTIVE_NOW})"
     elif [[ ${TICKET_COUNTER} -le ${CUR} ]]; then
      __logd "Auto-heal skipped: ticket counter (${TICKET_COUNTER}) not greater than current serving (${CUR})"
     fi
    ) 200> "${QUEUE_DIR}/ticket_lock"
   else
    if [[ $((WAIT_COUNT % 60)) -eq 0 ]] && [[ ${WAIT_COUNT} -ge 60 ]]; then
     __logw "Auto-heal condition met but ticket counter (${TICKET_COUNTER}) not greater than current serving (${CURRENT_SERVING})"
    fi
   fi
  fi

  # Check if it's my turn (ticket <= current_serving + max_slots) and slots available
  if [[ ${MY_TICKET} -le $((CURRENT_SERVING + MAX_SLOTS)) ]] \
   && [[ ${ACTIVE_DOWNLOADS} -lt ${MAX_SLOTS} ]]; then
   # Try to claim slot atomically
   mkdir -p "${QUEUE_DIR}/active"
   local MY_LOCK_FILE="${QUEUE_DIR}/active/${BASHPID}.${MY_TICKET}.lock"

   # Use flock to ensure only one process can claim a slot at a time
   (
    flock -x 201
    # Re-check active downloads after acquiring lock
    local ACTIVE_AFTER_LOCK=0
    if [[ -d "${QUEUE_DIR}/active" ]]; then
     ACTIVE_AFTER_LOCK=$(find "${QUEUE_DIR}/active" -name "*.lock" -type f 2> /dev/null | wc -l)
    fi

    # Double-check that we can still proceed
    local CURRENT_AFTER_LOCK=0
    if [[ -f "${CURRENT_SERVING_FILE}" ]]; then
     CURRENT_AFTER_LOCK=$(cat "${CURRENT_SERVING_FILE}" 2> /dev/null || echo "0")
    fi

    if [[ ${MY_TICKET} -le $((CURRENT_AFTER_LOCK + MAX_SLOTS)) ]] \
     && [[ ${ACTIVE_AFTER_LOCK} -lt ${MAX_SLOTS} ]]; then
     # Check Overpass API status
     local WAIT_TIME=0
     local STATUS_CHECK_FAILED=false
     set +e
     WAIT_TIME=$(__check_overpass_status 2>&1 | tail -1)
     local STATUS_CHECK_EXIT=$?
     set -e

     # If status check failed or returned non-zero, allow through anyway (fallback)
     # The queue system itself provides rate limiting through MAX_SLOTS
     if [[ ${STATUS_CHECK_EXIT} -ne 0 ]] || [[ -z "${WAIT_TIME}" ]]; then
      STATUS_CHECK_FAILED=true
      __logw "Overpass status check failed or returned empty, allowing download anyway (ticket: ${MY_TICKET})"
      WAIT_TIME=0
     fi

     if [[ ${WAIT_TIME} -eq 0 ]]; then
      # Claim the slot
      echo "${MY_TICKET}" > "${MY_LOCK_FILE}"
      if [[ "${STATUS_CHECK_FAILED}" == "true" ]]; then
       __logd "Download slot granted (ticket: ${MY_TICKET}, position: ${ACTIVE_AFTER_LOCK}) - status check bypassed"
      else
       __logd "Download slot granted (ticket: ${MY_TICKET}, position: ${ACTIVE_AFTER_LOCK})"
      fi
      exit 0
     else
      __logd "Overpass API not ready (wait time: ${WAIT_TIME}s), will retry"
     fi
    fi
    exit 1
   ) 201> "${QUEUE_DIR}/slot_lock"

   if [[ $? -eq 0 ]]; then
    __log_finish
    return 0
   fi
  fi

  sleep ${CHECK_INTERVAL}
  WAIT_COUNT=$((WAIT_COUNT + CHECK_INTERVAL))

  # Log progress every 10 seconds, with more detail if waiting longer
  if [[ $((WAIT_COUNT % 10)) -eq 0 ]]; then
   local ELAPSED_TIME
   ELAPSED_TIME=$(($(date +%s) - START_TIME))
   __logw "Still waiting for download turn (ticket: ${MY_TICKET}, current: ${CURRENT_SERVING}, active: ${ACTIVE_DOWNLOADS}/${MAX_SLOTS}, waited: ${WAIT_COUNT}s, elapsed: ${ELAPSED_TIME}s)"
  fi
  # Log warning every 60 seconds with more context
  if [[ $((WAIT_COUNT % 60)) -eq 0 ]] && [[ ${WAIT_COUNT} -ge 60 ]]; then
   __logw "Download queue wait time: ${WAIT_COUNT}s (max: ${MAX_WAIT_TIME}s). Ticket ${MY_TICKET} waiting, current serving: ${CURRENT_SERVING}, active: ${ACTIVE_DOWNLOADS}/${MAX_SLOTS}"
  fi
 done

 local TOTAL_WAIT_TIME
 TOTAL_WAIT_TIME=$(($(date +%s) - START_TIME))
 __loge "ERROR: Timeout waiting for download turn (ticket: ${MY_TICKET}, waited: ${WAIT_COUNT}s, total time: ${TOTAL_WAIT_TIME}s)"
 __log_finish
 return 1
}

# Release download slot and advance queue
# Parameters: ticket_number
# Returns: 0 on success, 1 on error
function __release_download_ticket() {
 __log_start
 local MY_TICKET="${1}"
 local QUEUE_DIR="${TMP_DIR}/download_queue"
 local CURRENT_SERVING_FILE="${QUEUE_DIR}/current_serving"
 local MY_LOCK_FILE="${QUEUE_DIR}/active/${BASHPID}.${MY_TICKET}.lock"

 if [[ -z "${MY_TICKET}" ]]; then
  __loge "ERROR: Ticket number is required"
  __log_finish
  return 1
 fi

 # Remove my lock file
 if [[ -f "${MY_LOCK_FILE}" ]]; then
  rm -f "${MY_LOCK_FILE}"
  __logd "Released download slot (ticket: ${MY_TICKET})"
 fi

 # Advance current serving number if this is the next in line
 (
  flock -x 200
  local CURRENT_SERVING=0
  if [[ -f "${CURRENT_SERVING_FILE}" ]]; then
   CURRENT_SERVING=$(cat "${CURRENT_SERVING_FILE}" 2> /dev/null || echo "0")
  fi

  # Advance to next ticket when releasing the current or a newer slot
  local NEXT_SERVING=$((MY_TICKET + 1))
  if [[ ${NEXT_SERVING} -gt ${CURRENT_SERVING} ]]; then
   echo "${NEXT_SERVING}" > "${CURRENT_SERVING_FILE}"
   __logd "Queue advanced (now serving: ${NEXT_SERVING})"
  fi
 ) 200> "${QUEUE_DIR}/ticket_lock"

 __log_finish
 return 0
}

if ! declare -f __retry_file_operation > /dev/null 2>&1; then
 # Retry file operations with exponential backoff and cleanup on failure
 # Parameters: operation_command max_retries base_delay [cleanup_command] [smart_wait]
 # Returns: 0 if successful, 1 if failed after all retries
 function __retry_file_operation() {
  __log_start
  local OPERATION_COMMAND="$1"
  local MAX_RETRIES_LOCAL="${2:-3}"
  local BASE_DELAY_LOCAL="${3:-2}"
  local CLEANUP_COMMAND="${4:-}"
  local SMART_WAIT="${5:-false}"
  # Optional: explicit Overpass endpoint for smart-wait (avoids relying on global)
  local SMART_WAIT_ENDPOINT="${6:-}"
  local RETRY_COUNT=0
  local EXPONENTIAL_DELAY="${BASE_DELAY_LOCAL}"

  __logd "Executing file operation with retry logic: ${OPERATION_COMMAND}"
  __logd "Max retries: ${MAX_RETRIES_LOCAL}, Base delay: ${BASE_DELAY_LOCAL}s, Smart wait: ${SMART_WAIT}"

  # Get download slot if smart wait is enabled for Overpass operations
  # Use provided SMART_WAIT_ENDPOINT when available; else fall back to OVERPASS_INTERPRETER matching
  local EFFECTIVE_OVERPASS_FOR_WAIT="${SMART_WAIT_ENDPOINT:-}"
  if [[ -z "${EFFECTIVE_OVERPASS_FOR_WAIT}" ]] && [[ "${OPERATION_COMMAND}" == *"/api/interpreter"* ]]; then
   EFFECTIVE_OVERPASS_FOR_WAIT="${OVERPASS_INTERPRETER}"
  fi

  if [[ "${SMART_WAIT}" == "true" ]] && [[ -n "${EFFECTIVE_OVERPASS_FOR_WAIT}" ]]; then
   # Use simple semaphore system (recommended - no tickets, no ordering)
   if ! __wait_for_download_slot; then
    __loge "Failed to obtain download slot after waiting"
    trap - EXIT INT TERM
    __log_finish
    return 1
   fi
   __logd "Download slot acquired, proceeding with download"
   # Setup slot cleanup on exit
   # shellcheck disable=SC2317
   __cleanup_slot() {
    __release_download_slot > /dev/null 2>&1 || true
   }
   trap '__cleanup_slot' EXIT INT TERM
  fi

  while [[ ${RETRY_COUNT} -lt ${MAX_RETRIES_LOCAL} ]]; do
   # Execute the operation and capture both stdout and stderr for better error logging
   if eval "${OPERATION_COMMAND}"; then
    __logd "File operation succeeded on attempt $((RETRY_COUNT + 1))"
    # Release download slot if acquired
    if [[ "${SMART_WAIT}" == "true" ]] && [[ -n "${EFFECTIVE_OVERPASS_FOR_WAIT}" ]]; then
     __release_download_slot > /dev/null 2>&1 || true
    fi
    trap - EXIT INT TERM
    __log_finish
    return 0
   else
    # If this looks like an Overpass operation, check for specific error messages
    if [[ "${OPERATION_COMMAND}" == *"/api/interpreter"* ]]; then
     __logw "Overpass API call failed on attempt $((RETRY_COUNT + 1))"

     # Try to extract and log specific error messages from stderr
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
    # Exponential backoff: multiply delay by 1.5 for next attempt
    EXPONENTIAL_DELAY=$((EXPONENTIAL_DELAY * 3 / 2))
   fi
  done

  # If cleanup command is provided, execute it
  if [[ -n "${CLEANUP_COMMAND}" ]]; then
   __logw "Executing cleanup command due to file operation failure"
   if eval "${CLEANUP_COMMAND}"; then
    __logd "Cleanup command executed successfully"
   else
    __logw "Cleanup command failed"
   fi
  fi

  __loge "File operation failed after ${MAX_RETRIES_LOCAL} attempts"
  # Release download slot if acquired
  if [[ "${SMART_WAIT}" == "true" ]] && [[ -n "${EFFECTIVE_OVERPASS_FOR_WAIT}" ]]; then
   __release_download_slot > /dev/null 2>&1 || true
  fi
  trap - EXIT INT TERM
  __log_finish
  return 1
 }
fi

if ! declare -f __check_overpass_status > /dev/null 2>&1; then
 # Check Overpass API status and wait time
 # Returns: 0 if slots available now, number of seconds to wait if busy
 function __check_overpass_status() {
  __log_start
  # Extract the base URL from OVERPASS_INTERPRETER
  # Handle both https://server.com/api/interpreter and https://server.com formats
  local BASE_URL="${OVERPASS_INTERPRETER%/api/interpreter}"
  BASE_URL="${BASE_URL%/}" # Remove trailing slash
  local STATUS_URL="${BASE_URL}/status"
  local STATUS_OUTPUT
  local AVAILABLE_SLOTS
  local WAIT_TIME

  __logd "Checking Overpass API status at ${STATUS_URL}..."

  if ! STATUS_OUTPUT=$(curl -s "${STATUS_URL}" 2>&1); then
   __logw "Could not reach Overpass API status page, assuming available"
   __log_finish
   echo "0"
   return 0
  fi

  # Extract available slots number (format: "X slots available now")
  AVAILABLE_SLOTS=$(echo "${STATUS_OUTPUT}" | grep -o '[0-9]* slots available now' | head -1 | grep -o '[0-9]*' || echo "0")

  if [[ -n "${AVAILABLE_SLOTS}" ]] && [[ "${AVAILABLE_SLOTS}" -gt 0 ]]; then
   __logd "Overpass API has ${AVAILABLE_SLOTS} slot(s) available now"
   __log_finish
   echo "0"
   return 0
  fi

  # Extract wait time from "Slot available after" messages (format: "...in X seconds.")
  # There can be multiple lines, we need the minimum wait time
  local ALL_WAIT_TIMES
  ALL_WAIT_TIMES=$(echo "${STATUS_OUTPUT}" | grep -o 'in [0-9]* seconds' | grep -o '[0-9]*' || echo "")

  if [[ -n "${ALL_WAIT_TIMES}" ]]; then
   # Find the minimum wait time from all available slots
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
fi

# Retry network operations with exponential backoff and HTTP error handling
# Parameters: url output_file max_retries base_delay [timeout]
# Returns: 0 if successful, 1 if failed after all retries
function __retry_network_operation() {
 __log_start
 local URL="$1"
 local OUTPUT_FILE="$2"
 local LOCAL_MAX_RETRIES="${3:-5}"
 local BASE_DELAY="${4:-2}"
 local TIMEOUT="${5:-30}"
 local RETRY_COUNT=0
 local EXPONENTIAL_DELAY="${BASE_DELAY}"

 __logd "Executing network operation with retry logic: ${URL}"
 __logd "Output file: ${OUTPUT_FILE}, Max retries: ${LOCAL_MAX_RETRIES}, Base delay: ${BASE_DELAY}s, Timeout: ${TIMEOUT}s"
 if [[ -n "${DOWNLOAD_USER_AGENT:-}" ]]; then
  __logd "Using User-Agent for network operation: ${DOWNLOAD_USER_AGENT}"
 fi

 while [[ ${RETRY_COUNT} -lt ${LOCAL_MAX_RETRIES} ]]; do
  # Use wget with specific error handling and timeout
  local WGET_UA_ARG=""
  if [[ -n "${DOWNLOAD_USER_AGENT:-}" ]]; then
   WGET_UA_ARG="--user-agent=\"${DOWNLOAD_USER_AGENT}\""
  else
   WGET_UA_ARG="--user-agent=\"OSM-Notes-Ingestion/1.0\""
  fi
  if wget --timeout="${TIMEOUT}" --tries=1 ${WGET_UA_ARG} \
   -O "${OUTPUT_FILE}" "${URL}" 2> /dev/null; then
   # Verify the downloaded file exists and has content
   if [[ -f "${OUTPUT_FILE}" ]] && [[ -s "${OUTPUT_FILE}" ]]; then
    __logd "Network operation succeeded on attempt $((RETRY_COUNT + 1))"
    __log_finish
    return 0
   else
    __logw "Downloaded file is empty or missing on attempt $((RETRY_COUNT + 1))"
   fi
  else
   __logw "Network operation failed on attempt $((RETRY_COUNT + 1))"
  fi

  RETRY_COUNT=$((RETRY_COUNT + 1))

  if [[ ${RETRY_COUNT} -lt ${LOCAL_MAX_RETRIES} ]]; then
   __logw "Network operation failed on attempt ${RETRY_COUNT}, retrying in ${EXPONENTIAL_DELAY}s"
   sleep "${EXPONENTIAL_DELAY}"
   # Exponential backoff: double the delay for next attempt
   EXPONENTIAL_DELAY=$((EXPONENTIAL_DELAY * 2))
  fi
 done

 __loge "Network operation failed after ${LOCAL_MAX_RETRIES} attempts"
 __log_finish
 return 1
}

# Retry Overpass API calls with specific configuration
# Parameters: query output_file max_retries base_delay timeout
# Returns: 0 if successful, 1 if failed after all retries
function __retry_overpass_api() {
 __log_start
 local QUERY="$1"
 local OUTPUT_FILE="$2"
 local LOCAL_MAX_RETRIES="${3:-3}"
 local BASE_DELAY="${4:-5}"
 local TIMEOUT="${5:-300}"
 local RETRY_COUNT=0
 local EXPONENTIAL_DELAY="${BASE_DELAY}"

 __logd "Executing Overpass API call with retry logic"
 __logd "Query: ${QUERY}"
 __logd "Output: ${OUTPUT_FILE}, Max retries: ${LOCAL_MAX_RETRIES}, Timeout: ${TIMEOUT}s"
 if [[ -n "${DOWNLOAD_USER_AGENT:-}" ]]; then
  __logd "Using User-Agent for Overpass: ${DOWNLOAD_USER_AGENT}"
 fi

 while [[ ${RETRY_COUNT} -lt ${LOCAL_MAX_RETRIES} ]]; do
  if [[ -n "${DOWNLOAD_USER_AGENT:-}" ]]; then
   if wget -q -O "${OUTPUT_FILE}" --timeout="${TIMEOUT}" \
    --header="User-Agent: ${DOWNLOAD_USER_AGENT}" \
    "https://overpass-api.de/api/interpreter?data=${QUERY}"; then
    if [[ -f "${OUTPUT_FILE}" ]] && [[ -s "${OUTPUT_FILE}" ]]; then
     __logd "Overpass API call succeeded on attempt $((RETRY_COUNT + 1))"
     __log_finish
     return 0
    else
     __logw "Overpass API call returned empty file on attempt $((RETRY_COUNT + 1))"
    fi
   else
    __logw "Overpass API call failed on attempt $((RETRY_COUNT + 1))"
   fi
  else
   if wget -q -O "${OUTPUT_FILE}" --timeout="${TIMEOUT}" \
    "https://overpass-api.de/api/interpreter?data=${QUERY}"; then
    if [[ -f "${OUTPUT_FILE}" ]] && [[ -s "${OUTPUT_FILE}" ]]; then
     __logd "Overpass API call succeeded on attempt $((RETRY_COUNT + 1))"
     __log_finish
     return 0
    else
     __logw "Overpass API call returned empty file on attempt $((RETRY_COUNT + 1))"
    fi
   else
    __logw "Overpass API call failed on attempt $((RETRY_COUNT + 1))"
   fi
  fi

  RETRY_COUNT=$((RETRY_COUNT + 1))
  if [[ ${RETRY_COUNT} -lt ${LOCAL_MAX_RETRIES} ]]; then
   __logw "Overpass API call failed on attempt ${RETRY_COUNT}, retrying in ${EXPONENTIAL_DELAY}s"
   sleep "${EXPONENTIAL_DELAY}"
   EXPONENTIAL_DELAY=$((EXPONENTIAL_DELAY * 2))
  fi
 done

 __loge "Overpass API call failed after ${LOCAL_MAX_RETRIES} attempts"
 __log_finish
 return 1
}

# Retry OSM API calls with specific configuration
# Parameters: url output_file max_retries base_delay timeout
# Returns: 0 if successful, 1 if failed after all retries
function __retry_osm_api() {
 __log_start
 local URL="$1"
 local OUTPUT_FILE="$2"
 local LOCAL_MAX_RETRIES="${3:-5}"
 local BASE_DELAY="${4:-2}"
 local TIMEOUT="${5:-30}"
 local RETRY_COUNT=0
 local EXPONENTIAL_DELAY="${BASE_DELAY}"

 __logd "Executing OSM API call with retry logic: ${URL}"
 __logd "Output: ${OUTPUT_FILE}, Max retries: ${LOCAL_MAX_RETRIES}, Timeout: ${TIMEOUT}s"
 if [[ -n "${DOWNLOAD_USER_AGENT:-}" ]]; then
  __logd "Using User-Agent for OSM API: ${DOWNLOAD_USER_AGENT}"
 fi

 while [[ ${RETRY_COUNT} -lt ${LOCAL_MAX_RETRIES} ]]; do
  if [[ -n "${DOWNLOAD_USER_AGENT:-}" ]]; then
   if curl -s --connect-timeout "${TIMEOUT}" --max-time "${TIMEOUT}" \
    -H "User-Agent: ${DOWNLOAD_USER_AGENT}" \
    -o "${OUTPUT_FILE}" "${URL}"; then
    if [[ -f "${OUTPUT_FILE}" ]] && [[ -s "${OUTPUT_FILE}" ]]; then
     __logd "OSM API call succeeded on attempt $((RETRY_COUNT + 1))"
     __log_finish
     return 0
    else
     __logw "OSM API call returned empty file on attempt $((RETRY_COUNT + 1))"
    fi
   else
    __logw "OSM API call failed on attempt $((RETRY_COUNT + 1))"
   fi
  else
   if curl -s --connect-timeout "${TIMEOUT}" --max-time "${TIMEOUT}" \
    -o "${OUTPUT_FILE}" "${URL}"; then
    if [[ -f "${OUTPUT_FILE}" ]] && [[ -s "${OUTPUT_FILE}" ]]; then
     __logd "OSM API call succeeded on attempt $((RETRY_COUNT + 1))"
     __log_finish
     return 0
    else
     __logw "OSM API call returned empty file on attempt $((RETRY_COUNT + 1))"
    fi
   else
    __logw "OSM API call failed on attempt $((RETRY_COUNT + 1))"
   fi
  fi

  RETRY_COUNT=$((RETRY_COUNT + 1))
  if [[ ${RETRY_COUNT} -lt ${LOCAL_MAX_RETRIES} ]]; then
   __logw "OSM API call failed on attempt ${RETRY_COUNT}, retrying in ${EXPONENTIAL_DELAY}s"
   sleep "${EXPONENTIAL_DELAY}"
   EXPONENTIAL_DELAY=$((EXPONENTIAL_DELAY * 2))
  fi
 done

 __loge "OSM API call failed after ${LOCAL_MAX_RETRIES} attempts"
 __log_finish
 return 1
}

# Retry GeoServer API calls with authentication
# Parameters: url method data output_file max_retries base_delay timeout
# Returns: 0 if successful, 1 if failed after all retries
function __retry_geoserver_api() {
 __log_start
 local URL="$1"
 local METHOD="${2:-GET}"
 local DATA="${3:-}"
 local OUTPUT_FILE="$4"
 local LOCAL_MAX_RETRIES="${5:-3}"
 local BASE_DELAY="${6:-2}"
 local TIMEOUT="${7:-30}"
 local RETRY_COUNT=0
 local EXPONENTIAL_DELAY="${BASE_DELAY}"

 __logd "Executing GeoServer API call with retry logic: ${URL}"
 __logd "Method: ${METHOD}, Output: ${OUTPUT_FILE}, Max retries: ${LOCAL_MAX_RETRIES}, Timeout: ${TIMEOUT}s"

 while [[ ${RETRY_COUNT} -lt ${LOCAL_MAX_RETRIES} ]]; do
  if [[ "${METHOD}" == "POST" ]] && [[ -n "${DATA}" ]]; then
   if curl -s --connect-timeout "${TIMEOUT}" --max-time "${TIMEOUT}" \
    -X POST -d "${DATA}" -o "${OUTPUT_FILE}" "${URL}"; then
    if [[ -f "${OUTPUT_FILE}" ]] && [[ -s "${OUTPUT_FILE}" ]]; then
     __logd "GeoServer API call succeeded on attempt $((RETRY_COUNT + 1))"
     __log_finish
     return 0
    else
     __logw "GeoServer API call returned empty file on attempt $((RETRY_COUNT + 1))"
    fi
   else
    __logw "GeoServer API call failed on attempt $((RETRY_COUNT + 1))"
   fi
  else
   if curl -s --connect-timeout "${TIMEOUT}" --max-time "${TIMEOUT}" \
    -o "${OUTPUT_FILE}" "${URL}"; then
    if [[ -f "${OUTPUT_FILE}" ]] && [[ -s "${OUTPUT_FILE}" ]]; then
     __logd "GeoServer API call succeeded on attempt $((RETRY_COUNT + 1))"
     __log_finish
     return 0
    else
     __logw "GeoServer API call returned empty file on attempt $((RETRY_COUNT + 1))"
    fi
   else
    __logw "GeoServer API call failed on attempt $((RETRY_COUNT + 1))"
   fi
  fi

  RETRY_COUNT=$((RETRY_COUNT + 1))
  if [[ ${RETRY_COUNT} -lt ${LOCAL_MAX_RETRIES} ]]; then
   __logw "GeoServer API call failed on attempt ${RETRY_COUNT}, retrying in ${EXPONENTIAL_DELAY}s"
   sleep "${EXPONENTIAL_DELAY}"
   EXPONENTIAL_DELAY=$((EXPONENTIAL_DELAY * 2))
  fi
 done

 __loge "GeoServer API call failed after ${LOCAL_MAX_RETRIES} attempts"
 __log_finish
 return 1
}

# Retry network operations with exponential backoff and HTTP error handling
# Parameters: url output_file max_retries base_delay [timeout]
# Returns: 0 if successful, 1 if failed after all retries
function __retry_network_operation() {
 __log_start
 local URL="$1"
 local OUTPUT_FILE="$2"
 local LOCAL_MAX_RETRIES="${3:-5}"
 local BASE_DELAY="${4:-2}"
 local TIMEOUT="${5:-30}"
 local RETRY_COUNT=0
 local EXPONENTIAL_DELAY="${BASE_DELAY}"

 __logd "Executing network operation with retry logic: ${URL}"
 __logd "Output file: ${OUTPUT_FILE}, Max retries: ${LOCAL_MAX_RETRIES}, Base delay: ${BASE_DELAY}s, Timeout: ${TIMEOUT}s"
 if [[ -n "${DOWNLOAD_USER_AGENT:-}" ]]; then
  __logd "Using User-Agent for network operation: ${DOWNLOAD_USER_AGENT}"
 fi

 while [[ ${RETRY_COUNT} -lt ${LOCAL_MAX_RETRIES} ]]; do
  # Use wget with specific error handling and timeout
  if [[ -n "${DOWNLOAD_USER_AGENT:-}" ]]; then
   if wget --timeout="${TIMEOUT}" --tries=1 --user-agent="${DOWNLOAD_USER_AGENT}" \
    -O "${OUTPUT_FILE}" "${URL}" 2> /dev/null; then
    # Verify the downloaded file exists and has content
    if [[ -f "${OUTPUT_FILE}" ]] && [[ -s "${OUTPUT_FILE}" ]]; then
     __logd "Network operation succeeded on attempt $((RETRY_COUNT + 1))"
     __log_finish
     return 0
    else
     __logw "Downloaded file is empty or missing on attempt $((RETRY_COUNT + 1))"
    fi
   else
    __logw "Network operation failed on attempt $((RETRY_COUNT + 1))"
   fi
  else
   if wget --timeout="${TIMEOUT}" --tries=1 --user-agent="OSM-Notes-Ingestion/1.0" \
    -O "${OUTPUT_FILE}" "${URL}" 2> /dev/null; then
    # Verify the downloaded file exists and has content
    if [[ -f "${OUTPUT_FILE}" ]] && [[ -s "${OUTPUT_FILE}" ]]; then
     __logd "Network operation succeeded on attempt $((RETRY_COUNT + 1))"
     __log_finish
     return 0
    else
     __logw "Downloaded file is empty or missing on attempt $((RETRY_COUNT + 1))"
    fi
   else
    __logw "Network operation failed on attempt $((RETRY_COUNT + 1))"
   fi
  fi

  RETRY_COUNT=$((RETRY_COUNT + 1))

  if [[ ${RETRY_COUNT} -lt ${LOCAL_MAX_RETRIES} ]]; then
   __logw "Network operation failed on attempt ${RETRY_COUNT}, retrying in ${EXPONENTIAL_DELAY}s"
   sleep "${EXPONENTIAL_DELAY}"
   # Exponential backoff: double the delay for next attempt
   EXPONENTIAL_DELAY=$((EXPONENTIAL_DELAY * 2))
  fi
 done

 __loge "Network operation failed after ${LOCAL_MAX_RETRIES} attempts"
 __log_finish
 return 1
}

# Retry GeoServer API calls with authentication
# Parameters: url method data output_file max_retries base_delay timeout
# Returns: 0 if successful, 1 if failed after all retries
function __retry_geoserver_api() {
 __log_start
 local URL="$1"
 local METHOD="${2:-GET}"
 local DATA="${3:-}"
 local OUTPUT_FILE="${4:-/dev/null}"
 local LOCAL_MAX_RETRIES="${5:-3}"
 local BASE_DELAY="${6:-2}"
 local TIMEOUT="${7:-30}"
 local RETRY_COUNT=0
 local EXPONENTIAL_DELAY="${BASE_DELAY}"

 __logd "Executing GeoServer API call with retry logic: ${METHOD} ${URL}"
 __logd "Output: ${OUTPUT_FILE}, Max retries: ${LOCAL_MAX_RETRIES}, Timeout: ${TIMEOUT}s"

 while [[ ${RETRY_COUNT} -lt ${LOCAL_MAX_RETRIES} ]]; do
  local CURL_CMD="curl -s --connect-timeout ${TIMEOUT} --max-time ${TIMEOUT}"
  CURL_CMD="${CURL_CMD} -u \"${GEOSERVER_USER}:${GEOSERVER_PASSWORD}\""

  if [[ "${METHOD}" == "POST" ]] || [[ "${METHOD}" == "PUT" ]]; then
   CURL_CMD="${CURL_CMD} -X ${METHOD}"
   if [[ -n "${DATA}" ]]; then
    CURL_CMD="${CURL_CMD} -d \"${DATA}\""
   fi
  fi

  CURL_CMD="${CURL_CMD} -o \"${OUTPUT_FILE}\" \"${URL}\""

  if eval "${CURL_CMD}"; then
   __logd "GeoServer API call succeeded on attempt $((RETRY_COUNT + 1))"
   __log_finish
   return 0
  else
   __logw "GeoServer API call failed on attempt $((RETRY_COUNT + 1))"
  fi

  RETRY_COUNT=$((RETRY_COUNT + 1))
  if [[ ${RETRY_COUNT} -lt ${LOCAL_MAX_RETRIES} ]]; then
   __logw "GeoServer API call failed on attempt ${RETRY_COUNT}, retrying in ${EXPONENTIAL_DELAY}s"
   sleep "${EXPONENTIAL_DELAY}"
   EXPONENTIAL_DELAY=$((EXPONENTIAL_DELAY * 2))
  fi
 done

 __loge "GeoServer API call failed after ${LOCAL_MAX_RETRIES} attempts"
 __log_finish
 return 1
}

# Retry database operations with specific configuration
# Parameters: query output_file max_retries base_delay
# Returns: 0 if successful, 1 if failed after all retries
function __retry_database_operation() {
 __log_start
 local QUERY="$1"
 local OUTPUT_FILE="${2:-/dev/null}"
 local LOCAL_MAX_RETRIES="${3:-3}"
 local BASE_DELAY="${4:-2}"
 local RETRY_COUNT=0
 local EXPONENTIAL_DELAY="${BASE_DELAY}"
 local ERROR_FILE
 ERROR_FILE=$(mktemp)

 __logd "Executing database operation with retry logic"
 __logd "Query: ${QUERY}"
 __logd "Output: ${OUTPUT_FILE}, Max retries: ${LOCAL_MAX_RETRIES}"

 while [[ ${RETRY_COUNT} -lt ${LOCAL_MAX_RETRIES} ]]; do
  # Use ON_ERROR_STOP=1 to ensure SQL errors cause command to fail
  local PSQL_EXIT_CODE=0
  psql -d "${DBNAME}" -Atq -v ON_ERROR_STOP=1 -c "${QUERY}" > "${OUTPUT_FILE}" 2> "${ERROR_FILE}" || PSQL_EXIT_CODE=$?

  # Check for SQL errors in output file (with -Atq, errors may go to stdout)
  local HAS_ERROR=false
  if [[ -s "${OUTPUT_FILE}" ]]; then
   if grep -qiE "^ERROR\|^error\|no existe\|relation.*does not exist" "${OUTPUT_FILE}" 2> /dev/null; then
    HAS_ERROR=true
    __loge "SQL error detected in output: $(head -1 "${OUTPUT_FILE}")"
   fi
  fi

  # Check for errors in error file (stderr)
  if [[ -s "${ERROR_FILE}" ]]; then
   if grep -qiE "ERROR\|error\|no existe\|relation.*does not exist" "${ERROR_FILE}" 2> /dev/null; then
    HAS_ERROR=true
    __loge "PostgreSQL error: $(cat "${ERROR_FILE}")"
   fi
  fi

  if [[ ${PSQL_EXIT_CODE} -eq 0 ]] && [[ "${HAS_ERROR}" == false ]]; then
   __logd "Database operation succeeded on attempt $((RETRY_COUNT + 1))"
   rm -f "${ERROR_FILE}"
   __log_finish
   return 0
  else
   __logw "Database operation failed on attempt $((RETRY_COUNT + 1)) (exit code: ${PSQL_EXIT_CODE})"
  fi

  RETRY_COUNT=$((RETRY_COUNT + 1))
  if [[ ${RETRY_COUNT} -lt ${LOCAL_MAX_RETRIES} ]]; then
   __logw "Database operation failed on attempt ${RETRY_COUNT}, retrying in ${EXPONENTIAL_DELAY}s"
   sleep "${EXPONENTIAL_DELAY}"
   EXPONENTIAL_DELAY=$((EXPONENTIAL_DELAY * 2))
  fi
 done

 # Log final error before exiting
 if [[ -s "${ERROR_FILE}" ]]; then
  __loge "Final PostgreSQL error: $(cat "${ERROR_FILE}")"
 fi
 rm -f "${ERROR_FILE}"

 __loge "Database operation failed after ${LOCAL_MAX_RETRIES} attempts"
 __log_finish
 return 1
}

# Function to log data gaps to file and database
# Parameters: gap_type gap_count total_count error_details
function __log_data_gap() {
 __log_start
 local GAP_TYPE="$1"
 local GAP_COUNT="$2"
 local TOTAL_COUNT="$3"
 local ERROR_DETAILS="$4"
 local GAP_PERCENTAGE=$((GAP_COUNT * 100 / TOTAL_COUNT))

 __logd "Logging data gap: ${GAP_TYPE} - ${GAP_COUNT}/${TOTAL_COUNT} (${GAP_PERCENTAGE}%)"

 # Log to file
 local GAP_FILE="/tmp/processAPINotes_gaps.log"
 touch "${GAP_FILE}"

 cat >> "${GAP_FILE}" << EOF
========================================
GAP DETECTED: $(date '+%Y-%m-%d %H:%M:%S')
========================================
Type: ${GAP_TYPE}
Count: ${GAP_COUNT}/${TOTAL_COUNT} (${GAP_PERCENTAGE}%)
Details: ${ERROR_DETAILS}
---
EOF

 # Log to database
 psql -d "${DBNAME}" -c "
    INSERT INTO data_gaps (
      gap_type,
      gap_count,
      total_count,
      gap_percentage,
      error_details,
      processed
    ) VALUES (
      '${GAP_TYPE}',
      ${GAP_COUNT},
      ${TOTAL_COUNT},
      ${GAP_PERCENTAGE},
      '${ERROR_DETAILS}',
      FALSE
    )
  " 2> /dev/null || true

 __logd "Gap logged to file and database"
 __log_finish
}
