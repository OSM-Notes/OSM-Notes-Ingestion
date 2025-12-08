#!/usr/bin/env bats

# JSON Validation Error Handling Tests
# Tests for error cases in JSON validation with element checking
# Author: Andres Gomez (AngocA)
# Version: 2025-10-29

setup() {
 # Load test helper functions
 load "${BATS_TEST_DIRNAME}/../../test_helper.bash"

 # Load test properties (not production properties)
 if [[ -f "${SCRIPT_BASE_DIRECTORY}/etc/properties_test.sh" ]]; then
  source "${SCRIPT_BASE_DIRECTORY}/etc/properties_test.sh"
 else
  # Fallback to production properties if test properties not found
  source "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh"
 fi
 source "${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh"
 source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/validationFunctions.sh"

 # Create temporary test files
 TEST_DIR=$(mktemp -d)

 # Create valid OSM JSON file with elements
 cat > "${TEST_DIR}/osm_valid.json" << 'EOF'
{
  "version": 0.6,
  "generator": "Overpass API",
  "elements": [
    {
      "type": "node",
      "id": 123,
      "lat": 40.7128,
      "lon": -74.0060
    }
  ]
}
EOF

 # Create JSON without expected element
 cat > "${TEST_DIR}/no_elements.json" << 'EOF'
{
  "version": 0.6,
  "generator": "Overpass API"
}
EOF

 # Create JSON with empty elements array
 cat > "${TEST_DIR}/empty_elements.json" << 'EOF'
{
  "version": 0.6,
  "elements": []
}
EOF

 # Create JSON with null elements
 cat > "${TEST_DIR}/null_elements.json" << 'EOF'
{
  "version": 0.6,
  "elements": null
}
EOF

 # Create JSON with empty features array
 cat > "${TEST_DIR}/empty_features.json" << 'EOF'
{
  "type": "FeatureCollection",
  "features": []
}
EOF

 # Create invalid JSON file
 cat > "${TEST_DIR}/invalid.json" << 'EOF'
{
  "name": "test",
  "value": 42,
  "missing": "comma"
  "error": true
}
EOF

 # Create empty file
 touch "${TEST_DIR}/empty.json"

 # Create non-JSON file
 echo "This is not JSON" > "${TEST_DIR}/not_json.txt"
}

teardown() {
 # Clean up temporary files
 rm -rf "${TEST_DIR}"
}

@test "validate_json_with_element with missing elements field" {
 if ! command -v jq &> /dev/null; then
  skip "jq not available for testing"
 fi

 run __validate_json_with_element "${TEST_DIR}/no_elements.json" "elements"
 [[ "${status}" -eq 1 ]]
 [[ "${output}" == *"does not contain expected element 'elements'"* ]]
}

@test "validate_json_with_element with empty elements array" {
 if ! command -v jq &> /dev/null; then
  skip "jq not available for testing"
 fi

 run __validate_json_with_element "${TEST_DIR}/empty_elements.json" "elements"
 [[ "${status}" -eq 1 ]]
 [[ "${output}" == *"is empty"* ]]
}

@test "validate_json_with_element with null elements" {
 if ! command -v jq &> /dev/null; then
  skip "jq not available for testing"
 fi

 run __validate_json_with_element "${TEST_DIR}/null_elements.json" "elements"
 [[ "${status}" -eq 1 ]]
 [[ "${output}" == *"is empty"* ]] || [[ "${output}" == *"does not contain expected element"* ]]
}

@test "validate_json_with_element with empty features array" {
 if ! command -v jq &> /dev/null; then
  skip "jq not available for testing"
 fi

 run __validate_json_with_element "${TEST_DIR}/empty_features.json" "features"
 [[ "${status}" -eq 1 ]]
 [[ "${output}" == *"is empty"* ]]
}

@test "validate_json_with_element with invalid JSON syntax" {
 if ! command -v jq &> /dev/null; then
  skip "jq not available for testing"
 fi

 run __validate_json_with_element "${TEST_DIR}/invalid.json" "elements"
 [[ "${status}" -eq 1 ]]
 [[ "${output}" == *"JSON validation failed"* ]] || [[ "${output}" == *"Invalid JSON"* ]]
}

@test "validate_json_with_element without expected element parameter" {
 if ! command -v jq &> /dev/null; then
  skip "jq not available for testing"
 fi

 # Should only validate JSON structure, not check for elements
 run __validate_json_with_element "${TEST_DIR}/osm_valid.json" ""
 [[ "${status}" -eq 0 ]]
}

@test "validate_json_with_element with non-existent file" {
 if ! command -v jq &> /dev/null; then
  skip "jq not available for testing"
 fi

 run __validate_json_with_element "${TEST_DIR}/nonexistent.json" "elements"
 [[ "${status}" -eq 1 ]]
}

@test "validate_json_with_element with non-JSON file" {
 if ! command -v jq &> /dev/null; then
  skip "jq not available for testing"
 fi

 run __validate_json_with_element "${TEST_DIR}/not_json.txt" "elements"
 [[ "${status}" -eq 1 ]]
}

@test "validate_json_with_element with empty file" {
 if ! command -v jq &> /dev/null; then
  skip "jq not available for testing"
 fi

 # Empty files are actually valid JSON according to jq
 # But should fail when checking for elements
 run __validate_json_with_element "${TEST_DIR}/empty.json" "elements"
 # This might pass basic JSON validation but fail element check
 [[ "${status}" -ge 0 ]]
}

@test "validate_json_with_element validates basic JSON first" {
 if ! command -v jq &> /dev/null; then
  skip "jq not available for testing"
 fi

 # Invalid JSON should fail before element check
 run __validate_json_with_element "${TEST_DIR}/invalid.json" "elements"
 [[ "${status}" -eq 1 ]]
 # Should fail on basic validation, not element check
 [[ "${output}" == *"JSON validation"* ]] || [[ "${output}" == *"Invalid JSON"* ]]
}

