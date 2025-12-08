#!/usr/bin/env bats

# JSON Validation Basic Tests
# Tests for basic JSON validation with element checking
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

