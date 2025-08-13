#!/bin/bash

# Comprehensive cleanup script for OSM-Notes-profile
# This script removes all components from the database
# Can be used for full cleanup or partition-only cleanup
#
# Author: Andres Gomez (AngocA)
# Version: 2025-08-13

set -euo pipefail

# Define required variables
BASENAME="cleanupAll"
TMP_DIR="/tmp/${BASENAME}_$$"
mkdir -p "${TMP_DIR}"

# Define script base directory
SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load common functions (includes logging)
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/bin/commonFunctions.sh"

# Load global properties
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh"

# Start logger (using available logging functions)
__logi "Starting cleanupAll.sh script"

# Load validation functions
if [[ -f "${SCRIPT_BASE_DIRECTORY}/bin/validationFunctions.sh" ]]; then
 # shellcheck source=validationFunctions.sh
 source "${SCRIPT_BASE_DIRECTORY}/bin/validationFunctions.sh"
else
 __loge "ERROR: validationFunctions.sh not found"
 exit 1
fi

# Function to check if database exists
function __check_database() {
 local TARGET_DB="${1:-}"

 # Use provided database name or default from properties
 if [[ -z "${TARGET_DB}" ]]; then
  if [[ -n "${DBNAME:-}" ]]; then
   TARGET_DB="${DBNAME}"
  else
   TARGET_DB="osm_notes"
  fi
 fi

 __logi "Checking if database exists: ${TARGET_DB}"

 if psql -lqt | cut -d \| -f 1 | grep -qw "${TARGET_DB}"; then
  __logi "Database ${TARGET_DB} exists"
  return 0
 else
  __loge "Database ${TARGET_DB} does not exist"
  return 1
 fi
}

# Function to execute SQL script with validation
function __execute_sql_script() {
 local TARGET_DB="${1}"
 local SCRIPT_PATH="${2}"
 local SCRIPT_NAME="${3}"

 __logi "Executing ${SCRIPT_NAME}: ${SCRIPT_PATH}"

 # Validate SQL script using centralized validation
 if ! __validate_sql_structure "${SCRIPT_PATH}"; then
  __loge "ERROR: SQL script validation failed: ${SCRIPT_PATH}"
  return 1
 fi

 # Use peer authentication (no host, port, or password needed)
 local PSQL_CMD="psql"
 if [[ -n "${DB_USER:-}" ]]; then
  PSQL_CMD="${PSQL_CMD} -U ${DB_USER}"
 fi

 if ${PSQL_CMD} -d "${TARGET_DB}" -f "${SCRIPT_PATH}"; then
  __logi "SUCCESS: ${SCRIPT_NAME} completed"
  return 0
 else
  __loge "FAILED: ${SCRIPT_NAME} failed"
  return 1
 fi
}

# Function to list existing partition tables
function __list_partition_tables() {
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
}

# Function to drop all partition tables
function __drop_all_partitions() {
 local TARGET_DB="${1}"
 local DROP_SCRIPT="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_11_dropAllPartitions.sql"

 __logi "Dropping all partition tables using script: ${DROP_SCRIPT}"

 # Validate SQL script using centralized validation
 if ! __validate_sql_structure "${DROP_SCRIPT}"; then
  __loge "ERROR: Drop script validation failed: ${DROP_SCRIPT}"
  return 1
 fi

 # Use peer authentication (no host, port, or password needed)
 local PSQL_CMD="psql"
 if [[ -n "${DB_USER:-}" ]]; then
  PSQL_CMD="${PSQL_CMD} -U ${DB_USER}"
 fi

 if ${PSQL_CMD} -d "${TARGET_DB}" -f "${DROP_SCRIPT}"; then
  __logi "SUCCESS: Partition tables dropped"
  return 0
 else
  __loge "FAILED: Partition tables drop failed"
  return 1
 fi
}

# Function to verify partition cleanup
function __verify_partition_cleanup() {
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
  return 0
 else
  __logw "WARNING: ${REMAINING_COUNT} partition tables still exist"
  ${PSQL_CMD} -d "${TARGET_DB}" -c "
  SELECT table_name 
  FROM information_schema.tables 
  WHERE table_name LIKE '%_part_%' 
  ORDER BY table_name;
  "
  return 1
 fi
}

