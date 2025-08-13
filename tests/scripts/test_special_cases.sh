#!/bin/bash
# =============================================================================
# Script to run special case tests
# =============================================================================

set -euo pipefail

# =============================================================================
# Configuration variables
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../" && pwd)"
SPECIAL_CASES_DIR="${PROJECT_ROOT}/tests/fixtures/special_cases"
VERBOSE="${VERBOSE:-false}"
PARALLEL="${PARALLEL:-false}"
FAIL_FAST="${FAIL_FAST:-false}"

# =============================================================================
# Colors for output
# =============================================================================
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# =============================================================================
# Logging functions
# =============================================================================
__log_info() {
 echo -e "${BLUE}[INFO]${NC} $*"
}

__log_success() {
 echo -e "${GREEN}[SUCCESS]${NC} $*"
}

__log_warning() {
 echo -e "${YELLOW}[WARNING]${NC} $*"
}

__log_error() {
 echo -e "${RED}[ERROR]${NC} $*"
}

__log_debug() {
 if [[ "${VERBOSE}" == "true" ]]; then
  echo "[DEBUG] $*"
 fi
}

# =============================================================================
# Help function
# =============================================================================
__show_help() {
 cat << EOF
Usage: $0 [OPTIONS]

Options:
  --help, -h     Show this help
  --verbose      Verbose mode
  --parallel     Run tests in parallel
  --fail-fast    Stop on first failure
  --case CASE    Run only a specific case

Environment variables:
  VERBOSE        Verbose mode
  PARALLEL       Run in parallel
  FAIL_FAST      Stop on first failure

Examples:
  $0 --verbose
  $0 --parallel --fail-fast
  $0 --case zero_notes
EOF
}

# =============================================================================
# Function to check prerequisites
# =============================================================================
__check_prerequisites() {
 __log_info "Checking prerequisites..."

 # Check that the special cases directory exists
 if [[ ! -d "${SPECIAL_CASES_DIR}" ]]; then
  __log_error "Special cases directory not found: ${SPECIAL_CASES_DIR}"
  return 1
 fi

 # Check that the processing script exists
 if [[ ! -f "${PROJECT_ROOT}/bin/process/processAPINotes.sh" ]]; then
  __log_error "Processing script not found: ${PROJECT_ROOT}/bin/process/processAPINotes.sh"
  return 1
 fi

 __log_success "Prerequisites verified"
 return 0
}

# =============================================================================
# Function to execute a test case
# =============================================================================
__run_test_case() {
 local xml_file="$1"
 local case_name
 case_name=$(basename "${xml_file}" .xml)

 __log_info "Executing case: ${case_name}"
 __log_debug "File: ${xml_file}"

 # Execute the processing script
 if "${PROJECT_ROOT}/bin/process/processAPINotes.sh" "${xml_file}" > /dev/null 2>&1; then
  __log_success "Case ${case_name} completed successfully"
  return 0
 else
  __log_error "Case ${case_name} failed"
  return 1
 fi
}

# =============================================================================
# Function to execute all cases
# =============================================================================
__run_all_cases() {
 __log_info "Executing all special cases..."

 local success_count=0
 local total_count=0
 local failed_cases=()

 # Find all XML files
 local xml_files=()
 while IFS= read -r -d '' file; do
  xml_files+=("${file}")
 done < <(find "${SPECIAL_CASES_DIR}" -name "*.xml" -type f -print0)

 if [[ ${#xml_files[@]} -eq 0 ]]; then
  __log_warning "No XML files found to test"
  return 0
 fi

 __log_info "Found ${#xml_files[@]} cases to test"

 # Execute cases
 for xml_file in "${xml_files[@]}"; do
  local case_name
  case_name=$(basename "${xml_file}" .xml)
  ((total_count++))

  if __run_test_case "${xml_file}"; then
   ((success_count++))
  else
   failed_cases+=("${case_name}")
   if [[ "${FAIL_FAST}" == "true" ]]; then
    __log_error "Stopping on first failure: ${case_name}"
    break
   fi
  fi
 done

 # Show summary
 __log_info "Test summary:"
 __log_info "  Total: ${total_count}"
 __log_info "  Successful: ${success_count}"
 __log_info "  Failed: $((total_count - success_count))"

 if [[ ${#failed_cases[@]} -gt 0 ]]; then
  __log_warning "Failed cases: ${failed_cases[*]}"
  return 1
 else
  __log_success "All cases completed successfully"
  return 0
 fi
}

# =============================================================================
# Function to execute a specific case
# =============================================================================
__run_specific_case() {
 local case_name="$1"
 local xml_file="${SPECIAL_CASES_DIR}/${case_name}.xml"

 if [[ ! -f "${xml_file}" ]]; then
  __log_error "Case not found: ${case_name}"
  __log_info "Available cases:"
  find "${SPECIAL_CASES_DIR}" -name "*.xml" -exec basename {} .xml \; | sort
  return 1
 fi

 __run_test_case "${xml_file}"
}

# =============================================================================
# Argument processing
# =============================================================================
SPECIFIC_CASE=""

while [[ $# -gt 0 ]]; do
 case $1 in
 --help | -h)
  __show_help
  exit 0
  ;;
 --verbose)
  VERBOSE="true"
  shift
  ;;
 --parallel)
  PARALLEL="true"
  shift
  ;;
 --fail-fast)
  FAIL_FAST="true"
  shift
  ;;
 --case)
  SPECIFIC_CASE="$2"
  shift 2
  ;;
 *)
  __log_error "Unknown option: $1"
  __show_help
  exit 1
  ;;
 esac
done

# =============================================================================
# Main function
# =============================================================================
__main() {
 __log_info "Starting special case tests..."

 # Check prerequisites
 if ! __check_prerequisites; then
  exit 1
 fi

 # Execute specific case or all cases
 if [[ -n "${SPECIFIC_CASE}" ]]; then
  __log_info "Executing specific case: ${SPECIFIC_CASE}"
  if __run_specific_case "${SPECIFIC_CASE}"; then
   __log_success "Specific case completed successfully"
   exit 0
  else
   __log_error "Specific case failed"
   exit 1
  fi
 else
  __run_all_cases
 fi
}

# Execute main function
__main "$@"
