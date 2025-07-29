#!/bin/bash

# This script processes the most recent notes (creation or modification) from
# the OpenStreetMap API.
# * It downloads the notes via an HTTP call.
# * Then with an XSLT transformation converts the data into flat files.
# * It uploads the data into temp tables on a PostgreSQL database.
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
# For contributing, please execute these commands before submitting:
# * shellcheck -x -o all processAPINotes.sh
# * shfmt -w -i 1 -sr -bn processAPINotes.sh
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

# If all generated files should be deleted. In case of an error, this could be
# disabled.
# You can define when calling: export CLEAN=false
declare -r CLEAN="${CLEAN:-true}"

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
# Temporary directory for all files.
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

# XML Schema of the API notes file.
declare -r XMLSCHEMA_API_NOTES="${SCRIPT_BASE_DIRECTORY}/xsd/OSM-notes-API-schema.xsd"
# XSLT transformation files for API format.
declare -r XSLT_NOTES_API_FILE="${SCRIPT_BASE_DIRECTORY}/xslt/notes-API-csv.xslt"
declare -r XSLT_NOTE_COMMENTS_API_FILE="${SCRIPT_BASE_DIRECTORY}/xslt/note_comments-API-csv.xslt"
declare -r XSLT_TEXT_COMMENTS_API_FILE="${SCRIPT_BASE_DIRECTORY}/xslt/note_comments_text-API-csv.xslt"

# Script to process notes from Planet.
declare -r PROCESS_PLANET_NOTES_SCRIPT="processPlanetNotes.sh"
# Script to synchronize the notes with the Planet.
declare -r NOTES_SYNC_SCRIPT="${SCRIPT_BASE_DIRECTORY}/bin/process/${PROCESS_PLANET_NOTES_SCRIPT}"

# PostgreSQL SQL script files.
# Drop API tables.
declare -r POSTGRES_12_DROP_API_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_12_dropApiTables.sql"
# Create API tables.
declare -r POSTGRES_21_CREATE_API_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_21_createApiTables.sql"
# Create partitions dynamically.
declare -r POSTGRES_22_CREATE_PARTITIONS="${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_22_createPartitions.sql"
# Create properties table.
declare -r POSTGRES_23_CREATE_PROPERTIES_TABLE="${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_23_createPropertiesTables.sql"
# Load API notes.
declare -r POSTGRES_31_LOAD_API_NOTES="${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_31_loadApiNotes.sql"
# Insert new notes and comments.
declare -r POSTGRES_32_INSERT_NEW_NOTES_AND_COMMENTS="${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_32_insertNewNotesAndComments.sql"
# Insert new text comments.
declare -r POSTGRES_33_INSERT_NEW_TEXT_COMMENTS="${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_33_loadNewTextComments.sql"
# Update last values.
declare -r POSTGRES_34_UPDATE_LAST_VALUES="${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_34_updateLastValues.sql"
# Consolidate partitions.
declare -r POSTGRES_35_CONSOLIDATE_PARTITIONS="${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_35_consolidatePartitions.sql"

# Temporary file that contains the downloaded notes from the API.
declare -r API_NOTES_FILE="${TMP_DIR}/OSM-notes-API.xml"

# Location of the common functions.
declare -r FUNCTIONS_FILE="${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh"

# Error codes (defined here to avoid shellcheck warnings)
declare -r ERROR_HELP_MESSAGE=1
declare -r ERROR_INVALID_ARGUMENT=242
declare -r ERROR_MISSING_LIBRARY=241
declare -r ERROR_PLANET_PROCESS_IS_RUNNING=246
declare -r ERROR_NO_LAST_UPDATE=245
declare -r ERROR_INTERNET_ISSUE=251
declare -r ERROR_PREVIOUS_EXECUTION_FAILED=238
declare -r ERROR_EXECUTING_PLANET_DUMP=248

# Output files for processing
declare -r OUTPUT_NOTES_FILE="${TMP_DIR}/notes.csv"
declare -r OUTPUT_NOTE_COMMENTS_FILE="${TMP_DIR}/note_comments.csv"
declare -r OUTPUT_TEXT_COMMENTS_FILE="${TMP_DIR}/note_comments_text.csv"
declare -r FAILED_EXECUTION_FILE="${TMP_DIR}/failed_execution"

