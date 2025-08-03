#!/bin/bash

# This script prepares a database for note analysis and loads the notes from
# the planet, either completely or just the missing ones. Depending on the invocation,
# it performs different tasks.
# The script structure is:
# * Creates the database structure.
# * Downloads the list of country IDs (overpass).
# * Downloads the country boundaries (overpass).
# * Downloads the list of maritime area IDs (overpass).
# * Downloads the maritime area boundaries (overpass).
# * Imports the boundaries into the database.
# * Downloads the planet notes.
# * Converts the notes into flat CSV files.
# * Imports the notes into the database.
# * Sets the order for countries by zones.
# * Creates a function to get the country of a position using the order by
#   zones.
# * Runs the function against all notes.
#
# There are these workflows:
#
# * base > sync (This workflow is called from processApiNotes).
# * boundaries (Processes the countries and maritime areas only).
#
# These are some examples to call this script:
#
# * export LOG_LEVEL=DEBUG ; ~/OSM-Notes-profile/bin/process/processPlanetNotes.sh --base
# * export LOG_LEVEL=DEBUG ; ~/OSM-Notes-profile/bin/process/processPlanetNotes.sh
# * export LOG_LEVEL=DEBUG ; ~/OSM-Notes-profile/bin/process/processPlanetNotes.sh --boundaries
#
# The design of this architecture is at: https://miro.com/app/board/uXjVPDTbDok=/
#
# Known issues:
# * Austria has an issue to be imported with ogr2ogr for a particular thing in
#   the geometry. A simplification is done to upload it. However, there is a
#   missing part not being imported.
# * Taiwan has an issue to be imported with ogr2ogr for a very long row. Some
#   fields are removed.
# * The Gaza Strip is not at the same level as a country. The ID is hardcoded.
# * Not all countries have defined the maritime borders. Also, not all
#   countries have signed the Covemar.
#
# When running under MacOS or zsh, it is better to invoke bash:
# bash ./processPlanetNotes.sh
#
# To follow the progress you can execute:
#   tail -40f $(ls -1rtd /tmp/processPlanetNotes_* | tail -1)/processPlanetNotes.log
#
# You need to create a database called 'notes':
#   CREATE DATABASE notes;
# You need to install postgis and add the extension:
#   CREATE EXTENSION postgis;
#   CREATE EXTENSION btree_gist;
# You also need to log into the database with the current user ${USER}
#   createuser myuser
#   CREATE ROLE myuser WITH LOGIN
# You need to check the access to PostgreSQL with the following without
# password:
#   psql -d notes
# This could be an option:
#   export PGPASSWORD='password'
# Or change the pg_hba.conf file.
# Also you need to give permissions to create objects in public schema:
#   GRANT USAGE ON SCHEMA public TO myuser
#
# To not remove all generated files, you can export this:
#   export CLEAN=false
#
# To insert the rows from a backup for boundaries and notes:
#   export BACKUP_COUNTRIES=true
# It will need to run these from a PostgreSQL console:
#   INSERT INTO countries
#    SELECT * FROM backup_countries ;
# To create the copy before the execution:
#   CREATE TABLE backup_countries AS TABLE countries;
# For more information, please check this file:
# OSM-Notes-profile/sql/copyCountriesAndLocationNotes.sql
#
# To increase or reduce the verbosity, you can change the logger:
#   export LOG_LEVEL=DEBUG # For more messages.
#   export LOG_LEVEL=WARN  # Important messages.
#
# Some interesting queries to track the process:
#
# select country_name_en, americas, europe, russia_middle_east, asia_oceania
# from countries
# order by americas nulls last, europe nulls last,
#  russia_middle_east nulls last, asia_oceania nulls last;
#
# The most iterations to find an area.
# select iter, country_name_en, count(1)
# from tries t
# join countries c
# on (t.id_country = c.country_id)
# group by iter, country_name_en
# order by iter desc, count(1) desc;
#
# Details of the iteration.
# select t.*, country_name_en
# from tries t
# join countries c
# on (t.id_country = c.country_id)
# where iter = 121;
#
# How many iterations per region to find the appropriate area.
# This allows to reorganize the updates of the organizeAreas function.
# select iter, count(1), area, country_name_en
# from tries t
# join countries c
# on t.id_country = c.country_id
# group by iter, area, country_name_en
# order by area, count(1) desc;
#
# Sections per parameter:
#                                   empty    base    bounda
#                                   (sync)           ries
# __dropSyncTables                             x
# __dropApiTables                              x
# __dropGenericObjects                         x
# __dropBaseTables                             x
# __createBaseTables                           x
# __dropSyncTables                     x
# __checkBaseTables                    x
# __createBaseTables                   x
# __createSyncTables                   x
# __dropCountryTables                          x        x
# __createCountryTables                        x        x
# __processCountries                           x        x
# __processMaritimes                           x        x
# __cleanPartial                               x        x
# __downloadPlanetNotes                x
# __validatePlanetNotesXMLFile         x
# __createFunctionToGetCountry         x       x
# __createProcedures                   x       x
# __analyzeAndVacuum                   x       x
# __loadSyncNotes                      x
# __removeDuplicates                   x
# __loadTextComments                   x
# __dropSyncTables                     x
# __organizeAreas                      x
# __getLocationNotes                   x
# __cleanNotesFiles                    x       x
#
# This is the list of error codes:
# 1) Help message.
# 241) Library or utility missing.
# 242) Invalid argument for script invocation.
# 243) Logger utility is not available.
# 244) IDs list cannot be downloaded.
# 249) Error downloading boundary.
#
# For contributing, please execute these commands before submitting:
# * shellcheck -x -o all processPlanetNotes.sh
# * shfmt -w -i 1 -sr -bn processPlanetNotes.sh
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-31
declare -r VERSION="2025-07-31"

