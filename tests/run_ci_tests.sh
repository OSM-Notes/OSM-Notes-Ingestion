#!/bin/bash

# CI/CD Test Runner for OSM-Notes-profile
# Author: Andres Gomez (AngocA)
# Version: 2025-07-23

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print status messages
print_status() {
    local color="$1"
    local message="$2"
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] ${message}${NC}"
}

# Function to show help
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

CI/CD Test Runner for OSM-Notes-profile

Options:
    --help, -h           Show this help message
    --host-only          Run tests only on host environment
    --docker-only        Run tests only in Docker environment
    --all                Run all tests (host and Docker)
    --verbose, -v        Enable verbose output
    --no-cleanup         Don't cleanup after tests
    --parallel           Run tests in parallel where possible

Environment variables:
    CI_MODE              Set to 'true' for CI environment
    TEST_DBNAME          Test database name (default: osm_notes_test)
    TEST_DBUSER          Test database user (default: testuser)
    TEST_DBPASSWORD      Test database password (default: testpass)
    TEST_DBHOST          Test database host (default: localhost)
    TEST_DBPORT          Test database port (default: 5432)

Examples:
    $0 --all                    # Run all tests
    $0 --host-only --verbose    # Run host tests with verbose output
    $0 --docker-only            # Run Docker tests only
EOF
}

# Parse command line arguments
HOST_ONLY=false
DOCKER_ONLY=false
RUN_ALL=false
VERBOSE=false
NO_CLEANUP=false
PARALLEL=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_help
            exit 0
            ;;
        --host-only)
            HOST_ONLY=true
            shift
            ;;
        --docker-only)
            DOCKER_ONLY=true
            shift
            ;;
        --all)
            RUN_ALL=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --no-cleanup)
            NO_CLEANUP=true
            shift
            ;;
        --parallel)
            PARALLEL=true
            shift
            ;;
        *)
            print_status "$RED" "❌ ERROR: Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Set default behavior
if [[ "$HOST_ONLY" == "false" && "$DOCKER_ONLY" == "false" && "$RUN_ALL" == "false" ]]; then
    RUN_ALL=true
fi

# Function to run host tests
run_host_tests() {
    print_status "$BLUE" "🏠 Running host tests..."
    
    if [[ "$VERBOSE" == "true" ]]; then
        export LOG_LEVEL=DEBUG
    fi
    
    # Run basic tests
    print_status "$BLUE" "📋 Running BATS tests on host..."
    ./tests/run_tests.sh --bats-only
    
    # Run integration tests if available
    if [[ -f "./tests/run_tests.sh" ]]; then
        print_status "$BLUE" "🔗 Running integration tests on host..."
        ./tests/run_tests.sh --integration-only
    fi
    
    print_status "$GREEN" "✅ Host tests completed"
}

# Function to run Docker tests
run_docker_tests() {
    print_status "$BLUE" "🐳 Running Docker tests..."
    
    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        print_status "$RED" "❌ ERROR: Docker is not available"
        return 1
    fi
    
    # Check if docker-compose is available
    if ! command -v docker-compose &> /dev/null; then
        print_status "$RED" "❌ ERROR: docker-compose is not available"
        return 1
    fi
    
    # Navigate to docker directory
    cd tests/docker
    
    # Start containers
    print_status "$BLUE" "🚀 Starting Docker containers..."
    docker-compose up -d --build
    
    # Wait for services to be ready
    print_status "$BLUE" "⏳ Waiting for services to be ready..."
    sleep 10
    
    # Run tests in container
    print_status "$BLUE" "🧪 Running tests in Docker container..."
    docker-compose exec -T app bash -c "cd /app && ./tests/run_tests.sh --bats-only"
    
    # Run integration tests
    print_status "$BLUE" "🔗 Running integration tests in Docker..."
    docker-compose exec -T app bash -c "cd /app && ./tests/run_tests.sh --integration-only"
    
    # Run advanced tests if available
    if [[ -f "./tests/scripts/run_advanced_tests.sh" ]]; then
        print_status "$BLUE" "🚀 Running advanced tests in Docker..."
        docker-compose exec -T app bash -c "cd /app && ./tests/scripts/run_advanced_tests.sh --coverage-only"
        docker-compose exec -T app bash -c "cd /app && ./tests/scripts/run_advanced_tests.sh --security-only"
        docker-compose exec -T app bash -c "cd /app && ./tests/scripts/run_advanced_tests.sh --quality-only"
    fi
    
    # Stop containers if cleanup is enabled
    if [[ "$NO_CLEANUP" == "false" ]]; then
        print_status "$BLUE" "🧹 Cleaning up Docker containers..."
        docker-compose down
    fi
    
    # Return to original directory
    cd ../..
    
    print_status "$GREEN" "✅ Docker tests completed"
}

# Function to run tests in parallel
run_parallel_tests() {
    print_status "$BLUE" "⚡ Running tests in parallel..."
    
    # Start Docker tests in background
    run_docker_tests &
    DOCKER_PID=$!
    
    # Run host tests
    run_host_tests
    
    # Wait for Docker tests to complete
    wait $DOCKER_PID
    
    print_status "$GREEN" "✅ Parallel tests completed"
}

# Main execution
main() {
    print_status "$BLUE" "🚀 Starting CI/CD Test Runner..."
    
    # Set environment variables
    export TEST_DBNAME="${TEST_DBNAME:-osm_notes_test}"
    export TEST_DBUSER="${TEST_DBUSER:-testuser}"
    export TEST_DBPASSWORD="${TEST_DBPASSWORD:-testpass}"
    export TEST_DBHOST="${TEST_DBHOST:-localhost}"
    export TEST_DBPORT="${TEST_DBPORT:-5432}"
    
    # Create results directory
    mkdir -p ./ci_results
    
    # Run tests based on options
    if [[ "$RUN_ALL" == "true" ]]; then
        if [[ "$PARALLEL" == "true" ]]; then
            run_parallel_tests
        else
            run_host_tests
            run_docker_tests
        fi
    elif [[ "$HOST_ONLY" == "true" ]]; then
        run_host_tests
    elif [[ "$DOCKER_ONLY" == "true" ]]; then
        run_docker_tests
    fi
    
    print_status "$GREEN" "🎉 All CI/CD tests completed successfully!"
}

# Execute main function
main "$@" 