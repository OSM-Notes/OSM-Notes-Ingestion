#!/usr/bin/env bats

# Tests for enhanced error handling functions
# Author: Andres Gomez (AngocA)
# Version: 2025-07-29

load "${BATS_TEST_DIRNAME}/../../test_helper"

setup() {
 # Create temporary test directory
 TEST_DIR=$(mktemp -d)
 export TEST_DIR
}

teardown() {
 # Clean up test files
 rm -rf "${TEST_DIR}"
}

@test "retry_with_backoff should succeed on first attempt" {
 # Test successful command on first attempt
 run __retry_with_backoff "echo 'success'"
 [ "$status" -eq 0 ]
 [[ "$output" == *"Command succeeded on attempt 1"* ]]
}

@test "retry_with_backoff should succeed after failures" {
 # Create a command that fails twice then succeeds
 cat > "${TEST_DIR}/test_script.sh" << 'EOF'
#!/bin/bash
if [[ ! -f /tmp/retry_test_counter ]]; then
 echo "1" > /tmp/retry_test_counter
 exit 1
elif [[ $(cat /tmp/retry_test_counter) -eq 1 ]]; then
 echo "2" > /tmp/retry_test_counter
 exit 1
else
 echo "success"
 rm -f /tmp/retry_test_counter
 exit 0
fi
EOF
 chmod +x "${TEST_DIR}/test_script.sh"

 run __retry_with_backoff "${TEST_DIR}/test_script.sh" 3 1 10
 [ "$status" -eq 0 ]
 [[ "$output" == *"Command succeeded on attempt 3"* ]]
}

@test "retry_with_backoff should fail after max retries" {
 # Test command that always fails
 run __retry_with_backoff "false" 2 1 5
 [ "$status" -eq 1 ]
 [[ "$output" == *"Command failed after 2 attempts"* ]]
}

@test "circuit_breaker_execute should succeed when circuit is closed" {
 # Test successful execution when circuit is closed
 run __circuit_breaker_execute "test_service" "echo 'success'"
 [ "$status" -eq 0 ]
 [[ "$output" == *"Circuit breaker for test_service transitioning to CLOSED"* ]]
}

@test "circuit_breaker_execute should open circuit after threshold failures" {
 # Test circuit opening after multiple failures
 for i in {1..5}; do
  run __circuit_breaker_execute "failure_service" "false"
  [ "$status" -eq 1 ]
 done

 # Check that circuit is now open
 run __get_circuit_breaker_status "failure_service"
 [ "$status" -eq 0 ]
 [[ "$output" == "OPEN" ]]
}

@test "circuit_breaker_execute should skip execution when circuit is open" {
 # First, open the circuit
 for i in {1..5}; do
  __circuit_breaker_execute "skip_service" "false" >/dev/null 2>&1
 done

 # Now test that execution is skipped
 run __circuit_breaker_execute "skip_service" "echo 'should not execute'"
 [ "$status" -eq 1 ]
 [[ "$output" == *"Circuit breaker for skip_service is OPEN, skipping execution"* ]]
}

@test "download_with_retry should succeed with valid URL" {
 # Mock wget to simulate successful download
 cat > "${TEST_DIR}/wget" << 'EOF'
#!/bin/bash
echo "Downloading $2 to $4"
echo "success" > "$4"
exit 0
EOF
 chmod +x "${TEST_DIR}/wget"
 export PATH="${TEST_DIR}:${PATH}"

 run __download_with_retry "https://example.com/test" "${TEST_DIR}/output.txt"
 [ "$status" -eq 0 ]
 [[ "$output" == *"Download successful"* ]]
}

@test "api_call_with_retry should succeed with valid URL" {
 # Mock curl to simulate successful API call
 cat > "${TEST_DIR}/curl" << 'EOF'
#!/bin/bash
echo "Making API call to $2"
echo "success" > "$4"
exit 0
EOF
 chmod +x "${TEST_DIR}/curl"
 export PATH="${TEST_DIR}:${PATH}"

 run __api_call_with_retry "https://api.example.com/test" "${TEST_DIR}/output.txt"
 [ "$status" -eq 0 ]
 [[ "$output" == *"API call successful"* ]]
}

@test "database_operation_with_retry should succeed with valid SQL" {
 # Mock psql to simulate successful database operation
 cat > "${TEST_DIR}/psql" << 'EOF'
#!/bin/bash
echo "Executing SQL: $*"
exit 0
EOF
 chmod +x "${TEST_DIR}/psql"
 export PATH="${TEST_DIR}:${PATH}"

 run __database_operation_with_retry "SELECT 1;"
 [ "$status" -eq 0 ]
 [[ "$output" == *"Database operation succeeded"* ]]
}

