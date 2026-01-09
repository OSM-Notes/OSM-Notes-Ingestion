#!/usr/bin/env bats

# JSON Validation Advanced Tests
# Tests for advanced JSON validation scenarios and real-world structures
# Author: Andres Gomez (AngocA)
# Version: 2026-01-02

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

 # Create JSON with empty elements array
 cat > "${TEST_DIR}/empty_elements.json" << 'EOF'
{
  "version": 0.6,
  "elements": []
}
EOF
}

teardown() {
 # Clean up temporary files
 rm -rf "${TEST_DIR}"
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
 # Test behavior when jq is not available
 # Strategy: Remove jq from PATH completely and clear bash hash
 local original_path="${PATH}"
 local jq_was_available=false
 local jq_path=""
 local restricted_path=""

 if command -v jq &> /dev/null; then
  jq_was_available=true
  jq_path=$(command -v jq)
  # Get directory where jq is located
  local jq_dir
  jq_dir=$(dirname "${jq_path}")

  # Remove jq from bash hash
  hash -d jq 2> /dev/null || true

  # Build new PATH excluding jq's directory
  restricted_path=""
  IFS=':' read -ra PATH_ARRAY <<< "${PATH}"
  for path_dir in "${PATH_ARRAY[@]}"; do
   if [[ "${path_dir}" != "${jq_dir}" ]] && [[ -n "${path_dir}" ]]; then
    if [[ -z "${restricted_path}" ]]; then
     restricted_path="${path_dir}"
    else
     restricted_path="${restricted_path}:${path_dir}"
    fi
   fi
  done

  # If restricted_path is empty, use a minimal safe PATH
  if [[ -z "${restricted_path}" ]]; then
   restricted_path="/usr/bin:/bin"
  fi

  # Verify jq is no longer available with restricted PATH
  # If jq is still found, temporarily rename it or use a wrapper that fails
  if PATH="${restricted_path}" command -v jq &> /dev/null; then
   # Create a temporary wrapper that simulates jq not being available
   local temp_jq_wrapper="${TEST_DIR}/jq"
   echo '#!/bin/bash' > "${temp_jq_wrapper}"
   echo 'exit 127' >> "${temp_jq_wrapper}"
   chmod +x "${temp_jq_wrapper}"
   # Use the wrapper in PATH
   restricted_path="${TEST_DIR}:${restricted_path}"
  fi
 fi

 # Test that function detects missing jq
 # Use env to ensure PATH is set in the subshell
 # __validate_json_structure will check command -v jq first
 # and should fail because jq is not in PATH
 if [[ "${jq_was_available}" == "true" ]]; then
  # Run with restricted PATH
  PATH="${restricted_path}" run __validate_json_with_element "${TEST_DIR}/osm_valid.json" "elements"
 else
  # jq was not available, test should work as-is
  run __validate_json_with_element "${TEST_DIR}/osm_valid.json" "elements"
 fi
 # Function should return error status
 [[ "${status}" -eq 1 ]]
 # The error should mention jq
 [[ "${output}" == *"jq"* ]]
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
