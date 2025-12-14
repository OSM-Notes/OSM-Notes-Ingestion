#!/bin/bash

# Comprehensive cleanup script for OSM-Notes-profile
# This script removes all components from the database
# Can be used for full cleanup or partition-only cleanup
#
# This is the list of error codes:
# 1) Help message displayed
# 241) Library or utility missing
# 242) Invalid argument
# 255) General error
#
# Author: Andres Gomez (AngocA)
# Version: 2025-12-13
VERSION="2025-12-13"

set -euo pipefail
# shellcheck disable=SC2310,SC2312

# Define required variables
BASENAME="cleanupAll"
# Set PostgreSQL application name for monitoring
# This allows monitoring tools to identify which script is using the database
export PGAPPNAME="${BASENAME}"

TMP_DIR="/tmp/${BASENAME}_$$"
mkdir -p "${TMP_DIR}"

# Lock file for single execution
if [[ -z "${LOCK:-}" ]]; then
 declare -r LOCK="/tmp/${BASENAME}.lock"
fi

# Flag to track if the script should exit
EXIT_REQUESTED=0

# Define script base directory
SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load common functions (includes logging)
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/commonFunctions.sh"

# Load global properties
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh"

# Load validation functions
if [[ -f "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/validationFunctions.sh" ]]; then
 # shellcheck source=validationFunctions.sh
 source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/validationFunctions.sh"
else
 __loge "ERROR: validationFunctions.sh not found"
 exit "${ERROR_MISSING_LIBRARY}"
fi

# Start logger only if not being sourced for testing
if [[ "${SKIP_MAIN:-}" != "true" ]]; then
 __logi "Starting cleanupAll.sh script"
fi

# Function to check if database exists
function __check_database() {
 __log_start
 local TARGET_DB="${1:-}"

 # Use provided database name or from properties
 if [[ -z "${TARGET_DB}" ]]; then
  if [[ -z "${DBNAME:-}" ]]; then
   __loge "Database name not provided and DBNAME not set in properties"
   __loge "Please set DBNAME in etc/properties.sh or pass database name as parameter"
   __log_finish
   return 1
  fi
  TARGET_DB="${DBNAME}"
 fi

 __logi "Checking if database exists: ${TARGET_DB}"

 # Check if database exists by attempting to connect to it
 # If connection succeeds, database exists
 set +e
 if psql -d "${TARGET_DB}" -c "SELECT 1;" > /dev/null 2>&1; then
  __logi "Database ${TARGET_DB} exists"
  __log_finish
  return 0
 else
  __loge "Database ${TARGET_DB} does not exist"
  __log_finish
  return 1
 fi
}

# Function to execute SQL script with validation
function __execute_sql_script() {
 __log_start
 local TARGET_DB="${1}"
 local SCRIPT_PATH="${2}"
 local SCRIPT_NAME="${3}"

 if [[ ${EXIT_REQUESTED} -eq 1 ]]; then
  __loge "Cleanup was interrupted, skipping: ${SCRIPT_NAME}"
  __log_finish
  return 1
 fi

 __logi "Executing ${SCRIPT_NAME}: ${SCRIPT_PATH}"

 # Validate SQL script using centralized validation
 local VALIDATE_SQL_STATUS=0
 __validate_sql_structure "${SCRIPT_PATH}"
 VALIDATE_SQL_STATUS=$?
 if [[ ${VALIDATE_SQL_STATUS} -ne 0 ]]; then
  __loge "ERROR: SQL script validation failed: ${SCRIPT_PATH}"
  __log_finish
  return 1
 fi

 # Use peer authentication (no host, port, or password needed)
 local PSQL_CMD="psql"
 if [[ -n "${DB_USER:-}" ]]; then
  PSQL_CMD="${PSQL_CMD} -U ${DB_USER}"
 fi

 if ${PSQL_CMD} -d "${TARGET_DB}" -f "${SCRIPT_PATH}"; then
  __logi "SUCCESS: ${SCRIPT_NAME} completed"
  __log_finish
  return 0
 else
  __loge "FAILED: ${SCRIPT_NAME} failed"
  __log_finish
  return 1
 fi
}

# Function to list existing partition tables
function __list_partition_tables() {
 __log_start
 local TARGET_DB="${1}"

 __logi "Listing existing partition tables in database: ${TARGET_DB}"

 # Use peer authentication (no host, port, or password needed)
 local PSQL_CMD="psql"
 if [[ -n "${DB_USER:-}" ]]; then
  PSQL_CMD="${PSQL_CMD} -U ${DB_USER}"
 fi

 ${PSQL_CMD} -d "${TARGET_DB}" -c "
 SELECT table_name, COUNT(*) as count
 FROM information_schema.tables 
 WHERE table_name LIKE '%_part_%' 
 GROUP BY table_name 
 ORDER BY table_name;
 "
 __log_finish
}

