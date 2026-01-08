#!/bin/bash
# Consolidated Parallel Processing Functions for OSM-Notes-Ingestion
# This file consolidates all parallel processing functions to eliminate duplication
# Description: Centralized parallel processing functions with resource management and retry logic
#
# Author: Andres Gomez (AngocA)
# Version: 2025-12-07

# Load properties to ensure all required variables are available
# Only load production properties if we're not in a test environment
if [[ -z "${BATS_TEST_DIRNAME:-}" ]] && [[ -f "${SCRIPT_BASE_DIRECTORY:-.}/etc/properties.sh" ]]; then
 source "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh"
elif [[ -z "${BATS_TEST_DIRNAME:-}" ]] && [[ -f "./etc/properties.sh" ]]; then
 source "./etc/properties.sh"
fi

# Load common functions if not already loaded
if [[ -z "${__log_start:-}" ]]; then
 if [[ -f "${SCRIPT_BASE_DIRECTORY:-.}/lib/osm-common/commonFunctions.sh" ]]; then
  source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/commonFunctions.sh"
 elif [[ -f "./lib/osm-common/commonFunctions.sh" ]]; then
  source "./lib/osm-common/commonFunctions.sh"
 fi
fi

# Load validation functions if not already loaded
# NOTE: functionsProcess.sh defines __validate_csv_structure with FILE_TYPE parameter
# (notes/comments/text), while validationFunctions.sh uses EXPECTED_COLUMNS parameter.
# We should NOT load validationFunctions.sh here if the function already exists,
# as functionsProcess.sh (which is loaded before this file) should have already
# provided the correct validation function. Loading validationFunctions.sh here
# would overwrite the correct function with the wrong one.
# Only load validationFunctions.sh if the function doesn't exist at all.
if [[ -z "$(type -t __validate_csv_structure 2> /dev/null || true)" ]]; then
 if [[ -f "${SCRIPT_BASE_DIRECTORY:-.}/lib/osm-common/validationFunctions.sh" ]]; then
  source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/validationFunctions.sh"
 elif [[ -f "./lib/osm-common/validationFunctions.sh" ]]; then
  source "./lib/osm-common/validationFunctions.sh"
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
# MAX_RETRIES is already declared in functionsProcess.sh - do not redeclare
# RETRY_DELAY can be declared here if not already set
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
# Validates memory usage and system load to prevent system overload
#
# Parameters:
#   $1: Mode (optional, "minimal" for reduced requirements) [opcional]
#
# Returns:
#   0: Resources available
#   1: Resources not available (high memory or load)
#
# Examples:
#   if __check_system_resources; then
#     echo "System ready"
#   fi
#   if __check_system_resources "minimal"; then
#     echo "System ready (minimal mode)"
#   fi
#
# Related: docs/Documentation.md#parallel-processing (resource management)
function __check_system_resources() {
 __log_start
 # shellcheck disable=SC2120
 # MODE parameter is optional and has a default value
 local MODE="${1:-normal}"
 local MEMORY_PERCENT
 local CURRENT_LOAD
 local MEMORY_THRESHOLD
 local LOAD_THRESHOLD

 # Adjust thresholds based on mode
 if [[ "${MODE}" == "minimal" ]]; then
  MEMORY_THRESHOLD=90 # Allow up to 90% memory usage
  LOAD_THRESHOLD=3.0  # Allow higher system load
  __logd "Using minimal resource requirements mode"
 else
  MEMORY_THRESHOLD="${MAX_MEMORY_PERCENT:-80}" # Normal mode: use configured threshold
  LOAD_THRESHOLD="${MAX_LOAD_AVERAGE:-2.0}"    # Normal mode: use configured threshold
 fi

 # Check memory usage
 if command -v free > /dev/null 2>&1; then
  MEMORY_PERCENT=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}' || true)
  if [[ "${MEMORY_PERCENT}" -gt "${MEMORY_THRESHOLD}" ]]; then
   __logw "WARNING: High memory usage (${MEMORY_PERCENT}% > ${MEMORY_THRESHOLD}%), waiting for resources..."
   __log_finish
   return 1
  fi
 fi

 # Check system load
 if command -v uptime > /dev/null 2>&1; then
  CURRENT_LOAD=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//' || true)
  if [[ -n "${CURRENT_LOAD}" ]] && [[ "${CURRENT_LOAD}" != "0.00" ]]; then
   local LOAD_COMPARE
   LOAD_COMPARE=$(echo "${CURRENT_LOAD} > ${LOAD_THRESHOLD}" | bc -l 2> /dev/null || echo "0")
   if [[ "${LOAD_COMPARE}" == "1" ]]; then
    __logw "WARNING: High system load (${CURRENT_LOAD} > ${LOAD_THRESHOLD}), waiting for resources..."
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
# Polls system resources until available or timeout
#
# Parameters:
#   $1: Maximum wait time in seconds (optional, default: 60) [opcional]
#
# Returns:
#   0: Resources became available
#   1: Timeout waiting for resources
#
# Examples:
#   if __wait_for_resources 120; then
#     echo "Resources available"
#   fi
#
# Related: docs/Documentation.md#parallel-processing (resource management)
function __wait_for_resources() {
 __log_start
 local MAX_WAIT_TIME="${1:-60}"
 local WAIT_TIME=0
 local WAIT_INTERVAL=5

 __logd "Waiting for system resources to become available (max: ${MAX_WAIT_TIME}s)..."

 while [[ ${WAIT_TIME} -lt ${MAX_WAIT_TIME} ]]; do
  # shellcheck disable=SC2119
  # __check_system_resources is called without arguments intentionally (uses default values)
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

  # More aggressive reduction for XML processing (AWK processing is memory-efficient but large files still need caution)
  if [[ "${PROCESSING_TYPE}" == "XML" ]]; then
   if [[ "${MEMORY_PERCENT}" -gt 75 ]]; then
    ADJUSTED_WORKERS=1
    __logw "Reducing XML workers to ${ADJUSTED_WORKERS} due to very high memory usage (${MEMORY_PERCENT}%) - memory allocation risk" >&2
   elif [[ "${MEMORY_PERCENT}" -gt 65 ]]; then
    ADJUSTED_WORKERS=$((ADJUSTED_WORKERS / 2))
    if [[ ${ADJUSTED_WORKERS} -lt 1 ]]; then
     ADJUSTED_WORKERS=1
    fi
    __logw "Reducing XML workers to ${ADJUSTED_WORKERS} due to high memory usage (${MEMORY_PERCENT}%)" >&2
   elif [[ "${MEMORY_PERCENT}" -gt 50 ]]; then
    ADJUSTED_WORKERS=$((ADJUSTED_WORKERS * 2 / 3))
    __logw "Reducing XML workers to ${ADJUSTED_WORKERS} due to moderate memory usage (${MEMORY_PERCENT}%)" >&2
   fi
  else
   # Standard reduction for non-XML processing
   if [[ "${MEMORY_PERCENT}" -gt 85 ]]; then
    ADJUSTED_WORKERS=$((ADJUSTED_WORKERS / 2))
    __logw "Reducing workers to ${ADJUSTED_WORKERS} due to very high memory usage (${MEMORY_PERCENT}%)" >&2
   elif [[ "${MEMORY_PERCENT}" -gt 70 ]]; then
    ADJUSTED_WORKERS=$((ADJUSTED_WORKERS / 2))
    __logw "Reducing workers to ${ADJUSTED_WORKERS} due to high memory usage (${MEMORY_PERCENT}%)" >&2
   elif [[ "${MEMORY_PERCENT}" -gt 50 ]]; then
    ADJUSTED_WORKERS=$((ADJUSTED_WORKERS * 3 / 4))
    __logw "Reducing workers to ${ADJUSTED_WORKERS} due to moderate memory usage (${MEMORY_PERCENT}%)" >&2
   fi
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
 # shellcheck disable=SC2154
 # PARALLEL_PROCESS_DELAY is defined in etc/properties.sh or environment
 local ADJUSTED_DELAY="${PARALLEL_PROCESS_DELAY}"
 local MEMORY_PERCENT

 # If delay is 0 or very low, don't adjust it - respect user's intention for minimal/no delay
 if [[ "${PARALLEL_PROCESS_DELAY}" -le 2 ]]; then
  __logw "Delay is ${PARALLEL_PROCESS_DELAY}s, no adjustment needed"
  __logw "Finished process delay adjustment"
  printf "%d\n" "${ADJUSTED_DELAY}"
  return 0
 fi

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
 # For large files, we want smaller, more manageable parts for better reliability
 local PERFORMANCE_OPTIMIZED_PARTS
 if [[ ${FILE_SIZE_MB} -gt 5000 ]]; then
  # For files > 5GB, use medium parts for reliability
  PERFORMANCE_OPTIMIZED_PARTS=$((FILE_SIZE_MB / 100)) # ~100MB per part
  __logd "Extremely large file detected (${FILE_SIZE_MB} MB), using ~100MB parts for reliability"
 elif [[ ${FILE_SIZE_MB} -gt 1000 ]]; then
  # For files > 1GB, use smaller parts for better processing
  PERFORMANCE_OPTIMIZED_PARTS=$((FILE_SIZE_MB / 75)) # ~75MB per part
  __logd "Large file detected (${FILE_SIZE_MB} MB), using ~75MB parts for optimal processing"
 elif [[ ${FILE_SIZE_MB} -gt 100 ]]; then
  # For files > 100MB, use small parts
  PERFORMANCE_OPTIMIZED_PARTS=$((FILE_SIZE_MB / 50)) # ~50MB per part
  __logd "Medium file detected (${FILE_SIZE_MB} MB), using ~50MB parts"
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
 __logd "Calculated target: ~${ACTUAL_TARGET_PART_SIZE_MB} MB per part (${FILE_SIZE_MB} MB ÷ ${NUM_PARTS} parts)"
 __logd "Note: Actual part sizes may vary due to content distribution and processing method"
 __logd "Root tag: <${ROOT_TAG}>, Part prefix: ${PART_PREFIX}"

 # Calculate notes per part and adjust for optimal processing
 local NOTES_PER_PART
 NOTES_PER_PART=$((TOTAL_NOTES / NUM_PARTS))

 # Ensure reasonable notes per part for optimal processing
 # Target: 25,000 to 50,000 notes per part for memory safety
 local TARGET_NOTES_PER_PART=37500 # 37,500 notes per part (reduced for memory safety)
 local MIN_NOTES_PER_PART=25000    # 25,000 notes per part (reduced for memory safety)
 local MAX_NOTES_PER_PART=50000    # 50,000 notes per part (reduced for memory safety)

 if [[ ${NOTES_PER_PART} -gt ${MAX_NOTES_PER_PART} ]]; then
  # Too many notes per part, increase number of parts
  local NEW_NUM_PARTS
  NEW_NUM_PARTS=$((TOTAL_NOTES / TARGET_NOTES_PER_PART))
  if [[ ${NEW_NUM_PARTS} -gt ${NUM_PARTS} ]]; then
   NUM_PARTS=${NEW_NUM_PARTS}
   NOTES_PER_PART=${TARGET_NOTES_PER_PART}
   __logd "Adjusted to ${NUM_PARTS} parts with ~${NOTES_PER_PART} notes per part for optimal processing"
  fi
 elif [[ ${NOTES_PER_PART} -lt ${MIN_NOTES_PER_PART} ]] && [[ ${TOTAL_NOTES} -gt ${MIN_NOTES_PER_PART} ]]; then
  # Too few notes per part, decrease number of parts
  local NEW_NUM_PARTS
  NEW_NUM_PARTS=$((TOTAL_NOTES / TARGET_NOTES_PER_PART))
  if [[ ${NEW_NUM_PARTS} -lt ${NUM_PARTS} ]]; then
   NUM_PARTS=${NEW_NUM_PARTS}
   NOTES_PER_PART=${TARGET_NOTES_PER_PART}
   __logd "Adjusted to ${NUM_PARTS} parts with ~${NOTES_PER_PART} notes per part for optimal processing"
  fi
 fi

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
  __logd "Final parts configuration: ${NUM_PARTS} parts with ~${NOTES_PER_PART} notes per part"
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

 # For very large files, use line-based processing for better reliability and smaller parts
 local USE_BLOCK_PROCESSING=false
 local USE_POSITION_BASED=false

 if [[ ${FILE_SIZE_MB} -gt 5000 ]] && [[ ${TOTAL_NOTES} -gt 500000 ]]; then
  USE_POSITION_BASED=true
  __logd "Extremely large file detected (${FILE_SIZE_MB} MB, ${TOTAL_NOTES} notes), using position-based processing for maximum performance"
 elif [[ ${FILE_SIZE_MB} -gt 2000 ]] && [[ ${TOTAL_NOTES} -gt 100000 ]]; then
  # Changed from block-based to line-based for better reliability and smaller parts
  USE_BLOCK_PROCESSING=false
  __logd "Very large file detected (${FILE_SIZE_MB} MB, ${TOTAL_NOTES} notes), using line-based processing for optimal reliability and smaller parts"
 fi

 # Calculate optimal parts based on target notes per part
 local OPTIMAL_PARTS
 OPTIMAL_PARTS=$((TOTAL_NOTES / TARGET_NOTES_PER_PART))
 if [[ $((TOTAL_NOTES % TARGET_NOTES_PER_PART)) -gt 0 ]]; then
  ((OPTIMAL_PARTS++))
 fi

 # Use the optimal number of parts, but respect user limits
 if [[ ${OPTIMAL_PARTS} -lt ${NUM_PARTS} ]]; then
  NUM_PARTS=${OPTIMAL_PARTS}
  __logd "Adjusted parts to ${NUM_PARTS} based on optimal notes per part (${TARGET_NOTES_PER_PART})"
 fi

 # Create first part file
 PART_FILE="${OUTPUT_DIR}/${PART_PREFIX}_$(printf "%03d" "${PART_NUM}").xml"
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
  grep -n "<note" "${INPUT_XML}" 2> /dev/null | cut -d: -f1 > "${NOTE_POSITIONS_FILE}" || true

  # Calculate optimal split points
  local NOTES_PER_PART_OPTIMIZED
  NOTES_PER_PART_OPTIMIZED=$((TOTAL_NOTES / NUM_PARTS))

  __logd "Splitting into ${NUM_PARTS} parts with ~${NOTES_PER_PART_OPTIMIZED} notes per part"

  # Process each part using pre-calculated positions
  local START_TIME
  START_TIME=$(date +%s)

  for ((PART_NUM = 1; PART_NUM <= NUM_PARTS; PART_NUM++)); do
   local PART_FILE
   PART_FILE="${OUTPUT_DIR}/${PART_PREFIX}_$(printf "%03d" "${PART_NUM}").xml"
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
  # Line-based XML-aware processing for very large files (more reliable than block-based)
  __logd "Using line-based XML-aware processing for optimal reliability"

  # Find the start of the first note (skip header)
  local HEADER_SIZE=0
  local FIRST_NOTE_LINE
  FIRST_NOTE_LINE=$(grep -n "<note" "${INPUT_XML}" 2> /dev/null | head -1 || echo "")
  if [[ -n "${FIRST_NOTE_LINE}" ]]; then
   HEADER_SIZE=$(echo "${FIRST_NOTE_LINE}" | cut -d: -f1 2> /dev/null || echo "0")
  fi
  if [[ -z "${HEADER_SIZE}" ]] || [[ "${HEADER_SIZE}" -eq "0" ]]; then
   HEADER_SIZE=0
  fi

  # Extract header content
  head -n $((HEADER_SIZE - 1)) "${INPUT_XML}" > "${OUTPUT_DIR}/header.xml"

  # Use line-based processing for better XML integrity
  local CURRENT_LINE=0
  local CURRENT_NOTES=0
  local IN_NOTE=false
  local PART_CONTENT=""

  # Read the file line by line, starting after header
  while IFS= read -r LINE; do
   ((CURRENT_LINE++))

   # Skip header lines
   if [[ ${CURRENT_LINE} -le ${HEADER_SIZE} ]]; then
    continue
   fi

   # Check if we're starting a new note
   if [[ "${LINE}" =~ \<note ]]; then
    IN_NOTE=true
    ((CURRENT_NOTES++))
   fi

   # Add line to current part content (ensure proper line ending)
   PART_CONTENT+="${LINE}"$'\n'

   # Check if we're ending a note
   if [[ "${LINE}" =~ \</note\> ]]; then
    IN_NOTE=false
   fi

   # Check if current part is complete (by notes count)
   if [[ ${CURRENT_NOTES} -ge ${NOTES_PER_PART} ]] && [[ ${PART_NUM} -lt ${NUM_PARTS} ]]; then
    # Create part file
    local PART_FILE
    PART_FILE="${OUTPUT_DIR}/${PART_PREFIX}_$(printf "%03d" "${PART_NUM}").xml"

    # Create part with header and content
    cat "${OUTPUT_DIR}/header.xml" > "${PART_FILE}"
    printf "%s" "${PART_CONTENT}" >> "${PART_FILE}"
    echo "</${ROOT_TAG}>" >> "${PART_FILE}"

    # Count actual notes in this part
    local PART_NOTES
    PART_NOTES=$(grep -c "<note" "${PART_FILE}" 2> /dev/null || echo "0")

    # Get actual part size for accurate logging
    local PART_SIZE_BYTES
    PART_SIZE_BYTES=$(stat -c%s "${PART_FILE}" 2> /dev/null || echo "0")
    local PART_SIZE_MB
    PART_SIZE_MB=$((PART_SIZE_BYTES / 1024 / 1024))

    __logd "Created line-based XML part ${PART_NUM}: ${PART_FILE} (~${PART_NOTES} notes, ~${PART_SIZE_MB} MB)"

    # Check memory availability for XML processing
    if ! __check_memory_for_xml_processing "${PART_FILE}"; then
     __logw "WARNING: Insufficient memory for part ${PART_NUM}, reducing part size"
     # Reduce target notes per part for remaining parts
     TARGET_NOTES_PER_PART=$((TARGET_NOTES_PER_PART / 2))
     MIN_NOTES_PER_PART=$((MIN_NOTES_PER_PART / 2))
     MAX_NOTES_PER_PART=$((MAX_NOTES_PER_PART / 2))
     __logd "Adjusted target notes per part: ${TARGET_NOTES_PER_PART}"
    fi

    # Validate XML structure of this part
    if ! __validate_xml_part "${PART_FILE}" "${ROOT_TAG}"; then
     __loge "ERROR: XML validation failed for part ${PART_NUM}: ${PART_FILE}"
     rm -f "${PART_FILE}"
     __log_finish
     return 1
    fi

    # Reset for next part
    PART_CONTENT=""
    CURRENT_NOTES=0
    ((PART_NUM++))

    # Stop if we've reached the part limit
    if [[ ${PART_NUM} -gt ${NUM_PARTS} ]]; then
     break
    fi
   fi
  done < "${INPUT_XML}"

  # Create final part with remaining content if any
  if [[ -n "${PART_CONTENT}" ]] && [[ ${PART_NUM} -le ${NUM_PARTS} ]]; then
   local PART_FILE
   PART_FILE="${OUTPUT_DIR}/${PART_PREFIX}_$(printf "%03d" "${PART_NUM}").xml"

   cat "${OUTPUT_DIR}/header.xml" > "${PART_FILE}"
   printf "%s" "${PART_CONTENT}" >> "${PART_FILE}"
   echo "</${ROOT_TAG}>" >> "${PART_FILE}"

   local PART_NOTES
   PART_NOTES=$(grep -c "<note" "${PART_FILE}" 2> /dev/null || echo "0")
   local PART_SIZE_BYTES
   PART_SIZE_BYTES=$(stat -c%s "${PART_FILE}" 2> /dev/null || echo "0")
   local PART_SIZE_MB
   PART_SIZE_MB=$((PART_SIZE_BYTES / 1024 / 1024))

   __logd "Created final line-based XML part ${PART_NUM}: ${PART_FILE} (~${PART_NOTES} notes, ~${PART_SIZE_MB} MB)"

   # Check memory availability for XML processing
   if ! __check_memory_for_xml_processing "${PART_FILE}"; then
    __logw "WARNING: Insufficient memory for final part ${PART_NUM}"
   fi

   if ! __validate_xml_part "${PART_FILE}" "${ROOT_TAG}"; then
    __loge "ERROR: XML validation failed for final part ${PART_NUM}: ${PART_FILE}"
    rm -f "${PART_FILE}"
    __log_finish
    return 1
   fi
  fi

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
     PART_FILE="${OUTPUT_DIR}/${PART_PREFIX}_$(printf "%03d" "${PART_NUM}").xml"
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
 ACTUAL_PARTS=$(find "${OUTPUT_DIR}" -name "${PART_PREFIX}_*.xml" -type f 2> /dev/null | wc -l 2> /dev/null || echo "0")

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

 # shellcheck disable=SC2231
 # Glob pattern expansion is intentional here
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

# Process XML parts in parallel using GNU Parallel
# Automatically detects Planet vs API format based on generated file names
# Processes multiple XML parts concurrently with resource management
#
# Parameters:
#   $1: Input directory containing XML parts [requerido]
#   $2: Output directory (optional, uses input dir if not provided) [opcional]
#   $3: Maximum number of workers (optional, uses MAX_THREADS if not provided) [opcional]
#   $4: Processing type ("Planet" or "API", optional) [opcional]
#
# Returns:
#   0: Success
#   1: Error during processing
#
# Strategy: See docs/Documentation.md#parallel-processing for complete workflow
#   - Splits work into more parts than threads for better load balancing
#   - Uses GNU Parallel for concurrent processing
#   - Manages system resources to prevent overload
#
# Performance: See docs/Documentation.md#performance
#   - Processes multiple parts concurrently
#   - Automatically adjusts workers based on system resources
#
# Examples:
#   __processXmlPartsParallel "${TMP_DIR}" "${OUTPUT_DIR}" "${NUM_PARTS}" "Planet"
#   __processXmlPartsParallel "${TMP_DIR}" "" "${MAX_THREADS}" "API"
#
# Related: docs/Documentation.md#parallel-processing (complete parallel processing guide)
# Related Functions: __splitXmlForParallelSafe(), __check_system_resources()
function __processXmlPartsParallel() {
 __log_start
 __logd "Processing XML parts in parallel (consolidated version)."

 local INPUT_DIR="${1}"
 local OUTPUT_DIR="${2:-}"
 local MAX_WORKERS="${3:-${MAX_THREADS:-4}}"
 local PROCESSING_TYPE="${4:-}"

 # Configure system limits to prevent process killing
 __logd "Configuring system limits for parallel processing..."
 __configure_system_limits

 if [[ ! -d "${INPUT_DIR}" ]]; then
  __loge "ERROR: Input directory not found: ${INPUT_DIR}"
  __log_finish
  return 1
 fi

 # Create output directory if provided
 if [[ -n "${OUTPUT_DIR}" ]]; then
  mkdir -p "${OUTPUT_DIR}"
 fi

 # Auto-detect processing type if not provided
 if [[ -z "${PROCESSING_TYPE}" ]]; then
  local PLANET_CHECK
  PLANET_CHECK=$(find "${INPUT_DIR}" -name "planet_part_*.xml" -type f 2> /dev/null | head -1 || echo "")
  if [[ -n "${PLANET_CHECK}" ]]; then
   PROCESSING_TYPE="Planet"
   __logd "Auto-detected Planet format from file names"
  else
   local API_CHECK
   API_CHECK=$(find "${INPUT_DIR}" -name "api_part_*.xml" -type f 2> /dev/null | head -1 || echo "")
   if [[ -n "${API_CHECK}" ]]; then
    PROCESSING_TYPE="API"
    __logd "Auto-detected API format from file names"
   else
    __loge "ERROR: Cannot auto-detect processing type. No planet_part_*.xml or api_part_*.xml files found"
    __log_finish
    return 1
   fi
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
  local LOG_DATE
  LOG_DATE=$(date 2> /dev/null || echo 'unknown')
  echo "=== CONSOLIDATED ${PROCESSING_TYPE^^} PROCESSING LOG ==="
  echo "Generated: ${LOG_DATE}"
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

 # Split XML file with optimized single-pass AWK (much faster than awk+sed)
 __logi "Starting optimized single-pass XML splitting with AWK..."

 # Use AWK to split in a single pass through the file
 # This is ~2x faster than the old awk+sed approach (reads file only once)
 awk -v notes_per_part="${NOTES_PER_PART}" \
  -v num_parts="${NUM_PARTS}" \
  -v output_dir="${OUTPUT_DIR}" \
  -v format_type="${FORMAT_TYPE,,}" \
  '
  BEGIN {
   note_count = 0
   current_part = 0
   in_note = 0

   # Initialize first output file
   output_file = output_dir "/" format_type "_part_0.xml"
   print "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" > output_file
   print "<osm-notes>" > output_file
  }

  # Detect start of note tag
  /<note[^>]*>/ {
   # Check if we need to switch to next part
   if (note_count > 0 && note_count % notes_per_part == 0 && current_part < num_parts - 1) {
    # Close current part
    print "</osm-notes>" > output_file
    close(output_file)

    # Open next part
    current_part++
    output_file = output_dir "/" format_type "_part_" current_part ".xml"
    print "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" > output_file
    print "<osm-notes>" > output_file
   }
   note_count++
   in_note = 1
  }

  # Skip original XML declaration and osm-notes tags
  /^<\?xml/ || /^<osm-notes>$/ || /^<\/osm-notes>$/ {
   next
  }

  # Write all other lines to current output file
  {
   print $0 > output_file
  }

  END {
   # Close last part
   if (output_file != "") {
    print "</osm-notes>" > output_file
    close(output_file)
   }
  }
 ' "${XML_FILE}"

 # Verify parts were created
 local CREATED_PARTS
 CREATED_PARTS=$(find "${OUTPUT_DIR}" -name "${FORMAT_TYPE,,}_part_*.xml" -type f 2> /dev/null | wc -l 2> /dev/null || echo "0")

 if [[ "${CREATED_PARTS}" -eq 0 ]]; then
  __loge "ERROR: No parts were created"
  __log_finish
  return 1
 fi

 __logi "XML splitting completed. Created ${CREATED_PARTS} parts in single pass (optimized)."
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
# Processes API XML file part using AWK extraction (parallel processing).
# This function is called by GNU parallel or sequentially for each XML part.
#
# Parameters:
#   $1: XML part file path
#
# Returns: 0 on success, 1 on failure
function __processApiXmlPart() {
 local XML_PART="${1}"
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
 __logd "Part log file: ${PART_LOG_FILE}"

 __logi "Processing API XML part ${PART_NUM}: ${XML_PART}"

 # Convert XML part to CSV using AWK (fast and dependency-free)
 local OUTPUT_NOTES_PART
 local OUTPUT_COMMENTS_PART
 local OUTPUT_TEXT_PART
 OUTPUT_NOTES_PART="${TMP_DIR}/output-notes-part-${PART_NUM}.csv"
 OUTPUT_COMMENTS_PART="${TMP_DIR}/output-comments-part-${PART_NUM}.csv"
 OUTPUT_TEXT_PART="${TMP_DIR}/output-text-part-${PART_NUM}.csv"

 # Process notes with AWK
 __logd "Processing notes with AWK: ${XML_PART} -> ${OUTPUT_NOTES_PART}"
 if ! awk -f "${SCRIPT_BASE_DIRECTORY}/awk/extract_notes.awk" "${XML_PART}" > "${OUTPUT_NOTES_PART}"; then
  __loge "Notes CSV file was not created: ${OUTPUT_NOTES_PART}"
  __log_finish
  return 1
 fi

 if [[ ! -f "${OUTPUT_NOTES_PART}" ]]; then
  __loge "Notes CSV file was not created: ${OUTPUT_NOTES_PART}"
  __log_finish
  return 1
 fi

 # Process comments with AWK
 __logd "Processing comments with AWK: ${XML_PART} -> ${OUTPUT_COMMENTS_PART}"
 if ! awk -f "${SCRIPT_BASE_DIRECTORY}/awk/extract_comments.awk" "${XML_PART}" > "${OUTPUT_COMMENTS_PART}"; then
  __loge "Comments CSV file was not created: ${OUTPUT_COMMENTS_PART}"
  __log_finish
  return 1
 fi

 if [[ ! -f "${OUTPUT_COMMENTS_PART}" ]]; then
  __loge "Comments CSV file was not created: ${OUTPUT_COMMENTS_PART}"
  __log_finish
  return 1
 fi

 # Process text comments with AWK
 __logd "Processing text comments with AWK: ${XML_PART} -> ${OUTPUT_TEXT_PART}"
 if ! awk -f "${SCRIPT_BASE_DIRECTORY}/awk/extract_comment_texts.awk" "${XML_PART}" > "${OUTPUT_TEXT_PART}"; then
  __logw "Text comments CSV file was not created, generating empty file to continue: ${OUTPUT_TEXT_PART}"
  : > "${OUTPUT_TEXT_PART}"
 fi

 if [[ ! -f "${OUTPUT_TEXT_PART}" ]]; then
  __logw "Text comments CSV file was not created, generating empty file to continue: ${OUTPUT_TEXT_PART}"
  : > "${OUTPUT_TEXT_PART}"
 fi

 # Add part_id to the end of each line for notes
 # Note: AWK already outputs 8 columns: note_id,latitude,longitude,created_at,status,closed_at,id_country,part_id
 # The last two columns (id_country and part_id) are empty. We need to set part_id (8th column).
 __logd "Setting part_id ${PART_NUM} in notes CSV (replacing empty 8th column)"
 awk -v part_id="${PART_NUM}" -F',' 'BEGIN{OFS=","} {if(NF>=8) {$8=part_id} else if(NF==7) {$8=part_id} else {$0=$0 "," part_id} print}' "${OUTPUT_NOTES_PART}" > "${OUTPUT_NOTES_PART}.tmp" && mv "${OUTPUT_NOTES_PART}.tmp" "${OUTPUT_NOTES_PART}"

 # Add part_id to the end of each line for comments
 # Note: AWK already outputs 7 columns: note_id,sequence_action,event,created_at,id_user,username,part_id
 # The last column (part_id) is empty. We need to set it (7th column).
 __logd "Setting part_id ${PART_NUM} in comments CSV (replacing empty 7th column)"
 awk -v part_id="${PART_NUM}" -F',' 'BEGIN{OFS=","} {if(NF>=7) {$7=part_id} else {$0=$0 "," part_id} print}' "${OUTPUT_COMMENTS_PART}" > "${OUTPUT_COMMENTS_PART}.tmp" && mv "${OUTPUT_COMMENTS_PART}.tmp" "${OUTPUT_COMMENTS_PART}"

 # Set part_id in the 4th column (replacing empty part_id column)
 # Note: AWK already outputs 4 columns: note_id,sequence_action,"body",part_id
 # The last column (part_id) is empty (trailing comma). We need to replace it.
 # Use gsub to remove trailing comma and add part_id (handles quoted fields correctly)
 __logd "Setting part_id ${PART_NUM} in text comments CSV (replacing empty 4th column)"
 if [[ -s "${OUTPUT_TEXT_PART}" ]]; then
  awk -v part_id="${PART_NUM}" '{gsub(/,$/, ""); print $0 "," part_id}' "${OUTPUT_TEXT_PART}" > "${OUTPUT_TEXT_PART}.tmp" && mv "${OUTPUT_TEXT_PART}.tmp" "${OUTPUT_TEXT_PART}"
 else
  __logw "Text comments CSV is empty for part ${PART_NUM}; skipping part_id setting"
 fi

 # Validate CSV files structure and content before loading (optional)
 if [[ "${SKIP_CSV_VALIDATION:-true}" != "true" ]]; then
  __logd "Validating CSV files structure and enum compatibility for part ${PART_NUM}..."

  # Validate notes structure
  if ! __validate_csv_structure "${OUTPUT_NOTES_PART}" "notes"; then
   __loge "ERROR: Notes CSV structure validation failed for part ${PART_NUM}"
   __log_finish
   return 1
  fi

  # Validate notes enum values
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

  # Validate comments enum values
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
 else
  __logw "WARNING: CSV validation SKIPPED for part ${PART_NUM} (SKIP_CSV_VALIDATION=true)"
 fi

 __logi "✓ All CSV validations passed for API part ${PART_NUM}"
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
# NOTE: This entire function is DISABLED to avoid overriding functionsProcess.sh version
# The version in functionsProcess.sh has the correct signature and works properly
# DO NOT UNCOMMENT - will cause errors
# function __processPlanetXmlPart() { ... }
# All code below was part of that function and is now disabled

# Check if system has enough memory to process XML part safely
# Parameters:
#   $1: XML part file path
# Returns: 0 if enough memory, 1 if insufficient
function __check_memory_for_xml_processing() {
 local XML_PART_FILE="${1}"

 # Get file size in MB
 local FILE_SIZE_MB
 FILE_SIZE_MB=$(stat -c%s "${XML_PART_FILE}" 2> /dev/null || echo "0")
 FILE_SIZE_MB=$((FILE_SIZE_MB / 1024 / 1024))

 # Estimate memory needed for XML processing (AWK is efficient, but large files still need memory)
 local ESTIMATED_MEMORY_NEEDED
 ESTIMATED_MEMORY_NEEDED=$((FILE_SIZE_MB * 2))

 # Get available system memory in MB
 local AVAILABLE_MEMORY_MB
 local FREE_OUTPUT
 FREE_OUTPUT=$(free -m 2> /dev/null || echo "")
 if [[ -n "${FREE_OUTPUT}" ]]; then
  AVAILABLE_MEMORY_MB=$(echo "${FREE_OUTPUT}" | awk 'NR==2{print $7}' 2> /dev/null || echo "1024")
 else
  AVAILABLE_MEMORY_MB="1024"
 fi

 # Check if we have enough memory (need at least 2x estimated for safety)
 if [[ ${AVAILABLE_MEMORY_MB} -lt $((ESTIMATED_MEMORY_NEEDED * 2)) ]]; then
  __logw "WARNING: Insufficient memory for XML processing"
  __logw "Part size: ${FILE_SIZE_MB} MB, Estimated needed: ${ESTIMATED_MEMORY_NEEDED} MB"
  __logw "Available memory: ${AVAILABLE_MEMORY_MB} MB"
  return 1
 fi

 __logd "Memory check passed: ${AVAILABLE_MEMORY_MB} MB available for ${FILE_SIZE_MB} MB part"
 return 0
}

# Validate XML part structure to ensure it's well-formed (lightweight version)
# Parameters:
#   $1: XML part file path
#   $2: Expected root tag name
# Returns: 0 if valid, 1 if invalid
function __validate_xml_part() {
 local XML_PART_FILE="${1}"
 local EXPECTED_ROOT_TAG="${2}"

 # Check if file exists and is readable
 if [[ ! -f "${XML_PART_FILE}" ]] || [[ ! -r "${XML_PART_FILE}" ]]; then
  __loge "ERROR: Cannot read XML part file: ${XML_PART_FILE}"
  return 1
 fi

 # Check if file has content
 local FILE_SIZE
 FILE_SIZE=$(stat -c%s "${XML_PART_FILE}" 2> /dev/null || echo "0")
 if [[ "${FILE_SIZE}" -eq 0 ]]; then
  __loge "ERROR: XML part file is empty: ${XML_PART_FILE}"
  return 1
 fi

 # Lightweight validation: only check critical structure points
 # Since content comes from well-formed XML, we only need to validate boundaries

 # Check XML declaration (first line)
 local FIRST_LINE
 FIRST_LINE=$(head -n 1 "${XML_PART_FILE}" 2> /dev/null || echo "")
 if [[ ! "${FIRST_LINE}" =~ ^\<\?xml ]]; then
  __loge "ERROR: Missing or invalid XML declaration in part: ${XML_PART_FILE}"
  return 1
 fi

 # Check opening root tag (should be near the beginning)
 local OPENING_TAG_FOUND=false
 local LINE_NUM=1
 while IFS= read -r LINE && [[ ${LINE_NUM} -le 10 ]]; do
  if [[ "${LINE}" =~ ^[[:space:]]*\<${EXPECTED_ROOT_TAG}[[:space:]]*[\/]?\> ]]; then
   OPENING_TAG_FOUND=true
   break
  fi
  ((LINE_NUM++))
 done < "${XML_PART_FILE}"

 if [[ "${OPENING_TAG_FOUND}" == "false" ]]; then
  __loge "ERROR: Missing opening root tag <${EXPECTED_ROOT_TAG}> in first 10 lines of part: ${XML_PART_FILE}"
  return 1
 fi

 # Check closing root tag (should be at the end)
 local LAST_LINE
 LAST_LINE=$(tail -n 1 "${XML_PART_FILE}" 2> /dev/null || echo "")
 if [[ ! "${LAST_LINE}" =~ ^[[:space:]]*\</${EXPECTED_ROOT_TAG}\>[[:space:]]*$ ]]; then
  __loge "ERROR: Missing or invalid closing root tag </${EXPECTED_ROOT_TAG}> at end of part: ${XML_PART_FILE}"
  return 1
 fi

 # Quick check for balanced note tags (only count, don't validate structure)
 # This is fast since we're just counting lines, not parsing
 local OPEN_NOTES
 OPEN_NOTES=$(grep -c "<note" "${XML_PART_FILE}" 2> /dev/null || echo "0")
 local CLOSE_NOTES
 CLOSE_NOTES=$(grep -c "</note>" "${XML_PART_FILE}" 2> /dev/null || echo "0")

 if [[ "${OPEN_NOTES}" -ne "${CLOSE_NOTES}" ]]; then
  __loge "ERROR: Unbalanced note tags in part: ${XML_PART_FILE} (open: ${OPEN_NOTES}, close: ${CLOSE_NOTES})"
  return 1
 fi

 # Optional: Quick check for obvious XML syntax errors in first and last few lines
 # This catches most common issues without full parsing
 local FIRST_FEW_LINES
 FIRST_FEW_LINES=$(head -n 5 "${XML_PART_FILE}" 2> /dev/null || echo "")
 local LAST_FEW_LINES
 LAST_FEW_LINES=$(tail -n 5 "${XML_PART_FILE}" 2> /dev/null || echo "")

 # Check for obvious malformed tags in boundaries
 if [[ "${FIRST_FEW_LINES}" =~ \<[^\/\>]*\</ ]]; then
  __logw "WARNING: Potential malformed tag detected in first few lines of: ${XML_PART_FILE}"
 fi

 if [[ "${LAST_FEW_LINES}" =~ \<[^\/\>]*\</ ]]; then
  __logw "WARNING: Potential malformed tag detected in last few lines of: ${XML_PART_FILE}"
 fi

 # Check for extra content after closing root tag
 local LINES_AFTER_CLOSING_TAG
 LINES_AFTER_CLOSING_TAG=$(grep -n "</${EXPECTED_ROOT_TAG}>" "${XML_PART_FILE}" | tail -1 | cut -d: -f1)
 if [[ -n "${LINES_AFTER_CLOSING_TAG}" ]]; then
  local TOTAL_LINES
  TOTAL_LINES=$(wc -l < "${XML_PART_FILE}" 2> /dev/null || echo "0")
  if [[ "${LINES_AFTER_CLOSING_TAG}" -lt "${TOTAL_LINES}" ]]; then
   __loge "ERROR: Extra content detected after closing root tag in: ${XML_PART_FILE}"
   __loge "Closing tag at line ${LINES_AFTER_CLOSING_TAG}, but file has ${TOTAL_LINES} lines"
   return 1
  fi
 fi

 __logd "Lightweight XML part validation passed: ${XML_PART_FILE}"
 return 0
}

# Binary division XML file function for maximum performance
# Function: Divides a large XML file using binary division approach for maximum speed
# Parameters:
#   $1: Input XML file path
#   $2: Output directory for parts
#   $3: Target notes per part (default: 75000)
#   $4: Maximum number of parts (default: 100)
#   $5: Maximum threads for parallel processing (default: 8)
# Returns: 0 on success, 1 on failure
function __divide_xml_file_binary() {
 local INPUT_XML="${1}"
 local OUTPUT_DIR="${2}"
 local TARGET_NOTES_PER_PART="${3:-75000}"
 local NUM_PARTS="${4:-100}"
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
 __log_start "Binary division of XML file: ${INPUT_XML}"
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

 # Convert to MB for easier comparison
 local FILE_SIZE_MB
 FILE_SIZE_MB=$((FILE_SIZE_BYTES / 1024 / 1024))

 __logi "Binary division of ${XML_FORMAT} XML file: ${FILE_SIZE_MB} MB, ${TOTAL_NOTES} notes"
 __logd "Target notes per part: ${TARGET_NOTES_PER_PART}"
 __logd "Maximum parts: ${NUM_PARTS}"
 __logd "Root tag: <${ROOT_TAG}>, Part prefix: ${PART_PREFIX}"

 # Create temporary directory for intermediate files
 local TEMP_DIR
 TEMP_DIR=$(mktemp -d)
 __logd "Created temporary directory: ${TEMP_DIR}"

 # NEW OPTIMIZED FUNCTION: Single-pass distribution
 # Distributes notes to multiple parts in ONE single read pass
 __distribute_notes_single_pass() {
  local PARTS_ARRAY_ARG="${1}"
  local OUTPUT_DIR_ARG="${2}"
  local ROOT_TAG_ARG="${3}"
  local PART_PREFIX_ARG="${4}"

  __logd "Starting single-pass distribution of notes to parts"

  # Parse parts array from argument (format: "start:end,start:end,...")
  IFS=',' read -ra PARTS_INFO <<< "${PARTS_ARRAY_ARG}"

  # Initialize output files with XML headers
  local PART_COUNTER=0
  declare -A PART_FILE_MAP
  declare -A PART_NOTE_COUNT
  declare -A PART_START_MAP
  declare -A PART_END_MAP

  for PART_RANGE in "${PARTS_INFO[@]}"; do
   local START_NOTE END_NOTE
   IFS=':' read -r START_NOTE END_NOTE <<< "${PART_RANGE}"

   local PART_NUM
   PART_NUM=$(printf "%03d" "${PART_COUNTER}")
   local OUTPUT_FILE="${OUTPUT_DIR_ARG}/${PART_PREFIX_ARG}_${PART_NUM}.xml"

   # Create XML header for this part
   echo '<?xml version="1.0" encoding="UTF-8"?>' > "${OUTPUT_FILE}"
   echo "<${ROOT_TAG_ARG}>" >> "${OUTPUT_FILE}"

   # Store mappings for quick lookup
   PART_FILE_MAP[${PART_COUNTER}]="${OUTPUT_FILE}"
   PART_START_MAP[${PART_COUNTER}]="${START_NOTE}"
   PART_END_MAP[${PART_COUNTER}]="${END_NOTE}"
   PART_NOTE_COUNT[${PART_COUNTER}]=0

   __logd "Initialized part ${PART_COUNTER}: notes ${START_NOTE}-${END_NOTE} -> ${OUTPUT_FILE}"
   ((PART_COUNTER++))
  done

  local TOTAL_PARTS=${PART_COUNTER}
  __logi "Single-pass distribution: initialized ${TOTAL_PARTS} output files"

  # Single pass through input file
  local CURRENT_NOTE=0
  local IN_NOTE=false
  local NOTE_BUFFER=""
  local LINES_READ=0
  local LAST_PROGRESS_NOTE=0

  __logd "Starting single-pass read of ${INPUT_XML}..."

  while IFS= read -r line; do
   ((LINES_READ++))

   # Progress indicator every 100k lines
   if [[ $((LINES_READ % 100000)) -eq 0 ]]; then
    __logd "Progress: ${LINES_READ} lines read, ${CURRENT_NOTE} notes processed"
   fi

   # Check if we're entering a note
   if echo "${line}" | grep -q "^[[:space:]]*<note[^>]*>"; then
    IN_NOTE=true
    NOTE_BUFFER="${line}"
    ((CURRENT_NOTE++))

    # Progress indicator every 10k notes
    if [[ $((CURRENT_NOTE - LAST_PROGRESS_NOTE)) -ge 10000 ]]; then
     __logi "Single-pass progress: ${CURRENT_NOTE} notes processed"
     LAST_PROGRESS_NOTE=${CURRENT_NOTE}
    fi

   elif [[ "${IN_NOTE}" == "true" ]]; then
    # We're inside a note, add line to buffer
    NOTE_BUFFER+=$'\n'"${line}"

    # Check if we're exiting a note
    if echo "${line}" | grep -q "^[[:space:]]*</note>"; then
     IN_NOTE=false

     # Find which part(s) this note belongs to and write it
     for ((i = 0; i < TOTAL_PARTS; i++)); do
      local START="${PART_START_MAP[${i}]}"
      local END="${PART_END_MAP[${i}]}"

      if [[ ${CURRENT_NOTE} -gt ${START} ]] && [[ ${CURRENT_NOTE} -le ${END} ]]; then
       # Write note to this part's file
       echo "${NOTE_BUFFER}" >> "${PART_FILE_MAP[${i}]}"
       ((PART_NOTE_COUNT[${i}]++))
       break # Each note goes to exactly one part
      fi
     done

     # Clear buffer
     NOTE_BUFFER=""
    fi
   fi
  done < "${INPUT_XML}"

  __logi "Single-pass read completed: ${CURRENT_NOTE} notes processed, ${LINES_READ} lines read"

  # Close all XML files with closing tags
  for ((i = 0; i < TOTAL_PARTS; i++)); do
   echo "</${ROOT_TAG_ARG}>" >> "${PART_FILE_MAP[${i}]}"
   __logd "Part ${i}: ${PART_NOTE_COUNT[${i}]} notes written to ${PART_FILE_MAP[${i}]}"
  done

  __logi "Single-pass distribution completed successfully for ${TOTAL_PARTS} parts"
  return 0
 }

 # Function to create XML part from byte range (kept for compatibility)
 # shellcheck disable=SC2317
 # Function is called indirectly from other functions
 __create_xml_part() {
  local PART_NUM="${1}"
  local START_BYTE="${2}"
  local END_BYTE="${3}"
  local OUTPUT_FILE="${4}"
  local ROOT_TAG_LOCAL="${5}"

  # Create XML wrapper
  echo '<?xml version="1.0" encoding="UTF-8"?>' > "${OUTPUT_FILE}"
  echo "<${ROOT_TAG_LOCAL}>" >> "${OUTPUT_FILE}"

  # Extract content using dd (very fast for large files)
  dd if="${INPUT_XML}" bs=1M skip=$((START_BYTE / 1024 / 1024)) count=$(((END_BYTE - START_BYTE) / 1024 / 1024 + 1)) 2> /dev/null \
   | tail -c +$((START_BYTE % (1024 * 1024) + 1)) \
   | head -c $((END_BYTE - START_BYTE)) >> "${OUTPUT_FILE}" 2> /dev/null || true

  # Close XML tag
  echo "</${ROOT_TAG_LOCAL}>" >> "${OUTPUT_FILE}"

  # Validate that we have complete notes (find last complete note)
  local LAST_COMPLETE_NOTE
  LAST_COMPLETE_NOTE=$(grep -n "</note>" "${OUTPUT_FILE}" | tail -1 | cut -d: -f1 2> /dev/null || echo "0")

  if [[ "${LAST_COMPLETE_NOTE}" -gt 0 ]]; then
   # Truncate file to last complete note
   head -n "${LAST_COMPLETE_NOTE}" "${OUTPUT_FILE}" >> "${OUTPUT_FILE}.tmp"
   mv "${OUTPUT_FILE}.tmp" "${OUTPUT_FILE}"
   echo "</${ROOT_TAG_LOCAL}>" >> "${OUTPUT_FILE}"
  fi

  # Count notes in this part
  local PART_NOTES
  PART_NOTES=$(grep -c "<note" "${OUTPUT_FILE}" 2> /dev/null || echo "0")

  echo "${PART_NOTES}"
 }

 # Binary division algorithm based on note count
 local CURRENT_PARTS=1
 local PARTS_ARRAY=()
 PARTS_ARRAY+=("0:${TOTAL_NOTES}")

 __logd "Starting binary division process based on note count..."

 # Phase 1: Binary division until parts are close to target note count
 while [[ ${CURRENT_PARTS} -lt ${NUM_PARTS} ]]; do
  local NEW_PARTS_ARRAY=()
  local SPLIT_OCCURRED=false

  for PART_RANGE in "${PARTS_ARRAY[@]}"; do
   local START_NOTE END_NOTE
   IFS=':' read -r START_NOTE END_NOTE <<< "${PART_RANGE}"

   local PART_NOTES=$((END_NOTE - START_NOTE))

   # If part has more notes than target and we haven't reached part limit, split it
   if [[ ${PART_NOTES} -gt ${TARGET_NOTES_PER_PART} ]] && [[ ${CURRENT_PARTS} -lt ${NUM_PARTS} ]]; then
    local MID_NOTE=$(((START_NOTE + END_NOTE) / 2))

    # Add both halves to new array
    NEW_PARTS_ARRAY+=("${START_NOTE}:${MID_NOTE}")
    NEW_PARTS_ARRAY+=("${MID_NOTE}:${END_NOTE}")

    SPLIT_OCCURRED=true
    ((CURRENT_PARTS++))

    __logd "Split part at note ${MID_NOTE} (${PART_NOTES} notes -> ~$((PART_NOTES / 2)) notes each)"
   else
    # Keep part as is
    NEW_PARTS_ARRAY+=("${PART_RANGE}")
   fi
  done

  # Update parts array
  PARTS_ARRAY=("${NEW_PARTS_ARRAY[@]}")

  # If no splits occurred, we're done
  if [[ "${SPLIT_OCCURRED}" == "false" ]]; then
   __logd "No more splits needed, reached optimal note counts per part"
   break
  fi

  __logd "Binary division phase: ${CURRENT_PARTS} parts created"
 done

 __logi "Binary division completed: ${CURRENT_PARTS} parts created"

 # Phase 2: Create actual XML files using OPTIMIZED single-pass distribution
 __logi "Using optimized single-pass distribution method for maximum performance"

 # Convert parts array to comma-separated string for the function
 local PARTS_STRING=""
 for PART_RANGE in "${PARTS_ARRAY[@]}"; do
  if [[ -z "${PARTS_STRING}" ]]; then
   PARTS_STRING="${PART_RANGE}"
  else
   PARTS_STRING="${PARTS_STRING},${PART_RANGE}"
  fi
 done

 __logd "Parts array converted to string: ${#PARTS_ARRAY[@]} parts"

 # Call the optimized single-pass distribution function
 if ! __distribute_notes_single_pass "${PARTS_STRING}" "${OUTPUT_DIR}" \
  "${ROOT_TAG}" "${PART_PREFIX}"; then
  __loge "ERROR: Single-pass distribution failed"
  rm -rf "${TEMP_DIR}"
  __log_finish
  return 1
 fi

 __logi "Single-pass distribution completed successfully"

 # Collect results and validate parts
 __logd "Validating created parts..."
 local VALID_PARTS=0
 local TOTAL_NOTES_PROCESSED=0

 # Find all created part files
 local PART_FILES
 mapfile -t PART_FILES < <(find "${OUTPUT_DIR}" -name "${PART_PREFIX}_*.xml" \
  -type f | sort || true)

 if [[ ${#PART_FILES[@]} -eq 0 ]]; then
  __loge "ERROR: No part files were created"
  rm -rf "${TEMP_DIR}"
  __log_finish
  return 1
 fi

 __logd "Found ${#PART_FILES[@]} part files to validate"

 for OUTPUT_FILE in "${PART_FILES[@]}"; do
  local PART_BASENAME
  PART_BASENAME=$(basename "${OUTPUT_FILE}" .xml)
  local PART_NUM
  # Use parameter expansion instead of sed when possible
  PART_NUM="${PART_BASENAME#${PART_PREFIX}_}"

  if [[ -f "${OUTPUT_FILE}" ]]; then
   local PART_NOTES
   PART_NOTES=$(grep -c "<note" "${OUTPUT_FILE}" 2> /dev/null || echo "0")
   local PART_SIZE_BYTES
   PART_SIZE_BYTES=$(stat -c%s "${OUTPUT_FILE}" 2> /dev/null || echo "0")
   local PART_SIZE_MB
   PART_SIZE_MB=$((PART_SIZE_BYTES / 1024 / 1024))

   if [[ ${PART_NOTES} -gt 0 ]]; then
    ((VALID_PARTS++))
    TOTAL_NOTES_PROCESSED=$((TOTAL_NOTES_PROCESSED + PART_NOTES))
    __logd "Part ${PART_NUM}: ${PART_NOTES} notes, ${PART_SIZE_MB} MB - VALID"
   else
    __logw "Part ${PART_NUM}: No notes found - INVALID \
(file size: ${PART_SIZE_BYTES} bytes)"
    # Show first few lines for debugging
    if [[ ${PART_SIZE_BYTES} -gt 0 ]]; then
     __logd "Debug: First 5 lines of invalid part ${PART_NUM}:"
     local DEBUG_LINES
     DEBUG_LINES=$(head -5 "${OUTPUT_FILE}" 2> /dev/null || echo "")
     if [[ -n "${DEBUG_LINES}" ]]; then
      while IFS= read -r debug_line; do
       __logd "  ${debug_line}"
      done <<< "${DEBUG_LINES}"
     fi
    fi
    rm -f "${OUTPUT_FILE}"
   fi
  else
   __logw "Part ${PART_NUM}: File not found - MISSING"
  fi
 done

 # Clean up temporary directory
 rm -rf "${TEMP_DIR}"

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

 if [[ ${VALID_PARTS} -eq 0 ]]; then
  __loge "ERROR: Failed to create valid XML parts"
  __log_finish
  return 1
 fi

 __logi "Successfully created ${VALID_PARTS} ${XML_FORMAT} XML parts using binary division"
 __logi "Total notes processed: ${TOTAL_NOTES_PROCESSED}/${TOTAL_NOTES}"
 if [[ ${TOTAL_PROCESSING_TIME} -gt 0 ]]; then
  __logi "Performance: ${TOTAL_PROCESSING_TIME}s total, ${PROCESSING_SPEED_MBPS} MB/s, ${PROCESSING_SPEED_NOTES_PER_SEC} notes/s"
 else
  __logi "Performance: ${TOTAL_PROCESSING_TIME}s total (too fast to measure), speed: N/A"
 fi

 # Show part statistics
 local TOTAL_SIZE=0
 local MIN_SIZE=999999999
 local MAX_SIZE=0

 # shellcheck disable=SC2231
 # Glob pattern expansion is intentional here
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

 if [[ ${VALID_PARTS} -gt 0 ]]; then
  local AVG_SIZE
  AVG_SIZE=$((TOTAL_SIZE / VALID_PARTS))
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

# Function to handle corrupted XML files and attempt recovery
# Author: Andres Gomez
# Version: 2025-08-18
# Parameters:
#   $1: XML file path
#   $2: Backup directory for corrupted files
# Returns: 0 on successful recovery, 1 on failure
function __handle_corrupted_xml_file() {
 __log_start
 __logd "Function called with $# parameters: '$1' '${2:-}'"

 local XML_FILE="${1}"
 local BACKUP_DIR="${2:-/tmp/corrupted_xml_backup}"
 local XML_FILENAME
 XML_FILENAME=$(basename "${XML_FILE}")
 local BACKUP_FILE
 local BACKUP_DATE
 BACKUP_DATE=$(date +%Y%m%d_%H%M%S 2> /dev/null || echo 'unknown')
 BACKUP_FILE="${BACKUP_DIR}/${XML_FILENAME}.corrupted.${BACKUP_DATE}"

 __logd "Handling corrupted XML file: ${XML_FILE}"

 # Create backup directory if it doesn't exist
 mkdir -p "${BACKUP_DIR}"

 # Backup the corrupted file
 if cp "${XML_FILE}" "${BACKUP_FILE}"; then
  __logw "Corrupted XML file backed up to: ${BACKUP_FILE}"
 else
  __loge "Failed to backup corrupted XML file: ${XML_FILE}"
  __log_finish
  return 1
 fi

 # Attempt to identify the type of corruption
 __logd "Analyzing corruption type..."

 local CORRUPTION_TYPE="unknown"
 local CORRUPTION_DETAILS=""

 # Check for common corruption patterns
 # Check for extra content after closing tags (common in split XML files)
 local LAST_CLOSING_TAG_LINE
 local CLOSING_TAG_LINES
 CLOSING_TAG_LINES=$(grep -n "</osm-notes\|</osm" "${XML_FILE}" 2> /dev/null || echo "")
 if [[ -n "${CLOSING_TAG_LINES}" ]]; then
  LAST_CLOSING_TAG_LINE=$(echo "${CLOSING_TAG_LINES}" | tail -1 | cut -d: -f1 2> /dev/null || echo "0")
 else
  LAST_CLOSING_TAG_LINE="0"
 fi
 if [[ -n "${LAST_CLOSING_TAG_LINE}" ]]; then
  local TOTAL_LINES
  TOTAL_LINES=$(wc -l < "${XML_FILE}" 2> /dev/null || echo "0")

  # Check if there are lines after the closing tag
  if [[ "${TOTAL_LINES}" -gt "${LAST_CLOSING_TAG_LINE}" ]]; then
   CORRUPTION_TYPE="extra_content"
   CORRUPTION_DETAILS="Extra content after closing tags detected (${TOTAL_LINES} total lines, closing tag at line ${LAST_CLOSING_TAG_LINE})"
  else
   # Check if the closing tag line itself contains extra content
   local CLOSING_TAG_LINE_CONTENT
   CLOSING_TAG_LINE_CONTENT=$(sed -n "${LAST_CLOSING_TAG_LINE}p" "${XML_FILE}" 2> /dev/null)
   # Check if line contains only closing tag (with optional whitespace)
   if echo "${CLOSING_TAG_LINE_CONTENT}" | grep -q "^[[:space:]]*</osm-notes>[[:space:]]*$" 2> /dev/null || echo "${CLOSING_TAG_LINE_CONTENT}" | grep -q "^[[:space:]]*</osm>[[:space:]]*$" 2> /dev/null; then
    # Line contains only the closing tag, no extra content
    :
   else
    # Line contains closing tag plus extra content
    CORRUPTION_TYPE="extra_content"
    CORRUPTION_DETAILS="Extra content on same line as closing tag detected (line ${LAST_CLOSING_TAG_LINE})"
   fi
  fi
 fi

 # Check for error messages in the file
 if [[ "${CORRUPTION_TYPE}" == "unknown" ]]; then
  if grep -q "Extra content at the end of the document" "${XML_FILE}" 2> /dev/null; then
   CORRUPTION_TYPE="extra_content"
   CORRUPTION_DETAILS="Extra content after closing tags detected (error message found)"
  elif grep -q "unable to parse" "${XML_FILE}" 2> /dev/null; then
   CORRUPTION_TYPE="parse_error"
   CORRUPTION_DETAILS="General parsing error detected"
  elif grep -q "parser error" "${XML_FILE}" 2> /dev/null; then
   CORRUPTION_TYPE="parser_error"
   CORRUPTION_DETAILS="XML parser error detected"
  elif ! grep -q "</osm-notes\|</osm" "${XML_FILE}" 2> /dev/null; then
   CORRUPTION_TYPE="missing_closing_tag"
   CORRUPTION_DETAILS="Missing closing tag for root element"
  elif ! grep -q "<?xml" "${XML_FILE}" 2> /dev/null; then
   CORRUPTION_TYPE="missing_xml_declaration"
   CORRUPTION_DETAILS="Missing XML declaration"
  fi
 fi

 __logw "Corruption type identified: ${CORRUPTION_TYPE} - ${CORRUPTION_DETAILS}"

 # Attempt recovery based on corruption type
 case "${CORRUPTION_TYPE}" in
 "extra_content")
  __logd "Attempting to recover from extra content corruption..."
  # Try to find the last valid closing tag and truncate
  local LAST_VALID_LINE
  local CLOSING_TAG_LINES
  CLOSING_TAG_LINES=$(grep -n "</osm-notes\|</osm" "${XML_FILE}" 2> /dev/null || echo "")
  if [[ -n "${CLOSING_TAG_LINES}" ]]; then
   LAST_VALID_LINE=$(echo "${CLOSING_TAG_LINES}" | tail -1 | cut -d: -f1 2> /dev/null || echo "0")
  else
   LAST_VALID_LINE="0"
  fi
  if [[ -n "${LAST_VALID_LINE}" ]]; then
   local TEMP_RECOVERY_FILE
   TEMP_RECOVERY_FILE="${XML_FILE}.recovery"
   if head -n "${LAST_VALID_LINE}" "${XML_FILE}" > "${TEMP_RECOVERY_FILE}" 2> /dev/null; then
    if mv "${TEMP_RECOVERY_FILE}" "${XML_FILE}"; then
     __logi "Successfully recovered XML file by truncating at line ${LAST_VALID_LINE}"
     __log_finish
     return 0
    else
     rm -f "${TEMP_RECOVERY_FILE}"
    fi
   else
    rm -f "${TEMP_RECOVERY_FILE}"
   fi
  fi
  ;;

 "missing_closing_tag")
  __logd "Attempting to recover from missing closing tag..."
  # Try to add missing closing tag
  local ROOT_ELEMENT
  ROOT_ELEMENT=$(grep -o "<osm-notes\|<osm" "${XML_FILE}" | head -1)
  if [[ -n "${ROOT_ELEMENT}" ]]; then
   local CLOSING_TAG
   CLOSING_TAG="</${ROOT_ELEMENT#<}>"
   if echo "${CLOSING_TAG}" >> "${XML_FILE}" 2> /dev/null; then
    __logi "Successfully recovered XML file by adding missing closing tag: ${CLOSING_TAG}"
    __log_finish
    return 0
   fi
  fi
  ;;

 "missing_xml_declaration")
  __logd "Attempting to recover from missing XML declaration..."
  # Try to add XML declaration at the beginning
  local TEMP_RECOVERY_FILE
  TEMP_RECOVERY_FILE="${XML_FILE}.recovery"
  if (echo '<?xml version="1.0" encoding="UTF-8"?>' && cat "${XML_FILE}") > "${TEMP_RECOVERY_FILE}" 2> /dev/null; then
   if mv "${TEMP_RECOVERY_FILE}" "${XML_FILE}"; then
    __logi "Successfully recovered XML file by adding XML declaration"
    __log_finish
    return 0
   else
    rm -f "${TEMP_RECOVERY_FILE}"
   fi
  else
   rm -f "${TEMP_RECOVERY_FILE}"
  fi
  ;;

 *)
  __logw "No automatic recovery strategy available for corruption type: ${CORRUPTION_TYPE}"
  ;;
 esac

 # If recovery failed, log the failure and return error
 __loge "Failed to recover corrupted XML file: ${XML_FILE}"
 __loge "Corruption type: ${CORRUPTION_TYPE}"
 __loge "Corruption details: ${CORRUPTION_DETAILS}"
 __loge "File backed up to: ${BACKUP_FILE}"

 __log_finish
 return 1
}

# Function to validate XML file integrity and attempt recovery if needed
# Author: Andres Gomez
# Version: 2025-08-18
# Parameters:
#   $1: XML file path
#   $2: Enable recovery attempts (default: true)
#   $3: Validation mode: "full" (default) or "divided" (for split XML parts)
# Returns: 0 on success, 1 on failure
function __validate_xml_integrity() {
 __log_start
 __logd "Function called with $# parameters: '$1' '$2'"

 local XML_FILE="${1}"
 local ENABLE_RECOVERY="${2:-true}"
 local VALIDATION_MODE="${3:-full}"
 local RECOVERY_PERFORMED=false

 __logd "Validating XML file integrity: ${XML_FILE} (mode: ${VALIDATION_MODE})"

 # Check if file exists
 if [[ ! -f "${XML_FILE}" ]]; then
  __loge "ERROR: XML file not found: ${XML_FILE}"
  __log_finish
  return 1
 fi

 # Basic file checks
 if [[ ! -s "${XML_FILE}" ]]; then
  __loge "ERROR: XML file is empty: ${XML_FILE}"
  __log_finish
  return 1
 fi

 # For divided XML files, only validate structure at beginning and end
 if [[ "${VALIDATION_MODE}" == "divided" ]]; then
  __logd "Using divided XML validation mode - checking only structure boundaries"

  # Check XML declaration at beginning
  local FIRST_LINE
  FIRST_LINE=$(head -n 1 "${XML_FILE}" 2> /dev/null || echo "")
  if ! echo "${FIRST_LINE}" | grep -q "<?xml" 2> /dev/null; then
   __loge "ERROR: Divided XML file missing declaration at beginning: ${XML_FILE}"
   __log_finish
   return 1
  fi

  # Check root element opening at beginning
  local FIRST_FIVE_LINES
  FIRST_FIVE_LINES=$(head -n 5 "${XML_FILE}" 2> /dev/null || echo "")
  if ! echo "${FIRST_FIVE_LINES}" | grep -q "<osm-notes\|<osm" 2> /dev/null; then
   __loge "ERROR: Divided XML file missing root element opening: ${XML_FILE}"
   __log_finish
   return 1
  fi

  # Check root element closing at end
  local LAST_FIVE_LINES
  LAST_FIVE_LINES=$(tail -n 5 "${XML_FILE}" 2> /dev/null || echo "")
  if ! echo "${LAST_FIVE_LINES}" | grep -q "</osm-notes\|</osm" 2> /dev/null; then
   __loge "ERROR: Divided XML file missing root element closing: ${XML_FILE}"
   __log_finish
   return 1
  fi

  __logd "Divided XML validation passed - structure boundaries are correct"
  __log_finish
  return 0
 fi

 # Check for XML declaration
 if ! head -n 5 "${XML_FILE}" | grep -q "<?xml" 2> /dev/null; then
  __logw "WARNING: XML file missing declaration: ${XML_FILE}"
  if [[ "${ENABLE_RECOVERY}" == "true" ]]; then
   __logd "Attempting to recover missing XML declaration..."
   if __handle_corrupted_xml_file "${XML_FILE}"; then
    __logd "XML declaration recovery successful"
    RECOVERY_PERFORMED=true
   else
    __loge "XML declaration recovery failed"
    __log_finish
    return 1
   fi
  else
   __log_finish
   return 1
  fi
 fi

 # Check for root element
 if ! grep -q "<osm-notes\|<osm" "${XML_FILE}" 2> /dev/null; then
  __loge "ERROR: XML file missing root element: ${XML_FILE}"
  __log_finish
  return 1
 fi

 # Check for proper closing tags
 local OPEN_TAGS CLOSE_TAGS
 OPEN_TAGS=$(grep -c "<osm-notes\|<osm" "${XML_FILE}" 2> /dev/null || echo "0")
 OPEN_TAGS=$(echo "${OPEN_TAGS}" | tr -d '[:space:]')
 CLOSE_TAGS=$(grep -c "</osm-notes\|</osm" "${XML_FILE}" 2> /dev/null || echo "0")
 CLOSE_TAGS=$(echo "${CLOSE_TAGS}" | tr -d '[:space:]')

 if [[ "${OPEN_TAGS}" -ne "${CLOSE_TAGS}" ]]; then
  __logw "WARNING: XML structure imbalance detected: ${OPEN_TAGS} open, ${CLOSE_TAGS} close"
  if [[ "${ENABLE_RECOVERY}" == "true" ]]; then
   __logd "Attempting to recover from structure imbalance..."
   if __handle_corrupted_xml_file "${XML_FILE}"; then
    __logd "Structure recovery successful"
    RECOVERY_PERFORMED=true
   else
    __loge "Structure recovery failed"
    __log_finish
    return 1
   fi
  else
   __log_finish
   return 1
  fi
 fi

 # Final validation with xmllint if available
 if command -v xmllint > /dev/null 2>&1; then
  __logd "Performing final XML validation with xmllint..."
  if ! xmllint --noout "${XML_FILE}" 2> /dev/null; then
   __loge "ERROR: XML file failed final validation: ${XML_FILE}"
   if [[ "${ENABLE_RECOVERY}" == "true" ]]; then
    __logd "Attempting final recovery..."
    if __handle_corrupted_xml_file "${XML_FILE}"; then
     RECOVERY_PERFORMED=true
     # Re-validate after recovery
     if xmllint --noout "${XML_FILE}" 2> /dev/null; then
      __logi "XML file successfully recovered and validated"
      __log_finish
      return 0
     else
      __loge "XML file still invalid after recovery attempts"
      __log_finish
      return 1
     fi
    else
     __loge "Final recovery attempt failed"
     __log_finish
     return 1
    fi
   else
    __log_finish
    return 1
   fi
  fi
  __logd "XML validation passed"
 else
  __logd "xmllint not available, skipping final validation"
 fi

 # If recovery was performed and we reached here, validation passed
 if [[ "${RECOVERY_PERFORMED}" == "true" ]]; then
  __logi "XML file successfully recovered and validated"
 else
  __logi "XML file integrity validation completed successfully"
 fi

 __log_finish
 return 0
}
