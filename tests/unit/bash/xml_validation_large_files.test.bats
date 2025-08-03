#!/usr/bin/env bats

# Test XML validation for large files
# Author: Andres Gomez (AngocA)
# Version: 2025-08-03

load "${BATS_TEST_DIRNAME}/../../test_helper"

setup() {
 # Load properties
 source "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh"
 source "${SCRIPT_BASE_DIRECTORY}/etc/etl.properties"
 
 # Create test directory
 export TMP_DIR="$(mktemp -d)"
 TEST_DIR=$(mktemp -d "${TMP_DIR}/xml_validation_test_XXXXXX")
 export TEST_DIR
 
 # Create large XML test file
 create_large_test_xml
}

teardown() {
 # Cleanup test files
 if [[ -d "${TEST_DIR}" ]]; then
  rm -rf "${TEST_DIR}"
 fi
 if [[ -d "${TMP_DIR}" ]]; then
  rm -rf "${TMP_DIR}"
 fi
}

# Create a large XML test file for validation testing
create_large_test_xml() {
 local XML_FILE="${TEST_DIR}/large_test.xml"
 local NOTE_COUNT=1000
 
 # Create XML header
 cat > "${XML_FILE}" << 'EOF'
<?xml version="1.0"?>
<osm-notes>
EOF

 # Generate test notes
 for i in $(seq 1 "${NOTE_COUNT}"); do
  cat >> "${XML_FILE}" << EOF
  <note id="${i}" lat="40.4168" lon="-3.7038" created_at="2023-01-01T00:00:00Z">
   <comment action="opened" timestamp="2023-01-01T00:00:00Z" uid="1" user="testuser">Test comment ${i}</comment>
  </note>
EOF
 done
 
 # Close XML
 echo '</osm-notes>' >> "${XML_FILE}"
 
 export TEST_XML_FILE="${XML_FILE}"
}

@test "Basic XML structure validation works" {
 # Test basic XML validation with xmllint
 run xmllint --noout --nonet "${TEST_XML_FILE}"
 [ "${status}" -eq 0 ]
}

@test "XML contains expected elements" {
 # Test that XML contains required elements
 run grep -q "<osm-notes>" "${TEST_XML_FILE}"
 [ "${status}" -eq 0 ]
 
 run grep -q "<note" "${TEST_XML_FILE}"
 [ "${status}" -eq 0 ]
 
 run grep -q "<comment" "${TEST_XML_FILE}"
 [ "${status}" -eq 0 ]
}

@test "XML note count is correct" {
 # Test that we have the expected number of notes
 local NOTE_COUNT
 NOTE_COUNT=$(grep -c "<note" "${TEST_XML_FILE}")
 [ "${NOTE_COUNT}" -eq 1000 ]
}

@test "XML validation against schema works" {
 # Load properties to get schema path
 source "${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh"
 
 # Test validation against the planet schema
 run xmllint --noout --schema "${XMLSCHEMA_PLANET_NOTES}" "${TEST_XML_FILE}"
 [ "${status}" -eq 0 ]
}

@test "Large file threshold configuration is respected" {
 # Test that the configuration parameter is available
 [[ -n "${ETL_LARGE_FILE_THRESHOLD_MB:-}" ]]
 [[ "${ETL_LARGE_FILE_THRESHOLD_MB}" -gt 0 ]]
}

@test "Memory limit configuration is available" {
 # Test that memory limit configuration is available
 [[ -n "${ETL_XML_MEMORY_LIMIT_MB:-}" ]]
 [[ "${ETL_XML_MEMORY_LIMIT_MB}" -gt 0 ]]
}

@test "Timeout configuration is available" {
 # Test that timeout configuration is available
 [[ -n "${ETL_XML_VALIDATION_TIMEOUT:-}" ]]
 [[ "${ETL_XML_VALIDATION_TIMEOUT}" -gt 0 ]]
}

@test "Batch size configuration is available" {
 # Test that batch size configuration is available
 [[ -n "${ETL_XML_BATCH_SIZE:-}" ]]
 [[ "${ETL_XML_BATCH_SIZE}" -gt 0 ]]
}

@test "Sample size configuration is available" {
 # Test that sample size configuration is available
 [[ -n "${ETL_XML_SAMPLE_SIZE:-}" ]]
 [[ "${ETL_XML_SAMPLE_SIZE}" -gt 0 ]]
} 