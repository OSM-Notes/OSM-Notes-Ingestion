#!/bin/bash

# Script to identify functions missing logging patterns
# Script: identify_missing_logging.sh
# Author: Andres Gomez (AngocA)
# Version: 2025-08-13
# Description: Identifies specific functions missing __log_start and __log_finish

set -euo pipefail

# Source common functions
SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_BASE_DIRECTORY}/lib/bash_logger.sh"

# Functions that don't require logging (special cases)
# NOTE: Actually, ALL functions should have logging for consistency
# These are kept for reference but will be treated as requiring logging
declare -r EXEMPT_FUNCTIONS=(
)

# Colors for output
declare -r RED='\033[0;31m'
declare -r GREEN='\033[0;32m'
declare -r YELLOW='\033[1;33m'
declare -r NC='\033[0m' # No Color

# Print colored output
function __print_colored() {
 local color="$1"
 local message="$2"
 printf "%b%s%b\n" "${color}" "${message}" "${NC}"
}

# Analyze a single bash file
function __analyze_file() {
 local file_path="$1"
 local file_name
 file_name=$(basename "${file_path}")

 # Skip if not a bash file
 if [[ ! "${file_path}" =~ \.(sh|bash)$ ]]; then
  return 0
 fi

 # Check if file has functions
 if ! grep -q "^function [a-zA-Z_][a-zA-Z0-9_]*" "${file_path}"; then
  return 0
 fi

 echo "=== ${file_name} ==="

 # Get all function names in the file
 local -a function_names
 mapfile -t function_names < <(grep "^function [a-zA-Z_][a-zA-Z0-9_]*" "${file_path}" | sed 's/^function \([a-zA-Z_][a-zA-Z0-9_]*\).*/\1/')

 local total_functions=${#function_names[@]}
 local exempt_count=0
 local missing_start=0
 local missing_finish=0

 echo "Total functions: ${total_functions}"

 # Analyze each function
 for func_name in "${function_names[@]}"; do
  local is_exempt=false
  
  # Check if function is exempt
  for exempt_func in "${EXEMPT_FUNCTIONS[@]}"; do
   if [[ "${func_name}" == "${exempt_func}" ]]; then
    is_exempt=true
    exempt_count=$((exempt_count + 1))
    break
   fi
  done

  if [[ "${is_exempt}" == "true" ]]; then
   echo "  ✓ ${func_name} (EXEMPT)"
   continue
  fi

  # Check if function has __log_start
  local has_start=false
  if grep -A 20 "^function ${func_name}" "${file_path}" | grep -q "^[[:space:]]*__log_start"; then
   has_start=true
  fi

  # Check if function has __log_finish
  local has_finish=false
  if grep -A 50 "^function ${func_name}" "${file_path}" | grep -q "^[[:space:]]*__log_finish"; then
   has_finish=true
  fi

  if [[ "${has_start}" == "true" ]] && [[ "${has_finish}" == "true" ]]; then
   echo "  ✓ ${func_name}"
  else
   echo "  ✗ ${func_name}"
   if [[ "${has_start}" == "false" ]]; then
    echo "    - Missing __log_start"
    missing_start=$((missing_start + 1))
   fi
   if [[ "${has_finish}" == "false" ]]; then
    echo "    - Missing __log_finish"
    missing_finish=$((missing_finish + 1))
   fi
  fi
 done

 echo "Summary:"
 echo "  Exempt functions: ${exempt_count}"
 echo "  Functions missing __log_start: ${missing_start}"
 echo "  Functions missing __log_finish: ${missing_finish}"
 echo "  Required functions: $((total_functions - exempt_count))"
 echo ""
}

# Main function
function __main() {
 __log_start
 __logi "Identifying functions missing logging patterns"

 # Find all bash files in the project (excluding tests and hidden directories)
 local -a bash_files
 mapfile -t bash_files < <(find "${SCRIPT_BASE_DIRECTORY}" -type f \( -name "*.sh" -o -name "*.bash" \) -not -path "*/\.*" -not -path "*/tests/*" -not -path "*/mock_commands/*" | sort)

 __logi "Found ${#bash_files[@]} bash files to analyze"

 # Analyze each file
 for file_path in "${bash_files[@]}"; do
  __analyze_file "${file_path}"
 done

 __logi "Analysis completed"
 __log_finish
}

# Run main function
__main "$@"
