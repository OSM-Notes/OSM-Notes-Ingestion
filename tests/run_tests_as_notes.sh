#!/bin/bash

# Run tests as notes user
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

# Setup test environment
log_info "Setting up test environment for current user..."

# Create temporary directory for current user
TEST_DIR="${HOME}/tmp/notes_test"
mkdir -p "${TEST_DIR}"
chmod 755 "${TEST_DIR}"

# Clean up any existing lock files
rm -f /tmp/ETL.lock
rm -f /tmp/ETL_recovery.json

# Setup database
log_info "Setting up test database..."
"${SCRIPT_DIR}/setup_test_db.sh"

# Function to run tests as current user
run_tests_as_current_user() {
 local test_files="${1:-}"
 
 log_info "Running tests as current user..."
 
 # Export environment variables for current user
 export TEST_TMP_DIR="${TEST_DIR}"
 export TMPDIR="${TEST_DIR}"
 
 # Run tests with proper environment
 bash -c "
  cd '${PROJECT_ROOT}'
  source tests/properties.sh
  export TEST_TMP_DIR='${TEST_TMP_DIR}'
  export TMPDIR='${TMPDIR}'
  bats ${test_files}
 "
}

# Main execution
case "${1:-}" in
 --unit)
  log_info "Running unit tests..."
  run_tests_as_current_user "tests/unit/bash/"
  ;;
 --integration)
  log_info "Running integration tests..."
  run_tests_as_current_user "tests/integration/"
  ;;
 --etl)
  log_info "Running ETL tests..."
  run_tests_as_current_user "tests/unit/bash/ETL_enhanced.test.bats tests/integration/ETL_enhanced_integration.test.bats"
  ;;
 --all)
  log_info "Running all tests..."
  run_tests_as_current_user "tests/unit/bash/ tests/integration/"
  ;;
 --help | -h)
  echo "Usage: $0 [OPTIONS]"
  echo
  echo "Options:"
  echo "  --unit         Run unit tests only"
  echo "  --integration  Run integration tests only"
  echo "  --etl          Run ETL tests only"
  echo "  --all          Run all tests"
  echo "  --help, -h     Show this help"
  exit 0
  ;;
 "")
  log_info "Running all tests..."
  run_tests_as_current_user "tests/unit/bash/ tests/integration/"
  ;;
 *)
  log_error "Unknown option: $1"
  log_error "Use --help for usage information"
  exit 1
  ;;
esac

log_success "Tests completed"