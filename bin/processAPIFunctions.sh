#!/bin/bash

# Process API Functions for OSM-Notes-profile
# This file contains functions for processing API data.
#
# Author: Andres Gomez (AngocA)
# Version: 2025-08-13

# Define version variable
VERSION="2025-08-13"

# Show help function
function __show_help() {
 echo "Process API Functions for OSM-Notes-profile"
 echo "This file contains functions for processing API data."
 echo
 echo "Usage: source bin/processAPIFunctions.sh"
 echo
 echo "Available functions:"
 echo "  __getNewNotesFromApi     - Download new notes from API"
 echo "  __processApiXmlPart       - Process API XML part"
 echo "  __createApiTables         - Create API tables"
 echo "  __createPartitions        - Create partitions"
 echo "  __createPropertiesTable   - Create properties table"
 echo "  __createProcedures        - Create procedures"
 echo "  __loadApiNotes            - Load API notes"
 echo "  __insertNewNotesAndComments - Insert new notes and comments"
 echo "  __loadApiTextComments     - Load API text comments"
 echo "  __updateLastValue         - Update last value"
 echo "  __consolidatePartitions   - Consolidate partitions"
 echo
 echo "Author: Andres Gomez (AngocA)"
 echo "Version: ${VERSION}"
 exit 1
}

# shellcheck disable=SC2317,SC2155,SC2034

# API-specific variables
# shellcheck disable=SC2034
if [[ -z "${API_NOTES_FILE:-}" ]]; then declare -r API_NOTES_FILE="${TMP_DIR}/OSM-notes-API.xml"; fi
if [[ -z "${OUTPUT_NOTES_FILE:-}" ]]; then declare -r OUTPUT_NOTES_FILE="${TMP_DIR}/notes.csv"; fi
if [[ -z "${OUTPUT_NOTE_COMMENTS_FILE:-}" ]]; then declare -r OUTPUT_NOTE_COMMENTS_FILE="${TMP_DIR}/note_comments.csv"; fi
if [[ -z "${OUTPUT_TEXT_COMMENTS_FILE:-}" ]]; then declare -r OUTPUT_TEXT_COMMENTS_FILE="${TMP_DIR}/note_comments_text.csv"; fi

# XSLT transformation files for API format
# shellcheck disable=SC2034
if [[ -z "${XSLT_NOTES_API_FILE:-}" ]]; then declare -r XSLT_NOTES_API_FILE="${SCRIPT_BASE_DIRECTORY}/xslt/notes-API-csv.xslt"; fi
if [[ -z "${XSLT_NOTE_COMMENTS_API_FILE:-}" ]]; then declare -r XSLT_NOTE_COMMENTS_API_FILE="${SCRIPT_BASE_DIRECTORY}/xslt/note_comments-API-csv.xslt"; fi
if [[ -z "${XSLT_TEXT_COMMENTS_API_FILE:-}" ]]; then declare -r XSLT_TEXT_COMMENTS_API_FILE="${SCRIPT_BASE_DIRECTORY}/xslt/note_comments_text-API-csv.xslt"; fi

# XML Schema of the API notes file
# shellcheck disable=SC2034
if [[ -z "${XMLSCHEMA_API_NOTES:-}" ]]; then declare -r XMLSCHEMA_API_NOTES="${SCRIPT_BASE_DIRECTORY}/xsd/OSM-notes-API-schema.xsd"; fi

# PostgreSQL SQL script files for API
# shellcheck disable=SC2034
if [[ -z "${POSTGRES_12_DROP_API_TABLES:-}" ]]; then declare -r POSTGRES_12_DROP_API_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_12_dropApiTables.sql"; fi
if [[ -z "${POSTGRES_21_CREATE_API_TABLES:-}" ]]; then declare -r POSTGRES_21_CREATE_API_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_21_createApiTables.sql"; fi
if [[ -z "${POSTGRES_22_CREATE_PARTITIONS:-}" ]]; then declare -r POSTGRES_22_CREATE_PARTITIONS="${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_22_createPartitions.sql"; fi
if [[ -z "${POSTGRES_23_CREATE_PROPERTIES_TABLE:-}" ]]; then declare -r POSTGRES_23_CREATE_PROPERTIES_TABLE="${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_23_createPropertiesTables.sql"; fi
if [[ -z "${POSTGRES_31_LOAD_API_NOTES:-}" ]]; then declare -r POSTGRES_31_LOAD_API_NOTES="${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_31_loadApiNotes.sql"; fi
if [[ -z "${POSTGRES_32_INSERT_NEW_NOTES_AND_COMMENTS:-}" ]]; then declare -r POSTGRES_32_INSERT_NEW_NOTES_AND_COMMENTS="${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_32_insertNewNotesAndComments.sql"; fi
if [[ -z "${POSTGRES_33_INSERT_NEW_TEXT_COMMENTS:-}" ]]; then declare -r POSTGRES_33_INSERT_NEW_TEXT_COMMENTS="${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_33_loadNewTextComments.sql"; fi
if [[ -z "${POSTGRES_34_UPDATE_LAST_VALUES:-}" ]]; then declare -r POSTGRES_34_UPDATE_LAST_VALUES="${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_34_updateLastValues.sql"; fi
if [[ -z "${POSTGRES_35_CONSOLIDATE_PARTITIONS:-}" ]]; then declare -r POSTGRES_35_CONSOLIDATE_PARTITIONS="${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_35_consolidatePartitions.sql"; fi

