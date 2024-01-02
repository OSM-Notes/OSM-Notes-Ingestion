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
# Version: 2023-01-02
declare -r VERSION="2023-01-02"

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

# Name of the SQL script that populates the dimensions.
declare -r POPULATE_DIMENSIONS_FILE="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL-populateDimensionTables.sql"

# Name of the SQL script that updates the dimensions.
declare -r UDPATE_DIMENSIONS_FILE="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL-updateDimensionTables.sql"

# Name of the SQL script that check the existance of base tables.
declare -r CHECK_BASE_TABLES_FILE="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL-checkDWHTables.sql"

# Name of the SQL script that contains the objects to create in the DB.
declare -r DROP_OBJECTS_FILE="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL-removeDWHObjects.sql"

# Name of the SQL script that contains the objects to create in the DB.
declare -r CREATE_OBJECTS_FILE="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL-createDWHTables.sql"

# Regions per country.
declare -r REGIONS_FILE="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL-getWorldRegion.sql"

# Name of the SQL script that contains the alter statements.
declare -r ADD_OBJECTS_FILE="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL-addConstraintsIndexesTriggers.sql"

# Create staging procedures.
declare -r CREATE_STAGING_OBJS_FILE="${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging-createStagingObjects.sql"

# Script to do the initial load - create.
declare -r POSTGRES_FACTS_YEAR_CREATE="${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging-initialFactsLoadCreate.sql"
# Script to do the initial load - execute.
declare -r POSTGRES_FACTS_YEAR_EXECUTE="${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging-initialFactsLoadExecute.sql"
# Script to do the initial load - drop.
declare -r POSTGRES_FACTS_YEAR_DROP="${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging-initialFactsLoadDrop.sql"
# Script to do the initial load - execute.
declare -r POSTGRES_FACTS_UNIFY="${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging-unify.sql"

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
 if [[ ! -r "${CHECK_BASE_TABLES_FILE}" ]]; then
  __loge "ERROR: File ETL-checkDWHTables.sql was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${DROP_OBJECTS_FILE}" ]]; then
  __loge "ERROR: File ETL-removeDWHObjects.sql was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${CREATE_OBJECTS_FILE}" ]]; then
  __loge "ERROR: File ETL-createDWHTables.sql was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${REGIONS_FILE}" ]]; then
  __loge "ERROR: File ETL-getWorldRegion.sql was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${ADD_OBJECTS_FILE}" ]]; then
  __loge "ERROR: File ETL-addConstraintsIndexesTriggers.sql was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POPULATE_DIMENSIONS_FILE}" ]]; then
  __loge "ERROR: File ETL-populateDimensionTables.sql was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_FACTS_YEAR_CREATE}" ]]; then
  __loge "ERROR: File Staging-initialFactsLoadCreate.sql was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_FACTS_YEAR_EXECUTE}" ]]; then
  __loge "ERROR: File Staging-initialFactsLoadExecute.sql was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_FACTS_YEAR_DROP}" ]]; then
  __loge "ERROR: File Staging-initialFactsLoadDrop.sql was not found."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_FACTS_UNIFY}" ]]; then
  __loge "ERROR: File Staging-unify.sql was not found."
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
 if [[ "${MAX_THREADS}" -gt 1 ]]; then
  MAX_THREADS=$((MAX_THREADS-1))
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

  while [[ "${YEAR}" -ge "${MIN_YEAR}" ]]; do
   __waitForJobs
   (
    __logi "Starting ${YEAR}."
    # Loads the data in the database.
    export YEAR
    # shellcheck disable=SC2016
    psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
     -c "$(envsubst '$YEAR' < "${POSTGRES_FACTS_YEAR_CREATE}" || true)" 2>&1
    # shellcheck disable=SC2016
    psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
     -c "$(envsubst '$YEAR' < "${POSTGRES_FACTS_YEAR_EXECUTE}" || true)" 2>&1

    __logi "Finishing ${YEAR}."
   ) &
   sleep 5 # To insert all days of the year in the dimension.
   YEAR=$((YEAR - 1))
  done
   # Waits until all years are fniished.
  wait

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
      closed_dimension_id_user, dimension_application_creation
      )
     SELECT
      id_note, dimension_id_country, processing_time, action_at, action_comment,
      action_dimension_id_date, action_dimension_id_hour_of_week,
      action_dimension_id_user, opened_dimension_id_date,
      opened_dimension_id_hour_of_week, opened_dimension_id_user,
      closed_dimension_id_date, closed_dimension_id_hour_of_week,
      closed_dimension_id_user, dimension_application_creation
     FROM staging.facts_${YEAR}
    "
   echo "${STMT}" | psql -d "${DBNAME}" -v ON_ERROR_STOP=1 2>&1
   # Updates the sequence.
   STMT="SELECT SETVAL((SELECT PG_GET_SERIAL_SEQUENCE('dwh.facts', 'fact_id')),
    (SELECT (MAX(fact_id) + 1) FROM dwh.facts), FALSE)"
   echo "${STMT}" | psql -d "${DBNAME}" -v ON_ERROR_STOP=1 2>&1
   export YEAR
   # shellcheck disable=SC2016
   psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
    -c "$(envsubst '$YEAR' < "${POSTGRES_FACTS_YEAR_DROP}" || true)" 2>&1

   YEAR=$((YEAR + 1))
  done

  # Unifies the facts, by computing dates between years.
  psql -d "${DBNAME}" -f "${POSTGRES_FACTS_UNIFY}" 2>&1

 __log_finish
}

# Creates base tables that hold the whole history.
function __createBaseTables {
 __log_start
 __logi "Droping any ETL object if any exist"
 psql -d "${DBNAME}" -f "${DROP_OBJECTS_FILE}" 2>&1

 __logi "Creating tables for star model if they do not exist."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${CREATE_OBJECTS_FILE}" 2>&1
 __logi "Regions for countries."
 psql -d "${DBNAME}" -f "${REGIONS_FILE}" 2>&1
 __logi "Adding relation, indexes AND triggers."
 psql -d "${DBNAME}" -f "${ADD_OBJECTS_FILE}" 2>&1

 __logi "Creating staging objects."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${CREATE_STAGING_OBJS_FILE}" 2>&1

 __logi "Initial dimension population."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POPULATE_DIMENSIONS_FILE}" 2>&1

 __logi "Initial user dimension population."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${UDPATE_DIMENSIONS_FILE}" 2>&1

 echo "INSERT INTO dwh.properties VALUES ('initial load', 'true')" | \
   psql -d "${DBNAME}" -v ON_ERROR_STOP=1 2>&1

 __initialFacts

 __log_finish
}

# Checks the base tables if exist.
function __checkBaseTables {
 __log_start
 set +e
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${CHECK_BASE_TABLES_FILE}" 2>&1
 RET=${?}
 set -e
 if [[ "${RET}" -ne 0 ]]; then
  __createBaseTables
 fi
 __log_finish
}

# Processes the notes and comments.
function __processNotesETL {
 __log_start
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${UDPATE_DIMENSIONS_FILE}" 2>&1

 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${LOAD_NOTES_STAGING_FILE}" 2>&1
 __log_finish
}

######
# MAIN

function main() {
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
