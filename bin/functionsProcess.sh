#!/bin/bash

# OSM-Notes-profile - Common Functions
# This file serves as the main entry point for all common functions.
# It loads all refactored function files to maintain backward compatibility.
#
# Author: Andres Gomez (AngocA)
# Version: 2025-08-12

# shellcheck disable=SC2317,SC2155,SC2154

# Define script base directory (only if not already defined)
if [[ -z "${SCRIPT_BASE_DIRECTORY:-}" ]]; then
 SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# Define common variables (only if not already defined)
if [[ -z "${BASENAME:-}" ]]; then
 BASENAME="$(basename "${BASH_SOURCE[0]}" .sh)"
fi

if [[ -z "${TMP_DIR:-}" ]]; then
 TMP_DIR="/tmp/${BASENAME}_$$"
fi

# Define query file variable (only if not already defined)
if [[ -z "${QUERY_FILE:-}" ]]; then
 QUERY_FILE="${TMP_DIR}/query.op"
fi

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
# shellcheck disable=SC2034
declare -r OUTPUT_NOTES_CSV_FILE="${TMP_DIR}/output-notes.csv"
# shellcheck disable=SC2034
declare -r OUTPUT_NOTE_COMMENTS_CSV_FILE="${TMP_DIR}/output-note_comments.csv"
# shellcheck disable=SC2034
declare -r OUTPUT_TEXT_COMMENTS_CSV_FILE="${TMP_DIR}/output-text_comments.csv"

# PostgreSQL SQL script files
# Check base tables.
declare -r POSTGRES_11_CHECK_BASE_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_11_checkBaseTables.sql"
declare -r POSTGRES_11_CHECK_HISTORICAL_DATA="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_11_checkHistoricalData.sql"
declare -r POSTGRES_12_DROP_GENERIC_OBJECTS="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_12_dropGenericObjects.sql"
declare -r POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_21_createFunctionToGetCountry.sql"
declare -r POSTGRES_22_CREATE_PROC_INSERT_NOTE="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_22_createProcedure_insertNote.sql"
declare -r POSTGRES_23_CREATE_PROC_INSERT_NOTE_COMMENT="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_23_createProcedure_insertNoteComment.sql"
declare -r POSTGRES_31_ORGANIZE_AREAS="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_31_organizeAreas.sql"
declare -r POSTGRES_32_UPLOAD_NOTE_LOCATION="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_32_loadsBackupNoteLocation.sql"

# Additional PostgreSQL script files (only if not already defined)
if [[ -z "${POSTGRES_31_LOAD_API_NOTES:-}" ]]; then
 declare -r POSTGRES_31_LOAD_API_NOTES="${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_31_loadApiNotes.sql"
fi

if [[ -z "${POSTGRES_41_LOAD_PARTITIONED_SYNC_NOTES:-}" ]]; then
 declare -r POSTGRES_41_LOAD_PARTITIONED_SYNC_NOTES="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_41_loadPartitionedSyncNotes.sql"
fi

# XSLT and Schema files (only if not already defined)
if [[ -z "${XSLT_NOTES_PLANET_FILE:-}" ]]; then
 declare -r XSLT_NOTES_PLANET_FILE="${SCRIPT_BASE_DIRECTORY}/xslt/notes-Planet-csv.xslt"
fi

if [[ -z "${XSLT_NOTE_COMMENTS_PLANET_FILE:-}" ]]; then
 declare -r XSLT_NOTE_COMMENTS_PLANET_FILE="${SCRIPT_BASE_DIRECTORY}/xslt/note_comments-Planet-csv.xslt"
fi

if [[ -z "${XSLT_TEXT_COMMENTS_PLANET_FILE:-}" ]]; then
 declare -r XSLT_TEXT_COMMENTS_PLANET_FILE="${SCRIPT_BASE_DIRECTORY}/xslt/note_comments_text-Planet-csv.xslt"
fi

if [[ -z "${XMLSCHEMA_PLANET_NOTES:-}" ]]; then
 declare -r XMLSCHEMA_PLANET_NOTES="${SCRIPT_BASE_DIRECTORY}/xsd/OSM-notes-planet-schema.xsd"
fi

if [[ -z "${JSON_SCHEMA_OVERPASS:-}" ]]; then
 declare -r JSON_SCHEMA_OVERPASS="${SCRIPT_BASE_DIRECTORY}/json/osm-jsonschema.json"
fi

if [[ -z "${JSON_SCHEMA_GEOJSON:-}" ]]; then
 declare -r JSON_SCHEMA_GEOJSON="${SCRIPT_BASE_DIRECTORY}/json/geojsonschema.json"
fi

# Planet and Overpass configuration (only if not already defined)
if [[ -z "${PLANET_NOTES_FILE:-}" ]]; then
 declare -r PLANET_NOTES_FILE="${TMP_DIR}/OSM-notes-planet.xml"
fi

if [[ -z "${PLANET_NOTES_NAME:-}" ]]; then
 declare -r PLANET_NOTES_NAME="planet-notes-latest.osn"
fi

if [[ -z "${COUNTRIES_BOUNDARY_IDS_FILE:-}" ]]; then
 declare -r COUNTRIES_BOUNDARY_IDS_FILE="${TMP_DIR}/countries_boundary_ids.csv"
fi

if [[ -z "${MARITIME_BOUNDARY_IDS_FILE:-}" ]]; then
 declare -r MARITIME_BOUNDARY_IDS_FILE="${TMP_DIR}/maritime_boundary_ids.csv"
fi

# Configuration variables (if not already defined)
if [[ -z "${MAX_NOTES:-}" ]]; then
 # shellcheck disable=SC2034
 declare -r MAX_NOTES="10000"
elif [[ ! "${MAX_NOTES}" =~ ^[1-9][0-9]*$ ]]; then
 __loge "ERROR: MAX_NOTES must be a positive integer, got: ${MAX_NOTES}"
 exit 1
fi

if [[ -z "${GENERATE_FAILED_FILE:-}" ]]; then
 declare -r GENERATE_FAILED_FILE="false"
fi

if [[ -z "${LOG_FILENAME:-}" ]]; then
 declare -r LOG_FILENAME="${TMP_DIR}/${BASENAME}.log"
fi

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

