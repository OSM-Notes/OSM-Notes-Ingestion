#!/bin/bash

# Master Test Runner for OSM-Notes-profile (Consolidated)
# Author: Andres Gomez (AngocA)
# Version: 2025-08-08

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

# Test counters
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0

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

# Show help
show_help() {
 cat << EOF
Master Test Runner for OSM-Notes-profile

Usage: $0 [OPTIONS] [TEST_TYPE]

Options:
  -h, --help              Show this help message
  --mode MODE             Test mode (host|mock|docker|ci)
  --type TYPE             Test type (all|unit|integration|quality|dwh)

Modes:
  host                    Run tests on host system (default)
  mock                    Run tests with mock environment
  docker                  Run tests in Docker environment
  ci                      Run tests in CI/CD environment

Test Types:
  all                     Run all test suites (default)
  unit                    Run only unit tests
  integration             Run only integration tests
  quality                 Run only quality tests
  dwh                     Run only DWH enhanced tests

Examples:
  $0 --mode host --type all                    # Run all tests on host
  $0 --mode mock --type unit                   # Run unit tests with mock
  $0 --mode docker --type integration          # Run integration tests in Docker
  $0 --mode ci --type all                      # Run all tests in CI
  $0 --mode host --type dwh                    # Run DWH enhanced tests
  $0                                         # Run all tests on host (default)

EOF
}

# Check prerequisites
check_prerequisites() {
 log_info "Checking prerequisites..."

 # Check if BATS is installed
 if ! command -v bats &> /dev/null; then
  log_error "BATS is not installed. Please install it first:"
  log_error "  sudo apt-get install bats"
  exit 1
 fi

 log_success "Prerequisites check completed"
}

