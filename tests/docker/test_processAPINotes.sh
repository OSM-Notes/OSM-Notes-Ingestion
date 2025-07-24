#!/usr/bin/env bash

# Test script for processAPINotes.sh
# Author: Andres Gomez (AngocA)
# Version: 2025-01-27

set -euo pipefail

# Load environment
SCRIPT_BASE_DIRECTORY="/app"
export BASENAME="test_processAPINotes"
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

# Create API tables
psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_21_createApiTables.sql"

# Process API notes if file exists
if [[ -n "${API_NOTES_FILE:-}" ]] && [[ -f "${API_NOTES_FILE}" ]]; then
 echo "Processing API notes from: ${API_NOTES_FILE}"

 # Convert XML to CSV using XSLT
 csv_file="/tmp/api_notes.csv"
 xsltproc "${SCRIPT_BASE_DIRECTORY}/xslt/notes-API-csv.xslt" "${API_NOTES_FILE}" > "${csv_file}"

 # Load data into API tables
 psql -d "${TEST_DBNAME}" -c "\COPY notes_api FROM '${csv_file}' WITH (FORMAT csv, HEADER true);"

 # Process comments
 comments_csv="/tmp/api_comments.csv"
 xsltproc "${SCRIPT_BASE_DIRECTORY}/xslt/note_comments-API-csv.xslt" "${API_NOTES_FILE}" > "${comments_csv}"
 psql -d "${TEST_DBNAME}" -c "\COPY note_comments_api FROM '${comments_csv}' WITH (FORMAT csv, HEADER true);"

 # Process text comments
 text_csv="/tmp/api_text_comments.csv"
 xsltproc "${SCRIPT_BASE_DIRECTORY}/xslt/note_comments_text-API-csv.xslt" "${API_NOTES_FILE}" > "${text_csv}"
 psql -d "${TEST_DBNAME}" -c "\COPY note_comments_text_api FROM '${text_csv}' WITH (FORMAT csv, HEADER true);"

 # Insert new notes and comments
 psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_32_insertNewNotesAndComments.sql"

 echo "API notes processing completed successfully"
else
 echo "No API notes file provided, skipping processing"
fi

echo "Test completed successfully"
