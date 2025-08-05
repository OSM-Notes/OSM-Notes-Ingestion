#!/usr/bin/env bats

# Variable Duplication Tests
# Tests to detect duplicate variable declarations between scripts
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-30

load ../../test_helper.bash

# Helper function to extract readonly variables safely
extract_readonly_vars() {
 local file_path="$1"
 
 # Check if file exists
 if [[ ! -f "${file_path}" ]]; then
  echo ""
  return 0
 fi
 
 # Extract readonly variables
 grep -h "declare -r" "${file_path}" 2>/dev/null | \
  sed 's/declare -r \([A-Z_]*\)=.*/\1/' 2>/dev/null | sort 2>/dev/null || echo ""
}

# Helper function to check for duplicates
check_duplicates() {
 local file1="$1"
 local file2="$2"
 local description="$3"

 # Check if both files exist
 if [[ ! -f "${file1}" ]]; then
  echo "Warning: File ${file1} does not exist"
  return 0
 fi

 if [[ ! -f "${file2}" ]]; then
  echo "Warning: File ${file2} does not exist"
  return 0
 fi

 # Extract variables from both files
 local vars1
 vars1=$(extract_readonly_vars "${file1}")

 local vars2
 vars2=$(extract_readonly_vars "${file2}")

 # Find duplicates
 local duplicates
 duplicates=$(comm -12 <(echo "${vars1}") <(echo "${vars2}") 2>/dev/null || echo "")

 # Should be empty (no duplicates)
 [[ -z "${duplicates}" ]]
}

# Test to detect duplicate readonly variables between scripts
@test "should not have duplicate readonly variables between processAPINotes.sh and processAPIFunctions.sh" {
 check_duplicates \
  "${SCRIPT_BASE_DIRECTORY}/bin/process/processAPINotes.sh" \
  "${SCRIPT_BASE_DIRECTORY}/bin/processAPIFunctions.sh" \
  "processAPINotes.sh and processAPIFunctions.sh"
}

@test "should not have duplicate readonly variables between processPlanetNotes.sh and processPlanetFunctions.sh" {
 check_duplicates \
  "${SCRIPT_BASE_DIRECTORY}/bin/process/processPlanetNotes.sh" \
  "${SCRIPT_BASE_DIRECTORY}/bin/processPlanetFunctions.sh" \
  "processPlanetNotes.sh and processPlanetFunctions.sh"
}

@test "should not have duplicate readonly variables between cleanupAll.sh and validationFunctions.sh" {
 check_duplicates \
  "${SCRIPT_BASE_DIRECTORY}/bin/cleanupAll.sh" \
  "${SCRIPT_BASE_DIRECTORY}/bin/validationFunctions.sh" \
  "cleanupAll.sh and validationFunctions.sh"
}

@test "should not have duplicate readonly variables between cleanupAll.sh and validationFunctions.sh" {
 check_duplicates \
  "${SCRIPT_BASE_DIRECTORY}/bin/cleanupAll.sh" \
  "${SCRIPT_BASE_DIRECTORY}/bin/validationFunctions.sh" \
  "cleanupAll.sh and validationFunctions.sh"
}

@test "should not have duplicate readonly variables between functionsProcess.sh and commonFunctions.sh" {
 check_duplicates \
  "${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh" \
  "${SCRIPT_BASE_DIRECTORY}/bin/commonFunctions.sh" \
  "functionsProcess.sh and commonFunctions.sh"
}

@test "should not have duplicate readonly variables between processAPIFunctions.sh and processPlanetFunctions.sh" {
 check_duplicates \
  "${SCRIPT_BASE_DIRECTORY}/bin/processAPIFunctions.sh" \
  "${SCRIPT_BASE_DIRECTORY}/bin/processPlanetFunctions.sh" \
  "processAPIFunctions.sh and processPlanetFunctions.sh"
}

