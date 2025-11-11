#!/bin/bash

# Database Test Runner executed as notes user (or equivalent)
# Author: Andres Gomez (AngocA)
# Version: 2025-11-11

set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly PROJECT_ROOT
DEFAULT_DB_TEST_USER="${DB_TEST_USER:-notes}"
readonly DEFAULT_DB_TEST_USER

# Logs an informational message.
# Parameters:
#  $1 - Message to display.
function __log_info {
 echo -e "${BLUE}[INFO]${NC} $1"
}

# Logs a success message.
# Parameters:
#  $1 - Message to display.
function __log_success {
 echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Logs a warning message.
# Parameters:
#  $1 - Message to display.
function __log_warning {
 echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Logs an error message.
# Parameters:
#  $1 - Message to display.
function __log_error {
 echo -e "${RED}[ERROR]${NC} $1"
}

# Displays script usage.
# Parameters:
#  None.
function __show_help {
 cat << 'EOF'
Database Test Runner (run_tests_as_notes.sh)

Usage: run_tests_as_notes.sh [OPTIONS]

Options:
  --unit         Run only unit test suites that depend on PostgreSQL
  --integration  Run only integration suites that depend on PostgreSQL
  --all          Run all database-dependent suites (default)
  --all-tests    Alias for --all
  --help, -h     Show this help message

Environment variables:
  DB_TEST_USER        User name to execute database tests (default: notes)
  RUN_TESTS_SWITCHED  Internal flag to avoid recursive sudo re-execution

Examples:
  ./run_tests_as_notes.sh --all
  DB_TEST_USER=osm ./run_tests_as_notes.sh --integration
EOF
}

# Attempts to re-execute the script as the target database user.
# Parameters:
#  $@ - Original command line arguments.
function __maybe_switch_user {
 local TARGET_USER="${DEFAULT_DB_TEST_USER}"

 if [[ -z "${TARGET_USER}" ]]; then
  return 0
 fi

 local CURRENT_USER
 CURRENT_USER="$(id -un)"

 if [[ "${CURRENT_USER}" == "${TARGET_USER}" ]]; then
  return 0
 fi

 if [[ -n "${RUN_TESTS_SWITCHED:-}" ]]; then
  __log_warning "Already attempted user switch; continuing as ${CURRENT_USER}"
  return 0
 fi

 if command -v sudo > /dev/null 2>&1; then
  if sudo -n -u "${TARGET_USER}" true > /dev/null 2>&1; then
   __log_info "Switching to user ${TARGET_USER} for database tests"
   export RUN_TESTS_SWITCHED="true"
   exec sudo -E -n -u "${TARGET_USER}" bash "$0" "$@"
  else
   __log_warning "Unable to switch to ${TARGET_USER} without password"
   __log_warning "Continuing as ${CURRENT_USER}"
  fi
 else
  __log_warning "sudo not available; running as ${CURRENT_USER}"
 fi
}

# Loads test properties to configure database environment.
# Parameters:
#  None.
function __load_test_properties {
 local PROPERTIES_FILE="${SCRIPT_DIR}/properties.sh"

 if [[ -f "${PROPERTIES_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${PROPERTIES_FILE}"
  __log_info "Loaded test properties from ${PROPERTIES_FILE}"
 else
  __log_warning "properties.sh not found; relying on environment variables"
 fi
}

# Removes mock commands from PATH to ensure real PostgreSQL binaries are used.
# Parameters:
#  None.
function __purge_mock_commands_from_path {
 local MOCK_DIR="${SCRIPT_DIR}/mock_commands"

 if [[ ! "${PATH}" =~ ${MOCK_DIR} ]]; then
  return 0
 fi

 local CLEAN_PATH
 CLEAN_PATH=$(echo "${PATH}" | tr ':' '\n' | grep -v "${MOCK_DIR}" | tr '\n' ':' | sed 's/:$//')
 export PATH="${CLEAN_PATH}"
 __log_info "Removed mock commands directory from PATH"
}

# Validates the availability of required commands and PostgreSQL connectivity.
# Parameters:
#  None.
function __check_prerequisites {
 local REQUIRED_COMMANDS=("bats" "psql" "pg_isready")
 local COMMAND
 local HAS_ERROR=false

 for COMMAND in "${REQUIRED_COMMANDS[@]}"; do
  if ! command -v "${COMMAND}" > /dev/null 2>&1; then
   __log_error "Required command not found: ${COMMAND}"
   HAS_ERROR=true
  fi
 done

 if [[ "${HAS_ERROR}" == "true" ]]; then
  return 1
 fi

 local PG_ARGS=()

 if [[ -n "${TEST_DBHOST:-}" ]]; then
  PG_ARGS+=("-h" "${TEST_DBHOST}")
 fi

 if [[ -n "${TEST_DBPORT:-}" ]]; then
  PG_ARGS+=("-p" "${TEST_DBPORT}")
 fi

 if [[ -n "${TEST_DBUSER:-}" ]]; then
  PG_ARGS+=("-U" "${TEST_DBUSER}")
 fi

 if [[ -n "${TEST_DBNAME:-}" ]]; then
  PG_ARGS+=("-d" "${TEST_DBNAME}")
 fi

 if ! pg_isready "${PG_ARGS[@]}" > /dev/null 2>&1; then
  __log_error "PostgreSQL is not ready (pg_isready ${PG_ARGS[*]})"
  return 1
 fi

 __log_success "Prerequisites validated successfully"
}

# Prepares environment variables required by database tests.
# Parameters:
#  None.
function __prepare_environment {
 export SCRIPT_BASE_DIRECTORY="${PROJECT_ROOT}"
 export TEST_MODE=true
 export MOCK_MODE=false
}

# Executes the requested database-dependent test suites.
# Parameters:
#  $1 - Requested test type (unit|integration|all).
function __run_database_tests {
 local REQUESTED_TYPE="$1"
 local RUN_TESTS_SCRIPT="${SCRIPT_DIR}/run_tests.sh"

 if [[ ! -f "${RUN_TESTS_SCRIPT}" ]]; then
  __log_error "Core test runner not found at ${RUN_TESTS_SCRIPT}"
  return 1
 fi

 __log_info "Executing database test suites (type: ${REQUESTED_TYPE})"

 if bash "${RUN_TESTS_SCRIPT}" --mode host --type "${REQUESTED_TYPE}"; then
  __log_success "Database test suites finished successfully"
  return 0
 fi

 __log_error "Database test suites failed"
 return 1
}

# Parses input arguments and sets the global REQUESTED_TYPE variable.
# Parameters:
#  $@ - Command line arguments.
function __parse_arguments {
 REQUESTED_TYPE="all"

 while [[ $# -gt 0 ]]; do
  case "$1" in
  --unit)
   REQUESTED_TYPE="unit"
   shift
   ;;
  --integration)
   REQUESTED_TYPE="integration"
   shift
   ;;
  --all | --all-tests)
   REQUESTED_TYPE="all"
   shift
   ;;
  --help | -h)
   __show_help
   exit 0
   ;;
  *)
   __log_error "Unknown option: $1"
   __show_help
   exit 1
   ;;
  esac
 done
}

# Main entry point.
# Parameters:
#  $@ - Command line arguments.
function __main {
 __maybe_switch_user "$@"

 __parse_arguments "$@"

 __load_test_properties
 __purge_mock_commands_from_path
 __prepare_environment

 __check_prerequisites
 local CHECK_STATUS=$?
 if [[ "${CHECK_STATUS}" -ne 0 ]]; then
  __log_error "Database prerequisites are not satisfied"
  exit 1
 fi

 __run_database_tests "${REQUESTED_TYPE}"
 local RUN_STATUS=$?
 if [[ "${RUN_STATUS}" -ne 0 ]]; then
  exit 1
 fi
}

__main "$@"
