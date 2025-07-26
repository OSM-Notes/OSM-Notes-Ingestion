#!/usr/bin/env bash

# Test helper functions for BATS tests
# Author: Andres Gomez (AngocA)
# Version: 2025-07-23

# Test database configuration
# Use the values already set by run_tests.sh, don't override them
# Only set defaults if not already set

# Test directories
# Detect if running in Docker or host
if [[ -f "/app/bin/functionsProcess.sh" ]]; then
 # Running in Docker container
 export TEST_BASE_DIR="/app"
else
 # Running on host - detect project root
 export TEST_BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
export TEST_TMP_DIR="/tmp/bats_test_$$"

# Test environment variables
export LOG_LEVEL="DEBUG"
export CLEAN="false"
export MAX_THREADS="2"
export TEST_MAX_NOTES="100"

# Set required variables for functionsProcess.sh BEFORE loading scripts
export BASENAME="test"
export TMP_DIR="/tmp/test_$$"
export DBNAME="${TEST_DBNAME}"
export SCRIPT_BASE_DIRECTORY="${TEST_BASE_DIR}"
export LOG_FILENAME="/tmp/test.log"
export LOCK="/tmp/test.lock"

# Load project properties
# Only load properties.sh if we're in Docker, otherwise use test-specific properties
if [[ -f "/app/bin/functionsProcess.sh" ]]; then
 # Running in Docker - load original properties
 if [[ -f "${TEST_BASE_DIR}/etc/properties.sh" ]]; then
  source "${TEST_BASE_DIR}/etc/properties.sh"
 elif [[ -f "${TEST_BASE_DIR}/tests/properties.sh" ]]; then
  source "${TEST_BASE_DIR}/tests/properties.sh"
 else
  echo "Warning: properties.sh not found"
 fi
else
 # Running on host - use test-specific properties
 if [[ -f "${TEST_BASE_DIR}/tests/properties_test.sh" ]]; then
  # shellcheck source=properties_test.sh
  source "${TEST_BASE_DIR}/tests/properties_test.sh"
 elif [[ -f "${TEST_BASE_DIR}/tests/properties.sh" ]]; then
  source "${TEST_BASE_DIR}/tests/properties.sh"
 else
  echo "Warning: tests/properties.sh not found, using default test values"
 fi
fi

# Load the logger first
if [[ -f "${TEST_BASE_DIR}/lib/bash_logger.sh" ]]; then
 source "${TEST_BASE_DIR}/lib/bash_logger.sh"
else
 # Create a simple logger if not available
 __start_logger() {
  echo "Logger started"
 }
 
 # Create basic logging functions
 __logd() {
  echo "[DEBUG] $*"
 }
 
 __logi() {
  echo "[INFO] $*"
 }
 
 __logw() {
  echo "[WARN] $*"
 }
 
 __loge() {
  echo "[ERROR] $*"
 }
 
 __log_start() {
  __logi "Starting function"
 }
 
 __log_finish() {
  __logi "Function completed"
 }
fi

# Load the functions to test
if [[ -f "${TEST_BASE_DIR}/bin/functionsProcess.sh" ]]; then
 source "${TEST_BASE_DIR}/bin/functionsProcess.sh"
else
 echo "Warning: functionsProcess.sh not found"
fi

# Set additional environment variables for Docker container
export PGHOST="${TEST_DBHOST}"
export PGUSER="${TEST_DBUSER}"
export PGPASSWORD="${TEST_DBPASSWORD}"
export PGDATABASE="${TEST_DBNAME}"

# Initialize logging system
__start_logger

# Use mock psql when running on host
if [[ ! -f "/app/bin/functionsProcess.sh" ]]; then
 # Create a mock psql function that will be used instead of real psql
 psql() {
  mock_psql "$@"
 }
fi

# Setup function - runs before each test
setup() {
 # Create temporary directory
 mkdir -p "${TEST_TMP_DIR}"

 # Set up test environment
 export TMP_DIR="${TEST_TMP_DIR}"
 export DBNAME="${TEST_DBNAME}"

 # Mock external commands if needed
 if ! command -v psql &> /dev/null; then
  # Create mock psql if not available
  create_mock_psql
 fi
}

# Teardown function - runs after each test
teardown() {
 # Clean up temporary directory
 rm -rf "${TEST_TMP_DIR}"
}

# Create mock psql for testing
create_mock_psql() {
 cat > "${TEST_TMP_DIR}/psql" << 'EOF'
#!/bin/bash
# Mock psql command for testing
echo "Mock psql called with: $*"
exit 0
EOF
 chmod +x "${TEST_TMP_DIR}/psql"
 export PATH="${TEST_TMP_DIR}:${PATH}"
}

# Mock psql function for host testing
mock_psql() {
 if [[ -f "/app/bin/functionsProcess.sh" ]]; then
  # Running in Docker - use real psql
  psql "$@"
 else
  # Running on host - simulate psql
  echo "Mock psql called with: $*"
  return 0
 fi
}

# Helper function to create test database
create_test_database() {
 echo "DEBUG: Function called"
 local dbname="${1:-${TEST_DBNAME}}"
 echo "DEBUG: dbname = ${dbname}"
 
 if [[ -f "/app/bin/functionsProcess.sh" ]]; then
  echo "DEBUG: Docker detected"
  echo "DEBUG: Testing database connection..."
  psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${dbname}" -c "SELECT 1;" 2>&1
  if [ $? -eq 0 ]; then
   echo "Test database ${dbname} already exists"
   return 0
  else
   echo "DEBUG: Creating database..."
   psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d postgres -c "CREATE DATABASE ${dbname};" 2>&1
   if [ $? -eq 0 ]; then
    echo "Test database ${dbname} created successfully"
    return 0
   else
    echo "Failed to create test database ${dbname}"
    return 1
   fi
  fi
 else
  echo "DEBUG: Host detected"
  echo "Test database ${dbname} created (simulated)"
  return 0
 fi
}

