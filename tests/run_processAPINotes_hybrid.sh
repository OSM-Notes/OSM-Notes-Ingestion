#!/bin/bash

# Script to run processAPINotes.sh in hybrid mode (real DB, mocked downloads)
# Author: Andres Gomez (AngocA)
# Version: 2025-01-23

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

# Database configuration (can be overridden with environment variables)
DBNAME="${DBNAME:-osm-notes-test}"
DB_USER="${DB_USER:-${USER}}"
DB_HOST="${DB_HOST:-}"
DB_PORT="${DB_PORT:-5432}"
DB_PASSWORD="${DB_PASSWORD:-}"

# Function to show help
show_help() {
  cat << 'EOF'
Script to run processAPINotes.sh in hybrid mode (real DB, mocked downloads)

This script sets up a hybrid mock environment where:
  - Internet downloads are mocked (wget, aria2c)
  - Database operations use REAL PostgreSQL
  - All processing runs with real database but without internet downloads

The script executes processAPINotes.sh TWICE:
  1. First execution: Drops base tables, triggering processPlanetNotes.sh --base
  2. Second execution: Base tables exist, so only processAPINotes runs

Usage:
  ./run_processAPINotes_hybrid.sh [OPTIONS]

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

Examples:
  # Run with default settings (two executions)
  ./run_processAPINotes_hybrid.sh

  # Run with custom database
  DBNAME=my_test_db DB_USER=postgres ./run_processAPINotes_hybrid.sh

  # Run with debug logging
  LOG_LEVEL=DEBUG ./run_processAPINotes_hybrid.sh

  # Run and clean temporary files
  CLEAN=true ./run_processAPINotes_hybrid.sh
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

# Function to drop base tables (for first execution)
drop_base_tables() {
  log_info "Dropping base tables to trigger processPlanetNotes.sh --base..."

  local psql_cmd="psql"
  if [[ -n "${DB_HOST:-}" ]]; then
    psql_cmd="${psql_cmd} -h ${DB_HOST} -p ${DB_PORT}"
  fi

  # Check if base tables exist
  local tables_exist
  tables_exist=$(${psql_cmd} -d "${DBNAME}" -tAc \
    "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('countries', 'notes', 'note_comments', 'logs', 'tries');" 2>/dev/null || echo "0")

  if [[ "${tables_exist}" -gt 0 ]]; then
    log_info "Base tables exist, dropping them..."
    # Drop base tables (notes, note_comments, users, logs, etc.)
    ${psql_cmd} -d "${DBNAME}" -f "${PROJECT_ROOT}/sql/process/processPlanetNotes_13_dropBaseTables.sql" > /dev/null 2>&1 || true
    # Drop country tables (countries, tries)
    ${psql_cmd} -d "${DBNAME}" -c "DROP TABLE IF EXISTS tries CASCADE; DROP TABLE IF EXISTS countries CASCADE;" > /dev/null 2>&1 || true
    log_success "Base tables dropped"
  else
    log_info "Base tables don't exist (already clean)"
  fi
}

# Function to cleanup lock files
cleanup_lock_files() {
  log_info "Cleaning up lock files and failed execution markers..."

  # Clean processAPINotes lock file
  local lock_file="/tmp/processAPINotes.lock"
  if [[ -f "${lock_file}" ]]; then
    log_info "Removing lock file: ${lock_file}"
    rm -f "${lock_file}"
  fi

  # Clean failed execution markers
  local failed_file="/tmp/processAPINotes_failed_execution"
  if [[ -f "${failed_file}" ]]; then
    log_info "Removing failed execution marker: ${failed_file}"
    rm -f "${failed_file}"
  fi

  # Clean processPlanetNotes lock file (in case it exists)
  local planet_lock="/tmp/processPlanetNotes.lock"
  if [[ -f "${planet_lock}" ]]; then
    log_info "Removing planet lock file: ${planet_lock}"
    rm -f "${planet_lock}"
  fi

  # Clean processPlanetNotes failed execution marker (important!)
  local planet_failed="/tmp/processPlanetNotes_failed_execution"
  if [[ -f "${planet_failed}" ]]; then
    log_info "Removing planet failed execution marker: ${planet_failed}"
    rm -f "${planet_failed}"
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

  # Ensure all mock commands are executable
  chmod +x "${MOCK_COMMANDS_DIR}/wget" 2>/dev/null || true
  chmod +x "${MOCK_COMMANDS_DIR}/aria2c" 2>/dev/null || true
  chmod +x "${MOCK_COMMANDS_DIR}/pgrep" 2>/dev/null || true

  # DO NOT add MOCK_COMMANDS_DIR to PATH here - it will be handled by ensure_real_psql
  # which creates a hybrid_mock_dir with only the mocks we need

  # Verify mock aria2c exists and is executable
  if [[ ! -f "${MOCK_COMMANDS_DIR}/aria2c" ]]; then
    log_error "Mock aria2c not found at ${MOCK_COMMANDS_DIR}/aria2c"
    return 1
  fi
  if [[ ! -x "${MOCK_COMMANDS_DIR}/aria2c" ]]; then
    log_warning "Mock aria2c is not executable, fixing..."
    chmod +x "${MOCK_COMMANDS_DIR}/aria2c"
  fi

  # Source setup script (but don't activate yet - we'll do that after ensure_real_psql)
  # Temporarily disable set -e and set -u to avoid exiting on errors in sourced script
  set +eu
  # Source the script (errors about readonly variables are handled by the setup script itself)
  source "${SETUP_HYBRID_SCRIPT}" 2>/dev/null || true
  set -eu

  # Ensure real psql is used (not mock) - this creates hybrid_mock_dir and sets PATH correctly
  # This MUST be done before activate_hybrid_mock_environment to avoid adding MOCK_COMMANDS_DIR to PATH
  if ! ensure_real_psql; then
    log_error "Failed to ensure real psql is used"
    return 1
  fi

  # Now verify that aria2c mock is active (should be from hybrid_mock_dir)
  local aria2c_path
  aria2c_path=$(command -v aria2c 2> /dev/null || true)
  if [[ "${aria2c_path}" == "${HYBRID_MOCK_DIR:-}/aria2c" ]]; then
    log_success "Mock aria2c is active: ${aria2c_path}"
  elif [[ -n "${HYBRID_MOCK_DIR:-}" ]] && [[ -f "${HYBRID_MOCK_DIR}/aria2c" ]]; then
    log_warning "Mock aria2c not in PATH but exists at ${HYBRID_MOCK_DIR}/aria2c"
    log_warning "PATH: ${PATH}"
  else
    log_warning "Mock aria2c not detected. Current path: ${aria2c_path:-unknown}"
  fi

  # Final verification: ensure PATH doesn't contain MOCK_COMMANDS_DIR
  # (only hybrid_mock_dir should be in PATH)
  if echo "${PATH}" | grep -q "${MOCK_COMMANDS_DIR}"; then
    log_warning "MOCK_COMMANDS_DIR still in PATH, removing it..."
    local final_path
    final_path=$(echo "${PATH}" | tr ':' '\n' | grep -v "${MOCK_COMMANDS_DIR}" | tr '\n' ':' | sed 's/:$//')
    export PATH="${final_path}"
    hash -r 2> /dev/null || true
  fi

  log_success "Hybrid mock environment activated"
  return 0
}

# Function to ensure real psql is used (not mock)
# This function ensures psql is real while keeping aria2c and wget mocks active
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
  # This ensures:
  # 1. Real psql is found before mock psql (if it exists)
  # 2. Mock aria2c/wget are found before real ones (from hybrid_mock_dir)
  # 3. Real bzip2 is used (not mock)
  local clean_path
  clean_path=$(echo "${PATH}" | tr ':' '\n' | grep -v "${MOCK_COMMANDS_DIR}" | grep -v "mock_commands" | grep -v "^${real_psql_dir}$" | tr '\n' ':' | sed 's/:$//')
  
  # Create a custom mock directory that only contains aria2c, wget, pgrep (not psql)
  local hybrid_mock_dir
  hybrid_mock_dir="/tmp/hybrid_mock_commands_$$"
  mkdir -p "${hybrid_mock_dir}"
  
  # Store the directory path for cleanup
  export HYBRID_MOCK_DIR="${hybrid_mock_dir}"
  
  # Copy only the mocks we want (aria2c, wget, pgrep)
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

  # Set PATH: hybrid mock dir first (for aria2c/wget), then real psql dir, then rest
  # This ensures mock aria2c/wget are found before real ones, but real psql is found
  # (since there's no psql in hybrid_mock_dir)
  export PATH="${hybrid_mock_dir}:${real_psql_dir}:${clean_path}"
  hash -r 2> /dev/null || true

  # Verify we're using real psql (should find it in real_psql_dir since hybrid_mock_dir has no psql)
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

  # Verify mock aria2c is being used (should be from hybrid_mock_dir)
  local current_aria2c
  current_aria2c=$(command -v aria2c)
  if [[ "${current_aria2c}" != "${hybrid_mock_dir}/aria2c" ]]; then
    log_error "Mock aria2c not active. Current: ${current_aria2c:-unknown}, Expected: ${hybrid_mock_dir}/aria2c"
    log_error "PATH: ${PATH}"
    return 1
  fi

  log_success "Using real psql from: ${current_psql}"
  log_success "Using mock aria2c from: ${current_aria2c}"
  
  # Verify real bzip2 is being used (should NOT be from mock directories)
  local current_bzip2
  current_bzip2=$(command -v bzip2)
  if [[ "${current_bzip2}" == "${MOCK_COMMANDS_DIR}/bzip2" ]] || [[ "${current_bzip2}" == "${hybrid_mock_dir}/bzip2" ]]; then
    log_error "Mock bzip2 is being used instead of real bzip2: ${current_bzip2}"
    return 1
  fi
  log_success "Using real bzip2 from: ${current_bzip2}"
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

  # Set database variables
  export DBNAME="${DBNAME}"
  export DB_USER="${DB_USER}"
  if [[ -n "${DB_HOST:-}" ]]; then
    export DB_HOST="${DB_HOST}"
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
  if [[ -n "${DB_HOST:-}" ]]; then
    export PGHOST="${DB_HOST}"
  else
    unset PGHOST
  fi
  export PGPORT="${DB_PORT}"
  if [[ -n "${DB_PASSWORD}" ]]; then
    export PGPASSWORD="${DB_PASSWORD}"
  fi

  # Disable email alerts in test mode
  export SEND_ALERT_EMAIL="${SEND_ALERT_EMAIL:-false}"

  # Set project base directory
  export SCRIPT_BASE_DIRECTORY="${PROJECT_ROOT}"

  # Skip XML validation for faster execution
  export SKIP_XML_VALIDATION="${SKIP_XML_VALIDATION:-true}"

  log_success "Environment variables configured"
  log_info "  DBNAME: ${DBNAME}"
  log_info "  DB_USER: ${DB_USER}"
  log_info "  DB_HOST: ${DB_HOST:-unix socket}"
  log_info "  DB_PORT: ${DB_PORT}"
  log_info "  LOG_LEVEL: ${LOG_LEVEL}"
}

