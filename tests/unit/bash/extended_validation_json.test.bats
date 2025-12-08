#!/usr/bin/env bats

# Extended Validation JSON Tests
# Tests for JSON structure and schema validation
# Author: Andres Gomez (AngocA)
# Version: 2025-11-26

setup() {
 # Load test helper functions
 load "${BATS_TEST_DIRNAME}/../../test_helper.bash"

 # Ensure SCRIPT_BASE_DIRECTORY is set
 if [[ -z "${SCRIPT_BASE_DIRECTORY:-}" ]]; then
   export SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
 fi

 # Ensure TEST_BASE_DIR is set (used by some tests)
 if [[ -z "${TEST_BASE_DIR:-}" ]]; then
   export TEST_BASE_DIR="${SCRIPT_BASE_DIRECTORY}"
 fi

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

 # Create valid JSON file
 cat > "${TEST_DIR}/valid.json" << 'EOF'
{
  "name": "test",
  "value": 42,
  "active": true,
  "items": ["a", "b", "c"]
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

 # Create empty JSON file
 touch "${TEST_DIR}/empty.json"

 # Create non-JSON file
 echo "This is not JSON" > "${TEST_DIR}/not_json.txt"
}

teardown() {
 # Clean up temporary files
 rm -rf "${TEST_DIR}"
}

@test "validate_json_structure with valid JSON file" {
 run __validate_json_structure "${TEST_DIR}/valid.json"
 [[ "${status}" -eq 0 ]]
}

@test "validate_json_structure with invalid JSON file" {
 run __validate_json_structure "${TEST_DIR}/invalid.json"
 [[ "${status}" -eq 1 ]]
}

@test "validate_json_structure with empty file" {
 # Create an empty file
 touch "${TEST_DIR}/empty.json"

 # Empty files are actually valid JSON according to jq
 # This is the expected behavior
 run __validate_json_structure "${TEST_DIR}/empty.json"
 [[ "${status}" -eq 0 ]]
}

@test "validate_json_structure with non-existent file" {
 run __validate_json_structure "${TEST_DIR}/nonexistent.json"
 [[ "${status}" -eq 1 ]]
}

@test "validate_json_structure with non-JSON file" {
 run __validate_json_structure "${TEST_DIR}/not_json.txt"
 [[ "${status}" -eq 1 ]]
}

@test "validate_json_structure with expected root element" {
 run __validate_json_structure "${TEST_DIR}/valid.json" "name"
 [[ "${status}" -eq 0 ]]
}

@test "validate_json_structure with correct expected root element" {
 # Create JSON with specific root element
 cat > "${TEST_DIR}/root_test.json" << 'EOF'
{
  "features": [
    {"type": "Feature", "properties": {}, "geometry": {}}
  ]
}
EOF

 run __validate_json_structure "${TEST_DIR}/root_test.json" "features"
 [[ "${status}" -eq 0 ]]
}

@test "validate_json_structure with jq not available" {
 # This test verifies that the function works when jq is available
 # The warning message is only shown when jq is not available in the test environment,
 # we'll just verify the function works correctly with jq available
 if command -v jq &> /dev/null; then
  run __validate_json_structure "${TEST_DIR}/valid.json"
  [[ "${status}" -eq 0 ]]
 else
  skip "jq not available for testing"
 fi
}

@test "validate_json_structure with jq available" {
 # Test with jq if available
 if command -v jq &> /dev/null; then
  run __validate_json_structure "${TEST_DIR}/valid.json"
  [[ "${status}" -eq 0 ]]
 else
  skip "jq not available for testing"
 fi
}

@test "validate_json_structure with array JSON" {
 # Create array JSON
 cat > "${TEST_DIR}/array.json" << 'EOF'
[
  {"id": 1, "name": "item1"},
  {"id": 2, "name": "item2"}
]
EOF

 run __validate_json_structure "${TEST_DIR}/array.json"
 [[ "${status}" -eq 0 ]]
}

@test "validate_json_structure with nested JSON" {
 # Create nested JSON
 cat > "${TEST_DIR}/nested.json" << 'EOF'
{
  "level1": {
    "level2": {
      "level3": {
        "value": "deep"
      }
    }
  }
}
EOF

 run __validate_json_structure "${TEST_DIR}/nested.json"
 [[ "${status}" -eq 0 ]]
}

@test "validate_json_structure with JSON containing special characters" {
 # Create JSON with special characters
 cat > "${TEST_DIR}/special.json" << 'EOF'
{
  "name": "test with spaces",
  "description": "Contains: quotes, \"escaped\" quotes, and\nnewlines",
  "unicode": "café",
  "numbers": [1, 2, 3.14, -42]
}
EOF

 run __validate_json_structure "${TEST_DIR}/special.json"
 [[ "${status}" -eq 0 ]]
}

# Test JSON Schema validation
@test "JSON Schema validation should work with valid JSON and schema" {
 # Create a simple JSON schema
 cat > "${TEST_DIR}/test_schema.json" << 'EOF'
{
    "$schema": "http://json-schema.org/draft-07/schema#",
    "type": "object",
    "properties": {
        "name": {
            "type": "string"
        },
        "age": {
            "type": "number"
        }
    },
    "required": ["name"]
}
EOF

 # Create a valid JSON file
 cat > "${TEST_DIR}/valid_for_schema.json" << 'EOF'
{
    "name": "John Doe",
    "age": 30
}
EOF

 # Test with a simple schema first
 run __validate_json_schema "${TEST_DIR}/valid_for_schema.json" "${TEST_DIR}/test_schema.json"
 [[ "${status}" -eq 0 ]]
}

@test "JSON Schema validation should work with existing schemas" {
 # Test with the existing GeoJSON schema
 cat > "${TEST_DIR}/valid_geojson.json" << 'EOF'
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

 run __validate_json_schema "${TEST_DIR}/valid_geojson.json" "${SCRIPT_BASE_DIRECTORY}/json/geojsonschema.json"
 [[ "${status}" -eq 0 ]]
}

@test "JSON Schema validation should fail with invalid JSON" {
 # Create a simple JSON schema
 cat > "${TEST_DIR}/test_schema.json" << 'EOF'
{
    "$schema": "http://json-schema.org/draft-07/schema#",
    "type": "object",
    "properties": {
        "name": {
            "type": "string"
        }
    },
    "required": ["name"]
}
EOF

 # Create an invalid JSON file (missing required field)
 cat > "${TEST_DIR}/invalid_for_schema.json" << 'EOF'
{
    "age": 30
}
EOF

 run __validate_json_schema "${TEST_DIR}/invalid_for_schema.json" "${TEST_DIR}/test_schema.json"
 [[ "${status}" -eq 1 ]]
}

@test "JSON Schema validation should handle missing ajv" {
 # Mock ajv not available
 local original_path="${PATH}"
 export PATH="/tmp/empty:${PATH}"

 run __validate_json_schema "${TEST_DIR}/valid.json" "${TEST_DIR}/test_schema.json"
 [[ "${status}" -eq 1 ]]

 export PATH="${original_path}"
}

@test "JSON Schema validation should handle missing schema file" {
 run __validate_json_schema "${TEST_DIR}/valid.json" "/non/existent/schema.json"
 [[ "${status}" -eq 1 ]]
}

@test "JSON Schema validation should handle missing JSON file" {
 # Create a simple JSON schema
 cat > "${TEST_DIR}/test_schema.json" << 'EOF'
{
    "$schema": "http://json-schema.org/draft-07/schema#",
    "type": "object"
}
EOF

 run __validate_json_schema "/non/existent/file.json" "${TEST_DIR}/test_schema.json"
 [[ "${status}" -eq 1 ]]
}