#set -xv
# Fails when a variable is not initialized.
set -u
# Fails with a non-zero return code.
set -e
# Fails if the commands of a pipe return non-zero.
set -o pipefail
# Fails if an internal function fails.
set -E

# If all files should be deleted. In case of an error, this could be disabled.
# You can define when calling: export CLEAN=false
declare -r CLEAN=${CLEAN:-true}
# If the boundary rows are retrieved from backup table.
declare -r BACKUP_COUNTRIES=${BACKUP_COUNTRIES:-false}

# Logger levels: TRACE, DEBUG, INFO, WARN, ERROR, FATAL.
declare LOG_LEVEL="${LOG_LEVEL:-ERROR}"

# Base directory for the project.
declare SCRIPT_BASE_DIRECTORY
SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." \
 &> /dev/null && pwd)"
readonly SCRIPT_BASE_DIRECTORY

# Loads the global properties.
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh"

# Mask for the files and directories.
umask 0000

declare BASENAME
BASENAME=$(basename -s .sh "${0}")
readonly BASENAME
# Temporal directory for all files.
declare TMP_DIR
TMP_DIR=$(mktemp -d "/tmp/${BASENAME}_XXXXXX")
readonly TMP_DIR
chmod 777 "${TMP_DIR}"
# Log file for output.
declare LOG_FILENAME
LOG_FILENAME="${TMP_DIR}/${BASENAME}.log"
readonly LOG_FILENAME

# Lock file for single execution.
declare LOCK
LOCK="/tmp/${BASENAME}.lock"
readonly LOCK

# Type of process to run in the script.
declare -r PROCESS_TYPE=${1:-}

# Total notes count.
declare -i TOTAL_NOTES=-1

# Planet notes file configuration.
# (Declared in processPlanetFunctions.sh)

# PostgreSQL SQL script files.
# (Declared in processPlanetFunctions.sh)

# Flag to define that the process should update the location of notes.
# This variable is used in functionsProcess.sh
export UPDATE_NOTE_LOCATION=false

# Files for countries and maritimes processing.
# (Declared in processPlanetFunctions.sh)

# Error codes are already defined in functionsProcess.sh

# Location of the common functions.

# XSLT transformation files for Planet format (used by parallel processing).
# (Declared in processPlanetFunctions.sh)

# Control variables for functionsProcess.sh
export ONLY_EXECUTION="no"

###########
# FUNCTIONS

# Load common functions
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/bin/commonFunctions.sh"

# Load Planet-specific functions
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/bin/processPlanetFunctions.sh"

# Load validation functions
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/bin/validationFunctions.sh"

# Load error handling functions
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/bin/errorHandlingFunctions.sh"

# Load API-specific functions (includes POSTGRES_12_DROP_API_TABLES)
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/bin/processAPIFunctions.sh"

# Load process functions (includes GEOJSON_TEST and other variables)
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh"
# __start_logger
# __trapOn
# __checkBaseTables
# __downloadPlanetNotes
# __validatePlanetNotesXMLFile
# __createFunctionToGetCountry
# __createProcedures

# Shows the help information.
function __show_help {
 echo "${BASENAME} version ${VERSION}"
 echo "This is a script that downloads the OSM notes from the Planet,"
 echo "processes them with a XSLT transformation, to create a flat file,"
 echo "and finally it uploads them into a PostgreSQL database."
 echo
 echo "It could receive one of these parameters:"
 echo " * --base : to starts from scratch from Planet notes file, including the"
 echo "     boundaries."
 echo " * --boundaries : processes the countries and maritimes areas only."
 echo " * Without parameter, it processes the new notes from Planet notes file."
 echo
 echo "Environment variable:"
 echo " * BACKUP_COUNTRIES could be set to true, to insert boundary rows from"
 echo "   backup tables."
 echo " * CLEAN could be set to false, to left all created files."
 echo " * LOG_LEVEL specifies the logger levels. Possible values are:"
 echo "   DEBUG, INFO, WARN, ERROR"
 echo
 echo "Written by: Andres Gomez (AngocA)"
 echo "OSM-LatAm, OSM-Colombia, MaptimeBogota."
}

