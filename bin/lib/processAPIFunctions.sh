#!/bin/bash

# Process API Functions for OSM-Notes-profile
# This file contains functions for processing API data.
#
# Author: Andres Gomez (AngocA)
# Version: 2026-01-19
VERSION="2026-01-19"

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
# shellcheck disable=SC2034,SC2154
# TMP_DIR is defined in etc/properties.sh or environment
if [[ -z "${API_NOTES_FILE:-}" ]]; then declare -r API_NOTES_FILE="${TMP_DIR}/OSM-notes-API.xml"; fi
if [[ -z "${OUTPUT_NOTES_FILE:-}" ]]; then declare -r OUTPUT_NOTES_FILE="${TMP_DIR}/notes.csv"; fi
if [[ -z "${OUTPUT_NOTE_COMMENTS_FILE:-}" ]]; then declare -r OUTPUT_NOTE_COMMENTS_FILE="${TMP_DIR}/note_comments.csv"; fi
if [[ -z "${OUTPUT_TEXT_COMMENTS_FILE:-}" ]]; then declare -r OUTPUT_TEXT_COMMENTS_FILE="${TMP_DIR}/note_comments_text.csv"; fi

# XML Schema for strict validation (optional, only used if SKIP_XML_VALIDATION=false)
# shellcheck disable=SC2034,SC2154
# SCRIPT_BASE_DIRECTORY is defined in the main script
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
  # shellcheck disable=SC2154
  # ERROR_MISSING_LIBRARY is set by the calling script
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
  # shellcheck disable=SC2154
  # ERROR_INTERNET_ISSUE is set by the calling script
  __handle_error_with_cleanup "${ERROR_INTERNET_ISSUE}" "Network connectivity failed" \
   "rm -f ${TEMP_FILE} 2>/dev/null || true"
  return "${ERROR_INTERNET_ISSUE}"
 fi

 # Gets the most recent value on the database
 __logi "Retrieving last update from database..."
 # shellcheck disable=SC2154
 # DBNAME is set by the calling script or environment
 __logd "Database: ${DBNAME}"
 local DB_OPERATION="psql -d ${DBNAME} -Atq -c \"SELECT /* Notes-processAPI */ TO_CHAR(timestamp, E'YYYY-MM-DD\\\"T\\\"HH24:MI:SS\\\"Z\\\"') FROM max_note_timestamp\" -v ON_ERROR_STOP=1 > ${TEMP_FILE} 2> /dev/null"
 local CLEANUP_OPERATION="rm -f ${TEMP_FILE} 2>/dev/null || true"

 if ! __retry_file_operation "${DB_OPERATION}" 3 2 "${CLEANUP_OPERATION}"; then
  __loge "Failed to retrieve last update from database after retries"
  # shellcheck disable=SC2154
  # ERROR_NO_LAST_UPDATE is set by the calling script
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
 # shellcheck disable=SC2153,SC2154
 # OSM_API and MAX_NOTES are set by the calling script or environment
 REQUEST="${OSM_API}/notes/search.xml?limit=${MAX_NOTES}&closed=-1&sort=updated_at&from=${LAST_UPDATE}"
 __logi "API Request URL: ${REQUEST}"
 __logd "Max notes limit: ${MAX_NOTES}"
 __logi "Downloading notes from OSM API..."

 # Download notes from API with retry logic
 # Use longer timeout for large note downloads (120 seconds)
 # 30 seconds is insufficient for 10,000 notes (can be 12MB+)
 if __retry_osm_api "${REQUEST}" "${API_NOTES_FILE}" 5 2 120; then
  # Check if file exists (downloaded successfully)
  if [[ ! -f "${API_NOTES_FILE}" ]]; then
   __loge "ERROR: API notes file was not created after download"
   __log_finish
   return 1
  fi
  
  # File exists - check if it has content (empty XML with just <osm></osm> is valid)
  # An empty file (0 bytes) indicates download failure, but a file with XML structure
  # (even without <note> elements) is valid and indicates 0 notes scenario
  if [[ ! -s "${API_NOTES_FILE}" ]]; then
   __loge "ERROR: Downloaded file is completely empty (0 bytes)"
   rm -f "${API_NOTES_FILE}"
   __log_finish
   return 1
  fi
  
  # File has content - validate it's XML (even if empty of notes)
  # Check if file contains XML structure (at minimum <osm> tag)
  if ! grep -q '<osm' "${API_NOTES_FILE}" 2> /dev/null; then
   __loge "ERROR: Downloaded file does not contain valid XML structure"
   rm -f "${API_NOTES_FILE}"
   __log_finish
   return 1
  fi
  
  # File exists, has content, and contains XML structure - success
  # Even if it has no <note> elements (0 notes scenario), this is valid
  __logi "Successfully downloaded notes from API: ${API_NOTES_FILE}"
  __log_finish
  return 0
 else
  __loge "ERROR: Failed to download notes from API"
  rm -f "${API_NOTES_FILE}"
  __log_finish
  return 1
 fi
}
