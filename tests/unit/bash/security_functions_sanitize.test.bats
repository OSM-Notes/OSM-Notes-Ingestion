#!/usr/bin/env bats

# Security Functions Sanitize Tests
# Tests for SQL sanitization functions (string, identifier, integer, database)
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
# Tests for __sanitize_sql_string
# =============================================================================

@test "__sanitize_sql_string should escape single quotes" {
 # Test basic single quote escaping
 result=$(__sanitize_sql_string "test'value")
 [[ "${result}" == "test''value" ]]
}

@test "__sanitize_sql_string should handle multiple single quotes" {
 # Test multiple single quotes
 result=$(__sanitize_sql_string "test''value")
 [[ "${result}" == "test''''value" ]]
}

@test "__sanitize_sql_string should handle SQL injection attempt" {
 # Test classic SQL injection pattern
 result=$(__sanitize_sql_string "'; DROP TABLE users; --")
 [[ "${result}" == "''; DROP TABLE users; --" ]]
}

@test "__sanitize_sql_string should handle OR 1=1 injection" {
 # Test OR 1=1 injection pattern
 result=$(__sanitize_sql_string "' OR '1'='1")
 [[ "${result}" == "'' OR ''1''=''1" ]]
}

@test "__sanitize_sql_string should handle empty string" {
 # Test empty string
 result=$(__sanitize_sql_string "")
 [[ "${result}" == "" ]]
}

@test "__sanitize_sql_string should handle string without quotes" {
 # Test normal string without quotes
 result=$(__sanitize_sql_string "normal_value")
 [[ "${result}" == "normal_value" ]]
}

@test "__sanitize_sql_string should handle special characters" {
 # Test special characters (not SQL injection, but edge case)
 result=$(__sanitize_sql_string "test@#$%^&*()")
 [[ "${result}" == "test@#\$%^&*()" ]]
}

# =============================================================================
# Tests for __sanitize_sql_identifier
# =============================================================================

@test "__sanitize_sql_identifier should wrap unquoted identifier" {
 # Test basic identifier wrapping
 result=$(__sanitize_sql_identifier "table_name")
 [[ "${result}" == "\"table_name\"" ]]
}

@test "__sanitize_sql_identifier should not double-quote already quoted identifier" {
 # Test already quoted identifier
 result=$(__sanitize_sql_identifier "\"table_name\"")
 [[ "${result}" == "\"table_name\"" ]]
}

@test "__sanitize_sql_identifier should fail on empty input" {
 # Test empty identifier (should return error)
 run __sanitize_sql_identifier ""
 [[ "${status}" -ne 0 ]]
 [[ "${output}" == *"Empty identifier"* ]]
}

@test "__sanitize_sql_identifier should handle valid identifier with numbers" {
 # Test identifier with numbers
 result=$(__sanitize_sql_identifier "table_123")
 [[ "${result}" == "\"table_123\"" ]]
}

@test "__sanitize_sql_identifier should handle identifier with underscores" {
 # Test identifier with multiple underscores
 result=$(__sanitize_sql_identifier "my_table_name")
 [[ "${result}" == "\"my_table_name\"" ]]
}

@test "__sanitize_sql_identifier should prevent SQL injection in identifier" {
 # Test that injection attempts are properly quoted
 result=$(__sanitize_sql_identifier "table; DROP TABLE users; --")
 [[ "${result}" == "\"table; DROP TABLE users; --\"" ]]
}

# =============================================================================
# Tests for __sanitize_sql_integer
# =============================================================================

@test "__sanitize_sql_integer should accept valid positive integer" {
 # Test valid positive integer
 result=$(__sanitize_sql_integer "123")
 [[ "${result}" == "123" ]]
}

@test "__sanitize_sql_integer should accept valid negative integer" {
 # Test valid negative integer
 result=$(__sanitize_sql_integer "-456")
 [[ "${result}" == "-456" ]]
}

@test "__sanitize_sql_integer should accept zero" {
 # Test zero
 result=$(__sanitize_sql_integer "0")
 [[ "${result}" == "0" ]]
}

