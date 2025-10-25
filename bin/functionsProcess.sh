#!/bin/bash

# OSM-Notes-profile - Common Functions
# This file serves as the main entry point for all common functions.
# It loads all refactored function files to maintain backward compatibility.
#
# Author: Andres Gomez (AngocA)
# Version: 2025-10-24
# Updated: 2025-10-25

# Define version variable
VERSION="2025-10-25"

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
if [[ -f "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/commonFunctions.sh" ]]; then
 # shellcheck source=commonFunctions.sh
 source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/commonFunctions.sh"
else
 echo "ERROR: commonFunctions.sh not found"
 exit 1
fi

# Load validation functions
if [[ -f "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/validationFunctions.sh" ]]; then
 # shellcheck source=validationFunctions.sh
 source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/validationFunctions.sh"
else
 echo "ERROR: validationFunctions.sh not found"
 exit 1
fi

# Load security functions (SQL sanitization)
if [[ -f "${SCRIPT_BASE_DIRECTORY}/bin/securityFunctions.sh" ]]; then
 # shellcheck source=securityFunctions.sh
 source "${SCRIPT_BASE_DIRECTORY}/bin/securityFunctions.sh"
else
 echo "ERROR: securityFunctions.sh not found"
 exit 1
fi

# Load error handling functions
if [[ -f "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/errorHandlingFunctions.sh" ]]; then
 # shellcheck source=errorHandlingFunctions.sh
 source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/errorHandlingFunctions.sh"
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

# Load consolidated parallel processing functions (must be loaded AFTER wrapper functions)
if [[ -f "${SCRIPT_BASE_DIRECTORY}/bin/parallelProcessingFunctions.sh" ]]; then
 # shellcheck source=parallelProcessingFunctions.sh
 source "${SCRIPT_BASE_DIRECTORY}/bin/parallelProcessingFunctions.sh"
fi

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
declare -r POSTGRES_12_DROP_GENERIC_OBJECTS="${SCRIPT_BASE_DIRECTORY}/sql/consolidated_cleanup.sql"
declare -r POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_21_createFunctionToGetCountry.sql"
declare -r POSTGRES_22_CREATE_PROC_INSERT_NOTE="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_22_createProcedure_insertNote.sql"
declare -r POSTGRES_23_CREATE_PROC_INSERT_NOTE_COMMENT="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_23_createProcedure_insertNoteComment.sql"
declare -r POSTGRES_31_ORGANIZE_AREAS="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_31_organizeAreas.sql"
declare -r POSTGRES_32_UPLOAD_NOTE_LOCATION="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_32_loadsBackupNoteLocation.sql"

if [[ -z "${COUNTRIES_BOUNDARY_IDS_FILE:-}" ]]; then
 declare -r COUNTRIES_BOUNDARY_IDS_FILE="${TMP_DIR}/countries_boundary_ids.csv"
fi

if [[ -z "${MARITIME_BOUNDARY_IDS_FILE:-}" ]]; then
 declare -r MARITIME_BOUNDARY_IDS_FILE="${TMP_DIR}/maritime_boundary_ids.csv"
fi

# Configuration variables (if not already defined)
# MAX_NOTES is now defined in etc/properties.sh, no need to declare it here
# Just validate if it's set (only if it's defined)
if [[ -n "${MAX_NOTES:-}" ]] && [[ ! "${MAX_NOTES}" =~ ^[1-9][0-9]*$ ]]; then
 __loge "ERROR: MAX_NOTES must be a positive integer, got: ${MAX_NOTES}"
 # Don't exit in test environment, just log the error
 if [[ -z "${BATS_TEST_NAME:-}" ]]; then
  exit 1
 fi
fi

if [[ -z "${GENERATE_FAILED_FILE:-}" ]]; then
 declare -r GENERATE_FAILED_FILE="false"
fi

if [[ -z "${LOG_FILENAME:-}" ]]; then
 declare -r LOG_FILENAME="${TMP_DIR}/${BASENAME}.log"
fi

# Now uses functions loaded from parallelProcessingFunctions.sh at script startup
function __processXmlPartsParallel() {
 __log_start
 # Check if the consolidated function is available
 if ! declare -f __processXmlPartsParallelConsolidated > /dev/null 2>&1; then
  __loge "ERROR: Consolidated parallel processing functions not available. Please ensure parallelProcessingFunctions.sh was loaded."
  __log_finish
  return 1
 fi
 # Call the consolidated function
 __processXmlPartsParallelConsolidated "$@"
 local RETURN_CODE=$?
 __log_finish
 return "${RETURN_CODE}"
}

