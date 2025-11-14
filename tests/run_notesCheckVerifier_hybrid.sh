#!/bin/bash

# Script to run notesCheckVerifier.sh in hybrid mode (real DB, mocked downloads)
# Author: Andres Gomez (AngocA)
# Version: 2025-11-12

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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
readonly SCRIPT_DIR
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly PROJECT_ROOT
MOCK_COMMANDS_DIR="${SCRIPT_DIR}/mock_commands"
readonly MOCK_COMMANDS_DIR
SETUP_HYBRID_SCRIPT="${SCRIPT_DIR}/setup_hybrid_mock_environment.sh"
readonly SETUP_HYBRID_SCRIPT

# Database configuration - will be set up before running scripts
# All database connections must be controlled by properties files.
# We'll temporarily replace etc/properties.sh with properties_test.sh
# before executing the main scripts.

# Database connection parameters (for psql command only)
DB_HOST="${DB_HOST:-}"
DB_PORT="${DB_PORT:-5432}"
DB_PASSWORD="${DB_PASSWORD:-}"

# Function to show help
show_help() {
  cat << 'EOF'
Script to run notesCheckVerifier.sh in hybrid mode (real DB, mocked downloads)

This script sets up a hybrid mock environment where:
  - Internet downloads are mocked (wget, aria2c)
  - Database operations use REAL PostgreSQL
  - Email sending is mocked (mutt) to avoid sending real emails
  - All processing runs with real database but without internet downloads

Usage:
  ./run_notesCheckVerifier_hybrid.sh [OPTIONS]

Options:
  --help, -h     Show this help message

Environment variables:
  LOG_LEVEL      Logging level (TRACE, DEBUG, INFO, WARN, ERROR, FATAL)
                 Default: INFO
  CLEAN          Clean temporary files after execution (true/false)
                 Default: false
  DBNAME         Database name (default: osm-notes-test)
  DB_USER        Database user (default: current user)
  DB_HOST        Database host (default: unix socket)
  DB_PORT        Database port (default: 5432)
  DB_PASSWORD    Database password (if required)
  EMAILS         Email addresses for reports (comma-separated)
                 Default: test@example.com

Examples:
  # Run with default settings
  ./run_notesCheckVerifier_hybrid.sh

  # Run with custom database
  DBNAME=my_test_db DB_USER=postgres ./run_notesCheckVerifier_hybrid.sh

  # Run with debug logging
  LOG_LEVEL=DEBUG ./run_notesCheckVerifier_hybrid.sh

  # Run and clean temporary files
  CLEAN=true ./run_notesCheckVerifier_hybrid.sh
EOF
}

# Function to check if PostgreSQL is available
check_postgresql() {
  log_info "Checking PostgreSQL availability..."

  if ! command -v psql > /dev/null 2>&1; then
    log_error "PostgreSQL client (psql) is not installed"
    return 1
  fi

  # Try to connect to PostgreSQL
  local psql_cmd="psql"
  if [[ -n "${DB_HOST:-}" ]]; then
    psql_cmd="${psql_cmd} -h ${DB_HOST} -p ${DB_PORT}"
  fi

  if ${psql_cmd} -d postgres -c "SELECT 1;" > /dev/null 2>&1; then
    log_success "PostgreSQL is available"
    return 0
  else
    log_error "Cannot connect to PostgreSQL. Make sure PostgreSQL is running"
    log_error "Connection details: host=${DB_HOST:-unix socket}, port=${DB_PORT}, user=${DB_USER}"
    return 1
  fi
}

