#!/bin/bash

# Process Planet Functions for OSM-Notes-profile
# This file contains functions for processing Planet data.
#
# Author: Andres Gomez (AngocA)
# Version: 2025-10-19

# Define version variable
VERSION="2025-10-19"

# Show help function
function __show_help() {
 echo "Process Planet Functions for OSM-Notes-profile"
 echo "This file contains functions for processing Planet data."
 echo
 echo "Usage: source bin/processPlanetFunctions.sh"
 echo
 echo "Available functions:"
 echo "  __downloadPlanetNotes      - Download Planet notes"
 echo "  __processCountries         - Process countries data"
 echo "  __processMaritimes         - Process maritimes data"
 echo "  __processBoundary          - Process boundary data"
 echo "  __createBaseTables         - Create base tables"
 echo "  __createSyncTables         - Create sync tables"
 echo "  __createCountryTables      - Create country tables"
 echo "  __moveSyncToMain           - Move sync to main"
 echo "  __removeDuplicates         - Remove duplicates"
 echo "  __loadTextComments         - Load text comments"
 echo "  __objectsTextComments      - Objects text comments"
 echo
 echo "Author: Andres Gomez (AngocA)"
 echo "Version: ${VERSION}"
 exit 1
}

# shellcheck disable=SC2317,SC2155,SC2034

# Planet-specific variables
# shellcheck disable=SC2034
# Define variables with TMP_DIR - each script has its own TMP_DIR
# so these will be specific to each execution context
if [[ -z "${PLANET_NOTES_FILE:-}" ]]; then
 declare -r PLANET_NOTES_FILE="${TMP_DIR}/OSM-notes-planet.xml"
fi

# Planet notes filename for download (without extension)
# shellcheck disable=SC2034
if [[ -z "${PLANET_NOTES_NAME:-}" ]]; then
 declare -r PLANET_NOTES_NAME="planet-notes-latest.osn"
fi

if [[ -z "${COUNTRIES_FILE:-}" ]]; then
 declare -r COUNTRIES_FILE="${TMP_DIR}/countries"
fi

if [[ -z "${MARITIMES_FILE:-}" ]]; then
 declare -r MARITIMES_FILE="${TMP_DIR}/maritimes"
fi
# shellcheck disable=SC2034
declare OVERPASS_QUERY_FILE="${TMP_DIR}/query"

# XML Schema for strict validation (optional, only used if SKIP_XML_VALIDATION=false)
# shellcheck disable=SC2034
if [[ -z "${XMLSCHEMA_PLANET_NOTES:-}" ]]; then
 declare -r XMLSCHEMA_PLANET_NOTES="${SCRIPT_BASE_DIRECTORY}/xsd/OSM-notes-planet-schema.xsd"
fi

