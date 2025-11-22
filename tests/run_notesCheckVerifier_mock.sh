#!/bin/bash

# Script to run notesCheckVerifier.sh in full mock mode (no internet, no real DB)
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
Script to run notesCheckVerifier.sh in full mock mode

This script sets up a complete mock environment where:
  - Internet downloads are mocked (wget, aria2c)
  - Database operations are mocked (psql)
  - Email sending is mocked (mutt)
  - All processing runs without external dependencies

Usage:
  ./run_notesCheckVerifier_mock.sh [OPTIONS]

Options:
  --help, -h     Show this help message

Environment variables:
  LOG_LEVEL      Logging level (TRACE, DEBUG, INFO, WARN, ERROR, FATAL)
                 Default: INFO
  CLEAN          Clean temporary files after execution (true/false)
                 Default: false
  EMAILS         Email addresses for reports (comma-separated)
                 Default: test@example.com

Examples:
  # Run with default settings
  ./run_notesCheckVerifier_mock.sh

  # Run with debug logging
  LOG_LEVEL=DEBUG ./run_notesCheckVerifier_mock.sh

  # Run and clean temporary files
  CLEAN=true ./run_notesCheckVerifier_mock.sh
EOF
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
     [[ ! -f "${MOCK_COMMANDS_DIR}/aria2c" ]] || \
     [[ ! -f "${MOCK_COMMANDS_DIR}/mutt" ]]; then
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

  # Database variables are loaded from properties file, do not export
  # to prevent overriding properties file values in child scripts
  # The properties file will be replaced with properties_test.sh before execution

  # Disable email alerts in mock mode (or use test email)
  export EMAILS="${EMAILS:-test@example.com}"
  export SEND_ALERT_EMAIL="${SEND_ALERT_EMAIL:-false}"

  # Set project base directory
  export SCRIPT_BASE_DIRECTORY="${PROJECT_ROOT}"

  # Skip XML validation for faster execution
  export SKIP_XML_VALIDATION="${SKIP_XML_VALIDATION:-true}"

  log_success "Environment variables configured"
}

# Function to run notesCheckVerifier
run_notesCheckVerifier() {
  log_info "Running notesCheckVerifier.sh in mock mode..."

  local check_script
  check_script="${PROJECT_ROOT}/bin/monitor/notesCheckVerifier.sh"

  if [[ ! -f "${check_script}" ]]; then
    log_error "notesCheckVerifier.sh not found: ${check_script}"
    return 1
  fi

  # Make script executable
  chmod +x "${check_script}"

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
# This function is idempotent and can be called multiple times safely
cleanup() {
  # Prevent multiple simultaneous cleanup executions
  if [[ "${CLEANUP_IN_PROGRESS:-false}" == "true" ]]; then
    return 0
  fi
  export CLEANUP_IN_PROGRESS=true

  log_info "Cleaning up mock environment..."

  # Restore original properties file first (most important)
  restore_properties

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

  # Cleanup lock files before starting
  cleanup_lock_files

  # Setup mock environment
  if ! setup_mock_environment; then
    log_error "Failed to setup mock environment"
    exit 1
  fi

  # Setup test properties (replace etc/properties.sh with properties_test.sh)
  if ! setup_test_properties; then
    log_error "Failed to setup test properties"
    exit 1
  fi

  # Setup environment variables
  setup_environment_variables

  # Run notesCheckVerifier
  if ! run_notesCheckVerifier; then
    log_error "notesCheckVerifier.sh execution failed"
    exit_code=$?
  fi

  exit ${exit_code}
}

# Run main function
main "$@"