# Function to run processAPINotes
run_processAPINotes() {
  local execution_number="${1:-1}"
  log_info "Running processAPINotes.sh in hybrid mode (execution #${execution_number})..."

  local process_script
  process_script="${PROJECT_ROOT}/bin/process/processAPINotes.sh"

  if [[ ! -f "${process_script}" ]]; then
    log_error "processAPINotes.sh not found: ${process_script}"
    return 1
  fi

  # Make script executable
  chmod +x "${process_script}"

  # Ensure PATH is correctly set before running (verify bzip2 is real)
  # Remove MOCK_COMMANDS_DIR from PATH to ensure real commands are used
  local clean_path
  clean_path=$(echo "${PATH}" | tr ':' '\n' | grep -v "${MOCK_COMMANDS_DIR}" | grep -v "mock_commands" | tr '\n' ':' | sed 's/:$//')
  
  # Keep HYBRID_MOCK_DIR in PATH (contains aria2c, wget, pgrep mocks)
  # but ensure it doesn't contain bzip2
  if [[ -n "${HYBRID_MOCK_DIR:-}" ]] && [[ -d "${HYBRID_MOCK_DIR}" ]]; then
    # Check if hybrid_mock_dir has bzip2 (it shouldn't)
    if [[ -f "${HYBRID_MOCK_DIR}/bzip2" ]]; then
      log_error "HYBRID_MOCK_DIR contains bzip2 mock, which should not exist"
      rm -f "${HYBRID_MOCK_DIR}/bzip2" 2>/dev/null || true
    fi
    # Rebuild PATH: hybrid_mock_dir first (for aria2c/wget), then clean_path
    export PATH="${HYBRID_MOCK_DIR}:${clean_path}"
  else
    export PATH="${clean_path}"
  fi
  
  hash -r 2> /dev/null || true

  # Verify bzip2 is real (not mock)
  local current_bzip2
  current_bzip2=$(command -v bzip2 2>/dev/null || true)
  if [[ -z "${current_bzip2}" ]]; then
    log_error "bzip2 command not found in PATH"
    log_error "PATH: ${PATH}"
    return 1
  fi
  if [[ "${current_bzip2}" == *"mock_commands"* ]] || [[ "${current_bzip2}" == *"hybrid_mock_commands"* ]]; then
    log_error "Mock bzip2 detected in PATH before execution: ${current_bzip2}"
    log_error "PATH: ${PATH}"
    return 1
  fi
  
  # Verify aria2c is mock (should be from HYBRID_MOCK_DIR)
  local current_aria2c
  current_aria2c=$(command -v aria2c 2>/dev/null || true)
  if [[ -n "${current_aria2c}" ]] && [[ "${current_aria2c}" != "${HYBRID_MOCK_DIR:-}/aria2c" ]]; then
    log_warning "aria2c is not from HYBRID_MOCK_DIR: ${current_aria2c}"
  fi

  log_info "Using real bzip2: ${current_bzip2}"
  log_info "Using mock aria2c: ${current_aria2c:-not found}"

  # Final verification: ensure PATH doesn't contain MOCK_COMMANDS_DIR
  # This is critical: processPlanetNotes.sh must use real bzip2, not mock
  if echo "${PATH}" | grep -q "${MOCK_COMMANDS_DIR}"; then
    log_error "MOCK_COMMANDS_DIR still in PATH after cleanup!"
    log_error "PATH: ${PATH}"
    return 1
  fi
  
  # Export PATH to ensure child processes inherit it
  # This is critical: processPlanetNotes.sh must use real bzip2, not mock
  export PATH
  
  # Also export bzip2 path as a fallback (some scripts may check this)
  if [[ -n "${current_bzip2}" ]]; then
    export BZIP2="${current_bzip2}"
  fi

  # Run the script with clean PATH (exported so child processes inherit it)
  log_info "Executing: ${process_script}"
  log_info "PATH exported (first 200 chars): $(echo "${PATH}" | cut -c1-200)..."
  "${process_script}"

  local exit_code=$?
  if [[ ${exit_code} -eq 0 ]]; then
    log_success "processAPINotes.sh completed successfully (execution #${execution_number})"
  else
    log_error "processAPINotes.sh exited with code: ${exit_code} (execution #${execution_number})"
  fi

  return ${exit_code}
}

