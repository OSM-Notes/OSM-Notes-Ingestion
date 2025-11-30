#!/bin/bash

# Updates the current country and maritime boundaries, or
# insert new ones.
#
# When running in update mode (default), it automatically re-assigns countries
# for notes affected by boundary changes. This is much more efficient than
# re-processing all notes.
#
# To not remove all generated files, you can export this variable:
#   export CLEAN=false
#
# For contributing, please execute these commands before subimitting:
# * shellcheck -x -o all updateCountries.sh
# * shfmt -w -i 1 -sr -bn updateCountries.sh
#
# Author: Andres Gomez (AngocA)
# Version: 2025-11-30
VERSION="2025-11-30"

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
# CLEAN is now defined in etc/properties.sh, no need to declare it here

# Logger levels: TRACE, DEBUG, INFO, WARN, ERROR, FATAL.
declare LOG_LEVEL="${LOG_LEVEL:-ERROR}"

# Base directory for the project.
# Only set SCRIPT_BASE_DIRECTORY if not already defined (e.g., in test environment)
if [[ -z "${SCRIPT_BASE_DIRECTORY:-}" ]]; then
 declare SCRIPT_BASE_DIRECTORY
 SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." \
  &> /dev/null && pwd)"
 readonly SCRIPT_BASE_DIRECTORY
fi

# Loads the global properties.
# All database connections must be controlled by the properties file.
# If DBNAME is passed as environment variable (e.g., by processPlanetNotes.sh),
# it will be preserved. Otherwise, properties.sh will define it.
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh"

# Mask for the files and directories.
umask 0000

declare BASENAME
BASENAME=$(basename -s .sh "${0}")
readonly BASENAME
# Temporal directory for all files.
# IMPORTANT: Define TMP_DIR BEFORE loading processPlanetFunctions.sh
# because that script uses TMP_DIR in variable initialization
declare TMP_DIR
TMP_DIR=$(mktemp -d "/tmp/${BASENAME}_XXXXXX")
readonly TMP_DIR
chmod 777 "${TMP_DIR}"

# Load processPlanetFunctions.sh to get SQL file variables
# shellcheck disable=SC1091
if [[ -f "${SCRIPT_BASE_DIRECTORY}/bin/processPlanetFunctions.sh" ]]; then
 source "${SCRIPT_BASE_DIRECTORY}/bin/lib/processPlanetFunctions.sh"
fi
# Log file for output.
declare LOG_FILENAME
LOG_FILENAME="${TMP_DIR}/${BASENAME}.log"
readonly LOG_FILENAME

# Lock file for single execution.
declare LOCK
LOCK="/tmp/${BASENAME}.lock"
readonly LOCK

# Type of process to run in the script.
if [[ -z "${PROCESS_TYPE:-}" ]]; then
 declare -r PROCESS_TYPE=${1:-}
fi

# Location of the common functions.
declare -r QUERY_FILE="${TMP_DIR}/query"
declare -r UPDATE_COUNTRIES_FILE="${TMP_DIR}/countries"
declare -r UPDATE_MARITIMES_FILE="${TMP_DIR}/maritimes"

# Control variables for functionsProcess.sh
export ONLY_EXECUTION="no"

###########
# FUNCTIONS

# Load common functions
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/commonFunctions.sh"

# Load validation functions
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/validationFunctions.sh"

# Load error handling functions
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/errorHandlingFunctions.sh"

# Load process functions (includes retry functions and other variables)
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh"

# Overpass query files (needed for ID comparison)
# These are already declared in boundaryProcessingFunctions.sh, but we need them here
# Check if already declared (from boundaryProcessingFunctions.sh) before declaring
if [[ -z "${OVERPASS_COUNTRIES:-}" ]]; then
 declare -r OVERPASS_COUNTRIES="${SCRIPT_BASE_DIRECTORY}/overpass/countries.op"
fi
if [[ -z "${OVERPASS_MARITIMES:-}" ]]; then
 declare -r OVERPASS_MARITIMES="${SCRIPT_BASE_DIRECTORY}/overpass/maritimes.op"
fi

