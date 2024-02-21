#!/bin/bash

# This scripts processes the most recents notes (creation or modification) from
# the OpenStreetMap API.
# * It downloads the notes via an HTTP call.
# * Then with an XSLT transformation converts the data into flat files.
# * It uploads the data into temp tables on a PostreSQL database.
# * Finally, it synchronizes the master tables.
#
# These are some examples to call this script:
#
# * export LOG_LEVEL=DEBUG ; ~/OSM-Notes-profile/processAPINotes.sh
#
# To follow the progress you can execute:
#   tail -40f $(ls -1rtd /tmp/processAPINotes_* | tail -1)/processAPINotes.log
#
# This is the list of error codes:
# 1) Help message.
# 238) Previous execution failed.
# 241) Library or utility missing.
# 242) Invalid argument.
# 243) Logger utility is missing.
# 245) No last update.
# 246) Planet process is currently running.
# 248) Error executing the Planet dump.
#
# For contributing, please execute these commands before subimitting:
# * shellcheck -x -o all processAPINotes.sh
# * shfmt -w -i 1 -sr -bn processAPINotes.sh
#
# Author: Andres Gomez (AngocA)
# Version: 2024-02-20
declare -r VERSION="2024-02-20"

#set -xv
# Fails when a variable is not initialized.
set -u
# Fails with an non-zero return code.
set -e
# Fails if the commands of a pipe return non-zero.
set -o pipefail
# Fails if an internal function fails.
set -E

# If all generated files should be deleted. In case of an error, this could be
# disabled.
# You can defined when calling: export CLEAN=false
declare -r CLEAN="${CLEAN:-true}"

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

# Maximum of notes to download from the API.
declare -r MAX_NOTES=10000

# XML Schema of the API notes file.
declare -r XMLSCHEMA_API_NOTES="${SCRIPT_BASE_DIRECTORY}/xsd/OSM-notes-API-schema.xsd"
# Name of the file of the XSLT transformation for notes from API.
declare -r XSLT_NOTES_API_FILE="${SCRIPT_BASE_DIRECTORY}/xslt/notes-API-csv.xslt"
# Name of the file of the XSLT transformation for note comments from API.
declare -r XSLT_NOTE_COMMENTS_API_FILE="${SCRIPT_BASE_DIRECTORY}/xslt/note_comments-API-csv.xslt"
# Name of the file of the XSLT transformation for text comments from API.
declare -r XSLT_TEXT_COMMENTS_API_FILE="${SCRIPT_BASE_DIRECTORY}/xslt/note_comments_text-API-csv.xslt"
# Script to synchronize the notes with the Planet.
declare -r NOTES_SYNC_SCRIPT="${SCRIPT_BASE_DIRECTORY}/bin/process/processPlanetNotes.sh"

# PostgreSQL files.
# Drop API tables.
declare -r POSTGRES_12_DROP_API_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_12_dropApiTables.sql"
# Create API tables.
declare -r POSTGRES_21_CREATE_API_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_21_createApiTables.sql"
# Create properties file.
declare -r POSTGRES_22_CREATE_PROPERTIES_TABLE="${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_22_createPropertiesTables.sql"
# Load notes.
declare -r POSTGRES_31_LOAD_API_NOTES="${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_31_loadApiNotes.sql"
# Insert new notes and comments.
declare -r POSTGRES_32_INSERT_NEW_NOTES_AND_COMMENTS="${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_32_insertNewNotesAndComments.sql"
# Insert new text comments.
declare -r POSTGRES_33_INSERT_NEW_TEXT_COMMENTS="${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_33_loadNewTextComments.sql"
# Update last values.
declare -r POSTGRES_34_UPDATE_LAST_VALUES="${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_34_updateLastValues.sql"

# Temporal file that contiains the downloaded notes from the API.
declare -r API_NOTES_FILE="${TMP_DIR}/OSM-notes-API.xml"

