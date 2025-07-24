#!/usr/bin/env bash

# Test script for processPlanetNotes.sh
# Author: Andres Gomez (AngocA)
# Version: 2025-01-27

set -euo pipefail

# Load environment
SCRIPT_BASE_DIRECTORY="/app"
export BASENAME="test_processPlanetNotes"
export TMP_DIR="/tmp/test_$$"
export LOG_FILENAME="/tmp/test.log"
export LOCK="/tmp/test.lock"
source "${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh"

# Test configuration
declare -r TEST_DBNAME="${TEST_DBNAME:-osm_notes_test}"
declare -r TEST_DBUSER="${TEST_DBUSER:-testuser}"
declare -r TEST_DBPASSWORD="${TEST_DBPASSWORD:-testpass}"
declare -r TEST_DBHOST="${TEST_DBHOST:-postgres}"
declare -r TEST_DBPORT="${TEST_DBPORT:-5432}"

# Override database settings for testing
DBNAME="${TEST_DBNAME}"
DB_USER="${TEST_DBUSER}"
DB_PASSWORD="${TEST_DBPASSWORD}"
DB_HOST="${TEST_DBHOST}"
DB_PORT="${TEST_DBPORT}"

# Create test database if it doesn't exist
psql -d postgres -c "CREATE DATABASE ${TEST_DBNAME};" 2> /dev/null || true

# Create base tables
psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_21_createBaseTables_enum.sql"
psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_22_createBaseTables_tables.sql"
# Skip PostGIS constraints for test environment
# psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_23_createBaseTables_constraints.sql"

# Create sync tables
psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_24_createSyncTables.sql"

# Process Planet notes if file exists
if [[ -n "${PLANET_NOTES_FILE:-}" ]] && [[ -f "${PLANET_NOTES_FILE}" ]]; then
 echo "Processing Planet notes from: ${PLANET_NOTES_FILE}"

 # Convert XML to CSV using XSLT
 csv_file="/tmp/planet_notes.csv"
 xsltproc "${SCRIPT_BASE_DIRECTORY}/xslt/notes-Planet-csv.xslt" "${PLANET_NOTES_FILE}" > "${csv_file}"

 # Load data into sync tables
 psql -d "${TEST_DBNAME}" -c "\COPY notes_sync FROM '${csv_file}' WITH (FORMAT csv, HEADER true);"

 # Process comments
 comments_csv="/tmp/planet_comments.csv"
 xsltproc "${SCRIPT_BASE_DIRECTORY}/xslt/note_comments-Planet-csv.xslt" "${PLANET_NOTES_FILE}" > "${comments_csv}"
 psql -d "${TEST_DBNAME}" -c "\COPY note_comments_sync FROM '${comments_csv}' WITH (FORMAT csv, HEADER true);"

 # Process text comments
 text_csv="/tmp/planet_text_comments.csv"
 xsltproc "${SCRIPT_BASE_DIRECTORY}/xslt/note_comments_text-Planet-csv.xslt" "${PLANET_NOTES_FILE}" > "${text_csv}"
 psql -d "${TEST_DBNAME}" -c "\COPY note_comments_text_sync FROM '${text_csv}' WITH (FORMAT csv, HEADER true);"

 # Insert data into base tables
 psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_32_insertSyncDataIntoBaseTables.sql"

 echo "Planet notes processing completed successfully"
else
 echo "No Planet notes file provided, skipping processing"
fi

echo "Test completed successfully"