# Run tests on host system
run_host_tests() {
 local test_type="$1"

 log_info "Running tests on host system..."

 case "$test_type" in
 "all")
  bats tests/unit/bash/*.bats tests/integration/*.bats tests/unit/sql/*.sql
  ;;
 "unit")
  log_info "Running unit tests..."
  # Core functionality tests (run first for early failure detection)
  log_info "Running comprehensive parallel processing test suite..."
  bats tests/parallel_processing_test_suite.bats

  log_info "Running parallel processing robust tests..."
  bats tests/unit/bash/parallel_processing_robust.test.bats
  log_info "Running parallel delay tests..."
  bats tests/unit/bash/parallel_delay_test.bats
  # All other unit tests
  log_info "Running remaining unit tests..."
  bats tests/unit/bash/*.bats
  ;;
 "integration")
  log_info "Running integration tests..."
  # Parallel processing integration tests (run first)
  log_info "Running parallel processing integration tests..."
  bats tests/integration/processAPINotes_parallel_error_integration.test.bats
  # All other integration tests
  log_info "Running remaining integration tests..."
  bats tests/integration/*.bats
  ;;
 "quality")
  bats tests/advanced/quality/*.bats
  ;;
 "dwh")
  log_info "Running DWH enhanced tests..."
  # Run SQL unit tests for DWH
  if command -v psql &> /dev/null; then
   log_info "Running DWH SQL unit tests..."
   psql -d "${DBNAME:-notes}" -f tests/unit/sql/dwh_dimensions_enhanced.test.sql
   psql -d "${DBNAME:-notes}" -f tests/unit/sql/dwh_functions_enhanced.test.sql
  else
   log_warning "psql not found, skipping DWH SQL tests"
  fi
  # Run DWH integration tests
  bats tests/integration/ETL_enhanced_integration.test.bats
  bats tests/integration/datamart_enhanced_integration.test.bats
  ;;
 *)
  log_error "Unknown test type: $test_type"
  show_help
  exit 1
  ;;
 esac
}

# Run tests with mock environment
run_mock_tests() {
 local test_type="$1"

 log_info "Setting up mock environment..."

 # Setup mock environment
 if [[ -f "${SCRIPT_DIR}/setup_mock_environment.sh" ]]; then
  source "${SCRIPT_DIR}/setup_mock_environment.sh"
 fi

 # Export mock environment variables
 export MOCK_MODE=true
 export TEST_MODE=true
 export LOG_LEVEL="INFO"
 export TEST_TMP_DIR="/tmp/mock_test"
 export TMPDIR="/tmp/mock_test"
 export SCRIPT_BASE_DIRECTORY="${PROJECT_ROOT}"
 export DBNAME="mock_db"
 export DB_USER="mock_user"

 # Create temporary directory
 mkdir -p "${TEST_TMP_DIR}"

 log_info "Running tests with mock environment..."

 case "$test_type" in
 "all")
  bats tests/unit/bash/*.bats tests/integration/*.bats
  ;;
 "unit")
  bats tests/unit/bash/*.bats
  ;;
 "integration")
  bats tests/integration/*.bats
  ;;
 "quality")
  bats tests/unit/bash/format_and_lint.test.bats
  bats tests/unit/bash/function_naming_convention.test.bats
  bats tests/unit/bash/variable_naming_convention.test.bats
  bats tests/unit/bash/variable_duplication.test.bats
  bats tests/unit/bash/variable_duplication_detection.test.bats
  bats tests/unit/bash/script_help_validation.test.bats
  ;;
 *)
  log_error "Unknown test type: $test_type"
  exit 1
  ;;
 esac
}

# Run tests in Docker environment
run_docker_tests() {
 local test_type="$1"

 log_info "Running tests in Docker environment..."

 cd "${SCRIPT_DIR}/docker"

 # Check if Docker is available
 if ! command -v docker &> /dev/null; then
  log_error "Docker is not installed"
  exit 1
 fi

 # Start Docker services
 if docker compose up -d --build; then
  log_success "Docker services started"
 else
  log_error "Failed to start Docker services"
  exit 1
 fi

 # Wait for PostgreSQL
 if docker compose exec -T app bash -c "cd /app/tests/docker && ./wait_for_postgres.sh"; then
  log_success "PostgreSQL is ready"
 else
  log_error "PostgreSQL failed to start"
  exit 1
 fi

 # Setup test database
 if docker compose exec -T app bash -c "cd /app/tests/docker && ./setup_test_db_docker.sh"; then
  log_success "Test database setup completed"
 else
  log_error "Test database setup failed"
  exit 1
 fi

 # Run tests
 case "$test_type" in
 "all")
  docker compose exec -T app bash -c "cd /app/tests && bats unit/bash/*.bats integration/*.bats"
  ;;
 "unit")
  docker compose exec -T app bash -c "cd /app/tests && bats unit/bash/*.bats"
  ;;
 "integration")
  docker compose exec -T app bash -c "cd /app/tests && bats integration/*.bats"
  ;;
 "quality")
  docker compose exec -T app bash -c "cd /app/tests && bats unit/bash/format_and_lint.test.bats"
  docker compose exec -T app bash -c "cd /app/tests && bats unit/bash/function_naming_convention.test.bats"
  docker compose exec -T app bash -c "cd /app/tests && bats unit/bash/variable_naming_convention.test.bats"
  docker compose exec -T app bash -c "cd /app/tests && bats unit/bash/variable_duplication.test.bats"
  docker compose exec -T app bash -c "cd /app/tests && bats unit/bash/variable_duplication_detection.test.bats"
  docker compose exec -T app bash -c "cd /app/tests && bats unit/bash/script_help_validation.test.bats"
  ;;
 *)
  log_error "Unknown test type: $test_type"
  exit 1
  ;;
 esac

 # Cleanup
 docker compose down
}

# Run tests in CI environment
run_ci_tests() {
 local test_type="$1"

 log_info "Running tests in CI environment..."

 cd "${SCRIPT_DIR}/docker"

 # Use CI-specific docker-compose file
 local docker_compose_file="docker-compose.ci.yml"

 # Start CI services
 if docker compose -f "${docker_compose_file}" up -d --build; then
  log_success "CI services started"
 else
  log_error "Failed to start CI services"
  exit 1
 fi

 # Wait for PostgreSQL in CI
 if docker compose -f "${docker_compose_file}" exec -T app bash -c "cd /app/tests/docker && ./wait_for_postgres.sh"; then
  log_success "PostgreSQL is ready in CI"
 else
  log_error "PostgreSQL failed to start in CI"
  exit 1
 fi

 # Setup test database for CI
 if docker compose -f "${docker_compose_file}" exec -T app bash -c "cd /app/tests/docker && ./setup_test_db_docker.sh"; then
  log_success "CI test database setup completed"
 else
  log_error "CI test database setup failed"
  exit 1
 fi

 # Run tests with CI timeout
 case "$test_type" in
 "all")
  timeout 600s docker compose -f "${docker_compose_file}" exec -T app bash -c "cd /app/tests && bats unit/bash/*.bats integration/*.bats"
  ;;
 "unit")
  timeout 600s docker compose -f "${docker_compose_file}" exec -T app bash -c "cd /app/tests && bats unit/bash/*.bats"
  ;;
 "integration")
  timeout 600s docker compose -f "${docker_compose_file}" exec -T app bash -c "cd /app/tests && bats integration/*.bats"
  ;;
 "quality")
  timeout 600s docker compose -f "${docker_compose_file}" exec -T app bash -c "cd /app/tests && bats unit/bash/format_and_lint.test.bats"
  timeout 600s docker compose -f "${docker_compose_file}" exec -T app bash -c "cd /app/tests && bats unit/bash/function_naming_convention.test.bats"
  timeout 600s docker compose -f "${docker_compose_file}" exec -T app bash -c "cd /app/tests && bats unit/bash/variable_naming_convention.test.bats"
  timeout 600s docker compose -f "${docker_compose_file}" exec -T app bash -c "cd /app/tests && bats unit/bash/variable_duplication.test.bats"
  timeout 600s docker compose -f "${docker_compose_file}" exec -T app bash -c "cd /app/tests && bats unit/bash/variable_duplication_detection.test.bats"
  timeout 600s docker compose -f "${docker_compose_file}" exec -T app bash -c "cd /app/tests && bats unit/bash/script_help_validation.test.bats"
  ;;
 *)
  log_error "Unknown test type: $test_type"
  exit 1
  ;;
 esac

 # Cleanup
 docker compose -f "${docker_compose_file}" down
}

# Main execution
main() {
 local mode="host"
 local test_type="all"

 # Parse command line arguments
 while [[ $# -gt 0 ]]; do
  case $1 in
  -h | --help)
   show_help
   exit 0
   ;;
  --mode)
   mode="$2"
   shift 2
   ;;
  --type)
   test_type="$2"
   shift 2
   ;;
  *)
   log_error "Unknown option: $1"
   show_help
   exit 1
   ;;
  esac
 done

 # Check prerequisites
 check_prerequisites

 # Run tests based on mode
 case "$mode" in
 "host")
  run_host_tests "$test_type"
  ;;
 "mock")
  run_mock_tests "$test_type"
  ;;
 "docker")
  run_docker_tests "$test_type"
  ;;
 "ci")
  run_ci_tests "$test_type"
  ;;
 *)
  log_error "Unknown mode: $mode"
  show_help
  exit 1
  ;;
 esac

 log_success "All tests completed successfully!"
}

# Run main function
main "$@"
