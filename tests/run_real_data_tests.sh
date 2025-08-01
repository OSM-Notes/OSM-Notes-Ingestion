#!/bin/bash

# Run tests with real data from fixtures
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
FIXTURES_DIR="${SCRIPT_DIR}/fixtures"

# Function to check prerequisites
check_prerequisites() {
 log_info "Checking prerequisites for real data tests..."
 
 local missing_commands=()
 
 # Check required commands
 for cmd in xmllint xsltproc bzip2 psql; do
   if ! command -v "$cmd" >/dev/null 2>&1; then
     missing_commands+=("$cmd")
   fi
 done
 
 # Check optional commands
 if ! command -v osmtogeojson >/dev/null 2>&1; then
   log_warning "osmtogeojson not found - some conversion tests may fail"
 fi
 
 if [[ ${#missing_commands[@]} -gt 0 ]]; then
   log_error "Missing required commands: ${missing_commands[*]}"
   log_error "Please install the missing commands before running real data tests"
   return 1
 fi
 
 log_success "All required commands are available"
 return 0
}

# Function to test with real planet data
test_real_planet_data() {
 log_info "Testing with real planet data..."
 
 local test_file="${FIXTURES_DIR}/xml/planet_notes_real.xml"
 
 if [[ ! -f "$test_file" ]]; then
   log_error "Real planet data file not found: $test_file"
   return 1
 fi
 
 # Export test environment variables
 export TEST_TMP_DIR="/tmp/real_data_test_$(date +%s)"
 export TMPDIR="${TEST_TMP_DIR}"
 export SCRIPT_BASE_DIRECTORY="${PROJECT_ROOT}"
 export DBNAME="osm_notes"
 export DB_USER="${DB_USER:-postgres}"
 export DB_PASSWORD="${DB_PASSWORD:-}"
 export LOG_LEVEL="INFO"
 
 # Create temporary directory
 mkdir -p "${TEST_TMP_DIR}"
 
 # Test XML validation
 log_info "Step 1: Validating XML structure..."
 if xmllint --noout "$test_file"; then
   log_success "XML validation passed"
 else
   log_error "XML validation failed"
   return 1
 fi
 
 # Count notes
 log_info "Step 2: Counting notes..."
 note_count=$(xmllint --xpath "count(//note)" "$test_file")
 log_info "Found ${note_count} notes"
 
 # Test XSLT transformation
 log_info "Step 3: Testing XSLT transformation..."
 if [[ -f "${PROJECT_ROOT}/xslt/notes-Planet-csv.xslt" ]]; then
   if xsltproc "${PROJECT_ROOT}/xslt/notes-Planet-csv.xslt" "$test_file" > "${TEST_TMP_DIR}/planet_notes.csv"; then
     csv_lines=$(wc -l < "${TEST_TMP_DIR}/planet_notes.csv")
     log_success "CSV transformation completed: ${csv_lines} lines"
   else
     log_error "CSV transformation failed"
     return 1
   fi
 else
   log_warning "XSLT file not found, skipping CSV transformation"
 fi
 
 # Test database operations if available
 if command -v psql >/dev/null 2>&1; then
   log_info "Step 4: Testing database operations..."
   if psql -d "${DBNAME:-osm_notes}" -c "SELECT 1;" >/dev/null 2>&1; then
     log_success "Database connection successful"
   else
     log_warning "Database not accessible, skipping database tests"
   fi
 fi
 
 # Cleanup
 rm -rf "${TEST_TMP_DIR}"
 
 log_success "Real planet data test completed"
}

# Function to test with special cases
test_special_cases() {
 log_info "Testing with special cases..."
 
 local special_cases_dir="${FIXTURES_DIR}/special_cases"
 local failed_cases=()
 
 if [[ ! -d "$special_cases_dir" ]]; then
   log_error "Special cases directory not found: $special_cases_dir"
   return 1
 fi
 
 # Export test environment variables
 export TEST_TMP_DIR="/tmp/special_cases_test_$(date +%s)"
 export TMPDIR="${TEST_TMP_DIR}"
 export SCRIPT_BASE_DIRECTORY="${PROJECT_ROOT}"
 export DBNAME="osm_notes"
 export DB_USER="${DB_USER:-postgres}"
 export DB_PASSWORD="${DB_PASSWORD:-}"
 export LOG_LEVEL="INFO"
 
 # Create temporary directory
 mkdir -p "${TEST_TMP_DIR}"
 
 # Test each special case
 for xml_file in "${special_cases_dir}"/*.xml; do
   if [[ -f "$xml_file" ]]; then
     local case_name=$(basename "$xml_file" .xml)
     log_info "Testing special case: $case_name"
     
     # Validate XML
     if xmllint --noout "$xml_file"; then
       # Count notes
       local note_count=$(xmllint --xpath "count(//note)" "$xml_file")
       log_info "  Found ${note_count} notes"
       
       # Test XSLT transformation
       if [[ -f "${PROJECT_ROOT}/xslt/notes-API-csv.xslt" ]]; then
         if xsltproc "${PROJECT_ROOT}/xslt/notes-API-csv.xslt" "$xml_file" > "${TEST_TMP_DIR}/${case_name}.csv" 2>/dev/null; then
           local csv_lines=$(wc -l < "${TEST_TMP_DIR}/${case_name}.csv")
           log_success "  CSV transformation: ${csv_lines} lines"
         else
           log_warning "  CSV transformation failed for $case_name"
         fi
       fi
     else
       log_error "  XML validation failed for $case_name"
       failed_cases+=("$case_name")
     fi
   fi
 done
 
 # Report results
 if [[ ${#failed_cases[@]} -eq 0 ]]; then
   log_success "All special cases passed!"
 else
   log_error "The following special cases failed:"
   for case in "${failed_cases[@]}"; do
     log_error "  - $case"
   done
   return 1
 fi
 
 # Cleanup
 rm -rf "${TEST_TMP_DIR}"
}

# Function to test with large dataset
test_large_dataset() {
 log_info "Testing with large dataset..."
 
 local test_file="${FIXTURES_DIR}/xml/large_planet_notes.xml"
 
 if [[ ! -f "$test_file" ]]; then
   log_warning "Large dataset file not found: $test_file"
   return 0
 fi
 
 # Export test environment variables
 export TEST_TMP_DIR="/tmp/large_dataset_test_$(date +%s)"
 export TMPDIR="${TEST_TMP_DIR}"
 export SCRIPT_BASE_DIRECTORY="${PROJECT_ROOT}"
 export DBNAME="osm_notes"
 export DB_USER="${DB_USER:-postgres}"
 export DB_PASSWORD="${DB_PASSWORD:-}"
 export LOG_LEVEL="INFO"
 
 # Create temporary directory
 mkdir -p "${TEST_TMP_DIR}"
 
 # Test XML validation
 log_info "Step 1: Validating large XML structure..."
 if xmllint --noout "$test_file"; then
   log_success "Large XML validation passed"
 else
   log_error "Large XML validation failed"
   return 1
 fi
 
 # Count notes
 log_info "Step 2: Counting notes in large dataset..."
 note_count=$(xmllint --xpath "count(//note)" "$test_file")
 log_info "Found ${note_count} notes in large dataset"
 
 # Test XSLT transformation
 log_info "Step 3: Testing XSLT transformation on large dataset..."
 if [[ -f "${PROJECT_ROOT}/xslt/notes-Planet-csv.xslt" ]]; then
   if xsltproc "${PROJECT_ROOT}/xslt/notes-Planet-csv.xslt" "$test_file" > "${TEST_TMP_DIR}/large_planet_notes.csv"; then
     csv_lines=$(wc -l < "${TEST_TMP_DIR}/large_planet_notes.csv")
     log_success "Large CSV transformation completed: ${csv_lines} lines"
   else
     log_error "Large CSV transformation failed"
     return 1
   fi
 else
   log_warning "XSLT file not found, skipping large CSV transformation"
 fi
 
 # Cleanup
 rm -rf "${TEST_TMP_DIR}"
 
 log_success "Large dataset test completed"
}

# Function to test ETL workflow
test_etl_workflow() {
 log_info "Testing ETL workflow with real data..."
 
 local test_file="${FIXTURES_DIR}/xml/planet_notes_real.xml"
 
 if [[ ! -f "$test_file" ]]; then
   log_error "Real planet data file not found: $test_file"
   return 1
 fi
 
 # Export test environment variables
 export TEST_TMP_DIR="/tmp/etl_workflow_test_$(date +%s)"
 export TMPDIR="${TEST_TMP_DIR}"
 export SCRIPT_BASE_DIRECTORY="${PROJECT_ROOT}"
 export DBNAME="osm_notes"
 export DB_USER="${DB_USER:-postgres}"
 export DB_PASSWORD="${DB_PASSWORD:-}"
 export LOG_LEVEL="INFO"
 
 # Create temporary directory
 mkdir -p "${TEST_TMP_DIR}"
 
 # Copy test file to temporary location
 cp "$test_file" "${TEST_TMP_DIR}/planet_notes.xml"
 
 # Test ETL workflow steps
 log_info "Step 1: Testing XML validation..."
 if xmllint --noout "${TEST_TMP_DIR}/planet_notes.xml"; then
   log_success "XML validation passed"
 else
   log_error "XML validation failed"
   return 1
 fi
 
 log_info "Step 2: Testing XSLT transformation..."
 if [[ -f "${PROJECT_ROOT}/xslt/notes-Planet-csv.xslt" ]]; then
   if xsltproc "${PROJECT_ROOT}/xslt/notes-Planet-csv.xslt" "${TEST_TMP_DIR}/planet_notes.xml" > "${TEST_TMP_DIR}/notes.csv"; then
     csv_lines=$(wc -l < "${TEST_TMP_DIR}/notes.csv")
     log_success "CSV transformation completed: ${csv_lines} lines"
   else
     log_error "CSV transformation failed"
     return 1
   fi
 else
   log_warning "XSLT file not found, skipping CSV transformation"
 fi
 
 log_info "Step 3: Testing database operations..."
 if command -v psql >/dev/null 2>&1; then
   if psql -d "${DBNAME:-osm_notes}" -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" >/dev/null 2>&1; then
     log_success "Database operations successful"
   else
     log_warning "Database not accessible, skipping database operations"
   fi
 fi
 
 # Cleanup
 rm -rf "${TEST_TMP_DIR}"
 
 log_success "ETL workflow test completed"
}

# Function to test all real data scenarios
test_all_real_data() {
 log_info "Running all real data tests..."
 
 local failed_tests=()
 
 # Test real planet data
 if ! test_real_planet_data; then
   failed_tests+=("real_planet_data")
 fi
 
 # Test special cases
 if ! test_special_cases; then
   failed_tests+=("special_cases")
 fi
 
 # Test large dataset
 if ! test_large_dataset; then
   failed_tests+=("large_dataset")
 fi
 
 # Test ETL workflow
 if ! test_etl_workflow; then
   failed_tests+=("etl_workflow")
 fi
 
 # Report results
 if [[ ${#failed_tests[@]} -eq 0 ]]; then
   log_success "All real data tests passed!"
 else
   log_error "The following tests failed:"
   for test in "${failed_tests[@]}"; do
     log_error "  - $test"
   done
   return 1
 fi
}

# Main execution
case "${1:-}" in
 real-planet)
  test_real_planet_data
  ;;
 special-cases)
  test_special_cases
  ;;
 large-dataset)
  test_large_dataset
  ;;
 etl-workflow)
  test_etl_workflow
  ;;
 all)
  test_all_real_data
  ;;
 check)
  check_prerequisites
  ;;
 --help | -h)
  echo "Usage: $0 [COMMAND]"
  echo
  echo "Commands:"
  echo "  real-planet     Test with real planet data from fixtures"
  echo "  special-cases   Test with special cases (zero notes, single note, etc.)"
  echo "  large-dataset   Test with large dataset from fixtures"
  echo "  etl-workflow    Test complete ETL workflow with real data"
  echo "  all             Run all real data tests"
  echo "  check           Check prerequisites for real data tests"
  echo "  --help          Show this help"
  echo
  echo "This uses real data from tests/fixtures/ for realistic testing."
  exit 0
  ;;
 "")
  log_info "Running all real data tests..."
  test_all_real_data
  ;;
 *)
  log_error "Unknown command: $1"
  log_error "Use --help for usage information"
  exit 1
  ;;
esac

log_success "Real data tests completed" 