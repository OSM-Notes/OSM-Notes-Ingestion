#!/bin/bash
# Advanced WMS Integration Test Script
# Comprehensive tests for WMS manager functionality
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-27

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_status() {
 local color=$1
 local message=$2
 echo -e "${color}${message}${NC}"
}

print_header() {
 echo -e "${PURPLE}========================================${NC}"
 echo -e "${PURPLE}$1${NC}"
 echo -e "${PURPLE}========================================${NC}"
}

print_test_result() {
 local test_name="$1"
 local status="$2"
 local message="$3"

 if [[ "$status" -eq 0 ]]; then
  echo -e "${GREEN}✅ $test_name: PASSED${NC} - $message"
 else
  echo -e "${RED}❌ $test_name: FAILED${NC} - $message"
 fi
}

# Test database configuration
TEST_DBNAME="osm_notes_wms_test"
TEST_DBUSER="testuser"
TEST_DBPASSWORD="testpass"
TEST_DBHOST="postgres"
TEST_DBPORT="5432"

# WMS script path
WMS_SCRIPT="/app/bin/wms/wmsManager.sh"

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

print_header "🚀 ADVANCED WMS INTEGRATION TESTS"

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
    (3, '2023-03-01 09:00:00', NULL, 2.3522, 48.8566),
    (4, '2023-04-01 08:00:00', NULL, NULL, NULL),
    (5, '2023-05-01 07:00:00', '2023-05-10 06:00:00', 139.6917, 35.6895)
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

 ((TOTAL_TESTS++))
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
  # Check output
  if echo "$output" | grep -q "$expected_output"; then
   print_test_result "$test_name" 0 "Status and output match expectations"
   ((PASSED_TESTS++))
   return 0
  else
   print_test_result "$test_name" 1 "Status correct but output mismatch. Expected: $expected_output"
   print_status "$YELLOW" "Output: $output"
   ((FAILED_TESTS++))
   return 1
  fi
 else
  print_test_result "$test_name" 1 "Status mismatch. Expected: $expected_status, Got: $status"
  print_status "$YELLOW" "Output: $output"
  ((FAILED_TESTS++))
  return 1
 fi
}

# Function to verify database objects
verify_wms_objects() {
 local object_type="$1"
 local expected_count="$2"
 local test_name="$3"

 ((TOTAL_TESTS++))

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
 "functions")
  local count
  count=$(psql -h "$TEST_DBHOST" -U "$TEST_DBUSER" -d "$TEST_DBNAME" -t -c "SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema = 'wms' AND routine_name IN ('insert_new_notes', 'update_notes');" | tr -d ' ')
  ;;
 esac

 if [ "$count" -eq "$expected_count" ]; then
  print_test_result "$test_name" 0 "$object_type count correct: $count"
  ((PASSED_TESTS++))
  return 0
 else
  print_test_result "$test_name" 1 "$object_type count incorrect. Expected: $expected_count, Got: $count"
  ((FAILED_TESTS++))
  return 1
 fi
}

# Function to test performance
test_performance() {
 local test_name="$1"
 local operation="$2"

 ((TOTAL_TESTS++))
 print_status "$CYAN" "⚡ Testing performance: $test_name"

 # Set environment variables
 export DBNAME="$TEST_DBNAME"
 export DBUSER="$TEST_DBUSER"
 export DBPASSWORD="$TEST_DBPASSWORD"
 export DBHOST="$TEST_DBHOST"
 export DBPORT="$TEST_DBPORT"
 export PGPASSWORD="$TEST_DBPASSWORD"

 # Measure execution time
 local start_time
 local end_time
 local execution_time

 start_time=$(date +%s.%N)

 case "$operation" in
 "install")
  "$WMS_SCRIPT" install > /dev/null 2>&1
  ;;
 "status")
  "$WMS_SCRIPT" status > /dev/null 2>&1
  ;;
 "deinstall")
  "$WMS_SCRIPT" deinstall > /dev/null 2>&1
  ;;
 esac

 end_time=$(date +%s.%N)
 execution_time=$(echo "$end_time - $start_time" | bc)

 # Performance thresholds (in seconds)
 local threshold=5.0

 if (($(echo "$execution_time < $threshold" | bc -l))); then
  print_test_result "$test_name" 0 "Performance OK: ${execution_time}s (threshold: ${threshold}s)"
  ((PASSED_TESTS++))
  return 0
 else
  print_test_result "$test_name" 1 "Performance slow: ${execution_time}s (threshold: ${threshold}s)"
  ((FAILED_TESTS++))
  return 1
 fi
}

# Function to test error handling
test_error_handling() {
 local test_name="$1"
 local command="$2"
 local expected_error="$3"

 ((TOTAL_TESTS++))
 print_status "$YELLOW" "⚠️  Testing error handling: $test_name"

 # Set environment variables
 export DBNAME="$TEST_DBNAME"
 export DBUSER="$TEST_DBUSER"
 export DBPASSWORD="$TEST_DBPASSWORD"
 export DBHOST="$TEST_DBHOST"
 export DBPORT="$TEST_DBPORT"
 export PGPASSWORD="$TEST_DBPASSWORD"

 # Run command and capture output
 local output
 local status
 output=$(eval "$command" 2>&1)
 status=$?

 # Check if error message is present
 if echo "$output" | grep -q "$expected_error"; then
  print_test_result "$test_name" 0 "Error handled correctly: $expected_error"
  ((PASSED_TESTS++))
  return 0
 else
  print_test_result "$test_name" 1 "Error not handled correctly. Expected: $expected_error"
  print_status "$YELLOW" "Output: $output"
  ((FAILED_TESTS++))
  return 1
 fi
}