# Function to cleanup only partition tables
function __cleanup_partitions_only() {
 local TARGET_DB="${1}"

 __logi "Starting partition tables cleanup for database: ${TARGET_DB}"

 # Step 1: Check if database exists
 if ! __check_database "${TARGET_DB}"; then
  __loge "Database ${TARGET_DB} does not exist. Cannot proceed with partition cleanup."
  return 1
 fi

 # Step 2: List existing partition tables
 __logi "Step 1: Listing existing partition tables"
 __list_partition_tables "${TARGET_DB}"

 # Step 3: Drop all partition tables
 __logi "Step 2: Dropping all partition tables"
 if ! __drop_all_partitions "${TARGET_DB}"; then
  __loge "Failed to drop partition tables"
  return 1
 fi

 # Step 4: Verify cleanup
 __logi "Step 3: Verifying cleanup"
 if ! __verify_partition_cleanup "${TARGET_DB}"; then
  __logw "Some partition tables may still exist"
  return 1
 fi

 __logi "Partition tables cleanup completed successfully"
}

# Function to cleanup ETL components
function __cleanup_etl() {
 local TARGET_DB="${1}"

 __logi "Cleaning up ETL components"

 local ETL_SCRIPTS=(
  "${SCRIPT_BASE_DIRECTORY}/sql/dwh/datamartCountries/datamartCountries_dropDatamartObjects.sql:Countries Datamart"
  "${SCRIPT_BASE_DIRECTORY}/sql/dwh/datamartUsers/datamartUsers_dropDatamartObjects.sql:Users Datamart"
  "${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging_removeStagingObjects.sql:Staging Objects"
  "${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_12_removeDatamartObjects.sql:Datamart Objects"
  "${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_13_removeDWHObjects.sql:DWH Objects"
 )

 for SCRIPT_INFO in "${ETL_SCRIPTS[@]}"; do
  IFS=':' read -r SCRIPT_PATH SCRIPT_NAME <<< "${SCRIPT_INFO}"
  if [[ -f "${SCRIPT_PATH}" ]]; then
   __execute_sql_script "${TARGET_DB}" "${SCRIPT_PATH}" "${SCRIPT_NAME}"
  else
   __logw "Script not found: ${SCRIPT_PATH}"
  fi
 done
}

# Function to cleanup WMS components
function __cleanup_wms() {
 local TARGET_DB="${1}"

 __logi "Cleaning up WMS components"

 local WMS_SCRIPT="${SCRIPT_BASE_DIRECTORY}/sql/wms/removeFromDatabase.sql"
 if [[ -f "${WMS_SCRIPT}" ]]; then
  __execute_sql_script "${TARGET_DB}" "${WMS_SCRIPT}" "WMS Components"
 else
  __logw "WMS cleanup script not found: ${WMS_SCRIPT}"
 fi
}

# Function to cleanup API tables first (to resolve enum dependencies)
function __cleanup_api_tables() {
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

 if ${PSQL_CMD} -d "${TARGET_DB}" -c "${API_DROP_SQL}"; then
  __logi "SUCCESS: API tables dropped"
  return 0
 else
  __logw "WARNING: Some API tables may not have been dropped"
  return 1
 fi
}

# Function to cleanup base components
function __cleanup_base() {
 local TARGET_DB="${1}"

 __logi "Cleaning up base components"

 # First clean up API tables to resolve enum dependencies
 __cleanup_api_tables "${TARGET_DB}"

 local BASE_SCRIPTS=(
  "${SCRIPT_BASE_DIRECTORY}/sql/monitor/processCheckPlanetNotes_11_dropCheckTables.sql:Check Tables"
  "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_11_dropSyncTables.sql:Sync Tables"
  "${SCRIPT_BASE_DIRECTORY}/sql/consolidated_cleanup.sql:Generic Objects"
  "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_13_dropBaseTables.sql:Base Tables"
  "${SCRIPT_BASE_DIRECTORY}/sql/consolidated_cleanup.sql:Country Tables"
 )

 for SCRIPT_INFO in "${BASE_SCRIPTS[@]}"; do
  IFS=':' read -r SCRIPT_PATH SCRIPT_NAME <<< "${SCRIPT_INFO}"
  if [[ -f "${SCRIPT_PATH}" ]]; then
   __execute_sql_script "${TARGET_DB}" "${SCRIPT_PATH}" "${SCRIPT_NAME}"
  else
   __logw "Script not found: ${SCRIPT_PATH}"
  fi
 done
}

