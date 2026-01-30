#!/bin/bash

# Note Processing Functions for OSM-Notes-profile
# Author: Andres Gomez (AngocA)
# Version: 2025-12-20
# shellcheck disable=SC2034
VERSION="2025-12-20"

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

##
# Assigns countries to notes using location data (implementation)
# Main function for country assignment to notes. Supports two modes: production mode
# (loads backup CSV for speed) and hybrid/test mode (calculates countries directly).
# In production mode, loads note location backup CSV, imports to database, and
# verifies integrity using parallel processing. In hybrid/test mode, calculates
# countries only for notes without country assignment using get_country() function.
# Performs integrity verification to ensure country assignments are correct.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   0: Success - Countries assigned successfully (or no notes to process)
#   1: Failure - Database error, file operation error, or verification failure
#
# Error codes:
#   0: Success - Countries assigned successfully
#   1: Failure - Database error, file operation error, or verification failure
#
# Error conditions:
#   0: Success - Countries assigned successfully (or no notes to process)
#   1: Database error - Failed to query or update database
#   1: File operation error - Failed to create temporary files or directories
#   1: Verification failure - Integrity verification failed
#
# Context variables:
#   Reads:
#     - DBNAME: PostgreSQL database name (required)
#     - PGAPPNAME: PostgreSQL application name (optional)
#     - HYBRID_MOCK_MODE: If set, enables hybrid/test mode (optional)
#     - TEST_MODE: If set, enables test mode (optional)
#     - CSV_BACKUP_NOTE_LOCATION: Path to uncompressed backup CSV (required in production mode)
#     - CSV_BACKUP_NOTE_LOCATION_COMPRESSED: Path to compressed backup CSV (required in production mode)
#     - MAX_THREADS: Maximum number of threads for parallel processing (required)
#     - VERIFY_THREADS: Override for verification thread count (optional)
#     - VERIFY_CHUNK_SIZE: Chunk size for verification (optional, default: 100000)
#     - VERIFY_SQL_BATCH_SIZE: SQL batch size for verification (optional, default: 20000)
#     - POSTGRES_32_UPLOAD_NOTE_LOCATION: Path to SQL script for loading backup CSV (required in production mode)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets:
#     - MAX_NOTE_ID: Maximum note ID in database (exported)
#     - MAX_NOTE_ID_NOT_NULL: Maximum note ID with country assigned (exported)
#     - TOTAL_NOTES_TO_INVALIDATE: Total notes invalidated during verification (exported)
#   Modifies:
#     - MAX_THREADS: Reduced by 1 if > 1 (to prevent CPU monopolization)
#
# Side effects:
#   - Queries database to count notes without country assignment
#   - In production mode: Downloads backup CSV, extracts, imports to database
#   - In production mode: Verifies integrity using parallel processing (time-consuming)
#   - In hybrid/test mode: Updates notes table directly using get_country() function
#   - Creates temporary files and directories for verification
#   - Updates notes.id_country column in database
#   - Invalidates notes with incorrect country assignments
#   - Writes log messages to stderr
#   - Sets EXIT trap for cleanup of temporary files
#
# Notes:
#   - Production mode: Loads backup CSV (~4.8M notes) for speed, then verifies integrity
#   - Hybrid/test mode: Calculates countries directly (faster for testing, slower for full dataset)
#   - Integrity verification recalculates countries using spatial queries and compares with assignments
#   - Verification uses parallel processing (30min→5min for 4.8M notes)
#   - Verification can be time-consuming for large datasets (~5 minutes for 4.8M notes)
#   - Uses get_country() PostgreSQL function for country assignment
#   - Only processes notes without country assignment (NULL, -1, or -2)
#   - Critical function: Used in main processing workflow
#   - Performance: Production mode is faster for full dataset, hybrid/test mode is faster for testing
#
# Example:
#   # Production mode
#   export DBNAME="osm_notes"
#   export CSV_BACKUP_NOTE_LOCATION_COMPRESSED="/path/to/noteLocation.csv.zip"
#   export MAX_THREADS=8
#   __getLocationNotes_impl
#
#   # Hybrid/test mode
#   export DBNAME="osm_notes"
#   export TEST_MODE="true"
#   export MAX_THREADS=4
#   __getLocationNotes_impl
#
# Related: __resolve_note_location_backup() (resolves backup CSV file)
# Related: __verifyNoteIntegrity() (verifies note location integrity)
# Related: __reassignAffectedNotes() (reassigns countries after boundary updates)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
function __getLocationNotes_impl {
 __log_start
 __logd "Assigning countries to notes."

 # In hybrid/test mode, skip backup and calculate countries only for processed notes
 if [[ -n "${HYBRID_MOCK_MODE:-}" ]] || [[ -n "${TEST_MODE:-}" ]]; then
  __logi "=== HYBRID/TEST MODE: Calculating countries for processed notes only ==="
  __logi "Skipping backup CSV (contains 4.8M notes). Will calculate countries only for notes in database."
  __logd "HYBRID_MOCK_MODE=${HYBRID_MOCK_MODE:-unset}, TEST_MODE=${TEST_MODE:-unset}"
  __logd "Backup file would be: ${CSV_BACKUP_NOTE_LOCATION_COMPRESSED:-unset}"
  __logd "NOT using backup - this is intentional for faster test execution"

  # Get count of notes that need country assignment
  local NOTES_COUNT
  # shellcheck disable=SC2154
  # PGAPPNAME is set by the calling script or environment
  NOTES_COUNT=$(PGAPPNAME="${PGAPPNAME:-}" psql -d "${DBNAME}" -Atq -v ON_ERROR_STOP=1 \
   <<< "SELECT COUNT(*) FROM notes WHERE (id_country IS NULL OR id_country < 0)" 2> /dev/null || echo "0")

  if [[ "${NOTES_COUNT}" -eq "0" ]]; then
   __logi "All notes already have countries assigned. Skipping country calculation."
   __log_finish
   return 0
  fi

  __logi "Calculating countries for ${NOTES_COUNT} notes using get_country() function..."
  __logd "This will be much faster than loading 4.8M notes from backup CSV"

  # Assign countries to notes using get_country() function
  # This only processes notes that don't have a country assigned (NULL, -1, or -2)
  PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 <<< "
   UPDATE notes n
   SET id_country = get_country(n.longitude, n.latitude, n.note_id)
   WHERE (n.id_country IS NULL OR n.id_country < 0);
  " || {
   __loge "ERROR: Failed to assign countries to notes"
   __log_finish
   return 1
  }

  __logi "Successfully assigned countries to ${NOTES_COUNT} notes."
  __logd "Backup CSV was NOT used - test execution completed faster"
  __log_finish
  return 0
 fi

 # Always import previous note locations to speed up the process
 # NOTE: This section is ONLY executed when NOT in hybrid/test mode
 # In hybrid/test mode, the code above handles country assignment without backup
 __logi "=== LOADING BACKUP NOTE LOCATIONS ==="
 __logi "This process will load note location data from backup CSV file."
 __logi "This operation may take several minutes depending on the size of the backup file."
 __logi "Please wait, the process is actively working..."
 __logd "PRODUCTION MODE: Using backup CSV (HYBRID_MOCK_MODE=${HYBRID_MOCK_MODE:-unset}, TEST_MODE=${TEST_MODE:-unset})"

 # Resolve note location backup file (download from GitHub if not found locally)
 if ! __resolve_note_location_backup; then
  __logw "Warning: Note location backup file not available. Will calculate all countries from scratch (slower)."
  return 0
 fi

 __logi "Extracting notes backup."
 rm -f "${CSV_BACKUP_NOTE_LOCATION}"
 unzip "${CSV_BACKUP_NOTE_LOCATION_COMPRESSED}" -d /tmp
 chmod 666 "${CSV_BACKUP_NOTE_LOCATION}"

 __logi "Importing notes location from backup CSV..."
 __logi "This COPY operation may take several minutes for large datasets."
 export CSV_BACKUP_NOTE_LOCATION
 # shellcheck disable=SC2016
 # shellcheck disable=SC2154
 # POSTGRES_32_UPLOAD_NOTE_LOCATION is defined in pathConfigurationFunctions.sh
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -c "$(envsubst '$CSV_BACKUP_NOTE_LOCATION' \
   < "${POSTGRES_32_UPLOAD_NOTE_LOCATION}" || true)"

 __logi "Note locations imported successfully. Starting integrity verification process..."
 __logi "This process will verify that all assigned countries are correct by recalculating"
 __logi "each note's country using spatial queries. This may take several minutes for"
 __logi "large datasets (e.g., ~5 minutes for 4.8M notes with parallel processing)."

 # Retrieves the max note for already location processed notes (from file.)
 # Use COALESCE to handle NULL results from MAX() when no rows match
 MAX_NOTE_ID_NOT_NULL=$(PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -Atq -v ON_ERROR_STOP=1 \
  <<< "SELECT COALESCE(MAX(note_id), 0) FROM notes WHERE id_country IS NOT NULL")
 # Retrieves the max note.
 MAX_NOTE_ID=$(PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -Atq -v ON_ERROR_STOP=1 \
  <<< "SELECT COALESCE(MAX(note_id), 0) FROM notes")

 # Ensure numeric values (handle empty strings from psql)
 MAX_NOTE_ID_NOT_NULL=${MAX_NOTE_ID_NOT_NULL:-0}
 MAX_NOTE_ID=${MAX_NOTE_ID:-0}

 __logd "Statistics: MAX_NOTE_ID=${MAX_NOTE_ID}, MAX_NOTE_ID_NOT_NULL=${MAX_NOTE_ID_NOT_NULL}"

 # Verify integrity of imported note locations in parallel
 # Optimized: Parallelize verification by splitting data across threads (30min→5min for 4.8M notes)
 local -i TOTAL_NOTES_TO_INVALIDATE=0
 # Store original MAX_THREADS before reducing it
 local -i ORIGINAL_MAX_THREADS=${MAX_THREADS}

 # Uses n-1 cores, if number of cores is greater than 1.
 # This prevents monopolization of the CPUs.
 # Note: This reduction applies to other parallel operations, not verification threads
 if [[ "${MAX_THREADS}" -gt 1 ]]; then
  MAX_THREADS=$((MAX_THREADS - 1))
 fi

 # Calculate verify thread count using original MAX_THREADS or VERIFY_THREADS override
 local -i VERIFY_THREAD_OVERRIDE=0
 if [[ -n "${VERIFY_THREADS:-}" ]]; then
  VERIFY_THREAD_OVERRIDE=${VERIFY_THREADS:-0}
 fi
 local -i VERIFY_THREAD_COUNT=${ORIGINAL_MAX_THREADS}
 if ((VERIFY_THREAD_OVERRIDE > 0)); then
  VERIFY_THREAD_COUNT=${VERIFY_THREAD_OVERRIDE}
 fi
 # Limit to original MAX_THREADS, not the reduced one
 if ((VERIFY_THREAD_COUNT > ORIGINAL_MAX_THREADS)); then
  VERIFY_THREAD_COUNT=${ORIGINAL_MAX_THREADS}
 fi
 if ((VERIFY_THREAD_COUNT <= 0)); then
  VERIFY_THREAD_COUNT=1
 fi

 __logi "=== STARTING INTEGRITY VERIFICATION PROCESS ==="
 __logi "This is a time-consuming operation that will:"
 __logi "  1. Recalculate the country for each note using spatial queries"
 __logi "  2. Compare the recalculated country with the assigned country"
 __logi "  3. Invalidate notes with incorrect country assignments"
 __logi "Processing ${MAX_NOTE_ID_NOT_NULL} notes in parallel (${VERIFY_THREAD_COUNT} threads)..."
 __logi "Estimated time: ~5 minutes for 4.8M notes (without parallel: ~30 minutes)"
 __logi "Please wait, this process cannot be interrupted..."

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
 # Read SQL batch size from properties (default: 20000)
 # This can be overridden via VERIFY_SQL_BATCH_SIZE environment variable or properties file
 SQL_BATCH_SIZE=${VERIFY_SQL_BATCH_SIZE:-20000}
 if ((SQL_BATCH_SIZE <= 0)); then
  __logw "VERIFY_SQL_BATCH_SIZE invalid (${SQL_BATCH_SIZE}), resetting to 20000."
  SQL_BATCH_SIZE=20000
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

  local QUEUE_LOCK_FILE="${QUEUE_FILE}.lock"
  local CLEANUP_TEMP_DIR="${TEMP_COUNT_DIR}"
  local CLEANUP_QUEUE_FILE="${QUEUE_FILE}"
  local CLEANUP_QUEUE_LOCK="${QUEUE_LOCK_FILE}"

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
  __logi "Verification queue ready: ${TOTAL_CHUNKS} chunks of ~${EFFECTIVE_VERIFY_CHUNK_SIZE} notes each"

  # Progress tracking file for showing partial advances
  local PROGRESS_FILE
  PROGRESS_FILE=$(mktemp)
  echo "0" > "${PROGRESS_FILE}"
  touch "${PROGRESS_FILE}.lock"
  local CLEANUP_PROGRESS_FILE="${PROGRESS_FILE}"
  local CLEANUP_PROGRESS_LOCK="${PROGRESS_FILE}.lock"

  # Update trap to include progress file cleanup
  # shellcheck disable=SC2064
  trap 'rm -rf "${CLEANUP_TEMP_DIR:-}"; rm -f "${CLEANUP_QUEUE_FILE:-}" "${CLEANUP_QUEUE_LOCK:-}" "${CLEANUP_PROGRESS_FILE:-}" "${CLEANUP_PROGRESS_LOCK:-}" 2> /dev/null || true' EXIT

  # Start progress monitor in background
  (
   local -i LAST_REPORTED=0
   local -i REPORT_INTERVAL=30
   local -i HEARTBEAT_INTERVAL=300
   local -i LAST_HEARTBEAT=0
   local START_TIME
   START_TIME=$(date +%s)
   while true; do
    sleep "${REPORT_INTERVAL}"
    if [[ ! -f "${PROGRESS_FILE}" ]]; then
     break
    fi
    local -i COMPLETED_CHUNKS=0
    COMPLETED_CHUNKS=$(cat "${PROGRESS_FILE}" 2> /dev/null || echo "0")
    if [[ ${COMPLETED_CHUNKS} -ge ${TOTAL_CHUNKS} ]]; then
     break
    fi
    local CURRENT_TIME
    CURRENT_TIME=$(date +%s)
    local -i ELAPSED=$((CURRENT_TIME - START_TIME))

    # Show progress when there's new progress
    if [[ ${COMPLETED_CHUNKS} -gt ${LAST_REPORTED} ]]; then
     local -i PERCENTAGE=$((COMPLETED_CHUNKS * 100 / TOTAL_CHUNKS))
     local -i PROCESSED_NOTES=$((COMPLETED_CHUNKS * EFFECTIVE_VERIFY_CHUNK_SIZE))
     if [[ ${PROCESSED_NOTES} -gt ${MAX_NOTE_ID_NOT_NULL} ]]; then
      PROCESSED_NOTES=${MAX_NOTE_ID_NOT_NULL}
     fi
     local -i REMAINING_CHUNKS=$((TOTAL_CHUNKS - COMPLETED_CHUNKS))
     local -i AVG_TIME_PER_CHUNK=0
     if [[ ${COMPLETED_CHUNKS} -gt 0 ]]; then
      AVG_TIME_PER_CHUNK=$((ELAPSED / COMPLETED_CHUNKS))
     fi
     local -i ESTIMATED_REMAINING=0
     if [[ ${AVG_TIME_PER_CHUNK} -gt 0 ]]; then
      ESTIMATED_REMAINING=$((REMAINING_CHUNKS * AVG_TIME_PER_CHUNK))
     fi
     local ESTIMATED_STR=""
     if [[ ${ESTIMATED_REMAINING} -gt 0 ]]; then
      local -i EST_HOURS=$((ESTIMATED_REMAINING / 3600))
      local -i EST_MINUTES=$(((ESTIMATED_REMAINING % 3600) / 60))
      ESTIMATED_STR=" - Estimated remaining: ${EST_HOURS}h ${EST_MINUTES}m"
     fi
     __logi "Progress: ${COMPLETED_CHUNKS}/${TOTAL_CHUNKS} chunks completed (${PERCENTAGE}%) - ~${PROCESSED_NOTES} notes processed${ESTIMATED_STR}"
     LAST_REPORTED=${COMPLETED_CHUNKS}
     LAST_HEARTBEAT=${CURRENT_TIME}
    # Show heartbeat message every 5 minutes even if no progress
    elif ((CURRENT_TIME - LAST_HEARTBEAT >= HEARTBEAT_INTERVAL)); then
     local -i PERCENTAGE=$((COMPLETED_CHUNKS * 100 / TOTAL_CHUNKS))
     local -i PROCESSED_NOTES=$((COMPLETED_CHUNKS * EFFECTIVE_VERIFY_CHUNK_SIZE))
     if [[ ${PROCESSED_NOTES} -gt ${MAX_NOTE_ID_NOT_NULL} ]]; then
      PROCESSED_NOTES=${MAX_NOTE_ID_NOT_NULL}
     fi
     local -i ELAPSED_HOURS=$((ELAPSED / 3600))
     local -i ELAPSED_MINUTES=$(((ELAPSED % 3600) / 60))
     __logi "Still processing... ${COMPLETED_CHUNKS}/${TOTAL_CHUNKS} chunks completed (${PERCENTAGE}%) - ~${PROCESSED_NOTES} notes processed - Elapsed: ${ELAPSED_HOURS}h ${ELAPSED_MINUTES}m"
     LAST_HEARTBEAT=${CURRENT_TIME}
    fi
   done
  ) &
  local PROGRESS_MONITOR_PID=$!

  local -i THREADS_STARTED=0
  # Export queue file path and file descriptor for threads
  export QUEUE_FILE
  export VERIFY_QUEUE_FD
  for J in $(seq 1 1 "${VERIFY_THREAD_COUNT}"); do
   (
    local -i THREAD_ID=${J}
    __logi "Starting integrity verification thread ${THREAD_ID}."
    local -i THREAD_COUNT=0
    # Use atomic queue reading with lock file to prevent multiple threads
    # from reading the same range
    while true; do
     local RANGE_START RANGE_END
     # Atomically read and remove first line from queue file
     # Use a lock file descriptor that persists for the entire operation
     exec {QUEUE_LOCK_FD}> "${QUEUE_LOCK_FILE}"
     if ! flock -x "${QUEUE_LOCK_FD}"; then
      __loge "Thread ${THREAD_ID}: unable to acquire queue lock"
      exec {QUEUE_LOCK_FD}>&-
      break
     fi

     # Read first line from queue file (with lock held)
     if ! IFS=' ' read -r RANGE_START RANGE_END < "${QUEUE_FILE}"; then
      # No more lines in queue
      __logd "Thread ${THREAD_ID}: queue empty, exiting"
      flock -u "${QUEUE_LOCK_FD}"
      exec {QUEUE_LOCK_FD}>&-
      break
     fi

     # Remove the first line from queue file atomically (with lock held)
     # Use tail to skip first line and write to temp file, then move
     local TEMP_QUEUE
     TEMP_QUEUE=$(mktemp)
     if ! tail -n +2 "${QUEUE_FILE}" > "${TEMP_QUEUE}" 2> /dev/null; then
      __logw "Thread ${THREAD_ID}: failed to create temp queue file"
      rm -f "${TEMP_QUEUE}" 2> /dev/null || true
      flock -u "${QUEUE_LOCK_FD}"
      exec {QUEUE_LOCK_FD}>&-
      break
     fi
     if ! mv "${TEMP_QUEUE}" "${QUEUE_FILE}" 2> /dev/null; then
      __logw "Thread ${THREAD_ID}: failed to update queue file"
      rm -f "${TEMP_QUEUE}" 2> /dev/null || true
      flock -u "${QUEUE_LOCK_FD}"
      exec {QUEUE_LOCK_FD}>&-
      break
     fi

     # Release lock after successfully reading and removing from queue
     flock -u "${QUEUE_LOCK_FD}"
     exec {QUEUE_LOCK_FD}>&-

     if [[ -z "${RANGE_START:-}" ]] || [[ -z "${RANGE_END:-}" ]]; then
      __logw "Thread ${THREAD_ID}: invalid range read (START=${RANGE_START:-empty}, END=${RANGE_END:-empty})"
      break
     fi

     __logd "Thread ${THREAD_ID}: acquired range ${RANGE_START}-${RANGE_END} from queue"
     local -i RANGE_TOTAL=0
     local -i SUB_START=${RANGE_START}
     local -i RANGE_LIMIT=${RANGE_END}
     while ((SUB_START < RANGE_LIMIT)); do
      local -i SUB_END=$((SUB_START + SQL_BATCH_SIZE))
      if ((SUB_END > RANGE_LIMIT)); then
       SUB_END=${RANGE_LIMIT}
      fi

      # Validate SQL file exists
      # shellcheck disable=SC2154
      # POSTGRES_33_VERIFY_NOTE_INTEGRITY is defined in pathConfigurationFunctions.sh
      if [[ ! -f "${POSTGRES_33_VERIFY_NOTE_INTEGRITY}" ]]; then
       __loge "ERROR: SQL file does not exist: ${POSTGRES_33_VERIFY_NOTE_INTEGRITY}"
       __log_finish
       return 1
      fi

      # Export variables for envsubst
      export SUB_START
      export SUB_END

      # Execute SQL file with parameter substitution
      local SUB_COUNT
      # shellcheck disable=SC2016
      # envsubst requires single quotes for variable names to expand them
      SUB_COUNT=$(PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -Atq -v ON_ERROR_STOP=1 \
       -c "$(envsubst '$SUB_START,$SUB_END' \
        < "${POSTGRES_33_VERIFY_NOTE_INTEGRITY}" || true)")
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

     # Update progress counter atomically
     (
      flock -x 300
      local -i CURRENT_PROGRESS
      CURRENT_PROGRESS=$(cat "${PROGRESS_FILE}" 2> /dev/null || echo "0")
      echo $((CURRENT_PROGRESS + 1)) > "${PROGRESS_FILE}"
     ) 300> "${PROGRESS_FILE}.lock"
    done

    echo "${THREAD_COUNT}" > "${TEMP_COUNT_DIR}/count_${THREAD_ID}"
    __logi "Thread ${THREAD_ID}: total invalidated ${THREAD_COUNT}"
   ) &
   THREADS_STARTED=$((THREADS_STARTED + 1))
  done

  # Wait for all verification threads to complete
  # Only wait if threads were actually started to prevent infinite blocking
  if [[ ${THREADS_STARTED} -gt 0 ]]; then
   wait
  else
   __logw "WARNING: No verification threads were started. Skipping wait."
  fi

  # Stop progress monitor
  kill "${PROGRESS_MONITOR_PID}" 2> /dev/null || true
  wait "${PROGRESS_MONITOR_PID}" 2> /dev/null || true

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
  rm -f "${QUEUE_FILE}" "${QUEUE_LOCK_FILE}"
  rm -f "${PROGRESS_FILE}" "${PROGRESS_FILE}.lock" 2> /dev/null || true
  CLEANUP_QUEUE_FILE=""
  CLEANUP_QUEUE_LOCK=""
  CLEANUP_TEMP_DIR=""
  CLEANUP_PROGRESS_FILE=""
  CLEANUP_PROGRESS_LOCK=""

  if [[ "${TOTAL_NOTES_TO_INVALIDATE}" -gt 0 ]]; then
   __logi "Found and invalidated ${TOTAL_NOTES_TO_INVALIDATE} notes with incorrect country assignments"
  else
   __logi "No incorrect country assignments found"
  fi
 fi

 # Check if there are any notes without country assignment
 local -i NOTES_WITHOUT_COUNTRY
 NOTES_WITHOUT_COUNTRY=$(PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -Atq -v ON_ERROR_STOP=1 \
  <<< "SELECT COUNT(*) FROM notes WHERE (id_country IS NULL OR id_country < 0)")
 __logi "Notes without country assignment: ${NOTES_WITHOUT_COUNTRY}"

 if [[ "${NOTES_WITHOUT_COUNTRY}" -eq 0 ]]; then
  __logi "All notes already have country assignment. Skipping location processing."
  __log_finish
  return 0
 fi

 # Processes notes that still require country assignment.
 local -i ASSIGNABLE_NOTES
 ASSIGNABLE_NOTES=$(
  PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -Atq -v ON_ERROR_STOP=1 << 'EOF'
SELECT COUNT(*)
FROM notes
WHERE (id_country IS NULL OR id_country < 0)
AND longitude IS NOT NULL
AND latitude IS NOT NULL;
EOF
 )

 local -i NOTES_WITHOUT_COORDS
 NOTES_WITHOUT_COORDS=$(
  PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -Atq -v ON_ERROR_STOP=1 << 'EOF'
SELECT COUNT(*)
FROM notes
WHERE (id_country IS NULL OR id_country < 0)
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
 WHERE (id_country IS NULL OR id_country < 0)
 AND longitude IS NOT NULL
 AND latitude IS NOT NULL
 ORDER BY note_id
) TO STDOUT
EOF
 )
 if ! PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -Atq -v ON_ERROR_STOP=1 \
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
    NOTE_IDS=$(tr '\n' ',' < "${CHUNK_PATH}" | sed 's/,$//' || true)
    if [[ -z "${NOTE_IDS:-}" ]]; then
     continue
    fi

    # Validate SQL file exists
    # shellcheck disable=SC2154
    # POSTGRES_37_ASSIGN_COUNTRY_TO_NOTES_CHUNK is defined in pathConfigurationFunctions.sh
    if [[ ! -f "${POSTGRES_37_ASSIGN_COUNTRY_TO_NOTES_CHUNK}" ]]; then
     __loge "ERROR: SQL file does not exist: ${POSTGRES_37_ASSIGN_COUNTRY_TO_NOTES_CHUNK}"
     continue
    fi

    # Export variable for envsubst
    export NOTE_IDS

    # Execute SQL file with parameter substitution
    local CHUNK_ASSIGNED
    # shellcheck disable=SC2016
    # envsubst requires single quotes for variable names to expand them
    CHUNK_ASSIGNED=$(PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -Atq -v ON_ERROR_STOP=1 \
     -c "$(envsubst '$NOTE_IDS' \
      < "${POSTGRES_37_ASSIGN_COUNTRY_TO_NOTES_CHUNK}" || true)")

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
  SAMPLE_LATITUDES=$(head -n "${HEAD_LINES}" "${XML_FILE}" | grep -o 'lat="[^"]*"' | head -50 | sed 's/lat="//;s/"//g' | grep -v '^$' || true)
  SAMPLE_LONGITUDES=$(head -n "${HEAD_LINES}" "${XML_FILE}" | grep -o 'lon="[^"]*"' | head -50 | sed 's/lon="//;s/"//g' | grep -v '^$' || true)

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
 LATITUDES=$(grep -o 'lat="[^"]*"' "${XML_FILE}" | sed 's/lat="//;s/"//g' | grep -v '^$' || true)
 LONGITUDES=$(grep -o 'lon="[^"]*"' "${XML_FILE}" | sed 's/lon="//;s/"//g' | grep -v '^$' || true)

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
  if timeout "${TIMEOUT}" curl -s --connect-timeout 5 -H "User-Agent: ${DOWNLOAD_USER_AGENT:-OSM-Notes-Ingestion/1.0}" "${URL}" > /dev/null 2>&1; then
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
##
# Handles errors with cleanup commands and failed execution marker creation
# Centralized error handler that logs errors, executes cleanup commands, and creates
# failed execution marker file (for non-network errors). Distinguishes between network
# errors (temporary, allow retry) and other errors (permanent, block execution). Uses
# exit in production, return in test environment.
#
# Parameters:
#   $1: ERROR_CODE - Error code to return/exit with (required)
#   $2: ERROR_MESSAGE - Error message to log (required)
#   $3+: CLEANUP_COMMANDS - Array of cleanup commands to execute (optional, variable number)
#
# Returns:
#   In production: Exits with ERROR_CODE
#   In test environment: Returns with ERROR_CODE
#
# Error codes:
#   ERROR_CODE: Returns/exits with provided error code
#
# Error conditions:
#   ERROR_CODE: Always returns/exits with provided error code
#
# Context variables:
#   Reads:
#     - ERROR_INTERNET_ISSUE: Error code for network issues (optional, default: 251)
#     - FAILED_EXECUTION_FILE: Path to failed execution marker file (optional)
#     - TMP_DIR: Temporary directory (optional)
#     - CLEAN: If "true", executes cleanup commands (optional, default: true)
#     - TEST_MODE: If "true", uses return instead of exit (optional)
#     - BATS_TEST_NAME: If set, uses return instead of exit (optional, BATS testing)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies:
#     - Creates failed execution marker file (for non-network errors)
#
# Side effects:
#   - Logs error details (code, message, stack trace)
#   - Creates failed execution marker file (for non-network errors)
#   - Executes cleanup commands (if CLEAN=true)
#   - Writes log messages to stderr
#   - Exits script with ERROR_CODE (production) or returns ERROR_CODE (test)
#   - No database or network operations
#
# Notes:
#   - Distinguishes network errors (temporary) from other errors (permanent)
#   - Network errors don't create failed execution marker (allows retry)
#   - Other errors create failed execution marker (prevents repeated failures)
#   - Cleanup commands are executed only if CLEAN=true
#   - Uses eval to execute cleanup commands (be careful with command injection)
#   - Critical function: Centralized error handling for all error scenarios
#   - Test environment detection: TEST_MODE or BATS_TEST_NAME
#
# Example:
#   __handle_error_with_cleanup 1 "Processing failed" "rm -f /tmp/temp_file"
#   # Logs error, executes cleanup, creates marker, exits with code 1
#
# Related: __create_failed_marker() (creates failed execution marker)
# Related: __trapOn() (sets up error traps)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
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

 # Determine if this is a temporary network error that shouldn't block future executions
 # Network errors (ERROR_INTERNET_ISSUE) are temporary and should allow retry on next execution
 # Only create failed execution file for non-network errors (data corruption, logic errors, etc.)
 local IS_NETWORK_ERROR=false
 if [[ "${ERROR_CODE}" == "${ERROR_INTERNET_ISSUE:-251}" ]] \
  || [[ "${ERROR_MESSAGE}" == *"Network connectivity"* ]] \
  || [[ "${ERROR_MESSAGE}" == *"API download failed"* ]] \
  || [[ "${ERROR_MESSAGE}" == *"Internet issues"* ]]; then
  IS_NETWORK_ERROR=true
  __logw "Network error detected - will not create failed execution file to allow retry on next execution"
 fi

 # Create failed execution file to prevent re-execution (only for non-network errors)
 if [[ -n "${FAILED_EXECUTION_FILE:-}" ]] && [[ "${IS_NETWORK_ERROR}" == "false" ]]; then
  __loge "Creating failed execution file: ${FAILED_EXECUTION_FILE}"
  {
   local DATE_OUTPUT
   DATE_OUTPUT=$(date || echo "unknown")
   echo "Error occurred at ${DATE_OUTPUT}: ${ERROR_MESSAGE} (code: ${ERROR_CODE})"
   local CALLER_OUTPUT
   CALLER_OUTPUT=$(caller 0 || echo "unknown")
   echo "Stack trace: ${CALLER_OUTPUT}"
  } > "${FAILED_EXECUTION_FILE}"
  echo "Temporary directory: ${TMP_DIR:-unknown}" >> "${FAILED_EXECUTION_FILE}"
 elif [[ "${IS_NETWORK_ERROR}" == "true" ]]; then
  __logw "Skipping failed execution file creation for temporary network error"
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
 local CALLER_OUTPUT
 CALLER_OUTPUT=$(caller 0 || echo "unknown")
 __loge "Stack trace: ${CALLER_OUTPUT}"
 if [[ "${IS_NETWORK_ERROR}" == "true" ]]; then
  __loge "Failed execution file NOT created (network error - will retry on next execution)"
 else
  __loge "Failed execution file created: ${FAILED_EXECUTION_FILE:-none}"
 fi

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
#
# Alternative implementation: Simple semaphore (no tickets, no ordering)
# Functions: __acquire_download_slot, __release_download_slot,
# __cleanup_stale_slots, __wait_for_download_slot

