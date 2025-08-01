#!/bin/bash

# Integration Tests Runner for OSM-Notes-profile
# This script runs integration tests that actually execute the scripts
# to detect real problems like logging errors, database issues, etc.
#
# Author: Andres Gomez (AngocA)
# Version: 2025-08-01

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Script directory
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Test results
declare -i TOTAL_TESTS=0
declare -i PASSED_TESTS=0
declare -i FAILED_TESTS=0
declare -a FAILED_TEST_FILES=()

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

# Show help
show_help() {
  cat << EOF
Integration Tests Runner for OSM-Notes-profile

Usage: $0 [OPTIONS]

Options:
  -h, --help              Show this help message
  -v, --verbose           Verbose output
  --all                   Run all integration tests
  --process-api           Run only processAPINotes integration tests
  --process-planet        Run only processPlanetNotes integration tests
  --cleanup               Run only cleanupAll integration tests
  --wms                   Run only WMS integration tests
  --etl                   Run only ETL integration tests

Examples:
  $0 --all                    # Run all integration tests
  $0 --process-api            # Run only API processing tests
  $0 --process-planet         # Run only Planet processing tests
  $0 --cleanup                # Run only cleanup tests

Integration tests execute the actual scripts to detect:
- Logging errors (orden no encontrada)
- Database connection issues
- SQL script errors
- Function availability problems
- Error handling issues
- Real execution problems

EOF
}

# Run a single test file
run_test_file() {
  local test_file="$1"
  local test_name="$(basename "${test_file}" .test.bats)"
  
  log_info "Running integration test: ${test_name}"
  
  if bats "${test_file}" 2>&1; then
    log_success "✓ ${test_name} passed"
    ((PASSED_TESTS++))
  else
    log_error "✗ ${test_name} failed"
    ((FAILED_TESTS++))
    FAILED_TEST_FILES+=("${test_file}")
  fi
  
  ((TOTAL_TESTS++))
  echo
}

# Run all integration tests
run_all_integration_tests() {
  log_info "Running all integration tests..."
  
  # Find all integration test files
  local integration_tests
  mapfile -t integration_tests < <(find "${SCRIPT_DIR}/unit/bash" -name "*_integration.test.bats" -type f)
  
  if [[ ${#integration_tests[@]} -eq 0 ]]; then
    log_warning "No integration tests found"
    return 0
  fi
  
  for test_file in "${integration_tests[@]}"; do
    run_test_file "${test_file}"
  done
}

# Run specific integration tests
run_specific_tests() {
  local test_pattern="$1"
  local test_files
  
  mapfile -t test_files < <(find "${SCRIPT_DIR}/unit/bash" -name "*${test_pattern}*_integration.test.bats" -type f)
  
  if [[ ${#test_files[@]} -eq 0 ]]; then
    log_warning "No integration tests found for pattern: ${test_pattern}"
    return 0
  fi
  
  for test_file in "${test_files[@]}"; do
    run_test_file "${test_file}"
  done
}

# Show test results
show_results() {
  echo
  echo "=========================================="
  echo "Integration Tests Results"
  echo "=========================================="
  echo "Total tests: ${TOTAL_TESTS}"
  echo "Passed: ${PASSED_TESTS}"
  echo "Failed: ${FAILED_TESTS}"
  echo
  
  if [[ ${FAILED_TESTS} -gt 0 ]]; then
    log_error "Failed test files:"
    for test_file in "${FAILED_TEST_FILES[@]}"; do
      echo "  - $(basename "${test_file}")"
    done
    echo
    log_error "Integration tests detected real problems!"
    log_error "These issues need to be fixed before deployment."
    return 1
  else
    log_success "All integration tests passed!"
    log_success "No real problems detected in the scripts."
    return 0
  fi
}

# Main function
main() {
  local run_all=false
  local test_pattern=""
  
  # Parse command line arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help)
        show_help
        exit 0
        ;;
      -v|--verbose)
        set -x
        shift
        ;;
      --all)
        run_all=true
        shift
        ;;
      --process-api)
        test_pattern="processAPINotes"
        shift
        ;;
      --process-planet)
        test_pattern="processPlanetNotes"
        shift
        ;;
      --cleanup)
        test_pattern="cleanupAll"
        shift
        ;;
      --wms)
        test_pattern="wms"
        shift
        ;;
      --etl)
        test_pattern="etl"
        shift
        ;;
      *)
        log_error "Unknown option: $1"
        show_help
        exit 1
        ;;
    esac
  done
  
  # Check if bats is available
  if ! command -v bats > /dev/null 2>&1; then
    log_error "bats is not installed. Please install bats to run integration tests."
    exit 1
  fi
  
  # Check if PostgreSQL is available
  if ! command -v psql > /dev/null 2>&1; then
    log_error "PostgreSQL (psql) is not available. Integration tests require PostgreSQL."
    exit 1
  fi
  
  log_info "Starting integration tests..."
  log_info "Project root: ${PROJECT_ROOT}"
  log_info "Script directory: ${SCRIPT_DIR}"
  echo
  
  if [[ "${run_all}" == true ]]; then
    run_all_integration_tests
  elif [[ -n "${test_pattern}" ]]; then
    run_specific_tests "${test_pattern}"
  else
    log_info "No test pattern specified, running all integration tests..."
    run_all_integration_tests
  fi
  
  show_results
}

# Run main function
main "$@" 