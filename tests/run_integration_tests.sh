#!/bin/bash

# Integration Test Runner for OSM-Notes-profile
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

log_warning() {
 echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Test files to run
INTEGRATION_TESTS=(
 "tests/integration/end_to_end.test.bats"
 "tests/integration/ETL_enhanced_integration.test.bats"
 "tests/integration/wms_integration.test.bats"
)

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

log_info "Starting integration test execution..."

# Check prerequisites
log_info "Checking prerequisites..."

# Check if PostgreSQL is running
if ! pg_isready -h "${TEST_DBHOST:-localhost}" -p "${TEST_DBPORT:-5432}" -U "${TEST_DBUSER:-angoca}" &> /dev/null; then
 log_error "PostgreSQL is not accessible"
 log_info "Please ensure PostgreSQL is running and accessible"
 exit 1
fi

# Check if BATS is installed
if ! command -v bats &> /dev/null; then
 log_error "BATS is not installed"
 log_info "Please install BATS: sudo apt-get install bats"
 exit 1
fi

log_success "Prerequisites check completed"

# Setup test database
log_info "Setting up test database..."

# Create test database if it doesn't exist
if ! psql -h "${TEST_DBHOST:-localhost}" -p "${TEST_DBPORT:-5432}" -U "${TEST_DBUSER:-angoca}" -d "${TEST_DBNAME:-osm_notes_test}" -c "SELECT 1;" &> /dev/null; then
 log_info "Creating test database..."
 createdb -h "${TEST_DBHOST:-localhost}" -p "${TEST_DBPORT:-5432}" -U "${TEST_DBUSER:-angoca}" "${TEST_DBNAME:-osm_notes_test}"
fi

log_success "Test database setup completed"

# Run integration tests
for test_file in "${INTEGRATION_TESTS[@]}"; do
 log_info "Running: ${test_file}"
 
 # Check if file exists
 if [[ ! -f "${test_file}" ]]; then
  log_error "Test file not found: ${test_file}"
  continue
 fi
 
 # Set environment variables for tests
 export TEST_DBNAME="${TEST_DBNAME:-osm_notes_test}"
 export TEST_DBUSER="${TEST_DBUSER:-angoca}"
 export TEST_DBPASSWORD="${TEST_DBPASSWORD:-}"
 export TEST_DBHOST="${TEST_DBHOST:-localhost}"
 export TEST_DBPORT="${TEST_DBPORT:-5432}"
 
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
echo "INTEGRATION TEST SUMMARY"
echo "=========================================="
echo "Total tests: ${TOTAL_TESTS}"
echo "Passed: ${PASSED_TESTS}"
echo "Failed: ${FAILED_TESTS}"

if [[ ${FAILED_TESTS} -eq 0 ]]; then
 log_success "All integration tests passed! 🎉"
 exit 0
else
 log_error "Some integration tests failed! ❌"
 exit 1
fi 