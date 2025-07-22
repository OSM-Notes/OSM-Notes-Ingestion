#!/bin/bash

# Test runner script for OSM-Notes-profile
# Author: Andres Gomez (AngocA)
# Version: 2025-07-20

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

# Test configuration
TEST_DBNAME="osm_notes_test"
TEST_DBUSER="test_user"
TEST_DBPASSWORD="test_pass"
TEST_DBHOST="localhost"
TEST_DBPORT="5432"

# Test results
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Logging functions
log_info() {
  echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $*"
}

# Check prerequisites
check_prerequisites() {
  log_info "Checking prerequisites..."
  
  # Check if BATS is installed
  if ! command -v bats &> /dev/null; then
    log_error "BATS is not installed. Please install it first:"
    log_error "  sudo apt-get install bats"
    log_error "  or visit: https://github.com/bats-core/bats-core"
    exit 1
  fi
  
  # Check if PostgreSQL is running
  if ! pg_isready -h "${TEST_DBHOST}" -p "${TEST_DBPORT}" &> /dev/null; then
    log_error "PostgreSQL is not running or not accessible"
    log_error "Please start PostgreSQL and ensure it's accessible"
    exit 1
  fi
  
  # Check if pgTAP is installed
  if ! psql -d postgres -c "SELECT 1 FROM pg_extension WHERE extname = 'pgtap';" &> /dev/null; then
    log_warning "pgTAP extension not found. SQL tests will be skipped."
    log_warning "To install pgTAP:"
    log_warning "  sudo apt-get install postgresql-15-pgtap"
  fi
  
  log_success "Prerequisites check completed"
}

# Setup test database
setup_test_database() {
  log_info "Setting up test database..."
  
  # Drop database if exists
  dropdb --if-exists "${TEST_DBNAME}" 2>/dev/null || true
  
  # Create database
  createdb "${TEST_DBNAME}" 2>/dev/null || {
    log_error "Failed to create test database ${TEST_DBNAME}"
    return 1
  }
  
  # Create base tables
  log_info "Creating base tables..."
  psql -d "${TEST_DBNAME}" -f "${PROJECT_ROOT}/sql/process/processPlanetNotes_22_createBaseTables_tables.sql" 2>/dev/null || {
    log_error "Failed to create base tables"
    return 1
  }
  
  # Create functions and procedures
  log_info "Creating functions and procedures..."
  psql -d "${TEST_DBNAME}" -f "${PROJECT_ROOT}/sql/functionsProcess_21_createFunctionToGetCountry.sql" 2>/dev/null || {
    log_error "Failed to create get_country function"
    return 1
  }
  
  psql -d "${TEST_DBNAME}" -f "${PROJECT_ROOT}/sql/functionsProcess_22_createProcedure_insertNote.sql" 2>/dev/null || {
    log_error "Failed to create insert_note procedure"
    return 1
  }
  
  psql -d "${TEST_DBNAME}" -f "${PROJECT_ROOT}/sql/functionsProcess_23_createProcedure_insertNoteComment.sql" 2>/dev/null || {
    log_error "Failed to create insert_note_comment procedure"
    return 1
  }
  
  log_success "Test database setup completed"
}

# Cleanup test database
cleanup_test_database() {
  log_info "Cleaning up test database..."
  dropdb --if-exists "${TEST_DBNAME}" 2>/dev/null || true
  log_success "Test database cleanup completed"
}

# Run BATS tests
run_bats_tests() {
  log_info "Running BATS tests..."
  
  local bats_tests=(
    "${SCRIPT_DIR}/unit/bash/functionsProcess.test.bats"
    "${SCRIPT_DIR}/unit/bash/processPlanetNotes.test.bats"
  )
  
  log_info "Total BATS tests to run: ${#bats_tests[@]}"
  log_info "BATS tests: ${bats_tests[*]}"
  
  local bats_tests=(
    "${SCRIPT_DIR}/unit/bash/functionsProcess.test.bats"
    "${SCRIPT_DIR}/unit/bash/processPlanetNotes.test.bats"
  )
  
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

# Run pgTAP tests
run_pgtap_tests() {
  log_info "Running pgTAP tests..."
  
  local pgtap_tests=(
    "${SCRIPT_DIR}/unit/sql/functions.test.sql"
    "${SCRIPT_DIR}/unit/sql/tables.test.sql"
  )
  
  for test_file in "${pgtap_tests[@]}"; do
    if [[ -f "${test_file}" ]]; then
      log_info "Running $(basename "${test_file}")..."
      
      if pg_prove -d "${TEST_DBNAME}" "${test_file}"; then
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
  done
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
  echo "OSM-Notes-profile Test Suite"
  echo "=========================================="
  echo
  
  # Check prerequisites
  check_prerequisites
  
  # Setup test database
  setup_test_database
  
  # Run BATS tests
  run_bats_tests
  
  # Run pgTAP tests
  run_pgtap_tests
  
  # Cleanup
  cleanup_test_database
  
  # Print summary
  print_summary
}

# Handle script arguments
case "${1:-}" in
  --help|-h)
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --help, -h    Show this help message"
    echo "  --bats-only   Run only BATS tests"
    echo "  --pgtap-only  Run only pgTAP tests"
    echo "  --no-cleanup  Don't cleanup test database after tests"
    echo
    echo "Environment variables:"
    echo "  TEST_DBNAME     Test database name (default: osm_notes_test)"
    echo "  TEST_DBUSER     Test database user (default: test_user)"
    echo "  TEST_DBPASSWORD Test database password (default: test_pass)"
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
  --pgtap-only)
    check_prerequisites
    setup_test_database
    run_pgtap_tests
    cleanup_test_database
    print_summary
    ;;
  --no-cleanup)
    check_prerequisites
    setup_test_database
    run_bats_tests
    run_pgtap_tests
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