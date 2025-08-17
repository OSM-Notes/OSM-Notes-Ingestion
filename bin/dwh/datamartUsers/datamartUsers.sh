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
# Version: 2025-08-11
VERSION="2025-08-11"

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
# CLEAN is now defined in etc/properties.sh, no need to declare it here

# Logger levels: TRACE, DEBUG, INFO, WARN, ERROR, FATAL.
declare LOG_LEVEL="${LOG_LEVEL:-ERROR}"

# Base directory for the project.
declare SCRIPT_BASE_DIRECTORY
SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." \
 &> /dev/null && pwd)"
readonly SCRIPT_BASE_DIRECTORY

# Loads the global properties.
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh"

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
if [[ -z "${PROCESS_TYPE:-}" ]]; then
 declare -r PROCESS_TYPE=${1:-}
fi

# Name of the SQL script that contains the objects to create in the DB.
declare -r POSTGRES_11_CHECK_OBJECTS_FILE="${SCRIPT_BASE_DIRECTORY}/sql/dwh/datamartUsers/datamartUsers_11_checkDatamartUsersTables.sql"

# Name of the SQL script that contains the tables to create in the DB.
declare -r POSTGRES_12_CREATE_TABLES_FILE="${SCRIPT_BASE_DIRECTORY}/sql/dwh/datamartUsers/datamartUsers_12_createDatamartUsersTable.sql"

# Name of the SQL script that contains the procedures to create in the DB.
declare -r POSTGRES_13_CREATE_PROCEDURES_FILE="${SCRIPT_BASE_DIRECTORY}/sql/dwh/datamartUsers/datamartUsers_13_createProcedure.sql"

# Last year activities script.
declare -r POSTGRES_14_LAST_YEAR_ACTITIES_SCRIPT="${SCRIPT_BASE_DIRECTORY}/sql/dwh/datamarts_lastYearActivities.sql"

# Generic script to add years.
declare -r POSTGRES_21_ADD_YEARS_SCRIPT="${SCRIPT_BASE_DIRECTORY}/sql/dwh/datamartUsers/datamartUsers_21_alterTableAddYears.sql"

# Name of the SQL script to analyse only users with few actions.
declare -r POSTGRES_31_POPULATE_OLD_USERS_FILE="${SCRIPT_BASE_DIRECTORY}/sql/dwh/datamartUsers/datamartUsers_31_populateOldUsers.sql"

# Name of the SQL script that contains the ETL process.
declare -r POSTGRES_32_POPULATE_FILE="${SCRIPT_BASE_DIRECTORY}/sql/dwh/datamartUsers/datamartUsers_32_populateDatamartUsersTable.sql"

###########
# FUNCTIONS

# Load common functions
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/bin/commonFunctions.sh"

# Load validation functions
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/bin/validationFunctions.sh"

# Load error handling functions
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/bin/errorHandlingFunctions.sh"

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
  && [[ "${PROCESS_TYPE}" != "-h" ]]; then
  echo "ERROR: Invalid parameter. It should be:"
  echo " * Empty string, nothing."
  echo " * --help"
  exit "${ERROR_INVALID_ARGUMENT}"
 fi

 __checkPrereqsCommands

 ## Validate SQL script files using centralized validation
 __logi "Validating SQL script files..."

 # Create array of SQL files to validate
 local SQL_FILES=(
  "${POSTGRES_11_CHECK_OBJECTS_FILE}"
  "${POSTGRES_12_CREATE_TABLES_FILE}"
  "${POSTGRES_13_CREATE_PROCEDURES_FILE}"
  "${POSTGRES_14_LAST_YEAR_ACTITIES_SCRIPT}"
  "${POSTGRES_21_ADD_YEARS_SCRIPT}"
  "${POSTGRES_31_POPULATE_OLD_USERS_FILE}"
  "${POSTGRES_32_POPULATE_FILE}"
 )

 # Validate each SQL file
 for SQL_FILE in "${SQL_FILES[@]}"; do
  if ! __validate_sql_structure "${SQL_FILE}"; then
   __loge "ERROR: SQL file validation failed: ${SQL_FILE}"
   exit "${ERROR_MISSING_LIBRARY}"
  fi
 done

 __log_finish
}

