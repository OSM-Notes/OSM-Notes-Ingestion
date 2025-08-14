#!/bin/bash

# Simple Logging Pattern Validation Script
# Script: validate_logging_patterns_simple.sh
# Author: Andres Gomez (AngocA)
# Version: 2025-08-13
# Description: Simple validation that all bash functions follow the logging pattern

set -euo pipefail

# Source common functions
SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_BASE_DIRECTORY}/lib/bash_logger.sh"

# Configuration
declare -r TEMP_DIR="/tmp/logging_validation_simple_$$"
declare -r RESULTS_FILE="${TEMP_DIR}/validation_results.txt"
declare -r SUMMARY_FILE="${TEMP_DIR}/validation_summary.txt"

# Functions that don't require logging (special cases)
declare -r EXEMPT_FUNCTIONS=(
 "__show_help"
 "__start_logger"
 "__processXmlPartsParallel"
 "__splitXmlForParallelSafe"
 "__splitXmlForParallelAPI"
 "__splitXmlForParallelPlanet"
)

# Statistics
declare -i TOTAL_FUNCTIONS=0
declare -i VALID_FUNCTIONS=0
declare -i INVALID_FUNCTIONS=0
declare -i MISSING_LOG_START=0
declare -i MISSING_LOG_FINISH=0

# Colors for output
declare -r RED='\033[0;31m'
declare -r GREEN='\033[0;32m'
declare -r YELLOW='\033[1;33m'
declare -r NC='\033[0m' # No Color

# Initialize environment
function __initialize_validation() {
 __log_start

 # Create temporary directory
 mkdir -p "${TEMP_DIR}"

 # Initialize results files
 > "${RESULTS_FILE}"
 > "${SUMMARY_FILE}"

 __logi "Simple logging pattern validation initialized"
 __logi "Temporary directory: ${TEMP_DIR}"

 __log_finish
}

# Cleanup function
function __cleanup_validation() {
 __log_start

 if [[ -d "${TEMP_DIR}" ]]; then
  rm -rf "${TEMP_DIR}"
  __logi "Temporary directory cleaned up: ${TEMP_DIR}"
 fi

 __log_finish
}

# Print colored output
function __print_colored() {
 local color="$1"
 local message="$2"
 printf "%b%s%b\n" "${color}" "${message}" "${NC}"
}

# Simple validation of a single bash file
function __validate_bash_file_simple() {
 local file_path="$1"
 local file_name
 file_name=$(basename "${file_path}")

 __logd "Validating file: ${file_name}"

 # Skip if not a bash file
 if [[ ! "${file_path}" =~ \.(sh|bash)$ ]]; then
  return 0
 fi

 # Simple grep-based validation
 local has_functions=false
 local functions_without_start=0
 local functions_without_finish=0

 # Check if file has functions
 if grep -q "^function [a-zA-Z_][a-zA-Z0-9_]*" "${file_path}"; then
  has_functions=true
  __logd "File contains functions: ${file_name}"

  # Count functions missing __log_start
  functions_without_start=$(grep -c "^function [a-zA-Z_][a-zA-Z0-9_]*" "${file_path}" 2> /dev/null || echo "0")
  local functions_with_start
  functions_with_start=$(grep -c "^[[:space:]]*__log_start" "${file_path}" 2> /dev/null || echo "0")

  # Ensure variables are numeric and handle empty results
  # Convert to integer safely
  if [[ "${functions_without_start}" =~ ^[0-9]+$ ]]; then
    functions_without_start=${functions_without_start}
  else
    functions_without_start=0
  fi
  if [[ "${functions_with_start}" =~ ^[0-9]+$ ]]; then
    functions_with_start=${functions_with_start}
  else
    functions_with_start=0
  fi

  if [[ "${functions_with_start}" -lt "${functions_without_start}" ]]; then
   local missing_start
   missing_start=$((functions_without_start - functions_with_start))
   __logw "WARNING: ${missing_start} functions missing __log_start in ${file_name}"
  fi

  # Count functions missing __log_finish
  local functions_with_finish
  functions_with_finish=$(grep -c "^[[:space:]]*__log_finish" "${file_path}" 2> /dev/null || echo "0")
  
  # Ensure variable is numeric and handle empty results
  # Convert to integer safely
  if [[ "${functions_with_finish}" =~ ^[0-9]+$ ]]; then
    functions_with_finish=${functions_with_finish}
  else
    functions_with_finish=0
  fi

  if [[ "${functions_with_finish}" -lt "${functions_without_start}" ]]; then
   local missing_finish
   missing_finish=$((functions_without_start - functions_with_finish))
   __logw "WARNING: ${missing_finish} functions missing __log_finish in ${file_name}"
  fi

  # Count exempt functions in this file
  local exempt_in_file=0
  for exempt_func in "${EXEMPT_FUNCTIONS[@]}"; do
   if grep -q "^function ${exempt_func}" "${file_path}"; then
    exempt_in_file=$((exempt_in_file + 1))
   fi
  done

  # Calculate required functions (total - exempt)
  local required_functions=$((functions_without_start - exempt_in_file))
  
  # Update statistics
  TOTAL_FUNCTIONS=$((TOTAL_FUNCTIONS + required_functions))

  local valid_in_file=0
  local invalid_in_file=0

  # A function is valid if it has both __log_start and __log_finish (excluding exempt functions)
  if [[ "${functions_with_start}" -eq "${required_functions}" ]] && [[ "${functions_with_finish}" -eq "${required_functions}" ]]; then
   valid_in_file="${required_functions}"
   invalid_in_file=0
   if [[ ${exempt_in_file} -gt 0 ]]; then
    __print_colored "${GREEN}" "✓ ${file_name}: All ${required_functions} required functions follow the pattern (${exempt_in_file} exempt)"
   else
    __print_colored "${GREEN}" "✓ ${file_name}: All ${required_functions} functions follow the pattern"
   fi
  else
   valid_in_file=0
   invalid_in_file="${required_functions}"
   if [[ ${exempt_in_file} -gt 0 ]]; then
    __print_colored "${RED}" "✗ ${file_name}: ${invalid_in_file} required functions have issues (${exempt_in_file} exempt)"
   else
    __print_colored "${RED}" "✗ ${file_name}: ${invalid_in_file} functions have issues"
   fi
  fi

  VALID_FUNCTIONS=$((VALID_FUNCTIONS + valid_in_file))
  INVALID_FUNCTIONS=$((INVALID_FUNCTIONS + invalid_in_file))

  # Record results
  {
   echo "File: ${file_path}"
   echo "Total functions: ${functions_without_start}"
   echo "Exempt functions: ${exempt_in_file}"
   echo "Required functions: ${required_functions}"
   echo "Functions with __log_start: ${functions_with_start}"
   echo "Functions with __log_finish: ${functions_with_finish}"
   echo "Valid functions: ${valid_in_file}"
   echo "Invalid functions: ${invalid_in_file}"
   echo "---"
  } >> "${RESULTS_FILE}"
 else
  __logd "No functions found in: ${file_name}"
 fi
}

