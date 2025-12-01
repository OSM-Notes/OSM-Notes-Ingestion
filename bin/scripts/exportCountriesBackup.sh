#!/bin/bash

# Exports current country boundaries from the database to a GeoJSON backup file
# in the repository. This backup can be used by processPlanet base to avoid
# downloading countries from Overpass on every run.
#
# The script filters out maritime boundaries (identified by comprehensive patterns
# including EEZ, Contiguous Zone, maritime, and fisheries zones) and exports only
# country boundaries to data/countries.geojson.
#
# Usage:
#   ./bin/scripts/exportCountriesBackup.sh
#   DBNAME=osm-notes ./bin/scripts/exportCountriesBackup.sh
#
# Environment variables:
#   DBNAME - Database name (default: notes)
#   LOG_LEVEL - Logging level (default: INFO)
#
# Output:
#   data/countries.geojson - GeoJSON file with country boundaries
#
# See also:
#   - data/BOUNDARIES_BACKUP.md - Complete documentation on boundaries backups
#   - bin/scripts/exportMaritimesBackup.sh - Export maritime boundaries
#
# Author: Andres Gomez (AngocA)
# Version: 2025-12-01
VERSION="2025-12-01"

# Base directory for the project.
SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." \
 &> /dev/null && pwd)"
declare -r SCRIPT_BASE_DIRECTORY

# Logger levels: TRACE, DEBUG, INFO, WARN, ERROR, FATAL.
declare LOG_LEVEL="${LOG_LEVEL:-INFO}"

# Load common functions
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/commonFunctions.sh"

# Database name
declare DBNAME="${DBNAME:-notes}"

# Output file
declare -r OUTPUT_FILE="${SCRIPT_BASE_DIRECTORY}/data/countries.geojson"