# Creates base tables that hold the whole history.
function __createBaseTables {
 __log_start
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_12_CREATE_TABLES_FILE}"
 PROCESS_OLD_USERS=yes
 __log_finish
}

# Checks the tables are created.
function __checkBaseTables {
 __log_start
 set +e
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_11_CHECK_OBJECTS_FILE}"
 RET=${?}
 set -e
 if [[ "${RET}" -ne 0 ]]; then
  __logw "Creating datamart users tables."
  __createBaseTables
  __logw "Datamart users tables created."
 fi
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_13_CREATE_PROCEDURES_FILE}"
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_14_LAST_YEAR_ACTITIES_SCRIPT}"
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
  psql -d "${DBNAME}" -c "$(envsubst '$YEAR' \
   < "${POSTGRES_21_ADD_YEARS_SCRIPT}" || true)" 2>&1
  set -e
 done
 __log_finish
}

# Processes initial batch of users.
function __processOldUsers {
 __log_start
 MAX_USER_ID=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT MAX(user_id) FROM dwh.dimension_users" -v ON_ERROR_STOP=1)
 MAX_USER_ID=$(("MAX_USER_ID" + 1))

 # Processes the users in parallel.
 # Uses n-1 cores, if number of cores is greater than 1.
 # This prevents monopolization of the CPUs.
 if [[ "${MAX_THREADS}" -gt 6 ]]; then
  MAX_THREADS=$((MAX_THREADS - 2))
 elif [[ "${MAX_THREADS}" -gt 1 ]]; then
  MAX_THREADS=$((MAX_THREADS - 1))
 fi

 SIZE=$((MAX_USER_ID / MAX_THREADS))
 LOWER_VALUE=1
 HIGH_VALUE="${SIZE}"
 ITER=1
 __logw "Starting parallel process for datamartUsers..."
 while [[ "${ITER}" -le "${MAX_THREADS}" ]]; do
  (
   __logi "Starting user batch ${LOWER_VALUE}-${HIGH_VALUE} - ${BASHPID}."

   export LOWER_VALUE
   export HIGH_VALUE
   set +e
   # shellcheck disable=SC2016
   psql -d "${DBNAME}" -c "$(envsubst '$LOWER_VALUE,$HIGH_VALUE' \
    < "${POSTGRES_31_POPULATE_OLD_USERS_FILE}" || true)" \
    >> "${LOG_FILENAME}.${BASHPID}" 2>&1
   set -e

   __logi "Finished user batch ${LOWER_VALUE}-${HIGH_VALUE} - ${BASHPID}."
  ) &
  ITER=$((ITER + 1))
  LOWER_VALUE=$((HIGH_VALUE + 1))
  HIGH_VALUE=$((HIGH_VALUE + SIZE))
  __logi "Check log per thread for more information."
  sleep 5
 done

 wait
 __logw "Waited for all jobs, restarting in main thread."

 __log_finish
}
# Processes the notes and comments.
function __processNotesUser {
 __log_start
 if [[ "${PROCESS_OLD_USERS}" == "yes" ]]; then
  __processOldUsers
 fi
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_32_POPULATE_FILE}" 2>&1
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
 # shellcheck disable=SC2034
 ONLY_EXECUTION="no"
 flock -n 7
 # shellcheck disable=SC2034
 ONLY_EXECUTION="yes"

 # This variable is to process all those users that have performed less than 20
 # note actions, but are 95% of the users. It should be processed when the
 # tables are created.
 PROCESS_OLD_USERS=no

 set +E
 __checkBaseTables
 # Add new columns for years after 2013.
 __addYears
 set -E
 __processNotesUser

 __logw "Ending process."
 __log_finish
}

# Allows to other user read the directory.
chmod go+x "${TMP_DIR}"

__start_logger
if [[ "${SKIP_MAIN:-}" != "true" ]]; then
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
fi