# Helper function to drop test database
drop_test_database() {
 local dbname="${1:-${TEST_DBNAME}}"

 # Detect if running in Docker or host
 if [[ -f "/app/bin/functionsProcess.sh" ]]; then
  # Running in Docker - don't drop database to keep it for tests
  echo "Test database ${dbname} kept for Docker tests"
 else
  # Running on host - simulate database drop
  echo "Test database ${dbname} dropped (simulated)"
 fi
}

# Helper function to run SQL file
run_sql_file() {
 local sql_file="${1}"
 local dbname="${2:-${TEST_DBNAME}}"

 if [[ -f "${sql_file}" ]]; then
  # Detect if running in Docker or host
  if [[ -f "/app/bin/functionsProcess.sh" ]]; then
   # Running in Docker - use real psql
   psql -d "${dbname}" -f "${sql_file}" 2> /dev/null
   return $?
  else
   # Running on host - simulate SQL execution
   echo "SQL file ${sql_file} executed (simulated)"
   return 0
  fi
 else
  echo "SQL file not found: ${sql_file}"
  return 1
 fi
}

# Helper function to check if table exists
table_exists() {
 local table_name="${1}"
 local dbname="${2:-${TEST_DBNAME}}"

 # Detect if running in Docker or host
 if [[ -f "/app/bin/functionsProcess.sh" ]]; then
  # Running in Docker - try to connect to real database
  local result
  result=$(psql -d "${dbname}" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_name = '${table_name}';" 2> /dev/null | tr -d ' ')

  if [[ -n "${result}" ]] && [[ "${result}" == "1" ]]; then
   return 0
  else
   return 1
  fi
 else
  # Running on host - simulate table check
  echo "Table ${table_name} exists (simulated)"
  return 0
 fi
}

# Helper function to count rows in table
count_rows() {
 local table_name="${1}"
 local dbname="${2:-${TEST_DBNAME}}"

 # Detect if running in Docker or host
 if [[ -f "/app/bin/functionsProcess.sh" ]]; then
  # Running in Docker - try to connect to real database
  local result
  result=$(psql -d "${dbname}" -t -c "SELECT COUNT(*) FROM ${table_name};" 2> /dev/null | tr -d ' ')

  if [[ -n "${result}" ]] && [[ "${result}" =~ ^[0-9]+$ ]]; then
   echo "${result}"
  else
   echo "0"
  fi
 else
  # Running on host - simulate row count
  echo "0"
 fi
}

# Helper function to create sample data
create_sample_data() {
 local dbname="${1:-${TEST_DBNAME}}"

 # Detect if running in Docker or host
 if [[ -f "/app/bin/functionsProcess.sh" ]]; then
  # Running in Docker - use real psql
  psql -d "${dbname}" -c "
     INSERT INTO notes (note_id, latitude, longitude, created_at, status) VALUES
     (123, 40.7128, -74.0060, '2013-04-28T02:39:27Z', 'open'),
     (456, 34.0522, -118.2437, '2013-04-30T15:20:45Z', 'closed');
   " 2> /dev/null

  psql -d "${dbname}" -c "
     INSERT INTO note_comments (note_id, sequence_action, event, created_at, id_user) VALUES
     (123, 1, 'opened', '2013-04-28T02:39:27Z', 123),
     (456, 1, 'opened', '2013-04-30T15:20:45Z', 456),
     (456, 2, 'closed', '2013-05-01T10:15:30Z', 789);
   " 2> /dev/null
 else
  # Running on host - simulate sample data creation
  echo "Sample data created (simulated)"
 fi
}

# Helper function to check if function exists
function_exists() {
 local function_name="${1}"
 local dbname="${2:-${TEST_DBNAME}}"

 # Detect if running in Docker or host
 if [[ -f "/app/bin/functionsProcess.sh" ]]; then
  # Running in Docker - try to connect to real database
  local result
  result=$(psql -d "${dbname}" -t -c "SELECT COUNT(*) FROM information_schema.routines WHERE routine_name = '${function_name}';" 2> /dev/null)

  if [[ "${result}" == "1" ]]; then
   return 0
  else
   return 1
  fi
 else
  # Running on host - simulate function check
  echo "Function ${function_name} exists (simulated)"
  return 0
 fi
}

# Helper function to check if procedure exists
procedure_exists() {
 local procedure_name="${1}"
 local dbname="${2:-${TEST_DBNAME}}"

 # Detect if running in Docker or host
 if [[ -f "/app/bin/functionsProcess.sh" ]]; then
  # Running in Docker - try to connect to real database
  local result
  result=$(psql -d "${dbname}" -t -c "SELECT COUNT(*) FROM information_schema.routines WHERE routine_name = '${procedure_name}' AND routine_type = 'PROCEDURE';" 2> /dev/null)

  if [[ "${result}" == "1" ]]; then
   return 0
  else
   return 1
  fi
 else
  # Running on host - simulate procedure check
  echo "Procedure ${procedure_name} exists (simulated)"
  return 0
 fi
}
