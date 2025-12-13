#!/bin/bash

# Process API Functions for OSM-Notes-profile
# This file contains functions for processing API data.
#
# Author: Andres Gomez (AngocA)
# Version: 2025-12-13
VERSION="2025-12-13"

# Show help function
function __show_help() {
 echo "Process API Functions for OSM-Notes-profile"
 echo "This file contains functions for processing API data."
 echo
 echo "Usage: source bin/lib/processAPIFunctions.sh"
 echo
 echo "Available functions:"
 echo "  __getNewNotesFromApi     - Download new notes from API"
 echo "  __createApiTables         - Create API tables"
 echo "  __createPropertiesTable   - Create properties table"
 echo "  __createProcedures        - Create procedures"
 echo "  __loadApiNotes            - Load API notes"
 echo "  __insertNewNotesAndComments - Insert new notes and comments"
 echo "  __loadApiTextComments     - Load API text comments"
 echo "  __updateLastValue         - Update last value"
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

# XML Schema for strict validation (optional, only used if SKIP_XML_VALIDATION=false)
# shellcheck disable=SC2034
if [[ -z "${XMLSCHEMA_API_NOTES:-}" ]]; then
 declare -r XMLSCHEMA_API_NOTES="${SCRIPT_BASE_DIRECTORY}/xsd/OSM-notes-API-schema.xsd"
fi

# PostgreSQL SQL script files for API
# shellcheck disable=SC2034
if [[ -z "${POSTGRES_12_DROP_API_TABLES:-}" ]]; then declare -r POSTGRES_12_DROP_API_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_12_dropApiTables.sql"; fi
if [[ -z "${POSTGRES_21_CREATE_API_TABLES:-}" ]]; then declare -r POSTGRES_21_CREATE_API_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_21_createApiTables.sql"; fi
if [[ -z "${POSTGRES_23_CREATE_PROPERTIES_TABLE:-}" ]]; then declare -r POSTGRES_23_CREATE_PROPERTIES_TABLE="${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_23_createPropertiesTables.sql"; fi
if [[ -z "${POSTGRES_31_LOAD_API_NOTES:-}" ]]; then declare -r POSTGRES_31_LOAD_API_NOTES="${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_31_loadApiNotes.sql"; fi
if [[ -z "${POSTGRES_32_INSERT_NEW_NOTES_AND_COMMENTS:-}" ]]; then declare -r POSTGRES_32_INSERT_NEW_NOTES_AND_COMMENTS="${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_32_insertNewNotesAndComments.sql"; fi
if [[ -z "${POSTGRES_33_INSERT_NEW_TEXT_COMMENTS:-}" ]]; then declare -r POSTGRES_33_INSERT_NEW_TEXT_COMMENTS="${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_33_loadNewTextComments.sql"; fi
if [[ -z "${POSTGRES_34_UPDATE_LAST_VALUES:-}" ]]; then declare -r POSTGRES_34_UPDATE_LAST_VALUES="${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_34_updateLastValues.sql"; fi

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


# Get new notes from API
function __getNewNotesFromApi() {
 __log_start
 __logd "Getting new notes from API."

 local TEMP_FILE
 local LAST_UPDATE
 local REQUEST

 TEMP_FILE=$(mktemp)

 # Check network connectivity
 if ! __check_network_connectivity 10; then
  __loge "Network connectivity check failed"
  __handle_error_with_cleanup "${ERROR_INTERNET_ISSUE}" "Network connectivity failed" \
   "rm -f ${TEMP_FILE} 2>/dev/null || true"
  return "${ERROR_INTERNET_ISSUE}"
 fi

 # Gets the most recent value on the database
 __logi "Retrieving last update from database..."
 __logd "Database: ${DBNAME}"
 local DB_OPERATION="psql -d ${DBNAME} -Atq -c \"SELECT /* Notes-processAPI */ TO_CHAR(timestamp, E'YYYY-MM-DD\\\"T\\\"HH24:MI:SS\\\"Z\\\"') FROM max_note_timestamp\" -v ON_ERROR_STOP=1 > ${TEMP_FILE} 2> /dev/null"
 local CLEANUP_OPERATION="rm -f ${TEMP_FILE} 2>/dev/null || true"

 if ! __retry_file_operation "${DB_OPERATION}" 3 2 "${CLEANUP_OPERATION}"; then
  __loge "Failed to retrieve last update from database after retries"
  __handle_error_with_cleanup "${ERROR_NO_LAST_UPDATE}" "Database query failed" \
   "rm -f ${TEMP_FILE} 2>/dev/null || true"
  return "${ERROR_NO_LAST_UPDATE}"
 fi

 LAST_UPDATE=$(cat "${TEMP_FILE}")
 rm "${TEMP_FILE}"
 __logi "Last update retrieved: ${LAST_UPDATE}"
 if [[ "${LAST_UPDATE}" == "" ]]; then
  __loge "No last update. Please load notes first."
  __handle_error_with_cleanup "${ERROR_NO_LAST_UPDATE}" "No last update found" \
   "rm -f ${API_NOTES_FILE} 2>/dev/null || true"
  return "${ERROR_NO_LAST_UPDATE}"
 fi

 # Gets the values from OSM API with the correct URL including date filter
 # shellcheck disable=SC2153
 REQUEST="${OSM_API}/notes/search.xml?limit=${MAX_NOTES}&closed=-1&sort=updated_at&from=${LAST_UPDATE}"
 __logi "API Request URL: ${REQUEST}"
 __logd "Max notes limit: ${MAX_NOTES}"
 __logi "Downloading notes from OSM API..."

 # Download notes from API with retry logic
 # Use longer timeout for large note downloads (120 seconds)
 # 30 seconds is insufficient for 10,000 notes (can be 12MB+)
 if __retry_osm_api "${REQUEST}" "${API_NOTES_FILE}" 5 2 120; then
  if [[ -s "${API_NOTES_FILE}" ]]; then
   __logi "Successfully downloaded notes from API: ${API_NOTES_FILE}"
   __log_finish
   return 0
  else
   __loge "ERROR: Downloaded file is empty"
   rm -f "${API_NOTES_FILE}"
   __log_finish
   return 1
  fi
 else
  __loge "ERROR: Failed to download notes from API"
  rm -f "${API_NOTES_FILE}"
  __log_finish
  return 1
 fi
}
