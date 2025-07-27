#!/bin/bash
# WMS Integration Test Script for Docker
# Tests WMS manager functionality in a containerized environment
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-27

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
 local color=$1
 local message=$2
 echo -e "${color}${message}${NC}"
}

# Test database configuration
TEST_DBNAME="osm_notes_wms_test"
TEST_DBUSER="testuser"
TEST_DBPASSWORD="testpass"
TEST_DBHOST="postgres"
TEST_DBPORT="5432"

# WMS script path
WMS_SCRIPT="/app/bin/wms/wmsManager.sh"

print_status "$BLUE" "🚀 Starting WMS Integration Tests in Docker..."

# Function to wait for PostgreSQL
wait_for_postgres() {
 print_status "$BLUE" "⏳ Waiting for PostgreSQL to be ready..."
 until pg_isready -h "$TEST_DBHOST" -U "$TEST_DBUSER" -d "$TEST_DBNAME"; do
  sleep 1
 done
 print_status "$GREEN" "✅ PostgreSQL is ready"
}

# Function to create test database
create_test_database() {
 print_status "$BLUE" "📦 Creating test database..."

 # Create database
 createdb -h "$TEST_DBHOST" -U "$TEST_DBUSER" "$TEST_DBNAME" 2> /dev/null || true

 # Enable PostGIS extension
 psql -h "$TEST_DBHOST" -U "$TEST_DBUSER" -d "$TEST_DBNAME" -c "CREATE EXTENSION IF NOT EXISTS postgis;" 2> /dev/null || true

 # Create basic notes table structure
 psql -h "$TEST_DBHOST" -U "$TEST_DBUSER" -d "$TEST_DBNAME" -c "
    CREATE TABLE IF NOT EXISTS notes (
      note_id INTEGER PRIMARY KEY,
      created_at TIMESTAMP,
      closed_at TIMESTAMP,
      lon DOUBLE PRECISION,
      lat DOUBLE PRECISION
    );
  " 2> /dev/null || true

 # Insert test data
 psql -h "$TEST_DBHOST" -U "$TEST_DBUSER" -d "$TEST_DBNAME" -c "
    INSERT INTO notes (note_id, created_at, closed_at, lon, lat) VALUES
    (1, '2023-01-01 10:00:00', NULL, -74.006, 40.7128),
    (2, '2023-02-01 11:00:00', '2023-02-15 12:00:00', -118.2437, 34.0522),
    (3, '2023-03-01 09:00:00', NULL, 2.3522, 48.8566)
    ON CONFLICT (note_id) DO NOTHING;
  " 2> /dev/null || true

 print_status "$GREEN" "✅ Test database created successfully"
}

# Function to drop test database
drop_test_database() {
 print_status "$BLUE" "🗑️  Dropping test database..."
 dropdb -h "$TEST_DBHOST" -U "$TEST_DBUSER" "$TEST_DBNAME" 2> /dev/null || true
 print_status "$GREEN" "✅ Test database dropped"
}

# Function to run WMS test
run_wms_test() {
 local test_name="$1"
 local command="$2"
 local expected_status="$3"
 local expected_output="$4"

 print_status "$BLUE" "🧪 Running test: $test_name"

 # Set environment variables
 export DBNAME="$TEST_DBNAME"
 export DBUSER="$TEST_DBUSER"
 export DBPASSWORD="$TEST_DBPASSWORD"
 export DBHOST="$TEST_DBHOST"
 export DBPORT="$TEST_DBPORT"
 export PGPASSWORD="$TEST_DBPASSWORD"

 # Run command
 local output
 local status
 output=$(eval "$command" 2>&1)
 status=$?

 # Check status
 if [ "$status" -eq "$expected_status" ]; then
  print_status "$GREEN" "✅ Status check passed"
 else
  print_status "$RED" "❌ Status check failed. Expected: $expected_status, Got: $status"
  print_status "$YELLOW" "Output: $output"
  return 1
 fi

 # Check output
 if echo "$output" | grep -q "$expected_output"; then
  print_status "$GREEN" "✅ Output check passed"
 else
  print_status "$RED" "❌ Output check failed. Expected: $expected_output"
  print_status "$YELLOW" "Output: $output"
  return 1
 fi

 print_status "$GREEN" "✅ Test passed: $test_name"
 return 0
}

# Function to verify database objects
verify_wms_objects() {
 local object_type="$1"
 local expected_count="$2"

 case "$object_type" in
  "schema")
   local count
   count=$(psql -h "$TEST_DBHOST" -U "$TEST_DBUSER" -d "$TEST_DBNAME" -t -c "SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name = 'wms';" | tr -d ' ')
   ;;
  "table")
   local count
   count=$(psql -h "$TEST_DBHOST" -U "$TEST_DBUSER" -d "$TEST_DBNAME" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'wms' AND table_name = 'notes_wms';" | tr -d ' ')
   ;;
  "triggers")
   local count
   count=$(psql -h "$TEST_DBHOST" -U "$TEST_DBUSER" -d "$TEST_DBNAME" -t -c "SELECT COUNT(*) FROM information_schema.triggers WHERE trigger_name IN ('insert_new_notes', 'update_notes');" | tr -d ' ')
   ;;
  "notes")
   local count
   count=$(psql -h "$TEST_DBHOST" -U "$TEST_DBUSER" -d "$TEST_DBNAME" -t -c "SELECT COUNT(*) FROM wms.notes_wms;" | tr -d ' ')
   ;;
 esac

 if [ "$count" -eq "$expected_count" ]; then
  print_status "$GREEN" "✅ $object_type count correct: $count"
  return 0
 else
  print_status "$RED" "❌ $object_type count incorrect. Expected: $expected_count, Got: $count"
  return 1
 fi
}