# Generate summary report
function __generate_summary() {
 __log_start

 {
  echo "=== SIMPLE LOGGING PATTERN VALIDATION SUMMARY ==="
  echo "Generated: $(date)"
  echo ""
  echo "STATISTICS:"
  echo "  Total functions analyzed: ${TOTAL_FUNCTIONS}"
  echo "  Valid functions: ${VALID_FUNCTIONS}"
  echo "  Invalid functions: ${INVALID_FUNCTIONS}"
  if [[ ${TOTAL_FUNCTIONS} -gt 0 ]]; then
   echo "  Success rate: $((VALID_FUNCTIONS * 100 / TOTAL_FUNCTIONS))%"
  else
   echo "  Success rate: N/A (no functions found)"
  fi
  echo ""
  echo "RECOMMENDATIONS:"
  if [[ ${INVALID_FUNCTIONS} -eq 0 ]]; then
   echo "  ✓ All functions follow the logging pattern correctly!"
  else
   echo "  ✗ ${INVALID_FUNCTIONS} functions need to be fixed:"
   echo "    - Add __log_start at the beginning of each function"
   echo "    - Add __log_finish before each return statement"
   echo "    - Add __log_finish at the end of each function"
  fi
  echo ""
  echo "Detailed results available in: ${RESULTS_FILE}"
 } > "${SUMMARY_FILE}"

 # Display summary
 cat "${SUMMARY_FILE}"

 __log_finish
}

# Main validation function
function __run_validation() {
 __log_start

 __logi "Starting simple logging pattern validation for all bash files"

 # Find all bash files in the project (excluding tests and hidden directories)
 local -a bash_files
 mapfile -t bash_files < <(find "${SCRIPT_BASE_DIRECTORY}" -type f \( -name "*.sh" -o -name "*.bash" \) -not -path "*/\.*" -not -path "*/tests/*" -not -path "*/mock_commands/*" | sort)

 __logi "Found ${#bash_files[@]} bash files to validate"

 # Validate each file
 for file_path in "${bash_files[@]}"; do
  __validate_bash_file_simple "${file_path}"
 done

 __logi "Validation completed. Generating summary..."
 __generate_summary

 __log_finish
}

# Main execution
function main() {
 __log_start

 # Set up error handling
 trap '__loge "ERROR: Validation interrupted" && __cleanup_validation && exit 1' INT TERM

 __logi "Simple Logging Pattern Validation Tool"
 __logi "This tool validates that all bash functions follow the logging pattern"

 # Initialize
 __initialize_validation

 # Run validation
 __run_validation

 # Cleanup and exit with appropriate code
 __cleanup_validation

 if [[ ${INVALID_FUNCTIONS} -eq 0 ]]; then
  __logi "Validation completed successfully - all functions follow the pattern!"
  __log_finish
  exit 0
 else
  __logw "Validation completed with ${INVALID_FUNCTIONS} issues found"
  __log_finish
  exit 1
 fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
 main "$@"
fi
