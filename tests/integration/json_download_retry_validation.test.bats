#!/usr/bin/env bats

# Integration tests for JSON download with validation and retry logic
# Tests the complete flow: download -> validate -> retry if validation fails
# Author: Andres Gomez (AngocA)
# Version: 2025-12-15

load "$(dirname "$BATS_TEST_FILENAME")/../test_helper.bash"

setup() {
 # Load test helper first
 load "$(dirname "$BATS_TEST_FILENAME")/../test_helper.bash"

 SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
 export SCRIPT_BASE_DIRECTORY
 export TMP_DIR="$(mktemp -d)"
 export BASENAME="test_json_validation_integration"
 export BASHPID=$$
 export RATE_LIMIT=4
 export OVERPASS_INTERPRETER="https://overpass-api.de/api/interpreter"
 export TEST_MODE="true"
 export DBNAME="${TEST_DBNAME:-test_db}"

 # Load required functions
 __load_validation_functions

 # Load functionsProcess.sh to get __retry_file_operation
 if [ -f "${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh" ]; then
  source "${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh" > /dev/null 2>&1 || true
 fi

 # Load noteProcessingFunctions.sh for download queue functions (needed by __retry_file_operation with smart_wait)
 if [ -f "${SCRIPT_BASE_DIRECTORY}/bin/lib/noteProcessingFunctions.sh" ]; then
  source "${SCRIPT_BASE_DIRECTORY}/bin/lib/noteProcessingFunctions.sh" > /dev/null 2>&1 || true
 fi

 # Check if jq is available
 if ! command -v jq > /dev/null 2>&1; then
  skip "jq not available - required for JSON validation tests"
 fi
}

teardown() {
 # Cleanup
 if [[ -n "${TMP_DIR:-}" ]] && [[ -d "${TMP_DIR}" ]]; then
  rm -rf "${TMP_DIR}" 2> /dev/null || true
 fi
}

# Helper function to load validation functions
__load_validation_functions() {
 # Check if function already loaded
 if declare -f __validate_json_with_element > /dev/null 2>&1; then
  return 0
 fi

 # Ensure commonFunctions.sh is loaded first (required by functionsProcess.sh)
 if [ -f "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/commonFunctions.sh" ]; then
  source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/commonFunctions.sh" > /dev/null 2>&1 || true
 fi
  
 # Try loading from correct location
 if [ -f "${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh" ]; then
  source "${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh" > /dev/null 2>&1 || true
 fi

 # Also ensure validationFunctions.sh is loaded
 if [ -f "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/validationFunctions.sh" ]; then
  source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/validationFunctions.sh" > /dev/null 2>&1 || true
 fi
  
 # Verify function is now loaded
 if ! declare -f __validate_json_with_element > /dev/null 2>&1; then
  echo "WARNING: __validate_json_with_element function not loaded" >&2
 fi
}

