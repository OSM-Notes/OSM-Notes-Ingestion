#!/bin/bash

# This script prepares a database for note analysis, and loads the notes from
# the planet, completely or the missing ones. Depending on the invokation it
# performs some tasks.
# The script structure is:
# * Creates the database structure.
# * Downloads the list of country ids (overpass).
# * Downloads the country boundaries (overpass).
# * Downloads the list of maritime area ids (overpass).
# * Downloads the maritime area boundaries (overpass).
# * Imports the boundaries into the db.
# * Downloads the planet notes.
# * Converts the notes into flat CSV files.
# * Imports the notes into the db.
# * Sets the order for countries by zones.
# * Creates a function to get the country of a position using the order by
#   zones.
# * Runs the function against all notes.
#
# Globally there are two workflows:
#
# * base > sync (This workflow is called from processApiNotes)
# * base > flatfile > locatenotes > sync (if there is not enough memory for the
#   other workflow, this can be used with 2 computers)
#
# These are some examples to call this script:
#
# * export LOG_LEVEL=DEBUG ; ~/OSM-Notes-profile/bin/process/processPlanetNotes.sh --base
# * export LOG_LEVEL=DEBUG ; ~/OSM-Notes-profile/bin/process/processPlanetNotes.sh
# * export LOG_LEVEL=DEBUG ; ~/OSM-Notes-profile/bin/process/processPlanetNotes.sh --flatfile
# * export LOG_LEVEL=DEBUG ; ~/OSM-Notes-profile/bin/process/processPlanetNotes.sh --locatenotes output-notes.csv output-note_comments.csv output-text_comments.csv
# * export LOG_LEVEL=DEBUG ; ~/OSM-Notes-profile/bin/process/processPlanetNotes.sh --boundaries
#
# The design of this architecture is at: https://miro.com/app/board/uXjVPDTbDok=/
#
# If the download fails with "Too many requests", you can check this page:
# http://overpass-api.de/api/status and increase the sleep time between loops.
# There is a variable for this: SECONDS_TO_WAIT.
#
# Known errors:
# * Austria has an issue to be imported with ogr2ogr for a particular thing in
#   the geometry. A simplification is done to upload it. However, there is a
#   missing part not being imported.
# * Taiwan has an issue to be imported with ogr2ogr for a very long row. Some
#   fields are removed.
# * The Gaza Strip is not at the same level as a country. The ID is hardcoded.
# * Not all countries have defined the maritimes borders. Also, not all
#   countries have signed the Covemar.
#
# The following files are necessary to prepare the environment.
# https://github.com/tyrasd/osmtogeojson
# npm install -g osmtogeojson
# https://sourceforge.net/projects/saxon/files/Saxon-HE/11/Java/SaxonHE11-4J.zip/download
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
# To specify the Saxon location, you can put this file in the same directory as
# saxon ; otherwise, it will this location:
#   export SAXON_JAR=~/saxon/
#
# To not remove all generated files, you can export this:
#   export CLEAN=false
#
# To insert the rows from a backup for boundaries and notes:
#   export BACKUP=true
#   export BACKUP_COUNTRIES=true
# It will need to run these from a PostgreSQL console:
#   INSERT INTO countries
#    SELECT * FROM backup_countries ;
#   UPDATE notes AS n
#    SET id_country = b.id_country
#    FROM backup_note_country AS b
#    WHERE b.note_id = n.note_id
#     AND n.id_country IS NULL;
# To create the copy before the execution:
#   CREATE TABLE backup_countries AS TABLE countries;
#   CREATE TABLE backup_note_country AS
#    SELECT note_id, id_country FROM notes;
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
# from tries 
# join countries c
# on t.id_country = c.country_id
# group by iter, area, country_name_en
# order by area, count(1) desc;
#
# Sections per parameter:
#                                   empty    base    locate  bounda flatfile
#                                   (sync)           notes   ries
# __dropSyncTables                             x
# __dropApiTables                              x
# __dropBaseTables                             x
# __createBaseTables                           x
# __dropSyncTables                     x               x
# __checkBaseTables                    x               x
# __createBaseTables                   x               x
# __createSyncTables                   x               x
# __dropCountryTables                          x               x
# __createCountryTables                        x               x
# __processCountries                           x               x
# __processMaritimes                           x               x
# __cleanPartial                               x               x
# __downloadPlanetNotes                x                                x
# __validatePlanetNotesXMLFile         x                                x
# __convertPlanetNotesToFlatFile       x                                x
# __createFunctionToGetCountry         x       x       x
# __createProcedures                   x       x       x
# __analyzeAndVacuum                   x       x       x
# __copyFlatFiles                                      x
# __loadSyncNotes                      x               x
# __removeDuplicates                   x               x
# __dropSyncTables                     x               x
# __organizeAreas                      x               x
# __getLocationNotes                   x               x
# __cleanNotesFiles                    x       x       x
#
# This is the list of error codes:
# 1) Help message.
# 241) Library or utility missing.
# 242) Invalid argument for script invocation.
# 243) Logger utility is not available.
# 244) Ids list cannot be downloaded.
# 249) Error downloading boundary.
#
# For contributing, please execute these commands before subimitting:
# * shellcheck -x -o all processPlanetNotes.sh
# * shfmt -w -i 1 -sr -bn processPlanetNotes.sh
#
# Author: Andres Gomez (AngocA)
# Version: 2024-01-09
declare -r VERSION="2024-01-09"

