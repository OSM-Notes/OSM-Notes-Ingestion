#!/bin/bash
# Test script to investigate connection pooling for PostgreSQL
# Version: 2025-07-27

set -euo pipefail

# Database configuration
export DBNAME="osm_notes_test"
export DB_USER="testuser"
export DB_PASSWORD="testpass"
export DB_HOST="postgres"
export DB_PORT="5432"

echo "=== Testing Connection Pooling Solutions ==="
echo "Database: ${DBNAME}"
echo "User: ${DB_USER}"
echo "Host: ${DB_HOST}:${DB_PORT}"
echo ""

# Clean and create test database
echo "🧹 Cleaning database state..."
psql -h "${DB_HOST}" -U "${DB_USER}" -d postgres -c "DROP DATABASE IF EXISTS ${DBNAME};" 2> /dev/null || true
psql -h "${DB_HOST}" -U "${DB_USER}" -d postgres -c "CREATE DATABASE ${DBNAME};" 2> /dev/null || true

# Test 1: Use a single persistent connection with multiple operations
echo "📋 Test 1: Single persistent connection with multiple operations..."
psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DBNAME}" << 'EOF'
-- Start a session and keep it open
\set ON_ERROR_STOP on

-- Create ENUM types
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'note_status_enum') THEN
    CREATE TYPE note_status_enum AS ENUM (
      'open',
      'close',
      'hidden'
    );
    RAISE NOTICE 'Created note_status_enum';
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

-- Create a table using the ENUM types
CREATE TABLE IF NOT EXISTS test_notes (
  id INTEGER PRIMARY KEY,
  status note_status_enum,
  event note_event_enum
);

-- Create a procedure using the ENUM types
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

SELECT 'All objects created successfully in single connection' as result;
EOF

# Test 2: Use a named session to maintain connection state
echo "📋 Test 2: Named session approach..."
psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DBNAME}" -c "
-- Set session name
SELECT set_config('application_name', 'test_session', false);

-- Create ENUM types in this session
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'note_status_enum') THEN
    CREATE TYPE note_status_enum AS ENUM (
      'open',
      'close',
      'hidden'
    );
    RAISE NOTICE 'Created note_status_enum in session';
  END IF;
END
\$\$;

-- Verify in same session
SELECT 'Session verification:' as status;
SELECT typname, enumlabel 
FROM pg_enum e 
JOIN pg_type t ON e.enumtypid = t.oid 
WHERE t.typname IN ('note_status_enum', 'note_event_enum')
ORDER BY t.typname, e.enumsortorder;
"

# Test 3: Use transaction isolation level
echo "📋 Test 3: Transaction isolation level approach..."
psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DBNAME}" << 'EOF'
-- Set transaction isolation level
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

-- Start transaction
BEGIN;

-- Create ENUM types
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'note_status_enum') THEN
    CREATE TYPE note_status_enum AS ENUM (
      'open',
      'close',
      'hidden'
    );
    RAISE NOTICE 'Created note_status_enum in transaction';
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
    RAISE NOTICE 'Created note_event_enum in transaction';
  END IF;
END
$$;

-- Verify in same transaction
SELECT 'Transaction verification:' as status;
SELECT typname, enumlabel 
FROM pg_enum e 
JOIN pg_type t ON e.enumtypid = t.oid 
WHERE t.typname IN ('note_status_enum', 'note_event_enum')
ORDER BY t.typname, e.enumsortorder;

-- Commit transaction
COMMIT;

-- Verify after commit
SELECT 'Post-commit verification:' as status;
SELECT typname, enumlabel 
FROM pg_enum e 
JOIN pg_type t ON e.enumtypid = t.oid 
WHERE t.typname IN ('note_status_enum', 'note_event_enum')
ORDER BY t.typname, e.enumsortorder;
EOF

echo "✅ Connection pooling tests completed successfully"
