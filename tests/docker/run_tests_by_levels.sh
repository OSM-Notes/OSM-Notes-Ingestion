#!/bin/bash

# Script to run all tests by levels inside Docker container
# Author: Andres Gomez (AngocA)
# Version: 2025-10-20

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
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

log_level() {
 echo -e "${MAGENTA}[LEVEL]${NC} $1"
}

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DOCKER_COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.ci.yml"

# Test counters by level
declare -A LEVEL_TOTAL
declare -A LEVEL_PASSED
declare -A LEVEL_FAILED

# Initialize counters
for level in 1 2 3 4; do
 LEVEL_TOTAL[$level]=0
 LEVEL_PASSED[$level]=0
 LEVEL_FAILED[$level]=0
done

# Function to check prerequisites
__check_prerequisites() {
 log_info "Checking prerequisites..."

 if ! command -v docker &> /dev/null; then
  log_error "Docker is not installed"
  exit 1
 fi

 if ! docker compose version &> /dev/null; then
  log_error "Docker Compose is not available"
  exit 1
 fi

 log_success "Prerequisites check completed"
}

# Function to start Docker services
__start_docker_services() {
 log_info "Starting Docker services..."

 cd "${SCRIPT_DIR}"
 docker compose -f "${DOCKER_COMPOSE_FILE}" up -d --build

 log_info "Waiting for services to be ready..."
 sleep 15

 # Wait for PostgreSQL
 local -i -r MAX_RETRIES=40
 local -i retry=0

 while [ $retry -lt $MAX_RETRIES ]; do
  if docker compose -f "${DOCKER_COMPOSE_FILE}" exec -T postgres \
   pg_isready -U testuser -d osm_notes_test &> /dev/null; then
   log_success "PostgreSQL is ready"
   return 0
  fi
  retry=$((retry + 1))
  log_info "Waiting for PostgreSQL... (${retry}/${MAX_RETRIES})"
  sleep 2
 done

 log_error "PostgreSQL failed to start"
 return 1
}

# Function to setup test database
__setup_test_database() {
 log_info "Setting up test database..."

 cd "${SCRIPT_DIR}"

 if docker compose -f "${DOCKER_COMPOSE_FILE}" exec -T app \
  bash -c "cd /app/tests/docker && ./setup_test_db_docker.sh"; then
  log_success "Test database setup completed"
  return 0
 else
  log_error "Test database setup failed"
  return 1
 fi
}

# Function to cleanup test database
__cleanup_test_database() {
 log_info "Cleaning up test database..."

 cd "${SCRIPT_DIR}"

 docker compose -f "${DOCKER_COMPOSE_FILE}" exec -T app \
  bash -c "psql -h postgres -U testuser -d postgres -c 'DROP DATABASE IF EXISTS osm_notes_test;'" || true

 log_success "Test database cleaned up"
}

# Function to run Level 1 tests (Unit tests - Bash)
__run_level1_tests() {
 log_level "=========================================="
 log_level "LEVEL 1: Unit Tests - Bash Scripts"
 log_level "=========================================="

 cd "${SCRIPT_DIR}"

 local -a test_files=(
  "tests/unit/bash/functionsProcess.test.bats"
  "tests/unit/bash/processPlanetNotes.test.bats"
  "tests/unit/bash/processAPINotes.test.bats"
  "tests/unit/bash/cleanupAll.test.bats"
  "tests/unit/bash/variable_duplication.test.bats"
  "tests/unit/bash/variable_naming_convention.test.bats"
  "tests/unit/bash/function_naming_convention.test.bats"
  "tests/unit/bash/script_help_validation.test.bats"
  "tests/unit/bash/format_and_lint.test.bats"
 )

 for test_file in "${test_files[@]}"; do
  log_info "Running: $(basename "${test_file}")"

  set +e
  docker compose -f "${DOCKER_COMPOSE_FILE}" exec -T app \
   bash -c "cd /app && bats ${test_file}"
  local exit_code=$?
  set -e

  if [ $exit_code -eq 0 ]; then
   log_success "$(basename "${test_file}") passed"
   LEVEL_PASSED[1]=$((LEVEL_PASSED[1] + 1))
  else
   log_error "$(basename "${test_file}") failed"
   LEVEL_FAILED[1]=$((LEVEL_FAILED[1] + 1))
  fi
  LEVEL_TOTAL[1]=$((LEVEL_TOTAL[1] + 1))
 done

 log_level "Level 1 completed: ${LEVEL_PASSED[1]}/${LEVEL_TOTAL[1]} passed"
}