# Shows the help information.
function __show_help {
 echo "${BASENAME} version ${VERSION}"
 echo "Updates the country and maritime boundaries."
 echo
 echo "This script handles the complete lifecycle of countries and maritimes:"
 echo "  - Creates and manages table structures (--base mode drops and recreates)"
 echo "  - Downloads and processes geographic data"
 echo "  - Updates boundaries and verifies note locations"
 echo "  - Re-assigns countries for notes affected by boundary changes"
 echo
 echo "Usage:"
 echo "  ${BASENAME}.sh              # Update boundaries in normal mode"
 echo "  ${BASENAME}.sh --base       # Drop and recreate base tables"
 echo "  ${BASENAME}.sh --help       # Show this help message"
 echo "  ${BASENAME}.sh -h           # Show this help message"
 echo
 echo "Environment variables:"
 echo "  CLEAN=true|false            # Control cleanup of temporary files"
 echo
 echo "Written by: Andres Gomez (AngocA)"
 echo "OSM-LatAm, OSM-Colombia, MaptimeBogota."
 exit "${ERROR_HELP_MESSAGE}"
}

# Checks prerequisites to run the script.
function __checkPrereqs {
 __log_start
 if [[ "${PROCESS_TYPE}" != "" ]] && [[ "${PROCESS_TYPE}" != "--base" ]] \
  && [[ "${PROCESS_TYPE}" != "--help" ]] \
  && [[ "${PROCESS_TYPE}" != "-h" ]]; then
  echo "ERROR: Invalid parameter. It should be:"
  echo " * Empty string, nothing."
  echo " * --help"
  exit "${ERROR_INVALID_ARGUMENT}"
 fi

 # Validate prerequisites: commands, DB connection, and functions
 __checkPrereqsCommands
 __checkPrereqs_functions
 __log_finish
}

# Clean files and tables.
function __cleanPartial {
 __log_start
 if [[ -n "${CLEAN:-}" ]] && [[ "${CLEAN}" = true ]]; then
  rm -f "${QUERY_FILE}.*" "${COUNTRIES_FILE}" "${MARITIMES_FILE}"
  echo "DROP TABLE IF EXISTS import" | psql -d "${DBNAME}"
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
     echo "Failed command: "${ERROR_COMMAND}"
     echo "Exit code: "${ERROR_EXIT_CODE}"
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

# Drop existing country tables
function __dropCountryTables {
 __log_start
 __logi "=== DROPPING COUNTRY TABLES ==="
 __logd "Dropping countries table directly"
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 << 'EOF'
-- Drop country tables
DROP TABLE IF EXISTS countries CASCADE;
EOF
 __logi "=== COUNTRY TABLES DROPPED SUCCESSFULLY ==="
 __log_finish
}

# Creates country tables
function __createCountryTables {
 __log_start
 __logi "Creating country and maritime tables."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_26_CREATE_COUNTRY_TABLES}"

 # Create international waters table (for optimization)
 __logi "Creating international waters table..."
 if [[ -f "${POSTGRES_27_CREATE_INTERNATIONAL_WATERS:-}" ]]; then
  psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_27_CREATE_INTERNATIONAL_WATERS}" 2>&1 || __logw "Warning: Failed to create international waters table (may not exist yet)"
 else
  __logw "Warning: International waters table script not found, skipping"
 fi

 __log_finish
}

# Refreshes the materialized view for disputed and unclaimed areas.
# This should be called after countries are updated (monthly).
function __refreshDisputedAreasView {
 __log_start
 __logi "Refreshing materialized view for disputed and unclaimed areas..."

 # Check if materialized view exists
 local VIEW_EXISTS
 VIEW_EXISTS=$(psql -d "${DBNAME}" -Atq -c "SELECT EXISTS(SELECT 1 FROM pg_matviews WHERE schemaname = 'wms' AND matviewname = 'disputed_and_unclaimed_areas');" 2> /dev/null | tr -d ' ' || echo "f")

 if [[ "${VIEW_EXISTS}" != "t" ]]; then
  __logw "Materialized view wms.disputed_and_unclaimed_areas does not exist, skipping refresh"
  __logw "Run sql/wms/prepareDatabase.sql to create it"
  __log_finish
  return 0
 fi

 # Check if refresh SQL file exists
 local REFRESH_SQL
 REFRESH_SQL="${SCRIPT_BASE_DIRECTORY}/sql/wms/refreshDisputedAreasView.sql"

 if [[ ! -f "${REFRESH_SQL}" ]]; then
  __loge "Refresh SQL file not found: ${REFRESH_SQL}"
  __log_finish
  return 1
 fi

 __logi "Executing refresh (this may take several minutes)..."
 if psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${REFRESH_SQL}" > /dev/null 2>&1; then
  __logi "Materialized view refreshed successfully"
 else
  __loge "Failed to refresh materialized view"
  __log_finish
  return 1
 fi

 __log_finish
 return 0
}