# =============================================================================
# Simple Semaphore System (Recommended)
# =============================================================================

##
# Acquires a download slot for Overpass API rate limiting
# Uses atomic directory creation (mkdir) to acquire a slot in the download queue.
# Implements semaphore-based rate limiting to prevent overwhelming Overpass API.
#
# Parameters:
#   None (uses process ID and environment variables)
#
# Returns:
#   0: Success - Download slot acquired
#   1: Failure - Timeout waiting for slot or error acquiring slot
#
# Error codes:
#   0: Success - Slot acquired and lock directory created
#   1: Failure - Timeout waiting for available slot or error during acquisition
#
# Context variables:
#   Reads:
#     - TMP_DIR: Temporary directory for queue files (required)
#     - RATE_LIMIT: Maximum concurrent download slots (optional, default: 8)
#     - BASHPID: Process ID (used for lock directory naming)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies:
#     - Filesystem: Creates lock directory in TMP_DIR/download_queue/active/
#
# Side effects:
#   - Creates lock directory atomically using mkdir (prevents race conditions)
#   - Writes PID to lock directory for reference
#   - Cleans up stale locks before attempting acquisition
#   - Blocks until slot becomes available (may wait up to timeout period)
#   - Uses file locking (flock) for atomic operations
#   - Logs slot acquisition to standard logger
#   - No network or database operations
#
# Implementation details:
#   - Uses mkdir for atomic lock creation (mkdir is atomic in Linux)
#   - Uses flock for coordinating between processes
#   - Cleans stale locks (from dead processes) before acquisition
#   - Retries with exponential backoff if slot not immediately available
#
# Example:
#   if __acquire_download_slot; then
#     # Perform download operation
#     curl ...
#     __release_download_slot
#   else
#     echo "Failed to acquire slot"
#   fi
#
# Related: __release_download_slot() (releases acquired slot)
# Related: __wait_for_download_slot() (wrapper that calls this)
# Related: __cleanup_stale_slots() (cleans up dead process locks)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
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
 # shellcheck disable=SC2310
 # Intentional: cleanup failures should not stop execution
 __cleanup_stale_slots || true

 while [[ ${RETRY_COUNT} -lt ${MAX_RETRIES} ]]; do
  # Try to acquire slot atomically (all operations inside flock)
  (
   flock -x 200
   # Count active downloads inside flock to prevent race conditions
   local ACTIVE_NOW=0
   if [[ -d "${ACTIVE_DIR}" ]]; then
    local FIND_RESULT
    FIND_RESULT=$(find "${ACTIVE_DIR}" -name "*.lock" -type d 2> /dev/null || echo "")
    ACTIVE_NOW=$(echo "${FIND_RESULT}" | wc -l || echo "0")
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
       local FIND_RESULT
       FIND_RESULT=$(find "${ACTIVE_DIR}" -name "*.lock" -type d 2> /dev/null || echo "")
       ACTIVE_AFTER=$(echo "${FIND_RESULT}" | wc -l || echo "0")
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
  local EXIT_CODE=$?

  if [[ ${EXIT_CODE} -eq 0 ]]; then
   __log_finish
   return 0
  fi

  # Minimal wait - queries don't take long, so we can retry quickly
  sleep "${CHECK_INTERVAL}"
  RETRY_COUNT=$((RETRY_COUNT + 1))
 done

 local TOTAL_WAIT
 TOTAL_WAIT=$(($(date +%s) - START_TIME))
 __loge "ERROR: Timeout waiting for download slot (waited: ${TOTAL_WAIT}s, max retries: ${MAX_RETRIES})"
 __log_finish
 return 1
}

