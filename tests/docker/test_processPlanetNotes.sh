#!/bin/bash
# Test script for Planet Notes processing in Docker environment
# Version: 2025-07-26

set -euo pipefail

# Database configuration
export DBNAME="osm_notes_test"
export DB_USER="testuser"
export DB_PASSWORD="testpass"
export DB_HOST="postgres"
export DB_PORT="5432"

# Test configuration
PLANET_NOTES_FILE="${PLANET_NOTES_FILE:-/app/tests/fixtures/xml/planet_notes_sample.xml}"

echo "=== Planet Notes Processing Test ==="
echo "Database: ${DBNAME}"
echo "User: ${DB_USER}"
echo "Host: ${DB_HOST}:${DB_PORT}"
echo "Planet Notes File: ${PLANET_NOTES_FILE}"
echo ""

# Load base functions and procedures
echo "📋 Loading base functions and procedures..."
psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DBNAME}" -f /app/sql/functionsProcess_21_createFunctionToGetCountry.sql 2> /dev/null || true
psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DBNAME}" -f /app/sql/functionsProcess_22_createProcedure_insertNote.sql 2> /dev/null || true
psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DBNAME}" -f /app/sql/functionsProcess_23_createProcedure_insertNoteComment.sql 2> /dev/null || true

# Create base tables
echo "📋 Creating base tables..."
psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DBNAME}" -f /app/sql/process/processPlanetNotes_21_createBaseTables_enum.sql 2> /dev/null || true
psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DBNAME}" -f /app/sql/process/processPlanetNotes_22_createBaseTables_tables.sql 2> /dev/null || true

# Create sync tables
echo "📋 Creating sync tables..."
psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DBNAME}" -f /app/sql/process/processPlanetNotes_24_createSyncTables.sql 2> /dev/null || true

# Create partitions
echo "📋 Creating partitions..."
psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DBNAME}" -f /app/sql/process/processPlanetNotes_25_createPartitions.sql 2> /dev/null || true

# Set up process lock
echo "📋 Setting up process lock..."
psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DBNAME}" -c "INSERT INTO properties (key, value) VALUES ('process_lock', 'test_lock') ON CONFLICT (key) DO UPDATE SET value = 'test_lock';" 2> /dev/null || true

# Clear existing data
echo "📋 Clearing existing data..."
psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DBNAME}" -c "DELETE FROM note_comments_text;" 2> /dev/null || true
psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DBNAME}" -c "DELETE FROM note_comments;" 2> /dev/null || true
psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DBNAME}" -c "DELETE FROM notes;" 2> /dev/null || true

# Process Planet notes
echo "🔄 Processing Planet notes..."
if [[ -f "${PLANET_NOTES_FILE}" ]]; then
 echo "DEBUG: PLANET_NOTES_FILE=${PLANET_NOTES_FILE}"
 echo "DEBUG: Checking if file exists..."
 if [[ -f "${PLANET_NOTES_FILE}" ]]; then
  echo "Processing Planet notes from: ${PLANET_NOTES_FILE}"

  # Convert XML to CSV using XSLT
  csv_file="/tmp/planet_notes.csv"
  comments_csv="/tmp/planet_comments.csv"
  text_csv="/tmp/planet_text_comments.csv"

  echo "Converting XML to CSV..."
  xsltproc /app/xslt/notes-Planet-csv.xslt "${PLANET_NOTES_FILE}" > "${csv_file}"
  xsltproc /app/xslt/note_comments-Planet-csv.xslt "${PLANET_NOTES_FILE}" > "${comments_csv}"
  xsltproc /app/xslt/note_comments_text-Planet-csv.xslt "${PLANET_NOTES_FILE}" > "${text_csv}"

  # Load data into sync tables using \copy
  echo "Loading data into sync tables..."
  psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DBNAME}" -c "\copy notes_sync (note_id, latitude, longitude, created_at, status, closed_at, id_country) FROM '${csv_file}' WITH (FORMAT csv);"
  psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DBNAME}" -c "\copy note_comments_sync (note_id, sequence_action, event, created_at, id_user, username) FROM '${comments_csv}' WITH (FORMAT csv);"
  psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DBNAME}" -c "\copy note_comments_text_sync (note_id, sequence_action, body) FROM '${text_csv}' WITH (FORMAT csv);"

  # Move sync data to main tables manually
  echo "Moving data to main tables..."
  psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DBNAME}" -c "INSERT INTO notes (note_id, latitude, longitude, created_at, status, closed_at, id_country) SELECT note_id, latitude, longitude, created_at, status, closed_at, id_country FROM notes_sync;"
  psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DBNAME}" -c "INSERT INTO note_comments (note_id, sequence_action, event, created_at, id_user) SELECT note_id, sequence_action, event, created_at, id_user FROM note_comments_sync;"
  psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DBNAME}" -c "INSERT INTO note_comments_text (note_id, sequence_action, body) SELECT note_id, sequence_action, body FROM note_comments_text_sync;"

  # Clear sync tables
  echo "Clearing sync tables..."
  psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DBNAME}" -c "DELETE FROM notes_sync;"
  psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DBNAME}" -c "DELETE FROM note_comments_sync;"
  psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DBNAME}" -c "DELETE FROM note_comments_text_sync;"

  # Clean up temporary files
  rm -f "${csv_file}" "${comments_csv}" "${text_csv}"

  echo "Planet notes processing completed successfully"
 else
  echo "ERROR: Planet notes file not found: ${PLANET_NOTES_FILE}"
  exit 1
 fi
else
 echo "ERROR: Planet notes file not specified or not found"
 exit 1
fi

# Verify results
echo "📊 Verifying results..."
NOTES_COUNT=$(psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DBNAME}" -t -c "SELECT COUNT(*) FROM notes;" | xargs)
COMMENTS_COUNT=$(psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DBNAME}" -t -c "SELECT COUNT(*) FROM note_comments;" | xargs)
TEXT_COMMENTS_COUNT=$(psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DBNAME}" -t -c "SELECT COUNT(*) FROM note_comments_text;" | xargs)

echo "Results:"
echo "  Notes: ${NOTES_COUNT}"
echo "  Comments: ${COMMENTS_COUNT}"
echo "  Text Comments: ${TEXT_COMMENTS_COUNT}"

# Clean up lock
echo "📋 Cleaning up process lock..."
psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DBNAME}" -c "DELETE FROM properties WHERE key = 'process_lock';" 2> /dev/null || true

echo "Test completed successfully"