# Performs maintenance operations on countries table after data is loaded.
# This includes REINDEX of spatial indexes and ANALYZE to update statistics.
function __maintainCountriesTable {
 __log_start
 __logi "Performing maintenance on countries table..."

 # Check if countries table exists and has data
 local COUNTRIES_COUNT
 COUNTRIES_COUNT=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM countries;" 2> /dev/null | grep -E '^[0-9]+$' | tail -1 || echo "0")

 if [[ "${COUNTRIES_COUNT:-0}" -eq 0 ]]; then
  __logw "Countries table is empty, skipping maintenance"
  __log_finish
  return 0
 fi

 __logi "Found ${COUNTRIES_COUNT} countries, performing maintenance..."

 # REINDEX the spatial index to ensure it's properly built
 __logi "Rebuilding spatial index (countries_spatial)..."
 if psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -c "REINDEX INDEX CONCURRENTLY countries_spatial;" 2> /dev/null; then
  __logi "Spatial index rebuilt successfully"
 else
  # If CONCURRENTLY fails (e.g., no concurrent access), try regular REINDEX
  __logw "CONCURRENTLY REINDEX failed, trying regular REINDEX..."
  if psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -c "REINDEX INDEX countries_spatial;" 2> /dev/null; then
   __logi "Spatial index rebuilt successfully"
  else
   __logw "REINDEX failed, but continuing..."
  fi
 fi

 # ANALYZE the table to update statistics
 __logi "Updating table statistics (ANALYZE)..."
 if psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -c "ANALYZE countries;" 2> /dev/null; then
  __logi "Table statistics updated successfully"
 else
  __logw "ANALYZE failed, but continuing..."
 fi

 # Create optimized indexes for bounding box queries
 __logi "Creating optimized spatial indexes for bounding boxes..."
 if [[ -f "${POSTGRES_26_OPTIMIZE_COUNTRY_INDEXES:-}" ]]; then
  if psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_26_OPTIMIZE_COUNTRY_INDEXES}" 2>&1; then
   __logi "Optimized spatial indexes created successfully"
  else
   __logw "Warning: Failed to create optimized indexes (may already exist)"
  fi
 else
  __logw "Warning: Optimized indexes script not found, skipping"
 fi

 # Show final index size
 local INDEX_SIZE
 INDEX_SIZE=$(psql -d "${DBNAME}" -Atq -c "SELECT pg_size_pretty(pg_relation_size('countries_spatial'));" 2> /dev/null | head -1 || echo "unknown")
 __logi "Spatial index size: ${INDEX_SIZE}"

 __log_finish
}

