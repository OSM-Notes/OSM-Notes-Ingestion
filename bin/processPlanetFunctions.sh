#!/bin/bash

# Process Planet Functions for OSM-Notes-profile
# This file contains functions for processing Planet data.
#
# Author: Andres Gomez (AngocA)
# Version: 2025-08-04

# Show help function
function __show_help() {
 echo "Process Planet Functions for OSM-Notes-profile"
 echo "This file contains functions for processing Planet data."
 echo
 echo "Usage: source bin/processPlanetFunctions.sh"
 echo
 echo "Available functions:"
 echo "  __downloadPlanetNotes      - Download Planet notes"
 echo "  __processPlanetXmlPart     - Process Planet XML part"
 echo "  __createBaseTables         - Create base tables"
 echo "  __createSyncTables         - Create sync tables"
 echo "  __createCountryTables      - Create country tables"
 echo "  __createPartitions         - Create partitions"
 echo "  __loadPartitionedSyncNotes - Load partitioned sync notes"
 echo "  __consolidatePartitions    - Consolidate partitions"
 echo "  __moveSyncToMain           - Move sync to main"
 echo "  __removeDuplicates         - Remove duplicates"
 echo "  __loadTextComments         - Load text comments"
 echo "  __objectsTextComments      - Objects text comments"
 echo
 echo "Author: Andres Gomez (AngocA)"
 echo "Version: 2025-08-04"
 exit 1
}

# shellcheck disable=SC2317,SC2155,SC2034

# Planet-specific variables
# shellcheck disable=SC2034
if [[ -z "${PLANET_NOTES_FILE:-}" ]]; then
 declare -r PLANET_NOTES_FILE="${TMP_DIR}/OSM-notes-planet.xml"
fi

if [[ -z "${COUNTRIES_FILE:-}" ]]; then
 declare -r COUNTRIES_FILE="${TMP_DIR}/countries"
fi

if [[ -z "${MARITIMES_FILE:-}" ]]; then
 declare -r MARITIMES_FILE="${TMP_DIR}/maritimes"
fi
# shellcheck disable=SC2034
declare OVERPASS_QUERY_FILE="${TMP_DIR}/query"

# XSLT transformation files for Planet format
# shellcheck disable=SC2034
if [[ -z "${XSLT_NOTES_PLANET_FILE:-}" ]]; then declare -r XSLT_NOTES_PLANET_FILE="${SCRIPT_BASE_DIRECTORY}/xslt/notes-Planet-csv.xslt"; fi
if [[ -z "${XSLT_NOTE_COMMENTS_PLANET_FILE:-}" ]]; then declare -r XSLT_NOTE_COMMENTS_PLANET_FILE="${SCRIPT_BASE_DIRECTORY}/xslt/note_comments-Planet-csv.xslt"; fi
if [[ -z "${XSLT_TEXT_COMMENTS_PLANET_FILE:-}" ]]; then declare -r XSLT_TEXT_COMMENTS_PLANET_FILE="${SCRIPT_BASE_DIRECTORY}/xslt/note_comments_text-Planet-csv.xslt"; fi

# XML Schema of the Planet notes file
# shellcheck disable=SC2034
if [[ -z "${XMLSCHEMA_PLANET_NOTES:-}" ]]; then declare -r XMLSCHEMA_PLANET_NOTES="${SCRIPT_BASE_DIRECTORY}/xsd/OSM-notes-planet-schema.xsd"; fi

