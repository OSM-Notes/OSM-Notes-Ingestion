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
# (Declared in processAPIFunctions.sh)
# XSLT transformation files are already defined in functionsProcess.sh

# Script to process notes from Planet.
declare -r PROCESS_PLANET_NOTES_SCRIPT="processPlanetNotes.sh"
# Script to synchronize the notes with the Planet.
declare -r NOTES_SYNC_SCRIPT="${SCRIPT_BASE_DIRECTORY}/bin/process/${PROCESS_PLANET_NOTES_SCRIPT}"

# PostgreSQL SQL script files.
# (Declared in processAPIFunctions.sh)

# Temporary file that contains the downloaded notes from the API.
# (Declared in processAPIFunctions.sh)

# Location of the common functions.

# Error codes are already defined in functionsProcess.sh

# Output files for processing
# (Declared in processAPIFunctions.sh)
# FAILED_EXECUTION_FILE is already defined in functionsProcess.sh

# Control variables for functionsProcess.sh
export GENERATE_FAILED_FILE=true
export ONLY_EXECUTION="no"

###########
# FUNCTIONS

# Load common functions
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/bin/commonFunctions.sh"

# Load API-specific functions
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/bin/processAPIFunctions.sh"

# Load validation functions
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/bin/validationFunctions.sh"

# Load error handling functions
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/bin/errorHandlingFunctions.sh"

# Load process functions (includes PostgreSQL variables)
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh"

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
 __log_start
 __logi "=== STARTING PREREQUISITES CHECK ==="
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
 local SQL_FILES=(
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
 for SQL_FILE in "${SQL_FILES[@]}"; do
  if ! __validate_sql_structure "${SQL_FILE}"; then
   __loge "ERROR: SQL file validation failed: ${SQL_FILE}"
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

 # CSV files are generated during processing, no need to validate them here
 # as they will be created by __processApiXmlPart function

 __checkPrereqs_functions
 __logi "=== PREREQUISITES CHECK COMPLETED SUCCESSFULLY ==="
 __log_finish
 set -e
}

# Drop tables for notes from API.
function __dropApiTables {
 __log_start
 __logi "=== DROPPING API TABLES ==="
 __logd "Executing SQL file: ${POSTGRES_12_DROP_API_TABLES}"
 psql -d "${DBNAME}" -f "${POSTGRES_12_DROP_API_TABLES}"
 __logi "=== API TABLES DROPPED SUCCESSFULLY ==="
 __log_finish
}

# Checks that no processPlanetNotes is running
function __checkNoProcessPlanet {
 __log_start
 __logi "=== CHECKING FOR RUNNING PLANET PROCESSES ==="
 local QTY
 set +e
 QTY="$(pgrep "${PROCESS_PLANET_NOTES_SCRIPT:0:15}" | wc -l)"
 set -e
 __logd "Found ${QTY} running planet processes"
 if [[ "${QTY}" -ne "0" ]]; then
  __loge "${BASENAME} is currently running."
  __logw "It is better to wait for it to finish."
  exit "${ERROR_PLANET_PROCESS_IS_RUNNING}"
 fi
 __logi "=== NO CONFLICTING PROCESSES FOUND ==="
 __log_finish
}

# Creates tables for notes from API.
function __createApiTables {
 __log_start
 __logi "=== CREATING API TABLES ==="
 __logd "Executing SQL file: ${POSTGRES_21_CREATE_API_TABLES}"
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_21_CREATE_API_TABLES}"
 __logi "=== API TABLES CREATED SUCCESSFULLY ==="
 __log_finish
}

# Creates partitions dynamically based on MAX_THREADS.
function __createPartitions {
 __log_start
 __logi "=== CREATING PARTITIONS ==="
 __logd "Using MAX_THREADS: ${MAX_THREADS}"
 __logd "Executing SQL file: ${POSTGRES_22_CREATE_PARTITIONS}"

 export MAX_THREADS
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -c "$(envsubst "\$MAX_THREADS" < "${POSTGRES_22_CREATE_PARTITIONS}" || true)"
 __logi "=== PARTITIONS CREATED SUCCESSFULLY ==="
 __log_finish
}