#set -xv
# Fails when a variable is not initialized.
set -u
# Fails with an non-zero return code.
set -e
# Fails if the commands of a pipe return non-zero.
set -o pipefail
# Fails if an internal function fails.
set -E

# Error codes.
# 244: The list of ids for boundary geometries cannot be downloaded.
declare -r ERROR_DOWNLOADING_ID_LIST=244
# 249: Error downloading boundary.
declare -r ERROR_DOWNLOADING_BOUNDARY=249

# If all files should be deleted. In case of an error, this could be disabled.
# You can defined when calling: export CLEAN=false
declare -r CLEAN=${CLEAN:-true}
# If boundary rows and location of the notes are retrieved from backup table.
declare -r BACKUP=${BACKUP:-false}
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
# shellcheck source=../../etc/properties.sh
source "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh"

declare BASENAME
BASENAME=$(basename -s .sh "${0}")
readonly BASENAME
# Temporal directory for all files.
declare TMP_DIR
TMP_DIR=$(mktemp -d "/tmp/${BASENAME}_XXXXXX")
readonly TMP_DIR
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

# Flat file to start from load.
declare -r FLAT_NOTES_FILE=${2:-}
declare -r FLAT_NOTE_COMMENTS_FILE=${3:-}
declare -r FLAT_TEXT_COMMENTS_FILE=${4:-}

# File that contains the ids of the boundaries for countries.
declare -r COUNTRIES_FILE="${TMP_DIR}/countries"
# File taht contains the ids of the boundaries of the maritimes areas.
declare -r MARITIMES_FILE="${TMP_DIR}/maritimes"
# File for the Overpass query.
declare -r QUERY_FILE="${TMP_DIR}/query"

# Name of the file to download.
declare -r PLANET_NOTES_NAME="planet-notes-latest.osn"
# Filename for the OSM Notes from Planet.
declare -r PLANET_NOTES_FILE="${TMP_DIR}/${PLANET_NOTES_NAME}"

# PostgreSQL files.
# Drop sync tables.
declare -r POSTGRES_11_DROP_SYNC_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_11_dropSyncTables.sql"
# Drop api tables.
declare -r POSTGRES_12_DROP_API_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_12_dropApiTables.sql"
# Drop base tables.
declare -r POSTGRES_13_DROP_BASE_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_13_dropBaseTables.sql"
# Drop current country tables.
declare -r POSTGRES_14_DROP_COUNTRY_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_14_dropCountryTables.sql"
# Create enums.
declare -r POSTGRES_21_CREATE_ENUMS="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_21_createBaseTables-enum.sql"
# Create base tables.
declare -r POSTGRES_22_CREATE_BASE_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_22_createBaseTables-tables.sql"
# Create constraints for base tables.
declare -r POSTGRES_23_CREATE_CONSTRAINTS="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_23_createBaseTables-constraints.sql"
# Create sync tables.
declare -r POSTGRES_24_CREATE_SYNC_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_24_createSyncTables.sql"
# Create country tables.
declare -r POSTGRES_25_CREATE_COUNTRY_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_25_createCountryTables.sql"
# Vacuum and analyze.
declare -r POSTGRES_31_VACUUM_AND_ANALYZE="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_31_analyzeVacuum.sql"
# Load sync notes.
declare -r POSTGRES_41_LOAD_SYNC_NOTES="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_41_loadSyncNotes.sql"
# Remove duplicates.
declare -r POSTGRES_42_REMOVE_DUPLICATES="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_42_removeDuplicates.sql"
# Assign sequence for comments
declare -r POSTGRES_43_COMMENTS_SEQUENCE="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_43_commentsSequence.sql"
# Load text comments.
declare -r POSTGRES_44_LOAD_TEXT_COMMENTS="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_44_loadTextComments.sql"
# Load text comments.
declare -r POSTGRES_45_OBJECTS_TEXT_COMMENTS="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_45_objectsTextComments.sql"

