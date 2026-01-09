#!/usr/bin/env bats

# Note Processing Retry Tests
# Tests for retry functions (file, network, database operations)
# Author: Andres Gomez (AngocA)
# Version: 2025-12-07

load "${BATS_TEST_DIRNAME}/../../test_helper"
load "${BATS_TEST_DIRNAME}/../../test_helpers_common"

setup() {
 # Setup test properties first (this must be done before any script sources properties.sh)
 if declare -f setup_test_properties > /dev/null 2>&1; then
  setup_test_properties
 fi
 
 # Create temporary test directory
 TEST_DIR=$(mktemp -d)
 export TEST_DIR

 # Set up test environment variables
 export SCRIPT_BASE_DIRECTORY="${TEST_BASE_DIR}"
 export TMP_DIR="${TEST_DIR}"
 export DBNAME="${TEST_DBNAME:-osm_notes_ingestion_test}"
 export RATE_LIMIT="${RATE_LIMIT:-8}"
 export BASHPID=$$

 # Set log level to DEBUG to capture all log output
 export LOG_LEVEL="DEBUG"
 export __log_level="DEBUG"

 # Load note processing functions
 source "${TEST_BASE_DIR}/bin/lib/noteProcessingFunctions.sh"
}

teardown() {
 # Restore original properties if needed
 if declare -f restore_properties > /dev/null 2>&1; then
  restore_properties
 fi
 
 # Clean up test files
 rm -rf "${TEST_DIR}"
}

# =============================================================================
# Tests for Retry Functions
# =============================================================================

@test "__retry_file_operation should succeed on first attempt" {
 local SUCCESS_FILE="${TEST_DIR}/success.txt"

 # Mock operation that succeeds
 operation() {
  echo "success" > "${SUCCESS_FILE}"
  return 0
 }

 run __retry_file_operation "operation" 3 1
 [[ "${status}" -eq 0 ]]
 [[ -f "${SUCCESS_FILE}" ]]
}

@test "__retry_file_operation should retry on failure" {
 local ATTEMPT_FILE="${TEST_DIR}/attempts.txt"
 local ATTEMPT_COUNT=0

 # Mock operation that fails twice then succeeds
 operation() {
  ATTEMPT_COUNT=$((ATTEMPT_COUNT + 1))
  echo "${ATTEMPT_COUNT}" >> "${ATTEMPT_FILE}"
  if [[ ${ATTEMPT_COUNT} -lt 3 ]]; then
   return 1
  fi
  return 0
 }

 run __retry_file_operation "operation" 3 1
 [[ "${status}" -eq 0 ]]
 [[ $(wc -l < "${ATTEMPT_FILE}") -eq 3 ]]
}

@test "__retry_file_operation should fail after max retries" {
 # Mock operation that always fails
 operation() {
  return 1
 }

 run __retry_file_operation "operation" 2 1
 [[ "${status}" -eq 1 ]]
}

@test "__retry_file_operation should execute cleanup on failure" {
 # Use a file to track cleanup execution
 local CLEANUP_FILE="${TEST_DIR}/cleanup_executed.txt"
 rm -f "${CLEANUP_FILE}"

 # Mock operation that always fails
 operation() {
  return 1
 }
 export -f operation

 # Cleanup command that creates a file
 cleanup() {
  touch "${CLEANUP_FILE}"
 }
 export -f cleanup

 run __retry_file_operation "operation" 1 1 "cleanup" 2>/dev/null
 [[ "${status}" -eq 1 ]]
 [[ -f "${CLEANUP_FILE}" ]]
}

@test "__retry_network_operation should succeed with valid URL" {
 local OUTPUT_FILE="${TEST_DIR}/output.txt"

 # Create a mock curl script
 local MOCK_CURL="${TEST_DIR}/curl"
 cat > "${MOCK_CURL}" << 'EOF'
#!/bin/bash
# Find the output file argument (-o)
OUTPUT_ARG=""
for i in "$@"; do
 if [[ "${OUTPUT_ARG}" == "-o" ]]; then
  echo "mock content" > "$i"
  exit 0
 fi
 if [[ "$i" == "-o" ]]; then
  OUTPUT_ARG="-o"
 fi
done
exit 1
EOF
 chmod +x "${MOCK_CURL}"

 # Add mock to PATH
 export PATH="${TEST_DIR}:${PATH}"

 run __retry_network_operation "https://example.com" "${OUTPUT_FILE}" 3 1 10 2>/dev/null
 [[ "${status}" -eq 0 ]]
 [[ -f "${OUTPUT_FILE}" ]]
}

