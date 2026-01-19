#!/bin/bash

# Script to run get_country function unit tests
#
# This script executes the SQL unit tests for the get_country function,
# testing it with capital cities, special cases, disputed areas, and
# non-continental territories.
#
# Author: Andres Gomez (AngocA)
# Version: 2025-11-30

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# Source library functions if available (don't fail if not found)
# Note: We skip loading functionsProcess.sh as it may have dependencies
# that aren't available in test environments
# if [[ -f "${PROJECT_ROOT}/bin/lib/functionsProcess.sh" ]]; then
 # shellcheck source=/dev/null
 # source "${PROJECT_ROOT}/bin/lib/functionsProcess.sh" 2>/dev/null || true
# fi

# Default database name (not readonly to allow override via command line)
DBNAME="${DBNAME:-notes}"

# Test file
readonly TEST_FILE="${SCRIPT_DIR}/get_country_function.test.sql"

# Function to print usage
__print_usage() {
 cat << EOF
Usage: $0 [OPTIONS]

Options:
  -d, --database DBNAME    Database name (default: notes)
  -h, --help              Show this help message

Examples:
  $0
  $0 -d test_db
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
 case $1 in
 -d | --database)
  DBNAME="$2"
  shift 2
  ;;
 -h | --help)
  __print_usage
  exit 0
  ;;
 *)
  echo "ERROR: Unknown option: $1" >&2
  __print_usage
  exit 1
  ;;
 esac
done

# Check if test file exists
if [[ ! -f "${TEST_FILE}" ]]; then
 echo "ERROR: Test file not found: ${TEST_FILE}" >&2
 exit 1
fi

# Check if psql is available
if ! command -v psql > /dev/null 2>&1; then
 echo "ERROR: psql command not found" >&2
 exit 1
fi

# Check database connection
if ! psql -d "${DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
 echo "ERROR: Cannot connect to database: ${DBNAME}" >&2
 exit 1
fi

# Check if get_country function exists
if ! psql -d "${DBNAME}" -t -c "SELECT 1 FROM pg_proc WHERE proname = 'get_country';" | grep -q 1; then
 echo "ERROR: Function get_country does not exist in database: ${DBNAME}" >&2
 exit 1
fi

# Check if countries table exists
if ! psql -d "${DBNAME}" -t -c "SELECT 1 FROM information_schema.tables WHERE table_name = 'countries';" | grep -q 1; then
 echo "ERROR: Table countries does not exist in database: ${DBNAME}" >&2
 exit 1
fi

# Setup test countries if setup script exists
SETUP_SCRIPT="${PROJECT_ROOT}/tests/setup_test_countries_for_get_country.sh"
if [[ -f "${SETUP_SCRIPT}" ]]; then
 echo ""
 echo "=========================================="
 echo "Setting up test countries for get_country tests"
 echo "=========================================="
 # Execute setup script in a subshell to avoid affecting current environment
 set +e
 if bash "${SETUP_SCRIPT}" 2>&1; then
  echo "Test countries setup completed"
 else
  echo "WARNING: Test countries setup failed, continuing anyway..."
 fi
 set -e
fi

# Run tests
echo "=========================================="
echo "Running get_country function unit tests"
echo "=========================================="
echo "Database: ${DBNAME}"
echo "Test file: ${TEST_FILE}"
echo ""

# Execute test file
if psql -d "${DBNAME}" -f "${TEST_FILE}" 2>&1; then
 echo ""
 echo "=========================================="
 echo "Basic tests completed successfully"
 echo "=========================================="
 
 # Also run return values tests if available
 RETURN_VALUES_TEST="${SCRIPT_DIR}/get_country_return_values.test.sql"
 if [[ -f "${RETURN_VALUES_TEST}" ]]; then
  echo ""
  echo "=========================================="
  echo "Running return values tests (bug detection)"
  echo "=========================================="
  if psql -d "${DBNAME}" -f "${RETURN_VALUES_TEST}" 2>&1; then
   echo ""
   echo "Return values tests passed"
  else
   echo ""
   echo "=========================================="
   echo "Return values tests failed"
   echo "=========================================="
   exit 1
  fi
 fi

 # Also run partial failures tests if available
 PARTIAL_FAILURES_TEST="${SCRIPT_DIR}/get_country_partial_failures.test.sql"
 if [[ -f "${PARTIAL_FAILURES_TEST}" ]]; then
  echo ""
  echo "=========================================="
  echo "Running partial failures tests"
  echo "=========================================="
  if psql -d "${DBNAME}" -f "${PARTIAL_FAILURES_TEST}" 2>&1; then
   echo ""
   echo "Partial failures tests passed"
  else
   echo ""
   echo "=========================================="
   echo "Partial failures tests failed"
   echo "=========================================="
   exit 1
  fi
 fi

 echo ""
 echo "=========================================="
 echo "All tests completed successfully"
 echo "=========================================="
 exit 0
else
 echo ""
 echo "=========================================="
 echo "Tests failed"
 echo "=========================================="
 exit 1
fi