# PostgreSQL SQL script files for Planet
# shellcheck disable=SC2034
if [[ -z "${POSTGRES_11_DROP_SYNC_TABLES:-}" ]]; then declare -r POSTGRES_11_DROP_SYNC_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_11_dropSyncTables.sql"; fi
if [[ -z "${POSTGRES_12_DROP_PLANET_API_TABLES:-}" ]]; then declare -r POSTGRES_12_DROP_PLANET_API_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_12_dropApiTables.sql"; fi
if [[ -z "${POSTGRES_13_DROP_BASE_TABLES:-}" ]]; then declare -r POSTGRES_13_DROP_BASE_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_13_dropBaseTables.sql"; fi
if [[ -z "${POSTGRES_14_DROP_COUNTRY_TABLES:-}" ]]; then declare -r POSTGRES_14_DROP_COUNTRY_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_14_dropCountryTables.sql"; fi
if [[ -z "${POSTGRES_21_CREATE_ENUMS:-}" ]]; then declare -r POSTGRES_21_CREATE_ENUMS="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_21_createBaseTables_enum.sql"; fi
if [[ -z "${POSTGRES_22_CREATE_BASE_TABLES:-}" ]]; then declare -r POSTGRES_22_CREATE_BASE_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_22_createBaseTables_tables.sql"; fi
if [[ -z "${POSTGRES_23_CREATE_CONSTRAINTS:-}" ]]; then declare -r POSTGRES_23_CREATE_CONSTRAINTS="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_23_createBaseTables_constraints.sql"; fi
if [[ -z "${POSTGRES_24_CREATE_SYNC_TABLES:-}" ]]; then declare -r POSTGRES_24_CREATE_SYNC_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_24_createSyncTables.sql"; fi
if [[ -z "${POSTGRES_25_CREATE_PARTITIONS:-}" ]]; then declare -r POSTGRES_25_CREATE_PARTITIONS="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_25_createPartitions.sql"; fi
if [[ -z "${POSTGRES_26_CREATE_COUNTRY_TABLES:-}" ]]; then declare -r POSTGRES_26_CREATE_COUNTRY_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_25_createCountryTables.sql"; fi
if [[ -z "${POSTGRES_31_VACUUM_AND_ANALYZE:-}" ]]; then declare -r POSTGRES_31_VACUUM_AND_ANALYZE="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_31_analyzeVacuum.sql"; fi
if [[ -z "${POSTGRES_41_LOAD_PARTITIONED_SYNC_NOTES:-}" ]]; then declare -r POSTGRES_41_LOAD_PARTITIONED_SYNC_NOTES="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_41_loadPartitionedSyncNotes.sql"; fi
if [[ -z "${POSTGRES_42_CONSOLIDATE_PARTITIONS:-}" ]]; then declare -r POSTGRES_42_CONSOLIDATE_PARTITIONS="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_42_consolidatePartitions.sql"; fi

# Count XML notes for Planet
function __countXmlNotesPlanet() {
 __log_start
 __logd "Counting XML notes for Planet."

 local XML_FILE="${1}"
 local COUNT

 if [[ ! -f "${XML_FILE}" ]]; then
  __loge "ERROR: XML file not found: ${XML_FILE}"
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 COUNT=$(xmllint --xpath "count(//note)" "${XML_FILE}" 2> /dev/null || echo "0")
 __logi "Found ${COUNT} notes in Planet XML file."
 __log_finish
 echo "${COUNT}"
}

