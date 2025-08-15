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

# Function to install missing tools
__install_missing_tools() {
    local missing_tools=("$@")
    
    log_info "Installing missing tools: ${missing_tools[*]}"
    
    # Detect package manager
    if command -v apt-get >/dev/null 2>&1; then
        log_info "Using apt-get package manager"
        sudo apt-get update -qq
        for tool in "${missing_tools[@]}"; do
            case "${tool}" in
                "bats")
                    log_info "Installing bats..."
                    sudo apt-get install -y bats
                    ;;
                "shfmt")
                    log_info "Installing shfmt..."
                    sudo apt-get install -y shfmt
                    ;;
                *)
                    log_warning "Unknown tool: ${tool}"
                    ;;
            esac
        done
    elif command -v yum >/dev/null 2>&1; then
        log_info "Using yum package manager"
        for tool in "${missing_tools[@]}"; do
            case "${tool}" in
                "bats")
                    log_info "Installing bats..."
                    sudo yum install -y bats
                    ;;
                "shfmt")
                    log_info "Installing shfmt..."
                    sudo yum install -y shfmt
                    ;;
                *)
                    log_warning "Unknown tool: ${tool}"
                    ;;
            esac
        done
    elif command -v dnf >/dev/null 2>&1; then
        log_info "Using dnf package manager"
        for tool in "${missing_tools[@]}"; do
            case "${tool}" in
                "bats")
                    log_info "Installing bats..."
                    sudo dnf install -y bats
                    ;;
                "shfmt")
                    log_info "Installing shfmt..."
                    sudo dnf install -y shfmt
                    ;;
                *)
                    log_warning "Unknown tool: ${tool}"
                    ;;
            esac
        done
    else
        log_warning "Unsupported package manager, trying alternative installation methods"
        
        # Try to install bats using alternative methods
        if [[ " ${missing_tools[*]} " =~ " bats " ]]; then
            log_info "Installing bats using alternative method..."
            if command -v npm >/dev/null 2>&1; then
                sudo npm install -g bats
            elif command -v pip3 >/dev/null 2>&1; then
                sudo pip3 install bats-core
            else
                log_warning "Could not install bats automatically"
            fi
        fi
        
        # Try to install shfmt using alternative methods
        if [[ " ${missing_tools[*]} " =~ " shfmt " ]]; then
            log_info "Installing shfmt using alternative method..."
            if command -v go >/dev/null 2>&1; then
                go install mvdan.cc/sh/v3/cmd/shfmt@latest
            elif command -v curl >/dev/null 2>&1; then
                curl -sSfL https://github.com/mvdan/sh/releases/latest/download/shfmt_linux_amd64 -o /tmp/shfmt
                chmod +x /tmp/shfmt
                sudo mv /tmp/shfmt /usr/local/bin/
            else
                log_warning "Could not install shfmt automatically"
            fi
        fi
    fi
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
        
        # Try to install missing tools
        if [[ "${CI:-false}" == "true" ]] || [[ "${GITHUB_ACTIONS:-false}" == "true" ]]; then
            log_info "Attempting to install missing tools in CI environment..."
            __install_missing_tools "${missing_tools[@]}"
            
            # Verify again after installation
            log_info "Verifying tools after installation..."
            local still_missing=()
            for tool in "${missing_tools[@]}"; do
                if command -v "${tool}" >/dev/null 2>&1; then
                    log_success "✓ ${tool} is now available"
                else
                    log_warning "⚠ ${tool} is still not available"
                    still_missing+=("${tool}")
                fi
            done
            
            if [[ ${#still_missing[@]} -gt 0 ]]; then
                log_warning "Some tools could not be installed: ${still_missing[*]}"
                # In CI environment, we can continue with missing tools for now
                if [[ "${CI:-false}" == "true" ]] || [[ "${GITHUB_ACTIONS:-false}" == "true" ]]; then
                    log_info "Continuing in CI environment despite missing tools"
                    return 0
                fi
            fi
        fi
        
        # In non-CI environment, return error if tools are missing
        if [[ "${CI:-false}" != "true" ]] && [[ "${GITHUB_ACTIONS:-false}" != "true" ]]; then
            return 1
        fi
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
    if ! __verify_tools; then
        log_error "Failed to verify required tools"
        exit 1
    fi
    
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
