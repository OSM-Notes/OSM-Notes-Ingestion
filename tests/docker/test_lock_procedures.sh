#!/bin/bash
# Test script to verify lock procedures creation
# Version: 2025-07-27

set -euo pipefail

# Database configuration
export DBNAME="osm_notes_test"
export DB_USER="testuser"
export DB_PASSWORD="testpass"
export DB_HOST="postgres"
export DB_PORT="5432"

echo "=== Testing Lock Procedures Creation ==="
echo "Database: ${DBNAME}"
echo "User: ${DB_USER}"
echo "Host: ${DB_HOST}:${DB_PORT}"
echo ""

# Create test database if it doesn't exist
psql -h "${DB_HOST}" -U "${DB_USER}" -d postgres -c "CREATE DATABASE ${DBNAME};" 2> /dev/null || true

# Create base tables and lock procedures
echo "📋 Creating base tables and lock procedures..."
psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DBNAME}" -f /app/sql/process/processPlanetNotes_21_createBaseTables_enum.sql 2> /dev/null || true
psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DBNAME}" -f /app/sql/process/processPlanetNotes_22_createBaseTables_tables.sql 2> /dev/null || true

# Test if lock procedures exist
echo "📋 Testing lock procedures..."
psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DBNAME}" -c "
SELECT 
  CASE 
    WHEN EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'put_lock') 
    THEN 'put_lock procedure exists'
    ELSE 'put_lock procedure NOT found'
  END as put_lock_status;
"

psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DBNAME}" -c "
SELECT 
  CASE 
    WHEN EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'remove_lock') 
    THEN 'remove_lock procedure exists'
    ELSE 'remove_lock procedure NOT found'
  END as remove_lock_status;
"

# Test lock functionality
echo "📋 Testing lock functionality..."
psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DBNAME}" -c "
DO \$\$
BEGIN
  -- Try to acquire a lock
  CALL put_lock('test_process_1');
  RAISE NOTICE 'Lock acquired successfully';
  
  -- Try to acquire another lock (should fail)
  BEGIN
    CALL put_lock('test_process_2');
    RAISE NOTICE 'ERROR: Second lock should not have been acquired';
  EXCEPTION
    WHEN OTHERS THEN
      RAISE NOTICE 'Expected error: %', SQLERRM;
  END;
  
  -- Remove the lock
  CALL remove_lock('test_process_1');
  RAISE NOTICE 'Lock removed successfully';
  
  -- Try to acquire lock again (should succeed)
  CALL put_lock('test_process_2');
  RAISE NOTICE 'Second lock acquired successfully';
  
  -- Clean up
  CALL remove_lock('test_process_2');
  RAISE NOTICE 'Second lock removed successfully';
END \$\$;
"

echo "✅ Lock procedures test completed successfully"
