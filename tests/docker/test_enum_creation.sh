#!/bin/bash
# Test script to verify ENUM types creation and usage
# Version: 2025-07-27

set -euo pipefail

# Database configuration
export DBNAME="osm_notes_test"
export DB_USER="testuser"
export DB_PASSWORD="testpass"
export DB_HOST="postgres"
export DB_PORT="5432"

echo "=== Testing ENUM Types Creation ==="
echo "Database: ${DBNAME}"
echo "User: ${DB_USER}"
echo "Host: ${DB_HOST}:${DB_PORT}"
echo ""

# Clean and create test database
echo "🧹 Cleaning database state..."
psql -h "${DB_HOST}" -U "${DB_USER}" -d postgres -c "DROP DATABASE IF EXISTS ${DBNAME};" 2> /dev/null || true
psql -h "${DB_HOST}" -U "${DB_USER}" -d postgres -c "CREATE DATABASE ${DBNAME};" 2> /dev/null || true

# Create ENUM types
echo "📋 Creating ENUM types..."
psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DBNAME}" -f /app/sql/process/processPlanetNotes_21_createBaseTables_enum.sql

# Verify ENUM types exist
echo "📋 Verifying ENUM types..."
psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DBNAME}" -c "
SELECT 
  typname as enum_name,
  enumlabel as enum_value
FROM pg_enum e
JOIN pg_type t ON e.enumtypid = t.oid
WHERE t.typname IN ('note_status_enum', 'note_event_enum')
ORDER BY t.typname, e.enumsortorder;
"

# Try to create a simple procedure that uses the ENUM types
echo "📋 Testing procedure creation with ENUM types..."
psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DBNAME}" -c "
CREATE OR REPLACE PROCEDURE test_enum_procedure (
  test_event note_event_enum,
  test_status note_status_enum
)
LANGUAGE plpgsql
AS \$\$
BEGIN
  RAISE NOTICE 'Event: %, Status: %', test_event, test_status;
END
\$\$;
"

echo "✅ ENUM types test completed successfully" 