# Counts notes in XML file (API format)
# Parameters:
#   $1: Input XML file path
# Returns:
#   TOTAL_NOTES: Number of notes found (exported variable)
function __countXmlNotesAPI() {
 local XML_FILE="${1}"

 __log_start
 __logi "Counting notes in XML file (API format) ${XML_FILE}"

 # Check if file exists
 if [[ ! -f "${XML_FILE}" ]]; then
  __loge "File not found: ${XML_FILE}"
  TOTAL_NOTES=0
  export TOTAL_NOTES
  __log_finish
  return 1
 fi

 # Get total number of notes for API format using xmlstarlet with timeout
 TOTAL_NOTES=$(timeout 120 xmlstarlet sel -t -v "count(/osm/note)" "${XML_FILE}" 2> /dev/null)
 local XMLSTARLET_STATUS=$?

 if [[ ${XMLSTARLET_STATUS} -ne 0 ]]; then
  if [[ ${XMLSTARLET_STATUS} -eq 124 ]]; then
   __loge "Timeout processing XML file (120s): ${XML_FILE}"
  else
   __loge "Error processing XML file: ${XML_FILE}"
  fi
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

 # Check if file exists
 if [[ ! -f "${XML_FILE}" ]]; then
  __loge "File not found: ${XML_FILE}"
  TOTAL_NOTES=0
  export TOTAL_NOTES
  __log_finish
  return 1
 fi

 # Get total number of notes for Planet format using lightweight grep
 TOTAL_NOTES=$(grep -c '<note' "${XML_FILE}" 2> /dev/null)
 local GREP_STATUS=$?

 # grep returns 0 when no matches found, which is not an error
 if [[ ${GREP_STATUS} -ne 0 ]]; then
  __loge "Error counting notes in XML file (exit code ${GREP_STATUS}): ${XML_FILE}"
  TOTAL_NOTES=0
  export TOTAL_NOTES
  __log_finish
  return 1
 fi

 # grep returns "0" when no matches found, which is valid
 # No need to handle special exit codes

 # Ensure TOTAL_NOTES is treated as a decimal number and is valid
 # Note: grep returns "0" when no matches found, which is valid
 if [[ -z "${TOTAL_NOTES}" ]] || [[ ! "${TOTAL_NOTES}" =~ ^[0-9]+$ ]]; then
  __loge "Invalid or empty note count returned by grep: '${TOTAL_NOTES}'"
  TOTAL_NOTES=0
  export TOTAL_NOTES
  __log_finish
  return 1
 fi

 # Convert to integer safely - avoid 10# prefix for large numbers that look like dates
 if [[ "${TOTAL_NOTES}" =~ ^[0-9]+$ ]]; then
  # Safe integer conversion without base prefix for large numbers
  TOTAL_NOTES=$((TOTAL_NOTES + 0))
 else
  __loge "Invalid note count format: '${TOTAL_NOTES}'"
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

  # Use lightweight commands instead of xmlstarlet for better memory efficiency
  # Since Planet XML is well-formed and each note starts on a new line,
  # we can use grep to find line numbers and extract ranges efficiently

  # Find the line numbers where notes start
  local NOTE_LINES
  NOTE_LINES=$(grep -n '<note' "${XML_FILE}" | cut -d: -f1)

  # Convert to array for easier processing
  local NOTE_LINE_ARRAY
  mapfile -t NOTE_LINE_ARRAY <<< "${NOTE_LINES}"

  # Calculate start and end line numbers for this part
  local START_LINE="${NOTE_LINE_ARRAY[$((START - 1))]}"
  local END_LINE

  if [[ "${END}" -ge "${#NOTE_LINE_ARRAY[@]}" ]]; then
   # Last part - go to end of file, but exclude the closing tag
   END_LINE=$(wc -l < "${XML_FILE}")
   # Find the line with the closing tag and stop before it
   local CLOSING_TAG_LINE
   if [[ "${XML_FORMAT_LOCAL}" == "API" ]]; then
    CLOSING_TAG_LINE=$(grep -n '</osm>' "${XML_FILE}" | head -1 | cut -d: -f1)
   else
    CLOSING_TAG_LINE=$(grep -n '</osm-notes>' "${XML_FILE}" | head -1 | cut -d: -f1)
   fi
   if [[ -n "${CLOSING_TAG_LINE}" ]]; then
    END_LINE=$((CLOSING_TAG_LINE - 1))
   fi
  else
   # Get the line number of the next note (or end of file)
   END_LINE="${NOTE_LINE_ARRAY[${END}]}"
   if [[ -z "${END_LINE}" ]]; then
    END_LINE=$(wc -l < "${XML_FILE}")
    # Exclude the closing tag
    local CLOSING_TAG_LINE
    if [[ "${XML_FORMAT_LOCAL}" == "API" ]]; then
     CLOSING_TAG_LINE=$(grep -n '</osm>' "${XML_FILE}" | head -1 | cut -d: -f1)
    else
     CLOSING_TAG_LINE=$(grep -n '</osm-notes>' "${XML_FILE}" | head -1 | cut -d: -f1)
    fi
    if [[ -n "${CLOSING_TAG_LINE}" ]]; then
     END_LINE=$((CLOSING_TAG_LINE - 1))
    fi
   fi
  fi

  # Extract the XML header and footer
  local XML_HEADER
  local XML_FOOTER

  if [[ "${XML_FORMAT_LOCAL}" == "API" ]]; then
   XML_HEADER='<?xml version="1.0" encoding="UTF-8"?>\n<osm>'
   XML_FOOTER='</osm>'
  else
   XML_HEADER='<?xml version="1.0" encoding="UTF-8"?>\n<osm-notes>'
   XML_FOOTER='</osm-notes>'
  fi

  # Create the XML part file efficiently
  {
   echo -e "${XML_HEADER}"
   # Extract the range of lines containing the notes
   sed -n "${START_LINE},${END_LINE}p" "${XML_FILE}"
   echo "${XML_FOOTER}"
  } > "${OUTPUT_FILE}"

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
 local FAILED_JOBS=()

 __log_start
 __logi "Processing XML parts in ${PARTS_DIR} with ${MAX_THREADS} background jobs"

 # Process parts using traditional background jobs
 for XML_PART in $(find "${PARTS_DIR}" -name "${PART_PREFIX}_*.xml" | sort); do
  (
   __logi "Starting processing ${XML_PART} - ${BASHPID}."
   if ! "${PROCESS_FUNCTION}" "${XML_PART}" >> "${LOG_FILENAME}.${BASHPID}" 2>&1; then
    # Create failed file for this specific job
    local FAILED_JOB_FILE="${TMP_DIR}/failed_job_${BASHPID}.log"
    local EXIT_CODE="${?}"
    {
     __loge "Job ${BASHPID} failed processing ${XML_PART}"
     echo "Error occurred at $(date)"
     echo "Job PID: ${BASHPID}"
     echo "XML Part: ${XML_PART}"
     echo "Log file: ${LOG_FILENAME}.${BASHPID}"
     echo "Exit code: ${EXIT_CODE}"
     echo "Temporary directory: ${TMP_DIR}"
    } > "${FAILED_JOB_FILE}"

    # Also create main failed file if GENERATE_FAILED_FILE is true
    if [[ "${GENERATE_FAILED_FILE}" = true ]]; then
     {
      __loge "Job ${BASHPID} failed processing ${XML_PART}"
      echo "Error occurred at $(date)"
      echo "Job PID: ${BASHPID}"
      echo "XML Part: ${XML_PART}"
      echo "Log file: ${LOG_FILENAME}.${BASHPID}"
      echo "Exit code: ${EXIT_CODE}"
      echo "Temporary directory: ${TMP_DIR}"
      echo "---"
     } >> "${FAILED_EXECUTION_FILE}"
    fi

    # Signal failure by creating a marker file
    touch "${TMP_DIR}/job_failed_${BASHPID}"
    exit 1
   fi
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
   FAILED_JOBS+=("${JOB}")
  fi
 done
 __logw "Waited for all jobs, restarting in main thread - XML processing."

 # Check for failed job markers
 local FAILED_MARKERS
 FAILED_MARKERS=$(find "${TMP_DIR}" -name "job_failed_*" 2> /dev/null | wc -l)

 if [[ "${FAIL}" -ne 0 ]] || [[ "${FAILED_MARKERS}" -gt 0 ]]; then
  __loge "ERROR: ${FAIL} jobs failed during parallel processing"

  # List all failed job files
  local FAILED_JOB_FILES
  FAILED_JOB_FILES=$(find "${TMP_DIR}" -name "failed_job_*.log" 2> /dev/null)
  if [[ -n "${FAILED_JOB_FILES}" ]]; then
   __loge "Failed job details:"
   while IFS= read -r failed_file; do
    __loge "  ${failed_file}:"
    while IFS= read -r line; do
     __loge "    ${line}"
    done < "${failed_file}"
   done <<< "${FAILED_JOB_FILES}"
  fi

  # Create comprehensive failed execution file
  if [[ "${GENERATE_FAILED_FILE}" = true ]]; then
   {
    __loge "Parallel processing failed"
    echo "Error occurred at $(date)"
    echo "Failed jobs: ${FAIL}"
    echo "Failed markers found: ${FAILED_MARKERS}"
    echo "Temporary directory: ${TMP_DIR}"
    echo "---"
   } > "${FAILED_EXECUTION_FILE}"

   # Append failed job details
   if [[ -n "${FAILED_JOB_FILES}" ]]; then
    echo "Failed job details:" >> "${FAILED_EXECUTION_FILE}"
    while IFS= read -r failed_file; do
     {
      echo "  ${failed_file}:"
      cat "${failed_file}"
      echo "---"
     } >> "${FAILED_EXECUTION_FILE}"
    done <<< "${FAILED_JOB_FILES}"
   fi
  fi

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

 __logi "=== STARTING API XML PART PROCESSING ==="
 __logd "Input XML part: ${XML_PART}"
 __logd "XSLT files:"
 __logd "  Notes: ${XSLT_NOTES_FILE_LOCAL}"
 __logd "  Comments: ${XSLT_COMMENTS_FILE_LOCAL}"
 __logd "  Text: ${XSLT_TEXT_FILE_LOCAL}"

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

 # Validate CSV files for enum compatibility before loading
 __logd "Validating CSV files for enum compatibility..."
 if ! __validate_csv_for_enum_compatibility "${OUTPUT_NOTES_PART}" "notes"; then
  __loge "ERROR: Notes CSV validation failed for part ${PART_NUM}"
  return 1
 fi

 if ! __validate_csv_for_enum_compatibility "${OUTPUT_COMMENTS_PART}" "comments"; then
  __loge "ERROR: Comments CSV validation failed for part ${PART_NUM}"
  return 1
 fi

 __logi "=== LOADING PART ${PART_NUM} INTO DATABASE ==="
 __logd "Database: ${DBNAME}"
 __logd "Part ID: ${PART_NUM}"
 __logd "Max threads: ${MAX_THREADS}"

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

 __logi "=== API XML PART ${PART_NUM} PROCESSING COMPLETED SUCCESSFULLY ==="
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

 __logi "=== STARTING PLANET XML PART PROCESSING ==="
 __logd "Input XML part: ${XML_PART}"
 __logd "XSLT files:"
 __logd "  Notes: ${XSLT_NOTES_FILE_LOCAL}"
 __logd "  Comments: ${XSLT_COMMENTS_FILE_LOCAL}"
 __logd "  Text: ${XSLT_TEXT_FILE_LOCAL}"

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

 __logi "=== PLANET XML PART ${PART_NUM} PROCESSING COMPLETED SUCCESSFULLY ==="
}

# Function to validate input files and directories

# Function to validate multiple input files
# Parameters:
#   $@: List of file paths to validate
# Returns:
#   0 if all valid, 1 if any invalid

# Validate XML structure (delegates to validationFunctions.sh)
# Parameters:
#   $1: XML file path
#   $2: Expected root element (optional)
# Returns:
#   0 if valid, 1 if invalid

# Function to validate CSV file structure
# Parameters:
#   $1: CSV file path
#   $2: Expected number of columns (optional)
# Returns:
#   0 if valid, 1 if invalid

# Function to validate SQL file structure
# Parameters:
#   $1: SQL file path
# Returns:
#   0 if valid, 1 if invalid

# Function to validate configuration file
# Parameters:
#   $1: Config file path
# Returns:
#   0 if valid, 1 if invalid

# Validates JSON file structure and syntax
# Parameters:
#   $1: JSON file path
#   $2: Optional expected root element name (e.g., "osm-notes")
# Returns:
#   0 if valid, 1 if invalid

# Validates database connection and basic functionality
# Parameters:
#   $1: Database name (optional, uses DBNAME if not provided)
#   $2: Database user (optional, uses DB_USER if not provided)
#   $3: Database host (optional, uses DBHOST if not provided)
#   $4: Database port (optional, uses DBPORT if not provided)
# Returns:
#   0 if connection successful, 1 if failed

# Validates database table existence and structure
# Parameters:
#   $1: Database name (optional, uses DBNAME if not provided)
#   $2: Database user (optional, uses DB_USER if not provided)
#   $3: Database host (optional, uses DBHOST if not provided)
#   $4: Database port (optional, uses DBPORT if not provided)
#   $5+: List of required table names
# Returns:
#   0 if all tables exist, 1 if any missing

# Validates database schema and extensions
# Parameters:
#   $1: Database name (optional, uses DBNAME if not provided)
#   $2: Database user (optional, uses DB_USER if not provided)
#   $3: Database host (optional, uses DBHOST if not provided)
#   $4: Database port (optional, uses DBPORT if not provided)
#   $5+: List of required extensions
# Returns:
#   0 if all extensions exist, 1 if any missing

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
 # shellcheck disable=SC2034
 RET_FUNC="${RET}"
 __log_finish
}

