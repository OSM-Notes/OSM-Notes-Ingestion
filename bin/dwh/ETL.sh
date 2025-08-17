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
# Version: 2025-08-17
VERSION="2025-08-17"

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
SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." \
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
LOCK="${TMP_DIR}/${BASENAME}.lock"
readonly LOCK

# Type of process to run in the script.
if [[ -z "${PROCESS_TYPE:-}" ]]; then
 declare -r PROCESS_TYPE=${1:-}
fi

# Load common functions
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/bin/commonFunctions.sh"

# Load validation functions
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/bin/validationFunctions.sh"

# Load error handling functions
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/bin/errorHandlingFunctions.sh"

# Initialize logger
__start_logger

# PostgreSQL SQL script files.
# Check base tables.
declare -r POSTGRES_11_CHECK_DWH_BASE_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_11_checkDWHTables.sql"
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

###########
# FUNCTIONS

# ETL Configuration file.
declare -r ETL_CONFIG_FILE="${SCRIPT_BASE_DIRECTORY}/etc/etl.properties"

# ETL Recovery and monitoring variables.
declare ETL_START_TIME
declare ETL_CURRENT_STEP=""

# Load ETL configuration if available.
if [[ -f "${ETL_CONFIG_FILE}" ]]; then
 # shellcheck disable=SC1090
 source "${ETL_CONFIG_FILE}"
 __logi "Loaded ETL configuration from ${ETL_CONFIG_FILE}"
else
 __logw "ETL configuration file not found, using defaults"
fi

# Set default values for ETL configuration if not defined.
declare -r ETL_BATCH_SIZE="${ETL_BATCH_SIZE:-1000}"
declare -r ETL_COMMIT_INTERVAL="${ETL_COMMIT_INTERVAL:-100}"
declare -r ETL_VACUUM_AFTER_LOAD="${ETL_VACUUM_AFTER_LOAD:-true}"
declare -r ETL_ANALYZE_AFTER_LOAD="${ETL_ANALYZE_AFTER_LOAD:-true}"
declare -r MAX_MEMORY_USAGE="${MAX_MEMORY_USAGE:-80}"
declare -r MAX_DISK_USAGE="${MAX_DISK_USAGE:-90}"
declare -r ETL_TIMEOUT="${ETL_TIMEOUT:-7200}"
declare -r ETL_RECOVERY_ENABLED="${ETL_RECOVERY_ENABLED:-true}"
declare -r ETL_RECOVERY_FILE="${ETL_RECOVERY_FILE:-${TMP_DIR}/ETL_recovery.json}"
declare -r ETL_VALIDATE_INTEGRITY="${ETL_VALIDATE_INTEGRITY:-true}"
declare -r ETL_VALIDATE_DIMENSIONS="${ETL_VALIDATE_DIMENSIONS:-true}"
declare -r ETL_VALIDATE_FACTS="${ETL_VALIDATE_FACTS:-true}"
declare -r ETL_PARALLEL_ENABLED="${ETL_PARALLEL_ENABLED:-true}"
declare -r ETL_MAX_PARALLEL_JOBS="${ETL_MAX_PARALLEL_JOBS:-4}"
declare -r ETL_MONITOR_RESOURCES="${ETL_MONITOR_RESOURCES:-true}"
declare -r ETL_MONITOR_INTERVAL="${ETL_MONITOR_INTERVAL:-30}"

# Set default value for CLEAN if not defined
declare CLEAN="${CLEAN:-true}"

