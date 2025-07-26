#!/bin/bash

# This script is designed to be sourced from other scripts. It contains functions
# used across different scripts in the project.
#
# This script uses the constant ERROR_LOGGER_UTILITY.
#
# For contributing, please execute these commands before submitting:
# * shellcheck -x -o all functionsProcess.sh
# * shfmt -w -i 1 -sr -bn functionsProcess.sh
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-25

# Error codes.
# 1: Help message.
# shellcheck disable=SC2034
declare -r ERROR_HELP_MESSAGE=1
# 238: Previous execution failed.
declare -r ERROR_PREVIOUS_EXECUTION_FAILED=238
# 239: Error creating report.
declare -r ERROR_CREATING_REPORT=239
# 241: Library or utility missing.
declare -r ERROR_MISSING_LIBRARY=241
# 242: Invalid argument for script invocation.
# shellcheck disable=SC2034
declare -r ERROR_INVALID_ARGUMENT=242
# 243: Logger utility is not available.
declare -r ERROR_LOGGER_UTILITY=243
# 244: The list of IDs for boundary geometries cannot be downloaded.
declare -r ERROR_DOWNLOADING_BOUNDARY_ID_LIST=244
# 245: No last update.
declare -r ERROR_NO_LAST_UPDATE=245
# 246: Planet process is currently running.
declare -r ERROR_PLANET_PROCESS_IS_RUNNING=246
# 247: Error downloading planet notes file.
declare -r ERROR_DOWNLOADING_NOTES=247
# 248: Error executing the Planet dump.
declare -r ERROR_EXECUTING_PLANET_DUMP=248
# 249: Error downloading boundary.
declare -r ERROR_DOWNLOADING_BOUNDARY=249
# 250: Error converting OSM JSON to GeoJSON.
declare -r ERROR_GEOJSON_CONVERSION=250
# 251: Internet issue.
declare -r ERROR_INTERNET_ISSUE=251
# 255: General error.
declare -r ERROR_GENERAL=255

# Flag to generate file for failed execution.
declare GENERATE_FAILED_FILE=true
# Previous execution failed file path.
# shellcheck disable=SC2154
declare -r FAILED_EXECUTION_FILE="/tmp/${BASENAME}_failed"

# Flag to track if prerequisites have been checked in current execution
declare PREREQS_CHECKED=false

# File that contains the IDs of the boundaries for countries.
# shellcheck disable=SC2154
declare -r COUNTRIES_BOUNDARY_IDS_FILE="${TMP_DIR}/countries"
# File that contains the IDs of the boundaries of the maritime areas.
# shellcheck disable=SC2154
declare -r MARITIME_BOUNDARY_IDS_FILE="${TMP_DIR}/maritimes"
# File for the Overpass query.
declare OVERPASS_QUERY_FILE="${TMP_DIR}/query"

# Logger framework.
# Taken from https://github.com/DushyanthJyothi/bash-logger.
# shellcheck disable=SC2154
declare -r LOGGER_UTILITY="${SCRIPT_BASE_DIRECTORY}/lib/bash_logger.sh"

# XSLT transformation files for Planet format.
declare -r XSLT_NOTES_PLANET_FILE="${SCRIPT_BASE_DIRECTORY}/xslt/notes-Planet-csv.xslt"
declare -r XSLT_NOTE_COMMENTS_PLANET_FILE="${SCRIPT_BASE_DIRECTORY}/xslt/note_comments-Planet-csv.xslt"
declare -r XSLT_TEXT_COMMENTS_PLANET_FILE="${SCRIPT_BASE_DIRECTORY}/xslt/note_comments_text-Planet-csv.xslt"
# XML Schema of the Planet notes file.
declare -r XMLSCHEMA_PLANET_NOTES="${SCRIPT_BASE_DIRECTORY}/xsd/OSM-notes-planet-schema.xsd"

