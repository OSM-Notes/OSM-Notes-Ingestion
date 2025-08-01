#!/bin/bash

# Run hybrid tests (mock internet downloads, real database/XML processing) - Fixed version
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

# Function to check prerequisites
check_prerequisites() {
 log_info "Checking prerequisites for hybrid tests..."
 
 local missing_commands=()
 
 # Check required commands
 for cmd in xmllint xsltproc bzip2; do
   if ! command -v "$cmd" >/dev/null 2>&1; then
     missing_commands+=("$cmd")
   fi
 done
 
 # Check optional commands
 if ! command -v psql >/dev/null 2>&1; then
   log_warning "psql not found - database tests will be skipped"
 fi
 
 if ! command -v osmtogeojson >/dev/null 2>&1; then
   log_warning "osmtogeojson not found - some conversion tests may fail"
 fi
 
 if [[ ${#missing_commands[@]} -gt 0 ]]; then
   log_error "Missing required commands: ${missing_commands[*]}"
   log_error "Please install the missing commands before running hybrid tests"
   return 1
 fi
 
 log_success "All required commands are available"
 return 0
}

# Function to run hybrid tests
run_hybrid_tests() {
 local test_type="${1:-all}"
 
 log_info "Running hybrid tests: ${test_type}"
 
 # Setup hybrid mock environment
 "${SCRIPT_DIR}/setup_hybrid_mock_environment.sh" setup
 
 # Check real commands
 "${SCRIPT_DIR}/setup_hybrid_mock_environment.sh" check
 
 # Activate hybrid mock environment
 "${SCRIPT_DIR}/setup_hybrid_mock_environment.sh" activate
 source "${SCRIPT_DIR}/mock_logger.sh"
 
 # Export test environment variables
 export TEST_TMP_DIR="/tmp/hybrid_test_$(date +%s)"
 export TMPDIR="${TEST_TMP_DIR}"
 export SCRIPT_BASE_DIRECTORY="${PROJECT_ROOT}"
 export DBNAME="osm_notes"
 export DB_USER="${DB_USER:-postgres}"
 export DB_PASSWORD="${DB_PASSWORD:-}"
 export LOG_LEVEL="INFO"
 
 # Create temporary directory
 mkdir -p "${TEST_TMP_DIR}"
 
 # Run tests based on type
 case "${test_type}" in
  hybrid-integration)
   log_info "Running hybrid integration tests..."
   bats "${SCRIPT_DIR}/unit/bash/hybrid_integration.test.bats"
   ;;
  variable-detection)
   log_info "Running variable duplication detection tests..."
   bats "${SCRIPT_DIR}/unit/bash/variable_duplication_detection.test.bats"
   ;;
  help-validation)
   log_info "Running help validation tests..."
   bats "${SCRIPT_DIR}/unit/bash/script_help_validation.test.bats"
   ;;
  all)
   log_info "Running all hybrid tests..."
   bats "${SCRIPT_DIR}/unit/bash/hybrid_integration.test.bats"
   bats "${SCRIPT_DIR}/unit/bash/variable_duplication_detection.test.bats"
   bats "${SCRIPT_DIR}/unit/bash/script_help_validation.test.bats"
   ;;
  *)
   log_error "Unknown test type: ${test_type}"
   exit 1
   ;;
 esac
 
 # Deactivate hybrid mock environment
 "${SCRIPT_DIR}/setup_hybrid_mock_environment.sh" deactivate
 
 # Cleanup
 rm -rf "${TEST_TMP_DIR}"
}

# Function to test script execution with hybrid environment
test_script_execution_hybrid() {
 local script_path="$1"
 local script_name=$(basename "$script_path")
 
 log_info "Testing script execution with hybrid environment: ${script_name}"
 
 # Setup hybrid mock environment
 "${SCRIPT_DIR}/setup_hybrid_mock_environment.sh" setup
 
 # Activate hybrid mock environment
 "${SCRIPT_DIR}/setup_hybrid_mock_environment.sh" activate
 source "${SCRIPT_DIR}/mock_logger.sh"
 
 # Export test environment variables
 export TEST_TMP_DIR="/tmp/hybrid_test_$(date +%s)"
 export TMPDIR="${TEST_TMP_DIR}"
 export SCRIPT_BASE_DIRECTORY="${PROJECT_ROOT}"
 export DBNAME="osm_notes"
 export DB_USER="${DB_USER:-postgres}"
 export DB_PASSWORD="${DB_PASSWORD:-}"
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
 
 # Deactivate hybrid mock environment
 "${SCRIPT_DIR}/setup_hybrid_mock_environment.sh" deactivate
 
 # Cleanup
 rm -rf "${TEST_TMP_DIR}"
}

