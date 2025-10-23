#!/bin/bash

# Assigns countries to notes using the get_country function in parallel.
# This script ONLY assigns countries, it does NOT process Planet data.
#
# Usage:
#   assignCountriesToNotes.sh
#
# Prerequisites:
#   - Table 'notes' must exist with data
#   - Table 'countries' must exist with data
#   - Function 'get_country' must exist
#
# Author: Andres Gomez (AngocA)
# Version: 2025-10-21

set -u
set -e
set -o pipefail

# Logger levels: TRACE, DEBUG, INFO, WARN, ERROR, FATAL.
declare LOG_LEVEL="${LOG_LEVEL:-INFO}"

# Base directory for the project.
if [[ -z "${SCRIPT_BASE_DIRECTORY:-}" ]]; then
 declare SCRIPT_BASE_DIRECTORY
 SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." \
  &> /dev/null && pwd)"
 readonly SCRIPT_BASE_DIRECTORY
fi

# Load properties
if [[ -f "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh" ]]; then
 source "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh"
fi

# Load logger
if [[ -f "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/bash_logger.sh" ]]; then
 source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/bash_logger.sh"
fi

# Load common functions (contains __getLocationNotes)
if [[ -f "${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh" ]]; then
 source "${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh"
fi

# Setup temporary directory and logging
declare BASENAME
BASENAME=$(basename -s .sh "${0}")
readonly BASENAME

declare TMP_DIR
TMP_DIR=$(mktemp -d "/tmp/${BASENAME}_XXXXXX")
readonly TMP_DIR
chmod 777 "${TMP_DIR}"

# Set LOG_FILENAME if not already set
if [[ -z "${LOG_FILENAME:-}" ]]; then
 declare LOG_FILENAME
 LOG_FILENAME="${TMP_DIR}/${BASENAME}.log"
 readonly LOG_FILENAME
 # Start logger
 __set_log_file
fi

###############################################################################
# Main function
###############################################################################
main() {
 __log_start
 __logi "=== ASSIGNING COUNTRIES TO NOTES ==="
 __logi "Temporary directory: ${TMP_DIR}"
 __logi "Log file: ${LOG_FILENAME}"

 # Verify prerequisites
 __logi "Verifying prerequisites..."

 # Check prerequisites: commands, DB connection, and functions
 __checkPrereqsCommands

 # Check if notes table exists and has data
 local NOTES_COUNT
 NOTES_COUNT=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM notes;" 2> /dev/null || echo "0")

 if [[ "${NOTES_COUNT}" -eq 0 ]]; then
  __loge "ERROR: No notes found in database '${DBNAME}'"
  exit 1
 fi
 __logi "Found ${NOTES_COUNT} notes to process"

 # Check if countries table exists and has data
 local COUNTRIES_COUNT
 COUNTRIES_COUNT=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM countries;" 2> /dev/null || echo "0")

 if [[ "${COUNTRIES_COUNT}" -eq 0 ]]; then
  __loge "ERROR: No countries found in database '${DBNAME}'"
  __loge "Please run: DBNAME=notes ./bin/process/updateCountries.sh --base"
  exit 1
 fi
 __logi "Found ${COUNTRIES_COUNT} countries for assignment"

 # Check if get_country function exists
 local FUNCTION_EXISTS
 FUNCTION_EXISTS=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM pg_proc WHERE proname = 'get_country';" 2> /dev/null || echo "0")

 if [[ "${FUNCTION_EXISTS}" -eq 0 ]]; then
  __loge "ERROR: Function get_country not found"
  exit 1
 fi
 __logi "Function get_country verified"

 # Set UPDATE_NOTE_LOCATION to true to process all notes
 export UPDATE_NOTE_LOCATION=true

 # Execute the location assignment
 __logi "Starting location assignment (parallel processing)..."
 __logi "This will process notes in batches with progress visible"

 __getLocationNotes

 # Verify results
 local NOTES_WITH_COUNTRY
 NOTES_WITH_COUNTRY=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(id_country) FROM notes;")

 __logi "=== ASSIGNMENT COMPLETED ==="
 __logi "Total notes: ${NOTES_COUNT}"
 __logi "Notes with country: ${NOTES_WITH_COUNTRY}"
 __logi "Percentage: $(awk "BEGIN {printf \"%.2f\", 100.0 * ${NOTES_WITH_COUNTRY} / ${NOTES_COUNT}}")%"

 __log_finish
}

# Execute main
main "$@"