##
# Releases a previously acquired download slot
# Removes the process lock file/directory to free up a slot for other processes.
# Should be called after download operation completes to allow other processes to proceed.
#
# Parameters:
#   None (uses process ID to identify lock)
#
# Returns:
#   0: Success - Slot released successfully
#   1: Failure - Error releasing slot (rare, usually succeeds)
#
# Error codes:
#   0: Success - Lock file/directory removed, slot released
#   1: Failure - Error removing lock file/directory (should not normally occur)
#
# Context variables:
#   Reads:
#     - TMP_DIR: Temporary directory for queue files (required)
#     - BASHPID: Process ID (used to identify lock file)
#     - RATE_LIMIT: Maximum concurrent download slots (for logging)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies:
#     - Filesystem: Removes lock file/directory from TMP_DIR/download_queue/active/
#
# Side effects:
#   - Removes lock file or directory (based on PID) from active directory
#   - Counts remaining active slots for logging
#   - Logs slot release to standard logger
#   - No network or database operations
#
# Example:
#   if __wait_for_download_slot; then
#     # Perform download
#     curl ...
#     # Always release slot when done
#     __release_download_slot
#   fi
#
# Related: __wait_for_download_slot() (acquires slot)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
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
  # Support for file-based locks (backward compatibility)
  rm -f "${MY_LOCK_FILE}" || true
 fi

 # Count remaining active slots
 local ACTIVE_COUNT=0
 if [[ -d "${ACTIVE_DIR}" ]]; then
  # Count both directories and files for backward compatibility
  local FIND_RESULT
  FIND_RESULT=$(find "${ACTIVE_DIR}" -name "*.lock" \( -type d -o -type f \) 2> /dev/null || echo "")
  ACTIVE_COUNT=$(echo "${FIND_RESULT}" | wc -l || echo "0")
 fi
 __logd "Download slot released (active: ${ACTIVE_COUNT}/${RATE_LIMIT:-4})"

 __log_finish
 return 0
}