# Overpass queries
# Get countries.
declare -r OVERPASS_COUNTRIES="${SCRIPT_BASE_DIRECTORY}/overpass/countries.op"
# Get maritimes.
declare -r OVERPASS_MARITIMES="${SCRIPT_BASE_DIRECTORY}/overpass/maritimes.op"

# Last note id file.
declare -r LAST_NOTE_FILE="${TMP_DIR}/lastNote.xml"

# Location of the common functions.
declare -r FUNCTIONS_FILE="${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh"

# File for lock when downloading countries.
declare -r LOCK_OGR2OGR=/tmp/ogr2ogr.lock

###########
# FUNCTIONS

# shellcheck source=../functionsProcess.sh
source "${FUNCTIONS_FILE}"
# __start_logger
# __trapOn
# __checkBaseTables
# __downloadPlanetNotes
# __validatePlanetNotesXMLFile
# __convertPlanetNotesToFlatFile
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
 echo " * --flatfile : converts the planet file into a flat csv file."
 echo " * --locatenotes <flatNotesfile> <flatNoteCommentsfile> <flatTextCommentsfile> :"
 echo "      takes the flatfiles, import them and finally locate the notes."
 echo " * Without parameter, it processes the new notes from Planet notes file."
 echo
 echo "Flatfile option is useful when the regular machine does not have enough"
 echo "memory to process the notes file. Normally it needs 6 GB for Java."
 echo "LocateNotes is useful to continue from the flat file."
 echo
 echo "Environment variable:"
 echo " * BACKUP could be set to true, to insert rows from backup tables."
 echo " * BACKUP_COUNTRIES could be set to true, to insert boundary rows from"
 echo "   backup tables."
 echo " * CLEAN could be set to false, to left all created files."
 echo " * SAXON_JAR specifies the location of the Saxon JAR file."
 echo " * LOG_LEVEL specifies the logger leves. Possible values are:"
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
  && [[ "${PROCESS_TYPE}" != "--flatfile" ]] \
  && [[ "${PROCESS_TYPE}" != "--locatenotes" ]] \
  && [[ "${PROCESS_TYPE}" != "--help" ]] \
  && [[ "${PROCESS_TYPE}" != "-h" ]]; then
  echo "ERROR: Invalid parameter. It should be:"
  echo " * Empty string, nothing."
  echo " * --base"
  echo " * --boundaries"
  echo " * --flatfile"
  echo " * --help"
  echo " * --locatenotes"
  exit "${ERROR_INVALID_ARGUMENT}"
 fi
 if [[ "${PROCESS_TYPE}" == "--locatenotes" ]] \
  && [[ "${FLAT_NOTES_FILE}" == "" ]]; then
  __loge "ERROR: You  must specify a flat Notes CSV file to process."
  exit "${ERROR_INVALID_ARGUMENT}"
 fi
 if [[ "${PROCESS_TYPE}" == "--locatenotes" ]] \
  && [[ "${FLAT_NOTE_COMMENTS_FILE}" == "" ]]; then
  __loge "ERROR: You  must specify a flat Note Comments CSV file to process."
  exit "${ERROR_INVALID_ARGUMENT}"
 fi
 if [[ "${PROCESS_TYPE}" == "--locatenotes" ]] \
  && [[ "${FLAT_TEXT_COMMENTS_FILE}" == "" ]]; then
  __loge "ERROR: You  must specify a flat TextComments CSV file to process."
  exit "${ERROR_INVALID_ARGUMENT}"
 fi
 set +e
 # Checks prereqs.
 if [[ "${PROCESS_TYPE}" != "--flatfile" ]]; then
  __checkPrereqsCommands
 fi
 if [[ "${PROCESS_TYPE}" == "" ]] \
  || [[ "${PROCESS_TYPE}" == "--flatfile" ]]; then
  __checkPrereqsCommands
  ## Saxon Jar
  if [[ ! -r "${SAXON_JAR}" ]]; then
   __loge "ERROR: Saxon jar is missing at ${SAXON_JAR}."
   exit "${ERROR_MISSING_LIBRARY}"
  fi
  if ! java -cp "${SAXON_JAR}" net.sf.saxon.Transform -? > /dev/null 2>&1; then
   __loge "ERROR: Saxon jar is missing at ${SAXON_JAR}."
   exit "${ERROR_MISSING_LIBRARY}"
  fi
 fi

 ## Checks if the flat file exist.
 if [[ "${FLAT_NOTES_FILE}" != "" ]] && [[ ! -r "${FLAT_NOTES_FILE}" ]]; then
  __loge "ERROR: The flat file cannot be accessed: ${FLAT_NOTES_FILE}."
  exit "${ERROR_INVALID_ARGUMENT}"
 fi
 ## Checks the flat file if exist.
 if [[ "${FLAT_NOTE_COMMENTS_FILE}" != "" ]] \
  && [[ ! -r "${FLAT_NOTE_COMMENTS_FILE}" ]]; then
  __loge "ERROR: The flat file cannot be accessed: ${FLAT_NOTE_COMMENTS_FILE}."
  exit "${ERROR_INVALID_ARGUMENT}"
 fi
 ## Checks the flat file if exist.
 if [[ "${FLAT_TEXT_COMMENTS_FILE}" != "" ]] \
  && [[ ! -r "${FLAT_TEXT_COMMENTS_FILE}" ]]; then
  __loge "ERROR: The flat file cannot be accessed: ${FLAT_TEXT_COMMENTS_FILE}."
  exit "${ERROR_INVALID_ARGUMENT}"
 fi

 ## Checks postgres scripts.
 if [[ ! -r "${POSTGRES_11_DROP_SYNC_TABLES}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_11_DROP_SYNC_TABLES}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_12_DROP_API_TABLES}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_12_DROP_API_TABLES}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_13_DROP_BASE_TABLES}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_13_DROP_BASE_TABLES}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_14_DROP_COUNTRY_TABLES}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_14_DROP_COUNTRY_TABLES}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_21_CREATE_ENUMS}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_21_CREATE_ENUMS}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_22_CREATE_BASE_TABLES}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_22_CREATE_BASE_TABLES}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_23_CREATE_CONSTRAINTS}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_23_CREATE_CONSTRAINTS}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_24_CREATE_SYNC_TABLES}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_24_CREATE_SYNC_TABLES}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_25_CREATE_COUNTRY_TABLES}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_25_CREATE_COUNTRY_TABLES}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_31_VACUUM_AND_ANALYZE}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_31_VACUUM_AND_ANALYZE}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_41_LOAD_SYNC_NOTES}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_41_LOAD_SYNC_NOTES}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_42_REMOVE_DUPLICATES}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_42_REMOVE_DUPLICATES}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_43_COMMENTS_SEQUENCE}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_43_COMMENTS_SEQUENCE}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_44_LOAD_TEXT_COMMENTS}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_44_LOAD_TEXT_COMMENTS}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_45_OBJECTS_TEXT_COMMENTS}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_45_OBJECTS_TEXT_COMMENTS}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 __checkPrereqs_functions
 __log_finish
 set -e
}

# Drop sync tables.
function __dropSyncTables {
 __log_start
 __logi "Droping sync tables."
 psql -d "${DBNAME}" -f "${POSTGRES_11_DROP_SYNC_TABLES}"
 __log_finish
}

# Drop tables for notes from API.
function __dropApiTables {
 __log_start
 __logi "Droping api tables."
 psql -d "${DBNAME}" -f "${POSTGRES_12_DROP_API_TABLES}"
 __log_finish
}

# Drop existing base tables.
function __dropBaseTables {
 __log_start
 __logi "Droping base tables."
 psql -d "${DBNAME}" -f "${POSTGRES_13_DROP_BASE_TABLES}"
 __log_finish
}

# Drop existing base tables.
function __dropCountryTables {
 __log_start
 __logi "Droping country tables."
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
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_25_CREATE_COUNTRY_TABLES}"
 __log_finish
}

