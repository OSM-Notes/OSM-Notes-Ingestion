#!/bin/bash

# Basic tests for OSM-Notes-profile
# Author: Andres Gomez (AngocA)
# Version: 2025-01-27

echo "=== RUNNING BASIC TESTS ==="
echo "Testing basic functionality..."

# Get the base directory
SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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

# Test 1: Script loading
log_info "Running Script loading test..."
((TOTAL_TESTS++))
if source "${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh" 2>/dev/null; then
  log_success "Script loading test passed"
  ((PASSED_TESTS++))
else
  log_error "Script loading test failed"
  ((FAILED_TESTS++))
fi

# Test 2: Function availability
log_info "Running Function availability test..."
((TOTAL_TESTS++))
if declare -f __checkPrereqsCommands > /dev/null 2>&1; then
  log_success "Function availability test passed"
  ((PASSED_TESTS++))
else
  log_error "Function availability test failed"
  ((FAILED_TESTS++))
fi

# Test 3: Help functionality
log_info "Running Help functionality test..."
((TOTAL_TESTS++))
if timeout 10s "${SCRIPT_BASE_DIRECTORY}/bin/process/processAPINotes.sh" --help > /dev/null 2>&1; then
  # Help should return exit code 1, so if we get here, it failed
  log_error "Help functionality test failed (expected exit code 1)"
  ((FAILED_TESTS++))
else
  if [[ $? -eq 1 ]]; then
    log_success "Help functionality test passed (exit code 1 is expected)"
    ((PASSED_TESTS++))
  else
    log_error "Help functionality test failed (unexpected exit code)"
    ((FAILED_TESTS++))
  fi
fi

# Test 4: Dry-run mode
log_info "Running Dry-run mode test..."
((TOTAL_TESTS++))
if timeout 10s "${SCRIPT_BASE_DIRECTORY}/bin/process/processPlanetNotes.sh" --help > /dev/null 2>&1; then
  # Help should return exit code 1, so if we get here, it failed
  log_error "Dry-run mode test failed (expected exit code 1)"
  ((FAILED_TESTS++))
else
  if [[ $? -eq 1 ]]; then
    log_success "Dry-run mode test passed (exit code 1 is expected)"
    ((PASSED_TESTS++))
  else
    log_error "Dry-run mode test failed (unexpected exit code)"
    ((FAILED_TESTS++))
  fi
fi

# Test 5: SQL file validation
log_info "Running SQL file validation test..."
((TOTAL_TESTS++))
SQL_VALID=true
for sql_file in "${SCRIPT_BASE_DIRECTORY}/sql/process/"*.sql; do
  if [[ -f "$sql_file" ]]; then
    if ! grep -q 'CREATE\|INSERT\|UPDATE\|SELECT\|DROP\|VACUUM\|ANALYZE' "$sql_file"; then
      SQL_VALID=false
      break
    fi
  fi
done

if [[ "$SQL_VALID" == "true" ]]; then
  log_success "SQL file validation test passed"
  ((PASSED_TESTS++))
else
  log_error "SQL file validation test failed"
  ((FAILED_TESTS++))
fi

# Test 6: XSLT file validation
log_info "Running XSLT file validation test..."
((TOTAL_TESTS++))
XSLT_VALID=true
for xslt_file in "${SCRIPT_BASE_DIRECTORY}/xslt/"*.xslt; do
  if [[ -f "$xslt_file" ]]; then
    if ! grep -q 'xsl:stylesheet\|xsl:template' "$xslt_file"; then
      XSLT_VALID=false
      break
    fi
  fi
done

if [[ "$XSLT_VALID" == "true" ]]; then
  log_success "XSLT file validation test passed"
  ((PASSED_TESTS++))
else
  log_error "XSLT file validation test failed"
  ((FAILED_TESTS++))
fi

# Test 7: Properties file validation
log_info "Running Properties file validation test..."
((TOTAL_TESTS++))
if [[ -f "${SCRIPT_BASE_DIRECTORY}/etc/etl.properties" ]] && [[ -f "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh" ]]; then
  log_success "Properties file validation test passed"
  ((PASSED_TESTS++))
else
  log_error "Properties file validation test failed"
  ((FAILED_TESTS++))
fi

# Show results
echo "=========================================="
echo "BASIC TESTS RESULTS"
echo "=========================================="
echo "Total tests: ${TOTAL_TESTS}"
echo "Passed tests: ${PASSED_TESTS}"
echo "Failed tests: ${FAILED_TESTS}"
echo

if [[ ${FAILED_TESTS} -eq 0 ]]; then
  log_success "All basic tests passed! 🎉"
  exit 0
else
  log_error "Some basic tests failed! ❌"
  exit 1
fi 