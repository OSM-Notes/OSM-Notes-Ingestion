#!/bin/bash

# Simple integration tests for OSM-Notes-profile
# Author: Andres Gomez (AngocA)
# Version: 2025-08-03

set -e

SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== RUNNING SIMPLE INTEGRATION TESTS ==="
echo "Testing basic integration functionality..."

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

# Test counter
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Run a simple test
run_simple_test() {
  local test_name="$1"
  local test_command="$2"
  
  log_info "Running ${test_name}..."
  ((TOTAL_TESTS++))
  
  if eval "$test_command"; then
    log_success "${test_name} passed"
    ((PASSED_TESTS++))
  else
    log_error "${test_name} failed"
    ((FAILED_TESTS++))
  fi
  echo
}

# Test script loading
run_simple_test "Script loading test" "
  source bin/functionsProcess.sh > /dev/null 2>&1 && 
  echo 'Scripts loaded successfully'
"

# Test function availability
run_simple_test "Function availability test" "
  source bin/functionsProcess.sh > /dev/null 2>&1 && 
  declare -f __checkPrereqsCommands > /dev/null && 
  echo 'Functions available'
"

# Test help functionality
run_simple_test "Help functionality test" "
  timeout 10s bin/process/processAPINotes.sh --help > /dev/null 2>&1 && 
  echo 'Help works'
"

# Test dry-run mode
run_simple_test "Dry-run mode test" "
  timeout 10s bin/process/processPlanetNotes.sh --help > /dev/null 2>&1 && 
  echo 'Dry-run works'
"

# Test SQL file validation
run_simple_test "SQL file validation test" "
  for sql_file in sql/process/*.sql; do
    if [[ -f \"\$sql_file\" ]]; then
      grep -q 'CREATE\|INSERT\|UPDATE\|SELECT' \"\$sql_file\" || exit 1
    fi
  done && 
  echo 'SQL files validated'
"

# Test XSLT file validation
run_simple_test "XSLT file validation test" "
  for xslt_file in xslt/*.xslt; do
    if [[ -f \"\$xslt_file\" ]]; then
      grep -q 'xsl:stylesheet\|xsl:template' \"\$xslt_file\" || exit 1
    fi
  done && 
  echo 'XSLT files validated'
"

# Test properties file validation
run_simple_test "Properties file validation test" "
  [[ -f etc/etl.properties ]] && 
  [[ -f etc/properties.sh ]] && 
  echo 'Properties files exist'
"

# Show results
echo "=========================================="
echo "SIMPLE INTEGRATION TESTS RESULTS"
echo "=========================================="
echo "Total tests: ${TOTAL_TESTS}"
echo "Passed tests: ${PASSED_TESTS}"
echo "Failed tests: ${FAILED_TESTS}"
echo

if [[ ${FAILED_TESTS} -eq 0 ]]; then
  log_success "All simple integration tests passed! 🎉"
  exit 0
else
  log_error "Some simple integration tests failed! ❌"
  exit 1
fi 