# JSON schema files for validation.
declare -r JSON_SCHEMA_OVERPASS="${SCRIPT_BASE_DIRECTORY}/json/osm-jsonschema.json"
declare -r JSON_SCHEMA_GEOJSON="${SCRIPT_BASE_DIRECTORY}/json/geojsonschema.json"

# Output CSV files for processed data.
declare -r OUTPUT_NOTES_CSV_FILE="${TMP_DIR}/output-notes.csv"
declare -r OUTPUT_NOTE_COMMENTS_CSV_FILE="${TMP_DIR}/output-note_comments.csv"
declare -r OUTPUT_TEXT_COMMENTS_CSV_FILE="${TMP_DIR}/output-text_comments.csv"

# PostgreSQL SQL script files.
# Check base tables.
declare -r POSTGRES_11_CHECK_BASE_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_11_checkBaseTables.sql"
# Drop generic objects.
declare -r POSTGRES_12_DROP_GENERIC_OBJECTS="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_12_dropGenericObjects.sql"
# Create get country function.
declare -r POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_21_createFunctionToGetCountry.sql"
# Create insert note procedure.
declare -r POSTGRES_22_CREATE_PROC_INSERT_NOTE="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_22_createProcedure_insertNote.sql"
# Create insert note comment procedure.
declare -r POSTGRES_23_CREATE_PROC_INSERT_NOTE_COMMENT="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_23_createProcedure_insertNoteComment.sql"
# Organize areas.
declare -r POSTGRES_31_ORGANIZE_AREAS="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_31_organizeAreas.sql"
# Upload note locations.
declare -r POSTGRES_32_UPLOAD_NOTE_LOCATION="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_32_loadsBackupNoteLocation.sql"

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
  # shellcheck source=../lib/bash_logger.sh
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
 trap '{ printf "%s ERROR: The script ${BASENAME:-} did not finish correctly. Directory "${TMP_DIR:-}" - Line number: %d%s.\n" "$(date +%Y%m%d_%H:%M:%S)" "${LINENO}" "$(__validation)"; exit ${ERROR_GENERAL};}' \
  ERR
 trap '{ printf "%s WARN: The script ${BASENAME:-} was terminated.\n" "$(date +%Y%m%d_%H:%M:%S)"; exit ${ERROR_GENERAL};}' \
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
   "${PROCESS_FUNCTION}" "${XML_PART}" >> "${LOG_FILENAME}.${BASHPID}" 2>&1
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
 PART_NUM=$(echo "${BASENAME_PART}" | sed 's/part_//')

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
 PART_NUM=$(echo "${BASENAME_PART}" | sed 's/part_//')

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
 if [[ ! -r "${XSLT_NOTES_FILE}" ]]; then
  __loge "ERROR: File is missing at ${XSLT_NOTES_FILE}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${XSLT_NOTE_COMMENTS_FILE}" ]]; then
  __loge "ERROR: File is missing at ${XSLT_NOTE_COMMENTS_FILE}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${XSLT_TEXT_COMMENTS_FILE}" ]]; then
  __loge "ERROR: File is missing at ${XSLT_TEXT_COMMENTS_FILE}."
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
 # Download Planet notes.
 __logw "Retrieving Planet notes file..."
 # shellcheck disable=SC2154
 aria2c -d "${TMP_DIR}" -o "${PLANET_NOTES_NAME}.bz2" -x 8 \
  "${PLANET}/notes/${PLANET_NOTES_NAME}.bz2"
 # shellcheck disable=SC2154
 wget -O "${PLANET_NOTES_FILE}.bz2.md5" \
  "${PLANET}/notes/${PLANET_NOTES_NAME}.bz2.md5"
 # Validates the download with the hash value md5.
 diff <(md5sum "${PLANET_NOTES_FILE}.bz2" | cut -d' ' -f 1 || true) \
  <(cut -d' ' -f 1 "${PLANET_NOTES_FILE}.bz2.md5" || true)
 # If there is a difference, if will return non-zero value and fail the script.

 rm "${PLANET_NOTES_FILE}.bz2.md5"

 if [[ ! -r "${PLANET_NOTES_FILE}.bz2" ]]; then
  __loge "ERROR: Downloading notes file."
  # shellcheck disable=SC2154
  exit "${ERROR_DOWNLOADING_NOTES}"
 fi
 __logi "Extracting Planet notes..."
 bzip2 -d "${PLANET_NOTES_FILE}.bz2"
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
 set +e
 __logi "Retrieving shape ${ID}."
 RETRY=true
 while [[ "${RETRY}" = true ]]; do
  # Retrieves the JSON from Overpass.
  # shellcheck disable=SC2154
  wget -O "${JSON_FILE}" --post-file="${QUERY_FILE}" \
   "${OVERPASS_INTERPRETER}" 2> "${OUTPUT_OVERPASS}"
  RET="${?}"
  cat "${OUTPUT_OVERPASS}"
  MANY_REQUESTS=$(grep -c "ERROR 429: Too Many Requests." "${OUTPUT_OVERPASS}")
  if [[ "${MANY_REQUESTS}" -ne 0 ]]; then
   # If "too many requests" as part of the output, then waits.
   # shellcheck disable=SC2154
   __logw "Waiting ${SECONDS_TO_WAIT} seconds because too many requests."
   sleep "${SECONDS_TO_WAIT}"
  elif [[ "${RET}" -ne 0 ]]; then
   # Retry once if there was an error.
   set -e
  else
   # Validates the JSON with a JSON schema.
   set +e
   ajv validate -s "${JSON_SCHEMA_OVERPASS}" -d "${JSON_FILE}" \
    --spec=draft2020 2> /dev/null
   echo "${RET}"
   set -e
   if [[ "${RET}" -eq 0 ]]; then
    # The format is valid.
    __logd "The JSON file ${JSON_FILE} is valid."
    RETRY=false
   else
    __logd "The JSON file ${JSON_FILE} is invalid; retrying."
   fi
  fi
 done
 rm -f "${OUTPUT_OVERPASS}"
 set -e

 # Validate the GeoJSON with a JSON schema
 __logi "Converting into GeoJSON."
 osmtogeojson "${JSON_FILE}" > "${GEOJSON_FILE}"
 set +e
 ajv validate -s "${JSON_SCHEMA_GEOJSON}" -d "${JSON_FILE}" \
  --spec=draft2020 2> /dev/null
 echo "${RET}"
 set -e
 if [[ "${RET}" -ne 0 ]]; then
  __loge "The GeoJSON file ${JSON_FILE} is invalid; failing."
  exit "${ERROR_GEOJSON_CONVERSION}"
 fi

 set +o pipefail
 NAME=$(grep "\"name\":" "${GEOJSON_FILE}" | head -1 \
  | awk -F\" '{print $4}' | sed "s/'/''/")
 NAME_ES=$(grep "\"name:es\":" "${GEOJSON_FILE}" | head -1 \
  | awk -F\" '{print $4}' | sed "s/'/''/")
 NAME_EN=$(grep "\"name:en\":" "${GEOJSON_FILE}" | head -1 \
  | awk -F\" '{print $4}' | sed "s/'/''/")
 set -o pipefail
 set -e
 NAME_EN="${NAME_EN:-No English name}"
 __logi "Name: ${NAME_EN:-}."

 # Taiwan cannot be imported directly. Thus, a simplification is done.
 # ERROR:  row is too big: size 8616, maximum size 8160
 grep -v "official_name" "${GEOJSON_FILE}" \
  | grep -v "alt_name" > "${GEOJSON_FILE}-new"
 mv "${GEOJSON_FILE}-new" "${GEOJSON_FILE}"

 __logi "Importing into Postgres."
 set +e
 mkdir "${LOCK_OGR2OGR}" 2> /dev/null
 RET="${?}"
 set -e
 while [[ "${RET}" -ne 0 ]]; do
  set +e
  LOCK_ID=$(cat "${LOCK_OGR2OGR}"/pid)
  set -e
  __logd "${PROCESS} waiting for the lock. Current owner ${LOCK_ID}."
  sleep 2
  set +e
  mkdir "${LOCK_OGR2OGR}" 2> /dev/null
  RET="${?}"
  set -e
 done
 echo "${PROCESS}" > "${LOCK_OGR2OGR}"/pid
 __logi "Acquired lock ${PROCESS} - ${ID}."
 ogr2ogr -f "PostgreSQL" PG:"dbname=${DBNAME} user=${DB_USER}" \
  "${GEOJSON_FILE}" -nln import -overwrite
 # If an error like this appears:
 # ERROR:  column "name:xx-XX" specified more than once
 # It means two of the objects of the country has a name for the same
 # language, but with different case. The current solution is to open
 # the JSON file, look for the language, and modify the parts to have the
 # same case. Or modify the objects in OSM.
 STATEMENT="SELECT COUNT(1) FROM countries
   WHERE country_id = ${ID}"
 COUNTRY_QTY=$(echo "${STATEMENT}" | psql -d "${DBNAME}" -t -v ON_ERROR_STOP=1)
 if [[ "${COUNTRY_QTY}" -eq 0 ]]; then
  __logi "Inserting into final table."
  if [[ "${ID}" -ne 16239 ]]; then
   STATEMENT="INSERT INTO countries (country_id, country_name, country_name_es,
     country_name_en, geom)
     SELECT ${ID}, '${NAME}', '${NAME_ES}', '${NAME_EN}',
      ST_Union(ST_makeValid(wkb_geometry))
     FROM import
     GROUP BY 1"
  else # This case is for Austria.
   # GEOSUnaryUnion: TopologyException: Input geom 1 is invalid:
   # Self-intersection at or near point 10.454439900000001 47.555796399999998
   # at 10.454439900000001 47.555796399999998
   STATEMENT="INSERT INTO countries (country_id, country_name, country_name_es,
     country_name_en, geom)
     SELECT ${ID}, '${NAME}', '${NAME_ES}', '${NAME_EN}',
      ST_Union(ST_Buffer(wkb_geometry, 0.0))
     FROM import
     GROUP BY 1"
  fi
 elif [[ "${COUNTRY_QTY}" -eq 1 ]]; then
  if [[ "${ID}" -ne 16239 ]]; then
   STATEMENT="UPDATE countries AS c
    SET country_name = '${NAME}', country_name_es = '${NAME_ES}',
    country_name_en = '${NAME_EN}',
    geom = (
     SELECT geom FROM (
      SELECT ${ID}, ST_Union(ST_makeValid(wkb_geometry)) geom
      FROM import GROUP BY 1
     ) AS t
    ),
    updated = true
    WHERE country_id = ${ID}"
  else # This case is for Austria.
   # GEOSUnaryUnion: TopologyException: Input geom 1 is invalid:
   # Self-intersection at or near point 10.454439900000001 47.555796399999998
   # at 10.454439900000001 47.555796399999998
   STATEMENT="UPDATE countries AS c
    SET country_name = '${NAME}', country_name_es = '${NAME_ES}',
    country_name_en = '${NAME_EN}',
    geom = (
     SELECT geom FROM (
      SELECT ${ID}, ST_Union(ST_Buffer(wkb_geometry, 0.0))
      FROM import GROUP BY 1
     ) AS t
    ),
    updated = true
    FROM import AS i
    WHERE country_id = ${ID}"
  fi
 fi
 __logt "${STATEMENT}"
 echo "${STATEMENT}" | psql -d "${DBNAME}" -v ON_ERROR_STOP=1
 unset NAME
 unset NAME_ES
 unset NAME_EN

 __logi "Released lock ${PROCESS} - ${ID}."
 rm -f "${LOCK_OGR2OGR}/pid"
 rmdir "${LOCK_OGR2OGR}/"

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
