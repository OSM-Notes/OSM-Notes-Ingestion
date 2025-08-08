#!/bin/bash

# DWH Enhanced Tests Runner
# Author: Andres Gomez (AngocA)
# Version: 2025-08-08

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

# Show help
show_help() {
  cat << EOF
DWH Enhanced Tests Runner

Usage: $0 [OPTIONS]

Options:
  -h, --help              Show this help message
  --db-name DBNAME        Database name (default: notes)
  --db-user DBUSER        Database user (default: notes)
  --skip-sql              Skip SQL unit tests
  --skip-integration      Skip integration tests
  --dry-run               Show what would be executed without running

Examples:
  $0                                    # Run all DWH tests
  $0 --db-name testdb                   # Run tests against testdb
  $0 --skip-sql                         # Skip SQL tests, run only integration
  $0 --dry-run                          # Show what would be executed

EOF
}

# Check prerequisites
check_prerequisites() {
  log_info "Checking prerequisites..."
  
  # Check if BATS is installed
  if ! command -v bats &> /dev/null; then
    log_error "BATS is not installed. Please install it first:"
    log_error "  sudo apt-get install bats"
    exit 1
  fi
  
  # Check if psql is available (for SQL tests)
  if ! command -v psql &> /dev/null; then
    log_warning "psql not found, SQL tests will be skipped"
    SKIP_SQL=true
  else
    SKIP_SQL=false
  fi
  
  log_success "Prerequisites check completed"
}

# Run SQL unit tests
run_sql_tests() {
  if [[ "${SKIP_SQL:-false}" == "true" ]]; then
    log_warning "Skipping SQL tests (psql not available)"
    return 0
  fi
  
  log_info "Running DWH SQL unit tests..."
  
  local dbname="${DBNAME:-notes}"
  local dbuser="${DBUSER:-notes}"
  
  # Test 1: Enhanced dimensions
  log_info "Testing enhanced dimensions..."
  if psql -d "${dbname}" -U "${dbuser}" -f tests/unit/sql/dwh_dimensions_enhanced.test.sql; then
    log_success "Enhanced dimensions tests passed"
    ((PASSED_TESTS++))
  else
    log_error "Enhanced dimensions tests failed"
    ((FAILED_TESTS++))
  fi
  ((TOTAL_TESTS++))
  
  # Test 2: Enhanced functions
  log_info "Testing enhanced functions..."
  if psql -d "${dbname}" -U "${dbuser}" -f tests/unit/sql/dwh_functions_enhanced.test.sql; then
    log_success "Enhanced functions tests passed"
    ((PASSED_TESTS++))
  else
    log_error "Enhanced functions tests failed"
    ((FAILED_TESTS++))
  fi
  ((TOTAL_TESTS++))
}

# Run integration tests
run_integration_tests() {
  if [[ "${SKIP_INTEGRATION:-false}" == "true" ]]; then
    log_warning "Skipping integration tests"
    return 0
  fi
  
  log_info "Running DWH integration tests..."
  
  # Test 1: ETL enhanced integration
  log_info "Testing ETL enhanced integration..."
  if bats tests/integration/ETL_enhanced_integration.test.bats; then
    log_success "ETL enhanced integration tests passed"
    ((PASSED_TESTS++))
  else
    log_error "ETL enhanced integration tests failed"
    ((FAILED_TESTS++))
  fi
  ((TOTAL_TESTS++))
  
  # Test 2: Datamart enhanced integration
  log_info "Testing datamart enhanced integration..."
  if bats tests/integration/datamart_enhanced_integration.test.bats; then
    log_success "Datamart enhanced integration tests passed"
    ((PASSED_TESTS++))
  else
    log_error "Datamart enhanced integration tests failed"
    ((FAILED_TESTS++))
  fi
  ((TOTAL_TESTS++))
}

# Parse command line arguments
parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help)
        show_help
        exit 0
        ;;
      --db-name)
        DBNAME="$2"
        shift 2
        ;;
      --db-user)
        DBUSER="$2"
        shift 2
        ;;
      --skip-sql)
        SKIP_SQL=true
        shift
        ;;
      --skip-integration)
        SKIP_INTEGRATION=true
        shift
        ;;
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      *)
        log_error "Unknown option: $1"
        show_help
        exit 1
        ;;
    esac
  done
}

# Main function
main() {
  log_info "Starting DWH enhanced tests..."
  
  # Parse arguments
  parse_args "$@"
  
  # Check prerequisites
  check_prerequisites
  
  # Show what would be executed in dry-run mode
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_info "DRY RUN - Would execute:"
    if [[ "${SKIP_SQL:-false}" != "true" ]]; then
      log_info "  - SQL unit tests: dwh_dimensions_enhanced.test.sql"
      log_info "  - SQL unit tests: dwh_functions_enhanced.test.sql"
    fi
    if [[ "${SKIP_INTEGRATION:-false}" != "true" ]]; then
      log_info "  - Integration tests: ETL_enhanced_integration.test.bats"
      log_info "  - Integration tests: datamart_enhanced_integration.test.bats"
    fi
    exit 0
  fi
  
  # Run tests
  run_sql_tests
  run_integration_tests
  
  # Summary
  log_info "Test summary:"
  log_info "  Total tests: ${TOTAL_TESTS}"
  log_info "  Passed: ${PASSED_TESTS}"
  log_info "  Failed: ${FAILED_TESTS}"
  
  if [[ ${FAILED_TESTS} -eq 0 ]]; then
    log_success "All DWH enhanced tests passed!"
    exit 0
  else
    log_error "Some DWH enhanced tests failed!"
    exit 1
  fi
}

# Run main function
main "$@"