# Function to setup test database
setup_test_database() {
  log_info "Setting up test database: ${DBNAME}"

  local psql_cmd="psql"
  if [[ -n "${DB_HOST:-}" ]]; then
    psql_cmd="${psql_cmd} -h ${DB_HOST} -p ${DB_PORT}"
  fi

  # Check if database exists
  if ${psql_cmd} -d "${DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
    log_info "Database ${DBNAME} already exists"
  else
    log_info "Creating database ${DBNAME}..."
    if [[ -n "${DB_HOST}" ]]; then
      createdb -h "${DB_HOST}" -p "${DB_PORT}" "${DBNAME}" 2>/dev/null || true
    else
      createdb "${DBNAME}" 2>/dev/null || true
    fi
    log_success "Database ${DBNAME} created successfully"
  fi

  log_info "Ensuring PostGIS extensions are installed in ${DBNAME}"
  if ! ${psql_cmd} -d "${DBNAME}" -c "CREATE EXTENSION IF NOT EXISTS postgis;" > /dev/null 2>&1; then
    log_error "Failed to create extension postgis in ${DBNAME}"
    log_error "Make sure PostGIS is installed"
    return 1
  fi
  if ! ${psql_cmd} -d "${DBNAME}" -c "CREATE EXTENSION IF NOT EXISTS btree_gist;" > /dev/null 2>&1; then
    log_error "Failed to create extension btree_gist in ${DBNAME}"
    return 1
  fi
  log_success "PostGIS extensions ready in ${DBNAME}"
}

# Function to migrate database schema (add missing columns)
migrate_database_schema() {
  # Load DBNAME from properties file if not already loaded
  if [[ -z "${DBNAME:-}" ]]; then
    # shellcheck disable=SC1091
    source "${PROJECT_ROOT}/etc/properties.sh"
  fi
  
  log_info "Migrating database schema (adding missing columns if needed)..."

  local psql_cmd="psql"
  if [[ -n "${DB_HOST:-}" ]]; then
    psql_cmd="${psql_cmd} -h ${DB_HOST} -p ${DB_PORT}"
  fi

  local migration_script="${PROJECT_ROOT}/sql/process/processPlanetNotes_26_migrateMissingColumns.sql"
  
  if [[ ! -f "${migration_script}" ]]; then
    log_warning "Migration script not found: ${migration_script}"
    return 0
  fi

  # Execute migration script (ignore errors if tables don't exist yet)
  if ${psql_cmd} -d "${DBNAME}" -f "${migration_script}" > /dev/null 2>&1; then
    log_success "Database schema migration completed"
  else
    log_warning "Migration script execution had warnings (this is OK if tables don't exist yet)"
  fi
}

# Function to cleanup lock files
cleanup_lock_files() {
  log_info "Cleaning up lock files and failed execution markers..."

  # Clean notesCheckVerifier lock file
  local lock_file="/tmp/notesCheckVerifier.lock"
  if [[ -f "${lock_file}" ]]; then
    log_info "Removing lock file: ${lock_file}"
    rm -f "${lock_file}"
  fi

  # Clean failed execution marker
  local failed_file="/tmp/notesCheckVerifier_failed_execution"
  if [[ -f "${failed_file}" ]]; then
    log_info "Removing failed execution marker: ${failed_file}"
    rm -f "${failed_file}"
  fi

  # Clean processCheckPlanetNotes lock file (in case it exists)
  local check_lock="/tmp/processCheckPlanetNotes.lock"
  if [[ -f "${check_lock}" ]]; then
    log_info "Removing check lock file: ${check_lock}"
    rm -f "${check_lock}"
  fi

  log_success "Lock files cleaned"
}

