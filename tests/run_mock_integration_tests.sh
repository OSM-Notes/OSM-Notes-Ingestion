#!/bin/bash

# Run mock integration tests
# Author: Andres Gomez (AngocA)
# Version: 2025-08-01

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

# Function to setup mock environment
setup_mock_environment() {
 log_info "Setting up mock environment..."
 
 # Setup mock commands
 "${SCRIPT_DIR}/setup_mock_environment.sh" setup
}

# Function to run tests with mock environment
run_mock_tests() {
 local test_type="${1:-all}"
 
 log_info "Running mock tests: ${test_type}"
 
 # Setup mock environment
 setup_mock_environment
 source "${SCRIPT_DIR}/setup_mock_environment.sh"
 
 # Activate mock environment
 "${SCRIPT_DIR}/setup_mock_environment.sh" activate
 source "${SCRIPT_DIR}/mock_logger.sh"
 
 # Export test environment variables
 export TEST_TMP_DIR="/tmp/mock_test_$(date +%s)"
 export TMPDIR="${TEST_TMP_DIR}"
 export SCRIPT_BASE_DIRECTORY="${PROJECT_ROOT}"
 export DBNAME="mock_db"
 export DB_USER="mock_user"
 export DB_PASSWORD="mock_password"
 export LOG_LEVEL="INFO"
 
 # Create temporary directory
 mkdir -p "${TEST_TMP_DIR}"
 
 # Run tests based on type
 case "${test_type}" in
  variable-detection)
   log_info "Running variable duplication detection tests..."
   bats "${SCRIPT_DIR}/unit/bash/variable_duplication_detection.test.bats"
   ;;
  help-validation)
   log_info "Running help validation tests..."
   bats "${SCRIPT_DIR}/unit/bash/script_help_validation.test.bats"
   ;;
  integration)
   log_info "Running integration tests..."
   bats "${SCRIPT_DIR}/integration/"
   ;;
  all)
   log_info "Running all mock tests..."
   bats "${SCRIPT_DIR}/unit/bash/variable_duplication_detection.test.bats"
   bats "${SCRIPT_DIR}/unit/bash/script_help_validation.test.bats"
   bats "${SCRIPT_DIR}/unit/bash/functionsProcess.test.bats"
   ;;
  *)
   log_error "Unknown test type: ${test_type}"
   exit 1
   ;;
 esac
 
 # Deactivate mock environment
 "${SCRIPT_DIR}/setup_mock_environment.sh" deactivate
 
 # Cleanup
 rm -rf "${TEST_TMP_DIR}"
}

# Function to test script execution with mock commands
test_script_execution() {
 local script_path="$1"
 local script_name=$(basename "$script_path")
 
 log_info "Testing script execution: ${script_name}"
 
 # Setup mock environment
 setup_mock_environment
 source "${SCRIPT_DIR}/setup_mock_environment.sh"
 
 # Activate mock environment
 "${SCRIPT_DIR}/setup_mock_environment.sh" activate
 source "${SCRIPT_DIR}/mock_logger.sh"
 
 # Export test environment variables
 export TEST_TMP_DIR="/tmp/mock_test_$(date +%s)"
 export TMPDIR="${TEST_TMP_DIR}"
 export SCRIPT_BASE_DIRECTORY="${PROJECT_ROOT}"
 export DBNAME="mock_db"
 export DB_USER="mock_user"
 export DB_PASSWORD="mock_password"
 export LOG_LEVEL="INFO"
 
 # Create temporary directory
 mkdir -p "${TEST_TMP_DIR}"
 
 # Test script with --help
 if [[ -f "${PROJECT_ROOT}/${script_path}" ]]; then
   log_info "Testing ${script_name} with --help..."
   if "${PROJECT_ROOT}/${script_path}" --help > /dev/null 2>&1; then
     log_success "${script_name} --help test passed"
   else
     log_error "${script_name} --help test failed"
     return 1
   fi
 fi
 
 # Deactivate mock environment
 "${SCRIPT_DIR}/setup_mock_environment.sh" deactivate
 
 # Cleanup
 rm -rf "${TEST_TMP_DIR}"
}

# Function to test all main scripts
test_all_scripts() {
 log_info "Testing all main scripts with mock environment..."
 
 local scripts=(
   "bin/cleanupAll.sh"
   "bin/process/processAPINotes.sh"
   "bin/process/processPlanetNotes.sh"
   "bin/dwh/ETL.sh"
   "bin/dwh/profile.sh"
   "bin/wms/wmsManager.sh"
   "bin/cleanupAll.sh"
   "bin/process/updateCountries.sh"
   "bin/dwh/datamartCountries/datamartCountries.sh"
   "bin/dwh/datamartUsers/datamartUsers.sh"
   "bin/wms/geoserverConfig.sh"
 )
 
 local failed_scripts=()
 
 for script in "${scripts[@]}"; do
   if ! test_script_execution "$script"; then
     failed_scripts+=("$script")
   fi
 done
 
 # Report results
 if [[ ${#failed_scripts[@]} -eq 0 ]]; then
   log_success "All script tests passed!"
 else
   log_error "The following scripts failed:"
   for script in "${failed_scripts[@]}"; do
     log_error "  - $script"
   done
   return 1
 fi
}

# Main execution
case "${1:-}" in
 variable-detection)
  run_mock_tests "variable-detection"
  ;;
 help-validation)
  run_mock_tests "help-validation"
  ;;
 integration)
  run_mock_tests "integration"
  ;;
 scripts)
  test_all_scripts
  ;;
 all)
  run_mock_tests "all"
  test_all_scripts
  ;;
 --help | -h)
  echo "Usage: $0 [COMMAND]"
  echo
  echo "Commands:"
  echo "  variable-detection  Run variable duplication detection tests"
  echo "  help-validation     Run help validation tests"
  echo "  integration        Run integration tests"
  echo "  scripts            Test all main scripts with mock environment"
  echo "  all                Run all mock tests and script tests"
  echo "  --help             Show this help"
  exit 0
  ;;
 "")
  log_info "Running all mock tests..."
  run_mock_tests "all"
  test_all_scripts
  ;;
 *)
  log_error "Unknown command: $1"
  log_error "Use --help for usage information"
  exit 1
  ;;
esac

log_success "Mock integration tests completed" 