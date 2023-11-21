#!/bin/bash

# ETL process that takes the notes and its comments and populates a table which
# is easy to read from the OSM Notes profile.
# The execution of this ETL is independent of the process that retrieves the
# notes from Planet and API. This allows a longer execution that the periodic
# poll for new notes.
#
# To follow the progress you can execute:
#   tail -40f $(ls -1rtd /tmp/ETL_* | tail -1)/ETL.log
#
# This is the list of error codes:
# 1) Help message.
# 241) Library or utility missing.
# 242) Invalid argument for script invocation.
# 243) Logger utility is not available.
#
# For contributing, please execute these commands before subimitting:
# * shellcheck -x -o all ETL.sh
# * shfmt -w -i 1 -sr -bn ETL.sh
#
# Author: Andres Gomez (AngocA)
# Version: 2022-12-28
declare -r VERSION="2022-12-28"

#set -xv
# Fails when a variable is not initialized.
set -u
# Fails with an non-zero return code.
set -e
# Fails if the commands of a pipe return non-zero.
set -o pipefail
# Fails if an internal function fails.
set -E

# If all files should be deleted. In case of an error, this could be disabled.
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

declare BASENAME
BASENAME=$(basename -s .sh "${0}")
readonly BASENAME
# Temporal directory for all files.
declare TMP_DIR
TMP_DIR=$(mktemp -d "/tmp/${BASENAME}_XXXXXX")
readonly TMP_DIR
# Lof file for output.
declare LOG_FILENAME
LOG_FILENAME="${TMP_DIR}/${BASENAME}.log"
readonly LOG_FILENAME

# Lock file for single execution.
declare LOCK
LOCK="/tmp/${BASENAME}.lock"
readonly LOCK

# Type of process to run in the script.
declare -r PROCESS_TYPE=${1:-}

# Name of the SQL script that contains the ETL process.
declare -r POPULATE_DIMENSIONS_FILE="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL-populateDimensionTables.sql"

# Name of the SQL script that check the existance of base tables.
declare -r CHECK_BASE_TABLES_FILE="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL-checkBaseDWHTables.sql"

# Name of the SQL script that contains the objects to create in the DB.
declare -r CREATE_OBJECTS_FILE="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL-createDWHObjects.sql"

# Regions per country.
declare -r REGIONS_FILE="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL-getWorldRegion.sql"

# Name of the SQL script that contains the alter statements.
declare -r ADD_OBJECTS_FILE="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL-addConstraintsIndexesTriggers.sql"

# Create staging procedures.
declare -r CREATE_STAGING_OBJS_FILE="${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging-createStagingObjects.sql"

# Create staging procedures.
declare -r LOAD_NOTES_STAGING_FILE="${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging-loadNotes.sql"

# Location of the datamart user script.
declare -r DATAMART_COUNTRIES_FILE="${SCRIPT_BASE_DIRECTORY}/bin/dwh/datamartCountries/datamartCountries.sh"

# Location of the datamart user script.
declare -r DATAMART_USERS_FILE="${SCRIPT_BASE_DIRECTORY}/bin/dwh/datamartUsers/datamartUsers.sh"

# Location of the common functions.
declare -r FUNCTIONS_FILE="${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh"

###########
# FUNCTIONS

# shellcheck source=../functionsProcess.sh
source "${FUNCTIONS_FILE}"

# Shows the help information.
function __show_help {
 echo "${0} version ${VERSION}"
 echo "This is the ETL process that extracts the values from transactional"
 echo "tables and then inserts them into the facts and dimensions tables."
 echo
 echo "Written by: Andres Gomez (AngocA)"
 echo "OSM-LatAm, OSM-Colombia, MaptimeBogota."
 exit "${ERROR_HELP_MESSAGE}"
}

