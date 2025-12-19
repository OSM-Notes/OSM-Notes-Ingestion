#!/bin/bash

# Script to run comment_insertion_flow test
# Author: Andres Gomez (AngocA)
# Version: 2025-12-19

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
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

# Detect database name from properties or use default
if [[ -z "${TEST_DBNAME:-}" ]]; then
  # Try to load properties file to get DBNAME
  if [[ -f "${PROJECT_ROOT}/etc/properties.sh" ]]; then
    # shellcheck disable=SC1090
    source "${PROJECT_ROOT}/etc/properties.sh" 2> /dev/null || true
    TEST_DBNAME="${DBNAME:-}"
  fi

  # If still not set, check which database exists
  if [[ -z "${TEST_DBNAME:-}" ]]; then
    if psql -d "osm-notes" -c "SELECT 1;" > /dev/null 2>&1; then
      TEST_DBNAME="osm-notes"
    elif psql -d "notes" -c "SELECT 1;" > /dev/null 2>&1; then
      TEST_DBNAME="notes"
    else
      TEST_DBNAME="osm-notes"
    fi
  fi
fi

TEST_FILE="${SCRIPT_DIR}/unit/sql/comment_insertion_flow.test.sql"

# Check if test database exists
check_database() {
  if ! psql -d "${TEST_DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
    log_error "Test database '${TEST_DBNAME}' does not exist"
    log_info "Please run the setup script first:"
    log_info "  ${SCRIPT_DIR}/setup_test_environment_for_comment_insertion.sh"
    exit 1
  fi
}

# Run the test
run_test() {
  log_info "Running comment_insertion_flow test..."
  echo ""

  if psql -d "${TEST_DBNAME}" \
    --set ON_ERROR_STOP=1 \
    -f "${TEST_FILE}" \
    2>&1 | tee /tmp/comment_insertion_test_output.log; then
    echo ""
    log_success "Test completed successfully!"

    # Show summary of test notices
    if grep -q "Test passed:" /tmp/comment_insertion_test_output.log 2> /dev/null; then
      echo ""
      log_info "Test results summary:"
      grep "Test passed:" /tmp/comment_insertion_test_output.log | sed 's/^/  /'
    fi

    return 0
  else
    echo ""
    log_error "Test failed. Check the output above for details."
    return 1
  fi
}

# Main execution
main() {
  check_database
  run_test
}

# Run main function
main
