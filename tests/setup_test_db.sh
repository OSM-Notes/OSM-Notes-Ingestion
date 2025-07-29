#!/bin/bash

# Setup script for test database
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

# Test database configuration
TEST_DBNAME="osm_notes_test"
TEST_DBUSER="notes"
TEST_DBPASSWORD="testpass"
TEST_DBHOST="localhost"
TEST_DBPORT="5432"

# Export variables for tests
export TEST_DBNAME
export TEST_DBUSER
export TEST_DBPASSWORD
export TEST_DBHOST
export TEST_DBPORT
export PGPASSWORD="${TEST_DBPASSWORD}"

log_info "Setting up test database environment..."

# Test connection as notes user (using local connection)
log_info "Testing database connection..."
if sudo -u notes psql -d postgres -c "SELECT 1;" >/dev/null 2>&1; then
 log_success "Database connection successful"
else
 log_error "Database connection failed"
 log_info "Please check PostgreSQL configuration"
 exit 1
fi

# Create test database if it doesn't exist
log_info "Creating test database if it doesn't exist..."
if ! sudo -u notes psql -d "${TEST_DBNAME}" -c "SELECT 1;" >/dev/null 2>&1; then
 log_info "Creating database ${TEST_DBNAME}..."
 sudo -u notes createdb "${TEST_DBNAME}"
 log_success "Database ${TEST_DBNAME} created"
else
 log_success "Database ${TEST_DBNAME} already exists"
fi

# Install required extensions
log_info "Installing required extensions..."
sudo -u notes psql -d "${TEST_DBNAME}" -c "CREATE EXTENSION IF NOT EXISTS postgis;" >/dev/null 2>&1 || log_warning "PostGIS extension installation failed"
sudo -u notes psql -d "${TEST_DBNAME}" -c "CREATE EXTENSION IF NOT EXISTS btree_gist;" >/dev/null 2>&1 || log_warning "btree_gist extension installation failed"

log_success "Test database setup completed"
log_info "Environment variables set:"
log_info "  TEST_DBNAME=${TEST_DBNAME}"
log_info "  TEST_DBUSER=${TEST_DBUSER}"
log_info "  TEST_DBHOST=${TEST_DBHOST}"
log_info "  TEST_DBPORT=${TEST_DBPORT}"
log_info "  PGPASSWORD=***"