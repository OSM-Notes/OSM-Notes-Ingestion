#!/bin/bash

# Simple Error Handling Tests for OSM-Notes-profile
# Author: Andres Gomez (AngocA)
# Version: 2025-08-03

set -e

SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== RUNNING SIMPLE ERROR HANDLING TESTS ==="
echo "Testing error handling functionality..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counter
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

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Run a test suite
run_test_suite() {
  local suite_name="$1"
  local test_file="$2"
  
  log_info "Running ${suite_name}..."
  ((TOTAL_TESTS++))
  
  if timeout 60s bats "tests/unit/bash/${test_file}"; then
    log_success "${suite_name} passed"
    ((PASSED_TESTS++))
  else
    log_error "${suite_name} failed"
    ((FAILED_TESTS++))
  fi
  echo
}

# Run basic error handling tests
run_test_suite "Basic Error Handling" "error_handling.test.bats"

# Run simple error handling tests
run_test_suite "Simple Error Handling" "error_handling_simple.test.bats"

# Run enhanced error handling tests
run_test_suite "Enhanced Error Handling" "error_handling_enhanced.test.bats"

# Run process error handling tests
run_test_suite "Process Error Handling - Improved" "processAPINotes_error_handling_improved.test.bats"

# Run parallel error handling tests
run_test_suite "Process Error Handling - Parallel" "processAPINotes_parallel_error.test.bats"

# Run edge cases tests
run_test_suite "Edge Cases" "edge_cases_integration.test.bats"

# Run simple performance tests
run_test_suite "Simple Performance Tests" "performance_edge_cases_simple.test.bats"

# Show results
echo "=========================================="
echo "SIMPLE ERROR HANDLING TESTS RESULTS"
echo "=========================================="
echo "Total test suites: ${TOTAL_TESTS}"
echo "Passed suites: ${PASSED_TESTS}"
echo "Failed suites: ${FAILED_TESTS}"
echo

if [[ ${FAILED_TESTS} -eq 0 ]]; then
  log_success "All simple error handling tests passed! 🎉"
  exit 0
else
  log_error "Some simple error handling tests failed! ❌"
  log_warning "Check the individual test suite outputs for details."
  exit 1
fi 