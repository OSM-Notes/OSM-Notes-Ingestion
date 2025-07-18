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
# Version: 2025-07-10
declare -r VERSION="2025-07-10"

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
chmod 777 "${TMP_DIR}"
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

# Name of the SQL script that check the existance of base tables.
declare -r POSTGRES_11_CHECK_BASE_TABLES_FILE="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_11_checkDWHTables.sql"
# Name of the SQL script that contains existing ETL object form the DB.
declare -r POSTGRES_12_DROP_OBJECTS_FILE="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_12_removeDatamartObjects.sql"
# Name of the SQL script that contains existing ETL object form the DB.
declare -r POSTGRES_13_DROP_OBJECTS_FILE="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_13_removeDWHObjects.sql"

# Name of the SQL script that contains the objects to create in the DB.
declare -r POSTGRES_22_CREATE_OBJECTS_FILE="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_22_createDWHTables.sql"
# Populates regions per country.
declare -r POSTGRES_23_REGIONS_FILE="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_23_getWorldRegion.sql"
# Name of the SQL script that contains the alter statements and PK.
declare -r POSTGRES_24_ADD_OBJECTS_FILE="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_24_addFunctions.sql"
# Create staging procedures.
declare -r POSTGRES_25_POPULATE_DIMENSIONS_FILE="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_25_populateDimensionTables.sql"
# Name of the SQL script that updates the dimensions.
declare -r POSTGRES_26_UDPATE_DIMENSIONS_FILE="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_26_updateDimensionTables.sql"

# Create base staging objects.
declare -r POSTGRES_31_CREATE_BASE_STAGING_OBJS_FILE="${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging_31_createBaseStagingObjects.sql"
# Create staging objets.
declare -r POSTGRES_32_CREATE_STAGING_OBJS_FILE="${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging_32_createStagingObjects.sql"
# Script to do the initial load - create. One-time execution.
declare -r POSTGRES_33_FACTS_BASE_CREATE="${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging_33_initialFactsBaseObjects.sql"
# Script to do the initial load - create. One-time execution.
declare -r POSTGRES_34_FACTS_YEAR_CREATE="${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging_34_initialFactsLoadCreate.sql"
# Script to do the initial load - execute.
declare -r POSTGRES_35_FACTS_YEAR_EXECUTE="${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging_35_initialFactsLoadExecute.sql"
# Script to do the initial load - drop.
declare -r POSTGRES_36_FACTS_YEAR_DROP="${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging_36_initialFactsLoadDrop.sql"
# Name of the SQL script that contains the alter statements.
declare -r POSTGRES_41_ADD_CONSTRAINTS="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_41_addConstraintsIndexesTriggers.sql"
# Script to do the initial load - execute.
declare -r POSTGRES_51_FACTS_UNIFY="${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging_51_unify.sql"

# Create staging procedures.
declare -r POSTGRES_61_LOAD_NOTES_STAGING_FILE="${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging_61_loadNotes.sql"

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
 if [[ ! -r "${DATAMART_COUNTRIES_FILE}" ]]; then
  __loge "ERROR: File datamartCountries.sh was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${DATAMART_USERS_FILE}" ]]; then
  __loge "ERROR: File datamartUsers.sh was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_11_CHECK_BASE_TABLES_FILE}" ]]; then
  __loge "ERROR: File ${POSTGRES_11_CHECK_BASE_TABLES_FILE} was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_12_DROP_OBJECTS_FILE}" ]]; then
  __loge "ERROR: File ${POSTGRES_12_DROP_OBJECTS_FILE} was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_13_DROP_OBJECTS_FILE}" ]]; then
  __loge "ERROR: File ${POSTGRES_13_DROP_OBJECTS_FILE} was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_22_CREATE_OBJECTS_FILE}" ]]; then
  __loge "ERROR: File ${POSTGRES_22_CREATE_OBJECTS_FILE} was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_23_REGIONS_FILE}" ]]; then
  __loge "ERROR: File ${POSTGRES_23_REGIONS_FILE} was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_24_ADD_OBJECTS_FILE}" ]]; then
  __loge "ERROR: File ${POSTGRES_24_ADD_OBJECTS_FILE} was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_25_POPULATE_DIMENSIONS_FILE}" ]]; then
  __loge "ERROR: File ${POSTGRES_25_POPULATE_DIMENSIONS_FILE} was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_26_UDPATE_DIMENSIONS_FILE}" ]]; then
  __loge "ERROR: File ${POSTGRES_26_UDPATE_DIMENSIONS_FILE} was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_31_CREATE_BASE_STAGING_OBJS_FILE}" ]]; then
  __loge "ERROR: File ${POSTGRES_31_CREATE_BASE_STAGING_OBJS_FILE} was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_32_CREATE_STAGING_OBJS_FILE}" ]]; then
  __loge "ERROR: File ${POSTGRES_32_CREATE_STAGING_OBJS_FILE} was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_33_FACTS_BASE_CREATE}" ]]; then
  __loge "ERROR: File ${POSTGRES_33_FACTS_BASE_CREATE} was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_34_FACTS_YEAR_CREATE}" ]]; then
  __loge "ERROR: File ${POSTGRES_34_FACTS_YEAR_CREATE} was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_35_FACTS_YEAR_EXECUTE}" ]]; then
  __loge "ERROR: File ${POSTGRES_35_FACTS_YEAR_EXECUTE} was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_36_FACTS_YEAR_DROP}" ]]; then
  __loge "ERROR: File ${POSTGRES_36_FACTS_YEAR_DROP} was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_41_ADD_CONSTRAINTS}" ]]; then
  __loge "ERROR: File ${POSTGRES_41_ADD_CONSTRAINTS} was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_51_FACTS_UNIFY}" ]]; then
  __loge "ERROR: File ${POSTGRES_51_FACTS_UNIFY} was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_61_LOAD_NOTES_STAGING_FILE}" ]]; then
  __loge "ERROR: File ${POSTGRES_61_LOAD_NOTES_STAGING_FILE} was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 __log_finish
 set -e
}

