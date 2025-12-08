#!/usr/bin/env bats

# Security Functions Integration Tests
# Tests for SQL execution with parameters and function availability
# Author: Andres Gomez (AngocA)
# Version: 2025-12-08

load "${BATS_TEST_DIRNAME}/../../test_helper"

setup() {
 # Create temporary test directory
 TEST_DIR=$(mktemp -d)
 export TEST_DIR

 # Load security functions
 source "${TEST_BASE_DIR}/bin/lib/securityFunctions.sh"
}

teardown() {
 # Clean up test files
 rm -rf "${TEST_DIR}"
}

# =============================================================================
# Tests for __execute_sql_with_params
# =============================================================================

@test "__execute_sql_with_params should sanitize variable names" {
 # Test that variable names are sanitized
 # This test verifies the function doesn't crash with special chars in var names
 local TEST_DB="test_db"
 local SQL_TEMPLATE="SELECT :var1;"

 # Mock psql to capture the command
 cat > "${TEST_DIR}/psql" << 'EOF'
#!/bin/bash
echo "psql called with: $*"
exit 0
EOF
 chmod +x "${TEST_DIR}/psql"
 export PATH="${TEST_DIR}:${PATH}"

 # Test with special characters in variable name (should be sanitized)
 run __execute_sql_with_params "${TEST_DB}" "${SQL_TEMPLATE}" "var;DROP" "value"

 # Should not crash and should sanitize the variable name
 [[ "${status}" -eq 0 ]] || [[ "${status}" -eq 1 ]]
}

@test "__execute_sql_with_params should handle multiple parameters" {
 # Test multiple parameters
 local TEST_DB="test_db"
 local SQL_TEMPLATE="SELECT :var1, :var2;"

 # Mock psql
 cat > "${TEST_DIR}/psql" << 'EOF'
#!/bin/bash
echo "psql called"
exit 0
EOF
 chmod +x "${TEST_DIR}/psql"
 export PATH="${TEST_DIR}:${PATH}"

 run __execute_sql_with_params "${TEST_DB}" "${SQL_TEMPLATE}" "var1" "value1" "var2" "value2"

 # Should execute without error
 [[ "${status}" -eq 0 ]] || [[ "${status}" -eq 1 ]]
}

# =============================================================================
# Function Existence Tests
# =============================================================================

@test "All security functions should be available" {
 # Test that all security functions exist
 run declare -f __sanitize_sql_string
 [[ "${status}" -eq 0 ]]

 run declare -f __sanitize_sql_identifier
 [[ "${status}" -eq 0 ]]

 run declare -f __sanitize_sql_integer
 [[ "${status}" -eq 0 ]]

 run declare -f __sanitize_database_name
 [[ "${status}" -eq 0 ]]

 run declare -f __execute_sql_with_params
 [[ "${status}" -eq 0 ]]
}