# PostgreSQL SQL script files for Planet
# shellcheck disable=SC2034
if [[ -z "${POSTGRES_11_DROP_SYNC_TABLES:-}" ]]; then declare -r POSTGRES_11_DROP_SYNC_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_11_dropSyncTables.sql"; fi
if [[ -z "${POSTGRES_12_DROP_PLANET_API_TABLES:-}" ]]; then declare -r POSTGRES_12_DROP_PLANET_API_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_12_dropApiTables.sql"; fi
if [[ -z "${POSTGRES_13_DROP_BASE_TABLES:-}" ]]; then declare -r POSTGRES_13_DROP_BASE_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_13_dropBaseTables.sql"; fi
if [[ -z "${POSTGRES_14_DROP_COUNTRY_TABLES:-}" ]]; then declare -r POSTGRES_14_DROP_COUNTRY_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/consolidated_cleanup.sql"; fi
if [[ -z "${POSTGRES_21_CREATE_ENUMS:-}" ]]; then declare -r POSTGRES_21_CREATE_ENUMS="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_21_createBaseTables_enum.sql"; fi
if [[ -z "${POSTGRES_22_CREATE_BASE_TABLES:-}" ]]; then declare -r POSTGRES_22_CREATE_BASE_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_22_createBaseTables_tables.sql"; fi
if [[ -z "${POSTGRES_23_CREATE_CONSTRAINTS:-}" ]]; then declare -r POSTGRES_23_CREATE_CONSTRAINTS="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_23_createBaseTables_constraints.sql"; fi
if [[ -z "${POSTGRES_24_CREATE_SYNC_TABLES:-}" ]]; then declare -r POSTGRES_24_CREATE_SYNC_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_24_createSyncTables.sql"; fi
if [[ -z "${POSTGRES_25_CREATE_PARTITIONS:-}" ]]; then declare -r POSTGRES_25_CREATE_PARTITIONS="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_25_createPartitions.sql"; fi
if [[ -z "${POSTGRES_26_CREATE_COUNTRY_TABLES:-}" ]]; then declare -r POSTGRES_26_CREATE_COUNTRY_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_25_createCountryTables.sql"; fi
if [[ -z "${POSTGRES_31_VACUUM_AND_ANALYZE:-}" ]]; then declare -r POSTGRES_31_VACUUM_AND_ANALYZE="${SCRIPT_BASE_DIRECTORY}/sql/consolidated_cleanup.sql"; fi
if [[ -z "${POSTGRES_41_LOAD_PARTITIONED_SYNC_NOTES:-}" ]]; then declare -r POSTGRES_41_LOAD_PARTITIONED_SYNC_NOTES="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_41_loadPartitionedSyncNotes.sql"; fi
if [[ -z "${POSTGRES_42_CONSOLIDATE_PARTITIONS:-}" ]]; then declare -r POSTGRES_42_CONSOLIDATE_PARTITIONS="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_42_consolidatePartitions.sql"; fi
if [[ -z "${POSTGRES_43_MOVE_SYNC_TO_MAIN:-}" ]]; then declare -r POSTGRES_43_MOVE_SYNC_TO_MAIN="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_43_moveSyncToMain.sql"; fi

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

 # Use grep for faster counting of large files
 COUNT=$(grep -c '<note' "${XML_FILE}" 2> /dev/null || echo "0")
 __logi "Found ${COUNT} notes in Planet XML file using grep."
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
 TOTAL_NOTES=$(grep -c '<note' "${XML_FILE}" 2> /dev/null || echo "0")

 if [[ "${TOTAL_NOTES}" -eq 0 ]]; then
  __logw "WARNING: No notes found in XML file."
  __log_finish
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

   # Extract notes for this part using sed
   # Create a temporary file for this part
   local TEMP_PART_FILE
   TEMP_PART_FILE=$(mktemp)

   # Extract notes using sed pattern matching
   # Find the start of the note and extract until the end
   local NOTE_PATTERN="<note[^>]*>.*?</note>"
   sed -n "/<note[^>]*>/,/<\/note>/p" "${XML_FILE}" \
    | sed -n "${START_POS},${END_POS}p" > "${TEMP_PART_FILE}" 2> /dev/null || true

   # If sed extraction failed, try alternative approach with grep and context
   if [[ ! -s "${TEMP_PART_FILE}" ]]; then
    # Alternative: extract note boundaries and content
    grep -A 100 -B 5 "<note" "${XML_FILE}" \
     | sed -n "/<note/,/<\/note>/p" \
     | head -n $((END_POS - START_POS + 1)) > "${TEMP_PART_FILE}" 2> /dev/null || true
   fi

   # Copy extracted content to output file
   if [[ -s "${TEMP_PART_FILE}" ]]; then
    cat "${TEMP_PART_FILE}" >> "${OUTPUT_FILE}"
   fi

   # Clean up temporary file
   rm -f "${TEMP_PART_FILE}" 2> /dev/null || true

   echo '</osm-notes>' >> "${OUTPUT_FILE}"

   __logd "Created part ${i}: ${OUTPUT_FILE} (notes ${START_POS}-${END_POS})"
  fi
 done

 __logi "XML splitting completed. Created ${NUM_PARTS} parts."
 __log_finish
}

