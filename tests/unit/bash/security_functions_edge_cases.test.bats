#!/usr/bin/env bats

# Security Functions Edge Cases Tests
# Tests for edge cases and boundary conditions
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
# Edge Cases and Boundary Tests
# =============================================================================

@test "Edge case: string with only single quote" {
 # Test string with only a single quote
 result=$(__sanitize_sql_string "'")
 [[ "${result}" == "''" ]]
}

@test "Edge case: string with many single quotes" {
 # Test string with many single quotes
 result=$(__sanitize_sql_string "''''''")
 [[ "${result}" == "''''''''''''" ]]
}

@test "Edge case: identifier with maximum valid length" {
 # Test identifier at reasonable length
 long_id="a$(printf '%.0sa' {1..60})"
 result=$(__sanitize_sql_identifier "${long_id}")
 [[ "${result}" == "\"${long_id}\"" ]]
}

@test "Edge case: integer at boundary values" {
 # Test maximum integer (approximate)
 result=$(__sanitize_sql_integer "2147483647")
 [[ "${result}" == "2147483647" ]]

 # Test minimum integer
 result=$(__sanitize_sql_integer "-2147483648")
 [[ "${result}" == "-2147483648" ]]
}

@test "Edge case: database name with only underscores" {
 # Test database name with only underscores (should fail)
 run __sanitize_database_name "___"
 [[ "${status}" -ne 0 ]]
}

@test "Edge case: database name with only numbers" {
 # Test database name with only numbers (should work)
 result=$(__sanitize_database_name "123")
 [[ "${result}" == "123" ]]
}

