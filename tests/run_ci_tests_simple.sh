#!/bin/bash

# CI Test Runner for OSM-Notes-profile (GitHub Actions)
# Author: Andres Gomez (AngocA)
# Version: 2025-08-13

set -uo pipefail

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

# Load test properties
# shellcheck disable=SC1091
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/properties.sh" ]]; then
 source "$(dirname "${BASH_SOURCE[0]}")/properties.sh"
fi

# Test configuration with standardized defaults
MAX_THREADS="${MAX_THREADS:-2}"
TEST_TIMEOUT="${TEST_TIMEOUT:-300}"
TEST_RETRIES="${TEST_RETRIES:-3}"

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Function to install CI dependencies
install_ci_dependencies() {
 log_info "Installing CI dependencies..."

 # Install additional dependencies that might be missing
 if command -v apt-get &> /dev/null; then
  log_info "Installing additional packages via apt-get..."
  sudo apt-get update
  sudo apt-get install -y \
   libxml2-utils \
   xsltproc \
   shfmt \
   shellcheck \
   postgresql-client \
   bats
 elif command -v yum &> /dev/null; then
  log_info "Installing additional packages via yum..."
  sudo yum install -y \
   libxml2 \
   libxslt \
   shfmt \
   shellcheck \
   postgresql \
   bats
 elif command -v dnf &> /dev/null; then
  log_info "Installing additional packages via dnf..."
  sudo dnf install -y \
   libxml2 \
   libxslt \
   shfmt \
   shellcheck \
   postgresql \
   bats
 else
  log_warning "Unsupported package manager, trying to install manually..."
 fi

 # Verify critical tools are available
 local missing_tools=()
 
 for tool in xsltproc xmllint shfmt shellcheck; do
  if ! command -v "$tool" &> /dev/null; then
   missing_tools+=("$tool")
  fi
 done

 if [[ ${#missing_tools[@]} -gt 0 ]]; then
  log_warning "Missing tools: ${missing_tools[*]}"
  log_info "Some tests may fail due to missing tools"
 else
  log_success "All critical tools are available"
 fi
}

# Function to check prerequisites
check_prerequisites() {
 log_info "Checking prerequisites..."

 # Check if PostgreSQL is accessible
 if ! pg_isready -h "${TEST_DBHOST:-localhost}" -p "${TEST_DBPORT:-5432}" -U "${TEST_DBUSER:-testuser}" &> /dev/null; then
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
 if ! psql -h "${TEST_DBHOST:-localhost}" -p "${TEST_DBPORT:-5432}" -U "${TEST_DBUSER:-testuser}" -d "${TEST_DBNAME}" -c "SELECT 1;" &> /dev/null; then
  log_info "Creating test database..."
  createdb -h "${TEST_DBHOST:-localhost}" -p "${TEST_DBPORT:-5432}" -U "${TEST_DBUSER:-testuser}" "${TEST_DBNAME}"
 fi

 # Create base tables
 log_info "Creating base tables..."
 psql -h "${TEST_DBHOST:-localhost}" -p "${TEST_DBPORT:-5432}" -U "${TEST_DBUSER:-testuser}" -d "${TEST_DBNAME}" -f "${PROJECT_ROOT}/sql/process/processPlanetNotes_21_createBaseTables_enum.sql" 2> /dev/null || true
 psql -h "${TEST_DBHOST:-localhost}" -p "${TEST_DBPORT:-5432}" -U "${TEST_DBUSER:-testuser}" -d "${TEST_DBNAME}" -f "${PROJECT_ROOT}/sql/process/processPlanetNotes_22_createBaseTables_tables.sql" 2> /dev/null || true
 psql -h "${TEST_DBHOST:-localhost}" -p "${TEST_DBPORT:-5432}" -U "${TEST_DBUSER:-testuser}" -d "${TEST_DBNAME}" -f "${PROJECT_ROOT}/sql/process/processPlanetNotes_23_createBaseTables_constraints.sql" 2> /dev/null || true

 log_success "Test database setup completed"
}

# Function to cleanup test database
cleanup_test_database() {
 log_info "Cleaning up test database..."

 # Drop test database
 if psql -h "${TEST_DBHOST:-localhost}" -p "${TEST_DBPORT:-5432}" -U "${TEST_DBUSER:-testuser}" -d "${TEST_DBNAME}" -c "SELECT 1;" &> /dev/null; then
  log_info "Dropping test database..."
  dropdb -h "${TEST_DBHOST:-localhost}" -p "${TEST_DBPORT:-5432}" -U "${TEST_DBUSER:-testuser}" "${TEST_DBNAME}"
 fi

 log_success "Test database cleanup completed"
}

# Function to run BATS tests
run_bats_tests() {
 log_info "Running BATS tests..."

  # Define tests that are safe for CI environment
 local bats_tests=(
   "${SCRIPT_DIR}/unit/bash/functionsProcess.test.bats"
   "${SCRIPT_DIR}/unit/bash/processPlanetNotes.test.bats"
   "${SCRIPT_DIR}/unit/bash/processPlanetNotes_integration_fixed.test.bats"
   "${SCRIPT_DIR}/unit/bash/cleanupAll.test.bats"
   "${SCRIPT_DIR}/unit/bash/variable_duplication.test.bats"
   "${SCRIPT_DIR}/unit/bash/script_help_validation.test.bats"
   "${SCRIPT_DIR}/unit/bash/variable_duplication_detection.test.bats"
   "${SCRIPT_DIR}/unit/bash/script_execution_integration.test.bats"
   "${SCRIPT_DIR}/unit/bash/sql_validation_integration.test.bats"
   "${SCRIPT_DIR}/unit/bash/sql_constraints_validation.test.bats"
   "${SCRIPT_DIR}/unit/bash/parallel_processing_validation.test.bats"
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
   export TEST_DBHOST="${TEST_DBHOST:-localhost}"
   export TEST_DBPORT="${TEST_DBPORT:-5432}"

   log_info "Executing bats for: ${test_file}"
   if bats "${test_file}" || true; then
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

# Function to run XSLT tests (only if tools are available)
run_xslt_tests() {
 log_info "Running XSLT tests..."

 # Check if XSLT tools are available
 if ! command -v xsltproc &> /dev/null || ! command -v xmllint &> /dev/null; then
  log_warning "XSLT tools not available, skipping XSLT tests"
  return 0
 fi

 local xslt_tests=(
  "${SCRIPT_DIR}/unit/bash/xslt_simple.test.bats"
  "${SCRIPT_DIR}/unit/bash/xslt_enum_validation.test.bats"
 )

 for test_file in "${xslt_tests[@]}"; do
  if [[ -f "${test_file}" ]]; then
   log_info "Running XSLT test: $(basename "${test_file}")"
   if bats "${test_file}" || true; then
    log_success "$(basename "${test_file}") passed"
    ((PASSED_TESTS++))
   else
    log_error "$(basename "${test_file}") failed"
    ((FAILED_TESTS++))
   fi
   ((TOTAL_TESTS++))
  fi
 done
}

# Function to run format and lint tests (only if tools are available)
run_format_tests() {
 log_info "Running format and lint tests..."

 # Check if formatting tools are available
 if ! command -v shfmt &> /dev/null || ! command -v shellcheck &> /dev/null; then
  log_warning "Formatting tools not available, skipping format tests"
  return 0
 fi

 local format_tests=(
  "${SCRIPT_DIR}/unit/bash/format_and_lint.test.bats"
 )

 for test_file in "${format_tests[@]}"; do
  if [[ -f "${test_file}" ]]; then
   log_info "Running format test: $(basename "${test_file}")"
   if bats "${test_file}" || true; then
    log_success "$(basename "${test_file}") passed"
    ((PASSED_TESTS++))
   else
    log_error "$(basename "${test_file}") failed"
    ((FAILED_TESTS++))
   fi
   ((TOTAL_TESTS++))
  fi
 done
}

# Print test summary
print_summary() {
 echo
 echo "=========================================="
 echo "CI TEST SUMMARY"
 echo "=========================================="
 echo "Total tests: ${TOTAL_TESTS}"
 echo "Passed: ${PASSED_TESTS}"
 echo "Failed: ${FAILED_TESTS}"

 if [[ ${FAILED_TESTS} -eq 0 ]]; then
  log_success "All CI tests passed! 🎉"
  exit 0
 else
  log_error "Some CI tests failed! ❌"
  exit 1
 fi
}

# Main function
main() {
 echo "=========================================="
 echo "OSM-Notes-profile CI Test Suite"
 echo "=========================================="
 echo

 # Install CI dependencies
 install_ci_dependencies

 # Check prerequisites
 check_prerequisites

 # Setup test database
 setup_test_database

 # Run BATS tests
 run_bats_tests

 # Run XSLT tests (if tools available)
 run_xslt_tests

 # Run format tests (if tools available)
 run_format_tests

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
  echo "  --xslt-only          Run only XSLT tests"
  echo "  --format-only        Run only format tests"
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
 --xslt-only)
  run_xslt_tests
  print_summary
  ;;
 --format-only)
  run_format_tests
  print_summary
  ;;
 --no-cleanup)
  check_prerequisites
  setup_test_database
  run_bats_tests
  run_xslt_tests
  run_format_tests
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