# Verifies that all expected countries were loaded and reloads missing ones.
# This addresses the issue where Overpass API limits may cause some countries
# to not be downloaded or imported correctly.
function __verifyAndReloadMissingCountries {
 __log_start
 __logi "=== VERIFYING COUNTRIES COMPLETENESS ==="

 # Check if COUNTRIES_BOUNDARY_IDS_FILE exists (created by __processCountries_impl)
 # The file is created in boundaryProcessingFunctions.sh and should be in TMP_DIR
 local EXPECTED_COUNTRIES_FILE
 if [[ -n "${COUNTRIES_BOUNDARY_IDS_FILE:-}" ]] && [[ -f "${COUNTRIES_BOUNDARY_IDS_FILE}" ]]; then
  EXPECTED_COUNTRIES_FILE="${COUNTRIES_BOUNDARY_IDS_FILE}"
 elif [[ -f "${TMP_DIR}/countries_boundary_ids.csv" ]]; then
  EXPECTED_COUNTRIES_FILE="${TMP_DIR}/countries_boundary_ids.csv"
 else
  __logw "Countries boundary IDs file not found. Skipping verification."
  __logw "Expected location: ${COUNTRIES_BOUNDARY_IDS_FILE:-${TMP_DIR}/countries_boundary_ids.csv}"
  __log_finish
  return 0
 fi
 if [[ ! -f "${EXPECTED_COUNTRIES_FILE}" ]]; then
  __logw "Expected countries file not found: ${EXPECTED_COUNTRIES_FILE}"
  __log_finish
  return 0
 fi

 # Get list of loaded country IDs from database
 local LOADED_COUNTRIES_FILE
 LOADED_COUNTRIES_FILE="${TMP_DIR}/loaded_countries.txt"
 psql -d "${DBNAME}" -Atq -c "SELECT country_id FROM countries ORDER BY country_id;" > "${LOADED_COUNTRIES_FILE}" 2> /dev/null || true

 if [[ ! -s "${LOADED_COUNTRIES_FILE}" ]]; then
  __logw "No countries found in database. Skipping verification."
  __log_finish
  return 0
 fi

 # Find missing countries
 local MISSING_COUNTRIES_FILE
 MISSING_COUNTRIES_FILE="${TMP_DIR}/missing_countries.txt"
 comm -23 <(sort -n "${EXPECTED_COUNTRIES_FILE}") <(sort -n "${LOADED_COUNTRIES_FILE}") > "${MISSING_COUNTRIES_FILE}" || true

 local MISSING_COUNT
 MISSING_COUNT=$(wc -l < "${MISSING_COUNTRIES_FILE}" 2> /dev/null | tr -d ' ' || echo "0")

 if [[ "${MISSING_COUNT}" -eq 0 ]] || [[ ! -s "${MISSING_COUNTRIES_FILE}" ]]; then
  __logi "All expected countries are loaded. No missing countries found."
  __log_finish
  return 0
 fi

 __logw "Found ${MISSING_COUNT} missing countries. Attempting to reload..."

 # Show first 10 missing countries for logging
 local SAMPLE_MISSING
 SAMPLE_MISSING=$(head -10 "${MISSING_COUNTRIES_FILE}" | tr '\n' ',' | sed 's/,$//')
 __logi "Sample missing countries: ${SAMPLE_MISSING}"

 # Reload missing countries using __processList
 # Create a temporary file with missing country IDs
 local MISSING_LIST_FILE
 MISSING_LIST_FILE="${TMP_DIR}/missing_countries_list.txt"
 cp "${MISSING_COUNTRIES_FILE}" "${MISSING_LIST_FILE}"

 __logi "Reloading ${MISSING_COUNT} missing countries..."
 # Invoke separately to handle errors properly
 __processList "${MISSING_LIST_FILE}"
 local RELOAD_RETURN_CODE=$?
 if [[ "${RELOAD_RETURN_CODE}" -eq 0 ]]; then
  __logi "Successfully reloaded missing countries"

  # Verify again after reload
  psql -d "${DBNAME}" -Atq -c "SELECT country_id FROM countries ORDER BY country_id;" > "${LOADED_COUNTRIES_FILE}" 2> /dev/null || true
  comm -23 <(sort -n "${EXPECTED_COUNTRIES_FILE}") <(sort -n "${LOADED_COUNTRIES_FILE}") > "${MISSING_COUNTRIES_FILE}" || true
  MISSING_COUNT=$(wc -l < "${MISSING_COUNTRIES_FILE}" 2> /dev/null | tr -d ' ' || echo "0")

  if [[ "${MISSING_COUNT}" -eq 0 ]]; then
   __logi "All countries successfully loaded after reload attempt"
  else
   __logw "Still ${MISSING_COUNT} countries missing after reload attempt"
   SAMPLE_MISSING=$(head -10 "${MISSING_COUNTRIES_FILE}" | tr '\n' ',' | sed 's/,$//')
   __logw "Remaining missing countries: ${SAMPLE_MISSING}"
  fi
 else
  __loge "Failed to reload missing countries (exit code: ${RELOAD_RETURN_CODE})"
  __log_finish
  return 1
 fi

 __logi "=== COUNTRIES VERIFICATION COMPLETED ==="
 __log_finish
 return 0
}

