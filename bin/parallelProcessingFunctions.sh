#!/bin/bash
# Consolidated Parallel Processing Functions for OSM-Notes-profile
# This file consolidates all parallel processing functions to eliminate duplication
#
# Author: Andres Gomez (AngocA)
# Version: 2025-08-16
# Description: Centralized parallel processing functions with resource management and retry logic

# Load properties if not already loaded
if [[ -z "${MAX_THREADS:-}" ]]; then
 if [[ -f "${SCRIPT_BASE_DIRECTORY:-.}/etc/properties.sh" ]]; then
  source "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh"
 elif [[ -f "./etc/properties.sh" ]]; then
  source "./etc/properties.sh"
 fi
fi

# Load common functions if not already loaded
if [[ -z "${__log_start:-}" ]]; then
 if [[ -f "${SCRIPT_BASE_DIRECTORY:-.}/bin/commonFunctions.sh" ]]; then
  source "${SCRIPT_BASE_DIRECTORY}/bin/commonFunctions.sh"
 elif [[ -f "./bin/commonFunctions.sh" ]]; then
  source "./bin/commonFunctions.sh"
 fi
fi

# Resource management constants
declare -r MAX_MEMORY_PERCENT=80
declare -r MAX_LOAD_AVERAGE=2.0
declare -r PROCESS_TIMEOUT=300
declare -r MAX_RETRIES=3
declare -r RETRY_DELAY=5

# Parallel processing constants
# Note: PARALLEL_PROCESS_DELAY is already declared as readonly in properties.sh

# Common help function for library files
function __show_help_library() {
 local SCRIPT_NAME="${1:-Unknown Script}"
 local DESCRIPTION="${2:-No description available}"
 local FUNCTIONS_LIST="${3:-}"
 local VERSION="${4:-${VERSION:-Unknown}}"

 echo "${SCRIPT_NAME}"
 echo "${DESCRIPTION}"
 echo
 echo "Usage: source bin/$(basename "${BASH_SOURCE[0]}")"
 echo
 if [[ -n "${FUNCTIONS_LIST}" ]]; then
  echo "Available functions:"
  echo -e "${FUNCTIONS_LIST}"
  echo
 fi
 echo "Author: Andres Gomez (AngocA)"
 echo "Version: ${VERSION}"
 exit "${ERROR_HELP_MESSAGE:-1}"
}

# Check system resources before launching new processes
# Returns: 0 if resources are available, 1 if not
function __check_system_resources() {
 __log_start
 local MEMORY_PERCENT
 local CURRENT_LOAD

 # Check memory usage
 if command -v free > /dev/null 2>&1; then
  MEMORY_PERCENT=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}' || true)
  if [[ "${MEMORY_PERCENT}" -gt "${MAX_MEMORY_PERCENT}" ]]; then
   __logw "WARNING: High memory usage (${MEMORY_PERCENT}%), waiting for resources..."
   __log_finish
   return 1
  fi
 fi

 # Check system load
 if command -v uptime > /dev/null 2>&1; then
  CURRENT_LOAD=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//' || true)
  if [[ -n "${CURRENT_LOAD}" ]] && [[ "${CURRENT_LOAD}" != "0.00" ]]; then
   if [[ $(echo "${CURRENT_LOAD} > ${MAX_LOAD_AVERAGE}" | bc -l 2>/dev/null || echo "0") == "1" ]]; then
    __logw "WARNING: High system load (${CURRENT_LOAD}), waiting for resources..."
    __log_finish
    return 1
   fi
  fi
 fi

 __logd "System resources OK - Memory: ${MEMORY_PERCENT:-N/A}%, Load: ${CURRENT_LOAD:-N/A}"
 __log_finish
 return 0
}

# Wait for system resources to become available
# Parameters:
#   $1: Maximum wait time in seconds (optional, default: 60)
# Returns: 0 if resources become available, 1 if timeout
function __wait_for_resources() {
 __log_start
 local MAX_WAIT_TIME="${1:-60}"
 local WAIT_TIME=0
 local WAIT_INTERVAL=5

 __logd "Waiting for system resources to become available (max: ${MAX_WAIT_TIME}s)..."

 while [[ ${WAIT_TIME} -lt ${MAX_WAIT_TIME} ]]; do
  if __check_system_resources; then
   __logd "Resources available after ${WAIT_TIME}s"
   __log_finish
   return 0
  fi

  sleep "${WAIT_INTERVAL}"
  WAIT_TIME=$((WAIT_TIME + WAIT_INTERVAL))
 done

 __logw "WARNING: Timeout waiting for system resources"
 __log_finish
 return 1
}

# Adjust number of workers based on system resources
# Parameters:
#   $1: Requested number of workers
# Returns: Adjusted number of workers
function __adjust_workers_for_resources() {
 __log_start
 local REQUESTED_WORKERS="${1:-4}"
 local ADJUSTED_WORKERS="${REQUESTED_WORKERS}"
 local MEMORY_PERCENT

 # Check memory and reduce workers if needed
 if command -v free > /dev/null 2>&1; then
  MEMORY_PERCENT=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}' || true)
  if [[ "${MEMORY_PERCENT}" -gt 70 ]]; then
   ADJUSTED_WORKERS=$((ADJUSTED_WORKERS / 2))
   __logw "Reducing workers to ${ADJUSTED_WORKERS} due to high memory usage (${MEMORY_PERCENT}%)"
  elif [[ "${MEMORY_PERCENT}" -gt 50 ]]; then
   ADJUSTED_WORKERS=$((ADJUSTED_WORKERS * 3 / 4))
   __logw "Reducing workers to ${ADJUSTED_WORKERS} due to moderate memory usage (${MEMORY_PERCENT}%)"
  fi
 fi

 # Ensure minimum workers
 if [[ ${ADJUSTED_WORKERS} -lt 1 ]]; then
  ADJUSTED_WORKERS=1
 fi

 __logd "Adjusted workers from ${REQUESTED_WORKERS} to ${ADJUSTED_WORKERS}"
 __log_finish
 echo "${ADJUSTED_WORKERS}"
}

