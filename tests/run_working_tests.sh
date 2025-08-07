#!/bin/bash

# Working Tests Runner for OSM-Notes-profile
# This script runs all tests that are known to work correctly
# Author: Andres Gomez (AngocA)
# Version: 2025-01-27

echo "=== RUNNING WORKING TESTS ==="
echo "Testing functionality that is known to work..."

# Get the base directory
SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TESTS_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Test counter
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Function to run a test suite
run_test_suite() {
  local suite_name="$1"
  local test_command="$2"
  
  log_info "Running $suite_name..."
  ((TOTAL_TESTS++))
  
  if eval "$test_command"; then
    log_success "$suite_name passed"
    ((PASSED_TESTS++))
  else
    log_error "$suite_name failed"
    ((FAILED_TESTS++))
  fi
  echo
}

# Change to tests directory for proper relative paths
cd "${TESTS_DIRECTORY}"

# Unit Tests - Core Functions
run_test_suite "Core Functions Tests" "bats unit/bash/functionsProcess.test.bats"

# Unit Tests - Error Handling
run_test_suite "Error Handling Tests" "bats unit/bash/error_handling.test.bats"

# Unit Tests - Input Validation
run_test_suite "Input Validation Tests" "bats unit/bash/input_validation.test.bats"

# Unit Tests - Date Validation
run_test_suite "Date Validation Tests" "bats unit/bash/date_validation.test.bats"

# Unit Tests - Date Validation UTC
run_test_suite "Date Validation UTC Tests" "bats unit/bash/date_validation_utc.test.bats"

# Unit Tests - XML Validation Functions
run_test_suite "XML Validation Functions Tests" "bats unit/bash/xml_validation_functions.test.bats"

# Unit Tests - XML Validation Enhanced
run_test_suite "XML Validation Enhanced Tests" "bats unit/bash/xml_validation_enhanced.test.bats"

# Unit Tests - Extended Validation
run_test_suite "Extended Validation Tests" "bats unit/bash/extended_validation.test.bats"

# Unit Tests - Checksum Validation
run_test_suite "Checksum Validation Tests" "bats unit/bash/checksum_validation.test.bats"

# Unit Tests - Boundary Validation
run_test_suite "Boundary Validation Tests" "bats unit/bash/boundary_validation.test.bats"

# Unit Tests - XSLT Enum Validation
run_test_suite "XSLT Enum Validation Tests" "bats unit/bash/xslt_enum_validation.test.bats"

# Unit Tests - XSLT CSV Format
run_test_suite "XSLT CSV Format Tests" "bats unit/bash/xslt_csv_format.test.bats"

# Unit Tests - Parallel Failed File
run_test_suite "Parallel Failed File Tests" "bats unit/bash/parallel_failed_file.test.bats"

# Unit Tests - XML Validation Simple
run_test_suite "XML Validation Simple Tests" "bats unit/bash/xml_validation_simple.test.bats"

# Integration Tests - Boundary Processing Error
run_test_suite "Boundary Processing Error Integration Tests" "bats integration/boundary_processing_error_integration.test.bats"

# Integration Tests - ETL Enhanced
run_test_suite "ETL Enhanced Integration Tests" "bats integration/ETL_enhanced_integration.test.bats"

# Integration Tests - Process API Notes Parallel Error
run_test_suite "Process API Notes Parallel Error Integration Tests" "bats integration/processAPINotes_parallel_error_integration.test.bats"

# Show results
echo "=========================================="
echo "WORKING TESTS RESULTS"
echo "=========================================="
echo "Total test suites: ${TOTAL_TESTS}"
echo "Passed test suites: ${PASSED_TESTS}"
echo "Failed test suites: ${FAILED_TESTS}"
echo

if [[ ${FAILED_TESTS} -eq 0 ]]; then
  log_success "All working tests passed! 🎉"
  echo
  echo "Summary of working functionality:"
  echo "✓ Core functions and environment setup"
  echo "✓ Error handling and validation"
  echo "✓ Input validation (files, SQL, XML, CSV)"
  echo "✓ Date validation (ISO8601, UTC, API formats)"
  echo "✓ XML validation (structure, dates, error handling)"
  echo "✓ Extended validation (JSON, database, coordinates)"
  echo "✓ Checksum validation (MD5, SHA256, files, directories)"
  echo "✓ Boundary validation (topology, large boundaries)"
  echo "✓ XSLT processing (enum validation, CSV format)"
  echo "✓ Parallel processing (failed file generation)"
  echo "✓ ETL functionality (dry-run, validation, configuration)"
  echo "✓ Integration workflows (boundary processing, API notes)"
  echo
  log_info "Note: Some tests were skipped due to Docker dependencies or environment issues."
  log_info "These tests require specific database setup or Docker containers."
  exit 0
else
  log_error "Some working tests failed! ❌"
  exit 1
fi 