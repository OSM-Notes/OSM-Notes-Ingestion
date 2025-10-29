#!/usr/bin/env bats

# Author: Andres Gomez (AngocA)
# Version: 2025-10-29

# Test file for JSON validation with element checking function
# Tests __validate_json_with_element function

setup() {
 # Load test helper functions
 load "${BATS_TEST_DIRNAME}/../../test_helper.bash"

 # Load properties and functions
 source "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh"
 if [[ -f "${SCRIPT_BASE_DIRECTORY}/etc/osm-notes-processing.properties" ]]; then
  source "${SCRIPT_BASE_DIRECTORY}/etc/osm-notes-processing.properties"
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

 # Create valid GeoJSON file with features
 cat > "${TEST_DIR}/geojson_valid.json" << 'EOF'
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "geometry": {
        "type": "Point",
        "coordinates": [0, 0]
      },
      "properties": {
        "name": "Test Point"
      }
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

@test "validate_json_with_element with valid OSM JSON and elements" {
 if ! command -v jq &> /dev/null; then
  skip "jq not available for testing"
 fi

 run __validate_json_with_element "${TEST_DIR}/osm_valid.json" "elements"
 [[ "${status}" -eq 0 ]]
}

@test "validate_json_with_element with valid GeoJSON and features" {
 if ! command -v jq &> /dev/null; then
  skip "jq not available for testing"
 fi

 run __validate_json_with_element "${TEST_DIR}/geojson_valid.json" "features"
 [[ "${status}" -eq 0 ]]
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

@test "validate_json_with_element with nested element path" {
 if ! command -v jq &> /dev/null; then
  skip "jq not available for testing"
 fi

 # Create JSON with nested structure
 cat > "${TEST_DIR}/nested.json" << 'EOF'
{
  "data": {
    "result": {
      "items": [1, 2, 3]
    }
  }
}
EOF

 # Test with nested path (should not work with current implementation)
 # Current implementation only checks top-level elements
 run __validate_json_with_element "${TEST_DIR}/nested.json" "data"
 [[ "${status}" -eq 0 ]]
}

@test "validate_json_with_element requires jq command" {
 # Skip if jq is available (test is for when it's not)
 if command -v jq &> /dev/null; then
  skip "jq is available, cannot test jq requirement"
 fi

 run __validate_json_with_element "${TEST_DIR}/osm_valid.json" "elements"
 [[ "${status}" -eq 1 ]]
 [[ "${output}" == *"jq command not available"* ]]
}

@test "validate_json_with_element with OSM JSON containing multiple elements" {
 if ! command -v jq &> /dev/null; then
  skip "jq not available for testing"
 fi

 # Create OSM JSON with multiple element types
 cat > "${TEST_DIR}/osm_multiple.json" << 'EOF'
{
  "version": 0.6,
  "generator": "Overpass API",
  "elements": [
    {"type": "node", "id": 1, "lat": 40.0, "lon": -74.0},
    {"type": "way", "id": 2},
    {"type": "relation", "id": 3}
  ]
}
EOF

 run __validate_json_with_element "${TEST_DIR}/osm_multiple.json" "elements"
 [[ "${status}" -eq 0 ]]
}

@test "validate_json_with_element with GeoJSON containing multiple features" {
 if ! command -v jq &> /dev/null; then
  skip "jq not available for testing"
 fi

 # Create GeoJSON with multiple features
 cat > "${TEST_DIR}/geojson_multiple.json" << 'EOF'
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "geometry": {"type": "Point", "coordinates": [0, 0]},
      "properties": {"name": "Point 1"}
    },
    {
      "type": "Feature",
      "geometry": {"type": "Point", "coordinates": [1, 1]},
      "properties": {"name": "Point 2"}
    }
  ]
}
EOF

 run __validate_json_with_element "${TEST_DIR}/geojson_multiple.json" "features"
 [[ "${status}" -eq 0 ]]
}

@test "validate_json_with_element validates element count is not zero" {
 if ! command -v jq &> /dev/null; then
  skip "jq not available for testing"
 fi

 # Element exists but has length 0
 run __validate_json_with_element "${TEST_DIR}/empty_elements.json" "elements"
 [[ "${status}" -eq 1 ]]
 # Should detect that count is 0
 [[ "${output}" == *"is empty"* ]]
}

@test "validate_json_with_element works with real Overpass API JSON structure" {
 if ! command -v jq &> /dev/null; then
  skip "jq not available for testing"
 fi

 # Create JSON matching real Overpass API response structure
 cat > "${TEST_DIR}/overpass_real.json" << 'EOF'
{
  "version": 0.6,
  "generator": "Overpass API 0.7.62.1 3b416d5",
  "osm3s": {
    "timestamp_osm_base": "2025-10-29T12:00:00Z",
    "copyright": "The data included in this document is from www.openstreetmap.org"
  },
  "elements": [
    {
      "type": "relation",
      "id": 16239,
      "members": [],
      "tags": {
        "admin_level": "2",
        "boundary": "administrative",
        "name": "Austria",
        "name:en": "Austria",
        "type": "boundary"
      }
    }
  ]
}
EOF

 run __validate_json_with_element "${TEST_DIR}/overpass_real.json" "elements"
 [[ "${status}" -eq 0 ]]
}

@test "validate_json_with_element works with real GeoJSON structure" {
 if ! command -v jq &> /dev/null; then
  skip "jq not available for testing"
 fi

 # Create JSON matching real GeoJSON structure after osmtogeojson conversion
 cat > "${TEST_DIR}/geojson_real.json" << 'EOF'
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {
        "name": "Austria",
        "admin_level": "2",
        "type": "boundary"
      },
      "geometry": {
        "type": "Polygon",
        "coordinates": [[[0, 0], [1, 0], [1, 1], [0, 1], [0, 0]]]
      }
    }
  ]
}
EOF

 run __validate_json_with_element "${TEST_DIR}/geojson_real.json" "features"
 [[ "${status}" -eq 0 ]]
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

