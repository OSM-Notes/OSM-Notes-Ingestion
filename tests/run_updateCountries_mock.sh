#!/bin/bash

# Script to run updateCountries.sh in full mock mode (no internet, no real DB)
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
Script to run updateCountries.sh in full mock mode

This script sets up a complete mock environment where:
  - Internet downloads are mocked (curl, aria2c)
  - Database operations are mocked (psql)
  - Geographic conversions are mocked (osmtogeojson, ogr2ogr)
  - All processing runs without external dependencies

The script executes updateCountries.sh in two modes:
  1. First execution: --base mode (drops and recreates tables)
  2. Second execution: Update mode (normal monthly update)

Usage:
  ./run_updateCountries_mock.sh [OPTIONS]

Options:
  --help, -h     Show this help message

Environment variables:
  LOG_LEVEL      Logging level (TRACE, DEBUG, INFO, WARN, ERROR, FATAL)
                 Default: INFO
  CLEAN          Clean temporary files after execution (true/false)
                 Default: false

Examples:
  # Run with default settings (two executions)
  ./run_updateCountries_mock.sh

  # Run with debug logging
  LOG_LEVEL=DEBUG ./run_updateCountries_mock.sh

  # Run and clean temporary files
  CLEAN=true ./run_updateCountries_mock.sh
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

  # Clean updateCountries lock file
  local lock_file="/tmp/updateCountries.lock"
  if [[ -f "${lock_file}" ]]; then
    log_info "Removing lock file: ${lock_file}"
    rm -f "${lock_file}"
  fi

  # Clean failed execution marker
  local failed_file="/tmp/updateCountries_failed_execution"
  if [[ -f "${failed_file}" ]]; then
    log_info "Removing failed execution marker: ${failed_file}"
    rm -f "${failed_file}"
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
     [[ ! -f "${MOCK_COMMANDS_DIR}/curl" ]] || \
     [[ ! -f "${MOCK_COMMANDS_DIR}/osmtogeojson" ]]; then
    log_info "Creating mock commands..."
    bash "${SETUP_MOCK_SCRIPT}" setup
  fi

  # Create ogr2ogr mock only for full mock mode (when DB is mocked)
  # ogr2ogr is needed to "import" GeoJSON to mocked database
  if [[ ! -f "${MOCK_COMMANDS_DIR}/ogr2ogr" ]]; then
    log_info "Creating mock ogr2ogr for full mock mode..."
    # Create ogr2ogr mock inline (since we're in full mock mode)
    cat > "${MOCK_COMMANDS_DIR}/ogr2ogr" << 'EOF'
#!/bin/bash

# Mock ogr2ogr command for testing (full mock mode only)
# Author: Andres Gomez (AngocA)
# Version: 2025-11-12

# Parse arguments
ARGS=()
OUTPUT=""
INPUT=""
QUIET=false

while [[ $# -gt 0 ]]; do
 case $1 in
  -f)
   OUTPUT_FORMAT="$2"
   shift 2
   ;;
  -nln)
   LAYER_NAME="$2"
   shift 2
   ;;
  -nlt)
   GEOMETRY_TYPE="$2"
   shift 2
   ;;
  -q)
   QUIET=true
   shift
   ;;
  --version)
   echo "GDAL 3.6.0"
   exit 0
   ;;
  -*)
   # Skip other options
   shift
   ;;
  *)
   ARGS+=("$1")
   shift
   ;;
 esac
done

# Get input and output from arguments
if [[ ${#ARGS[@]} -ge 2 ]]; then
 OUTPUT="${ARGS[0]}"
 INPUT="${ARGS[1]}"
elif [[ ${#ARGS[@]} -eq 1 ]]; then
 OUTPUT="${ARGS[0]}"
fi

# Simulate conversion (just verify files exist)
if [[ -n "${INPUT}" ]] && [[ ! -f "${INPUT}" ]]; then
 echo "ERROR: Input file not found: ${INPUT}" >&2
 exit 1
fi

if [[ -n "${OUTPUT}" ]]; then
 # Create a dummy output file
 touch "${OUTPUT}" 2>/dev/null || true
fi

if [[ "$QUIET" != true ]]; then
 echo "Mock ogr2ogr: Converted ${INPUT:-stdin} to ${OUTPUT:-stdout}"
fi

exit 0
EOF
    chmod +x "${MOCK_COMMANDS_DIR}/ogr2ogr"
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

  # Disable email alerts in mock mode
  export SEND_ALERT_EMAIL="${SEND_ALERT_EMAIL:-false}"

  # Set project base directory
  export SCRIPT_BASE_DIRECTORY="${PROJECT_ROOT}"

  # Skip XML validation for faster execution
  export SKIP_XML_VALIDATION="${SKIP_XML_VALIDATION:-true}"

  log_success "Environment variables configured"
}

# Function to run updateCountries
run_updateCountries() {
  local execution_mode="${1:-}"
  log_info "Running updateCountries.sh in mock mode (mode: ${execution_mode:-normal})..."

  local update_script
  update_script="${PROJECT_ROOT}/bin/process/updateCountries.sh"

  if [[ ! -f "${update_script}" ]]; then
    log_error "updateCountries.sh not found: ${update_script}"
    return 1
  fi

  # Make script executable
  chmod +x "${update_script}"

  # Run the script with optional mode parameter
  log_info "Executing: ${update_script} ${execution_mode}"
  if [[ -n "${execution_mode}" ]]; then
    "${update_script}" "${execution_mode}"
  else
    "${update_script}"
  fi

  local exit_code=$?
  if [[ ${exit_code} -eq 0 ]]; then
    log_success "updateCountries.sh completed successfully (mode: ${execution_mode:-normal})"
  else
    log_error "updateCountries.sh exited with code: ${exit_code} (mode: ${execution_mode:-normal})"
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

  # First execution: --base mode (drops and recreates tables)
  log_info "=== FIRST EXECUTION: --base mode ==="
  cleanup_lock_files

  if ! run_updateCountries "--base"; then
    log_error "First execution (--base mode) failed"
    exit_code=$?
    exit ${exit_code}
  fi

  # Wait a moment between executions
  sleep 2

  # Second execution: Update mode (normal monthly update)
  log_info "=== SECOND EXECUTION: Update mode (normal monthly update) ==="
  cleanup_lock_files

  if ! run_updateCountries; then
    log_error "Second execution (update mode) failed"
    exit_code=$?
  fi

  exit ${exit_code}
}

# Run main function
main "$@"

