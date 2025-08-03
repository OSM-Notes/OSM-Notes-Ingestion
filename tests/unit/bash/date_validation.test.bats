#!/usr/bin/env bats

# Test file for date validation functions
# Author: Andres Gomez (AngocA)
# Version: 2025-07-27

load "${BATS_TEST_DIRNAME}/../../test_helper.bash"

setup() {
  # Create temporary test files
  TEST_XML_FILE=$(mktemp)
  TEST_CSV_FILE=$(mktemp)
  
  # Create test XML with valid UTC format dates
  cat > "${TEST_XML_FILE}" << 'EOF'
<?xml version="1.0"?>
<osm-notes>
  <note id="123" lat="40.7128" lon="-74.0060" created_at="2023-01-15 10:30:00 UTC" closed_at="2023-01-20 14:45:00 UTC">
    <comment action="opened" timestamp="2023-01-15 10:30:00 UTC" uid="456" user="testuser">Test comment</comment>
    <comment action="closed" timestamp="2023-01-20 14:45:00 UTC" uid="456" user="testuser">Closing comment</comment>
  </note>
  <note id="124" lat="40.7128" lon="-74.0060" created_at="2023-02-15 10:30:00 UTC">
    <comment action="opened" timestamp="2023-02-15 10:30:00 UTC" uid="457" user="testuser2">Another comment</comment>
  </note>
</osm-notes>
EOF

  # Create test CSV with valid ISO 8601 dates
  cat > "${TEST_CSV_FILE}" << 'EOF'
note_id,created_at,closed_at,status
123,2023-01-15T10:30:00Z,2023-01-20T14:45:00Z,closed
124,2023-02-15T10:30:00Z,,open
125,2023-03-15T10:30:00Z,2023-03-20T14:45:00Z,closed
EOF
}

teardown() {
  # Clean up temporary files
  rm -f "${TEST_XML_FILE}" "${TEST_CSV_FILE}"
}

@test "validate_iso8601_date with valid UTC format" {
  run __validate_iso8601_date "2023-01-15T10:30:00Z"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DEBUG: ISO 8601 date validation passed"* ]]
}

@test "validate_iso8601_date with valid timezone offset format" {
  run __validate_iso8601_date "2023-01-15T10:30:00+05:00"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DEBUG: ISO 8601 date validation passed"* ]]
}

@test "validate_iso8601_date with valid API format" {
  run __validate_iso8601_date "2023-01-15 10:30:00 UTC"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DEBUG: ISO 8601 date validation passed"* ]]
}

@test "validate_iso8601_date with empty string" {
  run __validate_iso8601_date ""
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: Date string is empty"* ]]
}

@test "validate_iso8601_date with invalid format" {
  run __validate_iso8601_date "2023/01/15 10:30:00"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: ISO 8601 date validation failed"* ]]
}

@test "validate_iso8601_date with invalid year" {
  run __validate_iso8601_date "2024-01-15T10:30:00Z"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: ISO 8601 date validation failed"* ]]
}

@test "validate_xml_dates with valid XML file" {
  run __validate_xml_dates "${TEST_XML_FILE}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DEBUG: XML date validation passed"* ]]
}

@test "validate_xml_dates with custom xpath" {
  run __validate_xml_dates "${TEST_XML_FILE}" "//@created_at"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DEBUG: XML date validation passed"* ]]
}

@test "validate_xml_dates with non-existent file" {
  run __validate_xml_dates "/non/existent/file.xml"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: XML file validation failed"* ]]
}

@test "validate_csv_dates with valid CSV file" {
  run __validate_csv_dates "${TEST_CSV_FILE}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DEBUG: CSV date validation passed"* ]]
}

@test "validate_csv_dates with specific column" {
  run __validate_csv_dates "${TEST_CSV_FILE}" "2"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DEBUG: CSV date validation passed"* ]]
}

@test "validate_csv_dates with non-existent file" {
  run __validate_csv_dates "/non/existent/file.csv"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: CSV file validation failed"* ]]
}

@test "validate_csv_dates with CSV without date columns" {
  # Create CSV without date columns
  local temp_csv=$(mktemp)
  echo "id,name,value" > "${temp_csv}"
  echo "1,test,123" >> "${temp_csv}"
  
  run __validate_csv_dates "${temp_csv}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARNING: No date column found in CSV header"* ]]
  
  rm -f "${temp_csv}"
}

@test "validate_iso8601_date with various valid formats" {
  local valid_dates=(
    "2023-01-15T10:30:00Z"
    "2023-01-15T10:30:00+05:00"
    "2023-01-15T10:30:00-05:00"
    "2023-01-15 10:30:00 UTC"
    "2023-12-31T23:59:59Z"
    "2023-06-15T00:00:00+00:00"
    "2020-01-01T00:00:00Z"
    "2022-06-15T12:30:45Z"
  )
  
  for date in "${valid_dates[@]}"; do
    run __validate_iso8601_date "${date}"
    [ "$status" -eq 0 ] || echo "Failed for date: ${date}"
    [[ "$output" == *"DEBUG: ISO 8601 date validation passed"* ]]
  done
}

@test "validate_iso8601_date with various invalid formats" {
  local invalid_dates=(
    "2023/01/15T10:30:00Z"
    "2023-01-15 10:30:00"
    "2023-13-15T10:30:00Z"
    "2023-01-32T10:30:00Z"
    "2023-01-15T25:30:00Z"
    "2023-01-15T10:70:00Z"
    "2024-01-15T10:30:00Z"
    "2019-01-15T10:30:00Z"
    "invalid-date"
    ""
  )
  
  for date in "${invalid_dates[@]}"; do
    run __validate_iso8601_date "${date}"
    [ "$status" -eq 1 ] || echo "Should have failed for date: ${date}"
    [[ "$output" == *"ERROR"* ]]
  done
}