#!/bin/bash
#
# Test database setup script for Docker environment
# Author: Andres Gomez (AngocA)
# Version: 2025-10-25

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

# Test database configuration for Docker
TEST_DBNAME="osm_notes_test"
TEST_DBUSER="testuser"
TEST_DBPASSWORD="testpass"
TEST_DBHOST="postgres"
TEST_DBPORT="5432"

# Export variables for tests
export TEST_DBNAME
export TEST_DBUSER
export TEST_DBPASSWORD
export TEST_DBHOST
export TEST_DBPORT
export PGPASSWORD="${TEST_DBPASSWORD}"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

log_info "Setting up test database environment for Docker..."

# Create test directories with proper permissions
log_info "Creating test directories..."
mkdir -p /app/tests/tmp /app/tests/unit/bash/tmp /app/tests/output /app/tests/results 2> /dev/null || true
mkdir -p /app/tests/output/mock_planet_unit 2> /dev/null || true
chmod -R 777 /app/tests/tmp /app/tests/unit/bash/tmp /app/tests/output /app/tests/results 2> /dev/null || true
log_success "Test directories created"

# Test connection
log_info "Testing database connection..."
if PGPASSWORD="${TEST_DBPASSWORD}" psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d postgres -c "SELECT 1;" > /dev/null 2>&1; then
 log_success "Database connection successful"
else
 log_error "Database connection failed"
 log_info "Please check PostgreSQL container is running"
 exit 1
fi

# Create test database if it doesn't exist
log_info "Creating test database if it doesn't exist..."
if ! PGPASSWORD="${TEST_DBPASSWORD}" psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
 log_info "Creating database ${TEST_DBNAME}..."
 PGPASSWORD="${TEST_DBPASSWORD}" createdb -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" "${TEST_DBNAME}"
 log_success "Database ${TEST_DBNAME} created"
else
 log_success "Database ${TEST_DBNAME} already exists"
fi

# Install required extensions
log_info "Installing required extensions..."
PGPASSWORD="${TEST_DBPASSWORD}" psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "CREATE EXTENSION IF NOT EXISTS postgis;" > /dev/null 2>&1 || log_warning "PostGIS extension installation failed"
PGPASSWORD="${TEST_DBPASSWORD}" psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "CREATE EXTENSION IF NOT EXISTS btree_gist;" > /dev/null 2>&1 || log_warning "btree_gist extension installation failed"

# Create enums
log_info "Creating enums..."
PGPASSWORD="${TEST_DBPASSWORD}" psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -f "${PROJECT_ROOT}/sql/process/processPlanetNotes_21_createBaseTables_enum.sql" > /dev/null 2>&1 || log_warning "Enum creation failed"

# Create base tables
log_info "Creating base tables..."
PGPASSWORD="${TEST_DBPASSWORD}" psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -f "${PROJECT_ROOT}/sql/process/processPlanetNotes_22_createBaseTables_tables.sql" > /dev/null 2>&1 || log_warning "Base tables creation failed"

# Create API tables
log_info "Creating API tables..."
PGPASSWORD="${TEST_DBPASSWORD}" psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -f "${PROJECT_ROOT}/sql/process/processAPINotes_21_createApiTables.sql" > /dev/null 2>&1 || log_warning "API tables creation failed"

# Create constraints and indexes (using Docker-specific script)
log_info "Creating constraints and indexes (Docker version)..."
PGPASSWORD="${TEST_DBPASSWORD}" psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -f "${SCRIPT_DIR}/createBaseTables_constraints_docker.sql" > /dev/null 2>&1 || log_warning "Constraints creation failed"

# Verify tables exist
log_info "Verifying tables exist..."
TABLES=("notes" "note_comments" "note_comments_text" "users" "logs" "properties" "notes_api" "note_comments_api" "note_comments_text_api")

for table in "${TABLES[@]}"; do
 if PGPASSWORD="${TEST_DBPASSWORD}" psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "SELECT 1 FROM ${table} LIMIT 1;" > /dev/null 2>&1; then
  log_success "Table ${table} exists"
 else
  log_warning "Table ${table} does not exist or is not accessible"
 fi
done

log_success "Test database setup completed for Docker"
log_info "Environment variables set:"
log_info "  TEST_DBNAME=${TEST_DBNAME}"
log_info "  TEST_DBUSER=${TEST_DBUSER}"
log_info "  TEST_DBHOST=${TEST_DBHOST}"
log_info "  TEST_DBPORT=${TEST_DBPORT}"
log_info "  PGPASSWORD=***"