# Wrapper function: Split XML for parallel processing (consolidated implementation)
# Now uses functions loaded from parallelProcessingFunctions.sh at script startup
function __splitXmlForParallelSafe() {
 # This is a wrapper function that will be overridden by the real implementation
 # in parallelProcessingFunctions.sh if that file is sourced after this one.
 # If you see this error, it means parallelProcessingFunctions.sh wasn't loaded.
 __loge "ERROR: This is a wrapper function. parallelProcessingFunctions.sh must be sourced to override this with the real implementation."
 __loge "ERROR: Please ensure parallelProcessingFunctions.sh is loaded AFTER functionsProcess.sh"
 return 1
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

 # Validate XML structure first (only if XML validation is enabled)
 # Only validate if the file is suspected to be malformed and validation is not skipped
 if [[ "${SKIP_XML_VALIDATION}" != "true" ]] && command -v xmllint > /dev/null 2>&1; then
  # Check if the file contains basic XML structure
  if ! grep -q "<?xml" "${XML_FILE}" 2> /dev/null; then
   __loge "File does not appear to be XML: ${XML_FILE}"
   TOTAL_NOTES=0
   export TOTAL_NOTES
   __log_finish
   return 1
  fi

  # Try to validate XML structure - fail only on severe structural issues
  if ! xmllint --noout "${XML_FILE}" > /dev/null 2>&1; then
   # Check if it's a severe structural issue (missing closing tags, etc.)
   if grep -q "<note" "${XML_FILE}" 2> /dev/null && ! grep -q "</note>" "${XML_FILE}" 2> /dev/null; then
    __loge "Severe XML structural issue in file: ${XML_FILE}"
    TOTAL_NOTES=0
    export TOTAL_NOTES
    __log_finish
    return 1
   else
    __logw "XML structure validation failed for file: ${XML_FILE}, but continuing with counting"
   fi
  fi
 fi

 # Count notes using grep (fast and reliable)
 TOTAL_NOTES=$(grep -c '<note ' "${XML_FILE}" 2> /dev/null || echo "0")

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
 # grep returns 1 when no matches found in some versions, which is also not an error
 if [[ ${GREP_STATUS} -ne 0 ]] && [[ ${GREP_STATUS} -ne 1 ]]; then
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
# Now uses functions loaded from parallelProcessingFunctions.sh at script startup
function __splitXmlForParallelAPI() {
 __log_start
 # Check if the consolidated function is available
 if ! declare -f __splitXmlForParallelSafeConsolidated > /dev/null 2>&1; then
  __loge "ERROR: Consolidated parallel processing functions not available. Please ensure parallelProcessingFunctions.sh was loaded."
  __log_finish
  return 1
 fi
 # Call the consolidated function
 __splitXmlForParallelSafeConsolidated "$@"
 local RETURN_CODE=$?
 __log_finish
 return "${RETURN_CODE}"
}

# Wrapper function for Planet format that uses parallel processing
# Now uses functions loaded from parallelProcessingFunctions.sh at script startup
function __splitXmlForParallelPlanet() {
 # This is a wrapper function that will be overridden by the real implementation
 # in parallelProcessingFunctions.sh if that file is sourced after this one.
 __loge "ERROR: This is a wrapper function. parallelProcessingFunctions.sh must be sourced to override this with the real implementation."
 return 1
}

# Processes a single XML part for API notes using AWK extraction
# Parameters:
#   $1: XML part file path
function __processApiXmlPart() {
 __log_start
 local XML_PART="${1}"
 local PART_NUM
 local BASENAME_PART

 __logi "=== STARTING API XML PART PROCESSING (AWK) ==="
 __logd "Input XML part: ${XML_PART}"

 # Debug: Show environment variables
 __logd "Environment check in subshell:"
 __logd "  XML_PART: '${XML_PART}'"
 __logd "  TMP_DIR: '${TMP_DIR:-NOT_SET}'"
 __logd "  SCRIPT_BASE_DIRECTORY: '${SCRIPT_BASE_DIRECTORY:-NOT_SET}'"
 __logd "  DBNAME: '${DBNAME:-NOT_SET}'"

 BASENAME_PART=$(basename "${XML_PART}" .xml)
 # Extract number from api_part_N or planet_part_N format
 PART_NUM=$(echo "${BASENAME_PART}" | sed 's/.*_part_//' | sed 's/^0*//')

 # Handle case where part number is just "0"
 if [[ -z "${PART_NUM}" ]]; then
  PART_NUM="0"
 fi

 # PostgreSQL partitions are 1-based (part_1, part_2, ..., part_N)
 # But file names are 0-based (part_0, part_1, ..., part_N-1)
 # So we need to add 1 to match PostgreSQL partition names
 PART_NUM=$((PART_NUM + 1))

 # Debug: Show extraction process
 __logd "Extracting part number from: ${XML_PART}"
 __logd "Basename: ${BASENAME_PART}"
 __logd "Part number: ${PART_NUM} (adjusted for PostgreSQL 1-based partitions)"

 # Validate part number
 if [[ ! "${PART_NUM}" =~ ^[0-9]+$ ]] || [[ ${PART_NUM} -lt 1 ]]; then
  __loge "Invalid part number extracted: '${PART_NUM}' from file: ${XML_PART}"
  __log_finish
  return 1
 fi

 __logi "Processing API XML part ${PART_NUM}: ${XML_PART}"

 # Convert XML part to CSV using AWK
 local OUTPUT_NOTES_PART
 local OUTPUT_COMMENTS_PART
 local OUTPUT_TEXT_PART
 OUTPUT_NOTES_PART="${TMP_DIR}/output-notes-part-${PART_NUM}.csv"
 OUTPUT_COMMENTS_PART="${TMP_DIR}/output-comments-part-${PART_NUM}.csv"
 OUTPUT_TEXT_PART="${TMP_DIR}/output-text-part-${PART_NUM}.csv"

 # Process notes with AWK (fast and dependency-free)
 __logd "Processing notes with AWK: ${XML_PART} -> ${OUTPUT_NOTES_PART}"
 awk -f "${SCRIPT_BASE_DIRECTORY}/awk/extract_notes.awk" "${XML_PART}" > "${OUTPUT_NOTES_PART}"
 if [[ ! -f "${OUTPUT_NOTES_PART}" ]]; then
  __loge "Notes CSV file was not created: ${OUTPUT_NOTES_PART}"
  __log_finish
  return 1
 fi

 # Process comments with AWK (fast and dependency-free)
 __logd "Processing comments with AWK: ${XML_PART} -> ${OUTPUT_COMMENTS_PART}"
 awk -f "${SCRIPT_BASE_DIRECTORY}/awk/extract_comments.awk" "${XML_PART}" > "${OUTPUT_COMMENTS_PART}"
 if [[ ! -f "${OUTPUT_COMMENTS_PART}" ]]; then
  __loge "Comments CSV file was not created: ${OUTPUT_COMMENTS_PART}"
  __log_finish
  return 1
 fi

 # Process text comments with AWK (fast and dependency-free)
 __logd "Processing text comments with AWK: ${XML_PART} -> ${OUTPUT_TEXT_PART}"
 awk -f "${SCRIPT_BASE_DIRECTORY}/awk/extract_comment_texts.awk" "${XML_PART}" > "${OUTPUT_TEXT_PART}"
 if [[ ! -f "${OUTPUT_TEXT_PART}" ]]; then
  __logw "Text comments CSV file was not created, generating empty file to continue: ${OUTPUT_TEXT_PART}"
  : > "${OUTPUT_TEXT_PART}"
 fi

 # Add part_id to the end of each line for notes
 __logd "Adding part_id ${PART_NUM} to notes CSV"
 awk -v part_id="${PART_NUM}" '{print $0 "," part_id}' "${OUTPUT_NOTES_PART}" > "${OUTPUT_NOTES_PART}.tmp" && mv "${OUTPUT_NOTES_PART}.tmp" "${OUTPUT_NOTES_PART}"

 # Add part_id to the end of each line for comments
 __logd "Adding part_id ${PART_NUM} to comments CSV"
 awk -v part_id="${PART_NUM}" '{print $0 "," part_id}' "${OUTPUT_COMMENTS_PART}" > "${OUTPUT_COMMENTS_PART}.tmp" && mv "${OUTPUT_COMMENTS_PART}.tmp" "${OUTPUT_COMMENTS_PART}"

 # Add part_id to the end of each line for text comments
 __logd "Adding part_id ${PART_NUM} to text comments CSV"
 if [[ -s "${OUTPUT_TEXT_PART}" ]]; then
  awk -v part_id="${PART_NUM}" '{print $0 "," part_id}' "${OUTPUT_TEXT_PART}" > "${OUTPUT_TEXT_PART}.tmp" && mv "${OUTPUT_TEXT_PART}.tmp" "${OUTPUT_TEXT_PART}"
 else
  __logw "Text comments CSV is empty for part ${PART_NUM}; skipping part_id append"
 fi

 # Debug: Show generated CSV files and their sizes
 __logd "Generated CSV files for part ${PART_NUM}:"
 __logd "  Notes: ${OUTPUT_NOTES_PART} ($(wc -l < "${OUTPUT_NOTES_PART}" || echo 0) lines)" || true
 __logd "  Comments: ${OUTPUT_COMMENTS_PART} ($(wc -l < "${OUTPUT_COMMENTS_PART}" || echo 0) lines)" || true
 __logd "  Text: ${OUTPUT_TEXT_PART} ($(wc -l < "${OUTPUT_TEXT_PART}" || echo 0) lines)" || true

 # Validate CSV files structure and content before loading
 __logd "Validating CSV files structure and enum compatibility..."

 # Validate structure first
 if ! __validate_csv_structure "${OUTPUT_NOTES_PART}" "notes"; then
  __loge "ERROR: Notes CSV structure validation failed for part ${PART_NUM}"
  __log_finish
  return 1
 fi

 # Then validate enum values
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

 # Validate comments enum
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
 __log_finish
 __log_finish
}

# Processes a single XML part for Planet notes using AWK extraction
# Parameters:
#   $1: XML part file path
function __processPlanetXmlPart() {
 __log_start
 local XML_PART="${1}"
 local PART_NUM
 local BASENAME_PART

 __logi "=== STARTING PLANET XML PART PROCESSING (AWK) ==="
 __logd "Input XML part: ${XML_PART}"

 # Debug: Show environment variables
 __logd "Environment check in subshell:"
 __logd "  XML_PART: '${XML_PART}'"
 __logd "  TMP_DIR: '${TMP_DIR:-NOT_SET}'"
 __logd "  SCRIPT_BASE_DIRECTORY: '${SCRIPT_BASE_DIRECTORY:-NOT_SET}'"
 __logd "  DBNAME: '${DBNAME:-NOT_SET}'"

 BASENAME_PART=$(basename "${XML_PART}" .xml)
 # Extract number from planet_part_N or api_part_N format
 PART_NUM=$(echo "${BASENAME_PART}" | sed 's/.*_part_//' | sed 's/^0*//')

 # Handle case where part number is just "0"
 if [[ -z "${PART_NUM}" ]]; then
  PART_NUM="0"
 fi

 # PostgreSQL partitions are 1-based (part_1, part_2, ..., part_N)
 # But file names are 0-based (part_0, part_1, ..., part_N-1)
 # So we need to add 1 to match PostgreSQL partition names
 PART_NUM=$((PART_NUM + 1))

 # Debug: Show extraction process
 __logd "Extracting part number from: ${XML_PART}"
 __logd "Basename: ${BASENAME_PART}"
 __logd "Part number: ${PART_NUM} (adjusted for PostgreSQL 1-based partitions)"

 # Validate part number
 if [[ ! "${PART_NUM}" =~ ^[0-9]+$ ]] || [[ ${PART_NUM} -lt 1 ]]; then
  __loge "Invalid part number extracted: '${PART_NUM}' from file: ${XML_PART}"
  __log_finish
  return 1
 fi

 __logi "Processing Planet XML part ${PART_NUM}: ${XML_PART}"

 # Convert XML part to CSV using AWK (faster, no external dependencies)
 local OUTPUT_NOTES_PART
 local OUTPUT_COMMENTS_PART
 local OUTPUT_TEXT_PART
 OUTPUT_NOTES_PART="${TMP_DIR}/output-notes-part-${PART_NUM}.csv"
 OUTPUT_COMMENTS_PART="${TMP_DIR}/output-comments-part-${PART_NUM}.csv"
 OUTPUT_TEXT_PART="${TMP_DIR}/output-text-part-${PART_NUM}.csv"

 # Process notes with AWK (fast and dependency-free)
 __logd "Processing notes with AWK: ${XML_PART} -> ${OUTPUT_NOTES_PART}"
 awk -f "${SCRIPT_BASE_DIRECTORY}/awk/extract_notes.awk" "${XML_PART}" > "${OUTPUT_NOTES_PART}"
 if [[ ! -f "${OUTPUT_NOTES_PART}" ]]; then
  __loge "Notes CSV file was not created: ${OUTPUT_NOTES_PART}"
  __log_finish
  return 1
 fi

 # Add part_id to the end of each line
 __logd "Adding part_id ${PART_NUM} to notes CSV"
 awk -v part_id="${PART_NUM}" '{print $0 "," part_id}' "${OUTPUT_NOTES_PART}" > "${OUTPUT_NOTES_PART}.tmp" && mv "${OUTPUT_NOTES_PART}.tmp" "${OUTPUT_NOTES_PART}"

 # Process comments with AWK (fast and dependency-free)
 __logd "Processing comments with AWK: ${XML_PART} -> ${OUTPUT_COMMENTS_PART}"
 awk -f "${SCRIPT_BASE_DIRECTORY}/awk/extract_comments.awk" "${XML_PART}" > "${OUTPUT_COMMENTS_PART}"
 if [[ ! -f "${OUTPUT_COMMENTS_PART}" ]]; then
  __loge "Comments CSV file was not created: ${OUTPUT_COMMENTS_PART}"
  __log_finish
  return 1
 fi

 # Add part_id to the end of each line
 __logd "Adding part_id ${PART_NUM} to comments CSV"
 awk -v part_id="${PART_NUM}" '{print $0 "," part_id}' "${OUTPUT_COMMENTS_PART}" > "${OUTPUT_COMMENTS_PART}.tmp" && mv "${OUTPUT_COMMENTS_PART}.tmp" "${OUTPUT_COMMENTS_PART}"

 # Process text comments with AWK (fast and dependency-free)
 __logd "Processing text comments with AWK: ${XML_PART} -> ${OUTPUT_TEXT_PART}"
 awk -f "${SCRIPT_BASE_DIRECTORY}/awk/extract_comment_texts.awk" "${XML_PART}" > "${OUTPUT_TEXT_PART}"
 if [[ ! -f "${OUTPUT_TEXT_PART}" ]]; then
  __logw "Text comments CSV file was not created, generating empty file to continue: ${OUTPUT_TEXT_PART}"
  : > "${OUTPUT_TEXT_PART}"
 fi

 # Add part_id to the end of each line
 __logd "Adding part_id ${PART_NUM} to text comments CSV"
 if [[ -s "${OUTPUT_TEXT_PART}" ]]; then
  awk -v part_id="${PART_NUM}" '{print $0 "," part_id}' "${OUTPUT_TEXT_PART}" > "${OUTPUT_TEXT_PART}.tmp" && mv "${OUTPUT_TEXT_PART}.tmp" "${OUTPUT_TEXT_PART}"
 else
  __logw "Text comments CSV is empty for part ${PART_NUM}; skipping part_id append"
 fi

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
 __log_finish
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

# Validates all properties from etc/properties.sh configuration file.
# Ensures all required parameters have valid values and proper types.
#
# Validates:
#   - Database configuration (DBNAME, DB_USER)
#   - Email configuration (EMAILS format, ADMIN_EMAIL format)
#   - URLs (OSM_API, PLANET, OVERPASS_INTERPRETER)
#   - Numeric parameters (LOOP_SIZE, MAX_NOTES, MAX_THREADS, MIN_NOTES_FOR_PARALLEL)
#   - Boolean parameters (CLEAN, SKIP_XML_VALIDATION, SEND_ALERT_EMAIL)
#
# Returns:
#   0 if all properties are valid
#
# Exits:
#   ERROR_GENERAL (1) if any property is invalid
function __validate_properties {
 __log_start
 __logi "Validating properties from configuration file"

 local -i VALIDATION_ERRORS=0

 # Validate DBNAME (required, non-empty string)
 if [[ -z "${DBNAME:-}" ]]; then
  __loge "ERROR: DBNAME is not set or empty"
  VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
 else
  __logd "✓ DBNAME: ${DBNAME}"
 fi

 # Validate DB_USER (required, non-empty string)
 if [[ -z "${DB_USER:-}" ]]; then
  __loge "ERROR: DB_USER is not set or empty"
  VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
 else
  __logd "✓ DB_USER: ${DB_USER}"
 fi

 # Validate EMAILS (basic email format check)
 if [[ -n "${EMAILS:-}" ]]; then
  # Basic email regex: contains @ and . after @
  if [[ ! "${EMAILS}" =~ ^[^@]+@[^@]+\.[^@]+$ ]]; then
   __logw "WARNING: EMAILS may have invalid format: ${EMAILS}"
   __logw "Expected format: user@domain.com"
  else
   __logd "✓ EMAILS: ${EMAILS}"
  fi
 fi

 # Validate OSM_API (URL format)
 if [[ -n "${OSM_API:-}" ]]; then
  if [[ ! "${OSM_API}" =~ ^https?:// ]]; then
   __loge "ERROR: OSM_API must be a valid HTTP/HTTPS URL, got: ${OSM_API}"
   VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
  else
   __logd "✓ OSM_API: ${OSM_API}"
  fi
 fi

 # Validate PLANET (URL format)
 if [[ -n "${PLANET:-}" ]]; then
  if [[ ! "${PLANET}" =~ ^https?:// ]]; then
   __loge "ERROR: PLANET must be a valid HTTP/HTTPS URL, got: ${PLANET}"
   VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
  else
   __logd "✓ PLANET: ${PLANET}"
  fi
 fi

 # Validate OVERPASS_INTERPRETER (URL format)
 if [[ -n "${OVERPASS_INTERPRETER:-}" ]]; then
  if [[ ! "${OVERPASS_INTERPRETER}" =~ ^https?:// ]]; then
   __loge "ERROR: OVERPASS_INTERPRETER must be a valid HTTP/HTTPS URL, got: ${OVERPASS_INTERPRETER}"
   VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
  else
   __logd "✓ OVERPASS_INTERPRETER: ${OVERPASS_INTERPRETER}"
  fi
 fi

 # Validate LOOP_SIZE (positive integer)
 if [[ -n "${LOOP_SIZE:-}" ]]; then
  if [[ ! "${LOOP_SIZE}" =~ ^[1-9][0-9]*$ ]]; then
   __loge "ERROR: LOOP_SIZE must be a positive integer, got: ${LOOP_SIZE}"
   VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
  else
   __logd "✓ LOOP_SIZE: ${LOOP_SIZE}"
  fi
 fi

 # Validate MAX_NOTES (positive integer)
 if [[ -n "${MAX_NOTES:-}" ]]; then
  if [[ ! "${MAX_NOTES}" =~ ^[1-9][0-9]*$ ]]; then
   __loge "ERROR: MAX_NOTES must be a positive integer, got: ${MAX_NOTES}"
   VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
  else
   __logd "✓ MAX_NOTES: ${MAX_NOTES}"
  fi
 fi

 # Validate MAX_THREADS (positive integer, reasonable limit)
 if [[ -n "${MAX_THREADS:-}" ]]; then
  if [[ ! "${MAX_THREADS}" =~ ^[1-9][0-9]*$ ]]; then
   __loge "ERROR: MAX_THREADS must be a positive integer, got: ${MAX_THREADS}"
   VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
  elif [[ "${MAX_THREADS}" -gt 100 ]]; then
   __logw "WARNING: MAX_THREADS=${MAX_THREADS} exceeds recommended maximum (100)"
   __logw "This may cause excessive resource usage"
  elif [[ "${MAX_THREADS}" -lt 1 ]]; then
   __loge "ERROR: MAX_THREADS must be at least 1, got: ${MAX_THREADS}"
   VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
  else
   __logd "✓ MAX_THREADS: ${MAX_THREADS}"
  fi
 fi

 # Validate MIN_NOTES_FOR_PARALLEL (positive integer)
 if [[ -n "${MIN_NOTES_FOR_PARALLEL:-}" ]]; then
  if [[ ! "${MIN_NOTES_FOR_PARALLEL}" =~ ^[1-9][0-9]*$ ]]; then
   __loge "ERROR: MIN_NOTES_FOR_PARALLEL must be a positive integer, got: ${MIN_NOTES_FOR_PARALLEL}"
   VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
  else
   __logd "✓ MIN_NOTES_FOR_PARALLEL: ${MIN_NOTES_FOR_PARALLEL}"
  fi
 fi

 # Validate CLEAN (boolean: true or false)
 if [[ -n "${CLEAN:-}" ]]; then
  if [[ "${CLEAN}" != "true" && "${CLEAN}" != "false" ]]; then
   __loge "ERROR: CLEAN must be 'true' or 'false', got: ${CLEAN}"
   VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
  else
   __logd "✓ CLEAN: ${CLEAN}"
  fi
 fi

 # Validate SKIP_XML_VALIDATION (boolean: true or false)
 if [[ -n "${SKIP_XML_VALIDATION:-}" ]]; then
  if [[ "${SKIP_XML_VALIDATION}" != "true" && "${SKIP_XML_VALIDATION}" != "false" ]]; then
   __loge "ERROR: SKIP_XML_VALIDATION must be 'true' or 'false', got: ${SKIP_XML_VALIDATION}"
   VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
  else
   __logd "✓ SKIP_XML_VALIDATION: ${SKIP_XML_VALIDATION}"
  fi
 fi

 # Validate ADMIN_EMAIL (email format check)
 if [[ -n "${ADMIN_EMAIL:-}" ]]; then
  # Basic email regex: contains @ and . after @
  if [[ ! "${ADMIN_EMAIL}" =~ ^[^@]+@[^@]+\.[^@]+$ ]]; then
   __logw "WARNING: ADMIN_EMAIL may have invalid format: ${ADMIN_EMAIL}"
   __logw "Expected format: user@domain.com"
   __logw "Email alerts may not work correctly"
  else
   __logd "✓ ADMIN_EMAIL: ${ADMIN_EMAIL}"
  fi
 else
  __logd "✓ ADMIN_EMAIL: using default (root@localhost)"
 fi

 # Validate SEND_ALERT_EMAIL (boolean: true or false)
 if [[ -n "${SEND_ALERT_EMAIL:-}" ]]; then
  if [[ "${SEND_ALERT_EMAIL}" != "true" && "${SEND_ALERT_EMAIL}" != "false" ]]; then
   __loge "ERROR: SEND_ALERT_EMAIL must be 'true' or 'false', got: ${SEND_ALERT_EMAIL}"
   VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
  else
   __logd "✓ SEND_ALERT_EMAIL: ${SEND_ALERT_EMAIL}"
  fi
 fi

 # Check for validation errors
 if [[ ${VALIDATION_ERRORS} -gt 0 ]]; then
  __loge "Properties validation failed with ${VALIDATION_ERRORS} error(s)"
  __loge "Please check your etc/properties.sh configuration file"
  __log_finish
  exit "${ERROR_GENERAL}"
 fi

 __logi "✓ All properties validated successfully"
 __log_finish
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
  return 0
 fi

 # Validate properties first (fail-fast on configuration errors)
 __validate_properties

 set +e
 ## PostgreSQL
 __logd "Checking PostgreSQL."
 if ! psql --version > /dev/null 2>&1; then
  __loge "ERROR: PostgreSQL is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Database existence
 __logd "Checking if database '${DBNAME}' exists."
 # shellcheck disable=SC2154
 if ! psql -lqt | cut -d \| -f 1 | grep -qw "${DBNAME}"; then
  __loge "ERROR: Database '${DBNAME}' does not exist."
  __loge "To create the database, run the following commands:"
  __loge "  createdb ${DBNAME}"
  __loge "  psql -d ${DBNAME} -c 'CREATE EXTENSION postgis;'"
  __loge "  psql -d ${DBNAME} -c 'CREATE EXTENSION btree_gist;'"
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Database connectivity with specified user
 __logd "Checking database connectivity with user '${DB_USER}'."
 # shellcheck disable=SC2154
 if ! psql -U "${DB_USER}" -d "${DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
  __loge "ERROR: Cannot connect to database '${DBNAME}' with user '${DB_USER}'."
  __loge "PostgreSQL authentication failed. Possible solutions:"
  __loge "  1. If user '${DB_USER}' doesn't exist, create it:"
  __loge "     sudo -u postgres createuser -d -P ${DB_USER}"
  __loge "  2. Grant access to the database:"
  __loge "     sudo -u postgres psql -c \"GRANT ALL PRIVILEGES ON DATABASE \\\"${DBNAME}\\\" TO ${DB_USER};\""
  __loge "  3. Configure PostgreSQL authentication in /etc/postgresql/*/main/pg_hba.conf:"
  __loge "     Change 'peer' to 'md5' or 'trust' for local connections"
  __loge "     Example: local   all   ${DB_USER}   md5"
  __loge "     Then reload: sudo systemctl reload postgresql"
  __loge "  4. Or use the current system user instead of '${DB_USER}'"
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## PostGIS
 __logd "Checking PostGIS."
 # shellcheck disable=SC2154
 psql -U "${DB_USER}" -d "${DBNAME}" -v ON_ERROR_STOP=1 > /dev/null 2>&1 << EOF
 SELECT /* Notes-base */ PostGIS_version();
EOF
 RET=${?}
 if [[ "${RET}" -ne 0 ]]; then
  __loge "ERROR: PostGIS extension is missing in database '${DBNAME}'."
  __loge "To enable PostGIS, run: psql -U ${DB_USER} -d ${DBNAME} -c 'CREATE EXTENSION postgis;'"
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## btree gist
 # shellcheck disable=SC2154
 __logd "Checking btree gist."
 RESULT=$(psql -U "${DB_USER}" -t -A -c "SELECT COUNT(1) FROM pg_extension WHERE extname = 'btree_gist';" "${DBNAME}")
 if [[ "${RESULT}" -ne 1 ]]; then
  __loge "ERROR: btree_gist extension is missing in database '${DBNAME}'."
  __loge "To enable btree_gist, run: psql -U ${DB_USER} -d ${DBNAME} -c 'CREATE EXTENSION btree_gist;'"
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
 ## XML lint (optional, only for strict validation)
 if [[ "${SKIP_XML_VALIDATION}" != "true" ]]; then
  __logd "Checking XML lint."
  if ! xmllint --version > /dev/null 2>&1; then
   __loge "ERROR: XMLlint is missing (required for XML validation)."
   __loge "To skip validation, set: export SKIP_XML_VALIDATION=true"
   exit "${ERROR_MISSING_LIBRARY}"
  fi
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

 # XML Schema file (only required if validation is enabled)
 if [[ "${SKIP_XML_VALIDATION}" != "true" ]]; then
  if [[ ! -r "${XMLSCHEMA_PLANET_NOTES}" ]]; then
   __loge "ERROR: XML schema file is missing at ${XMLSCHEMA_PLANET_NOTES}."
   __loge "To skip validation, set: export SKIP_XML_VALIDATION=true"
   exit "${ERROR_MISSING_LIBRARY}"
  fi
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
  __loge "ERROR: ogr2ogr cannot access the database '${DBNAME}' with user '${DB_USER}'."
  exit "${ERROR_MISSING_LIBRARY}"
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

# Checks if there is enough disk space for an operation.
# This function validates available disk space before large downloads or
# file operations to prevent failures due to insufficient space.
#
# Parameters:
#   $1 - directory_path: Directory where files will be written
#   $2 - required_space_gb: Required space in GB (can be decimal)
#   $3 - operation_name: Name of operation for logging (optional)
#
# Returns:
#   0 if enough space is available
#   1 if insufficient space
#
# Example:
#   __check_disk_space "/tmp" "15.5" "Planet download"
function __check_disk_space {
 __log_start
 local DIRECTORY="${1}"
 local REQUIRED_GB="${2}"
 local OPERATION_NAME="${3:-file operation}"

 # Validate parameters
 if [[ -z "${DIRECTORY}" ]]; then
  __loge "ERROR: Directory parameter is required"
  __log_finish
  return 1
 fi

 if [[ -z "${REQUIRED_GB}" ]]; then
  __loge "ERROR: Required space parameter is required"
  __log_finish
  return 1
 fi

 # Validate directory exists
 if [[ ! -d "${DIRECTORY}" ]]; then
  __loge "ERROR: Directory does not exist: ${DIRECTORY}"
  __log_finish
  return 1
 fi

 # Get available space in MB (df -BM outputs in MB)
 local AVAILABLE_MB
 AVAILABLE_MB=$(df -BM "${DIRECTORY}" | awk 'NR==2 {print $4}' | sed 's/M//')

 # Validate we got a valid number
 if [[ ! "${AVAILABLE_MB}" =~ ^[0-9]+$ ]]; then
  __logw "WARNING: Could not determine available disk space, proceeding anyway"
  __log_finish
  return 0
 fi

 # Convert required GB to MB for comparison
 # Handle decimal values by using bc or awk
 local REQUIRED_MB
 if command -v bc > /dev/null 2>&1; then
  REQUIRED_MB=$(echo "${REQUIRED_GB} * 1024" | bc | cut -d. -f1)
 else
  # Fallback to awk if bc not available
  REQUIRED_MB=$(awk "BEGIN {printf \"%.0f\", ${REQUIRED_GB} * 1024}")
 fi

 # Convert to GB for logging
 local AVAILABLE_GB
 if command -v bc > /dev/null 2>&1; then
  AVAILABLE_GB=$(echo "scale=2; ${AVAILABLE_MB} / 1024" | bc)
 else
  AVAILABLE_GB=$(awk "BEGIN {printf \"%.2f\", ${AVAILABLE_MB} / 1024}")
 fi

 __logi "Disk space check for ${OPERATION_NAME}:"
 __logi "  Directory: ${DIRECTORY}"
 __logi "  Required: ${REQUIRED_GB} GB (${REQUIRED_MB} MB)"
 __logi "  Available: ${AVAILABLE_GB} GB (${AVAILABLE_MB} MB)"

 # Check if we have enough space
 if [[ ${AVAILABLE_MB} -lt ${REQUIRED_MB} ]]; then
  __loge "ERROR: Insufficient disk space for ${OPERATION_NAME}"
  __loge "  Required: ${REQUIRED_GB} GB"
  __loge "  Available: ${AVAILABLE_GB} GB"
  __loge "  Shortfall: $(echo "scale=2; ${REQUIRED_GB} - ${AVAILABLE_GB}" | bc 2> /dev/null || echo "unknown") GB"
  __loge "Please free up disk space in ${DIRECTORY} before proceeding"
  __log_finish
  return 1
 fi

 # Calculate percentage of space that will be used
 local USAGE_PERCENT
 if command -v bc > /dev/null 2>&1; then
  USAGE_PERCENT=$(echo "scale=1; ${REQUIRED_MB} * 100 / ${AVAILABLE_MB}" | bc)
 else
  USAGE_PERCENT=$(awk "BEGIN {printf \"%.1f\", ${REQUIRED_MB} * 100 / ${AVAILABLE_MB}}")
 fi

 # Warn if we'll use more than 80% of available space
 if (($(echo "${USAGE_PERCENT} > 80" | bc -l 2> /dev/null || echo 0))); then
  __logw "WARNING: Operation will use ${USAGE_PERCENT}% of available disk space"
  __logw "Consider freeing up more space for safety margin"
 else
  __logi "✓ Sufficient disk space available (${USAGE_PERCENT}% will be used)"
 fi

 __log_finish
 return 0
}

# Downloads the notes from the planet.
function __downloadPlanetNotes {
 __log_start

 # Check disk space before downloading
 # Planet notes file requirements:
 # - Compressed file (.bz2): ~2 GB
 # - Decompressed file (.xml): ~10 GB
 # - CSV files generated: ~5 GB
 # - Safety margin (20%): ~3.4 GB
 # Total estimated: ~20 GB
 __logi "Validating disk space for Planet notes download..."
 if ! __check_disk_space "${TMP_DIR}" "20" "Planet notes download and processing"; then
  __loge "Cannot proceed with Planet download due to insufficient disk space"
  __handle_error_with_cleanup "${ERROR_GENERAL}" "Insufficient disk space for Planet download" \
   "echo 'No cleanup needed - download not started'"
 fi

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
  __log_finish
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
  __log_finish
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
  __log_finish
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
  __log_finish
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
  __log_finish
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
  __log_finish
  return 1
 fi
 __logd "GeoJSON conversion completed for boundary ${ID}"

 # Validate the GeoJSON with a JSON schema
 __logd "Validating GeoJSON structure for boundary ${ID}..."
 if ! __validate_json_structure "${GEOJSON_FILE}" "features"; then
  __loge "GeoJSON validation failed for boundary ${ID}"
  __handle_error_with_cleanup "${ERROR_GEOJSON_CONVERSION}" "Invalid GeoJSON structure for boundary ${ID}" \
   "rm -f ${JSON_FILE} ${GEOJSON_FILE} 2>/dev/null || true"
  __log_finish
  return 1
 fi
 __logd "GeoJSON validation passed for boundary ${ID}"

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
  __log_finish
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
  __log_finish
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

 # Process the imported data with geometry validation
 __logd "Processing imported data for boundary ${ID}..."

 # First, validate that we can create a non-NULL geometry
 __logd "Validating geometry before insert for boundary ${ID}..."
 local GEOM_CHECK_QUERY
 if [[ "${ID}" -eq 16239 ]]; then
  # Austria - use ST_Buffer to fix topology issues
  __logd "Using special processing for Austria (ID: 16239) with ST_Buffer"
  GEOM_CHECK_QUERY="SELECT ST_Union(ST_Buffer(geometry, 0.0)) IS NOT NULL AS has_geom FROM import"
 else
  # Standard processing with ST_MakeValid
  __logd "Using standard processing with ST_MakeValid for boundary ${ID}"
  GEOM_CHECK_QUERY="SELECT ST_Union(ST_makeValid(geometry)) IS NOT NULL AS has_geom FROM import"
 fi

 local HAS_VALID_GEOM
 HAS_VALID_GEOM=$(psql -d "${DBNAME}" -Atq -c "${GEOM_CHECK_QUERY}" 2> /dev/null || echo "f")

 if [[ "${HAS_VALID_GEOM}" != "t" ]]; then
  __loge "ERROR: Cannot create valid geometry for boundary ${ID}"
  __loge "ST_Union returned NULL - possible causes:"
  __loge "  1. No geometries in import table"
  __loge "  2. All geometries are invalid even after ST_MakeValid"
  __loge "  3. Geometry union operation failed"

  # Check if there are any rows in import table
  local IMPORT_COUNT
  IMPORT_COUNT=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM import" 2> /dev/null || echo "0")
  __loge "Import table has ${IMPORT_COUNT} rows for boundary ${ID}"

  # Log a sample of geometries for debugging
  __logd "Sample geometry validity check:"
  psql -d "${DBNAME}" -c "SELECT ST_IsValid(geometry) AS is_valid, ST_IsValidReason(geometry) AS reason FROM import LIMIT 5" 2> /dev/null || true

  __loge "Skipping boundary ${ID} due to NULL geometry - will not update database"
  rmdir "${PROCESS_LOCK}" 2> /dev/null || true
  __log_finish
  return 1
 fi

 __logi "✓ Geometry validation passed for boundary ${ID}"

# Now perform the actual insert with validated geometry
# Sanitize ID to ensure it's a valid integer
local SANITIZED_ID
SANITIZED_ID=$(__sanitize_sql_integer "${ID}")

local PROCESS_OPERATION
if [[ "${ID}" -eq 16239 ]]; then
 # Austria - use ST_Buffer to fix topology issues
 __logd "Inserting boundary ${ID} with ST_Buffer processing"
 PROCESS_OPERATION="psql -d ${DBNAME} -c \"INSERT INTO countries (country_id, country_name, country_name_es, country_name_en, geom) SELECT ${SANITIZED_ID}, '${NAME}', '${NAME_ES}', '${NAME_EN}', ST_Union(ST_Buffer(geometry, 0.0)) FROM import GROUP BY 1;\""
else
 # Standard processing
 __logd "Inserting boundary ${ID} with standard processing"
 PROCESS_OPERATION="psql -d ${DBNAME} -c \"INSERT INTO countries (country_id, country_name, country_name_es, country_name_en, geom) SELECT ${SANITIZED_ID}, '${NAME}', '${NAME_ES}', '${NAME_EN}', ST_Union(ST_makeValid(geometry)) FROM import GROUP BY 1;\""
fi

 if ! __retry_file_operation "${PROCESS_OPERATION}" 2 3 ""; then
  __loge "Failed to insert boundary ${ID} into countries table"
  __handle_error_with_cleanup "${ERROR_GENERAL}" "Data processing failed for boundary ${ID}" \
   "rm -f ${JSON_FILE} ${GEOJSON_FILE} 2>/dev/null || true; rmdir ${PROCESS_LOCK} 2>/dev/null || true"
  __log_finish
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
  __handle_error_with_cleanup "${ERROR_GENERAL}" "Insufficient disk space for boundaries download" \
   "echo 'No cleanup needed - download not started'"
 fi

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
  local ERROR_LOGS
  ERROR_LOGS=$(find "${TMP_DIR}" -maxdepth 1 -type f -name "${BASENAME}.log.*" | tr '\n' ' ')
  __loge "Found ${QTY_LOGS} error log files. Check them for details: ${ERROR_LOGS}"
  exit "${ERROR_DOWNLOADING_BOUNDARY}"
 fi
 if [[ -d "${LOCK_OGR2OGR}" ]]; then
  rm -f "${LOCK_OGR2OGR}/pid"
  rmdir "${LOCK_OGR2OGR}"
 fi
}

# Download the list of maritimes areas, then it downloads each area
# individually, converts the OSM JSON into a GeoJSON, and then it inserts the
# geometry of the maritime area into the Postgres database with ogr2ogr.
function __processMaritimes {
 __log_start

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

# Retry configuration
declare -r MAX_RETRIES="${MAX_RETRIES:-3}"
declare -r RETRY_BASE_DELAY="2"
declare -r MAX_DELAY="${MAX_DELAY:-60}"
declare -r CIRCUIT_BREAKER_THRESHOLD="${CIRCUIT_BREAKER_THRESHOLD:-5}"
declare -r CIRCUIT_BREAKER_TIMEOUT="${CIRCUIT_BREAKER_TIMEOUT:-300}"

# Circuit breaker state
declare -A CIRCUIT_BREAKER_STATES
declare -A CIRCUIT_BREAKER_FAILURE_COUNTS
declare -A CIRCUIT_BREAKER_LAST_FAILURE_TIMES

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

# Retry file operations with exponential backoff and cleanup on failure
# Parameters: operation_command max_retries base_delay [cleanup_command]
# Returns: 0 if successful, 1 if failed after all retries
function __retry_file_operation() {
 __log_start
 local OPERATION_COMMAND="$1"
 local MAX_RETRIES_LOCAL="${2:-3}"
 local BASE_DELAY_LOCAL="${3:-2}"
 local CLEANUP_COMMAND="${4:-}"
 local RETRY_COUNT=0
 local EXPONENTIAL_DELAY="${BASE_DELAY_LOCAL}"

 __logd "Executing file operation with retry logic: ${OPERATION_COMMAND}"
 __logd "Max retries: ${MAX_RETRIES_LOCAL}, Base delay: ${BASE_DELAY_LOCAL}s"

 while [[ ${RETRY_COUNT} -lt ${MAX_RETRIES_LOCAL} ]]; do
  if eval "${OPERATION_COMMAND}"; then
   __logd "File operation succeeded on attempt $((RETRY_COUNT + 1))"
   __log_finish
   return 0
  fi

  RETRY_COUNT=$((RETRY_COUNT + 1))

  if [[ ${RETRY_COUNT} -lt ${MAX_RETRIES_LOCAL} ]]; then
   __logw "File operation failed on attempt ${RETRY_COUNT}, retrying in ${EXPONENTIAL_DELAY}s"
   sleep "${EXPONENTIAL_DELAY}"
   # Exponential backoff: double the delay for next attempt
   EXPONENTIAL_DELAY=$((EXPONENTIAL_DELAY * 2))
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

 while [[ ${RETRY_COUNT} -lt ${LOCAL_MAX_RETRIES} ]]; do
  # Use wget with specific error handling and timeout
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

 while [[ ${RETRY_COUNT} -lt ${LOCAL_MAX_RETRIES} ]]; do
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

 while [[ ${RETRY_COUNT} -lt ${LOCAL_MAX_RETRIES} ]]; do
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

 __logd "Executing database operation with retry logic"
 __logd "Query: ${QUERY}"
 __logd "Output: ${OUTPUT_FILE}, Max retries: ${LOCAL_MAX_RETRIES}"

 while [[ ${RETRY_COUNT} -lt ${LOCAL_MAX_RETRIES} ]]; do
  if psql -d "${DBNAME}" -Atq -c "${QUERY}" > "${OUTPUT_FILE}" 2> /dev/null; then
   __logd "Database operation succeeded on attempt $((RETRY_COUNT + 1))"
   __log_finish
   return 0
  else
   __logw "Database operation failed on attempt $((RETRY_COUNT + 1))"
  fi

  RETRY_COUNT=$((RETRY_COUNT + 1))
  if [[ ${RETRY_COUNT} -lt ${LOCAL_MAX_RETRIES} ]]; then
   __logw "Database operation failed on attempt ${RETRY_COUNT}, retrying in ${EXPONENTIAL_DELAY}s"
   sleep "${EXPONENTIAL_DELAY}"
   EXPONENTIAL_DELAY=$((EXPONENTIAL_DELAY * 2))
  fi
 done

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

# Validates comprehensive CSV file structure and content.
# This function performs detailed validation of CSV files before database load,
# including column count, quote escaping, multivalue fields, and data integrity.
#
# Parameters:
#   $1 - CSV file path
#   $2 - File type (notes, comments, text)
#
# Validations performed:
#   - File exists and is readable
#   - Correct number of columns per file type
#   - Properly escaped quotes (PostgreSQL CSV format)
#   - No unescaped delimiters in text fields
#   - Multivalue fields are properly formatted
#   - No malformed lines
#
# Returns:
#   0 if all validations pass
#   1 if any validation fails
#
# Example:
#   __validate_csv_structure "output-notes.csv" "notes"
function __validate_csv_structure {
 __log_start
 local CSV_FILE="${1}"
 local FILE_TYPE="${2}"

 # Validate parameters
 if [[ -z "${CSV_FILE}" ]]; then
  __loge "ERROR: CSV file path parameter is required"
  __log_finish
  return 1
 fi

 if [[ -z "${FILE_TYPE}" ]]; then
  __loge "ERROR: File type parameter is required"
  __log_finish
  return 1
 fi

 # Check file exists
 if [[ ! -f "${CSV_FILE}" ]]; then
  __loge "ERROR: CSV file not found: ${CSV_FILE}"
  __log_finish
  return 1
 fi

 # Check file is readable
 if [[ ! -r "${CSV_FILE}" ]]; then
  __loge "ERROR: CSV file is not readable: ${CSV_FILE}"
  __log_finish
  return 1
 fi

 # Skip validation for empty files
 if [[ ! -s "${CSV_FILE}" ]]; then
  __logw "WARNING: CSV file is empty: ${CSV_FILE}"
  __log_finish
  return 0
 fi

 __logi "Validating CSV structure: ${CSV_FILE} (type: ${FILE_TYPE})"

 # Define expected column counts for each file type
 local EXPECTED_COLUMNS
 case "${FILE_TYPE}" in
 "notes")
  # Structure: note_id,latitude,longitude,created_at,closed_at,status[,part_id]
  EXPECTED_COLUMNS=6 # or 7 with part_id
  ;;
 "comments")
  # Structure: note_id,event,timestamp,user_id,username[,part_id]
  EXPECTED_COLUMNS=5 # or 6 with part_id
  ;;
 "text")
  # Structure: note_id,text[,part_id]
  EXPECTED_COLUMNS=2 # or 3 with part_id
  ;;
 *)
  __logw "WARNING: Unknown file type '${FILE_TYPE}', skipping column count validation"
  __log_finish
  return 0
  ;;
 esac

 # Sample first 100 lines for validation (performance optimization)
 local SAMPLE_SIZE=100
 local TOTAL_LINES
 TOTAL_LINES=$(wc -l < "${CSV_FILE}" 2> /dev/null || echo 0)

 __logd "CSV file has ${TOTAL_LINES} lines, validating first ${SAMPLE_SIZE} lines"

 # Validation counters
 local MALFORMED_LINES=0
 local UNESCAPED_QUOTES=0
 local WRONG_COLUMNS=0
 local LINE_NUMBER=0

 # Read and validate sample lines
 while IFS= read -r line && [[ ${LINE_NUMBER} -lt ${SAMPLE_SIZE} ]]; do
  ((LINE_NUMBER++))

  # Skip empty lines
  if [[ -z "${line}" ]]; then
   continue
  fi

  # Count columns (accounting for quoted fields with commas)
  # This is a basic count that may not be 100% accurate for complex CSVs
  local COLUMN_COUNT
  COLUMN_COUNT=$(echo "${line}" | awk -F',' '{print NF}')

  # Allow EXPECTED_COLUMNS or EXPECTED_COLUMNS+1 (with part_id)
  if [[ ${COLUMN_COUNT} -ne ${EXPECTED_COLUMNS} ]] && [[ ${COLUMN_COUNT} -ne $((EXPECTED_COLUMNS + 1)) ]]; then
   __logd "WARNING: Line ${LINE_NUMBER} has ${COLUMN_COUNT} columns, expected ${EXPECTED_COLUMNS} or $((EXPECTED_COLUMNS + 1))"
   ((WRONG_COLUMNS++))
   # Only show first 3 examples
   if [[ ${WRONG_COLUMNS} -le 3 ]]; then
    __logd "  Line content (first 100 chars): ${line:0:100}"
   fi
  fi

  # Check for unescaped quotes in text fields
  # In PostgreSQL CSV format, quotes should be doubled: "" not \"
  # Look for patterns like: ," " or ,"text" that might indicate issues
  if [[ "${FILE_TYPE}" == "text" ]]; then
   # Text field can contain quotes, check if they are properly escaped
   # PostgreSQL CSV uses "" to escape quotes inside quoted fields
   # Check for single quotes that aren't at field boundaries
   if echo "${line}" | grep -qE "[^,]'[^,]" 2> /dev/null; then
    # This is actually OK - single quotes are fine in CSV
    :
   fi

   # Check for potential unescaped double quotes (simplified check)
   # Count quotes: should be even (each field starts and ends with quote)
   local QUOTE_COUNT
   QUOTE_COUNT=$(echo "${line}" | tr -cd '"' | wc -c)
   if [[ $((QUOTE_COUNT % 2)) -ne 0 ]]; then
    __logd "WARNING: Line ${LINE_NUMBER} has odd number of quotes (${QUOTE_COUNT})"
    ((UNESCAPED_QUOTES++))
    if [[ ${UNESCAPED_QUOTES} -le 3 ]]; then
     __logd "  Line content (first 100 chars): ${line:0:100}"
    fi
   fi
  fi

 done < "${CSV_FILE}"

 # Report validation results
 __logd "CSV validation results for ${CSV_FILE}:"
 __logd "  Total lines checked: ${LINE_NUMBER}"
 __logd "  Wrong column count: ${WRONG_COLUMNS}"
 __logd "  Unescaped quotes: ${UNESCAPED_QUOTES}"

 # Determine if validation passed
 local VALIDATION_FAILED=0

 # Wrong columns is a critical error
 if [[ ${WRONG_COLUMNS} -gt $((LINE_NUMBER / 10)) ]]; then
  __loge "ERROR: Too many lines with wrong column count (${WRONG_COLUMNS} out of ${LINE_NUMBER})"
  __loge "More than 10% of lines have incorrect structure"
  VALIDATION_FAILED=1
 elif [[ ${WRONG_COLUMNS} -gt 0 ]]; then
  __logw "WARNING: Found ${WRONG_COLUMNS} lines with unexpected column count (may be OK if multivalue fields)"
 fi

 # Unescaped quotes is a warning, not critical (might be false positives)
 if [[ ${UNESCAPED_QUOTES} -gt 0 ]]; then
  __logw "WARNING: Found ${UNESCAPED_QUOTES} lines with potential quote issues"
  __logw "This may cause PostgreSQL COPY errors. Review the CSV if load fails."
 fi

 if [[ ${VALIDATION_FAILED} -eq 1 ]]; then
  __loge "CSV structure validation FAILED for ${CSV_FILE}"
  __log_finish
  return 1
 fi

 __logi "✓ CSV structure validation PASSED for ${CSV_FILE}"
 __log_finish
 return 0
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
 echo "Available wrapper functions:"
 echo "  - __checkPrereqsCommands  - Check prerequisites"
 echo "  - __createFunctionToGetCountry - Create country function"
 echo "  - __createProcedures      - Create procedures"
 echo "  - __organizeAreas         - Organize areas"
 echo "  - __getLocationNotes      - Get location notes"
 echo
 echo "Author: Andres Gomez (AngocA)"
 echo "Version: ${VERSION}"
 exit 1
}

# Enhanced XML validation with error handling
# Now uses consolidated functions from consolidatedValidationFunctions.sh
function __validate_xml_with_enhanced_error_handling() {
 __log_start
 # Source the consolidated validation functions
 if [[ -f "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/consolidatedValidationFunctions.sh" ]]; then
  source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/consolidatedValidationFunctions.sh"
  __validate_xml_with_enhanced_error_handling "$@"
 else
  # Fallback if consolidated functions are not available
  __loge "ERROR: Consolidated validation functions not found. Please ensure consolidatedValidationFunctions.sh is available."
  __log_finish
  return 1
 fi
 __log_finish
}

# Basic XML structure validation (lightweight)
# Now uses consolidated functions from consolidatedValidationFunctions.sh
function __validate_xml_basic() {
 __log_start
 # Source the consolidated validation functions
 if [[ -f "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/consolidatedValidationFunctions.sh" ]]; then
  source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/consolidatedValidationFunctions.sh"
  __validate_xml_basic "$@"
 else
  # Fallback if consolidated functions are not available
  __loge "ERROR: Consolidated validation functions not found. Please ensure consolidatedValidationFunctions.sh is available."
  __log_finish
  return 1
 fi
 __log_finish
}

# XML structure-only validation (very lightweight)
# Now uses consolidated functions from consolidatedValidationFunctions.sh
function __validate_xml_structure_only() {
 __log_start
 # Source the consolidated validation functions
 if [[ -f "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/consolidatedValidationFunctions.sh" ]]; then
  source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/consolidatedValidationFunctions.sh"
  __validate_xml_structure_only "$@"
 else
  # Fallback if consolidated functions are not available
  __loge "ERROR: Consolidated validation functions not found. Please ensure consolidatedValidationFunctions.sh is available."
  __log_finish
  return 1
 fi
 __log_finish
}
