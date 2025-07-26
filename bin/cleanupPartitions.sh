#!/bin/bash

# Manual cleanup script for partition tables
# This script removes all partition tables that might have been left behind
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-26

set -euo pipefail

# Define required variables
BASENAME="cleanupPartitions"
TMP_DIR="/tmp/${BASENAME}_$$"
mkdir -p "${TMP_DIR}"

# Simple logging functions
function log_info() {
 echo "$(date '+%Y-%m-%d %H:%M:%S') - INFO - $*" || true
}

function log_error() {
 echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR - $*" >&2 || true
}

function log_warn() {
 echo "$(date '+%Y-%m-%d %H:%M:%S') - WARN - $*" || true
}

# Function to check if database exists
function check_database() {
 local DBNAME="${1}"

 log_info "Checking if database exists: ${DBNAME}"

 if psql -lqt | cut -d \| -f 1 | grep -qw "${DBNAME}"; then
  log_info "Database ${DBNAME} exists"
  return 0
 else
  log_error "Database ${DBNAME} does not exist"
  return 1
 fi
}

# Function to list existing partition tables
function list_partition_tables() {
 local DBNAME="${1}"

 log_info "Listing existing partition tables in database: ${DBNAME}"

 psql -d "${DBNAME}" -c "
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

 log_info "Dropping all partition tables using script: ${DROP_SCRIPT}"

 if [[ ! -f "${DROP_SCRIPT}" ]]; then
  log_error "Drop script not found: ${DROP_SCRIPT}"
  return 1
 fi

 psql -d "${DBNAME}" -f "${DROP_SCRIPT}"

 log_info "Partition tables cleanup completed"
}

# Function to verify cleanup
function verify_cleanup() {
 local DBNAME="${1}"

 log_info "Verifying that all partition tables have been removed"

 local REMAINING_COUNT
 REMAINING_COUNT=$(psql -d "${DBNAME}" -t -c "
 SELECT COUNT(*) 
 FROM information_schema.tables 
 WHERE table_name LIKE '%_part_%';
 " | tr -d ' ')

 if [[ "${REMAINING_COUNT}" -eq 0 ]]; then
  log_info "SUCCESS: All partition tables have been removed"
  return 0
 else
  log_warn "WARNING: ${REMAINING_COUNT} partition tables still exist"
  psql -d "${DBNAME}" -c "
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

 log_info "Starting partition tables cleanup for database: ${DBNAME}"

 # Step 1: Check if database exists
 if ! check_database "${DBNAME}"; then
  return 1
 fi

 # Step 2: List existing partition tables
 log_info "Step 1: Listing existing partition tables"
 list_partition_tables "${DBNAME}"

 # Step 3: Drop all partition tables
 log_info "Step 2: Dropping all partition tables"
 if ! drop_all_partitions "${DBNAME}"; then
  log_error "Failed to drop partition tables"
  return 1
 fi

 # Step 4: Verify cleanup
 log_info "Step 3: Verifying cleanup"
 if ! verify_cleanup "${DBNAME}"; then
  log_warn "Some partition tables may still exist"
  return 1
 fi

 log_info "Partition tables cleanup completed successfully"
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
 echo "Usage: $0 <database_name>"
 echo ""
 echo "This script removes all partition tables that might have been left behind"
 echo "after a cancelled or failed parallel processing operation."
 echo ""
 echo "Examples:"
 echo "  $0 osm_notes_test"
 echo "  $0 osm_notes_prod"
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
 local DBNAME="${1:-}"
 if [[ -z "${DBNAME}" ]]; then
  log_error "Database name is required"
  show_help
  exit 1
 fi

 # Check for help flag
 if [[ "${DBNAME}" == "-h" || "${DBNAME}" == "--help" ]]; then
  show_help
  exit 0
 fi

 log_info "Starting partition tables cleanup"

 # Run cleanup
 if cleanup_partitions "${DBNAME}"; then
  log_info "Partition tables cleanup completed successfully"
  exit 0
 else
  log_error "Partition tables cleanup failed"
  exit 1
 fi
}

# Execute main function
main "$@"