# Checks prerequisites to run the script.
function __checkPrereqs {
 __log_start
 __logi "=== STARTING PLANET PREREQUISITES CHECK ==="
 if [[ "${PROCESS_TYPE}" != "" ]] && [[ "${PROCESS_TYPE}" != "--base" ]] \
  && [[ "${PROCESS_TYPE}" != "--boundaries" ]] \
  && [[ "${PROCESS_TYPE}" != "--help" ]] \
  && [[ "${PROCESS_TYPE}" != "-h" ]]; then
  echo "ERROR: Invalid parameter. It should be:"
  echo " * Empty string, nothing."
  echo " * --base"
  echo " * --boundaries"
  echo " * --help"
  exit "${ERROR_INVALID_ARGUMENT}"
 fi
 set +e
 # Checks prereqs.
 __checkPrereqsCommands

 ## Validate SQL script files using centralized validation
 __logi "Validating SQL script files..."

 # Create array of SQL files to validate
 local SQL_FILES=(
  "${POSTGRES_11_DROP_SYNC_TABLES}"
  "${POSTGRES_12_DROP_API_TABLES}"
  "${POSTGRES_13_DROP_BASE_TABLES}"
  "${POSTGRES_14_DROP_COUNTRY_TABLES}"
  "${POSTGRES_21_CREATE_ENUMS}"
  "${POSTGRES_22_CREATE_BASE_TABLES}"
  "${POSTGRES_23_CREATE_CONSTRAINTS}"
  "${POSTGRES_24_CREATE_SYNC_TABLES}"
  "${POSTGRES_26_CREATE_COUNTRY_TABLES}"
  "${POSTGRES_31_VACUUM_AND_ANALYZE}"
  "${POSTGRES_25_CREATE_PARTITIONS}"
  "${POSTGRES_41_LOAD_PARTITIONED_SYNC_NOTES}"
  "${POSTGRES_42_CONSOLIDATE_PARTITIONS}"
 )

 # Validate each SQL file
 for SQL_FILE in "${SQL_FILES[@]}"; do
  if ! __validate_sql_structure "${SQL_FILE}"; then
   __loge "ERROR: SQL file validation failed: ${SQL_FILE}"
   exit "${ERROR_MISSING_LIBRARY}"
  fi
 done

 ## Validate XSLT files
 __logi "Validating XSLT files..."
 if ! __validate_input_file "${XSLT_NOTES_PLANET_FILE}" "XSLT notes file"; then
  __loge "ERROR: XSLT notes file validation failed: ${XSLT_NOTES_PLANET_FILE}"
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 if ! __validate_input_file "${XSLT_NOTE_COMMENTS_PLANET_FILE}" "XSLT comments file"; then
  __loge "ERROR: XSLT comments file validation failed: ${XSLT_NOTE_COMMENTS_PLANET_FILE}"
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 if ! __validate_input_file "${XSLT_TEXT_COMMENTS_PLANET_FILE}" "XSLT text comments file"; then
  __loge "ERROR: XSLT text comments file validation failed: ${XSLT_TEXT_COMMENTS_PLANET_FILE}"
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 ## Validate XML schema files
 __logi "Validating XML schema files..."
 if ! __validate_input_file "${XMLSCHEMA_PLANET_NOTES}" "XML schema file"; then
  __loge "ERROR: XML schema validation failed: ${XMLSCHEMA_PLANET_NOTES}"
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 # Validate XSLT files
 __logi "Validating XSLT files..."
 if ! __validate_input_file "${XSLT_NOTES_PLANET_FILE}" "XSLT notes file"; then
  __loge "ERROR: XSLT notes file validation failed: ${XSLT_NOTES_PLANET_FILE}"
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 # Validate dates in XML files if they exist
 __logi "Validating dates in XML files..."
 if [[ -f "${PLANET_NOTES_FILE}" ]]; then
  if ! __validate_xml_dates "${PLANET_NOTES_FILE}"; then
   __loge "ERROR: XML date validation failed: ${PLANET_NOTES_FILE}"
   exit "${ERROR_MISSING_LIBRARY}"
  fi
 fi

 # CSV files are generated during processing, no need to validate them here
 # as they will be created by __processPlanetXmlPart function

 ## Validate JSON schema files
 __logi "Validating JSON schema files..."
 if ! __validate_input_file "${JSON_SCHEMA_OVERPASS}" "JSON schema file"; then
  __loge "ERROR: JSON schema file validation failed: ${JSON_SCHEMA_OVERPASS}"
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 if ! __validate_input_file "${JSON_SCHEMA_GEOJSON}" "GeoJSON schema file"; then
  __loge "ERROR: GeoJSON schema file validation failed: ${JSON_SCHEMA_GEOJSON}"
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 ## Validate test files
 __logi "Validating test files..."
 if ! __validate_input_file "${GEOJSON_TEST}" "GeoJSON test file"; then
  __loge "ERROR: GeoJSON test file validation failed: ${GEOJSON_TEST}"
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 ## Validate backup files if they exist
 if [[ -f "${CSV_BACKUP_NOTE_LOCATION_COMPRESSED}" ]]; then
  __logi "Validating backup files..."
  if ! __validate_input_file "${CSV_BACKUP_NOTE_LOCATION_COMPRESSED}" "Backup file"; then
   __loge "ERROR: Backup file validation failed: ${CSV_BACKUP_NOTE_LOCATION_COMPRESSED}"
   exit "${ERROR_MISSING_LIBRARY}"
  fi
 fi

 if [[ -f "${POSTGRES_32_UPLOAD_NOTE_LOCATION}" ]]; then
  if ! __validate_sql_structure "${POSTGRES_32_UPLOAD_NOTE_LOCATION}"; then
   __loge "ERROR: Upload SQL file validation failed: ${POSTGRES_32_UPLOAD_NOTE_LOCATION}"
   exit "${ERROR_MISSING_LIBRARY}"
  fi
 fi

 __checkPrereqs_functions
 __logi "=== PLANET PREREQUISITES CHECK COMPLETED SUCCESSFULLY ==="
 __log_finish
 set -e
}

# Drop sync tables.
function __dropSyncTables {
 __log_start
 __logi "=== DROPPING SYNC TABLES ==="
 __logd "Executing SQL file: ${POSTGRES_11_DROP_SYNC_TABLES}"
 psql -d "${DBNAME}" -c "SET app.max_threads = '${MAX_THREADS}';" -f "${POSTGRES_11_DROP_SYNC_TABLES}"
 __logi "=== SYNC TABLES DROPPED SUCCESSFULLY ==="
 __log_finish
}

# Drop tables for notes from API.
function __dropApiTables {
 __log_start
 __logi "=== DROPPING API TABLES ==="
 __logd "Executing SQL file: ${POSTGRES_12_DROP_API_TABLES}"
 psql -d "${DBNAME}" -c "SET app.max_threads = '${MAX_THREADS}';" -f "${POSTGRES_12_DROP_API_TABLES}"
 __logi "=== API TABLES DROPPED SUCCESSFULLY ==="
 __log_finish
}

# Drop existing base tables.
function __dropBaseTables {
 __log_start
 __logi "=== DROPPING BASE TABLES ==="
 __logd "Executing SQL file: ${POSTGRES_13_DROP_BASE_TABLES}"
 psql -d "${DBNAME}" -f "${POSTGRES_13_DROP_BASE_TABLES}"
 __logi "=== BASE TABLES DROPPED SUCCESSFULLY ==="
 __log_finish
}

