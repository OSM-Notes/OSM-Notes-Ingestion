#!/bin/bash

# Regenerates countries and maritimes backup files from scratch
# This script:
# 1. Drops and recreates the countries table
# 2. Downloads and processes all countries and maritimes from Overpass
# 3. Exports the results to data/countries.geojson and data/maritimes.geojson
#
# This is useful when the backup files have incomplete geometries due to
# bugs in the import process (e.g., missing -select flag in ogr2ogr).
#
# Usage:
#   ./bin/scripts/regenerateBoundariesBackup.sh
#   DBNAME=test_db ./bin/scripts/regenerateBoundariesBackup.sh
#
# Environment variables:
#   DBNAME - Database name (default: notes)
#   LOG_LEVEL - Logging level (default: INFO)
#
# Output:
#   data/countries.geojson - GeoJSON file with country boundaries
#   data/maritimes.geojson - GeoJSON file with maritime boundaries
#
# Author: Andres Gomez (AngocA)
# Version: 2025-01-23

set -euo pipefail

# Base directory for the project
SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." \
 &> /dev/null && pwd)"
declare -r SCRIPT_BASE_DIRECTORY

# Logger levels: TRACE, DEBUG, INFO, WARN, ERROR, FATAL
declare LOG_LEVEL="${LOG_LEVEL:-INFO}"

# Load common functions
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/commonFunctions.sh"

# Database name
declare DBNAME="${DBNAME:-notes}"

# Output files
declare -r COUNTRIES_OUTPUT="${SCRIPT_BASE_DIRECTORY}/data/countries.geojson"
declare -r MARITIMES_OUTPUT="${SCRIPT_BASE_DIRECTORY}/data/maritimes.geojson"