# Function to setup hybrid mock environment
setup_hybrid_mock_environment() {
  log_info "Setting up hybrid mock environment..."

  # Setup mock commands
  if [[ ! -f "${SETUP_HYBRID_SCRIPT}" ]]; then
    log_error "Hybrid mock setup script not found: ${SETUP_HYBRID_SCRIPT}"
    return 1
  fi

  # Create mock commands if they don't exist
  if [[ ! -f "${MOCK_COMMANDS_DIR}/wget" ]] || \
     [[ ! -f "${MOCK_COMMANDS_DIR}/aria2c" ]]; then
    log_info "Creating mock commands..."
    bash "${SETUP_HYBRID_SCRIPT}" setup
  fi

  # Ensure pgrep mock exists
  if [[ ! -f "${MOCK_COMMANDS_DIR}/pgrep" ]]; then
    log_info "Creating mock pgrep..."
    cat > "${MOCK_COMMANDS_DIR}/pgrep" << 'EOF'
#!/bin/bash
# Mock pgrep - always returns no processes found
exit 1
EOF
    chmod +x "${MOCK_COMMANDS_DIR}/pgrep"
  fi

  # Ensure mutt mock exists (to avoid sending real emails)
  if [[ ! -f "${MOCK_COMMANDS_DIR}/mutt" ]]; then
    log_info "Creating mock mutt..."
    # Source setup_mock_environment.sh to get create_mock_mutt function
    set +eu
    source "${SCRIPT_DIR}/setup_mock_environment.sh" 2> /dev/null || true
    set -eu
    if command -v create_mock_mutt > /dev/null 2>&1; then
      create_mock_mutt
    else
      # Create inline if function not available
      cat > "${MOCK_COMMANDS_DIR}/mutt" << 'MUTTEOF'
#!/bin/bash
# Mock mutt command for testing
echo "Mock email sent: $@"
exit 0
MUTTEOF
      chmod +x "${MOCK_COMMANDS_DIR}/mutt"
    fi
  fi

  # Ensure all mock commands are executable
  chmod +x "${MOCK_COMMANDS_DIR}/wget" 2>/dev/null || true
  chmod +x "${MOCK_COMMANDS_DIR}/aria2c" 2>/dev/null || true
  chmod +x "${MOCK_COMMANDS_DIR}/pgrep" 2>/dev/null || true
  chmod +x "${MOCK_COMMANDS_DIR}/mutt" 2>/dev/null || true

  # Source setup script (but don't activate yet - we'll do that after ensure_real_psql)
  set +eu
  source "${SETUP_HYBRID_SCRIPT}" 2>/dev/null || true
  set -eu

  # Ensure real psql is used (not mock) - this creates hybrid_mock_dir and sets PATH correctly
  if ! ensure_real_psql; then
    log_error "Failed to ensure real psql is used"
    return 1
  fi

  # Add mutt mock to hybrid_mock_dir
  if [[ -n "${HYBRID_MOCK_DIR:-}" ]] && [[ -d "${HYBRID_MOCK_DIR}" ]]; then
    if [[ -f "${MOCK_COMMANDS_DIR}/mutt" ]]; then
      cp "${MOCK_COMMANDS_DIR}/mutt" "${HYBRID_MOCK_DIR}/mutt"
      chmod +x "${HYBRID_MOCK_DIR}/mutt"
    fi
  fi

  log_success "Hybrid mock environment activated"
  return 0
}

# Function to ensure real psql is used (not mock)
# This function ensures psql is real while keeping aria2c, wget, and mutt mocks active
ensure_real_psql() {
  log_info "Ensuring real PostgreSQL client is used..."

  # Remove mock commands directory from PATH temporarily to find real psql
  local temp_path
  temp_path=$(echo "${PATH}" | tr ':' '\n' | grep -v "${MOCK_COMMANDS_DIR}" | tr '\n' ':' | sed 's/:$//')

  # Find real psql path
  local real_psql_path
  real_psql_path=""
  while IFS= read -r dir; do
    if [[ -f "${dir}/psql" ]] && [[ "${dir}" != "${MOCK_COMMANDS_DIR}" ]]; then
      real_psql_path="${dir}/psql"
      break
    fi
  done <<< "$(echo "${temp_path}" | tr ':' '\n')"

  if [[ -z "${real_psql_path}" ]]; then
    log_error "Real psql command not found in PATH"
    return 1
  fi

  # Get real psql directory
  local real_psql_dir
  real_psql_dir=$(dirname "${real_psql_path}")

  # Rebuild PATH: Remove ALL mock directories to ensure real commands are used
  local clean_path
  clean_path=$(echo "${PATH}" | tr ':' '\n' | grep -v "${MOCK_COMMANDS_DIR}" | grep -v "mock_commands" | grep -v "^${real_psql_dir}$" | tr '\n' ':' | sed 's/:$//')
  
  # Create a custom mock directory that only contains aria2c, wget, pgrep, mutt (not psql)
  local hybrid_mock_dir
  hybrid_mock_dir="/tmp/hybrid_mock_commands_$$"
  mkdir -p "${hybrid_mock_dir}"
  
  # Store the directory path for cleanup
  export HYBRID_MOCK_DIR="${hybrid_mock_dir}"
  
  # Copy only the mocks we want (aria2c, wget, pgrep, mutt)
  if [[ -f "${MOCK_COMMANDS_DIR}/aria2c" ]]; then
    cp "${MOCK_COMMANDS_DIR}/aria2c" "${hybrid_mock_dir}/aria2c"
    chmod +x "${hybrid_mock_dir}/aria2c"
  fi
  if [[ -f "${MOCK_COMMANDS_DIR}/wget" ]]; then
    cp "${MOCK_COMMANDS_DIR}/wget" "${hybrid_mock_dir}/wget"
    chmod +x "${hybrid_mock_dir}/wget"
  fi
  if [[ -f "${MOCK_COMMANDS_DIR}/pgrep" ]]; then
    cp "${MOCK_COMMANDS_DIR}/pgrep" "${hybrid_mock_dir}/pgrep"
    chmod +x "${hybrid_mock_dir}/pgrep"
  fi
  if [[ -f "${MOCK_COMMANDS_DIR}/mutt" ]]; then
    cp "${MOCK_COMMANDS_DIR}/mutt" "${hybrid_mock_dir}/mutt"
    chmod +x "${hybrid_mock_dir}/mutt"
  fi

  # Set PATH: hybrid mock dir first (for aria2c/wget/mutt), then real psql dir, then rest
  export PATH="${hybrid_mock_dir}:${real_psql_dir}:${clean_path}"
  hash -r 2> /dev/null || true

  # Verify we're using real psql
  local current_psql
  current_psql=$(command -v psql)
  if [[ "${current_psql}" == "${MOCK_COMMANDS_DIR}/psql" ]] || [[ "${current_psql}" == "${hybrid_mock_dir}/psql" ]]; then
    log_error "Mock psql is being used instead of real psql"
    return 1
  fi
  if [[ -z "${current_psql}" ]]; then
    log_error "psql not found in PATH"
    return 1
  fi

  # Verify mock aria2c is being used
  local current_aria2c
  current_aria2c=$(command -v aria2c)
  if [[ "${current_aria2c}" != "${hybrid_mock_dir}/aria2c" ]]; then
    log_warning "Mock aria2c not active. Current: ${current_aria2c:-unknown}, Expected: ${hybrid_mock_dir}/aria2c"
  fi

  log_success "Using real psql from: ${current_psql}"
  log_success "Using mock aria2c from: ${current_aria2c:-unknown}"
  
  return 0
}