# Function to run Level 2 tests (Unit tests - SQL)
__run_level2_tests() {
 log_level "=========================================="
 log_level "LEVEL 2: Unit Tests - SQL Scripts"
 log_level "=========================================="

 cd "${SCRIPT_DIR}"

 # Ensure database exists before running SQL tests
 log_info "Verifying database exists for SQL tests..."
 if ! docker compose -f "${DOCKER_COMPOSE_FILE}" exec -T app \
  bash -c "psql -h postgres -U testuser -d osm_notes_test -c 'SELECT 1;' > /dev/null 2>&1"; then
  log_warning "Database not found, recreating..."
  __setup_test_database
 fi

 local -a test_files=(
  "tests/unit/sql/tables_simple.test.sql"
  "tests/unit/sql/functions_simple.test.sql"
 )

 for test_file in "${test_files[@]}"; do
  log_info "Running: $(basename "${test_file}")"

  set +e
  docker compose -f "${DOCKER_COMPOSE_FILE}" exec -T app \
   bash -c "cd /app && psql -h postgres -U testuser -d osm_notes_test \
    -f ${test_file}"
  local exit_code=$?
  set -e

  if [ $exit_code -eq 0 ]; then
   log_success "$(basename "${test_file}") passed"
   LEVEL_PASSED[2]=$((LEVEL_PASSED[2] + 1))
  else
   log_error "$(basename "${test_file}") failed"
   LEVEL_FAILED[2]=$((LEVEL_FAILED[2] + 1))
  fi
  LEVEL_TOTAL[2]=$((LEVEL_TOTAL[2] + 1))
 done

 log_level "Level 2 completed: ${LEVEL_PASSED[2]}/${LEVEL_TOTAL[2]} passed"
}

# Function to run Level 3 tests (Integration tests)
__run_level3_tests() {
 log_level "=========================================="
 log_level "LEVEL 3: Integration Tests"
 log_level "=========================================="

 cd "${SCRIPT_DIR}"

 # Ensure database exists before running integration tests
 log_info "Verifying database exists for integration tests..."
 if ! docker compose -f "${DOCKER_COMPOSE_FILE}" exec -T app \
  bash -c "psql -h postgres -U testuser -d osm_notes_test -c 'SELECT 1;' > /dev/null 2>&1"; then
  log_warning "Database not found, recreating..."
  __setup_test_database
 fi

 local -a test_files=(
  "tests/integration/end_to_end.test.bats"
  "tests/integration/logging_pattern_validation_integration.test.bats"
  "tests/integration/boundary_processing_error_integration.test.bats"
  "tests/integration/processAPINotes_parallel_error_integration.test.bats"
 )

 for test_file in "${test_files[@]}"; do
  if [[ -f "${PROJECT_ROOT}/${test_file}" ]]; then
   log_info "Running: $(basename "${test_file}")"

   set +e
   docker compose -f "${DOCKER_COMPOSE_FILE}" exec -T app \
    bash -c "cd /app && bats ${test_file}"
   local exit_code=$?
   set -e

   if [ $exit_code -eq 0 ]; then
    log_success "$(basename "${test_file}") passed"
    LEVEL_PASSED[3]=$((LEVEL_PASSED[3] + 1))
   else
    log_error "$(basename "${test_file}") failed"
    LEVEL_FAILED[3]=$((LEVEL_FAILED[3] + 1))
   fi
   LEVEL_TOTAL[3]=$((LEVEL_TOTAL[3] + 1))
  else
   log_warning "Test file not found: ${test_file}"
  fi
 done

 log_level "Level 3 completed: ${LEVEL_PASSED[3]}/${LEVEL_TOTAL[3]} passed"
}

# Function to run Level 4 tests (Advanced tests)
__run_level4_tests() {
 log_level "=========================================="
 log_level "LEVEL 4: Advanced Tests (Quality, Coverage)"
 log_level "=========================================="

 cd "${SCRIPT_DIR}"

 # Format and linting
 log_info "Running format and lint checks..."
 set +e
 docker compose -f "${DOCKER_COMPOSE_FILE}" exec -T app \
  bash -c "cd /app && find bin -name '*.sh' -type f -exec shellcheck -x {} \;"
 local exit_code=$?
 set -e

 if [ $exit_code -eq 0 ]; then
  log_success "Shellcheck passed"
  LEVEL_PASSED[4]=$((LEVEL_PASSED[4] + 1))
 else
  log_error "Shellcheck failed"
  LEVEL_FAILED[4]=$((LEVEL_FAILED[4] + 1))
 fi
 LEVEL_TOTAL[4]=$((LEVEL_TOTAL[4] + 1))

 # shfmt check
 log_info "Running shfmt format check..."
 set +e
 docker compose -f "${DOCKER_COMPOSE_FILE}" exec -T app \
  bash -c "cd /app && find bin -name '*.sh' -type f -exec shfmt -d -i 1 -sr -bn {} \;"
 exit_code=$?
 set -e

 if [ $exit_code -eq 0 ]; then
  log_success "shfmt check passed"
  LEVEL_PASSED[4]=$((LEVEL_PASSED[4] + 1))
 else
  log_error "shfmt check failed"
  LEVEL_FAILED[4]=$((LEVEL_FAILED[4] + 1))
 fi
 LEVEL_TOTAL[4]=$((LEVEL_TOTAL[4] + 1))

 log_level "Level 4 completed: ${LEVEL_PASSED[4]}/${LEVEL_TOTAL[4]} passed"
}

