#!/bin/bash

# Generates a CSV backup of note locations (note_id, id_country) for
# faster processing in subsequent runs.
#
# Author: Andres Gomez (AngocA)
# Version: 2025-10-26

# Base directory for the project.
declare -r SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." \
 &> /dev/null && pwd)"

# Logger levels: TRACE, DEBUG, INFO, WARN, ERROR, FATAL.
declare LOG_LEVEL="${LOG_LEVEL:-INFO}"

# Load common functions
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/commonFunctions.sh"

# Database name
declare DBNAME="${DBNAME:-notes}"

# Output file
declare -r OUTPUT_FILE="${SCRIPT_BASE_DIRECTORY}/data/noteLocation.csv"
declare -r COMPRESSED_FILE="${SCRIPT_BASE_DIRECTORY}/data/noteLocation.csv.zip"

###############################################################################
# Main function
###############################################################################
main() {
 __log_start
 __logi "Generating note location backup..."

 # Check database connection
 __logd "Checking database connection..."
 if ! psql -d "${DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
  __loge "ERROR: Cannot connect to database '${DBNAME}'"
  exit 1
 fi

 # Get count of notes with country assignment
 __logd "Getting note count..."
 local NOTE_COUNT
 NOTE_COUNT=$(psql -d "${DBNAME}" -Atq -c \
  "SELECT COUNT(*) FROM notes WHERE id_country IS NOT NULL")

 __logi "Notes with country assignment: ${NOTE_COUNT}"

 if [[ "${NOTE_COUNT}" -eq 0 ]]; then
  __loge "ERROR: No notes with country assignment found in database"
  exit 1
 fi

 # Get max note_id
 __logd "Getting max note_id..."
 local MAX_NOTE_ID
 MAX_NOTE_ID=$(psql -d "${DBNAME}" -Atq -c \
  "SELECT MAX(note_id) FROM notes WHERE id_country IS NOT NULL")

 __logi "Max note_id with country: ${MAX_NOTE_ID}"

 # Export notes to CSV
 __logd "Exporting notes to CSV..."
 psql -d "${DBNAME}" -c \
  "\COPY (SELECT note_id, id_country FROM notes WHERE id_country IS NOT NULL ORDER BY note_id) TO STDOUT WITH CSV" \
  > "${OUTPUT_FILE}"

 # Compress the file
 __logd "Compressing CSV file..."
 zip -q -j "${COMPRESSED_FILE}" "${OUTPUT_FILE}"

 # Get file sizes
 local CSV_SIZE
 CSV_SIZE=$(ls -lh "${OUTPUT_FILE}" | awk '{print $5}')
 local ZIP_SIZE
 ZIP_SIZE=$(ls -lh "${COMPRESSED_FILE}" | awk '{print $5}')

 __logi "CSV file size: ${CSV_SIZE}"
 __logi "Compressed size: ${ZIP_SIZE}"
 __logi "Backup created successfully: ${COMPRESSED_FILE}"

 # Remove uncompressed file
 rm -f "${OUTPUT_FILE}"

 __log_finish
}

# Execute main
main "$@"