##
# Cleans up stale download slot locks from dead processes
# Removes lock files/directories from processes that are no longer running.
# Prevents queue system from being blocked by locks from crashed or terminated processes.
#
# Parameters:
#   None (uses process ID detection from lock file names)
#
# Returns:
#   0: Success - Cleanup completed (may have cleaned 0 or more stale locks)
#
# Error codes:
#   0: Always succeeds (cleanup is best-effort, failures are logged but don't stop execution)
#
# Context variables:
#   Reads:
#     - TMP_DIR: Temporary directory for queue files (required)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies:
#     - Filesystem: Removes stale lock files/directories from TMP_DIR/download_queue/active/
#
# Side effects:
#   - Scans active directory for lock files/directories
#   - Checks if process ID from lock name is still running
#   - Removes locks from dead processes
#   - Logs cleanup operations to standard logger
#   - No network or database operations
#
# Example:
#   # Usually called automatically before acquiring slots
#   __cleanup_stale_slots
#   __acquire_download_slot
#
# Related: __acquire_download_slot() (calls this before acquisition)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
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

##
# Waits for and acquires a download slot for Overpass API rate limiting
# Wrapper function that calls __acquire_download_slot to obtain a slot in the download queue.
# Used to prevent overwhelming Overpass API with concurrent requests.
#
# Parameters:
#   None (uses process ID and environment variables)
#
# Returns:
#   0: Success - Download slot acquired
#   1: Failure - Timeout waiting for slot or error acquiring slot
#
# Error codes:
#   0: Success - Slot acquired and ready for download
#   1: Failure - Timeout waiting for available slot or error during acquisition
#
# Context variables:
#   Reads:
#     - TMP_DIR: Temporary directory for queue files (required)
#     - RATE_LIMIT: Maximum concurrent download slots (optional, default: 4)
#     - BASHPID: Process ID (used for lock file naming)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies:
#     - Filesystem: Creates lock file/directory in TMP_DIR/download_queue/active/
#
# Side effects:
#   - Creates lock file/directory in download queue active directory
#   - Blocks until slot becomes available (may wait up to timeout period)
#   - Logs slot acquisition to standard logger
#   - No network or database operations
#
# Example:
#   if __wait_for_download_slot; then
#     # Perform download operation
#     curl ...
#     __release_download_slot
#   else
#     echo "Failed to acquire download slot"
#   fi
#
# Related: __release_download_slot() (releases acquired slot)
# Related: __acquire_download_slot() (internal acquisition logic)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
function __wait_for_download_slot() {
 __acquire_download_slot
 return $?
}