# Location of the common functions.
declare -r FUNCTIONS_FILE="${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh"

###########
# FUNCTIONS

# shellcheck source=../functionsProcess.sh
source "${FUNCTIONS_FILE}"

# Shows the help information.
function __show_help {
 echo "${0} version ${VERSION}."
 echo
 echo "This script downloads the OSM notes from the OpenStreetMap API."
 echo "It requests the most recent ones and synchronizes them on a local"
 echo "database that holds the whole notes history."
 echo
 echo "It does not receive any parameter for regular execution. The only"
 echo "parameter allowed is to invoke the help message (-h|--help)."
 echo "This script should be configured in a crontab or similar scheduler."
 echo
 echo "Instead, it could be parametrized with the following environment"
 echo "variables."
 echo "* CLEAN={true|false/empty}: Deletes all generated files."
 echo "* LOG_LEVEL={TRACE|DEBUG|INFO|WARN|ERROR|FATAL}: Configures the"
 echo "  logger level."
 echo "* SAXON_CLASSPATH=: Location of the saxon-he-11.4.jar file."
 echo
 echo "This script could call processPlanetNotes.sh which use another"
 echo "environment variables. Please check the documentation of that script."
 echo
 echo "Written by: Andres Gomez (AngocA)."
 echo "OSM-LatAm, OSM-Colombia, MaptimeBogota."
 exit "${ERROR_HELP_MESSAGE}"
}

# Checks prerequisites to run the script.
function __checkPrereqs {
 #__log_start
 __logd "Checking process type."
 if [[ "${PROCESS_TYPE}" != "" ]] && [[ "${PROCESS_TYPE}" != "--help" ]] \
  && [[ "${PROCESS_TYPE}" != "-h" ]]; then
  echo "ERROR: Invalid parameter. It should be:"
  echo " * Empty string (nothing)."
  echo " * --help"
  __loge "ERROR: Invalid parameter."
  exit "${ERROR_INVALID_ARGUMENT}"
 fi
 set +e
 # Checks prereqs.
 __checkPrereqsCommands

 ## Saxon Jar
 __logd "Checking Saxon Jar."
 if [[ ! -r "${SAXON_JAR}" ]]; then
  __loge "ERROR: Saxon jar is missing at ${SAXON_JAR}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 ## Checks required files.
 if [[ ! -r "${NOTES_SYNC_SCRIPT}" ]]; then
  __loge "ERROR: File is missing at ${NOTES_SYNC_SCRIPT}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 ## Checks postgres scripts.
 if [[ ! -r "${POSTGRES_12_DROP_API_TABLES}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_12_DROP_API_TABLES}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_21_CREATE_API_TABLES}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_21_CREATE_API_TABLES}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_22_CREATE_PROPERTIES_TABLE}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_22_CREATE_PROPERTIES_TABLE}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_31_LOAD_API_NOTES}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_31_LOAD_API_NOTES}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_32_INSERT_NEW_NOTES_AND_COMMENTS}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_32_INSERT_NEW_NOTES_AND_COMMENTS}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_33_INSERT_NEW_TEXT_COMMENTS}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_33_INSERT_NEW_TEXT_COMMENTS}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_34_UPDATE_LAST_VALUES}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_34_UPDATE_LAST_VALUES}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 __checkPrereqs_functions
 #__log_finish
 set -e
}

# Drop tables for notes from API.
function __dropApiTables {
 __log_start
 __logi "Droping tables."
 psql -d "${DBNAME}" -f "${POSTGRES_12_DROP_API_TABLES}"
 __log_finish
}

# Checks that no processPlanetNotes is runnning
function __checkNoProcessPlanet {
 __log_start
 local QTY
 set +e
 QTY="$(pgrep processPlanetNotes.sh | wc -l)"
 set -e
 if [[ "${QTY}" -ne "0" ]]; then
  __loge "${BASENAME} is currently running."
  __logw "It is better to wait for it to finish."
  exit "${ERROR_PLANET_PROCESS_IS_RUNNING}"
 fi
 __log_finish
}

# Creates tables for notes from API.
function __createApiTables {
 __log_start
 __logi "Creating tables."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_21_CREATE_API_TABLES}"
 __log_finish
}

# Creates table properties during the execution.
function __createPropertiesTable {
 __log_start
 __logi "Creating properties table."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_22_CREATE_PROPERTIES_TABLE}"
 __log_finish
}

