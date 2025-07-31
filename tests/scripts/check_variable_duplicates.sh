#!/bin/bash

# Variable Duplication Checker
# Script to detect duplicate variable declarations between scripts
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-30

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Function to extract readonly variables from a file
extract_readonly_vars() {
 local file_path="$1"
 grep -h "declare -r" "${file_path}" 2>/dev/null | \
  sed 's/declare -r \([A-Z_]*\)=.*/\1/' | sort
}

# Function to check for duplicates between two files
check_duplicates() {
 local file1="$1"
 local file2="$2"
 local description="$3"

 log_info "Checking duplicates between: ${description}"

 # Extract variables from both files
 local vars1
 vars1=$(extract_readonly_vars "${file1}")

 local vars2
 vars2=$(extract_readonly_vars "${file2}")

 # Find duplicates
 local duplicates
 duplicates=$(comm -12 <(echo "${vars1}") <(echo "${vars2}"))

 if [[ -n "${duplicates}" ]]; then
  log_error "Duplicate variables found between ${file1} and ${file2}:"
  echo "${duplicates}" | sed 's/^/  - /'
  return 1
 else
  log_success "No duplicates found between ${file1} and ${file2}"
  return 0
 fi
}

# Function to check all script pairs
check_all_script_pairs() {
 local has_errors=0

   # Define script pairs to check
  local script_pairs=(
   "${PROJECT_ROOT}/bin/process/processAPINotes.sh:${PROJECT_ROOT}/bin/processAPIFunctions.sh:processAPINotes.sh and processAPIFunctions.sh"
   "${PROJECT_ROOT}/bin/process/processPlanetNotes.sh:${PROJECT_ROOT}/bin/processPlanetFunctions.sh:processPlanetNotes.sh and processPlanetFunctions.sh"
   "${PROJECT_ROOT}/bin/cleanupAll.sh:${PROJECT_ROOT}/bin/validationFunctions.sh:cleanupAll.sh and validationFunctions.sh"
   "${PROJECT_ROOT}/bin/cleanupPartitions.sh:${PROJECT_ROOT}/bin/validationFunctions.sh:cleanupPartitions.sh and validationFunctions.sh"
   "${PROJECT_ROOT}/bin/functionsProcess.sh:${PROJECT_ROOT}/bin/commonFunctions.sh:functionsProcess.sh and commonFunctions.sh"
   "${PROJECT_ROOT}/bin/processAPIFunctions.sh:${PROJECT_ROOT}/bin/processPlanetFunctions.sh:processAPIFunctions.sh and processPlanetFunctions.sh"
   "${PROJECT_ROOT}/bin/processPlanetFunctions.sh:${PROJECT_ROOT}/bin/monitor/processCheckPlanetNotes.sh:processPlanetFunctions.sh and processCheckPlanetNotes.sh"
   "${PROJECT_ROOT}/bin/process/updateCountries.sh:${PROJECT_ROOT}/bin/validationFunctions.sh:updateCountries.sh and validationFunctions.sh"
   "${PROJECT_ROOT}/bin/monitor/notesCheckVerifier.sh:${PROJECT_ROOT}/bin/validationFunctions.sh:notesCheckVerifier.sh and validationFunctions.sh"
   "${PROJECT_ROOT}/bin/monitor/processCheckPlanetNotes.sh:${PROJECT_ROOT}/bin/validationFunctions.sh:processCheckPlanetNotes.sh and validationFunctions.sh"
   "${PROJECT_ROOT}/bin/dwh/datamartCountries/datamartCountries.sh:${PROJECT_ROOT}/bin/validationFunctions.sh:datamartCountries.sh and validationFunctions.sh"
   "${PROJECT_ROOT}/bin/dwh/datamartUsers/datamartUsers.sh:${PROJECT_ROOT}/bin/validationFunctions.sh:datamartUsers.sh and validationFunctions.sh"
   "${PROJECT_ROOT}/bin/dwh/profile.sh:${PROJECT_ROOT}/bin/validationFunctions.sh:profile.sh and validationFunctions.sh"
   "${PROJECT_ROOT}/bin/dwh/ETL.sh:${PROJECT_ROOT}/bin/validationFunctions.sh:ETL.sh and validationFunctions.sh"
  )

 for pair in "${script_pairs[@]}"; do
  IFS=':' read -r file1 file2 description <<< "${pair}"
  
  if [[ -f "${file1}" && -f "${file2}" ]]; then
   if ! check_duplicates "${file1}" "${file2}" "${description}"; then
    has_errors=1
   fi
  else
   log_warning "Skipping check for ${description} - one or both files not found"
  fi
 done

 return "${has_errors}"
}

