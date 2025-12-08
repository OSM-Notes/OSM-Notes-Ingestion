#!/usr/bin/env bats

# Security Functions SQL Injection Tests
# Tests for SQL injection prevention scenarios
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
# Integration Tests: Real SQL Injection Scenarios
# =============================================================================

@test "SQL injection: classic OR 1=1 should be sanitized in string" {
 # Test that classic OR 1=1 injection is properly escaped
 malicious_input="' OR '1'='1"
 sanitized=$(__sanitize_sql_string "${malicious_input}")

 # The sanitized version should have all quotes escaped
 [[ "${sanitized}" == *"''"* ]]
 # Should not contain the original injection pattern as-is
 [[ "${sanitized}" != "${malicious_input}" ]]
}

@test "SQL injection: UNION SELECT should be sanitized in string" {
 # Test UNION SELECT injection
 malicious_input="' UNION SELECT * FROM users --"
 sanitized=$(__sanitize_sql_string "${malicious_input}")

 # Should escape quotes
 [[ "${sanitized}" == *"''"* ]]
}

@test "SQL injection: DROP TABLE should be sanitized in string" {
 # Test DROP TABLE injection
 malicious_input="'; DROP TABLE users; --"
 sanitized=$(__sanitize_sql_string "${malicious_input}")

 # Should escape quotes
 [[ "${sanitized}" == *"''"* ]]
}

@test "SQL injection: identifier injection should be quoted" {
 # Test that malicious identifier is properly quoted
 malicious_identifier="table; DROP TABLE users; --"
 sanitized=$(__sanitize_sql_identifier "${malicious_identifier}")

 # Should be wrapped in quotes
 [[ "${sanitized}" == "\"${malicious_identifier}\"" ]]
}

@test "SQL injection: integer injection should be rejected" {
 # Test that malicious integer input is rejected
 malicious_integer="1; DROP TABLE users; --"

 run __sanitize_sql_integer "${malicious_integer}"

 # Should fail validation
 [[ "${status}" -ne 0 ]]
}

@test "SQL injection: database name injection should be rejected" {
 # Test that malicious database name is rejected
 malicious_dbname="test; DROP DATABASE; --"

 run __sanitize_database_name "${malicious_dbname}"

 # Should fail validation
 [[ "${status}" -ne 0 ]]
}

