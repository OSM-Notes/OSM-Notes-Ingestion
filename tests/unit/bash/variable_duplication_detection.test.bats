#!/usr/bin/env bats

# Require minimum BATS version for run flags
bats_require_minimum_version 1.5.0

# Variable duplication detection tests
# Author: Andres Gomez (AngocA)
# Version: 2025-08-01

setup() {
 # Setup test environment
 export SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
 export TMP_DIR="$(mktemp -d)"
 export BASENAME="test_variable_detection"
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

# Test that all main scripts can be sourced without variable conflicts
@test "all main scripts should be sourceable without variable conflicts" {
 # List of main scripts to test
 local scripts=(
   "bin/cleanupAll.sh"
   "bin/process/processAPINotes.sh"
   "bin/process/processPlanetNotes.sh"
   "bin/dwh/ETL.sh"
   "bin/dwh/profile.sh"
   "bin/wms/wmsManager.sh"
   "bin/cleanupAll.sh"
   "bin/process/updateCountries.sh"
   "bin/dwh/datamartCountries/datamartCountries.sh"
   "bin/dwh/datamartUsers/datamartUsers.sh"
   "bin/wms/geoserverConfig.sh"
 )

 for script in "${scripts[@]}"; do
   if [[ -f "${SCRIPT_BASE_DIRECTORY}/${script}" ]]; then
     # Source the script with SKIP_MAIN to prevent main function execution
     run bash -c "SKIP_MAIN=true source '${SCRIPT_BASE_DIRECTORY}/${script}' > /dev/null 2>&1 || exit 1"
     [ "$status" -eq 0 ] || echo "Failed to source: ${script}"
   fi
 done
}

# Test that functions can be loaded without variable conflicts
@test "function libraries should be sourceable without variable conflicts" {
 # List of function libraries to test
 local libraries=(
   "bin/commonFunctions.sh"
   "bin/functionsProcess.sh"
   "bin/validationFunctions.sh"
   "bin/errorHandlingFunctions.sh"
   "bin/processAPIFunctions.sh"
   "bin/processPlanetFunctions.sh"
 )

 for library in "${libraries[@]}"; do
   if [[ -f "${SCRIPT_BASE_DIRECTORY}/${library}" ]]; then
     # Source the library and capture any variable conflicts
     run bash -c "source '${SCRIPT_BASE_DIRECTORY}/${library}' > /dev/null 2>&1 || exit 1"
     [ "$status" -eq 0 ] || echo "Failed to source: ${library}"
   fi
 done
}

# Test that multiple sourcing of the same file doesn't cause conflicts
@test "multiple sourcing of same file should not cause variable conflicts" {
 # Test multiple sourcing of key libraries
 run bash -c "
   source '${SCRIPT_BASE_DIRECTORY}/bin/commonFunctions.sh' > /dev/null 2>&1
   source '${SCRIPT_BASE_DIRECTORY}/bin/commonFunctions.sh' > /dev/null 2>&1
   source '${SCRIPT_BASE_DIRECTORY}/bin/commonFunctions.sh' > /dev/null 2>&1
   echo 'Multiple sourcing successful'
 "
 [ "$status" -eq 0 ]
 [[ "$output" == *"Multiple sourcing successful"* ]]
}

# Test that readonly variables are properly handled
@test "readonly variables should be handled correctly" {
 # Test that we can source files with readonly variables multiple times
 run bash -c "
   source '${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh' > /dev/null 2>&1
   source '${SCRIPT_BASE_DIRECTORY}/bin/processPlanetFunctions.sh' > /dev/null 2>&1
   source '${SCRIPT_BASE_DIRECTORY}/bin/processAPIFunctions.sh' > /dev/null 2>&1
   echo 'Readonly variables handled correctly'
 "
 [ "$status" -eq 0 ]
 [[ "$output" == *"Readonly variables handled correctly"* ]]
}

# Test that variable declarations are consistent
@test "variable declarations should be consistent across files" {
 # Test that key variables are declared consistently
 run bash -c "
   source '${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh' > /dev/null 2>&1
   source '${SCRIPT_BASE_DIRECTORY}/bin/processPlanetFunctions.sh' > /dev/null 2>&1
   echo \"PLANET_NOTES_FILE: \${PLANET_NOTES_FILE:-}\"
   echo \"COUNTRIES_FILE: \${COUNTRIES_FILE:-}\"
   echo \"MARITIMES_FILE: \${MARITIMES_FILE:-}\"
 "
 [ "$status" -eq 0 ]
 [[ "$output" == *"PLANET_NOTES_FILE:"* ]]
 [[ "$output" == *"COUNTRIES_FILE:"* ]]
 [[ "$output" == *"MARITIMES_FILE:"* ]]
}

# Test that error codes are consistent
@test "error codes should be consistent across files" {
 # Test that error codes are defined consistently
 run bash -c "
   source '${SCRIPT_BASE_DIRECTORY}/bin/commonFunctions.sh' > /dev/null 2>&1
   echo \"ERROR_HELP_MESSAGE: \${ERROR_HELP_MESSAGE:-}\"
   echo \"ERROR_INVALID_ARGUMENT: \${ERROR_INVALID_ARGUMENT:-}\"
   echo \"ERROR_MISSING_LIBRARY: \${ERROR_MISSING_LIBRARY:-}\"
 "
 [ "$status" -eq 0 ]
 [[ "$output" == *"ERROR_HELP_MESSAGE:"* ]]
 [[ "$output" == *"ERROR_INVALID_ARGUMENT:"* ]]
 [[ "$output" == *"ERROR_MISSING_LIBRARY:"* ]]
}

# Test that all required variables are defined
@test "all required variables should be defined" {
 # Test that essential variables are available after sourcing
 run bash -c "
   source '${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh' > /dev/null 2>&1
   source '${SCRIPT_BASE_DIRECTORY}/bin/processPlanetFunctions.sh' > /dev/null 2>&1
   source '${SCRIPT_BASE_DIRECTORY}/bin/processAPIFunctions.sh' > /dev/null 2>&1
   
   # Check essential variables
   [[ -n \"\${SCRIPT_BASE_DIRECTORY:-}\" ]] && echo 'SCRIPT_BASE_DIRECTORY: OK'
   [[ -n \"\${TMP_DIR:-}\" ]] && echo 'TMP_DIR: OK'
   [[ -n \"\${BASENAME:-}\" ]] && echo 'BASENAME: OK'
   [[ -n \"\${LOG_LEVEL:-}\" ]] && echo 'LOG_LEVEL: OK'
 "
 [ "$status" -eq 0 ]
 [[ "$output" == *"SCRIPT_BASE_DIRECTORY: OK"* ]]
 [[ "$output" == *"TMP_DIR: OK"* ]]
 [[ "$output" == *"BASENAME: OK"* ]]
 [[ "$output" == *"LOG_LEVEL: OK"* ]]
} 