# Gets the new notes
function __getNewNotesFromApi {
 __log_start
 declare TEMP_FILE="${TMP_DIR}/last_update_value.txt"
 # Gets the most recent value on the database.
 psql -d "${DBNAME}" -Atq \
  -c "SELECT /* Notes-processAPI */ \
      TO_CHAR(timestamp, 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"')
     FROM max_note_timestamp" \
  -v ON_ERROR_STOP=1 > "${TEMP_FILE}" 2> /dev/null
 LAST_UPDATE=$(cat "${TEMP_FILE}")
 __logw "Last update: ${LAST_UPDATE}."
 if [[ "${LAST_UPDATE}" == "" ]]; then
  __loge "No last update. Please load notes first."
  exit "${ERROR_NO_LAST_UPDATE}"
 fi

 # Gets the values from OSM API.
 REQUEST="${OSM_API}/notes/search.xml?limit=${MAX_NOTES}&closed=-1&sort=updated_at&from=${LAST_UPDATE}"
 __logt "${REQUEST}"
 wget -O "${API_NOTES_FILE}" "${REQUEST}" 2> "${LOG_FILENAME}"

 rm "${TEMP_FILE}"
 __log_finish
}

# Validates the XML file to be sure everything will work fine.
function __validateApiNotesXMLFile {
 __log_start

 xmllint --noout --schema "${XMLSCHEMA_API_NOTES}" "${API_NOTES_FILE}"

 __log_finish
}

# Creates the XSLT files and process the XML files with them.
# The CSV file structure for notes is:
# 3451247,29.6141093,-98.4844977,"2022-11-22 02:13:03 UTC",,"open"
# 3451210,39.7353700,-104.9626400,"2022-11-22 01:30:39 UTC","2022-11-22 02:09:32 UTC","close"
#
# The CSV file structure for comments is:
# 3450803,'opened','2022-11-21 17:13:10 UTC',17750622,'Juanmiguelrizogonzalez'
# 3450803,'closed','2022-11-22 02:06:53 UTC',15422751,'GHOSTsama2503'
# 3450803,'reopened','2022-11-22 02:06:58 UTC',15422751,'GHOSTsama2503'
# 3450803,'commented','2022-11-22 02:07:24 UTC',15422751,'GHOSTsama2503'
#
# The CSV file structure for text comment is:
# 3450803,'Iglesia pentecostal Monte de Sion aquí es donde está realmente'
# 3450803,'Existe otra iglesia sin nombre cercana a la posición de la nota, ¿es posible que se trate de un error, o hay una al lado de la otra?'
# 3451247,'If you are in the area, could you please survey a more exact location for Nothing Bundt Cakes and move the node to that location? Thanks!'
function __convertApiNotesToFlatFile {
 __log_start
 # Process the notes file.
 # XSLT transformations.

 # Converts the XML into a flat file in CSV format.
 java -Xmx1000m -cp "${SAXON_JAR}" net.sf.saxon.Transform \
  -s:"${API_NOTES_FILE}" -xsl:"${XSLT_NOTES_API_FILE}" \
  -o:"${OUTPUT_NOTES_FILE}"
 local RESULT
 RESULT=$(grep -c "<note " "${API_NOTES_FILE}")
 __logi "${RESULT} - Notes from API."
 RESULT=$(wc -l "${OUTPUT_NOTES_FILE}")
 __logw "${RESULT} - Notes in flat file."
 cat "${OUTPUT_NOTES_FILE}"

 java -Xmx1000m -cp "${SAXON_JAR}" net.sf.saxon.Transform \
  -s:"${API_NOTES_FILE}" -xsl:"${XSLT_NOTE_COMMENTS_API_FILE}" \
  -o:"${OUTPUT_NOTE_COMMENTS_FILE}"
 RESULT=$(grep -c "<comment>" "${API_NOTES_FILE}")
 __logi "${RESULT} - Comments from API."
 RESULT=$(wc -l "${OUTPUT_NOTE_COMMENTS_FILE}")
 __logw "${RESULT} - Note comments in flat file."
 cat "${OUTPUT_NOTE_COMMENTS_FILE}"

 java -Xmx1000m -cp "${SAXON_JAR}" net.sf.saxon.Transform \
  -s:"${API_NOTES_FILE}" -xsl:"${XSLT_TEXT_COMMENTS_API_FILE}" \
  -o:"${OUTPUT_TEXT_COMMENTS_FILE}"
 RESULT=$(grep -c "<comment>" "${API_NOTES_FILE}")
 __logi "${RESULT} - Text comments from API."
 RESULT=$(wc -l "${OUTPUT_TEXT_COMMENTS_FILE}")
 __logw "${RESULT} - Text comment in flat file."
 cat "${OUTPUT_TEXT_COMMENTS_FILE}"

 __log_finish
}