# Shows the help information.
function __show_help {
 echo "${0} version ${VERSION}"
 echo "This is the ETL process that extracts the values from transactional"
 echo "tables and then inserts them into the facts and dimensions tables."
 echo
 echo "Usage:"
 echo "  ${0} [OPTIONS]"
 echo
 echo "Options:"
 echo "  --create          Create initial data warehouse"
 echo "  --incremental     Run incremental update only"
 echo "  --validate        Validate data integrity only"
 echo "  --resume          Resume from last successful step"
 echo "  --dry-run         Show what would be executed"
 echo "  --help, -h        Show this help"
 echo
 echo "Environment variables:"
 echo "  ETL_BATCH_SIZE       Records per batch (default: 1000)"
 echo "  ETL_COMMIT_INTERVAL  Commit every N records (default: 100)"
 echo "  CLEAN                Clean temporary files (default: true)"
 echo "  LOG_LEVEL            Logging level (default: ERROR)"
 echo
 echo "Written by: Andres Gomez (AngocA)"
 echo "OSM-LatAm, OSM-Colombia, MaptimeBogota."
 exit "${ERROR_HELP_MESSAGE}"
}

# Saves the current progress for recovery.
function __save_progress {
 __log_start
 local STEP_NAME="${1}"
 local STATUS="${2}"
 local TIMESTAMP
 TIMESTAMP=$(date +%s)

 if [[ "${ETL_RECOVERY_ENABLED}" == "true" ]]; then
  local RECOVERY_FILE="${ETL_RECOVERY_FILE:-${TMP_DIR}/ETL_recovery.json}"
  cat > "${RECOVERY_FILE}" << EOF
{
    "last_step": "${STEP_NAME}",
    "status": "${STATUS}",
    "timestamp": "${TIMESTAMP}",
    "etl_start_time": "${ETL_START_TIME}"
}
EOF
  __logd "Progress saved: ${STEP_NAME} - ${STATUS}"
 fi
 __log_finish
}

# Resumes from the last successful step.
function __resume_from_last_step {
 __log_start
 if [[ "${ETL_RECOVERY_ENABLED}" != "true" ]]; then
  __logi "Recovery disabled, skipping resume"
  __log_finish
  return 0
 fi

 local RECOVERY_FILE="${ETL_RECOVERY_FILE:-${TMP_DIR}/ETL_recovery.json}"
 if [[ -f "${RECOVERY_FILE}" ]]; then
  if command -v jq &> /dev/null; then
   local LAST_STEP
   local STATUS
   LAST_STEP=$(jq -r '.last_step' "${RECOVERY_FILE}" 2> /dev/null)
   STATUS=$(jq -r '.status' "${RECOVERY_FILE}" 2> /dev/null)

   if [[ "${STATUS}" == "completed" ]] && [[ -n "${LAST_STEP}" ]]; then
    __logi "Resuming from step after: ${LAST_STEP}"
    __log_finish
    return 0
   else
    __logw "Last execution failed at step: ${LAST_STEP}"
    __log_finish
    return 1
   fi
  else
   __logw "jq not available, cannot parse recovery file"
   __log_finish
   return 1
  fi
 fi
 __log_finish
 return 0
}

