#!/bin/bash

# Master test runner for OSM-Notes-profile
# Author: Andres Gomez (AngocA)
# Version: 2025-08-03

set -e

SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0

# Logging functions
log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Show help
show_help() {
  cat << EOF
Master Test Runner for OSM-Notes-profile

Usage: $0 [OPTIONS]

Options:
  -h, --help              Show this help message
  --core                  Run only core tests
  --validation            Run only validation tests
  --integration           Run only integration tests
  --error-handling        Run only error handling tests
  --quality               Run only quality tests
  --xml-xslt              Run only XML/XSLT tests
  --parallel              Run only parallel processing tests
  --all                   Run all test suites (default)

Test Suites:
  core                    Basic functionality tests
  validation              Input/output validation tests
  integration             Integration with external systems
  error-handling          Error handling and edge cases
  quality                 Code quality and conventions
  xml-xslt                XML processing and XSLT tests
  parallel                Parallel processing tests

Examples:
  $0 --core                    # Run only core tests
  $0 --validation              # Run only validation tests
  $0 --all                     # Run all test suites
  $0                           # Run all test suites (default)

EOF
}

# Run a test suite
run_test_suite() {
  local suite_name="$1"
  local script_name="$2"
  
  log_info "Running ${suite_name} tests..."
  
  if ./"${script_name}"; then
    log_success "${suite_name} tests passed"
    ((PASSED_SUITES++))
  else
    log_error "${suite_name} tests failed"
    ((FAILED_SUITES++))
  fi
  
  ((TOTAL_SUITES++))
  echo
}

# Run all test suites
run_all_suites() {
  log_info "Running all test suites..."
  
  # Core tests
  run_test_suite "Core" "run_core_tests.sh"
  
  # Validation tests
  run_test_suite "Validation" "run_validation_tests.sh"
  
  # Integration tests
  run_test_suite "Integration" "run_integration_tests.sh"
  
  # Error handling tests
  run_test_suite "Error Handling" "run_error_handling_tests.sh"
  
  # Quality tests
  run_test_suite "Quality" "run_quality_tests.sh"
  
  # XML/XSLT tests
  run_test_suite "XML/XSLT" "run_xml_xslt_tests.sh"
  
  # Parallel processing tests
  run_test_suite "Parallel Processing" "run_parallel_tests.sh"
}

# Show results
show_results() {
  echo
  echo "=========================================="
  echo "MASTER TEST RUNNER RESULTS"
  echo "=========================================="
  echo "Total test suites: ${TOTAL_SUITES}"
  echo "Passed suites: ${PASSED_SUITES}"
  echo "Failed suites: ${FAILED_SUITES}"
  echo
  
  if [[ ${FAILED_SUITES} -eq 0 ]]; then
    log_success "All test suites passed! 🎉"
    exit 0
  else
    log_error "Some test suites failed! ❌"
    log_warning "Check the individual test suite outputs for details."
    exit 1
  fi
}

# Main function
main() {
  local run_core=false
  local run_validation=false
  local run_integration=false
  local run_error_handling=false
  local run_quality=false
  local run_xml_xslt=false
  local run_parallel=false
  local run_all=true
  
  # Parse command line arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help)
        show_help
        exit 0
        ;;
      --core)
        run_core=true
        run_all=false
        shift
        ;;
      --validation)
        run_validation=true
        run_all=false
        shift
        ;;
      --integration)
        run_integration=true
        run_all=false
        shift
        ;;
      --error-handling)
        run_error_handling=true
        run_all=false
        shift
        ;;
      --quality)
        run_quality=true
        run_all=false
        shift
        ;;
      --xml-xslt)
        run_xml_xslt=true
        run_all=false
        shift
        ;;
      --parallel)
        run_parallel=true
        run_all=false
        shift
        ;;
      --all)
        run_all=true
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
    log_error "bats is not installed. Please install bats to run tests."
    exit 1
  fi
  
  log_info "Starting master test runner..."
  log_info "Project root: ${SCRIPT_BASE_DIRECTORY}"
  echo
  
  if [[ "${run_all}" == true ]]; then
    run_all_suites
  else
    # Run specific test suites
    if [[ "${run_core}" == true ]]; then
      run_test_suite "Core" "run_core_tests.sh"
    fi
    
    if [[ "${run_validation}" == true ]]; then
      run_test_suite "Validation" "run_validation_tests.sh"
    fi
    
    if [[ "${run_integration}" == true ]]; then
      run_test_suite "Integration" "run_integration_tests.sh"
    fi
    
    if [[ "${run_error_handling}" == true ]]; then
      run_test_suite "Error Handling" "run_error_handling_tests.sh"
    fi
    
    if [[ "${run_quality}" == true ]]; then
      run_test_suite "Quality" "run_quality_tests.sh"
    fi
    
    if [[ "${run_xml_xslt}" == true ]]; then
      run_test_suite "XML/XSLT" "run_xml_xslt_tests.sh"
    fi
    
    if [[ "${run_parallel}" == true ]]; then
      run_test_suite "Parallel Processing" "run_parallel_tests.sh"
    fi
  fi
  
  show_results
}

# Run main function
main "$@" 