# Adjust process delay based on system resources
# Returns: Adjusted delay in seconds
function __adjust_process_delay() {
 __log_start
 local BASE_DELAY="${PARALLEL_PROCESS_DELAY}"
 local ADJUSTED_DELAY="${BASE_DELAY}"
 local MEMORY_PERCENT

 # Check memory and increase delay if needed
 if command -v free > /dev/null 2>&1; then
  MEMORY_PERCENT=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}' || true)
  if [[ "${MEMORY_PERCENT}" -gt 70 ]]; then
   ADJUSTED_DELAY=$((ADJUSTED_DELAY * 3))
   __logw "Increased process delay to ${ADJUSTED_DELAY}s due to high memory usage (${MEMORY_PERCENT}%)"
  elif [[ "${MEMORY_PERCENT}" -gt 50 ]]; then
   ADJUSTED_DELAY=$((ADJUSTED_DELAY * 2))
   __logw "Increased process delay to ${ADJUSTED_DELAY}s due to moderate memory usage (${MEMORY_PERCENT}%)"
  fi
 fi

 # Check system load and adjust delay
 if command -v uptime > /dev/null 2>&1; then
  local CURRENT_LOAD
  CURRENT_LOAD=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//' || true)
  if [[ -n "${CURRENT_LOAD}" ]] && [[ "${CURRENT_LOAD}" != "0.00" ]]; then
   if (($(echo "${CURRENT_LOAD} > ${MAX_LOAD_AVERAGE}" | bc -l || true))); then
    ADJUSTED_DELAY=$((ADJUSTED_DELAY * 2))
    __logw "Increased process delay to ${ADJUSTED_DELAY}s due to high system load (${CURRENT_LOAD})"
   fi
  fi
 fi

 # Ensure reasonable delay limits
 if [[ ${ADJUSTED_DELAY} -gt 10 ]]; then
  ADJUSTED_DELAY=10
  __logw "Capped process delay at 10s for reasonable performance"
 fi

 __logd "Adjusted process delay from ${BASE_DELAY}s to ${ADJUSTED_DELAY}s"
 __log_finish
 echo "${ADJUSTED_DELAY}"
}

# Configure system limits to prevent process killing
# Returns: 0 on success, 1 on failure
function __configure_system_limits() {
 __log_start
 local SUCCESS=true

 # Check if we can modify limits
 if [[ -n "${BASH_VERSION:-}" ]]; then
  # Set higher limits for current shell
  if command -v ulimit > /dev/null 2>&1; then
   # Increase file descriptor limit
   if ulimit -n 65536 2> /dev/null; then
    __logd "Increased file descriptor limit to 65536"
   else
    __logw "Could not increase file descriptor limit"
    SUCCESS=false
   fi

   # Increase process limit if possible
   if ulimit -u 32768 2> /dev/null; then
    __logd "Increased process limit to 32768"
   else
    __logw "Could not increase process limit"
   fi
  fi
 fi

 # Check and set memory limits if possible
 if command -v prlimit > /dev/null 2>&1; then
  # Get current process ID
  local CURRENT_PID=$$

  # Try to increase memory limit (soft limit to 2GB, hard limit to 4GB)
  if prlimit --pid "${CURRENT_PID}" --as=2147483648:4294967296 2> /dev/null; then
   __logd "Increased memory limit to 2GB soft, 4GB hard"
  else
   __logw "Could not increase memory limit"
  fi
 fi

 # Log current limits
 if command -v ulimit > /dev/null 2>&1; then
  __logd "Current limits:"
  __logd "  File descriptors: $(ulimit -n || true)"
  __logd "  Processes: $(ulimit -u || true)"
  __logd "  Memory: $(ulimit -v || true)"
 fi

 if [[ "${SUCCESS}" == "true" ]]; then
  __logd "System limits configured successfully"
  __log_finish
  return 0
 else
  __logw "Some system limits could not be configured"
  __log_finish
  return 1
 fi
}

