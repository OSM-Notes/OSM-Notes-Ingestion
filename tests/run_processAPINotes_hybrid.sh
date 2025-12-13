#!/bin/bash

# Script to run processAPINotes.sh in hybrid mode (real DB, mocked downloads)
# Author: Andres Gomez (AngocA)
# Version: 2025-12-13

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
Script to run processAPINotes.sh in hybrid mode (real DB, mocked downloads)

This script sets up a hybrid mock environment where:
  - Internet downloads are mocked (wget, aria2c)
  - Database operations use REAL PostgreSQL
  - All processing runs with real database but without internet downloads

The script executes processAPINotes.sh FOUR TIMES:
  1. First execution: Drops base tables, triggering processPlanetNotes.sh --base
  2. Second execution: Base tables exist, uses 5 notes for sequential processing (< 10)
  3. Third execution: Uses 20 notes for parallel processing (>= 10)
  4. Fourth execution: No new notes (empty response) - tests handling of no updates

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

# Function to clean test database using cleanupAll.sh
clean_test_database() {
 # Load DBNAME from properties file if not already loaded
 if [[ -z "${DBNAME:-}" ]]; then
  # shellcheck disable=SC1091
  source "${PROJECT_ROOT}/etc/properties.sh"
 fi

 log_info "Cleaning test database: ${DBNAME} using cleanupAll.sh"

 local psql_cmd="psql"
 if [[ -n "${DB_HOST:-}" ]]; then
  psql_cmd="${psql_cmd} -h ${DB_HOST} -p ${DB_PORT}"
 fi

 # Check if database exists - cleanupAll.sh requires database to exist
 if ! ${psql_cmd} -d "${DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
  log_info "Database ${DBNAME} does not exist, skipping cleanup"
  return 0
 fi

 local cleanup_script="${PROJECT_ROOT}/bin/cleanupAll.sh"

 if [[ ! -f "${cleanup_script}" ]]; then
  log_error "cleanupAll.sh not found: ${cleanup_script}"
  return 1
 fi

 # Make script executable
 chmod +x "${cleanup_script}"

 # Run cleanupAll.sh with full cleanup mode
 # It will use DBNAME from properties.sh (which is now properties_test.sh)
 # cleanupAll.sh will show a summary of what was cleaned
 local cleanup_output
 cleanup_output=$("${cleanup_script}" --all 2>&1)
 local cleanup_exit_code=$?

 if [[ ${cleanup_exit_code} -eq 0 ]]; then
  log_success "Database ${DBNAME} cleaned successfully using cleanupAll.sh"
  # Show cleanup summary if available
  if echo "${cleanup_output}" | grep -q "CLEANUP SUMMARY"; then
   log_info "Cleanup summary:"
   echo "${cleanup_output}" | grep -A 20 "CLEANUP SUMMARY" | while IFS= read -r line; do
    log_info "  ${line}"
   done
  fi
 else
  log_error "cleanupAll.sh failed with exit code: ${cleanup_exit_code}"
  log_error "Cleanup output:"
  echo "${cleanup_output}" | while IFS= read -r line; do
   log_error "  ${line}"
  done
  return 1
 fi
}