# Validates data integrity of the data warehouse.
function __validate_data_integrity {
 __log_start

 if [[ "${ETL_VALIDATE_INTEGRITY}" != "true" ]]; then
  __logi "Data integrity validation disabled"
  __log_finish
  return 0
 fi

 __logi "Starting data integrity validation"

 # Validate dimensions have data
 if [[ "${ETL_VALIDATE_DIMENSIONS}" == "true" ]]; then
  __logi "Validating dimensions..."

  local DIMENSION_COUNTS
  if ! DIMENSION_COUNTS=$(psql -d "${DBNAME}" -t -A -c "
   SELECT 
    'dimension_users' as table_name, COUNT(*) as count FROM dwh.dimension_users
   UNION ALL
   SELECT 'dimension_countries', COUNT(*) FROM dwh.dimension_countries
   UNION ALL
   SELECT 'dimension_days', COUNT(*) FROM dwh.dimension_days
   UNION ALL
  SELECT 'dimension_time_of_week', COUNT(*) FROM dwh.dimension_time_of_week
   UNION ALL
   SELECT 'dimension_applications', COUNT(*) FROM dwh.dimension_applications
   UNION ALL
   SELECT 'dimension_hashtags', COUNT(*) FROM dwh.dimension_hashtags
  " 2> /dev/null); then
   __loge "ERROR: Failed to validate dimensions"
   __log_finish
   return 1
  fi

  echo "${DIMENSION_COUNTS}" | while IFS='|' read -r table count; do
   if [[ "${count}" -eq 0 ]]; then
    __loge "ERROR: Table ${table} is empty"
    __log_finish
    return 1
   fi
   __logi "Table ${table}: ${count} records"
  done
 fi

 # Validate facts have valid references
 if [[ "${ETL_VALIDATE_FACTS}" == "true" ]]; then
  __logi "Validating fact table references..."

  local ORPHANED_FACTS
  if ! ORPHANED_FACTS=$(psql -d "${DBNAME}" -t -A -c "
   SELECT COUNT(*) FROM dwh.facts f
   LEFT JOIN dwh.dimension_countries c ON f.dimension_id_country = c.dimension_country_id
   WHERE c.dimension_country_id IS NULL
  " 2> /dev/null); then
   __loge "ERROR: Failed to validate fact references"
   __log_finish
   return 1
  fi

  if [[ "${ORPHANED_FACTS}" -gt 0 ]]; then
   __loge "ERROR: Found ${ORPHANED_FACTS} facts with invalid country references"
   __log_finish
   return 1
  fi

  __logi "Fact table references validation passed"
 fi

 __logi "Data integrity validation completed successfully"
 __log_finish
}

# Monitors system resources during execution.
function __monitor_resources {
 __log_start
 if [[ "${ETL_MONITOR_RESOURCES}" != "true" ]]; then
  __log_finish
  return 0
 fi

 local MEMORY_USAGE
 local DISK_USAGE
 MEMORY_USAGE=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
 DISK_USAGE=$(df /tmp | tail -1 | awk '{print $5}' | sed 's/%//')

 if [[ "${MEMORY_USAGE}" -gt "${MAX_MEMORY_USAGE}" ]]; then
  __logw "High memory usage: ${MEMORY_USAGE}%"
  sleep "${ETL_MONITOR_INTERVAL}"
 fi

 if [[ "${DISK_USAGE}" -gt "${MAX_DISK_USAGE}" ]]; then
  __loge "ERROR: High disk usage: ${DISK_USAGE}%"
  __log_finish
  return 1
 fi
 __log_finish
}

# Checks if ETL execution has exceeded timeout.
function __check_timeout {
 __log_start
 local CURRENT_TIME
 CURRENT_TIME=$(date +%s)
 local ELAPSED_TIME=$((CURRENT_TIME - ETL_START_TIME))

 if [[ ${ELAPSED_TIME} -gt ${ETL_TIMEOUT} ]]; then
  __loge "ERROR: ETL timeout reached (${ETL_TIMEOUT}s)"
  __log_finish
  return 1
 fi
 __log_finish
}

# Checks prerequisites to run the script.
function __checkPrereqs {
 __log_start
 __logi "=== STARTING ETL PREREQUISITES CHECK ==="
 if [[ "${PROCESS_TYPE}" != "" ]] && [[ "${PROCESS_TYPE}" != "--create" ]] \
  && [[ "${PROCESS_TYPE}" != "--incremental" ]] \
  && [[ "${PROCESS_TYPE}" != "--validate" ]] \
  && [[ "${PROCESS_TYPE}" != "--resume" ]] \
  && [[ "${PROCESS_TYPE}" != "--dry-run" ]] \
  && [[ "${PROCESS_TYPE}" != "--help" ]] \
  && [[ "${PROCESS_TYPE}" != "-h" ]]; then
  echo "ERROR: Invalid parameter. It should be:"
  echo " * Empty string, nothing."
  echo " * --create"
  echo " * --incremental"
  echo " * --validate"
  echo " * --resume"
  echo " * --dry-run"
  echo " * --help"
  exit "${ERROR_INVALID_ARGUMENT}"
 fi
 set +e
 # Checks prereqs.
 __checkPrereqsCommands

 ## Validate SQL script files using centralized validation
 __logi "Validating SQL script files..."

 # Create array of SQL files to validate
 local SQL_FILES=(
  "${POSTGRES_11_CHECK_DWH_BASE_TABLES}"
  "${POSTGRES_12_DROP_DATAMART_OBJECTS}"
  "${POSTGRES_13_DROP_DWH_OBJECTS}"
  "${POSTGRES_22_CREATE_DWH_TABLES}"
  "${POSTGRES_23_GET_WORLD_REGIONS}"
  "${POSTGRES_24_ADD_FUNCTIONS}"
  "${POSTGRES_25_POPULATE_DIMENSIONS}"
  "${POSTGRES_26_UPDATE_DIMENSIONS}"
  "${POSTGRES_31_CREATE_BASE_STAGING_OBJECTS}"
  "${POSTGRES_32_CREATE_STAGING_OBJECTS}"
  "${POSTGRES_33_CREATE_FACTS_BASE_OBJECTS}"
  "${POSTGRES_34_CREATE_FACTS_YEAR_LOAD}"
  "${POSTGRES_35_EXECUTE_FACTS_YEAR_LOAD}"
  "${POSTGRES_36_DROP_FACTS_YEAR_LOAD}"
  "${POSTGRES_41_ADD_CONSTRAINTS_INDEXES_TRIGGERS}"
  "${POSTGRES_51_UNIFY_FACTS}"
  "${POSTGRES_61_LOAD_NOTES_STAGING}"
 )

 # Validate each SQL file
 for SQL_FILE in "${SQL_FILES[@]}"; do
  if ! __validate_sql_structure "${SQL_FILE}"; then
   __loge "ERROR: SQL file validation failed: ${SQL_FILE}"
   exit "${ERROR_MISSING_LIBRARY}"
  fi
 done

 ## Validate configuration file if it exists
 if [[ -f "${ETL_CONFIG_FILE}" ]]; then
  __logi "Validating ETL configuration file..."
  if ! __validate_config_file "${ETL_CONFIG_FILE}"; then
   __loge "ERROR: ETL configuration file validation failed: ${ETL_CONFIG_FILE}"
   exit "${ERROR_MISSING_LIBRARY}"
  fi
 fi

 __logi "=== ETL PREREQUISITES CHECK COMPLETED SUCCESSFULLY ==="
 set -e
 __log_finish
}

# Improved wait for jobs with resource monitoring.
function __waitForJobs {
 __log_start

 # Uses n-1 cores, if number of cores is greater than 1.
 # This prevents monopolization of the CPUs.
 local AVAILABLE_THREADS
 if [[ "${MAX_THREADS}" -gt 6 ]]; then
  AVAILABLE_THREADS=$((MAX_THREADS - 2))
 elif [[ "${MAX_THREADS}" -gt 1 ]]; then
  AVAILABLE_THREADS=$((MAX_THREADS - 1))
 else
  AVAILABLE_THREADS=1
 fi

 local CURRENT_JOBS
 CURRENT_JOBS=$(jobs -p | wc -l)
 __logd "Current jobs: ${CURRENT_JOBS}, Available threads: ${AVAILABLE_THREADS}"

 while [[ "${CURRENT_JOBS}" -ge ${AVAILABLE_THREADS} ]]; do
  __logi "Waiting for job completion... (${CURRENT_JOBS}/${AVAILABLE_THREADS})"
  wait -n
  CURRENT_JOBS=$(jobs -p | wc -l)

  # Monitor resources while waiting
  __monitor_resources
  __check_timeout
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
 __logi "=== CREATING BASE TABLES ==="
 __logi "Dropping any ETL object if any exist."
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

 __logi "=== BASE TABLES CREATED SUCCESSFULLY ==="
 __log_finish
}

# Checks the base tables if exist.
function __checkBaseTables {
 __log_start
 __logi "=== CHECKING BASE TABLES ==="
 set +e
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_11_CHECK_DWH_BASE_TABLES}" 2>&1
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

 __logi "=== BASE TABLES CHECK COMPLETED ==="
 __log_finish
}

# Processes the notes and comments.
function __processNotesETL {
 __log_start
 __logi "=== PROCESSING NOTES ETL ==="
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_26_UPDATE_DIMENSIONS}" 2>&1

 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_61_LOAD_NOTES_STAGING}" 2>&1
 __logi "=== NOTES ETL PROCESSING COMPLETED ==="
 __log_finish
}

