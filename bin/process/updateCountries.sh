#!/bin/bash

# Update Countries - Download and update country/maritime boundaries
# Downloads boundaries from Overpass API and updates database, automatically
# re-assigning countries for notes affected by boundary changes
#
# For detailed documentation, see:
#   - docs/Documentation.md (system overview, boundary processing)
#   - docs/Country_Assignment_2D_Grid.md (country assignment strategy)
#   - docs/Capital_Validation_Explanation.md (boundary validation)
#   - bin/README.md (usage examples, parameters)
#
# Quick Reference:
#   Usage: ./updateCountries.sh [--base]
#   --base: Recreate tables mode (drops and recreates boundary tables)
#   (no flag): Update mode (updates existing boundaries, re-assigns affected notes)
#   Examples: export LOG_LEVEL=DEBUG ; ./updateCountries.sh
#
# Error Codes: See docs/Troubleshooting_Guide.md for complete list and solutions
#   1) Help message displayed
#   238) Previous execution failed (see docs/Troubleshooting_Guide.md#failed-execution)
#   241) Library or utility missing
#   242) Invalid argument
#   243) Logger utility is missing
#   249) Error downloading boundary
#   250) Error GeoJSON conversion
#   255) General error
#
# Modes:
#   --base: Recreate tables (drops and recreates boundary tables from scratch)
#   (update): Update mode (updates existing boundaries, efficiently re-assigns only affected notes)
#
# Performance: See docs/Country_Assignment_2D_Grid.md#performance
#   - Update mode: Only re-assigns notes affected by boundary changes (much faster)
#   - Base mode: Full reload of all boundaries
#
# Dependencies: PostgreSQL, PostGIS, Overpass API, ogr2ogr, lib/osm-common/
#
# For contributing: shellcheck -x -o all updateCountries.sh && shfmt -w -i 1 -sr -bn updateCountries.sh
#
# Author: Andres Gomez (AngocA)
# Version: 2025-12-11
VERSION="2025-12-11"

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

# CRITICAL: Unset LOG_FILE before defining our own log file to prevent
# inheriting the parent process's log file (e.g., from processPlanetNotes.sh).
# This must be done BEFORE loading commonFunctions.sh which loads bash_logger.sh,
# because bash_logger.sh auto-initializes if LOG_FILE is already set.
unset LOG_FILE

declare BASENAME
BASENAME=$(basename -s .sh "${0}")
readonly BASENAME

# Set PostgreSQL application name for monitoring
# This allows monitoring tools to identify which script is using the database
export PGAPPNAME="${BASENAME}"

# Temporal directory for all files.
# IMPORTANT: Define TMP_DIR BEFORE loading processPlanetFunctions.sh
# because that script uses TMP_DIR in variable initialization
# Always create our own TMP_DIR for independent execution (like processAPINotes and processPlanetNotes)
# When running as subprocess, we use our own TMP_DIR and our own log file for complete independence
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
# Always use our own log file in our TMP_DIR (like processAPINotes and processPlanetNotes)
# This ensures complete independence and log separation
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
  echo "DROP TABLE IF EXISTS import" | PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}"
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
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 << 'EOF'
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
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_26_CREATE_COUNTRY_TABLES}"

 # Create international waters table (for optimization)
 __logi "Creating international waters table..."
 if [[ -f "${POSTGRES_27_CREATE_INTERNATIONAL_WATERS:-}" ]]; then
  PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_27_CREATE_INTERNATIONAL_WATERS}" 2>&1 || __logw "Warning: Failed to create international waters table (may not exist yet)"
 else
  __logw "Warning: International waters table script not found, skipping"
 fi

 __log_finish
}

