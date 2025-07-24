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
# For contributing, please execute these commands before submitting:
# * shellcheck -x -o all ETL.sh
# * shfmt -w -i 1 -sr -bn ETL.sh
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-18
declare -r VERSION="2025-07-18"

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

# PostgreSQL SQL script files.
# Check base tables.
declare -r POSTGRES_11_CHECK_BASE_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_11_checkDWHTables.sql"
# Drop datamart objects.
declare -r POSTGRES_12_DROP_DATAMART_OBJECTS="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_12_removeDatamartObjects.sql"
# Drop DWH objects.
declare -r POSTGRES_13_DROP_DWH_OBJECTS="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_13_removeDWHObjects.sql"

# Create DWH tables.
declare -r POSTGRES_22_CREATE_DWH_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_22_createDWHTables.sql"
# Populates regions per country.
declare -r POSTGRES_23_GET_WORLD_REGIONS="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_23_getWorldRegion.sql"
# Add functions.
declare -r POSTGRES_24_ADD_FUNCTIONS="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_24_addFunctions.sql"
# Populate dimension tables.
declare -r POSTGRES_25_POPULATE_DIMENSIONS="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_25_populateDimensionTables.sql"
# Update dimension tables.
declare -r POSTGRES_26_UPDATE_DIMENSIONS="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_26_updateDimensionTables.sql"

# Staging SQL script files.
# Create base staging objects.
declare -r POSTGRES_31_CREATE_BASE_STAGING_OBJECTS="${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging_31_createBaseStagingObjects.sql"
# Create staging objects.
declare -r POSTGRES_32_CREATE_STAGING_OBJECTS="${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging_32_createStagingObjects.sql"
# Create initial facts base objects.
declare -r POSTGRES_33_CREATE_FACTS_BASE_OBJECTS="${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging_33_initialFactsBaseObjects.sql"
# Create initial facts load.
declare -r POSTGRES_34_CREATE_FACTS_YEAR_LOAD="${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging_34_initialFactsLoadCreate.sql"
# Execute initial facts load.
declare -r POSTGRES_35_EXECUTE_FACTS_YEAR_LOAD="${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging_35_initialFactsLoadExecute.sql"
# Drop initial facts load.
declare -r POSTGRES_36_DROP_FACTS_YEAR_LOAD="${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging_36_initialFactsLoadDrop.sql"
# Add constraints, indexes and triggers.
declare -r POSTGRES_41_ADD_CONSTRAINTS_INDEXES_TRIGGERS="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_41_addConstraintsIndexesTriggers.sql"
# Unify facts.
declare -r POSTGRES_51_UNIFY_FACTS="${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging_51_unify.sql"

# Load notes staging.
declare -r POSTGRES_61_LOAD_NOTES_STAGING="${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging_61_loadNotes.sql"

# Datamart script files.
declare -r DATAMART_COUNTRIES_SCRIPT="${SCRIPT_BASE_DIRECTORY}/bin/dwh/datamartCountries/datamartCountries.sh"
declare -r DATAMART_USERS_SCRIPT="${SCRIPT_BASE_DIRECTORY}/bin/dwh/datamartUsers/datamartUsers.sh"

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
  && [[ "${PROCESS_TYPE}" != "-h" ]]; then
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
 if [[ ! -r "${DATAMART_COUNTRIES_SCRIPT}" ]]; then
  __loge "ERROR: File datamartCountries.sh was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${DATAMART_USERS_SCRIPT}" ]]; then
  __loge "ERROR: File datamartUsers.sh was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_11_CHECK_BASE_TABLES}" ]]; then
  __loge "ERROR: File ${POSTGRES_11_CHECK_BASE_TABLES} was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_12_DROP_DATAMART_OBJECTS}" ]]; then
  __loge "ERROR: File ${POSTGRES_12_DROP_DATAMART_OBJECTS} was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_13_DROP_DWH_OBJECTS}" ]]; then
  __loge "ERROR: File ${POSTGRES_13_DROP_DWH_OBJECTS} was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_22_CREATE_DWH_TABLES}" ]]; then
  __loge "ERROR: File ${POSTGRES_22_CREATE_DWH_TABLES} was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_23_GET_WORLD_REGIONS}" ]]; then
  __loge "ERROR: File ${POSTGRES_23_GET_WORLD_REGIONS} was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_24_ADD_FUNCTIONS}" ]]; then
  __loge "ERROR: File ${POSTGRES_24_ADD_FUNCTIONS} was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_25_POPULATE_DIMENSIONS}" ]]; then
  __loge "ERROR: File ${POSTGRES_25_POPULATE_DIMENSIONS} was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_26_UPDATE_DIMENSIONS}" ]]; then
  __loge "ERROR: File ${POSTGRES_26_UPDATE_DIMENSIONS} was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_31_CREATE_BASE_STAGING_OBJECTS}" ]]; then
  __loge "ERROR: File ${POSTGRES_31_CREATE_BASE_STAGING_OBJECTS} was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_32_CREATE_STAGING_OBJECTS}" ]]; then
  __loge "ERROR: File ${POSTGRES_32_CREATE_STAGING_OBJECTS} was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_33_CREATE_FACTS_BASE_OBJECTS}" ]]; then
  __loge "ERROR: File ${POSTGRES_33_CREATE_FACTS_BASE_OBJECTS} was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_34_CREATE_FACTS_YEAR_LOAD}" ]]; then
  __loge "ERROR: File ${POSTGRES_34_CREATE_FACTS_YEAR_LOAD} was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_35_EXECUTE_FACTS_YEAR_LOAD}" ]]; then
  __loge "ERROR: File ${POSTGRES_35_EXECUTE_FACTS_YEAR_LOAD} was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_36_DROP_FACTS_YEAR_LOAD}" ]]; then
  __loge "ERROR: File ${POSTGRES_36_DROP_FACTS_YEAR_LOAD} was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_41_ADD_CONSTRAINTS_INDEXES_TRIGGERS}" ]]; then
  __loge "ERROR: File ${POSTGRES_41_ADD_CONSTRAINTS_INDEXES_TRIGGERS} was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_51_UNIFY_FACTS}" ]]; then
  __loge "ERROR: File ${POSTGRES_51_UNIFY_FACTS} was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_61_LOAD_NOTES_STAGING}" ]]; then
  __loge "ERROR: File ${POSTGRES_61_LOAD_NOTES_STAGING} was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 __log_finish
 set -e
}

