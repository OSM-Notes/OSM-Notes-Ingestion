#!/bin/bash

# Verify CI/CD Environment for Tests
# Author: Andres Gomez (AngocA)
# Version: 2025-10-13

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Logging functions
log_info() {
 echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
 echo -e "${GREEN}[SUCCESS]${NC} $1"
 ((PASSED_CHECKS++)) || true
}

log_warning() {
 echo -e "${YELLOW}[WARNING]${NC} $1"
 ((WARNING_CHECKS++)) || true
}

log_error() {
 echo -e "${RED}[ERROR]${NC} $1"
 ((FAILED_CHECKS++)) || true
}

# Function to verify directories
__verify_directories() {
 log_info "Verifying test directories..."

 local -a REQUIRED_DIRECTORIES=(
  "${SCRIPT_DIR}/tmp"
  "${SCRIPT_DIR}/output"
  "${SCRIPT_DIR}/results"
 )

 for DIR in "${REQUIRED_DIRECTORIES[@]}"; do
  ((TOTAL_CHECKS++)) || true
  if [[ -d "${DIR}" ]]; then
   if [[ -r "${DIR}" && -w "${DIR}" ]]; then
    log_success "Directory exists and is accessible: ${DIR}"
   else
    log_error "Directory exists but is not accessible: ${DIR}"
   fi
  else
   log_error "Directory does not exist: ${DIR}"
  fi
 done
}

# Function to verify environment variables
__verify_environment_variables() {
 log_info "Verifying environment variables..."

 local -a REQUIRED_VARS=(
  "DBNAME"
  "DBHOST"
  "DBPORT"
  "DBUSER"
 )

 for VAR in "${REQUIRED_VARS[@]}"; do
  ((TOTAL_CHECKS++)) || true
  if [[ -n "${!VAR:-}" ]]; then
   log_success "Environment variable is set: ${VAR}=${!VAR}"
  else
   log_error "Environment variable is not set: ${VAR}"
  fi
 done

 # Check optional variables
 local -a OPTIONAL_VARS=(
  "TEST_MODE"
  "CI_MODE"
  "LOG_LEVEL"
  "MAX_THREADS"
 )

 for VAR in "${OPTIONAL_VARS[@]}"; do
  ((TOTAL_CHECKS++)) || true
  if [[ -n "${!VAR:-}" ]]; then
   log_success "Optional variable is set: ${VAR}=${!VAR}"
  else
   log_warning "Optional variable is not set: ${VAR}"
  fi
 done
}

# Function to verify required tools
__verify_required_tools() {
 log_info "Verifying required tools..."

 local -a REQUIRED_TOOLS=(
  "bats"
  "psql"
  "xmllint"
  "xsltproc"
  "shellcheck"
 )

 for TOOL in "${REQUIRED_TOOLS[@]}"; do
  ((TOTAL_CHECKS++)) || true
  if command -v "${TOOL}" > /dev/null 2>&1; then
   local VERSION
   VERSION=$(${TOOL} --version 2>&1 | head -1 || echo "unknown")
   log_success "Tool is available: ${TOOL} (${VERSION})"
  else
   log_error "Tool is not available: ${TOOL}"
  fi
 done

 # Check optional tools
 local -a OPTIONAL_TOOLS=(
  "shfmt"
  "aria2c"
  "osmtogeojson"
 )

 for TOOL in "${OPTIONAL_TOOLS[@]}"; do
  ((TOTAL_CHECKS++)) || true
  if command -v "${TOOL}" > /dev/null 2>&1; then
   local VERSION
   VERSION=$(${TOOL} --version 2>&1 | head -1 || echo "unknown")
   log_success "Optional tool is available: ${TOOL} (${VERSION})"
  else
   log_warning "Optional tool is not available: ${TOOL}"
  fi
 done
}

# Function to verify database connection
__verify_database_connection() {
 log_info "Verifying database connection..."

 ((TOTAL_CHECKS++)) || true

 # Check if psql is available
 if ! command -v psql > /dev/null 2>&1; then
  log_error "psql command not found, cannot verify database connection"
  return 1
 fi

 # Try to connect to database
 local DBHOST="${DBHOST:-localhost}"
 local DBPORT="${DBPORT:-5432}"
 local DBUSER="${DBUSER:-postgres}"
 local DBNAME="${DBNAME:-osm_notes_test}"

 if PGPASSWORD="${DBPASSWORD:-}" psql -h "${DBHOST}" -p "${DBPORT}" \
  -U "${DBUSER}" -d "${DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
  log_success "Database connection successful: ${DBUSER}@${DBHOST}:${DBPORT}/${DBNAME}"
 else
  log_warning "Database connection failed: ${DBUSER}@${DBHOST}:${DBPORT}/${DBNAME}"
  log_warning "Tests requiring database connection may fail"
 fi
}