# Split XML for parallel processing (safe version)
# Now uses functions loaded from parallelProcessingFunctions.sh at script startup
function __splitXmlForParallelSafe() {
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

# Process XML parts in parallel
# Now uses functions loaded from parallelProcessingFunctions.sh at script startup
function __processXmlPartsParallel() {
 # Check if the consolidated function is available
 if ! declare -f __processXmlPartsParallelConsolidated > /dev/null 2>&1; then
  __loge "ERROR: Consolidated parallel processing functions not available. Please ensure parallelProcessingFunctions.sh was loaded."
  return 1
 fi
 # Call the consolidated function
 __processXmlPartsParallelConsolidated "$@"
}

# Process Planet XML part

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

  # Download Planet notes with robust retry logic
  __logi "Downloading Planet notes from OSM..."
  if ! __retry_network_operation "https://planet.openstreetmap.org/notes/notes-latest.osn.bz2" "${TEMP_FILE}" 3 5 60; then
    __loge "ERROR: Failed to download Planet notes after retries"
    rm -f "${TEMP_FILE}"
    __log_finish
    return 1
  fi

  # Verify downloaded file has content
  if [[ ! -s "${TEMP_FILE}" ]]; then
    __loge "ERROR: Downloaded file is empty"
    rm -f "${TEMP_FILE}"
    __log_finish
    return 1
  fi

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

 # Debug: Show file info
 local FILE_SIZE
 FILE_SIZE=$(stat -c%s "${BOUNDARY_FILE}" 2> /dev/null || echo "unknown")
 __logd "Boundary file size: ${FILE_SIZE} bytes"

 local FILE_PREVIEW
 FILE_PREVIEW=$(head -c 200 "${BOUNDARY_FILE}" 2> /dev/null || echo "Cannot read file")
 __logd "First 200 chars of file: ${FILE_PREVIEW}"

 # Import boundary using ogr2ogr
 __logd "Importing boundary: ${BOUNDARY_FILE} -> ${TABLE_NAME}"

 # Capture ogr2ogr output for debugging
 local OGR_OUTPUT
 OGR_OUTPUT=$(mktemp)

 # Import GeoJSON to PostgreSQL
 # Strategy: Use SQL SELECT to pick only needed columns, avoiding duplicates
 # Import to temporary table first, then map to target schema
 local TEMP_TABLE="${TABLE_NAME}_import"

 # Note: Using -sql to SELECT only the columns we need
 # This avoids the duplicate column issue (name:es vs name:ES become same column in PostgreSQL)
 __logd "Importing with column selection to temporary table: ${TEMP_TABLE}"
 if ogr2ogr -f "PostgreSQL" "PG:dbname=${DBNAME}" "${BOUNDARY_FILE}" \
  -nln "${TEMP_TABLE}" -nlt PROMOTE_TO_MULTI -a_srs EPSG:4326 \
  -lco GEOMETRY_NAME=geom \
  -dialect SQLite \
  -sql "SELECT id, name, \"name:es\" as name_es, \"name:en\" as name_en, geometry FROM $(basename "${BOUNDARY_FILE}" .geojson)" \
  -overwrite \
  --config PG_USE_COPY YES 2> "${OGR_OUTPUT}"; then
  __logd "Import successful, now mapping columns to target table: ${TABLE_NAME}"

  # The imported temp table has: id (string), name, name_es, name_en, geom
  # The target table has: country_id (integer), country_name, country_name_es, country_name_en, geom
  if psql -d "${DBNAME}" -v ON_ERROR_STOP=1 << EOF >> "${OGR_OUTPUT}" 2>&1; then
   -- Insert with proper column mapping and type conversion
   INSERT INTO ${TABLE_NAME} (country_id, country_name, country_name_es, country_name_en, geom)
   SELECT 
     CAST(SUBSTRING(id FROM 'relation/([0-9]+)') AS INTEGER) AS country_id,
     COALESCE(name, 'Unknown') AS country_name,
     name_es AS country_name_es,
     name_en AS country_name_en,
     geom
   FROM ${TEMP_TABLE}
   WHERE id LIKE 'relation/%';
   
   -- Drop temporary table
   DROP TABLE ${TEMP_TABLE};
EOF
   __logi "Successfully imported boundary: ${TABLE_NAME}"
   rm -f "${OGR_OUTPUT}"
   __log_finish
   return 0
  else
   __loge "ERROR: Failed to map columns from ${TEMP_TABLE} to ${TABLE_NAME}"
   if [[ -s "${OGR_OUTPUT}" ]]; then
    __loge "SQL error output:"
    while IFS= read -r line; do
     __loge "  ${line}"
    done < "${OGR_OUTPUT}"
   fi
   rm -f "${OGR_OUTPUT}"
   __log_finish
   return 1
  fi
 else
  __loge "ERROR: Failed to import boundary with ogr2ogr"
  if [[ -s "${OGR_OUTPUT}" ]]; then
   __loge "ogr2ogr error output:"
   while IFS= read -r line; do
    __loge "  ${line}"
   done < "${OGR_OUTPUT}"
  fi
  rm -f "${OGR_OUTPUT}"
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

 # Download countries boundary (or use cached file if available)
 local GEOJSON_FILE
 if [[ -f "/tmp/countries.geojson" ]] && [[ -s "/tmp/countries.geojson" ]]; then
  __logi "Using cached countries boundary from /tmp/countries.geojson"
  GEOJSON_FILE="/tmp/countries.geojson"
 else
  __logi "Downloading countries boundary..."
  if wget -q -O "${COUNTRIES_FILE}.json" --timeout=300 "https://overpass-api.de/api/interpreter?data=[out:json];relation[\"admin_level\"=\"2\"][\"boundary\"=\"administrative\"];out geom;"; then
   if [[ -s "${COUNTRIES_FILE}.json" ]]; then
    # Convert OSM JSON to GeoJSON using osmtogeojson
    if ! osmtogeojson "${COUNTRIES_FILE}.json" > "${COUNTRIES_FILE}.geojson" 2> /dev/null; then
     __loge "ERROR: Failed to convert OSM JSON to GeoJSON"
     __log_finish
     return 1
    fi
   else
    __loge "ERROR: Downloaded countries file is empty"
    __log_finish
    return 1
   fi
  else
   __loge "ERROR: Failed to download countries boundary from Overpass API"
   __log_finish
   return 1
  fi
  GEOJSON_FILE="${COUNTRIES_FILE}.geojson"
 fi

 # Process the GeoJSON file
 if [[ -s "${GEOJSON_FILE}" ]]; then
  # Import to database
  if __processBoundary "${GEOJSON_FILE}" "countries"; then
   __logi "Successfully processed countries boundary"
   __log_finish
   return 0
  else
   __loge "ERROR: Failed to import countries boundary"
   __log_finish
   return 1
  fi
 else
  __loge "ERROR: Countries GeoJSON file not found or empty"
  __log_finish
  return 1
 fi
}