# Function to print summary
__print_summary() {
 echo
 echo "=========================================="
 echo "TEST EXECUTION SUMMARY BY LEVELS"
 echo "=========================================="
 echo

 local -i total_all=0
 local -i passed_all=0
 local -i failed_all=0

 for level in 1 2 3 4; do
  local total="${LEVEL_TOTAL[$level]}"
  local passed="${LEVEL_PASSED[$level]}"
  local failed="${LEVEL_FAILED[$level]}"

  if [ "$total" -gt 0 ]; then
   local percentage=$((passed * 100 / total))
   echo "Level ${level}:"
   echo "  Total:  ${total}"
   echo "  Passed: ${passed} ✅"
   echo "  Failed: ${failed} ❌"
   echo "  Rate:   ${percentage}%"
   echo
  fi

  total_all=$((total_all + total))
  passed_all=$((passed_all + passed))
  failed_all=$((failed_all + failed))
 done

 echo "=========================================="
 echo "OVERALL SUMMARY:"
 echo "=========================================="
 echo "Total Tests:  ${total_all}"
 echo "Passed:       ${passed_all} ✅"
 echo "Failed:       ${failed_all} ❌"

 if [ "$total_all" -gt 0 ]; then
  local percentage=$((passed_all * 100 / total_all))
  echo "Success Rate: ${percentage}%"
 fi
 echo "=========================================="
 echo

 if [ "$failed_all" -eq 0 ]; then
  log_success "All tests passed! 🎉"
  return 0
 else
  log_error "Some tests failed! ❌"
  return 1
 fi
}

# Function to stop Docker services
__stop_docker_services() {
 log_info "Stopping Docker services..."

 cd "${SCRIPT_DIR}"
 docker compose -f "${DOCKER_COMPOSE_FILE}" down --volumes --remove-orphans

 log_success "Docker services stopped"
}

# Function to show logs
__show_logs() {
 log_info "Showing Docker logs..."

 cd "${SCRIPT_DIR}"
 docker compose -f "${DOCKER_COMPOSE_FILE}" logs --tail=100
}

# Function to show help
__show_help() {
 cat << EOF
Usage: $0 [OPTIONS]

Run all tests by levels inside Docker container

Options:
  --help, -h          Show this help message
  --level1            Run only Level 1 tests (Unit tests - Bash)
  --level2            Run only Level 2 tests (Unit tests - SQL)
  --level3            Run only Level 3 tests (Integration)
  --level4            Run only Level 4 tests (Advanced)
  --logs              Show Docker logs after tests
  --no-cleanup        Don't cleanup Docker services after tests

Levels:
  Level 1: Unit Tests - Bash Scripts
  Level 2: Unit Tests - SQL Scripts
  Level 3: Integration Tests
  Level 4: Advanced Tests (Quality, Coverage)

Examples:
  $0                  # Run all levels
  $0 --level1         # Run only Level 1
  $0 --logs           # Run all and show logs
  $0 --no-cleanup     # Run all without cleanup

EOF
}

# Main function
main() {
 local run_level1=false
 local run_level2=false
 local run_level3=false
 local run_level4=false
 local show_logs=false
 local no_cleanup=false
 local run_all=true

 # Parse arguments
 while [[ $# -gt 0 ]]; do
  case $1 in
  --help | -h)
   __show_help
   exit 0
   ;;
  --level1)
   run_level1=true
   run_all=false
   shift
   ;;
  --level2)
   run_level2=true
   run_all=false
   shift
   ;;
  --level3)
   run_level3=true
   run_all=false
   shift
   ;;
  --level4)
   run_level4=true
   run_all=false
   shift
   ;;
  --logs)
   show_logs=true
   shift
   ;;
  --no-cleanup)
   no_cleanup=true
   shift
   ;;
  *)
   log_error "Unknown option: $1"
   __show_help
   exit 1
   ;;
  esac
 done

 # Setup trap for cleanup - will be handled at the end
 # We don't use EXIT trap to avoid stopping services prematurely

 # Check prerequisites
 __check_prerequisites

 # Start Docker services
 if ! __start_docker_services; then
  log_error "Failed to start Docker services"
  exit 1
 fi

 # Setup test database
 if ! __setup_test_database; then
  log_error "Failed to setup test database"
  exit 1
 fi

 # Run tests based on options
 if [ "$run_all" = true ]; then
  __run_level1_tests
  __run_level2_tests
  __run_level3_tests
  __run_level4_tests
 else
  [ "$run_level1" = true ] && __run_level1_tests
  [ "$run_level2" = true ] && __run_level2_tests
  [ "$run_level3" = true ] && __run_level3_tests
  [ "$run_level4" = true ] && __run_level4_tests
 fi

 # Show logs if requested
 if [ "$show_logs" = true ]; then
  __show_logs
 fi

 # Cleanup test database if not keeping services
 if [ "$no_cleanup" = false ]; then
  __cleanup_test_database
 fi

 # Stop Docker services if cleanup is enabled
 if [ "$no_cleanup" = false ]; then
  __stop_docker_services
 fi

 # Print summary and exit
 __print_summary
 local exit_code=$?

 exit $exit_code
}

# Run main function
main "$@"
