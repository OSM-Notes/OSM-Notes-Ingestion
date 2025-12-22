#!/bin/bash
# Script to run optimization-related SQL tests
# Author: Andres Gomez (AngocA)
# Version: 2025-12-22

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# Database name (can be overridden by environment variable)
DBNAME="${DBNAME:-notes}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
  echo -e "${YELLOW}[INFO]${NC} $*"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $*"
}

# Check if PostgreSQL is available
if ! command -v psql >/dev/null 2>&1; then
  log_error "PostgreSQL client (psql) is not installed"
  exit 1
fi

# Check database connection
if ! psql -d "${DBNAME}" -c "SELECT 1;" >/dev/null 2>&1; then
  log_error "Cannot connect to database '${DBNAME}'"
  log_info "You can override the database name by setting DBNAME environment variable"
  exit 1
fi

log_info "Running optimization SQL tests against database '${DBNAME}'..."
echo ""

# Test files to run
TESTS=(
  "test_analyze_cache_properties.sql"
  "test_integrity_check_exists.sql"
)

PASSED=0
FAILED=0

for test_file in "${TESTS[@]}"; do
  test_path="${SCRIPT_DIR}/${test_file}"
  
  if [[ ! -f "${test_path}" ]]; then
    log_error "Test file not found: ${test_path}"
    FAILED=$((FAILED + 1))
    continue
  fi
  
  log_info "Running: ${test_file}"
  
  if psql -d "${DBNAME}" -f "${test_path}" >/dev/null 2>&1; then
    log_success "${test_file} PASSED"
    PASSED=$((PASSED + 1))
  else
    log_error "${test_file} FAILED"
    log_info "To see detailed output, run: psql -d ${DBNAME} -f ${test_path}"
    FAILED=$((FAILED + 1))
  fi
  echo ""
done

# Summary
echo "=========================================="
log_info "Test Summary:"
log_success "Passed: ${PASSED}"
if [[ ${FAILED} -gt 0 ]]; then
  log_error "Failed: ${FAILED}"
  exit 1
else
  log_success "Failed: ${FAILED}"
  exit 0
fi