# Creates table properties during the execution.
function __createPropertiesTable {
 __log_start
 __logi "=== CREATING PROPERTIES TABLE ==="
 __logd "Executing SQL file: ${POSTGRES_23_CREATE_PROPERTIES_TABLE}"
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_23_CREATE_PROPERTIES_TABLE}"
 __logi "=== PROPERTIES TABLE CREATED SUCCESSFULLY ==="
 __log_finish
}

function __getNewNotesFromApi {
 __log_start
 __logi "=== STARTING API NOTES RETRIEVAL ==="
 declare TEMP_FILE="${TMP_DIR}/last_update_value.txt"

 # Check network connectivity before proceeding
 __logi "Checking network connectivity..."
 if ! __check_network_connectivity 10; then
  __loge "Network connectivity check failed"
  __handle_error_with_cleanup "${ERROR_INTERNET_ISSUE}" "Network connectivity failed" \
   "rm -f ${TEMP_FILE} 2>/dev/null || true"
  # shellcheck disable=SC2317
  return "${ERROR_INTERNET_ISSUE}"
 fi

 # Gets the most recent value on the database with retry logic
 __logi "Retrieving last update from database..."
 __logd "Database: ${DBNAME}"
 local DB_OPERATION="psql -d ${DBNAME} -Atq -c \"SELECT /* Notes-processAPI */ TO_CHAR(timestamp, 'YYYY-MM-DD\\\"T\\\"HH24:MI:SS\\\"Z\\\"') FROM max_note_timestamp\" -v ON_ERROR_STOP=1 > ${TEMP_FILE} 2> /dev/null"
 local CLEANUP_OPERATION="rm -f ${TEMP_FILE} 2>/dev/null || true"

 if ! __retry_file_operation "${DB_OPERATION}" 3 2 "${CLEANUP_OPERATION}"; then
  __loge "Failed to retrieve last update from database after retries"
  __handle_error_with_cleanup "${ERROR_NO_LAST_UPDATE}" "Database query failed" \
   "rm -f ${TEMP_FILE} 2>/dev/null || true"
  # shellcheck disable=SC2317
  return "${ERROR_NO_LAST_UPDATE}"
 fi

 LAST_UPDATE=$(cat "${TEMP_FILE}")
 rm "${TEMP_FILE}"
 __logi "Last update retrieved: ${LAST_UPDATE}"
 if [[ "${LAST_UPDATE}" == "" ]]; then
  __loge "No last update. Please load notes first."
  __handle_error_with_cleanup "${ERROR_NO_LAST_UPDATE}" "No last update found" \
   "rm -f ${API_NOTES_FILE} 2>/dev/null || true"
  # shellcheck disable=SC2317
  return "${ERROR_NO_LAST_UPDATE}"
 fi

 # Gets the values from OSM API with enhanced error handling
 # shellcheck disable=SC2153
 REQUEST="${OSM_API}/notes/search.xml?limit=${MAX_NOTES}&closed=-1&sort=updated_at&from=${LAST_UPDATE}"
 __logi "API Request URL: ${REQUEST}"
 __logd "Max notes limit: ${MAX_NOTES}"
 __logi "Retrieving notes from API..."
 local OUTPUT_WGET="${TMP_DIR}/${BASENAME}.wget.log"

 # Use retry logic for API download
 local DOWNLOAD_OPERATION="wget -O ${API_NOTES_FILE} ${REQUEST}"
 local DOWNLOAD_CLEANUP="rm -f ${OUTPUT_WGET} 2>/dev/null || true"

 # Execute download with proper waiting
 local DOWNLOAD_SUCCESS=false
 local RETRY_COUNT=0
 local DOWNLOAD_MAX_RETRIES=3
 local DOWNLOAD_BASE_DELAY=5

 while [[ ${RETRY_COUNT} -lt ${DOWNLOAD_MAX_RETRIES} ]]; do
  __logd "Download attempt $((RETRY_COUNT + 1))/${DOWNLOAD_MAX_RETRIES}"

  # Execute wget and wait for it to complete
  if wget -O "${API_NOTES_FILE}" "${REQUEST}"; then
   # Check if file exists and has content
   if [[ -f "${API_NOTES_FILE}" ]] && [[ -s "${API_NOTES_FILE}" ]]; then
    DOWNLOAD_SUCCESS=true
    __logd "Download completed successfully"
    break
   else
    __logw "Download completed but file is missing or empty"
   fi
  else
   __logw "Download failed on attempt $((RETRY_COUNT + 1))"
  fi

  RETRY_COUNT=$((RETRY_COUNT + 1))

  if [[ ${RETRY_COUNT} -lt ${DOWNLOAD_MAX_RETRIES} ]]; then
   __logd "Waiting ${DOWNLOAD_BASE_DELAY}s before retry"
   sleep "${DOWNLOAD_BASE_DELAY}"
  fi
 done

 if [[ "${DOWNLOAD_SUCCESS}" == false ]]; then
  __loge "Failed to download API notes after ${DOWNLOAD_MAX_RETRIES} attempts"
  __handle_error_with_cleanup "${ERROR_INTERNET_ISSUE}" "API download failed" \
   "rm -f ${API_NOTES_FILE} ${OUTPUT_WGET} 2>/dev/null || true"
  # shellcheck disable=SC2317
  return "${ERROR_INTERNET_ISSUE}"
 fi

 # Since we're not capturing wget output to a file, we'll check the downloaded file
 if [[ ! -f "${API_NOTES_FILE}" ]] || [[ ! -s "${API_NOTES_FILE}" ]]; then
  __loge "API unreachable or download failed. Probably there are Internet issues."
  GENERATE_FAILED_FILE=false
  __handle_error_with_cleanup "${ERROR_INTERNET_ISSUE}" "API download failed" \
   "rm -f ${API_NOTES_FILE} 2>/dev/null || true"
  # shellcheck disable=SC2317
  return "${ERROR_INTERNET_ISSUE}"
 fi

 __logi "=== API NOTES RETRIEVAL COMPLETED SUCCESSFULLY ==="
 __log_finish
 return 0
}