# Calculates and populates international waters areas.
# This should be called after countries and maritimes are processed.
function __calculateInternationalWaters {
 __log_start
 __logi "Calculating international waters areas..."

 # Check if international waters table exists
 local TABLE_EXISTS
 TABLE_EXISTS=$(PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -Atq -c "SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'international_waters');" 2> /dev/null | tr -d ' ' || echo "f")

 if [[ "${TABLE_EXISTS}" != "t" ]]; then
  __logw "International waters table does not exist, skipping calculation"
  __logw "This is normal if processPlanetNotes_27_createInternationalWatersTable.sql was not run"
  __log_finish
  return 0
 fi

 # Check if calculation SQL file exists
 if [[ ! -f "${POSTGRES_28_ADD_INTERNATIONAL_WATERS:-}" ]]; then
  __logw "International waters calculation script not found: ${POSTGRES_28_ADD_INTERNATIONAL_WATERS:-}"
  __logw "Skipping international waters calculation"
  __log_finish
  return 0
 fi

 __logi "Executing international waters calculation (this may take several minutes)..."
 # Use ON_ERROR_STOP=0 to allow the script to continue even if international waters calculation fails
 # This is especially important in hybrid/mock mode where test geometries may cause PostGIS errors
 local SQL_OUTPUT
 SQL_OUTPUT=$(PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=0 -f "${POSTGRES_28_ADD_INTERNATIONAL_WATERS}" 2>&1)
 local SQL_EXIT_CODE=$?

 if echo "${SQL_OUTPUT}" | grep -q "ERROR"; then
  __logw "WARNING: International waters calculation encountered errors (this may be expected in test/hybrid mode)"
  __logw "Continuing without international waters data - this is acceptable for testing"
  __log_finish
  return 0
 elif [[ ${SQL_EXIT_CODE} -eq 0 ]]; then
  __logi "International waters calculation completed successfully"
  __log_finish
  return 0
 else
  __logw "WARNING: International waters calculation failed (non-critical, continuing)"
  __log_finish
  return 0
 fi
}

# Refreshes the materialized view for disputed and unclaimed areas.
# This should be called after countries are updated (monthly).
function __refreshDisputedAreasView {
 __log_start
 __logi "Refreshing materialized view for disputed and unclaimed areas..."

 # Check if materialized view exists
 local VIEW_EXISTS
 VIEW_EXISTS=$(PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -Atq -c "SELECT EXISTS(SELECT 1 FROM pg_matviews WHERE schemaname = 'wms' AND matviewname = 'disputed_and_unclaimed_areas');" 2> /dev/null | tr -d ' ' || echo "f")

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
 if PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${REFRESH_SQL}" > /dev/null 2>&1; then
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
 COUNTRIES_COUNT=$(PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM countries;" 2> /dev/null | grep -E '^[0-9]+$' | tail -1 || echo "0")

 if [[ "${COUNTRIES_COUNT:-0}" -eq 0 ]]; then
  __logw "Countries table is empty, skipping maintenance"
  __log_finish
  return 0
 fi

 __logi "Found ${COUNTRIES_COUNT} countries, performing maintenance..."

 # REINDEX the spatial index to ensure it's properly built
 __logi "Rebuilding spatial index (countries_spatial)..."
 if PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -c "REINDEX INDEX CONCURRENTLY countries_spatial;" 2> /dev/null; then
  __logi "Spatial index rebuilt successfully"
 else
  # If CONCURRENTLY fails (e.g., no concurrent access), try regular REINDEX
  __logw "CONCURRENTLY REINDEX failed, trying regular REINDEX..."
  if PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -c "REINDEX INDEX countries_spatial;" 2> /dev/null; then
   __logi "Spatial index rebuilt successfully"
  else
   __logw "REINDEX failed, but continuing..."
  fi
 fi

 # ANALYZE the table to update statistics
 __logi "Updating table statistics (ANALYZE)..."
 if PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -c "ANALYZE countries;" 2> /dev/null; then
  __logi "Table statistics updated successfully"
 else
  __logw "ANALYZE failed, but continuing..."
 fi

 # Create optimized indexes for bounding box queries
 __logi "Creating optimized spatial indexes for bounding boxes..."
 if [[ -f "${POSTGRES_26_OPTIMIZE_COUNTRY_INDEXES:-}" ]]; then
  if PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_26_OPTIMIZE_COUNTRY_INDEXES}" 2>&1; then
   __logi "Optimized spatial indexes created successfully"
  else
   __logw "Warning: Failed to create optimized indexes (may already exist)"
  fi
 else
  __logw "Warning: Optimized indexes script not found, skipping"
 fi

 # Show final index size
 local INDEX_SIZE
 INDEX_SIZE=$(PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -Atq -c "SELECT pg_size_pretty(pg_relation_size('countries_spatial'));" 2> /dev/null | head -1 || echo "unknown")
 __logi "Spatial index size: ${INDEX_SIZE}"

 __log_finish
}