###############################################################################
# Main function
###############################################################################
main() {
 # Enable bash debug mode if BASH_DEBUG environment variable is set
 if [[ "${BASH_DEBUG:-}" == "true" ]] || [[ "${BASH_DEBUG:-}" == "1" ]]; then
  set -xv
 fi

 __log_start
 __logi "=== REGENERATING BOUNDARIES BACKUP FILES ==="
 __logi "This will download and process all countries and maritimes from Overpass"
 __logi "Database: ${DBNAME}"

 # Check database connection
 __logd "Checking database connection..."
 if ! psql -d "${DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
  __loge "ERROR: Cannot connect to database '${DBNAME}'"
  __loge "Please create the database first or set DBNAME environment variable"
  exit 1
 fi

 # Create data directory if it doesn't exist
 __logd "Ensuring data directory exists..."
 mkdir -p "${SCRIPT_BASE_DIRECTORY}/data"

 # Step 1: Temporarily move existing backups to force download from Overpass
 __logi "Step 1: Moving existing backups to force fresh download..."
 local COUNTRIES_BACKUP="${SCRIPT_BASE_DIRECTORY}/data/countries.geojson"
 local COUNTRIES_BACKUP_GZ="${SCRIPT_BASE_DIRECTORY}/data/countries.geojson.gz"
 local MARITIMES_BACKUP="${SCRIPT_BASE_DIRECTORY}/data/maritimes.geojson"
 local MARITIMES_BACKUP_GZ="${SCRIPT_BASE_DIRECTORY}/data/maritimes.geojson.gz"

 local BACKUP_TMP_DIR
 BACKUP_TMP_DIR=$(mktemp -d)
 if [[ -f "${COUNTRIES_BACKUP}" ]]; then
  mv "${COUNTRIES_BACKUP}" "${BACKUP_TMP_DIR}/countries.geojson.backup"
  __logd "Moved ${COUNTRIES_BACKUP} to temporary location"
 fi
 if [[ -f "${COUNTRIES_BACKUP_GZ}" ]]; then
  mv "${COUNTRIES_BACKUP_GZ}" "${BACKUP_TMP_DIR}/countries.geojson.gz.backup"
  __logd "Moved ${COUNTRIES_BACKUP_GZ} to temporary location"
 fi
 if [[ -f "${MARITIMES_BACKUP}" ]]; then
  mv "${MARITIMES_BACKUP}" "${BACKUP_TMP_DIR}/maritimes.geojson.backup"
  __logd "Moved ${MARITIMES_BACKUP} to temporary location"
 fi
 if [[ -f "${MARITIMES_BACKUP_GZ}" ]]; then
  mv "${MARITIMES_BACKUP_GZ}" "${BACKUP_TMP_DIR}/maritimes.geojson.gz.backup"
  __logd "Moved ${MARITIMES_BACKUP_GZ} to temporary location"
 fi

 # Step 2: Run updateCountries in --base mode
 # This will drop and recreate tables, then download and process all boundaries
 __logi "Step 2: Running updateCountries in --base mode..."
 __logi "This will download and process all countries and maritimes from Overpass"
 __logi "This may take a long time (30-60 minutes)..."

 if ! "${SCRIPT_BASE_DIRECTORY}/bin/process/updateCountries.sh" --base; then
  __loge "ERROR: updateCountries --base failed"
  # Restore backups on failure
  if [[ -f "${BACKUP_TMP_DIR}/countries.geojson.backup" ]]; then
   mv "${BACKUP_TMP_DIR}/countries.geojson.backup" "${COUNTRIES_BACKUP}"
  fi
  if [[ -f "${BACKUP_TMP_DIR}/countries.geojson.gz.backup" ]]; then
   mv "${BACKUP_TMP_DIR}/countries.geojson.gz.backup" "${COUNTRIES_BACKUP_GZ}"
  fi
  if [[ -f "${BACKUP_TMP_DIR}/maritimes.geojson.backup" ]]; then
   mv "${BACKUP_TMP_DIR}/maritimes.geojson.backup" "${MARITIMES_BACKUP}"
  fi
  if [[ -f "${BACKUP_TMP_DIR}/maritimes.geojson.gz.backup" ]]; then
   mv "${BACKUP_TMP_DIR}/maritimes.geojson.gz.backup" "${MARITIMES_BACKUP_GZ}"
  fi
  rm -rf "${BACKUP_TMP_DIR}"
  exit 1
 fi

 # Clean up temporary backup directory (backups will be regenerated)
 rm -rf "${BACKUP_TMP_DIR}"
 __logi "Step 2 completed successfully"

 # Step 3: Export countries backup
 __logi "Step 3: Exporting countries backup..."
 if ! "${SCRIPT_BASE_DIRECTORY}/bin/scripts/exportCountriesBackup.sh"; then
  __loge "ERROR: Failed to export countries backup"
  exit 1
 fi

 # Verify countries backup file
 if [[ ! -f "${COUNTRIES_OUTPUT}" ]] || [[ ! -s "${COUNTRIES_OUTPUT}" ]]; then
  __loge "ERROR: Countries backup file was not created or is empty"
  exit 1
 fi

 local COUNTRIES_SIZE
 COUNTRIES_SIZE=$(stat -c%s "${COUNTRIES_OUTPUT}" 2> /dev/null || echo "0")
 local COUNTRIES_SIZE_HUMAN
 COUNTRIES_SIZE_HUMAN=$(numfmt --to=iec-i --suffix=B "${COUNTRIES_SIZE}" 2> /dev/null || echo "${COUNTRIES_SIZE} bytes")

 __logi "Countries backup created: ${COUNTRIES_OUTPUT} (${COUNTRIES_SIZE_HUMAN})"

 # Step 4: Export maritimes backup
 __logi "Step 4: Exporting maritimes backup..."
 if ! "${SCRIPT_BASE_DIRECTORY}/bin/scripts/exportMaritimesBackup.sh"; then
  __loge "ERROR: Failed to export maritimes backup"
  exit 1
 fi

 # Verify maritimes backup file
 if [[ ! -f "${MARITIMES_OUTPUT}" ]] || [[ ! -s "${MARITIMES_OUTPUT}" ]]; then
  __loge "ERROR: Maritimes backup file was not created or is empty"
  exit 1
 fi

 local MARITIMES_SIZE
 MARITIMES_SIZE=$(stat -c%s "${MARITIMES_OUTPUT}" 2> /dev/null || echo "0")
 local MARITIMES_SIZE_HUMAN
 MARITIMES_SIZE_HUMAN=$(numfmt --to=iec-i --suffix=B "${MARITIMES_SIZE}" 2> /dev/null || echo "${MARITIMES_SIZE} bytes")

 __logi "Maritimes backup created: ${MARITIMES_OUTPUT} (${MARITIMES_SIZE_HUMAN})"

 # Validate GeoJSON files if jq is available
 if command -v jq > /dev/null 2>&1; then
  __logd "Validating GeoJSON files..."
  local COUNTRIES_FEATURES
  COUNTRIES_FEATURES=$(jq '.features | length' "${COUNTRIES_OUTPUT}" 2> /dev/null || echo "0")
  local MARITIMES_FEATURES
  MARITIMES_FEATURES=$(jq '.features | length' "${MARITIMES_OUTPUT}" 2> /dev/null || echo "0")

  __logi "Countries backup: ${COUNTRIES_FEATURES} features"
  __logi "Maritimes backup: ${MARITIMES_FEATURES} features"
 fi

 __logi "=== BACKUP REGENERATION COMPLETED SUCCESSFULLY ==="
 __logi "Files created:"
 __logi "  - ${COUNTRIES_OUTPUT}"
 __logi "  - ${MARITIMES_OUTPUT}"
 __log_finish
}

# Execute main
main "$@"
