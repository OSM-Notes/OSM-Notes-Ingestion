#!/bin/bash

# Script to run deterministic fixtures with a real PostgreSQL database
# This script:
# 1. Sets up mock environment for downloads (aria2c, wget, bzip2)
# 2. Uses real PostgreSQL database instead of mock psql
# 3. Configures environment variables for database connection
#
# Author: Andres Gomez (AngocA)
# Version: 2025-10-31

SCRIPT_SOURCED=false
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
 SCRIPT_SOURCED=true
fi

if [[ "${SCRIPT_SOURCED}" == "false" ]]; then
 set -euo pipefail
fi

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

# Helper to exit or return depending on execution mode
script_exit() {
 local STATUS="${1:-0}"
 if [[ "${SCRIPT_SOURCED}" == "true" ]]; then
  return "${STATUS}"
 else
  exit "${STATUS}"
 fi
}

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOCK_COMMANDS_DIR="${SCRIPT_DIR}/mock_commands"

# Database configuration (can be overridden with environment variables)
DBNAME="${DBNAME:-osm-notes-test}"
DB_USER="${DB_USER:-${USER}}"
DB_HOST="${DB_HOST:-}"
DB_PORT="${DB_PORT:-5432}"
DB_PASSWORD="${DB_PASSWORD:-}"

# Function to check if PostgreSQL is available
check_postgresql() {
 log_info "Checking PostgreSQL availability..."
 
 if ! command -v psql > /dev/null 2>&1; then
  log_error "PostgreSQL client (psql) is not installed"
  return 1
 fi
 
 # Try to connect to PostgreSQL
 if psql -d postgres -c "SELECT 1;" > /dev/null 2>&1; then
  log_success "PostgreSQL is available"
  return 0
 else
  log_error "Cannot connect to PostgreSQL. Make sure PostgreSQL is running and accessible"
  return 1
 fi
}

# Function to create test database if it doesn't exist
setup_test_database() {
 log_info "Setting up test database: ${DBNAME}"
 
 # Check if database exists
 if psql -d "${DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
  log_warning "Database ${DBNAME} already exists"
  read -p "Do you want to drop and recreate it? (y/N): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
   log_info "Dropping database ${DBNAME}..."
   psql -d postgres -c "DROP DATABASE IF EXISTS ${DBNAME};" > /dev/null 2>&1 || true
   log_info "Creating database ${DBNAME}..."
   createdb "${DBNAME}" 2>/dev/null || true
   log_success "Database ${DBNAME} created successfully"
  else
   log_info "Using existing database ${DBNAME}"
  fi
 else
  log_info "Creating database ${DBNAME}..."
  createdb "${DBNAME}" 2>/dev/null || true
  log_success "Database ${DBNAME} created successfully"
 fi

 log_info "Ensuring PostGIS extensions are installed in ${DBNAME}" 
 if ! psql -d "${DBNAME}" -c "CREATE EXTENSION IF NOT EXISTS postgis;" > /dev/null 2>&1; then
  log_error "Failed to create extension postgis in ${DBNAME}. Make sure PostGIS is installed"
  return 1
 fi
 if ! psql -d "${DBNAME}" -c "CREATE EXTENSION IF NOT EXISTS btree_gist;" > /dev/null 2>&1; then
  log_error "Failed to create extension btree_gist in ${DBNAME}."
  return 1
 fi
 log_success "PostGIS extensions ready in ${DBNAME}"
}

# Function to setup mock environment (excluding psql)
setup_mock_environment() {
 log_info "Setting up mock environment (downloads only)..."
 
 # Setup hybrid mock environment (includes aria2c, wget, bzip2, but NOT psql)
 if [[ -f "${SCRIPT_DIR}/setup_hybrid_mock_environment.sh" ]]; then
  source "${SCRIPT_DIR}/setup_hybrid_mock_environment.sh"
 else
  log_error "setup_hybrid_mock_environment.sh not found"
  return 1
 fi
}