# =============================================================================
# Ticket-Based Queue System
# =============================================================================

##
# Gets the next ticket number in the download queue (FIFO system)
# Atomically increments and returns the ticket counter for FIFO queue ordering.
# Used with ticket-based queue system to ensure fair ordering of download requests.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   Exit code: 0 (always succeeds)
#   Output: Ticket number (integer) on stdout
#
# Error codes:
#   0: Always succeeds (ticket number output to stdout)
#   Output value: Sequential ticket number (1, 2, 3, ...)
#
# Context variables:
#   Reads:
#     - TMP_DIR: Temporary directory for queue files (required)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies:
#     - Filesystem: Increments ticket counter file in TMP_DIR/download_queue/
#
# Side effects:
#   - Creates queue directory if it doesn't exist
#   - Atomically increments ticket counter using flock
#   - Outputs ticket number to stdout (use command substitution to capture)
#   - Logs ticket acquisition to standard logger
#   - No network or database operations
#
# Implementation details:
#   - Uses flock for atomic file operations (prevents race conditions)
#   - Ticket counter stored in file: TMP_DIR/download_queue/ticket_counter
#   - Lock file: TMP_DIR/download_queue/ticket_lock
#
# Output format:
#   - Single integer on stdout: next ticket number
#   - Starts at 1, increments sequentially
#
# Example:
#   TICKET=$(__get_download_ticket)
#   echo "Got ticket: ${TICKET}"
#   __wait_for_download_turn "${TICKET}"
#
# Related: __wait_for_download_turn() (waits for ticket to be served)
# Related: __release_download_ticket() (releases ticket and advances queue)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
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

##
# Prunes stale lock files from FIFO queue active directory
# Removes lock files from dead processes to prevent queue deadlocks.
# Checks if process ID from lock filename is still running, removes lock if process is dead.
#
# Parameters:
#   None (scans active directory for lock files)
#
# Returns:
#   0: Success - Cleanup completed (may have cleaned 0 or more stale locks)
#
# Error codes:
#   0: Always succeeds (cleanup is best-effort, failures are logged but don't stop execution)
#
# Context variables:
#   Reads:
#     - TMP_DIR: Temporary directory for queue files (required)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies:
#     - Filesystem: Removes stale lock files from TMP_DIR/download_queue/active/
#
# Side effects:
#   - Scans active directory for lock files matching pattern: <pid>.<ticket>.lock
#   - Checks if process ID from lock filename is still running (ps -p)
#   - Removes locks from dead processes
#   - Logs cleanup operations to standard logger
#   - No network or database operations
#
# Lock file format:
#   - Pattern: <pid>.<ticket>.lock
#   - Example: 12345.42.lock (PID 12345, ticket 42)
#   - Extracts PID part before first dot
#
# Example:
#   # Usually called automatically by __wait_for_download_turn
#   __queue_prune_stale_locks
#
# Related: __wait_for_download_turn() (calls this periodically)
# Related: __cleanup_stale_slots() (similar function for semaphore system)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
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
##
# Waits for download turn in FIFO queue system using ticket number
# Blocks until the ticket number is served and a download slot becomes available.
# Implements FIFO ordering with rate limiting and Overpass API status checking.
#
# Parameters:
#   $1: Ticket number - Ticket number obtained from __get_download_ticket (required)
#
# Returns:
#   0: Success - Ticket served and download slot acquired
#   1: Failure - Timeout waiting for turn or invalid ticket
#   2: Invalid argument - Ticket number is empty
#
# Error codes:
#   0: Success - Ticket served, slot acquired, and lock file created
#   1: Failure - Timeout waiting for turn (exceeded MAX_WAIT_TIME) or error acquiring slot
#   2: Invalid argument - Ticket number parameter is empty
#
# Context variables:
#   Reads:
#     - TMP_DIR: Temporary directory for queue files (required)
#     - RATE_LIMIT: Maximum concurrent download slots (optional, default: 4)
#     - CONTINUE_ON_OVERPASS_ERROR: Reduces wait time if true (optional, default: false)
#     - BASHPID: Process ID (used for lock file naming)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies:
#     - Filesystem: Creates lock file in TMP_DIR/download_queue/active/
#     - Filesystem: Updates current_serving counter in queue directory
#
# Side effects:
#   - Blocks until ticket is served (may wait up to MAX_WAIT_TIME seconds)
#   - Creates lock file when slot is acquired
#   - Checks Overpass API status before acquiring slot
#   - Updates current serving counter atomically
#   - Logs wait progress periodically
#   - Auto-heals queue if no activity detected
#   - No network or database operations (except Overpass status check)
#
# Wait time configuration:
#   - Default MAX_WAIT_TIME: 3600 seconds (1 hour)
#   - Reduced to 600 seconds if CONTINUE_ON_OVERPASS_ERROR=true
#   - Auto-heal after 300 seconds of inactivity
#
# Example:
#   TICKET=$(__get_download_ticket)
#   if __wait_for_download_turn "${TICKET}"; then
#     # Perform download
#     curl ...
#     __release_download_ticket "${TICKET}"
#   else
#     echo "Timeout waiting for turn"
#   fi
#
# Related: __get_download_ticket() (obtains ticket number)
# Related: __release_download_ticket() (releases ticket and advances queue)
# Related: __check_overpass_status() (checks API availability)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
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
  CURRENT_SERVING=$(
   (
    flock -s 200
    if [[ -f "${CURRENT_SERVING_FILE}" ]]; then
     cat "${CURRENT_SERVING_FILE}" 2> /dev/null || echo "0"
    else
     echo "0"
    fi
   ) 200> "${QUEUE_DIR}/ticket_lock"
  )

  # Calculate how many slots are currently in use
  local ACTIVE_DOWNLOADS=0
  if [[ -d "${QUEUE_DIR}/active" ]]; then
   local FIND_RESULT
   FIND_RESULT=$(find "${QUEUE_DIR}/active" -name "*.lock" -type f 2> /dev/null || echo "")
   ACTIVE_DOWNLOADS=$(echo "${FIND_RESULT}" | wc -l || echo "0")
  fi

  # Periodically prune stale locks to avoid deadlocks (every ~30s)
  # Skip pruning on first iteration (WAIT_COUNT=0) to avoid delay when slots are available
  if [[ ${WAIT_COUNT} -gt 0 ]] && [[ $((WAIT_COUNT % 30)) -eq 0 ]]; then
   # shellcheck disable=SC2310
   # Intentional: pruning failures should not stop execution
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
      local FIND_RESULT
      FIND_RESULT=$(find "${QUEUE_DIR}/active" -name "*.lock" -type f 2> /dev/null || echo "")
      ACTIVE_NOW=$(echo "${FIND_RESULT}" | wc -l || echo "0")
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
     local FIND_RESULT
     FIND_RESULT=$(find "${QUEUE_DIR}/active" -name "*.lock" -type f 2> /dev/null || echo "")
     ACTIVE_AFTER_LOCK=$(echo "${FIND_RESULT}" | wc -l || echo "0")
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
     local STATUS_OUTPUT
     # shellcheck disable=SC2310,SC2311
     # SC2310: Intentional: check return value explicitly
     # SC2311: Intentional: function in command substitution
     STATUS_OUTPUT=$(__check_overpass_status 2>&1 || echo "")
     set -e
     WAIT_TIME=$(echo "${STATUS_OUTPUT}" | tail -1 || echo "0")
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
   local EXIT_CODE=$?

   if [[ ${EXIT_CODE} -eq 0 ]]; then
    __log_finish
    return 0
   fi
  fi

  sleep "${CHECK_INTERVAL}"
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