###############################################################################
# Main function
###############################################################################
main() {
 # Enable bash debug mode if BASH_DEBUG environment variable is set
 if [[ "${BASH_DEBUG:-}" == "true" ]] || [[ "${BASH_DEBUG:-}" == "1" ]]; then
  set -xv
 fi

 __log_start
 __logi "Exporting country boundaries backup..."

 # Check database connection
 __logd "Checking database connection..."
 if ! psql -d "${DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
  __loge "ERROR: Cannot connect to database '${DBNAME}'"
  exit 1
 fi

 # Check if countries table exists
 __logd "Checking countries table..."
 local COUNTRIES_COUNT
 COUNTRIES_COUNT=$(psql -d "${DBNAME}" -Atq -c \
  "SELECT COUNT(*) FROM countries" 2> /dev/null || echo "0")
 if [[ "${COUNTRIES_COUNT}" -eq 0 ]]; then
  __loge "ERROR: Countries table is empty or does not exist"
  exit 1
 fi
 __logi "Found ${COUNTRIES_COUNT} countries in database"

# Filter out maritime boundaries (they have their own backup)
# Countries are those that don't have maritime patterns in their names
# Maritime patterns include: EEZ variations, Contiguous Zone variations, maritime,
# and fisheries zones
local COUNTRIES_ONLY_COUNT
COUNTRIES_ONLY_COUNT=$(psql -d "${DBNAME}" -Atq -c \
 "SELECT COUNT(*) FROM countries WHERE NOT (
  country_name_en ILIKE '%(EEZ)%' OR country_name_en ILIKE '%EEZ%' OR
  country_name_en ILIKE '%Exclusive Economic Zone%' OR country_name_en ILIKE '%Economic Zone%' OR
  country_name_en ILIKE '%(Contiguous Zone)%' OR country_name_en ILIKE '%Contiguous Zone%' OR
  country_name_en ILIKE '%contiguous area%' OR country_name_en ILIKE '%contiguous border%' OR
  country_name_en ILIKE '%(maritime)%' OR country_name_en ILIKE '%maritime%' OR
  country_name_en ILIKE '%Fisheries protection zone%' OR country_name_en ILIKE '%Fishing territory%' OR
  country_name ILIKE '%(EEZ)%' OR country_name ILIKE '%EEZ%' OR
  country_name ILIKE '%Exclusive Economic Zone%' OR country_name ILIKE '%Economic Zone%' OR
  country_name ILIKE '%(Contiguous Zone)%' OR country_name ILIKE '%Contiguous Zone%' OR
  country_name ILIKE '%contiguous area%' OR country_name ILIKE '%contiguous border%' OR
  country_name ILIKE '%(maritime)%' OR country_name ILIKE '%maritime%' OR
  country_name ILIKE '%Fisheries protection zone%' OR country_name ILIKE '%Fishing territory%'
 )" 2> /dev/null || echo "0")

 __logi "Found ${COUNTRIES_ONLY_COUNT} countries (excluding maritimes)"

 if [[ "${COUNTRIES_ONLY_COUNT}" -eq 0 ]]; then
  __loge "ERROR: No countries found in database (excluding maritimes)"
  exit 1
 fi

 # Create data directory if it doesn't exist
 __logd "Ensuring data directory exists..."
 mkdir -p "${SCRIPT_BASE_DIRECTORY}/data"

# Export countries to GeoJSON using ogr2ogr
# Exclude maritime boundaries using comprehensive patterns
__logd "Exporting country boundaries to GeoJSON..."
if ogr2ogr -f "GeoJSON" "${OUTPUT_FILE}" \
 "PG:dbname=${DBNAME}" \
 -sql "SELECT country_id, country_name, country_name_es, country_name_en, geom FROM countries WHERE NOT (
  country_name_en ILIKE '%(EEZ)%' OR country_name_en ILIKE '%EEZ%' OR
  country_name_en ILIKE '%Exclusive Economic Zone%' OR country_name_en ILIKE '%Economic Zone%' OR
  country_name_en ILIKE '%(Contiguous Zone)%' OR country_name_en ILIKE '%Contiguous Zone%' OR
  country_name_en ILIKE '%contiguous area%' OR country_name_en ILIKE '%contiguous border%' OR
  country_name_en ILIKE '%(maritime)%' OR country_name_en ILIKE '%maritime%' OR
  country_name_en ILIKE '%Fisheries protection zone%' OR country_name_en ILIKE '%Fishing territory%' OR
  country_name ILIKE '%(EEZ)%' OR country_name ILIKE '%EEZ%' OR
  country_name ILIKE '%Exclusive Economic Zone%' OR country_name ILIKE '%Economic Zone%' OR
  country_name ILIKE '%(Contiguous Zone)%' OR country_name ILIKE '%Contiguous Zone%' OR
  country_name ILIKE '%contiguous area%' OR country_name ILIKE '%contiguous border%' OR
  country_name ILIKE '%(maritime)%' OR country_name ILIKE '%maritime%' OR
  country_name ILIKE '%Fisheries protection zone%' OR country_name ILIKE '%Fishing territory%'
 )" \
 -lco RFC7946=YES \
 -lco WRITE_BBOX=YES 2> /dev/null; then
  __logi "Successfully exported country boundaries to GeoJSON"
 else
  __loge "ERROR: Failed to export country boundaries"
  exit 1
 fi

 # Verify the file was created and is not empty
 if [[ ! -f "${OUTPUT_FILE}" ]] || [[ ! -s "${OUTPUT_FILE}" ]]; then
  __loge "ERROR: Output file was not created or is empty"
  exit 1
 fi

 # Get file size
 local FILE_SIZE
 FILE_SIZE=$(stat -c%s "${OUTPUT_FILE}" 2> /dev/null || echo "0")
 local FILE_SIZE_HUMAN
 FILE_SIZE_HUMAN=$(numfmt --to=iec-i --suffix=B "${FILE_SIZE}" 2> /dev/null || echo "${FILE_SIZE} bytes")

 __logi "Backup file size: ${FILE_SIZE_HUMAN}"
 __logi "Backup created successfully: ${OUTPUT_FILE}"

 # Validate GeoJSON structure
 __logd "Validating GeoJSON structure..."
 if command -v jq > /dev/null 2>&1; then
  if jq empty "${OUTPUT_FILE}" 2> /dev/null; then
   local FEATURES_COUNT
   FEATURES_COUNT=$(jq '.features | length' "${OUTPUT_FILE}" 2> /dev/null || echo "0")
   __logi "GeoJSON is valid with ${FEATURES_COUNT} features"
  else
   __logw "WARNING: GeoJSON validation failed (jq found errors)"
  fi
 else
  __logw "WARNING: jq not available, skipping GeoJSON validation"
 fi

 __log_finish
}

# Execute main
main "$@"
