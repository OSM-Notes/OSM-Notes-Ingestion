#!/bin/bash

# Script to setup test environment for comment_insertion_flow test
# Author: Andres Gomez (AngocA)
# Version: 2025-12-19

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
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Detect database name from properties or use default
if [[ -z "${TEST_DBNAME:-}" ]]; then
  # Try to load properties file to get DBNAME
  if [[ -f "${PROJECT_ROOT}/etc/properties.sh" ]]; then
    # Source properties.sh and get DBNAME
    # shellcheck disable=SC1090
    source "${PROJECT_ROOT}/etc/properties.sh" 2> /dev/null || true
    TEST_DBNAME="${DBNAME:-}"
  fi

  # If still not set, check which database exists
  if [[ -z "${TEST_DBNAME:-}" ]]; then
    if psql -d "osm-notes" -c "SELECT 1;" > /dev/null 2>&1; then
      TEST_DBNAME="osm-notes"
    elif psql -d "notes" -c "SELECT 1;" > /dev/null 2>&1; then
      TEST_DBNAME="notes"
    else
      TEST_DBNAME="osm-notes"
    fi
  fi
fi

# Check if PostgreSQL is available
check_postgresql() {
  log_info "Checking PostgreSQL availability..."
  if ! command -v psql > /dev/null 2>&1; then
    log_error "PostgreSQL client (psql) is not installed or not in PATH"
    exit 1
  fi

  # Test connection to postgres database
  if ! psql -d postgres -c "SELECT 1;" > /dev/null 2>&1; then
    log_error "Cannot connect to PostgreSQL. Please ensure PostgreSQL is running."
    log_info "Try: sudo systemctl start postgresql"
    exit 1
  fi

  log_success "PostgreSQL is available"
}

# Create test database
create_test_database() {
  log_info "Creating test database '${TEST_DBNAME}' if it doesn't exist..."

  if psql -d "${TEST_DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
    log_warning "Database '${TEST_DBNAME}' already exists. Using existing database."
    return 0
  fi

  if command -v createdb > /dev/null 2>&1; then
    createdb "${TEST_DBNAME}" 2> /dev/null || {
      log_error "Failed to create database '${TEST_DBNAME}'"
      exit 1
    }
    log_success "Database '${TEST_DBNAME}' created"
  else
    log_warning "createdb command not available. Trying to create via psql..."
    psql -d postgres -c "CREATE DATABASE ${TEST_DBNAME};" || {
      log_error "Failed to create database '${TEST_DBNAME}'"
      exit 1
    }
    log_success "Database '${TEST_DBNAME}' created via psql"
  fi
}

# Create base tables and enums
setup_base_schema() {
  log_info "Setting up base schema..."

  # Step 1: Create ENUMs
  log_info "  Creating ENUM types..."
  psql -d "${TEST_DBNAME}" \
    -f "${PROJECT_ROOT}/sql/process/processPlanetNotes_20_createBaseTables_enum.sql" \
    > /dev/null 2>&1 || {
    log_warning "  ENUM creation had warnings (may already exist)"
  }

  # Step 2: Create tables (includes put_lock, remove_lock procedures)
  log_info "  Creating tables and procedures..."
  psql -d "${TEST_DBNAME}" \
    -f "${PROJECT_ROOT}/sql/process/processPlanetNotes_21_createBaseTables_tables.sql" \
    > /dev/null 2>&1 || {
    log_error "  Failed to create tables"
    exit 1
  }

  # Step 3: Create constraints
  log_info "  Creating constraints..."
  psql -d "${TEST_DBNAME}" \
    -f "${PROJECT_ROOT}/sql/process/processPlanetNotes_22_createBaseTables_constraints.sql" \
    > /dev/null 2>&1 || {
    log_error "  Failed to create constraints"
    exit 1
  }

  log_success "Base schema created"
}

# Create functions and procedures
setup_functions() {
  log_info "Setting up functions and procedures..."

  # Create get_country function
  log_info "  Creating get_country function..."
  psql -d "${TEST_DBNAME}" \
    -f "${PROJECT_ROOT}/sql/functionsProcess_20_createFunctionToGetCountry.sql" \
    > /dev/null 2>&1 || {
    log_warning "  get_country function creation had warnings"
  }

  # Create insert_note procedure
  log_info "  Creating insert_note procedure..."
  psql -d "${TEST_DBNAME}" \
    -f "${PROJECT_ROOT}/sql/functionsProcess_21_createProcedure_insertNote.sql" \
    > /dev/null 2>&1 || {
    log_error "  Failed to create insert_note procedure"
    exit 1
  }

  # Create insert_note_comment procedure
  log_info "  Creating insert_note_comment procedure..."
  psql -d "${TEST_DBNAME}" \
    -f "${PROJECT_ROOT}/sql/functionsProcess_22_createProcedure_insertNoteComment.sql" \
    > /dev/null 2>&1 || {
    log_error "  Failed to create insert_note_comment procedure"
    exit 1
  }

  # Create sequence trigger for note_comments
  log_info "  Creating sequence trigger for note_comments..."
  psql -d "${TEST_DBNAME}" \
    -f "${PROJECT_ROOT}/sql/process/processPlanetNotes_32_commentsSequence.sql" \
    > /dev/null 2>&1 || {
    log_error "  Failed to create sequence trigger"
    exit 1
  }

  log_success "Functions and procedures created"
}

# Verify setup
verify_setup() {
  log_info "Verifying setup..."

  local errors=0
  local result=0

  # Check for required tables
  for table in notes note_comments note_comments_text users logs properties; do
    if ! psql -d "${TEST_DBNAME}" -c "\d ${table}" > /dev/null 2>&1; then
      log_error "  Table '${table}' is missing"
      errors=$((errors + 1))
    fi
  done

  # Check for required procedures
  for proc in put_lock remove_lock insert_note insert_note_comment; do
    if ! psql -d "${TEST_DBNAME}" -c "\df ${proc}" | grep -q "${proc}"; then
      log_error "  Procedure/Function '${proc}' is missing"
      errors=$((errors + 1))
    fi
  done

  # Check for get_country function
  if ! psql -d "${TEST_DBNAME}" -c "\df get_country" | grep -q "get_country"; then
    log_error "  Function 'get_country' is missing"
    errors=$((errors + 1))
  fi

  if [[ ${errors} -eq 0 ]]; then
    log_success "Setup verification passed"
    result=0
  else
    log_error "Setup verification failed with ${errors} errors"
    result=1
  fi

  return "${result}"
}

# Main execution
main() {
  log_info "Setting up test environment for comment_insertion_flow test"
  log_info "Test database: ${TEST_DBNAME}"
  echo ""

  check_postgresql
  create_test_database
  setup_base_schema
  setup_functions

  echo ""
  if verify_setup; then
    log_success "Test environment setup completed successfully!"
    echo ""
    log_info "You can now run the test with:"
    echo "  psql -d ${TEST_DBNAME} -f ${SCRIPT_DIR}/unit/sql/comment_insertion_flow.test.sql"
    echo ""
    log_info "Or use the test runner:"
    echo "  ${SCRIPT_DIR}/run_comment_insertion_test.sh"
  else
    log_error "Test environment setup failed verification"
    exit 1
  fi
}

# Run main function
main