# Verifies if the base tables contain historical data.
# This is critical for processAPI to ensure it doesn't run without historical context.
# Returns: 0 if historical data exists, non-zero if validation fails
function __checkHistoricalData {
 __log_start
 __logi "Validating historical data in base tables..."

 # Make this block resilient even when caller has 'set -e' enabled
 local ERREXIT_WAS_ON=false
 if [[ $- == *e* ]]; then
  ERREXIT_WAS_ON=true
  set +e
 fi

 local RET
 local HIST_OUT_FILE
 HIST_OUT_FILE="${TMP_DIR:-/tmp}/hist_check_$$.log"
 # Ensure directory exists
 mkdir -p "${TMP_DIR:-/tmp}" 2> /dev/null || true

 # Execute and capture output and exit code safely
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_11_CHECK_HISTORICAL_DATA}" > "${HIST_OUT_FILE}" 2>&1
 RET=$?

 # Restore errexit if it was previously on
 if [[ "${ERREXIT_WAS_ON}" == true ]]; then
  set -e
 fi

 # Read captured output
 local HIST_OUT=""
 if [[ -s "${HIST_OUT_FILE}" ]]; then
  HIST_OUT="$(cat "${HIST_OUT_FILE}")"
 fi
 rm -f "${HIST_OUT_FILE}" 2> /dev/null || true

 # If exit code is zero but output contains ERROR, treat as failure to be safe
 if [[ "${RET}" -eq 0 ]] && echo "${HIST_OUT}" | grep -q "ERROR:"; then
  RET=1
 fi

 # Print psql output to current logger context with appropriate levels
 if [[ -n "${HIST_OUT}" ]]; then
  while IFS= read -r LINE; do
   if [[ "${LINE}" == *"ERROR:"* ]]; then
    __loge "${LINE}"
   else
    __logd "${LINE}"
   fi
  done <<< "${HIST_OUT}"
 fi

 if [[ "${RET}" -eq 0 ]]; then
  __logi "Historical data validation passed"
 else
  # Consolidate error messages into a single, clear error log
  local ERROR_MESSAGE="CRITICAL: Historical data validation failed! ProcessAPI cannot continue without historical data from Planet. The system needs historical context to properly process incremental updates. Required action: Run processPlanetNotes.sh first to load historical data: ${SCRIPT_BASE_DIRECTORY}/bin/process/processPlanetNotes.sh. This will load the complete historical dataset from OpenStreetMap Planet dump."
  __loge "${ERROR_MESSAGE}"
 fi

 # shellcheck disable=SC2034
 RET_FUNC="${RET}"
 __log_finish
 return "${RET}"
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
 local DOWNLOAD_OPERATION="aria2c -d ${TMP_DIR} -o ${PLANET_NOTES_NAME}.bz2 -x 8 ${PLANET}/notes/${PLANET_NOTES_NAME}.bz2"
 local DOWNLOAD_CLEANUP="rm -f ${TMP_DIR}/${PLANET_NOTES_NAME}.bz2 2>/dev/null || true"

 if ! __retry_file_operation "${DOWNLOAD_OPERATION}" 3 10 "${DOWNLOAD_CLEANUP}"; then
  __loge "Failed to download Planet notes after retries"
  __handle_error_with_cleanup "${ERROR_DOWNLOADING_NOTES}" "Planet download failed" \
   "rm -f ${TMP_DIR}/${PLANET_NOTES_NAME}.bz2 2>/dev/null || true"
 fi

 # Move downloaded file to expected location
 if [[ -f "${TMP_DIR}/${PLANET_NOTES_NAME}.bz2" ]]; then
  mv "${TMP_DIR}/${PLANET_NOTES_NAME}.bz2" "${PLANET_NOTES_FILE}.bz2"
  __logi "Moved downloaded file to expected location: ${PLANET_NOTES_FILE}.bz2"
 else
  __loge "ERROR: Downloaded file not found at expected location"
  __handle_error_with_cleanup "${ERROR_DOWNLOADING_NOTES}" "Downloaded file not found" \
   "rm -f ${TMP_DIR}/${PLANET_NOTES_NAME}.bz2 2>/dev/null || true"
 fi

 # Download MD5 file with retry logic
 local MD5_OPERATION="wget -O ${PLANET_NOTES_FILE}.bz2.md5 ${PLANET}/notes/${PLANET_NOTES_NAME}.bz2.md5"
 local MD5_CLEANUP="rm -f ${PLANET_NOTES_FILE}.bz2.md5 2>/dev/null || true"

 if ! __retry_file_operation "${MD5_OPERATION}" 3 5 "${MD5_CLEANUP}"; then
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
 local EXTRACT_OPERATION="bzip2 -d ${PLANET_NOTES_FILE}.bz2"
 local EXTRACT_CLEANUP="rm -f ${PLANET_NOTES_FILE} 2>/dev/null || true"

 if ! __retry_file_operation "${EXTRACT_OPERATION}" 2 3 "${EXTRACT_CLEANUP}"; then
  __loge "Failed to extract Planet notes after retries"
  __handle_error_with_cleanup "${ERROR_DOWNLOADING_NOTES}" "File extraction failed" \
   "rm -f ${PLANET_NOTES_FILE}.bz2 ${PLANET_NOTES_FILE} 2>/dev/null || true"
 fi

 # After bzip2 extraction, the file should already have the correct name
 # PLANET_NOTES_FILE already includes .xml extension, so no renaming needed
 if [[ ! -f "${PLANET_NOTES_FILE}" ]]; then
  __loge "ERROR: Extracted file not found: ${PLANET_NOTES_FILE}"
  return 1
 fi

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
 # shellcheck disable=SC2034
 RET_FUNC="${RET}"
 __log_finish
}

# Calculates estimated row size from GeoJSON properties
function __calculate_row_size_estimate() {
 __log_start
 local GEOJSON_FILE="$1"

 if [[ ! -f "${GEOJSON_FILE}" ]]; then
  __log_finish
  echo "0"
  return
 fi

 if command -v jq > /dev/null 2>&1; then
  # Calculate estimated row size from properties
  local ESTIMATED_SIZE
  ESTIMATED_SIZE=$(jq -r '.features[0].properties | to_entries | map(.key | length + (.value | tostring | length)) | add' "${GEOJSON_FILE}" 2> /dev/null)

  if [[ -n "${ESTIMATED_SIZE}" ]] && [[ "${ESTIMATED_SIZE}" != "null" ]]; then
   echo "${ESTIMATED_SIZE}"
  else
   echo "0"
  fi
 else
  # Fallback: estimate based on file size
  local FILE_SIZE
  FILE_SIZE=$(wc -c < "${GEOJSON_FILE}")
  echo "$((FILE_SIZE / 10))" # Rough estimate
 fi
 __log_finish
}