# Process maritimes
function __processMaritimes() {
 __log_start
 __logd "Processing maritimes."

 # Download maritime boundaries (or use cached file if available)
 local GEOJSON_FILE
 if [[ -f "/tmp/maritimes.geojson" ]] && [[ -s "/tmp/maritimes.geojson" ]]; then
  __logi "Using cached maritime boundaries from /tmp/maritimes.geojson"
  GEOJSON_FILE="/tmp/maritimes.geojson"
 else
  __logi "Downloading maritime boundaries..."
  if wget -q -O "${MARITIMES_FILE}.json" --timeout=300 "https://overpass-api.de/api/interpreter?data=[out:json];relation[\"boundary\"=\"maritime\"];out geom;"; then
   if [[ -s "${MARITIMES_FILE}.json" ]]; then
    # Convert OSM JSON to GeoJSON using osmtogeojson
    if ! osmtogeojson "${MARITIMES_FILE}.json" > "${MARITIMES_FILE}.geojson" 2> /dev/null; then
     __loge "ERROR: Failed to convert OSM JSON to GeoJSON"
     __log_finish
     return 1
    fi
   else
    __loge "ERROR: Downloaded maritimes file is empty"
    __log_finish
    return 1
   fi
  else
   __loge "ERROR: Failed to download maritime boundaries from Overpass API"
   __log_finish
   return 1
  fi
  GEOJSON_FILE="${MARITIMES_FILE}.geojson"
 fi

 # Process the GeoJSON file
 if [[ -s "${GEOJSON_FILE}" ]]; then
  # Import to database (maritimes go into the countries table)
  if __processBoundary "${GEOJSON_FILE}" "countries"; then
   __logi "Successfully processed maritime boundaries"
   __log_finish
   return 0
  else
   __loge "ERROR: Failed to import maritime boundaries"
   __log_finish
   return 1
  fi
 else
  __loge "ERROR: Maritimes GeoJSON file not found or empty"
  __log_finish
  return 1
 fi
}