# Function to test all main scripts with hybrid environment
test_all_scripts_hybrid() {
 log_info "Testing all main scripts with hybrid environment..."
 
 local scripts=(
   "bin/cleanupAll.sh"
   "bin/process/processAPINotes.sh"
   "bin/process/processPlanetNotes.sh"
   "bin/dwh/ETL.sh"
   "bin/dwh/profile.sh"
   "bin/wms/wmsManager.sh"
   "bin/cleanupPartitions.sh"
   "bin/process/updateCountries.sh"
   "bin/dwh/datamartCountries/datamartCountries.sh"
   "bin/dwh/datamartUsers/datamartUsers.sh"
   "bin/wms/geoserverConfig.sh"
 )
 
 local failed_scripts=()
 
 for script in "${scripts[@]}"; do
   if ! test_script_execution_hybrid "$script"; then
     failed_scripts+=("$script")
   fi
 done
 
 # Report results
 if [[ ${#failed_scripts[@]} -eq 0 ]]; then
   log_success "All script tests passed with hybrid environment!"
 else
   log_error "The following scripts failed with hybrid environment:"
   for script in "${failed_scripts[@]}"; do
     log_error "  - $script"
   done
   return 1
 fi
}

# Function to run end-to-end workflow test
run_end_to_end_workflow() {
 log_info "Running end-to-end workflow test with hybrid environment..."
 
 # Setup hybrid mock environment
 "${SCRIPT_DIR}/setup_hybrid_mock_environment.sh" setup
 
 # Activate hybrid mock environment
 "${SCRIPT_DIR}/setup_hybrid_mock_environment.sh" activate
 source "${SCRIPT_DIR}/mock_logger.sh"
 
 # Export test environment variables
 export TEST_TMP_DIR="/tmp/hybrid_e2e_$(date +%s)"
 export TMPDIR="${TEST_TMP_DIR}"
 export SCRIPT_BASE_DIRECTORY="${PROJECT_ROOT}"
 export DBNAME="osm_notes"
 export DB_USER="${DB_USER:-postgres}"
 export DB_PASSWORD="${DB_PASSWORD:-}"
 export LOG_LEVEL="INFO"
 
 # Create temporary directory
 mkdir -p "${TEST_TMP_DIR}"
 
 # Test workflow steps
 log_info "Step 1: Download mock data..."
 wget -O "${TEST_TMP_DIR}/planet_notes.xml" "https://planet.openstreetmap.org/notes/planet-notes-latest.osm.bz2"
 
 log_info "Step 2: Validate XML structure..."
 if xmllint --noout "${TEST_TMP_DIR}/planet_notes.xml"; then
   log_success "XML validation passed"
 else
   log_error "XML validation failed"
   return 1
 fi
 
 log_info "Step 3: Count notes..."
 note_count=$(xmllint --xpath "count(//note)" "${TEST_TMP_DIR}/planet_notes.xml")
 log_info "Found ${note_count} notes"
 
 log_info "Step 4: Transform to CSV (if XSLT available)..."
 if [[ -f "${SCRIPT_BASE_DIRECTORY}/xslt/notes-Planet-csv.xslt" ]]; then
   if xsltproc "${SCRIPT_BASE_DIRECTORY}/xslt/notes-Planet-csv.xslt" "${TEST_TMP_DIR}/planet_notes.xml" > "${TEST_TMP_DIR}/notes.csv"; then
     csv_lines=$(wc -l < "${TEST_TMP_DIR}/notes.csv")
     log_success "CSV transformation completed: ${csv_lines} lines"
   else
     log_error "CSV transformation failed"
     return 1
   fi
 else
   log_warning "XSLT file not found, skipping CSV transformation"
 fi
 
 # Deactivate hybrid mock environment
 "${SCRIPT_DIR}/setup_hybrid_mock_environment.sh" deactivate
 
 # Cleanup
 rm -rf "${TEST_TMP_DIR}"
 
 log_success "End-to-end workflow test completed successfully"
}

# Main execution
case "${1:-}" in
 hybrid-integration)
  run_hybrid_tests "hybrid-integration"
  ;;
 variable-detection)
  run_hybrid_tests "variable-detection"
  ;;
 help-validation)
  run_hybrid_tests "help-validation"
  ;;
 scripts)
  test_all_scripts_hybrid
  ;;
 e2e)
  run_end_to_end_workflow
  ;;
 all)
  run_hybrid_tests "all"
  test_all_scripts_hybrid
  run_end_to_end_workflow
  ;;
 check)
  check_prerequisites
  ;;
 --help | -h)
  echo "Usage: $0 [COMMAND]"
  echo
  echo "Commands:"
  echo "  hybrid-integration  Run hybrid integration tests (mock downloads, real processing)"
  echo "  variable-detection  Run variable duplication detection tests"
  echo "  help-validation     Run help validation tests"
  echo "  scripts            Test all main scripts with hybrid environment"
  echo "  e2e                Run end-to-end workflow test"
  echo "  all                Run all hybrid tests and workflows"
  echo "  check              Check prerequisites for hybrid tests"
  echo "  --help             Show this help"
  echo
  echo "This environment mocks internet downloads (wget, aria2c) but uses"
  echo "real commands for database and XML processing."
  exit 0
  ;;
 "")
  log_info "Running all hybrid tests..."
  run_hybrid_tests "all"
  test_all_scripts_hybrid
  run_end_to_end_workflow
  ;;
 *)
  log_error "Unknown command: $1"
  log_error "Use --help for usage information"
  exit 1
  ;;
esac

log_success "Hybrid tests completed" 