#!/bin/bash

# Test script for GitHub Actions workflow
# This script simulates the steps that GitHub Actions would perform
# to verify that no warnings are generated
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-30

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Test directories
readonly TEST_DIRS=(
 "tests/results"
 "tests/docker/logs"
 ".benchmarks"
 "advanced_reports"
 "coverage"
 "security_reports"
)

# Test files
readonly TEST_FILES=(
 "tests/results/test-summary.log"
 "tests/docker/logs/integration-tests.log"
 ".benchmarks/benchmark-info.log"
 ".benchmarks/performance.log"
 "advanced_reports/advanced-tests.log"
 "coverage/coverage.txt"
 "security_reports/security.txt"
 "shellcheck-results.txt"
)

# Function to log messages
log_info() {
 echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
 echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
 echo -e "${RED}[ERROR]${NC} $1"
}

# Function to create test directories
create_test_directories() {
 log_info "Creating test directories..."

 for DIR in "${TEST_DIRS[@]}"; do
  if mkdir -p "${DIR}"; then
   log_info "Created directory: ${DIR}"
  else
   log_error "Failed to create directory: ${DIR}"
   return 1
  fi
 done
}

# Function to create test files
create_test_files() {
 log_info "Creating test files..."

 for FILE in "${TEST_FILES[@]}"; do
  local DIR
  DIR=$(dirname "${FILE}")

  # Ensure directory exists
  mkdir -p "${DIR}"

  # Create test content
  case "${FILE}" in
  "tests/results/test-summary.log")
   echo "Test results directory created" > "${FILE}"
   ;;
  "tests/docker/logs/integration-tests.log")
   echo "Integration tests started" > "${FILE}"
   echo "Running basic integration tests..." >> "${FILE}"
   echo "Integration tests completed" >> "${FILE}"
   ;;
  ".benchmarks/benchmark-info.log")
   echo "Benchmarks directory created" > "${FILE}"
   ;;
  ".benchmarks/performance.log")
   echo "Running simple performance test..." > "${FILE}"
   echo "Performance test completed successfully" >> "${FILE}"
   echo "Benchmark results saved" >> "${FILE}"
   ;;
  "advanced_reports/advanced-tests.log")
   echo "Running advanced tests..." > "${FILE}"
   echo "Advanced tests completed successfully" >> "${FILE}"
   ;;
  "coverage/coverage.txt")
   echo "Coverage: 85%" > "${FILE}"
   ;;
  "security_reports/security.txt")
   echo "Security scan passed" > "${FILE}"
   ;;
  "shellcheck-results.txt")
   echo "ShellCheck completed successfully" > "${FILE}"
   ;;
  *)
   echo "Test file content" > "${FILE}"
   ;;
  esac

  log_info "Created file: ${FILE}"
 done
}

# Function to verify files exist
verify_files_exist() {
 log_info "Verifying test files exist..."

 local MISSING_FILES=()

 for FILE in "${TEST_FILES[@]}"; do
  if [[ -f "${FILE}" ]]; then
   log_info "File exists: ${FILE}"
  else
   MISSING_FILES+=("${FILE}")
   log_error "File missing: ${FILE}"
  fi
 done

 if [[ ${#MISSING_FILES[@]} -gt 0 ]]; then
  log_error "Missing files: ${MISSING_FILES[*]}"
  return 1
 fi

 log_info "All test files exist"
 return 0
}

# Function to simulate GitHub Actions upload
simulate_upload() {
 log_info "Simulating GitHub Actions upload..."

 local UPLOAD_DIRS=(
  "tests/results/"
  "tests/docker/logs/"
  ".benchmarks/"
  "advanced_reports/"
  "coverage/"
  "security_reports/"
 )

 for DIR in "${UPLOAD_DIRS[@]}"; do
  if [[ -d "${DIR}" ]]; then
   local FILE_COUNT
   FILE_COUNT=$(find "${DIR}" -type f | wc -l)
   log_info "Directory ${DIR} has ${FILE_COUNT} files"
  else
   log_warning "Directory ${DIR} does not exist"
  fi
 done
}

# Function to clean up test files
cleanup() {
 log_info "Cleaning up test files..."

 for DIR in "${TEST_DIRS[@]}"; do
  if [[ -d "${DIR}" ]]; then
   rm -rf "${DIR}"
   log_info "Removed directory: ${DIR}"
  fi
 done

 if [[ -f "shellcheck-results.txt" ]]; then
  rm -f "shellcheck-results.txt"
  log_info "Removed file: shellcheck-results.txt"
 fi
}

# Main function
main() {
 log_info "Starting GitHub Actions workflow test..."

 # Create test directories and files
 create_test_directories
 create_test_files

 # Verify files exist
 if verify_files_exist; then
  log_info "All files created successfully"
 else
  log_error "Some files are missing"
  cleanup
  exit 1
 fi

 # Simulate upload
 simulate_upload

 log_info "GitHub Actions workflow test completed successfully"

 # Clean up
 cleanup

 log_info "Test completed successfully"
}

# Run main function
main "$@"
