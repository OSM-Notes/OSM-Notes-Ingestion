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
# Version: 2025-10-19
VERSION="2025-10-19"

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

# Variable to define that the process should update the location of notes.
# This variable is used in functionsProcess.sh
export UPDATE_NOTE_LOCATION=true

# Loads the global properties.
# shellcheck disable=SC1091
if [[ -f "${SCRIPT_BASE_DIRECTORY}/tests/properties.sh" ]] && [[ "${BATS_TEST_NAME:-}" != "" ]]; then
 # Use test properties when running in test environment
 source "${SCRIPT_BASE_DIRECTORY}/tests/properties.sh"
else
 # Use production properties
 source "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh"
fi

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
 source "${SCRIPT_BASE_DIRECTORY}/bin/processPlanetFunctions.sh"
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

# Shows the help information.
function __show_help {
 echo "${BASENAME} version ${VERSION}"
 echo "Updates the country and maritime boundaries."
 echo
 echo "This script handles the complete lifecycle of countries and maritimes:"
 echo "  - Creates and manages table structures (--base mode drops and recreates)"
 echo "  - Downloads and processes geographic data"
 echo "  - Updates boundaries and verifies note locations"
 echo
 echo "Written by: Andres Gomez (AngocA)"
 echo "OSM-LatAm, OSM-Colombia, MaptimeBogota."
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
 __logd "Dropping countries and tries tables directly"
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 << 'EOF'
-- Drop country tables
DROP TABLE IF EXISTS countries CASCADE;
DROP TABLE IF EXISTS tries CASCADE;
EOF
 __logi "=== COUNTRY TABLES DROPPED SUCCESSFULLY ==="
 __log_finish
}

# Creates country tables
function __createCountryTables {
 __log_start
 __logi "Creating country and maritime tables."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_26_CREATE_COUNTRY_TABLES}"
 __log_finish
}

# Re-assigns countries only for notes affected by geometry changes.
# This is much more efficient than re-processing all notes.
# Only processes notes within bounding boxes of countries that were updated.
function __reassignAffectedNotes {
 __log_start
 __logi "Re-assigning countries for notes affected by boundary changes..."

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
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 << 'SQL'
   -- Re-assign country for notes that might be affected
   -- The get_country function will check if note is still in current country first
   UPDATE notes n
   SET id_country = get_country(n.longitude, n.latitude, n.note_id)
   WHERE EXISTS (
     SELECT 1
     FROM countries c
     WHERE c.updated = TRUE
       AND ST_Intersects(
         ST_MakeEnvelope(
           ST_XMin(c.geometry), ST_YMin(c.geometry),
           ST_XMax(c.geometry), ST_YMax(c.geometry),
           4326
         ),
         ST_SetSRID(ST_MakePoint(n.longitude, n.latitude), 4326)
       )
   );
SQL

 # Show statistics
 local -r NOTES_UPDATED=$(psql -d "${DBNAME}" -Atq -c "
   SELECT COUNT(*)
   FROM tries
   WHERE area = 'Country changed';
 ")
 __logi "Notes that changed country: ${NOTES_UPDATED}"

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
 __log_start
 __logi "Preparing environment."
 __logd "Output saved at: ${TMP_DIR}."
 __logi "Processing: ${PROCESS_TYPE}."

 # Checks the prerequisities. It could terminate the process.
 __checkPrereqs

 __logw "Starting process."

 # Sets the trap in case of any signal.
 __trapOn
 exec 7> "${LOCK}"
 __logw "Validating single execution."
 ONLY_EXECUTION="no"
 flock -n 7
 ONLY_EXECUTION="yes"

 if [[ "${PROCESS_TYPE}" == "-h" ]] \
  || [[ "${PROCESS_TYPE}" == "--help" ]]; then
  __show_help
  exit "${ERROR_HELP_MESSAGE}"
 elif [[ "${PROCESS_TYPE}" == "--base" ]]; then
  __logi "Running in base mode - dropping and recreating tables for consistency"

  # Drop and recreate country tables for consistency with processPlanetNotes.sh
  __logi "Dropping existing country and maritime tables..."
  __dropCountryTables

  __logi "Creating country and maritime tables..."
  __createCountryTables

  # Process countries and maritimes data
  __logi "Processing countries and maritimes data..."
  __processCountries
  __processMaritimes
  __cleanPartial
  # Note: __getLocationNotes is called by the main process (processAPINotes.sh)
  # after countries are loaded, not here
 else
  __logi "Running in update mode - processing existing data only"
  STMT="UPDATE countries SET updated = TRUE"
  echo "${STMT}" | psql -d "${DBNAME}" -v ON_ERROR_STOP=1
  __processCountries
  __processMaritimes
  __cleanPartial

  # Re-assign countries for notes affected by boundary changes
  # This is automatic and much more efficient than re-processing all notes
  __reassignAffectedNotes
 fi
 __log_finish
}

# Only execute main if this script is being run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
 __start_logger
 if [[ ! -t 1 ]]; then
  __set_log_file "${LOG_FILENAME}"
  main >> "${LOG_FILENAME}" 2>&1
 else
  main
 fi
fi
