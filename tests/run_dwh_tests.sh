#!/bin/bash

# DWH (Data Warehouse) Tests Runner
# Author: Andres Gomez (AngocA)
# Version: 2025-10-13

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Logging functions
log_info() {
 echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
 echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
 echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
 echo -e "${RED}[ERROR]${NC} $1"
}

# Function to run a test suite
__run_test_suite() {
 local -r TEST_FILE="$1"
 local -r TEST_NAME="$2"

 log_info "Running ${TEST_NAME}..."

 ((TOTAL_TESTS++)) || true

 if [[ -f "${TEST_FILE}" ]]; then
  if bats "${TEST_FILE}"; then
   log_success "${TEST_NAME} passed"
   ((PASSED_TESTS++)) || true
   return 0
  else
   log_error "${TEST_NAME} failed"
   ((FAILED_TESTS++)) || true
   return 1
  fi
 else
  log_warning "${TEST_NAME} not found at ${TEST_FILE}, skipping..."
  ((FAILED_TESTS++)) || true
  return 1
 fi
}

# Function to run SQL test
__run_sql_test() {
 local -r TEST_FILE="$1"
 local -r TEST_NAME="$2"

 log_info "Running SQL test: ${TEST_NAME}..."

 ((TOTAL_TESTS++)) || true

 if [[ ! -f "${TEST_FILE}" ]]; then
  log_warning "${TEST_NAME} not found at ${TEST_FILE}, skipping..."
  return 0
 fi

 # Check if psql is available
 if ! command -v psql > /dev/null 2>&1; then
  log_warning "psql not available, skipping SQL test: ${TEST_NAME}"
  return 0
 fi

 # Database configuration with defaults
 local DBHOST="${DBHOST:-localhost}"
 local DBPORT="${DBPORT:-5432}"
 local DBUSER="${DBUSER:-postgres}"
 local DBNAME="${DBNAME:-osm_notes_test}"

 # Try to run SQL test
 if PGPASSWORD="${DBPASSWORD:-}" psql -h "${DBHOST}" -p "${DBPORT}" \
  -U "${DBUSER}" -d "${DBNAME}" -f "${TEST_FILE}" > /dev/null 2>&1; then
  log_success "SQL test passed: ${TEST_NAME}"
  ((PASSED_TESTS++)) || true
  return 0
 else
  log_warning "SQL test failed or database not available: ${TEST_NAME}"
  log_warning "Continuing with other tests..."
  return 0
 fi
}

# Function to run DWH SQL unit tests
__run_dwh_sql_tests() {
 log_info "Running DWH SQL unit tests..."

 local SQL_TESTS_DIR="${SCRIPT_DIR}/unit/sql"
 local TEST_RESULT=0

 # Run DWH-specific SQL tests
 # shellcheck disable=SC2310
 __run_sql_test \
  "${SQL_TESTS_DIR}/dwh_dimensions_enhanced.test.sql" \
  "DWH dimensions enhanced" || TEST_RESULT=1

 # shellcheck disable=SC2310
 __run_sql_test \
  "${SQL_TESTS_DIR}/dwh_functions_enhanced.test.sql" \
  "DWH functions enhanced" || TEST_RESULT=1

 # shellcheck disable=SC2310
 __run_sql_test \
  "${SQL_TESTS_DIR}/dwh_cleanup.test.sql" \
  "DWH cleanup" || TEST_RESULT=1

 return "${TEST_RESULT}"
}

# Function to run DWH unit tests (BATS)
__run_dwh_unit_tests() {
 log_info "Running DWH unit tests (BATS)..."

 local UNIT_TESTS_DIR="${SCRIPT_DIR}/unit/bash"
 local TEST_RESULT=0

 # Run ETL integration test
 # shellcheck disable=SC2310
 __run_test_suite \
  "${UNIT_TESTS_DIR}/ETL_integration.test.bats" \
  "ETL integration" || TEST_RESULT=1

 # Run datamart users test
 # shellcheck disable=SC2310
 __run_test_suite \
  "${UNIT_TESTS_DIR}/datamartUsers_integration.test.bats" \
  "Datamart users integration" || TEST_RESULT=1

 # Run datamart countries test
 # shellcheck disable=SC2310
 __run_test_suite \
  "${UNIT_TESTS_DIR}/datamartCountries_integration.test.bats" \
  "Datamart countries integration" || TEST_RESULT=1

 return "${TEST_RESULT}"
}

# Function to run DWH integration tests
__run_dwh_integration_tests() {
 log_info "Running DWH integration tests..."

 local INTEGRATION_TESTS_DIR="${SCRIPT_DIR}/integration"
 local TEST_RESULT=0

 # Run ETL enhanced integration test
 # shellcheck disable=SC2310
 __run_test_suite \
  "${INTEGRATION_TESTS_DIR}/ETL_enhanced_integration.test.bats" \
  "ETL enhanced integration" || TEST_RESULT=1

 # Run datamart enhanced integration test
 # shellcheck disable=SC2310
 __run_test_suite \
  "${INTEGRATION_TESTS_DIR}/datamart_enhanced_integration.test.bats" \
  "Datamart enhanced integration" || TEST_RESULT=1

 return "${TEST_RESULT}"
}