# Waits until a job is finished, to not have more parallel process than cores
# to the server.
function __waitForJobs {
 __log_start
 MAX_THREADS=$(nproc)
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
    -c "$(envsubst '$YEAR' < "${POSTGRES_33_FACTS_BASE_CREATE}" || true)"
   # shellcheck disable=SC2016
   psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
    -c "$(envsubst '$YEAR' < "${POSTGRES_34_FACTS_YEAR_CREATE}" || true)"
   # shellcheck disable=SC2016
   psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
    -c "$(envsubst '$YEAR' < "${POSTGRES_35_FACTS_YEAR_EXECUTE}" || true)" \
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
    -c "$(envsubst '$YEAR' < "${POSTGRES_36_FACTS_YEAR_DROP}" || true)" 2>&1
  fi

  YEAR=$((YEAR + 1))
 done

 # Assign all constraints to the fact table.
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_41_ADD_CONSTRAINTS}" 2>&1

 # Unifies the facts, by computing dates between years.
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_51_FACTS_UNIFY}" 2>&1

 __log_finish
}

# Creates base tables that hold the whole history.
function __createBaseTables {
 __log_start
 __logi "Droping any ETL object if any exist."
 psql -d "${DBNAME}" -f "${POSTGRES_12_DROP_OBJECTS_FILE}" 2>&1
 psql -d "${DBNAME}" -f "${POSTGRES_13_DROP_OBJECTS_FILE}" 2>&1

 __logi "Creating tables for star model if they do not exist."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_22_CREATE_OBJECTS_FILE}" 2>&1
 __logi "Regions for countries."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_23_REGIONS_FILE}" 2>&1
 __logi "Adding relation, indexes AND triggers."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_24_ADD_OBJECTS_FILE}" 2>&1

 __logi "Initial dimension population."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_25_POPULATE_DIMENSIONS_FILE}" 2>&1

 __logi "Initial user dimension population."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_26_UDPATE_DIMENSIONS_FILE}" 2>&1

 __logi "Creating base staging objects."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_31_CREATE_BASE_STAGING_OBJS_FILE}" 2>&1

 __logi "Creating staging objects."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_32_CREATE_STAGING_OBJS_FILE}" 2>&1

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
  -f "${POSTGRES_11_CHECK_BASE_TABLES_FILE}" 2>&1
 RET=${?}
 set -e
 if [[ "${RET}" -ne 0 ]]; then
  __createBaseTables
 fi

 __logi "Recreating base staging objects."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_31_CREATE_BASE_STAGING_OBJS_FILE}" 2>&1

 __logi "Recreating staging objects."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_32_CREATE_STAGING_OBJS_FILE}" 2>&1

 __log_finish
}

# Processes the notes and comments.
function __processNotesETL {
 __log_start
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_26_UDPATE_DIMENSIONS_FILE}" 2>&1

 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_61_LOAD_NOTES_STAGING_FILE}" 2>&1
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
 "${DATAMART_COUNTRIES_FILE}"

 # Updates the datamart for users.
 "${DATAMART_USERS_FILE}"

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
