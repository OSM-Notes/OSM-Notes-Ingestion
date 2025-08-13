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
# Version: 2025-08-12
VERSION="2025-08-12"

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

# Enable failed execution file generation
export GENERATE_FAILED_FILE=true

# Failed execution file
declare -r FAILED_EXECUTION_FILE="${TMP_DIR}/failed_execution.log"

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

# Function to handle cleanup on exit respecting CLEAN flag
function __cleanup_on_exit() {
 local EXIT_CODE=$?

 # Only clean if CLEAN is true and this is an error exit (non-zero)
 if [[ "${CLEAN}" == "true" ]] && [[ ${EXIT_CODE} -ne 0 ]] && [[ -n "${TMP_DIR:-}" ]]; then
  __logw "Error detected (exit code: ${EXIT_CODE}), cleaning up temporary directory: ${TMP_DIR}"
  if [[ -d "${TMP_DIR}" ]]; then
   rm -rf "${TMP_DIR}" 2> /dev/null || true
   __logi "Temporary directory cleaned up: ${TMP_DIR}"
  fi
 elif [[ "${CLEAN}" == "false" ]] && [[ ${EXIT_CODE} -ne 0 ]]; then
  __logw "Error detected (exit code: ${EXIT_CODE}), but CLEAN=false - preserving temporary files in: ${TMP_DIR:-}"
 fi

 exit "${EXIT_CODE}"
}

# Set trap to handle cleanup on any exit (after loading logging functions)
trap '__cleanup_on_exit' EXIT

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

 __splitXmlForParallelPlanet "${PLANET_NOTES_FILE}"
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
  rm -f "${PLANET_NOTES_FILE}" "${OUTPUT_NOTES_FILE}" \
   "${OUTPUT_NOTE_COMMENTS_FILE}" "${OUTPUT_TEXT_COMMENTS_FILE}"
  rm -f "${TMP_DIR}"/part_country_* "${TMP_DIR}"/part_maritime_*
 fi
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
 if [[ ! -f "${PLANET_NOTES_FILE}" ]]; then
  __loge "ERROR: Planet notes file not found: ${PLANET_NOTES_FILE}"
  exit "${ERROR_DATA_VALIDATION}"
 fi

 # Clean up any existing temporary files
 __cleanup_validation_temp_files

 # Validate XML structure against schema with enhanced error handling
 __logi "Validating XML structure against schema..."
 if ! __validate_xml_with_enhanced_error_handling "${PLANET_NOTES_FILE}" "${XMLSCHEMA_PLANET_NOTES}"; then
  __loge "ERROR: XML structure validation failed: ${PLANET_NOTES_FILE}"
  __cleanup_validation_temp_files
  exit "${ERROR_DATA_VALIDATION}"
 fi

 # Validate dates in XML file
 __logi "Validating dates in XML file..."
 if ! __validate_xml_dates "${PLANET_NOTES_FILE}"; then
  __loge "ERROR: XML date validation failed: ${PLANET_NOTES_FILE}"
  __cleanup_validation_temp_files
  exit "${ERROR_DATA_VALIDATION}"
 fi

 # Validate coordinates in XML file
 __logi "Validating coordinates in XML file..."
 if ! __validate_xml_coordinates "${PLANET_NOTES_FILE}"; then
  __loge "ERROR: XML coordinate validation failed: ${PLANET_NOTES_FILE}"
  __cleanup_validation_temp_files
  exit "${ERROR_DATA_VALIDATION}"
 fi

 # Final cleanup
 __cleanup_validation_temp_files

 __logi "All Planet notes XML validations passed successfully"
 __log_finish
}