# Function to verify test files
__verify_test_files() {
 log_info "Verifying test files..."

 local -a TEST_RUNNERS=(
  "${SCRIPT_DIR}/run_tests.sh"
  "${SCRIPT_DIR}/run_integration_tests.sh"
  "${SCRIPT_DIR}/run_all_tests.sh"
 )

 for FILE in "${TEST_RUNNERS[@]}"; do
  ((TOTAL_CHECKS++)) || true
  if [[ -f "${FILE}" ]]; then
   if [[ -x "${FILE}" ]]; then
    log_success "Test runner exists and is executable: $(basename "${FILE}")"
   else
    log_warning "Test runner exists but is not executable: $(basename "${FILE}")"
   fi
  else
   log_warning "Test runner does not exist: $(basename "${FILE}")"
  fi
 done

 # Verify test directories
 local -a TEST_DIRECTORIES=(
  "${SCRIPT_DIR}/unit"
  "${SCRIPT_DIR}/integration"
  "${SCRIPT_DIR}/fixtures"
 )

 for DIR in "${TEST_DIRECTORIES[@]}"; do
  ((TOTAL_CHECKS++)) || true
  if [[ -d "${DIR}" ]]; then
   local FILE_COUNT
   FILE_COUNT=$(find "${DIR}" -type f -name "*.bats" 2> /dev/null | wc -l)
   log_success "Test directory exists: $(basename "${DIR}") (${FILE_COUNT} test files)"
  else
   log_warning "Test directory does not exist: $(basename "${DIR}")"
  fi
 done
}

# Function to verify system resources
__verify_system_resources() {
 log_info "Verifying system resources..."

 ((TOTAL_CHECKS++)) || true

 # Check available memory
 if command -v free > /dev/null 2>&1; then
  local AVAILABLE_MEM
  AVAILABLE_MEM=$(free -m | awk '/^Mem:/{print $7}')
  if [[ ${AVAILABLE_MEM} -gt 512 ]]; then
   log_success "Available memory: ${AVAILABLE_MEM} MB"
  else
   log_warning "Low available memory: ${AVAILABLE_MEM} MB"
  fi
 else
  log_info "free command not available, skipping memory check"
 fi

 ((TOTAL_CHECKS++)) || true

 # Check available disk space
 if command -v df > /dev/null 2>&1; then
  local AVAILABLE_DISK
  AVAILABLE_DISK=$(df -h "${PROJECT_ROOT}" | awk 'NR==2 {print $4}')
  log_success "Available disk space: ${AVAILABLE_DISK}"
 else
  log_info "df command not available, skipping disk space check"
 fi

 ((TOTAL_CHECKS++)) || true

 # Check CPU cores
 if command -v nproc > /dev/null 2>&1; then
  local CPU_CORES
  CPU_CORES=$(nproc)
  log_success "Available CPU cores: ${CPU_CORES}"
 else
  log_info "nproc command not available, skipping CPU check"
 fi
}

# Function to show verification summary
__show_verification_summary() {
 echo
 echo "=========================================="
 echo "CI Environment Verification Summary"
 echo "=========================================="
 echo "Total Checks: ${TOTAL_CHECKS}"
 echo "Passed: ${PASSED_CHECKS} ✓"
 echo "Warnings: ${WARNING_CHECKS} ⚠"
 echo "Failed: ${FAILED_CHECKS} ✗"
 echo "=========================================="
 echo

 if [[ ${FAILED_CHECKS} -gt 0 ]]; then
  echo "⚠ VERIFICATION FAILED: ${FAILED_CHECKS} critical check(s) failed"
  echo "Please fix the errors before running tests"
  return 1
 elif [[ ${WARNING_CHECKS} -gt 0 ]]; then
  echo "⚠ VERIFICATION PASSED WITH WARNINGS: ${WARNING_CHECKS} warning(s)"
  echo "Some tests may fail or be skipped"
  return 0
 else
  echo "✓ VERIFICATION PASSED: All checks successful"
  echo "CI environment is ready for testing"
  return 0
 fi
}

# Main function
main() {
 log_info "Starting CI environment verification..."
 log_info "Project Root: ${PROJECT_ROOT}"
 log_info "Script Directory: ${SCRIPT_DIR}"
 echo

 # Execute verification steps
 __verify_directories
 echo
 __verify_environment_variables
 echo
 __verify_required_tools
 echo
 __verify_database_connection
 echo
 __verify_test_files
 echo
 __verify_system_resources
 echo

 # Show summary
 # shellcheck disable=SC2310
 if __show_verification_summary; then
  log_success "CI environment verification completed successfully!"
  return 0
 else
  log_error "CI environment verification failed!"
  return 1
 fi
}

# Run main function
main "$@"