@test "__retry_network_operation should retry on failure" {
 local OUTPUT_FILE="${TEST_DIR}/output.txt"
 local ATTEMPT_FILE="${TEST_DIR}/attempts.txt"
 rm -f "${ATTEMPT_FILE}"

 # Create a mock curl script that fails twice then succeeds
 local MOCK_CURL="${TEST_DIR}/curl"
 cat > "${MOCK_CURL}" << EOF
#!/bin/bash
ATTEMPT_FILE="${ATTEMPT_FILE}"
if [[ -f "\${ATTEMPT_FILE}" ]]; then
 ATTEMPT=\$(cat "\${ATTEMPT_FILE}")
else
 ATTEMPT=0
fi
ATTEMPT=\$((ATTEMPT + 1))
echo "\${ATTEMPT}" > "\${ATTEMPT_FILE}"

# Find the output file argument (-o)
OUTPUT_ARG=""
for i in "\$@"; do
 if [[ "\${OUTPUT_ARG}" == "-o" ]]; then
  if [[ \${ATTEMPT} -ge 3 ]]; then
   echo "content" > "\$i"
   exit 0
  fi
 fi
 if [[ "\$i" == "-o" ]]; then
  OUTPUT_ARG="-o"
 fi
done
exit 1
EOF
 chmod +x "${MOCK_CURL}"

 # Add mock to PATH
 export PATH="${TEST_DIR}:${PATH}"

 run __retry_network_operation "https://example.com" "${OUTPUT_FILE}" 5 1 10 2>/dev/null
 [[ "${status}" -eq 0 ]]
 [[ -f "${OUTPUT_FILE}" ]]
}

@test "__retry_overpass_api should handle query parameter" {
 local OUTPUT_FILE="${TEST_DIR}/output.txt"

 # Mock curl for Overpass API using common helper
 local MOCK_RESPONSE="${TEST_DIR}/mock_response.json"
 echo "result" > "${MOCK_RESPONSE}"
 __setup_mock_curl_overpass "" "${MOCK_RESPONSE}"

 run __retry_overpass_api "test query" "${OUTPUT_FILE}" 3 1 30
 [[ "${status}" -eq 0 ]]
}

