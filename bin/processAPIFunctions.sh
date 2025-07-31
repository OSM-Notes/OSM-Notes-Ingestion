#!/bin/bash

# Process API Functions for OSM-Notes-profile
# This file contains functions specific to processAPINotes.sh
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-30

# shellcheck disable=SC2317,SC2155,SC2034

# API-specific variables
# shellcheck disable=SC2034
declare -r API_NOTES_FILE="${TMP_DIR}/OSM-notes-API.xml"
declare -r OUTPUT_NOTES_FILE="${TMP_DIR}/notes.csv"
declare -r OUTPUT_NOTE_COMMENTS_FILE="${TMP_DIR}/note_comments.csv"
declare -r OUTPUT_TEXT_COMMENTS_FILE="${TMP_DIR}/note_comments_text.csv"

# XSLT transformation files for API format
# shellcheck disable=SC2034
declare -r XSLT_NOTES_API_FILE="${SCRIPT_BASE_DIRECTORY}/xslt/notes-API-csv.xslt"
declare -r XSLT_NOTE_COMMENTS_API_FILE="${SCRIPT_BASE_DIRECTORY}/xslt/note_comments-API-csv.xslt"
declare -r XSLT_TEXT_COMMENTS_API_FILE="${SCRIPT_BASE_DIRECTORY}/xslt/note_comments_text-API-csv.xslt"

# XML Schema of the API notes file
# shellcheck disable=SC2034
declare -r XMLSCHEMA_API_NOTES="${SCRIPT_BASE_DIRECTORY}/xsd/OSM-notes-API-schema.xsd"

# PostgreSQL SQL script files for API
# shellcheck disable=SC2034
declare -r POSTGRES_12_DROP_API_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_12_dropApiTables.sql"
declare -r POSTGRES_21_CREATE_API_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_21_createApiTables.sql"
declare -r POSTGRES_22_CREATE_PARTITIONS="${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_22_createPartitions.sql"
declare -r POSTGRES_23_CREATE_PROPERTIES_TABLE="${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_23_createPropertiesTables.sql"
declare -r POSTGRES_31_LOAD_API_NOTES="${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_31_loadApiNotes.sql"
declare -r POSTGRES_32_INSERT_NEW_NOTES_AND_COMMENTS="${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_32_insertNewNotesAndComments.sql"
declare -r POSTGRES_33_INSERT_NEW_TEXT_COMMENTS="${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_33_loadNewTextComments.sql"
declare -r POSTGRES_34_UPDATE_LAST_VALUES="${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_34_updateLastValues.sql"
declare -r POSTGRES_35_CONSOLIDATE_PARTITIONS="${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_35_consolidatePartitions.sql"

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

 COUNT=$(xmllint --xpath "count(//note)" "${XML_FILE}" 2> /dev/null || echo "0")
 __logi "Found ${COUNT} notes in API XML file."
 __log_finish
 echo "${COUNT}"
}

# Split XML for parallel API processing
function __splitXmlForParallelAPI() {
 __log_start
 __logd "Splitting XML for parallel API processing."

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

 # Split XML file
 for ((i = 0; i < NUM_PARTS; i++)); do
  local START_POS=$((i * NOTES_PER_PART + 1))
  local END_POS=$(((i + 1) * NOTES_PER_PART))

  if [[ "${END_POS}" -gt "${TOTAL_NOTES}" ]]; then
   END_POS="${TOTAL_NOTES}"
  fi

  if [[ "${START_POS}" -le "${TOTAL_NOTES}" ]]; then
   local OUTPUT_FILE="${OUTPUT_DIR}/api_part_${i}.xml"

   # Create XML wrapper
   echo '<?xml version="1.0" encoding="UTF-8"?>' > "${OUTPUT_FILE}"
   echo '<osm-notes>' >> "${OUTPUT_FILE}"

   # Extract notes for this part
   for ((j = START_POS; j <= END_POS; j++)); do
    xmllint --xpath "//note[${j}]" "${XML_FILE}" 2> /dev/null >> "${OUTPUT_FILE}" || true
   done

   echo '</osm-notes>' >> "${OUTPUT_FILE}"

   __logd "Created part ${i}: ${OUTPUT_FILE} (notes ${START_POS}-${END_POS})"
  fi
 done

 __logi "XML splitting completed. Created ${NUM_PARTS} parts."
 __log_finish
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
