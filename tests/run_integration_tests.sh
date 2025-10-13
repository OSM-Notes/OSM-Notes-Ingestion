#!/bin/bash

# Integration Tests Runner for GitHub Actions
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

# Function to run all integration tests
__run_all_integration_tests() {
 log_info "Running all integration tests..."

 local -r INTEGRATION_DIR="${SCRIPT_DIR}/integration"

 if [[ ! -d "${INTEGRATION_DIR}" ]]; then
  log_error "Integration test directory not found: ${INTEGRATION_DIR}"
  return 1
 fi

 # Run each integration test
 local TEST_FILES
 TEST_FILES=$(find "${INTEGRATION_DIR}" -name "*.bats" -type f | sort)

 if [[ -z "${TEST_FILES}" ]]; then
  log_warning "No integration tests found in ${INTEGRATION_DIR}"
  return 0
 fi

 local TEST_RESULT=0
 for TEST_FILE in ${TEST_FILES}; do
  local TEST_NAME
  TEST_NAME=$(basename "${TEST_FILE}" .bats)
  # shellcheck disable=SC2310
  __run_test_suite "${TEST_FILE}" "${TEST_NAME}" || TEST_RESULT=1
 done

 return "${TEST_RESULT}"
}

# Function to run process-api tests
__run_process_api_tests() {
 log_info "Running process-api integration tests..."

 local TEST_RESULT=0

 # shellcheck disable=SC2310
 __run_test_suite \
  "${SCRIPT_DIR}/integration/processAPINotes_parallel_error_integration.test.bats" \
  "processAPINotes parallel error integration" || TEST_RESULT=1

 # shellcheck disable=SC2310
 __run_test_suite \
  "${SCRIPT_DIR}/integration/processAPI_historical_e2e.test.bats" \
  "processAPI historical end-to-end" || TEST_RESULT=1

 return "${TEST_RESULT}"
}

# Function to run process-planet tests
__run_process_planet_tests() {
 log_info "Running process-planet integration tests..."

 local TEST_RESULT=0

 # shellcheck disable=SC2310
 __run_test_suite \
  "${SCRIPT_DIR}/integration/mock_planet_processing.test.bats" \
  "mock planet processing integration" || TEST_RESULT=1

 # shellcheck disable=SC2310
 __run_test_suite \
  "${SCRIPT_DIR}/integration/boundary_processing_error_integration.test.bats" \
  "boundary processing error integration" || TEST_RESULT=1

 return "${TEST_RESULT}"
}

# Function to run cleanup tests
__run_cleanup_tests() {
 log_info "Running cleanup integration tests..."

 # Note: Cleanup tests may be included in other integration tests
 # For now, we'll check if any cleanup-specific tests exist

 log_info "Cleanup tests are integrated with other test suites"
 return 0
}

# Function to run WMS tests
__run_wms_tests() {
 log_info "Running WMS integration tests..."

 local TEST_RESULT=0

 # shellcheck disable=SC2310
 __run_test_suite \
  "${SCRIPT_DIR}/integration/wms_integration.test.bats" \
  "WMS integration" || TEST_RESULT=1

 return "${TEST_RESULT}"
}

# Function to run ETL tests
__run_etl_tests() {
 log_info "Running ETL integration tests..."

 local TEST_RESULT=0

 # shellcheck disable=SC2310
 __run_test_suite \
  "${SCRIPT_DIR}/integration/ETL_enhanced_integration.test.bats" \
  "ETL enhanced integration" || TEST_RESULT=1

 # shellcheck disable=SC2310
 __run_test_suite \
  "${SCRIPT_DIR}/integration/datamart_enhanced_integration.test.bats" \
  "datamart enhanced integration" || TEST_RESULT=1

 return "${TEST_RESULT}"
}

# Function to run end-to-end tests
__run_e2e_tests() {
 log_info "Running end-to-end integration tests..."

 local TEST_RESULT=0

 # shellcheck disable=SC2310
 __run_test_suite \
  "${SCRIPT_DIR}/integration/end_to_end.test.bats" \
  "end-to-end integration" || TEST_RESULT=1

 return "${TEST_RESULT}"
}

# Function to show test summary
__show_test_summary() {
 echo
 echo "=========================================="
 echo "Integration Test Results Summary"
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
Integration Tests Runner for GitHub Actions

Usage: $0 [OPTIONS]

Options:
  --help, -h          Show this help message
  --all               Run all integration tests (default)
  --process-api       Run process-api integration tests
  --process-planet    Run process-planet integration tests
  --cleanup           Run cleanup integration tests
  --wms               Run WMS integration tests
  --etl               Run ETL integration tests
  --e2e               Run end-to-end integration tests

Environment Variables:
  DBHOST              Database host (default: localhost)
  DBPORT              Database port (default: 5432)
  DBUSER              Database user (default: postgres)
  DBPASSWORD          Database password (default: postgres)
  DBNAME              Database name (default: osm_notes_test)
  LOG_LEVEL           Logging level (default: INFO)

Examples:
  $0 --all                    # Run all integration tests
  $0 --process-api            # Run only process-api tests
  $0 --etl                    # Run only ETL tests

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
  --process-api)
   RUN_MODE="process-api"
   shift
   ;;
  --process-planet)
   RUN_MODE="process-planet"
   shift
   ;;
  --cleanup)
   RUN_MODE="cleanup"
   shift
   ;;
  --wms)
   RUN_MODE="wms"
   shift
   ;;
  --etl)
   RUN_MODE="etl"
   shift
   ;;
  --e2e)
   RUN_MODE="e2e"
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
 export DBPASSWORD="${DBPASSWORD:-postgres}"
 export DBNAME="${DBNAME:-osm_notes_test}"
 export LOG_LEVEL="${LOG_LEVEL:-INFO}"

 # Ensure test directories exist
 mkdir -p "${SCRIPT_DIR}/tmp"
 mkdir -p "${SCRIPT_DIR}/output"
 mkdir -p "${SCRIPT_DIR}/results"

 log_info "Starting integration tests in mode: ${RUN_MODE}"
 log_info "Database: ${DBUSER}@${DBHOST}:${DBPORT}/${DBNAME}"

 # Change to project root to ensure correct paths
 cd "${PROJECT_ROOT}"

 # Run tests based on mode
 local FINAL_RESULT=0

 case "${RUN_MODE}" in
 all)
  # shellcheck disable=SC2310
  __run_all_integration_tests || FINAL_RESULT=1
  ;;
 process-api)
  # shellcheck disable=SC2310
  __run_process_api_tests || FINAL_RESULT=1
  ;;
 process-planet)
  # shellcheck disable=SC2310
  __run_process_planet_tests || FINAL_RESULT=1
  ;;
 cleanup)
  # shellcheck disable=SC2310
  __run_cleanup_tests || FINAL_RESULT=1
  ;;
 wms)
  # shellcheck disable=SC2310
  __run_wms_tests || FINAL_RESULT=1
  ;;
 etl)
  # shellcheck disable=SC2310
  __run_etl_tests || FINAL_RESULT=1
  ;;
 e2e)
  # shellcheck disable=SC2310
  __run_e2e_tests || FINAL_RESULT=1
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
  log_success "All integration tests completed successfully!"
 else
  log_warning "Some integration tests failed"
 fi

 exit "${FINAL_RESULT}"
}

# Run main function
main "$@"
