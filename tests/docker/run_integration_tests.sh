#!/bin/bash

# Integration Tests Runner for Docker Environment
# Author: Andres Gomez (AngocA)
# Version: 2025-07-20

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
DOCKER_COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"

# Test configuration
TEST_TIMEOUT=300  # 5 minutes
MAX_RETRIES=3

# Function to check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi
    
    # Check if Docker Compose is installed
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose is not installed"
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        # Try with sudo
        if sudo docker info &> /dev/null; then
            log_warning "Docker requires sudo access"
            DOCKER_CMD="sudo docker"
            DOCKER_COMPOSE_CMD="sudo docker-compose"
        else
            log_error "Docker daemon is not running"
            exit 1
        fi
    else
        DOCKER_CMD="docker"
        DOCKER_COMPOSE_CMD="docker-compose"
    fi
    
    log_success "Prerequisites check completed"
}

# Function to start services
start_services() {
    log_info "Starting Docker services..."
    
    cd "${SCRIPT_DIR}"
    
    # Build and start containers
    ${DOCKER_COMPOSE_CMD} up -d --build
    
    # Wait for PostgreSQL to be ready
    log_info "Waiting for PostgreSQL to be ready..."
    local retries=0
    while [ $retries -lt $MAX_RETRIES ]; do
        if ${DOCKER_COMPOSE_CMD} exec -T postgres pg_isready -U testuser -d osm_notes_test; then
            log_success "PostgreSQL is ready"
            break
        else
            retries=$((retries + 1))
            log_warning "PostgreSQL not ready, retrying... ($retries/$MAX_RETRIES)"
            sleep 10
        fi
    done
    
    if [ $retries -eq $MAX_RETRIES ]; then
        log_error "PostgreSQL failed to start"
        exit 1
    fi
    
    # Wait for mock API to be ready
    log_info "Waiting for mock API to be ready..."
    retries=0
    while [ $retries -lt $MAX_RETRIES ]; do
        if curl -s http://localhost:8001/api/0.6/notes &> /dev/null; then
            log_success "Mock API is ready"
            break
        else
            retries=$((retries + 1))
            log_warning "Mock API not ready, retrying... ($retries/$MAX_RETRIES)"
            sleep 5
        fi
    done
    
    if [ $retries -eq $MAX_RETRIES ]; then
        log_error "Mock API failed to start"
        exit 1
    fi
}

# Function to run integration tests
run_integration_tests() {
    log_info "Running integration tests..."
    
    cd "${SCRIPT_DIR}"
    
    # Run tests in the app container
    if ${DOCKER_COMPOSE_CMD} exec -T app bash -c "cd /app && ./tests/run_tests.sh --integration-only"; then
        log_success "Integration tests passed"
        return 0
    else
        log_error "Integration tests failed"
        return 1
    fi
}

# Function to run end-to-end tests
run_e2e_tests() {
    log_info "Running end-to-end tests..."
    
    cd "${SCRIPT_DIR}"
    
    # Run end-to-end tests
    if ${DOCKER_COMPOSE_CMD} exec -T app bash -c "cd /app && bats tests/integration/end_to_end.test.bats"; then
        log_success "End-to-end tests passed"
        return 0
    else
        log_error "End-to-end tests failed"
        return 1
    fi
}

# Function to run performance tests
run_performance_tests() {
    log_info "Running performance tests..."
    
    cd "${SCRIPT_DIR}"
    
    # Run performance tests
    if ${DOCKER_COMPOSE_CMD} exec -T app bash -c "cd /app && python3 -m pytest tests/performance/ -v"; then
        log_success "Performance tests passed"
        return 0
    else
        log_error "Performance tests failed"
        return 1
    fi
}

# Function to stop services
stop_services() {
    log_info "Stopping Docker services..."
    
    cd "${SCRIPT_DIR}"
    ${DOCKER_COMPOSE_CMD} down --volumes --remove-orphans
    
    log_success "Services stopped"
}

# Function to show logs
show_logs() {
    log_info "Showing service logs..."
    
    cd "${SCRIPT_DIR}"
    ${DOCKER_COMPOSE_CMD} logs
}

# Function to cleanup
cleanup() {
    log_info "Cleaning up..."
    
    # Stop services
    stop_services
    
    # Remove test artifacts
    rm -rf "${PROJECT_ROOT}/tests/results" 2>/dev/null || true
    rm -rf "${PROJECT_ROOT}/.benchmarks" 2>/dev/null || true
    
    log_success "Cleanup completed"
}

# Function to show help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --help, -h          Show this help message"
    echo "  --start-only        Only start services"
    echo "  --stop-only         Only stop services"
    echo "  --logs              Show service logs"
    echo "  --cleanup           Clean up all resources"
    echo "  --e2e-only          Run only end-to-end tests"
    echo "  --performance-only  Run only performance tests"
    echo
    echo "Environment variables:"
    echo "  TEST_TIMEOUT        Test timeout in seconds (default: 300)"
    echo "  MAX_RETRIES         Maximum retries for service startup (default: 3)"
}

# Main function
main() {
    local start_only=false
    local stop_only=false
    local show_logs=false
    local cleanup_only=false
    local e2e_only=false
    local performance_only=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
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
            --e2e-only)
                e2e_only=true
                shift
                ;;
            --performance-only)
                performance_only=true
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
    trap cleanup EXIT
    
    # Check prerequisites
    check_prerequisites
    
    if [ "$cleanup_only" = true ]; then
        cleanup
        exit 0
    fi
    
    if [ "$stop_only" = true ]; then
        stop_services
        exit 0
    fi
    
    if [ "$show_logs" = true ]; then
        show_logs
        exit 0
    fi
    
    # Start services
    start_services
    
    if [ "$start_only" = true ]; then
        log_info "Services started. Use --stop-only to stop them."
        exit 0
    fi
    
    # Run tests based on options
    local test_result=0
    
    if [ "$e2e_only" = true ]; then
        run_e2e_tests || test_result=1
    elif [ "$performance_only" = true ]; then
        run_performance_tests || test_result=1
    else
        # Run all tests
        run_integration_tests || test_result=1
        run_e2e_tests || test_result=1
        run_performance_tests || test_result=1
    fi
    
    # Show logs if tests failed
    if [ $test_result -ne 0 ]; then
        log_warning "Some tests failed. Showing logs..."
        show_logs
    fi
    
    exit $test_result
}

# Run main function
main "$@" 