# Processes the list of countries or maritimes areas in the given file.
function __processList {
 __log_start

 BOUNDARIES_FILE="${1}"
 __logi "Retrieving the countriy or maritime boundaries."
 while read -r LINE; do
  ID=$(echo "${LINE}" | awk '{print $1}')
  JSON_FILE="${TMP_DIR}/${ID}.json"
  GEOJSON_FILE="${TMP_DIR}/${ID}.geojson"
  __logi "ID: ${ID}"
  cat << EOF > "${QUERY_FILE}"
   [out:json];
   rel(${ID});
   (._;>;);
   out;
EOF
  __logi "Retrieving shape."
  set +e
  wget -O "${JSON_FILE}" --post-file="${QUERY_FILE}" "${OVERPASS_INTERPRETER}"
  if [[ "${?}" -ne 0 ]]; then
   # Retry once if there was an error.
   set -e
   wget -O "${JSON_FILE}" --post-file="${QUERY_FILE}" "${OVERPASS_INTERPRETER}"
  fi
  set -e

  __logi "Converting into geoJSON."
  osmtogeojson "${JSON_FILE}" > "${GEOJSON_FILE}"
  set +e
  set +o pipefail
  NAME=$(grep "\"name\":" "${GEOJSON_FILE}" | head -1 \
   | awk -F\" '{print $4}' | sed "s/'/''/")
  NAME_ES=$(grep "\"name:es\":" "${GEOJSON_FILE}" | head -1 \
   | awk -F\" '{print $4}' | sed "s/'/''/")
  NAME_EN=$(grep "\"name:en\":" "${GEOJSON_FILE}" | head -1 \
   | awk -F\" '{print $4}' | sed "s/'/''/")
  set -o pipefail
  set -e
  __logi "Name: ${NAME_EN}."

  # Taiwan cannot be imported directly. Thus, a simplification is done.
  # ERROR:  row is too big: size 8616, maximum size 8160
  grep -v "official_name" "${GEOJSON_FILE}" \
   | grep -v "alt_name" > "${GEOJSON_FILE}-new"
  mv "${GEOJSON_FILE}-new" "${GEOJSON_FILE}"

  __logi "Importing into Postgres."
  while [[ -r "${LOCK_OGR2OGR}"
    && $(cat "${LOCK_OGR2OGR}") != "${BASHPID}" ]]; do
   __logw "${BOUNDARIES_FILE} - Waiting ${BASHPID} for ${ID}..."
   sleep 1
  done
  echo "${BASHPID}" > "${LOCK_OGR2OGR}"
  ogr2ogr -f "PostgreSQL" PG:"dbname=${DBNAME} user=${DB_USER}" \
   "${GEOJSON_FILE}" -nln import -overwrite
  # If an error like this appear:
  # ERROR:  column "name:xx-XX" specified more than once
  # It means two of the objects of the country has a name for the same
  # language, but with different case. The current solution is to open
  # the JSON file, look for the language, and modify the parts to have the
  # same case. Or modify the objects in OSM.
  rm "${LOCK_OGR2OGR}"

  __logi "Inserting into final table."
  if [[ "${ID}" -ne 16239 ]]; then
   STATEMENT="INSERT INTO countries (country_id, country_name, country_name_es,
     country_name_en, geom)
     select ${ID}, '${NAME}', '${NAME_ES}', '${NAME_EN}',
      ST_Union(ST_makeValid(wkb_geometry))
     from import group by 1"
  else # This case is for Austria.
   # GEOSUnaryUnion: TopologyException: Input geom 1 is invalid:
   # Self-intersection at or near point 10.454439900000001 47.555796399999998
   # at 10.454439900000001 47.555796399999998
   STATEMENT="INSERT INTO countries (country_id, country_name, country_name_es,
     country_name_en, geom)
     SELECT ${ID}, '${NAME}', '${NAME_ES}', '${NAME_EN}',
      ST_Union(ST_Buffer(wkb_geometry,0.0))
     from import group by 1"
  fi
  __logd "${STATEMENT}"
  echo "${STATEMENT}" | psql -d "${DBNAME}" -v ON_ERROR_STOP=1

  if [[ -n "${CLEAN}" ]] && [[ "${CLEAN}" = true ]]; then
   rm -f "${JSON_FILE}" "${GEOJSON_FILE}"
  fi
  __logi "Waiting ${SECONDS_TO_WAIT} seconds..."
  sleep "${SECONDS_TO_WAIT}"
 done < "${BOUNDARIES_FILE}"

 __log_finish
}

# Download the list of countries, then it downloads each country individually,
# converts the OSM JSON into a GeoJSON, and then it inserts the geometry of the
# country into the Postgres database with ogr2ogr.
function __processCountries {
 __log_start
 echo "TRUNCATE TABLE countries" | psql -d "${DBNAME}" -v ON_ERROR_STOP=1

 # Extracts ids of all country relations into a JSON.
 __logi "Obtaining the countries ids."
 set +e
 wget -O "${COUNTRIES_FILE}" --post-file="${OVERPASS_COUNTRIES}" \
  "${OVERPASS_INTERPRETER}"
 RET=${?}
 set -e
 if [[ "${RET}" -ne 0 ]]; then
  __loge "ERROR: Country list could not be downloaded."
  exit "${ERROR_DOWNLOADING_ID_LIST}"
 fi

 tail -n +2 "${COUNTRIES_FILE}" > "${COUNTRIES_FILE}.tmp"
 mv "${COUNTRIES_FILE}.tmp" "${COUNTRIES_FILE}"

 # Areas not at country level.
 {
  # Adds the Gaza Strip
  echo "1703814"
  # Adds Judea and Samaria.
  echo "1803010"
  # Adds the Buthan - China dispute.
  echo "12931402"
  # Adds Ilemi Triangle
  echo "192797"
  # Adds Neutral zone Burkina Faso - Benin
  echo "12940096"
  # Adds Bir Tawil
  echo "3335661"
  # Adds Jungholz, Austria
  echo "37848"
  # Adds Antarctica areas
  echo "3394112" # British Antarctic
  echo "3394110" # Argentine Antarctic
  echo "3394115" # Chilean Antarctic
  echo "3394113" # Ross dependency
  echo "3394111" # Australian Antarctic
  echo "3394114" # Adelia Land
  echo "3245621" # Queen Maud Land
  echo "2955118" # Peter I Island
  echo "2186646" # Antarctica continent
 } >> "${COUNTRIES_FILE}"

 # Processes the countries in parallel.
 MAX_THREADS=$(nproc)
 # Uses n-1 cores, if number of cores is greater than 1.
 # This prevents monopolization of the CPUs.
 if [[ "${MAX_THREADS}" -gt 6 ]]; then
  MAX_THREADS=$((MAX_THREADS-2))
 elif [[ "${MAX_THREADS}" -gt 1 ]]; then
  MAX_THREADS=$((MAX_THREADS-1))
 fi

 TOTAL_LINES=$(cat ${COUNTRIES_FILE} | wc -l)
 SIZE=$((TOTAL_LINES / MAX_THREADS))
 SIZE=$((SIZE + 1))
 split -l"${SIZE}" "${COUNTRIES_FILE}" "${TMP_DIR}/part_country_"
 rm -f "${LOCK_OGR2OGR}"
 for I in $(ls -1 ${TMP_DIR}/part_country_??) ; do
  (
   __logi "Starting list ${I} - ${BASHPID}"
   __processList "${I}" >> "${LOG_FILENAME}.${BASHPID}" 2>&1
   __logi "Finished list ${I} - ${BASHPID}"
   rm -f "${LOG_FILENAME}.${BASHPID}"
  ) &
  sleep 5
 done

 wait

 # If some of the threads generated an error.
 if [[ $(ls -1 "${TMP_DIR}" | grep "${BASENAME}\.log\." | wc -l) -ne 0 ]]; then
  exit "${ERROR_DOWNLOADING_BOUNDARY}"
 fi
 rm -f "${LOCK_OGR2OGR}"
 __log_finish
}

# Download the list of maritimes areas, then it downloads each area
# individually, converts the OSM JSON into a GeoJSON, and then it inserts the
# geometry of the maritime area into the Postgres database with ogr2ogr.
function __processMaritimes {
 __log_start
 # Extracts ids of all EEZ relations into a JSON.
 __logi "Obtaining the eez ids."
 set +e
 wget -O "${MARITIMES_FILE}" --post-file="${OVERPASS_MARITIMES}" \
  "${OVERPASS_INTERPRETER}"
 RET=${?}
 set -e
 if [[ "${RET}" -ne 0 ]]; then
  __loge "ERROR: Maritimes border list could not be downloaded."
  exit "${ERROR_DOWNLOADING_ID_LIST}"
 fi

 tail -n +2 "${MARITIMES_FILE}" > "${MARITIMES_FILE}.tmp"
 mv "${MARITIMES_FILE}.tmp" "${MARITIMES_FILE}"

 # Processes the maritimes in parallel.
 MAX_THREADS=$(nproc)
 # Uses n-1 cores, if number of cores is greater than 1.
 # This prevents monopolization of the CPUs.
 if [[ "${MAX_THREADS}" -gt 6 ]]; then
  MAX_THREADS=$((MAX_THREADS-2))
 elif [[ "${MAX_THREADS}" -gt 1 ]]; then
  MAX_THREADS=$((MAX_THREADS-1))
 fi

 TOTAL_LINES=$(cat ${MARITIMES_FILE} | wc -l)
 SIZE=$((TOTAL_LINES / MAX_THREADS))
 SIZE=$((SIZE + 1))
 split -l"${SIZE}" "${MARITIMES_FILE}" "${TMP_DIR}/part_maritime_"
 rm -f "${LOCK_OGR2OGR}"
 for I in $(ls -1 ${TMP_DIR}/part_maritime_??) ; do
  (
   __logi "Starting list ${I} - ${BASHPID}"
   __processList "${I}" >> "${LOG_FILENAME}.${BASHPID}" 2>&1
   __logi "Finished list ${I} - ${BASHPID}"
   rm -f "${LOG_FILENAME}.${BASHPID}"
  ) &
  sleep 5
 done

 wait

 # If some of the threads generated an error.
 if [[ $(ls -1 "${TMP_DIR}" | grep "${BASENAME}\.log\." | wc -l) -ne 0 ]]; then
  exit "${ERROR_DOWNLOADING_BOUNDARY}"
 fi
 rm -f "${LOCK_OGR2OGR}"

 __logi "Calculating statistics on countries."
 echo "ANALYZE countries" | psql -d "${DBNAME}" -v ON_ERROR_STOP=1
 __log_finish
}

# Clean files and tables.
function __cleanPartial {
 __log_start
 if [[ -n "${CLEAN}" ]] && [[ "${CLEAN}" = true ]]; then
  rm -f "${QUERY_FILE}" "${COUNTRIES_FILE}" "${MARITIMES_FILE}"
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

# Copies the CSV file to temporal directory.
function __copyFlatFiles {
 __log_start
 cp "${FLAT_NOTES_FILE}" "${OUTPUT_NOTES_FILE}"
 cp "${FLAT_NOTE_COMMENTS_FILE}" "${OUTPUT_NOTE_COMMENTS_FILE}"
 cp "${FLAT_TEXT_COMMENTS_FILE}" "${OUTPUT_TEXT_COMMENTS_FILE}"
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
   < "${POSTGRES_41_LOAD_SYNC_NOTES}" || true)"
 __log_finish
}

# Removes notes and comments from the new set that are already in the database.
function __removeDuplicates {
 __log_start
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_42_REMOVE_DUPLICATES}"
 # Puts the sequence. When reexecuting, some objects already exist.
 psql -d "${DBNAME}" -f "${POSTGRES_43_COMMENTS_SEQUENCE}"
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
   < "${POSTGRES_44_LOAD_TEXT_COMMENTS}" || true)"
 # Some objects could already exist.
 psql -d "${DBNAME}" -f "${POSTGRES_45_OBJECTS_TEXT_COMMENTS}"
 __log_finish
}