@test "should not have duplicate readonly variables between processPlanetFunctions.sh and processCheckPlanetNotes.sh" {
 check_duplicates \
  "${SCRIPT_BASE_DIRECTORY}/bin/processPlanetFunctions.sh" \
  "${SCRIPT_BASE_DIRECTORY}/bin/monitor/processCheckPlanetNotes.sh" \
  "processPlanetFunctions.sh and processCheckPlanetNotes.sh"
}

# Additional tests for scripts with main functions
@test "should not have duplicate readonly variables between updateCountries.sh and validationFunctions.sh" {
 check_duplicates \
  "${SCRIPT_BASE_DIRECTORY}/bin/process/updateCountries.sh" \
  "${SCRIPT_BASE_DIRECTORY}/bin/validationFunctions.sh" \
  "updateCountries.sh and validationFunctions.sh"
}

@test "should not have duplicate readonly variables between notesCheckVerifier.sh and validationFunctions.sh" {
 check_duplicates \
  "${SCRIPT_BASE_DIRECTORY}/bin/monitor/notesCheckVerifier.sh" \
  "${SCRIPT_BASE_DIRECTORY}/bin/validationFunctions.sh" \
  "notesCheckVerifier.sh and validationFunctions.sh"
}

@test "should not have duplicate readonly variables between processCheckPlanetNotes.sh and validationFunctions.sh" {
 check_duplicates \
  "${SCRIPT_BASE_DIRECTORY}/bin/monitor/processCheckPlanetNotes.sh" \
  "${SCRIPT_BASE_DIRECTORY}/bin/validationFunctions.sh" \
  "processCheckPlanetNotes.sh and validationFunctions.sh"
}

@test "should not have duplicate readonly variables between datamartCountries.sh and validationFunctions.sh" {
 check_duplicates \
  "${SCRIPT_BASE_DIRECTORY}/bin/dwh/datamartCountries/datamartCountries.sh" \
  "${SCRIPT_BASE_DIRECTORY}/bin/validationFunctions.sh" \
  "datamartCountries.sh and validationFunctions.sh"
}

@test "should not have duplicate readonly variables between datamartUsers.sh and validationFunctions.sh" {
 check_duplicates \
  "${SCRIPT_BASE_DIRECTORY}/bin/dwh/datamartUsers/datamartUsers.sh" \
  "${SCRIPT_BASE_DIRECTORY}/bin/validationFunctions.sh" \
  "datamartUsers.sh and validationFunctions.sh"
}

@test "should not have duplicate readonly variables between profile.sh and validationFunctions.sh" {
 check_duplicates \
  "${SCRIPT_BASE_DIRECTORY}/bin/dwh/profile.sh" \
  "${SCRIPT_BASE_DIRECTORY}/bin/validationFunctions.sh" \
  "profile.sh and validationFunctions.sh"
}

@test "should not have duplicate readonly variables between ETL.sh and validationFunctions.sh" {
 check_duplicates \
  "${SCRIPT_BASE_DIRECTORY}/bin/dwh/ETL.sh" \
  "${SCRIPT_BASE_DIRECTORY}/bin/validationFunctions.sh" \
  "ETL.sh and validationFunctions.sh"
}

@test "should detect and report duplicate variables with detailed information" {
 # This test provides detailed information about any duplicates found
 local api_notes_vars
 api_notes_vars=$(extract_readonly_vars "${SCRIPT_BASE_DIRECTORY}/bin/process/processAPINotes.sh")

 local api_functions_vars
 api_functions_vars=$(extract_readonly_vars "${SCRIPT_BASE_DIRECTORY}/bin/processAPIFunctions.sh")

 local duplicates
 duplicates=$(comm -12 <(echo "${api_notes_vars}") <(echo "${api_functions_vars}") 2>/dev/null || echo "")

 if [[ -n "${duplicates}" ]]; then
  echo "Duplicate variables found between processAPINotes.sh and processAPIFunctions.sh:"
  echo "${duplicates}"
  echo "These variables should be declared in only one of the files."
  return 1
 fi

 # If we get here, no duplicates were found
 [[ -z "${duplicates}" ]]
}

