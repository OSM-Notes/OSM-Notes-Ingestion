#!/bin/bash

# Script to run processAPINotes.sh in full mock mode (no internet, no real DB)
# Author: Andres Gomez (AngocA)
# Version: 2025-11-12

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

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
SETUP_MOCK_SCRIPT="${SCRIPT_DIR}/setup_mock_environment.sh"
readonly SETUP_MOCK_SCRIPT

# Function to show help
show_help() {
  cat << 'EOF'
Script to run processAPINotes.sh in full mock mode

This script sets up a complete mock environment where:
  - Internet downloads are mocked (wget, aria2c)
  - Database operations are mocked (psql)
  - All processing runs without external dependencies

The script executes processAPINotes.sh FOUR TIMES:
  1. First execution: Resets base tables marker, triggering processPlanetNotes.sh --base
  2. Second execution: Base tables exist, uses 5 notes for sequential processing (< 10)
  3. Third execution: Uses 20 notes for parallel processing (>= 10)
  4. Fourth execution: No new notes (empty response) - tests handling of no updates

Usage:
  ./run_processAPINotes_mock.sh [OPTIONS]

Options:
  --help, -h     Show this help message

Environment variables:
  LOG_LEVEL      Logging level (TRACE, DEBUG, INFO, WARN, ERROR, FATAL)
                 Default: INFO
  CLEAN          Clean temporary files after execution (true/false)
                 Default: false

Examples:
  # Run with default settings (four executions)
  ./run_processAPINotes_mock.sh

  # Run with debug logging
  LOG_LEVEL=DEBUG ./run_processAPINotes_mock.sh

  # Run and clean temporary files
  CLEAN=true ./run_processAPINotes_mock.sh
EOF
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

  # Clean failed execution marker
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

  log_success "Lock files cleaned"
}

# Function to reset base tables marker (simulates first run)
reset_base_tables_marker() {
  log_info "Resetting base tables marker to simulate first run (tables don't exist)"
  local base_tables_marker="/tmp/osm_notes_base_tables_created"
  if [[ -f "${base_tables_marker}" ]]; then
    rm -f "${base_tables_marker}"
    log_info "Base tables marker removed - processPlanetNotes.sh --base will be called"
  else
    log_info "Base tables marker already absent - processPlanetNotes.sh --base will be called"
  fi
}

# Function to setup mock environment
setup_mock_environment() {
  log_info "Setting up mock environment..."

  # Setup mock commands
  if [[ ! -f "${SETUP_MOCK_SCRIPT}" ]]; then
    log_error "Mock setup script not found: ${SETUP_MOCK_SCRIPT}"
    return 1
  fi

  # Create mock commands if they don't exist
  if [[ ! -f "${MOCK_COMMANDS_DIR}/psql" ]] || \
     [[ ! -f "${MOCK_COMMANDS_DIR}/wget" ]] || \
     [[ ! -f "${MOCK_COMMANDS_DIR}/aria2c" ]]; then
    log_info "Creating mock commands..."
    bash "${SETUP_MOCK_SCRIPT}" setup
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


  # Activate mock environment
  log_info "Activating mock environment..."
  bash "${SETUP_MOCK_SCRIPT}" activate

  # Add mock commands to PATH (ensure they're first)
  export PATH="${MOCK_COMMANDS_DIR}:${PATH}"
  hash -r 2> /dev/null || true

  # Verify mock commands are in PATH
  local psql_path
  psql_path=$(command -v psql 2> /dev/null || true)
  if [[ "${psql_path}" != "${MOCK_COMMANDS_DIR}/psql" ]]; then
    log_warning "Mock psql not detected. Current path: ${psql_path:-unknown}"
  fi

  log_success "Mock environment activated"
}

# Function to setup environment variables
setup_environment_variables() {
  log_info "Setting up environment variables..."

  # Set logging level
  export LOG_LEVEL="${LOG_LEVEL:-INFO}"

  # Set clean flag
  export CLEAN="${CLEAN:-false}"

  # Set mock mode flags
  export MOCK_MODE=true
  export TEST_MODE=true

  # Set database variables for mock
  export DBNAME="${DBNAME:-mock_db}"
  export DB_USER="${DB_USER:-mock_user}"
  export DB_PASSWORD="${DB_PASSWORD:-mock_password}"

  # Disable email alerts in mock mode
  export SEND_ALERT_EMAIL="${SEND_ALERT_EMAIL:-false}"

  # Set project base directory
  export SCRIPT_BASE_DIRECTORY="${PROJECT_ROOT}"

  log_success "Environment variables configured"
}

# Function to run processAPINotes
run_processAPINotes() {
  local execution_number="${1:-1}"
  log_info "Running processAPINotes.sh in mock mode (execution #${execution_number})..."

  local process_script
  process_script="${PROJECT_ROOT}/bin/process/processAPINotes.sh"

  if [[ ! -f "${process_script}" ]]; then
    log_error "processAPINotes.sh not found: ${process_script}"
    return 1
  fi

  # Make script executable
  chmod +x "${process_script}"

  # Export MOCK_NOTES_COUNT so wget mock can use it
  if [[ -n "${MOCK_NOTES_COUNT:-}" ]]; then
    export MOCK_NOTES_COUNT
    log_info "MOCK_NOTES_COUNT set to: ${MOCK_NOTES_COUNT}"
  else
    unset MOCK_NOTES_COUNT
  fi

  # Run the script
  log_info "Executing: ${process_script}"
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
  log_info "Cleaning up mock environment..."

  # Deactivate mock environment if setup script exists
  if [[ -f "${SETUP_MOCK_SCRIPT}" ]]; then
    bash "${SETUP_MOCK_SCRIPT}" deactivate 2> /dev/null || true
  fi

  # Remove mock commands from PATH
  local new_path
  new_path=$(echo "${PATH}" | sed "s|${MOCK_COMMANDS_DIR}:||g")
  export PATH="${new_path}"
  hash -r 2> /dev/null || true

  # Unset mock environment variables
  unset MOCK_MODE
  unset TEST_MODE

  log_success "Cleanup completed"
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

  # Cleanup lock files before starting
  cleanup_lock_files

  # Setup mock environment
  if ! setup_mock_environment; then
    log_error "Failed to setup mock environment"
    exit 1
  fi

  # Setup environment variables
  setup_environment_variables

  # First execution: Reset base tables marker to trigger processPlanetNotes.sh --base
  log_info "=== FIRST EXECUTION: Will load processPlanetNotes.sh --base ==="
  cleanup_lock_files
  reset_base_tables_marker

  # Use default fixture (original OSM-notes-API.xml) for first execution
  unset MOCK_NOTES_COUNT
  export MOCK_NOTES_COUNT=""

  # Run processAPINotes (first time - will call processPlanetNotes.sh --base)
  if ! run_processAPINotes 1; then
    log_error "First execution failed"
    exit_code=$?
    exit ${exit_code}
  fi

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

  # Wait a moment between executions
  sleep 2

  # Third execution: Use 20 notes for parallel processing
  log_info "=== THIRD EXECUTION: Parallel processing (>= 10 notes) ==="
  cleanup_lock_files

  # Set MOCK_NOTES_COUNT to 20 for parallel processing (above MIN_NOTES_FOR_PARALLEL=10)
  export MOCK_NOTES_COUNT="20"
  log_info "Using ${MOCK_NOTES_COUNT} notes for parallel processing test"

  # Run processAPINotes (third time - parallel processing)
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

