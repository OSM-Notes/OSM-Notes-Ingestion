#!/usr/bin/env bats
# Input Validation Tests
# Tests for the input validation functions in functionsProcess.sh
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-27

setup() {
  # Load test helper functions
  load "${BATS_TEST_DIRNAME}/../../test_helper.bash"
  
  # Functions are loaded by test_helper.bash
  
  # Create temporary test files
  TEST_DIR=$(mktemp -d)
  VALID_SQL_FILE="${TEST_DIR}/valid.sql"
  INVALID_SQL_FILE="${TEST_DIR}/invalid.sql"
  VALID_XML_FILE="${TEST_DIR}/valid.xml"
  INVALID_XML_FILE="${TEST_DIR}/invalid.xml"
  VALID_CSV_FILE="${TEST_DIR}/valid.csv"
  INVALID_CSV_FILE="${TEST_DIR}/invalid.csv"
  VALID_CONFIG_FILE="${TEST_DIR}/valid.config"
  INVALID_CONFIG_FILE="${TEST_DIR}/invalid.config"
  
  # Create valid SQL file
  cat > "${VALID_SQL_FILE}" << 'EOF'
CREATE TABLE test_table (
  id INTEGER PRIMARY KEY,
  name VARCHAR(100)
);
INSERT INTO test_table VALUES (1, 'test');
EOF

  # Create invalid SQL file (empty)
  touch "${INVALID_SQL_FILE}"

  # Create valid XML file
  cat > "${VALID_XML_FILE}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
  <note id="1" lat="40.7128" lon="-74.0060">
    <comment action="opened" timestamp="2023-01-01T10:00:00Z" uid="123" user="testuser">
      <text>Test note</text>
    </comment>
  </note>
</osm-notes>
EOF

  # Create invalid XML file
  cat > "${INVALID_XML_FILE}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
  <note id="1" lat="40.7128" lon="-74.0060">
    <comment action="opened" timestamp="2023-01-01T10:00:00Z" uid="123" user="testuser">
      <text>Test note
    </comment>
  </note>
</osm-notes>
EOF

  # Create valid CSV file
  cat > "${VALID_CSV_FILE}" << 'EOF'
id,name,value
1,test1,100
2,test2,200
EOF

  # Create invalid CSV file (empty)
  touch "${INVALID_CSV_FILE}"

  # Create valid config file
  cat > "${VALID_CONFIG_FILE}" << 'EOF'
DBNAME=test_db
 DB_USER=test_user
DBPASSWORD=test_pass
MAX_THREADS=4
EOF

  # Create invalid config file
  cat > "${INVALID_CONFIG_FILE}" << 'EOF'
# This is a comment
invalid line
another invalid line
EOF
}

teardown() {
  # Clean up test files
  rm -rf "${TEST_DIR}"
}

@test "Input validation: should validate existing file successfully" {
  run __validate_input_file "${VALID_SQL_FILE}" "Test SQL file"
  [ "$status" -eq 0 ]
  [[ "$output" == *"validation passed"* ]]
}

@test "Input validation: should fail for non-existent file" {
  run __validate_input_file "/non/existent/file" "Non-existent file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"File does not exist"* ]]
}

@test "Input validation: should fail for empty file path" {
  run __validate_input_file "" "Empty file path"
  [ "$status" -eq 1 ]
  [[ "$output" == *"path is empty"* ]]
}

@test "Input validation: should validate directory successfully" {
  run __validate_input_file "${TEST_DIR}" "Test directory" "dir"
  [ "$status" -eq 0 ]
  [[ "$output" == *"validation passed"* ]]
}

@test "Input validation: should fail for file when expecting directory" {
  run __validate_input_file "${VALID_SQL_FILE}" "File as directory" "dir"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Path is not a directory"* ]]
}

@test "SQL validation: should validate valid SQL file successfully" {
  run __validate_sql_structure "${VALID_SQL_FILE}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"SQL structure validation passed"* ]]
}

@test "SQL validation: should fail for empty SQL file" {
  run __validate_sql_structure "${INVALID_SQL_FILE}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"SQL file is empty"* ]]
}

@test "SQL validation: should fail for non-existent SQL file" {
  run __validate_sql_structure "/non/existent/file.sql"
  [ "$status" -eq 1 ]
  [[ "$output" == *"SQL file"* ]]
}

@test "XML validation: should validate valid XML file successfully" {
  run __validate_xml_structure "${VALID_XML_FILE}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"XML structure validation passed"* ]]
}

@test "XML validation: should validate XML with expected root element" {
  run __validate_xml_structure "${VALID_XML_FILE}" "osm-notes"
  [ "$status" -eq 0 ]
  [[ "$output" == *"XML structure validation passed"* ]]
}

@test "XML validation: should fail for invalid XML syntax" {
  run __validate_xml_structure "${INVALID_XML_FILE}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid XML syntax"* ]]
}

@test "XML validation: should fail for wrong root element" {
  run __validate_xml_structure "${VALID_XML_FILE}" "wrong-root"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Expected root element"* ]]
}

@test "CSV validation: should validate valid CSV file successfully" {
  run __validate_csv_structure "${VALID_CSV_FILE}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"CSV structure validation passed"* ]]
}

@test "CSV validation: should validate CSV with expected column count" {
  run __validate_csv_structure "${VALID_CSV_FILE}" "3"
  [ "$status" -eq 0 ]
  [[ "$output" == *"CSV structure validation passed"* ]]
}

@test "CSV validation: should fail for empty CSV file" {
  run __validate_csv_structure "${INVALID_CSV_FILE}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"CSV file is empty"* ]]
}

@test "CSV validation: should fail for wrong column count" {
  run __validate_csv_structure "${VALID_CSV_FILE}" "5"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Expected 5 columns, got 3"* ]]
}

@test "Config validation: should validate valid config file successfully" {
  run __validate_config_file "${VALID_CONFIG_FILE}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Configuration file validation passed"* ]]
}

@test "Config validation: should fail for invalid config file" {
  run __validate_config_file "${INVALID_CONFIG_FILE}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Configuration file validation failed"* ]]
}

@test "Multiple file validation: should validate multiple files successfully" {
  run __validate_input_files "${VALID_SQL_FILE}" "${VALID_XML_FILE}" "${VALID_CSV_FILE}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"All input files validation passed"* ]]
}

@test "Multiple file validation: should fail when any file is invalid" {
  run __validate_input_files "${VALID_SQL_FILE}" "/non/existent/file" "${VALID_CSV_FILE}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Some input files validation failed"* ]]
}