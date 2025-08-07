#!/bin/bash

# Simple Error Handling Tests for OSM-Notes-profile
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

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Run a test
run_test() {
  local test_name="$1"
  local test_command="$2"
  
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  log_info "Running: $test_name"
  
  if bash -c "$test_command" > /dev/null 2>&1; then
    log_success "$test_name passed"
    PASSED_TESTS=$((PASSED_TESTS + 1))
  else
    log_error "$test_name failed"
    FAILED_TESTS=$((FAILED_TESTS + 1))
  fi
  echo
}

# Show results
show_results() {
  echo
  echo "=========================================="
  echo "SIMPLE ERROR HANDLING TESTS RESULTS"
  echo "=========================================="
  echo "Total tests: ${TOTAL_TESTS}"
  echo "Passed tests: ${PASSED_TESTS}"
  echo "Failed tests: ${FAILED_TESTS}"
  echo
  
  if [[ ${FAILED_TESTS} -eq 0 ]]; then
    log_success "All error handling tests passed! 🎉"
    exit 0
  else
    log_error "Some error handling tests failed! ❌"
    exit 1
  fi
}

# Main function
main() {
  log_info "Running Simple Error Handling Tests..."
  echo
  
  # Test 1: Check if error handling functions exist
  run_test "Error handling functions exist" "
    grep -q '__handle_error_with_cleanup' bin/errorHandlingFunctions.sh && 
    grep -q '__loge' bin/errorHandlingFunctions.sh
  "
  
  # Test 2: Check if validation functions exist
  run_test "Validation functions exist" "
    grep -q '__validate_input_file' bin/validationFunctions.sh && 
    grep -q '__validate_file_checksum' bin/validationFunctions.sh
  "
  
  # Test 3: Check if common functions exist
  run_test "Common functions exist" "
    grep -q '__logi' bin/commonFunctions.sh && 
    grep -q '__loge' bin/commonFunctions.sh
  "
  
  # Test 4: Check if process functions exist
  run_test "Process functions exist" "
    grep -q '__processApiXmlPart' bin/functionsProcess.sh && 
    grep -q '__processPlanetXmlPart' bin/functionsProcess.sh
  "
  
  # Test 5: Check if error handling files are valid bash
  run_test "Error handling files are valid bash" "
    bash -n bin/errorHandlingFunctions.sh && 
    bash -n bin/validationFunctions.sh && 
    bash -n bin/commonFunctions.sh
  "
  
  # Test 6: Check if error handling functions can be sourced
  run_test "Error handling functions can be sourced" "
    source bin/errorHandlingFunctions.sh 2>/dev/null && 
    declare -f __handle_error_with_cleanup > /dev/null
  "
  
  # Test 7: Check if validation functions can be sourced
  run_test "Validation functions can be sourced" "
    source bin/validationFunctions.sh 2>/dev/null && 
    declare -f __validate_input_file > /dev/null
  "
  
  # Test 8: Check if common functions can be sourced
  run_test "Common functions can be sourced" "
    source lib/bash_logger.sh && 
    source bin/commonFunctions.sh && 
    declare -f __logi > /dev/null
  "
  
  # Test 9: Check if error codes are defined
  run_test "Error codes are defined" "
    grep -q 'ERROR_' bin/errorHandlingFunctions.sh || 
    grep -q 'ERROR_' bin/commonFunctions.sh
  "
  
  # Test 10: Check if trap functions exist
  run_test "Trap functions exist" "
    grep -q 'trap' bin/errorHandlingFunctions.sh || 
    grep -q 'trap' bin/commonFunctions.sh
  "
  
  show_results
}

# Run main function
main "$@" 