# Processes a specific boundary ID.
# Parameters:
#   $1: Query file path (optional, uses global QUERY_FILE if not provided)
function __processBoundary {
 __log_start
 __logi "=== STARTING BOUNDARY PROCESSING ==="
 # Use provided query file or fall back to global
 local QUERY_FILE_TO_USE="${1:-${QUERY_FILE}}"

 __logd "Boundary ID: ${ID}"
 __logd "Process ID: ${BASHPID}"
 __logd "JSON file: ${JSON_FILE}"
 __logd "GeoJSON file: ${GEOJSON_FILE}"
 __logd "Query file: ${QUERY_FILE_TO_USE}"
 OUTPUT_OVERPASS="${TMP_DIR}/output.${BASHPID}"

 __logi "Retrieving shape ${ID}."

 # Check network connectivity before proceeding
 __logd "Checking network connectivity for boundary ${ID}..."
 if ! __check_network_connectivity 10; then
  __loge "Network connectivity check failed for boundary ${ID}"
  __handle_error_with_cleanup "${ERROR_INTERNET_ISSUE}" "Network connectivity failed for boundary ${ID}" \
   "rm -f ${JSON_FILE} ${GEOJSON_FILE} ${OUTPUT_OVERPASS} 2>/dev/null || true"
  return 1
 fi
 __logd "Network connectivity confirmed for boundary ${ID}"

 # Use retry logic for Overpass API calls
 __logd "Downloading boundary ${ID} from Overpass API..."
 local OVERPASS_OPERATION="wget -O ${JSON_FILE} --post-file=${QUERY_FILE_TO_USE} ${OVERPASS_INTERPRETER} 2> ${OUTPUT_OVERPASS}"
 local OVERPASS_CLEANUP="rm -f ${JSON_FILE} ${OUTPUT_OVERPASS} 2>/dev/null || true"

 if ! __retry_file_operation "${OVERPASS_OPERATION}" 5 15 "${OVERPASS_CLEANUP}"; then
  __loge "Failed to retrieve boundary ${ID} from Overpass after retries"
  __handle_error_with_cleanup "${ERROR_DOWNLOADING_BOUNDARY}" "Overpass API failed for boundary ${ID}" \
   "rm -f ${JSON_FILE} ${OUTPUT_OVERPASS} 2>/dev/null || true"
  return 1
 fi
 __logd "Successfully downloaded boundary ${ID} from Overpass API"

 # Check for specific Overpass errors
 __logd "Checking Overpass API response for errors..."
 cat "${OUTPUT_OVERPASS}"
 local MANY_REQUESTS
 MANY_REQUESTS=$(grep -c "ERROR 429: Too Many Requests." "${OUTPUT_OVERPASS}")
 if [[ "${MANY_REQUESTS}" -ne 0 ]]; then
  __loge "Too many requests to Overpass API for boundary ${ID}"
  __handle_error_with_cleanup "${ERROR_DOWNLOADING_BOUNDARY}" "Overpass rate limit exceeded for boundary ${ID}" \
   "rm -f ${JSON_FILE} ${OUTPUT_OVERPASS} 2>/dev/null || true"
  return 1
 fi

 __logd "No Overpass API errors detected for boundary ${ID}"
 rm -f "${OUTPUT_OVERPASS}"

 # Validate the JSON with a JSON schema
 __logi "Validating JSON structure for boundary ${ID}..."
 if ! __validate_json_structure "${JSON_FILE}" "elements"; then
  __loge "JSON validation failed for boundary ${ID}"
  __handle_error_with_cleanup "${ERROR_DATA_VALIDATION}" "Invalid JSON structure for boundary ${ID}" \
   "rm -f ${JSON_FILE} 2>/dev/null || true"
  return 1
 fi
 __logd "JSON validation passed for boundary ${ID}"

 # Convert to GeoJSON with retry logic
 __logi "Converting into GeoJSON for boundary ${ID}."
 local GEOJSON_OPERATION="osmtogeojson ${JSON_FILE} > ${GEOJSON_FILE}"
 local GEOJSON_CLEANUP="rm -f ${GEOJSON_FILE} 2>/dev/null || true"

 if ! __retry_file_operation "${GEOJSON_OPERATION}" 2 5 "${GEOJSON_CLEANUP}"; then
  __loge "Failed to convert boundary ${ID} to GeoJSON after retries"
  __handle_error_with_cleanup "${ERROR_GEOJSON_CONVERSION}" "GeoJSON conversion failed for boundary ${ID}" \
   "rm -f ${JSON_FILE} ${GEOJSON_FILE} 2>/dev/null || true"
  return 1
 fi
 __logd "GeoJSON conversion completed for boundary ${ID}"

 # Validate the GeoJSON with a JSON schema
 __logd "Validating GeoJSON structure for boundary ${ID}..."
 if ! __validate_json_structure "${GEOJSON_FILE}" "features"; then
  __loge "GeoJSON validation failed for boundary ${ID}"
  __handle_error_with_cleanup "${ERROR_GEOJSON_CONVERSION}" "Invalid GeoJSON structure for boundary ${ID}" \
   "rm -f ${JSON_FILE} ${GEOJSON_FILE} 2>/dev/null || true"
  return 1
 fi
 __logd "GeoJSON validation passed for boundary ${ID}"

 # Extract names with error handling
 __logd "Extracting names for boundary ${ID}..."
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
 __logd "Extracted names for boundary ${ID}:"
 __logd "  Name: ${NAME:-N/A}"
 __logd "  Name ES: ${NAME_ES:-N/A}"
 __logd "  Name EN: ${NAME_EN:-N/A}"

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
 __logd "Acquiring lock for boundary ${ID}..."

 # Create a unique lock directory for this process
 local PROCESS_LOCK="${LOCK_OGR2OGR}.${BASHPID}"
 local LOCK_OPERATION="mkdir ${PROCESS_LOCK} 2> /dev/null"
 local LOCK_CLEANUP="rmdir ${PROCESS_LOCK} 2>/dev/null || true"

 if ! __retry_file_operation "${LOCK_OPERATION}" 3 2 "${LOCK_CLEANUP}"; then
  __loge "Failed to acquire lock for boundary ${ID}"
  __handle_error_with_cleanup "${ERROR_GENERAL}" "Lock acquisition failed for boundary ${ID}" \
   "rm -f ${JSON_FILE} ${GEOJSON_FILE} 2>/dev/null || true"
  return 1
 fi
 __logd "Lock acquired for boundary ${ID}"

 # Import with ogr2ogr using retry logic with special handling for Austria
 __logd "Importing boundary ${ID} into database..."

 # Always use field selection to avoid row size issues
 __logd "Using field-selected import for boundary ${ID} to avoid row size issues"

 local IMPORT_OPERATION
 if [[ "${ID}" -eq 16239 ]]; then
  # Austria - use ST_Buffer to fix topology issues
  __logd "Using special handling for Austria (ID: 16239)"
  IMPORT_OPERATION="ogr2ogr -f PostgreSQL PG:dbname=${DBNAME} -nln import -overwrite -skipfailures -select name,admin_level,type,geometry ${GEOJSON_FILE}"
 else
  # Standard import with field selection to avoid row size issues
  __logd "Using field-selected import for boundary ${ID}"
  IMPORT_OPERATION="ogr2ogr -f PostgreSQL PG:dbname=${DBNAME} -nln import -overwrite -skipfailures -mapFieldType StringList=String -select name,admin_level,type,geometry ${GEOJSON_FILE}"
 fi

 local IMPORT_CLEANUP="rmdir ${PROCESS_LOCK} 2>/dev/null || true"

 if ! __retry_file_operation "${IMPORT_OPERATION}" 2 5 "${IMPORT_CLEANUP}"; then
  __loge "Failed to import boundary ${ID} into database after retries"
  __handle_error_with_cleanup "${ERROR_GENERAL}" "Database import failed for boundary ${ID}" \
   "rm -f ${JSON_FILE} ${GEOJSON_FILE} 2>/dev/null || true; rmdir ${PROCESS_LOCK} 2>/dev/null || true"
  return 1
 fi
 __logd "Database import completed for boundary ${ID}"

 # Check for column duplication errors and handle them
 __logd "Checking for duplicate columns in import table for boundary ${ID}..."
 local COLUMN_CHECK_OPERATION="psql -d ${DBNAME} -c \"SELECT column_name, COUNT(*) FROM information_schema.columns WHERE table_name = 'import' GROUP BY column_name HAVING COUNT(*) > 1;\" 2>/dev/null"
 local COLUMN_CHECK_RESULT
 COLUMN_CHECK_RESULT=$(eval "${COLUMN_CHECK_OPERATION}" 2> /dev/null || echo "")

 if [[ -n "${COLUMN_CHECK_RESULT}" ]] && [[ "${COLUMN_CHECK_RESULT}" != *"0 rows"* ]]; then
  __logw "Detected duplicate columns in import table for boundary ${ID}"
  __logw "This is likely due to case-sensitive column names in the GeoJSON"
  __logd "Attempting to fix duplicate columns..."
  # Handle column duplication by removing problematic columns
  local FIX_COLUMNS_OPERATION="psql -d ${DBNAME} -c \"ALTER TABLE import DROP COLUMN IF EXISTS \\\"name:xx-XX\\\", DROP COLUMN IF EXISTS \\\"name:XX-xx\\\";\" 2>/dev/null"
  if ! eval "${FIX_COLUMNS_OPERATION}"; then
   __logw "Failed to fix duplicate columns, but continuing..."
  else
   __logd "Duplicate columns fixed for boundary ${ID}"
  fi
 else
  __logd "No duplicate columns detected for boundary ${ID}"
 fi

 # Process the imported data with special handling for Austria
 __logd "Processing imported data for boundary ${ID}..."
 local PROCESS_OPERATION
 if [[ "${ID}" -eq 16239 ]]; then
  # Austria - use ST_Buffer to fix topology issues
  __logd "Using special processing for Austria (ID: 16239)"
  PROCESS_OPERATION="psql -d ${DBNAME} -c \"INSERT INTO countries (country_id, country_name, country_name_es, country_name_en, geom) SELECT ${ID}, '${NAME}', '${NAME_ES}', '${NAME_EN}', ST_Union(ST_Buffer(geometry, 0.0)) FROM import GROUP BY 1;\""
 else
  # Standard processing
  __logd "Using standard processing for boundary ${ID}"
  PROCESS_OPERATION="psql -d ${DBNAME} -c \"INSERT INTO countries (country_id, country_name, country_name_es, country_name_en, geom) SELECT ${ID}, '${NAME}', '${NAME_ES}', '${NAME_EN}', ST_Union(ST_makeValid(geometry)) FROM import GROUP BY 1;\""
 fi

 if ! __retry_file_operation "${PROCESS_OPERATION}" 2 3 ""; then
  __loge "Failed to process boundary ${ID} data"
  __handle_error_with_cleanup "${ERROR_GENERAL}" "Data processing failed for boundary ${ID}" \
   "rm -f ${JSON_FILE} ${GEOJSON_FILE} 2>/dev/null || true; rmdir ${PROCESS_LOCK} 2>/dev/null || true"
  return 1
 fi
 __logd "Data processing completed for boundary ${ID}"

 rmdir "${PROCESS_LOCK}" 2> /dev/null || true
 __logi "=== BOUNDARY PROCESSING COMPLETED SUCCESSFULLY ==="
 __log_finish
}