# Waits until a job is finished, to not have more parallel process than cores
# to the server.
function __waitForJobs {
 __log_start
 # Uses n-1 cores, if number of cores is greater than 1.
 # This prevents monopolization of the CPUs.
 if [[ "${MAX_THREADS}" -gt 6 ]]; then
  MAX_THREADS=$((MAX_THREADS - 2))
 elif [[ "${MAX_THREADS}" -gt 1 ]]; then
  MAX_THREADS=$((MAX_THREADS - 1))
 fi
 QTY=$(jobs -p | wc -l)
 __logd "Number of threads ${QTY} from max ${MAX_THREADS}."
 while [[ "${QTY}" -ge ${MAX_THREADS} ]]; do
  __logi "Waiting for a thread..."
  wait -n
  __logi "Waiting is over."
  QTY=$(jobs -p | wc -l)
 done
 __log_finish
}

# Process facts in parallel.
function __initialFacts {
 __log_start
 # First year (less number of notes).
 MIN_YEAR="2013"
 # Gets the current year as max (max number of notes).
 MAX_YEAR=$(date +%Y)
 # Processing year.
 YEAR="${MAX_YEAR}"

 __logw "Starting parallel process to process facts per year..."
 while [[ "${YEAR}" -ge "${MIN_YEAR}" ]]; do
  __waitForJobs
  (
   __logi "Starting ${YEAR} - ${BASHPID}."
   # Loads the data in the database.
   export YEAR
   # shellcheck disable=SC2016
   psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
    -c "$(envsubst '$YEAR' < "${POSTGRES_33_CREATE_FACTS_BASE_OBJECTS}" || true)"
   # shellcheck disable=SC2016
   psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
    -c "$(envsubst '$YEAR' < "${POSTGRES_34_CREATE_FACTS_YEAR_LOAD}" || true)"
   # shellcheck disable=SC2016
   psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
    -c "$(envsubst '$YEAR' < "${POSTGRES_35_EXECUTE_FACTS_YEAR_LOAD}" || true)" \
    >> "${LOG_FILENAME}.${BASHPID}" 2>&1
   __logi "Finishing ${YEAR} - ${BASHPID}."
  ) &
  __logi "Check log per thread for more information."
  sleep 5 # To insert all days of the year in the dimension.
  YEAR=$((YEAR - 1))
 done
 psql -d "${DBNAME}" -c "DROP INDEX IF EXISTS comments_function_year"

 # Waits until all years are fniished.
 wait
 __logw "Waited for all jobs, restarting in main thread."

 YEAR="2013"
 while [[ "${YEAR}" -le "${MAX_YEAR}" ]]; do
  __logi "Copying facts from ${YEAR}."
  STMT="
    INSERT INTO dwh.facts (
      id_note, dimension_id_country, processing_time, action_at, action_comment,
      action_dimension_id_date, action_dimension_id_hour_of_week,
      action_dimension_id_user, opened_dimension_id_date,
      opened_dimension_id_hour_of_week, opened_dimension_id_user,
      closed_dimension_id_date, closed_dimension_id_hour_of_week,
      closed_dimension_id_user, dimension_application_creation,
      recent_opened_dimension_id_date, days_to_resolution,
      days_to_resolution_active, days_to_resolution_from_reopen, hashtag_1,
      hashtag_2, hashtag_3, hashtag_4, hashtag_5, hashtag_number
      )
     SELECT /* Notes-ETL */
      id_note, dimension_id_country, processing_time, action_at, action_comment,
      action_dimension_id_date, action_dimension_id_hour_of_week,
      action_dimension_id_user, opened_dimension_id_date,
      opened_dimension_id_hour_of_week, opened_dimension_id_user,
      closed_dimension_id_date, closed_dimension_id_hour_of_week,
      closed_dimension_id_user, dimension_application_creation,
      recent_opened_dimension_id_date, days_to_resolution,
      days_to_resolution_active, days_to_resolution_from_reopen, hashtag_1,
      hashtag_2, hashtag_3, hashtag_4, hashtag_5, hashtag_number
     FROM staging.facts_${YEAR}
     ORDER BY fact_id
    "
  echo "${STMT}" | psql -d "${DBNAME}" -v ON_ERROR_STOP=1 2>&1

  # Drops the temporal tables.
  if [[ -n "${CLEAN}" ]] && [[ "${CLEAN}" = true ]]; then
   export YEAR
   # shellcheck disable=SC2016
   psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
    -c "$(envsubst '$YEAR' < "${POSTGRES_36_DROP_FACTS_YEAR_LOAD}" || true)" 2>&1
  fi

  YEAR=$((YEAR + 1))
 done

 # Assign all constraints to the fact table.
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_41_ADD_CONSTRAINTS_INDEXES_TRIGGERS}" 2>&1

 # Unifies the facts, by computing dates between years.
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_51_UNIFY_FACTS}" 2>&1

 __log_finish
}