# Checks if the quantity of notes is less that the maximum allowed. If is the
# the same, it means not all notes were downloaded, and it needs a
# synchronization
function __checkQtyNotes {
 __log_start
 local -i QTY
 QTY=$(wc -l "${OUTPUT_NOTES_FILE}" | awk '{print $1}')
 if [[ "${QTY}" -ge "${MAX_NOTES}" ]]; then
  __logw "Starting full synchronization from Planet."
  __logi "This could take several minutes."
  "${NOTES_SYNC_SCRIPT}"
  __logw "Finished full synchronization from Planet."
 fi
 __log_finish
}

# Loads notes from API into the database.
function __loadApiNotes {
 __log_start

 __logt "Notes to be processed:"
 declare TEXT
 while read -r LINE; do
  TEXT=$(echo "${LINE}" | cut -f 1 -d,)
  __logt "${TEXT}"
 done < "${OUTPUT_NOTES_FILE}"
 echo
 __logt "Note comments to be processed:"
 while read -r LINE; do
  TEXT=$(echo "${LINE}" | cut -f 1-2 -d,)
  __logt "${TEXT}"
 done < "${OUTPUT_NOTE_COMMENTS_FILE}"

 # Comment's text are not shown because they are multiline.

 # Loads the data in the database.
 export OUTPUT_NOTES_FILE
 export OUTPUT_NOTE_COMMENTS_FILE
 export OUTPUT_TEXT_COMMENTS_FILE
 # shellcheck disable=SC2016
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -c "$(envsubst '$OUTPUT_NOTES_FILE,$OUTPUT_NOTE_COMMENTS_FILE,$OUTPUT_TEXT_COMMENTS_FILE' \
   < "${POSTGRES_31_LOAD_API_NOTES}" || true)"
 __log_finish
}

# Inserts new notes and comments into the database.
function __insertNewNotesAndComments {
 __log_start
 PROCESS_ID="${$}"
 echo "CALL put_lock(${PROCESS_ID}::VARCHAR)" | psql -d "${DBNAME}" -v ON_ERROR_STOP=1

 export PROCESS_ID
 # shellcheck disable=SC2016
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -c "$(envsubst '$PROCESS_ID' < "${POSTGRES_32_INSERT_NEW_NOTES_AND_COMMENTS}" \
   || true)"

 echo "CALL remove_lock(${PROCESS_ID}::VARCHAR)" | psql -d "${DBNAME}" -v ON_ERROR_STOP=1
 __log_finish
}