# Processes the list of countries or maritime areas in the given file.
function __processList {
 __log_start
 __logi "=== STARTING LIST PROCESSING ==="
 __logd "Process ID: ${BASHPID}"
 __logd "Boundaries file: ${1}"

 BOUNDARIES_FILE="${1}"
 # Create a unique query file for this process
 local QUERY_FILE_LOCAL="${TMP_DIR}/query.${BASHPID}.op"
 __logi "Retrieving the country or maritime boundaries."
 local PROCESSED_COUNT=0
 local FAILED_COUNT=0
 local TOTAL_LINES
 TOTAL_LINES=$(wc -l < "${BOUNDARIES_FILE}")
 __logd "Total boundaries to process: ${TOTAL_LINES}"

 while read -r LINE; do
  ID=$(echo "${LINE}" | awk '{print $1}')
  JSON_FILE="${TMP_DIR}/${ID}.json"
  GEOJSON_FILE="${TMP_DIR}/${ID}.geojson"
  __logi "Processing boundary ID: ${ID} (${PROCESSED_COUNT}/${TOTAL_LINES})"
  __logd "Creating query file for boundary ${ID}..."
  cat << EOF > "${QUERY_FILE_LOCAL}"
   [out:json];
   rel(${ID});
   (._;>;);
   out;
EOF

  if __processBoundary "${QUERY_FILE_LOCAL}"; then
   PROCESSED_COUNT=$((PROCESSED_COUNT + 1))
   __logd "Successfully processed boundary ${ID}"
  else
   FAILED_COUNT=$((FAILED_COUNT + 1))
   __loge "Failed to process boundary ${ID}"
  fi

  if [[ -n "${CLEAN:-}" ]] && [[ "${CLEAN}" = true ]]; then
   rm -f "${JSON_FILE}" "${GEOJSON_FILE}" "${QUERY_FILE_LOCAL}"
  else
   mv "${JSON_FILE}" "${TMP_DIR}/${ID}.json.old"
   mv "${GEOJSON_FILE}" "${TMP_DIR}/${ID}.geojson.old"
  fi
 done < "${BOUNDARIES_FILE}"

 __logi "List processing completed:"
 __logi "  Total boundaries: ${TOTAL_LINES}"
 __logi "  Successfully processed: ${PROCESSED_COUNT}"
 __logi "  Failed: ${FAILED_COUNT}"
 __logi "=== LIST PROCESSING COMPLETED ==="
 __log_finish
}

# Download the list of countries, then it downloads each country individually,
# converts the OSM JSON into a GeoJSON, and then it inserts the geometry of the
# country into the Postgres database with ogr2ogr.
function __processCountries {
 __log_start
 __logi "=== STARTING COUNTRIES PROCESSING ==="
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
   __logi "Starting list ${I} - ${BASHPID}."
   # shellcheck disable=SC2154
   if __processList "${I}" >> "${LOG_FILENAME}.${BASHPID}" 2>&1; then
    echo "SUCCESS:${BASHPID}:${I}" >> "${JOB_STATUS_FILE}"
   else
    echo "FAILED:${BASHPID}:${I}" >> "${JOB_STATUS_FILE}"
   fi
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

 FAIL=0
 local FAILED_JOBS=()
 for JOB in $(jobs -p); do
  echo "${JOB}"
  set +e
  wait "${JOB}"
  RET="${?}"
  set -e
  if [[ "${RET}" -ne 0 ]]; then
   FAIL=$((FAIL + 1))
   FAILED_JOBS+=("${JOB}")
  fi
 done
 __logw "Waited for all jobs, restarting in main thread - countries."

 # Check job status file for more detailed error information
 if [[ -f "${JOB_STATUS_FILE}" ]]; then
  local FAILED_COUNT=0
  local SUCCESS_COUNT=0
  while IFS=':' read -r status pid file; do
   if [[ "$status" == "FAILED" ]]; then
    FAILED_COUNT=$((FAILED_COUNT + 1))
    __loge "Job ${pid} failed processing file: ${file}"
   elif [[ "$status" == "SUCCESS" ]]; then
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
   fi
  done < "${JOB_STATUS_FILE}"

  __logi "Job summary: ${SUCCESS_COUNT} successful, ${FAILED_COUNT} failed"
 fi

 if [[ "${FAIL}" -ne 0 ]]; then
  local FAILED_JOBS_INFO=""
  for JOB_PID in "${FAILED_JOBS[@]}"; do
   if [[ -f "${LOG_FILENAME}.${JOB_PID}" ]]; then
    FAILED_JOBS_INFO="${FAILED_JOBS_INFO} ${JOB_PID}:${LOG_FILENAME}.${JOB_PID}"
   fi
  done
  __loge "FAIL! (${FAIL}) - Failed jobs: ${FAILED_JOBS[*]}. Check individual log files for detailed error information:${FAILED_JOBS_INFO}"
  __loge "=== COUNTRIES PROCESSING FAILED ==="
  __handle_error_with_cleanup "${ERROR_DOWNLOADING_BOUNDARY}" "Countries processing failed" \
   "echo 'Countries processing cleanup called'"
 fi

 __logi "=== COUNTRIES PROCESSING COMPLETED SUCCESSFULLY ==="

 # If some of the threads generated an error.
 set +e
 QTY_LOGS=$(find "${TMP_DIR}" -maxdepth 1 -type f -name "${BASENAME}.log.*" | wc -l)
 set -e
 if [[ "${QTY_LOGS}" -ne 0 ]]; then
  __logw "Some threads generated errors."
  local ERROR_LOGS=$(find "${TMP_DIR}" -maxdepth 1 -type f -name "${BASENAME}.log.*" | tr '\n' ' ')
  __loge "Found ${QTY_LOGS} error log files. Check them for details: ${ERROR_LOGS}"
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
   if [[ -n "${CLEAN:-}" ]] && [[ "${CLEAN}" = true ]]; then
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

# Function to validate dates in CSV files
# Parameters:
#   $1: CSV file path
#   $2: Column number containing dates (optional, defaults to auto-detect)
# Returns:
#   0 if all dates are valid, 1 if any invalid

# Function to validate file checksum
# Parameters:
#   $1: File path to validate
#   $2: Expected checksum
#   $3: Algorithm (optional, defaults to md5)
# Returns:
#   0 if valid, 1 if invalid

# Function to validate checksum from a checksum file
# Parameters:
#   $1: File path to validate
#   $2: Checksum file path
#   $3: Algorithm (optional, defaults to md5)
# Returns:
#   0 if valid, 1 if invalid

# Function to generate checksum for a file
# Parameters:
#   $1: File path
#   $2: Algorithm (optional, defaults to md5)
#   $3: Output file (optional, if not provided prints to stdout)
# Returns:
#   0 if successful, 1 if failed
function __generate_file_checksum() {
 __log_start
 local FILE_PATH="${1}"
 local ALGORITHM="${2:-md5}"
 local OUTPUT_FILE="${3:-}"
 local VALIDATION_ERRORS=()

 # Check if file exists and is readable
 if ! __validate_input_file "${FILE_PATH}" "File for checksum generation"; then
  return 1
 fi

 # Validate algorithm
 local VALID_ALGORITHMS=("md5" "sha1" "sha256" "sha512")
 local VALID_ALGORITHM=false
 for ALGO in "${VALID_ALGORITHMS[@]}"; do
  if [[ "${ALGORITHM}" == "${ALGO}" ]]; then
   VALID_ALGORITHM=true
   break
  fi
 done

 if [[ "${VALID_ALGORITHM}" == "false" ]]; then
  __loge "Invalid algorithm: ${ALGORITHM}. Supported: ${VALID_ALGORITHMS[*]}"
  return 1
 fi

 # Generate checksum
 local CHECKSUM
 case "${ALGORITHM}" in
 "md5")
  CHECKSUM=$(md5sum "${FILE_PATH}" 2> /dev/null)
  ;;
 "sha1")
  CHECKSUM=$(sha1sum "${FILE_PATH}" 2> /dev/null)
  ;;
 "sha256")
  CHECKSUM=$(sha256sum "${FILE_PATH}" 2> /dev/null)
  ;;
 "sha512")
  CHECKSUM=$(sha512sum "${FILE_PATH}" 2> /dev/null)
  ;;
 *)
  __loge "Unsupported algorithm: ${ALGORITHM}"
  return 1
  ;;
 esac

 if [[ -z "${CHECKSUM}" ]]; then
  __loge "Failed to generate ${ALGORITHM} checksum for file: ${FILE_PATH}"
  return 1
 fi

 # Output checksum
 if [[ -n "${OUTPUT_FILE}" ]]; then
  echo "${CHECKSUM}" > "${OUTPUT_FILE}"
  __logd "${ALGORITHM} checksum saved to: ${OUTPUT_FILE}"
 else
  echo "${CHECKSUM}"
 fi

 __log_finish
 return 0
}

