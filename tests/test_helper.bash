#!/usr/bin/env bash

# Test helper functions for BATS tests
# Author: Andres Gomez (AngocA)
# Version: 2025-07-20

# Test database configuration
export TEST_DBNAME="osm_notes_test"
export TEST_DBUSER="test_user"
export TEST_DBPASSWORD="test_pass"
export TEST_DBHOST="localhost"
export TEST_DBPORT="5432"

# Test directories
if [[ -n "$BATS_TEST_FILENAME" ]]; then
  export TEST_BASE_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
else
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
source "${TEST_BASE_DIR}/etc/properties.sh"

# Load the logger first
source "${TEST_BASE_DIR}/lib/bash_logger.sh"

# Load the functions to test
source "${TEST_BASE_DIR}/bin/functionsProcess.sh"

# Initialize logging system
__start_logger

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

# Helper function to create test database
create_test_database() {
  local dbname="${1:-${TEST_DBNAME}}"
  
  # Drop database if exists
  dropdb --if-exists "${dbname}" 2>/dev/null || true
  
  # Create database
  createdb "${dbname}" 2>/dev/null || {
    echo "Failed to create test database ${dbname}"
    return 1
  }
  
  echo "Test database ${dbname} created successfully"
}

# Helper function to drop test database
drop_test_database() {
  local dbname="${1:-${TEST_DBNAME}}"
  
  dropdb --if-exists "${dbname}" 2>/dev/null || true
  echo "Test database ${dbname} dropped"
}

# Helper function to run SQL file
run_sql_file() {
  local sql_file="${1}"
  local dbname="${2:-${TEST_DBNAME}}"
  
  if [[ -f "${sql_file}" ]]; then
    psql -d "${dbname}" -f "${sql_file}" 2>/dev/null
    return $?
  else
    echo "SQL file not found: ${sql_file}"
    return 1
  fi
}

# Helper function to check if table exists
table_exists() {
  local table_name="${1}"
  local dbname="${2:-${TEST_DBNAME}}"
  
  local result
  result=$(psql -d "${dbname}" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_name = '${table_name}';" 2>/dev/null | tr -d ' ')
  
  if [[ "${result}" == "1" ]]; then
    return 0
  else
    return 1
  fi
}

# Helper function to count rows in table
count_rows() {
  local table_name="${1}"
  local dbname="${2:-${TEST_DBNAME}}"
  
  psql -d "${dbname}" -t -c "SELECT COUNT(*) FROM ${table_name};" 2>/dev/null | tr -d ' '
}

# Helper function to create sample data
create_sample_data() {
  local dbname="${1:-${TEST_DBNAME}}"
  
  psql -d "${dbname}" -c "
    INSERT INTO notes (note_id, latitude, longitude, created_at, status) VALUES
    (123, 40.7128, -74.0060, '2013-04-28T02:39:27Z', 'open'),
    (456, 34.0522, -118.2437, '2013-04-30T15:20:45Z', 'closed');
  " 2>/dev/null
  
  psql -d "${dbname}" -c "
    INSERT INTO note_comments (note_id, sequence_action, event, created_at, id_user) VALUES
    (123, 1, 'opened', '2013-04-28T02:39:27Z', 123),
    (456, 1, 'opened', '2013-04-30T15:20:45Z', 456),
    (456, 2, 'closed', '2013-05-01T10:15:30Z', 789);
  " 2>/dev/null
}

# Helper function to check if function exists
function_exists() {
  local function_name="${1}"
  local dbname="${2:-${TEST_DBNAME}}"
  
  local result
  result=$(psql -d "${dbname}" -t -c "SELECT COUNT(*) FROM information_schema.routines WHERE routine_name = '${function_name}';" 2>/dev/null)
  
  if [[ "${result}" == "1" ]]; then
    return 0
  else
    return 1
  fi
}

# Helper function to check if procedure exists
procedure_exists() {
  local procedure_name="${1}"
  local dbname="${2:-${TEST_DBNAME}}"
  
  local result
  result=$(psql -d "${dbname}" -t -c "SELECT COUNT(*) FROM information_schema.routines WHERE routine_name = '${procedure_name}' AND routine_type = 'PROCEDURE';" 2>/dev/null)
  
  if [[ "${result}" == "1" ]]; then
    return 0
  else
    return 1
  fi
} 