@test "database_operation_with_retry should execute rollback on failure" {
 # Mock psql to simulate database failure then rollback success
 cat > "${TEST_DIR}/psql" << 'EOF'
#!/bin/bash
if [[ "$*" == *"SELECT 1;"* ]]; then
 echo "Database operation failed"
 exit 1
elif [[ "$*" == *"ROLLBACK"* ]]; then
 echo "Rollback executed"
 exit 0
fi
EOF
 chmod +x "${TEST_DIR}/psql"
 export PATH="${TEST_DIR}:${PATH}"

 run __database_operation_with_retry "SELECT 1;" "ROLLBACK;"
 [ "$status" -eq 1 ]
 [[ "$output" == *"Rollback executed"* ]]
}

@test "file_operation_with_retry should succeed with valid operation" {
 # Test successful file operation
 run __file_operation_with_retry "echo 'test' > ${TEST_DIR}/test.txt"
 [ "$status" -eq 0 ]
 [[ "$output" == *"File operation succeeded"* ]]
 [ -f "${TEST_DIR}/test.txt" ]
}

@test "file_operation_with_retry should execute cleanup on failure" {
 # Test file operation with cleanup
 run __file_operation_with_retry "false" "echo 'cleanup executed' > ${TEST_DIR}/cleanup.txt"
 [ "$status" -eq 1 ]
 [[ "$output" == *"cleanup executed"* ]]
 [ -f "${TEST_DIR}/cleanup.txt" ]
}

@test "check_network_connectivity should succeed with internet" {
 # Mock curl to simulate successful connectivity check
 cat > "${TEST_DIR}/curl" << 'EOF'
#!/bin/bash
if [[ "$*" == *"timeout"* ]]; then
 exit 0
fi
exit 1
EOF
 chmod +x "${TEST_DIR}/curl"
 export PATH="${TEST_DIR}:${PATH}"

 run __check_network_connectivity 5
 [ "$status" -eq 0 ]
 [[ "$output" == *"Network connectivity confirmed"* ]]
}

@test "handle_error_with_cleanup should execute cleanup commands" {
 # Test error handling with cleanup
 run __handle_error_with_cleanup 255 "Test error" "echo 'cleanup1' > ${TEST_DIR}/cleanup1.txt" "echo 'cleanup2' > ${TEST_DIR}/cleanup2.txt"
 [ "$status" -eq 255 ]
 [ -f "${TEST_DIR}/cleanup1.txt" ]
 [ -f "${TEST_DIR}/cleanup2.txt" ]
 [[ "$(cat ${TEST_DIR}/cleanup1.txt)" == "cleanup1" ]]
 [[ "$(cat ${TEST_DIR}/cleanup2.txt)" == "cleanup2" ]]
}

@test "get_circuit_breaker_status should return current status" {
 # Test getting circuit breaker status
 run __get_circuit_breaker_status "test_service"
 [ "$status" -eq 0 ]
 [[ "$output" == "CLOSED" ]]
}

@test "reset_circuit_breaker should reset circuit state" {
 # First, open the circuit
 for i in {1..5}; do
  __circuit_breaker_execute "reset_service" "false" >/dev/null 2>&1
 done

 # Verify circuit is open
 run __get_circuit_breaker_status "reset_service"
 [[ "$output" == "OPEN" ]]

 # Reset the circuit
 run __reset_circuit_breaker "reset_service"
 [ "$status" -eq 0 ]

 # Verify circuit is closed
 run __get_circuit_breaker_status "reset_service"
 [[ "$output" == "CLOSED" ]]
}

@test "error handling functions should be available" {
 # Test that all error handling functions exist
 run declare -f __retry_with_backoff
 [ "$status" -eq 0 ]
 [[ "$output" == *"__retry_with_backoff"* ]]

 run declare -f __circuit_breaker_execute
 [ "$status" -eq 0 ]
 [[ "$output" == *"__circuit_breaker_execute"* ]]

 run declare -f __download_with_retry
 [ "$status" -eq 0 ]
 [[ "$output" == *"__download_with_retry"* ]]

 run declare -f __api_call_with_retry
 [ "$status" -eq 0 ]
 [[ "$output" == *"__api_call_with_retry"* ]]

 run declare -f __database_operation_with_retry
 [ "$status" -eq 0 ]
 [[ "$output" == *"__database_operation_with_retry"* ]]

 run declare -f __file_operation_with_retry
 [ "$status" -eq 0 ]
 [[ "$output" == *"__file_operation_with_retry"* ]]

 run declare -f __check_network_connectivity
 [ "$status" -eq 0 ]
 [[ "$output" == *"__check_network_connectivity"* ]]

 run declare -f __handle_error_with_cleanup
 [ "$status" -eq 0 ]
 [[ "$output" == *"__handle_error_with_cleanup"* ]]
} 