# Function to setup environment variables
setup_environment_variables() {
  log_info "Setting up environment variables..."

  # Set logging level
  export LOG_LEVEL="${LOG_LEVEL:-INFO}"

  # Set clean flag
  export CLEAN="${CLEAN:-false}"

  # Set hybrid mock mode flags
  export HYBRID_MOCK_MODE=true
  export TEST_MODE=true

  # Database variables are loaded from properties file, do not export
  # to prevent overriding properties file values in child scripts
  # Only export PostgreSQL client variables for psql command
  if [[ -n "${DB_HOST:-}" ]]; then
    export DB_HOST="${DB_HOST}"
  else
    unset DB_HOST
  fi
  export DB_PORT="${DB_PORT}"
  if [[ -n "${DB_PASSWORD}" ]]; then
    export DB_PASSWORD="${DB_PASSWORD}"
  fi

  # DBNAME and DB_USER should already be loaded from properties file
  # But if not, load them now (fallback)
  if [[ -z "${DBNAME:-}" ]]; then
    # shellcheck disable=SC1091
    source "${PROJECT_ROOT}/etc/properties.sh"
  fi

  # PostgreSQL client variables (for psql command only)
  export PGDATABASE="${DBNAME}"
  export PGUSER="${DB_USER}"
  if [[ -n "${DB_HOST:-}" ]]; then
    export PGHOST="${DB_HOST}"
  else
    unset PGHOST
  fi
  export PGPORT="${DB_PORT}"
  if [[ -n "${DB_PASSWORD}" ]]; then
    export PGPASSWORD="${DB_PASSWORD}"
  fi

  # Disable email alerts in test mode (or use test email)
  export EMAILS="${EMAILS:-test@example.com}"
  export SEND_ALERT_EMAIL="${SEND_ALERT_EMAIL:-false}"

  # Set project base directory
  export SCRIPT_BASE_DIRECTORY="${PROJECT_ROOT}"
  export MOCK_FIXTURES_DIR="${PROJECT_ROOT}/tests/fixtures/command/extra"

  # Skip XML validation for faster execution
  export SKIP_XML_VALIDATION="${SKIP_XML_VALIDATION:-true}"

  log_success "Environment variables configured"
  log_info "  Properties file: etc/properties.sh (test version)"
  log_info "  DBNAME: ${DBNAME} (from properties file)"
  log_info "  DB_USER: ${DB_USER} (from properties file)"
  log_info "  DB_HOST: ${DB_HOST:-unix socket}"
  log_info "  DB_PORT: ${DB_PORT}"
  log_info "  LOG_LEVEL: ${LOG_LEVEL}"
}