# Creates base tables that hold the whole history.
function __createBaseTables {
 __log_start
 __logi "Droping any ETL object if any exist."
 psql -d "${DBNAME}" -f "${POSTGRES_12_DROP_DATAMART_OBJECTS}" 2>&1
 psql -d "${DBNAME}" -f "${POSTGRES_13_DROP_DWH_OBJECTS}" 2>&1

 __logi "Creating tables for star model if they do not exist."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_22_CREATE_DWH_TABLES}" 2>&1
 __logi "Regions for countries."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_23_GET_WORLD_REGIONS}" 2>&1
 __logi "Adding relation, indexes AND triggers."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_24_ADD_FUNCTIONS}" 2>&1

 __logi "Initial dimension population."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_25_POPULATE_DIMENSIONS}" 2>&1

 __logi "Initial user dimension population."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_26_UPDATE_DIMENSIONS}" 2>&1

 __logi "Creating base staging objects."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_31_CREATE_BASE_STAGING_OBJECTS}" 2>&1

 __logi "Creating staging objects."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_32_CREATE_STAGING_OBJECTS}" 2>&1

 echo "INSERT INTO dwh.properties VALUES ('initial load', 'true')" \
  | psql -d "${DBNAME}" -v ON_ERROR_STOP=1 2>&1

 __initialFacts

 __log_finish
}

# Checks the base tables if exist.
function __checkBaseTables {
 __log_start
 set +e
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_11_CHECK_BASE_TABLES}" 2>&1
 RET=${?}
 set -e
 if [[ "${RET}" -ne 0 ]]; then
  __createBaseTables
 fi

 __logi "Recreating base staging objects."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_31_CREATE_BASE_STAGING_OBJECTS}" 2>&1

 __logi "Recreating staging objects."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_32_CREATE_STAGING_OBJECTS}" 2>&1

 __log_finish
}

# Processes the notes and comments.
function __processNotesETL {
 __log_start
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_26_UPDATE_DIMENSIONS}" 2>&1

 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_61_LOAD_NOTES_STAGING}" 2>&1
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

 __logw "Starting process."
 # Sets the trap in case of any signal.
 __trapOn
 exec 7> "${LOCK}"
 __logw "Validating single execution."
 ONLY_EXECUTION="no"
 flock -n 7
 ONLY_EXECUTION="yes"

 __checkPrereqs
 set +E
 __checkBaseTables
 set -E

 __processNotesETL

 # Updates the datamart for countries.
 "${DATAMART_COUNTRIES_SCRIPT}"

 # Updates the datamart for users.
 "${DATAMART_USERS_SCRIPT}"

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
  mv "${LOG_FILENAME}" "/tmp/${BASENAME}_$(date +%Y-%m-%d_%H-%M-%S || true).log"
  rmdir "${TMP_DIR}"
 fi
else
 main
fi