# Validates XML structure with enhanced error handling for large files
# Parameters:
#   $1 - XML file path
#   $2 - Schema file path (optional for very large files)
# Returns:
#   0 if validation passes, 1 if validation fails
# Enhanced XML validation with error handling
# Now uses consolidated functions from consolidatedValidationFunctions.sh
function __validate_xml_with_enhanced_error_handling {
 # Source the consolidated validation functions
 if [[ -f "${SCRIPT_BASE_DIRECTORY}/bin/consolidatedValidationFunctions.sh" ]]; then
  source "${SCRIPT_BASE_DIRECTORY}/bin/consolidatedValidationFunctions.sh"
  __validate_xml_with_enhanced_error_handling "$@"
 else
  # Fallback if consolidated functions are not available
  __loge "ERROR: Consolidated validation functions not found. Please ensure consolidatedValidationFunctions.sh is available."
  return 1
 fi
}

# Basic XML structure validation (lightweight)
# Parameters:
#   $1 - XML file path
# Returns:
#   0 if validation passes, 1 if validation fails
function __validate_xml_basic {
 local XML_FILE="${1}"

 if [[ ! -f "${XML_FILE}" ]]; then
  __loge "ERROR: XML file not found: ${XML_FILE}"
  return 1
 fi

 __logi "Performing basic XML validation: ${XML_FILE}"

 # Check basic XML structure using xmllint without schema
 local XMLLINT_OUTPUT
 if ! timeout 120 xmllint --noout --nonet "${XML_FILE}" 2>&1; then
  XMLLINT_OUTPUT=$(timeout 120 xmllint --noout --nonet "${XML_FILE}" 2>&1)
  __loge "ERROR: Basic XML structure validation failed - xmllint output: ${XMLLINT_OUTPUT}"
  return 1
 fi

 # Check root element
 if ! grep -q "<osm-notes>" "${XML_FILE}" 2> /dev/null; then
  __loge "ERROR: Missing root element <osm-notes> in ${XML_FILE}"
  return 1
 fi

 # Check for note elements
 if ! grep -q "<note" "${XML_FILE}" 2> /dev/null; then
  __loge "ERROR: No note elements found in XML file ${XML_FILE}"
  return 1
 fi

 # Count total notes
 local TOTAL_NOTES
 TOTAL_NOTES=$(grep -c "<note" "${XML_FILE}" 2> /dev/null || echo "0")

 if [[ "${TOTAL_NOTES}" -gt 0 ]]; then
  __logi "Found ${TOTAL_NOTES} notes in XML file"

  # Check for proper note structure (opening and closing tags)
  local OPENING_TAGS
  local CLOSING_TAGS
  OPENING_TAGS=$(grep -c "<note" "${XML_FILE}" 2> /dev/null || echo "0")
  CLOSING_TAGS=$(grep -c "</note>" "${XML_FILE}" 2> /dev/null || echo "0")

  if [[ "${OPENING_TAGS}" -ne "${CLOSING_TAGS}" ]]; then
   __loge "ERROR: Mismatched note tags: ${OPENING_TAGS} opening, ${CLOSING_TAGS} closing"
   return 1
  fi

  __logi "Basic XML validation passed"
  return 0
 else
  __loge "ERROR: No notes found in XML file"
  return 1
 fi
}