# Drop existing base tables.
function __dropCountryTables {
 __log_start
 __logi "=== DROPPING COUNTRY TABLES ==="
 __logd "Executing SQL file: ${POSTGRES_14_DROP_COUNTRY_TABLES}"
 psql -d "${DBNAME}" -f "${POSTGRES_14_DROP_COUNTRY_TABLES}"
 __logi "=== COUNTRY TABLES DROPPED SUCCESSFULLY ==="
 __log_finish
}

# Creates base tables that hold the whole history.
function __createBaseTables {
 __log_start
 __logi "=== CREATING BASE TABLES ==="
 __logd "Executing SQL files:"
 __logd "  Enums: ${POSTGRES_21_CREATE_ENUMS}"
 __logd "  Base tables: ${POSTGRES_22_CREATE_BASE_TABLES}"
 __logd "  Constraints: ${POSTGRES_23_CREATE_CONSTRAINTS}"
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_21_CREATE_ENUMS}"

 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_22_CREATE_BASE_TABLES}"

 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_23_CREATE_CONSTRAINTS}"
 __logi "=== BASE TABLES CREATED SUCCESSFULLY ==="
 __log_finish
}

# Creates sync tables that receives the whole history, but then keep the new
# ones.
function __createSyncTables {
 __log_start
 __logi "Creating tables."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_24_CREATE_SYNC_TABLES}"
 __log_finish
}

# Creates base tables that hold the whole history.
function __createCountryTables {
 __log_start
 __logi "Creating tables."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_26_CREATE_COUNTRY_TABLES}"
 __log_finish
}

# Clean files and tables.
function __cleanPartial {
 __log_start
 if [[ -n "${CLEAN:-}" ]] && [[ "${CLEAN}" = true ]]; then
  rm -f "${COUNTRIES_FILE}" "${MARITIMES_FILE}"
  __logw "Dropping import table."
  echo "DROP TABLE IF EXISTS import" | psql -d "${DBNAME}"
 fi
 __log_finish
}

# Calculates statistics on all tables and vacuum.
function __analyzeAndVacuum {
 __log_start
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_31_VACUUM_AND_ANALYZE}"
 __log_finish
}

# Loads new notes from sync.
function __loadSyncNotes {
 __log_start
 # Loads the data in the database.
 export OUTPUT_NOTES_FILE
 export OUTPUT_NOTE_COMMENTS_FILE
 # shellcheck disable=SC2016
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -c "$(envsubst '$OUTPUT_NOTES_FILE,$OUTPUT_NOTE_COMMENTS_FILE' \
   < "${POSTGRES_41_LOAD_PARTITIONED_SYNC_NOTES}" || true)"
 __log_finish
}

# Removes notes and comments from the new set that are already in the database.
function __removeDuplicates {
 __log_start
 PROCESS_ID="${$}"
 echo "CALL put_lock('${PROCESS_ID}'::VARCHAR)" | psql -d "${DBNAME}" \
  -v ON_ERROR_STOP=1
 __logi "Lock put ${PROCESS_ID}"

 export PROCESS_ID
 # shellcheck disable=SC2016
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -c "$(envsubst '$PROCESS_ID' < "${POSTGRES_43_REMOVE_DUPLICATES}" || true)"

 echo "CALL remove_lock('${PROCESS_ID}'::VARCHAR)" | psql -d "${DBNAME}" \
  -v ON_ERROR_STOP=1
 # Puts the sequence. When reexecuting, some objects already exist.
 __logi "Lock removed ${PROCESS_ID}"

 psql -d "${DBNAME}" -f "${POSTGRES_44_COMMENTS_SEQUENCE}"
 __log_finish
}

# Loads text comments.
function __loadTextComments {
 __log_start
 # Loads the text comment in the database.
 export OUTPUT_TEXT_COMMENTS_FILE
 # shellcheck disable=SC2016
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -c "$(envsubst '$OUTPUT_TEXT_COMMENTS_FILE' \
   < "${POSTGRES_45_LOAD_TEXT_COMMENTS}" || true)"
 # Some objects could already exist.
 psql -d "${DBNAME}" -f "${POSTGRES_46_OBJECTS_TEXT_COMMENTS}"
 __log_finish
}

# Moves data from sync tables to main tables after consolidation.
function __moveSyncToMain {
 __log_start
 __logi "Moving data from sync tables to main tables"
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_43_MOVE_SYNC_TO_MAIN}"
 __log_finish
}

# Creates partition tables for parallel processing and verifies their creation.
function __createPartitionTables {
 __log_start
 __logi "Creating partition tables with MAX_THREADS=${MAX_THREADS}"
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -c "SET app.max_threads = '${MAX_THREADS}';" \
  -f "${POSTGRES_25_CREATE_PARTITIONS}"
 __logi "Partition tables creation completed"

 # Verify that partition tables were created
 __logi "Verifying partition tables creation..."
 psql -d "${DBNAME}" -c "
 SELECT table_name, COUNT(*) as count 
 FROM information_schema.tables 
 WHERE table_name LIKE '%_part_%' 
 GROUP BY table_name 
 ORDER BY table_name;
 "
 __log_finish
}

# Processes Planet notes with parallel processing when notes are available.
function __processPlanetNotesWithParallel {
 __log_start
 __logi "Processing Planet notes with parallel processing"

 # Create partitions for parallel processing
 __createPartitionTables

 __splitXmlForParallelPlanet "${PLANET_NOTES_FILE}.xml"
 # Export XSLT variables for parallel processing
 export XSLT_NOTES_FILE XSLT_NOTE_COMMENTS_FILE XSLT_TEXT_COMMENTS_FILE
 __processXmlPartsParallel "__processPlanetXmlPart"
 # Consolidate partitions into main tables
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -c "SET app.max_threads = '${MAX_THREADS}';" \
  -f "${POSTGRES_42_CONSOLIDATE_PARTITIONS}"

 # Move data from sync tables to main tables
 __logi "Moving data from sync tables to main tables"
 __moveSyncToMain

 __logi "Planet notes processing with parallel processing completed"
 __log_finish
}