# Validates API notes XML file completely (structure, dates, coordinates)
# Parameters:
#   None (uses global API_NOTES_FILE variable)
# Returns:
#   0 if all validations pass, exits with ERROR_DATA_VALIDATION if any validation fails
function __validateApiNotesXMLFileComplete {
 __log_start
 __logi "=== COMPLETE API NOTES XML VALIDATION ==="

 # Check if file exists
 if [[ ! -f "${API_NOTES_FILE}" ]]; then
  __loge "ERROR: API notes file not found: ${API_NOTES_FILE}"
  exit "${ERROR_DATA_VALIDATION}"
 fi

 # Validate XML structure against schema with enhanced error handling
 __logi "Validating XML structure against schema..."
 if ! __validate_xml_with_enhanced_error_handling "${API_NOTES_FILE}" "${XMLSCHEMA_API_NOTES}"; then
  __loge "ERROR: XML structure validation failed: ${API_NOTES_FILE}"
  exit "${ERROR_DATA_VALIDATION}"
 fi

 # Validate dates in XML file
 __logi "Validating dates in XML file..."
 if ! __validate_xml_dates "${API_NOTES_FILE}"; then
  __loge "ERROR: XML date validation failed: ${API_NOTES_FILE}"
  exit "${ERROR_DATA_VALIDATION}"
 fi

 # Validate coordinates in XML file
 __logi "Validating coordinates in XML file..."
 if ! __validate_xml_coordinates "${API_NOTES_FILE}"; then
  __loge "ERROR: XML coordinate validation failed: ${API_NOTES_FILE}"
  exit "${ERROR_DATA_VALIDATION}"
 fi

 __logi "All API notes XML validations passed successfully"
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
  # Check if there are notes to process
  if [[ "${TOTAL_NOTES}" -gt 0 ]]; then
   # Check if we have enough notes to justify parallel processing
   if [[ "${TOTAL_NOTES}" -ge "${MIN_NOTES_FOR_PARALLEL}" ]]; then
    __logi "Processing ${TOTAL_NOTES} notes with parallel processing (threshold: ${MIN_NOTES_FOR_PARALLEL})"
    __splitXmlForParallelAPI "${API_NOTES_FILE}"
    # Export XSLT variables for parallel processing
    export XSLT_NOTES_API_FILE XSLT_NOTE_COMMENTS_API_FILE XSLT_TEXT_COMMENTS_API_FILE
    __processXmlPartsParallel "__processApiXmlPart"
   else
    __logi "Processing ${TOTAL_NOTES} notes sequentially (below threshold: ${MIN_NOTES_FOR_PARALLEL})"
    __processApiXmlSequential "${API_NOTES_FILE}"
   fi
  else
   __logi "No notes found in XML file, skipping processing."
  fi
 fi

 __log_finish
}

