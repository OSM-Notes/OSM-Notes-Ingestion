#!/bin/bash
# Consolidated Parallel Processing Functions for OSM-Notes-profile
# This file consolidates all parallel processing functions to eliminate duplication
#
# Author: Andres Gomez (AngocA)
# Version: 2025-01-27
# Description: Centralized parallel processing functions for better maintainability

# Load properties if not already loaded
if [[ -z "${MAX_THREADS:-}" ]] && [[ -f "${SCRIPT_BASE_DIRECTORY:-.}/etc/properties.sh" ]]; then
 source "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh"
elif [[ -z "${MAX_THREADS:-}" ]] && [[ -f "./etc/properties.sh" ]]; then
 source "./etc/properties.sh"
fi

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

# Process XML parts in parallel (consolidated version)
# Parameters:
#   $1: Input directory containing XML parts
#   $2: XSLT file for processing
#   $3: Output directory for CSV files
#   $4: Maximum number of workers (optional, default: 4)
# Returns: 0 on success, 1 on failure
function __processXmlPartsParallel() {
 __log_start
 __logd "Processing XML parts in parallel (consolidated version)."

 local INPUT_DIR="${1}"
 local XSLT_FILE="${2}"
 local OUTPUT_DIR="${3}"
 local MAX_WORKERS="${4:-${MAX_THREADS:-4}}"

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

 # Find all XML parts
 local XML_FILES
 mapfile -t XML_FILES < <(find "${INPUT_DIR}" -name "*.xml" -type f | sort)

 if [[ ${#XML_FILES[@]} -eq 0 ]]; then
  __logw "WARNING: No XML files found in ${INPUT_DIR}"
  __log_finish
  return 0
 fi

 __logi "Processing ${#XML_FILES[@]} XML parts with max ${MAX_WORKERS} workers."

 # Process files in parallel
 local PIDS=()
 local PROCESSED=0

 for XML_FILE in "${XML_FILES[@]}"; do
  local BASE_NAME
  BASE_NAME=$(basename "${XML_FILE}" .xml)
  local OUTPUT_FILE="${OUTPUT_DIR}/${BASE_NAME}.csv"

  # Process XML file
  if xsltproc "${XSLT_FILE}" "${XML_FILE}" > "${OUTPUT_FILE}" 2> /dev/null; then
   __logd "Successfully processed: ${XML_FILE} -> ${OUTPUT_FILE}"
   ((PROCESSED++))
  else
   __loge "ERROR: Failed to process: ${XML_FILE}"
  fi

  # Limit concurrent processes
  if [[ ${#PIDS[@]} -ge ${MAX_WORKERS} ]]; then
   wait "${PIDS[0]}"
   PIDS=("${PIDS[@]:1}")
  fi
 done

 # Wait for remaining processes
 for PID in "${PIDS[@]}"; do
  wait "${PID}"
 done

 __logi "Parallel processing completed. Processed ${PROCESSED}/${#XML_FILES[@]} files."
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
    # Find the next note start line or end of file
    local NEXT_INDEX=$((END_INDEX + 1))
    END_LINE=${NOTE_LINE_ARRAY[NEXT_INDEX]}
    if [[ -z "${END_LINE}" ]]; then
     END_LINE=$(wc -l < "${XML_FILE}")
    fi
   else
    # Last part - go to end of file
    END_LINE=$(wc -l < "${XML_FILE}")
   fi
   
   __logd "Creating part ${i}: lines ${START_LINE}-${END_LINE}"
   
   # Create XML wrapper
   echo '<?xml version="1.0" encoding="UTF-8"?>' > "${OUTPUT_FILE}"
   echo '<osm-notes>' >> "${OUTPUT_FILE}"
   
   # Extract lines using sed (memory efficient)
   sed -n "${START_LINE},${END_LINE}p" "${XML_FILE}" >> "${OUTPUT_FILE}"
   
   echo '</osm-notes>' >> "${OUTPUT_FILE}"
   
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
 PART_NUM="${BASENAME_PART//part_/}"

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
 __logd "Processing notes with xsltproc: ${XSLT_NOTES_FILE_LOCAL} -> ${OUTPUT_NOTES_PART}"
 xsltproc --stringparam default-timestamp "${CURRENT_TIMESTAMP}" -o "${OUTPUT_NOTES_PART}" "${XSLT_NOTES_FILE_LOCAL}" "${XML_PART}"
 if [[ ! -f "${OUTPUT_NOTES_PART}" ]]; then
  __loge "Notes CSV file was not created: ${OUTPUT_NOTES_PART}"
  __log_finish
  return 1
 fi

 # Process comments
 __logd "Processing comments with xsltproc: ${XSLT_COMMENTS_FILE_LOCAL} -> ${OUTPUT_COMMENTS_PART}"
 xsltproc --stringparam default-timestamp "${CURRENT_TIMESTAMP}" -o "${OUTPUT_COMMENTS_PART}" "${XSLT_COMMENTS_FILE_LOCAL}" "${XML_PART}"
 if [[ ! -f "${OUTPUT_COMMENTS_PART}" ]]; then
  __loge "Comments CSV file was not created: ${OUTPUT_COMMENTS_PART}"
  __log_finish
  return 1
 fi

 # Process text comments
 __logd "Processing text comments with xsltproc: ${XSLT_TEXT_FILE_LOCAL} -> ${OUTPUT_TEXT_PART}"
 xsltproc --stringparam default-timestamp "${CURRENT_TIMESTAMP}" -o "${OUTPUT_TEXT_PART}" "${XSLT_TEXT_FILE_LOCAL}" "${XML_PART}"
 if [[ ! -f "${OUTPUT_TEXT_PART}" ]]; then
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
 PART_NUM="${BASENAME_PART//part_/}"

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
 __logd "Processing notes with xsltproc: ${XSLT_NOTES_FILE_LOCAL} -> ${OUTPUT_NOTES_PART}"
 xsltproc --stringparam default-timestamp "${CURRENT_TIMESTAMP}" -o "${OUTPUT_NOTES_PART}" "${XSLT_NOTES_FILE_LOCAL}" "${XML_PART}"
 if [[ ! -f "${OUTPUT_NOTES_PART}" ]]; then
  __loge "Notes CSV file was not created: ${OUTPUT_NOTES_PART}"
  __log_finish
  return 1
 fi

 # Process comments
 __logd "Processing comments with xsltproc: ${XSLT_COMMENTS_FILE_LOCAL} -> ${OUTPUT_COMMENTS_PART}"
 xsltproc --stringparam default-timestamp "${CURRENT_TIMESTAMP}" -o "${OUTPUT_COMMENTS_PART}" "${XSLT_COMMENTS_FILE_LOCAL}" "${XML_PART}"
 if [[ ! -f "${OUTPUT_COMMENTS_PART}" ]]; then
  __loge "Comments CSV file was not created: ${OUTPUT_COMMENTS_PART}"
  __log_finish
  return 1
 fi

 # Process text comments
 __logd "Processing text comments with xsltproc: ${XSLT_TEXT_FILE_LOCAL} -> ${OUTPUT_TEXT_PART}"
 xsltproc --stringparam default-timestamp "${CURRENT_TIMESTAMP}" -o "${OUTPUT_TEXT_PART}" "${XSLT_TEXT_FILE_LOCAL}" "${XML_PART}"
 if [[ ! -f "${OUTPUT_TEXT_PART}" ]]; then
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