# Cleans files generated during the process.
function __cleanNotesFiles {
 __log_start
 if [[ -n "${CLEAN:-}" ]] && [[ "${CLEAN}" = true ]]; then
  rm -f "${PLANET_NOTES_FILE}.xml" "${OUTPUT_NOTES_FILE}" \
   "${OUTPUT_NOTE_COMMENTS_FILE}" "${OUTPUT_TEXT_COMMENTS_FILE}"
  rm -f "${TMP_DIR}"/part_country_* "${TMP_DIR}"/part_maritime_*
 fi
 __log_finish
}

# Validates the XML file to be sure everything will work fine.
function __validatePlanetNotesXMLFile {
 __log_start

 # shellcheck disable=SC2154
 xmllint --noout --schema "${XMLSCHEMA_PLANET_NOTES}" \
  "${PLANET_NOTES_FILE}.xml" 2>&1

 __log_finish
}

# Validates Planet notes XML file completely (structure, dates, coordinates)
# Parameters:
#   None (uses global PLANET_NOTES_FILE variable)
# Returns:
#   0 if all validations pass, exits with ERROR_DATA_VALIDATION if any validation fails
function __validatePlanetNotesXMLFileComplete {
 __log_start

 # Check if file exists
 if [[ ! -f "${PLANET_NOTES_FILE}.xml" ]]; then
  __loge "ERROR: Planet notes file not found: ${PLANET_NOTES_FILE}.xml"
  exit "${ERROR_DATA_VALIDATION}"
 fi

 # Clean up any existing temporary files
 __cleanup_validation_temp_files

 # Validate XML structure against schema with enhanced error handling
 __logi "Validating XML structure against schema..."
 if ! __validate_xml_with_enhanced_error_handling "${PLANET_NOTES_FILE}.xml" "${XMLSCHEMA_PLANET_NOTES}"; then
  __loge "ERROR: XML structure validation failed: ${PLANET_NOTES_FILE}.xml"
  __cleanup_validation_temp_files
  exit "${ERROR_DATA_VALIDATION}"
 fi

 # Validate dates in XML file
 __logi "Validating dates in XML file..."
 if ! __validate_xml_dates "${PLANET_NOTES_FILE}.xml"; then
  __loge "ERROR: XML date validation failed: ${PLANET_NOTES_FILE}.xml"
  __cleanup_validation_temp_files
  exit "${ERROR_DATA_VALIDATION}"
 fi

 # Validate coordinates in XML file
 __logi "Validating coordinates in XML file..."
 if ! __validate_xml_coordinates "${PLANET_NOTES_FILE}.xml"; then
  __loge "ERROR: XML coordinate validation failed: ${PLANET_NOTES_FILE}.xml"
  __cleanup_validation_temp_files
  exit "${ERROR_DATA_VALIDATION}"
 fi

 # Final cleanup
 __cleanup_validation_temp_files

 __logi "All Planet notes XML validations passed successfully"
 __log_finish
}

# Alternative XML structure validation for large files
# Parameters:
#   $1 - XML file path
# Returns:
#   0 if validation passes, 1 if validation fails
function __validate_xml_structure_alternative {
 local XML_FILE="${1}"

 if [[ ! -f "${XML_FILE}" ]]; then
  __loge "ERROR: XML file not found: ${XML_FILE}"
  return 1
 fi

 __logi "Using alternative XML validation method..."

 # Check basic XML structure without full schema validation
 if ! xmllint --noout --nonet "${XML_FILE}" 2> /dev/null; then
  __loge "ERROR: Basic XML structure validation failed"
  return 1
 fi

 # Check root element
 if ! grep -q "<osm-notes>" "${XML_FILE}" 2> /dev/null; then
  __loge "ERROR: Missing root element <osm-notes>"
  return 1
 fi

 # Check for note elements
 if ! grep -q "<note" "${XML_FILE}" 2> /dev/null; then
  __loge "ERROR: No note elements found in XML"
  return 1
 fi

 # Count total notes
 local TOTAL_NOTES
 TOTAL_NOTES=$(grep -c "<note" "${XML_FILE}" 2> /dev/null || echo "0")

 if [[ "${TOTAL_NOTES}" -gt 0 ]]; then
  __logi "Found ${TOTAL_NOTES} notes in XML file"

  # For very large files, use more conservative sampling
  local SAMPLE_SIZE="${ETL_XML_SAMPLE_SIZE:-50}"
  if [[ "${TOTAL_NOTES}" -gt 10000 ]]; then
   SAMPLE_SIZE=25
  elif [[ "${TOTAL_NOTES}" -gt 100000 ]]; then
   SAMPLE_SIZE=10
  fi

  # Sample validation for large files
  if [[ "${TOTAL_NOTES}" -gt "${SAMPLE_SIZE}" ]]; then
   __logw "WARNING: Large file detected. Validating sample of ${SAMPLE_SIZE} notes only."
   
   # Create a more robust sample extraction
   local SAMPLE_FILE
   SAMPLE_FILE=$(mktemp "${TMP_DIR}/sample_validation_XXXXXX.xml" 2> /dev/null)
   
   if [[ -n "${SAMPLE_FILE}" ]]; then
    # Extract sample with proper XML structure
    {
     echo '<?xml version="1.0"?>'
     echo '<osm-notes>'
     # Get random sample of notes
     awk -v sample_size="${SAMPLE_SIZE}" -v total="${TOTAL_NOTES}" '
      /<note/ { 
       count++; 
       if (count <= sample_size || (rand() < sample_size / total && count > sample_size)) {
        in_note = 1; 
        print; 
        next 
       }
      }
      in_note { print }
      /<\/note>/ { 
       if (in_note) { 
        in_note = 0; 
        print 
       }
      }
     ' "${XML_FILE}" | head -n $((SAMPLE_SIZE * 20))
     echo '</osm-notes>'
    } > "${SAMPLE_FILE}" 2> /dev/null

    if [[ -s "${SAMPLE_FILE}" ]]; then
     # Validate sample against schema with timeout
     if timeout 60 xmllint --noout --schema "${XMLSCHEMA_PLANET_NOTES}" "${SAMPLE_FILE}" 2> /dev/null; then
      __logi "Sample validation passed"
      if [[ -n "${CLEAN:-}" ]] && [[ "${CLEAN}" = true ]]; then
       rm -f "${SAMPLE_FILE}"
      fi
     else
      __loge "ERROR: Sample validation failed"
      if [[ -n "${CLEAN:-}" ]] && [[ "${CLEAN}" = true ]]; then
       rm -f "${SAMPLE_FILE}"
      fi
      return 1
     fi
    else
     __loge "ERROR: Could not create valid sample file"
     if [[ -n "${CLEAN:-}" ]] && [[ "${CLEAN}" = true ]]; then
      rm -f "${SAMPLE_FILE}"
     fi
     return 1
    fi
   else
    __loge "ERROR: Could not create sample file"
    return 1
   fi
  else
   # For smaller files, validate the entire file
   if ! xmllint --noout --schema "${XMLSCHEMA_PLANET_NOTES}" "${XML_FILE}" 2> /dev/null; then
    __loge "ERROR: Full validation failed"
    return 1
   fi
  fi
 else
  __loge "ERROR: No notes found in XML file"
  return 1
 fi

 __logi "Alternative XML validation completed successfully"
 return 0
}