# Main test execution
main() {
 print_status "$BLUE" "🔧 Setting up test environment..."

 # Wait for PostgreSQL
 wait_for_postgres

 # Clean up any existing WMS installation
 print_status "$BLUE" "🧹 Cleaning up any existing WMS installation..."
 export DBNAME="$TEST_DBNAME"
 export DBUSER="$TEST_DBUSER"
 export DBPASSWORD="$TEST_DBPASSWORD"
 export DBHOST="$TEST_DBHOST"
 export DBPORT="$TEST_DBPORT"
 export PGPASSWORD="$TEST_DBPASSWORD"
 "$WMS_SCRIPT" deinstall > /dev/null 2>&1 || true

 # Create test database
 create_test_database

 print_status "$BLUE" "🧪 Starting WMS integration tests..."

 local tests_passed=0
 local tests_failed=0

 # Test 1: Install WMS
 print_status "$BLUE" "🧪 Starting test 1..."
 if run_wms_test "Install WMS" "$WMS_SCRIPT install" 0 "installation completed successfully"; then
  ((tests_passed++))
  print_status "$GREEN" "✅ WMS installation test passed"
 else
  # Try force install if already installed
  print_status "$BLUE" "🧪 Trying force install..."
  if run_wms_test "Force install WMS" "$WMS_SCRIPT install --force" 0 "installation completed successfully"; then
   ((tests_passed++))
   print_status "$GREEN" "✅ WMS force installation test passed"
  else
   ((tests_failed++))
   print_status "$RED" "❌ WMS installation test failed"
  fi
 fi

 print_status "$BLUE" "🧪 Test 1 completed. Passed: $tests_passed, Failed: $tests_failed"

 # Test 2: Check status
 if run_wms_test "Check WMS status" "$WMS_SCRIPT status" 0 "WMS is installed"; then
  ((tests_passed++))
 else
  ((tests_failed++))
 fi

 # Test 3: Try to install again (should fail)
 if run_wms_test "Prevent double installation" "$WMS_SCRIPT install" 0 "already installed"; then
  ((tests_passed++))
 else
  ((tests_failed++))
 fi

 # Test 4: Force reinstall
 if run_wms_test "Force reinstall" "$WMS_SCRIPT install --force" 0 "Forcing reinstallation"; then
  ((tests_passed++))
 else
  ((tests_failed++))
 fi

 # Test 5: Dry run
 if run_wms_test "Dry run" "$WMS_SCRIPT install --dry-run" 0 "DRY RUN"; then
  ((tests_passed++))
 else
  ((tests_failed++))
 fi

 # Test 6: Deinstall
 if run_wms_test "Deinstall WMS" "$WMS_SCRIPT deinstall" 0 "removal completed successfully"; then
  ((tests_passed++))

  # Verify objects were removed
  verify_wms_objects "schema" 0
  if [ $? -eq 0 ]; then
   print_status "$GREEN" "✅ All WMS objects removed correctly"
  else
   print_status "$RED" "❌ WMS objects removal verification failed"
   ((tests_failed++))
  fi
 else
  ((tests_failed++))
 fi

 # Test 7: Try to deinstall again (should handle gracefully)
 if run_wms_test "Handle deinstall when not installed" "$WMS_SCRIPT deinstall" 0 "not installed"; then
  ((tests_passed++))
 else
  ((tests_failed++))
 fi

 # Test 8: Test PostGIS requirement
 print_status "$BLUE" "🧪 Testing PostGIS requirement..."
 psql -h "$TEST_DBHOST" -U "$TEST_DBUSER" -d "$TEST_DBNAME" -c "DROP EXTENSION IF EXISTS postgis;" 2> /dev/null || true

 if run_wms_test "PostGIS requirement" "$WMS_SCRIPT install" 1 "PostGIS extension is required"; then
  ((tests_passed++))
 else
  ((tests_failed++))
 fi

 # Restore PostGIS
 psql -h "$TEST_DBHOST" -U "$TEST_DBUSER" -d "$TEST_DBNAME" -c "CREATE EXTENSION IF NOT EXISTS postgis;" 2> /dev/null || true

 # Test 9: Test missing columns requirement
 print_status "$BLUE" "🧪 Testing missing columns requirement..."
 psql -h "$TEST_DBHOST" -U "$TEST_DBUSER" -d "$TEST_DBNAME" -c "DROP TABLE IF EXISTS notes;" 2> /dev/null || true

 if run_wms_test "Missing columns requirement" "$WMS_SCRIPT install" 1 "Required columns"; then
  ((tests_passed++))
 else
  ((tests_failed++))
 fi

 # Restore notes table
 create_test_database

 # Clean up
 drop_test_database

 # Summary
 print_status "$BLUE" "📊 Test Summary:"
 print_status "$GREEN" "✅ Tests passed: $tests_passed"
 if [ $tests_failed -gt 0 ]; then
  print_status "$RED" "❌ Tests failed: $tests_failed"
  exit 1
 else
  print_status "$GREEN" "🎉 All tests passed!"
  exit 0
 fi
}

# Execute main function
main "$@"