# Inserts the net text comments.
function __loadApiTextComments {
 __log_start
 export OUTPUT_TEXT_COMMENTS_FILE
 # shellcheck disable=SC2016
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -c "$(envsubst '$OUTPUT_TEXT_COMMENTS_FILE' \
   < "${POSTGRES_33_INSERT_NEW_TEXT_COMMENTS}" || true)"
 __log_finish
}

# Updates the refreshed value.
function __updateLastValue {
 __log_start
 __logi "Updating last update time."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_34_UPDATE_LAST_VALUES}"
 __log_finish
}

# Clean files generated during the process.
function __cleanNotesFiles {
 __log_start
 if [[ -n "${CLEAN}" ]] && [[ "${CLEAN}" = true ]]; then
  rm "${API_NOTES_FILE}" "${OUTPUT_NOTES_FILE}" \
   "${OUTPUT_NOTE_COMMENTS_FILE}" "${OUTPUT_TEXT_COMMENTS_FILE}"
 fi
 __log_finish
}

######
# MAIN

function main() {
 __log_start
 __logi "Preparing environment."
 __logd "Output saved at: ${TMP_DIR}."
 __logi "Processing: ${PROCESS_TYPE}."

 if [[ "${PROCESS_TYPE}" == "-h" ]] || [[ "${PROCESS_TYPE}" == "--help" ]]; then
  __show_help
 fi
 if [[ -f "${FAILED_EXECUTION_FILE}" ]]; then
  echo "Previous execution failed. Please verify the data and then remove the"
  echo "next file:"
  echo "   ${FAILED_EXECUTION_FILE}"
  exit "${ERROR_PREVIOUS_EXECUTION_FAILED}"
 fi
 __checkPrereqs
 __logw "Process started."

 # Sets the trap in case of any signal.
 __trapOn
 exec 8> "${LOCK}"
 __logw "Validating single execution."
 ONLY_EXECUTION="no"
 flock -n 8
 ONLY_EXECUTION="yes"

 __dropApiTables
 set +E
 __checkNoProcessPlanet
 export RET_FUNC=0
 __checkBaseTables
 if [[ "${RET_FUNC}" -ne 0 ]]; then
  __logw "Creating base tables. It will take half an hour approximately."
  "${NOTES_SYNC_SCRIPT}" --base
  __logw "Base tables created."
  __logi "This could take several minutes."
  set +e
  "${NOTES_SYNC_SCRIPT}"
  RET=${?}
  set -e
  if [[ "${RET}" -ne 0 ]]; then
   __loge "Error while executing the planet dump."
   exit "${ERROR_EXECUTING_PLANET_DUMP}"
  fi
  __logw "Finished full synchronization from Planet."
 fi

 set -E
 __createApiTables
 __createPropertiesTable
 __createProcedures
 __getNewNotesFromApi
 declare -i RESULT
 RESULT=$(wc -l < "${API_NOTES_FILE}")
 if [[ "${RESULT}" -ne 0 ]]; then
  __validateApiNotesXMLFile
  __convertApiNotesToFlatFile
  __checkQtyNotes
  __loadApiNotes
  __insertNewNotesAndComments
  __loadApiTextComments
  __updateLastValue
 fi
 __cleanNotesFiles

 rm -f "${LOCK}"
 __logw "Process finished."
 __log_finish
}
# Return value for several functions.
declare -i RET

# Allows to other users read the directory.
chmod go+x "${TMP_DIR}"

__start_logger
if [[ ! -t 1 ]]; then
 __set_log_file "${LOG_FILENAME}"
 main >> "${LOG_FILENAME}" 2>&1
 if [[ -n "${CLEAN}" ]] && [[ "${CLEAN}" = true ]]; then
  mv "${LOG_FILENAME}" "/tmp/${BASENAME}_$(date +%Y-%m-%d_%H-%M-%S || true).log"
  rmdir "${TMP_DIR}"
 fi
else
 main
fi