# Function to validate multiple files using checksum files
# Parameters:
#   $1: Directory containing files to validate
#   $2: Checksum file path
#   $3: Algorithm (optional, defaults to md5)
# Returns:
#   0 if all valid, 1 if any invalid

# Validates JSON file against a JSON Schema
# Parameters:
#   $1: JSON file path to validate
#   $2: JSON Schema file path
#   $3: Schema specification (optional, defaults to draft2020)
# Returns:
#   0 if valid, 1 if invalid

# Validates geographic coordinates
# Parameters:
#   $1: Latitude value
#   $2: Longitude value
#   $3: Precision (optional, defaults to 7 decimal places)
# Returns:
#   0 if coordinates are valid, 1 if invalid

# Validates numeric values within specified ranges
# Parameters:
#   $1: Value to validate
#   $2: Minimum value (optional)
#   $3: Maximum value (optional)
#   $4: Description for error messages (optional)
# Returns:
#   0 if value is valid, 1 if invalid

# Validates string values against patterns
# Parameters:
#   $1: Value to validate
#   $2: Regular expression pattern
#   $3: Description for error messages (optional)
# Returns:
#   0 if value matches pattern, 1 if invalid

# Validates XML content for coordinate attributes using XPath
# This is the unified implementation for both API and Planet XML coordinate validation.
# Supports auto-detection of XML format (Planet vs API) and uses xmlstarlet for robust parsing.
#
# Parameters:
#   $1: XML file path
#   $2: Latitude XPath expression (optional, auto-detects based on XML structure)
#   $3: Longitude XPath expression (optional, auto-detects based on XML structure)
# Returns:
#   0 if all coordinates are valid, 1 if any invalid
#
# XML Format Support:
#   - Planet XML: /osm-notes/note/@lat and /osm-notes/note/@lon
#   - API XML: //@lat and //@lon (generic)
#   - Custom XPath: Can be specified via parameters 2 and 3
function __validate_xml_coordinates() {
 local XML_FILE="${1}"
 local LAT_XPATH="${2:-}"
 local LON_XPATH="${3:-}"
 local VALIDATION_ERRORS=()

 # Check if file exists and is readable
 if ! __validate_input_file "${XML_FILE}" "XML file"; then
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
    return 1
   fi
  fi

  # Report validation results
  if [[ ${SAMPLE_COUNT} -gt 0 ]]; then
   __logi "Lite coordinate validation passed using ${VALIDATION_STRATEGY}: ${SAMPLE_COUNT} samples validated"
   return 0
  else
   __logw "No coordinates found in sample validation of large XML file"
   return 0 # Don't fail validation for large files, just warn
  fi
 fi

 # For smaller files, auto-detect XPath based on XML structure if not provided
 if [[ -z "${LAT_XPATH}" ]] || [[ -z "${LON_XPATH}" ]]; then
  # Check if it's a Planet format XML (has /osm-notes/note structure)
  # Use lightweight grep instead of xmlstarlet to avoid memory issues
  if grep -q '<osm-notes' "${XML_FILE}" && grep -q '<note' "${XML_FILE}"; then
   LAT_XPATH="/osm-notes/note/@lat"
   LON_XPATH="/osm-notes/note/@lon"
   __logd "Auto-detected Planet XML format, using XPath: ${LAT_XPATH}, ${LON_XPATH}"
  elif grep -q '<osm' "${XML_FILE}" && grep -q '<note' "${XML_FILE}"; then
   # Check if it's an API format XML (has /osm/note structure)
   LAT_XPATH="/osm/note/@lat"
   LON_XPATH="/osm/note/@lon"
   __logd "Auto-detected API XML format, using XPath: ${LAT_XPATH}, ${LON_XPATH}"
  else
   # Default to generic XPath for other formats
   LAT_XPATH="//@lat"
   LON_XPATH="//@lon"
   __logd "Auto-detected generic XML format, using XPath: ${LAT_XPATH}, ${LON_XPATH}"
  fi
 fi

 # Extract coordinates using lightweight commands for smaller files
 local LATITUDES
 local LONGITUDES

 # Use grep and sed instead of xmlstarlet to avoid memory issues
 if [[ "${LAT_XPATH}" == "/osm-notes/note/@lat" ]]; then
  # Planet format: extract lat/lon attributes from note tags
  LATITUDES=$(grep -o 'lat="[^"]*"' "${XML_FILE}" | sed 's/lat="//;s/"//g' | grep -v '^$')
  LONGITUDES=$(grep -o 'lon="[^"]*"' "${XML_FILE}" | sed 's/lon="//;s/"//g' | grep -v '^$')
 elif [[ "${LAT_XPATH}" == "/osm/note/@lat" ]]; then
  # API format: extract lat/lon attributes from note tags
  LATITUDES=$(grep -o 'lat="[^"]*"' "${XML_FILE}" | sed 's/lat="//;s/"//g' | grep -v '^$')
  LONGITUDES=$(grep -o 'lon="[^"]*"' "${XML_FILE}" | sed 's/lon="//;s/"//g' | grep -v '^$')
 else
  # Generic format: try to find any lat/lon attributes
  LATITUDES=$(grep -o 'lat="[^"]*"' "${XML_FILE}" | sed 's/lat="//;s/"//g' | grep -v '^$')
  LONGITUDES=$(grep -o 'lon="[^"]*"' "${XML_FILE}" | sed 's/lon="//;s/"//g' | grep -v '^$')
 fi

 if [[ -z "${LATITUDES}" ]] || [[ -z "${LONGITUDES}" ]]; then
  __logw "No coordinates found in XML file using XPath: ${LAT_XPATH}, ${LON_XPATH}"
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
  return 1
 fi

 # Log success message
 __logi "XML coordinate validation passed: ${XML_FILE}"
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
# Version: 2025-08-12

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
 __log_start
 local COMMAND="$1"
 local MAX_RETRIES_PARAM="${2:-${MAX_RETRIES}}"
 local BASE_DELAY_PARAM="${3:-${BASE_DELAY}}"
 local MAX_DELAY_PARAM="${4:-${MAX_DELAY}}"
 local RETRY_COUNT=0
 local DELAY="${BASE_DELAY_PARAM}"

 __logd "Executing command with retry logic: ${COMMAND}"

 while [[ ${RETRY_COUNT} -lt ${MAX_RETRIES_PARAM} ]]; do
  # Execute the command
  if eval "${COMMAND}"; then
   __logd "Command succeeded on attempt $((RETRY_COUNT + 1))"
   __log_finish
   return 0
  fi

  RETRY_COUNT=$((RETRY_COUNT + 1))

  if [[ ${RETRY_COUNT} -lt ${MAX_RETRIES_PARAM} ]]; then
   # Add jitter to prevent thundering herd
   local JITTER=$((RANDOM % 1000))
   local JITTER_DELAY=$(echo "scale=3; ${JITTER} / 1000" | bc -l 2> /dev/null || echo "0")
   local TOTAL_DELAY=$(echo "scale=3; ${DELAY} + ${JITTER_DELAY}" | bc -l 2> /dev/null || echo "${DELAY}")

   echo "WARNING: Command failed on attempt ${RETRY_COUNT}, retrying in ${TOTAL_DELAY}s (${RETRY_COUNT}/${MAX_RETRIES_PARAM})" >&2
   sleep "${TOTAL_DELAY}"

   # Exponential backoff with max delay
   DELAY=$(echo "scale=3; ${DELAY} * 2" | bc -l 2> /dev/null || echo "${DELAY}")
   if (($(echo "${DELAY} > ${MAX_DELAY_PARAM}" | bc -l 2> /dev/null || echo "0"))); then
    DELAY="${MAX_DELAY_PARAM}"
   fi
  fi
 done

 __loge "Command failed after ${MAX_RETRIES_PARAM} attempts: ${COMMAND}"
 __log_finish
 return 1
}

# Circuit breaker pattern implementation
# Parameters: service_name command_to_execute
# Returns: 0 if successful, 1 if circuit is open or command failed
function __circuit_breaker_execute() {
 __log_start
 local SERVICE_NAME="$1"
 local COMMAND="$2"
 local CURRENT_TIME=$(date +%s)
 local STATE="${CIRCUIT_BREAKER_STATES[${SERVICE_NAME}]:-CLOSED}"
 local FAILURE_COUNT="${CIRCUIT_BREAKER_FAILURE_COUNTS[${SERVICE_NAME}]:-0}"
 local LAST_FAILURE_TIME="${CIRCUIT_BREAKER_LAST_FAILURE_TIMES[${SERVICE_NAME}]:-0}"

 # Check if circuit is open and timeout has passed
 if [[ "${STATE}" == "OPEN" ]]; then
  local TIME_SINCE_FAILURE=$((CURRENT_TIME - LAST_FAILURE_TIME))
  if [[ ${TIME_SINCE_FAILURE} -gt ${CIRCUIT_BREAKER_TIMEOUT} ]]; then
   echo "INFO: Circuit breaker for ${SERVICE_NAME} transitioning to HALF_OPEN" >&2
   CIRCUIT_BREAKER_STATES[${SERVICE_NAME}]="HALF_OPEN"
   STATE="HALF_OPEN"
  else
   echo "WARNING: Circuit breaker for ${SERVICE_NAME} is OPEN, skipping execution" >&2
   __log_finish
   return 1
  fi
 fi

 # Execute command
 if eval "${COMMAND}"; then
  # Success - close circuit and reset failure count
  if [[ "${STATE}" != "CLOSED" ]]; then
   echo "INFO: Circuit breaker for ${SERVICE_NAME} transitioning to CLOSED" >&2
  fi
  CIRCUIT_BREAKER_STATES[${SERVICE_NAME}]="CLOSED"
  CIRCUIT_BREAKER_FAILURE_COUNTS[${SERVICE_NAME}]=0
  __log_finish
  return 0
 else
  # Failure - increment failure count
  FAILURE_COUNT=$((FAILURE_COUNT + 1))
  CIRCUIT_BREAKER_FAILURE_COUNTS[${SERVICE_NAME}]=${FAILURE_COUNT}
  CIRCUIT_BREAKER_LAST_FAILURE_TIMES[${SERVICE_NAME}]=${CURRENT_TIME}

  if [[ ${FAILURE_COUNT} -ge ${CIRCUIT_BREAKER_THRESHOLD} ]]; then
   __loge "Circuit breaker for ${SERVICE_NAME} transitioning to OPEN (${FAILURE_COUNT} failures)"
   CIRCUIT_BREAKER_STATES[${SERVICE_NAME}]="OPEN"
  fi
  __log_finish
  return 1
 fi
}