# Function to cleanup temporary files
function __cleanup_temp_files() {
 __logi "Cleaning up temporary files"

 # Remove process temporary directories
 if [[ -d "/tmp" ]]; then
  find /tmp -maxdepth 1 -name "process*" -type d -exec rm -rf {} + 2> /dev/null || true
  __logi "Temporary process directories cleaned"
 fi
}

# Main cleanup function
function __cleanup_all() {
 local TARGET_DB="${1}"

 __logi "Starting comprehensive cleanup for database: ${TARGET_DB}"

 # Step 1: Check if database exists
 if ! __check_database "${TARGET_DB}"; then
  __logw "Database ${TARGET_DB} does not exist. Skipping database cleanup operations."
  __logi "Continuing with temporary file cleanup only."

  # Step 5: Cleanup temporary files
  __logi "Step 1: Cleaning up temporary files"
  __cleanup_temp_files

  __logi "Cleanup completed (database operations skipped)"
  return 0
 fi

 # Step 2: Cleanup ETL components
 __logi "Step 1: Cleaning up ETL components"
 __cleanup_etl "${TARGET_DB}"

 # Step 3: Cleanup WMS components
 __logi "Step 2: Cleaning up WMS components"
 __cleanup_wms "${TARGET_DB}"

 # Step 4: Cleanup base components
 __logi "Step 3: Cleaning up base components"
 __cleanup_base "${TARGET_DB}"

 # Step 5: Cleanup temporary files
 __logi "Step 4: Cleaning up temporary files"
 __cleanup_temp_files

 __logi "Comprehensive cleanup completed successfully"
}

# Cleanup function
# shellcheck disable=SC2317
function __cleanup() {
 if [[ -d "${TMP_DIR}" ]]; then
  rm -rf "${TMP_DIR}"
 fi
}

# Show help
function __show_help() {
 echo "Usage: $0 [OPTIONS] [database_name]"
 echo ""
 echo "This script removes components from the OSM-Notes-profile database."
 echo "Can perform comprehensive cleanup or partition-only cleanup."
 echo ""
 echo "OPTIONS:"
 echo "  -p, --partitions-only    Clean only partition tables"
 echo "  -a, --all               Clean everything (default)"
 echo "  -h, --help              Show this help message"
 echo ""
 echo "Examples:"
 echo "  $0                       # Full cleanup using default database"
 echo "  $0 notes                 # Full cleanup using specified database"
 echo "  $0 -p osm_notes_test     # Clean only partitions in test database"
 echo "  $0 --partitions-only     # Clean only partitions in default database"
 echo ""
 echo "Database connection uses properties from etc/properties.sh:"
 echo "  Default database: osm_notes"
 echo "  Database user: ${DB_USER:-not set}"
 echo "  Authentication: peer (uses system user)"
 echo ""
 echo "Full cleanup will:"
 echo "  1. Check if the database exists"
 echo "  2. Remove ETL components (datamarts, staging, DWH objects)"
 echo "  3. Remove WMS components"
 echo "  4. Remove base components (tables, functions, procedures)"
 echo "  5. Clean up temporary files"
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
 # Set up cleanup trap
 trap __cleanup EXIT

 # Parse command line arguments
 local CLEANUP_MODE="all"
 local DBNAME_PARAM=""

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
   DBNAME_PARAM="$1"
   shift
   ;;
  esac
 done

 # Use parameter or default from properties
 local TARGET_DB="${DBNAME_PARAM:-}"
 if [[ -z "${TARGET_DB}" ]]; then
  if [[ -n "${DBNAME:-}" ]]; then
   TARGET_DB="${DBNAME}"
  else
   TARGET_DB="osm_notes"
  fi
 fi

 __logi "Starting cleanup for database: ${TARGET_DB} (mode: ${CLEANUP_MODE})"

 # Run cleanup based on mode
 case "${CLEANUP_MODE}" in
 "partitions")
  if __cleanup_partitions_only "${TARGET_DB}"; then
   __logi "Partition cleanup completed successfully"
   exit 0
  else
   __loge "Partition cleanup failed"
   exit 1
  fi
  ;;
 "all")
  if __cleanup_all "${TARGET_DB}"; then
   __logi "Comprehensive cleanup completed successfully"
   exit 0
  else
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