@test "__retry_osm_api should use curl" {
 local OUTPUT_FILE="${TEST_DIR}/output.txt"

 # Create a mock curl script that handles -w flag for HTTP code
 local MOCK_CURL="${TEST_DIR}/curl"
 cat > "${MOCK_CURL}" << 'EOF'
#!/bin/bash
# Mock curl that handles both HTTP/2 check and real API calls
OUTPUT_FILE=""
HTTP_CODE_OUTPUT=""
NEXT_IS_OUTPUT=false
NEXT_IS_HTTP_CODE=false
HAS_W_FLAG=false

# Check if this is an HTTP/2 check: --http2 with --max-time 5 and no -w flag
HAS_HTTP2=false
HAS_MAX_TIME_5=false
HAS_W=false
PREV_ARG=""
for arg in "$@"; do
 if [[ "${arg}" == "--http2" ]]; then
  HAS_HTTP2=true
 fi
 if [[ "${arg}" == "-w" ]]; then
  HAS_W=true
 fi
 if [[ "${PREV_ARG}" == "--max-time" ]] && [[ "${arg}" == "5" ]]; then
  HAS_MAX_TIME_5=true
 fi
 PREV_ARG="${arg}"
done

# If HTTP/2 check (has --http2, --max-time 5, but no -w), return success
if [[ "${HAS_HTTP2}" == "true" ]] && [[ "${HAS_MAX_TIME_5}" == "true" ]] && [[ "${HAS_W}" == "false" ]]; then
 exit 0
fi

# Parse arguments for -o and -w
for arg in "$@"; do
 if [[ "${NEXT_IS_OUTPUT}" == "true" ]]; then
  OUTPUT_FILE="${arg}"
  NEXT_IS_OUTPUT=false
 elif [[ "${NEXT_IS_HTTP_CODE}" == "true" ]]; then
  HTTP_CODE_OUTPUT="${arg}"
  NEXT_IS_HTTP_CODE=false
 elif [[ "${arg}" == "-o" ]]; then
  NEXT_IS_OUTPUT=true
 elif [[ "${arg}" == "-w" ]]; then
  NEXT_IS_HTTP_CODE=true
  HAS_W_FLAG=true
 fi
done

# Create output file if specified (and not /dev/null or a temp file)
# When using -o with -w, curl writes content to file first, then HTTP code to stdout
if [[ -n "${OUTPUT_FILE}" ]] && [[ "${OUTPUT_FILE}" != "/dev/null" ]]; then
 # Write content to the output file (this is what curl does with -o)
 echo "<osm><note id=\"1\"/></osm>" > "${OUTPUT_FILE}"
fi

# Output HTTP code if -w was used (to stdout, after file content)
# curl writes HTTP code to stdout when using -w, even with -o
# The HTTP code is written AFTER the file content when using -o
if [[ "${HAS_W_FLAG}" == "true" ]]; then
 # Write HTTP code to stdout (this is what curl does with -w)
 # Must be exactly 3 characters for tail -c 3 to work correctly
 # Note: curl writes HTTP code AFTER writing file content when using -o
 printf "200" >&1
fi

exit 0
EOF
 chmod +x "${MOCK_CURL}"

 # Add mock to PATH (only for this test, won't affect hybrid scripts)
 export PATH="${TEST_DIR}:${PATH}"

 run __retry_osm_api "https://api.openstreetmap.org/api/0.6/notes" "${OUTPUT_FILE}" 3 1 30 2>/dev/null
 [[ "${status}" -eq 0 ]]
 [[ -f "${OUTPUT_FILE}" ]]
}

@test "__retry_geoserver_api should handle POST method" {
 local OUTPUT_FILE="${TEST_DIR}/output.txt"

 # Create a mock curl script that handles POST
 local MOCK_CURL="${TEST_DIR}/curl"
 cat > "${MOCK_CURL}" << 'EOF'
#!/bin/bash
# Find the output file argument (-o)
OUTPUT_ARG=""
for i in "$@"; do
 if [[ "${OUTPUT_ARG}" == "-o" ]]; then
  echo "result" > "$i"
  exit 0
 fi
 if [[ "$i" == "-o" ]]; then
  OUTPUT_ARG="-o"
 fi
done
exit 1
EOF
 chmod +x "${MOCK_CURL}"

 # Add mock to PATH
 export PATH="${TEST_DIR}:${PATH}"

 run __retry_geoserver_api "https://geoserver.example.com" "POST" "data" "${OUTPUT_FILE}" 3 1 30 2>/dev/null
 [[ "${status}" -eq 0 ]]
 [[ -f "${OUTPUT_FILE}" ]]
}

@test "__retry_database_operation should execute SQL query" {
 local OUTPUT_FILE="${TEST_DIR}/output.txt"

 # Mock psql to succeed
 # Mock psql using common helper
 __setup_mock_psql_for_query ".*" "result" 0

 run __retry_database_operation "SELECT 1" "${OUTPUT_FILE}" 3 1
 [[ "${status}" -eq 0 ]]
}

@test "__retry_database_operation should detect SQL errors" {
 local OUTPUT_FILE="${TEST_DIR}/output.txt"

 # Mock psql to return error (both exit code and error message)
 # The function checks for ERROR in output, so we need both
 __setup_mock_psql_for_query ".*" "ERROR: syntax error" 1

 run __retry_database_operation "INVALID SQL" "${OUTPUT_FILE}" 2 1
 # Function should detect error and return 1 after retries
 [[ "${status}" -eq 1 ]]
}

