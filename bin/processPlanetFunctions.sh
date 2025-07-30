#!/bin/bash

# Process Planet Functions for OSM-Notes-profile
# This file contains functions specific to processPlanetNotes.sh
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-30

# shellcheck disable=SC2317,SC2155,SC2034

# Planet-specific variables
# shellcheck disable=SC2034
declare -r PLANET_NOTES_FILE="${TMP_DIR}/OSM-notes-planet.xml"
declare -r COUNTRIES_FILE="${TMP_DIR}/countries"
declare -r MARITIMES_FILE="${TMP_DIR}/maritimes"
declare OVERPASS_QUERY_FILE="${TMP_DIR}/query"

# XSLT transformation files for Planet format
# shellcheck disable=SC2034
declare -r XSLT_NOTES_PLANET_FILE="${SCRIPT_BASE_DIRECTORY}/xslt/notes-Planet-csv.xslt"
declare -r XSLT_NOTE_COMMENTS_PLANET_FILE="${SCRIPT_BASE_DIRECTORY}/xslt/note_comments-Planet-csv.xslt"
declare -r XSLT_TEXT_COMMENTS_PLANET_FILE="${SCRIPT_BASE_DIRECTORY}/xslt/note_comments_text-Planet-csv.xslt"

# XML Schema of the Planet notes file
# shellcheck disable=SC2034
declare -r XMLSCHEMA_PLANET_NOTES="${SCRIPT_BASE_DIRECTORY}/xsd/OSM-notes-planet-schema.xsd"

# PostgreSQL SQL script files for Planet
# shellcheck disable=SC2034
declare -r POSTGRES_11_DROP_SYNC_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_11_dropSyncTables.sql"
declare -r POSTGRES_12_DROP_API_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_12_dropApiTables.sql"
declare -r POSTGRES_13_DROP_BASE_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_13_dropBaseTables.sql"
declare -r POSTGRES_14_DROP_COUNTRY_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_14_dropCountryTables.sql"
declare -r POSTGRES_21_CREATE_ENUMS="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_21_createBaseTables_enum.sql"
declare -r POSTGRES_22_CREATE_BASE_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_22_createBaseTables_tables.sql"
declare -r POSTGRES_23_CREATE_CONSTRAINTS="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_23_createBaseTables_constraints.sql"
declare -r POSTGRES_24_CREATE_SYNC_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_24_createSyncTables.sql"
declare -r POSTGRES_25_CREATE_PARTITIONS="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_25_createPartitions.sql"
declare -r POSTGRES_26_CREATE_COUNTRY_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_25_createCountryTables.sql"
declare -r POSTGRES_31_VACUUM_AND_ANALYZE="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_31_analyzeVacuum.sql"
declare -r POSTGRES_41_LOAD_PARTITIONED_SYNC_NOTES="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_41_loadPartitionedSyncNotes.sql"
declare -r POSTGRES_42_CONSOLIDATE_PARTITIONS="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_42_consolidatePartitions.sql"

# Count XML notes for Planet
function __countXmlNotesPlanet() {
 __log_start
 __logd "Counting XML notes for Planet."

 local xml_file="${1}"
 local count

 if [[ ! -f "${xml_file}" ]]; then
  __loge "ERROR: XML file not found: ${xml_file}"
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 count=$(xmllint --xpath "count(//note)" "${xml_file}" 2> /dev/null || echo "0")
 __logi "Found ${count} notes in Planet XML file."
 __log_finish
 echo "${count}"
}

