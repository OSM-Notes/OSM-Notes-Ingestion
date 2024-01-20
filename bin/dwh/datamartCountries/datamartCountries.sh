#!/bin/bash

# Creates a datamart for country's data.
#
# To follow the progress you can execute:
#   tail -40f $(ls -1rtd /tmp/datamartCountries_* | tail -1)/datamartCountries.log
#
# This is the list of error codes:
# 1) Help message.
# 241) Library or utility missing.
# 242) Invalid argument for script invocation.
# 243) Logger utility is not available.
#
# For contributing, please execute these commands at the end:
# * shellcheck -x -o all datamartCountries.sh
# * shfmt -w -i 1 -sr -bn datamartCountries.sh
#
# Author: Andres Gomez (AngocA)
# Version: 2023-12-08
declare -r VERSION="2023-12-08"

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
declare LOG_FILENAME
LOG_FILENAME="${TMP_DIR}/${BASENAME}.log"
readonly LOG_FILENAME

# Lock file for single execution.
declare LOCK
LOCK="/tmp/${BASENAME}.lock"
readonly LOCK

# Type of process to run in the script.
declare -r PROCESS_TYPE=${1:-}

# Name of the SQL script that contains the objects to create in the DB.
declare -r CHECK_OBJECTS_FILE="${SCRIPT_BASE_DIRECTORY}/sql/dwh/datamartCountries/datamartCountries-checkDatamartCountriesTables.sql"

# Name of the SQL script that contains the tables to create in the DB.
declare -r CREATE_TABLES_FILE="${SCRIPT_BASE_DIRECTORY}/sql/dwh/datamartCountries/datamartCountries-createDatamarCountriesTable.sql"

# Name of the SQL script that contains the procedures to create in the DB.
declare -r CREATE_PROCEDURES_FILE="${SCRIPT_BASE_DIRECTORY}/sql/dwh/datamartCountries/datamartCountries-createProcedure.sql"

# Name of the SQL script that contains the ETL process.
declare -r POPULATE_FILE="${SCRIPT_BASE_DIRECTORY}/sql/dwh/datamartCountries/datamartCountries-populateDatamartCountriesTable.sql"

# Generic script to add years.
declare -r ADD_YEARS_SCRIPT="${SCRIPT_BASE_DIRECTORY}/sql/dwh/datamartCountries/datamartCountries-alterTableAddYears.sql"

# Last year activites script.
declare -r LAST_YEAR_ACTITIES_SCRIPT="${SCRIPT_BASE_DIRECTORY}/sql/dwh/datamarts-lastYearActivities.sql"

# Location of the common functions.
declare -r FUNCTIONS_FILE="${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh"

###########
# FUNCTIONS

# shellcheck source=../../functionsProcess.sh
source "${FUNCTIONS_FILE}"

# Shows the help information.
function __show_help {
 echo "${0} version ${VERSION}"
 echo "This scripts populates the datamart to visualize country's data."
 echo
 echo "Written by: Andres Gomez (AngocA)"
 echo "OSM-LatAm, OSM-Colombia, MaptimeBogota."
 exit "${ERROR_HELP_MESSAGE}"
}

# Checks prerequisites to run the script.
function __checkPrereqs {
 __log_start
 if [[ "${PROCESS_TYPE}" != "" ]] && [[ "${PROCESS_TYPE}" != "--help" ]] \
  && [[ "${PROCESS_TYPE}" != "-h" ]]; then
  echo "ERROR: Invalid parameter. It should be:"
  echo " * Empty string, nothing."
  echo " * --help"
  exit "${ERROR_INVALID_ARGUMENT}"
 fi

 __checkPrereqsCommands

 ## Check files
 if [[ ! -r "${CHECK_OBJECTS_FILE}" ]]; then
  __loge "ERROR: File datamartCountries-checkDatamartCountriesTables.sql was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${CREATE_TABLES_FILE}" ]]; then
  __loge "ERROR: File datamartCountries-createDatamartCountriesTable.sql was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${CREATE_PROCEDURES_FILE}" ]]; then
  __loge "ERROR: File datamartCountries-createProcedure.sql was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POPULATE_FILE}" ]]; then
  __loge "ERROR: File datamartCountries-populateDatamartCountriesTable.sql was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${ADD_YEARS_SCRIPT}" ]]; then
  __loge "ERROR: File datamartCountries-alterTableAddYears.sql was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${LAST_YEAR_ACTITIES_SCRIPT}" ]]; then
  __loge "ERROR: File datamart-lastYearActivities.sql was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 __log_finish
 set -e
}

# Creates base tables that hold the whole history.
function __createBaseTables {
 __log_start
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${CREATE_TABLES_FILE}"
 __log_finish
}

# Checks the tables are created.
function __checkBaseTables {
 __log_start
 set +e
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${CHECK_OBJECTS_FILE}"
 RET=${?}
 set -e
 if [[ "${RET}" -ne 0 ]]; then
  __logw "Creating datamart countries tables."
  __createBaseTables
  __logw "Datamart countries tables created."
 fi
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${CREATE_PROCEDURES_FILE}"
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${LAST_YEAR_ACTITIES_SCRIPT}"
 __log_finish
}

# Adds the columns up to the current year.
function __addYears {
 __log_start
 YEAR=2013
 CURRENT_YEAR=$(date +%Y)
 while [[ "${YEAR}" -lt "${CURRENT_YEAR}" ]]; do
  YEAR=$((YEAR + 1))
  export YEAR
  set +e
  # shellcheck disable=SC2016
  psql -d "${DBNAME}" -c "$(envsubst '$YEAR' < "${ADD_YEARS_SCRIPT}" \
   || true)" 2>&1
  set -e
 done
 __log_finish
}

# Processes the notes and comments.
function __processNotesCountries {
 __log_start
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POPULATE_FILE}" 2>&1
 __log_finish
}

######
# MAIN

function main() {
 __log_start
 __logi "Preparing environment."
 __logd "Output saved at: ${TMP_DIR}."
 __logi "Processing: ${PROCESS_TYPE}."

 if [[ "${PROCESS_TYPE}" == "-h" ]] \
  || [[ "${PROCESS_TYPE}" == "--help" ]]; then
  __show_help
 fi
 __checkPrereqs

 __logw "Starting process."
 # Sets the trap in case of any signal.
 __trapOn
 exec 7> "${LOCK}"
 __logw "Validating single execution."
 ONLY_EXECUTION="no"
 flock -n 7
 ONLY_EXECUTION="yes"

 set +E
 __checkBaseTables
 # Add new columns for years after 2013.
 __addYears
 set -E
 __processNotesCountries

 __logw "Ending process."
 __log_finish
}

# Allows to other user read the directory.
chmod go+x "${TMP_DIR}"

__start_logger
if [[ ! -t 1 ]]; then
 __set_log_file "${LOG_FILENAME}"
 main >> "${LOG_FILENAME}"
 if [[ -n "${CLEAN}" ]] && [[ "${CLEAN}" = true ]]; then
  mv "${LOG_FILENAME}" "/tmp/${BASENAME}_$(date +%Y-%m-%d_%H-%M-%S \
   || true).log"
  rmdir "${TMP_DIR}"
 fi
else
 main
fi
