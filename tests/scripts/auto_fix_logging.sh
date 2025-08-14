#!/bin/bash

# Automated Logging Pattern Fixer
# Script: auto_fix_logging.sh
# Author: Andres Gomez (AngocA)
# Version: 2025-08-13
# Description: Automatically adds __log_start and __log_finish to bash functions

set -euo pipefail

# Source common functions
SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_BASE_DIRECTORY}/lib/bash_logger.sh"

# Configuration
declare -r BACKUP_DIR="/tmp/logging_fix_backup_$$"
declare -r TEMP_DIR="/tmp/logging_fix_temp_$$"
declare -r LOG_FILE="/tmp/logging_fix_$$.log"

# Statistics
declare -i TOTAL_FUNCTIONS=0
declare -i FIXED_FUNCTIONS=0
declare -i SKIPPED_FUNCTIONS=0
declare -i ERROR_FUNCTIONS=0

# Colors for output
declare -r RED='\033[0;31m'
declare -r GREEN='\033[0;32m'
declare -r YELLOW='\033[1;33m'
declare -r BLUE='\033[0;34m'
declare -r NC='\033[0m' # No Color

# Print colored output
function __print_colored() {
 local color="$1"
 local message="$2"
 printf "%b%s%b\n" "${color}" "${message}" "${NC}"
}

# Initialize backup and temp directories
function __initialize_fix() {
 __log_start
 __logi "Initializing automated logging pattern fixer"

 # Create backup directory
 mkdir -p "${BACKUP_DIR}"
 __logi "Backup directory: ${BACKUP_DIR}"

 # Create temp directory
 mkdir -p "${TEMP_DIR}"
 __logi "Temp directory: ${TEMP_DIR}"

 # Initialize log file
 > "${LOG_FILE}"
 __logi "Log file: ${LOG_FILE}"

 __log_finish
}

# Cleanup function
function __cleanup_fix() {
 __log_start

 if [[ -d "${TEMP_DIR}" ]]; then
  rm -rf "${TEMP_DIR}"
  __logi "Temp directory cleaned up: ${TEMP_DIR}"
 fi

 __log_finish
}

# Create backup of a file
function __backup_file() {
 local file_path="$1"
 local file_name
 file_name=$(basename "${file_path}")
 local backup_path="${BACKUP_DIR}/${file_name}.$(date +%Y%m%d_%H%M%S)"

 cp "${file_path}" "${backup_path}"
 __logd "Backup created: ${backup_path}"
 echo "${backup_path}"
}

# Fix a single function in a file
function __fix_function() {
 local file_path="$1"
 local function_name="$2"
 local temp_file="${TEMP_DIR}/$(basename "${file_path}")"

 __logd "Fixing function: ${function_name} in $(basename "${file_path}")"

 # Create temp copy
 cp "${file_path}" "${temp_file}"

 # Find function start line
 local function_start_line
 function_start_line=$(grep -n "^function ${function_name}" "${temp_file}" | cut -d: -f1)

 if [[ -z "${function_start_line}" ]]; then
  __loge "Function ${function_name} not found in ${file_path}"
  return 1
 fi

 # Check if function already has __log_start
 local has_start=false
 if sed -n "${function_start_line},$((function_start_line + 20))p" "${temp_file}" | grep -q "^[[:space:]]*__log_start"; then
  has_start=true
 fi

 # Check if function already has __log_finish
 local has_finish=false
 if sed -n "${function_start_line},$((function_start_line + 50))p" "${temp_file}" | grep -q "^[[:space:]]*__log_finish"; then
  has_finish=true
 fi

 local modified=false

 # Add __log_start if missing
 if [[ "${has_start}" == "false" ]]; then
  # Insert __log_start after function declaration
  local insert_line=$((function_start_line + 1))
  sed -i "${insert_line}a\\ __log_start" "${temp_file}"
  modified=true
  __logd "Added __log_start to ${function_name}"
 fi

 # Add __log_finish if missing
 if [[ "${has_finish}" == "false" ]]; then
   # Find function end (next function or end of file)
 local next_function_line
 next_function_line=$(sed -n "$((function_start_line + 1)),\$p" "${temp_file}" | grep -n "^function " | head -1 | cut -d: -f1)
 
 local function_end_line
 if [[ -n "${next_function_line}" ]] && [[ "${next_function_line}" =~ ^[0-9]+$ ]]; then
  function_end_line=$((function_start_line + next_function_line - 1))
 else
  function_end_line=$(wc -l < "${temp_file}")
 fi

  # Find all return statements in the function
  local return_lines
  mapfile -t return_lines < <(sed -n "${function_start_line},${function_end_line}p" "${temp_file}" | grep -n "^[[:space:]]*return" | cut -d: -f1)

  if [[ ${#return_lines[@]} -gt 0 ]]; then
   # Add __log_finish before each return
   for return_line in "${return_lines[@]}"; do
    local actual_line=$((function_start_line + return_line - 1))
    sed -i "${actual_line}i\\ __log_finish" "${temp_file}"
    # Adjust subsequent line numbers
    return_lines=($(echo "${return_lines[@]}" | tr ' ' '\n' | awk -v line="${return_line}" '$1 > line {print $1 + 1} $1 <= line {print $1}' | tr '\n' ' '))
   done
  fi

  # Add __log_finish at the end of function (before closing brace)
  local last_line_in_function
  last_line_in_function=$(sed -n "${function_start_line},${function_end_line}p" "${temp_file}" | grep -n "^}" | tail -1 | cut -d: -f1)
  
  if [[ -n "${last_line_in_function}" ]]; then
   local actual_line=$((function_start_line + last_line_in_function - 1))
   sed -i "${actual_line}i\\ __log_finish" "${temp_file}"
  fi

  modified=true
  __logd "Added __log_finish to ${function_name}"
 fi

 # Replace original file if modified
 if [[ "${modified}" == "true" ]]; then
  cp "${temp_file}" "${file_path}"
  __logi "Fixed function ${function_name} in ${file_path}"
  return 0
 else
  __logd "Function ${function_name} already has correct logging"
  return 2
 fi
}

# Fix all functions in a file
function __fix_file() {
 local file_path="$1"
 local file_name
 file_name=$(basename "${file_path}")

 __logi "Processing file: ${file_name}"

 # Skip if not a bash file
 if [[ ! "${file_path}" =~ \.(sh|bash)$ ]]; then
  __logd "Skipping non-bash file: ${file_name}"
  return 0
 fi

 # Check if file has functions
 if ! grep -q "^function [a-zA-Z_][a-zA-Z0-9_]*" "${file_path}"; then
  __logd "No functions found in: ${file_name}"
  return 0
 fi

 # Create backup
 local backup_path
 backup_path=$(__backup_file "${file_path}")

 # Get all function names
 local -a function_names
 mapfile -t function_names < <(grep "^function [a-zA-Z_][a-zA-Z0-9_]*" "${file_path}" | sed 's/^function \([a-zA-Z_][a-zA-Z0-9_]*\).*/\1/')

 local file_fixed=0
 local file_skipped=0
 local file_errors=0

 # Process each function
 for func_name in "${function_names[@]}"; do
  TOTAL_FUNCTIONS=$((TOTAL_FUNCTIONS + 1))

  case $(__fix_function "${file_path}" "${func_name}") in
   0) # Fixed
    file_fixed=$((file_fixed + 1))
    FIXED_FUNCTIONS=$((FIXED_FUNCTIONS + 1))
    ;;
   2) # Already correct
    file_skipped=$((file_skipped + 1))
    SKIPPED_FUNCTIONS=$((SKIPPED_FUNCTIONS + 1))
    ;;
   *) # Error
    file_errors=$((file_errors + 1))
    ERROR_FUNCTIONS=$((ERROR_FUNCTIONS + 1))
    ;;
  esac
 done

 # Log results
 __logi "File ${file_name} results:"
 __logi "  Fixed: ${file_fixed}"
 __logi "  Skipped: ${file_skipped}"
 __logi "  Errors: ${file_errors}"
 __logi "  Backup: ${backup_path}"

 # Record in log file
 {
  echo "=== ${file_name} ==="
  echo "Fixed: ${file_fixed}"
  echo "Skipped: ${file_skipped}"
  echo "Errors: ${file_errors}"
  echo "Backup: ${backup_path}"
  echo "---"
 } >> "${LOG_FILE}"
}