# Gets the area of each note.
function __getLocationNotes {
 __log_start
 if [[ -n "${BACKUP}" ]] && [[ "${BACKUP}" = true ]]; then
  echo "Please update the rows from the backup table:"
  echo "   UPDATE notes AS n"
  echo "    SET id_country = b.id_country"
  echo "    FROM backup_note_country AS b"
  echo "    WHERE b.note_id = n.note_id"
  echo "     AND n.id_country IS NULL;"
  read -r
 else
  declare -l MAX_NOTE_ID
  wget -O "${LAST_NOTE_FILE}" \
   "${OSM_API}/notes/search.xml?limit=1&closed=0&from=$(date "+%Y-%m-%d" \
    || true)"
  MAX_NOTE_ID=$(awk -F'[<>]' '/^  <id>/ {print $3}' "${LAST_NOTE_FILE}")
  MAX_NOTE_ID=$((MAX_NOTE_ID + 100))

  MAX_THREADS=$(nproc)
  # Uses n-1 cores, if number of cores is greater than 1.
  # This prevents monopolization of the CPUs.
  if [[ "${MAX_THREADS}" -gt 6 ]]; then
   MAX_THREADS=$((MAX_THREADS-2))
  elif [[ "${MAX_THREADS}" -gt 1 ]]; then
   MAX_THREADS=$((MAX_THREADS-1))
  fi

  declare -l SIZE=$((MAX_NOTE_ID / MAX_THREADS))
  rm -r "${LAST_NOTE_FILE}"
  for J in $(seq 1 1 "${MAX_THREADS}"); do
   (
    __logi "Starting ${J}."
    MIN=$((SIZE * (J - 1) + LOOP_SIZE))
    MAX=$((SIZE * J))
    for I in $(seq -f %1.0f "$((MAX))" "-${LOOP_SIZE}" "${MIN}"); do
     MIN_LOOP=$((I - LOOP_SIZE))
     MAX_LOOP=${I}
     __logd "${I}: [${MIN_LOOP} - ${MAX_LOOP}]."
     STMT="UPDATE notes
       SET id_country = get_country(longitude, latitude, note_id)
       WHERE ${MIN_LOOP} <= note_id AND note_id <= ${MAX_LOOP}
       AND id_country IS NULL"
     echo "${STMT}" | psql -d "${DBNAME}" -v ON_ERROR_STOP=1
    done
    __logi "Finishing ${J}."
   ) &
  done
  wait
  echo "UPDATE notes
    SET id_country = get_country(longitude, latitude, note_id)
    WHERE id_country IS NULL" | psql -d "${DBNAME}" -v ON_ERROR_STOP=1
 fi
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
 __logi "Preparing environment."
 __logd "Output saved at: ${TMP_DIR}."
 __logi "Processing: ${PROCESS_TYPE}."

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
  elif [[ "${PROCESS_TYPE}" == "--flatfile" ]]; then
   __logi "Process: Converts the planet into a flat CSV file."
  elif [[ "${PROCESS_TYPE}" == "--locatenotes" ]]; then
   __logi "Process: Takes the flat file and import it into the DB."
  fi
 fi
 # Checks the prerequisities. It could terminate the process.
 __checkPrereqs

 __logw "Starting process."

 # Sets the trap in case of any signal.
 __trapOn
 if [[ "${PROCESS_TYPE}" != "--flatfile" ]]; then
  exec 7> "${LOCK}"
  __logw "Validating single execution."
  ONLY_EXECUTION="no"
  flock -n 7
  ONLY_EXECUTION="yes"
 fi

 if [[ "${PROCESS_TYPE}" == "--base" ]]; then
  __dropSyncTables   # base
  __dropApiTables    # base
  __dropBaseTables   # base
  __createBaseTables # base
 elif [[ "${PROCESS_TYPE}" == "" ]] \
  || [[ "${PROCESS_TYPE}" == "--locatenotes" ]]; then
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
  if [[ (  -n "${BACKUP}" && "${BACKUP}" = true ) ]] \
    || [[ ( -n "${BACKUP_COUNTRIES}" && "${BACKUP_COUNTRIES}" = true ) ]]; then
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
 if [[ "${PROCESS_TYPE}" == "" ]] \
  || [[ "${PROCESS_TYPE}" == "--flatfile" ]]; then
  __downloadPlanetNotes          # sync and flatfile
  __validatePlanetNotesXMLFile   # sync and flatfile
  __convertPlanetNotesToFlatFile # sync and flatfile
  if [[ "${PROCESS_TYPE}" == "--flatfile" ]]; then
   echo "CSV files are at ${TMP_DIR}"
   __logw "Ending process."
   exit 0
  fi
 fi
 __createFunctionToGetCountry # base, sync & locate
 __createProcedures           # all
 __analyzeAndVacuum           # all
 if [[ "${PROCESS_TYPE}" == "--locatenotes" ]]; then
  __copyFlatFiles # locate
 fi
 if [[ "${PROCESS_TYPE}" == "" ]] \
  || [[ "${PROCESS_TYPE}" == "--locatenotes" ]]; then
  __loadSyncNotes    # sync & locate
  __removeDuplicates # sync & locate
  __loadTextComments # sync & locate
  __dropSyncTables   # sync & locate
  set +E
  export RET_FUNC=0
  __organizeAreas    # sync & locate
  set -E
  if [[ "${RET_FUNC}" -ne 0 ]]; then
   __createCountryTables # sync & locate
   if [[ (  -n "${BACKUP}" && "${BACKUP}" = true ) ]] \
     || [[ ( -n "${BACKUP_COUNTRIES}" && "${BACKUP_COUNTRIES}" = true ) ]]; then
    echo "Please copy the rows from the backup table:"
    echo "   INSERT INTO countries "
    echo "     SELECT * FROM backup_countries ;"
    read -r
   else
    __processCountries # sync & locate
    __processMaritimes # sync & locate
   fi
   __cleanPartial        # sync & locate
   __organizeAreas
  fi
  __getLocationNotes # sync & locate
 fi
 __cleanNotesFiles # base, sync & locate
 __logw "Ending process."

 if [[ -n "${CLEAN}" ]] && [[ "${CLEAN}" = true ]]; then
  if [[ ! -t 1 ]]; then
   mv "${LOG_FILENAME}" "/tmp/${BASENAME}_$(date +%Y-%m-%d_%H-%M-%S \
    || true).log"
   rmdir "${TMP_DIR}"
  fi
 fi
}

# Allows to other user read the directory.
chmod go+x "${TMP_DIR}"

__start_logger
if [[ ! -t 1 ]]; then
 __set_log_file "${LOG_FILENAME}"
 main >> "${LOG_FILENAME}" 2>&1
else
 main
fi
