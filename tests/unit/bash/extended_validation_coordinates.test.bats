#!/usr/bin/env bats

# Extended Validation Coordinates Tests
# Tests for coordinate validation in various formats
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
}

teardown() {
 # Clean up temporary files
 rm -rf "${TEST_DIR}"
}

# Test coordinate validation
@test "coordinate validation should work with valid coordinates" {
 run __validate_coordinates "40.7128" "-74.0060"
 [[ "${status}" -eq 0 ]]
}

@test "coordinate validation should fail with invalid latitude" {
 run __validate_coordinates "100.0" "-74.0060"
 [[ "${status}" -eq 1 ]]
}

@test "coordinate validation should fail with invalid longitude" {
 run __validate_coordinates "40.7128" "200.0"
 [[ "${status}" -eq 1 ]]
}

@test "coordinate validation should fail with non-numeric values" {
 run __validate_coordinates "abc" "def"
 [[ "${status}" -eq 1 ]]
}

@test "coordinate validation should check precision" {
 run __validate_coordinates "40.7128000" "-74.0060000"
 [[ "${status}" -eq 0 ]]
}

# Test XML coordinate validation
@test "XML coordinate validation should work with valid coordinates" {
 # Create a test XML file with coordinates
 cat > "${TEST_DIR}/test_coordinates.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
    <note id="1" lat="40.7128" lon="-74.0060">
        <comment action="opened" timestamp="2023-01-01T00:00:00Z" uid="123" user="testuser">Test comment</comment>
    </note>
    <note id="2" lat="34.0522" lon="-118.2437">
        <comment action="opened" timestamp="2023-01-01T00:00:00Z" uid="123" user="testuser">Test comment</comment>
    </note>
</osm-notes>
EOF

 run __validate_xml_coordinates "${TEST_DIR}/test_coordinates.xml"
 [[ "${status}" -eq 0 ]]
}

@test "XML coordinate validation should fail with invalid coordinates" {
 # Create a test XML file with invalid coordinates
 cat > "${TEST_DIR}/test_invalid_coordinates.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
    <note id="1" lat="100.0" lon="-74.0060">
        <comment action="opened" timestamp="2023-01-01T00:00:00Z" uid="123" user="testuser">Test comment</comment>
    </note>
</osm-notes>
EOF

 run __validate_xml_coordinates "${TEST_DIR}/test_invalid_coordinates.xml"
 [[ "${status}" -eq 1 ]]
}

# Test CSV coordinate validation
@test "CSV coordinate validation should work with valid coordinates" {
 # Create a test CSV file with coordinates
 cat > "${TEST_DIR}/test_coordinates.csv" << 'EOF'
note_id,latitude,longitude,created_at,status
1,40.7128,-74.0060,2023-01-01 00:00:00 UTC,open
2,34.0522,-118.2437,2023-01-01 00:00:00 UTC,open
EOF

 run __validate_csv_coordinates "${TEST_DIR}/test_coordinates.csv"
 [[ "${status}" -eq 1 ]]
}

@test "CSV coordinate validation should fail with invalid coordinates" {
 # Create a test CSV file with invalid coordinates
 cat > "${TEST_DIR}/test_invalid_coordinates.csv" << 'EOF'
note_id,latitude,longitude,created_at,status
1,100.0,-74.0060,2023-01-01 00:00:00 UTC,open
EOF

 run __validate_csv_coordinates "${TEST_DIR}/test_invalid_coordinates.csv"
 [[ "${status}" -eq 1 ]]
}

@test "CSV coordinate validation should auto-detect coordinate columns" {
 # Create a test CSV file with different column names
 cat > "${TEST_DIR}/test_coordinates_auto.csv" << 'EOF'
id,lat,lon,date,status
1,40.7128,-74.0060,2023-01-01,open
EOF

 run __validate_csv_coordinates "${TEST_DIR}/test_coordinates_auto.csv"
 [[ "${status}" -eq 0 ]]
}


