#!/bin/bash

# Simple CI Test Runner for OSM-Notes-profile
# This script runs basic tests for CI/CD pipeline
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-29

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test results
TESTS_PASSED=0
TESTS_FAILED=0

# Function to print colored output
print_status() {
    local status="$1"
    local message="$2"
    case "$status" in
        "PASS")
            echo -e "${GREEN}✓ PASS${NC}: $message"
            ((TESTS_PASSED++))
            ;;
        "FAIL")
            echo -e "${RED}✗ FAIL${NC}: $message"
            ((TESTS_FAILED++))
            ;;
        "WARN")
            echo -e "${YELLOW}⚠ WARN${NC}: $message"
            ;;
    esac
}

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo "Running: $test_name"
    if eval "$test_command" >/dev/null 2>&1; then
        print_status "PASS" "$test_name"
    else
        print_status "FAIL" "$test_name"
    fi
}

# Main test execution
main() {
    echo "Starting CI Tests for OSM-Notes-profile"
    echo "======================================"
    
    # Test 1: Check if required files exist
    run_test "Check required files exist" "
        test -f bin/functionsProcess.sh &&
        test -f bin/process/processAPINotes.sh &&
        test -f bin/process/processPlanetNotes.sh &&
        test -f tests/test_helper.bash
    "
    
    # Test 2: Check if scripts are executable
    run_test "Check scripts are executable" "
        test -x tests/run_tests.sh &&
        test -x tests/setup_test_db.sh
    "
    
    # Test 3: Check if bats is available
    run_test "Check bats is available" "command -v bats >/dev/null 2>&1"
    
    # Test 4: Check if shellcheck is available
    run_test "Check shellcheck is available" "command -v shellcheck >/dev/null 2>&1"
    
    # Test 5: Run basic syntax check on main scripts
    run_test "Syntax check functionsProcess.sh" "bash -n bin/functionsProcess.sh"
    run_test "Syntax check processAPINotes.sh" "bash -n bin/process/processAPINotes.sh"
    run_test "Syntax check processPlanetNotes.sh" "bash -n bin/process/processPlanetNotes.sh"
    
    # Test 6: Run shellcheck on main scripts
    run_test "ShellCheck functionsProcess.sh" "shellcheck bin/functionsProcess.sh"
    run_test "ShellCheck processAPINotes.sh" "shellcheck bin/process/processAPINotes.sh"
    run_test "ShellCheck processPlanetNotes.sh" "shellcheck bin/process/processPlanetNotes.sh"
    
    # Test 7: Check if test files exist
    run_test "Check test files exist" "
        test -f tests/unit/bash/error_handling_enhanced.test.bats &&
        test -f tests/unit/bash/boundary_validation.test.bats
    "
    
    # Test 8: Run basic bats test (if possible)
    if command -v bats >/dev/null 2>&1; then
        run_test "Run basic bats test" "
            bats tests/unit/bash/error_handling_enhanced.test.bats --tap | head -20
        "
    else
        print_status "WARN" "bats not available, skipping bats tests"
    fi
    
    # Test 9: Check if Docker files exist (for integration tests)
    run_test "Check Docker files exist" "
        test -f tests/docker/docker-compose.yml &&
        test -f tests/docker/Dockerfile
    "
    
    # Test 10: Check if properties files exist
    run_test "Check properties files exist" "
        test -f etc/properties.sh &&
        test -f etc/etl.properties
    "
    
    echo ""
    echo "Test Summary"
    echo "============"
    echo "Tests Passed: $TESTS_PASSED"
    echo "Tests Failed: $TESTS_FAILED"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed!${NC}"
        exit 1
    fi
}

# Run main function
main "$@" 