# Split XML for parallel Planet processing
function __splitXmlForParallelPlanet() {
 __log_start
 __logd "Splitting XML for parallel Planet processing."

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
   local output_file="${output_dir}/planet_part_${i}.xml"

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

# Split XML for parallel processing (safe version)
function __splitXmlForParallelSafe() {
 __log_start
 __logd "Splitting XML for parallel processing (safe version)."

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

 # Split XML file safely
 for ((i = 0; i < num_parts; i++)); do
  local start_pos=$((i * notes_per_part + 1))
  local end_pos=$(((i + 1) * notes_per_part))

  if [[ "${end_pos}" -gt "${total_notes}" ]]; then
   end_pos="${total_notes}"
  fi

  if [[ "${start_pos}" -le "${total_notes}" ]]; then
   local output_file="${output_dir}/safe_part_${i}.xml"

   # Create XML wrapper
   echo '<?xml version="1.0" encoding="UTF-8"?>' > "${output_file}"
   echo '<osm-notes>' >> "${output_file}"

   # Extract notes for this part safely
   for ((j = start_pos; j <= end_pos; j++)); do
    xmllint --xpath "//note[${j}]" "${xml_file}" 2> /dev/null >> "${output_file}" || true
   done

   echo '</osm-notes>' >> "${output_file}"

   __logd "Created safe part ${i}: ${output_file} (notes ${start_pos}-${end_pos})"
  fi
 done

 __logi "XML splitting completed safely. Created ${num_parts} parts."
 __log_finish
}

# Process XML parts in parallel
function __processXmlPartsParallel() {
 __log_start
 __logd "Processing XML parts in parallel."

 local input_dir="${1}"
 local xslt_file="${2}"
 local output_dir="${3}"
 local max_workers="${4:-4}"

 if [[ ! -d "${input_dir}" ]]; then
  __loge "ERROR: Input directory not found: ${input_dir}"
  return 1
 fi

 if [[ ! -f "${xslt_file}" ]]; then
  __loge "ERROR: XSLT file not found: ${xslt_file}"
  return 1
 fi

 # Create output directory
 mkdir -p "${output_dir}"

 # Find all XML parts
 local xml_files
 mapfile -t xml_files < <(find "${input_dir}" -name "*.xml" -type f)

 if [[ ${#xml_files[@]} -eq 0 ]]; then
  __logw "WARNING: No XML files found in ${input_dir}"
  return 0
 fi

 __logi "Processing ${#xml_files[@]} XML parts with max ${max_workers} workers."

 # Process files in parallel
 local pids=()
 local processed=0

 for xml_file in "${xml_files[@]}"; do
  local base_name
  base_name=$(basename "${xml_file}" .xml)
  local output_file="${output_dir}/${base_name}.csv"

  # Process XML file
  if xsltproc "${xslt_file}" "${xml_file}" > "${output_file}" 2> /dev/null; then
   __logd "Successfully processed: ${xml_file} -> ${output_file}"
   ((processed++))
  else
   __loge "ERROR: Failed to process: ${xml_file}"
  fi

  # Limit concurrent processes
  if [[ ${#pids[@]} -ge ${max_workers} ]]; then
   wait "${pids[0]}"
   pids=("${pids[@]:1}")
  fi
 done

 # Wait for remaining processes
 for pid in "${pids[@]}"; do
  wait "${pid}"
 done

 __logi "Parallel processing completed. Processed ${processed}/${#xml_files[@]} files."
 __log_finish
}

# Process Planet XML part
function __processPlanetXmlPart() {
 __log_start
 __logd "Processing Planet XML part."

 local xml_file="${1}"
 local xslt_file="${2:-${XSLT_NOTES_PLANET_FILE}}"
 local output_file="${3:-${OUTPUT_NOTES_CSV_FILE}}"

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
  __logi "Successfully processed Planet XML part: ${xml_file}"
  __log_finish
  return 0
 else
  __loge "ERROR: Failed to process Planet XML part: ${xml_file}"
  __log_finish
  return 1
 fi
}

# Download Planet notes
function __downloadPlanetNotes() {
 __log_start
 __logd "Downloading Planet notes."

 local temp_file
 temp_file=$(mktemp)

 # Check network connectivity
 if ! __check_network_connectivity 10; then
  __loge "Network connectivity check failed"
  __handle_error_with_cleanup "${ERROR_INTERNET_ISSUE}" "Network connectivity failed" \
   "rm -f ${TEMP_FILE} 2>/dev/null || true"
  return "${ERROR_INTERNET_ISSUE}"
 fi

 # Download Planet notes
 __logi "Downloading Planet notes from OSM..."
 if wget -q -O "${temp_file}" "https://planet.openstreetmap.org/notes/notes-latest.osn.bz2"; then
  if [[ -s "${temp_file}" ]]; then
   # Decompress and move
   if bunzip2 -c "${temp_file}" > "${PLANET_NOTES_FILE}" 2> /dev/null; then
    rm -f "${temp_file}"
    __logi "Successfully downloaded and decompressed Planet notes: ${PLANET_NOTES_FILE}"
    __log_finish
    return 0
   else
    __loge "ERROR: Failed to decompress Planet notes"
    rm -f "${temp_file}"
    __log_finish
    return 1
   fi
  else
   __loge "ERROR: Downloaded file is empty"
   rm -f "${temp_file}"
   __log_finish
   return 1
  fi
 else
  __loge "ERROR: Failed to download Planet notes"
  rm -f "${temp_file}"
  __log_finish
  return 1
 fi
}

# Validate Planet notes XML file
function __validatePlanetNotesXMLFile() {
 __log_start
 __logd "Validating Planet notes XML file."

 if [[ ! -f "${PLANET_NOTES_FILE}" ]]; then
  __loge "ERROR: Planet notes file not found: ${PLANET_NOTES_FILE}"
  return 1
 fi

 # Validate XML structure
 if ! __validate_xml_structure "${PLANET_NOTES_FILE}"; then
  __loge "ERROR: XML structure validation failed"
  return 1
 fi

 # Validate against schema if available
 if [[ -f "${XMLSCHEMA_PLANET_NOTES}" ]]; then
  if xmllint --schema "${XMLSCHEMA_PLANET_NOTES}" "${PLANET_NOTES_FILE}" > /dev/null 2>&1; then
   __logi "XML schema validation passed"
  else
   __logw "WARNING: XML schema validation failed, but continuing"
  fi
 fi

 __logi "Planet notes XML file validation completed successfully."
 __log_finish
}

# Process boundary
function __processBoundary() {
 __log_start
 __logd "Processing boundary."

 local boundary_file="${1}"
 local table_name="${2}"

 if [[ ! -f "${boundary_file}" ]]; then
  __loge "ERROR: Boundary file not found: ${boundary_file}"
  return 1
 fi

 # Import boundary using ogr2ogr
 __logd "Importing boundary: ${boundary_file} -> ${table_name}"
 if ogr2ogr -f "PostgreSQL" "PG:dbname=${DBNAME}" "${boundary_file}" \
  -nln "${table_name}" -nlt PROMOTE_TO_MULTI -a_srs EPSG:4326 \
  -lco GEOMETRY_NAME=geom -lco FID=id --config PG_USE_COPY YES 2> /dev/null; then
  __logi "Successfully imported boundary: ${table_name}"
  __log_finish
  return 0
 else
  __loge "ERROR: Failed to import boundary: ${table_name}"
  __log_finish
  return 1
 fi
}

# Process list
function __processList() {
 __log_start
 __logd "Processing list."

 local list_file="${1}"
 local table_name="${2}"

 if [[ ! -f "${list_file}" ]]; then
  __loge "ERROR: List file not found: ${list_file}"
  return 1
 fi

 # Import list using ogr2ogr
 __logd "Importing list: ${list_file} -> ${table_name}"
 if ogr2ogr -f "PostgreSQL" "PG:dbname=${DBNAME}" "${list_file}" \
  -nln "${table_name}" -nlt PROMOTE_TO_MULTI -a_srs EPSG:4326 \
  -lco GEOMETRY_NAME=geom -lco FID=id --config PG_USE_COPY YES 2> /dev/null; then
  __logi "Successfully imported list: ${table_name}"
  __log_finish
  return 0
 else
  __loge "ERROR: Failed to import list: ${table_name}"
  __log_finish
  return 1
 fi
}

# Process countries
function __processCountries() {
 __log_start
 __logd "Processing countries."

 # Download countries boundary
 __logi "Downloading countries boundary..."
 if wget -q -O "${COUNTRIES_FILE}.json" "https://overpass-api.de/api/interpreter?data=[out:json];relation[\"admin_level\"=\"2\"][\"boundary\"=\"administrative\"];out geom;"; then
  if [[ -s "${COUNTRIES_FILE}.json" ]]; then
   # Convert to GeoJSON
   if jq -c '.features[] | {type: "Feature", properties: {name: .properties.name, id: .properties.id}, geometry: .geometry}' \
    "${COUNTRIES_FILE}.json" > "${COUNTRIES_FILE}.geojson" 2> /dev/null; then
    # Import to database
    if __processBoundary "${COUNTRIES_FILE}.geojson" "countries"; then
     __logi "Successfully processed countries boundary"
     __log_finish
     return 0
    else
     __loge "ERROR: Failed to import countries boundary"
     __log_finish
     return 1
    fi
   else
    __loge "ERROR: Failed to convert countries to GeoJSON"
    __log_finish
    return 1
   fi
  else
   __loge "ERROR: Downloaded countries file is empty"
   __log_finish
   return 1
  fi
 else
  __loge "ERROR: Failed to download countries boundary"
  __log_finish
  return 1
 fi
}

# Process maritimes
function __processMaritimes() {
 __log_start
 __logd "Processing maritimes."

 # Download maritime boundaries
 __logi "Downloading maritime boundaries..."
 if wget -q -O "${MARITIMES_FILE}.json" "https://overpass-api.de/api/interpreter?data=[out:json];relation[\"boundary\"=\"maritime\"];out geom;"; then
  if [[ -s "${MARITIMES_FILE}.json" ]]; then
   # Convert to GeoJSON
   if jq -c '.features[] | {type: "Feature", properties: {name: .properties.name, id: .properties.id}, geometry: .geometry}' \
    "${MARITIMES_FILE}.json" > "${MARITIMES_FILE}.geojson" 2> /dev/null; then
    # Import to database
    if __processBoundary "${MARITIMES_FILE}.geojson" "maritimes"; then
     __logi "Successfully processed maritime boundaries"
     __log_finish
     return 0
    else
     __loge "ERROR: Failed to import maritime boundaries"
     __log_finish
     return 1
    fi
   else
    __loge "ERROR: Failed to convert maritimes to GeoJSON"
    __log_finish
    return 1
   fi
  else
   __loge "ERROR: Downloaded maritimes file is empty"
   __log_finish
   return 1
  fi
 else
  __loge "ERROR: Failed to download maritime boundaries"
  __log_finish
  return 1
 fi
}
