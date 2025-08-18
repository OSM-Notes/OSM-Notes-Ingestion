#!/usr/bin/env bats

# Test file for XML corruption recovery functions
# Author: Andres Gomez
# Version: 2025-08-18

load ../../test_helper

setup() {
  SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
  TEST_OUTPUT_DIR="${SCRIPT_BASE_DIRECTORY}/tests/output"
  mkdir -p "${TEST_OUTPUT_DIR}"
  
  # Source the functions
  source "${SCRIPT_BASE_DIRECTORY}/bin/parallelProcessingFunctions.sh"
  
  # Create test XML files
  create_test_xml_files
}

teardown() {
  # Clean up test files
  rm -rf "${TEST_OUTPUT_DIR}"
}

create_test_xml_files() {
  # Create a valid XML file
  cat > "${TEST_OUTPUT_DIR}/valid.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
<note id="1" lat="40.0" lon="-74.0" created_at="2023-01-01T00:00:00Z">
  <comment action="opened" timestamp="2023-01-01T00:00:00Z">Test note</comment>
</note>
</osm-notes>
EOF

  # Create a corrupted XML file with extra content
  cat > "${TEST_OUTPUT_DIR}/corrupted_extra_content.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
<note id="1" lat="40.0" lon="-74.0" created_at="2023-01-01T00:00:00Z">
  <comment action="opened" timestamp="2023-01-01T00:00:00Z">Test note</comment>
</note>
</osm-notes>
Extra content after closing tag
EOF

  # Create a corrupted XML file with missing closing tag
  cat > "${TEST_OUTPUT_DIR}/corrupted_missing_closing.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
<note id="1" lat="40.0" lon="-74.0" created_at="2023-01-01T00:00:00Z">
  <comment action="opened" timestamp="2023-01-01T00:00:00Z">Test note</comment>
</note>
EOF

  # Create a corrupted XML file with missing XML declaration
  cat > "${TEST_OUTPUT_DIR}/corrupted_missing_declaration.xml" << 'EOF'
<osm-notes>
<note id="1" lat="40.0" lon="-74.0" created_at="2023-01-01T00:00:00Z">
  <comment action="opened" timestamp="2023-01-01T00:00:00Z">Test note</comment>
</note>
</osm-notes>
EOF
}

@test "XML integrity validation passes for valid XML file" {
  local xml_file="${TEST_OUTPUT_DIR}/valid.xml"
  
  run __validate_xml_integrity "${xml_file}" "false"
  
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "XML file integrity validation completed successfully"
}

@test "XML integrity validation detects and recovers from extra content corruption" {
  local xml_file="${TEST_OUTPUT_DIR}/corrupted_extra_content.xml"
  
  run __validate_xml_integrity "${xml_file}" "true"
  
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "XML file successfully recovered and validated"
  
  # Verify the file was actually fixed
  run xmllint --noout "${xml_file}" 2>&1
  [ "$status" -eq 0 ]
}

@test "XML integrity validation detects and recovers from missing closing tag" {
  local xml_file="${TEST_OUTPUT_DIR}/corrupted_missing_closing.xml"
  
  run __validate_xml_integrity "${xml_file}" "true"
  
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "XML file successfully recovered and validated"
  
  # Verify the file was actually fixed
  run xmllint --noout "${xml_file}" 2>&1
  [ "$status" -eq 0 ]
}

@test "XML integrity validation detects and recovers from missing XML declaration" {
  local xml_file="${TEST_OUTPUT_DIR}/corrupted_missing_declaration.xml"
  
  run __validate_xml_integrity "${xml_file}" "true"
  
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "XML file successfully recovered and validated"
  
  # Verify the file was actually fixed
  run xmllint --noout "${xml_file}" 2>&1
  [ "$status" -eq 0 ]
}

@test "Corrupted XML file handler creates backup and attempts recovery" {
  local xml_file="${TEST_OUTPUT_DIR}/corrupted_extra_content.xml"
  local backup_dir="${TEST_OUTPUT_DIR}/backup"
  
  run __handle_corrupted_xml_file "${xml_file}" "${backup_dir}"
  
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "Successfully recovered XML file"
  
  # Verify backup was created
  [ -d "${backup_dir}" ]
  [ "$(find "${backup_dir}" -name "*.corrupted.*" | wc -l)" -eq 1 ]
}

@test "XML corruption recovery preserves original file structure" {
  local xml_file="${TEST_OUTPUT_DIR}/corrupted_extra_content.xml"
  local original_content
  original_content=$(grep -c "<note" "${xml_file}")
  
  run __handle_corrupted_xml_file "${xml_file}"
  
  [ "$status" -eq 0 ]
  
  # Verify the recovered file still has the same note count
  local recovered_content
  recovered_content=$(grep -c "<note" "${xml_file}")
  [ "${recovered_content}" -eq "${original_content}" ]
}