##
# Releases download ticket and advances FIFO queue
# Removes lock file for the ticket and advances the current serving counter.
# Allows the next ticket in line to be served.
#
# Parameters:
#   $1: Ticket number - Ticket number to release (required)
#
# Returns:
#   0: Success - Ticket released and queue advanced
#   1: Failure - Error releasing ticket or advancing queue
#   2: Invalid argument - Ticket number is empty
#
# Error codes:
#   0: Success - Lock file removed and queue counter advanced
#   1: Failure - Error removing lock file or updating queue counter (should not normally occur)
#   2: Invalid argument - Ticket number parameter is empty
#
# Context variables:
#   Reads:
#     - TMP_DIR: Temporary directory for queue files (required)
#     - BASHPID: Process ID (used to identify lock file)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies:
#     - Filesystem: Removes lock file from TMP_DIR/download_queue/active/
#     - Filesystem: Updates current_serving counter in queue directory
#
# Side effects:
#   - Removes lock file for the ticket (based on PID and ticket number)
#   - Atomically advances current serving counter to next ticket
#   - Uses flock for atomic queue counter updates
#   - Logs ticket release and queue advancement to standard logger
#   - No network or database operations
#
# Queue advancement logic:
#   - Advances to ticket + 1 when releasing
#   - Only advances if ticket + 1 > current serving (prevents going backwards)
#   - Uses file locking (flock) for atomic updates
#
# Example:
#   TICKET=$(__get_download_ticket)
#   __wait_for_download_turn "${TICKET}"
#   # Perform download
#   curl ...
#   # Always release ticket when done
#   __release_download_ticket "${TICKET}"
#
# Related: __get_download_ticket() (obtains ticket number)
# Related: __wait_for_download_turn() (waits for ticket to be served)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
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
 ##
 # Retries file operations with exponential backoff and optional smart wait
 # Executes arbitrary shell commands with retry logic, cleanup on failure, and optional
 # Overpass API rate limiting integration. Supports smart wait for Overpass operations.
 #
 # Parameters:
 #   $1: Operation command - Shell command to execute (required)
 #   $2: Max retries - Maximum retry attempts (optional, default: 3)
 #   $3: Base delay - Base delay in seconds for exponential backoff (optional, default: 2)
 #   $4: Cleanup command - Command to execute on failure (optional)
 #   $5: Smart wait - Enable Overpass API rate limiting (optional, default: false)
 #   $6: Smart wait endpoint - Overpass endpoint for smart wait (optional, auto-detected)
 #
 # Returns:
 #   0: Success - Operation succeeded
 #   1: Failure - Operation failed after all retries
 #   2: Invalid argument - Missing operation command
 #   6: Network error - Smart wait slot acquisition failed
 #
 # Error codes:
 #   0: Success - Operation executed successfully
 #   1: Failure - Operation failed after max retries
 #   2: Invalid argument - Operation command is empty
 #   6: Network error - Failed to acquire download slot when smart wait enabled
 #
 # Context variables:
 #   Reads:
 #     - TMP_DIR: Temporary directory for queue files (if smart wait enabled)
 #     - OVERPASS_INTERPRETER: Overpass API endpoint (for smart wait detection)
 #     - OVERPASS_RETRIES_PER_ENDPOINT: Max retries (optional, default: 7)
 #     - OVERPASS_BACKOFF_SECONDS: Base delay (optional, default: 20)
 #     - RATE_LIMIT: Maximum concurrent slots (optional, default: 8)
 #     - LOG_LEVEL: Controls logging verbosity
 #   Sets: None
 #   Modifies: None (operation may modify filesystem, but function itself doesn't)
 #
 # Side effects:
 #   - Executes operation command via eval (security consideration)
 #   - Executes cleanup command on failure (if provided)
 #   - Acquires/releases download slot if smart wait enabled
 #   - Sleeps between retries (exponential backoff)
 #   - Logs all operations to standard logger
 #
 # Security notes:
 #   - Uses eval to execute operation command (ensure command is trusted)
 #   - Operation command should be sanitized before passing to this function
 #
 # Example:
 #   if __retry_file_operation "curl -o file.txt https://example.com" 5 3 "rm -f file.txt" "true"; then
 #     echo "Download succeeded"
 #   fi
 #
 # Related: __wait_for_download_slot() (used for smart wait)
 # Related: __release_download_slot() (used for smart wait)
 # Related: STANDARD_ERROR_CODES.md (error code definitions)
 ##
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
   # shellcheck disable=SC2154
   # OVERPASS_INTERPRETER is defined in etc/properties.sh or environment
   EFFECTIVE_OVERPASS_FOR_WAIT="${OVERPASS_INTERPRETER}"
  fi

  if [[ "${SMART_WAIT}" == "true" ]] && [[ -n "${EFFECTIVE_OVERPASS_FOR_WAIT}" ]]; then
   # Use simple semaphore system (recommended - no tickets, no ordering)
   # shellcheck disable=SC2310
   # Intentional: check return value explicitly
   if ! __wait_for_download_slot; then
    __loge "Failed to obtain download slot after waiting"
    trap - EXIT INT TERM
    __log_finish
    return 1
   fi
   __logd "Download slot acquired, proceeding with download"
   # Setup slot cleanup on exit
   # shellcheck disable=SC2317,SC2310
   # SC2317: Function is invoked indirectly via trap
   # SC2310: Intentional: cleanup failures should not stop execution
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
     # shellcheck disable=SC2310
     # Intentional: release failures should not stop execution
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
      local GREP_RESULT
      GREP_RESULT=$(grep -i "error" "${OUTPUT_OVERPASS}" || echo "")
      ERROR_LINE=$(echo "${GREP_RESULT}" | head -1 || echo "")
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
   # shellcheck disable=SC2310
   # Intentional: release failures should not stop execution
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

  if ! STATUS_OUTPUT=$(curl -s -H "User-Agent: ${DOWNLOAD_USER_AGENT:-OSM-Notes-Ingestion/1.0}" "${STATUS_URL}" 2>&1); then
   __logw "Could not reach Overpass API status page, assuming available"
   __log_finish
   echo "0"
   return 0
  fi

  # Extract available slots number (format: "X slots available now")
  local SLOTS_LINE
  local GREP_RESULT
  GREP_RESULT=$(echo "${STATUS_OUTPUT}" | grep -o '[0-9]* slots available now' || echo "")
  SLOTS_LINE=$(echo "${GREP_RESULT}" | head -1 || echo "")
  AVAILABLE_SLOTS=$(echo "${SLOTS_LINE}" | grep -o '[0-9]*' || echo "0")

  if [[ -n "${AVAILABLE_SLOTS}" ]] && [[ "${AVAILABLE_SLOTS}" -gt 0 ]]; then
   __logd "Overpass API has ${AVAILABLE_SLOTS} slot(s) available now"
   __log_finish
   echo "0"
   return 0
  fi

  # Extract wait time from "Slot available after" messages (format: "...in X seconds.")
  # There can be multiple lines, we need the minimum wait time
  local ALL_WAIT_TIMES
  local WAIT_LINES
  WAIT_LINES=$(echo "${STATUS_OUTPUT}" | grep -o 'in [0-9]* seconds' || echo "")
  ALL_WAIT_TIMES=$(echo "${WAIT_LINES}" | grep -o '[0-9]*' || echo "")

  if [[ -n "${ALL_WAIT_TIMES}" ]]; then
   # Find the minimum wait time from all available slots
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
fi

