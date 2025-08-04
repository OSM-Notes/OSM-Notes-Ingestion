#!/bin/bash

# Manual cleanup script for partition tables
# This script removes all partition tables that might have been left behind
#
# Author: Andres Gomez (AngocA)
# Version: 2025-08-04

set -euo pipefail

# Define required variables
BASENAME="cleanupPartitions"
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
 local DBNAME="${1:-${DBNAME}}"

 __logi "Checking if database exists: ${DBNAME}"

 if psql -lqt | cut -d \| -f 1 | grep -qw "${DBNAME}"; then
  __logi "Database ${DBNAME} exists"
  return 0
 else
  __loge "Database ${DBNAME} does not exist"
  return 1
 fi
}

# Function to list existing partition tables
function list_partition_tables() {
 local DBNAME="${1}"

 __logi "Listing existing partition tables in database: ${DBNAME}"

 # Use properties for database connection
 local PSQL_CMD="psql"
 if [[ -n "${DB_USER:-}" ]]; then
  PSQL_CMD="${PSQL_CMD} -U ${DB_USER}"
 fi
 if [[ -n "${DB_PASSWORD:-}" ]]; then
  export PGPASSWORD="${DB_PASSWORD}"
 fi
 if [[ -n "${DB_HOST:-}" ]]; then
  PSQL_CMD="${PSQL_CMD} -h ${DB_HOST}"
 fi
 if [[ -n "${DB_PORT:-}" ]]; then
  PSQL_CMD="${PSQL_CMD} -p ${DB_PORT}"
 fi

 ${PSQL_CMD} -d "${DBNAME}" -c "
 SELECT table_name, COUNT(*) as count
 FROM information_schema.tables 
 WHERE table_name LIKE '%_part_%' 
 GROUP BY table_name 
 ORDER BY table_name;
 "
}

# Function to drop all partition tables
function drop_all_partitions() {
 local DBNAME="${1}"
 local SCRIPT_BASE_DIRECTORY
 SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
 local DROP_SCRIPT="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_11_dropAllPartitions.sql"

 __logi "Dropping all partition tables using script: ${DROP_SCRIPT}"

 # Validate SQL script using centralized validation
 if ! __validate_sql_structure "${DROP_SCRIPT}"; then
  __loge "ERROR: Drop script validation failed: ${DROP_SCRIPT}"
  return 1
 fi

 # Use properties for database connection
 local PSQL_CMD="psql"
 if [[ -n "${DB_USER:-}" ]]; then
  PSQL_CMD="${PSQL_CMD} -U ${DB_USER}"
 fi
 if [[ -n "${DB_PASSWORD:-}" ]]; then
  export PGPASSWORD="${DB_PASSWORD}"
 fi
 if [[ -n "${DB_HOST:-}" ]]; then
  PSQL_CMD="${PSQL_CMD} -h ${DB_HOST}"
 fi
 if [[ -n "${DB_PORT:-}" ]]; then
  PSQL_CMD="${PSQL_CMD} -p ${DB_PORT}"
 fi

 ${PSQL_CMD} -d "${DBNAME}" -f "${DROP_SCRIPT}"

 __logi "Partition tables cleanup completed"
}

# Function to verify cleanup
function verify_cleanup() {
 local DBNAME="${1}"

 __logi "Verifying that all partition tables have been removed"

 # Use properties for database connection
 local PSQL_CMD="psql"
 if [[ -n "${DB_USER:-}" ]]; then
  PSQL_CMD="${PSQL_CMD} -U ${DB_USER}"
 fi
 if [[ -n "${DB_PASSWORD:-}" ]]; then
  export PGPASSWORD="${DB_PASSWORD}"
 fi
 if [[ -n "${DB_HOST:-}" ]]; then
  PSQL_CMD="${PSQL_CMD} -h ${DB_HOST}"
 fi
 if [[ -n "${DB_PORT:-}" ]]; then
  PSQL_CMD="${PSQL_CMD} -p ${DB_PORT}"
 fi

 local REMAINING_COUNT
 REMAINING_COUNT=$(${PSQL_CMD} -d "${DBNAME}" -t -c "
 SELECT COUNT(*) 
 FROM information_schema.tables 
 WHERE table_name LIKE '%_part_%';
 " | tr -d ' ')

 if [[ "${REMAINING_COUNT}" -eq 0 ]]; then
  __logi "SUCCESS: All partition tables have been removed"
  return 0
 else
  __logw "WARNING: ${REMAINING_COUNT} partition tables still exist"
  ${PSQL_CMD} -d "${DBNAME}" -c "
  SELECT table_name 
  FROM information_schema.tables 
  WHERE table_name LIKE '%_part_%' 
  ORDER BY table_name;
  "
  return 1
 fi
}

# Main cleanup function
function cleanup_partitions() {
 local DBNAME="${1}"

 __logi "Starting partition tables cleanup for database: ${DBNAME}"

 # Step 1: Check if database exists
 if ! check_database "${DBNAME}"; then
  return 1
 fi

 # Step 2: List existing partition tables
 __logi "Step 1: Listing existing partition tables"
 list_partition_tables "${DBNAME}"

 # Step 3: Drop all partition tables
 __logi "Step 2: Dropping all partition tables"
 if ! drop_all_partitions "${DBNAME}"; then
  __loge "Failed to drop partition tables"
  return 1
 fi

 # Step 4: Verify cleanup
 __logi "Step 3: Verifying cleanup"
 if ! verify_cleanup "${DBNAME}"; then
  __logw "Some partition tables may still exist"
  return 1
 fi

 __logi "Partition tables cleanup completed successfully"
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
 echo "This script removes all partition tables that might have been left behind"
 echo "after a cancelled or failed parallel processing operation."
 echo ""
 echo "Examples:"
 echo "  $0                    # Uses default database from properties"
 echo "  $0 osm_notes_test     # Uses test database"
 echo "  $0 osm_notes          # Uses production database"
 echo ""
 echo "Database connection uses properties from etc/properties.sh:"
 echo "  Default database: osm_notes"
 echo "  Database user: ${DB_USER:-not set}"
 echo "  Authentication: peer (uses system user)"
 echo ""
 echo "The script will:"
 echo "  1. Check if the database exists"
 echo "  2. List all existing partition tables"
 echo "  3. Drop all partition tables (up to 100 of each type)"
 echo "  4. Verify that all partition tables have been removed"
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

 __logi "Starting partition tables cleanup for database: ${TARGET_DB}"

 # Run cleanup
 if cleanup_partitions "${TARGET_DB}"; then
  __logi "Partition tables cleanup completed successfully"
  exit 0
 else
  __loge "Partition tables cleanup failed"
  exit 1
 fi
}

# Execute main function
if [[ "${SKIP_MAIN:-}" != "true" ]]; then
 main "$@"
fi