# Checks prerequisites to run the script.
function __checkPrereqs {
 __log_start
 if [[ "${PROCESS_TYPE}" != "" ]] && [[ "${PROCESS_TYPE}" != "--create" ]] \
   && [[ "${PROCESS_TYPE}" != "--help" ]] \
   && [[ "${PROCESS_TYPE}" != "-h" ]] ; then
  echo "ERROR: Invalid parameter. It should be:"
  echo " * Empty string (nothing)."
  echo " * --create"
  echo " * --help"
  __loge "ERROR: Invalid parameter."
  exit "${ERROR_INVALID_ARGUMENT}"
 fi
 set +e
 __checkPrereqsCommands
 
 ## Check files
 if [[ ! -r "${DATAMART_COUNTRIES_FILE}" ]]; then
  __loge "ERROR: File datamartCountries.sh was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${DATAMART_USERS_FILE}" ]]; then
  __loge "ERROR: File datamartUsers.sh was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${CHECK_BASE_TABLES_FILE}" ]]; then
  __loge "ERROR: File checkBaseTables.sql was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${CREATE_OBJECTS_FILE}" ]]; then
  __loge "ERROR: File createObjects.sql was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${REGIONS_FILE}" ]]; then
  __loge "ERROR: File ETL-getWorldRegion.sql was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${ADD_OBJECTS_FILE}" ]]; then
  __loge "ERROR: File alterObjects.sql was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POPULATE_DIMENSIONS_FILE}" ]]; then
  __loge "ERROR: File populateTables.sql was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 __log_finish
 set -e
}

# Creates base tables that hold the whole history.
function __createBaseTables {
 __log_start
 __logi "Creating tables for star model if they do not exist"
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${CREATE_OBJECTS_FILE}"
 __logi "Regions for countries"
 psql -d "${DBNAME}" -f "${REGIONS_FILE}"
 __logi "Adding relation, indexes AND triggers"
 psql -d "${DBNAME}" -f "${ADD_OBJECTS_FILE}"

 __logi "Creating staging objects"
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${CREATE_STAGING_OBJS_FILE}" 2>&1
 __log_finish
}

# Checks the base tables if exist.
function __checkBaseTables {
 __log_start
 set +e
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${CHECK_BASE_TABLES_FILE}"
 RET=${?}
 set -e
 if [[ "${RET}" -ne 0 ]] ; then
  __createBaseTables
 fi
 __log_finish
}

# Processes the notes and comments.
function __processNotesETL {
 __log_start
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POPULATE_DIMENSIONS_FILE}"

 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${LOAD_NOTES_STAGING_FILE}" 2>&1
 __log_finish
}

######
# MAIN

function main() {
 __logi "Preparing environment."
 __logd "Output saved at: ${TMP_DIR}"
 __logi "Processing: ${PROCESS_TYPE}"
 
 if [[ "${PROCESS_TYPE}" == "-h" ]] || [[ "${PROCESS_TYPE}" == "--help" ]]; then
  __show_help
 fi
 __checkPrereqs
 __checkBaseTables
 
 __logw "Starting process"
 # Sets the trap in case of any signal.
 __trapOn
 exec 7> "${LOCK}"
 __logw "Validating single execution."
 flock -n 7
 
 __processNotesETL

 # Updates the datamart for countries.
 "${DATAMART_COUNTRIES_FILE}"
 
 # Updates the datamart for users.
 "${DATAMART_USERS_FILE}"

 __logw "Ending process"
}

# Allows to other user read the directory.
chmod go+x "${TMP_DIR}"

__start_logger
if [ ! -t 1 ] ; then
 __set_log_file "${LOG_FILENAME}"
 main >> "${LOG_FILENAME}"
 if [[ -n "${CLEAN}" ]] && [[ "${CLEAN}" = true ]] ; then
  mv "${LOG_FILENAME}" "/tmp/${BASENAME}_$(date +%Y-%m-%d_%H-%M-%S || true).log"
  rmdir "${TMP_DIR}"
 fi
else
 main
fi