# Function to cleanup
cleanup() {
  # Disable error exit temporarily for cleanup
  set +e

  log_info "Cleaning up hybrid mock environment..."

  # Deactivate hybrid mock environment if setup script exists
  if [[ -f "${SETUP_HYBRID_SCRIPT}" ]]; then
    # Temporarily disable set -u to avoid errors with unset variables
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

  # Setup test database
  if ! setup_test_database; then
    log_error "Database setup failed. Aborting."
    exit 1
  fi

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

  # First execution: Drop base tables to trigger processPlanetNotes.sh --base
  log_info "=== FIRST EXECUTION: Will load processPlanetNotes.sh --base ==="
  
  # Clean up any failed execution markers before running processPlanetNotes
  cleanup_lock_files
  
  drop_base_tables

  # Run processAPINotes (first time - will call processPlanetNotes.sh --base)
  if ! run_processAPINotes 1; then
    log_error "First execution failed"
    exit_code=$?
    exit ${exit_code}
  fi

  # Wait a moment between executions
  sleep 2

  # Second execution: Base tables exist, so only processAPINotes runs
  log_info "=== SECOND EXECUTION: Only processAPINotes (no processPlanetNotes) ==="
  cleanup_lock_files

  # Run processAPINotes (second time - tables exist, no processPlanetNotes call)
  if ! run_processAPINotes 2; then
    log_error "Second execution failed"
    exit_code=$?
  fi

  exit ${exit_code}
}

# Run main function
main "$@"

