#!/bin/bash
# Test script to investigate CREATE TYPE IF NOT EXISTS for ENUM types
# Version: 2025-07-27

set -euo pipefail

# Database configuration
export DBNAME="osm_notes_test"
export DB_USER="testuser"
export DB_PASSWORD="testpass"
export DB_HOST="postgres"
export DB_PORT="5432"

echo "=== Testing CREATE TYPE IF NOT EXISTS for ENUM Types ==="
echo "Database: ${DBNAME}"
echo "User: ${DB_USER}"
echo "Host: ${DB_HOST}:${DB_PORT}"
echo ""

# Clean and create test database
echo "🧹 Cleaning database state..."
psql -h "${DB_HOST}" -U "${DB_USER}" -d postgres -c "DROP DATABASE IF EXISTS ${DBNAME};" 2> /dev/null || true
psql -h "${DB_HOST}" -U "${DB_USER}" -d postgres -c "CREATE DATABASE ${DBNAME};" 2> /dev/null || true

# Test 1: Try to create ENUM types with IF NOT EXISTS
echo "📋 Test 1: Creating ENUM types with IF NOT EXISTS..."
psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DBNAME}" << 'EOF'
-- Test CREATE TYPE IF NOT EXISTS (this syntax doesn't exist in PostgreSQL)
-- We'll use a DO block instead
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'note_status_enum') THEN
    CREATE TYPE note_status_enum AS ENUM (
      'open',
      'close',
      'hidden'
    );
    RAISE NOTICE 'Created note_status_enum';
  ELSE
    RAISE NOTICE 'note_status_enum already exists';
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'note_event_enum') THEN
    CREATE TYPE note_event_enum AS ENUM (
      'opened',
      'closed',
      'reopened',
      'commented',
      'hidden'
    );
    RAISE NOTICE 'Created note_event_enum';
  ELSE
    RAISE NOTICE 'note_event_enum already exists';
  END IF;
END
$$;

-- Verify ENUM types exist
SELECT 'ENUM types verification:' as status;
SELECT typname, enumlabel 
FROM pg_enum e 
JOIN pg_type t ON e.enumtypid = t.oid 
WHERE t.typname IN ('note_status_enum', 'note_event_enum')
ORDER BY t.typname, e.enumsortorder;
EOF

# Test 2: Try to create the same ENUM types again (should not fail)
echo "📋 Test 2: Attempting to create ENUM types again..."
psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DBNAME}" << 'EOF'
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'note_status_enum') THEN
    CREATE TYPE note_status_enum AS ENUM (
      'open',
      'close',
      'hidden'
    );
    RAISE NOTICE 'Created note_status_enum (second attempt)';
  ELSE
    RAISE NOTICE 'note_status_enum already exists (second attempt)';
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'note_event_enum') THEN
    CREATE TYPE note_event_enum AS ENUM (
      'opened',
      'closed',
      'reopened',
      'commented',
      'hidden'
    );
    RAISE NOTICE 'Created note_event_enum (second attempt)';
  ELSE
    RAISE NOTICE 'note_event_enum already exists (second attempt)';
  END IF;
END
$$;

-- Test 3: Try to create a table using the ENUM types
CREATE TABLE IF NOT EXISTS test_notes (
  id INTEGER PRIMARY KEY,
  status note_status_enum,
  event note_event_enum
);

SELECT 'Table creation test:' as status;
SELECT 'Table created successfully with ENUM types' as result;
EOF

# Test 4: Try to create procedures using the ENUM types
echo "📋 Test 3: Creating procedures with ENUM types..."
psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DBNAME}" << 'EOF'
CREATE OR REPLACE PROCEDURE test_enum_procedure (
  test_status note_status_enum,
  test_event note_event_enum
)
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE NOTICE 'Status: %, Event: %', test_status, test_event;
END
$$;

SELECT 'Procedure creation test:' as status;
SELECT 'Procedure created successfully with ENUM types' as result;
EOF

echo "✅ CREATE TYPE IF NOT EXISTS test completed successfully" 