# Structure-only validation for very large files (no xmllint)
# Parameters:
#   $1 - XML file path
# Returns:
#   0 if validation passes, 1 if validation fails
function __validate_xml_structure_only {
 local XML_FILE="${1}"

 if [[ ! -f "${XML_FILE}" ]]; then
  __loge "ERROR: XML file not found: ${XML_FILE}"
  return 1
 fi

 __logi "Performing structure-only validation for very large file: ${XML_FILE}"

 # Check root element
 if ! grep -q "<osm-notes>" "${XML_FILE}" 2> /dev/null; then
  __loge "ERROR: Missing root element <osm-notes> in ${XML_FILE}"
  return 1
 fi

 # Check for note elements
 if ! grep -q "<note" "${XML_FILE}" 2> /dev/null; then
  __loge "ERROR: No note elements found in XML file ${XML_FILE}"
  return 1
 fi

 # Count total notes
 local TOTAL_NOTES
 TOTAL_NOTES=$(grep -c "<note" "${XML_FILE}" 2> /dev/null || echo "0")

 if [[ "${TOTAL_NOTES}" -gt 0 ]]; then
  __logi "Found ${TOTAL_NOTES} notes in XML file"

  # Check for proper note structure (opening and closing tags)
  local OPENING_TAGS
  local CLOSING_TAGS
  OPENING_TAGS=$(grep -c "<note" "${XML_FILE}" 2> /dev/null || echo "0")
  CLOSING_TAGS=$(grep -c "</note>" "${XML_FILE}" 2> /dev/null || echo "0")

  if [[ "${OPENING_TAGS}" -ne "${CLOSING_TAGS}" ]]; then
   __loge "ERROR: Mismatched note tags: ${OPENING_TAGS} opening, ${CLOSING_TAGS} closing"
   return 1
  fi

  # Additional lightweight checks
  # Check for common XML issues
  if grep -q "&[^a-zA-Z0-9#]" "${XML_FILE}" 2> /dev/null; then
   __logw "WARNING: Potential unescaped ampersands found in XML"
  fi

  # Check for basic XML structure integrity
  local FIRST_LINE
  local LAST_LINE
  FIRST_LINE=$(head -1 "${XML_FILE}" 2> /dev/null | grep -c "<?xml\|<osm-notes>" || echo "0")
  LAST_LINE=$(tail -1 "${XML_FILE}" 2> /dev/null | grep -c "</osm-notes>" || echo "0")

  if [[ "${FIRST_LINE}" -eq 0 ]] && [[ "${LAST_LINE}" -eq 0 ]]; then
   __logw "WARNING: XML declaration or root element structure may be incomplete"
  fi

  __logi "Structure-only validation passed for very large file"
  return 0
 else
  __loge "ERROR: No notes found in XML file"
  return 1
 fi
}

# Monitor xmllint resource usage in the background
# Parameters:
#   $1 - PID of the xmllint process
#   $2 - monitoring interval in seconds
#   $3 - log file for resource monitoring
function __monitor_xmllint_resources {
 local XMLLINT_PID="${1}"
 local INTERVAL="${2:-5}"
 local MONITOR_LOG="${3:-${TMP_DIR}/xmllint_resources.log}"

 __logi "Starting resource monitoring for xmllint PID: ${XMLLINT_PID}"

 {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Starting resource monitoring for PID ${XMLLINT_PID}"

  while kill -0 "${XMLLINT_PID}" 2> /dev/null; do
   if ps -p "${XMLLINT_PID}" > /dev/null 2>&1; then
    local CPU_USAGE
    local MEM_USAGE
    local RSS_KB
    CPU_USAGE=$(ps -p "${XMLLINT_PID}" -o %cpu --no-headers 2> /dev/null | tr -d ' ')
    MEM_USAGE=$(ps -p "${XMLLINT_PID}" -o %mem --no-headers 2> /dev/null | tr -d ' ')
    RSS_KB=$(ps -p "${XMLLINT_PID}" -o rss --no-headers 2> /dev/null | tr -d ' ')

    echo "$(date '+%Y-%m-%d %H:%M:%S') - PID: ${XMLLINT_PID}, CPU: ${CPU_USAGE}%, Memory: ${MEM_USAGE}%, RSS: ${RSS_KB}KB"

    # Check if memory usage is too high
    if [[ -n "${RSS_KB}" ]] && [[ "${RSS_KB}" -gt 2097152 ]]; then # 2GB in KB
     echo "$(date '+%Y-%m-%d %H:%M:%S') - WARNING: Memory usage exceeds 2GB (${RSS_KB}KB)"
    fi
   fi
   sleep "${INTERVAL}"
  done

  echo "$(date '+%Y-%m-%d %H:%M:%S') - Process ${XMLLINT_PID} finished or terminated"
 } >> "${MONITOR_LOG}" 2>&1 &

 local MONITOR_PID=$!
 echo "${MONITOR_PID}"
}