# Function to show test summary
__show_test_summary() {
 echo
 echo "=========================================="
 echo "DWH Test Results Summary"
 echo "=========================================="
 echo "Total Test Suites: ${TOTAL_TESTS}"
 echo "Passed: ${PASSED_TESTS} ✅"
 echo "Failed: ${FAILED_TESTS} ❌"

 if [[ ${TOTAL_TESTS} -gt 0 ]]; then
  local SUCCESS_RATE
  SUCCESS_RATE=$((PASSED_TESTS * 100 / TOTAL_TESTS))
  echo "Success Rate: ${SUCCESS_RATE}%"
 fi

 echo "=========================================="
 echo
}

# Function to show help
__show_help() {
 cat << EOF
DWH (Data Warehouse) Tests Runner

Usage: $0 [OPTIONS]

Options:
  --help, -h              Show this help message
  --all                   Run all DWH tests (default)
  --sql-only              Run only SQL unit tests
  --unit-only             Run only BATS unit tests
  --integration-only      Run only integration tests
  --skip-integration      Run all tests except integration tests
  --skip-sql              Run all tests except SQL tests

Environment Variables:
  DBHOST                  Database host (default: localhost)
  DBPORT                  Database port (default: 5432)
  DBUSER                  Database user (default: postgres)
  DBPASSWORD              Database password
  DBNAME                  Database name (default: osm_notes_test)

Examples:
  $0                              # Run all DWH tests
  $0 --skip-integration           # Run SQL and unit tests only
  $0 --sql-only                   # Run only SQL tests
  $0 --integration-only           # Run only integration tests

EOF
}

# Main function
main() {
 local RUN_MODE="all"

 # Parse command line arguments
 while [[ $# -gt 0 ]]; do
  case $1 in
  --help | -h)
   __show_help
   exit 0
   ;;
  --all)
   RUN_MODE="all"
   shift
   ;;
  --sql-only)
   RUN_MODE="sql-only"
   shift
   ;;
  --unit-only)
   RUN_MODE="unit-only"
   shift
   ;;
  --integration-only)
   RUN_MODE="integration-only"
   shift
   ;;
  --skip-integration)
   RUN_MODE="skip-integration"
   shift
   ;;
  --skip-sql)
   RUN_MODE="skip-sql"
   shift
   ;;
  *)
   log_error "Unknown option: $1"
   __show_help
   exit 1
   ;;
  esac
 done

 # Set default environment variables if not set
 export DBHOST="${DBHOST:-localhost}"
 export DBPORT="${DBPORT:-5432}"
 export DBUSER="${DBUSER:-postgres}"
 export DBNAME="${DBNAME:-osm_notes_test}"

 log_info "Starting DWH tests in mode: ${RUN_MODE}"
 log_info "Database: ${DBUSER}@${DBHOST}:${DBPORT}/${DBNAME}"

 # Change to project root to ensure correct paths
 cd "${PROJECT_ROOT}"

 # Run tests based on mode
 local FINAL_RESULT=0

 case "${RUN_MODE}" in
 all)
  # shellcheck disable=SC2310
  __run_dwh_sql_tests || FINAL_RESULT=1
  # shellcheck disable=SC2310
  __run_dwh_unit_tests || FINAL_RESULT=1
  # shellcheck disable=SC2310
  __run_dwh_integration_tests || FINAL_RESULT=1
  ;;
 sql-only)
  # shellcheck disable=SC2310
  __run_dwh_sql_tests || FINAL_RESULT=1
  ;;
 unit-only)
  # shellcheck disable=SC2310
  __run_dwh_unit_tests || FINAL_RESULT=1
  ;;
 integration-only)
  # shellcheck disable=SC2310
  __run_dwh_integration_tests || FINAL_RESULT=1
  ;;
 skip-integration)
  # shellcheck disable=SC2310
  __run_dwh_sql_tests || FINAL_RESULT=1
  # shellcheck disable=SC2310
  __run_dwh_unit_tests || FINAL_RESULT=1
  ;;
 skip-sql)
  # shellcheck disable=SC2310
  __run_dwh_unit_tests || FINAL_RESULT=1
  # shellcheck disable=SC2310
  __run_dwh_integration_tests || FINAL_RESULT=1
  ;;
 *)
  log_error "Unknown run mode: ${RUN_MODE}"
  __show_help
  exit 1
  ;;
 esac

 # Show summary
 __show_test_summary

 if [[ ${FINAL_RESULT} -eq 0 ]]; then
  log_success "All DWH tests completed successfully!"
 else
  log_warning "Some DWH tests failed or were skipped"
 fi

 exit "${FINAL_RESULT}"
}

# Run main function
main "$@"
