#!/usr/bin/env bats

# Note Processing Network Tests
# Tests for network connectivity and Overpass status
# Author: Andres Gomez (AngocA)
# Version: 2025-12-07

load "${BATS_TEST_DIRNAME}/../../test_helper"

setup() {
 # Create temporary test directory
 TEST_DIR=$(mktemp -d)
 export TEST_DIR

 # Set up test environment variables
 export SCRIPT_BASE_DIRECTORY="${TEST_BASE_DIR}"
 export TMP_DIR="${TEST_DIR}"
 export DBNAME="${TEST_DBNAME:-test_db}"
 export RATE_LIMIT="${RATE_LIMIT:-8}"
 export BASHPID=$$

 # Set log level to DEBUG to capture all log output
 export LOG_LEVEL="DEBUG"
 export __log_level="DEBUG"

 # Load note processing functions
 source "${TEST_BASE_DIR}/bin/lib/noteProcessingFunctions.sh"
}

teardown() {
 # Clean up test files
 rm -rf "${TEST_DIR}"
}

# =============================================================================
# Tests for __check_network_connectivity
# =============================================================================

@test "__check_network_connectivity should return 0 when network is available" {
 # Mock curl to return success
 curl() {
  return 0
 }
 export -f curl

 run __check_network_connectivity 5
 [[ "${status}" -eq 0 ]]
}

@test "__check_network_connectivity should return 1 when network is unavailable" {
 # Create a mock curl that always fails
 local MOCK_CURL="${TEST_DIR}/curl"
 cat > "${MOCK_CURL}" << 'EOF'
#!/bin/bash
exit 1
EOF
 chmod +x "${MOCK_CURL}"

 # Create a mock timeout that just executes the command
 local MOCK_TIMEOUT="${TEST_DIR}/timeout"
 cat > "${MOCK_TIMEOUT}" << 'EOF'
#!/bin/bash
shift
"$@"
EOF
 chmod +x "${MOCK_TIMEOUT}"

 export PATH="${TEST_DIR}:${PATH}"

 run __check_network_connectivity 5 2>/dev/null
 [[ "${status}" -eq 1 ]]
}

@test "__check_network_connectivity should accept timeout parameter" {
 # Mock curl to return success
 curl() {
  [[ "$1" == "--connect-timeout" ]]
  [[ "$2" == "10" ]]
  return 0
 }
 export -f curl

 run __check_network_connectivity 10
 [[ "${status}" -eq 0 ]]
}

# =============================================================================
# Tests for __check_overpass_status
# =============================================================================

@test "__check_overpass_status should return 0 when slots available" {
 export OVERPASS_INTERPRETER="https://overpass-api.de/api/interpreter"

 # Mock curl to return status with available slots
 curl() {
  if [[ "$1" == "-s" ]] && [[ "$2" == "https://overpass-api.de/status" ]]; then
   echo "2 slots available now"
   return 0
  fi
  return 1
 }
 export -f curl

 # Capture only the wait time (last line)
 local WAIT_TIME
 WAIT_TIME=$(__check_overpass_status 2>/dev/null | tail -1)
 [[ "${WAIT_TIME}" == "0" ]]
}

@test "__check_overpass_status should return wait time when busy" {
 export OVERPASS_INTERPRETER="https://overpass-api.de/api/interpreter"

 # Mock curl to return status with wait time
 curl() {
  if [[ "$1" == "-s" ]] && [[ "$2" == "https://overpass-api.de/status" ]]; then
   echo "Slot available after in 30 seconds."
   return 0
  fi
  return 1
 }
 export -f curl

 # Capture only the wait time (last line)
 local WAIT_TIME
 WAIT_TIME=$(__check_overpass_status 2>/dev/null | tail -1)
 [[ "${WAIT_TIME}" == "30" ]]
}

@test "__check_overpass_status should handle connection failure" {
 export OVERPASS_INTERPRETER="https://overpass-api.de/api/interpreter"

 # Mock curl to fail
 curl() {
  return 1
 }
 export -f curl

 # Capture only the wait time (last line)
 local WAIT_TIME
 WAIT_TIME=$(__check_overpass_status 2>/dev/null | tail -1)
 [[ "${WAIT_TIME}" == "0" ]]
}