# Processes API XML file sequentially for small datasets
# Parameters:
#   $1: XML file path
function __processApiXmlSequential {
 __log_start
 __logi "=== PROCESSING API XML SEQUENTIALLY ==="

 local XML_FILE="${1}"
 local OUTPUT_NOTES_FILE="${TMP_DIR}/output-notes-sequential.csv"
 local OUTPUT_COMMENTS_FILE="${TMP_DIR}/output-comments-sequential.csv"
 local OUTPUT_TEXT_FILE="${TMP_DIR}/output-text-sequential.csv"

 # Generate current timestamp for XSLT processing
 local CURRENT_TIMESTAMP
 CURRENT_TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
 __logd "Using timestamp for XSLT processing: ${CURRENT_TIMESTAMP}"

 # Process notes
 __logd "Processing notes with xsltproc: ${XSLT_NOTES_API_FILE} -> ${OUTPUT_NOTES_FILE}"
 xsltproc --stringparam default-timestamp "${CURRENT_TIMESTAMP}" -o "${OUTPUT_NOTES_FILE}" "${XSLT_NOTES_API_FILE}" "${XML_FILE}"
 if [[ ! -f "${OUTPUT_NOTES_FILE}" ]]; then
  __loge "Notes CSV file was not created: ${OUTPUT_NOTES_FILE}"
  return 1
 fi

 # Process comments
 __logd "Processing comments with xsltproc: ${XSLT_NOTE_COMMENTS_API_FILE} -> ${OUTPUT_COMMENTS_FILE}"
 xsltproc --stringparam default-timestamp "${CURRENT_TIMESTAMP}" -o "${OUTPUT_COMMENTS_FILE}" "${XSLT_NOTE_COMMENTS_API_FILE}" "${XML_FILE}"
 if [[ ! -f "${OUTPUT_COMMENTS_FILE}" ]]; then
  __loge "Comments CSV file was not created: ${OUTPUT_COMMENTS_FILE}"
  return 1
 fi

 # Process text comments
 __logd "Processing text comments with xsltproc: ${XSLT_TEXT_COMMENTS_API_FILE} -> ${OUTPUT_TEXT_FILE}"
 xsltproc --stringparam default-timestamp "${CURRENT_TIMESTAMP}" -o "${OUTPUT_TEXT_FILE}" "${XSLT_TEXT_COMMENTS_API_FILE}" "${XML_FILE}"
 if [[ ! -f "${OUTPUT_TEXT_FILE}" ]]; then
  __loge "Text comments CSV file was not created: ${OUTPUT_TEXT_FILE}"
  return 1
 fi

 # Debug: Show generated CSV files and their sizes
 __logd "Generated CSV files:"
 __logd "  Notes: ${OUTPUT_NOTES_FILE} ($(wc -l < "${OUTPUT_NOTES_FILE}" || echo 0) lines)" || true
 __logd "  Comments: ${OUTPUT_COMMENTS_FILE} ($(wc -l < "${OUTPUT_COMMENTS_FILE}" || echo 0) lines)" || true
 __logd "  Text: ${OUTPUT_TEXT_FILE} ($(wc -l < "${OUTPUT_TEXT_FILE}" || echo 0) lines)" || true

 __logi "=== LOADING SEQUENTIAL DATA INTO DATABASE ==="
 __logd "Database: ${DBNAME}"

 # Load into database with single thread (no partitioning)
 export OUTPUT_NOTES_FILE
 export OUTPUT_COMMENTS_FILE
 export OUTPUT_TEXT_FILE
 export PART_ID="1"
 export MAX_THREADS="1"
 # shellcheck disable=SC2016
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -c "SET app.part_id = '1'; SET app.max_threads = '1';" \
  -c "$(envsubst '$OUTPUT_NOTES_FILE,$OUTPUT_COMMENTS_FILE,$OUTPUT_TEXT_FILE,$PART_ID' \
   < "${POSTGRES_31_LOAD_API_NOTES}" || true)"

 __logi "=== SEQUENTIAL API XML PROCESSING COMPLETED SUCCESSFULLY ==="
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

    # Generate unique process ID with timestamp to avoid conflicts
    PROCESS_ID="${$}_$(date +%s)_${RANDOM}_${PART}"

    # Set lock with retry logic and better error handling
    local LOCK_RETRY_COUNT=0
    local LOCK_MAX_RETRIES=3
    local LOCK_RETRY_DELAY=2

    while [[ ${LOCK_RETRY_COUNT} -lt ${LOCK_MAX_RETRIES} ]]; do
     if echo "CALL put_lock('${PROCESS_ID}'::VARCHAR)" | psql -d "${DBNAME}" -v ON_ERROR_STOP=1; then
      __logd "Lock acquired successfully for part ${PART}: ${PROCESS_ID}"
      break
     else
      LOCK_RETRY_COUNT=$((LOCK_RETRY_COUNT + 1))
      __logw "Lock acquisition failed for part ${PART}, attempt ${LOCK_RETRY_COUNT}/${LOCK_MAX_RETRIES}"

      if [[ ${LOCK_RETRY_COUNT} -lt ${LOCK_MAX_RETRIES} ]]; then
       sleep "${LOCK_RETRY_DELAY}"
      fi
     fi
    done

    if [[ ${LOCK_RETRY_COUNT} -eq ${LOCK_MAX_RETRIES} ]]; then
     __loge "Failed to acquire lock for part ${PART} after ${LOCK_MAX_RETRIES} attempts"
     # Force error to trigger trap
     false
    fi

    export PROCESS_ID
    if ! psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
     -c "$(envsubst "\$PROCESS_ID" < "${POSTGRES_32_INSERT_NEW_NOTES_AND_COMMENTS}" || true)"; then
     __loge "Failed to process insertion part ${PART}"
     # Remove lock even on failure
     echo "CALL remove_lock('${PROCESS_ID}'::VARCHAR)" | psql -d "${DBNAME}" -v ON_ERROR_STOP=1 || true
     __handle_error_with_cleanup "${ERROR_GENERAL}" "Database insertion failed for part ${PART}" \
      "echo 'CALL remove_lock(\"${PROCESS_ID}\"::VARCHAR)' | psql -d \"${DBNAME}\" -v ON_ERROR_STOP=1 || true"
    fi

    # Remove lock on success
    if ! echo "CALL remove_lock('${PROCESS_ID}'::VARCHAR)" | psql -d "${DBNAME}" -v ON_ERROR_STOP=1; then
     __loge "Failed to remove lock for part ${PART}"
     __handle_error_with_cleanup "${ERROR_GENERAL}" "Failed to remove lock for part ${PART}"
    fi

    __logi "Completed insertion part ${PART}"
   ) &
  done

  # Wait for all insertion jobs to complete
  wait

  # Check if any background jobs failed
  if ! wait; then
   __loge "One or more insertion parts failed"
   __handle_error_with_cleanup "${ERROR_GENERAL}" "One or more insertion parts failed"
  fi

 else
  # For small datasets, use single connection
  # Generate unique process ID with timestamp to avoid conflicts
  PROCESS_ID="${$}_$(date +%s)_${RANDOM}"

  # Set lock with retry logic and better error handling
  local LOCK_RETRY_COUNT=0
  local LOCK_MAX_RETRIES=3
  local LOCK_RETRY_DELAY=2

  while [[ ${LOCK_RETRY_COUNT} -lt ${LOCK_MAX_RETRIES} ]]; do
   if echo "CALL put_lock('${PROCESS_ID}'::VARCHAR)" | psql -d "${DBNAME}" -v ON_ERROR_STOP=1; then
    __logd "Lock acquired successfully: ${PROCESS_ID}"
    break
   else
    LOCK_RETRY_COUNT=$((LOCK_RETRY_COUNT + 1))
    __logw "Lock acquisition failed, attempt ${LOCK_RETRY_COUNT}/${LOCK_MAX_RETRIES}"

    if [[ ${LOCK_RETRY_COUNT} -lt ${LOCK_MAX_RETRIES} ]]; then
     sleep "${LOCK_RETRY_DELAY}"
    fi
   fi
  done

  if [[ ${LOCK_RETRY_COUNT} -eq ${LOCK_MAX_RETRIES} ]]; then
   __loge "Failed to acquire lock after ${LOCK_MAX_RETRIES} attempts"
   # Force error to trigger trap
   false
  fi

  export PROCESS_ID
  if ! psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
   -c "$(envsubst "\$PROCESS_ID" < "${POSTGRES_32_INSERT_NEW_NOTES_AND_COMMENTS}" || true)"; then
   __loge "Failed to process insertion"
   # Remove lock even on failure
   echo "CALL remove_lock('${PROCESS_ID}'::VARCHAR)" | psql -d "${DBNAME}" -v ON_ERROR_STOP=1 || true
   __handle_error_with_cleanup "${ERROR_GENERAL}" "Database insertion failed" \
    "echo 'CALL remove_lock(\"${PROCESS_ID}\"::VARCHAR)' | psql -d \"${DBNAME}\" -v ON_ERROR_STOP=1 || true"
  fi

  # Remove lock on success
  if ! echo "CALL remove_lock('${PROCESS_ID}'::VARCHAR)" | psql -d "${DBNAME}" -v ON_ERROR_STOP=1; then
   __loge "Failed to remove lock for single process"
   __handle_error_with_cleanup "${ERROR_GENERAL}" "Failed to remove lock for single process"
  fi
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
 if [[ -n "${CLEAN:-}" ]] && [[ "${CLEAN}" = true ]]; then
  rm "${API_NOTES_FILE}" "${OUTPUT_NOTES_FILE}" \
   "${OUTPUT_NOTE_COMMENTS_FILE}" "${OUTPUT_TEXT_COMMENTS_FILE}"
 fi
 __log_finish
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
   exit "${ERROR_EXIT_CODE}";
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
  __logw "Base tables missing. Creating base tables. It will take half an hour approximately."
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
 else
  # Base tables exist, now check if they contain historical data
  __logi "Base tables found. Validating historical data..."
  __checkHistoricalData
  if [[ "${RET_FUNC}" -ne 0 ]]; then
   exit "${ERROR_EXECUTING_PLANET_DUMP}"
  fi
  __logi "Historical data validation passed. ProcessAPI can continue safely."
 fi

 set -E
 __createApiTables
 __createPartitions
 __createPropertiesTable
 __createProcedures
 set +E
 __getNewNotesFromApi
 set -E

 # Verify that the API notes file was downloaded successfully
 if [[ ! -f "${API_NOTES_FILE}" ]]; then
  __loge "ERROR: API notes file was not downloaded: ${API_NOTES_FILE}"
  exit "${ERROR_INTERNET_ISSUE}"
 fi

 # Check if the file has content (not empty)
 if [[ ! -s "${API_NOTES_FILE}" ]]; then
  __loge "ERROR: API notes file is empty: ${API_NOTES_FILE}"
  exit "${ERROR_INTERNET_ISSUE}"
 fi

 __logi "API notes file downloaded successfully: ${API_NOTES_FILE}"

 declare -i RESULT
 RESULT=$(wc -l < "${API_NOTES_FILE}")
 if [[ "${RESULT}" -ne 0 ]]; then
  __validateApiNotesXMLFileComplete
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
 if [[ -n "${CLEAN:-}" ]] && [[ "${CLEAN}" = true ]]; then
  mv "${LOG_FILENAME}" "/tmp/${BASENAME}_$(date +%Y-%m-%d_%H-%M-%S || true).log"
  rmdir "${TMP_DIR}"
 fi
else
 main
fi
