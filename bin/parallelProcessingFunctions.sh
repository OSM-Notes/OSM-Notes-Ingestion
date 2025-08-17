#!/bin/bash
# Consolidated Parallel Processing Functions for OSM-Notes-profile
# This file consolidates all parallel processing functions to eliminate duplication
#
# Author: Andres Gomez (AngocA)
# Version: 2025-08-17
# Description: Centralized parallel processing functions with resource management and retry logic

# Load properties to ensure all required variables are available
# Only load production properties if we're not in a test environment
if [[ -z "${BATS_TEST_DIRNAME:-}" ]] && [[ -f "${SCRIPT_BASE_DIRECTORY:-.}/etc/properties.sh" ]]; then
 source "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh"
elif [[ -z "${BATS_TEST_DIRNAME:-}" ]] && [[ -f "./etc/properties.sh" ]]; then
 source "./etc/properties.sh"
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
if [[ -z "${MAX_MEMORY_PERCENT:-}" ]]; then
 declare -r MAX_MEMORY_PERCENT=80
fi
if [[ -z "${MAX_LOAD_AVERAGE:-}" ]]; then
 declare -r MAX_LOAD_AVERAGE=2.0
fi
if [[ -z "${PROCESS_TIMEOUT:-}" ]]; then
 declare -r PROCESS_TIMEOUT=300
fi
# MAX_RETRIES is already declared in functionsProcess.sh
if [[ -z "${MAX_RETRIES:-}" ]]; then
 declare -r MAX_RETRIES=3
fi
if [[ -z "${RETRY_DELAY:-}" ]]; then
 declare -r RETRY_DELAY=5
fi

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
   if [[ $(echo "${CURRENT_LOAD} > ${MAX_LOAD_AVERAGE}" | bc -l 2> /dev/null || echo "0") == "1" ]]; then
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
#   $2: Processing type (optional, for XML-specific adjustments)
# Returns: Adjusted number of workers
function __adjust_workers_for_resources() {
 # Redirect logging to stderr to avoid interfering with stdout
 __log_start >&2
 local REQUESTED_WORKERS="${1:-4}"
 local PROCESSING_TYPE="${2:-}"
 local ADJUSTED_WORKERS="${REQUESTED_WORKERS}"
 local MEMORY_PERCENT

 # XML-specific adjustment: reduce by 2 threads for XML processing to prevent system overload
 if [[ "${PROCESSING_TYPE}" == "XML" ]] && [[ ${REQUESTED_WORKERS} -gt 2 ]]; then
  ADJUSTED_WORKERS=$((REQUESTED_WORKERS - 2))
  __logw "Reducing XML processing workers from ${REQUESTED_WORKERS} to ${ADJUSTED_WORKERS} to prevent system overload" >&2
 fi

 # Check memory and reduce workers if needed
 if command -v free > /dev/null 2>&1; then
  MEMORY_PERCENT=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}' || true)
  if [[ "${MEMORY_PERCENT}" -gt 70 ]]; then
   ADJUSTED_WORKERS=$((ADJUSTED_WORKERS / 2))
   __logw "Reducing workers to ${ADJUSTED_WORKERS} due to high memory usage (${MEMORY_PERCENT}%)" >&2
  elif [[ "${MEMORY_PERCENT}" -gt 50 ]]; then
   ADJUSTED_WORKERS=$((ADJUSTED_WORKERS * 3 / 4))
   __logw "Reducing workers to ${ADJUSTED_WORKERS} due to moderate memory usage (${MEMORY_PERCENT}%)" >&2
  fi
 fi

 # Ensure minimum workers
 if [[ ${ADJUSTED_WORKERS} -lt 1 ]]; then
  ADJUSTED_WORKERS=1
 fi

 __logd "Adjusted workers from ${REQUESTED_WORKERS} to ${ADJUSTED_WORKERS}" >&2
 __log_finish >&2
 # Output only the numeric result to stdout
 printf "%d\n" "${ADJUSTED_WORKERS}"
}

# Adjust process delay based on system resources
# Returns: Adjusted delay in seconds
function __adjust_process_delay() {
 # Use warning level logging to ensure output goes to stderr
 __logw "Starting process delay adjustment"
 # Use a different variable name to avoid readonly conflicts
 local ADJUSTED_DELAY="${PARALLEL_PROCESS_DELAY}"
 local MEMORY_PERCENT

 # Check memory and increase delay if needed
 if command -v free > /dev/null 2>&1; then
  MEMORY_PERCENT=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}' || true)
  if [[ "${MEMORY_PERCENT}" -gt 70 ]]; then
   ADJUSTED_DELAY=$((ADJUSTED_DELAY * 3))
   __logw "Increased process delay to ${ADJUSTED_DELAY}s due to high memory usage (${MEMORY_PERCENT}%)" >&2
  elif [[ "${MEMORY_PERCENT}" -gt 50 ]]; then
   ADJUSTED_DELAY=$((ADJUSTED_DELAY * 2))
   __logw "Increased process delay to ${ADJUSTED_DELAY}s due to moderate memory usage (${MEMORY_PERCENT}%)" >&2
  fi
 fi

 # Check system load and adjust delay
 if command -v uptime > /dev/null 2>&1; then
  local CURRENT_LOAD
  CURRENT_LOAD=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//' || true)
  if [[ -n "${CURRENT_LOAD}" ]] && [[ "${CURRENT_LOAD}" != "0.00" ]]; then
   if [[ $(echo "${CURRENT_LOAD} > ${MAX_LOAD_AVERAGE}" | bc -l 2> /dev/null || echo "0") == "1" ]]; then
    ADJUSTED_DELAY=$((ADJUSTED_DELAY * 2))
    __logw "Increased process delay to ${ADJUSTED_DELAY}s due to high system load (${CURRENT_LOAD})" >&2
   fi
  fi
 fi

 # Ensure reasonable delay limits
 if [[ ${ADJUSTED_DELAY} -gt 10 ]]; then
  ADJUSTED_DELAY=10
  __logw "Capped process delay at 10s for reasonable performance" >&2
 fi

 __logw "Adjusted process delay from ${PARALLEL_PROCESS_DELAY}s to ${ADJUSTED_DELAY}s"
 __logw "Finished process delay adjustment"
 # Output only the numeric result to stdout
 printf "%d\n" "${ADJUSTED_DELAY}"
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

