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
declare -r TEST_DBUSER="${TEST_DBUSER:-test_user}"
declare -r TEST_DBPASSWORD="${TEST_DBPASSWORD:-test_pass}"
declare -r TEST_DBHOST="${TEST_DBHOST:-test-db}"
declare -r TEST_DBPORT="${TEST_DBPORT:-5432}"

# Export database settings for external functions
export DBNAME="${TEST_DBNAME}"
export DB_USER="${TEST_DBUSER}"
export DB_PASSWORD="${TEST_DBPASSWORD}"
export DB_HOST="${TEST_DBHOST}"
export DB_PORT="${TEST_DBPORT}"

# Create test database if it doesn't exist
psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d postgres -c "CREATE DATABASE ${TEST_DBNAME};" 2> /dev/null || true

# Create base tables
psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_21_createBaseTables_enum.sql"
psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_22_createBaseTables_tables.sql"
# Skip PostGIS constraints for test environment
# psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_23_createBaseTables_constraints.sql"

# Create sync tables
psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_24_createSyncTables.sql"

# Process Planet notes if file exists
echo "DEBUG: PLANET_NOTES_FILE=${PLANET_NOTES_FILE:-'not set'}"
echo "DEBUG: Checking if file exists..."
if [[ -n "${PLANET_NOTES_FILE:-}" ]] && [[ -f "${PLANET_NOTES_FILE}" ]]; then
 echo "Processing Planet notes from: ${PLANET_NOTES_FILE}"

 # Convert XML to CSV using XSLT
 csv_file="/tmp/planet_notes.csv"
 xsltproc "${SCRIPT_BASE_DIRECTORY}/xslt/notes-Planet-csv.xslt" "${PLANET_NOTES_FILE}" > "${csv_file}"

 # Load data into sync tables
 psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "\COPY notes_sync (note_id, latitude, longitude, created_at, status, closed_at, id_country) FROM '${csv_file}' WITH (FORMAT csv);"

 # Process comments
 comments_csv="/tmp/planet_comments.csv"
 xsltproc "${SCRIPT_BASE_DIRECTORY}/xslt/note_comments-Planet-csv.xslt" "${PLANET_NOTES_FILE}" > "${comments_csv}"
 psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "\COPY note_comments_sync (note_id, sequence_action, event, created_at, id_user, username) FROM '${comments_csv}' WITH (FORMAT csv);"

 # Process text comments
 text_csv="/tmp/planet_text_comments.csv"
 xsltproc "${SCRIPT_BASE_DIRECTORY}/xslt/note_comments_text-Planet-csv.xslt" "${PLANET_NOTES_FILE}" > "${text_csv}"
 psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "\COPY note_comments_text_sync (note_id, sequence_action, body) FROM '${text_csv}' WITH (FORMAT csv);"

 # Move sync data to main tables
 psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_43_moveSyncToMain.sql"

 echo "Planet notes processing completed successfully"
else
 echo "No Planet notes file provided, skipping processing"
fi

echo "Test completed successfully"
