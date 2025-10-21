#!/bin/bash

# Setup CI/CD Environment for Tests
# Author: Andres Gomez (AngocA)
# Version: 2025-10-13

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

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

# Function to create test directories
__create_test_directories() {
 log_info "Creating test directories..."

 local -a DIRECTORIES=(
  "${SCRIPT_DIR}/tmp"
  "${SCRIPT_DIR}/output"
  "${SCRIPT_DIR}/results"
  "${SCRIPT_DIR}/ci_results"
  "${PROJECT_ROOT}/.benchmarks"
  "${PROJECT_ROOT}/advanced_reports"
  "${PROJECT_ROOT}/coverage"
  "${PROJECT_ROOT}/security_reports"
 )

 for DIR in "${DIRECTORIES[@]}"; do
  if [[ ! -d "${DIR}" ]]; then
   mkdir -p "${DIR}"
   log_info "Created directory: ${DIR}"
  else
   log_info "Directory already exists: ${DIR}"
  fi
 done

 # Set proper permissions
 chmod 755 "${SCRIPT_DIR}/tmp" 2> /dev/null || true
 chmod 755 "${SCRIPT_DIR}/output" 2> /dev/null || true
 chmod 755 "${SCRIPT_DIR}/results" 2> /dev/null || true

 log_success "Test directories created successfully"
}

# Function to setup environment variables
__setup_environment_variables() {
 log_info "Setting up environment variables..."

 # Database configuration
 export TEST_DBNAME="${TEST_DBNAME:-osm_notes_test}"
 export TEST_DBUSER="${TEST_DBUSER:-postgres}"
 export TEST_DBPASSWORD="${TEST_DBPASSWORD:-postgres}"
 export TEST_DBHOST="${TEST_DBHOST:-localhost}"
 export TEST_DBPORT="${TEST_DBPORT:-5432}"

 # Legacy variables for backward compatibility
 export DBNAME="${DBNAME:-${TEST_DBNAME}}"
 export DB_USER="${DB_USER:-${TEST_DBUSER}}"
 export DBPASSWORD="${DBPASSWORD:-${TEST_DBPASSWORD}}"
 export DBHOST="${DBHOST:-${TEST_DBHOST}}"
 export DBPORT="${DBPORT:-${TEST_DBPORT}}"

 # PostgreSQL password for psql
 export PGPASSWORD="${DBPASSWORD}"

 # Test configuration
 export TEST_MODE="true"
 export CI_MODE="true"
 export LOG_LEVEL="${LOG_LEVEL:-INFO}"
 export MAX_THREADS="${MAX_THREADS:-2}"

 # Path configuration
 export SCRIPT_BASE_DIRECTORY="${PROJECT_ROOT}"
 export TEST_TMP_DIR="${SCRIPT_DIR}/tmp"
 export TEST_OUTPUT_DIR="${SCRIPT_DIR}/output"
 export TEST_RESULTS_DIR="${SCRIPT_DIR}/results"

 log_success "Environment variables configured"
}

# Function to create test properties file
__create_test_properties() {
 log_info "Creating test properties file..."

 local PROPERTIES_FILE="${SCRIPT_DIR}/properties.sh"

 if [[ -f "${PROPERTIES_FILE}" ]]; then
  log_warning "Properties file already exists: ${PROPERTIES_FILE}"
  return 0
 fi

 # shellcheck disable=SC2312
 cat > "${PROPERTIES_FILE}" << EOF
#!/bin/bash

# Test Properties for CI/CD
# Generated automatically by setup_ci_environment.sh
# Date: $(date)

# Database configuration
export TEST_DBNAME="${TEST_DBNAME}"
export TEST_DBUSER="${TEST_DBUSER}"
export TEST_DBPASSWORD="${TEST_DBPASSWORD}"
export TEST_DBHOST="${TEST_DBHOST}"
export TEST_DBPORT="${TEST_DBPORT}"

# Legacy variables
export DBNAME="${DBNAME}"
export DB_USER="${DB_USER}"
export DBPASSWORD="${DBPASSWORD}"
export DBHOST="${DBHOST}"
export DBPORT="${DBPORT}"

# PostgreSQL password
export PGPASSWORD="${DBPASSWORD}"

# Test configuration
export TEST_MODE="true"
export CI_MODE="true"
export LOG_LEVEL="${LOG_LEVEL}"
export MAX_THREADS="${MAX_THREADS}"

# Path configuration
export SCRIPT_BASE_DIRECTORY="${PROJECT_ROOT}"
export TEST_TMP_DIR="${SCRIPT_DIR}/tmp"
export TEST_OUTPUT_DIR="${SCRIPT_DIR}/output"
export TEST_RESULTS_DIR="${SCRIPT_DIR}/results"
EOF

 chmod 644 "${PROPERTIES_FILE}"

 log_success "Test properties file created: ${PROPERTIES_FILE}"
}