# Function to drop all partition tables
function __drop_all_partitions() {
 __log_start
 local TARGET_DB="${1}"
 local DROP_SCRIPT="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_11_dropAllPartitions.sql"

 __logi "Dropping all partition tables using script: ${DROP_SCRIPT}"

 # Validate SQL script using centralized validation
 local VALIDATE_DROP_STATUS=0
 __validate_sql_structure "${DROP_SCRIPT}"
 VALIDATE_DROP_STATUS=$?
 if [[ ${VALIDATE_DROP_STATUS} -ne 0 ]]; then
  __loge "ERROR: Drop script validation failed: ${DROP_SCRIPT}"
  __log_finish
  return 1
 fi

 # Use peer authentication (no host, port, or password needed)
 local PSQL_CMD="psql"
 if [[ -n "${DB_USER:-}" ]]; then
  PSQL_CMD="${PSQL_CMD} -U ${DB_USER}"
 fi

 if ${PSQL_CMD} -d "${TARGET_DB}" -f "${DROP_SCRIPT}"; then
  __logi "SUCCESS: Partition tables dropped"
  __log_finish
  return 0
 else
  __loge "FAILED: Partition tables drop failed"
  __log_start
  return 1
 fi
}

# Function to verify partition cleanup
function __verify_partition_cleanup() {
 __log_start
 local TARGET_DB="${1}"

 __logi "Verifying that all partition tables have been removed"

 # Use peer authentication (no host, port, or password needed)
 local PSQL_CMD="psql"
 if [[ -n "${DB_USER:-}" ]]; then
  PSQL_CMD="${PSQL_CMD} -U ${DB_USER}"
 fi

 local REMAINING_COUNT
 REMAINING_COUNT=$(${PSQL_CMD} -d "${TARGET_DB}" -t -c "
 SELECT COUNT(*) 
 FROM information_schema.tables 
 WHERE table_name LIKE '%_part_%';
 " | tr -d ' ')

 if [[ "${REMAINING_COUNT}" -eq 0 ]]; then
  __logi "SUCCESS: All partition tables have been removed"
  __log_finish
  return 0
 else
  __logw "WARNING: ${REMAINING_COUNT} partition tables still exist"
  ${PSQL_CMD} -d "${TARGET_DB}" -c "
  SELECT table_name 
  FROM information_schema.tables 
  WHERE table_name LIKE '%_part_%' 
  ORDER BY table_name;
  "
  __log_finish
  return 1
 fi
}

# Function to cleanup only partition tables
function __cleanup_partitions_only() {
 __log_start
 local TARGET_DB="${1}"

 __logi "Starting partition tables cleanup for database: ${TARGET_DB}"

 # Step 1: Check if database exists
 local CHECK_DATABASE_STATUS=0
 __check_database "${TARGET_DB}"
 CHECK_DATABASE_STATUS=$?
 if [[ ${CHECK_DATABASE_STATUS} -ne 0 ]]; then
  __loge "Database ${TARGET_DB} does not exist. Cannot proceed with partition cleanup."
  __log_finish
  return 1
 fi

 # Step 2: List existing partition tables
 __logi "Step 1: Listing existing partition tables"
 __list_partition_tables "${TARGET_DB}"

 # Step 3: Drop all partition tables
 __logi "Step 2: Dropping all partition tables"
 local DROP_PARTITIONS_STATUS=0
 __drop_all_partitions "${TARGET_DB}"
 DROP_PARTITIONS_STATUS=$?
 if [[ ${DROP_PARTITIONS_STATUS} -ne 0 ]]; then
  __loge "Failed to drop partition tables"
  __log_finish
  return 1
 fi

 # Step 4: Verify cleanup
 __logi "Step 3: Verifying cleanup"
 local VERIFY_PARTITIONS_STATUS=0
 __verify_partition_cleanup "${TARGET_DB}"
 VERIFY_PARTITIONS_STATUS=$?
 if [[ ${VERIFY_PARTITIONS_STATUS} -ne 0 ]]; then
  __logw "Some partition tables may still exist"
  __log_finish
  return 1
 fi

 __logi "Partition tables cleanup completed successfully"
 __log_finish
}

# Function to cleanup WMS components
function __cleanup_wms() {
 __log_start
 local TARGET_DB="${1}"

 __logi "Cleaning up WMS components"

 local WMS_SCRIPT="${SCRIPT_BASE_DIRECTORY}/sql/wms/removeFromDatabase.sql"
 if [[ ! -f "${WMS_SCRIPT}" ]]; then
  __logw "WMS cleanup script not found: ${WMS_SCRIPT}"
  __logw "Skipping WMS cleanup (script not found)"
  __log_finish
  return 0
 fi

 local EXECUTE_WMS_STATUS=0
 __execute_sql_script "${TARGET_DB}" "${WMS_SCRIPT}" "WMS Components"
 EXECUTE_WMS_STATUS=$?
 if [[ ${EXECUTE_WMS_STATUS} -ne 0 ]]; then
  __loge "Failed to execute WMS cleanup script"
  __log_finish
  return 1
 fi

 # Verify WMS schema was dropped
 local PSQL_CMD="psql"
 if [[ -n "${DB_USER:-}" ]]; then
  PSQL_CMD="${PSQL_CMD} -U ${DB_USER}"
 fi

 local WMS_EXISTS
 WMS_EXISTS=$(${PSQL_CMD} -d "${TARGET_DB}" -Atq -c "
  SELECT COUNT(*)
  FROM information_schema.schemata
  WHERE schema_name = 'wms';
 " 2> /dev/null | tr -d ' ' || echo "0")

 if [[ "${WMS_EXISTS}" -ne "0" ]]; then
  __loge "ERROR: WMS schema still exists after cleanup"
  __log_finish
  return 1
 fi

 __logi "SUCCESS: WMS components removed"
 __log_finish
 return 0
}

# Function to cleanup API tables first (to resolve enum dependencies)
function __cleanup_api_tables() {
 __log_start
 local TARGET_DB="${1}"

 __logi "Cleaning up API tables (to resolve enum dependencies)"

 # Drop API tables directly with CASCADE to handle dependencies
 local API_DROP_SQL="
 DROP TABLE IF EXISTS note_comments_api CASCADE;
 DROP TABLE IF EXISTS note_comments_api_part_1 CASCADE;
 DROP TABLE IF EXISTS note_comments_api_part_2 CASCADE;
 DROP TABLE IF EXISTS note_comments_api_part_3 CASCADE;
 DROP TABLE IF EXISTS note_comments_api_part_4 CASCADE;
 DROP TABLE IF EXISTS notes_api CASCADE;
 DROP TABLE IF EXISTS notes_api_part_1 CASCADE;
 DROP TABLE IF EXISTS notes_api_part_2 CASCADE;
 DROP TABLE IF EXISTS notes_api_part_3 CASCADE;
 DROP TABLE IF EXISTS notes_api_part_4 CASCADE;
 "

 # Use peer authentication (no host, port, or password needed)
 local PSQL_CMD="psql"
 if [[ -n "${DB_USER:-}" ]]; then
  PSQL_CMD="${PSQL_CMD} -U ${DB_USER}"
 fi

 if ! ${PSQL_CMD} -d "${TARGET_DB}" -c "${API_DROP_SQL}" 2> /dev/null; then
  __loge "ERROR: Failed to drop API tables"
  __log_finish
  return 1
 fi

 # Verify API tables were dropped
 local REMAINING_API_TABLES
 REMAINING_API_TABLES=$(${PSQL_CMD} -d "${TARGET_DB}" -Atq -c "
  SELECT COUNT(*)
  FROM information_schema.tables
  WHERE table_schema = 'public'
  AND (table_name LIKE 'notes_api%' OR table_name LIKE 'note_comments_api%');
 " 2> /dev/null | tr -d ' ' || echo "0")

 if [[ "${REMAINING_API_TABLES}" -ne "0" ]]; then
  __loge "ERROR: ${REMAINING_API_TABLES} API table(s) still exist after cleanup"
  __log_finish
  return 1
 fi

 __logi "SUCCESS: API tables dropped"
 __log_finish
 return 0
}

# Function to get list of all tables in database
function __list_all_tables() {
 __log_start
 local TARGET_DB="${1}"
 local OUTPUT_FILE="${2}"

 local PSQL_CMD="psql"
 if [[ -n "${DB_USER:-}" ]]; then
  PSQL_CMD="${PSQL_CMD} -U ${DB_USER}"
 fi

 # Get all tables in public schema
 ${PSQL_CMD} -d "${TARGET_DB}" -Atq -c "
  SELECT table_name
  FROM information_schema.tables
  WHERE table_schema = 'public'
  ORDER BY table_name;
 " > "${OUTPUT_FILE}" 2> /dev/null || true

 __log_finish
}

# Function to get list of all functions and procedures
function __list_all_functions() {
 __log_start
 local TARGET_DB="${1}"
 local OUTPUT_FILE="${2}"

 local PSQL_CMD="psql"
 if [[ -n "${DB_USER:-}" ]]; then
  PSQL_CMD="${PSQL_CMD} -U ${DB_USER}"
 fi

 # Get all functions and procedures in public schema
 ${PSQL_CMD} -d "${TARGET_DB}" -Atq -c "
  SELECT routine_name || ' (' || routine_type || ')'
  FROM information_schema.routines
  WHERE routine_schema = 'public'
  ORDER BY routine_name;
 " > "${OUTPUT_FILE}" 2> /dev/null || true

 __log_finish
}

# Function to get list of all types
function __list_all_types() {
 __log_start
 local TARGET_DB="${1}"
 local OUTPUT_FILE="${2}"

 local PSQL_CMD="psql"
 if [[ -n "${DB_USER:-}" ]]; then
  PSQL_CMD="${PSQL_CMD} -U ${DB_USER}"
 fi

 # Get all custom types in public schema
 ${PSQL_CMD} -d "${TARGET_DB}" -Atq -c "
  SELECT typname
  FROM pg_type
  WHERE typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
  AND typtype = 'e'
  ORDER BY typname;
 " > "${OUTPUT_FILE}" 2> /dev/null || true

 __log_finish
}

# Function to get list of all schemas (excluding system schemas)
function __list_all_schemas() {
 __log_start
 local TARGET_DB="${1}"
 local OUTPUT_FILE="${2}"

 local PSQL_CMD="psql"
 if [[ -n "${DB_USER:-}" ]]; then
  PSQL_CMD="${PSQL_CMD} -U ${DB_USER}"
 fi

 # Get all non-system schemas
 ${PSQL_CMD} -d "${TARGET_DB}" -Atq -c "
  SELECT schema_name
  FROM information_schema.schemata
  WHERE schema_name NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
  ORDER BY schema_name;
 " > "${OUTPUT_FILE}" 2> /dev/null || true

 __log_finish
}

# Function to generate cleanup summary
function __generate_cleanup_summary() {
 __log_start
 local TARGET_DB="${1}"
 local BEFORE_DIR="${2}"
 local AFTER_DIR="${3}"

 __logi "=========================================="
 __logi "CLEANUP SUMMARY"
 __logi "=========================================="

 # Compare tables
 local BEFORE_TABLES="${BEFORE_DIR}/tables.txt"
 local AFTER_TABLES="${AFTER_DIR}/tables.txt"
 local TABLES_DROPPED=0
 local TABLES_REMAINING=0

 if [[ -f "${BEFORE_TABLES}" ]] && [[ -f "${AFTER_TABLES}" ]]; then
  local DROPPED_TABLES
  DROPPED_TABLES=$(comm -23 "${BEFORE_TABLES}" "${AFTER_TABLES}" 2> /dev/null | wc -l || echo "0")
  DROPPED_TABLES=$(echo "${DROPPED_TABLES}" | tr -d ' ')
  TABLES_DROPPED=$((DROPPED_TABLES))
  TABLES_REMAINING=$(wc -l < "${AFTER_TABLES}" 2> /dev/null | tr -d ' ' || echo "0")
  TABLES_REMAINING=$(echo "${TABLES_REMAINING}" | tr -d ' ')

  __logi "Tables:"
  __logi "  Before cleanup: $(wc -l < "${BEFORE_TABLES}" 2> /dev/null | tr -d ' ' || echo "0")"
  __logi "  Dropped: ${TABLES_DROPPED}"
  __logi "  Remaining: ${TABLES_REMAINING}"

  if [[ ${TABLES_REMAINING} -gt 0 ]]; then
   __logw "Remaining tables:"
   while IFS= read -r table; do
    __logw "  - ${table}"
   done < "${AFTER_TABLES}"
  fi
 fi

 # Compare functions
 local BEFORE_FUNCTIONS="${BEFORE_DIR}/functions.txt"
 local AFTER_FUNCTIONS="${AFTER_DIR}/functions.txt"
 local FUNCTIONS_DROPPED=0
 local FUNCTIONS_REMAINING=0

 if [[ -f "${BEFORE_FUNCTIONS}" ]] && [[ -f "${AFTER_FUNCTIONS}" ]]; then
  local DROPPED_FUNCTIONS
  DROPPED_FUNCTIONS=$(comm -23 "${BEFORE_FUNCTIONS}" "${AFTER_FUNCTIONS}" 2> /dev/null | wc -l || echo "0")
  DROPPED_FUNCTIONS=$(echo "${DROPPED_FUNCTIONS}" | tr -d ' ')
  FUNCTIONS_DROPPED=$((DROPPED_FUNCTIONS))
  FUNCTIONS_REMAINING=$(wc -l < "${AFTER_FUNCTIONS}" 2> /dev/null | tr -d ' ' || echo "0")
  FUNCTIONS_REMAINING=$(echo "${FUNCTIONS_REMAINING}" | tr -d ' ')

  __logi "Functions/Procedures:"
  __logi "  Before cleanup: $(wc -l < "${BEFORE_FUNCTIONS}" 2> /dev/null | tr -d ' ' || echo "0")"
  __logi "  Dropped: ${FUNCTIONS_DROPPED}"
  __logi "  Remaining: ${FUNCTIONS_REMAINING}"

  if [[ ${FUNCTIONS_REMAINING} -gt 0 ]]; then
   __logw "Remaining functions/procedures:"
   while IFS= read -r func; do
    __logw "  - ${func}"
   done < "${AFTER_FUNCTIONS}"
  fi
 fi

 # Compare types
 local BEFORE_TYPES="${BEFORE_DIR}/types.txt"
 local AFTER_TYPES="${AFTER_DIR}/types.txt"
 local TYPES_DROPPED=0
 local TYPES_REMAINING=0

 if [[ -f "${BEFORE_TYPES}" ]] && [[ -f "${AFTER_TYPES}" ]]; then
  local DROPPED_TYPES
  DROPPED_TYPES=$(comm -23 "${BEFORE_TYPES}" "${AFTER_TYPES}" 2> /dev/null | wc -l || echo "0")
  DROPPED_TYPES=$(echo "${DROPPED_TYPES}" | tr -d ' ')
  TYPES_DROPPED=$((DROPPED_TYPES))
  TYPES_REMAINING=$(wc -l < "${AFTER_TYPES}" 2> /dev/null | tr -d ' ' || echo "0")
  TYPES_REMAINING=$(echo "${TYPES_REMAINING}" | tr -d ' ')

  __logi "Types:"
  __logi "  Before cleanup: $(wc -l < "${BEFORE_TYPES}" 2> /dev/null | tr -d ' ' || echo "0")"
  __logi "  Dropped: ${TYPES_DROPPED}"
  __logi "  Remaining: ${TYPES_REMAINING}"

  if [[ ${TYPES_REMAINING} -gt 0 ]]; then
   __logw "Remaining types:"
   while IFS= read -r type; do
    __logw "  - ${type}"
   done < "${AFTER_TYPES}"
  fi
 fi

 # Compare schemas
 local BEFORE_SCHEMAS="${BEFORE_DIR}/schemas.txt"
 local AFTER_SCHEMAS="${AFTER_DIR}/schemas.txt"
 local SCHEMAS_DROPPED=0
 local SCHEMAS_REMAINING=0

 if [[ -f "${BEFORE_SCHEMAS}" ]] && [[ -f "${AFTER_SCHEMAS}" ]]; then
  local DROPPED_SCHEMAS
  DROPPED_SCHEMAS=$(comm -23 "${BEFORE_SCHEMAS}" "${AFTER_SCHEMAS}" 2> /dev/null | wc -l || echo "0")
  DROPPED_SCHEMAS=$(echo "${DROPPED_SCHEMAS}" | tr -d ' ')
  SCHEMAS_DROPPED=$((DROPPED_SCHEMAS))
  SCHEMAS_REMAINING=$(wc -l < "${AFTER_SCHEMAS}" 2> /dev/null | tr -d ' ' || echo "0")
  SCHEMAS_REMAINING=$(echo "${SCHEMAS_REMAINING}" | tr -d ' ')

  __logi "Schemas:"
  __logi "  Before cleanup: $(wc -l < "${BEFORE_SCHEMAS}" 2> /dev/null | tr -d ' ' || echo "0")"
  __logi "  Dropped: ${SCHEMAS_DROPPED}"
  __logi "  Remaining: ${SCHEMAS_REMAINING}"

  if [[ ${SCHEMAS_REMAINING} -gt 0 ]]; then
   __logw "Remaining schemas:"
   while IFS= read -r schema; do
    __logw "  - ${schema}"
   done < "${AFTER_SCHEMAS}"
  fi
 fi

 __logi "=========================================="
 __log_finish
}

# Function to verify cleanup completed successfully
function __verify_cleanup_success() {
 __log_start
 local TARGET_DB="${1}"
 local AFTER_DIR="${2}"
 local VERIFICATION_FAILED=0

 __logi "Verifying cleanup completed successfully..."

 local PSQL_CMD="psql"
 if [[ -n "${DB_USER:-}" ]]; then
  PSQL_CMD="${PSQL_CMD} -U ${DB_USER}"
 fi

 # List of tables that MUST be dropped (critical tables)
 local CRITICAL_TABLES=(
  "notes"
  "note_comments"
  "note_comments_text"
  "notes_api"
  "note_comments_api"
  "notes_sync"
  "note_comments_sync"
  "note_comments_text_sync"
  "countries"
  "users"
  "properties"
  "logs"
  "license"
 )

 local AFTER_TABLES="${AFTER_DIR}/tables.txt"
 if [[ -f "${AFTER_TABLES}" ]]; then
  for CRITICAL_TABLE in "${CRITICAL_TABLES[@]}"; do
   if grep -q "^${CRITICAL_TABLE}$" "${AFTER_TABLES}" 2> /dev/null; then
    __loge "ERROR: Critical table '${CRITICAL_TABLE}' was not dropped"
    VERIFICATION_FAILED=1
   fi
  done
 fi

 # Check if WMS schema still exists
 local WMS_EXISTS
 WMS_EXISTS=$(${PSQL_CMD} -d "${TARGET_DB}" -Atq -c "
  SELECT COUNT(*)
  FROM information_schema.schemata
  WHERE schema_name = 'wms';
 " 2> /dev/null | tr -d ' ' || echo "0")

 if [[ "${WMS_EXISTS}" -ne "0" ]]; then
  __loge "ERROR: WMS schema still exists after cleanup"
  VERIFICATION_FAILED=1
 fi

 # Check for partition tables (only real partition tables, not system tables)
 local PARTITION_COUNT
 PARTITION_COUNT=$(${PSQL_CMD} -d "${TARGET_DB}" -Atq -c "
  SELECT COUNT(*)
  FROM information_schema.tables
  WHERE table_schema = 'public'
  AND table_name LIKE '%_part_%'
  AND (
    table_name LIKE 'notes_sync_part_%'
    OR table_name LIKE 'note_comments_sync_part_%'
    OR table_name LIKE 'note_comments_text_sync_part_%'
    OR table_name LIKE 'notes_api_part_%'
    OR table_name LIKE 'note_comments_api_part_%'
    OR table_name LIKE 'note_comments_text_api_part_%'
  );
 " 2> /dev/null | tr -d ' ' || echo "0")

 if [[ "${PARTITION_COUNT}" -ne "0" ]]; then
  __loge "ERROR: ${PARTITION_COUNT} partition table(s) still exist after cleanup"
  VERIFICATION_FAILED=1
 fi

 if [[ ${VERIFICATION_FAILED} -eq 1 ]]; then
  __loge "Cleanup verification FAILED: Some objects were not properly removed"
  __log_finish
  return 1
 else
  __logi "Cleanup verification PASSED: All critical objects were removed"
  __log_finish
  return 0
 fi
}

# Function to cleanup base components
function __cleanup_base() {
 __log_start
 local TARGET_DB="${1}"

 __logi "Cleaning up base components"

 # First clean up API tables to resolve enum dependencies
 if [[ ${EXIT_REQUESTED} -eq 1 ]]; then
  __loge "Cleanup was interrupted"
  __log_finish
  return 1
 fi
 __cleanup_api_tables "${TARGET_DB}"

 local BASE_SCRIPTS=(
  "${SCRIPT_BASE_DIRECTORY}/sql/monitor/processCheckPlanetNotes_11_dropCheckTables.sql:Check Tables"
  "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_11_dropSyncTables.sql:Sync Tables"
  "${SCRIPT_BASE_DIRECTORY}/sql/consolidated_cleanup.sql:Generic Objects"
  "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_13_dropBaseTables.sql:Base Tables"
 )

 for SCRIPT_INFO in "${BASE_SCRIPTS[@]}"; do
  if [[ ${EXIT_REQUESTED} -eq 1 ]]; then
   __loge "Cleanup was interrupted"
   __log_finish
   return 1
  fi
  IFS=':' read -r SCRIPT_PATH SCRIPT_NAME <<< "${SCRIPT_INFO}"
  if [[ -f "${SCRIPT_PATH}" ]]; then
   local EXECUTE_SQL_STATUS=0
   __execute_sql_script "${TARGET_DB}" "${SCRIPT_PATH}" "${SCRIPT_NAME}"
   EXECUTE_SQL_STATUS=$?
   if [[ ${EXECUTE_SQL_STATUS} -ne 0 ]]; then
    __loge "Failed to execute: ${SCRIPT_NAME}"
    __log_finish
    return 1
   fi
  else
   __logw "Script not found: ${SCRIPT_PATH}"
  fi
 done

 # Drop country tables explicitly (consolidated_cleanup.sql no longer drops them)
 # This is safe during full cleanup as these tables will be recreated by updateCountries.sh
 if [[ ${EXIT_REQUESTED} -eq 1 ]]; then
  __loge "Cleanup was interrupted"
  __log_finish
  return 1
 fi
 local PSQL_CMD="psql"
 if [[ -n "${DB_USER:-}" ]]; then
  PSQL_CMD="${PSQL_CMD} -U ${DB_USER}"
 fi
 __logi "Dropping country tables (countries)..."
 if ! ${PSQL_CMD} -d "${TARGET_DB}" -c "DROP TABLE IF EXISTS countries CASCADE;" 2> /dev/null; then
  __loge "ERROR: Failed to drop countries table"
  __log_finish
  return 1
 fi
 __logi "SUCCESS: Country tables dropped"

 __log_finish
}

# Function to cleanup temporary files
function __cleanup_temp_files() {
 __log_start
 __logi "Cleaning up temporary files"

 # Remove process temporary directories
 if [[ -d "/tmp" ]]; then
  find /tmp -maxdepth 1 -name "process*" -type d -exec rm -rf {} + 2> /dev/null || true
  __logi "Temporary process directories cleaned"
 fi
 __log_finish
}

# Main cleanup function
function __cleanup_all() {
 __log_start
 local TARGET_DB="${1}"

 __logi "Starting comprehensive cleanup for database: ${TARGET_DB}"

 # Step 1: Check if database exists
 if [[ ${EXIT_REQUESTED} -eq 1 ]]; then
  __loge "Cleanup was interrupted"
  __log_finish
  return 1
 fi

 local CHECK_DATABASE_STATUS_ALL=0
 __check_database "${TARGET_DB}"
 CHECK_DATABASE_STATUS_ALL=$?
 if [[ ${CHECK_DATABASE_STATUS_ALL} -ne 0 ]]; then
  __logw "Database ${TARGET_DB} does not exist. Skipping database cleanup operations."
  __logi "Continuing with temporary file cleanup only."

  # Step 5: Cleanup temporary files
  __logi "Step 1: Cleaning up temporary files"
  __cleanup_temp_files

  __logi "Cleanup completed (database operations skipped)"
  __log_finish
  return 0
 fi

 # Capture state BEFORE cleanup
 local BEFORE_DIR="${TMP_DIR}/before"
 local AFTER_DIR="${TMP_DIR}/after"
 mkdir -p "${BEFORE_DIR}" "${AFTER_DIR}"

 __logi "Capturing database state BEFORE cleanup..."
 __list_all_tables "${TARGET_DB}" "${BEFORE_DIR}/tables.txt"
 __list_all_functions "${TARGET_DB}" "${BEFORE_DIR}/functions.txt"
 __list_all_types "${TARGET_DB}" "${BEFORE_DIR}/types.txt"
 __list_all_schemas "${TARGET_DB}" "${BEFORE_DIR}/schemas.txt"

 # Step 2: Cleanup WMS components
 if [[ ${EXIT_REQUESTED} -eq 1 ]]; then
  __loge "Cleanup was interrupted"
  __log_finish
  return 1
 fi
 __logi "Step 2: Cleaning up WMS components"
 local CLEANUP_WMS_STATUS=0
 __cleanup_wms "${TARGET_DB}"
 CLEANUP_WMS_STATUS=$?
 if [[ ${CLEANUP_WMS_STATUS} -ne 0 ]]; then
  __loge "WMS cleanup failed"
  __log_finish
  return 1
 fi

 # Step 3: Cleanup base components
 if [[ ${EXIT_REQUESTED} -eq 1 ]]; then
  __loge "Cleanup was interrupted"
  __log_finish
  return 1
 fi
 __logi "Step 3: Cleaning up base components"
 local CLEANUP_BASE_STATUS=0
 __cleanup_base "${TARGET_DB}"
 CLEANUP_BASE_STATUS=$?
 if [[ ${CLEANUP_BASE_STATUS} -ne 0 ]]; then
  __loge "Base cleanup failed"
  __log_finish
  return 1
 fi

 # Step 4: Cleanup temporary files
 if [[ ${EXIT_REQUESTED} -eq 1 ]]; then
  __loge "Cleanup was interrupted"
  __log_finish
  return 1
 fi
 __logi "Step 4: Cleaning up temporary files"
 __cleanup_temp_files

 # Capture state AFTER cleanup
 __logi "Capturing database state AFTER cleanup..."
 __list_all_tables "${TARGET_DB}" "${AFTER_DIR}/tables.txt"
 __list_all_functions "${TARGET_DB}" "${AFTER_DIR}/functions.txt"
 __list_all_types "${TARGET_DB}" "${AFTER_DIR}/types.txt"
 __list_all_schemas "${TARGET_DB}" "${AFTER_DIR}/schemas.txt"

 # Generate summary
 __generate_cleanup_summary "${TARGET_DB}" "${BEFORE_DIR}" "${AFTER_DIR}"

 # Verify cleanup succeeded
 if [[ ${EXIT_REQUESTED} -eq 1 ]]; then
  __loge "Cleanup was interrupted"
  __log_finish
  return 1
 fi
 local VERIFY_STATUS=0
 __verify_cleanup_success "${TARGET_DB}" "${AFTER_DIR}"
 VERIFY_STATUS=$?
 if [[ ${VERIFY_STATUS} -ne 0 ]]; then
  __loge "Cleanup verification failed: Some critical objects were not removed"
  __log_finish
  return 1
 fi

 __logi "Comprehensive cleanup completed successfully"
 __log_finish
}

# Function to handle interruption signals
function __handle_interrupt() {
 __logi "INTERRUPTED: Received interrupt signal. Cleaning up and exiting..."
 EXIT_REQUESTED=1
 __cleanup
 exit 130
}

# Cleanup function
# shellcheck disable=SC2317
function __cleanup() {
 __log_start
 # Remove lock file if it exists and we own it
 if [[ -n "${LOCK:-}" ]] && [[ -f "${LOCK}" ]]; then
  rm -f "${LOCK}" 2> /dev/null || true
 fi
 # Close lock file descriptor if open
 exec 8>&- 2> /dev/null || true
 # Remove temporary directory
 if [[ -d "${TMP_DIR}" ]]; then
  rm -rf "${TMP_DIR}"
 fi
 __log_finish
}

# Show help
function __show_help() {
 echo "Usage: $0 [OPTIONS]"
 echo ""
 echo "This script removes components from the OSM-Notes-profile database."
 echo "Can perform comprehensive cleanup or partition-only cleanup."
 echo ""
 echo "Database is configured in etc/properties.sh (DBNAME variable)."
 echo ""
 echo "OPTIONS:"
 echo "  -p, --partitions-only    Clean only partition tables"
 echo "  -a, --all               Clean everything (default)"
 echo "  -h, --help              Show this help message"
 echo ""
 echo "Examples:"
 echo "  $0                       # Full cleanup using configured database"
 echo "  $0 -p                    # Clean only partitions"
 echo "  $0 --partitions-only     # Clean only partitions"
 echo ""
 echo "Database connection uses properties from etc/properties.sh:"
 if [[ -n "${DBNAME:-}" ]]; then
  echo "  Database: ${DBNAME}"
 else
  echo "  Database: (not configured - set DBNAME in etc/properties.sh)"
 fi
 echo "  Database user: ${DB_USER:-not set}"
 echo "  Authentication: peer (uses system user)"
 echo ""
 echo "Full cleanup will:"
 echo "  1. Check if the database exists"
 echo "  2. Remove WMS components"
 echo "  3. Remove base components (tables, functions, procedures)"
 echo "  4. Clean up temporary files"
 echo ""
 echo "Partition-only cleanup will:"
 echo "  1. Check if the database exists"
 echo "  2. List all existing partition tables"
 echo "  3. Drop all partition tables"
 echo "  4. Verify that all partition tables have been removed"
 echo ""
 echo "WARNING: This will permanently remove data and components!"
}

# Main execution
function main() {
 # Enable bash debug mode if BASH_DEBUG environment variable is set
 if [[ "${BASH_DEBUG:-}" == "true" ]] || [[ "${BASH_DEBUG:-}" == "1" ]]; then
  set -xv
 fi

 # Set up cleanup trap and signal handlers
 trap __cleanup EXIT
 trap __handle_interrupt INT TERM

 # Parse command line arguments
 local CLEANUP_MODE="all"

 while [[ $# -gt 0 ]]; do
  case $1 in
  -p | --partitions-only)
   CLEANUP_MODE="partitions"
   shift
   ;;
  -a | --all)
   CLEANUP_MODE="all"
   shift
   ;;
  -h | --help)
   __show_help
   exit 0
   ;;
  -*)
   __loge "Unknown option: $1"
   __show_help
   exit 1
   ;;
  *)
   __loge "This script does not accept database name as argument"
   __loge "Configure database name in etc/properties.sh (DBNAME variable)"
   __show_help
   exit 1
   ;;
  esac
 done

 # Use database from properties (required)
 if [[ -z "${DBNAME:-}" ]]; then
  __loge "DBNAME not set in etc/properties.sh"
  __loge "Please configure DBNAME in etc/properties.sh before running cleanup"
  exit 1
 fi
 local TARGET_DB="${DBNAME}"

 # Prevent concurrent executions using flock
 __logi "Checking for concurrent executions..."
 exec 8> "${LOCK}"
 if ! flock -n 8; then
  __loge "ERROR: Another instance of ${BASENAME} is already running"
  __loge "Lock file: ${LOCK}"
  __loge "If you are sure no other instance is running, remove the lock file:"
  __loge "  rm -f ${LOCK}"
  exit 1
 fi

 # Write lock file content with useful debugging information
 local START_TIMESTAMP=""
 START_TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
 cat > "${LOCK}" << EOF
PID: $$
Process: ${BASENAME}
Started: ${START_TIMESTAMP}
Temporary directory: ${TMP_DIR}
Cleanup mode: ${CLEANUP_MODE}
Database: ${TARGET_DB}
Main script: ${0}
EOF
 __logd "Lock file created: ${LOCK}"

 __logi "Starting cleanup for database: ${TARGET_DB} (mode: ${CLEANUP_MODE})"

 # Run cleanup based on mode
 case "${CLEANUP_MODE}" in
 "partitions")
  if [[ ${EXIT_REQUESTED} -eq 1 ]]; then
   __loge "Cleanup was interrupted before starting"
   exit 130
  fi
  local CLEAN_PARTITIONS_STATUS=0
  __cleanup_partitions_only "${TARGET_DB}"
  CLEAN_PARTITIONS_STATUS=$?
  if [[ ${CLEAN_PARTITIONS_STATUS} -eq 0 ]]; then
   if [[ ${EXIT_REQUESTED} -eq 1 ]]; then
    __loge "Cleanup was interrupted"
    exit 130
   fi
   __logi "Partition cleanup completed successfully"
   exit 0
  else
   if [[ ${EXIT_REQUESTED} -eq 1 ]]; then
    __loge "Cleanup was interrupted"
    exit 130
   fi
   __loge "Partition cleanup failed"
   exit 1
  fi
  ;;
 "all")
  if [[ ${EXIT_REQUESTED} -eq 1 ]]; then
   __loge "Cleanup was interrupted before starting"
   exit 130
  fi
  local CLEAN_ALL_STATUS=0
  __cleanup_all "${TARGET_DB}"
  CLEAN_ALL_STATUS=$?
  if [[ ${CLEAN_ALL_STATUS} -eq 0 ]]; then
   if [[ ${EXIT_REQUESTED} -eq 1 ]]; then
    __loge "Cleanup was interrupted"
    exit 130
   fi
   __logi "Comprehensive cleanup completed successfully"
   exit 0
  else
   if [[ ${EXIT_REQUESTED} -eq 1 ]]; then
    __loge "Cleanup was interrupted"
    exit 130
   fi
   __loge "Comprehensive cleanup failed"
   exit 1
  fi
  ;;
 *)
  __loge "Unknown cleanup mode: ${CLEANUP_MODE}"
  exit 1
  ;;
 esac
}

# Execute main function
if [[ "${SKIP_MAIN:-}" != "true" ]]; then
 main "$@"
fi
