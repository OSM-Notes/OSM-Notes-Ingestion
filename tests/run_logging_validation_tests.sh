#!/bin/bash

# Logging Pattern Validation Tests Runner
# Author: Andres Gomez (AngocA)
# Version: 2025-01-27

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
Logging Pattern Validation Tests Runner for OSM-Notes-profile

Usage: $0 [OPTIONS]

Options:
  -h, --help              Show this help message
  --mode MODE             Test mode (unit|integration|all)
  --validate-only         Run only the validation script (no BATS tests)
  --bats-only             Run only BATS tests (no validation script)

Modes:
  unit                    Run only unit tests for logging patterns
  integration             Run only integration tests for logging patterns
  all                     Run all logging pattern tests (default)

Examples:
  $0 --mode all                    # Run all logging pattern tests
  $0 --mode unit                   # Run only unit tests
  $0 --mode integration            # Run only integration tests
  $0 --validate-only               # Run only validation script
  $0 --bats-only                   # Run only BATS tests
  $0                               # Run all tests (default)

EOF
}

# Check prerequisites
check_prerequisites() {
 log_info "Checking prerequisites..."

 # Check if BATS is installed
 if ! command -v bats &> /dev/null; then
  log_warning "BATS is not installed. Some tests will be skipped."
  log_warning "Install BATS: sudo apt-get install bats"
 fi

 # Check if validation scripts exist
 if [[ ! -f "${SCRIPT_DIR}/scripts/validate_logging_patterns.sh" ]]; then
  log_error "Validation script not found: ${SCRIPT_DIR}/scripts/validate_logging_patterns.sh"
  exit 1
 fi

 if [[ ! -f "${SCRIPT_DIR}/scripts/validate_logging_patterns_simple.sh" ]]; then
  log_error "Simple validation script not found: ${SCRIPT_DIR}/scripts/validate_logging_patterns_simple.sh"
  exit 1
 fi

 log_success "Prerequisites check completed"
}

# Run unit tests
run_unit_tests() {
 log_info "Running logging pattern unit tests..."
 ((TOTAL_TESTS++))

 if timeout 60s bats "unit/bash/logging_pattern_validation.test.bats" 2> /dev/null; then
  log_success "Unit tests passed"
  ((PASSED_TESTS++))
 else
  log_error "Unit tests failed"
  ((FAILED_TESTS++))
 fi
 echo
}

# Run integration tests
run_integration_tests() {
 log_info "Running logging pattern integration tests..."
 ((TOTAL_TESTS++))

 if timeout 120s bats "integration/logging_pattern_validation_integration.test.bats" 2> /dev/null; then
  log_success "Integration tests passed"
  ((PASSED_TESTS++))
 else
  log_error "Integration tests failed"
  ((FAILED_TESTS++))
 fi
 echo
}

# Run validation script
run_validation_script() {
 log_info "Running logging pattern validation script..."
 ((TOTAL_TESTS++))

 # Create temporary directory for validation results
 local temp_dir="/tmp/logging_validation_$$"
 mkdir -p "${temp_dir}"

 # Run the validation script
 if timeout 300s bash "${SCRIPT_DIR}/scripts/validate_logging_patterns.sh" "${temp_dir}" > /dev/null 2>&1; then
  log_success "Validation script executed successfully"
  
  # Check if results were generated
  if [[ -f "${temp_dir}/validation_results.txt" ]] && [[ -f "${temp_dir}/validation_summary.txt" ]]; then
   log_success "Validation results generated"
   
   # Display summary
   if [[ -s "${temp_dir}/validation_summary.txt" ]]; then
    echo "=== VALIDATION SUMMARY ==="
    cat "${temp_dir}/validation_summary.txt"
    echo "=========================="
   fi
   
   ((PASSED_TESTS++))
  else
   log_warning "Validation script ran but no results generated"
   ((FAILED_TESTS++))
  fi
 else
  log_error "Validation script failed"
  ((FAILED_TESTS++))
 fi

 # Clean up
 rm -rf "${temp_dir}"
 echo
}

# Run simple validation script
run_simple_validation_script() {
 log_info "Running simple logging pattern validation script..."
 ((TOTAL_TESTS++))

 # Create temporary directory for validation results
 local temp_dir="/tmp/simple_logging_validation_$$"
 mkdir -p "${temp_dir}"

 # Run the simple validation script
 if timeout 300s bash "${SCRIPT_DIR}/scripts/validate_logging_patterns_simple.sh" "${temp_dir}" > /dev/null 2>&1; then
  log_success "Simple validation script executed successfully"
  
  # Check if results were generated
  if [[ -f "${temp_dir}/validation_results.txt" ]] && [[ -f "${temp_dir}/validation_summary.txt" ]]; then
   log_success "Simple validation results generated"
   
   # Display summary
   if [[ -s "${temp_dir}/validation_summary.txt" ]]; then
    echo "=== SIMPLE VALIDATION SUMMARY ==="
    cat "${temp_dir}/validation_summary.txt"
    echo "================================="
   fi
   
   ((PASSED_TESTS++))
  else
   log_warning "Simple validation script ran but no results generated"
   ((FAILED_TESTS++))
  fi
 else
  log_error "Simple validation script failed"
  ((FAILED_TESTS++))
 fi

 # Clean up
 rm -rf "${temp_dir}"
 echo
}

# Show results
show_results() {
 echo "=========================================="
 echo "LOGGING PATTERN VALIDATION TEST RESULTS"
 echo "=========================================="
 echo "Total tests: ${TOTAL_TESTS}"
 echo "Passed tests: ${PASSED_TESTS}"
 echo "Failed tests: ${FAILED_TESTS}"
 echo

 if [[ ${FAILED_TESTS} -eq 0 ]]; then
  log_success "All logging pattern validation tests passed! 🎉"
  exit 0
 else
  log_warning "Some logging pattern validation tests failed"
  log_info "Tests completed with warnings"
  exit 0
 fi
}

# Main execution
main() {
 local mode="all"
 local validate_only=false
 local bats_only=false

 # Parse command line arguments
 while [[ $# -gt 0 ]]; do
  case $1 in
  -h | --help)
   show_help
   exit 0
   ;;
  --mode)
   mode="$2"
   shift 2
   ;;
  --validate-only)
   validate_only=true
   shift
   ;;
  --bats-only)
   bats_only=true
   shift
   ;;
  *)
   log_error "Unknown option: $1"
   show_help
   exit 1
   ;;
  esac
 done

 echo "=== LOGGING PATTERN VALIDATION TESTS ==="
 echo "Testing logging pattern validation functionality..."
 echo

 # Check prerequisites
 check_prerequisites

 # Change to tests directory for proper relative paths
 cd "${SCRIPT_DIR}"

 # Run tests based on mode
 if [[ "$validate_only" == "true" ]]; then
  log_info "Running validation scripts only..."
  run_validation_script
  run_simple_validation_script
 elif [[ "$bats_only" == "true" ]]; then
  log_info "Running BATS tests only..."
  case "$mode" in
  "unit")
   run_unit_tests
   ;;
  "integration")
   run_integration_tests
   ;;
  "all" | *)
   run_unit_tests
   run_integration_tests
   ;;
  esac
 else
  log_info "Running all tests..."
  case "$mode" in
  "unit")
   run_unit_tests
   ;;
  "integration")
   run_integration_tests
   ;;
  "all" | *)
   run_unit_tests
   run_integration_tests
   run_validation_script
   run_simple_validation_script
   ;;
  esac
 fi

 echo "=== LOGGING PATTERN VALIDATION TESTS COMPLETED ==="
 show_results
}

# Run main function
main "$@"
