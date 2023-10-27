#!/bin/bash

# ETL process that takes the notes and its comments and populates a table which
# is easy to read from the OSM Notes profile.
# When this ETL is run, it updates each note and comment with an associated
# code.
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
# 248) Required file is missing.
#
# For contributing, please execute these commands before subimitting:
# * shellcheck -x -o all ETL.sh
# * shfmt -w -i 1 -sr -bn ETL.sh
#
# Author: Andres Gomez (AngocA)
# Version: 2022-12-20
declare -r VERSION="2022-12-20"

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
# 1: Help message.
declare -r ERROR_HELP_MESSAGE=1
# 241: Library or utility missing.
declare -r ERROR_MISSING_LIBRARY=241
# 242: Invalid argument for script invocation.
declare -r ERROR_INVALID_ARGUMENT=242
# 248: Missing dependant file.
declare -r ERROR_MISSING_FILE=248

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
declare LOG_FILE
LOG_FILE="${TMP_DIR}/${BASENAME}.log"
readonly LOG_FILE

# Lock file for single execution.
declare LOCK
LOCK="/tmp/${BASENAME}.lock"
readonly LOCK

# Type of process to run in the script.
declare -r PROCESS_TYPE=${1:-}

# Name of the SQL script that check the existance of base tables.
declare -r CHECK_BASE_TABLES_FILE="${SCRIPT_BASE_DIRECTORY}/bin/dwh/checkBaseTables.sql"

# Name of the SQL script that contains the objects to create in the DB.
declare -r CREATE_OBJECTS_FILE="${SCRIPT_BASE_DIRECTORY}/bin/dwh/createObjects.sql"

# Name of the SQL script that contains the statement to empty the tables.
declare -r EMPTY_TABLES_FILE="${SCRIPT_BASE_DIRECTORY}/bin/dwh/emptyTables.sql"

# Name of the SQL script that contains the alter statements.
declare -r ALTER_OBJECTS_FILE="${SCRIPT_BASE_DIRECTORY}/bin/dwh/alterObjects.sql"

# Name of the SQL script that contains the ETL process.
declare -r POPULATE_FILE="${SCRIPT_BASE_DIRECTORY}/bin/dwh/populateTables.sql"

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
 echo "It could receive one of these parameters:"
 echo " * --create to create the tables and start from empty tables."
 echo " * Without parameter it processes with existing data."
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
 ## PostgreSQL
 if ! psql --version > /dev/null 2>&1 ; then
  __loge "ERROR: PostgreSQL is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## flock
 if ! flock --version > /dev/null 2>&1 ; then
  __loge "ERROR: flock is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Bash 4 or greater.
 if [[ "${BASH_VERSINFO[0]}" -lt 4 ]] ; then
  __loge "ERROR: Requires Bash 4+."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Check files
 if [[ ! -r "${CHECK_BASE_TABLES_FILE}" ]]; then
  __loge "ERROR: File checkBaseTables.sql was not found."
  exit "${ERROR_MISSING_FILE}"
 fi
 if [[ ! -r "${CREATE_OBJECTS_FILE}" ]]; then
  __loge "ERROR: File createObjects.sql was not found."
  exit "${ERROR_MISSING_FILE}"
 fi
 if [[ ! -r "${EMPTY_TABLES_FILE}" ]]; then
  __loge "ERROR: File emptyTables.sql was not found."
  exit "${ERROR_MISSING_FILE}"
 fi
 if [[ ! -r "${ALTER_OBJECTS_FILE}" ]]; then
  __loge "ERROR: File alterObjects.sql was not found."
  exit "${ERROR_MISSING_FILE}"
 fi
 if [[ ! -r "${POPULATE_FILE}" ]]; then
  __loge "ERROR: File populateTables.sql was not found."
  exit "${ERROR_MISSING_FILE}"
 fi
 __log_finish
 set -e
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

# Creates base tables that hold the whole history.
function __createBaseTables {
 __log_start
 __logi "Creating tables for star model if they do not exist"
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${CREATE_OBJECTS_FILE}"
 __logi "Deleting any data"
 psql -d "${DBNAME}" -f "${EMPTY_TABLES_FILE}"
 __logi "Adding relation and indexes"
 psql -d "${DBNAME}" -f "${ALTER_OBJECTS_FILE}"
 __log_finish
}

# Processes the notes and comments.
function __processNotes {
 __log_start
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POPULATE_FILE}"
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
 
 if [[ "${PROCESS_TYPE}" == "--create" ]] ; then
  __createBaseTables
 fi
 __processNotes
 
 __logw "Ending process"
}

# Allows to other user read the directory.
chmod go+x "${TMP_DIR}"

__start_logger
if [ ! -t 1 ] ; then
 __set_log_file "${LOG_FILENAME}"
 main >> "${LOG_FILENAME}"
 if [[ -n "${CLEAN}" ]] && [[ "${CLEAN}" = true ]] ; then
  mv "${LOG_FILE}" "/tmp/${BASENAME}_$(date +%Y-%m-%d_%H-%M-%S || true).log"
  rmdir "${TMP_DIR}"
 fi
else
 main
fi