# Checks if boundaries (countries or maritimes) need to be updated by comparing
# IDs from Overpass query with repository backup.
# Returns 0 if update is needed, 1 if backup matches.
function __checkBoundariesUpdateNeeded {
 __log_start
 local TYPE="${1}"                # "countries" or "maritimes"
 local OVERPASS_QUERY_FILE="${2}" # Overpass query file (.op)
 local BACKUP_FILE="${3}"         # Backup GeoJSON file

 __logd "Checking if ${TYPE} update is needed..."

 # Determine backup file location if not provided
 if [[ -z "${BACKUP_FILE}" ]]; then
  if [[ "${TYPE}" == "countries" ]]; then
   BACKUP_FILE="${SCRIPT_BASE_DIRECTORY}/data/countries.geojson"
  elif [[ "${TYPE}" == "maritimes" ]]; then
   BACKUP_FILE="${SCRIPT_BASE_DIRECTORY}/data/maritimes.geojson"
  else
   __loge "ERROR: Unknown type: ${TYPE}"
   __log_finish
   return 0
  fi
 fi

 # If backup doesn't exist, update is needed
 if [[ ! -f "${BACKUP_FILE}" ]] || [[ ! -s "${BACKUP_FILE}" ]]; then
  __logi "No backup file found for ${TYPE}, update needed"
  __log_finish
  return 0
 fi

 # Download IDs from Overpass first
 local TMP_IDS_FILE
 TMP_IDS_FILE="${TMP_DIR}/${TYPE}_ids_from_overpass.txt"
 __logd "Downloading ${TYPE} IDs from Overpass..."
 set +e
 if [[ -n "${DOWNLOAD_USER_AGENT:-}" ]]; then
  wget -O "${TMP_IDS_FILE}" --header="User-Agent: ${DOWNLOAD_USER_AGENT}" --post-file="${OVERPASS_QUERY_FILE}" \
   "${OVERPASS_INTERPRETER}" 2> /dev/null
 else
  wget -O "${TMP_IDS_FILE}" --post-file="${OVERPASS_QUERY_FILE}" \
   "${OVERPASS_INTERPRETER}" 2> /dev/null
 fi
 local RET=${?}
 set -e

 if [[ "${RET}" -ne 0 ]] || [[ ! -s "${TMP_IDS_FILE}" ]]; then
  __logw "Failed to download ${TYPE} IDs from Overpass, assuming update needed"
  __log_finish
  return 0
 fi

 # Remove header and sort
 tail -n +2 "${TMP_IDS_FILE}" 2> /dev/null | sort -n > "${TMP_IDS_FILE}.sorted" || true
 mv "${TMP_IDS_FILE}.sorted" "${TMP_IDS_FILE}"

 # Add special areas for countries (same as in __processCountries_impl)
 if [[ "${TYPE}" == "countries" ]]; then
  {
   echo "1703814"  # Gaza Strip
   echo "1803010"  # Judea and Samaria
   echo "12931402" # Bhutan - China dispute
   echo "192797"   # Ilemi Triangle
   echo "12940096" # Neutral zone Burkina Faso - Benin
   echo "3335661"  # Bir Tawil
   echo "37848"    # Jungholz, Austria
   echo "3394112"  # British Antarctic
   echo "3394110"  # Argentine Antarctic
   echo "3394115"  # Chilean Antarctic
   echo "3394113"  # Ross dependency
   echo "3394111"  # Australian Antarctic
   echo "3394114"  # Adelia Land
   echo "3245621"  # Queen Maud Land
   echo "2955118"  # Peter I Island
   echo "2186646"  # Antarctica continent
  } >> "${TMP_IDS_FILE}"
  sort -n "${TMP_IDS_FILE}" > "${TMP_IDS_FILE}.sorted"
  mv "${TMP_IDS_FILE}.sorted" "${TMP_IDS_FILE}"
 fi

 # Extract IDs from backup GeoJSON
 local BACKUP_IDS_FILE
 BACKUP_IDS_FILE="${TMP_DIR}/${TYPE}_ids_from_backup.txt"
 if command -v jq > /dev/null 2>&1; then
  jq -r '.features[].properties.country_id' "${BACKUP_FILE}" 2> /dev/null \
   | sort -n > "${BACKUP_IDS_FILE}" || true
 else
  # Fallback: use ogrinfo
  ogrinfo -al -so "${BACKUP_FILE}" 2> /dev/null \
   | grep -E '^country_id \(' | awk '{print $3}' | sort -n > "${BACKUP_IDS_FILE}" || true
 fi

 # Compare counts
 local OVERPASS_COUNT
 OVERPASS_COUNT=$(wc -l < "${TMP_IDS_FILE}" 2> /dev/null | tr -d ' ' || echo "0")
 local BACKUP_COUNT
 BACKUP_COUNT=$(wc -l < "${BACKUP_IDS_FILE}" 2> /dev/null | tr -d ' ' || echo "0")

 __logd "Overpass ${TYPE} IDs: ${OVERPASS_COUNT}"
 __logd "Backup ${TYPE} IDs: ${BACKUP_COUNT}"

 if [[ "${OVERPASS_COUNT}" -eq 0 ]]; then
  __logw "No IDs found from Overpass, update needed"
  __log_finish
  return 0
 fi

 if [[ "${OVERPASS_COUNT}" -ne "${BACKUP_COUNT}" ]]; then
  __logi "${TYPE} ID counts differ (Overpass: ${OVERPASS_COUNT}, Backup: ${BACKUP_COUNT}), update needed"
  __log_finish
  return 0
 fi

 # Compare IDs if counts match
 if ! diff -q "${TMP_IDS_FILE}" "${BACKUP_IDS_FILE}" > /dev/null 2>&1; then
  __logi "${TYPE} ID lists differ, update needed"
  __log_finish
  return 0
 fi

 __logi "${TYPE} IDs match backup, no update needed"
 __log_finish
 return 1
}