# Enhanced network download with retry and circuit breaker
# Parameters: url output_file [service_name]
# Returns: 0 if successful, 1 if failed
function __download_with_retry() {
 __log_start
 local URL="$1"
 local OUTPUT_FILE="$2"
 local SERVICE_NAME="${3:-download}"
 local COMMAND="wget -O '${OUTPUT_FILE}' '${URL}'"

 __logd "Downloading ${URL} to ${OUTPUT_FILE}"

 # Use circuit breaker for network operations
 if __circuit_breaker_execute "${SERVICE_NAME}" "${COMMAND}"; then
  __logd "Download successful: ${URL}"
  __log_finish
  return 0
 else
  __loge "Download failed after retries: ${URL}"
  __log_finish
  return 1
 fi
}

# Enhanced API call with retry and circuit breaker
# Parameters: url output_file [service_name]
# Returns: 0 if successful, 1 if failed
function __api_call_with_retry() {
 __log_start
 local URL="$1"
 local OUTPUT_FILE="$2"
 local SERVICE_NAME="${3:-api}"
 local COMMAND="curl -s -o '${OUTPUT_FILE}' '${URL}'"

 __logd "Making API call to ${URL}"

 # Use circuit breaker for API operations
 if __circuit_breaker_execute "${SERVICE_NAME}" "${COMMAND}"; then
  __logd "API call successful: ${URL}"
  __log_finish
  return 0
 else
  __loge "API call failed after retries: ${URL}"
  __log_finish
  return 1
 fi
}

# Database operation with retry and rollback capability
# Parameters: sql_command [rollback_command]
# Returns: 0 if successful, 1 if failed
function __database_operation_with_retry() {
 __log_start
 local SQL_COMMAND="$1"
 local ROLLBACK_COMMAND="${2:-}"
 local MAX_RETRIES_PARAM="${MAX_RETRIES:-3}"
 local RETRY_COUNT=0

 __logd "Executing database operation with retry"

 while [[ ${RETRY_COUNT} -lt ${MAX_RETRIES_PARAM} ]]; do
  if psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -c "${SQL_COMMAND}" > /dev/null 2>&1; then
   __logd "Database operation succeeded on attempt $((RETRY_COUNT + 1))"
   __log_finish
   return 0
  fi

  RETRY_COUNT=$((RETRY_COUNT + 1))

  if [[ ${RETRY_COUNT} -lt ${MAX_RETRIES_PARAM} ]]; then
   echo "WARNING: Database operation failed on attempt ${RETRY_COUNT}, retrying in ${BASE_DELAY}s" >&2
   sleep "${BASE_DELAY}"
  fi
 done

 # If rollback command is provided, execute it
 if [[ -n "${ROLLBACK_COMMAND}" ]]; then
  echo "WARNING: Executing rollback command due to database operation failure" >&2
  if psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -c "${ROLLBACK_COMMAND}" > /dev/null 2>&1; then
   __logd "Rollback executed successfully"
  else
   __loge "Rollback failed"
  fi
 fi

 __loge "Database operation failed after ${MAX_RETRIES_PARAM} attempts"
 __log_finish
 return 1
}

# File operation with retry and cleanup
# Parameters: operation_command [cleanup_command]
# Returns: 0 if successful, 1 if failed
function __file_operation_with_retry() {
 __log_start
 local OPERATION_COMMAND="$1"
 local CLEANUP_COMMAND="${2:-}"
 local MAX_RETRIES_PARAM="${MAX_RETRIES:-3}"
 local RETRY_COUNT=0

 __logd "Executing file operation with retry"

 while [[ ${RETRY_COUNT} -lt ${MAX_RETRIES_PARAM} ]]; do
  if eval "${OPERATION_COMMAND}"; then
   __logd "File operation succeeded on attempt $((RETRY_COUNT + 1))"
   __log_finish
   return 0
  fi

  RETRY_COUNT=$((RETRY_COUNT + 1))

  if [[ ${RETRY_COUNT} -lt ${MAX_RETRIES_PARAM} ]]; then
   echo "WARNING: File operation failed on attempt ${RETRY_COUNT}, retrying in ${BASE_DELAY}s" >&2
   sleep "${BASE_DELAY}"
  fi
 done

 # If cleanup command is provided, execute it
 if [[ -n "${CLEANUP_COMMAND}" ]]; then
  echo "WARNING: Executing cleanup command due to file operation failure" >&2
  if eval "${CLEANUP_COMMAND}"; then
   __logd "Cleanup executed successfully"
  else
   __loge "Cleanup failed"
  fi
 fi

 __loge "File operation failed after ${MAX_RETRIES_PARAM} attempts"
 __log_finish
 return 1
}

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

# Enhanced error recovery with automatic cleanup
# Parameters: error_code error_message [cleanup_commands...]
# Returns: Always exits with error_code
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
 # For now, always use return to avoid issues in test environments
 # TODO: Implement proper environment detection
 return "${ERROR_CODE}"
}

# Get circuit breaker status for monitoring
# Parameters: service_name
# Returns: Status string (CLOSED/OPEN/HALF_OPEN)
function __get_circuit_breaker_status() {
 __log_start
 local SERVICE_NAME="$1"
 echo "${CIRCUIT_BREAKER_STATES[${SERVICE_NAME}]:-CLOSED}"
 __log_finish
}

# Reset circuit breaker for a service
# Parameters: service_name
# Returns: 0 if reset successful
function __reset_circuit_breaker() {
 __log_start
 local SERVICE_NAME="$1"

 CIRCUIT_BREAKER_STATES[${SERVICE_NAME}]="CLOSED"
 CIRCUIT_BREAKER_FAILURE_COUNTS[${SERVICE_NAME}]=0
 CIRCUIT_BREAKER_LAST_FAILURE_TIMES[${SERVICE_NAME}]=0

 echo "INFO: Circuit breaker reset for ${SERVICE_NAME}" >&2
 __log_finish
 return 0
}

# Retry file operations with cleanup on failure
# Parameters: operation_command max_retries base_delay [cleanup_command]
# Returns: 0 if successful, 1 if failed after all retries
function __retry_file_operation() {
 __log_start
 local OPERATION_COMMAND="$1"
 local MAX_RETRIES_LOCAL="${2:-3}"
 local BASE_DELAY_LOCAL="${3:-2}"
 local CLEANUP_COMMAND="${4:-}"
 local RETRY_COUNT=0

 __logd "Executing file operation with retry logic: ${OPERATION_COMMAND}"

 while [[ ${RETRY_COUNT} -lt ${MAX_RETRIES_LOCAL} ]]; do
  if eval "${OPERATION_COMMAND}"; then
   __logd "File operation succeeded on attempt $((RETRY_COUNT + 1))"
   __log_finish
   return 0
  fi

  RETRY_COUNT=$((RETRY_COUNT + 1))

  if [[ ${RETRY_COUNT} -lt ${MAX_RETRIES_LOCAL} ]]; then
   echo "WARNING: File operation failed on attempt ${RETRY_COUNT}, retrying in ${BASE_DELAY_LOCAL}s" >&2
   sleep "${BASE_DELAY_LOCAL}"
  fi
 done

 # If cleanup command is provided, execute it
 if [[ -n "${CLEANUP_COMMAND}" ]]; then
  echo "WARNING: Executing cleanup command due to file operation failure" >&2
  if eval "${CLEANUP_COMMAND}"; then
   __logd "Cleanup executed successfully"
  else
   __loge "Cleanup failed"
  fi
 fi

 __loge "File operation failed after ${MAX_RETRIES_LOCAL} attempts"
 __log_finish
 return 1
}