# Handle memory and timeout errors for XML validation
# Parameters:
#   $1 - Exit code from xmllint
#   $2 - File being validated
# Returns:
#   0 if error is handled, 1 if error is fatal
function __handle_xml_validation_error {
 local EXIT_CODE="${1}"
 local XML_FILE="${2}"

 case "${EXIT_CODE}" in
 124) # Timeout
  __loge "ERROR: XML validation timed out for file: ${XML_FILE}"
  __loge "ERROR: This may be due to a very large file or system constraints"
  return 1
  ;;
 137) # Killed (OOM)
  __loge "ERROR: XML validation was killed due to memory constraints for file: ${XML_FILE}"
  __loge "ERROR: The file is too large for the available system memory"
  return 1
  ;;
 139) # Segmentation fault
  __loge "ERROR: XML validation crashed with segmentation fault for file: ${XML_FILE}"
  __loge "ERROR: This may indicate corrupted XML or system issues"
  return 1
  ;;
 *) # Other errors
  __loge "ERROR: XML validation failed with exit code ${EXIT_CODE} for file: ${XML_FILE}"
  return 1
  ;;
 esac
}

# Clean up temporary files created during validation
# Parameters:
#   None
# Returns:
#   0 if cleanup successful
function __cleanup_validation_temp_files {
 # Only clean up if CLEAN is set to true
 if [[ -n "${CLEAN:-}" ]] && [[ "${CLEAN}" = true ]]; then
  local TEMP_FILES=(
   "/tmp/sample_validation.xml"
   "/tmp/validation_error.log"
  )

  for TEMP_FILE in "${TEMP_FILES[@]}"; do
   if [[ -f "${TEMP_FILE}" ]]; then
    rm -f "${TEMP_FILE}"
    __logd "Cleaned up temporary file: ${TEMP_FILE}"
   fi
  done
 else
  __logd "Skipping cleanup of temporary files (CLEAN=${CLEAN:-false})"
 fi

 return 0
}

