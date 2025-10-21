#!/bin/bash

# Master test runner for OSM-Notes-profile
# Author: Andres Gomez (AngocA)
# Version: 2025-07-28

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

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Function to show test statistics
show_test_stats() {
 local total_tests="$1"
 local passed_tests="$2"
 local failed_tests="$3"
 local percentage=$((passed_tests * 100 / total_tests))

 echo
 echo "📊 Test Results Summary:"
 echo "========================="
 echo "Total Tests: ${total_tests}"
 echo "Passed: ${passed_tests} ✅"
 echo "Failed: ${failed_tests} ❌"
 echo "Success Rate: ${percentage}%"
 echo
}

# Function to run tests with database
run_db_tests() {
 log_info "Running tests with real database..."

 if [[ -f "${SCRIPT_DIR}/run_tests_as_notes.sh" ]]; then
  "${SCRIPT_DIR}/run_tests_as_notes.sh" "$@"
 else
  log_error "Database test runner not found"
  return 1
 fi
}

# Function to run mock tests
run_mock_tests() {
 log_info "Running tests with mock environment..."

 if [[ -f "${SCRIPT_DIR}/run_mock_tests.sh" ]]; then
  "${SCRIPT_DIR}/run_mock_tests.sh" "$@"
 else
  log_error "Mock test runner not found"
  return 1
 fi
}

# Function to run simple tests
run_simple_tests() {
 log_info "Running simple tests..."

 if [[ -f "${SCRIPT_DIR}/run_tests_simple.sh" ]]; then
  "${SCRIPT_DIR}/run_tests_simple.sh" "$@"
 else
  log_error "Simple test runner not found"
  return 1
 fi
}

# Function to show available options
show_help() {
 echo "OSM-Notes-profile Test Runner"
 echo "============================="
 echo
 echo "Usage: $0 [MODE] [TEST_TYPE]"
 echo
 echo "Modes:"
 echo "  --db          Run tests with real database (requires PostgreSQL)"
 echo "  --mock        Run tests with mock environment (no database required)"
 echo "  --simple      Run simple tests (basic validation)"
 echo "  --all         Run all test modes"
 echo
 echo "Test Types:"
 echo "  --unit        Run unit tests only"
 echo "  --integration Run integration tests only"
 echo "  --all-tests   Run all test types"
 echo
 echo "Examples:"
 echo "  $0 --db --integration   # Run integration tests with database"
 echo "  $0 --mock --unit        # Run unit tests with mock environment"
 echo "  $0 --all --all-tests    # Run all tests in all modes"
 echo
 echo "Prerequisites:"
 echo "  - Database tests: PostgreSQL with user 'notes'"
 echo "  - Mock tests: No prerequisites"
 echo "  - Simple tests: Basic system tools"
}

# Main execution
case "${1:-}" in
--db)
 case "${2:-}" in
 --unit)
  run_db_tests --unit
  ;;
 --integration)
  run_db_tests --integration
  ;;
 --etl)
  run_db_tests --etl
  ;;
 --all-tests)
  run_db_tests --all
  ;;
 "")
  run_db_tests --all
  ;;
 *)
  log_error "Unknown test type: $2"
  show_help
  exit 1
  ;;
 esac
 ;;
--mock)
 case "${2:-}" in
 --unit)
  run_mock_tests --unit
  ;;
 --integration)
  run_mock_tests --integration
  ;;
 --etl)
  run_mock_tests --etl
  ;;
 --all-tests)
  run_mock_tests --all
  ;;
 "")
  run_mock_tests --all
  ;;
 *)
  log_error "Unknown test type: $2"
  show_help
  exit 1
  ;;
 esac
 ;;
--simple)
 case "${2:-}" in
 --unit)
  run_simple_tests --unit
  ;;
 --integration)
  run_simple_tests --integration
  ;;
 --etl)
  run_simple_tests --etl
  ;;
 --all-tests)
  run_simple_tests
  ;;
 "")
  run_simple_tests
  ;;
 *)
  log_error "Unknown test type: $2"
  show_help
  exit 1
  ;;
 esac
 ;;
--all)
 log_info "Running all test modes..."
 echo
 echo "🔧 Database Tests:"
 run_db_tests --etl || log_warning "Database tests failed"
 echo
 echo "🎭 Mock Tests:"
 run_mock_tests --etl || log_warning "Mock tests failed"
 echo
 echo "📋 Simple Tests:"
 run_simple_tests --etl || log_warning "Simple tests failed"
 ;;
--help | -h)
 show_help
 exit 0
 ;;
"")
 log_info "No mode specified, showing help..."
 show_help
 exit 0
 ;;
*)
 log_error "Unknown mode: $1"
 show_help
 exit 1
 ;;
esac

log_success "Test execution completed"