# Checks if maritime boundaries need to be updated by comparing current
# database state with the repository backup.
# Returns 0 if update is needed, 1 if backup matches current state.
# DEPRECATED: Use __checkBoundariesUpdateNeeded instead.
function __checkMaritimesUpdateNeeded {
 __log_start
 __logd "Checking if maritime boundaries update is needed..."

 # Determine backup file location
 local REPO_MARITIMES_BACKUP
 REPO_MARITIMES_BACKUP="${SCRIPT_BASE_DIRECTORY}/data/maritimes.geojson"

 # If backup doesn't exist, update is needed
 if [[ ! -f "${REPO_MARITIMES_BACKUP}" ]] || [[ ! -s "${REPO_MARITIMES_BACKUP}" ]]; then
  __logi "No backup file found, update needed"
  __log_finish
  return 0
 fi

 # Get current maritime IDs from database
 local CURRENT_MARITIMES_FILE
 CURRENT_MARITIMES_FILE="${TMP_DIR}/current_maritimes_ids.txt"
 psql -d "${DBNAME}" -Atq -c \
  "SELECT country_id FROM countries WHERE country_name_en LIKE '%(EEZ)%' OR country_name_en LIKE '%(Contiguous Zone)%' OR country_name_en LIKE '%(maritime)%' OR country_name LIKE '%(EEZ)%' OR country_name LIKE '%(Contiguous Zone)%' OR country_name LIKE '%(maritime)%' ORDER BY country_id;" \
  > "${CURRENT_MARITIMES_FILE}" 2> /dev/null || true

 # Extract IDs from backup GeoJSON (if jq is available)
 local BACKUP_MARITIMES_FILE
 BACKUP_MARITIMES_FILE="${TMP_DIR}/backup_maritimes_ids.txt"
 if command -v jq > /dev/null 2>&1; then
  jq -r '.features[].properties.country_id' "${REPO_MARITIMES_BACKUP}" 2> /dev/null \
   | sort -n > "${BACKUP_MARITIMES_FILE}" || true
 else
  # Fallback: use ogrinfo to get IDs
  ogrinfo -al -so "${REPO_MARITIMES_BACKUP}" 2> /dev/null \
   | grep -E '^country_id \(' | awk '{print $3}' | sort -n > "${BACKUP_MARITIMES_FILE}" || true
 fi

 # Compare counts
 local CURRENT_COUNT
 CURRENT_COUNT=$(wc -l < "${CURRENT_MARITIMES_FILE}" 2> /dev/null | tr -d ' ' || echo "0")
 local BACKUP_COUNT
 BACKUP_COUNT=$(wc -l < "${BACKUP_MARITIMES_FILE}" 2> /dev/null | tr -d ' ' || echo "0")

 __logd "Current maritimes in database: ${CURRENT_COUNT}"
 __logd "Maritimes in backup: ${BACKUP_COUNT}"

 # If counts differ, update is needed
 if [[ "${CURRENT_COUNT}" -ne "${BACKUP_COUNT}" ]]; then
  __logi "Maritime count differs (current: ${CURRENT_COUNT}, backup: ${BACKUP_COUNT}), update needed"
  __log_finish
  return 0
 fi

 # Compare IDs if counts match
 if [[ "${CURRENT_COUNT}" -gt 0 ]]; then
  if ! diff -q "${CURRENT_MARITIMES_FILE}" "${BACKUP_MARITIMES_FILE}" > /dev/null 2>&1; then
   __logi "Maritime IDs differ, update needed"
   __log_finish
   return 0
  fi
 fi

 __logi "Maritime boundaries match backup, no update needed"
 __log_finish
 return 1
}