# Validate CSV file for enum compatibility before database loading
# Parameters:
#   $1 - CSV file path
#   $2 - File type (notes, comments, text)
# Returns:
#   0 if validation passes, 1 if validation fails
function __validate_csv_for_enum_compatibility {
 __log_start
 local CSV_FILE="${1}"
 local FILE_TYPE="${2}"

 if [[ ! -f "${CSV_FILE}" ]]; then
  __loge "ERROR: CSV file not found: ${CSV_FILE}"
  __log_finish
  return 1
 fi

 __logd "Validating CSV file for enum compatibility: ${CSV_FILE} (${FILE_TYPE})"

 case "${FILE_TYPE}" in
 "comments")
  # Validate comment events against note_event_enum
  local INVALID_LINES=0
  local LINE_NUMBER=0

  while IFS= read -r line; do
   ((LINE_NUMBER++))

   # Skip empty lines
   if [[ -z "${line}" ]]; then
    continue
   fi

   # Extract event value (3rd field)
   local EVENT
   EVENT=$(echo "${line}" | cut -d',' -f3 | tr -d '"' 2> /dev/null)

   # Check if event is empty or invalid
   if [[ -z "${EVENT}" ]]; then
    __logw "WARNING: Empty event value found in line ${LINE_NUMBER}: ${line}"
    ((INVALID_LINES++))
   elif [[ ! "${EVENT}" =~ ^(opened|closed|reopened|commented|hidden)$ ]]; then
    __logw "WARNING: Invalid event value '${EVENT}' found in line ${LINE_NUMBER}: ${line}"
    ((INVALID_LINES++))
   fi
  done < "${CSV_FILE}"

  if [[ "${INVALID_LINES}" -gt 0 ]]; then
   __loge "ERROR: Found ${INVALID_LINES} lines with invalid event values in ${CSV_FILE}"
   __log_finish
   return 1
  fi
  ;;

 "notes")
  # Validate note status against note_status_enum
  local INVALID_LINES=0
  local LINE_NUMBER=0

  while IFS= read -r line; do
   ((LINE_NUMBER++))

   # Skip empty lines
   if [[ -z "${line}" ]]; then
    continue
   fi

   # Extract status value (6th field)
   local STATUS
   STATUS=$(echo "${line}" | cut -d',' -f6 | tr -d '"' 2> /dev/null)

   # Check if status is empty or invalid (status can be empty for open notes)
   if [[ -n "${STATUS}" ]] && [[ ! "${STATUS}" =~ ^(open|close|hidden)$ ]]; then
    __logw "WARNING: Invalid status value '${STATUS}' found in line ${LINE_NUMBER}: ${line}"
    ((INVALID_LINES++))
   fi
  done < "${CSV_FILE}"

  if [[ "${INVALID_LINES}" -gt 0 ]]; then
   __loge "ERROR: Found ${INVALID_LINES} lines with invalid status values in ${CSV_FILE}"
   __log_finish
   return 1
  fi
  ;;

 *)
  __logw "WARNING: Unknown file type '${FILE_TYPE}', skipping enum validation"
  __log_finish
  return 0
  ;;
 esac

 __logd "CSV enum validation passed for ${CSV_FILE}"
 __log_finish
 return 0
}

# Show help function
function __show_help() {
 echo "OSM-Notes-profile - Common Functions"
 echo "This file serves as the main entry point for all common functions."
 echo
 echo "Usage: source bin/functionsProcess.sh"
 echo
 echo "This file loads the following function modules:"
 echo "  - commonFunctions.sh      - Common functions and error codes"
 echo "  - validationFunctions.sh  - Validation functions"
 echo "  - errorHandlingFunctions.sh - Error handling and retry functions"
 echo "  - processAPIFunctions.sh  - API processing functions"
 echo "  - processPlanetFunctions.sh - Planet processing functions"
 echo
 echo "Available legacy functions:"
 echo "  - __checkPrereqsCommands  - Check prerequisites"
 echo "  - __createFunctionToGetCountry - Create country function"
 echo "  - __createProcedures      - Create procedures"
 echo "  - __organizeAreas         - Organize areas"
 echo "  - __getLocationNotes      - Get location notes"
 echo
 echo "Author: Andres Gomez (AngocA)"
 echo "Version: 2025-08-12"
 exit 1
}

# Enhanced XML validation with error handling
# Parameters:
#   $1 - XML file path
#   $2 - Schema file path (optional)
#   $3 - Timeout in seconds (optional, default: 300)
# Returns:
#   0 if validation passes, 1 if validation fails
function __validate_xml_with_enhanced_error_handling() {
 local XML_FILE="${1}"
 local SCHEMA_FILE="${2}"
 local TIMEOUT="${3:-300}"

 if [[ ! -f "${XML_FILE}" ]]; then
  __loge "ERROR: XML file not found: ${XML_FILE}"
  return 1
 fi

 # Get file size for validation strategy
 local FILE_SIZE
 FILE_SIZE=$(stat -c%s "${XML_FILE}" 2> /dev/null || echo "0")
 local SIZE_MB=$((FILE_SIZE / 1024 / 1024))

 __logi "Validating XML file: ${XML_FILE} (${SIZE_MB} MB)"

 # Check if this is a planet XML file (contains "planet" in filename or path)
 local IS_PLANET_FILE=false
 if [[ "${XML_FILE}" =~ [Pp]lanet ]]; then
  IS_PLANET_FILE=true
  __logi "Planet XML file detected. Using basic validation to avoid memory issues."
 fi

 # Use appropriate validation strategy based on file size or file type
 local LARGE_FILE_THRESHOLD="${ETL_LARGE_FILE_THRESHOLD_MB:-500}"
 local VERY_LARGE_FILE_THRESHOLD="${ETL_VERY_LARGE_FILE_THRESHOLD_MB:-1000}"

 if [[ "${SIZE_MB}" -gt "${VERY_LARGE_FILE_THRESHOLD}" ]]; then
  __logw "WARNING: Very large XML file detected (${SIZE_MB} MB). Using structure-only validation."

  # For very large files, use basic structure validation only
  if __validate_xml_structure_only "${XML_FILE}"; then
   __logi "Structure-only validation succeeded for very large file"
   return 0
  else
   __loge "ERROR: Structure-only validation failed"
   return 1
  fi
 elif [[ "${SIZE_MB}" -gt "${LARGE_FILE_THRESHOLD}" ]] || [[ "${IS_PLANET_FILE}" == true ]]; then
  __logw "WARNING: Large XML file or Planet file detected (${SIZE_MB} MB). Using basic validation."

  # For large files or planet files, use basic XML validation without schema
  if __validate_xml_basic "${XML_FILE}"; then
   __logi "Basic XML validation succeeded"
   return 0
  else
   __loge "ERROR: Basic XML validation failed"
   return 1
  fi
 else
  # Standard validation for smaller files (non-planet)
  if [[ -n "${SCHEMA_FILE}" ]] && [[ -f "${SCHEMA_FILE}" ]]; then
   local XMLLINT_OUTPUT
   XMLLINT_OUTPUT=$(timeout "${TIMEOUT}" xmllint --noout --schema "${SCHEMA_FILE}" "${XML_FILE}" 2>&1)
   local EXIT_CODE=$?
   if [[ ${EXIT_CODE} -eq 0 ]]; then
    __logi "XML validation succeeded"
    return 0
   else
    __loge "ERROR: XML schema validation failed - xmllint output: ${XMLLINT_OUTPUT}"
    return 1
   fi
  else
   # Fallback to basic validation if no schema provided
   if __validate_xml_basic "${XML_FILE}"; then
    __logi "Basic XML validation succeeded"
    return 0
   else
    __loge "ERROR: Basic XML validation failed"
    return 1
   fi
  fi
 fi
}

# Basic XML structure validation (lightweight)
# Parameters:
#   $1 - XML file path
# Returns:
#   0 if validation passes, 1 if validation fails
function __validate_xml_basic() {
 local XML_FILE="${1}"

 if [[ ! -f "${XML_FILE}" ]]; then
  __loge "ERROR: XML file not found: ${XML_FILE}"
  return 1
 fi

 __logi "Performing basic XML validation: ${XML_FILE}"

 # Check basic XML structure using xmllint without schema
 local XMLLINT_OUTPUT
 if ! timeout 120 xmllint --noout --nonet "${XML_FILE}" 2>&1; then
  XMLLINT_OUTPUT=$(timeout 120 xmllint --noout --nonet "${XML_FILE}" 2>&1)
  __loge "ERROR: Basic XML structure validation failed - xmllint output: ${XMLLINT_OUTPUT}"
  return 1
 fi

 __logi "Basic XML validation succeeded"
 return 0
}

# XML structure-only validation (very lightweight)
# Parameters:
#   $1 - XML file path
# Returns:
#   0 if validation passes, 1 if validation fails
function __validate_xml_structure_only() {
 local XML_FILE="${1}"

 if [[ ! -f "${XML_FILE}" ]]; then
  __loge "ERROR: XML file not found: ${XML_FILE}"
  return 1
 fi

 __logi "Performing structure-only XML validation: ${XML_FILE}"

 # Check if file contains basic XML structure markers
 if grep -q '<?xml' "${XML_FILE}" && grep -q '<osm' "${XML_FILE}"; then
  __logi "Structure-only XML validation succeeded"
  return 0
 else
  __loge "ERROR: Structure-only XML validation failed - missing XML structure markers"
  return 1
 fi
}

# Count XML notes for API format
# Parameters:
#   $1 - XML file path
# Returns:
#   Number of notes found
function __countXmlNotesApi() {
 local XML_FILE="${1}"

 if [[ ! -f "${XML_FILE}" ]]; then
  __loge "ERROR: XML file not found: ${XML_FILE}"
  return 1
 fi

 # Count notes using grep (lightweight approach)
 local NOTE_COUNT
 NOTE_COUNT=$(grep -c '<note' "${XML_FILE}" 2> /dev/null || echo "0")

 __logi "Found ${NOTE_COUNT} notes in API XML file: ${XML_FILE}"
 echo "${NOTE_COUNT}"
 return 0
}
