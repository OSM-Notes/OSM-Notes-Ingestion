#!/usr/bin/env bats

# Variable Duplication Tests
# Tests to detect duplicate variable declarations between scripts
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-30

load ../../test_helper.bash

# Test to detect duplicate readonly variables between scripts
@test "should not have duplicate readonly variables between processAPINotes.sh and processAPIFunctions.sh" {
 # Get all readonly variables from processAPINotes.sh
 local api_notes_vars
 api_notes_vars=$(grep -h "declare -r" "${SCRIPT_BASE_DIRECTORY}/bin/process/processAPINotes.sh" | \
  sed 's/declare -r \([A-Z_]*\)=.*/\1/' | sort)

 # Get all readonly variables from processAPIFunctions.sh
 local api_functions_vars
 api_functions_vars=$(grep -h "declare -r" "${SCRIPT_BASE_DIRECTORY}/bin/processAPIFunctions.sh" | \
  sed 's/declare -r \([A-Z_]*\)=.*/\1/' | sort)

 # Find duplicates
 local duplicates
 duplicates=$(comm -12 <(echo "${api_notes_vars}") <(echo "${api_functions_vars}"))

 # Should be empty (no duplicates)
 [[ -z "${duplicates}" ]]
}

@test "should not have duplicate readonly variables between processPlanetNotes.sh and processPlanetFunctions.sh" {
 # Get all readonly variables from processPlanetNotes.sh
 local planet_notes_vars
 planet_notes_vars=$(grep -h "declare -r" "${SCRIPT_BASE_DIRECTORY}/bin/process/processPlanetNotes.sh" | \
  sed 's/declare -r \([A-Z_]*\)=.*/\1/' | sort)

 # Get all readonly variables from processPlanetFunctions.sh
 local planet_functions_vars
 planet_functions_vars=$(grep -h "declare -r" "${SCRIPT_BASE_DIRECTORY}/bin/processPlanetFunctions.sh" | \
  sed 's/declare -r \([A-Z_]*\)=.*/\1/' | sort)

 # Find duplicates
 local duplicates
 duplicates=$(comm -12 <(echo "${planet_notes_vars}") <(echo "${planet_functions_vars}"))

 # Should be empty (no duplicates)
 [[ -z "${duplicates}" ]]
}

@test "should not have duplicate readonly variables between cleanupAll.sh and validationFunctions.sh" {
 # Get all readonly variables from cleanupAll.sh
 local cleanup_vars
 cleanup_vars=$(grep -h "declare -r" "${SCRIPT_BASE_DIRECTORY}/bin/cleanupAll.sh" | \
  sed 's/declare -r \([A-Z_]*\)=.*/\1/' | sort)

 # Get all readonly variables from validationFunctions.sh
 local validation_vars
 validation_vars=$(grep -h "declare -r" "${SCRIPT_BASE_DIRECTORY}/bin/validationFunctions.sh" | \
  sed 's/declare -r \([A-Z_]*\)=.*/\1/' | sort)

 # Find duplicates
 local duplicates
 duplicates=$(comm -12 <(echo "${cleanup_vars}") <(echo "${validation_vars}"))

 # Should be empty (no duplicates)
 [[ -z "${duplicates}" ]]
}

@test "should not have duplicate readonly variables between cleanupPartitions.sh and validationFunctions.sh" {
 # Get all readonly variables from cleanupPartitions.sh
 local cleanup_vars
 cleanup_vars=$(grep -h "declare -r" "${SCRIPT_BASE_DIRECTORY}/bin/cleanupPartitions.sh" | \
  sed 's/declare -r \([A-Z_]*\)=.*/\1/' | sort)

 # Get all readonly variables from validationFunctions.sh
 local validation_vars
 validation_vars=$(grep -h "declare -r" "${SCRIPT_BASE_DIRECTORY}/bin/validationFunctions.sh" | \
  sed 's/declare -r \([A-Z_]*\)=.*/\1/' | sort)

 # Find duplicates
 local duplicates
 duplicates=$(comm -12 <(echo "${cleanup_vars}") <(echo "${validation_vars}"))

 # Should be empty (no duplicates)
 [[ -z "${duplicates}" ]]
}

@test "should not have duplicate readonly variables between functionsProcess.sh and commonFunctions.sh" {
 # Get all readonly variables from functionsProcess.sh
 local functions_vars
 functions_vars=$(grep -h "declare -r" "${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh" | \
  sed 's/declare -r \([A-Z_]*\)=.*/\1/' | sort)

 # Get all readonly variables from commonFunctions.sh
 local common_vars
 common_vars=$(grep -h "declare -r" "${SCRIPT_BASE_DIRECTORY}/bin/commonFunctions.sh" | \
  sed 's/declare -r \([A-Z_]*\)=.*/\1/' | sort)

 # Find duplicates
 local duplicates
 duplicates=$(comm -12 <(echo "${functions_vars}") <(echo "${common_vars}"))

 # Should be empty (no duplicates)
 [[ -z "${duplicates}" ]]
}

@test "should not have duplicate readonly variables between processAPIFunctions.sh and processPlanetFunctions.sh" {
 # Get all readonly variables from processAPIFunctions.sh
 local api_vars
 api_vars=$(grep -h "declare -r" "${SCRIPT_BASE_DIRECTORY}/bin/processAPIFunctions.sh" | \
  sed 's/declare -r \([A-Z_]*\)=.*/\1/' | sort)

 # Get all readonly variables from processPlanetFunctions.sh
 local planet_vars
 planet_vars=$(grep -h "declare -r" "${SCRIPT_BASE_DIRECTORY}/bin/processPlanetFunctions.sh" | \
  sed 's/declare -r \([A-Z_]*\)=.*/\1/' | sort)

 # Find duplicates
 local duplicates
 duplicates=$(comm -12 <(echo "${api_vars}") <(echo "${planet_vars}"))

 # Should be empty (no duplicates)
 [[ -z "${duplicates}" ]]
}

@test "should detect and report duplicate variables with detailed information" {
 # This test provides detailed information about any duplicates found
 local api_notes_vars
 api_notes_vars=$(grep -h "declare -r" "${SCRIPT_BASE_DIRECTORY}/bin/process/processAPINotes.sh" | \
  sed 's/declare -r \([A-Z_]*\)=.*/\1/' | sort)

 local api_functions_vars
 api_functions_vars=$(grep -h "declare -r" "${SCRIPT_BASE_DIRECTORY}/bin/processAPIFunctions.sh" | \
  sed 's/declare -r \([A-Z_]*\)=.*/\1/' | sort)

 local duplicates
 duplicates=$(comm -12 <(echo "${api_notes_vars}") <(echo "${api_functions_vars}"))

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
 run bash -c "
  cd '${SCRIPT_BASE_DIRECTORY}/bin/process' && \
  source '../processAPIFunctions.sh' && \
  source 'processAPINotes.sh' --help > /dev/null 2>&1
 "
 [[ ${status} -eq 0 ]]

 # Test that processPlanetNotes.sh can be sourced after processPlanetFunctions.sh
 run bash -c "
  cd '${SCRIPT_BASE_DIRECTORY}/bin/process' && \
  source '../processPlanetFunctions.sh' && \
  source 'processPlanetNotes.sh' --help > /dev/null 2>&1
 "
 [[ ${status} -eq 0 ]]
} 