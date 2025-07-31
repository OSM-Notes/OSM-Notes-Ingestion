#!/bin/bash

# OSM-Notes-profile - Common Functions
# This file serves as the main entry point for all common functions.
# It loads all refactored function files to maintain backward compatibility.
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-30

# shellcheck disable=SC2317,SC2155

# Define script base directory
SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Define common variables
BASENAME="$(basename "${BASH_SOURCE[0]}" .sh)"
TMP_DIR="/tmp/${BASENAME}_$$"

# Load all refactored function files
# This ensures backward compatibility while improving code organization

# Load common functions (error codes, logger, prerequisites, etc.)
if [[ -f "${SCRIPT_BASE_DIRECTORY}/bin/commonFunctions.sh" ]]; then
 # shellcheck source=commonFunctions.sh
 source "${SCRIPT_BASE_DIRECTORY}/bin/commonFunctions.sh"
else
 echo "ERROR: commonFunctions.sh not found"
 exit 1
fi

# Load validation functions
if [[ -f "${SCRIPT_BASE_DIRECTORY}/bin/validationFunctions.sh" ]]; then
 # shellcheck source=validationFunctions.sh
 source "${SCRIPT_BASE_DIRECTORY}/bin/validationFunctions.sh"
else
 echo "ERROR: validationFunctions.sh not found"
 exit 1
fi

# Load error handling functions
if [[ -f "${SCRIPT_BASE_DIRECTORY}/bin/errorHandlingFunctions.sh" ]]; then
 # shellcheck source=errorHandlingFunctions.sh
 source "${SCRIPT_BASE_DIRECTORY}/bin/errorHandlingFunctions.sh"
else
 echo "ERROR: errorHandlingFunctions.sh not found"
 exit 1
fi

# Load API-specific functions if needed
if [[ -f "${SCRIPT_BASE_DIRECTORY}/bin/processAPIFunctions.sh" ]]; then
 # shellcheck source=processAPIFunctions.sh
 source "${SCRIPT_BASE_DIRECTORY}/bin/processAPIFunctions.sh"
fi

# Load Planet-specific functions if needed
if [[ -f "${SCRIPT_BASE_DIRECTORY}/bin/processPlanetFunctions.sh" ]]; then
 # shellcheck source=processPlanetFunctions.sh
 source "${SCRIPT_BASE_DIRECTORY}/bin/processPlanetFunctions.sh"
fi

# Legacy functions that remain in this file for backward compatibility
# These functions are used by multiple scripts and haven't been moved yet

# Output CSV files for processed data
declare -r OUTPUT_NOTES_CSV_FILE="${TMP_DIR}/output-notes.csv"
declare -r OUTPUT_NOTE_COMMENTS_CSV_FILE="${TMP_DIR}/output-note_comments.csv"
declare -r OUTPUT_TEXT_COMMENTS_CSV_FILE="${TMP_DIR}/output-text_comments.csv"

# PostgreSQL SQL script files
# Check base tables.
declare -r POSTGRES_11_CHECK_BASE_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_11_checkBaseTables.sql"
declare -r POSTGRES_12_DROP_GENERIC_OBJECTS="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_12_dropGenericObjects.sql"
declare -r POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_21_createFunctionToGetCountry.sql"
declare -r POSTGRES_22_CREATE_PROC_INSERT_NOTE="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_22_createProcedure_insertNote.sql"
declare -r POSTGRES_23_CREATE_PROC_INSERT_NOTE_COMMENT="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_23_createProcedure_insertNoteComment.sql"
declare -r POSTGRES_31_ORGANIZE_AREAS="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_31_organizeAreas.sql"
declare -r POSTGRES_32_UPLOAD_NOTE_LOCATION="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_32_loadsBackupNoteLocation.sql"

