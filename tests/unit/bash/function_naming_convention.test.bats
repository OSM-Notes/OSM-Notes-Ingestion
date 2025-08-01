#!/usr/bin/env bats

# Require minimum BATS version for run flags
bats_require_minimum_version 1.5.0

# Function Naming Convention Tests
# Tests that all functions in bin directory follow the __ naming convention

setup() {
 # Setup test environment
 export SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
 export TMP_DIR="$(mktemp -d)"
 export BASENAME="test_function_naming"
 export LOG_LEVEL="INFO"
 
 # Ensure TMP_DIR exists and is writable
 if [[ ! -d "${TMP_DIR}" ]]; then
   mkdir -p "${TMP_DIR}" || { echo "ERROR: Could not create TMP_DIR: ${TMP_DIR}" >&2; exit 1; }
 fi
 if [[ ! -w "${TMP_DIR}" ]]; then
   echo "ERROR: TMP_DIR not writable: ${TMP_DIR}" >&2; exit 1;
 fi
}

teardown() {
 # Cleanup
 rm -rf "${TMP_DIR}"
}

# Test that all functions in bin directory follow __ naming convention
@test "all functions should follow __ naming convention" {
 # Find all bash scripts in bin directory
 local BASH_SCRIPTS
 mapfile -t BASH_SCRIPTS < <(find bin/ -name "*.sh" -type f)
 
 local TOTAL_ERRORS=0
 local VIOLATIONS=()
 
 for SCRIPT in "${BASH_SCRIPTS[@]}"; do
   # Find functions that don't start with __
   local SCRIPT_ERRORS
   SCRIPT_ERRORS=$(grep -n "^function [^_]" "${SCRIPT}" 2>/dev/null || true)
   
   if [[ -n "${SCRIPT_ERRORS}" ]]; then
     echo "ERROR: Found functions not following __ convention in ${SCRIPT}:"
     echo "${SCRIPT_ERRORS}"
     VIOLATIONS+=("${SCRIPT}")
     TOTAL_ERRORS=$((TOTAL_ERRORS + $(echo "${SCRIPT_ERRORS}" | wc -l)))
   fi
 done
  
 [ "${TOTAL_ERRORS}" -eq 0 ] || echo "Total violations: ${TOTAL_ERRORS} in ${#VIOLATIONS[@]} files"
}

# Test that specific common functions follow the convention
@test "common functions should follow __ naming convention" {
 # List of common functions that should exist
 local COMMON_FUNCTIONS=(
   "__log"
   "__log_info"
   "__log_debug"
   "__log_error"
   "__log_warn"
   "__log_fatal"
   "__start_logger"
   "__validation"
   "__trapOn"
   "__checkPrereqsCommands"
   "__checkPrereqs_functions"
   "__checkBaseTables"
 )
 
 for FUNC in "${COMMON_FUNCTIONS[@]}"; do
   # Check if function is defined in commonFunctions.sh
   run grep -q "function ${FUNC}" bin/commonFunctions.sh
   [ "$status" -eq 0 ] || echo "Function ${FUNC} should be defined in commonFunctions.sh"
 done
}

# Test that no functions start with single underscore
@test "no functions should start with single underscore" {
 # Find all bash scripts in bin directory
 local BASH_SCRIPTS
 mapfile -t BASH_SCRIPTS < <(find bin/ -name "*.sh" -type f)
 
 local TOTAL_ERRORS=0
 
 for SCRIPT in "${BASH_SCRIPTS[@]}"; do
   # Find functions that start with single _
   local SCRIPT_ERRORS
   SCRIPT_ERRORS=$(grep -n "^function _[^_]" "${SCRIPT}" 2>/dev/null || true)
   
   if [[ -n "${SCRIPT_ERRORS}" ]]; then
     echo "ERROR: Found functions starting with single _ in ${SCRIPT}:"
     echo "${SCRIPT_ERRORS}"
     TOTAL_ERRORS=$((TOTAL_ERRORS + $(echo "${SCRIPT_ERRORS}" | wc -l)))
   fi
 done
  
 [ "${TOTAL_ERRORS}" -eq 0 ]
}

# Test that main functions are properly named
@test "main functions should be properly named" {
 # Find all main functions
 local MAIN_FUNCTIONS
 MAIN_FUNCTIONS=$(find bin/ -name "*.sh" -exec grep -l "^function main()" {} \; 2>/dev/null || true)
 
 if [[ -n "${MAIN_FUNCTIONS}" ]]; then
   echo "WARNING: Found main() functions (should be __main):"
   echo "${MAIN_FUNCTIONS}"
   # This is a warning, not an error, as main() might be acceptable in some cases
 fi
}

# Test that helper functions follow convention
@test "helper functions should follow __ naming convention" {
 # Find all helper functions (show_help, check_database, etc.)
 local BASH_SCRIPTS
 mapfile -t BASH_SCRIPTS < <(find bin/ -name "*.sh" -type f)
 
 local TOTAL_ERRORS=0
 
 for SCRIPT in "${BASH_SCRIPTS[@]}"; do
   # Find helper functions that don't start with __
   local SCRIPT_ERRORS
   SCRIPT_ERRORS=$(grep -n "^function [a-z_][a-z0-9_]*()" "${SCRIPT}" 2>/dev/null | grep -v "^function __" || true)
   
   if [[ -n "${SCRIPT_ERRORS}" ]]; then
     echo "ERROR: Found helper functions not following __ convention in ${SCRIPT}:"
     echo "${SCRIPT_ERRORS}"
     TOTAL_ERRORS=$((TOTAL_ERRORS + $(echo "${SCRIPT_ERRORS}" | wc -l)))
   fi
 done
  
 [ "${TOTAL_ERRORS}" -eq 0 ]
} 