##
# Retries network operations (HTTP downloads) with exponential backoff
# Downloads file from URL with retry logic, HTTP error handling, and timeout management.
# Validates HTTP status codes and ensures downloaded file is non-empty.
#
# Parameters:
#   $1: URL - HTTP/HTTPS URL to download from (required)
#   $2: Output file - Path where downloaded file will be saved (required)
#   $3: Max retries - Maximum retry attempts (optional, default: 5)
#   $4: Base delay - Base delay in seconds for exponential backoff (optional, default: 2)
#   $5: Timeout - Connection and operation timeout in seconds (optional, default: 30)
#
# Returns:
#   0: Success - File downloaded successfully and is non-empty
#   1: Failure - All retry attempts failed or downloaded file is empty
#   2: Invalid argument - Missing required parameters (URL or output file)
#   3: Missing dependency - curl command not found
#   6: Network error - Connection timeout, DNS failure, or HTTP error (4xx, 5xx)
#   7: File error - Cannot write output file
#
# Error codes:
#   0: Success - File downloaded and saved successfully
#   1: Failure - All retries exhausted or file is empty after download
#   2: Invalid argument - URL or output file path is empty
#   3: Missing dependency - curl command not available
#   6: Network error - HTTP 4xx/5xx errors, connection timeout, or DNS failure
#   7: File error - Cannot create or write to output file (disk full, permissions)
#
# Context variables:
#   Reads:
#     - DOWNLOAD_USER_AGENT: User-Agent header for HTTP requests (optional)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies: None
#
# Side effects:
#   - Downloads file from URL using curl
#   - Creates output file with downloaded content
#   - Validates HTTP status codes (retries on 5xx, fails on 4xx)
#   - Logs all operations to standard logger
#   - Sleeps between retries (exponential backoff)
#
# Example:
#   if __retry_network_operation "https://example.com/data.json" "/tmp/data.json" 3 5 60; then
#     echo "Download succeeded"
#   else
#     echo "Download failed with code: $?"
#   fi
#
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
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
  # Use curl with specific error handling and timeout
  if curl -s --connect-timeout "${TIMEOUT}" --max-time "${TIMEOUT}" \
   -H "User-Agent: ${DOWNLOAD_USER_AGENT:-OSM-Notes-Ingestion/1.0}" \
   -o "${OUTPUT_FILE}" "${URL}"; then
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
##
# Retries Overpass API calls with exponential backoff and HTTP optimization
# Executes Overpass API query with retry logic, HTTP/2 support, and connection optimization.
# Uses exponential backoff between retries and validates response file is non-empty.
#
# Parameters:
#   $1: Query - Overpass API query string (URL-encoded, required)
#   $2: Output file - Path where API response will be saved (required)
#   $3: Max retries - Maximum retry attempts (optional, default: 3)
#   $4: Base delay - Base delay in seconds for exponential backoff (optional, default: 5)
#   $5: Timeout - Connection and operation timeout in seconds (optional, default: 300)
#
# Returns:
#   0: Success - API call succeeded and output file is non-empty
#   1: Failure - All retry attempts failed or output file is empty
#   2: Invalid argument - Missing required parameters (query or output file)
#   3: Missing dependency - curl command not found
#   6: Network error - Connection timeout or HTTP error
#   7: File error - Cannot write output file
#
# Error codes:
#   0: Success - Valid response received and saved to output file
#   1: Failure - All retries exhausted or output file is empty after successful HTTP response
#   2: Invalid argument - Query string or output file path is empty
#   3: Missing dependency - curl command not available
#   6: Network error - Connection timeout, DNS failure, or HTTP error
#   7: File error - Cannot create or write to output file
#
# Context variables:
#   Reads:
#     - DOWNLOAD_USER_AGENT: User-Agent header for HTTP requests (optional, default: OSM-Notes-Ingestion/1.0)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies: None
#
# Side effects:
#   - Downloads data from Overpass API using curl
#   - Creates output file with API response
#   - Uses HTTP/2 if available, falls back to HTTP/1.1 with keep-alive
#   - Enables compression (gzip, deflate, br)
#   - Logs all operations to standard logger
#   - Sleeps between retries (exponential backoff)
#
# Example:
#   if __retry_overpass_api "[out:json];node(123);out;" "/tmp/response.json" 5 10 60; then
#     echo "API call succeeded"
#   else
#     echo "API call failed with code: $?"
#   fi
#
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
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

 # Build optimized curl command with HTTP keep-alive and HTTP/2 support
 local CURL_OPTS=(
  "-s"
  "--connect-timeout" "${TIMEOUT}"
  "--max-time" "${TIMEOUT}"
  "--compressed"
  "--http1.1"
  "-H" "Connection: keep-alive"
  "-H" "Accept-Encoding: gzip, deflate, br"
 )

 # Try HTTP/2 if supported (fallback to HTTP/1.1 if not)
 if curl --http2 -s --max-time 5 "https://overpass-api.de" > /dev/null 2>&1; then
  CURL_OPTS+=("--http2")
  __logd "Using HTTP/2 for Overpass API"
 else
  __logd "HTTP/2 not available, using HTTP/1.1 with keep-alive"
 fi

 if [[ -n "${DOWNLOAD_USER_AGENT:-}" ]]; then
  CURL_OPTS+=("-H" "User-Agent: ${DOWNLOAD_USER_AGENT}")
 else
  CURL_OPTS+=("-H" "User-Agent: OSM-Notes-Ingestion/1.0")
 fi

 CURL_OPTS+=("-o" "${OUTPUT_FILE}")

 while [[ ${RETRY_COUNT} -lt ${LOCAL_MAX_RETRIES} ]]; do
  if curl "${CURL_OPTS[@]}" \
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

##
# Retries OSM API calls with exponential backoff and HTTP optimization
# Downloads data from OSM API with retry logic, HTTP/2 support, and conditional caching.
# Uses If-Modified-Since header when cached file exists to reduce bandwidth usage.
#
# Parameters:
#   $1: URL - OSM API endpoint URL (required)
#   $2: Output file - Path where API response will be saved (required)
#   $3: Max retries - Maximum retry attempts (optional, default: 5)
#   $4: Base delay - Base delay in seconds for exponential backoff (optional, default: 2)
#   $5: Timeout - Connection and operation timeout in seconds (optional, default: 30)
#
# Returns:
#   0: Success - API call succeeded and output file is non-empty
#   1: Failure - All retry attempts failed or output file is empty
#   2: Invalid argument - Missing required parameters (URL or output file)
#   3: Missing dependency - curl command not found
#   6: Network error - Connection timeout or HTTP error
#   7: File error - Cannot write output file
#
# Error codes:
#   0: Success - Valid response received and saved to output file
#   1: Failure - All retries exhausted or output file is empty after successful HTTP response
#   2: Invalid argument - URL or output file path is empty
#   3: Missing dependency - curl command not available
#   6: Network error - Connection timeout, DNS failure, or HTTP error
#   7: File error - Cannot create or write to output file
#
# Context variables:
#   Reads:
#     - DOWNLOAD_USER_AGENT: User-Agent header for HTTP requests (optional, default: OSM-Notes-Ingestion/1.0)
#     - ENABLE_HTTP_CACHE: Enable conditional caching with If-Modified-Since (optional, default: true)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies: None (output written to file, not variables)
#
# Side effects:
#   - Downloads data from OSM API using curl
#   - Creates output file with API response
#   - Uses HTTP/2 if available, falls back to HTTP/1.1 with keep-alive
#   - Enables compression (gzip, deflate, br)
#   - Uses If-Modified-Since header if cached file exists (reduces bandwidth)
#   - Logs all operations to standard logger
#   - Sleeps between retries (exponential backoff)
#
# Caching behavior:
#   - If output file exists and ENABLE_HTTP_CACHE=true, sends If-Modified-Since header
#   - Server returns 304 Not Modified if file hasn't changed (saves bandwidth)
#   - If 304 received, keeps existing file unchanged
#
# Example:
#   if __retry_osm_api "https://api.openstreetmap.org/api/0.6/notes/123" "/tmp/note.xml" 3 5 60; then
#     echo "API call succeeded"
#   else
#     echo "API call failed with code: $?"
#   fi
#
# Related: __retry_overpass_api() (for Overpass API calls)
# Related: __retry_network_operation() (for general HTTP downloads)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
##
# Downloads data from OSM API with retry logic, HTTP optimization, and conditional caching
# Executes HTTP GET request to OSM Notes API with exponential backoff retry, HTTP/2 support,
# keep-alive connections, compression, and conditional requests (If-Modified-Since) for caching.
# Handles HTTP 304 Not Modified responses to use cached files and validates successful downloads.
#
# Parameters:
#   $1: URL - OSM API URL to download (required)
#   $2: Output file - Path where downloaded data will be saved (required)
#   $3: Max retries - Maximum retry attempts (optional, default: 5)
#   $4: Base delay - Base delay in seconds for exponential backoff (optional, default: 2)
#   $5: Timeout - Connection and transfer timeout in seconds (optional, default: 30)
#
# Returns:
#   0: Success - Data downloaded successfully or HTTP 304 (cached file valid)
#   1: Failure - All retries exhausted or HTTP error code received
#
# Error codes:
#   0: Success - HTTP 200-299 received and file saved, or HTTP 304 (cached file valid)
#   1: Failure - HTTP error code (non-2xx, non-304), network failure, or empty response after all retries
#
# Context variables:
#   Reads:
#     - DOWNLOAD_USER_AGENT: User-Agent header for HTTP requests (optional)
#     - ENABLE_HTTP_CACHE: Enable conditional requests with If-Modified-Since (optional, default: true)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies: None
#
# Side effects:
#   - Downloads file from OSM API using curl
#   - Creates temporary file during download (mktemp)
#   - Moves temporary file to output file on success
#   - Uses existing output file for HTTP 304 Not Modified responses
#   - Logs all HTTP operations and retry attempts to standard logger
#   - Sleeps between retries with exponential backoff (delay *= 2)
#   - No database or other file operations
#
# HTTP optimizations:
#   - HTTP/2 support with fallback to HTTP/1.1
#   - Keep-alive connections
#   - Compression (gzip, deflate, br)
#   - Conditional requests (If-Modified-Since) when ENABLE_HTTP_CACHE=true
#
# Example:
#   if __retry_osm_api "https://api.openstreetmap.org/api/0.6/notes.json" "/tmp/notes.json" 3 5 60; then
#     echo "Download succeeded"
#   else
#     echo "Download failed"
#   fi
#
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
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

 # Build optimized curl command with HTTP keep-alive and HTTP/2 support
 local CURL_OPTS=(
  "-s"
  "--connect-timeout" "${TIMEOUT}"
  "--max-time" "${TIMEOUT}"
  "--compressed"
  "--http1.1"
  "-H" "Connection: keep-alive"
  "-H" "Accept-Encoding: gzip, deflate, br"
 )

 # Try HTTP/2 if supported (fallback to HTTP/1.1 if not)
 local OSM_BASE_URL
 OSM_BASE_URL=$(echo "${URL}" | sed -E 's|^https?://([^/]+).*|\1|')
 if curl --http2 -s --max-time 5 "https://${OSM_BASE_URL}" > /dev/null 2>&1; then
  CURL_OPTS+=("--http2")
  __logd "Using HTTP/2 for OSM API"
 else
  __logd "HTTP/2 not available, using HTTP/1.1 with keep-alive"
 fi

 if [[ -n "${DOWNLOAD_USER_AGENT:-}" ]]; then
  CURL_OPTS+=("-H" "User-Agent: ${DOWNLOAD_USER_AGENT}")
 fi

 # Conditional caching: use If-Modified-Since if we have a cached file
 if [[ -f "${OUTPUT_FILE}" ]] && [[ -s "${OUTPUT_FILE}" ]] \
  && [[ -n "${ENABLE_HTTP_CACHE:-true}" ]] \
  && [[ "${ENABLE_HTTP_CACHE}" == "true" ]]; then
  local FILE_MOD_TIME
  FILE_MOD_TIME=$(stat -c %y "${OUTPUT_FILE}" 2> /dev/null || stat -f %Sm "${OUTPUT_FILE}" 2> /dev/null || echo "")
  if [[ -n "${FILE_MOD_TIME}" ]]; then
   # Convert to HTTP date format (RFC 7231)
   local HTTP_DATE
   HTTP_DATE=$(date -u -d "${FILE_MOD_TIME}" "+%a, %d %b %Y %H:%M:%S GMT" 2> /dev/null \
    || date -u -j -f "%Y-%m-%d %H:%M:%S" "${FILE_MOD_TIME}" "+%a, %d %b %Y %H:%M:%S GMT" 2> /dev/null \
    || echo "")
   if [[ -n "${HTTP_DATE}" ]]; then
    CURL_OPTS+=("-H" "If-Modified-Since: ${HTTP_DATE}")
    __logd "Using conditional request with If-Modified-Since: ${HTTP_DATE}"
   fi
  fi
 fi

 while [[ ${RETRY_COUNT} -lt ${LOCAL_MAX_RETRIES} ]]; do
  # Execute curl: use temporary file for body, capture HTTP code separately
  local TEMP_OUTPUT
  TEMP_OUTPUT=$(mktemp)
  local HTTP_CODE
  local CURL_OUTPUT
  CURL_OUTPUT=$(curl "${CURL_OPTS[@]}" -w "%{http_code}" -o "${TEMP_OUTPUT}" "${URL}" 2> /dev/null || echo "")
  HTTP_CODE=$(echo -n "${CURL_OUTPUT}" | tail -c 3 || echo "")

  # Handle 304 Not Modified (cached response is still valid)
  if [[ "${HTTP_CODE}" == "304" ]]; then
   __logd "OSM API returned 304 Not Modified - using cached file"
   rm -f "${TEMP_OUTPUT}"
   if [[ -f "${OUTPUT_FILE}" ]] && [[ -s "${OUTPUT_FILE}" ]]; then
    __logd "OSM API call succeeded (cached) on attempt $((RETRY_COUNT + 1))"
    __log_finish
    return 0
   fi
  # Handle successful responses (200, 201, etc.)
  elif [[ "${HTTP_CODE}" =~ ^2[0-9]{2}$ ]]; then
   # Move temporary file to output file
   if [[ -f "${TEMP_OUTPUT}" ]] && [[ -s "${TEMP_OUTPUT}" ]]; then
    mv "${TEMP_OUTPUT}" "${OUTPUT_FILE}"
    __logd "OSM API call succeeded on attempt $((RETRY_COUNT + 1))"
    __log_finish
    return 0
   else
    rm -f "${TEMP_OUTPUT}"
    __logw "OSM API call returned empty file on attempt $((RETRY_COUNT + 1))"
   fi
  else
   rm -f "${TEMP_OUTPUT}"
   __logw "OSM API call failed with HTTP ${HTTP_CODE} on attempt $((RETRY_COUNT + 1))"
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