# Split XML for parallel Planet processing
function __splitXmlForParallelPlanet() {
 __log_start
 __logd "Splitting XML for parallel Planet processing."

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
   local OUTPUT_FILE="${OUTPUT_DIR}/planet_part_${i}.xml"

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

# Split XML for parallel processing (safe version)
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

# Process XML parts in parallel
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
 XML_FILES=$(find "${INPUT_DIR}" -name "*.xml" -type f | sort)

 if [[ -z "${XML_FILES}" ]]; then
  __loge "ERROR: No XML files found in ${INPUT_DIR}"
  return 1
 fi

 # Process files in parallel
 local PIDS=()
 local PROCESSED=0

 for XML_FILE in ${XML_FILES}; do
  local BASE_NAME
  BASE_NAME=$(basename "${XML_FILE}" .xml)
  local OUTPUT_FILE="${OUTPUT_DIR}/${BASE_NAME}.csv"

  # Process XML file in background
  (
   if xsltproc "${XSLT_FILE}" "${XML_FILE}" > "${OUTPUT_FILE}" 2> /dev/null; then
    __logd "Successfully processed: ${XML_FILE}"
   else
    __loge "ERROR: Failed to process: ${XML_FILE}"
    rm -f "${OUTPUT_FILE}"
   fi
  ) &
  PIDS+=($!)

  # Limit concurrent processes
  if [[ ${#PIDS[@]} -ge "${MAX_WORKERS}" ]]; then
   wait "${PIDS[0]}"
   PIDS=("${PIDS[@]:1}")
  fi

  PROCESSED=$((PROCESSED + 1))
 done

 # Wait for remaining processes
 for PID in "${PIDS[@]}"; do
  wait "${PID}"
 done

 __logi "Parallel processing completed. Processed ${PROCESSED} files."
 __log_finish
}

# Process Planet XML part
function __processPlanetXmlPart() {
 __log_start
 __logd "Processing Planet XML part."

 local XML_FILE="${1}"
 local XSLT_FILE="${2:-${XSLT_NOTES_PLANET_FILE}}"
 local OUTPUT_FILE="${3:-${OUTPUT_NOTES_CSV_FILE}}"

 if [[ ! -f "${XML_FILE}" ]]; then
  __loge "ERROR: XML file not found: ${XML_FILE}"
  return 1
 fi

 if [[ ! -f "${XSLT_FILE}" ]]; then
  __loge "ERROR: XSLT file not found: ${XSLT_FILE}"
  return 1
 fi

 # Validate XML structure
 if ! __validate_xml_structure "${XML_FILE}"; then
  __loge "ERROR: XML validation failed for ${XML_FILE}"
  return 1
 fi

 # Process XML with XSLT
 __logd "Processing XML with XSLT: ${XML_FILE} -> ${OUTPUT_FILE}"
 if xsltproc "${XSLT_FILE}" "${XML_FILE}" > "${OUTPUT_FILE}" 2> /dev/null; then
  __logi "Successfully processed Planet XML part: ${XML_FILE}"
  __log_finish
  return 0
 else
  __loge "ERROR: Failed to process Planet XML part: ${XML_FILE}"
  __log_finish
  return 1
 fi
}

# Download Planet notes
function __downloadPlanetNotes() {
 __log_start
 __logi "=== STARTING PLANET NOTES DOWNLOAD ==="
 __logd "Downloading Planet notes."

 local TEMP_FILE
 TEMP_FILE=$(mktemp)

 # Check network connectivity
 if ! __check_network_connectivity 10; then
  __loge "Network connectivity check failed"
  __handle_error_with_cleanup "${ERROR_INTERNET_ISSUE}" "Network connectivity failed" \
   "rm -f ${TEMP_FILE} 2>/dev/null || true"
  return "${ERROR_INTERNET_ISSUE}"
 fi

 # Download Planet notes
 __logi "Downloading Planet notes from OSM..."
 if wget -q -O "${TEMP_FILE}" "https://planet.openstreetmap.org/notes/notes-latest.osn.bz2"; then
  if [[ -s "${TEMP_FILE}" ]]; then
   # Decompress and move
   if bunzip2 -c "${TEMP_FILE}" > "${PLANET_NOTES_FILE}" 2> /dev/null; then
    rm -f "${TEMP_FILE}"
    __logi "Successfully downloaded and decompressed Planet notes: ${PLANET_NOTES_FILE}"
    __logi "=== PLANET NOTES DOWNLOAD COMPLETED SUCCESSFULLY ==="
    __log_finish
    return 0
   else
    __loge "ERROR: Failed to decompress Planet notes"
    rm -f "${TEMP_FILE}"
    __log_finish
    return 1
   fi
  else
   __loge "ERROR: Downloaded file is empty"
   rm -f "${TEMP_FILE}"
   __log_finish
   return 1
  fi
 else
  __loge "ERROR: Failed to download Planet notes"
  rm -f "${TEMP_FILE}"
  __log_finish
  return 1
 fi
}

# Validate Planet notes XML file
function __validatePlanetNotesXMLFile() {
 __log_start
 __logi "=== STARTING PLANET NOTES XML VALIDATION ==="
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
 __logi "=== PLANET NOTES XML VALIDATION COMPLETED SUCCESSFULLY ==="
 __log_finish
}

# Process boundary
function __processBoundary() {
 __log_start
 __logd "Processing boundary."

 local BOUNDARY_FILE="${1}"
 local TABLE_NAME="${2}"

 if [[ ! -f "${BOUNDARY_FILE}" ]]; then
  __loge "ERROR: Boundary file not found: ${BOUNDARY_FILE}"
  return 1
 fi

 # Import boundary using ogr2ogr
 __logd "Importing boundary: ${BOUNDARY_FILE} -> ${TABLE_NAME}"
 if ogr2ogr -f "PostgreSQL" "PG:dbname=${DBNAME}" "${BOUNDARY_FILE}" \
  -nln "${TABLE_NAME}" -nlt PROMOTE_TO_MULTI -a_srs EPSG:4326 \
  -lco GEOMETRY_NAME=geom -lco FID=id --config PG_USE_COPY YES 2> /dev/null; then
  __logi "Successfully imported boundary: ${TABLE_NAME}"
  __log_finish
  return 0
 else
  __loge "ERROR: Failed to import boundary: ${TABLE_NAME}"
  __log_finish
  return 1
 fi
}

# Process list
function __processList() {
 __log_start
 __logd "Processing list."

 local LIST_FILE="${1}"
 local TABLE_NAME="${2}"

 if [[ ! -f "${LIST_FILE}" ]]; then
  __loge "ERROR: List file not found: ${LIST_FILE}"
  return 1
 fi

 # Import list using ogr2ogr
 __logd "Importing list: ${LIST_FILE} -> ${TABLE_NAME}"
 if ogr2ogr -f "PostgreSQL" "PG:dbname=${DBNAME}" "${LIST_FILE}" \
  -nln "${TABLE_NAME}" -nlt PROMOTE_TO_MULTI -a_srs EPSG:4326 \
  -lco GEOMETRY_NAME=geom -lco FID=id --config PG_USE_COPY YES 2> /dev/null; then
  __logi "Successfully imported list: ${TABLE_NAME}"
  __log_finish
  return 0
 else
  __loge "ERROR: Failed to import list: ${TABLE_NAME}"
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