# Enhanced XML validation with better error handling
# Parameters:
#   $1 - XML file path
#   $2 - Schema file path
# Returns:
#   0 if validation passes, 1 if validation fails
function __validate_xml_with_enhanced_error_handling {
 local XML_FILE="${1}"
 local SCHEMA_FILE="${2}"
 local TIMEOUT="${3:-${ETL_XML_VALIDATION_TIMEOUT:-300}}"
 local MAX_MEMORY="${4:-${ETL_XML_MEMORY_LIMIT_MB:-2048}M}"

 if [[ ! -f "${XML_FILE}" ]]; then
  __loge "ERROR: XML file not found: ${XML_FILE}"
  return 1
 fi

 if [[ ! -f "${SCHEMA_FILE}" ]]; then
  __loge "ERROR: Schema file not found: ${SCHEMA_FILE}"
  return 1
 fi

 # Get file size for validation strategy
 local FILE_SIZE
 FILE_SIZE=$(stat -c%s "${XML_FILE}" 2> /dev/null || echo "0")
 local SIZE_MB=$((FILE_SIZE / 1024 / 1024))

 # Get available system memory and adjust limits
 local AVAILABLE_MEMORY_MB
 AVAILABLE_MEMORY_MB=$(free -m | awk 'NR==2{printf "%.0f", $7}')
 local ADJUSTED_MEMORY_LIMIT

 if [[ "${AVAILABLE_MEMORY_MB}" -gt 0 ]]; then
  # Use 50% of available memory, but at least 1GB and at most 4GB
  ADJUSTED_MEMORY_LIMIT=$((AVAILABLE_MEMORY_MB / 2))
  if [[ "${ADJUSTED_MEMORY_LIMIT}" -lt 1024 ]]; then
   ADJUSTED_MEMORY_LIMIT=1024
  elif [[ "${ADJUSTED_MEMORY_LIMIT}" -gt 4096 ]]; then
   ADJUSTED_MEMORY_LIMIT=4096
  fi
  MAX_MEMORY="${ADJUSTED_MEMORY_LIMIT}M"
  __logi "Available memory: ${AVAILABLE_MEMORY_MB} MB, using limit: ${MAX_MEMORY}"
 else
  __logw "WARNING: Could not determine available memory, using default: ${MAX_MEMORY}"
 fi

 __logi "Validating XML file: ${XML_FILE} (${SIZE_MB} MB)"

 # Use appropriate validation strategy based on file size
 local LARGE_FILE_THRESHOLD="${ETL_LARGE_FILE_THRESHOLD_MB:-500}"
 if [[ "${SIZE_MB}" -gt 100 ]]; then
  __logw "WARNING: Large XML file detected (${SIZE_MB} MB). Using memory-optimized validation."

  # For very large files, use batch validation instead of full validation
  if [[ "${SIZE_MB}" -gt "${LARGE_FILE_THRESHOLD}" ]]; then
   __logw "WARNING: Very large file detected (${SIZE_MB} MB). Using batch validation method."
   if __validate_xml_in_batches "${XML_FILE}" "${SCHEMA_FILE}"; then
    __logi "Batch XML validation succeeded"
    return 0
   else
    __loge "ERROR: Batch XML validation failed"
    return 1
   fi
  fi

  # Try with timeout and memory limits
  if timeout "${TIMEOUT}" xmllint --noout --schema "${SCHEMA_FILE}" \
   --maxmem "${MAX_MEMORY}" "${XML_FILE}" 2> /dev/null; then
   __logi "XML validation succeeded with memory limits"
   return 0
  else
   local EXIT_CODE=$?
   __handle_xml_validation_error "${EXIT_CODE}" "${XML_FILE}"

   # Try alternative validation
   __logw "WARNING: Attempting alternative validation method..."
   if __validate_xml_structure_alternative "${XML_FILE}"; then
    __logi "Alternative XML validation passed"
    return 0
   else
    __loge "ERROR: All XML validation methods failed"
    return 1
   fi
  fi
 else
  # Standard validation for smaller files
  if xmllint --noout --schema "${SCHEMA_FILE}" "${XML_FILE}" 2> /dev/null; then
   __logi "XML validation succeeded"
   return 0
  else
   local EXIT_CODE=$?
   __handle_xml_validation_error "${EXIT_CODE}" "${XML_FILE}"
   return 1
  fi
 fi
}

# Validate XML file in batches to handle very large files
# Parameters:
#   $1 - XML file path
#   $2 - Schema file path
# Returns:
#   0 if validation passes, 1 if validation fails
function __validate_xml_in_batches {
 local XML_FILE="${1}"
 local SCHEMA_FILE="${2}"
 local BATCH_SIZE="${3:-${ETL_XML_BATCH_SIZE:-1000}}"
 local MAX_BATCHES="${4:-${ETL_XML_MAX_BATCHES:-10}}"

 if [[ ! -f "${XML_FILE}" ]]; then
  __loge "ERROR: XML file not found: ${XML_FILE}"
  return 1
 fi

 __logi "Starting batch validation for large XML file..."

 # First, validate basic XML structure
 if ! xmllint --noout --nonet "${XML_FILE}" 2> /dev/null; then
  __loge "ERROR: Basic XML structure validation failed"
  return 1
 fi

 # Check root element
 if ! grep -q "<osm-notes>" "${XML_FILE}" 2> /dev/null; then
  __loge "ERROR: Missing root element <osm-notes>"
  return 1
 fi

 # Count total notes
 local TOTAL_NOTES
 TOTAL_NOTES=$(grep -c "<note" "${XML_FILE}" 2> /dev/null || echo "0")
 __logi "Found ${TOTAL_NOTES} notes in XML file"

 if [[ "${TOTAL_NOTES}" -eq 0 ]]; then
  __loge "ERROR: No notes found in XML file"
  return 1
 fi

 # Calculate batch size based on total notes
 local ACTUAL_BATCH_SIZE=$((TOTAL_NOTES / MAX_BATCHES))
 if [[ "${ACTUAL_BATCH_SIZE}" -lt "${BATCH_SIZE}" ]]; then
  ACTUAL_BATCH_SIZE="${BATCH_SIZE}"
 fi

 __logi "Validating ${MAX_BATCHES} batches of approximately ${ACTUAL_BATCH_SIZE} notes each"

 # Create temporary directory for batch files
 local BATCH_DIR
 BATCH_DIR=$(mktemp -d "${TMP_DIR}/xml_batch_XXXXXX" 2> /dev/null)
 if [[ ! -d "${BATCH_DIR}" ]]; then
  __loge "ERROR: Could not create batch directory"
  return 1
 fi

 # Extract and validate batches
 local BATCH_COUNT=0
 local SUCCESS_COUNT=0
 local LINE_NUMBER=1

 while [[ "${BATCH_COUNT}" -lt "${MAX_BATCHES}" ]]; do
  local BATCH_FILE="${BATCH_DIR}/batch_${BATCH_COUNT}.xml"
  
  # Create batch XML with proper structure
  {
   echo '<?xml version="1.0"?>'
   echo '<osm-notes>'
   # Extract notes for this batch
   awk -v start="${LINE_NUMBER}" -v batch_size="${ACTUAL_BATCH_SIZE}" '
    /<note/ { count++; if (count >= start && count < start + batch_size) { in_note = 1; print; next } }
    in_note { print }
    /<\/note>/ { if (in_note) { in_note = 0; print } }
   ' "${XML_FILE}" | head -n $((ACTUAL_BATCH_SIZE * 10))
   echo '</osm-notes>'
  } > "${BATCH_FILE}" 2> /dev/null

  if [[ -s "${BATCH_FILE}" ]]; then
   # Validate batch against schema
   if xmllint --noout --schema "${SCHEMA_FILE}" "${BATCH_FILE}" 2> /dev/null; then
    __logd "Batch ${BATCH_COUNT} validation passed"
    ((SUCCESS_COUNT++))
   else
    __loge "ERROR: Batch ${BATCH_COUNT} validation failed"
    if [[ -n "${CLEAN:-}" ]] && [[ "${CLEAN}" = true ]]; then
     rm -rf "${BATCH_DIR}"
    fi
    return 1
   fi
  else
   __logw "WARNING: Batch ${BATCH_COUNT} is empty, skipping"
  fi

  ((BATCH_COUNT++))
  LINE_NUMBER=$((LINE_NUMBER + ACTUAL_BATCH_SIZE))
 done

 # Cleanup
 if [[ -n "${CLEAN:-}" ]] && [[ "${CLEAN}" = true ]]; then
  rm -rf "${BATCH_DIR}"
 fi

 __logi "Batch validation completed: ${SUCCESS_COUNT}/${BATCH_COUNT} batches passed"
 return 0
}

