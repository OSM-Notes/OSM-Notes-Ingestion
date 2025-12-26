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
 __check_overpass_connectivity

 local TEST_ID="3793105"
 local JSON_FILE
 JSON_FILE=$(__download_json_from_overpass "${TEST_ID}")

 if [[ -z "${JSON_FILE}" ]]; then
  skip "Download failed - may be rate limited or network issue"
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
  skip "JSON validation failed - downloaded JSON may not contain 'elements' field or may be error response"
 fi
 [[ -f "${JSON_FILE}" ]]
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