# Generate summary report
function __generate_summary() {
 __log_start

 local summary_file="${TEMP_DIR}/fix_summary.txt"
 {
  echo "=== AUTOMATED LOGGING PATTERN FIX SUMMARY ==="
  echo "Generated: $(date)"
  echo ""
  echo "STATISTICS:"
  echo "  Total functions processed: ${TOTAL_FUNCTIONS}"
  echo "  Functions fixed: ${FIXED_FUNCTIONS}"
  echo "  Functions skipped (already correct): ${SKIPPED_FUNCTIONS}"
  echo "  Functions with errors: ${ERROR_FUNCTIONS}"
  if [[ ${TOTAL_FUNCTIONS} -gt 0 ]]; then
   echo "  Success rate: $((FIXED_FUNCTIONS * 100 / TOTAL_FUNCTIONS))%"
  else
   echo "  Success rate: N/A (no functions found)"
  fi
  echo ""
  echo "BACKUP FILES:"
  echo "  Backup directory: ${BACKUP_DIR}"
  echo "  Log file: ${LOG_FILE}"
  echo ""
  echo "RECOMMENDATIONS:"
  if [[ ${ERROR_FUNCTIONS} -eq 0 ]]; then
   echo "  ✓ All functions were processed successfully!"
  else
   echo "  ⚠ ${ERROR_FUNCTIONS} functions had errors during processing"
   echo "  Check the log file for details: ${LOG_FILE}"
  fi
  echo ""
  echo "  📁 Backup files are available in: ${BACKUP_DIR}"
  echo "  📝 Detailed log available in: ${LOG_FILE}"
 } > "${summary_file}"

 # Display summary
 cat "${summary_file}"

 __log_finish
}

# Main function
function __main() {
 __log_start
 __logi "Starting automated logging pattern fixer"

 # Initialize
 __initialize_fix

 # Find all bash files in the project (excluding tests and hidden directories)
 local -a bash_files
 mapfile -t bash_files < <(find "${SCRIPT_BASE_DIRECTORY}" -type f \( -name "*.sh" -o -name "*.bash" \) -not -path "*/\.*" -not -path "*/tests/*" -not -path "*/mock_commands/*" | sort)

 __logi "Found ${#bash_files[@]} bash files to process"

 # Process each file
 for file_path in "${bash_files[@]}"; do
  __fix_file "${file_path}"
 done

 # Generate summary
 __generate_summary

 # Cleanup
 __cleanup_fix

 __logi "Automated logging pattern fixer completed"
 __log_finish
}

# Run main function
__main "$@"
