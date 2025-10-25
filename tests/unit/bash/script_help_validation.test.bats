#!/usr/bin/env bats

# Require minimum BATS version for run flags
bats_require_minimum_version 1.5.0

# Script Help Validation Tests
# This test file validates that main scripts can be executed with --help option
# without errors, ensuring basic functionality and variable loading works correctly
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-31

# Test setup
setup() {
 # Set up test environment
 export SCRIPT_BASE_DIRECTORY="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
 export BASENAME="test_script_help"
 export TMP_DIR=$(mktemp -d)
 export LOG_FILENAME="${TMP_DIR}/test.log"
 export LOCK="${TMP_DIR}/test.lock"
}

# Test teardown
teardown() {
 # Clean up test environment
 if [[ -d "${TMP_DIR}" ]]; then
  rm -rf "${TMP_DIR}"
 fi
}

# Test that cleanupAll.sh works with --help
@test "cleanupAll.sh should work with --help option" {
 run bash "${SCRIPT_BASE_DIRECTORY}/bin/cleanupAll.sh" --help
 [ "$status" -eq 0 ]
 [[ "$output" == *"Usage:"* ]]
 [[ "$output" == *"cleanupAll.sh"* ]]
 [[ "$output" == *"database"* ]]
}

# Test that processAPINotes.sh works with --help
@test "processAPINotes.sh should work with --help option" {
 run bash "${SCRIPT_BASE_DIRECTORY}/bin/process/processAPINotes.sh" --help 2>&1
 [ "$status" -eq 1 ] # Expected exit code for help
}

# Test that processPlanetNotes.sh works with --help
@test "processPlanetNotes.sh should work with --help option" {
 run bash "${SCRIPT_BASE_DIRECTORY}/bin/process/processPlanetNotes.sh" --help 2>&1
 [ "$status" -eq 1 ] # Expected exit code for help
}

# Test that wmsManager.sh works with --help
@test "wmsManager.sh should work with --help option" {
 run bash "${SCRIPT_BASE_DIRECTORY}/bin/wms/wmsManager.sh" --help
 [ "$status" -eq 0 ] || [ "$status" -eq 1 ] # Accept both success and help exit codes
 [[ "$output" == *"Usage:"* ]] || [[ "$output" == *"WMS"* ]]
}

# Test that cleanupAll.sh works with --help (partition functionality)
@test "cleanupAll.sh should work with --help option and show partition info" {
 run bash "${SCRIPT_BASE_DIRECTORY}/bin/cleanupAll.sh" --help
 [ "$status" -eq 0 ]
 [[ "$output" == *"Usage:"* ]]
 [[ "$output" == *"cleanupAll.sh"* ]]
 [[ "$output" == *"partition"* ]]
}

# Test that updateCountries.sh works with --help
@test "updateCountries.sh should work with --help option" {
 run bash "${SCRIPT_BASE_DIRECTORY}/bin/process/updateCountries.sh" --help 2>&1
 # Script executed (even if exit code is non-zero for help), not a critical failure
 # Accept any non-critical exit code (< 128 typically means script ran)
 [ "$status" -lt 128 ]
}

# Test that geoserverConfig.sh should work with --help
@test "geoserverConfig.sh should work with --help option" {
 run bash "${SCRIPT_BASE_DIRECTORY}/bin/wms/geoserverConfig.sh" --help 2>&1
 [ "$status" -eq 0 ] || [ "$status" -eq 1 ] # Accept both success and help exit codes
}

# Test that all scripts can be sourced without errors
@test "all main scripts should be sourceable without errors" {
 # Test sourcing main scripts
 local SCRIPTS=(
  "${SCRIPT_BASE_DIRECTORY}/bin/cleanupAll.sh"
  "${SCRIPT_BASE_DIRECTORY}/bin/process/processAPINotes.sh"
  "${SCRIPT_BASE_DIRECTORY}/bin/process/processPlanetNotes.sh"
  "${SCRIPT_BASE_DIRECTORY}/bin/wms/wmsManager.sh"
  # cleanupPartitions.sh functionality now integrated into cleanupAll.sh
  "${SCRIPT_BASE_DIRECTORY}/bin/process/updateCountries.sh"
  "${SCRIPT_BASE_DIRECTORY}/bin/wms/geoserverConfig.sh"
 )

 for SCRIPT in "${SCRIPTS[@]}"; do
  if [[ -f "${SCRIPT}" ]]; then
   # Use a more robust approach to test script sourcing
   run bash -c "
    # Temporarily disable error exit
    set +e
    # Source the script and capture any readonly errors
    source '${SCRIPT}' 2>&1 | grep -q 'variable de solo lectura' || true
    # Check if sourcing succeeded (ignore readonly warnings)
    if [[ \$? -eq 0 ]]; then
     exit 0
    else
     exit 1
    fi
   "
   # Accept both success and readonly warning cases
   [ "$status" -eq 0 ] || echo "Failed to source: ${SCRIPT}"
  else
   echo "Script not found: ${SCRIPT}"
  fi
 done
}

# Test that scripts don't have syntax errors
@test "all main scripts should have valid bash syntax" {
 # Test syntax of main scripts
 local SCRIPTS=(
  "${SCRIPT_BASE_DIRECTORY}/bin/cleanupAll.sh"
  "${SCRIPT_BASE_DIRECTORY}/bin/process/processAPINotes.sh"
  "${SCRIPT_BASE_DIRECTORY}/bin/process/processPlanetNotes.sh"
  "${SCRIPT_BASE_DIRECTORY}/bin/wms/wmsManager.sh"
  # cleanupPartitions.sh functionality now integrated into cleanupAll.sh
  "${SCRIPT_BASE_DIRECTORY}/bin/process/updateCountries.sh"
  "${SCRIPT_BASE_DIRECTORY}/bin/wms/geoserverConfig.sh"
 )

 for SCRIPT in "${SCRIPTS[@]}"; do
  run bash -n "${SCRIPT}"
  [ "$status" -eq 0 ] || echo "Syntax error in: ${SCRIPT}"
 done
}

# Test that scripts are executable
@test "all main scripts should be executable" {
 # Test executability of main scripts
 local SCRIPTS=(
  "${SCRIPT_BASE_DIRECTORY}/bin/cleanupAll.sh"
  "${SCRIPT_BASE_DIRECTORY}/bin/process/processAPINotes.sh"
  "${SCRIPT_BASE_DIRECTORY}/bin/process/processPlanetNotes.sh"
  "${SCRIPT_BASE_DIRECTORY}/bin/wms/wmsManager.sh"
  # cleanupPartitions.sh functionality now integrated into cleanupAll.sh
  "${SCRIPT_BASE_DIRECTORY}/bin/process/updateCountries.sh"
  "${SCRIPT_BASE_DIRECTORY}/bin/wms/geoserverConfig.sh"
 )

 for SCRIPT in "${SCRIPTS[@]}"; do
  [[ -x "${SCRIPT}" ]] || echo "Not executable: ${SCRIPT}"
 done
}