# Process XML with XSLT using robust error handling and retry logic
# Parameters:
#   $1: XML file path
#   $2: XSLT file path
#   $3: Output file path
#   $4: XSLT parameter type (e.g., "--stringparam")
#   $5: XSLT parameter name (e.g., "default-timestamp")
#   $6: XSLT parameter value (e.g., timestamp string)
#   $7: Enable profiling (optional, default: false)
# Returns: 0 on success, 1 on failure
function __process_xml_with_xslt_robust() {
 __log_start
 __logd "Function called with $# parameters: '$1' '$2' '$3' '$4' '$5' '$6' '$7'"
 local XML_FILE="${1}"
 local XSLT_FILE="${2}"
 local OUTPUT_FILE="${3}"
 local XSLT_PARAM_TYPE="${4:-}"
 local XSLT_PARAM_NAME="${5:-}"
 local XSLT_PARAM_VALUE="${6:-}"
 local ENABLE_PROFILING="${7:-false}"
 local TIMEOUT="${PROCESS_TIMEOUT:-300}"
 __logd "ENABLE_PROFILING parameter received: '${ENABLE_PROFILING}'"
 __logd "All parameters received: XML='${1}', XSLT='${2}', OUTPUT='${3}', PARAM_TYPE='${4}', PARAM_NAME='${5}', PARAM_VALUE='${6}', PROFILING='${7}'"
 __logd "Using default timeout: ${TIMEOUT}s"
 local RETRY_COUNT=0
 local SUCCESS=false

 # Build XSLT parameters array
 local XSLT_ARGS=()
 if [[ -n "${XSLT_PARAM_TYPE}" ]] && [[ -n "${XSLT_PARAM_NAME}" ]] && [[ -n "${XSLT_PARAM_VALUE}" ]]; then
  XSLT_ARGS=("${XSLT_PARAM_TYPE}" "${XSLT_PARAM_NAME}" "${XSLT_PARAM_VALUE}")
  __logd "Built XSLT parameters: ${XSLT_ARGS[*]}"
 fi

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

 # Lightweight XML validation using grep instead of xmllint
 __logd "Performing lightweight XML validation before XSLT processing..."

 # Check if XML file contains expected content
 if ! grep -q "<note" "${XML_FILE}" 2> /dev/null; then
  __loge "ERROR: XML file does not contain expected note elements: ${XML_FILE}"
  __log_finish
  return 1
 fi

 # Check if XSLT file contains expected content
 if ! grep -q "xsl:stylesheet" "${XSLT_FILE}" 2> /dev/null; then
  __loge "ERROR: XSLT file does not contain expected stylesheet elements: ${XSLT_FILE}"
  __log_finish
  return 1
 fi

 # Check if XML file is not empty
 if [[ ! -s "${XML_FILE}" ]]; then
  __loge "ERROR: XML file is empty: ${XML_FILE}"
  __log_finish
  return 1
 fi

 # Check if XSLT file is not empty
 if [[ ! -s "${XSLT_FILE}" ]]; then
  __loge "ERROR: XSLT file is empty: ${XSLT_FILE}"
  __log_finish
  return 1
 fi

 # Check if XML file has minimum size (at least 100 bytes)
 local XML_SIZE
 XML_SIZE=$(stat -c%s "${XML_FILE}" 2> /dev/null || stat -f%z "${XML_FILE}" 2>&1 || echo "0")
 if [[ "${XML_SIZE}" -lt 100 ]]; then
  __loge "ERROR: XML file is too small (${XML_SIZE} bytes), expected at least 100 bytes: ${XML_FILE}"
  __log_finish
  return 1
 fi

 # Check if XSLT file has minimum size (at least 50 bytes)
 local XSLT_SIZE
 XSLT_SIZE=$(stat -c%s "${XSLT_FILE}" 2> /dev/null || stat -f%z "${XSLT_FILE}" 2>&1 || echo "0")
 if [[ "${XSLT_SIZE}" -lt 50 ]]; then
  __loge "ERROR: XSLT file is too small (${XSLT_SIZE} bytes), expected at least 50 bytes: ${XSLT_FILE}"
  __log_finish
  return 1
 fi

 # Check if XML file has correct format (contains XML declaration and root element)
 if ! head -n 5 "${XML_FILE}" | grep -q "<?xml" 2> /dev/null; then
  __loge "ERROR: XML file does not contain XML declaration: ${XML_FILE}"
  __log_finish
  return 1
 fi

 # Check if XSLT file has correct format (contains stylesheet declaration)
 if ! head -n 10 "${XSLT_FILE}" | grep -q "xsl:stylesheet" 2> /dev/null; then
  __loge "ERROR: XSLT file does not contain stylesheet declaration: ${XSLT_FILE}"
  __log_finish
  return 1
 fi

 # Check if XML file contains expected root element
 if ! grep -q "<osm-notes\|<osm" "${XML_FILE}" 2> /dev/null; then
  __loge "ERROR: XML file does not contain expected root element (<osm-notes> or <osm>): ${XML_FILE}"
  __log_finish
  return 1
 fi

 # Check if XSLT file contains expected template
 if ! grep -q "xsl:template" "${XSLT_FILE}" 2> /dev/null; then
  __loge "ERROR: XSLT file does not contain expected template elements: ${XSLT_FILE}"
  __log_finish
  return 1
 fi

 # Check if XSLT file contains expected output method
 if ! grep -q "method=\"text\"" "${XSLT_FILE}" 2> /dev/null; then
  __loge "ERROR: XSLT file does not contain expected output method (text): ${XSLT_FILE}"
  __log_finish
  return 1
 fi

 # Check if XSLT file contains expected parameter
 if ! grep -q "xsl:param.*default-timestamp" "${XSLT_FILE}" 2> /dev/null; then
  __loge "ERROR: XSLT file does not contain expected parameter (default-timestamp): ${XSLT_FILE}"
  __log_finish
  return 1
 fi

 # Check if XML file contains at least one note element
 local NOTE_COUNT
 NOTE_COUNT=$(grep -c "<note" "${XML_FILE}" 2> /dev/null || echo "0")
 if [[ "${NOTE_COUNT}" -eq 0 ]]; then
  __loge "ERROR: XML file does not contain any note elements: ${XML_FILE}"
  __log_finish
  return 1
 fi

 __logd "File validation passed: XML='${XML_FILE}', XSLT='${XSLT_FILE}' (${NOTE_COUNT} notes found)"

 # Create output directory if it doesn't exist
 local OUTPUT_DIR
 OUTPUT_DIR=$(dirname "${OUTPUT_FILE}")
 mkdir -p "${OUTPUT_DIR}"

 # Verify output directory is writable
 if [[ ! -w "${OUTPUT_DIR}" ]]; then
  __loge "ERROR: Output directory is not writable: ${OUTPUT_DIR}"
  __log_finish
  return 1
 fi

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
  __logd "About to check ENABLE_PROFILING: '${ENABLE_PROFILING}' (type: $(declare -p ENABLE_PROFILING 2> /dev/null || echo 'not declared'))"

  # Simplified logging to avoid syntax issues
  if [[ "${ENABLE_PROFILING}" == "true" ]]; then
   __logd "ENABLE_PROFILING is enabled"
  else
   __logd "ENABLE_PROFILING is disabled"
  fi

  if [[ "${ENABLE_PROFILING}" == "true" ]]; then
   local PROFILE_FILE
   PROFILE_FILE="${OUTPUT_FILE}.profile"
   __logd "Profiling enabled, profile will be saved to: ${PROFILE_FILE}"
   __logd "ENABLE_PROFILING value: '${ENABLE_PROFILING}'"

   if [[ -n "${XSLT_PARAM_TYPE}" ]] && [[ -n "${XSLT_PARAM_NAME}" ]] && [[ -n "${XSLT_PARAM_VALUE}" ]]; then
    local XSLT_ERROR_OUTPUT
    XSLT_ERROR_OUTPUT=$(timeout "${TIMEOUT}" xsltproc --profile "${XSLT_ARGS[@]}" -o "${OUTPUT_FILE}" "${XSLT_FILE}" "${XML_FILE}" 2> "${PROFILE_FILE}")
    local EXIT_CODE=$?
    if [[ ${EXIT_CODE} -eq 0 ]]; then
     if [[ -f "${OUTPUT_FILE}" ]]; then
      SUCCESS=true
      __logd "XSLT processing successful on attempt ${RETRY_COUNT}"
     else
      __loge "XSLT processing completed but output file not created"
     fi
    else
     if [[ ${EXIT_CODE} -eq 124 ]]; then
      __loge "XSLT processing timed out after ${TIMEOUT}s"
     else
      __loge "XSLT processing failed with exit code: ${EXIT_CODE}"
      __loge "XSLT error output: ${XSLT_ERROR_OUTPUT}"
     fi
    fi
   else
    local XSLT_ERROR_OUTPUT
    XSLT_ERROR_OUTPUT=$(timeout "${TIMEOUT}" xsltproc --profile -o "${OUTPUT_FILE}" "${XSLT_FILE}" "${XML_FILE}" 2> "${PROFILE_FILE}")
    local EXIT_CODE=$?
    if [[ ${EXIT_CODE} -eq 0 ]]; then
     if [[ -f "${OUTPUT_FILE}" ]]; then
      SUCCESS=true
      __logd "XSLT processing successful on attempt ${RETRY_COUNT}"
     else
      __loge "XSLT processing completed but output file not created"
     fi
    else
     if [[ ${EXIT_CODE} -eq 124 ]]; then
      __loge "XSLT processing timed out after ${TIMEOUT}s"
     else
      __loge "XSLT processing failed with exit code: ${EXIT_CODE}"
      __loge "XSLT error output: ${XSLT_ERROR_OUTPUT}"
     fi
    fi
   fi
  else
   if [[ -n "${XSLT_PARAM_TYPE}" ]] && [[ -n "${XSLT_PARAM_NAME}" ]] && [[ -n "${XSLT_PARAM_VALUE}" ]]; then
    local XSLT_ERROR_OUTPUT
    XSLT_ERROR_OUTPUT=$(timeout "${TIMEOUT}" xsltproc "${XSLT_ARGS[@]}" -o "${OUTPUT_FILE}" "${XSLT_FILE}" "${XML_FILE}" 2>&1)
    local EXIT_CODE=$?
    if [[ ${EXIT_CODE} -eq 0 ]]; then
     if [[ -f "${OUTPUT_FILE}" ]]; then
      SUCCESS=true
      __logd "XSLT processing successful on attempt ${RETRY_COUNT}"
     else
      __loge "XSLT processing completed but output file not created"
     fi
    else
     if [[ ${EXIT_CODE} -eq 124 ]]; then
      __loge "XSLT processing timed out after ${TIMEOUT}s"
     else
      __loge "XSLT processing failed with exit code: ${EXIT_CODE}"
      __loge "XSLT error output: ${XSLT_ERROR_OUTPUT}"
     fi
    fi
   else
    local XSLT_ERROR_OUTPUT
    XSLT_ERROR_OUTPUT=$(timeout "${TIMEOUT}" xsltproc -o "${OUTPUT_FILE}" "${XSLT_FILE}" "${XML_FILE}" 2>&1)
    local EXIT_CODE=$?
    if [[ ${EXIT_CODE} -eq 0 ]]; then
     if [[ -f "${OUTPUT_FILE}" ]]; then
      SUCCESS=true
      __logd "XSLT processing successful on attempt ${RETRY_COUNT}"
     else
      __loge "XSLT processing completed but output file not created"
     fi
    else
     if [[ ${EXIT_CODE} -eq 124 ]]; then
      __loge "XSLT processing timed out after ${TIMEOUT}s"
     else
      __loge "XSLT processing failed with exit code: ${EXIT_CODE}"
      __loge "XSLT error output: ${XSLT_ERROR_OUTPUT}"
     fi
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

# Optimized XML file division function
# Version: 2025-08-17
__divide_xml_file() {
 # Function: Divides a large XML file into smaller parts for parallel processing
 # Parameters:
 #   $1: Input XML file path
 #   $2: Output directory for parts
 #   $3: Target part size in MB (default: 100)
 #   $4: Maximum number of parts (default: 50)
 #   $5: Maximum threads for parallel processing (default: 8)
 # Returns: 0 on success, 1 on failure

 local INPUT_XML="${1}"
 local OUTPUT_DIR="${2}"
 local TARGET_PART_SIZE_MB="${3:-100}"
 local NUM_PARTS="${4:-50}"
 local MAX_THREADS="${5:-8}"

 # Validate inputs
 if [[ -z "${INPUT_XML}" ]] || [[ -z "${OUTPUT_DIR}" ]]; then
  __loge "ERROR: Input XML file and output directory are required"
  return 1
 fi

 if [[ ! -f "${INPUT_XML}" ]]; then
  __loge "ERROR: Input XML file does not exist: ${INPUT_XML}"
  return 1
 fi

 if [[ ! -d "${OUTPUT_DIR}" ]]; then
  __loge "ERROR: Output directory does not exist: ${OUTPUT_DIR}"
  return 1
 fi

 # Start logging and timing
 __log_start "Dividing XML file: ${INPUT_XML}"
 local START_TIME
 START_TIME=$(date +%s)

 # Clean up any existing parts
 find "${OUTPUT_DIR}" -name "planet_part_*.xml" -delete 2> /dev/null || true
 find "${OUTPUT_DIR}" -name "api_part_*.xml" -delete 2> /dev/null || true
 __logd "Cleaned up existing parts"

 # Detect XML format (Planet vs API)
 local XML_FORMAT=""
 local ROOT_TAG=""
 local PART_PREFIX=""

 if grep -q "<osm-notes" "${INPUT_XML}" 2> /dev/null; then
  XML_FORMAT="Planet"
  ROOT_TAG="osm-notes"
  PART_PREFIX="planet_part"
  __logd "Detected Planet XML format (osm-notes)"
 elif grep -q "<osm[[:space:]]" "${INPUT_XML}" 2> /dev/null; then
  XML_FORMAT="API"
  ROOT_TAG="osm"
  PART_PREFIX="api_part"
  __logd "Detected API XML format (osm)"
 else
  __loge "ERROR: Unknown XML format. Expected <osm-notes> (Planet) or <osm> (API)"
  __log_finish
  return 1
 fi

 # Get file size and total notes
 local FILE_SIZE_BYTES
 FILE_SIZE_BYTES=$(stat -c%s "${INPUT_XML}" 2> /dev/null || echo "0")
 local TOTAL_NOTES
 TOTAL_NOTES=$(grep -c "<note" "${INPUT_XML}" 2> /dev/null || echo "0")

 # Ensure TOTAL_NOTES is a valid number
 if [[ ! "${TOTAL_NOTES}" =~ ^[0-9]+$ ]]; then
  TOTAL_NOTES=0
 fi

 if [[ "${TOTAL_NOTES}" -eq 0 ]]; then
  __loge "ERROR: No notes found in XML file or file is not valid"
  __log_finish
  return 1
 fi

 # Ensure FILE_SIZE_BYTES is a valid number
 if [[ ! "${FILE_SIZE_BYTES}" =~ ^[0-9]+$ ]]; then
  FILE_SIZE_BYTES=0
 fi

 if [[ "${FILE_SIZE_BYTES}" -eq 0 ]]; then
  __loge "ERROR: Cannot determine file size"
  __log_finish
  return 1
 fi

 # Calculate optimal parts based on target size and performance considerations
 local FILE_SIZE_MB
 FILE_SIZE_MB=$((FILE_SIZE_BYTES / 1024 / 1024))
 local SIZE_BASED_PARTS
 SIZE_BASED_PARTS=$((FILE_SIZE_MB / TARGET_PART_SIZE_MB))

 # Calculate performance-optimized number of parts
 # For large files, we want fewer, larger parts to improve processing speed
 local PERFORMANCE_OPTIMIZED_PARTS
 if [[ ${FILE_SIZE_MB} -gt 5000 ]]; then
  # For files > 5GB, use very large parts (very few parts)
  PERFORMANCE_OPTIMIZED_PARTS=$((FILE_SIZE_MB / 500)) # ~500MB per part
  __logd "Extremely large file detected (${FILE_SIZE_MB} MB), optimizing for maximum performance with ~500MB parts"
 elif [[ ${FILE_SIZE_MB} -gt 1000 ]]; then
  # For files > 1GB, use larger parts (fewer parts)
  PERFORMANCE_OPTIMIZED_PARTS=$((FILE_SIZE_MB / 200)) # ~200MB per part
  __logd "Large file detected (${FILE_SIZE_MB} MB), optimizing for performance with ~200MB parts"
 elif [[ ${FILE_SIZE_MB} -gt 100 ]]; then
  # For files > 100MB, use medium parts
  PERFORMANCE_OPTIMIZED_PARTS=$((FILE_SIZE_MB / 100)) # ~100MB per part
  __logd "Medium file detected (${FILE_SIZE_MB} MB), using ~100MB parts"
 else
  # For smaller files, use requested size
  PERFORMANCE_OPTIMIZED_PARTS=${SIZE_BASED_PARTS}
 fi

 # Use the performance-optimized approach, but respect user limits
 # For large files, prefer performance optimization over user-specified parts
 if [[ ${FILE_SIZE_MB} -gt 1000 ]] && [[ ${PERFORMANCE_OPTIMIZED_PARTS} -lt ${NUM_PARTS} ]]; then
  # For large files, use performance-optimized parts if they result in fewer parts
  NUM_PARTS=${PERFORMANCE_OPTIMIZED_PARTS}
  __logd "Adjusted parts to ${NUM_PARTS} based on performance optimization for large file"
 elif [[ ${PERFORMANCE_OPTIMIZED_PARTS} -gt ${NUM_PARTS} ]]; then
  # For smaller files, use performance optimization if it results in more parts
  NUM_PARTS=${PERFORMANCE_OPTIMIZED_PARTS}
  __logd "Adjusted parts to ${NUM_PARTS} based on performance optimization"
 fi

 # Ensure reasonable limits for performance
 if [[ ${NUM_PARTS} -lt ${MAX_THREADS} ]]; then
  NUM_PARTS=${MAX_THREADS}
  __logd "Adjusted parts to minimum: ${NUM_PARTS} (MAX_THREADS)"
 fi
 if [[ ${NUM_PARTS} -gt 50 ]]; then
  NUM_PARTS=50
  __logw "Limited parts to maximum: ${NUM_PARTS} for optimal performance"
 fi

 # Calculate actual target part size based on final number of parts
 local ACTUAL_TARGET_PART_SIZE_MB
 ACTUAL_TARGET_PART_SIZE_MB=$((FILE_SIZE_MB / NUM_PARTS))

 __logi "Dividing ${XML_FORMAT} XML file: ${FILE_SIZE_MB} MB, ${TOTAL_NOTES} notes (max ${NUM_PARTS} parts)"
 __logd "Target part size: ~${ACTUAL_TARGET_PART_SIZE_MB} MB each (${FILE_SIZE_MB} MB ÷ ${NUM_PARTS} parts)"
 __logd "Root tag: <${ROOT_TAG}>, Part prefix: ${PART_PREFIX}"
 __logd "Note: Actual number of parts may be less than ${NUM_PARTS} depending on file size and content distribution"

 # Calculate notes per part
 local NOTES_PER_PART
 NOTES_PER_PART=$((TOTAL_NOTES / NUM_PARTS))

 # Only adjust if it's absolutely necessary
 if [[ ${NOTES_PER_PART} -eq 0 ]]; then
  NOTES_PER_PART=1
  NUM_PARTS=${TOTAL_NOTES}
  __logw "Adjusted to ${NUM_PARTS} parts with 1 note per part (no other option)"
 elif [[ ${NOTES_PER_PART} -eq 1 ]] && [[ ${TOTAL_NOTES} -gt ${NUM_PARTS} ]] && [[ $((TOTAL_NOTES - NUM_PARTS)) -gt 2 ]]; then
  # Only adjust if the difference is significant (more than 2)
  NUM_PARTS=${TOTAL_NOTES}
  __logw "Adjusted to ${NUM_PARTS} parts with 1 note per part (difference too large)"
 else
  # Keep the requested number of parts
  __logd "Maximum parts set to ${NUM_PARTS} with ~${NOTES_PER_PART} notes per part (actual parts may vary)"
 fi

 # Ensure we have at least 1 note per part
 if [[ ${NOTES_PER_PART} -lt 1 ]]; then
  NOTES_PER_PART=1
 fi

 __logd "Final: Notes per part: ${NOTES_PER_PART}, Maximum parts: ${NUM_PARTS}"

 # Use optimized approach: choose between line-by-line and block-based processing
 local PART_NUM=1
 local CURRENT_NOTES=0
 local PART_FILE=""
 local IN_NOTE=false
 local SKIP_HEADER=true
 local NOTES_PROCESSED=0
 # Buffer size for optimized processing (currently unused but reserved for future enhancements)

 # For very large files, use block-based processing for better performance
 local USE_BLOCK_PROCESSING=false
 local USE_POSITION_BASED=false

 if [[ ${FILE_SIZE_MB} -gt 5000 ]] && [[ ${TOTAL_NOTES} -gt 500000 ]]; then
  USE_POSITION_BASED=true
  __logd "Extremely large file detected (${FILE_SIZE_MB} MB, ${TOTAL_NOTES} notes), using position-based processing for maximum performance"
 elif [[ ${FILE_SIZE_MB} -gt 2000 ]] && [[ ${TOTAL_NOTES} -gt 100000 ]]; then
  USE_BLOCK_PROCESSING=true
  __logd "Very large file detected, using block-based processing for optimal performance"
 fi

 # Create first part file
 PART_FILE="${OUTPUT_DIR}/${PART_PREFIX}_$(printf "%03d" ${PART_NUM}).xml"
 echo '<?xml version="1.0" encoding="UTF-8"?>' > "${PART_FILE}"
 echo "<${ROOT_TAG}>" >> "${PART_FILE}"

 # Process XML using optimized method based on file size
 if [[ "${USE_POSITION_BASED}" == "true" ]]; then
  # Position-based processing for extremely large files (maximum performance)
  __logd "Using position-based processing for maximum performance"

  # Pre-calculate note positions for efficient splitting
  __logd "Pre-calculating note positions..."
  local NOTE_POSITIONS_FILE="${OUTPUT_DIR}/note_positions.txt"

  # Find all note start positions using grep and save to file
  grep -n "<note" "${INPUT_XML}" | cut -d: -f1 > "${NOTE_POSITIONS_FILE}"

  # Calculate optimal split points
  local NOTES_PER_PART_OPTIMIZED
  NOTES_PER_PART_OPTIMIZED=$((TOTAL_NOTES / NUM_PARTS))

  __logd "Splitting into ${NUM_PARTS} parts with ~${NOTES_PER_PART_OPTIMIZED} notes per part"

  # Process each part using pre-calculated positions
  local START_TIME
  START_TIME=$(date +%s)

  for ((PART_NUM = 1; PART_NUM <= NUM_PARTS; PART_NUM++)); do
   local PART_FILE="${OUTPUT_DIR}/${PART_PREFIX}_$(printf "%03d" ${PART_NUM}).xml"
   local START_LINE=1
   local END_LINE=${TOTAL_NOTES}

   # Calculate start and end positions for this part
   if [[ ${PART_NUM} -eq 1 ]]; then
    START_LINE=1
   else
    START_LINE=$(((PART_NUM - 1) * NOTES_PER_PART_OPTIMIZED + 1))
   fi

   if [[ ${PART_NUM} -eq ${NUM_PARTS} ]]; then
    END_LINE=${TOTAL_NOTES}
   else
    END_LINE=$((PART_NUM * NOTES_PER_PART_OPTIMIZED))
   fi

   # Get actual line numbers from positions file
   local START_POS
   START_POS=$(sed -n "${START_LINE}p" "${NOTE_POSITIONS_FILE}" 2> /dev/null || echo "1")
   local END_POS
   END_POS=$(sed -n "${END_LINE}p" "${NOTE_POSITIONS_FILE}" 2> /dev/null || echo "1")

   # Create part file
   echo '<?xml version="1.0" encoding="UTF-8"?>' > "${PART_FILE}"
   echo "<${ROOT_TAG}>" >> "${PART_FILE}"

   # Extract content between positions
   sed -n "${START_POS},${END_POS}p" "${INPUT_XML}" >> "${PART_FILE}"

   # Close part
   echo "</${ROOT_TAG}>" >> "${PART_FILE}"

   # Count actual notes in this part
   local PART_NOTES
   PART_NOTES=$(grep -c "<note" "${PART_FILE}" 2> /dev/null || echo "0")

   # Calculate and display progress
   local PROGRESS_PCT
   PROGRESS_PCT=$((PART_NUM * 100 / NUM_PARTS))
   local ELAPSED_TIME
   ELAPSED_TIME=$(($(date +%s) - START_TIME))
   local ESTIMATED_TOTAL
   ESTIMATED_TOTAL=$((ELAPSED_TIME * NUM_PARTS / PART_NUM))
   local REMAINING_TIME
   REMAINING_TIME=$((ESTIMATED_TOTAL - ELAPSED_TIME))

   __logd "Created position-based part ${PART_NUM}/${NUM_PARTS} (${PROGRESS_PCT}%): ${PART_FILE} (~${PART_NOTES} notes, lines ${START_POS}-${END_POS}) - ETA: ${REMAINING_TIME}s"
  done

  # Clean up positions file
  rm -f "${NOTE_POSITIONS_FILE}"

 elif [[ "${USE_BLOCK_PROCESSING}" == "true" ]]; then
  # Block-based processing for very large files
  __logd "Using block-based processing for optimal performance"

  # Calculate block size based on target part size
  local BLOCK_SIZE_BYTES
  BLOCK_SIZE_BYTES=$((TARGET_PART_SIZE_MB * 1024 * 1024))

  # Use dd to split file into blocks, then process each block
  # Block number counter (currently unused but reserved for future enhancements)
  local OFFSET=0
  local HEADER_SIZE=0

  # Find the start of the first note (skip header)
  HEADER_SIZE=$(grep -n "<note" "${INPUT_XML}" | head -1 | cut -d: -f1)
  if [[ -z "${HEADER_SIZE}" ]] || [[ "${HEADER_SIZE}" -eq "0" ]]; then
   HEADER_SIZE=0
  fi

  # Extract header content
  head -n $((HEADER_SIZE - 1)) "${INPUT_XML}" > "${OUTPUT_DIR}/header.xml"

  while [[ ${OFFSET} -lt ${FILE_SIZE_BYTES} ]]; do
   local PART_FILE="${OUTPUT_DIR}/${PART_PREFIX}_$(printf "%03d" ${PART_NUM}).xml"

   # Create part with header
   cat "${OUTPUT_DIR}/header.xml" > "${PART_FILE}"

   # Extract block and append to part
   dd if="${INPUT_XML}" of="${PART_FILE}" bs=1M skip=$((OFFSET / 1024 / 1024)) count=$((BLOCK_SIZE_BYTES / 1024 / 1024)) 2> /dev/null

   # Close part
   echo "</${ROOT_TAG}>" >> "${PART_FILE}"

   # Count notes in this part
   local PART_NOTES
   PART_NOTES=$(grep -c "<note" "${PART_FILE}" 2> /dev/null || echo "0")

   __logd "Created block part ${PART_NUM}: ${PART_FILE} (~${PART_NOTES} notes, ~${TARGET_PART_SIZE_MB} MB)"

   ((PART_NUM++))
   OFFSET=$((OFFSET + BLOCK_SIZE_BYTES))

   # Stop if we've reached the part limit
   if [[ ${PART_NUM} -gt ${NUM_PARTS} ]]; then
    break
   fi
  done

  # Clean up header file
  rm -f "${OUTPUT_DIR}/header.xml"

 else
  # Line-by-line processing for smaller files (original optimized approach)
  __logd "Using line-by-line processing"

  while IFS= read -r LINE; do
   # Skip XML header and root tags
   if [[ "${SKIP_HEADER}" == "true" ]]; then
    if [[ "${LINE}" =~ \<note ]]; then
     SKIP_HEADER=false
    else
     continue
    fi
   fi

   # Check if we're starting a new note
   if [[ "${LINE}" =~ \<note ]]; then
    IN_NOTE=true
    ((CURRENT_NOTES++))
    ((NOTES_PROCESSED++))
   fi

   # Write line to current part
   echo "${LINE}" >> "${PART_FILE}"

   # Check if we're ending a note
   if [[ "${LINE}" =~ \</note\> ]]; then
    # Note processing state (currently unused in block processing but reserved for future enhancements)

    # Check if current part is complete (by notes count only - size check removed for performance)
    local SHOULD_SPLIT=false

    # Only split if we have enough notes AND we haven't reached the total AND we haven't reached the part limit
    if [[ ${CURRENT_NOTES} -ge ${NOTES_PER_PART} ]] && [[ ${NOTES_PROCESSED} -lt ${TOTAL_NOTES} ]] && [[ ${PART_NUM} -lt ${NUM_PARTS} ]]; then
     SHOULD_SPLIT=true
     __logd "Splitting part ${PART_NUM} by note count: ${CURRENT_NOTES} >= ${NOTES_PER_PART} (processed: ${NOTES_PROCESSED}/${TOTAL_NOTES}, parts: ${PART_NUM}/${NUM_PARTS})"
    fi

    if [[ "${SHOULD_SPLIT}" == "true" ]]; then
     # Close current part
     echo "</${ROOT_TAG}>" >> "${PART_FILE}"

     # Get file size for logging (only when needed)
     local CURRENT_PART_SIZE
     CURRENT_PART_SIZE=$(stat -c%s "${PART_FILE}" 2> /dev/null || echo "0")
     local CURRENT_PART_SIZE_MB
     CURRENT_PART_SIZE_MB=$((CURRENT_PART_SIZE / 1024 / 1024))

     __logd "Created part ${PART_NUM}: ${PART_FILE} (${CURRENT_NOTES} notes, ${CURRENT_PART_SIZE_MB} MB)"

     # Start new part
     ((PART_NUM++))
     PART_FILE="${OUTPUT_DIR}/${PART_PREFIX}_$(printf "%03d" ${PART_NUM}).xml"
     echo '<?xml version="1.0" encoding="UTF-8"?>' > "${PART_FILE}"
     echo "<${ROOT_TAG}>" >> "${PART_FILE}"
     CURRENT_NOTES=0
    fi
   fi
  done < "${INPUT_XML}"
 fi

 # Close last part (only needed for line-by-line processing)
 if [[ "${USE_BLOCK_PROCESSING}" == "false" ]] && [[ -n "${PART_FILE}" ]] && [[ -f "${PART_FILE}" ]]; then
  echo "</${ROOT_TAG}>" >> "${PART_FILE}"
  local FINAL_PART_SIZE
  FINAL_PART_SIZE=$(stat -c%s "${PART_FILE}" 2> /dev/null || echo "0")
  local FINAL_PART_SIZE_MB
  FINAL_PART_SIZE_MB=$((FINAL_PART_SIZE / 1024 / 1024))
  __logd "Created final part: ${PART_FILE} (${CURRENT_NOTES} notes, ${FINAL_PART_SIZE_MB} MB)"
 fi

 # Count actual parts created and show statistics
 local ACTUAL_PARTS
 ACTUAL_PARTS=$(find "${OUTPUT_DIR}" -name "${PART_PREFIX}_*.xml" | wc -l)

 if [[ ${ACTUAL_PARTS} -eq 0 ]]; then
  __loge "ERROR: Failed to create XML parts"
  __log_finish
  return 1
 fi

 # Calculate processing time and performance metrics
 local END_TIME
 END_TIME=$(date +%s)
 local TOTAL_PROCESSING_TIME
 TOTAL_PROCESSING_TIME=$((END_TIME - START_TIME))

 # Avoid division by zero for very fast processing
 local PROCESSING_SPEED_MBPS
 local PROCESSING_SPEED_NOTES_PER_SEC
 if [[ ${TOTAL_PROCESSING_TIME} -gt 0 ]]; then
  PROCESSING_SPEED_MBPS=$((FILE_SIZE_MB / TOTAL_PROCESSING_TIME))
  PROCESSING_SPEED_NOTES_PER_SEC=$((TOTAL_NOTES / TOTAL_PROCESSING_TIME))
 else
  PROCESSING_SPEED_MBPS="N/A"
  PROCESSING_SPEED_NOTES_PER_SEC="N/A"
 fi

 __logi "Successfully created ${ACTUAL_PARTS} ${XML_FORMAT} XML parts in ${OUTPUT_DIR}"
 if [[ ${TOTAL_PROCESSING_TIME} -gt 0 ]]; then
  __logi "Performance: ${TOTAL_PROCESSING_TIME}s total, ${PROCESSING_SPEED_MBPS} MB/s, ${PROCESSING_SPEED_NOTES_PER_SEC} notes/s"
 else
  __logi "Performance: ${TOTAL_PROCESSING_TIME}s total (too fast to measure), speed: N/A"
 fi

 # Show detailed statistics
 local TOTAL_SIZE=0
 local MIN_SIZE=999999999
 local MAX_SIZE=0
 local AVG_SIZE=0

 for PART_FILE in "${OUTPUT_DIR}"/${PART_PREFIX}_*.xml; do
  if [[ -f "${PART_FILE}" ]]; then
   local PART_SIZE
   PART_SIZE=$(stat -c%s "${PART_FILE}" 2> /dev/null || echo "0")
   local PART_SIZE_MB
   PART_SIZE_MB=$((PART_SIZE / 1024 / 1024))
   local PART_NOTES
   PART_NOTES=$(grep -c "<note" "${PART_FILE}" 2> /dev/null || echo "0")

   __logd "Part ${PART_FILE}: ${PART_NOTES} notes, ${PART_SIZE_MB} MB"

   TOTAL_SIZE=$((TOTAL_SIZE + PART_SIZE))
   if [[ ${PART_SIZE} -lt ${MIN_SIZE} ]]; then
    MIN_SIZE=${PART_SIZE}
   fi
   if [[ ${PART_SIZE} -gt ${MAX_SIZE} ]]; then
    MAX_SIZE=${PART_SIZE}
   fi
  fi
 done

 if [[ ${ACTUAL_PARTS} -gt 0 ]]; then
  AVG_SIZE=$((TOTAL_SIZE / ACTUAL_PARTS))
  local TOTAL_SIZE_MB
  TOTAL_SIZE_MB=$((TOTAL_SIZE / 1024 / 1024))
  local MIN_SIZE_MB
  MIN_SIZE_MB=$((MIN_SIZE / 1024 / 1024))
  local MAX_SIZE_MB
  MAX_SIZE_MB=$((MAX_SIZE / 1024 / 1024))
  local AVG_SIZE_MB
  AVG_SIZE_MB=$((AVG_SIZE / 1024 / 1024))

  __logi "Part size statistics: Min=${MIN_SIZE_MB} MB, Max=${MAX_SIZE_MB} MB, Avg=${AVG_SIZE_MB} MB, Total=${TOTAL_SIZE_MB} MB"
 fi

 __log_finish
 return 0
}

# Process large XML file by dividing into parts and processing in parallel
# Parameters:
#   $1: Input XML file path
#   $2: XSLT file for processing
#   $3: Output directory for CSV files
#   $4: Maximum number of workers (optional, default: MAX_THREADS)
#   $5: Number of parts to create (optional, default: MAX_THREADS * 10)

# Process large XML files with intelligent parallel processing
# Automatically determines optimal number of parts based on file size and performance
# Parameters:
#   $1: Input XML file path
#   $2: XSLT file path
#   $3: Output directory
#   $4: Maximum workers (optional, default: MAX_THREADS)
# Returns: 0 on success, 1 on failure
function __processLargeXmlFile() {
 __log_start
 local INPUT_XML="${1}"
 local XSLT_FILE="${2}"
 local OUTPUT_DIR="${3}"
 local MAX_WORKERS="${4:-${MAX_THREADS}}"

 __logi "Processing large XML file with intelligent parallel processing"
 __logd "Input: ${INPUT_XML}"
 __logd "XSLT: ${XSLT_FILE}"
 __logd "Output: ${OUTPUT_DIR}"
 __logd "Max workers: ${MAX_WORKERS}"
 __logd "Parts calculation: Delegated to __divide_xml_file for optimal performance"

 # Use TMP_DIR from parent script if available, otherwise create temporary directory
 local PARTS_DIR
 if [[ -n "${TMP_DIR:-}" ]] && [[ -d "${TMP_DIR}" ]]; then
  PARTS_DIR="${TMP_DIR}/xml_parts"
  mkdir -p "${PARTS_DIR}"
  __logd "Using TMP_DIR from parent script: ${PARTS_DIR}"
 else
  PARTS_DIR=$(mktemp -d)
  __logd "Created temporary parts directory: ${PARTS_DIR}"
 fi

 # Divide XML file into parts - let __divide_xml_file calculate optimal parts
 if ! __divide_xml_file "${INPUT_XML}" "${PARTS_DIR}"; then
  __loge "ERROR: Failed to divide XML file"
  # Only clean up if we created the directory (not if using TMP_DIR)
  if [[ -z "${TMP_DIR:-}" ]] || [[ ! -d "${TMP_DIR}" ]]; then
   rm -rf "${PARTS_DIR}"
  fi
  __log_finish
  return 1
 fi

 # Process parts in parallel
 if ! __processXmlPartsParallel "${PARTS_DIR}" "${XSLT_FILE}" "${OUTPUT_DIR}" "${MAX_WORKERS}" "Planet"; then
  __loge "ERROR: Failed to process XML parts in parallel"
  # Only clean up if we created the directory (not if using TMP_DIR)
  if [[ -z "${TMP_DIR:-}" ]] || [[ ! -d "${TMP_DIR}" ]]; then
   rm -rf "${PARTS_DIR}"
  fi
  __log_finish
  return 1
 fi

 # Clean up temporary parts only if we created the directory
 if [[ -z "${TMP_DIR:-}" ]] || [[ ! -d "${TMP_DIR}" ]]; then
  rm -rf "${PARTS_DIR}"
  __logd "Cleaned up temporary parts directory"
 else
  __logd "Parts directory preserved in TMP_DIR: ${PARTS_DIR}"
 fi

 __logi "Successfully processed large XML file with intelligent parallel processing"
 __log_finish
 return 0
}

# Process XML parts in parallel (consolidated version)
# Automatically detects Planet vs API format based on generated file names
# Parameters:
#   $1: Input directory containing XML parts
#   $2: XSLT file for processing
#   $3: Output directory for CSV files
#   $4: Maximum number of workers (optional, default: 4)
#   $5: Processing type (optional, auto-detected if not provided)
# Returns: 0 on success, 1 on failure
function __processXmlPartsParallel() {
 __log_start
 __logd "Processing XML parts in parallel (consolidated version)."

 local INPUT_DIR="${1}"
 local XSLT_FILE="${2}"
 local OUTPUT_DIR="${3}"
 local MAX_WORKERS="${4:-${MAX_THREADS:-4}}"
 local PROCESSING_TYPE="${5:-}"

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

 # Auto-detect processing type if not provided
 if [[ -z "${PROCESSING_TYPE}" ]]; then
  if find "${INPUT_DIR}" -name "planet_part_*.xml" -type f | grep -q .; then
   PROCESSING_TYPE="Planet"
   __logd "Auto-detected Planet format from file names"
  elif find "${INPUT_DIR}" -name "api_part_*.xml" -type f | grep -q .; then
   PROCESSING_TYPE="API"
   __logd "Auto-detected API format from file names"
  else
   __loge "ERROR: Cannot auto-detect processing type. No planet_part_*.xml or api_part_*.xml files found"
   __log_finish
   return 1
  fi
 fi

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
 MAX_WORKERS=$(__adjust_workers_for_resources "${MAX_WORKERS}" "XML")
 __logi "Processing ${#XML_FILES[@]} ${PROCESSING_TYPE} XML parts with max ${MAX_WORKERS} workers (adjusted for resources)."

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
   __processPlanetXmlPart "${XML_FILE}" "${XSLT_FILE}" "${OUTPUT_DIR}" &
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
    __processPlanetXmlPart "${XML_FILE}" "${XSLT_FILE}" "${OUTPUT_DIR}"
   elif [[ "${PROCESSING_TYPE}" == "API" ]]; then
    __processApiXmlPart "${XML_FILE}"
   fi

   local EXIT_CODE=$?
   if [[ ${EXIT_CODE} -eq 0 ]]; then
    ((PROCESSED++))
    __logd "Retry successful for ${BASE_NAME}"
   else
    ((FAILED++))
    __loge "Retry failed for ${BASE_NAME}"
    FAILED_FILES+=("${XML_FILE}")
   fi
  done
 fi

 # Final statistics
 __logi "Parallel processing completed: ${PROCESSED} successful, ${FAILED} failed"

 # Consolidate part logs for better traceability
 __consolidate_part_logs "${OUTPUT_DIR:-${TMP_DIR}}" "${PROCESSING_TYPE:-Unknown}"

 if [[ ${FAILED} -gt 0 ]]; then
  __logw "Failed files:"
  for FAILED_FILE in "${FAILED_FILES[@]}"; do
   __logw "  ${FAILED_FILE}"
  done
  __log_finish
  return 1
 fi

 __log_finish
 return 0
}

# Consolidate part logs for better traceability
# Parameters:
#   $1: Output directory containing part logs
#   $2: Processing type (Planet or API)
# Returns: 0 on success, 1 on failure
function __consolidate_part_logs() {
 local OUTPUT_DIR="${1}"
 local PROCESSING_TYPE="${2}"
 local CONSOLIDATED_LOG="${OUTPUT_DIR}/consolidated_${PROCESSING_TYPE,,}_processing.log"

 if [[ ! -d "${OUTPUT_DIR}" ]]; then
  return 1
 fi

 __logd "Consolidating part logs from ${OUTPUT_DIR} into ${CONSOLIDATED_LOG}"

 # Find all part log files
 local PART_LOGS
 if [[ "${PROCESSING_TYPE}" == "Planet" ]]; then
  mapfile -t PART_LOGS < <(find "${OUTPUT_DIR}" -name "planet_part_*.log" -type f | sort -V 2> /dev/null || true)
 else
  mapfile -t PART_LOGS < <(find "${OUTPUT_DIR}" -name "api_part_*.log" -type f | sort -V 2> /dev/null || true)
 fi

 if [[ ${#PART_LOGS[@]} -eq 0 ]]; then
  __logw "No part logs found to consolidate"
  return 0
 fi

 # Create consolidated log header
 {
  echo "=== CONSOLIDATED ${PROCESSING_TYPE^^} PROCESSING LOG ==="
  echo "Generated: $(date)"
  echo "Total parts processed: ${#PART_LOGS[@]}"
  echo "Output directory: ${OUTPUT_DIR}"
  echo "================================================"
  echo ""
 } > "${CONSOLIDATED_LOG}"

 # Append each part log with clear separators
 for PART_LOG in "${PART_LOGS[@]}"; do
  local PART_NAME
  PART_NAME=$(basename "${PART_LOG}" .log)

  {
   echo ""
   echo "--- ${PART_NAME} LOG START ---"
   echo "File: ${PART_LOG}"
   echo "Size: $(stat -c%s "${PART_LOG}" 2> /dev/null || echo "unknown") bytes"
   echo "----------------------------------------"
   cat "${PART_LOG}" 2> /dev/null || echo "ERROR: Could not read part log"
   echo "----------------------------------------"
   echo "--- ${PART_NAME} LOG END ---"
   echo ""
  } >> "${CONSOLIDATED_LOG}"
 done

 __logi "Part logs consolidated into: ${CONSOLIDATED_LOG}"
 __logd "Consolidated log contains ${#PART_LOGS[@]} part logs for ${PROCESSING_TYPE} processing"
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
 local RETURN_CODE=$?
 __log_finish
 return "${RETURN_CODE}"
}

# Wrapper function for Planet format that uses parallel processing
# Parameters:
#   $1: XML file path
#   $2: Number of notes to split (optional, uses TOTAL_NOTES if not provided)
# Returns: 0 on success, 1 on failure
function __splitXmlForParallelPlanet() {
 __log_start
 __splitXmlForParallelSafe "${1}" "${2:-}" "${3:-}" "Planet"
 local RETURN_CODE=$?
 __log_finish
 return "${RETURN_CODE}"
}

# Process API XML part (consolidated version)
# Parameters:
#   $1: XML part file path
#   $2: XSLT notes file (optional, uses global if not provided)
#   $3: XSLT comments file (optional, uses global if not provided)
#   $4: XSLT text comments file (optional, uses global if not provided)
# Returns: 0 on success, 1 on failure
function __processApiXmlPart() {
 local XML_PART="${1}"
 local XSLT_NOTES_FILE_LOCAL="${2:-${XSLT_NOTES_API_FILE}}"
 local XSLT_COMMENTS_FILE_LOCAL="${3:-${XSLT_NOTE_COMMENTS_API_FILE}}"
 local XSLT_TEXT_FILE_LOCAL="${4:-${XSLT_TEXT_COMMENTS_API_FILE}}"
 local PART_NUM
 local BASENAME_PART

 # Extract part number from api_part_X.xml
 BASENAME_PART=$(basename "${XML_PART}" .xml)
 if [[ "${BASENAME_PART}" =~ ^api_part_([0-9]+)$ ]]; then
  PART_NUM="${BASH_REMATCH[1]}"
 else
  echo "ERROR: Invalid filename format: '${BASENAME_PART}'. Expected: api_part_X.xml" >&2
  return 1
 fi

 # Validate part number
 if [[ -z "${PART_NUM}" ]] || [[ ! "${PART_NUM}" =~ ^[0-9]+$ ]]; then
  echo "ERROR: Invalid part number extracted: '${PART_NUM}' from file: ${XML_PART}" >&2
  return 1
 fi

 # Create part-specific log file
 local PART_LOG_FILE="${TMP_DIR}/api_part_${PART_NUM}.log"
 local PART_LOG_DIR
 PART_LOG_DIR=$(dirname "${PART_LOG_FILE}")
 mkdir -p "${PART_LOG_DIR}"

 # Configure logging for this specific part
 if command -v __set_log_file > /dev/null 2>&1; then
  __set_log_file "${PART_LOG_FILE}"
 else
  # Fallback: redirect all output to the part log file
  exec 1> "${PART_LOG_FILE}" 2>&1
 fi

 # Start logging for this part
 __log_start
 __logi "=== STARTING API XML PART ${PART_NUM} PROCESSING ==="
 __logd "Input XML part: ${XML_PART}"
 __logd "XSLT files:"
 __logd "  Notes: ${XSLT_NOTES_FILE_LOCAL}"
 __logd "  Comments: ${XSLT_COMMENTS_FILE_LOCAL}"
 __logd "  Text: ${XSLT_TEXT_FILE_LOCAL}"
 __logd "Part log file: ${PART_LOG_FILE}"

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
 if ! __process_xml_with_xslt_robust "${XML_PART}" "${XSLT_NOTES_FILE_LOCAL}" "${OUTPUT_NOTES_PART}" "--stringparam" "default-timestamp" "${CURRENT_TIMESTAMP}" "${ENABLE_XSLT_PROFILING}"; then
  __loge "Notes CSV file was not created: ${OUTPUT_NOTES_PART}"
  __log_finish
  return 1
 fi

 # Process comments
 __logd "Processing comments with robust XSLT processor: ${XSLT_COMMENTS_FILE_LOCAL} -> ${OUTPUT_COMMENTS_PART}"
 if ! __process_xml_with_xslt_robust "${XML_PART}" "${XSLT_COMMENTS_FILE_LOCAL}" "${OUTPUT_COMMENTS_PART}" "--stringparam" "default-timestamp" "${CURRENT_TIMESTAMP}" "${ENABLE_XSLT_PROFILING}"; then
  __loge "Comments CSV file was not created: ${OUTPUT_COMMENTS_PART}"
  __log_finish
  return 1
 fi

 # Process text comments
 __logd "Processing text comments with robust XSLT processor: ${XSLT_TEXT_FILE_LOCAL} -> ${OUTPUT_TEXT_PART}"
 if ! __process_xml_with_xslt_robust "${XML_PART}" "${XSLT_TEXT_FILE_LOCAL}" "${OUTPUT_TEXT_PART}" "--stringparam" "default-timestamp" "${CURRENT_TIMESTAMP}" "${ENABLE_XSLT_PROFILING}"; then
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
#   $3: Output directory for CSV files
# Returns: 0 on success, 1 on failure
function __processPlanetXmlPart() {
 local XML_PART="${1}"
 local XSLT_NOTES_FILE_LOCAL="${2:-${XSLT_NOTES_PLANET_FILE}}"
 local OUTPUT_DIR="${3}"
 local XSLT_COMMENTS_FILE_LOCAL="${XSLT_NOTE_COMMENTS_PLANET_FILE}"
 local XSLT_TEXT_FILE_LOCAL="${XSLT_TEXT_COMMENTS_PLANET_FILE}"
 local PART_NUM
 local BASENAME_PART

 # Extract part number from planet_part_XXX.xml
 BASENAME_PART=$(basename "${XML_PART}" .xml)
 if [[ "${BASENAME_PART}" =~ ^planet_part_([0-9]+)$ ]]; then
  PART_NUM="${BASH_REMATCH[1]}"
 else
  echo "ERROR: Invalid filename format: '${BASENAME_PART}'. Expected: planet_part_XXX.xml" >&2
  return 1
 fi

 # Validate part number
 if [[ -z "${PART_NUM}" ]] || [[ ! "${PART_NUM}" =~ ^[0-9]+$ ]]; then
  echo "ERROR: Invalid part number extracted: '${PART_NUM}' from file: ${XML_PART}" >&2
  return 1
 fi

 # Create part-specific log file
 local PART_LOG_FILE="${OUTPUT_DIR}/planet_part_${PART_NUM}.log"
 local PART_LOG_DIR
 PART_LOG_DIR=$(dirname "${PART_LOG_FILE}")
 mkdir -p "${PART_LOG_DIR}"

 # Configure logging for this specific part
 if command -v __set_log_file > /dev/null 2>&1; then
  __set_log_file "${PART_LOG_FILE}"
 else
  # Fallback: redirect all output to the part log file
  exec 1> "${PART_LOG_FILE}" 2>&1
 fi

 # Start logging for this part
 __log_start
 __logi "=== STARTING PLANET XML PART ${PART_NUM} PROCESSING ==="
 __logd "Input XML part: ${XML_PART}"
 __logd "XSLT files:"
 __logd "  Notes: ${XSLT_NOTES_FILE_LOCAL}"
 __logd "  Comments: ${XSLT_COMMENTS_FILE_LOCAL}"
 __logd "  Text: ${XSLT_TEXT_FILE_LOCAL}"
 __logd "Part log file: ${PART_LOG_FILE}"

 __logi "Processing Planet XML part ${PART_NUM}: ${XML_PART}"

 # Convert XML part to CSV using XSLT
 local OUTPUT_NOTES_PART
 local OUTPUT_COMMENTS_PART
 local OUTPUT_TEXT_PART
 OUTPUT_NOTES_PART="${OUTPUT_DIR}/output-notes-part-${PART_NUM}.csv"
 OUTPUT_COMMENTS_PART="${OUTPUT_DIR}/output-comments-part-${PART_NUM}.csv"
 OUTPUT_TEXT_PART="${OUTPUT_DIR}/output-text-part-${PART_NUM}.csv"

 # Generate current timestamp for XSLT processing
 local CURRENT_TIMESTAMP
 CURRENT_TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
 __logd "Using timestamp for XSLT processing: ${CURRENT_TIMESTAMP}"

 # Process notes
 __logd "Processing notes with robust XSLT processor: ${XSLT_NOTES_FILE_LOCAL} -> ${OUTPUT_NOTES_PART}"
 if ! __process_xml_with_xslt_robust "${XML_PART}" "${XSLT_NOTES_FILE_LOCAL}" "${OUTPUT_NOTES_PART}" "--stringparam" "default-timestamp" "${CURRENT_TIMESTAMP}" "${ENABLE_XSLT_PROFILING:-false}"; then
  __loge "Notes CSV file was not created: ${OUTPUT_NOTES_PART}"
  __log_finish
  return 1
 fi

 # Process comments
 __logd "Processing comments with robust XSLT processor: ${XSLT_COMMENTS_FILE_LOCAL} -> ${OUTPUT_COMMENTS_PART}"
 if ! __process_xml_with_xslt_robust "${XML_PART}" "${XSLT_COMMENTS_FILE_LOCAL}" "${OUTPUT_COMMENTS_PART}" "--stringparam" "default-timestamp" "${CURRENT_TIMESTAMP}" "${ENABLE_XSLT_PROFILING:-false}"; then
  __loge "Comments CSV file was not created: ${OUTPUT_COMMENTS_PART}"
  __log_finish
  return 1
 fi

 # Process text comments
 __logd "Processing text comments with robust XSLT processor: ${XSLT_TEXT_FILE_LOCAL} -> ${OUTPUT_TEXT_PART}"
 if ! __process_xml_with_xslt_robust "${XML_PART}" "${XSLT_TEXT_FILE_LOCAL}" "${OUTPUT_TEXT_PART}" "--stringparam" "default-timestamp" "${CURRENT_TIMESTAMP}" "${ENABLE_XSLT_PROFILING:-false}"; then
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
 return 0
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

# Intelligent XML processing decision function
# Automatically chooses between traditional and enhanced division methods
# Parameters:
#   $1: Input XML file path
#   $2: XSLT file path
#   $3: Output directory
#   $4: Maximum workers (optional, default: MAX_THREADS)
#   $5: Processing type (optional, default: Planet)
# Returns: 0 on success, 1 on failure
function __processXmlIntelligently() {
 __log_start
 local INPUT_XML="${1}"
 local XSLT_FILE="${2}"
 local OUTPUT_DIR="${3}"
 local MAX_WORKERS="${4:-${MAX_THREADS}}"
 local PROCESSING_TYPE="${5:-Planet}"

 __logi "Intelligent XML processing decision"
 __logd "Input: ${INPUT_XML}"
 __logd "XSLT: ${XSLT_FILE}"
 __logd "Output: ${OUTPUT_DIR}"
 __logd "Max workers: ${MAX_WORKERS}"
 __logd "Processing type: ${PROCESSING_TYPE}"

 # Check if input file exists
 if [[ ! -f "${INPUT_XML}" ]]; then
  __loge "ERROR: Input XML file not found: ${INPUT_XML}"
  __log_finish
  return 1
 fi

 # Get file size in bytes
 local FILE_SIZE_BYTES
 FILE_SIZE_BYTES=$(stat -c%s "${INPUT_XML}" 2> /dev/null || echo "0")

 if [[ "${FILE_SIZE_BYTES}" -eq "0" ]]; then
  __loge "ERROR: Cannot determine file size or file is empty"
  __log_finish
  return 1
 fi

 # Convert to MB for easier comparison
 local FILE_SIZE_MB
 FILE_SIZE_MB=$((FILE_SIZE_BYTES / 1024 / 1024))

 __logd "File size: ${FILE_SIZE_MB} MB (${FILE_SIZE_BYTES} bytes)"

 # Decision logic: Use enhanced method if file is large (> 100 MB)
 if [[ "${FILE_SIZE_MB}" -gt 100 ]]; then
  __logi "Large file detected (${FILE_SIZE_MB} MB > 100 MB), using enhanced division method"

  # Delegate part calculation to __divide_xml_file for optimal performance
  # No need to calculate parts here - let the specialized function handle it
  if ! __processLargeXmlFile "${INPUT_XML}" "${XSLT_FILE}" "${OUTPUT_DIR}" "${MAX_WORKERS}"; then
   __loge "ERROR: Enhanced XML processing failed, falling back to traditional method"
   __logw "Falling back to traditional XML processing method"
   if ! __processXmlWithTraditionalMethod "${INPUT_XML}" "${XSLT_FILE}" "${OUTPUT_DIR}" "${MAX_WORKERS}" "${PROCESSING_TYPE}"; then
    __loge "ERROR: Both processing methods failed"
    __log_finish
    return 1
   fi
  fi
 else
  __logi "Standard file size (${FILE_SIZE_MB} MB ≤ 100 MB), using traditional method"

  # Use traditional method
  if ! __processXmlWithTraditionalMethod "${INPUT_XML}" "${XSLT_FILE}" "${OUTPUT_DIR}" "${MAX_WORKERS}" "${PROCESSING_TYPE}"; then
   __loge "ERROR: Traditional XML processing failed"
   __log_finish
   return 1
  fi
 fi

 __logi "Intelligent XML processing completed successfully"
 __log_finish
 return 0
}

# Traditional XML processing method (existing flow)
# Parameters:
#   $1: Input XML file path
#   $2: XSLT file path
#   $3: Output directory
#   $4: Maximum workers (optional, default: MAX_THREADS)
#   $5: Processing type (optional, default: Planet)
# Returns: 0 on success, 1 on failure
function __processXmlWithTraditionalMethod() {
 __log_start
 local INPUT_XML="${1}"
 local XSLT_FILE="${2}"
 local OUTPUT_DIR="${3}"
 local MAX_WORKERS="${4:-${MAX_THREADS}}"
 local PROCESSING_TYPE="${5:-Planet}"

 __logi "Processing XML with traditional method"
 __logd "Input: ${INPUT_XML}"
 __logd "XSLT: ${XSLT_FILE}"
 __logd "Output: ${OUTPUT_DIR}"
 __logd "Max workers: ${MAX_WORKERS}"
 __logd "Processing type: ${PROCESSING_TYPE}"

 # Create output directory
 mkdir -p "${OUTPUT_DIR}"

 # Use traditional division method
 if ! __splitXmlForParallelSafe "${INPUT_XML}" "${MAX_WORKERS}" "${OUTPUT_DIR}" "${PROCESSING_TYPE}"; then
  __loge "ERROR: Traditional XML division failed"
  __log_finish
  return 1
 fi

 # Process parts in parallel
 if ! __processXmlPartsParallel "${OUTPUT_DIR}" "${XSLT_FILE}" "${OUTPUT_DIR}/output" "${MAX_WORKERS}" "${PROCESSING_TYPE}"; then
  __loge "ERROR: Traditional parallel processing failed"
  __log_finish
  return 1
 fi

 __logi "Traditional XML processing completed successfully"
 __log_finish
 return 0
}