# Process XML with XSLT using timeout, retry logic, and performance profiling
# Parameters:
#   $1: XML file path
#   $2: XSLT file path
#   $3: Output file path
#   $4: Additional XSLT parameters (optional)
#   $5: Timeout in seconds (optional, default: PROCESS_TIMEOUT)
#   $6: Enable profiling (optional, default: false)
# Returns: 0 on success, 1 on failure
function __process_xml_with_xslt_robust() {
 __log_start
 __logd "Function called with $# parameters: '$1' '$2' '$3' '$4' '$5' '$6'"
 local XML_FILE="${1}"
 local XSLT_FILE="${2}"
 local OUTPUT_FILE="${3}"
 local XSLT_PARAMS="${4:-}"
 local TIMEOUT="${5:-${PROCESS_TIMEOUT}}"
 local ENABLE_PROFILING="${6:-false}"
 __logd "ENABLE_PROFILING parameter received: '${ENABLE_PROFILING}'"
 __logd "All parameters received: XML='${1}', XSLT='${2}', OUTPUT='${3}', PARAMS='${4}', TIMEOUT='${5}', PROFILING='${6}'"
 local RETRY_COUNT=0
 local SUCCESS=false

 # Validate inputs
 if [[ ! -f "${XML_FILE}" ]]; then
  __loge "ERROR: XML file not found: ${XML_FILE}"
  __log_finish
  return 1
 fi

 if [[ ! -f "${XSLT_FILE}" ]]; then
  __loge "ERROR: XSLT file not found: ${XSLT_FILE}"
  __log_finish
  return 1
 fi

 __logd "File validation passed: XML='${XML_FILE}', XSLT='${XSLT_FILE}'"

 # Create output directory if it doesn't exist
 local OUTPUT_DIR
 OUTPUT_DIR=$(dirname "${OUTPUT_FILE}")
 mkdir -p "${OUTPUT_DIR}"

 __logd "Processing XML with XSLT: ${XML_FILE} -> ${OUTPUT_FILE}"
 __logd "Timeout: ${TIMEOUT}s, Max retries: ${MAX_RETRIES}"

 __logd "Starting while loop: RETRY_COUNT=${RETRY_COUNT}, MAX_RETRIES=${MAX_RETRIES}, SUCCESS=${SUCCESS}"
 while [[ ${RETRY_COUNT} -le ${MAX_RETRIES} ]] && [[ "${SUCCESS}" == "false" ]]; do
  if [[ ${RETRY_COUNT} -gt 0 ]]; then
   __logw "Retry attempt ${RETRY_COUNT}/${MAX_RETRIES} for ${XML_FILE}"
   sleep "${RETRY_DELAY}"
  fi

  # Check system resources before processing
  if ! __check_system_resources; then
   __logw "WARNING: System resources low, waiting before retry..."
   if ! __wait_for_resources 30; then
    __loge "ERROR: Resources not available for retry"
    ((RETRY_COUNT++))
    continue
   fi
  fi

  # Process with timeout and optional profiling
  __logd "About to check ENABLE_PROFILING: '${ENABLE_PROFILING}' (type: $(declare -p ENABLE_PROFILING 2>/dev/null || echo 'not declared'))"
  __logd "ENABLE_PROFILING comparison: '${ENABLE_PROFILING}' == 'true' -> $([[ "${ENABLE_PROFILING}" == "true" ]] && echo 'true' || echo 'false')"
  if [[ "${ENABLE_PROFILING}" == "true" ]]; then
    local PROFILE_FILE
    PROFILE_FILE="${OUTPUT_FILE}.profile"
    __logd "Profiling enabled, profile will be saved to: ${PROFILE_FILE}"
    __logd "ENABLE_PROFILING value: '${ENABLE_PROFILING}'"
    
    if timeout "${TIMEOUT}" xsltproc --profile ${XSLT_PARAMS:+"${XSLT_PARAMS}"} -o "${OUTPUT_FILE}" "${XSLT_FILE}" "${XML_FILE}" 2> "${PROFILE_FILE}"; then
     if [[ -f "${OUTPUT_FILE}" ]]; then
      SUCCESS=true
      __logd "XSLT processing successful on attempt ${RETRY_COUNT}"
     else
      __loge "XSLT processing completed but output file not created"
     fi
    else
     local EXIT_CODE=$?
     if [[ ${EXIT_CODE} -eq 124 ]]; then
      __loge "XSLT processing timed out after ${TIMEOUT}s"
     else
      __loge "XSLT processing failed with exit code: ${EXIT_CODE}"
     fi
    fi
   else
    if timeout "${TIMEOUT}" xsltproc ${XSLT_PARAMS:+"${XSLT_PARAMS}"} -o "${OUTPUT_FILE}" "${XSLT_FILE}" "${XML_FILE}" 2> /dev/null; then
     if [[ -f "${OUTPUT_FILE}" ]]; then
      SUCCESS=true
      __logd "XSLT processing successful on attempt ${RETRY_COUNT}"
     else
      __loge "XSLT processing completed but output file not created"
     fi
    else
     local EXIT_CODE=$?
     if [[ ${EXIT_CODE} -eq 124 ]]; then
      __loge "XSLT processing timed out after ${TIMEOUT}s"
     else
      __loge "XSLT processing failed with exit code: ${EXIT_CODE}"
     fi
    fi
   fi

  if [[ "${SUCCESS}" == "false" ]]; then
   ((RETRY_COUNT++))
   # Clean up partial output
   if [[ -f "${OUTPUT_FILE}" ]]; then
    rm -f "${OUTPUT_FILE}"
   fi
  fi
 done

 if [[ "${SUCCESS}" == "true" ]]; then
  __logd "XSLT processing completed successfully"
  if [[ "${ENABLE_PROFILING}" == "true" ]]; then
   local PROFILE_FILE="${OUTPUT_FILE}.profile"
   if [[ -f "${PROFILE_FILE}" ]]; then
    __logi "Performance profile saved to: ${PROFILE_FILE}"
    __logd "Profile contains detailed timing information for optimization analysis"
   fi
  fi
  __log_finish
  return 0
 else
  __loge "ERROR: XSLT processing failed after ${MAX_RETRIES} retries"
  __log_finish
  return 1
 fi
}

