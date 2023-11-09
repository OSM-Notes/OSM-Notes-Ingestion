#!/bin/bash

# Creates a datamart for user's data.
#
# To follow the progress you can execute:
#   tail -40f $(ls -1rtd /tmp/datamartUsers_* | tail -1)/datamartUsers.log
#
# This is the list of error codes:
# 1) Help message.
# 241) Library or utility missing.
# 242) Invalid argument for script invocation.
# 243) Logger utility is not available.
#
# For contributing, please execute these commands at the end:
# * shellcheck -x -o all datamartUsers.sh
# * shfmt -w -i 1 -sr -bn datamartUsers.sh
#
# Author: Andres Gomez (AngocA)
# Version: 2023-11-09
declare -r VERSION="2023-11-09"

#set -xv
# Fails when a variable is not initialized.
set -u
# Fails with an non-zero return code.
set -e
# Fails if the commands of a pipe return non-zero.
set -o pipefail
# Fails if an internal function fails.
set -E

# Logger levels: TRACE, DEBUG, INFO, WARN, ERROR, FATAL.
declare LOG_LEVEL="${LOG_LEVEL:-ERROR}"

# Base directory for the project.
declare SCRIPT_BASE_DIRECTORY
SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." \
  &> /dev/null && pwd)"
readonly SCRIPT_BASE_DIRECTORY

# Loads the global properties.
# shellcheck source=../../../etc/properties.sh
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

# Name of the SQL script that contains the objects to create in the DB.
declare -r CHECK_OBJECTS_FILE="${SCRIPT_BASE_DIRECTORY}/sql/dwh/datamartUsers/datamartUsers-checkDatamartUsersTable.sql"

# Name of the SQL script that contains the objects to create in the DB.
declare -r CREATE_OBJECTS_FILE="${SCRIPT_BASE_DIRECTORY}/sql/dwh/datamartUsers/datamartUsers-createDatamartUsersTable.sql"

# Name of the SQL script that contains the ETL process.
declare -r POPULATE_FILE="${SCRIPT_BASE_DIRECTORY}/sql/dwh/datamartUsers/datamartUsers-populateDatamartUsersTable.sql"

# Generic script to add years.
declare -r ADD_YEARS_SCRIPT="${SCRIPT_BASE_DIRECTORY}/sql/dwh/datamartUsers/datamartUsers-alterTableAddYears.sql"

# Location of the common functions.
declare -r FUNCTIONS_FILE="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess.sh"

###########
# FUNCTIONS

# shellcheck source=../../functionsProcess.sh
source "${FUNCTIONS_FILE}"

# Shows the help information.
function __show_help {
 echo "${0} version ${VERSION}"
 echo "This scripts populates the datamart to visualize user's data."
 echo
 echo "Written by: Andres Gomez (AngocA)"
 echo "OSM-LatAm, OSM-Colombia, MaptimeBogota."
 exit "${ERROR_HELP_MESSAGE}"
}

# Checks prerequisites to run the script.
function __checkPrereqs {
 __log_start
  if [[ "${PROCESS_TYPE}" != "" ]] && [[ "${PROCESS_TYPE}" != "--help" ]] \
   && [[ "${PROCESS_TYPE}" != "-h" ]] ; then
  echo "ERROR: Invalid parameter. It should be:"
  echo " * Empty string, nothing."
  echo " * --help"
  exit "${ERROR_INVALID_ARGUMENT}"
 fi

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
 __log_finish
 set -e
}

# Creates base tables that hold the whole history.
function __createBaseTables {
 __log_start
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${CREATE_OBJECTS_FILE}"
 __log_finish
}

# Checks the tables are created.
function __checkBaseTables {
 __log_start
 set +e
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${CHECK_OBJECTS_FILE}"
 set -e
 RET=${?}
 if [[ "${RET}" -ne 0 ]] ; then
  __logw "Creating datamart users tables."
  __createBaseTables
  __logw "Datamart users tables created."
 fi
 __log_finish
}

# Adds the columns up to the current year.
function __addYears {
 __log_start
YEAR=2013
CURRENT_YEAR=$(date +%Y)
while [ "${YEAR}" -le "${CURRENT_YEAR}" ]; do
 # shellcheck disable=SC2016
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
   -c "$(envsubst '$YEAR' < "${ADD_YEARS_SCRIPT}")"
 YEAR=$((YEAR + 1)) 
done
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

 __logw "Starting process"
 # Sets the trap in case of any signal.
 __trapOn
 exec 7> "${LOCK}"
 __logw "Validating single execution."
 flock -n 7

 __checkBaseTables
 # Add new columns for years after 2013.
 __addYears
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
