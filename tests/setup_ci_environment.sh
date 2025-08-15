#!/bin/bash

# Setup CI Environment for OSM-Notes-profile
# Author: Andres Gomez (AngocA)
# Version: 2025-08-14

set -uo pipefail

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

# Function to wait for PostgreSQL to be ready
__wait_for_postgres() {
    local max_attempts=30
    local attempt=1
    
    log_info "Waiting for PostgreSQL to be ready..."
    
    while [[ ${attempt} -le ${max_attempts} ]]; do
        if pg_isready -h localhost -p 5432 -U testuser >/dev/null 2>&1; then
            log_success "PostgreSQL is ready!"
            return 0
        fi
        
        log_info "Attempt ${attempt}/${max_attempts}: PostgreSQL not ready yet, waiting..."
        sleep 2
        ((attempt++))
    done
    
    log_error "PostgreSQL failed to become ready after ${max_attempts} attempts"
    return 1
}

# Function to test database connection
__test_database_connection() {
    log_info "Testing database connection..."
    
    if psql -h localhost -U testuser -d osm_notes_test -c "SELECT version();" >/dev/null 2>&1; then
        log_success "Database connection successful"
        return 0
    else
        log_error "Database connection failed"
        return 1
    fi
}

# Function to setup environment variables
__setup_environment() {
    log_info "Setting up environment variables..."
    
    # Database configuration
    export TEST_DBNAME="osm_notes_test"
    export TEST_DBUSER="testuser"
    export TEST_DBPASSWORD="testpass"
    export TEST_DBHOST="localhost"
    export TEST_DBPORT="5432"
    
    # Legacy variables for backward compatibility
    export DBNAME="osm_notes_test"
    export DB_USER="testuser"
    export DBPASSWORD="testpass"
    export DBHOST="localhost"
    export DBPORT="5432"
    
    # PostgreSQL client configuration
    export PGPASSWORD="testpass"
    export PGHOST="localhost"
    export PGUSER="testuser"
    export PGDATABASE="osm_notes_test"
    
    # Application settings
    export LOG_LEVEL="INFO"
    export MAX_THREADS="2"
    export CI="true"
    export GITHUB_ACTIONS="true"
    
    log_success "Environment variables configured"
}

# Function to create necessary directories
__create_directories() {
    log_info "Creating necessary directories..."
    
    mkdir -p tests/results
    mkdir -p tests/output
    mkdir -p tests/docker/logs
    
    log_success "Directories created successfully"
}

# Function to verify tools availability
__verify_tools() {
    log_info "Verifying required tools are available..."
    
    local tools=("psql" "pg_isready" "bats" "shellcheck" "shfmt")
    local missing_tools=()
    
    for tool in "${tools[@]}"; do
        if command -v "${tool}" >/dev/null 2>&1; then
            log_success "✓ ${tool} is available"
        else
            log_warning "⚠ ${tool} is not available"
            missing_tools+=("${tool}")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_warning "Some tools are missing: ${missing_tools[*]}"
        return 1
    fi
    
    return 0
}

# Main function
main() {
    log_info "Setting up CI environment..."
    
    # Setup environment variables
    __setup_environment
    
    # Create necessary directories
    __create_directories
    
    # Verify tools availability
    __verify_tools
    
    # Wait for PostgreSQL
    if ! __wait_for_postgres; then
        log_error "Failed to wait for PostgreSQL"
        exit 1
    fi
    
    # Test database connection
    if ! __test_database_connection; then
        log_error "Failed to connect to database"
        exit 1
    fi
    
    log_success "CI environment setup completed successfully"
}

# Run main function
main "$@"
