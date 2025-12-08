#!/usr/bin/env bats

# JSON Validation Integration Tests
# Tests for integration scenarios in JSON validation workflow
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
    },
    {
      "type": "relation",
      "id": 456
    }
  ]
}
EOF
}

teardown() {
 # Clean up temporary files
 rm -rf "${TEST_DIR}"
}

@test "validate_json_with_element integration with download workflow" {
 if ! command -v jq &> /dev/null; then
  skip "jq not available for testing"
 fi

 # Simulate the workflow: download -> validate
 local JSON_FILE="${TEST_DIR}/downloaded.json"
 cp "${TEST_DIR}/osm_valid.json" "${JSON_FILE}"

 # Validate as would be done after download
 if ! __validate_json_with_element "${JSON_FILE}" "elements"; then
  echo "Validation failed, would retry download"
  rm -f "${JSON_FILE}"
  # Simulate retry
  cp "${TEST_DIR}/osm_valid.json" "${JSON_FILE}"
  __validate_json_with_element "${JSON_FILE}" "elements"
 fi

 # If we get here, validation succeeded
 [[ -f "${JSON_FILE}" ]]
 run __validate_json_with_element "${JSON_FILE}" "elements"
 [[ "${status}" -eq 0 ]]
}

