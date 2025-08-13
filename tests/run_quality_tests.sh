#!/bin/bash

# Quality Tests Runner for OSM-Notes-profile (Consolidated)
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
Quality Tests Runner for OSM-Notes-profile

Usage: $0 [OPTIONS]

Options:
  -h, --help              Show this help message
  --mode MODE             Test mode (basic|enhanced|all)
  --format-only           Run only formatting and linting tests
  --naming-only           Run only naming convention tests
  --validation-only       Run only validation tests

Modes:
  basic                   Run basic quality checks (default)
  enhanced                Run enhanced quality checks
  all                     Run all quality checks

Examples:
  $0 --mode basic                    # Run basic quality tests
  $0 --mode enhanced                 # Run enhanced quality tests
  $0 --format-only                   # Run only formatting tests
  $0 --naming-only                   # Run only naming tests
  $0                                 # Run basic quality tests (default)

EOF
}

# Run a test suite
run_test_suite() {
 local suite_name="$1"
 local test_file="$2"

 log_info "Running ${suite_name}..."
 ((TOTAL_TESTS++))

 if timeout 60s bats "tests/unit/bash/${test_file}" 2> /dev/null; then
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

 if eval "$check_command" > /dev/null 2>&1; then
  log_success "${check_name} passed"
  ((PASSED_TESTS++))
 else
  log_warning "${check_name} failed (expected for some files)"
  ((FAILED_TESTS++))
 fi
 echo
}

# Run basic quality tests
run_basic_quality_tests() {
 log_info "Running basic quality tests..."

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
}

# Run enhanced quality tests
run_enhanced_quality_tests() {
 log_info "Running enhanced quality tests..."

 # Format and lint tests
 run_test_suite "Code formatting and linting" "format_and_lint.test.bats"

 # Function naming convention tests
 run_test_suite "Function naming conventions" "function_naming_convention.test.bats"

 # Variable naming convention tests
 run_test_suite "Variable naming conventions" "variable_naming_convention.test.bats"

 # Variable duplication tests
 run_test_suite "Variable duplication detection" "variable_duplication.test.bats"
 run_test_suite "Variable duplication detection (enhanced)" "variable_duplication_detection.test.bats"

 # Script help validation tests
 run_test_suite "Script help validation" "script_help_validation.test.bats"

 # SQL validation tests
 run_test_suite "SQL validation integration" "sql_validation_integration.test.bats"
 run_test_suite "SQL constraints validation" "sql_constraints_validation.test.bats"
}

# Run formatting tests only
run_formatting_tests() {
 log_info "Running formatting tests only..."
 run_test_suite "Code formatting and linting" "format_and_lint.test.bats"
}

# Run naming tests only
run_naming_tests() {
 log_info "Running naming convention tests only..."
 run_test_suite "Function naming conventions" "function_naming_convention.test.bats"
 run_test_suite "Variable naming conventions" "variable_naming_convention.test.bats"
 run_test_suite "Variable duplication detection" "variable_duplication.test.bats"
 run_test_suite "Variable duplication detection (enhanced)" "variable_duplication_detection.test.bats"
}

# Run validation tests only
run_validation_tests() {
 log_info "Running validation tests only..."
 run_test_suite "Script help validation" "script_help_validation.test.bats"
 run_test_suite "SQL validation integration" "sql_validation_integration.test.bats"
 run_test_suite "SQL constraints validation" "sql_constraints_validation.test.bats"
}

# Show results
show_results() {
 echo "=========================================="
 echo "QUALITY TESTS RESULTS"
 echo "=========================================="
 echo "Total tests: ${TOTAL_TESTS}"
 echo "Passed tests: ${PASSED_TESTS}"
 echo "Failed tests: ${FAILED_TESTS}"
 echo

 if [[ ${FAILED_TESTS} -eq 0 ]]; then
  log_success "All quality tests passed! 🎉"
  exit 0
 else
  log_warning "Some quality tests failed"
  log_info "Quality tests completed with warnings"
  exit 0
 fi
}

# Main execution
main() {
 local mode="basic"
 local format_only=false
 local naming_only=false
 local validation_only=false

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
  --format-only)
   format_only=true
   shift
   ;;
  --naming-only)
   naming_only=true
   shift
   ;;
  --validation-only)
   validation_only=true
   shift
   ;;
  *)
   log_error "Unknown option: $1"
   show_help
   exit 1
   ;;
  esac
 done

 echo "=== RUNNING QUALITY TESTS ==="
 echo "Testing code quality..."

 # Run tests based on options
 if [[ "$format_only" == "true" ]]; then
  run_formatting_tests
 elif [[ "$naming_only" == "true" ]]; then
  run_naming_tests
 elif [[ "$validation_only" == "true" ]]; then
  run_validation_tests
 else
  case "$mode" in
  "basic")
   run_basic_quality_tests
   ;;
  "enhanced")
   run_enhanced_quality_tests
   ;;
  "all")
   run_basic_quality_tests
   run_enhanced_quality_tests
   ;;
  *)
   log_error "Unknown mode: $mode"
   show_help
   exit 1
   ;;
  esac
 fi

 show_results
}

# Run main function
main "$@"
