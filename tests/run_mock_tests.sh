#!/bin/bash

# Run mock tests that don't require real database
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

# Setup mock environment
log_info "Setting up mock test environment..."

# Source mock logger
source "${SCRIPT_DIR}/mock_logger.sh"

# Export mock environment variables
export MOCK_MODE=true
export TEST_MODE=true
export LOG_LEVEL="INFO"

# Function to run mock tests
run_mock_tests() {
 local test_files="${1:-}"
 
 log_info "Running mock tests..."
 
 # Export environment variables for mock tests
 export TEST_TMP_DIR="/tmp/mock_test"
 export TMPDIR="/tmp/mock_test"
 export SCRIPT_BASE_DIRECTORY="${PROJECT_ROOT}"
 export DBNAME="mock_db"
 export DB_USER="mock_user"
 
 # Create temporary directory
 mkdir -p "${TEST_TMP_DIR}"
 
 # Run tests with mock environment
 if [[ -d "${test_files}" ]]; then
  bats "${test_files}"/*.bats
 else
  bats ${test_files}
 fi
}

# Main execution
case "${1:-}" in
 --unit)
  log_info "Running unit tests with mock environment..."
  run_mock_tests "${PROJECT_ROOT}/tests/unit/bash"
  ;;
 --integration)
  log_info "Running integration tests with mock environment..."
  run_mock_tests "${PROJECT_ROOT}/tests/integration"
  ;;
 --etl)
  log_info "Running ETL tests with mock environment..."
  run_mock_tests "${PROJECT_ROOT}/tests/unit/bash/ETL_enhanced.test.bats ${PROJECT_ROOT}/tests/integration/ETL_enhanced_integration.test.bats"
  ;;
 --all)
  log_info "Running all tests with mock environment..."
  run_mock_tests "${PROJECT_ROOT}/tests/unit/bash ${PROJECT_ROOT}/tests/integration"
  ;;
 --help | -h)
  echo "Usage: $0 [OPTIONS]"
  echo
  echo "Options:"
  echo "  --unit         Run unit tests only (mock mode)"
  echo "  --integration  Run integration tests only (mock mode)"
  echo "  --etl          Run ETL tests only (mock mode)"
  echo "  --all          Run all tests (mock mode)"
  echo "  --help, -h     Show this help"
  exit 0
  ;;
 "")
  log_info "Running all tests with mock environment..."
  run_mock_tests "${PROJECT_ROOT}/tests/unit/bash ${PROJECT_ROOT}/tests/integration"
  ;;
 *)
  log_error "Unknown option: $1"
  log_error "Use --help for usage information"
  exit 1
  ;;
esac

log_success "Mock tests completed"