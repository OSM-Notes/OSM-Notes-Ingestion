#!/bin/bash

# Script to run get_country return values unit tests
#
# This script executes tests that verify get_country() returns correct values:
# - Valid countries return valid country_id (> 0), NOT -1 or -2
# - -1 is ONLY returned for known international waters
# - -2 is returned for unknown/not found countries
#
# These tests would have detected the bug where valid countries returned -1
#
# Author: Andres Gomez (AngocA)
# Version: 2026-01-19

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
readonly TEST_FILE="${SCRIPT_DIR}/get_country_return_values.test.sql"

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
echo "Running get_country return values tests"
echo "=========================================="
echo "Database: ${DBNAME}"
echo "Test file: ${TEST_FILE}"
echo ""
echo "These tests verify:"
echo "  1. Valid countries return valid country_id (> 0), NOT -1 or -2"
echo "  2. -1 is ONLY returned for known international waters"
echo "  3. -2 is returned for unknown/not found countries"
echo "  4. Return value semantics are correct"
echo ""

# Execute test file
if psql -d "${DBNAME}" -f "${TEST_FILE}" 2>&1; then
 echo ""
 echo "=========================================="
 echo "Tests completed successfully"
 echo "=========================================="
 exit 0
else
 echo ""
 echo "=========================================="
 echo "Tests failed"
 echo "=========================================="
 exit 1
fi
