#!/usr/bin/env bats

# Note Processing Retry Tests
# Tests for retry functions (file, network, database operations)
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

 # Create a mock wget script
 local MOCK_WGET="${TEST_DIR}/wget"
 cat > "${MOCK_WGET}" << 'EOF'
#!/bin/bash
# Find the output file argument (-O)
OUTPUT_ARG=""
for i in "$@"; do
 if [[ "${OUTPUT_ARG}" == "-O" ]]; then
  echo "mock content" > "$i"
  exit 0
 fi
 if [[ "$i" == "-O" ]]; then
  OUTPUT_ARG="-O"
 fi
done
exit 1
EOF
 chmod +x "${MOCK_WGET}"

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

 # Create a mock wget script that fails twice then succeeds
 local MOCK_WGET="${TEST_DIR}/wget"
 cat > "${MOCK_WGET}" << EOF
#!/bin/bash
ATTEMPT_FILE="${ATTEMPT_FILE}"
if [[ -f "\${ATTEMPT_FILE}" ]]; then
 ATTEMPT=\$(cat "\${ATTEMPT_FILE}")
else
 ATTEMPT=0
fi
ATTEMPT=\$((ATTEMPT + 1))
echo "\${ATTEMPT}" > "\${ATTEMPT_FILE}"

# Find the output file argument (-O)
OUTPUT_ARG=""
for i in "\$@"; do
 if [[ "\${OUTPUT_ARG}" == "-O" ]]; then
  if [[ \${ATTEMPT} -ge 3 ]]; then
   echo "content" > "\$i"
   exit 0
  fi
 fi
 if [[ "\$i" == "-O" ]]; then
  OUTPUT_ARG="-O"
 fi
done
exit 1
EOF
 chmod +x "${MOCK_WGET}"

 # Add mock to PATH
 export PATH="${TEST_DIR}:${PATH}"

 run __retry_network_operation "https://example.com" "${OUTPUT_FILE}" 5 1 10 2>/dev/null
 [[ "${status}" -eq 0 ]]
 [[ -f "${OUTPUT_FILE}" ]]
}

@test "__retry_overpass_api should handle query parameter" {
 local OUTPUT_FILE="${TEST_DIR}/output.txt"

 # Mock curl to succeed
 curl() {
  # Find the output file argument (-o)
  local OUTPUT_ARG=""
  local OUTPUT_FILE=""
  local ARGS=("$@")
  for i in "${!ARGS[@]}"; do
   if [[ "${ARGS[$i]}" == "-o" ]] && [[ $((i + 1)) -lt ${#ARGS[@]} ]]; then
    OUTPUT_FILE="${ARGS[$((i + 1))]}"
    echo "result" > "${OUTPUT_FILE}"
    return 0
   fi
  done
  return 1
 }
 export -f curl

 run __retry_overpass_api "test query" "${OUTPUT_FILE}" 3 1 30
 [[ "${status}" -eq 0 ]]
}

@test "__retry_osm_api should use curl" {
 local OUTPUT_FILE="${TEST_DIR}/output.txt"

 # Create a mock curl script
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
 psql() {
  if [[ "$1" == "-d" ]] && [[ "$3" == "-Atq" ]]; then
   echo "result" > "$6"
   return 0
  fi
  return 1
 }
 export -f psql

 run __retry_database_operation "SELECT 1" "${OUTPUT_FILE}" 3 1
 [[ "${status}" -eq 0 ]]
}

@test "__retry_database_operation should detect SQL errors" {
 local OUTPUT_FILE="${TEST_DIR}/output.txt"

 # Mock psql to return error
 psql() {
  if [[ "$1" == "-d" ]]; then
   echo "ERROR: syntax error" > "$6"
   return 1
  fi
  return 1
 }
 export -f psql

 run __retry_database_operation "INVALID SQL" "${OUTPUT_FILE}" 2 1
 [[ "${status}" -eq 1 ]]
}