# Function to setup test properties
# Replaces etc/properties.sh with properties_test.sh temporarily
# This ensures main scripts load test properties without knowing about test context
setup_test_properties() {
  log_info "Setting up test properties..."

  local properties_file="${PROJECT_ROOT}/etc/properties.sh"
  local test_properties_file="${PROJECT_ROOT}/etc/properties_test.sh"
  local properties_backup="${PROJECT_ROOT}/etc/properties.sh.backup"

  # Check if test properties file exists
  if [[ ! -f "${test_properties_file}" ]]; then
    log_error "Test properties file not found: ${test_properties_file}"
    return 1
  fi

  # Backup original properties file if it exists and backup doesn't exist
  if [[ -f "${properties_file}" ]] && [[ ! -f "${properties_backup}" ]]; then
    log_info "Backing up original properties file..."
    cp "${properties_file}" "${properties_backup}"
  fi

  # Replace properties.sh with properties_test.sh
  log_info "Replacing properties.sh with test properties..."
  cp "${test_properties_file}" "${properties_file}"

  log_success "Test properties configured"
}

# Function to restore original properties
restore_properties() {
  log_info "Restoring original properties..."

  local properties_file="${PROJECT_ROOT}/etc/properties.sh"
  local properties_backup="${PROJECT_ROOT}/etc/properties.sh.backup"

  # Restore original properties if backup exists
  if [[ -f "${properties_backup}" ]]; then
    log_info "Restoring original properties file..."
    mv "${properties_backup}" "${properties_file}"
    log_success "Original properties restored"
  else
    log_warning "Properties backup not found, skipping restore"
  fi
}

# Function to run notesCheckVerifier
run_notesCheckVerifier() {
  log_info "Running notesCheckVerifier.sh in hybrid mode..."

  local check_script
  check_script="${PROJECT_ROOT}/bin/monitor/notesCheckVerifier.sh"

  if [[ ! -f "${check_script}" ]]; then
    log_error "notesCheckVerifier.sh not found: ${check_script}"
    return 1
  fi

  # Make script executable
  chmod +x "${check_script}"

  # Ensure PATH is correctly set before running
  # Remove MOCK_COMMANDS_DIR from PATH to ensure real commands are used
  local clean_path
  clean_path=$(echo "${PATH}" | tr ':' '\n' | grep -v "${MOCK_COMMANDS_DIR}" | grep -v "mock_commands" | tr '\n' ':' | sed 's/:$//')
  
  # Keep HYBRID_MOCK_DIR in PATH (contains aria2c, wget, pgrep, mutt mocks)
  if [[ -n "${HYBRID_MOCK_DIR:-}" ]] && [[ -d "${HYBRID_MOCK_DIR}" ]]; then
    export PATH="${HYBRID_MOCK_DIR}:${clean_path}"
  else
    export PATH="${clean_path}"
  fi
  
  hash -r 2> /dev/null || true

  # Verify psql is real (not mock)
  local current_psql
  current_psql=$(command -v psql 2>/dev/null || true)
  if [[ -z "${current_psql}" ]]; then
    log_error "psql command not found in PATH"
    log_error "PATH: ${PATH}"
    return 1
  fi
  if [[ "${current_psql}" == *"mock_commands"* ]] || [[ "${current_psql}" == *"hybrid_mock_commands"* ]]; then
    log_error "Mock psql detected in PATH before execution: ${current_psql}"
    log_error "PATH: ${PATH}"
    return 1
  fi
  
  # Verify aria2c is mock (should be from HYBRID_MOCK_DIR)
  local current_aria2c
  current_aria2c=$(command -v aria2c 2>/dev/null || true)
  if [[ -n "${current_aria2c}" ]] && [[ "${current_aria2c}" != "${HYBRID_MOCK_DIR:-}/aria2c" ]]; then
    log_warning "aria2c is not from HYBRID_MOCK_DIR: ${current_aria2c}"
  fi

  log_info "Using real psql: ${current_psql}"
  log_info "Using mock aria2c: ${current_aria2c:-not found}"

  # Final verification: ensure PATH doesn't contain MOCK_COMMANDS_DIR
  if echo "${PATH}" | grep -q "${MOCK_COMMANDS_DIR}"; then
    log_error "MOCK_COMMANDS_DIR still in PATH after cleanup!"
    log_error "PATH: ${PATH}"
    return 1
  fi
  
  # Export PATH to ensure child processes inherit it
  export PATH
  
  # Run the script
  log_info "Executing: ${check_script}"
  "${check_script}"

  local exit_code=$?
  if [[ ${exit_code} -eq 0 ]]; then
    log_success "notesCheckVerifier.sh completed successfully"
  else
    log_error "notesCheckVerifier.sh exited with code: ${exit_code}"
  fi

  return ${exit_code}
}

