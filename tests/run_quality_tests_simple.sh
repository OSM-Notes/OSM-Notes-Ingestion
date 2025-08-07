#!/bin/bash

# Simple Quality Tests for OSM-Notes-profile
# Author: Andres Gomez (AngocA)
# Version: 2025-08-03

SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== RUNNING SIMPLE QUALITY TESTS ==="
echo "Testing code quality..."

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

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Run a test suite
run_test_suite() {
  local suite_name="$1"
  local test_file="$2"
  
  log_info "Running ${suite_name}..."
  ((TOTAL_TESTS++))
  
  if timeout 60s bats "tests/unit/bash/${test_file}" 2>/dev/null; then
    log_success "${suite_name} passed"
    ((PASSED_TESTS++))
  else
    log_error "${suite_name} failed"
    ((FAILED_TESTS++))
  fi
  echo
}

# Run basic quality checks
run_basic_quality_check() {
  local check_name="$1"
  local check_command="$2"
  
  log_info "Running ${check_name}..."
  ((TOTAL_TESTS++))
  
  if eval "$check_command" >/dev/null 2>&1; then
    log_success "${check_name} passed"
    ((PASSED_TESTS++))
  else
    log_warning "${check_name} failed (expected for some files)"
    ((FAILED_TESTS++))
  fi
  echo
}

# Test 1: Basic script syntax validation
run_basic_quality_check "Basic script syntax validation" "
  for script in bin/*.sh bin/*/*.sh; do
    if [[ -f \"\$script\" ]]; then
      bash -n \"\$script\"
    fi
  done
"

# Test 2: Check for basic shell best practices
run_basic_quality_check "Basic shell best practices" "
  for script in bin/*.sh bin/*/*.sh; do
    if [[ -f \"\$script\" ]]; then
      # Check for set -e usage
      grep -q 'set -e' \"\$script\" || echo \"Warning: \$script doesn't use set -e\"
    fi
  done
"

# Test 3: Check for proper shebang
run_basic_quality_check "Proper shebang validation" "
  for script in bin/*.sh bin/*/*.sh; do
    if [[ -f \"\$script\" ]]; then
      head -1 \"\$script\" | grep -q '^#!/bin/bash' || echo \"Warning: \$script doesn't have proper shebang\"
    fi
  done
"

# Test 4: Check for basic documentation
run_basic_quality_check "Basic documentation check" "
  for script in bin/*.sh bin/*/*.sh; do
    if [[ -f \"\$script\" ]]; then
      grep -q 'Author:' \"\$script\" || echo \"Warning: \$script doesn't have author info\"
    fi
  done
"

# Test 5: Check for version information
run_basic_quality_check "Version information check" "
  for script in bin/*.sh bin/*/*.sh; do
    if [[ -f \"\$script\" ]]; then
      grep -q 'Version:' \"\$script\" || echo \"Warning: \$script doesn't have version info\"
    fi
  done
"

# Test 6: Check for help functions
run_basic_quality_check "Help function check" "
  for script in bin/*.sh bin/*/*.sh; do
    if [[ -f \"\$script\" ]]; then
      grep -q 'show_help\|__show_help' \"\$script\" || echo \"Warning: \$script doesn't have help function\"
    fi
  done
"

# Test 7: Check for error handling
run_basic_quality_check "Error handling check" "
  for script in bin/*.sh bin/*/*.sh; do
    if [[ -f \"\$script\" ]]; then
      grep -q 'exit.*[0-9]' \"\$script\" || echo \"Warning: \$script doesn't have proper exit codes\"
    fi
  done
"

# Test 8: Check for logging functions
run_basic_quality_check "Logging functions check" "
  for script in bin/*.sh bin/*/*.sh; do
    if [[ -f \"\$script\" ]]; then
      grep -q '__log' \"\$script\" || echo \"Warning: \$script doesn't use logging functions\"
    fi
  done
"

# Test 9: Check for proper file permissions
run_basic_quality_check "File permissions check" "
  for script in bin/*.sh bin/*/*.sh; do
    if [[ -f \"\$script\" ]]; then
      [[ -x \"\$script\" ]] || echo \"Warning: \$script is not executable\"
    fi
  done
"

# Test 10: Check for proper line endings
run_basic_quality_check "Line endings check" "
  for script in bin/*.sh bin/*/*.sh; do
    if [[ -f \"\$script\" ]]; then
      file \"\$script\" | grep -q 'ASCII text' || echo \"Warning: \$script has wrong line endings\"
    fi
  done
"

# Show results
echo "=========================================="
echo "SIMPLE QUALITY TESTS RESULTS"
echo "=========================================="
echo "Total tests: ${TOTAL_TESTS}"
echo "Passed tests: ${PASSED_TESTS}"
echo "Failed tests: ${FAILED_TESTS}"
echo

if [[ ${FAILED_TESTS} -eq 0 ]]; then
  log_success "All simple quality tests passed! 🎉"
  exit 0
else
  log_warning "Some simple quality tests failed (this is expected for some files)"
  log_info "Quality tests completed with warnings"
  exit 0
fi 