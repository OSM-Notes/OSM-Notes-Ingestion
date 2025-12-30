#!/usr/bin/env bats

# Security Functions Edge Cases Tests
# Tests for edge cases and boundary conditions
# Author: Andres Gomez (AngocA)
# Version: 2025-12-08

load "${BATS_TEST_DIRNAME}/../../test_helper"

setup() {
 export TEST_BASE_DIR="${SCRIPT_BASE_DIRECTORY}"
 setup_test_properties
 # Create temporary test directory
 TEST_DIR=$(mktemp -d)
 export TEST_DIR

 # Load security functions
 source "${TEST_BASE_DIR}/bin/lib/securityFunctions.sh"
}

teardown() {
 # Clean up test files
 rm -rf "${TEST_DIR}"
 restore_properties
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

# =============================================================================
# Encoding Evasion Tests
# =============================================================================

@test "Encoding evasion: UTF-8 single quote variants should be sanitized" {
 # Test UTF-8 variants of single quote
 result1=$(__sanitize_sql_string "'")
 result2=$(__sanitize_sql_string "''")
 
 # All should be escaped
 [[ "${result1}" == "''" ]]
 [[ "${result2}" == "''''" ]]
}

@test "Encoding evasion: Unicode characters should be preserved" {
 # Test that Unicode characters are preserved (not broken by sanitization)
 unicode_input="test'value_测试_тест"
 result=$(__sanitize_sql_string "${unicode_input}")
 
 # Should escape quotes but preserve Unicode
 [[ "${result}" == *"''"* ]]
 [[ "${result}" == *"测试"* ]]
 [[ "${result}" == *"тест"* ]]
}

@test "Encoding evasion: mixed encoding attack should be sanitized" {
 # Test mixed encoding attack attempt
 malicious_input="' OR 1=1 --"
 result=$(__sanitize_sql_string "${malicious_input}")
 
 # Should escape quotes
 [[ "${result}" == *"''"* ]]
}

@test "Encoding evasion: identifier with Unicode should be quoted" {
 # Test identifier with Unicode characters
 unicode_id="table_测试_123"
 result=$(__sanitize_sql_identifier "${unicode_id}")
 
 # Should be wrapped in quotes
 [[ "${result}" == "\"${unicode_id}\"" ]]
}

# =============================================================================
# Advanced Edge Cases
# =============================================================================

@test "Edge case: string with newlines should be sanitized" {
 # Test string with newlines
 multiline_input="line1'line2"
 result=$(__sanitize_sql_string "${multiline_input}")
 
 # Should escape quotes
 [[ "${result}" == *"''"* ]]
}

@test "Edge case: string with tabs should be sanitized" {
 # Test string with tabs
 tab_input="value'	tab"
 result=$(__sanitize_sql_string "${tab_input}")
 
 # Should escape quotes
 [[ "${result}" == *"''"* ]]
}

@test "Edge case: identifier with maximum length should be handled" {
 # Test identifier at PostgreSQL limit (63 bytes)
 long_id="a$(printf '%.0sa' {1..60})"
 result=$(__sanitize_sql_identifier "${long_id}")
 
 # Should be wrapped in quotes
 [[ "${result}" == "\"${long_id}\"" ]]
}

@test "Edge case: database name at maximum length should be validated" {
 # Test database name at PostgreSQL limit (63 bytes)
 long_dbname="a$(printf '%.0sa' {1..60})"
 result=$(__sanitize_database_name "${long_dbname}")
 
 # Should pass validation
 [[ "${result}" == "${long_dbname}" ]]
}

@test "Edge case: database name exceeding maximum length should be rejected" {
 # Test database name exceeding PostgreSQL limit (64+ bytes)
 long_dbname="a$(printf '%.0sa' {1..63})"
 
 run __sanitize_database_name "${long_dbname}"
 
 # Should fail validation
 [[ "${status}" -ne 0 ]]
}

@test "Edge case: integer with leading zeros should be accepted" {
 # Test integer with leading zeros (should be normalized)
 result=$(__sanitize_sql_integer "00123")
 [[ "${result}" == "00123" ]]
}

@test "Edge case: negative zero should be handled" {
 # Test negative zero
 result=$(__sanitize_sql_integer "-0")
 [[ "${result}" == "-0" ]]
}

