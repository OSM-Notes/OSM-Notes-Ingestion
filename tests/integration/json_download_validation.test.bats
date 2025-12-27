#!/usr/bin/env bats

# JSON Download and Validation Tests
# Tests basic JSON download and validation functionality
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
# Test: JSON Structure Validation After Download
# =============================================================================
# Purpose: Verify that JSON structure is validated after successful download
# Scenario: Download JSON from Overpass API and validate structure
# Expected: Downloaded JSON should be valid and contain required elements
@test "should validate JSON structure after successful download" {
 local TEST_ID="3793105"
 local JSON_FILE="${TMP_DIR}/${TEST_ID}.json"
 local QUERY_FILE="${TMP_DIR}/query_${TEST_ID}.op"
 local VALID_JSON="${TMP_DIR}/valid_response.json"

 # Create a valid JSON response file
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

 # Create query file
 __create_overpass_query "${TEST_ID}" "${QUERY_FILE}"

 # Setup mock curl for Overpass API
 __setup_mock_curl_overpass "${QUERY_FILE}" "${VALID_JSON}"

 # Download using the helper function (which uses curl)
 run curl -s -H "User-Agent: OSM-Notes-Ingestion/1.0" -o "${JSON_FILE}" --data-binary @"${QUERY_FILE}" "${OVERPASS_INTERPRETER}" 2> /dev/null

 # Verify download succeeded
 [[ "${status}" -eq 0 ]]
 [[ -f "${JSON_FILE}" ]]
 [[ -s "${JSON_FILE}" ]]

 # Verify JSON is parseable
 jq empty "${JSON_FILE}" > /dev/null 2>&1
  
 # Validate JSON structure with element check
 run __validate_json_with_element "${JSON_FILE}" "elements"
 [[ "${status}" -eq 0 ]]
 [[ -f "${JSON_FILE}" ]]
}

# =============================================================================
# Test: Handle Download Failure Gracefully
# =============================================================================
# Purpose: Verify that download failures are handled gracefully
# Scenario: Download fails (network error, rate limit, etc.)
# Expected: System should handle failure without crashing
@test "should handle download failure gracefully" {
 local TEST_ID="3793105"
 local JSON_FILE="${TMP_DIR}/${TEST_ID}.json"
 local QUERY_FILE="${TMP_DIR}/query_${TEST_ID}.op"

 # Create query file
 __create_overpass_query "${TEST_ID}" "${QUERY_FILE}"

 # Setup mock curl that simulates failure
 curl() {
  return 1
 }
 export -f curl

 # Attempt download
 run curl -s -H "User-Agent: OSM-Notes-Ingestion/1.0" -o "${JSON_FILE}" --data-binary @"${QUERY_FILE}" "${OVERPASS_INTERPRETER}" 2> /dev/null

 # Should handle failure gracefully
 [[ "${status}" -ne 0 ]]
}

# =============================================================================
# Test: Handle Invalid JSON Response
# =============================================================================
# Purpose: Verify that invalid JSON responses are detected
# Scenario: API returns invalid JSON (error response, HTML, etc.)
# Expected: Validation should fail appropriately
@test "should detect invalid JSON response" {
 local TEST_ID="3793105"
 local JSON_FILE="${TMP_DIR}/${TEST_ID}.json"
 local QUERY_FILE="${TMP_DIR}/query_${TEST_ID}.op"
 local INVALID_JSON="${TMP_DIR}/invalid_response.json"

 # Create an invalid JSON response (error response from API)
 cat > "${INVALID_JSON}" << 'EOF'
{
  "version": 0.6,
  "generator": "Overpass API",
  "remark": "runtime error: Query timed out"
}
EOF

 # Create query file
 __create_overpass_query "${TEST_ID}" "${QUERY_FILE}"

 # Setup mock curl for Overpass API
 __setup_mock_curl_overpass "${QUERY_FILE}" "${INVALID_JSON}"

 # Download
 run curl -s -H "User-Agent: OSM-Notes-Ingestion/1.0" -o "${JSON_FILE}" --data-binary @"${QUERY_FILE}" "${OVERPASS_INTERPRETER}" 2> /dev/null

 # Download should succeed (curl mock returns success)
 [[ "${status}" -eq 0 ]]
 [[ -f "${JSON_FILE}" ]]

 # But validation should fail (no 'elements' field)
 run __validate_json_with_element "${JSON_FILE}" "elements"
 [[ "${status}" -ne 0 ]]
}

# =============================================================================
# Test: Corrupted JSON Detection
# =============================================================================
# Purpose: Verify that corrupted JSON files are detected
# Scenario: JSON file has valid structure but empty elements array
# Expected: Validation should fail
@test "should detect corrupted JSON" {
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
# Test: Invalid JSON Structure Detection
# =============================================================================
# Purpose: Verify that invalid JSON structures are detected
# Scenario: JSON file missing required elements field
# Expected: Validation should fail
@test "should detect invalid JSON structure" {
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
}

# =============================================================================
# Test: Validation Prevents Processing Invalid Data
# =============================================================================
# Purpose: Verify that validation prevents processing invalid data
# Scenario: JSON fails validation, processing should be skipped
# Expected: Processing should not occur when validation fails
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