# Performs database maintenance after data load.
function __perform_database_maintenance {
 __log_start
 __logi "=== PERFORMING DATABASE MAINTENANCE ==="

 if [[ "${ETL_VACUUM_AFTER_LOAD}" == "true" ]]; then
  __logi "Running VACUUM ANALYZE on fact table"
  psql -d "${DBNAME}" -c "VACUUM ANALYZE dwh.facts;" 2>&1
 fi

 if [[ "${ETL_ANALYZE_AFTER_LOAD}" == "true" ]]; then
  __logi "Running ANALYZE on dimension tables"
  psql -d "${DBNAME}" -c "ANALYZE dwh.dimension_users;" 2>&1
  psql -d "${DBNAME}" -c "ANALYZE dwh.dimension_countries;" 2>&1
  psql -d "${DBNAME}" -c "ANALYZE dwh.dimension_days;" 2>&1
  psql -d "${DBNAME}" -c "ANALYZE dwh.dimension_time_of_week;" 2>&1
  psql -d "${DBNAME}" -c "ANALYZE dwh.dimension_applications;" 2>&1
  psql -d "${DBNAME}" -c "ANALYZE dwh.dimension_applications;" 2>&1
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
 ETL_START_TIME=$(date +%s)
 __logi "Preparing environment."
 __logd "Output saved at: ${TMP_DIR}."
 __logi "Processing: ${PROCESS_TYPE}."

 if [[ "${PROCESS_TYPE}" == "-h" ]] || [[ "${PROCESS_TYPE}" == "--help" ]]; then
  __show_help
 fi

 # Handle dry-run mode
 if [[ "${PROCESS_TYPE}" == "--dry-run" ]]; then
  __logi "DRY RUN MODE - No actual changes will be made"
  __logi "Configuration:"
  __logi "  - ETL_BATCH_SIZE: ${ETL_BATCH_SIZE}"
  __logi "  - ETL_COMMIT_INTERVAL: ${ETL_COMMIT_INTERVAL}"
  __logi "  - ETL_RECOVERY_ENABLED: ${ETL_RECOVERY_ENABLED}"
  __logi "  - ETL_VALIDATE_INTEGRITY: ${ETL_VALIDATE_INTEGRITY}"
  __logi "  - ETL_PARALLEL_ENABLED: ${ETL_PARALLEL_ENABLED}"
  __logi "  - MAX_THREADS: ${MAX_THREADS}"
  __logi "  - DBNAME: ${DBNAME}"
  __logi ""
  __logi "Would execute the following steps:"
  __logi "1. Check prerequisites (files, database connection)"
  __logi "2. Validate data integrity (dimensions and facts)"
  __logi "3. Process notes ETL (load and transform data)"
  __logi "4. Perform database maintenance (VACUUM, ANALYZE)"
  __logi "5. Update datamarts (countries and users)"
  __logi "6. Final validation (data quality checks)"
  __logi ""
  __logi "Files that would be processed:"
  __logi "  - SQL scripts: Multiple ETL and staging scripts"
  __logi "  - Datamart scripts: ${DATAMART_COUNTRIES_SCRIPT}, ${DATAMART_USERS_SCRIPT}"
  __logi "  - Recovery file: ${ETL_RECOVERY_FILE}"
  __logi "  - Log file: ${LOG_FILENAME}"
  __log_finish
  return 0
 fi

 # Handle validate-only mode
 if [[ "${PROCESS_TYPE}" == "--validate" ]]; then
  __logi "VALIDATION MODE - Only validating data integrity"
  __trapOn
  exec 7> "${LOCK}"
  __logw "Validating single execution."
  flock -n 7
  __checkPrereqs
  __validate_data_integrity
  __logw "Validation completed."
  __log_finish
  return 0
 fi

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

 __checkPrereqs

 # Handle resume mode
 if [[ "${PROCESS_TYPE}" == "--resume" ]]; then
  __logi "RESUME MODE - Attempting to resume from last successful step"
  local RESUME_RESULT
  __resume_from_last_step
  RESUME_RESULT=$?
  if [[ ${RESUME_RESULT} -ne 0 ]]; then
   __loge "ERROR: Cannot resume from last step, starting fresh"
  fi
 fi

 # Handle incremental mode
 if [[ "${PROCESS_TYPE}" == "--incremental" ]]; then
  __logi "INCREMENTAL MODE - Processing only new data"
  ETL_CURRENT_STEP="incremental_update"
  __save_progress "${ETL_CURRENT_STEP}" "started"

  set +E
  __checkBaseTables
  set -E

  __processNotesETL
  __save_progress "${ETL_CURRENT_STEP}" "completed"

  # Perform database maintenance
  ETL_CURRENT_STEP="database_maintenance"
  __save_progress "${ETL_CURRENT_STEP}" "started"
  __perform_database_maintenance
  __save_progress "${ETL_CURRENT_STEP}" "completed"

  # Updates the datamart for countries.
  ETL_CURRENT_STEP="update_datamart_countries"
  __save_progress "${ETL_CURRENT_STEP}" "started"
  "${DATAMART_COUNTRIES_SCRIPT}"
  __save_progress "${ETL_CURRENT_STEP}" "completed"

  # Updates the datamart for users.
  ETL_CURRENT_STEP="update_datamart_users"
  __save_progress "${ETL_CURRENT_STEP}" "started"
  "${DATAMART_USERS_SCRIPT}"
  __save_progress "${ETL_CURRENT_STEP}" "completed"

  ETL_CURRENT_STEP="final_validation"
  __save_progress "${ETL_CURRENT_STEP}" "started"
  __validate_data_integrity
  __save_progress "${ETL_CURRENT_STEP}" "completed"
 fi

 # Handle create mode or default mode
 if [[ "${PROCESS_TYPE}" == "--create" ]] || [[ "${PROCESS_TYPE}" == "" ]]; then
  __logi "CREATE MODE - Creating or updating data warehouse"

  ETL_CURRENT_STEP="check_base_tables"
  __save_progress "${ETL_CURRENT_STEP}" "started"
  set +E
  __checkBaseTables
  set -E
  __save_progress "${ETL_CURRENT_STEP}" "completed"

  ETL_CURRENT_STEP="process_notes_etl"
  __save_progress "${ETL_CURRENT_STEP}" "started"
  __processNotesETL
  __save_progress "${ETL_CURRENT_STEP}" "completed"

  # Perform database maintenance
  ETL_CURRENT_STEP="database_maintenance"
  __save_progress "${ETL_CURRENT_STEP}" "started"
  __perform_database_maintenance
  __save_progress "${ETL_CURRENT_STEP}" "completed"

  # Updates the datamart for countries.
  ETL_CURRENT_STEP="update_datamart_countries"
  __save_progress "${ETL_CURRENT_STEP}" "started"
  "${DATAMART_COUNTRIES_SCRIPT}"
  __save_progress "${ETL_CURRENT_STEP}" "completed"

  # Updates the datamart for users.
  ETL_CURRENT_STEP="update_datamart_users"
  __save_progress "${ETL_CURRENT_STEP}" "started"
  "${DATAMART_USERS_SCRIPT}"
  __save_progress "${ETL_CURRENT_STEP}" "completed"

  ETL_CURRENT_STEP="final_validation"
  __save_progress "${ETL_CURRENT_STEP}" "started"
  __validate_data_integrity
  __save_progress "${ETL_CURRENT_STEP}" "completed"
 fi

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
   mv "${LOG_FILENAME}" "/tmp/${BASENAME}_$(date +%Y-%m-%d_%H-%M-%S || true).log"
   rmdir "${TMP_DIR}"
  fi
 else
  main
 fi
fi
