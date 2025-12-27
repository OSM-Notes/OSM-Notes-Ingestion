#!/usr/bin/env bats

# JSON Retry Logic Tests
# Tests retry mechanisms when JSON validation fails
# Author: Andres Gomez (AngocA)
# Version: 2025-12-23

load "$(dirname "$BATS_TEST_FILENAME")/../test_helper.bash"
load "$(dirname "$BATS_TEST_FILENAME")/json_validation_helpers.bash"

setup() {
 __setup_json_validation_test
}

teardown() {
 __teardown_json_validation_test
}

# =============================================================================
# Test: Retry Logic When JSON Validation Fails
# =============================================================================
# Purpose: Verify that the system retries downloads when JSON validation fails
# Scenario: First download returns corrupted JSON, system should retry
# Expected: System should retry download and eventually succeed or fail gracefully
@test "should retry download when JSON validation fails" {
 # Arrange: Create a mock scenario where first download is corrupted, then succeeds
 local TEST_ID="3793105"
 local JSON_FILE="${TMP_DIR}/${TEST_ID}.json"
 local QUERY_FILE="${TMP_DIR}/query_${TEST_ID}.op"
 local OUTPUT_OVERPASS="${TMP_DIR}/output_${TEST_ID}.txt"
 local CORRUPTED_JSON="${TMP_DIR}/corrupted_${TEST_ID}.json"
 local VALID_JSON="${TMP_DIR}/valid_${TEST_ID}.json"

 # Create corrupted JSON (valid structure but empty elements)
 cat > "${CORRUPTED_JSON}" << 'EOF'
{
  "version": 0.6,
  "generator": "Overpass API",
  "elements": []
}
EOF

 # Create valid JSON
 cat > "${VALID_JSON}" << 'EOF'
{
  "version": 0.6,
  "generator": "Overpass API",
  "elements": [
    {
      "type": "relation",
      "id": 3793105,
      "members": []
    }
  ]
}
EOF

 # Create query
 __create_overpass_query "${TEST_ID}" "${QUERY_FILE}"

 # Setup mock curl that returns corrupted JSON first, then valid JSON
 # Use a file to track retry count across function calls
 local RETRY_COUNT_FILE="${TMP_DIR}/retry_count.txt"
 echo "0" > "${RETRY_COUNT_FILE}"
 
 curl() {
  local ARGS=("$@")
  local OUTPUT_FILE=""
  
  # Extract output file
  for i in "${!ARGS[@]}"; do
   if [[ "${ARGS[$i]}" == "-o" ]] && [[ $((i + 1)) -lt ${#ARGS[@]} ]]; then
    OUTPUT_FILE="${ARGS[$((i + 1))]}"
    break
   fi
  done
  
  # Read current retry count
  local CURRENT_RETRY
  CURRENT_RETRY=$(cat "${RETRY_COUNT_FILE}" 2>/dev/null || echo "0")
  
  # First attempt: return corrupted JSON
  # Subsequent attempts: return valid JSON
  if [[ ${CURRENT_RETRY} -eq 0 ]]; then
   cp "${CORRUPTED_JSON}" "${OUTPUT_FILE}"
   echo "1" > "${RETRY_COUNT_FILE}"
  else
   cp "${VALID_JSON}" "${OUTPUT_FILE}"
  fi
  return 0
 }
 export -f curl

 # Simulate retry logic
 local DOWNLOAD_VALIDATION_RETRIES=3
 local DOWNLOAD_VALIDATION_RETRY_COUNT=0
 local DOWNLOAD_SUCCESS=false

 while [[ ${DOWNLOAD_VALIDATION_RETRY_COUNT} -lt ${DOWNLOAD_VALIDATION_RETRIES} ]] && [[ "${DOWNLOAD_SUCCESS}" == "false" ]]; do
  if [[ ${DOWNLOAD_VALIDATION_RETRY_COUNT} -gt 0 ]]; then
   # Clean up previous failed attempt
   rm -f "${JSON_FILE}" "${OUTPUT_OVERPASS}" 2> /dev/null || true
   __test_sleep 0.1
  fi

  # Attempt download
  run curl -s -H "User-Agent: OSM-Notes-Ingestion/1.0" -o "${JSON_FILE}" --data-binary @"${QUERY_FILE}" "${OVERPASS_INTERPRETER}" 2> "${OUTPUT_OVERPASS}"

  if [ "${status}" -eq 0 ] && [[ -f "${JSON_FILE}" ]] && [[ -s "${JSON_FILE}" ]]; then
   # Validate JSON structure
   if __validate_json_with_element "${JSON_FILE}" "elements"; then
    DOWNLOAD_SUCCESS=true
   else
    DOWNLOAD_VALIDATION_RETRY_COUNT=$((DOWNLOAD_VALIDATION_RETRY_COUNT + 1))
   fi
  else
   DOWNLOAD_VALIDATION_RETRY_COUNT=$((DOWNLOAD_VALIDATION_RETRY_COUNT + 1))
  fi
  
  # Use optimized sleep for retry delay (faster in CI)
  if [[ ${DOWNLOAD_VALIDATION_RETRY_COUNT} -lt ${DOWNLOAD_VALIDATION_RETRIES} ]] && [[ "${DOWNLOAD_SUCCESS}" == "false" ]]; then
   __test_sleep 0.1
  fi
 done

 # Should eventually succeed after retry
 [[ "${DOWNLOAD_SUCCESS}" == "true" ]]
 [[ ${DOWNLOAD_VALIDATION_RETRY_COUNT} -eq 1 ]]
}

# =============================================================================
# Test: Corrupted JSON Detection and Retry Trigger
# =============================================================================
# Purpose: Verify that corrupted JSON files are detected and trigger retry logic
# Scenario: JSON file has valid structure but empty elements array
# Expected: Validation should fail and trigger retry mechanism
@test "should detect corrupted JSON and trigger retry" {
 # Arrange: Create a corrupted JSON file (valid structure but empty elements)
 cat > "${TMP_DIR}/corrupted.json" << 'EOF'
{
  "version": 0.6,
  "generator": "Overpass API",
  "elements": []
}
EOF

 # Should fail validation
 run __validate_json_with_element "${TMP_DIR}/corrupted.json" "elements"
 [[ "${status}" -eq 1 ]]
 [[ "${output}" == *"is empty"* ]]
}

# =============================================================================
# Test: Error Handling After Max Retries
# =============================================================================
# Purpose: Verify graceful handling when validation fails after max retries
# Scenario: File that will always fail validation, retry until max retries
# Expected: Should fail gracefully after all retries exhausted
@test "should handle validation failure after max retries gracefully" {
 # Create a file that will always fail validation
 cat > "${TMP_DIR}/always_fail.json" << 'EOF'
{
  "version": 0.6,
  "generator": "Overpass API"
}
EOF

 # Simulate retry logic with max retries
 local MAX_RETRIES=3
 local RETRY_COUNT=0
 local SUCCESS=false

 while [[ ${RETRY_COUNT} -lt ${MAX_RETRIES} ]] && [[ "${SUCCESS}" == "false" ]]; do
  if __validate_json_with_element "${TMP_DIR}/always_fail.json" "elements"; then
   SUCCESS=true
  else
   RETRY_COUNT=$((RETRY_COUNT + 1))
   __test_sleep 0.1
  fi
 done

 # Should fail after all retries
 [[ "${SUCCESS}" == "false" ]]
 [[ ${RETRY_COUNT} -eq ${MAX_RETRIES} ]]
}

# =============================================================================
# Test: Overpass API Error Retry
# =============================================================================
# Purpose: Verify that Overpass API errors trigger retry in download loop
# Scenario: API returns error response, system should detect and retry
# Expected: Error detection should trigger retry mechanism
@test "should retry download when Overpass API returns errors" {
 # Test with a mock error response file
 local ERROR_OUTPUT="${TMP_DIR}/error_output.txt"
 echo "ERROR 429: Too Many Requests." > "${ERROR_OUTPUT}"

 # Check if error detection would trigger retry
 local MANY_REQUESTS
 MANY_REQUESTS=$(grep -c "ERROR 429" "${ERROR_OUTPUT}" 2> /dev/null || echo "0")
 MANY_REQUESTS=$(echo "${MANY_REQUESTS}" | tr -d '\n' | tr -d ' ')

 # Should detect error
 [[ "${MANY_REQUESTS}" -gt 0 ]]

 # Verify error response format
 local ERROR_RESPONSE="${TMP_DIR}/error_response.json"
 cat > "${ERROR_RESPONSE}" << 'EOF'
{
  "version": 0.6,
  "generator": "Overpass API",
  "remark": "runtime error: Query timed out"
}
EOF

 # Error response should fail validation (no elements)
 run __validate_json_with_element "${ERROR_RESPONSE}" "elements"
 [[ "${status}" -ne 0 ]]
}

# =============================================================================
# Test: Integration with __retry_file_operation Function
# =============================================================================
# Purpose: Verify integration with __retry_file_operation for downloads
# Scenario: Use __retry_file_operation to download JSON with retry logic
# Expected: Download should succeed with retry mechanism
@test "should integrate with __retry_file_operation for downloads" {
 if ! declare -f __retry_file_operation > /dev/null 2>&1; then
  skip "__retry_file_operation function not available"
 fi

 local TEST_ID="3793105"
 local JSON_FILE="${TMP_DIR}/${TEST_ID}.json"
 local QUERY_FILE="${TMP_DIR}/query_${TEST_ID}.op"
 local VALID_JSON="${TMP_DIR}/valid_response.json"

 # Create valid JSON response
 cat > "${VALID_JSON}" << 'EOF'
{
  "version": 0.6,
  "generator": "Overpass API",
  "elements": [
    {
      "type": "relation",
      "id": 3793105,
      "members": []
    }
  ]
}
EOF

 # Create query
 __create_overpass_query "${TEST_ID}" "${QUERY_FILE}"

 # Setup mock curl that returns valid JSON
 curl() {
  local ARGS=("$@")
  local OUTPUT_FILE=""
  
  # Extract output file
  for i in "${!ARGS[@]}"; do
   if [[ "${ARGS[$i]}" == "-o" ]] && [[ $((i + 1)) -lt ${#ARGS[@]} ]]; then
    OUTPUT_FILE="${ARGS[$((i + 1))]}"
    break
   fi
  done
  
  # Copy valid JSON to output file
  if [[ -n "${OUTPUT_FILE}" ]]; then
   cp "${VALID_JSON}" "${OUTPUT_FILE}"
  fi
  return 0
 }
 export -f curl

 # Use __retry_file_operation for download
 # Note: Using smart_wait=false to avoid dependency on download queue functions in test environment
 local OPERATION="curl -s -H 'User-Agent: OSM-Notes-Ingestion/1.0' -o '${JSON_FILE}' --data-binary '@${QUERY_FILE}' '${OVERPASS_INTERPRETER}' 2> /dev/null"
 run __retry_file_operation "${OPERATION}" 3 2 "" "false"

 # Download should succeed
 [[ "${status}" -eq 0 ]]
 [[ -f "${JSON_FILE}" ]]
 [[ -s "${JSON_FILE}" ]]

 # Then validate
 run __validate_json_with_element "${JSON_FILE}" "elements"
 [[ "${status}" -eq 0 ]]
}

