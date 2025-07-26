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
declare -r TEST_DBUSER="${TEST_DBUSER:-test_user}"
declare -r TEST_DBPASSWORD="${TEST_DBPASSWORD:-test_pass}"
declare -r TEST_DBHOST="${TEST_DBHOST:-test-db}"
declare -r TEST_DBPORT="${TEST_DBPORT:-5432}"

# Override database settings for testing
DBNAME="${TEST_DBNAME}"
DB_USER="${TEST_DBUSER}"
DB_PASSWORD="${TEST_DBPASSWORD}"
DB_HOST="${TEST_DBHOST}"
DB_PORT="${TEST_DBPORT}"

# Create test database if it doesn't exist
psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d postgres -c "CREATE DATABASE ${TEST_DBNAME};" 2> /dev/null || true

# Create base tables
psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_21_createBaseTables_enum.sql"
psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_22_createBaseTables_tables.sql"
# Skip PostGIS constraints for test environment
# psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_23_createBaseTables_constraints.sql"

# Create API tables
psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_21_createApiTables.sql"

# Create partitions for API tables (required for partitioned tables)
psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "CREATE TABLE IF NOT EXISTS notes_api_p1 PARTITION OF notes_api FOR VALUES FROM (1) TO (2);"
psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "CREATE TABLE IF NOT EXISTS note_comments_api_p1 PARTITION OF note_comments_api FOR VALUES FROM (1) TO (2);"
psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "CREATE TABLE IF NOT EXISTS note_comments_text_api_p1 PARTITION OF note_comments_text_api FOR VALUES FROM (1) TO (2);"

# Process API notes if file exists
echo "DEBUG: API_NOTES_FILE=${API_NOTES_FILE:-'not set'}"
echo "DEBUG: Checking if file exists..."
if [[ -n "${API_NOTES_FILE:-}" ]] && [[ -f "${API_NOTES_FILE}" ]]; then
 echo "Processing API notes from: ${API_NOTES_FILE}"

 # Convert XML to CSV using XSLT
 csv_file="/tmp/api_notes.csv"
 xsltproc "${SCRIPT_BASE_DIRECTORY}/xslt/notes-API-csv.xslt" "${API_NOTES_FILE}" > "${csv_file}"

   # Load data into API tables
  psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "\COPY notes_api (note_id, latitude, longitude, created_at, closed_at, status, id_country, part_id) FROM '${csv_file}' WITH (FORMAT csv);"

   # Process comments
  comments_csv="/tmp/api_comments.csv"
  xsltproc "${SCRIPT_BASE_DIRECTORY}/xslt/note_comments-API-csv.xslt" "${API_NOTES_FILE}" > "${comments_csv}"
  psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "\COPY note_comments_api (note_id, sequence_action, event, created_at, id_user, username, part_id) FROM '${comments_csv}' WITH (FORMAT csv);"

   # Process text comments
  text_csv="/tmp/api_text_comments.csv"
  xsltproc "${SCRIPT_BASE_DIRECTORY}/xslt/note_comments_text-API-csv.xslt" "${API_NOTES_FILE}" > "${text_csv}"
  psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "\COPY note_comments_text_api (note_id, sequence_action, body, part_id) FROM '${text_csv}' WITH (FORMAT csv);"

 # Insert new notes and comments
 psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_32_insertNewNotesAndComments.sql"

 echo "API notes processing completed successfully"
else
 echo "No API notes file provided, skipping processing"
fi

echo "Test completed successfully"