# Control variables for functionsProcess.sh
export GENERATE_FAILED_FILE=true
export ONLY_EXECUTION="no"

###########
# FUNCTIONS

# shellcheck source=functionsProcess.sh
# shellcheck disable=SC1091
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

 ## Validate required files using centralized validation
 __logi "Validating required files..."

 # Validate sync script
 if ! __validate_input_file "${NOTES_SYNC_SCRIPT}" "Notes sync script"; then
  __loge "ERROR: Notes sync script validation failed: ${NOTES_SYNC_SCRIPT}"
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 ## Validate SQL script files using centralized validation
 __logi "Validating SQL script files..."

 # Create array of SQL files to validate
 local sql_files=(
  "${POSTGRES_12_DROP_API_TABLES}"
  "${POSTGRES_21_CREATE_API_TABLES}"
  "${POSTGRES_22_CREATE_PARTITIONS}"
  "${POSTGRES_23_CREATE_PROPERTIES_TABLE}"
  "${POSTGRES_31_LOAD_API_NOTES}"
  "${POSTGRES_32_INSERT_NEW_NOTES_AND_COMMENTS}"
  "${POSTGRES_33_INSERT_NEW_TEXT_COMMENTS}"
  "${POSTGRES_34_UPDATE_LAST_VALUES}"
  "${POSTGRES_35_CONSOLIDATE_PARTITIONS}"
 )

 # Validate each SQL file
 for sql_file in "${sql_files[@]}"; do
  if ! __validate_sql_structure "${sql_file}"; then
   __loge "ERROR: SQL file validation failed: ${sql_file}"
   exit "${ERROR_MISSING_LIBRARY}"
  fi
 done

 # Validate dates in API notes file if it exists
 __logi "Validating dates in API notes file..."
 if [[ -f "${API_NOTES_FILE}" ]]; then
  if ! __validate_xml_dates "${API_NOTES_FILE}"; then
   __loge "ERROR: XML date validation failed: ${API_NOTES_FILE}"
   exit "${ERROR_MISSING_LIBRARY}"
  fi
 fi

 __checkPrereqs_functions
 #__log_finish
 set -e
}

# Drop tables for notes from API.
function __dropApiTables {
 __log_start
 __logi "Dropping tables."
 psql -d "${DBNAME}" -f "${POSTGRES_12_DROP_API_TABLES}"
 __log_finish
}