# Legacy function: Process XML parts in parallel (kept for backward compatibility)
function __processXmlPartsParallel() {
 __log_start
 __logd "Processing XML parts in parallel."

 local INPUT_DIR="${1}"
 local XSLT_FILE="${2}"
 local OUTPUT_DIR="${3}"
 local MAX_WORKERS="${4:-4}"

 if [[ ! -d "${INPUT_DIR}" ]]; then
  __loge "ERROR: Input directory not found: ${INPUT_DIR}"
  return 1
 fi

 if [[ ! -f "${XSLT_FILE}" ]]; then
  __loge "ERROR: XSLT file not found: ${XSLT_FILE}"
  return 1
 fi

 # Create output directory
 mkdir -p "${OUTPUT_DIR}"

 # Find all XML parts
 local XML_FILES
 mapfile -t XML_FILES < <(find "${INPUT_DIR}" -name "*.xml" -type f)

 if [[ ${#XML_FILES[@]} -eq 0 ]]; then
  __logw "WARNING: No XML files found in ${INPUT_DIR}"
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

# Legacy function: Split XML for parallel processing (safe version)
function __splitXmlForParallelSafe() {
 __log_start
 __logd "Splitting XML for parallel processing (safe version)."

 local XML_FILE="${1}"
 local NUM_PARTS="${2:-4}"
 local OUTPUT_DIR="${3:-${TMP_DIR}}"

 if [[ ! -f "${XML_FILE}" ]]; then
  __loge "ERROR: XML file not found: ${XML_FILE}"
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 # Create output directory
 mkdir -p "${OUTPUT_DIR}"

 # Count total notes
 local TOTAL_NOTES
 TOTAL_NOTES=$(xmllint --xpath "count(//note)" "${XML_FILE}" 2> /dev/null || echo "0")

 if [[ "${TOTAL_NOTES}" -eq 0 ]]; then
  __logw "WARNING: No notes found in XML file."
  return 0
 fi

 # Calculate notes per part
 local NOTES_PER_PART
 NOTES_PER_PART=$((TOTAL_NOTES / NUM_PARTS))
 if [[ $((TOTAL_NOTES % NUM_PARTS)) -gt 0 ]]; then
  NOTES_PER_PART=$((NOTES_PER_PART + 1))
 fi

 __logi "Splitting ${TOTAL_NOTES} notes into ${NUM_PARTS} parts (${NOTES_PER_PART} notes per part)."

 # Split XML file safely
 for ((i = 0; i < NUM_PARTS; i++)); do
  local START_POS=$((i * NOTES_PER_PART + 1))
  local END_POS=$(((i + 1) * NOTES_PER_PART))

  if [[ "${END_POS}" -gt "${TOTAL_NOTES}" ]]; then
   END_POS="${TOTAL_NOTES}"
  fi

  if [[ "${START_POS}" -le "${TOTAL_NOTES}" ]]; then
   local OUTPUT_FILE="${OUTPUT_DIR}/safe_part_${i}.xml"

   # Create XML wrapper
   echo '<?xml version="1.0" encoding="UTF-8"?>' > "${OUTPUT_FILE}"
   echo '<osm-notes>' >> "${OUTPUT_FILE}"

   # Extract notes for this part safely
   for ((j = START_POS; j <= END_POS; j++)); do
    xmllint --xpath "//note[${j}]" "${XML_FILE}" 2> /dev/null >> "${OUTPUT_FILE}" || true
   done

   echo '</osm-notes>' >> "${OUTPUT_FILE}"

   __logd "Created safe part ${i}: ${OUTPUT_FILE} (notes ${START_POS}-${END_POS})"
  fi
 done

 __logi "XML splitting completed safely. Created ${NUM_PARTS} parts."
 __log_finish
}

# Error codes are defined in commonFunctions.sh

# Common variables are defined in commonFunctions.sh
# Additional variables specific to functionsProcess.sh

# Directory for Lock when inserting in the database
declare -r LOCK_OGR2OGR=/tmp/ogr2ogr.lock

# Overpass queries
# Get countries.
declare -r OVERPASS_COUNTRIES="${SCRIPT_BASE_DIRECTORY}/overpass/countries.op"
# Get maritimes.
declare -r OVERPASS_MARITIMES="${SCRIPT_BASE_DIRECTORY}/overpass/maritimes.op"

# Note location backup file
declare -r CSV_BACKUP_NOTE_LOCATION="/tmp/noteLocation.csv"
declare -r CSV_BACKUP_NOTE_LOCATION_COMPRESSED="${SCRIPT_BASE_DIRECTORY}/data/noteLocation.csv.zip"

# ogr2ogr GeoJSON test file.
declare -r GEOJSON_TEST="${SCRIPT_BASE_DIRECTORY}/json/map.geojson"

###########
# FUNCTIONS

### Logger

# Loads the logger (log4j like) tool.
# It has the following functions.
function __log() { log "${@}"; }
function __logt() { log_trace "${@}"; }
function __logd() { log_debug "${@}"; }
function __logi() { log_info "${@}"; }
function __logw() { log_warn "${@}"; }
function __loge() { log_error "${@}"; }
function __logf() { log_fatal "${@}"; }

# Starts the logger utility.
function __start_logger() {
 if [[ -f "${LOGGER_UTILITY}" ]]; then
  # Starts the logger mechanism.
  set +e
  # shellcheck disable=SC1090
  source "${LOGGER_UTILITY}"
  local -i RET=${?}
  set -e
  if [[ "${RET}" -ne 0 ]]; then
   printf "\nERROR: Invalid logger framework file.\n"
   exit "${ERROR_LOGGER_UTILITY}"
  fi
  # Logger levels: TRACE, DEBUG, INFO, WARN, ERROR.
  # shellcheck disable=SC2154
  __set_log_level "${LOG_LEVEL}"
 else
  printf "\nLogger was not found.\n"
 fi
}

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

# Function that activates the error trap.
function __trapOn() {
 __log_start
 trap '{ printf "%s ERROR: The script ${BASENAME:-} did not finish correctly. Temporary directory: ${TMP_DIR:-} - Line number: %d%s.\n" "$(date +%Y%m%d_%H:%M:%S)" "${LINENO}" "$(__validation)"; exit ${ERROR_GENERAL};}' \
  ERR
 trap '{ printf "%s WARN: The script ${BASENAME:-} was terminated. Temporary directory: ${TMP_DIR:-}\n" "$(date +%Y%m%d_%H:%M:%S)"; exit ${ERROR_GENERAL};}' \
  SIGINT SIGTERM
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

 # Check if xmlstarlet is available
 if ! command -v xmlstarlet &> /dev/null; then
  __loge "xmlstarlet is not available"
  TOTAL_NOTES=0
  export TOTAL_NOTES
  __log_finish
  return 1
 fi

 # Check if file exists
 if [[ ! -f "${XML_FILE}" ]]; then
  __loge "File not found: ${XML_FILE}"
  TOTAL_NOTES=0
  export TOTAL_NOTES
  __log_finish
  return 1
 fi

 # Get total number of notes for API format using xmlstarlet
 TOTAL_NOTES=$(xmlstarlet sel -t -v "count(/osm/note)" "${XML_FILE}" 2> /dev/null)
 local xmlstarlet_status=$?

 if [[ ${xmlstarlet_status} -ne 0 ]]; then
  __loge "Error processing XML file: ${XML_FILE}"
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

# Counts notes in XML file (Planet format)
# Parameters:
#   $1: Input XML file path
# Returns:
#   TOTAL_NOTES: Number of notes found (exported variable)
function __countXmlNotesPlanet() {
 local XML_FILE="${1}"

 __log_start
 __logi "Counting notes in XML file (Planet format) ${XML_FILE}"

 # Check if xmlstarlet is available
 if ! command -v xmlstarlet &> /dev/null; then
  __loge "xmlstarlet is not available"
  TOTAL_NOTES=0
  export TOTAL_NOTES
  __log_finish
  return 1
 fi

 # Check if file exists
 if [[ ! -f "${XML_FILE}" ]]; then
  __loge "File not found: ${XML_FILE}"
  TOTAL_NOTES=0
  export TOTAL_NOTES
  __log_finish
  return 1
 fi

 # Get total number of notes for Planet format using xmlstarlet
 TOTAL_NOTES=$(xmlstarlet sel -t -v "count(/osm-notes/note)" "${XML_FILE}" 2> /dev/null)
 local xmlstarlet_status=$?

 if [[ ${xmlstarlet_status} -ne 0 ]]; then
  __loge "Error processing XML file: ${XML_FILE}"
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

# Wrapper function for API format that uses parallel processing
# Parameters:
#   $1: XML file path
#   $2: Number of notes to split (optional, uses TOTAL_NOTES if not provided)
function __splitXmlForParallelAPI() {
 __splitXmlForParallelSafe "${1}" "API" "${2:-}"
}

# Wrapper function for Planet format that uses parallel processing
# Parameters:
#   $1: XML file path
#   $2: Number of notes to split (optional, uses TOTAL_NOTES if not provided)
function __splitXmlForParallelPlanet() {
 __splitXmlForParallelSafe "${1}" "Planet" "${2:-}"
}

# Splits XML file into parts using parallel processing to avoid file access conflicts
# Parameters:
#   $1: XML file path
#   $2: XML format type ("API" or "Planet")
#   $3: Number of notes to split (optional, uses TOTAL_NOTES if not provided)
function __splitXmlForParallelSafe() {
 local XML_FILE="${1}"
 local XML_FORMAT="${2}"
 local TOTAL_NOTES_TO_SPLIT="${3:-${TOTAL_NOTES}}"
 local PARTS="${MAX_THREADS}"
 local PARTS_DIR="${TMP_DIR}"
 local PART_PREFIX="part"

 __log_start
 __logi "Splitting XML file (${XML_FORMAT} format) ${XML_FILE} into ${PARTS} parts using parallel processing"

 # Check if input file exists
 if [[ ! -f "${XML_FILE}" ]]; then
  __loge "ERROR: Input XML file does not exist: ${XML_FILE}"
  __log_finish
  return 1
 fi

 # Check if input file is readable
 if [[ ! -r "${XML_FILE}" ]]; then
  __loge "ERROR: Input XML file is not readable: ${XML_FILE}"
  __log_finish
  return 1
 fi

 # Validate XML structure
 if ! xmllint --noout "${XML_FILE}" 2> /dev/null; then
  __loge "ERROR: Invalid XML format in file: ${XML_FILE}"
  __log_finish
  return 1
 fi

 if [[ "${TOTAL_NOTES_TO_SPLIT}" -eq 0 ]]; then
  __logi "No notes to split, skipping XML division"
  __log_finish
  return
 fi

 # Calculate notes per part (round up to ensure all notes are processed)
 local NOTES_PER_PART
 NOTES_PER_PART=$(((TOTAL_NOTES_TO_SPLIT + PARTS - 1) / PARTS))

 __logi "Notes per part: ${NOTES_PER_PART}"

 # Create a function to process a single part
 process_part() {
  local PART="${1}"
  local START="${2}"
  local END="${3}"
  local OUTPUT_FILE="${4}"
  local XML_FORMAT_LOCAL="${5}"

  __logi "Creating part ${PART}: notes ${START}-${END} -> ${OUTPUT_FILE}"

  # Use different XPath selector based on format
  local XPATH_SELECTOR
  if [[ "${XML_FORMAT_LOCAL}" == "API" ]]; then
   XPATH_SELECTOR="/osm/note[position() >= ${START} and position() <= ${END}]"
  else
   XPATH_SELECTOR="/osm-notes/note[position() >= ${START} and position() <= ${END}]"
  fi

  # Extract XML part using xmlstarlet with proper structure
  # First, create a temporary file with the selected notes
  xmlstarlet sel -t \
   -m "${XPATH_SELECTOR}" -c . -n \
   "${XML_FILE}" > "${OUTPUT_FILE}.tmp"

  # Then wrap the content in proper XML structure
  {
   echo '<?xml version="1.0" encoding="UTF-8"?>'
   if [[ "${XML_FORMAT_LOCAL}" == "API" ]]; then
    echo '<osm>'
   else
    echo '<osm-notes>'
   fi
   cat "${OUTPUT_FILE}.tmp"
   if [[ "${XML_FORMAT_LOCAL}" == "API" ]]; then
    echo '</osm>'
   else
    echo '</osm-notes>'
   fi
  } > "${OUTPUT_FILE}"

  # Clean up temporary file
  rm -f "${OUTPUT_FILE}.tmp"

  # Validate the generated XML file
  if [[ ! -f "${OUTPUT_FILE}" ]]; then
   __loge "ERROR: XML part file was not created: ${OUTPUT_FILE}"
   return 1
  fi

  # Check if file is empty
  if [[ ! -s "${OUTPUT_FILE}" ]]; then
   __logw "WARNING: XML part file is empty: ${OUTPUT_FILE}"
  fi

  # Validate XML structure first
  if ! xmllint --noout "${OUTPUT_FILE}" 2> /dev/null; then
   __logw "WARNING: XML validation failed, attempting to fix encoding issues..."

   # Check if there are HTML entities in XML structure (not in text content)
   if grep -q "&lt;\|&gt;" "${OUTPUT_FILE}"; then
    __logw "WARNING: Found HTML entities in XML structure, attempting selective fix..."

    # Create a temporary file for the fix
    local TEMP_FILE="${OUTPUT_FILE}.temp"

    # Use a more sophisticated approach to fix only XML structure entities
    # This preserves HTML entities in text content while fixing XML structure
    awk '
     BEGIN { in_text_content = 0; in_tag = 0; in_attribute_value = 0; }
     {
       line = $0
       # Process line character by character to distinguish between XML structure and text content
       result = ""
       i = 1
       while (i <= length(line)) {
         char = substr(line, i, 1)
         if (char == "<") {
           # Start of XML tag - fix HTML entities in tag name and attribute names only
           in_tag = 1
           in_attribute_value = 0
           result = result char
           i++
           # Process the tag content
           while (i <= length(line) && substr(line, i, 1) != ">") {
             if (substr(line, i, 1) == "=") {
               # Start of attribute value
               in_attribute_value = 1
               result = result substr(line, i, 1)
               i++
             } else if (substr(line, i, 1) == "\"") {
               # Toggle attribute value state
               in_attribute_value = !in_attribute_value
               result = result substr(line, i, 1)
               i++
             } else if (in_attribute_value) {
               # Inside attribute value - preserve HTML entities
               result = result substr(line, i, 1)
               i++
             } else {
               # Outside attribute value - fix HTML entities in tag/attribute names
               if (substr(line, i, 4) == "&lt;") {
                 result = result "<"
                 i += 4
               } else if (substr(line, i, 4) == "&gt;") {
                 result = result ">"
                 i += 4
               } else {
                 result = result substr(line, i, 1)
                 i++
               }
             }
           }
           if (i <= length(line)) {
             result = result substr(line, i, 1)  # Add the closing ">"
             i++
           }
         } else {
           # Text content - preserve HTML entities
           result = result char
           i++
         }
       }
       print result
     }' "${OUTPUT_FILE}" > "${TEMP_FILE}"

    # Replace original file with fixed version
    mv "${TEMP_FILE}" "${OUTPUT_FILE}"
    __logi "Selectively fixed HTML entities in XML structure: ${OUTPUT_FILE}"
   fi

   # Validate again after fix
   if ! xmllint --noout "${OUTPUT_FILE}" 2> /dev/null; then
    __loge "ERROR: Invalid XML structure in file: ${OUTPUT_FILE} after encoding fix"
    return 1
   fi
  fi

  __logd "Validated XML part ${PART}: ${OUTPUT_FILE}"
 }

 # Export the function for parallel execution
 export -f process_part

 # Process parts in parallel
 local PART
 for PART in $(seq 1 "${PARTS}"); do
  local START
  local END
  START=$(((PART - 1) * NOTES_PER_PART + 1))
  END=$((PART * NOTES_PER_PART))

  # Ensure last part doesn't exceed total notes
  if [[ "${END}" -gt "${TOTAL_NOTES_TO_SPLIT}" ]]; then
   END="${TOTAL_NOTES_TO_SPLIT}"
  fi

  # Skip if start exceeds total notes
  if [[ "${START}" -gt "${TOTAL_NOTES_TO_SPLIT}" ]]; then
   break
  fi

  local OUTPUT_FILE
  OUTPUT_FILE="${PARTS_DIR}/${PART_PREFIX}_${PART}.xml"

  # Process this part in background
  (
   process_part "${PART}" "${START}" "${END}" "${OUTPUT_FILE}" "${XML_FORMAT}"
  ) &
 done

 # Wait for all background jobs to complete
 wait
 local WAIT_EXIT_CODE=${?}
 if [[ ${WAIT_EXIT_CODE} -ne 0 ]]; then
  __loge "ERROR: One or more XML splitting jobs failed"
  return 1
 fi

 __logi "XML splitting completed. Parts saved in: ${PARTS_DIR}"
 __log_finish
}

# Processes XML parts using traditional background jobs
# Parameters:
#   $1: Processing function name
function __processXmlPartsParallel() {
 local PROCESS_FUNCTION="${1}"
 local PARTS_DIR="${TMP_DIR}"
 local PART_PREFIX="part"

 __log_start
 __logi "Processing XML parts in ${PARTS_DIR} with ${MAX_THREADS} background jobs"

 # Process parts using traditional background jobs
 for XML_PART in $(find "${PARTS_DIR}" -name "${PART_PREFIX}_*.xml" | sort); do
  (
   __logi "Starting processing ${XML_PART} - ${BASHPID}."
   "${PROCESS_FUNCTION}" "${XML_PART}" >> "${LOG_FILENAME}.${BASHPID}" 2>&1 || true
   __logi "Finished processing ${XML_PART} - ${BASHPID}."
   if [[ -n "${CLEAN}" ]] && [[ "${CLEAN}" = true ]]; then
    rm -f "${LOG_FILENAME}.${BASHPID}"
   else
    mv "${LOG_FILENAME}.${BASHPID}" "${TMP_DIR}/${BASENAME}.old.${BASHPID}"
   fi
  ) &
  __logi "Check log per thread for more information."
  # Wait between starting background jobs to prevent overwhelming the system
  sleep 2
 done

 # Wait for all jobs to complete
 FAIL=0
 for JOB in $(jobs -p); do
  echo "${JOB}"
  set +e
  wait "${JOB}"
  RET="${?}"
  set -e
  if [[ "${RET}" -ne 0 ]]; then
   FAIL=$((FAIL + 1))
  fi
 done
 __logw "Waited for all jobs, restarting in main thread - XML processing."
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

 __log_finish
}

# Processes a single XML part for API notes
# Parameters:
#   $1: XML part file path
#   $2: XSLT notes file (optional, uses global if not provided)
#   $3: XSLT comments file (optional, uses global if not provided)
#   $4: XSLT text comments file (optional, uses global if not provided)
function __processApiXmlPart() {
 local XML_PART="${1}"
 local XSLT_NOTES_FILE_LOCAL="${2:-${XSLT_NOTES_API_FILE}}"
 local XSLT_COMMENTS_FILE_LOCAL="${3:-${XSLT_NOTE_COMMENTS_API_FILE}}"
 local XSLT_TEXT_FILE_LOCAL="${4:-${XSLT_TEXT_COMMENTS_API_FILE}}"
 local PART_NUM
 local BASENAME_PART

 # Debug: Show environment variables
 __logd "Environment check in subshell:"
 __logd "  XML_PART: '${XML_PART}'"
 __logd "  TMP_DIR: '${TMP_DIR:-NOT_SET}'"
 __logd "  XSLT_NOTES_API_FILE: '${XSLT_NOTES_API_FILE:-NOT_SET}'"
 __logd "  DBNAME: '${DBNAME:-NOT_SET}'"

 BASENAME_PART=$(basename "${XML_PART}" .xml)
 PART_NUM="${BASENAME_PART//part_/}"

 # Debug: Show extraction process
 __logd "Extracting part number from: ${XML_PART}"
 __logd "Basename: ${BASENAME_PART}"
 __logd "Part number: ${PART_NUM}"

 # Validate part number
 if [[ -z "${PART_NUM}" ]] || [[ ! "${PART_NUM}" =~ ^[0-9]+$ ]]; then
  __loge "Invalid part number extracted: '${PART_NUM}' from file: ${XML_PART}"
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
  return 1
 fi

 # Process comments
 __logd "Processing comments with xsltproc: ${XSLT_COMMENTS_FILE_LOCAL} -> ${OUTPUT_COMMENTS_PART}"
 xsltproc --stringparam default-timestamp "${CURRENT_TIMESTAMP}" -o "${OUTPUT_COMMENTS_PART}" "${XSLT_COMMENTS_FILE_LOCAL}" "${XML_PART}"
 if [[ ! -f "${OUTPUT_COMMENTS_PART}" ]]; then
  __loge "Comments CSV file was not created: ${OUTPUT_COMMENTS_PART}"
  return 1
 fi

 # Process text comments
 __logd "Processing text comments with xsltproc: ${XSLT_TEXT_FILE_LOCAL} -> ${OUTPUT_TEXT_PART}"
 xsltproc --stringparam default-timestamp "${CURRENT_TIMESTAMP}" -o "${OUTPUT_TEXT_PART}" "${XSLT_TEXT_FILE_LOCAL}" "${XML_PART}"
 if [[ ! -f "${OUTPUT_TEXT_PART}" ]]; then
  __loge "Text comments CSV file was not created: ${OUTPUT_TEXT_PART}"
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

 # Debug: Show generated CSV files and their sizes
 __logd "Generated CSV files for part ${PART_NUM}:"
 __logd "  Notes: ${OUTPUT_NOTES_PART} ($(wc -l < "${OUTPUT_NOTES_PART}" || echo 0) lines)" || true
 __logd "  Comments: ${OUTPUT_COMMENTS_PART} ($(wc -l < "${OUTPUT_COMMENTS_PART}" || echo 0) lines)" || true
 __logd "  Text: ${OUTPUT_TEXT_PART} ($(wc -l < "${OUTPUT_TEXT_PART}" || echo 0) lines)" || true

 # Load into database with partition ID and MAX_THREADS
 export OUTPUT_NOTES_PART
 export OUTPUT_COMMENTS_PART
 export OUTPUT_TEXT_PART
 export PART_ID="${PART_NUM}"
 export MAX_THREADS
 # shellcheck disable=SC2016
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -c "SET app.part_id = '${PART_NUM}'; SET app.max_threads = '${MAX_THREADS}';" \
  -c "$(envsubst '$OUTPUT_NOTES_PART,$OUTPUT_COMMENTS_PART,$OUTPUT_TEXT_PART,$PART_ID' \
   < "${POSTGRES_31_LOAD_API_NOTES}" || true)"

 __logi "Completed processing API part ${PART_NUM}"
}

# Processes a single XML part for Planet notes
# Parameters:
#   $1: XML part file path
#   $2: XSLT notes file (optional, uses global if not provided)
#   $3: XSLT comments file (optional, uses global if not provided)
#   $4: XSLT text comments file (optional, uses global if not provided)
function __processPlanetXmlPart() {
 local XML_PART="${1}"
 local XSLT_NOTES_FILE_LOCAL="${2:-${XSLT_NOTES_FILE}}"
 local XSLT_COMMENTS_FILE_LOCAL="${3:-${XSLT_NOTE_COMMENTS_FILE}}"
 local XSLT_TEXT_FILE_LOCAL="${4:-${XSLT_TEXT_COMMENTS_FILE}}"
 local PART_NUM
 local BASENAME_PART

 # Debug: Show environment variables
 __logd "Environment check in subshell:"
 __logd "  XML_PART: '${XML_PART}'"
 __logd "  TMP_DIR: '${TMP_DIR:-NOT_SET}'"
 __logd "  XSLT_NOTES_FILE: '${XSLT_NOTES_FILE:-NOT_SET}'"
 __logd "  DBNAME: '${DBNAME:-NOT_SET}'"

 BASENAME_PART=$(basename "${XML_PART}" .xml)
 PART_NUM="${BASENAME_PART//part_/}"

 # Debug: Show extraction process
 __logd "Extracting part number from: ${XML_PART}"
 __logd "Basename: ${BASENAME_PART}"
 __logd "Part number: ${PART_NUM}"

 # Validate part number
 if [[ -z "${PART_NUM}" ]] || [[ ! "${PART_NUM}" =~ ^[0-9]+$ ]]; then
  __loge "Invalid part number extracted: '${PART_NUM}' from file: ${XML_PART}"
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
  return 1
 fi

 # Add part_id to the end of each line
 __logd "Adding part_id ${PART_NUM} to notes CSV"
 awk -v part_id="${PART_NUM}" '{print $0 "," part_id}' "${OUTPUT_NOTES_PART}" > "${OUTPUT_NOTES_PART}.tmp" && mv "${OUTPUT_NOTES_PART}.tmp" "${OUTPUT_NOTES_PART}"

 # Process comments
 __logd "Processing comments with xsltproc: ${XSLT_COMMENTS_FILE_LOCAL} -> ${OUTPUT_COMMENTS_PART}"
 xsltproc --stringparam default-timestamp "${CURRENT_TIMESTAMP}" -o "${OUTPUT_COMMENTS_PART}" "${XSLT_COMMENTS_FILE_LOCAL}" "${XML_PART}"
 if [[ ! -f "${OUTPUT_COMMENTS_PART}" ]]; then
  __loge "Comments CSV file was not created: ${OUTPUT_COMMENTS_PART}"
  return 1
 fi

 # Add part_id to the end of each line
 __logd "Adding part_id ${PART_NUM} to comments CSV"
 awk -v part_id="${PART_NUM}" '{print $0 "," part_id}' "${OUTPUT_COMMENTS_PART}" > "${OUTPUT_COMMENTS_PART}.tmp" && mv "${OUTPUT_COMMENTS_PART}.tmp" "${OUTPUT_COMMENTS_PART}"

 # Process text comments
 __logd "Processing text comments with xsltproc: ${XSLT_TEXT_FILE_LOCAL} -> ${OUTPUT_TEXT_PART}"
 xsltproc --stringparam default-timestamp "${CURRENT_TIMESTAMP}" -o "${OUTPUT_TEXT_PART}" "${XSLT_TEXT_FILE_LOCAL}" "${XML_PART}"
 if [[ ! -f "${OUTPUT_TEXT_PART}" ]]; then
  __loge "Text comments CSV file was not created: ${OUTPUT_TEXT_PART}"
  return 1
 fi

 # Add part_id to the end of each line
 __logd "Adding part_id ${PART_NUM} to text comments CSV"
 awk -v part_id="${PART_NUM}" '{print $0 "," part_id}' "${OUTPUT_TEXT_PART}" > "${OUTPUT_TEXT_PART}.tmp" && mv "${OUTPUT_TEXT_PART}.tmp" "${OUTPUT_TEXT_PART}"

 # Debug: Show generated CSV files and their sizes
 __logd "Generated CSV files for part ${PART_NUM}:"
 __logd "  Notes: ${OUTPUT_NOTES_PART} ($(wc -l < "${OUTPUT_NOTES_PART}" || echo 0) lines)"
 __logd "  Comments: ${OUTPUT_COMMENTS_PART} ($(wc -l < "${OUTPUT_COMMENTS_PART}" || echo 0) lines)"
 __logd "  Text: ${OUTPUT_TEXT_PART} ($(wc -l < "${OUTPUT_TEXT_PART}" || echo 0) lines)"

 # Load into database with partition ID and MAX_THREADS
 export OUTPUT_NOTES_PART
 export OUTPUT_COMMENTS_PART
 export OUTPUT_TEXT_PART
 export PART_ID="${PART_NUM}"
 export MAX_THREADS
 # shellcheck disable=SC2016
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -c "SET app.part_id = '${PART_NUM}'; SET app.max_threads = '${MAX_THREADS}';" \
  -c "$(envsubst '$OUTPUT_NOTES_PART,$OUTPUT_COMMENTS_PART,$OUTPUT_TEXT_PART,$PART_ID' \
   < "${POSTGRES_41_LOAD_PARTITIONED_SYNC_NOTES}" || true)"

 __logi "Completed processing Planet part ${PART_NUM}"
}

# Function to validate input files and directories
# Parameters:
#   $1: File path to validate
#   $2: Description of the file (optional)
#   $3: Expected file type (optional: "file", "dir", "executable")
# Returns:
#   0 if valid, 1 if invalid
function __validate_input_file() {
 local FILE_PATH="${1}"
 local DESCRIPTION="${2:-File}"
 local EXPECTED_TYPE="${3:-file}"
 local VALIDATION_ERRORS=()

 # Check if file path is provided
 if [[ -z "${FILE_PATH}" ]]; then
  echo "ERROR: ${DESCRIPTION} path is empty" >&2
  return 1
 fi

 # Check if file exists
 if [[ ! -e "${FILE_PATH}" ]]; then
  VALIDATION_ERRORS+=("File does not exist: ${FILE_PATH}")
 fi

 # Check if file is readable (for files)
 if [[ "${EXPECTED_TYPE}" == "file" ]] && [[ -e "${FILE_PATH}" ]]; then
  if [[ ! -r "${FILE_PATH}" ]]; then
   VALIDATION_ERRORS+=("File is not readable: ${FILE_PATH}")
  fi
 fi

 # Check if directory is accessible (for directories)
 if [[ "${EXPECTED_TYPE}" == "dir" ]] && [[ -e "${FILE_PATH}" ]]; then
  if [[ ! -d "${FILE_PATH}" ]]; then
   VALIDATION_ERRORS+=("Path is not a directory: ${FILE_PATH}")
  elif [[ ! -r "${FILE_PATH}" ]]; then
   VALIDATION_ERRORS+=("Directory is not readable: ${FILE_PATH}")
  fi
 fi

 # Check if executable is executable
 if [[ "${EXPECTED_TYPE}" == "executable" ]] && [[ -e "${FILE_PATH}" ]]; then
  if [[ ! -x "${FILE_PATH}" ]]; then
   VALIDATION_ERRORS+=("File is not executable: ${FILE_PATH}")
  fi
 fi

 # Report validation errors
 if [[ ${#VALIDATION_ERRORS[@]} -gt 0 ]]; then
  echo "ERROR: ${DESCRIPTION} validation failed:" >&2
  for ERROR in "${VALIDATION_ERRORS[@]}"; do
   echo "  - ${ERROR}" >&2
  done
  return 1
 fi

 echo "DEBUG: ${DESCRIPTION} validation passed: ${FILE_PATH}" >&2
 return 0
}

# Function to validate multiple input files
# Parameters:
#   $@: List of file paths to validate
# Returns:
#   0 if all valid, 1 if any invalid
function __validate_input_files() {
 local ALL_VALID=true
 local FILE_PATH

 echo "DEBUG: Validating input files..." >&2

 for FILE_PATH in "$@"; do
  if ! __validate_input_file "${FILE_PATH}" "Input file"; then
   ALL_VALID=false
  fi
 done

 if [[ "${ALL_VALID}" == "true" ]]; then
  echo "DEBUG: All input files validation passed" >&2
  return 0
 else
  echo "ERROR: Some input files validation failed" >&2
  return 1
 fi
}

# Function to validate XML file structure
# Parameters:
#   $1: XML file path
#   $2: Expected root element (optional)
# Returns:
#   0 if valid, 1 if invalid
function __validate_xml_structure() {
 local XML_FILE="${1}"
 local EXPECTED_ROOT="${2:-}"
 local VALIDATION_ERRORS=()

 # Check if file exists and is readable
 if ! __validate_input_file "${XML_FILE}" "XML file"; then
  return 1
 fi

 # Check if file is not empty
 if [[ ! -s "${XML_FILE}" ]]; then
  echo "ERROR: XML file is empty: ${XML_FILE}" >&2
  return 1
 fi

 # Validate XML syntax
 if ! xmllint --noout "${XML_FILE}" 2> /dev/null; then
  VALIDATION_ERRORS+=("Invalid XML syntax")
 fi

 # Check expected root element if provided
 if [[ -n "${EXPECTED_ROOT}" ]]; then
  local ACTUAL_ROOT
  ACTUAL_ROOT=$(xmlstarlet sel -t -n -v "name(/*)" "${XML_FILE}" 2> /dev/null | tr -d ' ' | tr -d '\n')
  if [[ "${ACTUAL_ROOT}" != "${EXPECTED_ROOT}" ]]; then
   VALIDATION_ERRORS+=("Expected root element '${EXPECTED_ROOT}', got '${ACTUAL_ROOT}'")
  fi
 fi

 # Report validation errors
 if [[ ${#VALIDATION_ERRORS[@]} -gt 0 ]]; then
  echo "ERROR: XML structure validation failed for ${XML_FILE}:" >&2
  for ERROR in "${VALIDATION_ERRORS[@]}"; do
   echo "  - ${ERROR}" >&2
  done
  return 1
 fi

 echo "DEBUG: XML structure validation passed: ${XML_FILE}" >&2
 return 0
}

# Function to validate CSV file structure
# Parameters:
#   $1: CSV file path
#   $2: Expected number of columns (optional)
# Returns:
#   0 if valid, 1 if invalid
function __validate_csv_structure() {
 local CSV_FILE="${1}"
 local EXPECTED_COLUMNS="${2:-}"
 local VALIDATION_ERRORS=()

 # Check if file exists and is readable
 if ! __validate_input_file "${CSV_FILE}" "CSV file"; then
  return 1
 fi

 # Check if file is not empty
 if [[ ! -s "${CSV_FILE}" ]]; then
  echo "ERROR: CSV file is empty: ${CSV_FILE}" >&2
  return 1
 fi

 # Check if file has at least one line
 local LINE_COUNT
 LINE_COUNT=$(wc -l < "${CSV_FILE}")
 if [[ "${LINE_COUNT}" -eq 0 ]]; then
  VALIDATION_ERRORS+=("CSV file has no lines")
 fi

 # Check expected number of columns if provided
 if [[ -n "${EXPECTED_COLUMNS}" ]]; then
  local ACTUAL_COLUMNS
  ACTUAL_COLUMNS=$(head -1 "${CSV_FILE}" | tr ',' '\n' | wc -l)
  if [[ "${ACTUAL_COLUMNS}" -ne "${EXPECTED_COLUMNS}" ]]; then
   VALIDATION_ERRORS+=("Expected ${EXPECTED_COLUMNS} columns, got ${ACTUAL_COLUMNS}")
  fi
 fi

 # Report validation errors
 if [[ ${#VALIDATION_ERRORS[@]} -gt 0 ]]; then
  echo "ERROR: CSV structure validation failed for ${CSV_FILE}:" >&2
  for ERROR in "${VALIDATION_ERRORS[@]}"; do
   echo "  - ${ERROR}" >&2
  done
  return 1
 fi

 echo "DEBUG: CSV structure validation passed: ${CSV_FILE}" >&2
 return 0
}

# Function to validate SQL file structure
# Parameters:
#   $1: SQL file path
# Returns:
#   0 if valid, 1 if invalid
function __validate_sql_structure() {
 local sql_file="${1}"
 local validation_errors=()

 # Check if file exists and is readable
 if ! __validate_input_file "${sql_file}" "SQL file"; then
  return 1
 fi

 # Check if file is not empty
 if [[ ! -s "${sql_file}" ]]; then
  echo "ERROR: SQL file is empty: ${sql_file}" >&2
  return 1
 fi

 # Check for basic SQL syntax (simple validation)
 if ! grep -q -E "(SELECT|INSERT|UPDATE|DELETE|CREATE|DROP|ALTER|BEGIN|COMMIT)" "${sql_file}"; then
  validation_errors+=("No SQL statements found")
 fi

 # Report validation errors
 if [[ ${#validation_errors[@]} -gt 0 ]]; then
  echo "ERROR: SQL structure validation failed for ${sql_file}:" >&2
  for error in "${validation_errors[@]}"; do
   echo "  - ${error}" >&2
  done
  return 1
 fi

 echo "DEBUG: SQL structure validation passed: ${sql_file}" >&2
 return 0
}

# Function to validate configuration file
# Parameters:
#   $1: Config file path
# Returns:
#   0 if valid, 1 if invalid
function __validate_config_file() {
 local config_file="${1}"
 local validation_errors=()

 # Check if file exists and is readable
 if ! __validate_input_file "${config_file}" "Configuration file"; then
  return 1
 fi

 # Check if file is not empty
 if [[ ! -s "${config_file}" ]]; then
  echo "ERROR: Configuration file is empty: ${config_file}" >&2
  return 1
 fi

 # Check for basic configuration format (more flexible)
 if ! grep -q -E "^[A-Z_][A-Z0-9_]*=" "${config_file}" && ! grep -q -E "^declare.*=" "${config_file}"; then
  validation_errors+=("No valid configuration variables found")
 fi

 # Report validation errors
 if [[ ${#validation_errors[@]} -gt 0 ]]; then
  echo "ERROR: Configuration file validation failed for ${config_file}:" >&2
  for error in "${validation_errors[@]}"; do
   echo "  - ${error}" >&2
  done
  return 1
 fi

 echo "DEBUG: Configuration file validation passed: ${config_file}" >&2
 return 0
}

# Validates JSON file structure and syntax
# Parameters:
#   $1: JSON file path
#   $2: Optional expected root element name (e.g., "osm-notes")
# Returns:
#   0 if valid, 1 if invalid
function __validate_json_structure() {
 local json_file="${1}"
 local expected_root="${2:-}"
 local validation_errors=()

 # Check if file exists and is readable
 if ! __validate_input_file "${json_file}" "JSON file"; then
  return 1
 fi

 # Check if file is not empty
 if [[ ! -s "${json_file}" ]]; then
  echo "ERROR: JSON file is empty: ${json_file}" >&2
  return 1
 fi

 # Check JSON syntax using jq
 if ! command -v jq &> /dev/null; then
  echo "WARNING: jq not available, skipping JSON syntax validation" >&2
 else
  if ! jq empty "${json_file}" 2> /dev/null; then
   validation_errors+=("Invalid JSON syntax")
  fi
 fi

 # Check if file contains valid JSON structure (basic check without jq)
 if ! grep -q -E '^[[:space:]]*\{' "${json_file}" && ! grep -q -E '^[[:space:]]*\[' "${json_file}"; then
  validation_errors+=("File does not appear to contain valid JSON structure")
 fi

 # Check for expected root element if specified
 if [[ -n "${expected_root}" ]]; then
  if command -v jq &> /dev/null; then
   local actual_root
   actual_root=$(jq -r 'keys[0] // empty' "${json_file}" 2> /dev/null | head -1)
   if [[ "${actual_root}" != "${expected_root}" ]]; then
    validation_errors+=("Expected root element '${expected_root}', got '${actual_root}'")
   fi
  else
   # Fallback check using grep
   if ! grep -q "\"${expected_root}\"" "${json_file}"; then
    validation_errors+=("Expected root element '${expected_root}' not found")
   fi
  fi
 fi

 # Report validation errors
 if [[ ${#validation_errors[@]} -gt 0 ]]; then
  echo "ERROR: JSON file validation failed for ${json_file}:" >&2
  for error in "${validation_errors[@]}"; do
   echo "  - ${error}" >&2
  done
  return 1
 fi

 echo "DEBUG: JSON file validation passed: ${json_file}" >&2
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
function __validate_database_connection() {
 local DB_NAME_PARAM="${1:-${DBNAME:-}}"
 local DB_USER_PARAM="${2:-${DB_USER:-}}"
 local DB_HOST_PARAM="${3:-${DBHOST:-}}"
 local DB_PORT_PARAM="${4:-${DBPORT:-}}"
 local VALIDATION_ERRORS=()

 # Check if database parameters are provided
 if [[ -z "${DB_NAME_PARAM}" ]]; then
  echo "ERROR: Database name not provided and DBNAME not set" >&2
  return 1
 fi

 if [[ -z "${DB_USER_PARAM}" ]]; then
  echo "ERROR: Database user not provided and DB_USER not set" >&2
  return 1
 fi

 # Check if psql is available
 if ! command -v psql &> /dev/null; then
  echo "ERROR: psql command not available" >&2
  return 1
 fi

 # Build psql command
 local PSQL_CMD="psql"
 if [[ -n "${DB_HOST_PARAM}" ]]; then
  PSQL_CMD="${PSQL_CMD} -h ${DB_HOST_PARAM}"
 fi
 if [[ -n "${DB_PORT_PARAM}" ]]; then
  PSQL_CMD="${PSQL_CMD} -p ${DB_PORT_PARAM}"
 fi
 PSQL_CMD="${PSQL_CMD} -U ${DB_USER_PARAM} -d ${DB_NAME_PARAM}"

 # Test basic connection
 if ! ${PSQL_CMD} -c "SELECT 1;" > /dev/null 2>&1; then
  VALIDATION_ERRORS+=("Cannot connect to database ${DB_NAME_PARAM} as user ${DB_USER_PARAM}")
 fi

 # Test if database exists and is accessible
 if ! ${PSQL_CMD} -c "SELECT current_database();" > /dev/null 2>&1; then
  VALIDATION_ERRORS+=("Database ${DB_NAME_PARAM} does not exist or is not accessible")
 fi

 # Test if user has basic permissions
 if ! ${PSQL_CMD} -c "SELECT current_user;" > /dev/null 2>&1; then
  VALIDATION_ERRORS+=("User ${DB_USER_PARAM} does not have basic permissions")
 fi

 # Test if PostGIS extension is available (if needed)
 if [[ "${POSTGIS_REQUIRED:-true}" = true ]]; then
  if ! ${PSQL_CMD} -c "SELECT PostGIS_version();" > /dev/null 2>&1; then
   VALIDATION_ERRORS+=("PostGIS extension is not available")
  fi
 fi

 # Report validation errors
 if [[ ${#VALIDATION_ERRORS[@]} -gt 0 ]]; then
  echo "ERROR: Database connection validation failed:" >&2
  for ERROR in "${VALIDATION_ERRORS[@]}"; do
   echo "  - ${ERROR}" >&2
  done
  return 1
 fi

 echo "DEBUG: Database connection validation passed for ${DB_NAME_PARAM}" >&2
 return 0
}

# Validates database table existence and structure
# Parameters:
#   $1: Database name (optional, uses DBNAME if not provided)
#   $2: Database user (optional, uses DB_USER if not provided)
#   $3: Database host (optional, uses DBHOST if not provided)
#   $4: Database port (optional, uses DBPORT if not provided)
#   $5+: List of required table names
# Returns:
#   0 if all tables exist, 1 if any missing
function __validate_database_tables() {
 local DB_NAME_PARAM="${1:-${DBNAME:-}}"
 local DB_USER_PARAM="${2:-${DB_USER:-}}"
 local DB_HOST_PARAM="${3:-${DBHOST:-}}"
 local DB_PORT_PARAM="${4:-${DBPORT:-}}"
 shift 4 || shift $((4 - $#)) # Remove first 4 parameters, handle case where less than 4
 local REQUIRED_TABLES=("$@")
 local MISSING_TABLES=()

 # Check if database parameters are provided
 if [[ -z "${DB_NAME_PARAM}" ]]; then
  echo "ERROR: Database name not provided and DBNAME not set" >&2
  return 1
 fi

 if [[ -z "${DB_USER_PARAM}" ]]; then
  echo "ERROR: Database user not provided and DB_USER not set" >&2
  return 1
 fi

 # Check if psql is available
 if ! command -v psql &> /dev/null; then
  echo "ERROR: psql command not available" >&2
  return 1
 fi

 # Build psql command
 local PSQL_CMD="psql"
 if [[ -n "${DB_HOST_PARAM}" ]]; then
  PSQL_CMD="${PSQL_CMD} -h ${DB_HOST_PARAM}"
 fi
 if [[ -n "${DB_PORT_PARAM}" ]]; then
  PSQL_CMD="${PSQL_CMD} -p ${DB_PORT_PARAM}"
 fi
 PSQL_CMD="${PSQL_CMD} -U ${DB_USER_PARAM} -d ${DB_NAME_PARAM}"

 # Check each required table
 for TABLE in "${REQUIRED_TABLES[@]}"; do
  if ! ${PSQL_CMD} -c "SELECT 1 FROM information_schema.tables WHERE table_name = '${TABLE}';" | grep -q "1"; then
   MISSING_TABLES+=("${TABLE}")
  fi
 done

 # Report missing tables
 if [[ ${#MISSING_TABLES[@]} -gt 0 ]]; then
  echo "ERROR: Missing required database tables:" >&2
  for TABLE in "${MISSING_TABLES[@]}"; do
   echo "  - ${TABLE}" >&2
  done
  return 1
 fi

 echo "DEBUG: Database tables validation passed for ${DB_NAME_PARAM}" >&2
 return 0
}

# Validates database schema and extensions
# Parameters:
#   $1: Database name (optional, uses DBNAME if not provided)
#   $2: Database user (optional, uses DB_USER if not provided)
#   $3: Database host (optional, uses DBHOST if not provided)
#   $4: Database port (optional, uses DBPORT if not provided)
#   $5+: List of required extensions
# Returns:
#   0 if all extensions exist, 1 if any missing
function __validate_database_extensions() {
 local DB_NAME_PARAM="${1:-${DBNAME:-}}"
 local DB_USER_PARAM="${2:-${DB_USER:-}}"
 local DB_HOST_PARAM="${3:-${DBHOST:-}}"
 local DB_PORT_PARAM="${4:-${DBPORT:-}}"
 shift 4 || shift $((4 - $#)) # Remove first 4 parameters, handle case where less than 4
 local REQUIRED_EXTENSIONS=("$@")
 local MISSING_EXTENSIONS=()

 # Check if database parameters are provided
 if [[ -z "${DB_NAME_PARAM}" ]]; then
  echo "ERROR: Database name not provided and DBNAME not set" >&2
  return 1
 fi

 if [[ -z "${DB_USER_PARAM}" ]]; then
  echo "ERROR: Database user not provided and DB_USER not set" >&2
  return 1
 fi

 # Check if psql is available
 if ! command -v psql &> /dev/null; then
  echo "ERROR: psql command not available" >&2
  return 1
 fi

 # Build psql command
 local PSQL_CMD="psql"
 if [[ -n "${DB_HOST_PARAM}" ]]; then
  PSQL_CMD="${PSQL_CMD} -h ${DB_HOST_PARAM}"
 fi
 if [[ -n "${DB_PORT_PARAM}" ]]; then
  PSQL_CMD="${PSQL_CMD} -p ${DB_PORT_PARAM}"
 fi
 PSQL_CMD="${PSQL_CMD} -U ${DB_USER_PARAM} -d ${DB_NAME_PARAM}"

 # Check each required extension
 for EXTENSION in "${REQUIRED_EXTENSIONS[@]}"; do
  if ! ${PSQL_CMD} -c "SELECT 1 FROM pg_extension WHERE extname = '${EXTENSION}';" | grep -q "1"; then
   MISSING_EXTENSIONS+=("${EXTENSION}")
  fi
 done

 # Report missing extensions
 if [[ ${#MISSING_EXTENSIONS[@]} -gt 0 ]]; then
  echo "ERROR: Missing required database extensions:" >&2
  for EXTENSION in "${MISSING_EXTENSIONS[@]}"; do
   echo "  - ${EXTENSION}" >&2
  done
  return 1
 fi

 echo "DEBUG: Database extensions validation passed for ${DB_NAME_PARAM}" >&2
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
 fi
 set +e
 ## PostgreSQL
 __logd "Checking PostgreSQL."
 if ! psql --version > /dev/null 2>&1; then
  __loge "ERROR: PostgreSQL is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## PostGIS
 __logd "Checking PostGIS."
 # shellcheck disable=SC2154
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 > /dev/null 2>&1 << EOF
 SELECT /* Notes-base */ PostGIS_version();
EOF
 RET=${?}
 if [[ "${RET}" -ne 0 ]]; then
  __loge "ERROR: PostGIS extension is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## btree gist
 # shellcheck disable=SC2154
 __logd "Checking btree gist."
 RESULT=$(psql -t -A -c "SELECT COUNT(1) FROM pg_extension WHERE extname = 'btree_gist';" "${DBNAME}")
 if [[ "${RESULT}" -ne 1 ]]; then
  __loge "ERROR: btree_gist extension is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Wget
 __logd "Checking wget."
 if ! wget --version > /dev/null 2>&1; then
  __loge "ERROR: Wget is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Aria2c
 __logd "Checking aria2c."
 if ! aria2c --version > /dev/null 2>&1; then
  __loge "ERROR: Aria2c is missing."
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
 ## Block-sorting file compressor
 __logd "Checking bzip2."
 if ! bzip2 --help > /dev/null 2>&1; then
  __loge "ERROR: bzip2 is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## XML lint
 __logd "Checking XML lint."
 if ! xmllint --version > /dev/null 2>&1; then
  __loge "ERROR: XMLlint is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## XSLTproc
 __logd "Checking XSLTproc."
 if ! xsltproc --version > /dev/null 2>&1; then
  __loge "ERROR: XSLTproc is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## XMLStarlet for XML processing and splitting
 __logd "Checking XMLStarlet."
 if ! xmlstarlet --version > /dev/null 2>&1; then
  __loge "ERROR: XMLStarlet is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 ## Bash 4 or greater.
 __logd "Checking Bash version."
 if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  __loge "ERROR: Requires Bash 4+."
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 __logd "Checking files."
 if [[ ! -r "${CSV_BACKUP_NOTE_LOCATION_COMPRESSED}" ]]; then
  __loge "ERROR: Backup file is missing at ${CSV_BACKUP_NOTE_LOCATION_COMPRESSED}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_32_UPLOAD_NOTE_LOCATION}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_32_UPLOAD_NOTE_LOCATION}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${XSLT_NOTES_PLANET_FILE}" ]]; then
  __loge "ERROR: File is missing at ${XSLT_NOTES_PLANET_FILE}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${XSLT_NOTE_COMMENTS_PLANET_FILE}" ]]; then
  __loge "ERROR: File is missing at ${XSLT_NOTE_COMMENTS_PLANET_FILE}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${XSLT_TEXT_COMMENTS_PLANET_FILE}" ]]; then
  __loge "ERROR: File is missing at ${XSLT_TEXT_COMMENTS_PLANET_FILE}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${XMLSCHEMA_PLANET_NOTES}" ]]; then
  __loge "ERROR: File is missing at ${XMLSCHEMA_PLANET_NOTES}."
  exit "${ERROR_MISSING_LIBRARY}"
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
  __loge "ERROR: ogr2ogr cannot access the database."
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 ## Validate configuration variables
 __logd "Validating configuration variables."

 # Validate MAX_THREADS
 if [[ ! "${MAX_THREADS}" =~ ^[1-9][0-9]*$ ]]; then
  __loge "ERROR: MAX_THREADS must be a positive integer, got: ${MAX_THREADS}"
  exit "${ERROR_GENERAL}"
 fi
 # Validate MAX_THREADS to prevent excessive resource usage
 if [[ "${MAX_THREADS}" -gt 100 ]]; then
  __logw "MAX_THREADS exceeds 100, limiting to 100"
  MAX_THREADS=100
 fi
 # Validate TMP_DIR
 if [[ -z "${TMP_DIR}" ]]; then
  __loge "ERROR: TMP_DIR is not set"
  exit "${ERROR_GENERAL}"
 fi
 # Validate DBNAME
 if [[ -z "${DBNAME}" ]]; then
  __loge "ERROR: DBNAME is not set"
  exit "${ERROR_GENERAL}"
 fi
 # Validate MAX_NOTES
 if [[ ! "${MAX_NOTES}" =~ ^[1-9][0-9]*$ ]]; then
  __loge "ERROR: MAX_NOTES must be a positive integer, got: ${MAX_NOTES}"
  exit "${ERROR_GENERAL}"
 fi
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
function __checkBaseTables {
 __log_start
 set +e
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_11_CHECK_BASE_TABLES}"
 RET=${?}
 set -e
 RET_FUNC="${RET}"
 __log_finish
}

# Drop generic objects.
function __dropGenericObjects {
 __log_start
 __logi "Dropping generic objects."
 psql -d "${DBNAME}" -f "${POSTGRES_12_DROP_GENERIC_OBJECTS}"
 __log_finish
}

# Downloads the notes from the planet.
function __downloadPlanetNotes {
 __log_start

 # Check network connectivity before proceeding
 __logi "Checking network connectivity..."
 if ! __check_network_connectivity 15; then
  __loge "Network connectivity check failed"
  __handle_error_with_cleanup "${ERROR_INTERNET_ISSUE}" "Network connectivity failed" \
   "rm -f ${PLANET_NOTES_FILE}.bz2 ${PLANET_NOTES_FILE}.bz2.md5 2>/dev/null || true"
 fi

 # Download Planet notes with retry logic
 __logw "Retrieving Planet notes file..."
 local download_operation="aria2c -d ${TMP_DIR} -o ${PLANET_NOTES_NAME}.bz2 -x 8 ${PLANET}/notes/${PLANET_NOTES_NAME}.bz2"
 local download_cleanup="rm -f ${PLANET_NOTES_FILE}.bz2 2>/dev/null || true"

 if ! __retry_file_operation "${download_operation}" 3 10 "${download_cleanup}"; then
  __loge "Failed to download Planet notes after retries"
  __handle_error_with_cleanup "${ERROR_DOWNLOADING_NOTES}" "Planet download failed" \
   "rm -f ${PLANET_NOTES_FILE}.bz2 2>/dev/null || true"
 fi

 # Download MD5 file with retry logic
 local md5_operation="wget -O ${PLANET_NOTES_FILE}.bz2.md5 ${PLANET}/notes/${PLANET_NOTES_NAME}.bz2.md5"
 local md5_cleanup="rm -f ${PLANET_NOTES_FILE}.bz2.md5 2>/dev/null || true"

 if ! __retry_file_operation "${md5_operation}" 3 5 "${md5_cleanup}"; then
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

 # Extract file with retry logic
 __logi "Extracting Planet notes..."
 local extract_operation="bzip2 -d ${PLANET_NOTES_FILE}.bz2"
 local extract_cleanup="rm -f ${PLANET_NOTES_FILE} 2>/dev/null || true"

 if ! __retry_file_operation "${extract_operation}" 2 3 "${extract_cleanup}"; then
  __loge "Failed to extract Planet notes after retries"
  __handle_error_with_cleanup "${ERROR_DOWNLOADING_NOTES}" "File extraction failed" \
   "rm -f ${PLANET_NOTES_FILE}.bz2 ${PLANET_NOTES_FILE} 2>/dev/null || true"
 fi

 mv "${PLANET_NOTES_FILE}" "${PLANET_NOTES_FILE}.xml"
 __log_finish
}

# Validates the XML file to be sure everything will work fine.
function __validatePlanetNotesXMLFile {
 __log_start

 # shellcheck disable=SC2154
 xmllint --noout --schema "${XMLSCHEMA_PLANET_NOTES}" \
  "${PLANET_NOTES_FILE}.xml" 2>&1

 __log_finish
}

# Creates a function that performs basic triage according to longitude:
# * -180 - -30: Americas.
# * -30 - 25: West Europe and West Africa.
# * 25 - 65: Middle East, East Africa and Russia.
# * 65 - 180: Southeast Asia and Oceania.
function __createFunctionToGetCountry {
 __log_start
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY}"
 __log_finish
}

# Creates procedures to insert notes and comments.
function __createProcedures {
 __log_start
 # Creates a procedure that inserts a note.
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_22_CREATE_PROC_INSERT_NOTE}"

 # Creates a procedure that inserts a note comment.
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_23_CREATE_PROC_INSERT_NOTE_COMMENT}"
 __log_finish
}

# Assigns a value to each area to find it easily.
function __organizeAreas {
 __log_start
 set +e
 # Insert values for representative countries in each area.
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_31_ORGANIZE_AREAS}"
 RET=${?}
 set -e
 RET_FUNC="${RET}"
 __log_finish
}

# Processes a specific boundary ID.
function __processBoundary {
 __log_start
 PROCESS="${BASHPID}"
 OUTPUT_OVERPASS="${TMP_DIR}/output.${BASHPID}"

 __logi "Retrieving shape ${ID}."

 # Check network connectivity before proceeding
 if ! __check_network_connectivity 10; then
  __loge "Network connectivity check failed for boundary ${ID}"
  __handle_error_with_cleanup "${ERROR_INTERNET_ISSUE}" "Network connectivity failed for boundary ${ID}" \
   "rm -f ${JSON_FILE} ${GEOJSON_FILE} ${OUTPUT_OVERPASS} 2>/dev/null || true"
 fi

 # Use retry logic for Overpass API calls
 local overpass_operation="wget -O ${JSON_FILE} --post-file=${QUERY_FILE} ${OVERPASS_INTERPRETER} 2> ${OUTPUT_OVERPASS}"
 local overpass_cleanup="rm -f ${JSON_FILE} ${OUTPUT_OVERPASS} 2>/dev/null || true"

 if ! __retry_file_operation "${overpass_operation}" 5 15 "${overpass_cleanup}"; then
  __loge "Failed to retrieve boundary ${ID} from Overpass after retries"
  __handle_error_with_cleanup "${ERROR_DOWNLOADING_BOUNDARY}" "Overpass API failed for boundary ${ID}" \
   "rm -f ${JSON_FILE} ${OUTPUT_OVERPASS} 2>/dev/null || true"
 fi

 # Check for specific Overpass errors
 cat "${OUTPUT_OVERPASS}"
 local MANY_REQUESTS
 MANY_REQUESTS=$(grep -c "ERROR 429: Too Many Requests." "${OUTPUT_OVERPASS}")
 if [[ "${MANY_REQUESTS}" -ne 0 ]]; then
  __loge "Too many requests to Overpass API for boundary ${ID}"
  __handle_error_with_cleanup "${ERROR_DOWNLOADING_BOUNDARY}" "Overpass rate limit exceeded for boundary ${ID}" \
   "rm -f ${JSON_FILE} ${OUTPUT_OVERPASS} 2>/dev/null || true"
 fi

 rm -f "${OUTPUT_OVERPASS}"

 # Validate the JSON with a JSON schema
 __logi "Validating JSON structure for boundary ${ID}..."
 if ! __validate_json_structure "${JSON_FILE}" "osm"; then
  __loge "JSON validation failed for boundary ${ID}"
  __handle_error_with_cleanup "${ERROR_DATA_VALIDATION}" "Invalid JSON structure for boundary ${ID}" \
   "rm -f ${JSON_FILE} 2>/dev/null || true"
 fi

 # Convert to GeoJSON with retry logic
 __logi "Converting into GeoJSON for boundary ${ID}."
 local geojson_operation="osmtogeojson ${JSON_FILE} > ${GEOJSON_FILE}"
 local geojson_cleanup="rm -f ${GEOJSON_FILE} 2>/dev/null || true"

 if ! __retry_file_operation "${geojson_operation}" 2 5 "${geojson_cleanup}"; then
  __loge "Failed to convert boundary ${ID} to GeoJSON after retries"
  __handle_error_with_cleanup "${ERROR_GEOJSON_CONVERSION}" "GeoJSON conversion failed for boundary ${ID}" \
   "rm -f ${JSON_FILE} ${GEOJSON_FILE} 2>/dev/null || true"
 fi

 # Validate the GeoJSON with a JSON schema
 if ! __validate_json_structure "${GEOJSON_FILE}" "FeatureCollection"; then
  __loge "GeoJSON validation failed for boundary ${ID}"
  __handle_error_with_cleanup "${ERROR_GEOJSON_CONVERSION}" "Invalid GeoJSON structure for boundary ${ID}" \
   "rm -f ${JSON_FILE} ${GEOJSON_FILE} 2>/dev/null || true"
 fi

 # Extract names with error handling
 set +o pipefail
 local NAME
 NAME=$(grep "\"name\":" "${GEOJSON_FILE}" | head -1 \
  | awk -F\" '{print $4}' | sed "s/'/''/")
 local NAME_ES
 NAME_ES=$(grep "\"name:es\":" "${GEOJSON_FILE}" | head -1 \
  | awk -F\" '{print $4}' | sed "s/'/''/")
 local NAME_EN
 NAME_EN=$(grep "\"name:en\":" "${GEOJSON_FILE}" | head -1 \
  | awk -F\" '{print $4}' | sed "s/'/''/")
 set -o pipefail
 set -e
 NAME_EN="${NAME_EN:-No English name}"
 __logi "Name: ${NAME_EN:-}."

 # Special handling for Taiwan (ID: 16239) - remove problematic tags to avoid oversized records
 if [[ "${ID}" -eq 16239 ]]; then
  __logi "Special handling for Taiwan (ID: 16239) - removing problematic tags"
  if [[ -f "${GEOJSON_FILE}" ]]; then
   grep -v "official_name" "${GEOJSON_FILE}" \
    | grep -v "alt_name" > "${GEOJSON_FILE}-new"
   mv "${GEOJSON_FILE}-new" "${GEOJSON_FILE}"
  fi
 fi

 # Import into Postgres with retry logic
 __logi "Importing into Postgres for boundary ${ID}."
 local lock_operation="mkdir ${LOCK_OGR2OGR} 2> /dev/null"
 local lock_cleanup="rmdir ${LOCK_OGR2OGR} 2>/dev/null || true"

 if ! __retry_file_operation "${lock_operation}" 3 2 "${lock_cleanup}"; then
  __loge "Failed to acquire lock for boundary ${ID}"
  __handle_error_with_cleanup "${ERROR_GENERAL}" "Lock acquisition failed for boundary ${ID}" \
   "rm -f ${JSON_FILE} ${GEOJSON_FILE} 2>/dev/null || true"
 fi

 # Import with ogr2ogr using retry logic with special handling for Austria
 local import_operation
 if [[ "${ID}" -eq 16239 ]]; then
  # Austria - use ST_Buffer to fix topology issues
  import_operation="ogr2ogr -f PostgreSQL PG:dbname=${DBNAME} -nln import -overwrite ${GEOJSON_FILE}"
 else
  # Standard import
  import_operation="ogr2ogr -f PostgreSQL PG:dbname=${DBNAME} -nln import -overwrite ${GEOJSON_FILE}"
 fi

 local import_cleanup="rmdir ${LOCK_OGR2OGR} 2>/dev/null || true"

 if ! __retry_file_operation "${import_operation}" 2 5 "${import_cleanup}"; then
  __loge "Failed to import boundary ${ID} into database after retries"
  __handle_error_with_cleanup "${ERROR_GENERAL}" "Database import failed for boundary ${ID}" \
   "rm -f ${JSON_FILE} ${GEOJSON_FILE} 2>/dev/null || true; rmdir ${LOCK_OGR2OGR} 2>/dev/null || true"
 fi

 # Check for column duplication errors and handle them
 local column_check_operation="psql -d ${DBNAME} -c \"SELECT column_name, COUNT(*) FROM information_schema.columns WHERE table_name = 'import' GROUP BY column_name HAVING COUNT(*) > 1;\" 2>/dev/null"
 local column_check_result
 column_check_result=$(eval "${column_check_operation}" 2> /dev/null || echo "")

 if [[ -n "${column_check_result}" ]] && [[ "${column_check_result}" != *"0 rows"* ]]; then
  __logw "Detected duplicate columns in import table for boundary ${ID}"
  __logw "This is likely due to case-sensitive column names in the GeoJSON"
  # Handle column duplication by removing problematic columns
  local fix_columns_operation="psql -d ${DBNAME} -c \"ALTER TABLE import DROP COLUMN IF EXISTS \\\"name:xx-XX\\\", DROP COLUMN IF EXISTS \\\"name:XX-xx\\\";\" 2>/dev/null"
  if ! eval "${fix_columns_operation}"; then
   __logw "Failed to fix duplicate columns, but continuing..."
  fi
 fi

 # Process the imported data with special handling for Austria
 local process_operation
 if [[ "${ID}" -eq 16239 ]]; then
  # Austria - use ST_Buffer to fix topology issues
  process_operation="psql -d ${DBNAME} -c \"INSERT INTO countries (country_id, country_name, country_name_es, country_name_en, geom) SELECT ${ID}, '${NAME}', '${NAME_ES}', '${NAME_EN}', ST_Union(ST_Buffer(wkb_geometry, 0.0)) FROM import GROUP BY 1;\""
 else
  # Standard processing
  process_operation="psql -d ${DBNAME} -c \"INSERT INTO countries (country_id, country_name, country_name_es, country_name_en, geom) SELECT ${ID}, '${NAME}', '${NAME_ES}', '${NAME_EN}', ST_Union(ST_makeValid(wkb_geometry)) FROM import GROUP BY 1;\""
 fi

 if ! __retry_file_operation "${process_operation}" 2 3 ""; then
  __loge "Failed to process boundary ${ID} data"
  __handle_error_with_cleanup "${ERROR_GENERAL}" "Data processing failed for boundary ${ID}" \
   "rm -f ${JSON_FILE} ${GEOJSON_FILE} 2>/dev/null || true; rmdir ${LOCK_OGR2OGR} 2>/dev/null || true"
 fi

 rmdir "${LOCK_OGR2OGR}" 2> /dev/null || true
 __log_finish
}

# Processes the list of countries or maritime areas in the given file.
function __processList {
 __log_start

 BOUNDARIES_FILE="${1}"
 QUERY_FILE="${QUERY_FILE}.${BASHPID}"
 __logi "Retrieving the country or maritime boundaries."
 while read -r LINE; do
  ID=$(echo "${LINE}" | awk '{print $1}')
  JSON_FILE="${TMP_DIR}/${ID}.json"
  GEOJSON_FILE="${TMP_DIR}/${ID}.geojson"
  __logi "ID: ${ID}."
  cat << EOF > "${QUERY_FILE}"
   [out:json];
   rel(${ID});
   (._;>;);
   out;
EOF

  __processBoundary

  if [[ -n "${CLEAN}" ]] && [[ "${CLEAN}" = true ]]; then
   rm -f "${JSON_FILE}" "${GEOJSON_FILE}" "${QUERY_FILE}"
  else
   mv "${JSON_FILE}" "${TMP_DIR}/${ID}.json.old"
   mv "${GEOJSON_FILE}" "${TMP_DIR}/${ID}.geojson.old"
  fi
 done < "${BOUNDARIES_FILE}"

 __log_finish
}

# Download the list of countries, then it downloads each country individually,
# converts the OSM JSON into a GeoJSON, and then it inserts the geometry of the
# country into the Postgres database with ogr2ogr.
function __processCountries {
 __log_start
 # Extracts ids of all country relations into a JSON.
 __logi "Obtaining the countries ids."
 set +e
 wget -O "${COUNTRIES_BOUNDARY_IDS_FILE}" --post-file="${OVERPASS_COUNTRIES}" \
  "${OVERPASS_INTERPRETER}"
 RET=${?}
 set -e
 if [[ "${RET}" -ne 0 ]]; then
  __loge "ERROR: Country list could not be downloaded."
  exit "${ERROR_DOWNLOADING_BOUNDARY_ID_LIST}"
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
 SIZE=$((TOTAL_LINES / MAX_THREADS))
 SIZE=$((SIZE + 1))
 split -l"${SIZE}" "${COUNTRIES_BOUNDARY_IDS_FILE}" "${TMP_DIR}/part_country_"
 if [[ -d "${LOCK_OGR2OGR}" ]]; then
  rm -f "${LOCK_OGR2OGR}/pid"
  rmdir "${LOCK_OGR2OGR}"
 fi
 __logw "Starting background process to process country boundaries..."
 for I in "${TMP_DIR}"/part_country_??; do
  (
   __logi "Starting list ${I} - ${BASHPID}."
   # shellcheck disable=SC2154
   __processList "${I}" >> "${LOG_FILENAME}.${BASHPID}" 2>&1
   __logi "Finished list ${I} - ${BASHPID}."
   if [[ -n "${CLEAN}" ]] && [[ "${CLEAN}" = true ]]; then
    rm -f "${LOG_FILENAME}.${BASHPID}"
   else
    mv "${LOG_FILENAME}.${BASHPID}" "${TMP_DIR}/${BASENAME}.old.${BASHPID}"
   fi
  ) &
  __logi "Check log per thread for more information."
  sleep 2
 done

 FAIL=0
 for JOB in $(jobs -p); do
  echo "${JOB}"
  set +e
  wait "${JOB}"
  RET="${?}"
  set -e
  if [[ "${RET}" -ne 0 ]]; then
   FAIL=$((FAIL + 1))
  fi
 done
 __logw "Waited for all jobs, restarting in main thread - countries."
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
 __log_finish
}

# Download the list of maritimes areas, then it downloads each area
# individually, converts the OSM JSON into a GeoJSON, and then it inserts the
# geometry of the maritime area into the Postgres database with ogr2ogr.
function __processMaritimes {
 __log_start
 # Extracts ids of all EEZ relations into a JSON.
 __logi "Obtaining the eez ids."
 set +e
 wget -O "${MARITIME_BOUNDARY_IDS_FILE}" --post-file="${OVERPASS_MARITIMES}" \
  "${OVERPASS_INTERPRETER}"
 RET=${?}
 set -e
 if [[ "${RET}" -ne 0 ]]; then
  __loge "ERROR: Maritime border list could not be downloaded."
  exit "${ERROR_DOWNLOADING_BOUNDARY_ID_LIST}"
 fi

 tail -n +2 "${MARITIME_BOUNDARY_IDS_FILE}" > "${MARITIME_BOUNDARY_IDS_FILE}.tmp"
 mv "${MARITIME_BOUNDARY_IDS_FILE}.tmp" "${MARITIME_BOUNDARY_IDS_FILE}"

 TOTAL_LINES=$(wc -l < "${MARITIME_BOUNDARY_IDS_FILE}")
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
   if [[ -n "${CLEAN}" ]] && [[ "${CLEAN}" = true ]]; then
    rm -f "${LOG_FILENAME}.${BASHPID}"
   else
    mv "${LOG_FILENAME}.${BASHPID}" "${TMP_DIR}/${BASENAME}.old.${BASHPID}"
   fi
  ) &
  __logi "Check log per thread for more information."
  sleep 2
 done

 FAIL=0
 for JOB in $(jobs -p); do
  echo "${JOB}"
  set +e
  wait "${JOB}"
  RET="${?}"
  set -e
  if [[ "${RET}" -ne 0 ]]; then
   FAIL=$((FAIL + 1))
  fi
 done
 __logw "Waited for all jobs, restarting in main thread - maritimes."
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

# Gets the area of each note.
function __getLocationNotes {
 __log_start
 __logd "Testing if notes should be updated."
 # shellcheck disable=SC2154
 if [[ "${UPDATE_NOTE_LOCATION}" = false ]]; then
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
 fi

 # Retrieves the max note for already location processed notes (from file.)
 MAX_NOTE_ID_NOT_NULL=$(psql -d "${DBNAME}" -Atq -v ON_ERROR_STOP=1 \
  <<< "SELECT MAX(note_id) FROM notes WHERE id_country IS NOT NULL")
 # Retrieves the max note.
 MAX_NOTE_ID=$(psql -d "${DBNAME}" -Atq -v ON_ERROR_STOP=1 \
  <<< "SELECT MAX(note_id) FROM notes")

 # Uses n-1 cores, if number of cores is greater than 1.
 # This prevents monopolization of the CPUs.
 if [[ "${MAX_THREADS}" -gt 1 ]]; then
  MAX_THREADS=$((MAX_THREADS - 1))
 fi

 # Processes notes that should already have a location.
 declare -l SIZE=$((MAX_NOTE_ID_NOT_NULL / MAX_THREADS))
 __logw "Starting background process to locate notes - old..."
 for J in $(seq 1 1 "${MAX_THREADS}"); do
  (
   __logi "Starting ${J}."
   # shellcheck disable=SC2154
   MIN=$((SIZE * (J - 1) + LOOP_SIZE))
   MAX=$((SIZE * J))
   for I in $(seq -f %1.0f "$((MAX))" "-${LOOP_SIZE}" "${MIN}"); do
    MIN_LOOP=$((I - LOOP_SIZE))
    MAX_LOOP=${I}
    __logd "${I}: [${MIN_LOOP} - ${MAX_LOOP}]."
    # TODO: Could this be removed?
    #STMT="SELECT COUNT(1), 'Notes without country - before - ${J}: ${MIN_LOOP}-${MAX_LOOP}'
    #  FROM notes
    #  WHERE ${MIN_LOOP} <= note_id AND note_id <= ${MAX_LOOP}
    #  AND id_country IS NULL"
    #echo "${STMT}" | psql -d "${DBNAME}" -t -v ON_ERROR_STOP=1

    if [[ "${UPDATE_NOTE_LOCATION}" = true ]]; then
     __logd "Updating incorrectly located notes."
     STMT="UPDATE notes AS n /* Notes-base thread old review */
     SET id_country = NULL
     FROM countries AS c
     WHERE n.id_country = c.country_id
     AND NOT ST_Contains(c.geom, ST_SetSRID(ST_Point(n.longitude, n.latitude),
      4326))
      AND ${MIN_LOOP} <= n.note_id AND n.note_id <= ${MAX_LOOP}
      AND id_country IS NOT NULL"
     __logt "${STMT}"
     echo "${STMT}" | psql -d "${DBNAME}" -v ON_ERROR_STOP=1
    fi

    # TODO: Could this be removed?
    #STMT="SELECT COUNT(1), 'Notes without country - after - ${J}: ${MIN_LOOP}-${MAX_LOOP}'
    #  FROM notes
    #  WHERE ${MIN_LOOP} <= note_id AND note_id <= ${MAX_LOOP}
    #  AND id_country IS NULL"
    #echo "${STMT}" | psql -d "${DBNAME}" -t -v ON_ERROR_STOP=1

    STMT="UPDATE notes /* Notes-base thread old */
      SET id_country = get_country(longitude, latitude, note_id)
      WHERE ${MIN_LOOP} <= note_id AND note_id <= ${MAX_LOOP}
      AND id_country IS NULL"
    echo "${STMT}" | psql -d "${DBNAME}" -v ON_ERROR_STOP=1
   done
   __logi "Finished ${J}."
  ) &
  __logi "Check log per thread for more information."
 done

 wait
 __logw "Waited for all jobs, restarting in main thread - old notes."

 # Processes new notes that do not have location.
 MAX_NOTE_ID_NOT_NULL=$((MAX_NOTE_ID_NOT_NULL - LOOP_SIZE))
 QTY=$((MAX_NOTE_ID - MAX_NOTE_ID_NOT_NULL))
 declare -l SIZE=$((QTY / MAX_THREADS))
 __logw "Starting background process to locate notes - new..."
 for J in $(seq 1 1 "${MAX_THREADS}"); do
  (
   __logi "Starting ${J}."
   MIN=$((MAX_NOTE_ID_NOT_NULL + SIZE * (J - 1) + LOOP_SIZE))
   MAX=$((MAX_NOTE_ID_NOT_NULL + SIZE * J))
   for I in $(seq -f %1.0f "$((MAX))" "-${LOOP_SIZE}" "${MIN}"); do
    MIN_LOOP=$((I - LOOP_SIZE))
    MAX_LOOP=${I}
    __logd "${I}: [${MIN_LOOP} - ${MAX_LOOP}]."
    # TODO: Could this be removed?
    #STMT="SELECT COUNT(1), 'Notes without country - before - ${J}: ${MIN_LOOP}-${MAX_LOOP}'
    #  FROM notes
    #  WHERE ${MIN_LOOP} <= note_id AND note_id <= ${MAX_LOOP}
    #  AND id_country IS NULL"
    #echo "${STMT}" | psql -d "${DBNAME}" -t -v ON_ERROR_STOP=1

    if [[ "${UPDATE_NOTE_LOCATION}" = true ]]; then
     __logd "Updating incorrectly located notes."
     STMT="UPDATE notes AS n /* Notes-base thread new review */
     SET id_country = NULL
     FROM countries AS c
     WHERE n.id_country = c.country_id
     AND NOT ST_Contains(c.geom, ST_SetSRID(ST_Point(n.longitude, n.latitude),
      4326))
      AND ${MIN_LOOP} <= n.note_id AND n.note_id < ${MAX_LOOP}
      AND id_country IS NOT NULL"
     __logt "${STMT}"
     echo "${STMT}" | psql -d "${DBNAME}" -v ON_ERROR_STOP=1
    fi

    # TODO: Could this be removed?
    #STMT="SELECT COUNT(1), 'Notes without country - after - ${J}: ${MIN_LOOP}-${MAX_LOOP}'
    #  FROM notes
    #  WHERE ${MIN_LOOP} <= note_id AND note_id < ${MAX_LOOP}
    #  AND id_country IS NULL"
    #echo "${STMT}" | psql -d "${DBNAME}" -t -v ON_ERROR_STOP=1

    STMT="UPDATE notes /* Notes-base thread old */
      SET id_country = get_country(longitude, latitude, note_id)
      WHERE ${MIN_LOOP} <= note_id AND note_id < ${MAX_LOOP}
      AND id_country IS NULL"
    echo "${STMT}" | psql -d "${DBNAME}" -v ON_ERROR_STOP=1
   done
   __logi "Finished ${J}."
  ) &
  __logi "Check log per thread for more information."
 done

 wait
 __logw "Waited for all jobs, restarting in main thread - new notes."

 echo "UPDATE notes /* Notes-base remaining */
   SET id_country = get_country(longitude, latitude, note_id)
   WHERE id_country IS NULL" | psql -d "${DBNAME}" -v ON_ERROR_STOP=1

 __log_finish
}

# Function to validate ISO 8601 date format
# Parameters:
#   $1: Date string to validate
#   $2: Expected format (optional, defaults to ISO 8601)
# Returns:
#   0 if valid, 1 if invalid
function __validate_iso8601_date() {
 local date_string="${1}"
 local expected_format="${2:-ISO 8601}"
 local validation_errors=()

 # Check if date string is provided
 if [[ -z "${date_string}" ]]; then
  echo "ERROR: Date string is empty" >&2
  return 1
 fi

 # Check for basic ISO 8601 format patterns
 # Pattern 1: YYYY-MM-DDTHH:MM:SSZ (UTC) - Year 2020-2023
 # Pattern 2: YYYY-MM-DDTHH:MM:SS+HH:MM (with timezone offset) - Year 2020-2023
 # Pattern 3: YYYY-MM-DDTHH:MM:SS-HH:MM (with timezone offset) - Year 2020-2023
 # Pattern 4: YYYY-MM-DD HH:MM:SS UTC (API format) - Year 2020-2023

 local iso_pattern1="^20(2[0-3])-[0-1][0-9]-[0-3][0-9]T[0-2][0-9]:[0-5][0-9]:[0-5][0-9]Z$"
 local iso_pattern2="^20(2[0-3])-[0-1][0-9]-[0-3][0-9]T[0-2][0-9]:[0-5][0-9]:[0-5][0-9][+-][0-2][0-9]:[0-5][0-9]$"
 local iso_pattern3="^20(2[0-3])-[0-1][0-9]-[0-3][0-9] [0-2][0-9]:[0-5][0-9]:[0-5][0-9] UTC$"

 # Check if date matches any ISO 8601 pattern
 if ! echo "${date_string}" | grep -qE "${iso_pattern1}|${iso_pattern2}|${iso_pattern3}"; then
  validation_errors+=("Date does not match ISO 8601 format: ${date_string}")
 fi

 # Additional validation using date command if available
 if command -v date &> /dev/null; then
  # Try to parse the date with date command
  local parsed_date
  if ! parsed_date=$(date -d "${date_string}" +%Y-%m-%dT%H:%M:%SZ 2> /dev/null); then
   validation_errors+=("Date is not a valid date/time: ${date_string}")
  fi
 fi

 # Report validation errors
 if [[ ${#validation_errors[@]} -gt 0 ]]; then
  echo "ERROR: ${expected_format} date validation failed:" >&2
  for error in "${validation_errors[@]}"; do
   echo "  - ${error}" >&2
  done
  return 1
 fi

 echo "DEBUG: ${expected_format} date validation passed: ${date_string}" >&2
 return 0
}

# Function to validate dates in XML files
# Parameters:
#   $1: XML file path
#   $2: XPath expression for date elements (optional)
# Returns:
#   0 if all dates are valid, 1 if any invalid
function __validate_xml_dates() {
 local xml_file="${1}"
 local xpath_expression="${2:-//@created_at|//@closed_at|//@timestamp|//date}"
 local validation_errors=()

 # Check if file exists and is readable
 if ! __validate_input_file "${xml_file}" "XML file"; then
  return 1
 fi

 # Check if xmlstarlet is available
 if ! command -v xmlstarlet &> /dev/null; then
  echo "WARNING: xmlstarlet not available, skipping XML date validation" >&2
  return 0
 fi

 # Extract dates using xmlstarlet
 local dates
 dates=$(xmlstarlet sel -t -v "${xpath_expression}" "${xml_file}" 2> /dev/null | grep -v '^$')

 if [[ -z "${dates}" ]]; then
  echo "WARNING: No dates found in XML file with xpath: ${xpath_expression}" >&2
  return 0
 fi

 # Validate each date
 local line_number=0
 while IFS= read -r date_value; do
  ((line_number++))
  if ! __validate_iso8601_date "${date_value}" "ISO 8601"; then
   validation_errors+=("Line ${line_number}: Invalid date '${date_value}'")
  fi
 done <<< "${dates}"

 # Report validation errors
 if [[ ${#validation_errors[@]} -gt 0 ]]; then
  echo "ERROR: XML date validation failed for ${xml_file}:" >&2
  for error in "${validation_errors[@]}"; do
   echo "  - ${error}" >&2
  done
  return 1
 fi

 echo "DEBUG: XML date validation passed: ${xml_file}" >&2
 return 0
}

# Function to validate dates in CSV files
# Parameters:
#   $1: CSV file path
#   $2: Column number containing dates (optional, defaults to auto-detect)
# Returns:
#   0 if all dates are valid, 1 if any invalid
function __validate_csv_dates() {
 local csv_file="${1}"
 local date_column="${2:-}"
 local validation_errors=()

 # Check if file exists and is readable
 if ! __validate_input_file "${csv_file}" "CSV file"; then
  return 1
 fi

 # Auto-detect date column if not specified
 if [[ -z "${date_column}" ]]; then
  local header_line
  header_line=$(head -1 "${csv_file}")
  local column_number=1
  local found_date_column=false

  while IFS=',' read -ra columns; do
   for column in "${columns[@]}"; do
    if [[ "${column}" =~ (date|created|updated|timestamp|closed) ]]; then
     date_column="${column_number}"
     found_date_column=true
     break 2
    fi
    ((column_number++))
   done
  done <<< "${header_line}"

  if [[ "${found_date_column}" == "false" ]]; then
   echo "WARNING: No date column found in CSV header" >&2
   return 0
  fi
 fi

 # Extract dates from the specified column
 local dates
 dates=$(tail -n +2 "${csv_file}" | cut -d',' -f"${date_column}" | grep -v '^$')

 if [[ -z "${dates}" ]]; then
  echo "WARNING: No dates found in CSV column ${date_column}" >&2
  return 0
 fi

 # Validate each date
 local line_number=1
 while IFS= read -r date_value; do
  ((line_number++))
  if ! __validate_iso8601_date "${date_value}" "ISO 8601"; then
   validation_errors+=("Line ${line_number}: Invalid date '${date_value}'")
  fi
 done <<< "${dates}"

 # Report validation errors
 if [[ ${#validation_errors[@]} -gt 0 ]]; then
  echo "ERROR: CSV date validation failed for ${csv_file}:" >&2
  for error in "${validation_errors[@]}"; do
   echo "  - ${error}" >&2
  done
  return 1
 fi

 echo "DEBUG: CSV date validation passed: ${csv_file}" >&2
 return 0
}

# Function to validate file checksum
# Parameters:
#   $1: File path to validate
#   $2: Expected checksum
#   $3: Algorithm (optional, defaults to md5)
# Returns:
#   0 if valid, 1 if invalid
function __validate_file_checksum() {
 local file_path="${1}"
 local expected_checksum="${2}"
 local algorithm="${3:-md5}"
 local validation_errors=()

 # Check if file exists and is readable
 if ! __validate_input_file "${file_path}" "File for checksum validation"; then
  return 1
 fi

 # Check if expected checksum is provided
 if [[ -z "${expected_checksum}" ]]; then
  echo "ERROR: Expected checksum is empty" >&2
  return 1
 fi

 # Validate algorithm
 local valid_algorithms=("md5" "sha1" "sha256" "sha512")
 local valid_algorithm=false
 for algo in "${valid_algorithms[@]}"; do
  if [[ "${algorithm}" == "${algo}" ]]; then
   valid_algorithm=true
   break
  fi
 done

 if [[ "${valid_algorithm}" == "false" ]]; then
  echo "ERROR: ${algorithm} checksum validation failed:" >&2
  echo "  - Invalid algorithm: ${algorithm}. Supported: ${valid_algorithms[*]}" >&2
  return 1
 fi

 # Calculate actual checksum
 local actual_checksum
 case "${algorithm}" in
 "md5")
  actual_checksum=$(md5sum "${file_path}" | cut -d' ' -f 1 2> /dev/null)
  ;;
 "sha1")
  actual_checksum=$(sha1sum "${file_path}" | cut -d' ' -f 1 2> /dev/null)
  ;;
 "sha256")
  actual_checksum=$(sha256sum "${file_path}" | cut -d' ' -f 1 2> /dev/null)
  ;;
 "sha512")
  actual_checksum=$(sha512sum "${file_path}" | cut -d' ' -f 1 2> /dev/null)
  ;;
 *)
  echo "ERROR: ${algorithm} checksum validation failed:" >&2
  echo "  - Unsupported algorithm: ${algorithm}" >&2
  return 1
  ;;
 esac

 if [[ -z "${actual_checksum}" ]]; then
  echo "ERROR: ${algorithm} checksum validation failed:" >&2
  echo "  - Failed to calculate ${algorithm} checksum for file: ${file_path}" >&2
  return 1
 fi

 # Compare checksums
 if [[ "${actual_checksum}" != "${expected_checksum}" ]]; then
  echo "ERROR: ${algorithm} checksum validation failed:" >&2
  echo "  - Checksum mismatch for ${file_path}:" >&2
  echo "    Expected: ${expected_checksum}" >&2
  echo "    Actual:   ${actual_checksum}" >&2
  return 1
 fi

 echo "DEBUG: ${algorithm} checksum validation passed: ${file_path}" >&2
 return 0
}

# Function to validate checksum from a checksum file
# Parameters:
#   $1: File path to validate
#   $2: Checksum file path
#   $3: Algorithm (optional, defaults to md5)
# Returns:
#   0 if valid, 1 if invalid
function __validate_file_checksum_from_file() {
 local file_path="${1}"
 local checksum_file="${2}"
 local algorithm="${3:-md5}"
 local validation_errors=()

 # Check if checksum file exists and is readable
 if ! __validate_input_file "${checksum_file}" "Checksum file"; then
  return 1
 fi

 # Extract expected checksum from file
 local expected_checksum
 case "${algorithm}" in
 "md5")
  expected_checksum=$(cut -d' ' -f 1 "${checksum_file}" 2> /dev/null)
  ;;
 "sha1")
  expected_checksum=$(cut -d' ' -f 1 "${checksum_file}" 2> /dev/null)
  ;;
 "sha256")
  expected_checksum=$(cut -d' ' -f 1 "${checksum_file}" 2> /dev/null)
  ;;
 "sha512")
  expected_checksum=$(cut -d' ' -f 1 "${checksum_file}" 2> /dev/null)
  ;;
 *)
  echo "ERROR: Unsupported algorithm: ${algorithm}" >&2
  return 1
  ;;
 esac

 if [[ -z "${expected_checksum}" ]]; then
  echo "ERROR: Could not extract checksum from file: ${checksum_file}" >&2
  return 1
 fi

 # Validate the file using the extracted checksum
 __validate_file_checksum "${file_path}" "${expected_checksum}" "${algorithm}"
}

# Function to generate checksum for a file
# Parameters:
#   $1: File path
#   $2: Algorithm (optional, defaults to md5)
#   $3: Output file (optional, if not provided prints to stdout)
# Returns:
#   0 if successful, 1 if failed
function __generate_file_checksum() {
 local file_path="${1}"
 local algorithm="${2:-md5}"
 local output_file="${3:-}"
 local validation_errors=()

 # Check if file exists and is readable
 if ! __validate_input_file "${file_path}" "File for checksum generation"; then
  return 1
 fi

 # Validate algorithm
 local valid_algorithms=("md5" "sha1" "sha256" "sha512")
 local valid_algorithm=false
 for algo in "${valid_algorithms[@]}"; do
  if [[ "${algorithm}" == "${algo}" ]]; then
   valid_algorithm=true
   break
  fi
 done

 if [[ "${valid_algorithm}" == "false" ]]; then
  echo "ERROR: Invalid algorithm: ${algorithm}. Supported: ${valid_algorithms[*]}" >&2
  return 1
 fi

 # Generate checksum
 local checksum
 case "${algorithm}" in
 "md5")
  checksum=$(md5sum "${file_path}" 2> /dev/null)
  ;;
 "sha1")
  checksum=$(sha1sum "${file_path}" 2> /dev/null)
  ;;
 "sha256")
  checksum=$(sha256sum "${file_path}" 2> /dev/null)
  ;;
 "sha512")
  checksum=$(sha512sum "${file_path}" 2> /dev/null)
  ;;
 *)
  echo "ERROR: Unsupported algorithm: ${algorithm}" >&2
  return 1
  ;;
 esac

 if [[ -z "${checksum}" ]]; then
  echo "ERROR: Failed to generate ${algorithm} checksum for file: ${file_path}" >&2
  return 1
 fi

 # Output checksum
 if [[ -n "${output_file}" ]]; then
  echo "${checksum}" > "${output_file}"
  echo "DEBUG: ${algorithm} checksum saved to: ${output_file}" >&2
 else
  echo "${checksum}"
 fi

 return 0
}

# Function to validate multiple files using checksum files
# Parameters:
#   $1: Directory containing files to validate
#   $2: Checksum file path
#   $3: Algorithm (optional, defaults to md5)
# Returns:
#   0 if all valid, 1 if any invalid
function __validate_directory_checksums() {
 local directory="${1}"
 local checksum_file="${2}"
 local algorithm="${3:-md5}"
 local validation_errors=()

 # Check if directory exists
 if ! __validate_input_file "${directory}" "Directory" "dir"; then
  return 1
 fi

 # Check if checksum file exists
 if ! __validate_input_file "${checksum_file}" "Checksum file"; then
  return 1
 fi

 # Read checksum file and validate each file
 while IFS= read -r line; do
  # Skip empty lines and comments
  if [[ -z "${line}" ]] || [[ "${line}" =~ ^[[:space:]]*# ]]; then
   continue
  fi

  # Parse checksum and filename
  local checksum filename
  case "${algorithm}" in
  "md5" | "sha1" | "sha256" | "sha512")
   checksum=$(echo "${line}" | cut -d' ' -f 1)
   filename=$(echo "${line}" | sed 's/^[^ ]*  *//' | xargs basename)
   ;;
  *)
   echo "ERROR: Unsupported algorithm: ${algorithm}" >&2
   return 1
   ;;
  esac

  # Validate file
  local file_path="${directory}/${filename}"
  if ! __validate_file_checksum "${file_path}" "${checksum}" "${algorithm}"; then
   validation_errors+=("Failed to validate: ${filename}")
  fi
 done < "${checksum_file}"

 # Report validation errors
 if [[ ${#validation_errors[@]} -gt 0 ]]; then
  echo "ERROR: Directory checksum validation failed:" >&2
  for error in "${validation_errors[@]}"; do
   echo "  - ${error}" >&2
  done
  return 1
 fi

 echo "DEBUG: Directory checksum validation passed: ${directory}" >&2
 return 0
}

# Validates JSON file against a JSON Schema
# Parameters:
#   $1: JSON file path to validate
#   $2: JSON Schema file path
#   $3: Schema specification (optional, defaults to draft2020)
# Returns:
#   0 if valid, 1 if invalid
function __validate_json_schema() {
 local json_file="${1}"
 local schema_file="${2}"
 local spec="${3:-draft2020}"
 local validation_errors=()

 # Check if ajv is available
 if ! command -v ajv &> /dev/null; then
  echo "ERROR: ajv command not available for JSON Schema validation" >&2
  return 1
 fi

 # Check if JSON file exists and is readable
 if ! __validate_input_file "${json_file}" "JSON file"; then
  return 1
 fi

 # Check if schema file exists and is readable
 if ! __validate_input_file "${schema_file}" "JSON Schema file"; then
  return 1
 fi

 # Validate JSON against schema using ajv
 set +e
 ajv validate -s "${schema_file}" -d "${json_file}" --spec="${spec}" 2> /dev/null
 local ajv_status=$?
 set -e

 if [[ ${ajv_status} -eq 0 ]]; then
  echo "DEBUG: JSON Schema validation passed: ${json_file}" >&2
  return 0
 else
  echo "ERROR: JSON Schema validation failed: ${json_file}" >&2
  return 1
 fi
}

# Validates geographic coordinates
# Parameters:
#   $1: Latitude value
#   $2: Longitude value
#   $3: Precision (optional, defaults to 7 decimal places)
# Returns:
#   0 if coordinates are valid, 1 if invalid
function __validate_coordinates() {
 local latitude="${1}"
 local longitude="${2}"
 local precision="${3:-7}"
 local validation_errors=()

 # Check if values are numeric
 if ! [[ "${latitude}" =~ ^-?[0-9]+\.?[0-9]*$ ]]; then
  validation_errors+=("Latitude '${latitude}' is not a valid number")
 fi

 if ! [[ "${longitude}" =~ ^-?[0-9]+\.?[0-9]*$ ]]; then
  validation_errors+=("Longitude '${longitude}' is not a valid number")
 fi

 # Check latitude range (-90 to 90)
 if [[ "${latitude}" =~ ^-?[0-9]+\.?[0-9]*$ ]]; then
  if (($(echo "${latitude} < -90" | bc -l))) || (($(echo "${latitude} > 90" | bc -l))); then
   validation_errors+=("Latitude '${latitude}' is outside valid range (-90 to 90)")
  fi
 fi

 # Check longitude range (-180 to 180)
 if [[ "${longitude}" =~ ^-?[0-9]+\.?[0-9]*$ ]]; then
  if (($(echo "${longitude} < -180" | bc -l))) || (($(echo "${longitude} > 180" | bc -l))); then
   validation_errors+=("Longitude '${longitude}' is outside valid range (-180 to 180)")
  fi
 fi

 # Check precision
 if [[ "${latitude}" =~ ^-?[0-9]+\.[0-9]{${precision},}$ ]]; then
  validation_errors+=("Latitude '${latitude}' has too many decimal places (max ${precision})")
 fi

 if [[ "${longitude}" =~ ^-?[0-9]+\.[0-9]{${precision},}$ ]]; then
  validation_errors+=("Longitude '${longitude}' has too many decimal places (max ${precision})")
 fi

 # Report validation errors
 if [[ ${#validation_errors[@]} -gt 0 ]]; then
  echo "ERROR: Coordinate validation failed:" >&2
  for error in "${validation_errors[@]}"; do
   echo "  - ${error}" >&2
  done
  return 1
 fi

 echo "DEBUG: Coordinate validation passed: lat=${latitude}, lon=${longitude}" >&2
 return 0
}

# Validates numeric values within specified ranges
# Parameters:
#   $1: Value to validate
#   $2: Minimum value (optional)
#   $3: Maximum value (optional)
#   $4: Description for error messages (optional)
# Returns:
#   0 if value is valid, 1 if invalid
function __validate_numeric_range() {
 local value="${1}"
 local min_value="${2:-}"
 local max_value="${3:-}"
 local description="${4:-Value}"
 local validation_errors=()

 # Check if value is numeric
 if ! [[ "${value}" =~ ^-?[0-9]+\.?[0-9]*$ ]]; then
  echo "ERROR: ${description} '${value}' is not a valid number" >&2
  return 1
 fi

 # Check minimum value
 if [[ -n "${min_value}" ]]; then
  if (($(echo "${value} < ${min_value}" | bc -l))); then
   validation_errors+=("${description} '${value}' is below minimum (${min_value})")
  fi
 fi

 # Check maximum value
 if [[ -n "${max_value}" ]]; then
  if (($(echo "${value} > ${max_value}" | bc -l))); then
   validation_errors+=("${description} '${value}' is above maximum (${max_value})")
  fi
 fi

 # Report validation errors
 if [[ ${#validation_errors[@]} -gt 0 ]]; then
  echo "ERROR: Numeric range validation failed:" >&2
  for error in "${validation_errors[@]}"; do
   echo "  - ${error}" >&2
  done
  return 1
 fi

 echo "DEBUG: Numeric range validation passed: ${description}=${value}" >&2
 return 0
}

# Validates string values against patterns
# Parameters:
#   $1: Value to validate
#   $2: Regular expression pattern
#   $3: Description for error messages (optional)
# Returns:
#   0 if value matches pattern, 1 if invalid
function __validate_string_pattern() {
 local value="${1}"
 local pattern="${2}"
 local description="${3:-String value}"
 local validation_errors=()

 # Check if value matches pattern
 if ! [[ "${value}" =~ ${pattern} ]]; then
  echo "ERROR: ${description} '${value}' does not match required pattern" >&2
  return 1
 fi

 echo "DEBUG: String pattern validation passed: ${description}=${value}" >&2
 return 0
}

# Validates XML content for coordinate attributes
# Parameters:
#   $1: XML file path
#   $2: XPath expression for latitude (optional, defaults to //@lat)
#   $3: XPath expression for longitude (optional, defaults to //@lon)
# Returns:
#   0 if all coordinates are valid, 1 if any invalid
function __validate_xml_coordinates() {
 local xml_file="${1}"
 local lat_xpath="${2:-//@lat}"
 local lon_xpath="${3:-//@lon}"
 local validation_errors=()

 # Check if file exists and is readable
 if ! __validate_input_file "${xml_file}" "XML file"; then
  return 1
 fi

 # Check if xmlstarlet is available
 if ! command -v xmlstarlet &> /dev/null; then
  echo "WARNING: xmlstarlet not available, skipping XML coordinate validation" >&2
  return 0
 fi

 # Extract coordinates using xmlstarlet
 local latitudes
 local longitudes
 latitudes=$(xmlstarlet sel -t -v "${lat_xpath}" "${xml_file}" 2> /dev/null | grep -v '^$')
 longitudes=$(xmlstarlet sel -t -v "${lon_xpath}" "${xml_file}" 2> /dev/null | grep -v '^$')

 if [[ -z "${latitudes}" ]] || [[ -z "${longitudes}" ]]; then
  echo "WARNING: No coordinates found in XML file" >&2
  return 0
 fi

 # Validate each coordinate pair
 local line_number=0
 while IFS= read -r lat_value; do
  ((line_number++))
  lon_value=$(echo "${longitudes}" | sed -n "${line_number}p")

  if [[ -n "${lon_value}" ]]; then
   if ! __validate_coordinates "${lat_value}" "${lon_value}"; then
    validation_errors+=("Line ${line_number}: Invalid coordinates lat=${lat_value}, lon=${lon_value}")
   fi
  fi
 done <<< "${latitudes}"

 # Report validation errors
 if [[ ${#validation_errors[@]} -gt 0 ]]; then
  echo "ERROR: XML coordinate validation failed for ${xml_file}:" >&2
  for error in "${validation_errors[@]}"; do
   echo "  - ${error}" >&2
  done
  return 1
 fi

 echo "DEBUG: XML coordinate validation passed: ${xml_file}" >&2
 return 0
}

# Validates CSV content for coordinate columns
# Parameters:
#   $1: CSV file path
#   $2: Latitude column number (optional, defaults to auto-detect)
#   $3: Longitude column number (optional, defaults to auto-detect)
# Returns:
#   0 if all coordinates are valid, 1 if any invalid
function __validate_csv_coordinates() {
 local csv_file="${1}"
 local lat_column="${2:-}"
 local lon_column="${3:-}"
 local validation_errors=()

 # Check if file exists and is readable
 if ! __validate_input_file "${csv_file}" "CSV file"; then
  return 1
 fi

 # Auto-detect coordinate columns if not specified
 if [[ -z "${lat_column}" ]] || [[ -z "${lon_column}" ]]; then
  local header_line
  header_line=$(head -1 "${csv_file}")
  local column_number=1
  local found_lat=false
  local found_lon=false

  while IFS=',' read -ra columns; do
   for column in "${columns[@]}"; do
    if [[ "${column}" =~ (lat|latitude) ]]; then
     lat_column="${column_number}"
     found_lat=true
    elif [[ "${column}" =~ (lon|longitude) ]]; then
     lon_column="${column_number}"
     found_lon=true
    fi
    ((column_number++))
   done
  done <<< "${header_line}"

  if [[ "${found_lat}" == "false" ]] || [[ "${found_lon}" == "false" ]]; then
   echo "WARNING: Coordinate columns not found in CSV header" >&2
   return 0
  fi
 fi

 # Extract coordinates from the specified columns
 local coordinates
 coordinates=$(tail -n +2 "${csv_file}" | cut -d',' -f"${lat_column},${lon_column}" | grep -v '^$')

 if [[ -z "${coordinates}" ]]; then
  echo "WARNING: No coordinates found in CSV columns" >&2
  return 0
 fi

 # Validate each coordinate pair
 local line_number=1
 while IFS= read -r coordinate_line; do
  ((line_number++))
  local lat_value
  local lon_value
  lat_value=$(echo "${coordinate_line}" | cut -d',' -f1)
  lon_value=$(echo "${coordinate_line}" | cut -d',' -f2)

  if [[ -n "${lat_value}" ]] && [[ -n "${lon_value}" ]]; then
   if ! __validate_coordinates "${lat_value}" "${lon_value}"; then
    validation_errors+=("Line ${line_number}: Invalid coordinates lat=${lat_value}, lon=${lon_value}")
   fi
  fi
 done <<< "${coordinates}"

 # Report validation errors
 if [[ ${#validation_errors[@]} -gt 0 ]]; then
  echo "ERROR: CSV coordinate validation failed for ${csv_file}:" >&2
  for error in "${validation_errors[@]}"; do
   echo "  - ${error}" >&2
  done
  return 1
 fi

 echo "DEBUG: CSV coordinate validation passed: ${csv_file}" >&2
 return 0
}

# Validates production database variables
# This function ensures that production database variables are properly set
# Parameters: None
# Returns: 0 if validation passes, 1 if validation fails
function __validate_database_variables() {
 local validation_errors=()

 # Check primary database variables
 if [[ -z "${DBNAME:-}" ]]; then
  validation_errors+=("DBNAME is not set")
 fi

 if [[ -z "${DB_USER:-}" ]]; then
  validation_errors+=("DB_USER is not set")
 fi

 # Report validation errors
 if [[ ${#validation_errors[@]} -gt 0 ]]; then
  echo "ERROR: Database variable validation failed:" >&2
  for error in "${validation_errors[@]}"; do
   echo "  - ${error}" >&2
  done
  return 1
 fi

 echo "DEBUG: Database variable validation passed" >&2
 return 0
}

# Enhanced error handling and retry logic
# Author: Andres Gomez (AngocA)
# Version: 2025-07-29

# Retry configuration
declare -r MAX_RETRIES="${MAX_RETRIES:-3}"
declare -r BASE_DELAY="${BASE_DELAY:-2}"
declare -r MAX_DELAY="${MAX_DELAY:-60}"
declare -r CIRCUIT_BREAKER_THRESHOLD="${CIRCUIT_BREAKER_THRESHOLD:-5}"
declare -r CIRCUIT_BREAKER_TIMEOUT="${CIRCUIT_BREAKER_TIMEOUT:-300}"

# Circuit breaker state
declare -A CIRCUIT_BREAKER_STATES
declare -A CIRCUIT_BREAKER_FAILURE_COUNTS
declare -A CIRCUIT_BREAKER_LAST_FAILURE_TIMES

# Enhanced retry with exponential backoff and jitter
# Parameters: command_to_execute [max_retries] [base_delay] [max_delay]
# Returns: 0 if successful, 1 if failed after all retries
function __retry_with_backoff() {
 local command="$1"
 local max_retries="${2:-${MAX_RETRIES}}"
 local base_delay="${3:-${BASE_DELAY}}"
 local max_delay="${4:-${MAX_DELAY}}"
 local retry_count=0
 local delay="${base_delay}"

 echo "DEBUG: Executing command with retry logic: ${command}" >&2

 while [[ ${retry_count} -lt ${max_retries} ]]; do
  # Execute the command
  if eval "${command}"; then
   echo "DEBUG: Command succeeded on attempt $((retry_count + 1))" >&2
   return 0
  fi

  retry_count=$((retry_count + 1))

  if [[ ${retry_count} -lt ${max_retries} ]]; then
   # Add jitter to prevent thundering herd
   local jitter=$((RANDOM % 1000))
   local jitter_delay=$(echo "scale=3; ${jitter} / 1000" | bc -l 2> /dev/null || echo "0")
   local total_delay=$(echo "scale=3; ${delay} + ${jitter_delay}" | bc -l 2> /dev/null || echo "${delay}")

   echo "WARNING: Command failed on attempt ${retry_count}, retrying in ${total_delay}s (${retry_count}/${max_retries})" >&2
   sleep "${total_delay}"

   # Exponential backoff with max delay
   delay=$(echo "scale=3; ${delay} * 2" | bc -l 2> /dev/null || echo "${delay}")
   if (($(echo "${delay} > ${max_delay}" | bc -l 2> /dev/null || echo "0"))); then
    delay="${max_delay}"
   fi
  fi
 done

 echo "ERROR: Command failed after ${max_retries} attempts: ${command}" >&2
 return 1
}

# Circuit breaker pattern implementation
# Parameters: service_name command_to_execute
# Returns: 0 if successful, 1 if circuit is open or command failed
function __circuit_breaker_execute() {
 local service_name="$1"
 local command="$2"
 local current_time=$(date +%s)
 local state="${CIRCUIT_BREAKER_STATES[${service_name}]:-CLOSED}"
 local failure_count="${CIRCUIT_BREAKER_FAILURE_COUNTS[${service_name}]:-0}"
 local last_failure_time="${CIRCUIT_BREAKER_LAST_FAILURE_TIMES[${service_name}]:-0}"

 # Check if circuit is open and timeout has passed
 if [[ "${state}" == "OPEN" ]]; then
  local time_since_failure=$((current_time - last_failure_time))
  if [[ ${time_since_failure} -gt ${CIRCUIT_BREAKER_TIMEOUT} ]]; then
   echo "INFO: Circuit breaker for ${service_name} transitioning to HALF_OPEN" >&2
   CIRCUIT_BREAKER_STATES[${service_name}]="HALF_OPEN"
   state="HALF_OPEN"
  else
   echo "WARNING: Circuit breaker for ${service_name} is OPEN, skipping execution" >&2
   return 1
  fi
 fi

 # Execute command
 if eval "${command}"; then
  # Success - close circuit and reset failure count
  if [[ "${state}" != "CLOSED" ]]; then
   echo "INFO: Circuit breaker for ${service_name} transitioning to CLOSED" >&2
  fi
  CIRCUIT_BREAKER_STATES[${service_name}]="CLOSED"
  CIRCUIT_BREAKER_FAILURE_COUNTS[${service_name}]=0
  return 0
 else
  # Failure - increment failure count
  failure_count=$((failure_count + 1))
  CIRCUIT_BREAKER_FAILURE_COUNTS[${service_name}]=${failure_count}
  CIRCUIT_BREAKER_LAST_FAILURE_TIMES[${service_name}]=${current_time}

  if [[ ${failure_count} -ge ${CIRCUIT_BREAKER_THRESHOLD} ]]; then
   echo "ERROR: Circuit breaker for ${service_name} transitioning to OPEN (${failure_count} failures)" >&2
   CIRCUIT_BREAKER_STATES[${service_name}]="OPEN"
  fi
  return 1
 fi
}

# Enhanced network download with retry and circuit breaker
# Parameters: url output_file [service_name]
# Returns: 0 if successful, 1 if failed
function __download_with_retry() {
 local url="$1"
 local output_file="$2"
 local service_name="${3:-download}"
 local command="wget -O '${output_file}' '${url}'"

 echo "DEBUG: Downloading ${url} to ${output_file}" >&2

 # Use circuit breaker for network operations
 if __circuit_breaker_execute "${service_name}" "${command}"; then
  echo "DEBUG: Download successful: ${url}" >&2
  return 0
 else
  echo "ERROR: Download failed after retries: ${url}" >&2
  return 1
 fi
}

# Enhanced API call with retry and circuit breaker
# Parameters: url output_file [service_name]
# Returns: 0 if successful, 1 if failed
function __api_call_with_retry() {
 local url="$1"
 local output_file="$2"
 local service_name="${3:-api}"
 local command="curl -s -o '${output_file}' '${url}'"

 echo "DEBUG: Making API call to ${url}" >&2

 # Use circuit breaker for API operations
 if __circuit_breaker_execute "${service_name}" "${command}"; then
  echo "DEBUG: API call successful: ${url}" >&2
  return 0
 else
  echo "ERROR: API call failed after retries: ${url}" >&2
  return 1
 fi
}

# Database operation with retry and rollback capability
# Parameters: sql_command [rollback_command]
# Returns: 0 if successful, 1 if failed
function __database_operation_with_retry() {
 local sql_command="$1"
 local rollback_command="${2:-}"
 local max_retries="${MAX_RETRIES:-3}"
 local retry_count=0

 echo "DEBUG: Executing database operation with retry" >&2

 while [[ ${retry_count} -lt ${max_retries} ]]; do
  if psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -c "${sql_command}" > /dev/null 2>&1; then
   echo "DEBUG: Database operation succeeded on attempt $((retry_count + 1))" >&2
   return 0
  fi

  retry_count=$((retry_count + 1))

  if [[ ${retry_count} -lt ${max_retries} ]]; then
   echo "WARNING: Database operation failed on attempt ${retry_count}, retrying in ${BASE_DELAY}s" >&2
   sleep "${BASE_DELAY}"
  fi
 done

 # If rollback command is provided, execute it
 if [[ -n "${rollback_command}" ]]; then
  echo "WARNING: Executing rollback command due to database operation failure" >&2
  if psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -c "${rollback_command}" > /dev/null 2>&1; then
   echo "DEBUG: Rollback executed successfully" >&2
  else
   echo "ERROR: Rollback failed" >&2
  fi
 fi

 echo "ERROR: Database operation failed after ${max_retries} attempts" >&2
 return 1
}

# File operation with retry and cleanup
# Parameters: operation_command [cleanup_command]
# Returns: 0 if successful, 1 if failed
function __file_operation_with_retry() {
 local operation_command="$1"
 local cleanup_command="${2:-}"
 local max_retries="${MAX_RETRIES:-3}"
 local retry_count=0

 echo "DEBUG: Executing file operation with retry" >&2

 while [[ ${retry_count} -lt ${max_retries} ]]; do
  if eval "${operation_command}"; then
   echo "DEBUG: File operation succeeded on attempt $((retry_count + 1))" >&2
   return 0
  fi

  retry_count=$((retry_count + 1))

  if [[ ${retry_count} -lt ${max_retries} ]]; then
   echo "WARNING: File operation failed on attempt ${retry_count}, retrying in ${BASE_DELAY}s" >&2
   sleep "${BASE_DELAY}"
  fi
 done

 # If cleanup command is provided, execute it
 if [[ -n "${cleanup_command}" ]]; then
  echo "WARNING: Executing cleanup command due to file operation failure" >&2
  if eval "${cleanup_command}"; then
   echo "DEBUG: Cleanup executed successfully" >&2
  else
   echo "ERROR: Cleanup failed" >&2
  fi
 fi

 echo "ERROR: File operation failed after ${max_retries} attempts" >&2
 return 1
}

# Health check for network connectivity
# Parameters: [timeout_seconds]
# Returns: 0 if network is available, 1 if not
function __check_network_connectivity() {
 local timeout="${1:-10}"
 local test_urls=("https://www.google.com" "https://www.cloudflare.com" "https://www.github.com")

 echo "DEBUG: Checking network connectivity" >&2

 for url in "${test_urls[@]}"; do
  if timeout "${timeout}" curl -s --connect-timeout 5 "${url}" > /dev/null 2>&1; then
   echo "DEBUG: Network connectivity confirmed via ${url}" >&2
   return 0
  fi
 done

 echo "ERROR: Network connectivity check failed" >&2
 return 1
}

# Enhanced error recovery with automatic cleanup
# Parameters: error_code error_message [cleanup_commands...]
# Returns: Always exits with error_code
function __handle_error_with_cleanup() {
 local error_code="$1"
 local error_message="$2"
 shift 2
 local cleanup_commands=("$@")

 echo "ERROR: Error occurred: ${error_message} (code: ${error_code})" >&2

 # Execute cleanup commands
 for cmd in "${cleanup_commands[@]}"; do
  if [[ -n "${cmd}" ]]; then
   echo "DEBUG: Executing cleanup command: ${cmd}" >&2
   if eval "${cmd}"; then
    echo "DEBUG: Cleanup command succeeded: ${cmd}" >&2
   else
    echo "WARNING: Cleanup command failed: ${cmd}" >&2
   fi
  fi
 done

 # Log error details for debugging
 echo "ERROR: Error details - Code: ${error_code}, Message: ${error_message}" >&2
 echo "ERROR: Stack trace: $(caller 0)" >&2

 exit "${error_code}"
}

# Get circuit breaker status for monitoring
# Parameters: service_name
# Returns: Status string (CLOSED/OPEN/HALF_OPEN)
function __get_circuit_breaker_status() {
 local service_name="$1"
 echo "${CIRCUIT_BREAKER_STATES[${service_name}]:-CLOSED}"
}

# Reset circuit breaker for a service
# Parameters: service_name
# Returns: 0 if reset successful
function __reset_circuit_breaker() {
 local service_name="$1"

 CIRCUIT_BREAKER_STATES[${service_name}]="CLOSED"
 CIRCUIT_BREAKER_FAILURE_COUNTS[${service_name}]=0
 CIRCUIT_BREAKER_LAST_FAILURE_TIMES[${service_name}]=0

 echo "INFO: Circuit breaker reset for ${service_name}" >&2
 return 0
}

# Enhanced retry with exponential backoff and jitter
# Parameters: command_to_execute [max_retries] [base_delay] [max_delay]
# Returns: 0 if successful, 1 if failed after all retries
function __retry_with_backoff() {
 local command="$1"
 local max_retries="${2:-${MAX_RETRIES}}"
 local base_delay="${3:-${BASE_DELAY}}"
 local max_delay="${4:-${MAX_DELAY}}"
 local retry_count=0
 local delay="${base_delay}"

 echo "DEBUG: Executing command with retry logic: ${command}" >&2

 while [[ ${retry_count} -lt ${max_retries} ]]; do
  # Execute the command
  if eval "${command}"; then
   echo "DEBUG: Command succeeded on attempt $((retry_count + 1))" >&2
   return 0
  fi

  retry_count=$((retry_count + 1))

  if [[ ${retry_count} -lt ${max_retries} ]]; then
   # Add jitter to prevent thundering herd
   local jitter=$((RANDOM % 1000))
   local jitter_delay=$(echo "scale=3; ${jitter} / 1000" | bc -l 2> /dev/null || echo "0")
   local total_delay=$(echo "scale=3; ${delay} + ${jitter_delay}" | bc -l 2> /dev/null || echo "${delay}")

   echo "WARNING: Command failed on attempt ${retry_count}, retrying in ${total_delay}s (${retry_count}/${max_retries})" >&2
   sleep "${total_delay}"

   # Exponential backoff with max delay
   delay=$(echo "scale=3; ${delay} * 2" | bc -l 2> /dev/null || echo "${delay}")
   if (($(echo "${delay} > ${max_delay}" | bc -l 2> /dev/null || echo "0"))); then
    delay="${max_delay}"
   fi
  fi
 done

 echo "ERROR: Command failed after ${max_retries} attempts: ${command}" >&2
 return 1
}

# Retry file operations with cleanup on failure
# Parameters: operation_command max_retries base_delay [cleanup_command]
# Returns: 0 if successful, 1 if failed after all retries
function __retry_file_operation() {
 local operation_command="$1"
 local max_retries="${2:-3}"
 local base_delay="${3:-2}"
 local cleanup_command="${4:-}"
 local retry_count=0

 echo "DEBUG: Executing file operation with retry logic: ${operation_command}" >&2

 while [[ ${retry_count} -lt ${max_retries} ]]; do
  if eval "${operation_command}"; then
   echo "DEBUG: File operation succeeded on attempt $((retry_count + 1))" >&2
   return 0
  fi

  retry_count=$((retry_count + 1))

  if [[ ${retry_count} -lt ${max_retries} ]]; then
   echo "WARNING: File operation failed on attempt ${retry_count}, retrying in ${base_delay}s" >&2
   sleep "${base_delay}"
  fi
 done

 # If cleanup command is provided, execute it
 if [[ -n "${cleanup_command}" ]]; then
  echo "WARNING: Executing cleanup command due to file operation failure" >&2
  if eval "${cleanup_command}"; then
   echo "DEBUG: Cleanup executed successfully" >&2
  else
   echo "ERROR: Cleanup failed" >&2
  fi
 fi

 echo "ERROR: File operation failed after ${max_retries} attempts" >&2
 return 1
}