# Function to test concurrent operations
test_concurrent_operations() {
 local test_name="$1"

 ((TOTAL_TESTS++))
 print_status "$PURPLE" "🔄 Testing concurrent operations: $test_name"

 # Set environment variables
 export DBNAME="$TEST_DBNAME"
 export DBUSER="$TEST_DBUSER"
 export DBPASSWORD="$TEST_DBPASSWORD"
 export DBHOST="$TEST_DBHOST"
 export DBPORT="$TEST_DBPORT"
 export PGPASSWORD="$TEST_DBPASSWORD"

 # Run multiple status checks concurrently
 local pids=()
 local results=()

 for i in {1..3}; do
  "$WMS_SCRIPT" status > /dev/null 2>&1 &
  pids+=($!)
 done

 # Wait for all processes to complete
 for pid in "${pids[@]}"; do
  wait "$pid"
  results+=($?)
 done

 # Check if all processes completed successfully
 local all_success=true
 for result in "${results[@]}"; do
  if [ "$result" -ne 0 ]; then
   all_success=false
   break
  fi
 done

 if [ "$all_success" = true ]; then
  print_test_result "$test_name" 0 "All concurrent operations completed successfully"
  ((PASSED_TESTS++))
  return 0
 else
  print_test_result "$test_name" 1 "Some concurrent operations failed"
  ((FAILED_TESTS++))
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

 print_header "🧪 ADVANCED WMS INTEGRATION TESTS"

 # Test Suite 1: Basic Functionality
 print_header "📋 Test Suite 1: Basic Functionality"

 print_status "$BLUE" "🧪 Running basic functionality tests..."

 # Test 1: Install WMS
 print_status "$BLUE" "🧪 Test 1: Install WMS"
 if run_wms_test "Install WMS" "$WMS_SCRIPT install" 0 "installation completed successfully"; then
  print_status "$GREEN" "✅ Install WMS test passed"
 else
  print_status "$RED" "❌ Install WMS test failed"
 fi

 # Test 2: Check status
 print_status "$BLUE" "🧪 Test 2: Check WMS status"
 if run_wms_test "Check WMS status" "$WMS_SCRIPT status" 0 "WMS is installed"; then
  print_status "$GREEN" "✅ Check status test passed"
 else
  print_status "$RED" "❌ Check status test failed"
 fi

 # Test 3: Prevent double installation
 print_status "$BLUE" "🧪 Test 3: Prevent double installation"
 if run_wms_test "Prevent double installation" "$WMS_SCRIPT install" 0 "already installed"; then
  print_status "$GREEN" "✅ Prevent double installation test passed"
 else
  print_status "$RED" "❌ Prevent double installation test failed"
 fi

 # Test 4: Force reinstall
 print_status "$BLUE" "🧪 Test 4: Force reinstall"
 if run_wms_test "Force reinstall" "$WMS_SCRIPT install --force" 0 "installation completed successfully"; then
  print_status "$GREEN" "✅ Force reinstall test passed"
 else
  print_status "$RED" "❌ Force reinstall test failed"
 fi

 # Test 5: Dry run
 print_status "$BLUE" "🧪 Test 5: Dry run"
 if run_wms_test "Dry run" "$WMS_SCRIPT install --dry-run" 0 "DRY RUN\|already installed"; then
  print_status "$GREEN" "✅ Dry run test passed"
 else
  print_status "$RED" "❌ Dry run test failed"
 fi

 # Test 6: Deinstall
 print_status "$BLUE" "🧪 Test 6: Deinstall WMS"
 if run_wms_test "Deinstall WMS" "$WMS_SCRIPT deinstall" 0 "removal completed successfully"; then
  print_status "$GREEN" "✅ Deinstall test passed"
 else
  print_status "$RED" "❌ Deinstall test failed"
 fi

 # Test 7: Handle deinstall when not installed
 print_status "$BLUE" "🧪 Test 7: Handle deinstall when not installed"
 if run_wms_test "Handle deinstall when not installed" "$WMS_SCRIPT deinstall" 0 "not installed"; then
  print_status "$GREEN" "✅ Handle deinstall when not installed test passed"
 else
  print_status "$RED" "❌ Handle deinstall when not installed test failed"
 fi

 # Test Suite 2: Object Verification
 print_header "📋 Test Suite 2: Object Verification"

 print_status "$BLUE" "🧪 Running object verification tests..."

 # Reinstall for verification
 print_status "$BLUE" "🧪 Reinstalling WMS for verification..."
 if run_wms_test "Reinstall for verification" "$WMS_SCRIPT install" 0 "installation completed successfully"; then
  print_status "$GREEN" "✅ Reinstall for verification passed"
 else
  print_status "$RED" "❌ Reinstall for verification failed"
 fi

 # Verify objects
 print_status "$BLUE" "🧪 Verifying WMS objects..."
 verify_wms_objects "schema" 1 "Verify WMS schema exists"
 verify_wms_objects "table" 1 "Verify WMS table exists"
 verify_wms_objects "triggers" 2 "Verify WMS triggers exist"
 verify_wms_objects "functions" 2 "Verify WMS functions exist"
 verify_wms_objects "notes" 4 "Verify WMS notes count"

 # Clean up
 drop_test_database

 # Summary
 print_header "📊 TEST SUMMARY"
 print_status "$GREEN" "✅ Tests passed: $PASSED_TESTS"
 if [ $FAILED_TESTS -gt 0 ]; then
  print_status "$RED" "❌ Tests failed: $FAILED_TESTS"
 else
  print_status "$GREEN" "🎉 All tests passed!"
 fi
 print_status "$BLUE" "📈 Total tests: $TOTAL_TESTS"

 if [ $FAILED_TESTS -gt 0 ]; then
  exit 1
 else
  exit 0
 fi
}

# Execute main function
main "$@"