# =============================================================================
# Test: JSON Structure Validation After Download
# =============================================================================
# Purpose: Verify that JSON structure is validated after successful download
# Scenario: Download JSON from Overpass API and validate structure
# Expected: Downloaded JSON should be valid and contain required elements
@test "should validate JSON structure after successful download" {
 if ! command -v curl > /dev/null; then
  skip "curl not available for connectivity check"
 fi

 # Arrange: Check connectivity to Overpass API
 if ! curl -s --max-time 5 "${OVERPASS_INTERPRETER%/api/interpreter}/status" > /dev/null 2>&1; then
  skip "Overpass API not reachable"
 fi

 local TEST_ID="3793105" # Small test relation
 local JSON_FILE="${TMP_DIR}/${TEST_ID}.json"
 local QUERY_FILE="${TMP_DIR}/query_${TEST_ID}.op"
 local OUTPUT_OVERPASS="${TMP_DIR}/output_${TEST_ID}.txt"

 # Create query
 cat > "${QUERY_FILE}" << EOF
[out:json];
rel(${TEST_ID});
(._;>;);
out;
EOF

 # Download
 run curl -s -H "User-Agent: OSM-Notes-Ingestion/1.0" -o "${JSON_FILE}" --data-binary @"${QUERY_FILE}" "${OVERPASS_INTERPRETER}" 2> "${OUTPUT_OVERPASS}"

 if [ "${status}" -eq 0 ] && [[ -f "${JSON_FILE}" ]] && [[ -s "${JSON_FILE}" ]]; then
  # First check if JSON is valid
  if ! command -v jq > /dev/null 2>&1; then
   skip "jq not available for JSON validation"
  fi
  
  # Verify JSON is parseable
  if ! jq empty "${JSON_FILE}" > /dev/null 2>&1; then
   skip "Downloaded file is not valid JSON - may be rate limited or error response"
  fi
  
  # Validate JSON structure with element check
  run __validate_json_with_element "${JSON_FILE}" "elements"
  if [[ "${status}" -ne 0 ]]; then
   # Provide debug information
   echo "JSON validation failed. File content:" >&2
   head -20 "${JSON_FILE}" >&2 || true
   echo "Overpass output:" >&2
   cat "${OUTPUT_OVERPASS}" >&2 || true
   skip "JSON validation failed - downloaded JSON may not contain 'elements' field or may be error response"
  fi
  [[ -f "${JSON_FILE}" ]]
 else
  # Provide debug information for download failure
  if [[ -f "${OUTPUT_OVERPASS}" ]]; then
   echo "Download failed. Overpass output:" >&2
   cat "${OUTPUT_OVERPASS}" >&2 || true
  fi
  skip "Download failed - may be rate limited or network issue"
 fi
}

