#!/bin/bash

# Comprehensive cleanup script for OSM-Notes-profile
# This script removes all components from the database
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-30

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

# Start logger
__start_logger

# Load validation functions
if [[ -f "${SCRIPT_BASE_DIRECTORY}/bin/validationFunctions.sh" ]]; then
 # shellcheck source=validationFunctions.sh
 source "${SCRIPT_BASE_DIRECTORY}/bin/validationFunctions.sh"
else
 __loge "ERROR: validationFunctions.sh not found"
 exit 1
fi

# Function to check if database exists
function check_database() {
 local TARGET_DB="${1:-${DBNAME}}"

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
function execute_sql_script() {
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

# Function to cleanup ETL components
function cleanup_etl() {
 local TARGET_DB="${1}"

 __logi "Cleaning up ETL components"

 local ETL_SCRIPTS=(
  "${SCRIPT_BASE_DIRECTORY}/sql/dwh/datamartCountries/datamartCountries_dropDatamartObjects.sql:Countries Datamart"
  "${SCRIPT_BASE_DIRECTORY}/sql/dwh/datamartUsers/datamartUsers_dropDatamartObjects.sql:Users Datamart"
  "${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging_removeStagingObjects.sql:Staging Objects"
  "${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_12_removeDatamartObjects.sql:Datamart Objects"
  "${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_13_removeDWHObjects.sql:DWH Objects"
 )

 for script_info in "${ETL_SCRIPTS[@]}"; do
  IFS=':' read -r script_path script_name <<< "${script_info}"
  if [[ -f "${script_path}" ]]; then
   execute_sql_script "${TARGET_DB}" "${script_path}" "${script_name}"
  else
   __logw "Script not found: ${script_path}"
  fi
 done
}

# Function to cleanup WMS components
function cleanup_wms() {
 local TARGET_DB="${1}"

 __logi "Cleaning up WMS components"

 local WMS_SCRIPT="${SCRIPT_BASE_DIRECTORY}/sql/wms/removeFromDatabase.sql"
 if [[ -f "${WMS_SCRIPT}" ]]; then
  execute_sql_script "${TARGET_DB}" "${WMS_SCRIPT}" "WMS Components"
 else
  __logw "WMS cleanup script not found: ${WMS_SCRIPT}"
 fi
}

# Function to cleanup API tables first (to resolve enum dependencies)
function cleanup_api_tables() {
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
function cleanup_base() {
 local TARGET_DB="${1}"

 __logi "Cleaning up base components"

 # First clean up API tables to resolve enum dependencies
 cleanup_api_tables "${TARGET_DB}"

 local BASE_SCRIPTS=(
  "${SCRIPT_BASE_DIRECTORY}/sql/monitor/processCheckPlanetNotes_11_dropCheckTables.sql:Check Tables"
  "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_11_dropSyncTables.sql:Sync Tables"
  "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_13_dropBaseTables.sql:Base Tables"
  "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_14_dropCountryTables.sql:Country Tables"
  "${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_12_dropGenericObjects.sql:Generic Objects"
 )

 for script_info in "${BASE_SCRIPTS[@]}"; do
  IFS=':' read -r script_path script_name <<< "${script_info}"
  if [[ -f "${script_path}" ]]; then
   execute_sql_script "${TARGET_DB}" "${script_path}" "${script_name}"
  else
   __logw "Script not found: ${script_path}"
  fi
 done
}

# Function to cleanup temporary files
function cleanup_temp_files() {
 __logi "Cleaning up temporary files"

 # Remove process temporary directories
 if [[ -d "/tmp" ]]; then
  find /tmp -maxdepth 1 -name "process*" -type d -exec rm -rf {} + 2> /dev/null || true
  __logi "Temporary process directories cleaned"
 fi
}

# Main cleanup function
function cleanup_all() {
 local TARGET_DB="${1}"

 __logi "Starting comprehensive cleanup for database: ${TARGET_DB}"

 # Step 1: Check if database exists
 if ! check_database "${TARGET_DB}"; then
  return 1
 fi

 # Step 2: Cleanup ETL components
 __logi "Step 1: Cleaning up ETL components"
 cleanup_etl "${TARGET_DB}"

 # Step 3: Cleanup WMS components
 __logi "Step 2: Cleaning up WMS components"
 cleanup_wms "${TARGET_DB}"

 # Step 4: Cleanup base components
 __logi "Step 3: Cleaning up base components"
 cleanup_base "${TARGET_DB}"

 # Step 5: Cleanup temporary files
 __logi "Step 4: Cleaning up temporary files"
 cleanup_temp_files

 __logi "Comprehensive cleanup completed successfully"
}

# Cleanup function
# shellcheck disable=SC2317
function cleanup() {
 if [[ -d "${TMP_DIR}" ]]; then
  rm -rf "${TMP_DIR}"
 fi
}

# Show help
function show_help() {
 echo "Usage: $0 [database_name]"
 echo ""
 echo "This script removes all components from the OSM-Notes-profile database."
 echo "This includes ETL components, WMS components, base tables, and temporary files."
 echo ""
 echo "Examples:"
 echo "  $0                    # Uses default database from properties (osm_notes)"
 echo "  $0 notes              # Uses specified database"
 echo "  $0 osm_notes_test     # Uses test database"
 echo "  $0 osm_notes_prod     # Uses production database"
 echo ""
 echo "Database connection uses properties from etc/properties.sh:"
 echo "  Default database: osm_notes"
 echo "  Database user: ${DB_USER:-not set}"
 echo "  Authentication: peer (uses system user)"
 echo ""
 echo "The script will:"
 echo "  1. Check if the database exists"
 echo "  2. Remove ETL components (datamarts, staging, DWH objects)"
 echo "  3. Remove WMS components"
 echo "  4. Remove base components (tables, functions, procedures)"
 echo "  5. Clean up temporary files"
 echo ""
 echo "WARNING: This will permanently remove all data and components!"
}

# Main execution
function main() {
 # Set up cleanup trap
 trap cleanup EXIT

 # Check if database name is provided
 local DBNAME_PARAM="${1:-}"

 # Check for help flag
 if [[ "${DBNAME_PARAM}" == "-h" || "${DBNAME_PARAM}" == "--help" ]]; then
  show_help
  exit 0
 fi

 # Use parameter or default from properties
 local TARGET_DB="${DBNAME_PARAM:-${DBNAME:-}}"
 if [[ -z "${TARGET_DB}" ]]; then
  __loge "Database name is required. Please provide a database name or set DBNAME in etc/properties.sh"
  show_help
  exit 1
 fi

 __logi "Starting comprehensive cleanup for database: ${TARGET_DB}"

 # Run cleanup
 if cleanup_all "${TARGET_DB}"; then
  __logi "Comprehensive cleanup completed successfully"
  exit 0
 else
  __loge "Comprehensive cleanup failed"
  exit 1
 fi
}

# Execute main function
main "$@"