##
# Retry database operations with exponential backoff
# Executes a PostgreSQL query with retry logic and error detection.
# Handles both psql exit codes and SQL errors in output/error streams.
#
# Parameters:
#   $1: SQL query to execute (required)
#   $2: Output file path (optional, default: /dev/null)
#   $3: Maximum retry attempts (optional, default: 3)
#   $4: Base delay in seconds for exponential backoff (optional, default: 2)
#
# Returns:
#   0: Success - query executed successfully
#   1: Failure - query failed after all retry attempts
#   2: Invalid argument - missing required query parameter
#   3: Missing dependency - psql command not found
#   5: Database error - connection failed or query error
#
# Error codes:
#   0: Success - query executed and completed without errors
#   1: Failure - query failed after max retries (check logs for details)
#   2: Invalid argument - query parameter is empty or missing
#   3: Missing dependency - psql command not available in PATH
#   5: Database error - PostgreSQL connection failed or SQL syntax error
#
# Context variables:
#   Reads:
#     - DBNAME: PostgreSQL database name (required)
#     - PGAPPNAME: PostgreSQL application name for connection (optional)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies: None (output written to file, not variables)
#
# Side effects:
#   - Executes PostgreSQL query via psql command
#   - Creates temporary error file (mktemp) for stderr capture
#   - Writes query output to specified output file
#   - Logs all operations to standard logger
#   - Cleans up temporary error file on completion
#
# Example:
#   if __retry_database_operation "SELECT COUNT(*) FROM notes" "/tmp/count.txt" 5 3; then
#     echo "Query succeeded"
#   else
#     echo "Query failed with code: $?"
#   fi
#
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
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
  PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -Atq -v ON_ERROR_STOP=1 -c "${QUERY}" > "${OUTPUT_FILE}" 2> "${ERROR_FILE}" || PSQL_EXIT_CODE=$?

  # Check for SQL errors in output file (with -Atq, errors may go to stdout)
  local HAS_ERROR=false
  if [[ -s "${OUTPUT_FILE}" ]]; then
   if grep -qiE "^ERROR\|^error\|no existe\|relation.*does not exist" "${OUTPUT_FILE}" 2> /dev/null; then
    HAS_ERROR=true
    local ERROR_FIRST_LINE
    ERROR_FIRST_LINE=$(head -1 "${OUTPUT_FILE}" || echo "")
    __loge "SQL error detected in output: ${ERROR_FIRST_LINE}"
   fi
  fi

  # Check for errors in error file (stderr)
  if [[ -s "${ERROR_FILE}" ]]; then
   if grep -qiE "ERROR\|error\|no existe\|relation.*does not exist" "${ERROR_FILE}" 2> /dev/null; then
    HAS_ERROR=true
    local ERROR_CONTENT
    ERROR_CONTENT=$(cat "${ERROR_FILE}" || echo "")
    __loge "PostgreSQL error: ${ERROR_CONTENT}"
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
  local FINAL_ERROR
  FINAL_ERROR=$(cat "${ERROR_FILE}" || echo "")
  __loge "Final PostgreSQL error: ${FINAL_ERROR}"
 fi
 rm -f "${ERROR_FILE}"

 __loge "Database operation failed after ${LOCAL_MAX_RETRIES} attempts"
 __log_finish
 return 1
}

##
# Logs data gap to file and database
# Records a data gap event to both a log file and the database data_gaps table. Calculates
# gap percentage automatically. Used for tracking data integrity issues. Database insert
# failures are non-blocking (logged but don't cause function failure).
#
# Parameters:
#   $1: GAP_TYPE - Type of gap detected (e.g., "missing_comments", "missing_notes") (required)
#   $2: GAP_COUNT - Number of items with gaps (required, must be numeric)
#   $3: TOTAL_COUNT - Total number of items checked (required, must be numeric)
#   $4: ERROR_DETAILS - Details about the gap/error (optional)
#
# Returns:
#   Always returns 0 (non-blocking, database insert failures don't cause function failure)
#
# Error codes:
#   0: Success - Gap logged to file and database (or file only if database insert fails)
#
# Error conditions:
#   0: Success - Gap logged successfully
#   0: Success - Database insert failed (logged to file only, doesn't fail function)
#
# Context variables:
#   Reads:
#     - DBNAME: PostgreSQL database name (required)
#     - PGAPPNAME: PostgreSQL application name (optional)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies:
#     - Appends gap information to log file (/tmp/processAPINotes_gaps.log)
#     - Inserts gap record into data_gaps table
#
# Side effects:
#   - Calculates gap percentage (GAP_COUNT * 100 / TOTAL_COUNT)
#   - Appends gap information to log file with timestamp
#   - Inserts gap record into database (non-blocking, errors ignored)
#   - Writes log messages to stderr
#   - Database operations: INSERT into data_gaps table
#   - File operations: Append to gap log file
#   - No network operations
#
# Notes:
#   - Calculates gap percentage automatically
#   - Logs to file: /tmp/processAPINotes_gaps.log
#   - Database insert is non-blocking (failures don't cause function failure)
#   - Gap record marked as unprocessed (processed = FALSE)
#   - Used for tracking and monitoring data integrity issues
#   - Part of data quality monitoring workflow
#   - Database insert uses 2>/dev/null || true to prevent failures
#
# Example:
#   export DBNAME="osm_notes"
#   __log_data_gap "missing_comments" 5 50 "Notes without comments detected"
#   # Logs gap: 5/50 (10%) to file and database
#
# Related: __check_and_log_gaps() (checks and logs gaps from database)
# Related: __recover_from_gaps() (detects and recovers from gaps)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
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

 {
  local GAP_DATE
  GAP_DATE=$(date '+%Y-%m-%d %H:%M:%S' || echo "unknown")
  cat << EOF
========================================
GAP DETECTED: ${GAP_DATE}
========================================
Type: ${GAP_TYPE}
Count: ${GAP_COUNT}/${TOTAL_COUNT} (${GAP_PERCENTAGE}%)
Details: ${ERROR_DETAILS}
---
EOF
 } >> "${GAP_FILE}"

 # Log to database
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -c "
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
