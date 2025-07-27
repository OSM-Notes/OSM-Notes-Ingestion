#!/bin/bash
# Diagnostic script for PostgreSQL connection isolation and ENUM type issues
# Version: 2025-07-27

set -euo pipefail

# Database configuration
export DBNAME="osm_notes_test"
export DB_USER="testuser"
export DB_PASSWORD="testpass"
export DB_HOST="postgres"
export DB_PORT="5432"

echo "=== PostgreSQL Connection Isolation Diagnostic ==="
echo "Database: ${DBNAME}"
echo "User: ${DB_USER}"
echo "Host: ${DB_HOST}:${DB_PORT}"
echo ""

# Clean and create test database
echo "🧹 Cleaning database state..."
psql -h "${DB_HOST}" -U "${DB_USER}" -d postgres -c "DROP DATABASE IF EXISTS ${DBNAME};" 2> /dev/null || true
psql -h "${DB_HOST}" -U "${DB_USER}" -d postgres -c "CREATE DATABASE ${DBNAME};" 2> /dev/null || true

echo "📋 Testing ENUM creation in separate connections..."

# Test 1: Create ENUM in one connection
echo "Test 1: Creating ENUM types..."
psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DBNAME}" -c "
CREATE TYPE test_enum AS ENUM ('value1', 'value2');
SELECT 'ENUM created successfully' as status;
"

# Test 2: Verify ENUM exists in same connection
echo "Test 2: Verifying ENUM in same connection..."
psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DBNAME}" -c "
SELECT typname, enumlabel 
FROM pg_enum e 
JOIN pg_type t ON e.enumtypid = t.oid 
WHERE t.typname = 'test_enum';
"

# Test 3: Try to use ENUM in same connection
echo "Test 3: Using ENUM in same connection..."
psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DBNAME}" -c "
CREATE TABLE test_table (
  id INTEGER,
  value test_enum
);
SELECT 'Table created with ENUM successfully' as status;
"

# Test 4: Try to use ENUM in different connection
echo "Test 4: Using ENUM in different connection..."
psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DBNAME}" -c "
CREATE TABLE test_table2 (
  id INTEGER,
  value test_enum
);
SELECT 'Table2 created with ENUM successfully' as status;
"

# Test 5: Check if ENUM is visible in new connection
echo "Test 5: Checking ENUM visibility in new connection..."
psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DBNAME}" -c "
SELECT 
  typname as enum_name,
  enumlabel as enum_value
FROM pg_enum e
JOIN pg_type t ON e.enumtypid = t.oid
WHERE t.typname = 'test_enum'
ORDER BY e.enumsortorder;
"

echo "✅ Connection isolation diagnostic completed" 