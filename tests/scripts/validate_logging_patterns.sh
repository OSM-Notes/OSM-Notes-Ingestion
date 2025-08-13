#!/bin/bash

# Logging Pattern Validation Script
# Script: validate_logging_patterns.sh
# Author: Andres Gomez (AngocA)
# Version: 2025-01-23
# Description: Validates that all bash functions follow the logging pattern:
#             - __log_start at the beginning
#             - __log_finish before each return and at the end

set -euo pipefail

# Source common functions
SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_BASE_DIRECTORY}/lib/bash_logger.sh"

# Configuration
declare -r MAX_LINE_LENGTH=80
declare -r TEMP_DIR="/tmp/logging_validation_$$"
declare -r RESULTS_FILE="${TEMP_DIR}/validation_results.txt"
declare -r SUMMARY_FILE="${TEMP_DIR}/validation_summary.txt"

# Statistics
declare -i TOTAL_FUNCTIONS=0
declare -i VALID_FUNCTIONS=0
declare -i INVALID_FUNCTIONS=0
declare -i MISSING_LOG_START=0
declare -i MISSING_LOG_FINISH=0
declare -i MISSING_BOTH=0

# Colors for output
declare -r RED='\033[0;31m'
declare -r GREEN='\033[0;32m'
declare -r YELLOW='\033[1;33m'
declare -r BLUE='\033[0;34m'
declare -r NC='\033[0m' # No Color

