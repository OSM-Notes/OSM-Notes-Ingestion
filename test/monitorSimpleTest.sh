#!/bin/bash
# shellcheck disable=SC2034

# Simple test script for the monitoring system
# Author: Andres Gomez (AngocA)
# Version: 2025-07-24
declare -r VERSION="2025-07-24"

set -euo pipefail

# Test database name
declare -r TEST_DBNAME="notes_test_simple"

echo "=== Simple Monitoring Test ==="
echo "Setting up test database: ${TEST_DBNAME}"

# Create test database
psql -d postgres -c "DROP DATABASE IF EXISTS ${TEST_DBNAME};" || true
psql -d postgres -c "CREATE DATABASE ${TEST_DBNAME};"

# Create base tables structure
psql -d "${TEST_DBNAME}" -f "/app/sql/process/processPlanetNotes_21_createBaseTables_enum.sql"
psql -d "${TEST_DBNAME}" -f "/app/sql/process/processPlanetNotes_22_createBaseTables_tables.sql"
psql -d "${TEST_DBNAME}" -f "/app/sql/process/processPlanetNotes_23_createBaseTables_constraints.sql"

# Create check tables
psql -d "${TEST_DBNAME}" -f "/app/sql/monitor/processCheckPlanetNotes_21_createCheckTables.sql"

echo "Loading test data..."

# Insert users first
psql -d "${TEST_DBNAME}" -c "
INSERT INTO users (user_id, username) VALUES
(12345, 'testuser1'),
(67890, 'testuser2');
"

# Load sample data for success scenario (complete data)
psql -d "${TEST_DBNAME}" -c "
INSERT INTO notes (note_id, latitude, longitude, created_at, status, id_country) VALUES
(1001, 40.7128, -74.0060, '2025-01-01 10:00:00', 'open', 1),
(1002, 34.0522, -118.2437, '2025-01-01 11:00:00', 'close', 1),
(1003, 51.5074, -0.1278, '2025-01-01 12:00:00', 'open', 2);
"

psql -d "${TEST_DBNAME}" -c "
INSERT INTO note_comments (note_id, sequence_action, event, created_at, id_user) VALUES
(1001, 1, 'opened', '2025-01-01 10:00:00', 12345),
(1001, 2, 'commented', '2025-01-01 10:30:00', 67890),
(1002, 1, 'opened', '2025-01-01 11:00:00', 12345),
(1002, 2, 'closed', '2025-01-01 11:30:00', 67890),
(1003, 1, 'opened', '2025-01-01 12:00:00', 12345);
"

psql -d "${TEST_DBNAME}" -c "
INSERT INTO note_comments_text (note_id, sequence_action, body) VALUES
(1001, 1, 'Note opened for testing'),
(1001, 2, 'This is a test comment'),
(1002, 1, 'Another test note'),
(1002, 2, 'Note closed'),
(1003, 1, 'Third test note');
"

# Load same data into check tables (simulating Planet data)
psql -d "${TEST_DBNAME}" -c "
INSERT INTO notes_check (note_id, latitude, longitude, created_at, status, id_country) VALUES
(1001, 40.7128, -74.0060, '2025-01-01 10:00:00', 'open', 1),
(1002, 34.0522, -118.2437, '2025-01-01 11:00:00', 'close', 1),
(1003, 51.5074, -0.1278, '2025-01-01 12:00:00', 'open', 2);
"

psql -d "${TEST_DBNAME}" -c "
INSERT INTO note_comments_check (note_id, sequence_action, event, created_at, id_user) VALUES
(1001, 1, 'opened', '2025-01-01 10:00:00', 12345),
(1001, 2, 'commented', '2025-01-01 10:30:00', 67890),
(1002, 1, 'opened', '2025-01-01 11:00:00', 12345),
(1002, 2, 'closed', '2025-01-01 11:30:00', 67890),
(1003, 1, 'opened', '2025-01-01 12:00:00', 12345);
"

psql -d "${TEST_DBNAME}" -c "
INSERT INTO note_comments_text_check (note_id, sequence_action, body) VALUES
(1001, 1, 'Note opened for testing'),
(1001, 2, 'This is a test comment'),
(1002, 1, 'Another test note'),
(1002, 2, 'Note closed'),
(1003, 1, 'Third test note');
"

echo "Running monitoring test..."

# Temporarily change database
export DBNAME="${TEST_DBNAME}"

# Run monitoring script
if bash /app/bin/monitor/notesCheckVerifier.sh > /tmp/monitor_output.log 2> /tmp/monitor_error.log; then
 echo "✓ SUCCESS: Monitoring script executed successfully"

 # Check if differences were found
 if grep -q "Summary of differences:" /tmp/monitor_output.log; then
  echo "✗ FAILURE: Differences detected when none expected"
  cat /tmp/monitor_output.log
 else
  echo "✓ SUCCESS: No differences detected (expected)"
 fi
else
 echo "✗ FAILURE: Monitoring script failed"
 cat /tmp/monitor_error.log
fi

# Restore original database
export DBNAME="osm_notes_test"

# Cleanup
# psql -d postgres -c "DROP DATABASE IF EXISTS ${TEST_DBNAME};" || true

echo "=== Test completed ==="
