#!/bin/bash
#
# CI/CD Test Runner for OSM-Notes-profile
# Optimized for GitHub Actions
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-26

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
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DOCKER_COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.ci.yml"

# CI/CD specific settings
CI_TIMEOUT=600  # 10 minutes for CI
CI_MAX_RETRIES=20

# Function to check prerequisites
check_prerequisites() {
    log_info "Checking CI/CD prerequisites..."

    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not available in CI environment"
        exit 1
    fi

    # Check if Docker Compose is available
    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not available in CI environment"
        exit 1
    fi

    log_success "CI/CD prerequisites check completed"
}

# Function to start CI services
start_ci_services() {
    log_info "Starting CI/CD services..."

    cd "${SCRIPT_DIR}"

    # Build and start containers with CI configuration
    docker compose -f "${DOCKER_COMPOSE_FILE}" up -d --build

    log_success "CI/CD services started"
}

# Function to wait for PostgreSQL in CI
wait_for_postgres_ci() {
    log_info "Waiting for PostgreSQL in CI environment..."

    cd "${SCRIPT_DIR}"

    # Wait for PostgreSQL to be ready using the wait script
    if docker compose -f "${DOCKER_COMPOSE_FILE}" exec -T app bash -c "cd /app/tests/docker && ./wait_for_postgres.sh"; then
        log_success "PostgreSQL is ready in CI environment"
        return 0
    else
        log_error "PostgreSQL failed to start in CI environment"
        return 1
    fi
}

# Function to run CI tests
run_ci_tests() {
    log_info "Running CI/CD tests..."

    cd "${SCRIPT_DIR}"

    # Run basic functionality tests
    log_info "Running basic functionality tests..."
    if docker compose -f "${DOCKER_COMPOSE_FILE}" exec -T app bash -c "cd /app && bash tests/run_tests_simple.sh"; then
        log_success "Basic functionality tests passed"
    else
        log_error "Basic functionality tests failed"
        return 1
    fi

    # Run enhanced tests
    log_info "Running enhanced tests..."
    if docker compose -f "${DOCKER_COMPOSE_FILE}" exec -T app bash -c "cd /app && bash tests/run_enhanced_tests.sh"; then
        log_success "Enhanced tests passed"
    else
        log_error "Enhanced tests failed"
        return 1
    fi

    # Run unit tests
    log_info "Running unit tests..."
    if docker compose -f "${DOCKER_COMPOSE_FILE}" exec -T app bash -c "cd /app && bats tests/unit/bash/"; then
        log_success "Unit tests passed"
    else
        log_error "Unit tests failed"
        return 1
    fi

    log_success "All CI/CD tests passed"
    return 0
}

# Function to run database tests
run_database_tests() {
    log_info "Running database tests..."

    cd "${SCRIPT_DIR}"

    # Test database connection
    if docker compose -f "${DOCKER_COMPOSE_FILE}" exec -T app bash -c "cd /app && bash tests/docker/test_db_connection.sh"; then
        log_success "Database connection test passed"
    else
        log_error "Database connection test failed"
        return 1
    fi

    # Test API processing
    if docker compose -f "${DOCKER_COMPOSE_FILE}" exec -T app bash -c "cd /app && bash tests/docker/test_processAPINotes.sh"; then
        log_success "API processing test passed"
    else
        log_error "API processing test failed"
        return 1
    fi

    # Test Planet processing
    if docker compose -f "${DOCKER_COMPOSE_FILE}" exec -T app bash -c "cd /app && bash tests/docker/test_processPlanetNotes.sh"; then
        log_success "Planet processing test passed"
    else
        log_error "Planet processing test failed"
        return 1
    fi

    log_success "All database tests passed"
    return 0
}

# Function to show CI logs
show_ci_logs() {
    log_info "Showing CI/CD service logs..."

    cd "${SCRIPT_DIR}"
    docker compose -f "${DOCKER_COMPOSE_FILE}" logs
}

# Function to stop CI services
stop_ci_services() {
    log_info "Stopping CI/CD services..."

    cd "${SCRIPT_DIR}"
    docker compose -f "${DOCKER_COMPOSE_FILE}" down --volumes --remove-orphans

    log_success "CI/CD services stopped"
}

# Function to cleanup CI environment
cleanup_ci() {
    log_info "Cleaning up CI/CD environment..."

    # Stop services
    stop_ci_services

    # Remove CI artifacts
    rm -rf "${PROJECT_ROOT}/tests/results" 2> /dev/null || true
    rm -rf "${PROJECT_ROOT}/.benchmarks" 2> /dev/null || true

    log_success "CI/CD cleanup completed"
}

# Function to show help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "CI/CD Test Runner for OSM-Notes-profile"
    echo
    echo "Options:"
    echo "  --help, -h          Show this help message"
    echo "  --start-only        Only start CI services"
    echo "  --stop-only         Only stop CI services"
    echo "  --logs              Show CI service logs"
    echo "  --cleanup           Clean up all CI resources"
    echo "  --db-tests-only     Run only database tests"
    echo "  --basic-tests-only  Run only basic functionality tests"
    echo
    echo "Environment variables:"
    echo "  CI_TIMEOUT          Test timeout in seconds (default: 600)"
    echo "  CI_MAX_RETRIES      Maximum retries for service startup (default: 20)"
}

# Main function
main() {
    local start_only=false
    local stop_only=false
    local show_logs=false
    local cleanup_only=false
    local db_tests_only=false
    local basic_tests_only=false

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help | -h)
                show_help
                exit 0
                ;;
            --start-only)
                start_only=true
                shift
                ;;
            --stop-only)
                stop_only=true
                shift
                ;;
            --logs)
                show_logs=true
                shift
                ;;
            --cleanup)
                cleanup_only=true
                shift
                ;;
            --db-tests-only)
                db_tests_only=true
                shift
                ;;
            --basic-tests-only)
                basic_tests_only=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Set trap for cleanup
    trap cleanup_ci EXIT

    # Check prerequisites
    check_prerequisites

    if [ "$cleanup_only" = true ]; then
        cleanup_ci
        exit 0
    fi

    if [ "$stop_only" = true ]; then
        stop_ci_services
        exit 0
    fi

    if [ "$show_logs" = true ]; then
        show_ci_logs
        exit 0
    fi

    # Start services
    start_ci_services

    if [ "$start_only" = true ]; then
        log_info "CI/CD services started. Use --stop-only to stop them."
        exit 0
    fi

    # Wait for PostgreSQL
    if ! wait_for_postgres_ci; then
        log_error "Failed to start PostgreSQL in CI environment"
        show_ci_logs
        exit 1
    fi

    # Run tests based on options
    local test_result=0

    if [ "$db_tests_only" = true ]; then
        run_database_tests || test_result=1
    elif [ "$basic_tests_only" = true ]; then
        run_ci_tests || test_result=1
    else
        # Run all tests
        run_ci_tests || test_result=1
        run_database_tests || test_result=1
    fi

    # Show logs if tests failed
    if [ $test_result -ne 0 ]; then
        log_warning "Some CI/CD tests failed. Showing logs..."
        show_ci_logs
    fi

    exit $test_result
}

# Run main function
main "$@" 