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

# Test database configuration for peer authentication
TEST_DBNAME="osm_notes_test"
TEST_DBUSER="$(whoami)"
TEST_DBPASSWORD=""
TEST_DBHOST=""
TEST_DBPORT=""

# Export variables for tests
export TEST_DBNAME
export TEST_DBUSER
export TEST_DBPASSWORD
export TEST_DBHOST
export TEST_DBPORT

# For peer authentication, unset PGPASSWORD and database connection variables
unset PGPASSWORD 2> /dev/null || true
unset DB_HOST 2> /dev/null || true
unset DB_PORT 2> /dev/null || true
unset DB_USER 2> /dev/null || true
unset DB_PASSWORD 2> /dev/null || true

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

log_info "Setting up test database environment..."

# Test connection as current user
log_info "Testing database connection..."
if psql -d postgres -c "SELECT 1;" > /dev/null 2>&1; then
 log_success "Database connection successful"
else
 log_error "Database connection failed"
 log_info "Please check PostgreSQL configuration and ensure you have access"
 exit 1
fi

# Create test database if it doesn't exist
log_info "Creating test database if it doesn't exist..."
if ! psql -d "${TEST_DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
 log_info "Creating database ${TEST_DBNAME}..."
 createdb "${TEST_DBNAME}"
 log_success "Database ${TEST_DBNAME} created"
else
 log_success "Database ${TEST_DBNAME} already exists"
fi

# Install required extensions
log_info "Installing required extensions..."
psql -d "${TEST_DBNAME}" -c "CREATE EXTENSION IF NOT EXISTS postgis;" > /dev/null 2>&1 || log_warning "PostGIS extension installation failed"
psql -d "${TEST_DBNAME}" -c "CREATE EXTENSION IF NOT EXISTS btree_gist;" > /dev/null 2>&1 || log_warning "btree_gist extension installation failed"

# Create enums
log_info "Creating enums..."
psql -d "${TEST_DBNAME}" -f "${PROJECT_ROOT}/sql/process/processPlanetNotes_21_createBaseTables_enum.sql" > /dev/null 2>&1 || log_warning "Enum creation failed"

# Create base tables
log_info "Creating base tables..."
psql -d "${TEST_DBNAME}" -f "${PROJECT_ROOT}/sql/process/processPlanetNotes_22_createBaseTables_tables.sql" > /dev/null 2>&1 || log_warning "Base tables creation failed"

# Create API tables
log_info "Creating API tables..."
psql -d "${TEST_DBNAME}" -f "${PROJECT_ROOT}/sql/process/processAPINotes_21_createApiTables.sql" > /dev/null 2>&1 || log_warning "API tables creation failed"

# Create constraints and indexes
log_info "Creating constraints and indexes..."
psql -d "${TEST_DBNAME}" -f "${PROJECT_ROOT}/sql/process/processPlanetNotes_23_createBaseTables_constraints.sql" > /dev/null 2>&1 || log_warning "Constraints creation failed"

# Create functions and procedures
log_info "Creating functions and procedures..."
psql -d "${TEST_DBNAME}" -f "${PROJECT_ROOT}/sql/functionsProcess_21_createFunctionToGetCountry.sql" > /dev/null 2>&1 || log_warning "Function get_country creation failed"
psql -d "${TEST_DBNAME}" -f "${PROJECT_ROOT}/sql/functionsProcess_22_createProcedure_insertNote.sql" > /dev/null 2>&1 || log_warning "Procedure insertNote creation failed"
psql -d "${TEST_DBNAME}" -f "${PROJECT_ROOT}/sql/functionsProcess_23_createProcedure_insertNoteComment.sql" > /dev/null 2>&1 || log_warning "Procedure insertNoteComment creation failed"

# Verify tables exist
log_info "Verifying tables exist..."
TABLES=("notes" "note_comments" "note_comments_text" "users" "logs" "properties" "notes_api" "note_comments_api" "note_comments_text_api")

for table in "${TABLES[@]}"; do
 if psql -d "${TEST_DBNAME}" -c "SELECT 1 FROM ${table} LIMIT 1;" > /dev/null 2>&1; then
  log_success "Table ${table} exists"
 else
  log_warning "Table ${table} does not exist or is not accessible"
 fi
done

log_success "Test database setup completed"
log_info "Environment variables set:"
log_info "  TEST_DBNAME=${TEST_DBNAME}"
log_info "  TEST_DBUSER=${TEST_DBUSER}"
log_info "  TEST_DBHOST=${TEST_DBHOST:-not set (peer authentication)}"
log_info "  TEST_DBPORT=${TEST_DBPORT:-not set (peer authentication)}"
log_info "  Authentication: peer (no password required)"
