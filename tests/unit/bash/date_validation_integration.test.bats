#!/usr/bin/env bats

# Integration test file for date validation functions
# Author: Andres Gomez (AngocA)
# Version: 2025-07-27

load "${BATS_TEST_DIRNAME}/../../test_helper.bash"

setup() {
  # Set up test environment
  export SCRIPT_BASE_DIRECTORY="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  export BASENAME="test_script"
  export TMP_DIR=$(mktemp -d)
  export LOG_FILENAME="${TMP_DIR}/test.log"
  export LOCK="${TMP_DIR}/test.lock"
  
  # Create test XML files
  TEST_PLANET_XML=$(mktemp)
  TEST_API_XML=$(mktemp)
  
  # Create test planet XML with valid dates
  cat > "${TEST_PLANET_XML}" << 'EOF'
<?xml version="1.0"?>
<osm-notes>
  <note id="123" lat="40.7128" lon="-74.0060" created_at="2023-01-15T10:30:00Z" closed_at="2023-01-20T14:45:00Z">
    <comment action="opened" timestamp="2023-01-15T10:30:00Z" uid="456" user="testuser">Test comment</comment>
  </note>
</osm-notes>
EOF

  # Create test API XML with valid dates
  cat > "${TEST_API_XML}" << 'EOF'
<?xml version="1.0"?>
<osm>
  <note id="123" lat="40.7128" lon="-74.0060">
    <date_created>2023-01-15 10:30:00 UTC</date_created>
    <date_closed>2023-01-20 14:45:00 UTC</date_closed>
    <comments>
      <comment>
        <date>2023-01-15 10:30:00 UTC</date>
        <action>opened</action>
        <text>Test comment</text>
      </comment>
    </comments>
  </note>
</osm>
EOF
}

teardown() {
  # Clean up
  rm -rf "${TMP_DIR}"
  rm -f "${TEST_PLANET_XML}" "${TEST_API_XML}"
}

@test "processPlanetNotes.sh includes date validation" {
  # Check that the script sources functionsProcess.sh
  run grep -q "source.*functionsProcess.sh" "${SCRIPT_BASE_DIRECTORY}/bin/process/processPlanetNotes.sh"
  [ "$status" -eq 0 ]
  
  # Check that the script includes date validation
  run grep -q "__validate_xml_dates" "${SCRIPT_BASE_DIRECTORY}/bin/process/processPlanetNotes.sh"
  [ "$status" -eq 0 ]
}

@test "processAPINotes.sh includes date validation" {
  # Check that the script sources functionsProcess.sh
  run grep -q "source.*functionsProcess.sh" "${SCRIPT_BASE_DIRECTORY}/bin/process/processAPINotes.sh"
  [ "$status" -eq 0 ]
  
  # Check that the script includes date validation
  run grep -q "__validate_xml_dates" "${SCRIPT_BASE_DIRECTORY}/bin/process/processAPINotes.sh"
  [ "$status" -eq 0 ]
}

@test "date validation functions are available in functionsProcess.sh" {
  # Check that the functions exist in functionsProcess.sh
  run grep -q "__validate_iso8601_date" "${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh"
  [ "$status" -eq 0 ]
  
  run grep -q "__validate_xml_dates" "${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh"
  [ "$status" -eq 0 ]
  
  run grep -q "__validate_csv_dates" "${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh"
  [ "$status" -eq 0 ]
}

@test "date validation works with planet XML format" {
  # Source functions and test with planet XML
  source "${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh"
  
  run __validate_xml_dates "${TEST_PLANET_XML}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DEBUG: XML date validation passed"* ]]
}

@test "date validation works with API XML format" {
  # Source functions and test with API XML
  source "${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh"
  
  run __validate_xml_dates "${TEST_API_XML}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DEBUG: XML date validation passed"* ]]
}

@test "date validation fails with invalid dates in XML" {
  # Create XML with invalid dates
  local invalid_xml=$(mktemp)
  cat > "${invalid_xml}" << 'EOF'
<?xml version="1.0"?>
<osm-notes>
  <note id="123" lat="40.7128" lon="-74.0060" created_at="2024-01-15T10:30:00Z">
    <comment action="opened" timestamp="invalid-date" uid="456" user="testuser">Test comment</comment>
  </note>
</osm-notes>
EOF
  
  # Source functions and test with invalid XML
  source "${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh"
  
  run __validate_xml_dates "${invalid_xml}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: XML date validation failed"* ]]
  
  rm -f "${invalid_xml}"
}

@test "date validation integration with CSV files" {
  # Create test CSV with dates
  local test_csv=$(mktemp)
  cat > "${test_csv}" << 'EOF'
note_id,created_at,closed_at,status
123,2023-01-15T10:30:00Z,2023-01-20T14:45:00Z,closed
124,2023-02-15T10:30:00Z,,open
EOF
  
  # Source functions and test CSV validation
  source "${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh"
  
  run __validate_csv_dates "${test_csv}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DEBUG: CSV date validation passed"* ]]
  
  rm -f "${test_csv}"
}