# Function to setup test database
setup_test_database() {
 # Load DBNAME from properties file if not already loaded
 if [[ -z "${DBNAME:-}" ]]; then
  # shellcheck disable=SC1091
  source "${PROJECT_ROOT}/etc/properties.sh"
 fi

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
   createdb -h "${DB_HOST}" -p "${DB_PORT}" "${DBNAME}" 2> /dev/null || true
  else
   createdb "${DBNAME}" 2> /dev/null || true
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

# Function to modify Germany geometry for hybrid testing
# This ensures both validation cases are tested (optimized path and full search)
modify_germany_for_hybrid_test() {
 # Load DBNAME from properties file if not already loaded
 if [[ -z "${DBNAME:-}" ]]; then
  # shellcheck disable=SC1091
  source "${PROJECT_ROOT}/etc/properties.sh"
 fi

 log_info "Modifying Germany geometry for hybrid test (to test both validation cases)..."

 local psql_cmd="psql"
 if [[ -n "${DB_HOST:-}" ]]; then
  psql_cmd="${psql_cmd} -h ${DB_HOST} -p ${DB_PORT}"
 fi

 local modify_script="${PROJECT_ROOT}/sql/analysis/modify_germany_for_hybrid_test.sql"

 if [[ ! -f "${modify_script}" ]]; then
  log_warning "Germany modification script not found: ${modify_script}"
  return 0
 fi

 # Check if Germany exists and has notes before modifying
 local germany_count
 germany_count=$(${psql_cmd} -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM countries WHERE country_id = 51477;" 2> /dev/null | grep -E '^[0-9]+$' | head -1 || echo "0")

 if [[ "${germany_count:-0}" -eq 0 ]]; then
  log_info "Germany not found in database, skipping geometry modification"
  return 0
 fi

 # Check if there are notes assigned to Germany
 local notes_count
 notes_count=$(${psql_cmd} -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM notes WHERE id_country = 51477;" 2> /dev/null | grep -E '^[0-9]+$' | head -1 || echo "0")

 if [[ "${notes_count:-0}" -eq 0 ]]; then
  log_info "No notes assigned to Germany yet, will modify after notes are assigned"
  return 0
 fi

 # Execute modification script
 if ${psql_cmd} -d "${DBNAME}" -f "${modify_script}" > /dev/null 2>&1; then
  log_success "Germany geometry modified for hybrid test"
  log_info "This ensures both validation cases are tested (optimized path and full search)"
 else
  log_warning "Germany geometry modification had warnings (this is OK if no notes in Germany)"
 fi
}

# Function to verify timestamp was updated after processing notes
verify_timestamp_updated() {
 local execution_number="${1:-}"
 local initial_timestamp="${2:-}"
 log_info "Verifying timestamp was updated after execution #${execution_number}..."
 
 # Load DBNAME from properties file if not already loaded
 if [[ -z "${DBNAME:-}" ]]; then
  # shellcheck disable=SC1091
  source "${PROJECT_ROOT}/etc/properties.sh"
 fi
 
 local psql_cmd="psql"
 if [[ -n "${DB_HOST:-}" ]]; then
  psql_cmd="${psql_cmd} -h ${DB_HOST} -p ${DB_PORT}"
 fi
 
 # Get current timestamp from max_note_timestamp
 local current_timestamp
 current_timestamp=$(${psql_cmd} -d "${DBNAME}" -Atq -c "SELECT timestamp FROM max_note_timestamp;" 2> /dev/null | head -1 || echo "")
 
 if [[ -z "${current_timestamp}" ]]; then
  log_warning "Could not retrieve timestamp from max_note_timestamp table"
  return 0 # Don't fail test, just warn
 fi
 
 # If we have an initial timestamp, compare it with the current one
 # This is the key check: if set_config(..., false) doesn't persist, the timestamp won't update
 if [[ -n "${initial_timestamp}" ]]; then
  # Get the most recent note or comment timestamp to check if there are newer notes
  local latest_note_timestamp
  latest_note_timestamp=$(${psql_cmd} -d "${DBNAME}" -Atq -c "
   SELECT MAX(timestamp) FROM (
    SELECT MAX(created_at) as timestamp FROM notes
    UNION ALL
    SELECT MAX(closed_at) as timestamp FROM notes WHERE closed_at IS NOT NULL
    UNION ALL
    SELECT MAX(created_at) as timestamp FROM note_comments
   ) t;
  " 2> /dev/null | head -1 || echo "")
  
  if [[ -z "${latest_note_timestamp}" ]]; then
   log_warning "Could not retrieve latest note/comment timestamp, skipping verification"
   return 0
  fi
  
  # Check if there are notes newer than the initial timestamp
  # If yes, the timestamp should have been updated
  local has_newer_notes
  has_newer_notes=$(${psql_cmd} -d "${DBNAME}" -Atq -c "
   SELECT CASE WHEN timestamp '${latest_note_timestamp}' > timestamp '${initial_timestamp}' THEN 1 ELSE 0 END;
  " 2> /dev/null | head -1 || echo "0")
  
  if [[ "${current_timestamp}" == "${initial_timestamp}" ]]; then
   if [[ "${has_newer_notes}" == "1" ]]; then
    # There are newer notes but timestamp wasn't updated - this is the bug we're detecting
    log_error "ERROR: max_note_timestamp was NOT updated after execution #${execution_number}"
    log_error "  Initial timestamp: ${initial_timestamp}"
    log_error "  Current timestamp: ${current_timestamp}"
    log_error "  Latest note/comment: ${latest_note_timestamp}"
    log_error "  There are newer notes, but timestamp was not updated"
    log_error "  This indicates that app.integrity_check_passed did not persist between transactions"
    log_error "  Possible cause: set_config('app.integrity_check_passed', ..., false) instead of true"
    return 1
   else
    # No newer notes, so it's OK that timestamp didn't change
    log_success "Verified: max_note_timestamp unchanged (${current_timestamp}) - no newer notes (execution #${execution_number})"
    return 0
   fi
  else
   log_success "Verified: max_note_timestamp updated from ${initial_timestamp} to ${current_timestamp} (execution #${execution_number})"
   return 0
  fi
 fi
 
 # Fallback: Compare with latest note/comment timestamp if initial timestamp not provided
 # Get the most recent note or comment timestamp
 local latest_note_timestamp
 latest_note_timestamp=$(${psql_cmd} -d "${DBNAME}" -Atq -c "
  SELECT MAX(timestamp) FROM (
   SELECT MAX(created_at) as timestamp FROM notes
   UNION ALL
   SELECT MAX(closed_at) as timestamp FROM notes WHERE closed_at IS NOT NULL
   UNION ALL
   SELECT MAX(created_at) as timestamp FROM note_comments
  ) t;
 " 2> /dev/null | head -1 || echo "")
 
 if [[ -z "${latest_note_timestamp}" ]]; then
  log_warning "Could not retrieve latest note/comment timestamp"
  return 0 # Don't fail test, just warn
 fi
 
 # Compare timestamps (max_note_timestamp should be >= latest note/comment timestamp)
 # Allow 2 seconds difference for processing time
 local timestamp_diff
 timestamp_diff=$(${psql_cmd} -d "${DBNAME}" -Atq -c "
  SELECT EXTRACT(EPOCH FROM (timestamp '${latest_note_timestamp}' - timestamp '${current_timestamp}'));
 " 2> /dev/null | head -1 || echo "0")
 
 # If latest_note_timestamp is more than 2 seconds newer than current_timestamp,
 # it means the timestamp was not updated
 if (( $(echo "${timestamp_diff} > 2" | bc -l 2> /dev/null || echo "0") )); then
  log_error "Timestamp was NOT updated correctly!"
  log_error "  max_note_timestamp: ${current_timestamp}"
  log_error "  Latest note/comment: ${latest_note_timestamp}"
  log_error "  Difference: ${timestamp_diff} seconds"
  log_error "This indicates that __updateLastValue did not update the timestamp"
  log_error "Possible causes: integrity_check_passed not persisting between transactions"
  return 1
 else
  log_success "Timestamp verified: ${current_timestamp} (latest: ${latest_note_timestamp})"
  return 0
 fi
}

# Function to verify base tables are dropped (cleanupAll.sh should have done this)
verify_base_tables_dropped() {
 # Load DBNAME from properties file if not already loaded
 if [[ -z "${DBNAME:-}" ]]; then
  # shellcheck disable=SC1091
  source "${PROJECT_ROOT}/etc/properties.sh"
 fi

 log_info "Verifying base tables are dropped (cleanupAll.sh should have done this)..."

 local psql_cmd="psql"
 if [[ -n "${DB_HOST:-}" ]]; then
  psql_cmd="${psql_cmd} -h ${DB_HOST} -p ${DB_PORT}"
 fi

 # Check if base tables exist
 local tables_exist
 tables_exist=$(${psql_cmd} -d "${DBNAME}" -tAqc \
  "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('countries', 'notes', 'note_comments', 'logs');" 2> /dev/null | grep -E '^[0-9]+$' | head -1 || echo "0")

 if [[ "${tables_exist}" -eq 0 ]]; then
  log_success "Verified: No base tables exist (ready for processPlanetNotes.sh --base)"
  return 0
 else
  log_error "ERROR: Base tables still exist after cleanupAll.sh (${tables_exist} tables found)"
  log_error "This indicates cleanupAll.sh did not clean the database correctly"
  return 1
 fi
}

# Function to cleanup lock files
# Verifies if processes are actually running before removing lock files
# Removes stale lock files if the process is not running
cleanup_lock_files() {
 log_info "Cleaning up lock files and failed execution markers..."

 # Helper function to check if lock file is stale (process not running)
 check_and_remove_stale_lock() {
  local lock_file="${1}"
  local process_name="${2:-}"

  if [[ ! -f "${lock_file}" ]]; then
   return 0
  fi

  # Try to extract PID from lock file
  local lock_pid
  lock_pid=$(grep "^PID:" "${lock_file}" 2> /dev/null | awk '{print $2}' || echo "")

  if [[ -n "${lock_pid}" ]]; then
   # Check if process is actually running
   if ps -p "${lock_pid}" > /dev/null 2>&1; then
    log_warning "Lock file ${lock_file} has active process (PID: ${lock_pid})"
    log_warning "Process ${process_name:-unknown} is still running, keeping lock file"
    return 1
   else
    log_info "Removing stale lock file: ${lock_file} (process PID ${lock_pid} not running)"
    rm -f "${lock_file}"
    return 0
   fi
  else
   # No PID found, remove lock file (stale format)
   log_info "Removing lock file without valid PID: ${lock_file}"
   rm -f "${lock_file}"
   return 0
  fi
 }

 # Clean processAPINotes lock file
 check_and_remove_stale_lock "/tmp/processAPINotes.lock" "processAPINotes"

 # Clean failed execution markers
 local failed_file="/tmp/processAPINotes_failed_execution"
 if [[ -f "${failed_file}" ]]; then
  log_info "Removing failed execution marker: ${failed_file}"
  rm -f "${failed_file}"
 fi

 # Clean processPlanetNotes lock file (in case it exists)
 check_and_remove_stale_lock "/tmp/processPlanetNotes.lock" "processPlanetNotes"

 # Clean processPlanetNotes failed execution marker (important!)
 local planet_failed="/tmp/processPlanetNotes_failed_execution"
 if [[ -f "${planet_failed}" ]]; then
  log_info "Removing planet failed execution marker: ${planet_failed}"
  rm -f "${planet_failed}"
 fi

 # Clean updateCountries lock file (important for processPlanetNotes.sh --base)
 # This is critical - updateCountries can block processPlanetNotes
 check_and_remove_stale_lock "/tmp/updateCountries.lock" "updateCountries"

 # Clean updateCountries failed execution marker
 local update_countries_failed="/tmp/updateCountries_failed_execution"
 if [[ -f "${update_countries_failed}" ]]; then
  log_info "Removing updateCountries failed execution marker: ${update_countries_failed}"
  rm -f "${update_countries_failed}"
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
 if [[ ! -f "${MOCK_COMMANDS_DIR}/wget" ]] \
  || [[ ! -f "${MOCK_COMMANDS_DIR}/aria2c" ]]; then
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
 chmod +x "${MOCK_COMMANDS_DIR}/wget" 2> /dev/null || true
 chmod +x "${MOCK_COMMANDS_DIR}/aria2c" 2> /dev/null || true
 chmod +x "${MOCK_COMMANDS_DIR}/pgrep" 2> /dev/null || true

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
 source "${SETUP_HYBRID_SCRIPT}" 2> /dev/null || true
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

 # Create a custom mock directory that only contains aria2c, wget, pgrep, ogr2ogr (not psql)
 local hybrid_mock_dir
 hybrid_mock_dir="/tmp/hybrid_mock_commands_$$"
 mkdir -p "${hybrid_mock_dir}"

 # Store the directory path for cleanup
 export HYBRID_MOCK_DIR="${hybrid_mock_dir}"

 # Copy only the mocks we want (aria2c, wget, curl, pgrep, ogr2ogr)
 if [[ -f "${MOCK_COMMANDS_DIR}/aria2c" ]]; then
  cp "${MOCK_COMMANDS_DIR}/aria2c" "${hybrid_mock_dir}/aria2c"
  chmod +x "${hybrid_mock_dir}/aria2c"
 fi
 if [[ -f "${MOCK_COMMANDS_DIR}/wget" ]]; then
  cp "${MOCK_COMMANDS_DIR}/wget" "${hybrid_mock_dir}/wget"
  chmod +x "${hybrid_mock_dir}/wget"
 fi
 if [[ -f "${MOCK_COMMANDS_DIR}/curl" ]]; then
  cp "${MOCK_COMMANDS_DIR}/curl" "${hybrid_mock_dir}/curl"
  chmod +x "${hybrid_mock_dir}/curl"
 fi
 if [[ -f "${MOCK_COMMANDS_DIR}/pgrep" ]]; then
  cp "${MOCK_COMMANDS_DIR}/pgrep" "${hybrid_mock_dir}/pgrep"
  chmod +x "${hybrid_mock_dir}/pgrep"
 fi
 # Copy ogr2ogr mock for transparent country data insertion
 # Use the mock created by setup_hybrid_mock_environment.sh (has hybrid mode logic)
 # If it doesn't exist, create it using setup_hybrid_mock_environment.sh
 if [[ ! -f "${MOCK_COMMANDS_DIR}/ogr2ogr" ]]; then
  log_info "Creating ogr2ogr mock with hybrid mode support..."
  bash "${SETUP_HYBRID_SCRIPT}" setup 2> /dev/null || true
 fi
 if [[ -f "${MOCK_COMMANDS_DIR}/ogr2ogr" ]]; then
  cp "${MOCK_COMMANDS_DIR}/ogr2ogr" "${hybrid_mock_dir}/ogr2ogr"
  chmod +x "${hybrid_mock_dir}/ogr2ogr"
 else
  log_error "Failed to create ogr2ogr mock"
  return 1
 fi

 # Set PATH: hybrid mock dir first (for aria2c/wget/curl/ogr2ogr), then real psql dir, then rest
 # This ensures mock aria2c/wget/curl/ogr2ogr are found before real ones, but real psql is found
 # (since there's no psql in hybrid_mock_dir)
 export PATH="${hybrid_mock_dir}:${real_psql_dir}:${clean_path}"
 hash -r 2> /dev/null || true

 # Export MOCK_COMMANDS_DIR so mock ogr2ogr can find real ogr2ogr if needed
 # MOCK_COMMANDS_DIR is readonly, so we just export it without reassigning
 export MOCK_COMMANDS_DIR

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

 # Verify mock ogr2ogr is being used (should be from hybrid_mock_dir)
 local current_ogr2ogr
 current_ogr2ogr=$(command -v ogr2ogr 2> /dev/null || true)
 if [[ -n "${current_ogr2ogr}" ]]; then
  if [[ "${current_ogr2ogr}" == "${hybrid_mock_dir}/ogr2ogr" ]]; then
   log_success "Using mock ogr2ogr from: ${current_ogr2ogr}"
  else
   log_warning "ogr2ogr is not from HYBRID_MOCK_DIR: ${current_ogr2ogr}"
  fi
 fi

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
# CRITICAL: All variables must be exported here so child processes (processAPINotes.sh -> processPlanetNotes.sh)
# inherit them correctly. This ensures hybrid mock mode works even when processAPINotes.sh
# spawns processPlanetNotes.sh as a child process.
setup_environment_variables() {
 log_info "Setting up environment variables..."

 # Set logging level
 export LOG_LEVEL="${LOG_LEVEL:-INFO}"

 # Set clean flag
 export CLEAN="${CLEAN:-false}"

 # Set hybrid mock mode flags (MUST be exported for child processes)
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

 # Load DBNAME and DB_USER from properties file (which is now properties_test.sh)
 # shellcheck disable=SC1091
 source "${PROJECT_ROOT}/etc/properties.sh"

 # PostgreSQL client variables (for psql command only)
 # These are used by psql, not by our scripts
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

 # Set project base directory (MUST be exported for child processes)
 export SCRIPT_BASE_DIRECTORY="${PROJECT_ROOT}"
 export MOCK_FIXTURES_DIR="${PROJECT_ROOT}/tests/fixtures/command/extra"

 # Skip XML validation for faster execution
 export SKIP_XML_VALIDATION="${SKIP_XML_VALIDATION:-true}"

 # Export hybrid mock directory paths (MUST be exported for child processes)
 # These are set by setup_hybrid_mock_environment() which is called before this function
 if [[ -n "${HYBRID_MOCK_DIR:-}" ]]; then
  export HYBRID_MOCK_DIR
 fi

 if [[ -n "${MOCK_COMMANDS_DIR:-}" ]]; then
  export MOCK_COMMANDS_DIR
 fi

 log_success "Environment variables configured"
 log_info "  Properties file: etc/properties.sh (test version)"
 log_info "  DBNAME: ${DBNAME} (from properties file)"
 log_info "  DB_USER: ${DB_USER} (from properties file)"
 log_info "  DB_HOST: ${DB_HOST:-unix socket}"
 log_info "  DB_PORT: ${DB_PORT}"
 log_info "  LOG_LEVEL: ${LOG_LEVEL}"
 log_info "  HYBRID_MOCK_MODE: ${HYBRID_MOCK_MODE}"
 log_info "  TEST_MODE: ${TEST_MODE}"
 log_info "  HYBRID_MOCK_DIR: ${HYBRID_MOCK_DIR:-not set}"
 log_info "  MOCK_COMMANDS_DIR: ${MOCK_COMMANDS_DIR:-not set}"
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
   rm -f "${HYBRID_MOCK_DIR}/bzip2" 2> /dev/null || true
  fi
  # Rebuild PATH: hybrid_mock_dir first (for aria2c/wget), then clean_path
  export PATH="${HYBRID_MOCK_DIR}:${clean_path}"
 else
  export PATH="${clean_path}"
 fi

 hash -r 2> /dev/null || true

 # Verify bzip2 is real (not mock)
 local current_bzip2
 current_bzip2=$(command -v bzip2 2> /dev/null || true)
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
 current_aria2c=$(command -v aria2c 2> /dev/null || true)
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

 # Export MOCK_NOTES_COUNT so wget mock can use it
 if [[ -n "${MOCK_NOTES_COUNT:-}" ]]; then
  export MOCK_NOTES_COUNT
  log_info "MOCK_NOTES_COUNT set to: ${MOCK_NOTES_COUNT}"
 else
  unset MOCK_NOTES_COUNT
 fi

 # Export HYBRID_MOCK_DIR so mock ogr2ogr can access it
 if [[ -n "${HYBRID_MOCK_DIR:-}" ]]; then
  export HYBRID_MOCK_DIR
 fi

 # Export MOCK_COMMANDS_DIR so mock ogr2ogr can find real ogr2ogr if needed
 export MOCK_COMMANDS_DIR

 # CRITICAL: Export all hybrid mock environment variables again here to ensure they are
 # available to child processes (processAPINotes.sh -> processPlanetNotes.sh)
 # Even though they were exported in setup_environment_variables(), we re-export here
 # to ensure they are definitely set in the current shell session before executing
 export HYBRID_MOCK_MODE="${HYBRID_MOCK_MODE:-true}"
 export TEST_MODE="${TEST_MODE:-true}"
 export SKIP_XML_VALIDATION="${SKIP_XML_VALIDATION:-true}"
 export SEND_ALERT_EMAIL="${SEND_ALERT_EMAIL:-false}"
 export SCRIPT_BASE_DIRECTORY="${SCRIPT_BASE_DIRECTORY:-${PROJECT_ROOT}}"
 export MOCK_FIXTURES_DIR="${MOCK_FIXTURES_DIR:-${PROJECT_ROOT}/tests/fixtures/command/extra}"

 # Capture initial timestamp BEFORE execution (for verification)
 # This is critical to detect if set_config(..., false) prevents timestamp update
 local initial_timestamp=""
 if [[ ${execution_number} -gt 1 ]]; then
  # Load DBNAME from properties file if not already loaded
  if [[ -z "${DBNAME:-}" ]]; then
   # shellcheck disable=SC1091
   source "${PROJECT_ROOT}/etc/properties.sh"
  fi
  local psql_cmd="psql"
  if [[ -n "${DB_HOST:-}" ]]; then
   psql_cmd="${psql_cmd} -h ${DB_HOST} -p ${DB_PORT}"
  fi
  initial_timestamp=$(${psql_cmd} -d "${DBNAME}" -Atq -c "SELECT timestamp FROM max_note_timestamp;" 2> /dev/null | head -1 || echo "")
  if [[ -n "${initial_timestamp}" ]]; then
   log_info "Initial timestamp before execution #${execution_number}: ${initial_timestamp}"
  fi
 fi

 # Run the script with clean PATH (exported so child processes inherit it)
 # All environment variables are now exported and will be inherited by processAPINotes.sh
 # and its child process processPlanetNotes.sh
 log_info "Executing: ${process_script}"
 log_info "PATH exported (first 200 chars): $(echo "${PATH}" | cut -c1-200)..."
 log_info "HYBRID_MOCK_DIR: ${HYBRID_MOCK_DIR:-not set}"
 log_info "MOCK_COMMANDS_DIR: ${MOCK_COMMANDS_DIR:-not set}"
 log_info "All hybrid mock environment variables exported for child processes"
 "${process_script}"

 local exit_code=$?
 if [[ ${exit_code} -eq 0 ]]; then
  log_success "processAPINotes.sh completed successfully (execution #${execution_number})"
  
  # Verify timestamp was updated (if notes were processed)
  # This catches issues like set_config(..., false) not persisting between transactions
  if [[ ${execution_number} -gt 1 ]] && [[ -n "${initial_timestamp}" ]]; then
   # Only verify for executions after the first (first execution may not process notes)
   # Pass initial_timestamp to detect if timestamp didn't change
   verify_timestamp_updated "${execution_number}" "${initial_timestamp}"
   local verify_exit_code=$?
   if [[ ${verify_exit_code} -ne 0 ]]; then
    exit_code=${verify_exit_code}
   fi
  fi
 else
  log_error "processAPINotes.sh exited with code: ${exit_code} (execution #${execution_number})"
 fi

 return ${exit_code}
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

# Function to cleanup
# This function is idempotent and can be called multiple times safely
cleanup() {
 # Prevent multiple simultaneous cleanup executions
 if [[ "${CLEANUP_IN_PROGRESS:-false}" == "true" ]]; then
  return 0
 fi
 export CLEANUP_IN_PROGRESS=true

 # Disable error exit temporarily for cleanup
 set +e

 log_info "Cleaning up hybrid mock environment..."

 # Restore original properties file first (most important)
 restore_properties

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
  rm -rf "${HYBRID_MOCK_DIR}" 2> /dev/null || true
 fi

 # Unset hybrid mock environment variables
 unset HYBRID_MOCK_MODE 2> /dev/null || true
 unset TEST_MODE 2> /dev/null || true
 unset HYBRID_MOCK_DIR 2> /dev/null || true

 log_success "Cleanup completed"

 # Re-enable error exit
 set -e
 export CLEANUP_IN_PROGRESS=false
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

 # Setup trap for cleanup BEFORE making any changes
 # Capture EXIT, SIGINT (Ctrl+C), and SIGTERM to ensure cleanup always runs
 trap cleanup EXIT SIGINT SIGTERM

 # Check PostgreSQL availability
 if ! check_postgresql; then
  log_error "PostgreSQL check failed. Aborting."
  exit 1
 fi

 # Setup test properties FIRST (replace etc/properties.sh with properties_test.sh)
 # This must be done before setup_test_database() which needs DBNAME
 if ! setup_test_properties; then
  log_error "Failed to setup test properties"
  exit 1
 fi

 # Clean test database first (drop and recreate to ensure clean state)
 # This ensures the database is completely empty before first execution
 clean_test_database

 # Setup test database (now DBNAME is available from properties_test.sh)
 if ! setup_test_database; then
  log_error "Database setup failed. Aborting."
  exit 1
 fi

 # DO NOT migrate database schema here - tables don't exist yet
 # Migration will happen after processPlanetNotes.sh --base creates the tables

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

 # First execution: Ensure base tables don't exist to trigger processPlanetNotes.sh --base
 log_info "=== FIRST EXECUTION: Will load processPlanetNotes.sh --base ==="

 # Clean up any failed execution markers before running processPlanetNotes
 cleanup_lock_files

 # Verify base tables are dropped (cleanupAll.sh should have done this)
 # This is a safety check to ensure processAPINotes.sh will detect missing tables
 if ! verify_base_tables_dropped; then
  log_error "Base tables still exist after cleanupAll.sh. Cannot proceed with first execution."
  log_error "This will cause processAPINotes to incorrectly detect tables as existing"
  return 1
 fi

 # Use default fixture (original OSM-notes-API.xml) for first execution
 unset MOCK_NOTES_COUNT
 export MOCK_NOTES_COUNT=""

 # Run processAPINotes (first time - will call processPlanetNotes.sh --base)
 # This will detect missing base tables and execute processPlanetNotes.sh --base
 if ! run_processAPINotes 1; then
  log_error "First execution failed"
  exit_code=$?
  exit ${exit_code}
 fi

 # After first execution, base tables should exist (created by processPlanetNotes.sh --base)
 # Wait a moment between executions
 sleep 2

 # Second execution: Base tables exist, use 5 notes for sequential processing
 log_info "=== SECOND EXECUTION: Sequential processing (< 10 notes) ==="
 cleanup_lock_files

 # Set MOCK_NOTES_COUNT to 5 for sequential processing (below MIN_NOTES_FOR_PARALLEL=10)
 export MOCK_NOTES_COUNT="5"
 log_info "Using ${MOCK_NOTES_COUNT} notes for sequential processing test"

 # Run processAPINotes (second time - tables exist, sequential processing)
 if ! run_processAPINotes 2; then
  log_error "Second execution failed"
  exit_code=$?
 fi

 # Modify Germany geometry for hybrid testing after notes have been assigned
 # This ensures both validation cases are tested (optimized path and full search)
 modify_germany_for_hybrid_test

 # Wait a moment between executions
 sleep 2

  # Third execution: Use 20 notes for sequential processing
  log_info "=== THIRD EXECUTION: Sequential processing (>= 10 notes) ==="
  cleanup_lock_files

  # Set MOCK_NOTES_COUNT to 20 for sequential processing
  export MOCK_NOTES_COUNT="20"
  log_info "Using ${MOCK_NOTES_COUNT} notes for sequential processing test"

  # Run processAPINotes (third time - sequential processing)
 if ! run_processAPINotes 3; then
  log_error "Third execution failed"
  exit_code=$?
 fi

 # Wait a moment between executions
 sleep 2

 # Fourth execution: No new notes (empty response)
 log_info "=== FOURTH EXECUTION: No new notes (empty response) ==="
 cleanup_lock_files

 # Set MOCK_NOTES_COUNT to 0 for empty response (no new notes)
 export MOCK_NOTES_COUNT="0"
 log_info "Using ${MOCK_NOTES_COUNT} notes to simulate no new notes scenario"

 # Run processAPINotes (fourth time - no new notes)
 if ! run_processAPINotes 4; then
  log_error "Fourth execution failed"
  exit_code=$?
 fi

 exit ${exit_code}
}

# Run main function
main "$@"
