#!/bin/bash

# Test CI Fixes Validation Script
# Author: Andres Gomez (AngocA)
# Version: 2025-08-14

# This script tests the fixes applied to resolve GitHub Actions CI failures

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

log_warning() {
 echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
 echo -e "${RED}[ERROR]${NC} $1"
}

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Test function
run_test() {
 local test_name="$1"
 local test_command="$2"
 
 log_info "Running test: ${test_name}"
 TOTAL_TESTS=$((TOTAL_TESTS + 1))
 
 if eval "${test_command}"; then
  log_success "Test passed: ${test_name}"
  PASSED_TESTS=$((PASSED_TESTS + 1))
 else
  log_error "Test failed: ${test_name}"
  FAILED_TESTS=$((FAILED_TESTS + 1))
 fi
 echo ""
}

# Test 1: Check if results directory exists
run_test "Results directory exists" "[[ -d 'tests/results' ]]"

# Test 2: Check if workflows are properly formatted
run_test "Tests workflow is valid YAML" "python3 -c 'import yaml; yaml.safe_load(open(\".github/workflows/tests.yml\"))'"

# Test 3: Check if quality-tests workflow is valid YAML
run_test "Quality-tests workflow is valid YAML" "python3 -c 'import yaml; yaml.safe_load(open(\".github/workflows/quality-tests.yml\"))'"

# Test 4: Check if shellcheck issues were fixed
run_test "Shellcheck passes on wmsConfigExample.sh" "shellcheck -x -o all bin/wms/wmsConfigExample.sh"

# Test 5: Check if shellcheck issues were fixed
run_test "Shellcheck passes on geoserverConfig.sh" "shellcheck -x -o all bin/wms/geoserverConfig.sh"

# Test 6: Check if shellcheck issues were fixed
run_test "Shellcheck passes on wmsManager.sh" "shellcheck -x -o all bin/wms/wmsManager.sh"

# Test 7: Check if shellcheck issues were fixed
run_test "Shellcheck passes on processPlanetNotes.sh" "shellcheck -x -o all bin/process/processPlanetNotes.sh"

# Test 8: Check if base schema files exist
run_test "Base schema enum file exists" "[[ -f 'sql/process/processPlanetNotes_21_createBaseTables_enum.sql' ]]"

# Test 9: Check if DWH schema files exist
run_test "DWH schema file exists" "[[ -f 'sql/dwh/ETL_22_createDWHTables.sql' ]]"

# Test 10: Check if test properties file exists
run_test "Test properties file exists" "[[ -f 'tests/properties.sh' ]]"

# Test 11: Check if run_dwh_tests.sh is executable
run_test "DWH tests script is executable" "[[ -x 'tests/run_dwh_tests.sh' ]]"

# Test 12: Check if integration test files exist
run_test "ETL integration test exists" "[[ -f 'tests/integration/ETL_enhanced_integration.test.bats' ]]"

# Test 13: Check if datamart integration test exists
run_test "Datamart integration test exists" "[[ -f 'tests/integration/datamart_enhanced_integration.test.bats' ]]"

# Test 14: Check if unit test files exist
run_test "Unit test directory exists" "[[ -d 'tests/unit/bash' ]]"

# Test 15: Check if mock commands exist
run_test "Mock commands directory exists" "[[ -d 'tests/mock_commands' ]]"

# Summary
echo "=========================================="
echo "CI Fixes Validation Summary"
echo "=========================================="
echo "Total tests: ${TOTAL_TESTS}"
echo "Passed: ${PASSED_TESTS}"
echo "Failed: ${FAILED_TESTS}"
echo ""

if [[ ${FAILED_TESTS} -eq 0 ]]; then
 log_success "All CI fixes validation tests passed! 🎉"
 exit 0
else
 log_error "Some CI fixes validation tests failed! ❌"
 exit 1
fi
