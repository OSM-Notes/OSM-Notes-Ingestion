#!/bin/bash

# Simple Test Runner for OSM-Notes-profile (No Docker Required)
# Author: Andres Gomez (AngocA)
# Version: 2025-07-20

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Test configuration
TEST_DBNAME="${TEST_DBNAME:-osm_notes_test}"
TEST_DBUSER="${TEST_DBUSER:-$(whoami)}"
TEST_DBPASSWORD="${TEST_DBPASSWORD:-}"
TEST_DBHOST="${TEST_DBHOST:-localhost}"
TEST_DBPORT="${TEST_DBPORT:-5432}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"
MAX_THREADS="${MAX_THREADS:-2}"

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Function to check prerequisites
check_prerequisites() {
  log_info "Checking prerequisites..."

  # Check if PostgreSQL is running
  if ! pg_isready -h "${TEST_DBHOST}" -p "${TEST_DBPORT}" -U "${TEST_DBUSER}" &> /dev/null; then
    log_error "PostgreSQL is not accessible"
    log_info "Please ensure PostgreSQL is running and accessible"
    exit 1
  fi

  # Check if BATS is installed
  if ! command -v bats &> /dev/null; then
    log_error "BATS is not installed"
    log_info "Please install BATS: sudo apt-get install bats"
    exit 1
  fi

  # Check if psql is available
  if ! command -v psql &> /dev/null; then
    log_error "psql is not installed"
    log_info "Please install PostgreSQL client"
    exit 1
  fi

  log_success "Prerequisites check completed"
}

# Function to setup test database
setup_test_database() {
  log_info "Setting up test database..."

  # Create test database if it doesn't exist
  if ! psql -h "${TEST_DBHOST}" -p "${TEST_DBPORT}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "SELECT 1;" &> /dev/null; then
    log_info "Creating test database..."
    createdb -h "${TEST_DBHOST}" -p "${TEST_DBPORT}" -U "${TEST_DBUSER}" "${TEST_DBNAME}"
  fi

  # Create base tables
  log_info "Creating base tables..."
  psql -h "${TEST_DBHOST}" -p "${TEST_DBPORT}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -f "${PROJECT_ROOT}/sql/process/processPlanetNotes_21_createBaseTables_enum.sql" 2> /dev/null || true
  psql -h "${TEST_DBHOST}" -p "${TEST_DBPORT}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -f "${PROJECT_ROOT}/sql/process/processPlanetNotes_22_createBaseTables_tables.sql" 2> /dev/null || true
  psql -h "${TEST_DBHOST}" -p "${TEST_DBPORT}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -f "${PROJECT_ROOT}/sql/process/processPlanetNotes_23_createBaseTables_constraints.sql" 2> /dev/null || true

  # Create functions and procedures
  log_info "Creating functions and procedures..."
  psql -h "${TEST_DBHOST}" -p "${TEST_DBPORT}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -f "${PROJECT_ROOT}/sql/functionsProcess_21_createFunctionToGetCountry.sql" 2> /dev/null || true
  psql -h "${TEST_DBHOST}" -p "${TEST_DBPORT}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -f "${PROJECT_ROOT}/sql/functionsProcess_22_createProcedure_insertNote.sql" 2> /dev/null || true
  psql -h "${TEST_DBHOST}" -p "${TEST_DBPORT}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -f "${PROJECT_ROOT}/sql/functionsProcess_23_createProcedure_insertNoteComment.sql" 2> /dev/null || true

  log_success "Test database setup completed"
}

# Function to cleanup test database
cleanup_test_database() {
  log_info "Cleaning up test database..."

  # Drop test database
  dropdb -h "${TEST_DBHOST}" -p "${TEST_DBPORT}" -U "${TEST_DBUSER}" "${TEST_DBNAME}" 2> /dev/null || true

  log_success "Test database cleanup completed"
}