# Function to test script sourcing
test_script_sourcing() {
 log_info "Testing script sourcing to detect readonly errors..."

 local has_errors=0

 # Test processAPINotes.sh
 log_info "Testing processAPINotes.sh sourcing..."
 local api_output
 api_output=$(bash -c "
  cd '${PROJECT_ROOT}/bin/process' && \
  source 'processAPINotes.sh' --help
 " 2>&1)
 if [[ $? -ne 0 ]]; then
  # Check if it's a readonly variable error
  if echo "${api_output}" | grep -q "variable de sólo lectura\|readonly variable"; then
   log_error "processAPINotes.sh has readonly variable conflicts"
   echo "Error output: ${api_output}"
   has_errors=1
  else
   log_success "processAPINotes.sh sources correctly (non-readonly error ignored)"
  fi
 else
  log_success "processAPINotes.sh sources correctly"
 fi

 # Test processPlanetNotes.sh
 log_info "Testing processPlanetNotes.sh sourcing..."
 local planet_output
 planet_output=$(bash -c "
  cd '${PROJECT_ROOT}/bin/process' && \
  source 'processPlanetNotes.sh' --help
 " 2>&1)
 if [[ $? -ne 0 ]]; then
  # Check if it's a readonly variable error
  if echo "${planet_output}" | grep -q "variable de sólo lectura\|readonly variable"; then
   log_error "processPlanetNotes.sh has readonly variable conflicts"
   echo "Error output: ${planet_output}"
   has_errors=1
  else
   log_success "processPlanetNotes.sh sources correctly (non-readonly error ignored)"
  fi
 else
  log_success "processPlanetNotes.sh sources correctly"
 fi

 # Test all main scripts
 log_info "Testing all main scripts sourcing..."
 local main_scripts=(
  "${PROJECT_ROOT}/bin/process/updateCountries.sh"
  "${PROJECT_ROOT}/bin/monitor/notesCheckVerifier.sh"
  "${PROJECT_ROOT}/bin/monitor/processCheckPlanetNotes.sh"
  "${PROJECT_ROOT}/bin/dwh/datamartCountries/datamartCountries.sh"
  "${PROJECT_ROOT}/bin/dwh/datamartUsers/datamartUsers.sh"
  "${PROJECT_ROOT}/bin/dwh/profile.sh"
  "${PROJECT_ROOT}/bin/dwh/ETL.sh"
  "${PROJECT_ROOT}/bin/cleanupAll.sh"
  "${PROJECT_ROOT}/bin/cleanupPartitions.sh"
 )

 for script in "${main_scripts[@]}"; do
  if [[ -f "${script}" ]]; then
   local script_output
   script_output=$(bash -c "source '${script}' --help" 2>&1)
   if [[ $? -ne 0 ]]; then
    # Check if it's a readonly variable error or just a normal script behavior
    if echo "${script_output}" | grep -q "variable de sólo lectura\|readonly variable"; then
     log_error "$(basename "${script}") has readonly variable conflicts"
     echo "Error output: ${script_output}"
     has_errors=1
    else
     log_success "$(basename "${script}") sources correctly (non-readonly error ignored)"
    fi
   else
    log_success "$(basename "${script}") sources correctly"
   fi
  else
   log_warning "Script not found: ${script}"
  fi
 done

 return "${has_errors}"
}

# Function to show help
show_help() {
 echo "Variable Duplication Checker"
 echo
 echo "Usage: $0 [OPTIONS]"
 echo
 echo "Options:"
 echo "  -h, --help     Show this help message"
 echo "  -s, --source   Test script sourcing (default)"
 echo "  -d, --duplicates  Check for duplicate variables only"
 echo "  -a, --all      Run all checks (default)"
 echo
 echo "This script checks for duplicate readonly variable declarations"
 echo "between related scripts to prevent 'variable de sólo lectura' errors."
}

# Main function
main() {
 local check_duplicates_only=false
 local check_sourcing_only=false

 # Parse command line arguments
 while [[ $# -gt 0 ]]; do
  case $1 in
   -h|--help)
    show_help
    exit 0
    ;;
   -d|--duplicates)
    check_duplicates_only=true
    shift
    ;;
   -s|--source)
    check_sourcing_only=true
    shift
    ;;
   -a|--all)
    check_duplicates_only=false
    check_sourcing_only=false
    shift
    ;;
   *)
    log_error "Unknown option: $1"
    show_help
    exit 1
    ;;
  esac
 done

 echo "=========================================="
 echo "Variable Duplication Checker"
 echo "=========================================="

 local has_errors=0

 # Check for duplicate variables
 if [[ "${check_sourcing_only}" == "false" ]]; then
  log_info "Checking for duplicate readonly variables..."
  if ! check_all_script_pairs; then
   has_errors=1
  fi
 fi

 # Test script sourcing
 if [[ "${check_duplicates_only}" == "false" ]]; then
  if ! test_script_sourcing; then
   has_errors=1
  fi
 fi

 echo
 echo "=========================================="
 echo "CHECK SUMMARY"
 echo "=========================================="

 if [[ ${has_errors} -eq 0 ]]; then
  log_success "All checks passed! No variable duplication issues found."
  exit 0
 else
  log_error "Variable duplication issues found! Please fix the conflicts."
  exit 1
 fi
}

# Run main function
main "$@" 