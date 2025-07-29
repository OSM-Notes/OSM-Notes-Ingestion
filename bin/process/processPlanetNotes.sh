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
# Version: 2025-07-27
declare -r VERSION="2025-07-27"

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
declare -r PLANET_NOTES_FILENAME="planet-notes-latest.osn"
declare -r PLANET_NOTES_FILE="${TMP_DIR}/${PLANET_NOTES_FILENAME}"

# PostgreSQL SQL script files.
# Drop sync tables.
declare -r POSTGRES_11_DROP_SYNC_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_11_dropSyncTables.sql"
# Drop API tables.
declare -r POSTGRES_12_DROP_API_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_12_dropApiTables.sql"
# Drop base tables.
declare -r POSTGRES_13_DROP_BASE_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_13_dropBaseTables.sql"
# Drop country tables.
declare -r POSTGRES_14_DROP_COUNTRY_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_14_dropCountryTables.sql"
# Create enums.
declare -r POSTGRES_21_CREATE_ENUMS="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_21_createBaseTables_enum.sql"
# Create base tables.
declare -r POSTGRES_22_CREATE_BASE_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_22_createBaseTables_tables.sql"
# Create constraints for base tables.
declare -r POSTGRES_23_CREATE_CONSTRAINTS="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_23_createBaseTables_constraints.sql"
# Create sync tables.
declare -r POSTGRES_24_CREATE_SYNC_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_24_createSyncTables.sql"
# Create partitions for parallel processing.
declare -r POSTGRES_25_CREATE_PARTITIONS="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_25_createPartitions.sql"
# Create country tables.
declare -r POSTGRES_26_CREATE_COUNTRY_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_25_createCountryTables.sql"
# Vacuum and analyze.
declare -r POSTGRES_31_VACUUM_AND_ANALYZE="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_31_analyzeVacuum.sql"
# Load partitioned sync notes.
declare -r POSTGRES_41_LOAD_PARTITIONED_SYNC_NOTES="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_41_loadPartitionedSyncNotes.sql"
# Consolidate partitions.
declare -r POSTGRES_42_CONSOLIDATE_PARTITIONS="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_42_consolidatePartitions.sql"
# Remove duplicates.
declare -r POSTGRES_43_REMOVE_DUPLICATES="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_43_removeDuplicates.sql"
# Assign sequence for comments.
declare -r POSTGRES_44_COMMENTS_SEQUENCE="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_43_commentsSequence.sql"
# Load text comments.
declare -r POSTGRES_45_LOAD_TEXT_COMMENTS="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_44_loadTextComments.sql"
# Load text comments objects.
declare -r POSTGRES_46_OBJECTS_TEXT_COMMENTS="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_45_objectsTextComments.sql"
# Move sync to main tables.
declare -r POSTGRES_43_MOVE_SYNC_TO_MAIN="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_43_moveSyncToMain.sql"

# Flag to define that the process should update the location of notes.
# This variable is used in functionsProcess.sh
export UPDATE_NOTE_LOCATION=false

# Files for countries and maritimes processing.
declare -r COUNTRIES_FILE="${TMP_DIR}/countries"
declare -r MARITIMES_FILE="${TMP_DIR}/maritimes"

# Error codes (defined here to avoid shellcheck warnings)
declare -r ERROR_HELP_MESSAGE=1
declare -r ERROR_INVALID_ARGUMENT=242
declare -r ERROR_MISSING_LIBRARY=241

# Location of the common functions.
declare -r FUNCTIONS_FILE="${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh"

# XSLT transformation files for Planet format (used by parallel processing).
declare -r XSLT_NOTES_FILE="${SCRIPT_BASE_DIRECTORY}/xslt/notes-Planet-csv.xslt"
declare -r XSLT_NOTE_COMMENTS_FILE="${SCRIPT_BASE_DIRECTORY}/xslt/note_comments-Planet-csv.xslt"
declare -r XSLT_TEXT_COMMENTS_FILE="${SCRIPT_BASE_DIRECTORY}/xslt/note_comments_text-Planet-csv.xslt"

# Control variables for functionsProcess.sh
export ONLY_EXECUTION="no"

###########
# FUNCTIONS

# shellcheck source=functionsProcess.sh
# shellcheck disable=SC1091
source "${FUNCTIONS_FILE}"
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
 local sql_files=(
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
 for sql_file in "${sql_files[@]}"; do
  if ! __validate_sql_structure "${sql_file}"; then
   __loge "ERROR: SQL file validation failed: ${sql_file}"
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
 if ! __validate_xml_structure "${XMLSCHEMA_PLANET_NOTES}" "osm-notes"; then
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
 __log_finish
 set -e
}

# Drop sync tables.
function __dropSyncTables {
 __log_start
 __logi "Dropping sync tables."
 psql -d "${DBNAME}" -c "SET app.max_threads = '${MAX_THREADS}';" -f "${POSTGRES_11_DROP_SYNC_TABLES}"
 __log_finish
}

# Drop tables for notes from API.
function __dropApiTables {
 __log_start
 __logi "Dropping API tables."
 psql -d "${DBNAME}" -c "SET app.max_threads = '${MAX_THREADS}';" -f "${POSTGRES_12_DROP_API_TABLES}"
 __log_finish
}

# Drop existing base tables.
function __dropBaseTables {
 __log_start
 __logi "Dropping base tables."
 psql -d "${DBNAME}" -f "${POSTGRES_13_DROP_BASE_TABLES}"
 __log_finish
}

# Drop existing base tables.
function __dropCountryTables {
 __log_start
 __logi "Dropping country tables."
 psql -d "${DBNAME}" -f "${POSTGRES_14_DROP_COUNTRY_TABLES}"
 __log_finish
}

# Creates base tables that hold the whole history.
function __createBaseTables {
 __log_start
 __logi "Creating tables."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_21_CREATE_ENUMS}"

 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_22_CREATE_BASE_TABLES}"

 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_23_CREATE_CONSTRAINTS}"
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
 if [[ -n "${CLEAN}" ]] && [[ "${CLEAN}" = true ]]; then
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
 if [[ -n "${CLEAN}" ]] && [[ "${CLEAN}" = true ]]; then
  rm -f "${PLANET_NOTES_FILE}.xml" "${OUTPUT_NOTES_FILE}" \
   "${OUTPUT_NOTE_COMMENTS_FILE}" "${OUTPUT_TEXT_COMMENTS_FILE}"
  rm -f "${TMP_DIR}"/part_country_* "${TMP_DIR}"/part_maritime_*
 fi
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
  __downloadPlanetNotes        # sync
  __validatePlanetNotesXMLFile # sync
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
 if [[ -n "${CLEAN}" ]] && [[ "${CLEAN}" = true ]]; then
  mv "${LOG_FILENAME}" "/tmp/${BASENAME}_$(date +%Y-%m-%d_%H-%M-%S \
   || true).log"
  rmdir "${TMP_DIR}"
 fi
else
 main
fi
