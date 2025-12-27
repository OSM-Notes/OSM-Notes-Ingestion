#!/usr/bin/env bash

# Common helper functions for JSON validation integration tests
# Author: Andres Gomez (AngocA)
# Version: 2025-12-23

# Load common helpers
if [[ -n "${BATS_TEST_FILENAME:-}" ]]; then
 load "$(dirname "$BATS_TEST_FILENAME")/../test_helpers_common.bash"
else
 source "$(dirname "${BASH_SOURCE[0]}")/../test_helpers_common.bash"
fi

# =============================================================================
# Setup and Teardown Helpers
# =============================================================================

__setup_json_validation_test() {
 # Load test helper first
 load "$(dirname "$BATS_TEST_FILENAME")/../test_helper.bash"

 # Use common setup function
 __common_setup_test_dir "test_json_validation_integration"

 # Set JSON validation-specific environment variables
 export BASHPID=$$
 export RATE_LIMIT=4
 export OVERPASS_INTERPRETER="https://overpass-api.de/api/interpreter"

 # Load required functions
 __load_validation_functions

 # Load functionsProcess.sh to get __retry_file_operation
 if [ -f "${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh" ]; then
  source "${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh" > /dev/null 2>&1 || true
 fi

 # Load noteProcessingFunctions.sh for download queue functions
 if [ -f "${SCRIPT_BASE_DIRECTORY}/bin/lib/noteProcessingFunctions.sh" ]; then
  source "${SCRIPT_BASE_DIRECTORY}/bin/lib/noteProcessingFunctions.sh" > /dev/null 2>&1 || true
 fi

 # Check if jq is available
 if ! command -v jq > /dev/null 2>&1; then
  skip "jq not available - required for JSON validation tests"
 fi
}

__teardown_json_validation_test() {
 # Use common teardown function
 __common_teardown_test_dir
}

# =============================================================================
# Validation Function Loading
# =============================================================================

__load_validation_functions() {
 # Check if function already loaded
 if declare -f __validate_json_with_element > /dev/null 2>&1; then
  return 0
 fi

 # Ensure commonFunctions.sh is loaded first (required by functionsProcess.sh)
 if [ -f "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/commonFunctions.sh" ]; then
  source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/commonFunctions.sh" > /dev/null 2>&1 || true
 fi
  
 # Try loading from correct location
 if [ -f "${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh" ]; then
  source "${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh" > /dev/null 2>&1 || true
 fi

 # Also ensure validationFunctions.sh is loaded
 if [ -f "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/validationFunctions.sh" ]; then
  source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/validationFunctions.sh" > /dev/null 2>&1 || true
 fi
  
 # Verify function is now loaded
 if ! declare -f __validate_json_with_element > /dev/null 2>&1; then
  echo "WARNING: __validate_json_with_element function not loaded" >&2
 fi
}

# =============================================================================
# Connectivity Helpers
# =============================================================================

# Load service availability helpers if available
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/service_availability_helpers.bash" ]]; then
 source "$(dirname "${BASH_SOURCE[0]}")/service_availability_helpers.bash"
fi

# Legacy function for backward compatibility
# Use __skip_if_overpass_api_unavailable instead
__check_overpass_connectivity() {
 if [[ -n "${BATS_TEST_FILENAME:-}" ]]; then
  # Running in BATS - use new helper
  if command -v __skip_if_overpass_api_unavailable > /dev/null 2>&1; then
   __skip_if_overpass_api_unavailable "Overpass API not reachable"
  else
   # Fallback to old implementation
   if ! command -v curl > /dev/null; then
    skip "curl not available for connectivity check"
   fi
   if ! curl -s --max-time 5 "${OVERPASS_INTERPRETER%/api/interpreter}/status" > /dev/null 2>&1; then
    skip "Overpass API not reachable"
   fi
  fi
 else
  # Not in BATS - just check availability
  if command -v __check_overpass_api_status > /dev/null 2>&1; then
   __check_overpass_api_status 5
  else
   # Fallback
   if ! command -v curl > /dev/null; then
    return 1
   fi
   curl -s --max-time 5 "${OVERPASS_INTERPRETER%/api/interpreter}/status" > /dev/null 2>&1
  fi
 fi
}

# =============================================================================
# Test Data Helpers
# =============================================================================

__create_overpass_query() {
 local TEST_ID="${1:-3793105}"
 local QUERY_FILE="${2:-${TMP_DIR}/query_${TEST_ID}.op}"

 cat > "${QUERY_FILE}" << EOF
[out:json];
rel(${TEST_ID});
(._;>;);
out;
EOF

 echo "${QUERY_FILE}"
}

__download_json_from_overpass() {
 local TEST_ID="${1:-3793105}"
 local JSON_FILE="${TMP_DIR}/${TEST_ID}.json"
 local QUERY_FILE="${TMP_DIR}/query_${TEST_ID}.op"
 local OUTPUT_OVERPASS="${TMP_DIR}/output_${TEST_ID}.txt"

 # Create query
 __create_overpass_query "${TEST_ID}" "${QUERY_FILE}"

 # Download
 run curl -s -H "User-Agent: OSM-Notes-Ingestion/1.0" -o "${JSON_FILE}" --data-binary @"${QUERY_FILE}" "${OVERPASS_INTERPRETER}" 2> "${OUTPUT_OVERPASS}"

 if [ "${status}" -eq 0 ] && [[ -f "${JSON_FILE}" ]] && [[ -s "${JSON_FILE}" ]]; then
  echo "${JSON_FILE}"
 else
  echo ""
 fi
}