# Function to ensure real psql is used (not mock)
ensure_real_psql() {
 log_info "Ensuring real PostgreSQL client is used..."
 
 # Temporarily remove mock commands directory from PATH to find real psql
 TEMP_PATH=$(echo "$PATH" | tr ':' '\n' | grep -v "${MOCK_COMMANDS_DIR}" | tr '\n' ':' | sed 's/:$//')
 
 # Find real psql path
 REAL_PSQL_PATH=""
 while IFS= read -r dir; do
  if [[ -f "${dir}/psql" ]] && ! [[ "${dir}" == "${MOCK_COMMANDS_DIR}" ]]; then
   REAL_PSQL_PATH="${dir}/psql"
   break
  fi
 done <<< "$(echo "$TEMP_PATH" | tr ':' '\n')"
 
 if [[ -z "${REAL_PSQL_PATH}" ]]; then
  log_error "Real psql command not found in PATH"
  return 1
 fi
 
 # Remove mock commands directory from PATH and put real psql directory first
 local NEW_PATH
 NEW_PATH=$(echo "$TEMP_PATH" | tr ':' '\n' | grep -v "${MOCK_COMMANDS_DIR}" | tr '\n' ':' | sed 's/:$//')
 export PATH="${NEW_PATH}"
 
 # Re-add mock commands directory (but real psql should be found first in remaining paths)
 # We'll ensure mock commands dir is NOT first in PATH
 local REAL_PSQL_DIR
 REAL_PSQL_DIR=$(dirname "${REAL_PSQL_PATH}")
 export PATH="${REAL_PSQL_DIR}:${MOCK_COMMANDS_DIR}:${PATH}"
 
 # Verify we're using real psql
 local CURRENT_PSQL
 CURRENT_PSQL=$(command -v psql)
 if [[ "${CURRENT_PSQL}" != "${REAL_PSQL_PATH}" ]] && [[ -f "${MOCK_COMMANDS_DIR}/psql" ]]; then
  log_warning "Mock psql found in mock directory, removing from PATH..."
  local CLEAN_PATH
  CLEAN_PATH=$(echo "$PATH" | tr ':' '\n' | grep -v "${MOCK_COMMANDS_DIR}" | tr '\n' ':' | sed 's/:$//')
  export PATH="${REAL_PSQL_DIR}:${CLEAN_PATH}"
 fi
 
 # Verify again
 if ! command -v psql > /dev/null 2>&1; then
  log_error "Real psql command not found after PATH adjustment"
  return 1
 fi
 
 PSQL_PATH=$(command -v psql)
 log_success "Using real psql from: ${PSQL_PATH}"
}

# Function to setup environment variables
setup_environment() {
 log_info "Setting up environment variables..."
 
 # Database configuration
 export DBNAME="${DBNAME}"
 export DB_USER="${DB_USER}"
 local current_db_host="${DB_HOST-}"
 if [[ -n "${current_db_host}" ]]; then
  export DB_HOST="${current_db_host}"
 else
  unset DB_HOST
 fi
 export DB_PORT="${DB_PORT}"
 if [[ -n "${DB_PASSWORD}" ]]; then
  export DB_PASSWORD="${DB_PASSWORD}"
 fi
 
 # PostgreSQL client variables
 export PGDATABASE="${DBNAME}"
 export PGUSER="${DB_USER}"
 if [[ -n "${current_db_host}" ]]; then
  export PGHOST="${current_db_host}"
 else
  unset PGHOST
 fi
 export PGPORT="${DB_PORT}"
 if [[ -n "${DB_PASSWORD}" ]]; then
  export PGPASSWORD="${DB_PASSWORD}"
 fi
 
 # Application settings
 export LOG_LEVEL="${LOG_LEVEL:-DEBUG}"
 export CLEAN="${CLEAN:-false}"
 export SKIP_XML_VALIDATION="${SKIP_XML_VALIDATION:-true}"
 
 log_success "Environment variables configured"
 local HOST_DISPLAY
 if [[ -n "${current_db_host}" ]]; then
 HOST_DISPLAY="${current_db_host}"
 else
  HOST_DISPLAY="(unix socket / peer auth)"
 fi
 log_info "  DBNAME: ${DBNAME}"
 log_info "  DB_USER: ${DB_USER}"
 log_info "  DB_HOST: ${HOST_DISPLAY}"
 log_info "  DB_PORT: ${DB_PORT}"
 log_info "  LOG_LEVEL: ${LOG_LEVEL}"
 log_info "  CLEAN: ${CLEAN}"
}

# Main function
main() {
 log_info "=== Setting up Deterministic Fixtures with Real PostgreSQL ==="
 
 # Check prerequisites
 if ! check_postgresql; then
  log_error "PostgreSQL check failed. Aborting."
  script_exit 1
 fi
 
 # Setup test database
 if ! setup_test_database; then
  log_error "Database setup failed. Aborting."
  script_exit 1
 fi
 
 # Setup mock environment (downloads only)
 if ! setup_mock_environment; then
  log_error "Mock environment setup failed. Aborting."
  script_exit 1
 fi
 
 # Ensure real psql is used
 if ! ensure_real_psql; then
  log_error "Failed to ensure real psql is used. Aborting."
  script_exit 1
 fi
 
 # Setup environment variables
 setup_environment
 
 log_success "=== Setup completed successfully ==="
 echo
 log_info "You can now run:"
 echo "  ./bin/process/processAPINotes.sh"
 echo "  or"
 echo "  ./bin/cleanupAll.sh -a && ./bin/process/processAPINotes.sh"
 echo
 log_info "The scripts will use:"
 log_info "  - Mock commands for downloads (aria2c, wget)"
 log_info "  - Real PostgreSQL database: ${DBNAME}"
 log_info "  - Real psql client"

 script_exit 0
}

# Run main function
main "$@"

