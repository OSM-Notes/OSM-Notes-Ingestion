#!/bin/bash

# Process API Functions for OSM-Notes-profile
# This file contains functions specific to processAPINotes.sh
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-30

# shellcheck disable=SC2317,SC2155

# API-specific variables
declare -r API_NOTES_FILE="${TMP_DIR}/OSM-notes-API.xml"
declare -r OUTPUT_NOTES_FILE="${TMP_DIR}/notes.csv"
declare -r OUTPUT_NOTE_COMMENTS_FILE="${TMP_DIR}/note_comments.csv"
declare -r OUTPUT_TEXT_COMMENTS_FILE="${TMP_DIR}/note_comments_text.csv"

# XSLT transformation files for API format
declare -r XSLT_NOTES_API_FILE="${SCRIPT_BASE_DIRECTORY}/xslt/notes-API-csv.xslt"
declare -r XSLT_NOTE_COMMENTS_API_FILE="${SCRIPT_BASE_DIRECTORY}/xslt/note_comments-API-csv.xslt"
declare -r XSLT_TEXT_COMMENTS_API_FILE="${SCRIPT_BASE_DIRECTORY}/xslt/note_comments_text-API-csv.xslt"

# XML Schema of the API notes file
declare -r XMLSCHEMA_API_NOTES="${SCRIPT_BASE_DIRECTORY}/xsd/OSM-notes-API-schema.xsd"

# PostgreSQL SQL script files for API
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

 local xml_file="${1}"
 local count

 if [[ ! -f "${xml_file}" ]]; then
  __loge "ERROR: XML file not found: ${xml_file}"
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 count=$(xmllint --xpath "count(//note)" "${xml_file}" 2> /dev/null || echo "0")
 __logi "Found ${count} notes in API XML file."
 __log_finish
 echo "${count}"
}

# Split XML for parallel API processing
function __splitXmlForParallelAPI() {
 __log_start
 __logd "Splitting XML for parallel API processing."

 local xml_file="${1}"
 local num_parts="${2:-4}"
 local output_dir="${3:-${TMP_DIR}}"

 if [[ ! -f "${xml_file}" ]]; then
  __loge "ERROR: XML file not found: ${xml_file}"
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 # Create output directory
 mkdir -p "${output_dir}"

 # Count total notes
 local total_notes
 total_notes=$(xmllint --xpath "count(//note)" "${xml_file}" 2> /dev/null || echo "0")

 if [[ "${total_notes}" -eq 0 ]]; then
  __logw "WARNING: No notes found in XML file."
  return 0
 fi

 # Calculate notes per part
 local notes_per_part
 notes_per_part=$((total_notes / num_parts))
 if [[ $((total_notes % num_parts)) -gt 0 ]]; then
  notes_per_part=$((notes_per_part + 1))
 fi

 __logi "Splitting ${total_notes} notes into ${num_parts} parts (${notes_per_part} notes per part)."

 # Split XML file
 for ((i = 0; i < num_parts; i++)); do
  local start_pos=$((i * notes_per_part + 1))
  local end_pos=$(((i + 1) * notes_per_part))

  if [[ "${end_pos}" -gt "${total_notes}" ]]; then
   end_pos="${total_notes}"
  fi

  if [[ "${start_pos}" -le "${total_notes}" ]]; then
   local output_file="${output_dir}/api_part_${i}.xml"

   # Create XML wrapper
   echo '<?xml version="1.0" encoding="UTF-8"?>' > "${output_file}"
   echo '<osm-notes>' >> "${output_file}"

   # Extract notes for this part
   for ((j = start_pos; j <= end_pos; j++)); do
    xmllint --xpath "//note[${j}]" "${xml_file}" 2> /dev/null >> "${output_file}" || true
   done

   echo '</osm-notes>' >> "${output_file}"

   __logd "Created part ${i}: ${output_file} (notes ${start_pos}-${end_pos})"
  fi
 done

 __logi "XML splitting completed. Created ${num_parts} parts."
 __log_finish
}

# Process API XML part
function __processApiXmlPart() {
 __log_start
 __logd "Processing API XML part."

 local xml_file="${1}"
 local xslt_file="${2:-${XSLT_NOTES_API_FILE}}"
 local output_file="${3:-${OUTPUT_NOTES_FILE}}"

 if [[ ! -f "${xml_file}" ]]; then
  __loge "ERROR: XML file not found: ${xml_file}"
  return 1
 fi

 if [[ ! -f "${xslt_file}" ]]; then
  __loge "ERROR: XSLT file not found: ${xslt_file}"
  return 1
 fi

 # Validate XML structure
 if ! __validate_xml_structure "${xml_file}"; then
  __loge "ERROR: XML validation failed for ${xml_file}"
  return 1
 fi

 # Process XML with XSLT
 __logd "Processing XML with XSLT: ${xml_file} -> ${output_file}"
 if xsltproc "${xslt_file}" "${xml_file}" > "${output_file}" 2> /dev/null; then
  __logi "Successfully processed API XML part: ${xml_file}"
  __log_finish
  return 0
 else
  __loge "ERROR: Failed to process API XML part: ${xml_file}"
  __log_finish
  return 1
 fi
}

# Get new notes from API
function __getNewNotesFromApi() {
 __log_start
 __logd "Getting new notes from API."

 local temp_file
 temp_file=$(mktemp)

 # Check network connectivity
 if ! __check_network_connectivity 10; then
  __loge "Network connectivity check failed"
  __handle_error_with_cleanup "${ERROR_INTERNET_ISSUE}" "Network connectivity failed" \
   "rm -f ${TEMP_FILE} 2>/dev/null || true"
  return "${ERROR_INTERNET_ISSUE}"
 fi

 # Download notes from API
 __logi "Downloading notes from OSM API..."
 if curl -s -o "${temp_file}" "https://api.openstreetmap.org/api/0.6/notes?limit=10000"; then
  if [[ -s "${temp_file}" ]]; then
   mv "${temp_file}" "${API_NOTES_FILE}"
   __logi "Successfully downloaded notes from API: ${API_NOTES_FILE}"
   __log_finish
   return 0
  else
   __loge "ERROR: Downloaded file is empty"
   rm -f "${temp_file}"
   __log_finish
   return 1
  fi
 else
  __loge "ERROR: Failed to download notes from API"
  rm -f "${temp_file}"
  __log_finish
  return 1
 fi
}