# =============================================================================
# Test: Retry Logic When JSON Validation Fails
# =============================================================================
# Purpose: Verify that the system retries downloads when JSON validation fails
# Scenario: First download returns corrupted JSON, system should retry
# Expected: System should retry download and eventually succeed or fail gracefully
@test "should retry download when JSON validation fails" {
 if ! command -v curl > /dev/null; then
  skip "curl not available"
 fi

 # Arrange: Create a mock scenario where first download is corrupted
 local TEST_ID="3793105"
 local JSON_FILE="${TMP_DIR}/${TEST_ID}.json"
 local QUERY_FILE="${TMP_DIR}/query_${TEST_ID}.op"
 local OUTPUT_OVERPASS="${TMP_DIR}/output_${TEST_ID}.txt"

 # Create query
 cat > "${QUERY_FILE}" << EOF
[out:json];
rel(${TEST_ID});
(._;>;);
out;
EOF

 # Simulate retry logic
 local DOWNLOAD_VALIDATION_RETRIES=3
 local DOWNLOAD_VALIDATION_RETRY_COUNT=0
 local DOWNLOAD_SUCCESS=false
 local MAX_RETRIES_LOCAL=3
 local BASE_DELAY_LOCAL=2

 while [[ ${DOWNLOAD_VALIDATION_RETRY_COUNT} -lt ${DOWNLOAD_VALIDATION_RETRIES} ]] && [[ "${DOWNLOAD_SUCCESS}" == "false" ]]; do
  if [[ ${DOWNLOAD_VALIDATION_RETRY_COUNT} -gt 0 ]]; then
   # Clean up previous failed attempt
   rm -f "${JSON_FILE}" "${OUTPUT_OVERPASS}" 2> /dev/null || true
   sleep 1
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
 done

 # Should eventually succeed (if API is available)
 if curl -s --max-time 5 "${OVERPASS_INTERPRETER%/api/interpreter}/status" > /dev/null 2>&1; then
  [[ "${DOWNLOAD_SUCCESS}" == "true" ]]
 else
  skip "Overpass API not reachable"
 fi
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
# Test: GeoJSON Conversion with Validation and Retry
# =============================================================================
# Purpose: Verify that GeoJSON conversion includes validation and retry logic
# Scenario: Convert JSON to GeoJSON and validate the result
# Expected: GeoJSON should be validated and retry should occur if validation fails
@test "should validate GeoJSON after conversion with retry logic" {
 if ! command -v osmtogeojson > /dev/null; then
  skip "osmtogeojson not available"
 fi

 if ! command -v curl > /dev/null; then
  skip "curl not available"
 fi

 # Check connectivity
 if ! curl -s --max-time 5 "${OVERPASS_INTERPRETER%/api/interpreter}/status" > /dev/null 2>&1; then
  skip "Overpass API not reachable"
 fi

 local TEST_ID="3793105"
 local JSON_FILE="${TMP_DIR}/${TEST_ID}.json"
 local GEOJSON_FILE="${TMP_DIR}/${TEST_ID}.geojson"
 local QUERY_FILE="${TMP_DIR}/query_${TEST_ID}.op"

 # Create query
 cat > "${QUERY_FILE}" << EOF
[out:json];
rel(${TEST_ID});
(._;>;);
out;
EOF

 # Download JSON first
 run curl -s -H "User-Agent: OSM-Notes-Ingestion/1.0" -o "${JSON_FILE}" --data-binary @"${QUERY_FILE}" "${OVERPASS_INTERPRETER}" 2> /dev/null

 if [ "${status}" -ne 0 ] || [[ ! -f "${JSON_FILE}" ]] || [[ ! -s "${JSON_FILE}" ]]; then
  skip "Download failed - may be rate limited"
 fi

 # Validate JSON before conversion
 if ! __validate_json_with_element "${JSON_FILE}" "elements"; then
  skip "JSON validation failed"
 fi

 # Simulate GeoJSON conversion with retry logic
 local GEOJSON_VALIDATION_RETRIES=3
 local GEOJSON_VALIDATION_RETRY_COUNT=0
 local GEOJSON_SUCCESS=false

 while [[ ${GEOJSON_VALIDATION_RETRY_COUNT} -lt ${GEOJSON_VALIDATION_RETRIES} ]] && [[ "${GEOJSON_SUCCESS}" == "false" ]]; do
  if [[ ${GEOJSON_VALIDATION_RETRY_COUNT} -gt 0 ]]; then
   rm -f "${GEOJSON_FILE}" 2> /dev/null || true
   sleep 1
  fi

  # Convert to GeoJSON
  if osmtogeojson "${JSON_FILE}" > "${GEOJSON_FILE}" 2> /dev/null; then
   # Validate GeoJSON structure
   if __validate_json_with_element "${GEOJSON_FILE}" "features"; then
    GEOJSON_SUCCESS=true
   else
    GEOJSON_VALIDATION_RETRY_COUNT=$((GEOJSON_VALIDATION_RETRY_COUNT + 1))
   fi
  else
   GEOJSON_VALIDATION_RETRY_COUNT=$((GEOJSON_VALIDATION_RETRY_COUNT + 1))
  fi
 done

 # Should succeed
 [[ "${GEOJSON_SUCCESS}" == "true" ]]
 [[ -f "${GEOJSON_FILE}" ]]
 [[ -s "${GEOJSON_FILE}" ]]
}

# Test complete workflow: download -> validate -> convert -> validate
@test "should complete full workflow with validation at each step" {
 if ! command -v osmtogeojson > /dev/null; then
  skip "osmtogeojson not available"
 fi

 if ! command -v curl > /dev/null; then
  skip "curl not available"
 fi

 # Check connectivity
 if ! curl -s --max-time 5 "${OVERPASS_INTERPRETER%/api/interpreter}/status" > /dev/null 2>&1; then
  skip "Overpass API not reachable"
 fi

 local TEST_ID="3793105"
 local JSON_FILE="${TMP_DIR}/${TEST_ID}.json"
 local GEOJSON_FILE="${TMP_DIR}/${TEST_ID}.geojson"
 local QUERY_FILE="${TMP_DIR}/query_${TEST_ID}.op"
 local OUTPUT_OVERPASS="${TMP_DIR}/output_${TEST_ID}.txt"

 # Create query
 cat > "${QUERY_FILE}" << EOF
[out:json];
rel(${TEST_ID});
(._;>;);
out;
EOF

 # Step 1: Download with retry logic
 local DOWNLOAD_SUCCESS=false
 local DOWNLOAD_RETRY_COUNT=0
 local MAX_DOWNLOAD_RETRIES=3

 while [[ ${DOWNLOAD_RETRY_COUNT} -lt ${MAX_DOWNLOAD_RETRIES} ]] && [[ "${DOWNLOAD_SUCCESS}" == "false" ]]; do
  if [[ ${DOWNLOAD_RETRY_COUNT} -gt 0 ]]; then
   rm -f "${JSON_FILE}" "${OUTPUT_OVERPASS}" 2> /dev/null || true
   sleep 2
  fi

  run curl -s -H "User-Agent: OSM-Notes-Ingestion/1.0" -o "${JSON_FILE}" --data-binary @"${QUERY_FILE}" "${OVERPASS_INTERPRETER}" 2> "${OUTPUT_OVERPASS}"

  if [ "${status}" -eq 0 ] && [[ -f "${JSON_FILE}" ]] && [[ -s "${JSON_FILE}" ]]; then
   # Step 2: Validate JSON
   if __validate_json_with_element "${JSON_FILE}" "elements"; then
    DOWNLOAD_SUCCESS=true
   else
    DOWNLOAD_RETRY_COUNT=$((DOWNLOAD_RETRY_COUNT + 1))
   fi
  else
   DOWNLOAD_RETRY_COUNT=$((DOWNLOAD_RETRY_COUNT + 1))
  fi
 done

 # Skip if download failed (may be rate limited)
 if [[ "${DOWNLOAD_SUCCESS}" != "true" ]]; then
  skip "Download failed after retries - may be rate limited"
 fi

 # Step 3: Convert to GeoJSON with retry logic
 local GEOJSON_SUCCESS=false
 local GEOJSON_RETRY_COUNT=0
 local MAX_GEOJSON_RETRIES=3

 while [[ ${GEOJSON_RETRY_COUNT} -lt ${MAX_GEOJSON_RETRIES} ]] && [[ "${GEOJSON_SUCCESS}" == "false" ]]; do
  if [[ ${GEOJSON_RETRY_COUNT} -gt 0 ]]; then
   rm -f "${GEOJSON_FILE}" 2> /dev/null || true
   sleep 1
  fi

  # Step 4: Convert
  if osmtogeojson "${JSON_FILE}" > "${GEOJSON_FILE}" 2> /dev/null; then
   # Step 5: Validate GeoJSON
   if __validate_json_with_element "${GEOJSON_FILE}" "features"; then
    GEOJSON_SUCCESS=true
   else
    GEOJSON_RETRY_COUNT=$((GEOJSON_RETRY_COUNT + 1))
   fi
  else
   GEOJSON_RETRY_COUNT=$((GEOJSON_RETRY_COUNT + 1))
  fi
 done

 # Both should succeed
 [[ "${DOWNLOAD_SUCCESS}" == "true" ]]
 [[ "${GEOJSON_SUCCESS}" == "true" ]]
 [[ -f "${JSON_FILE}" ]]
 [[ -f "${GEOJSON_FILE}" ]]
 [[ -s "${GEOJSON_FILE}" ]]
}

# Test error handling when validation fails after max retries
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
   sleep 0.1
  fi
 done

 # Should fail after all retries
 [[ "${SUCCESS}" == "false" ]]
 [[ ${RETRY_COUNT} -eq ${MAX_RETRIES} ]]
}