# Initialize environment
function __initialize_validation() {
    __log_start
    
    # Create temporary directory
    mkdir -p "${TEMP_DIR}"
    
    # Initialize results files
    > "${RESULTS_FILE}"
    > "${SUMMARY_FILE}"
    
    __logi "Logging pattern validation initialized"
    __logi "Temporary directory: ${TEMP_DIR}"
    __logi "Results file: ${RESULTS_FILE}"
    __logi "Summary file: ${SUMMARY_FILE}"
    
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

# Validate a single bash file
function __validate_bash_file() {
    local file_path="$1"
    local file_name
    file_name=$(basename "${file_path}")
    
    __logd "Validating file: ${file_name}"
    
    # Skip if not a bash file
    if [[ ! "${file_path}" =~ \.(sh|bash)$ ]]; then
        __logd "Skipping non-bash file: ${file_name}"
        return 0
    fi
    
    # Read file content
    local content
    __logd "Reading file content: ${file_path}"
    if ! content=$(cat "${file_path}" 2>/dev/null); then
        __logw "WARNING: Could not read file: ${file_path}"
        return 1
    fi
    
    # Find function definitions
    __logd "Searching for function definitions in: ${file_name}"
    local -a function_lines
    mapfile -t function_lines < <(echo "${content}" | grep -n "^function [a-zA-Z_][a-zA-Z0-9_]*" || true)
    
    __logd "Found ${#function_lines[@]} functions in: ${file_name}"
    
    if [[ ${#function_lines[@]} -eq 0 ]]; then
        __logd "No functions found in: ${file_name}"
        return 0
    fi
    
    # Process each function
    __logd "Processing functions in: ${file_name}"
    for function_line in "${function_lines[@]}"; do
        local line_number="${function_line%%:*}"
        local function_name="${function_line#*:}"
        function_name="${function_name#function }"
        function_name="${function_name%%(*}"
        
        __logd "Validating function: ${function_name} at line ${line_number}"
        __validate_function_in_file "${file_path}" "${function_name}" "${line_number}" "${content}"
    done
    
    __logd "Completed validation of file: ${file_name}"
}

# Validate a single function in a file
function __validate_function_in_file() {
    local file_path="$1"
    local function_name="$2"
    local start_line="$3"
    local content="$4"
    
    local file_name
    file_name=$(basename "${file_path}")
    
    __logd "Validating function: ${function_name} in ${file_name}:${start_line}"
    
    # Find function boundaries (simplified approach)
    local function_start="${start_line}"
    local function_end
    
    # Use a simpler approach to find function boundaries
    # Look for the next function or end of file within a reasonable range
    local search_range=100  # Limit search to avoid hanging on very large files
    
    # Find the end of the function (next function or end of file)
    local next_function_line
    next_function_line=$(echo "${content}" | tail -n +$((start_line + 1)) | head -n "${search_range}" | grep -n "^function " | head -1 | cut -d: -f1)
    
    if [[ -n "${next_function_line}" ]]; then
        function_end=$((start_line + next_function_line - 1))
    else
        # If no next function found, use a reasonable limit
        function_end=$((start_line + search_range))
        local total_lines
        total_lines=$(echo "${content}" | wc -l)
        if [[ "${function_end}" -gt "${total_lines}" ]]; then
            function_end="${total_lines}"
        fi
    fi
    
    # Extract function content (with timeout)
    local function_content
    function_content=$(timeout 10s echo "${content}" | sed -n "${function_start},${function_end}p" 2>/dev/null || echo "")
    
    if [[ -z "${function_content}" ]]; then
        __logw "WARNING: Could not extract function content for ${function_name} in ${file_name}"
        return 1
    fi
    
    # Check for __log_start (simplified)
    local has_log_start=false
    if echo "${function_content}" | head -20 | grep -q "^[[:space:]]*__log_start"; then
        has_log_start=true
    fi
    
    # Check for __log_finish (simplified)
    local has_log_finish=false
    if echo "${function_content}" | grep -q "^[[:space:]]*__log_finish"; then
        has_log_finish=true
    fi
    
    # Check for returns without __log_finish (simplified)
    local returns_without_finish=0
    local total_returns=0
    
    # Count returns (with timeout)
    total_returns=$(timeout 5s echo "${function_content}" | grep -c "^[[:space:]]*return" 2>/dev/null || echo "0")
    
    # Simplified return checking - just check if there are returns and if __log_finish exists
    if [[ "${total_returns}" -gt 0 ]] && [[ "${has_log_finish}" == "false" ]]; then
        returns_without_finish="${total_returns}"
    fi
    
    # Determine validation status
    local is_valid=true
    local issues=()
    
    if [[ "${has_log_start}" == "false" ]]; then
        is_valid=false
        issues+=("missing __log_start")
        ((MISSING_LOG_START++))
    fi
    
    if [[ "${has_log_finish}" == "false" ]]; then
        is_valid=false
        issues+=("missing __log_finish")
        ((MISSING_LOG_FINISH++))
    fi
    
    if [[ "${returns_without_finish}" -gt 0 ]]; then
        is_valid=false
        issues+=("${returns_without_finish} return(s) without __log_finish")
    fi
    
    if [[ "${has_log_start}" == "false" && "${has_log_finish}" == "false" ]]; then
        ((MISSING_BOTH++))
    fi
    
    # Update statistics
    ((TOTAL_FUNCTIONS++))
    
    if [[ "${is_valid}" == "true" ]]; then
        ((VALID_FUNCTIONS++))
    else
        ((INVALID_FUNCTIONS++))
    fi
    
    # Record results
    {
        echo "File: ${file_path}"
        echo "Function: ${function_name}"
        echo "Line: ${start_line}"
        echo "Status: ${is_valid}"
        echo "Issues: ${issues[*]:-none}"
        echo "Returns: ${total_returns}"
        echo "Returns without __log_finish: ${returns_without_finish}"
        echo "---"
    } >> "${RESULTS_FILE}"
    
    # Print result
    if [[ "${is_valid}" == "true" ]]; then
        __print_colored "${GREEN}" "✓ ${function_name} in ${file_name}:${start_line}"
    else
        __print_colored "${RED}" "✗ ${function_name} in ${file_name}:${start_line} - ${issues[*]}"
    fi
}

# Generate summary report
function __generate_summary() {
    __log_start
    
    {
        echo "=== LOGGING PATTERN VALIDATION SUMMARY ==="
        echo "Generated: $(date)"
        echo ""
        echo "STATISTICS:"
        echo "  Total functions analyzed: ${TOTAL_FUNCTIONS}"
        echo "  Valid functions: ${VALID_FUNCTIONS}"
        echo "  Invalid functions: ${INVALID_FUNCTIONS}"
        echo "  Success rate: $((VALID_FUNCTIONS * 100 / TOTAL_FUNCTIONS))%"
        echo ""
        echo "ISSUES BREAKDOWN:"
        echo "  Missing __log_start: ${MISSING_LOG_START}"
        echo "  Missing __log_finish: ${MISSING_LOG_FINISH}"
        echo "  Missing both: ${MISSING_BOTH}"
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
    
    __logi "Starting logging pattern validation for all bash files"
    
    # Find all bash files in the project
    local -a bash_files
    mapfile -t bash_files < <(find "${SCRIPT_BASE_DIRECTORY}" -type f \( -name "*.sh" -o -name "*.bash" \) -not -path "*/\.*" -not -path "*/tests/*" | sort)
    
    __logi "Found ${#bash_files[@]} bash files to validate"
    
    # Validate each file
    __logi "Starting file validation loop..."
    for file_path in "${bash_files[@]}"; do
        __logd "Processing file: ${file_path}"
        __validate_bash_file "${file_path}"
        __logd "Completed file: ${file_path}"
    done
    
    __logi "Validation completed."
    
    __log_finish
}

# Main execution
function main() {
    __log_start
    
    # Set up error handling
    trap '__loge "ERROR: Validation interrupted" && __cleanup_validation && exit 1' INT TERM
    
    __logi "Logging Pattern Validation Tool"
    __logi "This tool validates that all bash functions follow the logging pattern"
    
    # Initialize
    __initialize_validation
    
    # Run validation
    __run_validation
    
    # Generate summary before cleanup
    __logi "Validation completed. Generating summary..."
    __generate_summary
    
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