# Process XML parts in parallel (consolidated version)
# Parameters:
#   $1: Input directory containing XML parts
#   $2: XSLT file for processing
#   $3: Output directory for CSV files
#   $4: Maximum number of workers (optional, default: 4)
#   $5: Processing type (optional, default: generic)
# Returns: 0 on success, 1 on failure
function __processXmlPartsParallel() {
 __log_start
 __logd "Processing XML parts in parallel (consolidated version)."

 local INPUT_DIR="${1}"
 local XSLT_FILE="${2}"
 local OUTPUT_DIR="${3}"
 local MAX_WORKERS="${4:-${MAX_THREADS:-4}}"
 local PROCESSING_TYPE="${5:-generic}"

 # Configure system limits to prevent process killing
 __logd "Configuring system limits for parallel processing..."
 __configure_system_limits

 if [[ ! -d "${INPUT_DIR}" ]]; then
  __loge "ERROR: Input directory not found: ${INPUT_DIR}"
  __log_finish
  return 1
 fi

 if [[ ! -f "${XSLT_FILE}" ]]; then
  __loge "ERROR: XSLT file not found: ${XSLT_FILE}"
  __log_finish
  return 1
 fi

 # Create output directory
 mkdir -p "${OUTPUT_DIR}"

 # Find only XML parts (exclude the original file)
 local XML_FILES
 if [[ "${PROCESSING_TYPE}" == "Planet" ]]; then
  mapfile -t XML_FILES < <(find "${INPUT_DIR}" -name "planet_part_*.xml" -type f | sort || true)
 elif [[ "${PROCESSING_TYPE}" == "API" ]]; then
  mapfile -t XML_FILES < <(find "${INPUT_DIR}" -name "api_part_*.xml" -type f | sort || true)
 else
  __loge "ERROR: Invalid processing type: ${PROCESSING_TYPE}. Must be 'Planet' or 'API'"
  __log_finish
  return 1
 fi

 if [[ ${#XML_FILES[@]} -eq 0 ]]; then
  __logw "WARNING: No XML files found in ${INPUT_DIR}"
  __log_finish
  return 0
 fi

 # Adjust workers based on system resources
 MAX_WORKERS=$(__adjust_workers_for_resources "${MAX_WORKERS}")
 __logi "Processing ${#XML_FILES[@]} XML parts with max ${MAX_WORKERS} workers (adjusted for resources)."

 # Process files in parallel with resource management
 local PIDS=()
 local PROCESSED=0
 local FAILED=0
 local FAILED_FILES=()
 local RETRY_QUEUE=()

 for XML_FILE in "${XML_FILES[@]}"; do
  local BASE_NAME
  BASE_NAME=$(basename "${XML_FILE}" .xml)

  # Wait for resources if needed before launching new process
  if ! __check_system_resources; then
   __logd "Waiting for system resources before processing ${BASE_NAME}..."
   if ! __wait_for_resources 60; then
    __logw "WARNING: Resources not available, adding ${BASE_NAME} to retry queue"
    RETRY_QUEUE+=("${XML_FILE}")
    continue
   fi
  fi

  # Launch processing in background based on processing type
  if [[ "${PROCESSING_TYPE}" == "Planet" ]]; then
   # Launch Planet processing in background
   __processPlanetXmlPart "${XML_FILE}" &
   local PID=$!
   PIDS+=("${PID}")
   __logd "Launched Planet XML part processing in background: ${XML_FILE} (PID: ${PID})"
  elif [[ "${PROCESSING_TYPE}" == "API" ]]; then
   # Launch API processing in background
   __processApiXmlPart "${XML_FILE}" &
   local PID=$!
   PIDS+=("${PID}")
   __logd "Launched API XML part processing in background: ${XML_FILE} (PID: ${PID})"
  fi

  # Add delay between process launches to prevent system overload
  local CURRENT_DELAY
  CURRENT_DELAY=$(__adjust_process_delay)
  if [[ ${CURRENT_DELAY} -gt 0 ]]; then
   __logd "Waiting ${CURRENT_DELAY}s before launching next process..."
   sleep "${CURRENT_DELAY}"
  fi

  # Limit concurrent processes
  if [[ ${#PIDS[@]} -ge ${MAX_WORKERS} ]]; then
   __logd "Reached max workers (${MAX_WORKERS}), waiting for one to complete..."
   wait "${PIDS[0]}"
   local EXIT_CODE=$?
   if [[ ${EXIT_CODE} -eq 0 ]]; then
    ((PROCESSED++))
    __logd "Background process completed successfully"
   else
    ((FAILED++))
    __loge "Background process failed with exit code: ${EXIT_CODE}"
    FAILED_FILES+=("${XML_FILE}")
   fi
   PIDS=("${PIDS[@]:1}")
  fi
 done

 # Wait for remaining processes
 __logd "Waiting for remaining ${#PIDS[@]} background processes to complete..."
 for PID in "${PIDS[@]}"; do
  wait "${PID}"
  local EXIT_CODE=$?
  if [[ ${EXIT_CODE} -eq 0 ]]; then
   ((PROCESSED++))
   __logd "Background process ${PID} completed successfully"
  else
   ((FAILED++))
   __loge "Background process ${PID} failed with exit code: ${EXIT_CODE}"
   FAILED_FILES+=("${XML_FILE}")
  fi
 done

 # Process retry queue if there are failed files
 if [[ ${#RETRY_QUEUE[@]} -gt 0 ]]; then
  __logi "Processing ${#RETRY_QUEUE[@]} files from retry queue..."
  for XML_FILE in "${RETRY_QUEUE[@]}"; do
   local BASE_NAME
   BASE_NAME=$(basename "${XML_FILE}" .xml)

   # Wait for resources
   if ! __wait_for_resources 120; then
    __loge "ERROR: Resources not available for retry of ${BASE_NAME}"
    ((FAILED++))
    FAILED_FILES+=("${XML_FILE}")
    continue
   fi

   # Retry processing
   if [[ "${PROCESSING_TYPE}" == "Planet" ]]; then
    __processPlanetXmlPart "${XML_FILE}"
   elif [[ "${PROCESSING_TYPE}" == "API" ]]; then
    __processApiXmlPart "${XML_FILE}"
   fi

   if __process_xml_with_xslt_robust "${XML_PART}" "${XSLT_NOTES_FILE_LOCAL}" "${OUTPUT_NOTES_PART}" "--stringparam default-timestamp \"${CURRENT_TIMESTAMP}\""; then
    ((PROCESSED++))
    __logd "Retry successful for ${BASE_NAME}"
   else
    ((FAILED++))
    __loge "Retry failed for ${BASE_NAME}"
    FAILED_FILES+=("${XML_FILE}")
   fi
  done
 fi

 __logi "Parallel processing completed. Processed ${PROCESSED}/${#XML_FILES[@]} files, Failed: ${FAILED}"

 # Log delay statistics
 local TOTAL_DELAY_TIME
 TOTAL_DELAY_TIME=$(((${#XML_FILES[@]} - 1) * PARALLEL_PROCESS_DELAY))
 __logd "Total delay time between processes: ${TOTAL_DELAY_TIME}s"

 if [[ ${#FAILED_FILES[@]} -gt 0 ]]; then
  __logw "Failed files:"
  for FAILED_FILE in "${FAILED_FILES[@]}"; do
   __logw "  - ${FAILED_FILE}"
  done
 fi

 # Check if any files were processed successfully
 if [[ ${PROCESSED} -eq 0 ]]; then
  __loge "ERROR: No files were processed successfully. All processing failed."
  __log_finish
  return 1
 fi

 __log_finish
}

# Split XML file for parallel processing (consolidated safe version)
# Parameters:
#   $1: XML file path
#   $2: Number of parts to split into (optional, default: 4)
#   $3: Output directory (optional, default: TMP_DIR)
#   $4: Format type (optional, default: API)
# Returns: 0 on success, 1 on failure
function __splitXmlForParallelSafe() {
 __log_start
 __logd "Splitting XML for parallel processing (consolidated safe version)."

 local XML_FILE="${1}"
 local NUM_PARTS="${2:-${MAX_THREADS:-4}}"
 local OUTPUT_DIR="${3:-${TMP_DIR}}"
 local FORMAT_TYPE="${4:-API}"

 if [[ ! -f "${XML_FILE}" ]]; then
  __loge "ERROR: XML file not found: ${XML_FILE}"
  __log_finish
  return "${ERROR_MISSING_LIBRARY}"
 fi

 # Create output directory
 mkdir -p "${OUTPUT_DIR}"

 # Count total notes
 local TOTAL_NOTES
 TOTAL_NOTES=$(grep -c '<note' "${XML_FILE}" 2> /dev/null || echo "0")

 if [[ "${TOTAL_NOTES}" -eq 0 ]]; then
  __logw "WARNING: No notes found in XML file."
  __log_finish
  return 0
 fi

 # Calculate notes per part
 local NOTES_PER_PART
 NOTES_PER_PART=$((TOTAL_NOTES / NUM_PARTS))
 if [[ $((TOTAL_NOTES % NUM_PARTS)) -gt 0 ]]; then
  NOTES_PER_PART=$((NOTES_PER_PART + 1))
 fi

 __logi "Splitting ${TOTAL_NOTES} notes into ${NUM_PARTS} parts (${NOTES_PER_PART} notes per part)."

 # Split XML file safely using awk (memory efficient)
 __logi "Starting memory-efficient XML splitting with awk..."

 # Get line numbers where notes start
 local NOTE_LINES
 NOTE_LINES=$(awk '/<note[^>]*>/ {print NR}' "${XML_FILE}" 2> /dev/null)

 if [[ -z "${NOTE_LINES}" ]]; then
  __loge "ERROR: No note start tags found in XML file"
  __log_finish
  return 1
 fi

 # Convert to array
 mapfile -t NOTE_LINE_ARRAY <<< "${NOTE_LINES}"
 local TOTAL_NOTE_LINES=${#NOTE_LINE_ARRAY[@]}

 __logi "Found ${TOTAL_NOTE_LINES} note start positions"

 # Calculate notes per part
 local NOTES_PER_PART
 NOTES_PER_PART=$((TOTAL_NOTES / NUM_PARTS))
 if [[ $((TOTAL_NOTES % NUM_PARTS)) -gt 0 ]]; then
  NOTES_PER_PART=$((NOTES_PER_PART + 1))
 fi

 for ((i = 0; i < NUM_PARTS; i++)); do
  local START_INDEX=$((i * NOTES_PER_PART))
  local END_INDEX=$(((i + 1) * NOTES_PER_PART - 1))

  if [[ "${END_INDEX}" -ge "${TOTAL_NOTE_LINES}" ]]; then
   END_INDEX=$((TOTAL_NOTE_LINES - 1))
  fi

  if [[ "${START_INDEX}" -lt "${TOTAL_NOTE_LINES}" ]]; then
   local OUTPUT_FILE="${OUTPUT_DIR}/${FORMAT_TYPE,,}_part_${i}.xml"
   local START_LINE=${NOTE_LINE_ARRAY[START_INDEX]}
   local END_LINE

   if [[ "${END_INDEX}" -lt $((TOTAL_NOTE_LINES - 1)) ]]; then
    # Find the next note start line to ensure we don't cut in the middle of a note
    local NEXT_INDEX=$((END_INDEX + 1))
    if [[ "${NEXT_INDEX}" -lt "${TOTAL_NOTE_LINES}" ]]; then
     # Go to the line before the next note starts
     END_LINE=$((NOTE_LINE_ARRAY[NEXT_INDEX] - 1))
    else
     # Last part - go to end of file
     END_LINE=$(wc -l < "${XML_FILE}")
    fi
   else
    # Last part - go to end of file
    END_LINE=$(wc -l < "${XML_FILE}")
   fi

   __logd "Creating part ${i}: lines ${START_LINE}-${END_LINE}"

   # Create XML wrapper
   {
    echo '<?xml version="1.0" encoding="UTF-8"?>'
    echo '<osm-notes>'
    # Extract lines using sed (memory efficient)
    sed -n "${START_LINE},${END_LINE}p" "${XML_FILE}"
    echo '</osm-notes>'
   } > "${OUTPUT_FILE}"

   __logd "Created ${FORMAT_TYPE,,} part ${i}: ${OUTPUT_FILE} (lines ${START_LINE}-${END_LINE})"
  fi
 done

 __logi "XML splitting completed safely. Created ${NUM_PARTS} parts."
 __log_finish
}

# Wrapper function for API format that uses parallel processing
# Parameters:
#   $1: XML file path
#   $2: Number of notes to split (optional, uses TOTAL_NOTES if not provided)
# Returns: 0 on success, 1 on failure
function __splitXmlForParallelAPI() {
 __log_start
 __splitXmlForParallelSafe "${1}" "${2:-}" "${3:-}" "API"
 local return_code=$?
 __log_finish
 return "${return_code}"
}

# Wrapper function for Planet format that uses parallel processing
# Parameters:
#   $1: XML file path
#   $2: Number of notes to split (optional, uses TOTAL_NOTES if not provided)
# Returns: 0 on success, 1 on failure
function __splitXmlForParallelPlanet() {
 __log_start
 __splitXmlForParallelSafe "${1}" "${2:-}" "${3:-}" "Planet"
 local return_code=$?
 __log_finish
 return "${return_code}"
}

# Process API XML part (consolidated version)
# Parameters:
#   $1: XML part file path
#   $2: XSLT notes file (optional, uses global if not provided)
#   $3: XSLT comments file (optional, uses global if not provided)
#   $4: XSLT text comments file (optional, uses global if not provided)
# Returns: 0 on success, 1 on failure
function __processApiXmlPart() {
 __log_start
 local XML_PART="${1}"
 local XSLT_NOTES_FILE_LOCAL="${2:-${XSLT_NOTES_API_FILE}}"
 local XSLT_COMMENTS_FILE_LOCAL="${3:-${XSLT_NOTE_COMMENTS_API_FILE}}"
 local XSLT_TEXT_FILE_LOCAL="${4:-${XSLT_TEXT_COMMENTS_API_FILE}}"
 local PART_NUM
 local BASENAME_PART

 __logi "=== STARTING API XML PART PROCESSING ==="
 __logd "Input XML part: ${XML_PART}"
 __logd "XSLT files:"
 __logd "  Notes: ${XSLT_NOTES_FILE_LOCAL}"
 __logd "  Comments: ${XSLT_COMMENTS_FILE_LOCAL}"
 __logd "  Text: ${XSLT_TEXT_FILE_LOCAL}"

 BASENAME_PART=$(basename "${XML_PART}" .xml)
 # Extract part number from api_part_X.xml
 if [[ "${BASENAME_PART}" =~ ^api_part_([0-9]+)$ ]]; then
  PART_NUM="${BASH_REMATCH[1]}"
 else
  __loge "Invalid filename format: '${BASENAME_PART}'. Expected: api_part_X.xml"
  __log_finish
  return 1
 fi

 # Validate part number
 if [[ -z "${PART_NUM}" ]] || [[ ! "${PART_NUM}" =~ ^[0-9]+$ ]]; then
  __loge "Invalid part number extracted: '${PART_NUM}' from file: ${XML_PART}"
  __log_finish
  return 1
 fi

 __logi "Processing API XML part ${PART_NUM}: ${XML_PART}"

 # Convert XML part to CSV using XSLT
 local OUTPUT_NOTES_PART
 local OUTPUT_COMMENTS_PART
 local OUTPUT_TEXT_PART
 OUTPUT_NOTES_PART="${TMP_DIR}/output-notes-part-${PART_NUM}.csv"
 OUTPUT_COMMENTS_PART="${TMP_DIR}/output-comments-part-${PART_NUM}.csv"
 OUTPUT_TEXT_PART="${TMP_DIR}/output-text-part-${PART_NUM}.csv"

 # Generate current timestamp for XSLT processing
 local CURRENT_TIMESTAMP
 CURRENT_TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
 __logd "Using timestamp for XSLT processing: ${CURRENT_TIMESTAMP}"

 # Process notes
 __logd "Processing notes with robust XSLT processor: ${XSLT_NOTES_FILE_LOCAL} -> ${OUTPUT_NOTES_PART}"
 if ! __process_xml_with_xslt_robust "${XML_PART}" "${XSLT_NOTES_FILE_LOCAL}" "${OUTPUT_NOTES_PART}" "--stringparam default-timestamp \"${CURRENT_TIMESTAMP}\"" "" "${ENABLE_XSLT_PROFILING}"; then
  __loge "Notes CSV file was not created: ${OUTPUT_NOTES_PART}"
  __log_finish
  return 1
 fi

 # Process comments
 __logd "Processing comments with robust XSLT processor: ${XSLT_COMMENTS_FILE_LOCAL} -> ${OUTPUT_COMMENTS_PART}"
 if ! __process_xml_with_xslt_robust "${XML_PART}" "${XSLT_COMMENTS_FILE_LOCAL}" "${OUTPUT_COMMENTS_PART}" "--stringparam default-timestamp \"${CURRENT_TIMESTAMP}\"" "" "${ENABLE_XSLT_PROFILING}"; then
  __loge "Comments CSV file was not created: ${OUTPUT_COMMENTS_PART}"
  __log_finish
  return 1
 fi

 # Process text comments
 __logd "Processing text comments with robust XSLT processor: ${XSLT_TEXT_FILE_LOCAL} -> ${OUTPUT_TEXT_PART}"
 if ! __process_xml_with_xslt_robust "${XML_PART}" "${XSLT_TEXT_FILE_LOCAL}" "${OUTPUT_TEXT_PART}" "--stringparam default-timestamp \"${CURRENT_TIMESTAMP}\"" "" "${ENABLE_XSLT_PROFILING}"; then
  __loge "Text comments CSV file was not created: ${OUTPUT_TEXT_PART}"
  __log_finish
  return 1
 fi

 # Add part_id to the end of each line for notes
 __logd "Adding part_id ${PART_NUM} to notes CSV"
 awk -v part_id="${PART_NUM}" '{print $0 "," part_id}' "${OUTPUT_NOTES_PART}" > "${OUTPUT_NOTES_PART}.tmp" && mv "${OUTPUT_NOTES_PART}.tmp" "${OUTPUT_NOTES_PART}"

 # Add part_id to the end of each line for comments
 __logd "Adding part_id ${PART_NUM} to comments CSV"
 awk -v part_id="${PART_NUM}" '{print $0 "," part_id}' "${OUTPUT_COMMENTS_PART}" > "${OUTPUT_COMMENTS_PART}.tmp" && mv "${OUTPUT_COMMENTS_PART}.tmp" "${OUTPUT_COMMENTS_PART}"

 # Add part_id to the end of each line for text comments
 __logd "Adding part_id ${PART_NUM} to text comments CSV"
 awk -v part_id="${PART_NUM}" '{print $0 "," part_id}' "${OUTPUT_TEXT_PART}" > "${OUTPUT_TEXT_PART}.tmp" && mv "${OUTPUT_TEXT_PART}.tmp" "${OUTPUT_TEXT_PART}"

 __logi "API XML part ${PART_NUM} processing completed successfully."
 __logd "Output files:"
 __logd "  Notes: ${OUTPUT_NOTES_PART}"
 __logd "  Comments: ${OUTPUT_COMMENTS_PART}"
 __logd "  Text: ${OUTPUT_TEXT_PART}"
 __log_finish
}

# Process Planet XML part (consolidated version)
# Parameters:
#   $1: XML part file path
#   $2: XSLT notes file (optional, uses global if not provided)
#   $3: XSLT comments file (optional, uses global if not provided)
#   $4: XSLT text comments file (optional, uses global if not provided)
# Returns: 0 on success, 1 on failure
function __processPlanetXmlPart() {
 __log_start
 local XML_PART="${1}"
 local XSLT_NOTES_FILE_LOCAL="${2:-${XSLT_NOTES_PLANET_FILE}}"
 local XSLT_COMMENTS_FILE_LOCAL="${3:-${XSLT_NOTE_COMMENTS_PLANET_FILE}}"
 local XSLT_TEXT_FILE_LOCAL="${4:-${XSLT_TEXT_COMMENTS_PLANET_FILE}}"
 local PART_NUM
 local BASENAME_PART

 __logi "=== STARTING PLANET XML PART PROCESSING ==="
 __logd "Input XML part: ${XML_PART}"
 __logd "XSLT files:"
 __logd "  Notes: ${XSLT_NOTES_FILE_LOCAL}"
 __logd "  Comments: ${XSLT_COMMENTS_FILE_LOCAL}"
 __logd "  Text: ${XSLT_TEXT_FILE_LOCAL}"

 BASENAME_PART=$(basename "${XML_PART}" .xml)
 # Extract part number from planet_part_X.xml
 if [[ "${BASENAME_PART}" =~ ^planet_part_([0-9]+)$ ]]; then
  PART_NUM="${BASH_REMATCH[1]}"
 else
  __loge "Invalid filename format: '${BASENAME_PART}'. Expected: planet_part_X.xml"
  __log_finish
  return 1
 fi

 # Validate part number
 if [[ -z "${PART_NUM}" ]] || [[ ! "${PART_NUM}" =~ ^[0-9]+$ ]]; then
  __loge "Invalid part number extracted: '${PART_NUM}' from file: ${XML_PART}"
  __log_finish
  return 1
 fi

 __logi "Processing Planet XML part ${PART_NUM}: ${XML_PART}"

 # Convert XML part to CSV using XSLT
 local OUTPUT_NOTES_PART
 local OUTPUT_COMMENTS_PART
 local OUTPUT_TEXT_PART
 OUTPUT_NOTES_PART="${TMP_DIR}/output-notes-part-${PART_NUM}.csv"
 OUTPUT_COMMENTS_PART="${TMP_DIR}/output-comments-part-${PART_NUM}.csv"
 OUTPUT_TEXT_PART="${TMP_DIR}/output-text-part-${PART_NUM}.csv"

 # Generate current timestamp for XSLT processing
 local CURRENT_TIMESTAMP
 CURRENT_TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
 __logd "Using timestamp for XSLT processing: ${CURRENT_TIMESTAMP}"

 # Process notes
 __logd "Processing notes with robust XSLT processor: ${XSLT_NOTES_FILE_LOCAL} -> ${OUTPUT_NOTES_PART}"
 if ! __process_xml_with_xslt_robust "${XML_PART}" "${XSLT_NOTES_FILE_LOCAL}" "${OUTPUT_NOTES_PART}" "--stringparam default-timestamp \"${CURRENT_TIMESTAMP}\"" "" "${ENABLE_XSLT_PROFILING}"; then
  __loge "Notes CSV file was not created: ${OUTPUT_NOTES_PART}"
  __log_finish
  return 1
 fi

 # Process comments
 __logd "Processing comments with robust XSLT processor: ${XSLT_COMMENTS_FILE_LOCAL} -> ${OUTPUT_COMMENTS_PART}"
 if ! __process_xml_with_xslt_robust "${XML_PART}" "${XSLT_COMMENTS_FILE_LOCAL}" "${OUTPUT_COMMENTS_PART}" "--stringparam default-timestamp \"${CURRENT_TIMESTAMP}\"" "" "${ENABLE_XSLT_PROFILING}"; then
  __loge "Comments CSV file was not created: ${OUTPUT_COMMENTS_PART}"
  __log_finish
  return 1
 fi

 # Process text comments
 __logd "Processing text comments with robust XSLT processor: ${XSLT_TEXT_FILE_LOCAL} -> ${OUTPUT_TEXT_PART}"
 if ! __process_xml_with_xslt_robust "${XML_PART}" "${XSLT_TEXT_FILE_LOCAL}" "${OUTPUT_TEXT_PART}" "--stringparam default-timestamp \"${CURRENT_TIMESTAMP}\"" "" "${ENABLE_XSLT_PROFILING}"; then
  __loge "Text comments CSV file was not created: ${OUTPUT_TEXT_PART}"
  __log_finish
  return 1
 fi

 # Add part_id to the end of each line for notes
 __logd "Adding part_id ${PART_NUM} to notes CSV"
 awk -v part_id="${PART_NUM}" '{print $0 "," part_id}' "${OUTPUT_NOTES_PART}" > "${OUTPUT_NOTES_PART}.tmp" && mv "${OUTPUT_NOTES_PART}.tmp" "${OUTPUT_NOTES_PART}"

 # Add part_id to the end of each line for comments
 __logd "Adding part_id ${PART_NUM} to comments CSV"
 awk -v part_id="${PART_NUM}" '{print $0 "," part_id}' "${OUTPUT_COMMENTS_PART}" > "${OUTPUT_COMMENTS_PART}.tmp" && mv "${OUTPUT_COMMENTS_PART}.tmp" "${OUTPUT_COMMENTS_PART}"

 # Add part_id to the end of each line for text comments
 __logd "Adding part_id ${PART_NUM} to text comments CSV"
 awk -v part_id="${PART_NUM}" '{print $0 "," part_id}' "${OUTPUT_TEXT_PART}" > "${OUTPUT_TEXT_PART}.tmp" && mv "${OUTPUT_TEXT_PART}.tmp" "${OUTPUT_TEXT_PART}"

 __logi "Planet XML part ${PART_NUM} processing completed successfully."
 __logd "Output files:"
 __logd "  Notes: ${OUTPUT_NOTES_PART}"
 __logd "  Comments: ${OUTPUT_COMMENTS_PART}"
 __logd "  Text: ${OUTPUT_TEXT_PART}"
 __log_finish
}

# Analyze XSLT performance profile for optimization insights
# Parameters:
#   $1: Profile file path
#   $2: Output format (optional: "summary", "detailed", "csv", default: "summary")
# Returns: 0 on success, 1 on failure
function __analyze_xslt_profile() {
 __log_start
 local PROFILE_FILE="${1}"
 local OUTPUT_FORMAT="${2:-summary}"

 if [[ ! -f "${PROFILE_FILE}" ]]; then
  __loge "ERROR: Profile file not found: ${PROFILE_FILE}"
  __log_finish
  return 1
 fi

 __logd "Analyzing XSLT performance profile: ${PROFILE_FILE}"
 __logd "Output format: ${OUTPUT_FORMAT}"

 # Parse profile file and extract key metrics
 local TOTAL_TIME=0
 local TEMPLATE_COUNT=0
 local SLOWEST_TEMPLATE=""
 local SLOWEST_TIME=0

 # Read profile file and extract timing information
 while IFS= read -r LINE; do
  # Parse xsltproc profile format: "    0                    /                                    1     16     16"
  if [[ "${LINE}" =~ ^[[:space:]]*([0-9]+)[[:space:]]+([^[:space:]]+)[[:space:]]+([0-9]+)[[:space:]]+([0-9]+)[[:space:]]+([0-9]+)$ ]]; then
   local TEMPLATE_INDEX="${BASH_REMATCH[1]}"
   local TEMPLATE_NAME="${BASH_REMATCH[2]}"
   local CALLS="${BASH_REMATCH[3]}"
   local TOTAL_TIME_100US="${BASH_REMATCH[4]}"
   local AVG_TIME_100US="${BASH_REMATCH[5]}"

   # Convert from 100us units to seconds
   local TIME_SEC
   TIME_SEC=$(echo "scale=6; ${TOTAL_TIME_100US} * 100 / 1000000" | bc -l 2> /dev/null || echo "0")

   TOTAL_TIME=$(echo "${TOTAL_TIME} + ${TIME_SEC}" | bc -l 2> /dev/null || echo "${TOTAL_TIME}")
   ((TEMPLATE_COUNT++))

   if (($(echo "${TIME_SEC} > ${SLOWEST_TIME}" | bc -l 2> /dev/null || echo "0"))); then
    SLOWEST_TIME="${TIME_SEC}"
    SLOWEST_TEMPLATE="${TEMPLATE_NAME}"
   fi
  fi
 done < "${PROFILE_FILE}"

 # Generate output based on format
 case "${OUTPUT_FORMAT}" in
 "summary")
  __logi "=== XSLT PERFORMANCE PROFILE SUMMARY ==="
  __logi "Total processing time: ${TOTAL_TIME}s"
  __logi "Templates executed: ${TEMPLATE_COUNT}"
  __logi "Slowest template: ${SLOWEST_TEMPLATE} (${SLOWEST_TIME}s)"
  __logi "Average time per template: $(echo "scale=3; ${TOTAL_TIME} / ${TEMPLATE_COUNT}" | bc -l 2> /dev/null || echo "0")s"
  ;;
 "detailed")
  __logi "=== XSLT PERFORMANCE PROFILE DETAILED ==="
  __logi "Total processing time: ${TOTAL_TIME}s"
  __logi "Templates executed: ${TEMPLATE_COUNT}"
  __logi "Slowest template: ${SLOWEST_TEMPLATE} (${SLOWEST_TIME}s)"
  __logi "Profile file: ${PROFILE_FILE}"
  __logd "Use 'cat ${PROFILE_FILE}' for full details"
  ;;
 "csv")
  echo "total_time,template_count,slowest_template,slowest_time"
  echo "${TOTAL_TIME},${TEMPLATE_COUNT},\"${SLOWEST_TEMPLATE}\",${SLOWEST_TIME}"
  ;;
 *)
  __loge "ERROR: Invalid output format: ${OUTPUT_FORMAT}"
  __log_finish
  return 1
  ;;
 esac

 __log_finish
 return 0
}

# Generate performance report from multiple profile files
# Parameters:
#   $1: Directory containing profile files
#   $2: Output report file (optional)
# Returns: 0 on success, 1 on failure
function __generate_performance_report() {
 __log_start
 local PROFILE_DIR="${1}"
 local REPORT_FILE="${2:-}"

 if [[ ! -d "${PROFILE_DIR}" ]]; then
  __loge "ERROR: Profile directory not found: ${PROFILE_DIR}"
  __log_finish
  return 1
 fi

 # Find all profile files
 local PROFILE_FILES
 mapfile -t PROFILE_FILES < <(find "${PROFILE_DIR}" -name "*.profile" -type f | sort || true)

 if [[ ${#PROFILE_FILES[@]} -eq 0 ]]; then
  __logw "WARNING: No profile files found in ${PROFILE_DIR}"
  __log_finish
  return 0
 fi

 __logi "Found ${#PROFILE_FILES[@]} profile files for analysis"

 # Generate report
 if [[ -n "${REPORT_FILE}" ]]; then
  # Write to file
  {
   echo "XSLT Performance Report - Generated: $(date)"
   echo "================================================"
   echo ""

   for PROFILE in "${PROFILE_FILES[@]}"; do
    echo "File: $(basename "${PROFILE}")"
    echo "----------------------------------------"
    __analyze_xslt_profile "${PROFILE}" "summary" | grep -E "^(Total|Templates|Slowest|Average)" || true
    echo ""
   done
  } > "${REPORT_FILE}"

  __logi "Performance report saved to: ${REPORT_FILE}"
 else
  # Display on console
  for PROFILE in "${PROFILE_FILES[@]}"; do
   __logi "=== $(basename "${PROFILE}") ==="
   __analyze_xslt_profile "${PROFILE}" "summary"
   echo ""
  done
 fi

 __log_finish
 return 0
}