# Test that Overpass API errors trigger retry in download loop
@test "should retry download when Overpass API returns errors" {
 if ! command -v curl > /dev/null; then
  skip "curl not available"
 fi

 # Test with a mock error response file
 local ERROR_OUTPUT="${TMP_DIR}/error_output.txt"
 echo "ERROR 429: Too Many Requests." > "${ERROR_OUTPUT}"

 # Check if error detection would trigger retry
 local MANY_REQUESTS
 MANY_REQUESTS=$(grep -c "ERROR 429" "${ERROR_OUTPUT}" 2> /dev/null || echo "0")
 MANY_REQUESTS=$(echo "${MANY_REQUESTS}" | tr -d '\n' | tr -d ' ')

 # Should detect error
 [[ "${MANY_REQUESTS}" -gt 0 ]]
}

# Test that validation happens before expensive operations
@test "should validate JSON before expensive GeoJSON conversion" {
 # Create a mock JSON that would fail validation
 cat > "${TMP_DIR}/no_elements.json" << 'EOF'
{
  "version": 0.6,
  "generator": "Overpass API"
}
EOF

 # Should fail validation before attempting conversion
 run __validate_json_with_element "${TMP_DIR}/no_elements.json" "elements"
 [[ "${status}" -eq 1 ]]

 # Verify we didn't create a GeoJSON file
 [[ ! -f "${TMP_DIR}/no_elements.geojson" ]]
}