# Run xmllint with resource limitations to prevent system overload
# Parameters:
#   $1 - timeout in seconds
#   $2 - xmllint command arguments
#   $3 - XML file path
# Returns:
#   0 if validation passes, 1 if validation fails
function __run_xmllint_with_limits {
 local TIMEOUT_SECS="${1}"
 local XMLLINT_ARGS="${2}"
 local XML_FILE="${3}"

 # CPU limit: 25% of one core, Memory limit: 2GB
 local CPU_LIMIT="25"
 local MEMORY_LIMIT="2000000" # 2GB in KB
 local MONITOR_LOG="${TMP_DIR}/xmllint_resources.log"

 __logi "Running xmllint with resource limits: CPU ${CPU_LIMIT}%, Memory ${MEMORY_LIMIT}KB"

 # Create a temporary script to run xmllint with resource limits
 local TEMP_SCRIPT
 TEMP_SCRIPT=$(mktemp)
 cat > "${TEMP_SCRIPT}" << EOF
#!/bin/bash
# Set memory limit
ulimit -v ${MEMORY_LIMIT}
# Run xmllint with timeout
timeout ${TIMEOUT_SECS} xmllint ${XMLLINT_ARGS} "${XML_FILE}" &
XMLLINT_PID=\$!
echo \$XMLLINT_PID > "${TMP_DIR}/xmllint.pid"
wait \$XMLLINT_PID
EOF

 chmod +x "${TEMP_SCRIPT}"

 # Run with cpulimit if available, otherwise just run the script
 local RESULT=0
 local MONITOR_PID=""

 if command -v cpulimit > /dev/null 2>&1; then
  # Start the process with cpulimit
  cpulimit --limit="${CPU_LIMIT}" "${TEMP_SCRIPT}" &
  local MAIN_PID=$!

  # Wait a bit for xmllint to start, then get its PID
  sleep 2
  if [[ -f "${TMP_DIR}/xmllint.pid" ]]; then
   local XMLLINT_PID
   XMLLINT_PID=$(cat "${TMP_DIR}/xmllint.pid" 2> /dev/null)
   if [[ -n "${XMLLINT_PID}" ]]; then
    MONITOR_PID=$(__monitor_xmllint_resources "${XMLLINT_PID}" 5 "${MONITOR_LOG}")
   fi
  fi

  # Wait for the main process to complete
  wait "${MAIN_PID}"
  RESULT=$?
 else
  __logw "WARNING: cpulimit not available, running without CPU limits"

  # Start the process normally
  "${TEMP_SCRIPT}" &
  local MAIN_PID=$!

  # Wait a bit for xmllint to start, then get its PID
  sleep 2
  if [[ -f "${TMP_DIR}/xmllint.pid" ]]; then
   local XMLLINT_PID
   XMLLINT_PID=$(cat "${TMP_DIR}/xmllint.pid" 2> /dev/null)
   if [[ -n "${XMLLINT_PID}" ]]; then
    MONITOR_PID=$(__monitor_xmllint_resources "${XMLLINT_PID}" 5 "${MONITOR_LOG}")
   fi
  fi

  # Wait for the main process to complete
  wait "${MAIN_PID}"
  RESULT=$?
 fi

 # Stop monitoring if it's running
 if [[ -n "${MONITOR_PID}" ]]; then
  kill "${MONITOR_PID}" 2> /dev/null || true
 fi

 # Clean up
 rm -f "${TEMP_SCRIPT}" "${TMP_DIR}/xmllint.pid"

 # Show resource monitoring summary if available
 if [[ -f "${MONITOR_LOG}" ]]; then
  __logi "Resource monitoring log available at: ${MONITOR_LOG}"
  local MAX_CPU
  local MAX_MEM
  MAX_CPU=$(grep "CPU:" "${MONITOR_LOG}" | sed 's/.*CPU: \([0-9.]*\)%.*/\1/' | sort -n | tail -1)
  MAX_MEM=$(grep "RSS:" "${MONITOR_LOG}" | sed 's/.*RSS: \([0-9]*\)KB.*/\1/' | sort -n | tail -1)
  if [[ -n "${MAX_CPU}" ]] && [[ -n "${MAX_MEM}" ]]; then
   __logi "Peak resource usage - CPU: ${MAX_CPU}%, Memory: ${MAX_MEM}KB"
  fi
 fi

 # Log output if there was an error
 if [[ ${RESULT} -ne 0 ]]; then
  __loge "xmllint validation failed with exit code: ${RESULT}"
  if [[ ${RESULT} -eq 124 ]]; then
   __loge "Process was terminated due to timeout (${TIMEOUT_SECS}s)"
  elif [[ ${RESULT} -eq 137 ]]; then
   __loge "Process was killed (likely due to memory limits)"
  fi
 fi

 return "${RESULT}"
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

# Function that activates the error trap.
function __trapOn() {
 __log_start
 trap '{ 
  local ERROR_LINE="${LINENO}"
  local ERROR_COMMAND="${BASH_COMMAND}"
  local ERROR_EXIT_CODE="$?"
  
  # Only report actual errors, not successful returns
  if [[ "${ERROR_EXIT_CODE}" -ne 0 ]]; then
   # Get the main script name (the one that was executed, not the library)
   local MAIN_SCRIPT_NAME
   MAIN_SCRIPT_NAME=$(basename "${0}" .sh)
   
   printf "%s ERROR: The script %s did not finish correctly. Temporary directory: ${TMP_DIR:-} - Line number: %d.\n" "$(date +%Y%m%d_%H:%M:%S)" "${MAIN_SCRIPT_NAME}" "${ERROR_LINE}";
   printf "ERROR: Failed command: %s (exit code: %d)\n" "${ERROR_COMMAND}" "${ERROR_EXIT_CODE}";
   if [[ "${GENERATE_FAILED_FILE}" = true ]]; then
    {
     echo "Error occurred at $(date +%Y%m%d_%H:%M:%S)"
     echo "Script: ${MAIN_SCRIPT_NAME}"
     echo "Line number: ${ERROR_LINE}"
     echo "Failed command: ${ERROR_COMMAND}"
     echo "Exit code: ${ERROR_EXIT_CODE}"
     echo "Temporary directory: ${TMP_DIR:-unknown}"
     echo "Process ID: $$"
    } > "${FAILED_EXECUTION_FILE}"
   fi;
   exit ${ERROR_EXIT_CODE};
  fi;
 }' ERR
 trap '{ 
  # Get the main script name (the one that was executed, not the library)
  local MAIN_SCRIPT_NAME
  MAIN_SCRIPT_NAME=$(basename "${0}" .sh)
  
  printf "%s WARN: The script %s was terminated. Temporary directory: ${TMP_DIR:-}\n" "$(date +%Y%m%d_%H:%M:%S)" "${MAIN_SCRIPT_NAME}";
  if [[ "${GENERATE_FAILED_FILE}" = true ]]; then
   {
    echo "Script terminated at $(date +%Y%m%d_%H:%M:%S)"
    echo "Script: ${MAIN_SCRIPT_NAME}" 
    echo "Temporary directory: ${TMP_DIR:-unknown}"
    echo "Process ID: $$"
    echo "Signal: SIGTERM/SIGINT"
   } > "${FAILED_EXECUTION_FILE}"
  fi;
  exit ${ERROR_GENERAL};
 }' SIGINT SIGTERM
 __log_finish
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
  __countXmlNotesPlanet "${PLANET_NOTES_FILE}"
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