# Function to create placeholder test files
__create_placeholder_files() {
 log_info "Creating placeholder files..."

 # Create placeholder in tmp directory
 echo "# CI Test Environment Setup" > "${SCRIPT_DIR}/tmp/setup.log"
 # shellcheck disable=SC2312
 echo "Setup started at: $(date)" >> "${SCRIPT_DIR}/tmp/setup.log"

 # Create placeholder in output directory
 echo "# Test Output Directory" > "${SCRIPT_DIR}/output/README.md"
 echo "This directory contains test execution output files." \
  >> "${SCRIPT_DIR}/output/README.md"

 # Create placeholder in results directory
 echo "# Test Results Directory" > "${SCRIPT_DIR}/results/README.md"
 echo "This directory contains test result files." \
  >> "${SCRIPT_DIR}/results/README.md"

 log_success "Placeholder files created"
}

# Function to verify required tools
__verify_required_tools() {
 log_info "Verifying required tools..."

 local -a REQUIRED_TOOLS=(
  "bats"
  "psql"
  "xmllint"
  "shellcheck"
 )

 local -a MISSING_TOOLS=()

 for TOOL in "${REQUIRED_TOOLS[@]}"; do
  if command -v "${TOOL}" > /dev/null 2>&1; then
   log_info "✓ ${TOOL} is available"
  else
   log_warning "✗ ${TOOL} is not available"
   MISSING_TOOLS+=("${TOOL}")
  fi
 done

 # Check optional tools
 local -a OPTIONAL_TOOLS=(
  "shfmt"
  "aria2c"
  "osmtogeojson"
 )

 for TOOL in "${OPTIONAL_TOOLS[@]}"; do
  if command -v "${TOOL}" > /dev/null 2>&1; then
   log_info "✓ ${TOOL} is available (optional)"
  else
   log_info "○ ${TOOL} is not available (optional)"
  fi
 done

 if [[ ${#MISSING_TOOLS[@]} -gt 0 ]]; then
  log_warning "Some required tools are missing: ${MISSING_TOOLS[*]}"
  log_warning "Tests may fail without these tools"
 else
  log_success "All required tools are available"
 fi
}

# Function to setup test fixtures
__setup_test_fixtures() {
 log_info "Setting up test fixtures..."

 local FIXTURES_DIR="${SCRIPT_DIR}/fixtures"

 if [[ -d "${FIXTURES_DIR}" ]]; then
  log_info "Test fixtures directory exists: ${FIXTURES_DIR}"

  # Create symlinks or copies if needed
  local XML_DIR="${FIXTURES_DIR}/xml"
  if [[ -d "${XML_DIR}" ]]; then
   log_info "XML fixtures available: ${XML_DIR}"
  fi

  local SPECIAL_CASES_DIR="${FIXTURES_DIR}/special_cases"
  if [[ -d "${SPECIAL_CASES_DIR}" ]]; then
   log_info "Special cases fixtures available: ${SPECIAL_CASES_DIR}"
  fi
 else
  log_warning "Test fixtures directory not found: ${FIXTURES_DIR}"
 fi

 log_success "Test fixtures setup completed"
}

# Function to create test summary file
__create_test_summary() {
 log_info "Creating test summary file..."

 local SUMMARY_FILE="${SCRIPT_DIR}/results/ci_setup_summary.log"

 # shellcheck disable=SC2312
 cat > "${SUMMARY_FILE}" << EOF
# CI Environment Setup Summary
Generated at: $(date)

## Environment Information
- Operating System: $(uname -s)
- Kernel Version: $(uname -r)
- Architecture: $(uname -m)

## Database Configuration
- Database Name: ${DBNAME}
- Database User: ${DB_USER}
- Database Host: ${DBHOST}
- Database Port: ${DBPORT}

## Test Configuration
- Test Mode: ${TEST_MODE}
- CI Mode: ${CI_MODE}
- Log Level: ${LOG_LEVEL}
- Max Threads: ${MAX_THREADS}

## Directory Structure
- Project Root: ${PROJECT_ROOT}
- Script Directory: ${SCRIPT_DIR}
- Tmp Directory: ${TEST_TMP_DIR}
- Output Directory: ${TEST_OUTPUT_DIR}
- Results Directory: ${TEST_RESULTS_DIR}

## Setup Status
- Test directories created: ✓
- Environment variables configured: ✓
- Test properties file created: ✓
- Placeholder files created: ✓
- Required tools verified: ✓
- Test fixtures setup: ✓

## Setup Complete
The CI test environment is ready for test execution.
EOF

 log_success "Test summary file created: ${SUMMARY_FILE}"
}

# Function to show setup summary
__show_setup_summary() {
 echo
 echo "=========================================="
 echo "CI Environment Setup Complete"
 echo "=========================================="
 echo "Database: ${DB_USER}@${DBHOST}:${DBPORT}/${DBNAME}"
 echo "Test Mode: ${TEST_MODE}"
 echo "CI Mode: ${CI_MODE}"
 echo "Log Level: ${LOG_LEVEL}"
 echo "Max Threads: ${MAX_THREADS}"
 echo "=========================================="
 echo
}

# Main function
main() {
 log_info "Starting CI environment setup..."
 log_info "Project Root: ${PROJECT_ROOT}"
 log_info "Script Directory: ${SCRIPT_DIR}"

 # Execute setup steps
 __create_test_directories
 __setup_environment_variables
 __create_test_properties
 __create_placeholder_files
 __verify_required_tools
 __setup_test_fixtures
 __create_test_summary

 # Show summary
 __show_setup_summary

 log_success "CI environment setup completed successfully!"

 return 0
}

# Run main function
main "$@"