# Shows a summary of failed boundary downloads (countries and maritimes)
# at the end of execution with IDs and country names.
function __showFailedBoundariesSummary {
 __log_start
 __logi "=== SUMMARY OF FAILED BOUNDARY DOWNLOADS ==="

 local FAILED_BOUNDARIES_FILE="${TMP_DIR}/failed_boundaries.txt"
 local FAILED_COUNT=0
 local FAILED_IDS=()

 # Check if failed_boundaries.txt exists
 if [[ -f "${FAILED_BOUNDARIES_FILE}" ]] && [[ -s "${FAILED_BOUNDARIES_FILE}" ]]; then
  FAILED_COUNT=$(wc -l < "${FAILED_BOUNDARIES_FILE}" 2> /dev/null | tr -d ' ' || echo "0")
  if [[ "${FAILED_COUNT}" -gt 0 ]]; then
   # Read failed IDs into array
   while IFS= read -r FAILED_ID; do
    if [[ -n "${FAILED_ID}" ]] && [[ "${FAILED_ID}" =~ ^[0-9]+$ ]]; then
     FAILED_IDS+=("${FAILED_ID}")
    fi
   done < "${FAILED_BOUNDARIES_FILE}"

   __logw "Found ${FAILED_COUNT} boundary/boundaries that failed to download:"

   # Query database for country names
   if [[ ${#FAILED_IDS[@]} -gt 0 ]]; then
    # Build SQL query to get country names
    local IDS_LIST
    IDS_LIST=$(
     IFS=','
     echo "${FAILED_IDS[*]}"
    )
    local QUERY_RESULT
    QUERY_RESULT=$(PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -Atq -c "SELECT country_id, COALESCE(country_name_en, country_name, 'Unknown') FROM countries WHERE country_id IN (${IDS_LIST}) ORDER BY country_id;" 2> /dev/null || echo "")

    if [[ -n "${QUERY_RESULT}" ]]; then
     # Display failed boundaries with names
     while IFS='|' read -r ID NAME; do
      if [[ -n "${ID}" ]] && [[ -n "${NAME}" ]]; then
       __logw "  - ID: ${ID} - ${NAME}"
      else
       __logw "  - ID: ${ID} - (not found in database)"
      fi
     done <<< "${QUERY_RESULT}"

     # Check for IDs not in database
     local FOUND_IDS
     FOUND_IDS=$(echo "${QUERY_RESULT}" | cut -d'|' -f1 | tr '\n' ' ')
     for ID in "${FAILED_IDS[@]}"; do
      if ! echo "${FOUND_IDS}" | grep -q "\b${ID}\b"; then
       __logw "  - ID: ${ID} - (not found in database, download failed completely)"
      fi
     done
    else
     # If query failed, just show IDs
     for ID in "${FAILED_IDS[@]}"; do
      __logw "  - ID: ${ID}"
     done
    fi

    __logw ""
    __logw "Failed boundaries file: ${FAILED_BOUNDARIES_FILE}"
    __logw "You can retry downloading these boundaries manually or run the script again."
   fi
  else
   __logi "No failed boundaries found - all downloads completed successfully"
  fi
 else
  __logi "No failed boundaries file found - all downloads completed successfully"
 fi

 __logi "=== END OF FAILED BOUNDARIES SUMMARY ==="
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
  curl -s -o "${TMP_IDS_FILE}" -H "User-Agent: ${DOWNLOAD_USER_AGENT}" \
   --data-binary "@${OVERPASS_QUERY_FILE}" \
   "${OVERPASS_INTERPRETER}" 2> /dev/null
 else
  curl -s -H "User-Agent: ${DOWNLOAD_USER_AGENT:-OSM-Notes-Ingestion/1.0}" -o "${TMP_IDS_FILE}" --data-binary "@${OVERPASS_QUERY_FILE}" \
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
 # Use comprehensive patterns to identify all maritime boundaries
 local CURRENT_MARITIMES_FILE
 CURRENT_MARITIMES_FILE="${TMP_DIR}/current_maritimes_ids.txt"
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -Atq -c \
  "SELECT country_id FROM countries WHERE (
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
  ) ORDER BY country_id;" \
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

# Marks countries that failed to update during the update process.
# Countries that remain with updated=TRUE after processing are marked as failed.
function __markFailedCountryUpdates {
 __log_start
 __logi "Marking countries that failed to update..."

 # Mark countries that failed (still have updated=TRUE) as update_failed=TRUE
 # and record the last update attempt timestamp
 local FAILED_COUNT
 FAILED_COUNT=$(PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -Atq -c "
   UPDATE countries
   SET update_failed = TRUE,
       last_update_attempt = CURRENT_TIMESTAMP
   WHERE updated = TRUE
   RETURNING country_id;
 " 2> /dev/null | wc -l | tr -d ' ' || echo "0")

 if [[ "${FAILED_COUNT}" -gt 0 ]]; then
  __logw "Marked ${FAILED_COUNT} countries as failed to update"
  # Show sample of failed countries
  local SAMPLE_FAILED
  SAMPLE_FAILED=$(PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -Atq -c "
    SELECT country_id || ':' || COALESCE(country_name_en, country_name, 'Unknown')
    FROM countries
    WHERE update_failed = TRUE
    ORDER BY country_id
    LIMIT 10;
  " 2> /dev/null | tr '\n' ',' | sed 's/,$//' || echo "")
  if [[ -n "${SAMPLE_FAILED}" ]]; then
   __logw "Sample failed countries: ${SAMPLE_FAILED}"
  fi
 else
  __logi "No countries failed to update"
 fi

 # Mark successfully updated countries as update_failed=FALSE
 # (countries that were processed and now have updated=FALSE)
 local SUCCESS_COUNT
 SUCCESS_COUNT=$(PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -Atq -c "
   UPDATE countries
   SET update_failed = FALSE,
       last_update_attempt = CURRENT_TIMESTAMP
   WHERE updated = FALSE
     AND (update_failed IS NULL OR update_failed = TRUE);
 " 2> /dev/null | wc -l | tr -d ' ' || echo "0")

 if [[ "${SUCCESS_COUNT}" -gt 0 ]]; then
  __logi "Marked ${SUCCESS_COUNT} countries as successfully updated"
 fi

 __log_finish
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
 FUNCTION_EXISTS=$(PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM pg_proc WHERE proname = 'get_country' AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');" 2> /dev/null | grep -E '^[0-9]+$' | tail -1 || echo "0")

 if [[ "${FUNCTION_EXISTS:-0}" -eq "0" ]]; then
  __logw "get_country function not found, creating it..."
  __createFunctionToGetCountry
  __logi "get_country function created successfully"
 fi

 # Get list of countries that were updated
 local -r UPDATED_COUNTRIES=$(PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -Atq -c "
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
 # Process in batches with partial commits (default: 1000 notes per batch)
 local BATCH_SIZE="${REASSIGN_NOTES_BATCH_SIZE:-1000}"
 __logi "Updating notes within affected areas (batch size: ${BATCH_SIZE})..."

 # Check if batch SQL file exists (new approach with commits)
 local BATCH_SQL_FILE="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_36_reassignAffectedNotes_batch.sql"
 if [[ -f "${BATCH_SQL_FILE}" ]]; then
  # Process in batches with commits after each batch
  local TOTAL_PROCESSED=0
  local BATCH_NUM=0
  local PROCESSED_COUNT=0

  # Get initial count of affected notes
  local TOTAL_AFFECTED
  TOTAL_AFFECTED=$(PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -Atq -c "
   SELECT COUNT(*)
   FROM notes n
   WHERE EXISTS (
     SELECT 1
     FROM countries c
     WHERE c.updated = TRUE
       AND ST_Intersects(
         ST_MakeEnvelope(
           ST_XMin(c.geom), ST_YMin(c.geom),
           ST_XMax(c.geom), ST_YMax(c.geom),
           4326
         ),
         ST_SetSRID(ST_MakePoint(n.longitude, n.latitude), 4326)
       )
   );
  " 2> /dev/null || echo "0")

  if [[ "${TOTAL_AFFECTED}" -eq "0" ]]; then
   __logi "No notes affected by boundary changes"
  else
   __logi "Total notes to process: ${TOTAL_AFFECTED}"

   # Process batches until no more notes
   # Safety limit to prevent infinite loops (max 1 million batches)
   local MAX_BATCHES=1000000
   while [[ ${BATCH_NUM} -lt ${MAX_BATCHES} ]]; do
    BATCH_NUM=$((BATCH_NUM + 1))

    # Execute batch SQL and capture processed count from RAISE NOTICE
    local PSQL_OUTPUT
    PSQL_OUTPUT=$(PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -c "SET app.batch_size = '${BATCH_SIZE}';" -f "${BATCH_SQL_FILE}" 2>&1)
    local PSQL_EXIT_CODE=$?

    # Check if psql command failed
    if [[ ${PSQL_EXIT_CODE} -ne 0 ]]; then
     __loge "Failed to execute batch SQL (exit code: ${PSQL_EXIT_CODE})"
     __loge "psql output: ${PSQL_OUTPUT}"
     __log_finish
     return 1
    fi

    # Extract processed count from RAISE NOTICE output
    # Format: "NOTICE: PROCESSED_COUNT:1234"
    PROCESSED_COUNT=$(echo "${PSQL_OUTPUT}" | grep -E 'PROCESSED_COUNT:[0-9]+' | sed -E 's/.*PROCESSED_COUNT:([0-9]+).*/\1/' || echo "0")

    # Validate that PROCESSED_COUNT is a number
    if ! [[ "${PROCESSED_COUNT}" =~ ^[0-9]+$ ]]; then
     __logw "Could not parse processed count from output, assuming 0"
     PROCESSED_COUNT=0
    fi

    if [[ "${PROCESSED_COUNT}" -eq "0" ]]; then
     break
    fi

    TOTAL_PROCESSED=$((TOTAL_PROCESSED + PROCESSED_COUNT))
    __logi "Batch ${BATCH_NUM}: Processed ${PROCESSED_COUNT} notes (total: ${TOTAL_PROCESSED}/${TOTAL_AFFECTED})"
   done

   # Check if we hit the safety limit
   if [[ ${BATCH_NUM} -ge ${MAX_BATCHES} ]]; then
    __loge "Reached maximum batch limit (${MAX_BATCHES}), stopping to prevent infinite loop"
    __log_finish
    return 1
   fi

   __logi "Completed: Processed ${TOTAL_PROCESSED} notes in ${BATCH_NUM} batches"
  fi
 else
  # Fallback to old single-transaction approach
  __logw "Batch SQL file not found, using single-transaction approach"
  if [[ ! -f "${POSTGRES_36_REASSIGN_AFFECTED_NOTES}" ]]; then
   __loge "ERROR: SQL file does not exist: ${POSTGRES_36_REASSIGN_AFFECTED_NOTES}"
   __log_finish
   return 1
  fi
  PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_36_REASSIGN_AFFECTED_NOTES}"
 fi

 # Show statistics
 __logi "Country assignment completed"

 # Mark countries as processed
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -c "
   UPDATE countries SET updated = FALSE WHERE updated = TRUE;
 "

 __logi "Re-assignment completed"
 __log_finish
}

# Checks for missing maritime boundaries by verifying EEZ centroids against OSM
# Uses centroids from World_EEZ shapefile as reference points
# For each centroid, checks if it's contained in any maritime boundary in OSM
# Parameters: None
# Returns: 0 on success, 1 on failure (non-fatal, logs warning)
function __checkMissingMaritimes() {
 __log_start
 __logi "Checking for missing maritime boundaries (verifying EEZ centroids against OSM)..."

 # Path to EEZ centroids CSV file (should be generated from shapefile)
 local EEZ_CENTROIDS_FILE="${SCRIPT_BASE_DIRECTORY}/data/eez_analysis/eez_centroids.csv"
 if [[ ! -f "${EEZ_CENTROIDS_FILE}" ]]; then
  __logd "EEZ centroids file not found: ${EEZ_CENTROIDS_FILE}"
  __logd "To enable this check, generate centroids from World_EEZ shapefile"
  __logd "See: bin/scripts/generateEEZCentroids.sh (if it exists)"
  __log_finish
  return 0
 fi

 __logi "Loading EEZ centroids from: ${EEZ_CENTROIDS_FILE}"
 local TOTAL_CENTROIDS
 TOTAL_CENTROIDS=$(tail -n +2 "${EEZ_CENTROIDS_FILE}" 2> /dev/null | wc -l | tr -d ' ' || echo "0")
 if [[ "${TOTAL_CENTROIDS}" -eq 0 ]]; then
  __logw "No centroids found in file, skipping check"
  __log_finish
  return 0
 fi

 __logi "Checking ${TOTAL_CENTROIDS} EEZ centroids against OSM maritime boundaries..."

 # Create temporary table for centroids in database
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -c "
  DROP TABLE IF EXISTS temp_eez_centroids CASCADE;
  CREATE TEMP TABLE temp_eez_centroids (
   eez_id INTEGER,
   name TEXT,
   territory TEXT,
   sovereign TEXT,
   centroid_lat NUMERIC,
   centroid_lon NUMERIC,
   geom GEOMETRY(Point, 4326)
  );
 " > /dev/null 2>&1 || {
  __logw "Failed to create temporary table, skipping check"
  __log_finish
  return 0
 }

 # Load centroids from CSV (skip header line)
 # Format expected: eez_id,name,territory,sovereign,centroid_lat,centroid_lon
 tail -n +2 "${EEZ_CENTROIDS_FILE}" 2> /dev/null | while IFS=',' read -r eez_id name territory sovereign centroid_lat centroid_lon; do
  # Escape quotes in text fields
  name=$(echo "${name}" | sed "s/'/''/g")
  territory=$(echo "${territory}" | sed "s/'/''/g")
  sovereign=$(echo "${sovereign}" | sed "s/'/''/g")

  PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -c "
   INSERT INTO temp_eez_centroids (eez_id, name, territory, sovereign, centroid_lat, centroid_lon, geom)
   VALUES (
    ${eez_id},
    '${name}',
    '${territory}',
    '${sovereign}',
    ${centroid_lat},
    ${centroid_lon},
    ST_SetSRID(ST_MakePoint(${centroid_lon}, ${centroid_lat}), 4326)
   );
  " > /dev/null 2>&1 || true
 done

 # First, filter centroids that are already covered in the database
 # Only check in OSM those that are NOT in the database
 __logi "Filtering centroids already covered in database..."
 local DB_COVERED_COUNT
 DB_COVERED_COUNT=$(PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -Atq -c "
  SELECT COUNT(*)
  FROM temp_eez_centroids t
  WHERE EXISTS (
   SELECT 1
   FROM countries c
   WHERE c.is_maritime = true
     AND ST_Contains(c.geom, t.geom)
  );
 " 2> /dev/null || echo "0")

 local TOTAL_CENTROIDS
 TOTAL_CENTROIDS=$(PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM temp_eez_centroids;" 2> /dev/null || echo "0")
 local NOT_IN_DB_COUNT=$((TOTAL_CENTROIDS - DB_COVERED_COUNT))

 __logi "Centroids already in database: ${DB_COVERED_COUNT}/${TOTAL_CENTROIDS}"
 __logi "Centroids to check in OSM: ${NOT_IN_DB_COUNT}/${TOTAL_CENTROIDS}"

 if [[ "${NOT_IN_DB_COUNT}" -eq 0 ]]; then
  __logi "All centroids are already covered in database, no need to check OSM"
  PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -c "DROP TABLE IF EXISTS temp_eez_centroids CASCADE;" > /dev/null 2>&1 || true
  __log_finish
  return 0
 fi

 # Check which centroids NOT in DB are covered by any maritime boundary in OSM
 # Query Overpass API for each centroid to see if it's contained in any maritime relation
 local MISSING_COUNT=0
 local CHECKED_COUNT=0
 local OUTPUT_DIR="${SCRIPT_BASE_DIRECTORY}/data/eez_analysis"
 mkdir -p "${OUTPUT_DIR}"
 local MISSING_EEZ_FILE="${OUTPUT_DIR}/missing_eez_osm_$(date +%Y%m%d).csv"
 local OVERPASS_API="${OVERPASS_INTERPRETER:-https://overpass-api.de/api/interpreter}"

 # Create CSV header
 echo "eez_id,name,territory,sovereign,centroid_lat,centroid_lon,status" > "${MISSING_EEZ_FILE}"

 __logi "Querying Overpass API for centroids NOT in database (this may take a while)..."
 local QUERY_TIMEOUT=25

 # Process only centroids that are NOT in the database
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -Atq -c "
  SELECT t.eez_id, t.name, t.territory, t.sovereign, t.centroid_lat, t.centroid_lon
  FROM temp_eez_centroids t
  WHERE NOT EXISTS (
   SELECT 1
   FROM countries c
   WHERE c.is_maritime = true
     AND ST_Contains(c.geom, t.geom)
  )
  ORDER BY t.eez_id;
 " 2> /dev/null | while IFS='|' read -r eez_id name territory sovereign centroid_lat centroid_lon; do
  CHECKED_COUNT=$((CHECKED_COUNT + 1))

  # Query Overpass for relations containing this point
  # Filter for maritime-related tags to avoid false positives (countries, regions, etc.)
  # This finds relations with maritime tags, not just boundary=maritime
  local OVERPASS_QUERY="[out:json][timeout:${QUERY_TIMEOUT}];
(
  is_in(${centroid_lat},${centroid_lon})[\"boundary\"=\"maritime\"];
  is_in(${centroid_lat},${centroid_lon})[\"type\"=\"boundary\"][\"maritime\"=\"yes\"];
  is_in(${centroid_lat},${centroid_lon})[\"type\"=\"boundary\"][\"boundary\"];
);
out;"

  local TEMP_OVERLASS_RESPONSE="${TMP_DIR}/overpass_${eez_id}.json"
  if curl -s --connect-timeout $((QUERY_TIMEOUT + 5)) --max-time $((QUERY_TIMEOUT + 5)) \
   -H "User-Agent: ${DOWNLOAD_USER_AGENT:-OSM-Notes-Ingestion/1.0}" \
   -H "Content-Type: application/x-www-form-urlencoded" \
   -o "${TEMP_OVERLASS_RESPONSE}" \
   -d "data=${OVERPASS_QUERY}" \
   "${OVERPASS_API}" 2> /dev/null; then

   # Check if response contains any relations
   if [[ -s "${TEMP_OVERLASS_RESPONSE}" ]] && grep -q "\"type\":\"relation\"" "${TEMP_OVERLASS_RESPONSE}" 2> /dev/null; then
    # Found relation(s) containing this centroid
    # Extract relation ID(s) from the response, filtering for maritime-related tags
    local RELATION_IDS
    # Priority 1: boundary=maritime
    RELATION_IDS=$(jq -r '.elements[] | select(.type=="relation" and (.tags.boundary // "") == "maritime") | .id' "${TEMP_OVERLASS_RESPONSE}" 2> /dev/null | head -1 || echo "")
    # Priority 2: type=boundary AND maritime=yes
    if [[ -z "${RELATION_IDS}" ]]; then
     RELATION_IDS=$(jq -r '.elements[] | select(.type=="relation" and (.tags.type // "") == "boundary" and (.tags.maritime // "") == "yes") | .id' "${TEMP_OVERLASS_RESPONSE}" 2> /dev/null | head -1 || echo "")
    fi
    # Priority 3: type=boundary with any boundary tag (but verify it's not administrative)
    if [[ -z "${RELATION_IDS}" ]]; then
     RELATION_IDS=$(jq -r '.elements[] | select(.type=="relation" and (.tags.type // "") == "boundary" and (.tags.boundary // "") != "" and (.tags.boundary // "") != "administrative") | .id' "${TEMP_OVERLASS_RESPONSE}" 2> /dev/null | head -1 || echo "")
    fi

    if [[ -n "${RELATION_IDS}" ]]; then
     # Try to download and import this relation as maritime
     __logd "EEZ ${eez_id} (${name}) - Found relation ${RELATION_IDS} in OSM, attempting to download and import as maritime..."
     if __download_and_import_maritime_relation "${RELATION_IDS}" "${eez_id}" "${name}"; then
      echo "${eez_id},\"${name}\",\"${territory}\",\"${sovereign}\",${centroid_lat},${centroid_lon},imported" >> "${MISSING_EEZ_FILE}"
      __logi "Successfully imported relation ${RELATION_IDS} for EEZ ${eez_id} (${name})"
     else
      echo "${eez_id},\"${name}\",\"${territory}\",\"${sovereign}\",${centroid_lat},${centroid_lon},covered_but_failed_import" >> "${MISSING_EEZ_FILE}"
      __logw "Found relation ${RELATION_IDS} in OSM but failed to import for EEZ ${eez_id} (${name})"
     fi
    else
     echo "${eez_id},\"${name}\",\"${territory}\",\"${sovereign}\",${centroid_lat},${centroid_lon},covered_no_relation_id" >> "${MISSING_EEZ_FILE}"
    fi
   else
    # No maritime relation found
    MISSING_COUNT=$((MISSING_COUNT + 1))
    echo "${eez_id},\"${name}\",\"${territory}\",\"${sovereign}\",${centroid_lat},${centroid_lon},missing" >> "${MISSING_EEZ_FILE}"
    __logd "EEZ ${eez_id} (${name}) - centroid not covered by any maritime boundary in OSM"
   fi
  else
   # Query failed, mark as unknown
   echo "${eez_id},\"${name}\",\"${territory}\",\"${sovereign}\",${centroid_lat},${centroid_lon},query_failed" >> "${MISSING_EEZ_FILE}"
  fi

  rm -f "${TEMP_OVERLASS_RESPONSE}" 2> /dev/null || true

  # Log progress every 10 centroids
  if [[ $((CHECKED_COUNT % 10)) -eq 0 ]]; then
   __logi "Progress: ${CHECKED_COUNT}/${NOT_IN_DB_COUNT} centroids checked, ${MISSING_COUNT} missing"
  fi

  # Small delay to avoid overwhelming Overpass API
  sleep 1
 done

 # Get final missing count from CSV
 MISSING_COUNT=$(grep -c ",missing$" "${MISSING_EEZ_FILE}" 2> /dev/null || echo "0")

 __logi "Completed: ${CHECKED_COUNT} centroids checked"
 if [[ "${MISSING_COUNT}" -eq 0 ]]; then
  __logi "All EEZ centroids are covered by maritime boundaries in OSM"
 else
  __logw "Found ${MISSING_COUNT} EEZ centroids not covered by any maritime boundary in OSM"
 fi

 # Generate summary report
 local REPORT_FILE="${OUTPUT_DIR}/missing_eez_osm_report_$(date +%Y%m%d).txt"
 {
  echo "Missing Maritime Boundaries Report (OSM Coverage Check)"
  echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
  echo ""
  echo "Method: Verify EEZ centroids against OSM maritime boundaries"
  echo "  - Total EEZ centroids checked: ${TOTAL_CENTROIDS}"
  echo "  - Centroids covered by OSM maritime boundaries: $((TOTAL_CENTROIDS - MISSING_COUNT))"
  echo "  - Centroids NOT covered in OSM: ${MISSING_COUNT}"
  echo ""
  echo "Note: Missing EEZ may not exist in OSM yet, or may have different boundaries."
  echo "These EEZ should be added to OSM as maritime boundaries."
  echo ""
  echo "Detailed results: ${MISSING_EEZ_FILE}"
 } > "${REPORT_FILE}"

 __logi "Summary report: ${REPORT_FILE}"
 __logi "Detailed results: ${MISSING_EEZ_FILE}"

 # Optionally send email if configured and there are missing EEZ
 if [[ "${MISSING_COUNT}" -gt 0 ]] && [[ "${SEND_ALERT_EMAIL:-true}" == "true" ]] && [[ -n "${ADMIN_EMAIL:-}" ]]; then
  local EMAIL_SUBJECT="Missing Maritime Boundaries Report - ${MISSING_COUNT} EEZ in OSM not in database"
  {
   echo "Missing Maritime Boundaries Report"
   echo "=================================="
   echo ""
   echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
   echo "Server: $(hostname)"
   echo ""
   echo "Summary:"
   echo "  - Total EEZ centroids from shapefile: ${TOTAL_CENTROIDS}"
   echo "  - Centroids already in database: ${DB_COVERED_COUNT}"
   echo "  - Centroids checked in OSM: ${CHECKED_COUNT}"
   echo "  - Centroids in OSM but NOT in database: ${MISSING_COUNT}"
   echo ""
   echo "These EEZ exist in OSM but were not imported to database."
   echo "They should be automatically downloaded in the next updateCountries.sh run."
   echo ""
   echo "Detailed results available at: ${MISSING_EEZ_FILE}"
   echo "Full report: ${REPORT_FILE}"
  } | mail -s "${EMAIL_SUBJECT}" "${ADMIN_EMAIL}" 2> /dev/null || {
   __logw "Failed to send email alert (mail command may not be configured)"
  }
 fi

 # Cleanup
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -c "DROP TABLE IF EXISTS temp_eez_centroids CASCADE;" > /dev/null 2>&1 || true

 __log_finish
 return 0
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
  exit "${ERROR_GENERAL}"
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
  # In base mode, use backup by default (if exists) for faster initial setup
  # This allows processPlanet to complete quickly on first run
  __logi "Processing countries and maritimes data..."
  __logi "Using backup if available (faster), otherwise downloading from Overpass..."
  __processCountries
  __processMaritimes
  __maintainCountriesTable
  __calculateInternationalWaters
  __refreshDisputedAreasView
  __cleanPartial
  # Note: __getLocationNotes is called by the main process (processAPINotes.sh)
  # after countries are loaded, not here
 else
  __logi "Running in update mode - processing existing data only"
  # Mark all countries for update and record update attempt timestamp
  STMT="UPDATE countries SET updated = TRUE, last_update_attempt = CURRENT_TIMESTAMP"
  echo "${STMT}" | PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1

  # In update mode, always download from Overpass to get latest geometries
  # (geometries can change even if IDs remain the same)
  # Force download from Overpass - don't use backup in update mode
  __logi "Processing countries and maritimes from Overpass (update mode - always get latest geometries)..."
  export FORCE_OVERPASS_DOWNLOAD="true"
  __processCountries
  __processMaritimes
  unset FORCE_OVERPASS_DOWNLOAD

  __maintainCountriesTable
  __calculateInternationalWaters
  __refreshDisputedAreasView
  __cleanPartial

  # Re-assign countries for notes affected by boundary changes
  # This is automatic and much more efficient than re-processing all notes
  __reassignAffectedNotes

  # Mark countries that failed to update (those still with updated=TRUE)
  __markFailedCountryUpdates

  # Show summary of failed boundary downloads
  __showFailedBoundariesSummary

  # Check for missing maritime boundaries (compare DB with OSM)
  if [[ "${CHECK_MISSING_MARITIMES:-false}" == "true" ]]; then
   __checkMissingMaritimes
  fi
 fi
 __log_finish
}

# Only execute main if this script is being run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
 # Always use our own log file (like processAPINotes and processPlanetNotes)
 # This ensures complete independence regardless of how we're called
 if [[ ! -t 1 ]]; then
  # Not a terminal - redirect to log file
  export LOG_FILE="${LOG_FILENAME}"
  # Redirect all output to log file
  exec >> "${LOG_FILENAME}" 2>&1
  __start_logger
  main
 else
  # Running in terminal - use stdout
  export LOG_FILE="${LOG_FILENAME}"
  __start_logger
  main
 fi
fi