# Checks that no processPlanetNotes is running
function __checkNoProcessPlanet {
 __log_start
 local QTY
 set +e
 QTY="$(pgrep "${PROCESS_PLANET_NOTES_SCRIPT:0:15}" | wc -l)"
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

# Creates partitions dynamically based on MAX_THREADS.
function __createPartitions {
 __log_start
 __logi "Creating partitions dynamically based on MAX_THREADS."

 export MAX_THREADS
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -c "$(envsubst "\$MAX_THREADS" < "${POSTGRES_22_CREATE_PARTITIONS}" || true)"
 __log_finish
}

# Creates table properties during the execution.
function __createPropertiesTable {
 __log_start
 __logi "Creating properties table."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_23_CREATE_PROPERTIES_TABLE}"
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
 rm "${TEMP_FILE}"
 __logw "Last update: ${LAST_UPDATE}."
 if [[ "${LAST_UPDATE}" == "" ]]; then
  __loge "No last update. Please load notes first."
  exit "${ERROR_NO_LAST_UPDATE}"
 fi

 # Gets the values from OSM API.
 # shellcheck disable=SC2153
 REQUEST="${OSM_API}/notes/search.xml?limit=${MAX_NOTES}&closed=-1&sort=updated_at&from=${LAST_UPDATE}"
 __logt "${REQUEST}"
 __logw "Retrieving notes from API."
 local OUTPUT_WGET="${TMP_DIR}/${BASENAME}.wget.log"
 set +e
 wget -O "${API_NOTES_FILE}" "${REQUEST}" > "${OUTPUT_WGET}" 2>&1
 RET="${?}"
 set -e
 local HOST_API
 HOST_API="$(echo "${OSM_API}" | awk -F/ '{print $3}')"
 local QTY
 set +e
 QTY=$(grep -c "unable to resolve host address ‘${HOST_API}’" "${OUTPUT_WGET}")
 set -e
 rm "${OUTPUT_WGET}"
 if [[ "${QTY}" -eq 1 ]]; then
  __loge "API unreachable. Probably there are Internet issues."
  GENERATE_FAILED_FILE=false
  RET="${ERROR_INTERNET_ISSUE}"
 fi
 __log_finish
 return "${RET}"
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

# Checks if the quantity of notes requires synchronization with Planet
function __processXMLorPlanet {
 __log_start

 if [[ "${TOTAL_NOTES}" -ge "${MAX_NOTES}" ]]; then
  __logw "Starting full synchronization from Planet."
  __logi "This could take several minutes."
  "${NOTES_SYNC_SCRIPT}"
  __logw "Finished full synchronization from Planet."
 else
  # Split XML into parts and process in parallel if there are notes to process
  if [[ "${TOTAL_NOTES}" -gt 0 ]]; then
   __splitXmlForParallelAPI "${API_NOTES_FILE}"
   # Export XSLT variables for parallel processing
   export XSLT_NOTES_API_FILE XSLT_NOTE_COMMENTS_API_FILE XSLT_TEXT_COMMENTS_API_FILE
   __processXmlPartsParallel "__processApiXmlPart"
  else
   __logi "No notes found in XML file, skipping processing."
  fi
 fi

 __log_finish
}

# Inserts new notes and comments into the database with parallel processing.
function __insertNewNotesAndComments {
 __log_start

 # Get the number of notes to process
 local NOTES_COUNT
 NOTES_COUNT=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(1) FROM notes_api" 2> /dev/null || echo "0")

 if [[ "${NOTES_COUNT}" -gt 1000 ]]; then
  # Split the insertion into chunks
  local PARTS="${MAX_THREADS}"

  for PART in $(seq 1 "${PARTS}"); do
   (
    __logi "Processing insertion part ${PART}"

    PROCESS_ID="${$}_${PART}"
    echo "CALL put_lock(${PROCESS_ID}::VARCHAR)" | psql -d "${DBNAME}" -v ON_ERROR_STOP=1

    export PROCESS_ID
    psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
     -c "$(envsubst "\$PROCESS_ID" < "${POSTGRES_32_INSERT_NEW_NOTES_AND_COMMENTS}" || true)"

    echo "CALL remove_lock(${PROCESS_ID}::VARCHAR)" | psql -d "${DBNAME}" -v ON_ERROR_STOP=1

    __logi "Completed insertion part ${PART}"
   ) &
  done

  # Wait for all insertion jobs to complete
  wait

 else
  # For small datasets, use single connection
  PROCESS_ID="${$}"
  echo "CALL put_lock(${PROCESS_ID}::VARCHAR)" | psql -d "${DBNAME}" -v ON_ERROR_STOP=1

  export PROCESS_ID
  psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
   -c "$(envsubst "\$PROCESS_ID" < "${POSTGRES_32_INSERT_NEW_NOTES_AND_COMMENTS}" || true)"

  echo "CALL remove_lock(${PROCESS_ID}::VARCHAR)" | psql -d "${DBNAME}" -v ON_ERROR_STOP=1
 fi

 __log_finish
}

# Inserts the new text comments.
function __loadApiTextComments {
 __log_start
 export OUTPUT_TEXT_COMMENTS_FILE
 # shellcheck disable=SC2016
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -c "$(envsubst "\$OUTPUT_TEXT_COMMENTS_FILE" \
   < "${POSTGRES_33_INSERT_NEW_TEXT_COMMENTS}" || true)"
 __log_finish
}

# Consolidates data from all partitions into single tables.
function __consolidatePartitions {
 __log_start
 __logi "Consolidating data from all partitions."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_35_CONSOLIDATE_PARTITIONS}"
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
 __logi "Process ID: ${$}"
 __logi "Processing: '${PROCESS_TYPE}'."

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
 __createPartitions
 __createPropertiesTable
 __createProcedures
 set +E
 __getNewNotesFromApi
 set -E
 declare -i RESULT
 RESULT=$(wc -l < "${API_NOTES_FILE}")
 if [[ "${RESULT}" -ne 0 ]]; then
  __validateApiNotesXMLFile
  __countXmlNotesAPI "${API_NOTES_FILE}"
  __processXMLorPlanet
  __consolidatePartitions
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