######
# MAIN

function main() {
 __log_start
 __logi "Preparing environment."
 __logd "Output saved at: ${TMP_DIR}."
 __logi "Process ID: ${$}"
 __logi "Processing: '${PROCESS_TYPE}'."

 if [[ "${PROCESS_TYPE}" == "-h" ]] \
  || [[ "${PROCESS_TYPE}" == "--help" ]]; then
  __show_help
  exit "${ERROR_HELP_MESSAGE}"
 else
  if [[ "${PROCESS_TYPE}" == "" ]]; then
   __logi "Process: Imports new notes from Planet."
  elif [[ "${PROCESS_TYPE}" == "--base" ]]; then
   __logi "Process: From scratch."
  elif [[ "${PROCESS_TYPE}" == "--boundaries" ]]; then
   __logi "Process: Downloads the countries and maritimes areas only."
  fi
 fi
 # Checks the prerequisities. It could terminate the process.
 __checkPrereqs

 __logw "Starting process."

 # Sets the trap in case of any signal.
 __trapOn
 exec 7> "${LOCK}"
 __logw "Validating single execution."
 ONLY_EXECUTION="no"
 flock -n 7
 ONLY_EXECUTION="yes"

 if [[ "${PROCESS_TYPE}" == "--base" ]]; then
  __dropSyncTables     # base
  __dropApiTables      # base
  __dropGenericObjects # base
  __dropBaseTables     # base
  __createBaseTables   # base
 elif [[ "${PROCESS_TYPE}" == "" ]]; then
  __dropSyncTables # sync
  set +E
  export RET_FUNC=0
  __checkBaseTables # sync
  if [[ "${RET_FUNC}" -ne 0 ]]; then
   __createBaseTables # sync
  fi
  set -E
  __createSyncTables # sync
 fi
 if [[ "${PROCESS_TYPE}" == "--base" ]] \
  || [[ "${PROCESS_TYPE}" == "--boundaries" ]]; then
  __dropCountryTables   # base and boundaries
  __createCountryTables # base and boundaries

  # Downloads the areas. It could terminate the execution if an error appears.
  if [[ -n "${BACKUP_COUNTRIES}" && "${BACKUP_COUNTRIES}" = true ]]; then
   echo "Please copy the rows from the backup table:"
   echo "   INSERT INTO countries "
   echo "     SELECT * FROM backup_countries ;"
   read -r
  else
   set +E
   __processCountries # base and boundaries
   __processMaritimes # base and boundaries
   set -E
  fi

  __cleanPartial # base and boundaries
  if [[ "${PROCESS_TYPE}" == "--boundaries" ]]; then
   __logw "Ending process."
   exit 0
  fi
 fi
 if [[ "${PROCESS_TYPE}" == "" ]]; then
  __downloadPlanetNotes # sync
  # Check if validation failed
  if ! __validatePlanetNotesXMLFileComplete; then
   __loge "ERROR: XML validation failed. Stopping process."
   exit "${ERROR_DATA_VALIDATION}"
  fi
  # Count notes in XML file
  __countXmlNotesPlanet "${PLANET_NOTES_FILE}.xml"
  # Split XML into parts and process in parallel if there are notes to process
  if [[ "${TOTAL_NOTES}" -gt 0 ]]; then
   __processPlanetNotesWithParallel
  else
   __logi "No notes found in XML file, skipping processing."
  fi
 fi
 __createFunctionToGetCountry # base & sync
 __createProcedures           # all
 if [[ "${PROCESS_TYPE}" == "" ]]; then
  __dropSyncTables # sync
  set +E
  export RET_FUNC=0
  __organizeAreas # sync
  set -E
  if [[ "${RET_FUNC}" -ne 0 ]]; then
   __createCountryTables # sync
   if [[ -n "${BACKUP_COUNTRIES}" && "${BACKUP_COUNTRIES}" = true ]]; then
    echo "Please copy the rows from the backup table:"
    echo "   INSERT INTO countries "
    echo "     SELECT * FROM backup_countries ;"
    read -r
   else
    __processCountries # sync
    __processMaritimes # sync
   fi
   __cleanPartial # sync
   __organizeAreas
  fi
  __getLocationNotes # sync
 fi
 __cleanNotesFiles  # base & sync
 __analyzeAndVacuum # base & sync

 rm -f "${LOCK}"
 __logw "Ending process."
 __log_finish
}

# Allows other users to read the directory.
chmod go+x "${TMP_DIR}"

__start_logger
if [[ ! -t 1 ]]; then
 __set_log_file "${LOG_FILENAME}"
 main >> "${LOG_FILENAME}" 2>&1
 if [[ -n "${CLEAN:-}" ]] && [[ "${CLEAN}" = true ]]; then
  mv "${LOG_FILENAME}" "/tmp/${BASENAME}_$(date +%Y-%m-%d_%H-%M-%S \
   || true).log"
  rmdir "${TMP_DIR}"
 fi
else
 main
fi