# Count XML notes for API
function __countXmlNotesAPI() {
 __log_start
 __logd "Counting XML notes for API."

 local XML_FILE="${1}"
 local COUNT

 if [[ ! -f "${XML_FILE}" ]]; then
  __loge "ERROR: XML file not found: ${XML_FILE}"
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 # Use grep for faster counting of large files
 COUNT=$(grep -c '<note' "${XML_FILE}" 2> /dev/null || echo "0")
 __logi "Found ${COUNT} notes in API XML file."
 __log_finish
 echo "${COUNT}"
}

# Split XML for parallel API processing
# Now uses consolidated functions from parallelProcessingFunctions.sh
function __splitXmlForParallelAPI() {
 # Source the consolidated parallel processing functions
 if [[ -f "${SCRIPT_BASE_DIRECTORY}/bin/parallelProcessingFunctions.sh" ]]; then
  source "${SCRIPT_BASE_DIRECTORY}/bin/parallelProcessingFunctions.sh"
  __splitXmlForParallelAPI "$@"
 else
  # Fallback if consolidated functions are not available
  __loge "ERROR: Consolidated parallel processing functions not found. Please ensure parallelProcessingFunctions.sh is available."
  return 1
 fi
}

# Process XML with XSLT for API
function __processXmlWithXsltAPI() {
 __log_start
 __logd "Processing XML with XSLT for API."

 local XML_FILE="${1}"
 local XSLT_FILE="${2:-${XSLT_NOTES_API_FILE}}"
 local OUTPUT_FILE="${3:-${OUTPUT_NOTES_FILE}}"

 if [[ ! -f "${XML_FILE}" ]]; then
  __loge "ERROR: XML file not found: ${XML_FILE}"
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 if [[ ! -f "${XSLT_FILE}" ]]; then
  __loge "ERROR: XSLT file not found: ${XSLT_FILE}"
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 # Create output directory
 mkdir -p "$(dirname "${OUTPUT_FILE}")"

 # Process XML with XSLT
 if xsltproc "${XSLT_FILE}" "${XML_FILE}" > "${OUTPUT_FILE}" 2> /dev/null; then
  __logi "XSLT processing completed successfully."
  __log_finish
  return 0
 else
  __loge "ERROR: XSLT processing failed."
  __log_finish
  return 1
 fi
}

# Get new notes from API
function __getNewNotesFromApi() {
 __log_start
 __logd "Getting new notes from API."

 local TEMP_FILE
 TEMP_FILE=$(mktemp)

 # Check network connectivity
 if ! __check_network_connectivity 10; then
  __loge "Network connectivity check failed"
  __handle_error_with_cleanup "${ERROR_INTERNET_ISSUE}" "Network connectivity failed" \
   "rm -f ${TEMP_FILE} 2>/dev/null || true"
  return "${ERROR_INTERNET_ISSUE}"
 fi

 # Download notes from API
 __logi "Downloading notes from OSM API..."
 if curl -s -o "${TEMP_FILE}" "https://api.openstreetmap.org/api/0.6/notes?limit=10000"; then
  if [[ -s "${TEMP_FILE}" ]]; then
   mv "${TEMP_FILE}" "${API_NOTES_FILE}"
   __logi "Successfully downloaded notes from API: ${API_NOTES_FILE}"
   __log_finish
   return 0
  else
   __loge "ERROR: Downloaded file is empty"
   rm -f "${TEMP_FILE}"
   __log_finish
   return 1
  fi
 else
  __loge "ERROR: Failed to download notes from API"
  rm -f "${TEMP_FILE}"
  __log_finish
  return 1
 fi
}