# Re-assigns countries only for notes affected by geometry changes.
# This is much more efficient than re-processing all notes.
# Only processes notes within bounding boxes of countries that were updated.
function __reassignAffectedNotes {
 __log_start
 __logi "Re-assigning countries for notes affected by boundary changes..."

 # Ensure get_country function exists before using it
 # functionsProcess.sh is already loaded at the top of the script
 local FUNCTION_EXISTS
 FUNCTION_EXISTS=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM pg_proc WHERE proname = 'get_country' AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');" 2> /dev/null | grep -E '^[0-9]+$' | tail -1 || echo "0")

 if [[ "${FUNCTION_EXISTS:-0}" -eq "0" ]]; then
  __logw "get_country function not found, creating it..."
  __createFunctionToGetCountry
  __logi "get_country function created successfully"
 fi

 # Get list of countries that were updated
 local -r UPDATED_COUNTRIES=$(psql -d "${DBNAME}" -Atq -c "
   SELECT country_id
   FROM countries
   WHERE updated = TRUE;
 ")

 if [[ -z "${UPDATED_COUNTRIES}" ]]; then
  __logi "No countries were updated, skipping re-assignment"
  __log_finish
  return 0
 fi

 local -r COUNT=$(echo "${UPDATED_COUNTRIES}" | wc -l)
 __logi "Found ${COUNT} countries with updated geometries"

 # Re-assign countries for notes within bounding boxes of updated countries
 # This uses the optimized get_country function which checks current country first
 __logi "Updating notes within affected areas..."
 # Validate SQL file exists
 if [[ ! -f "${POSTGRES_36_REASSIGN_AFFECTED_NOTES}" ]]; then
  __loge "ERROR: SQL file does not exist: ${POSTGRES_36_REASSIGN_AFFECTED_NOTES}"
  __log_finish
  return 1
 fi
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_36_REASSIGN_AFFECTED_NOTES}"

 # Show statistics
 # Note: Statistics about country changes are no longer tracked in tries table
 # This information can be obtained by comparing notes.id_country before and after update
 __logi "Country assignment completed"

 # Mark countries as processed
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -c "
   UPDATE countries SET updated = FALSE WHERE updated = TRUE;
 "

 __logi "Re-assignment completed"
 __log_finish
}

######
# MAIN