# Function to run BATS tests
run_bats_tests() {
  log_info "Running BATS tests..."

  local bats_tests=(
    "${SCRIPT_DIR}/unit/bash/functionsProcess.test.bats"
    "${SCRIPT_DIR}/unit/bash/processPlanetNotes.test.bats"
  )

  log_info "Total BATS tests to run: ${#bats_tests[@]}"
  log_info "BATS tests: ${bats_tests[*]}"

  for test_file in "${bats_tests[@]}"; do
    log_info "Processing test file: ${test_file}"
    if [[ -f "${test_file}" ]]; then
      log_info "Running $(basename "${test_file}")..."
      log_info "Test file path: ${test_file}"

      # Set environment variables for tests
      export TEST_DBNAME="${TEST_DBNAME}"
      export TEST_DBUSER="${TEST_DBUSER}"
      export TEST_DBPASSWORD="${TEST_DBPASSWORD}"
      export TEST_DBHOST="${TEST_DBHOST}"
      export TEST_DBPORT="${TEST_DBPORT}"

      log_info "Executing bats for: ${test_file}"
      if bats "${test_file}"; then
        log_success "$(basename "${test_file}") passed"
        ((PASSED_TESTS++))
      else
        log_error "$(basename "${test_file}") failed"
        ((FAILED_TESTS++))
      fi
      ((TOTAL_TESTS++))
    else
      log_warning "Test file not found: ${test_file}"
    fi
    log_info "Completed processing: ${test_file}"
    log_info "Moving to next test file..."
  done
  log_info "BATS tests completed"
  log_info "Total tests processed: ${TOTAL_TESTS}"
  log_info "Passed tests: ${PASSED_TESTS}"
  log_info "Failed tests: ${FAILED_TESTS}"
}

# Function to run end-to-end tests
run_e2e_tests() {
  log_info "Running end-to-end tests..."

  local e2e_test="${SCRIPT_DIR}/integration/end_to_end.test.bats"

  if [[ -f "${e2e_test}" ]]; then
    log_info "Running end-to-end tests..."

    # Set environment variables for tests
    export TEST_DBNAME="${TEST_DBNAME}"
    export TEST_DBUSER="${TEST_DBUSER}"
    export TEST_DBPASSWORD="${TEST_DBPASSWORD}"
    export TEST_DBHOST="${TEST_DBHOST}"
    export TEST_DBPORT="${TEST_DBPORT}"

    if bats "${e2e_test}"; then
      log_success "End-to-end tests passed"
      ((PASSED_TESTS++))
    else
      log_error "End-to-end tests failed"
      ((FAILED_TESTS++))
    fi
    ((TOTAL_TESTS++))
  else
    log_warning "End-to-end test file not found: ${e2e_test}"
  fi
}

# Print test summary
print_summary() {
  echo
  echo "=========================================="
  echo "TEST SUMMARY"
  echo "=========================================="
  echo "Total tests: ${TOTAL_TESTS}"
  echo "Passed: ${PASSED_TESTS}"
  echo "Failed: ${FAILED_TESTS}"

  if [[ ${FAILED_TESTS} -eq 0 ]]; then
    log_success "All tests passed! 🎉"
    exit 0
  else
    log_error "Some tests failed! ❌"
    exit 1
  fi
}

# Main function
main() {
  echo "=========================================="
  echo "OSM-Notes-profile Simple Test Suite"
  echo "=========================================="
  echo

  # Check prerequisites
  check_prerequisites

  # Setup test database
  setup_test_database

  # Run BATS tests
  run_bats_tests

  # Cleanup
  cleanup_test_database

  # Print summary
  print_summary
}

# Handle script arguments
case "${1:-}" in
--help | -h)
  echo "Usage: $0 [OPTIONS]"
  echo
  echo "Options:"
  echo "  --help, -h           Show this help message"
  echo "  --bats-only          Run only BATS tests"
  echo "  --e2e-only           Run only end-to-end tests"
  echo "  --no-cleanup         Don't cleanup test database after tests"
  echo
  echo "Environment variables:"
  echo "  TEST_DBNAME     Test database name (default: osm_notes_test)"
  echo "  TEST_DBUSER     Test database user (default: testuser)"
  echo "  TEST_DBPASSWORD Test database password (default: testpass)"
  echo "  TEST_DBHOST     Test database host (default: localhost)"
  echo "  TEST_DBPORT     Test database port (default: 5432)"
  exit 0
  ;;
--bats-only)
  check_prerequisites
  setup_test_database
  run_bats_tests
  cleanup_test_database
  print_summary
  ;;
--e2e-only)
  check_prerequisites
  setup_test_database
  run_e2e_tests
  cleanup_test_database
  print_summary
  ;;
--no-cleanup)
  check_prerequisites
  setup_test_database
  run_bats_tests
  run_e2e_tests
  print_summary
  ;;
"")
  main
  ;;
*)
  log_error "Unknown option: $1"
  log_error "Use --help for usage information"
  exit 1
  ;;
esac