# Function to cleanup
cleanup() {
  # Disable error exit temporarily for cleanup
  set +e

  log_info "Cleaning up hybrid mock environment..."

  # Restore original properties file first
  restore_properties

  # Deactivate hybrid mock environment if setup script exists
  if [[ -f "${SETUP_HYBRID_SCRIPT}" ]]; then
    set +u
    source "${SETUP_HYBRID_SCRIPT}" 2> /dev/null || true
    deactivate_hybrid_mock_environment 2> /dev/null || true
    set -u
  fi

  # Remove mock commands from PATH
  local new_path
  new_path=$(echo "${PATH}" | tr ':' '\n' | grep -v "${MOCK_COMMANDS_DIR}" | grep -v "${HYBRID_MOCK_DIR:-}" | tr '\n' ':' | sed 's/:$//')
  export PATH="${new_path}"
  hash -r 2> /dev/null || true

  # Clean up hybrid mock directory if it exists
  if [[ -n "${HYBRID_MOCK_DIR:-}" ]] && [[ -d "${HYBRID_MOCK_DIR}" ]]; then
    log_info "Cleaning up hybrid mock directory: ${HYBRID_MOCK_DIR}"
    rm -rf "${HYBRID_MOCK_DIR}" 2>/dev/null || true
  fi

  # Unset hybrid mock environment variables
  unset HYBRID_MOCK_MODE 2> /dev/null || true
  unset TEST_MODE 2> /dev/null || true
  unset HYBRID_MOCK_DIR 2> /dev/null || true

  log_success "Cleanup completed"

  # Re-enable error exit
  set -e
}

# Main function
main() {
  local exit_code=0

  # Parse arguments
  case "${1:-}" in
    --help | -h)
      show_help
      exit 0
      ;;
    "")
      # No arguments, continue
      ;;
    *)
      log_error "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac

  # Setup trap for cleanup
  trap cleanup EXIT

  # Check PostgreSQL availability
  if ! check_postgresql; then
    log_error "PostgreSQL check failed. Aborting."
    exit 1
  fi

  # Setup test properties (replace etc/properties.sh with properties_test.sh)
  # This must be done BEFORE setup_test_database() so DBNAME is available
  if ! setup_test_properties; then
    log_error "Failed to setup test properties"
    exit 1
  fi

  # Load DBNAME and DB_USER from properties file (which is now properties_test.sh)
  # shellcheck disable=SC1091
  source "${PROJECT_ROOT}/etc/properties.sh"

  # Setup test database
  if ! setup_test_database; then
    log_error "Database setup failed. Aborting."
    exit 1
  fi

  # Migrate database schema (add missing columns if needed)
  migrate_database_schema

  # Cleanup lock files before starting
  cleanup_lock_files

  # Setup hybrid mock environment
  if ! setup_hybrid_mock_environment; then
    log_error "Failed to setup hybrid mock environment"
    exit 1
  fi

  log_info "Hybrid mock environment setup completed successfully"

  # Setup environment variables
  log_info "Setting up environment variables..."
  setup_environment_variables
  log_info "Environment variables setup completed"

  # Run notesCheckVerifier
  if ! run_notesCheckVerifier; then
    log_error "notesCheckVerifier.sh execution failed"
    exit_code=$?
  fi

  exit ${exit_code}
}

# Run main function
main "$@"