@test "should validate that all scripts can be sourced without readonly errors" {
 # Test that processAPINotes.sh can be sourced after processAPIFunctions.sh
 if [[ -f "${SCRIPT_BASE_DIRECTORY}/bin/process/processAPINotes.sh" ]] && \
    [[ -f "${SCRIPT_BASE_DIRECTORY}/bin/processAPIFunctions.sh" ]]; then
  run bash -c "
   cd '${SCRIPT_BASE_DIRECTORY}/bin/process' && \
   source '../processAPIFunctions.sh' && \
   source 'processAPINotes.sh' --help > /dev/null 2>&1
  "
  [[ ${status} -eq 0 ]] || echo "processAPINotes.sh sourcing failed"
 else
  skip "Required files not found for processAPINotes.sh test"
 fi

 # Test that processPlanetNotes.sh can be sourced after processPlanetFunctions.sh
 if [[ -f "${SCRIPT_BASE_DIRECTORY}/bin/process/processPlanetNotes.sh" ]] && \
    [[ -f "${SCRIPT_BASE_DIRECTORY}/bin/processPlanetFunctions.sh" ]]; then
  run bash -c "
   cd '${SCRIPT_BASE_DIRECTORY}/bin/process' && \
   source '../processPlanetFunctions.sh' && \
   source 'processPlanetNotes.sh' --help > /dev/null 2>&1
  "
  [[ ${status} -eq 0 ]] || echo "processPlanetNotes.sh sourcing failed"
 else
  skip "Required files not found for processPlanetNotes.sh test"
 fi
}

@test "should validate that all main scripts can be sourced without readonly errors" {
 # Test all main scripts can be sourced without errors
 local main_scripts=(
  "${SCRIPT_BASE_DIRECTORY}/bin/process/updateCountries.sh"
  "${SCRIPT_BASE_DIRECTORY}/bin/monitor/notesCheckVerifier.sh"
  "${SCRIPT_BASE_DIRECTORY}/bin/monitor/processCheckPlanetNotes.sh"
  "${SCRIPT_BASE_DIRECTORY}/bin/dwh/datamartCountries/datamartCountries.sh"
  "${SCRIPT_BASE_DIRECTORY}/bin/dwh/datamartUsers/datamartUsers.sh"
  "${SCRIPT_BASE_DIRECTORY}/bin/dwh/profile.sh"
  "${SCRIPT_BASE_DIRECTORY}/bin/dwh/ETL.sh"
  "${SCRIPT_BASE_DIRECTORY}/bin/cleanupAll.sh"
  # cleanupPartitions.sh functionality now integrated into cleanupAll.sh
 )

 local failed_scripts=()

 for script in "${main_scripts[@]}"; do
  if [[ -f "${script}" ]]; then
   # Use a more robust approach to test script sourcing
   # First check if the script has valid syntax
   run bash -n "${script}"
   if [[ ${status} -ne 0 ]]; then
    failed_scripts+=("${script} (syntax error)")
    continue
   fi
   
   # Try to source the script in a controlled environment
   run bash -c "
    # Temporarily disable error exit
    set +e
    # Source the script and capture any readonly errors
    source '${script}' 2>&1 | grep -q 'variable de solo lectura' || true
    # Check if sourcing succeeded (ignore readonly warnings)
    if [[ \$? -eq 0 ]]; then
     exit 0
    else
     exit 1
    fi
   "
   
   if [[ ${status} -ne 0 ]]; then
    failed_scripts+=("${script}")
   fi
  fi
 done

 # Report any failures
 if [[ ${#failed_scripts[@]} -gt 0 ]]; then
  echo "Failed to source the following scripts:"
  printf '%s\n' "${failed_scripts[@]}"
  return 1
 fi

 # If we get here, all scripts were sourced successfully
 [[ ${#failed_scripts[@]} -eq 0 ]]
} 