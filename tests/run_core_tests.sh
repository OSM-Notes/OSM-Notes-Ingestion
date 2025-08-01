#!/bin/bash

# Core Test Runner for OSM-Notes-profile
# Author: Andres Gomez (AngocA)
# Version: 2025-07-30

set -euo pipefail

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

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Test files to run (core tests that we know work)
TEST_FILES=(
 "tests/unit/bash/functionsProcess.test.bats"
 "tests/unit/bash/processPlanetNotes.test.bats"
 "tests/unit/bash/cleanupAll.test.bats"
)

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

log_info "Starting core test execution..."

for test_file in "${TEST_FILES[@]}"; do
 log_info "Running: ${test_file}"
 
 # Check if file exists
 if [[ ! -f "${test_file}" ]]; then
  log_error "Test file not found: ${test_file}"
  continue
 fi
 
 # Run the test
 if bats "${test_file}"; then
  log_success "${test_file} passed"
  ((PASSED_TESTS++))
 else
  log_error "${test_file} failed"
  ((FAILED_TESTS++))
 fi
 ((TOTAL_TESTS++))
done

echo
echo "=========================================="
echo "CORE TEST SUMMARY"
echo "=========================================="
echo "Total tests: ${TOTAL_TESTS}"
echo "Passed: ${PASSED_TESTS}"
echo "Failed: ${FAILED_TESTS}"

if [[ ${FAILED_TESTS} -eq 0 ]]; then
 log_success "All core tests passed! 🎉"
 exit 0
else
 log_error "Some core tests failed! ❌"
 exit 1
fi 