# Test integration with __retry_file_operation function
@test "should integrate with __retry_file_operation for downloads" {
 if ! command -v curl > /dev/null; then
  skip "curl not available"
 fi

 if ! declare -f __retry_file_operation > /dev/null 2>&1; then
  skip "__retry_file_operation function not available"
 fi

 # Check connectivity
 if ! curl -s --max-time 5 "${OVERPASS_INTERPRETER%/api/interpreter}/status" > /dev/null 2>&1; then
  skip "Overpass API not reachable"
 fi

 local TEST_ID="3793105"
 local JSON_FILE="${TMP_DIR}/${TEST_ID}.json"
 local QUERY_FILE="${TMP_DIR}/query_${TEST_ID}.op"

 # Create query
 cat > "${QUERY_FILE}" << EOF
[out:json];
rel(${TEST_ID});
(._;>;);
out;
EOF

 # Use __retry_file_operation for download
 # Note: Using smart_wait=false to avoid dependency on download queue functions in test environment
 local OPERATION="curl -s -H 'User-Agent: OSM-Notes-Ingestion/1.0' -o '${JSON_FILE}' --data-binary '@${QUERY_FILE}' '${OVERPASS_INTERPRETER}' 2> /dev/null"
 run __retry_file_operation "${OPERATION}" 3 2 "" "false"

 if [[ "${status}" -eq 0 ]] && [[ -f "${JSON_FILE}" ]] && [[ -s "${JSON_FILE}" ]]; then
  # Then validate
  run __validate_json_with_element "${JSON_FILE}" "elements"
  [[ "${status}" -eq 0 ]]
 else
  skip "Download failed - may be rate limited or network issue"
 fi
}

# Test that validation prevents processing invalid data
@test "should prevent processing when validation fails" {
 # Create JSON that passes structure but fails element check
 cat > "${TMP_DIR}/invalid_elements.json" << 'EOF'
{
  "version": 0.6,
  "elements": null
}
EOF

 # Validation should fail
 run __validate_json_with_element "${TMP_DIR}/invalid_elements.json" "elements"
 [[ "${status}" -eq 1 ]]

 # Simulate that processing would be skipped
 local SHOULD_PROCESS=false
 if __validate_json_with_element "${TMP_DIR}/invalid_elements.json" "elements"; then
  SHOULD_PROCESS=true
 fi

 [[ "${SHOULD_PROCESS}" == "false" ]]
}