function main() {
 # Enable bash debug mode if BASH_DEBUG environment variable is set
 if [[ "${BASH_DEBUG:-}" == "true" ]] || [[ "${BASH_DEBUG:-}" == "1" ]]; then
  set -xv
 fi

 __log_start
 __logi "Preparing environment."
 __logd "Output saved at: ${TMP_DIR}."
 __logi "Processing: ${PROCESS_TYPE}."

 # Handle help first, before checking prerequisites
 if [[ "${PROCESS_TYPE}" == "-h" ]] \
  || [[ "${PROCESS_TYPE}" == "--help" ]]; then
  __show_help
  exit "${ERROR_HELP_MESSAGE}"
 fi

 # Checks the prerequisities. It could terminate the process.
 __checkPrereqs

 __logw "Starting process."

 # Sets the trap in case of any signal.
 __trapOn
 exec 7> "${LOCK}"
 __logw "Validating single execution."
 ONLY_EXECUTION="no"
 if ! flock -n 7; then
  __loge "Another instance of ${BASENAME} is already running."
  __loge "Lock file: ${LOCK}"
  if [[ -f "${LOCK}" ]]; then
   __loge "Lock file contents:"
   cat "${LOCK}" >&2 || true
  fi
  exit 1
 fi
 ONLY_EXECUTION="yes"

 # Write lock file content with useful debugging information
 cat > "${LOCK}" << EOF
PID: $$
Process: ${BASENAME}
Started: $(date '+%Y-%m-%d %H:%M:%S')
Temporary directory: ${TMP_DIR}
Process type: ${PROCESS_TYPE}
Main script: ${0}
EOF
 __logd "Lock file content written to: ${LOCK}"

 if [[ "${PROCESS_TYPE}" == "--base" ]]; then
  __logi "Running in base mode - dropping and recreating tables for consistency"

  # Drop and recreate country tables for consistency with processPlanetNotes.sh
  __logi "Dropping existing country and maritime tables..."
  __dropCountryTables

  __logi "Creating country and maritime tables..."
  __createCountryTables

  # Process countries and maritimes data
  __logi "Processing countries and maritimes data..."
  __processCountries
  __verifyAndReloadMissingCountries # Verify and reload any missing countries (may be due to Overpass limits)
  __processMaritimes
  __maintainCountriesTable
  __refreshDisputedAreasView
  __cleanPartial
  # Note: __getLocationNotes is called by the main process (processAPINotes.sh)
  # after countries are loaded, not here
 else
  __logi "Running in update mode - processing existing data only"
  STMT="UPDATE countries SET updated = TRUE"
  echo "${STMT}" | psql -d "${DBNAME}" -v ON_ERROR_STOP=1

  # Check if countries update is needed before processing
  if __checkBoundariesUpdateNeeded "countries" "${OVERPASS_COUNTRIES}" "${SCRIPT_BASE_DIRECTORY}/data/countries.geojson"; then
   __logi "Country boundaries update needed, processing..."
   # Force download from Overpass to get updated geometries (don't use backup)
   export FORCE_OVERPASS_DOWNLOAD="true"
   __processCountries
   unset FORCE_OVERPASS_DOWNLOAD
   __verifyAndReloadMissingCountries # Verify and reload any missing countries (may be due to Overpass limits)
  else
   __logi "Country boundaries are up to date, skipping download"
  fi

  # Check if maritimes update is needed before processing
  if __checkBoundariesUpdateNeeded "maritimes" "${OVERPASS_MARITIMES}" "${SCRIPT_BASE_DIRECTORY}/data/maritimes.geojson"; then
   __logi "Maritime boundaries update needed, processing..."
   # Force download from Overpass to get updated geometries (don't use backup)
   export FORCE_OVERPASS_DOWNLOAD="true"
   __processMaritimes
   unset FORCE_OVERPASS_DOWNLOAD
  else
   __logi "Maritime boundaries are up to date, skipping download"
  fi

  __maintainCountriesTable
  __refreshDisputedAreasView
  __cleanPartial

  # Re-assign countries for notes affected by boundary changes
  # This is automatic and much more efficient than re-processing all notes
  __reassignAffectedNotes
 fi
 __log_finish
}

# Only execute main if this script is being run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
 # Check if running as subprocess
 # When called from processPlanetNotes.sh, we write to a separate log file
 if [[ -n "${UPDATE_COUNTRIES_AS_SUBPROCESS:-}" ]] && [[ -n "${UPDATE_COUNTRIES_LOG_FILE:-}" ]]; then
  # Running as subprocess - write to specified log file
  export LOG_FILE="${UPDATE_COUNTRIES_LOG_FILE}"
  {
   __start_logger
   main
  } >> "${UPDATE_COUNTRIES_LOG_FILE}" 2>&1
 elif [[ ! -t 1 ]]; then
  # Not a terminal - redirect to log file
  export LOG_FILE="${LOG_FILENAME}"
  {
   __start_logger
   main
  } >> "${LOG_FILENAME}" 2>&1
 else
  # Running in terminal - use stdout
  __start_logger
  main
 fi
fi