@test "__sanitize_sql_integer should reject non-integer string" {
 # Test non-integer string
 run __sanitize_sql_integer "abc"
 [[ "${status}" -ne 0 ]]
 [[ "${output}" == *"Invalid integer format"* ]]
}

@test "__sanitize_sql_integer should reject float" {
 # Test float number
 run __sanitize_sql_integer "123.45"
 [[ "${status}" -ne 0 ]]
 [[ "${output}" == *"Invalid integer format"* ]]
}

@test "__sanitize_sql_integer should reject empty string" {
 # Test empty string
 run __sanitize_sql_integer ""
 [[ "${status}" -ne 0 ]]
 [[ "${output}" == *"Empty integer"* ]]
}

@test "__sanitize_sql_integer should reject SQL injection attempt" {
 # Test SQL injection in integer
 run __sanitize_sql_integer "1; DROP TABLE users; --"
 [[ "${status}" -ne 0 ]]
 [[ "${output}" == *"Invalid integer format"* ]]
}

@test "__sanitize_sql_integer should reject string with numbers" {
 # Test string containing numbers but not pure integer
 run __sanitize_sql_integer "123abc"
 [[ "${status}" -ne 0 ]]
 [[ "${output}" == *"Invalid integer format"* ]]
}

@test "__sanitize_sql_integer should handle large integers" {
 # Test large integer
 result=$(__sanitize_sql_integer "999999999")
 [[ "${result}" == "999999999" ]]
}

# =============================================================================
# Tests for __sanitize_database_name
# =============================================================================

@test "__sanitize_database_name should accept valid database name" {
 # Test valid database name
 result=$(__sanitize_database_name "test_db")
 [[ "${result}" == "test_db" ]]
}

@test "__sanitize_database_name should accept database name with numbers" {
 # Test database name with numbers
 result=$(__sanitize_database_name "db123")
 [[ "${result}" == "db123" ]]
}

@test "__sanitize_database_name should reject empty string" {
 # Test empty database name
 run __sanitize_database_name ""
 [[ "${status}" -ne 0 ]]
 [[ "${output}" == *"Empty database name"* ]]
}

@test "__sanitize_database_name should reject uppercase letters" {
 # Test uppercase letters (PostgreSQL identifiers should be lowercase)
 run __sanitize_database_name "TestDB"
 [[ "${status}" -ne 0 ]]
 [[ "${output}" == *"Invalid database name"* ]]
}

@test "__sanitize_database_name should reject special characters" {
 # Test special characters
 run __sanitize_database_name "test-db"
 [[ "${status}" -ne 0 ]]
 [[ "${output}" == *"Invalid database name"* ]]
}

@test "__sanitize_database_name should reject SQL injection attempt" {
 # Test SQL injection
 run __sanitize_database_name "test; DROP DATABASE; --"
 [[ "${status}" -ne 0 ]]
 [[ "${output}" == *"Invalid database name"* ]]
}

@test "__sanitize_database_name should reject name starting with underscore" {
 # Test name starting with underscore
 run __sanitize_database_name "_test_db"
 [[ "${status}" -ne 0 ]]
 [[ "${output}" == *"cannot start or end with underscore"* ]]
}

@test "__sanitize_database_name should reject name ending with underscore" {
 # Test name ending with underscore
 run __sanitize_database_name "test_db_"
 [[ "${status}" -ne 0 ]]
 [[ "${output}" == *"cannot start or end with underscore"* ]]
}

@test "__sanitize_database_name should reject name too long" {
 # Test name exceeding PostgreSQL 63 byte limit
 long_name="a$(printf '%.0sa' {1..63})"
 run __sanitize_database_name "${long_name}"
 [[ "${status}" -ne 0 ]]
 [[ "${output}" == *"too long"* ]]
}

@test "__sanitize_database_name should accept maximum length name" {
 # Test name at maximum length (63 characters)
 max_name="a$(printf '%.0sa' {1..61})"
 result=$(__sanitize_database_name "${max_name}")
 [[ "${result}" == "${max_name}" ]]
}

