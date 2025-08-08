#!/usr/bin/env bats

# Test file for large XML file validation
# Author: Andres Gomez (AngocA)
# Version: 2025-08-07

load "${BATS_TEST_DIRNAME}/../../test_helper"

setup() {
 # Create temporary directory
 export TMP_DIR=$(mktemp -d "${BATS_TMPDIR}/xml_validation_test_XXXXXX")
 
 # Create mock schema file
 cat > "${TMP_DIR}/test_schema.xsd" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
 <xs:element name="osm-notes">
  <xs:complexType>
   <xs:sequence>
    <xs:element name="note" maxOccurs="unbounded">
     <xs:complexType>
      <xs:sequence>
       <xs:element name="id" type="xs:integer"/>
       <xs:element name="lat" type="xs:decimal"/>
       <xs:element name="lon" type="xs:decimal"/>
       <xs:element name="created_at" type="xs:string"/>
       <xs:element name="status" type="xs:string"/>
      </xs:sequence>
     </xs:complexType>
    </xs:element>
   </xs:sequence>
  </xs:complexType>
 </xs:element>
</xs:schema>
EOF

 # Create large XML file for testing
 cat > "${TMP_DIR}/large_test.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
EOF

 # Generate many notes to simulate large file
 for i in {1..1000}; do
  cat >> "${TMP_DIR}/large_test.xml" << EOF
 <note>
  <id>${i}</id>
  <lat>40.7128</lat>
  <lon>-74.0060</lon>
  <created_at>2023-01-01T00:00:00Z</created_at>
  <status>open</status>
 </note>
EOF
 done

 echo '</osm-notes>' >> "${TMP_DIR}/large_test.xml"
 
 # Source the functions we need for testing
 if [[ -f "${BATS_TEST_DIRNAME}/../../../../bin/functionsProcess.sh" ]]; then
  source "${BATS_TEST_DIRNAME}/../../../../bin/functionsProcess.sh"
 fi
}

# Test cleanup
teardown() {
 # Clean up temporary files
 if [[ -d "${TMP_DIR}" ]]; then
  rm -rf "${TMP_DIR}"
 fi
}

@test "XML file structure validation works" {
 # Test basic XML structure validation using our enhanced function
 run __validate_xml_basic "${TMP_DIR}/large_test.xml"
 [[ "${status}" -eq 0 ]]
 [[ "${output}" == *"Basic XML validation passed"* ]]
}

@test "XML contains expected elements" {
 # Test that XML contains required elements
 run grep -q "<osm-notes>" "${TMP_DIR}/large_test.xml"
 [[ "${status}" -eq 0 ]]
 
 run grep -q "<note" "${TMP_DIR}/large_test.xml"
 [[ "${status}" -eq 0 ]]
}

@test "XML note count is correct" {
 # Test that we have the expected number of notes
 local NOTE_COUNT
 NOTE_COUNT=$(grep -c "<note" "${TMP_DIR}/large_test.xml")
 [[ "${NOTE_COUNT}" -eq 1000 ]]
}

@test "Enhanced XML validation works with large files" {
 # Test enhanced validation function with large file
 run __validate_xml_with_enhanced_error_handling "${TMP_DIR}/large_test.xml" "${TMP_DIR}/test_schema.xsd"
 [[ "${status}" -eq 0 ]]
 [[ "${output}" == *"XML validation succeeded"* ]]
}

@test "Structure-only validation works with large files" {
 # Test structure-only validation function
 run __validate_xml_structure_only "${TMP_DIR}/large_test.xml"
 [[ "${status}" -eq 0 ]]
 [[ "${output}" == *"Structure-only validation passed for very large file"* ]]
}

@test "Large file threshold configuration is respected" {
 # Test that the configuration parameter is available
 source "${BATS_TEST_DIRNAME}/../../../etc/etl.properties"
 [[ -n "${ETL_LARGE_FILE_THRESHOLD_MB:-}" ]]
 [[ "${ETL_LARGE_FILE_THRESHOLD_MB}" -gt 0 ]]
}

@test "Very large file threshold configuration is available" {
 # Test that very large file threshold configuration is available
 source "${BATS_TEST_DIRNAME}/../../../etc/etl.properties"
 [[ -n "${ETL_VERY_LARGE_FILE_THRESHOLD_MB:-}" ]]
 [[ "${ETL_VERY_LARGE_FILE_THRESHOLD_MB}" -gt 0 ]]
}

@test "Memory limit configuration is available" {
 # Test that memory limit configuration is available
 source "${BATS_TEST_DIRNAME}/../../../etc/etl.properties"
 [[ -n "${ETL_XML_MEMORY_LIMIT_MB:-}" ]]
 [[ "${ETL_XML_MEMORY_LIMIT_MB}" -gt 0 ]]
}

@test "Timeout configuration is available" {
 # Test that timeout configuration is available
 source "${BATS_TEST_DIRNAME}/../../../etc/etl.properties"
 [[ -n "${ETL_XML_VALIDATION_TIMEOUT:-}" ]]
 [[ "${ETL_XML_VALIDATION_TIMEOUT}" -gt 0 ]]
}

@test "File size detection works" {
 # Test file size calculation
 local FILE_SIZE
 FILE_SIZE=$(stat -c%s "${TMP_DIR}/large_test.xml")
 local SIZE_MB=$((FILE_SIZE / 1024 / 1024))
 # For small test files, size might be 0 MB but should be > 0 bytes
 [[ "${FILE_SIZE}" -gt 0 ]]
}

@test "Memory detection works" {
 # Test available memory detection
 local AVAILABLE_MEMORY_MB
 AVAILABLE_MEMORY_MB=$(free -m | awk 'NR==2{printf "%.0f", $7}')
 [[ "${AVAILABLE_MEMORY_MB}" -gt 0 ]]
}

@test "XML structure validation handles large files" {
 # Test that basic XML structure validation works for large files
 run __validate_xml_basic "${TMP_DIR}/large_test.xml"
 [[ "${status}" -eq 0 ]]
 [[ "${output}" == *"Basic XML validation passed"* ]]
}

@test "Enhanced validation handles different file sizes" {
 # Test enhanced validation with different file sizes (mocked)
 
 # Mock stat function to simulate different file sizes
 function stat() {
  if [[ "$*" == *"large_test.xml"* ]]; then
   echo "600000000"  # Simulate 600MB file
  else
   command stat "$@"
  fi
 }
 export -f stat
 
 # Test with large file
 run __validate_xml_with_enhanced_error_handling "${TMP_DIR}/large_test.xml" "${TMP_DIR}/test_schema.xsd"
 [[ "${status}" -eq 0 ]]
 [[ "${output}" == *"Basic XML validation succeeded"* ]]
}

@test "Configuration values are reasonable" {
 # Test that configuration values are reasonable
 source "${BATS_TEST_DIRNAME}/../../../etc/etl.properties"
 
 # Very large threshold should be greater than large threshold
 [[ "${ETL_VERY_LARGE_FILE_THRESHOLD_MB}" -gt "${ETL_LARGE_FILE_THRESHOLD_MB}" ]]
 
 # Memory limit should be reasonable
 [[ "${ETL_XML_MEMORY_LIMIT_MB}" -ge 512 ]]
 [[ "${ETL_XML_MEMORY_LIMIT_MB}" -le 8192 ]]
 
 # Timeout should be reasonable
 [[ "${ETL_XML_VALIDATION_TIMEOUT}" -ge 60 ]]
 [[ "${ETL_XML_VALIDATION_TIMEOUT}" -le 3600 ]]
} 