#!/usr/bin/env bats

# Test file for large XML file validation
# Author: Andres Gomez (AngocA)
# Version: 2025-08-07

load "${BATS_TEST_DIRNAME}/../../test_helper"

setup() {
 # Create temporary directory
 export TMP_DIR=$(mktemp -d "${BATS_TMPDIR}/xml_validation_test_XXXXXX")
 
 # Setup test environment
 export SCRIPT_DIR="$(cd "${BATS_TEST_DIRNAME}/../../../bin" && pwd)"
 
 # Source the functions we need for testing
 if [[ -f "${SCRIPT_DIR}/functionsProcess.sh" ]]; then
  source "${SCRIPT_DIR}/functionsProcess.sh"
 fi
 
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
 <note lat="40.7128" lon="-74.0060" id="${i}" created_at="2023-01-01T00:00:00Z" status="open">
  <comment>Test note ${i}</comment>
 </note>
EOF
 done

 echo '</osm-notes>' >> "${TMP_DIR}/large_test.xml"
}

# Test cleanup
teardown() {
 # Clean up temporary files
 if [[ -d "${TMP_DIR}" ]]; then
  rm -rf "${TMP_DIR}"
 fi
}

@test "Functions are available after sourcing" {
 # Check if our functions are available
 [[ $(type -t __validate_xml_structure) == "function" ]]
 [[ $(type -t __validate_xml_dates_lightweight) == "function" ]]
 [[ $(type -t __validate_xml_coordinates) == "function" ]]
}

@test "Check what functions are actually available" {
 # List all functions that start with __validate_xml
 local AVAILABLE_FUNCTIONS
 AVAILABLE_FUNCTIONS=$(declare -F | grep "__validate_xml" | awk '{print $3}' | sort)
 
 echo "Available __validate_xml functions:"
 echo "${AVAILABLE_FUNCTIONS}"
 
 # Check specific functions
 echo "Checking __validate_xml_coordinates: $(type -t __validate_xml_coordinates 2>/dev/null || echo 'NOT FOUND')"
 echo "Checking __validate_xml_structure: $(type -t __validate_xml_structure 2>/dev/null || echo 'NOT FOUND')"
 echo "Checking __validate_xml_dates_lightweight: $(type -t __validate_xml_dates_lightweight 2>/dev/null || echo 'NOT FOUND')"
 
 # At least one should be available
 [[ -n "${AVAILABLE_FUNCTIONS}" ]]
}

@test "XML file structure validation works" {
 # Test basic XML structure validation using our enhanced function
 run __validate_xml_structure "${TMP_DIR}/large_test.xml"
 [[ "${status}" -eq 0 ]]
 [[ "${output}" == *"XML STRUCTURE VALIDATION COMPLETED SUCCESSFULLY"* ]]
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
 # Test enhanced validation function with large file using coordinates validation
 # Create a smaller test file first to debug
 cat > "${TMP_DIR}/small_test.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
 <note lat="40.7128" lon="-74.0060" id="1" created_at="2023-01-01T00:00:00Z" status="open">
  <comment>Test note 1</comment>
 </note>
 <note lat="34.0522" lon="-118.2437" id="2" created_at="2023-01-01T00:00:00Z" status="open">
  <comment>Test note 2</comment>
 </note>
</osm-notes>
EOF

 # Test with smaller file first
 run __validate_xml_coordinates "${TMP_DIR}/small_test.xml"
 echo "Small file test - Status: ${status}, Output: ${output}"
 [[ "${status}" -eq 0 ]]
 
 # Now test with large file
 run __validate_xml_coordinates "${TMP_DIR}/large_test.xml"
 echo "Large file test - Status: ${status}, Output: ${output}"
 
 # Debug: check file size
 local FILE_SIZE
 FILE_SIZE=$(stat -c%s "${TMP_DIR}/large_test.xml" 2>/dev/null || echo "unknown")
 echo "Large file size: ${FILE_SIZE} bytes"
 
 [[ "${status}" -eq 0 ]]
 [[ "${output}" == *"XML coordinate validation passed"* ]]
}

@test "Structure-only validation works with large files" {
 # Test structure-only validation function
 run __validate_xml_structure "${TMP_DIR}/large_test.xml"
 [[ "${status}" -eq 0 ]]
 [[ "${output}" == *"XML STRUCTURE VALIDATION COMPLETED SUCCESSFULLY"* ]]
}

@test "Large file threshold configuration is respected" {
 # Test that the configuration parameter is available
 if [[ -f "${BATS_TEST_DIRNAME}/../../../etc/etl.properties" ]]; then
  source "${BATS_TEST_DIRNAME}/../../../etc/etl.properties"
  [[ -n "${ETL_LARGE_FILE_THRESHOLD_MB:-}" ]]
  [[ "${ETL_LARGE_FILE_THRESHOLD_MB}" -gt 0 ]]
 else
  skip "etl.properties file not found"
 fi
}

@test "Very large file threshold configuration is available" {
 # Test that very large file threshold configuration is available
 if [[ -f "${BATS_TEST_DIRNAME}/../../../etc/etl.properties" ]]; then
  source "${BATS_TEST_DIRNAME}/../../../etc/etl.properties"
  [[ -n "${ETL_VERY_LARGE_FILE_THRESHOLD_MB:-}" ]]
  [[ "${ETL_VERY_LARGE_FILE_THRESHOLD_MB}" -gt 0 ]]
 else
  skip "etl.properties file not found"
 fi
}

@test "Memory limit configuration is available" {
 # Test that memory limit configuration is available
 if [[ -f "${BATS_TEST_DIRNAME}/../../../etc/etl.properties" ]]; then
  source "${BATS_TEST_DIRNAME}/../../../etc/etl.properties"
  [[ -n "${ETL_XML_MEMORY_LIMIT_MB:-}" ]]
  [[ "${ETL_XML_MEMORY_LIMIT_MB}" -gt 0 ]]
 else
  skip "etl.properties file not found"
 fi
}

@test "Timeout configuration is available" {
 # Test that timeout configuration is available
 if [[ -f "${BATS_TEST_DIRNAME}/../../../etc/etl.properties" ]]; then
  source "${BATS_TEST_DIRNAME}/../../../etc/etl.properties"
  [[ -n "${ETL_XML_VALIDATION_TIMEOUT:-}" ]]
  [[ "${ETL_XML_VALIDATION_TIMEOUT}" -gt 0 ]]
 else
  skip "etl.properties file not found"
 fi
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
 run __validate_xml_structure "${TMP_DIR}/large_test.xml"
 [[ "${status}" -eq 0 ]]
 [[ "${output}" == *"XML STRUCTURE VALIDATION COMPLETED SUCCESSFULLY"* ]]
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
 run __validate_xml_coordinates "${TMP_DIR}/large_test.xml"
 [[ "${status}" -eq 0 ]]
 [[ "${output}" == *"Lite coordinate validation passed"* ]]
}

@test "Configuration values are reasonable" {
 # Test that configuration values are reasonable
 if [[ -f "${BATS_TEST_DIRNAME}/../../../etc/etl.properties" ]]; then
  source "${BATS_TEST_DIRNAME}/../../../etc/etl.properties"
  
  # Very large threshold should be greater than large threshold
  [[ "${ETL_VERY_LARGE_FILE_THRESHOLD_MB}" -gt "${ETL_LARGE_FILE_THRESHOLD_MB}" ]]
  
  # Memory limit should be reasonable
  [[ "${ETL_XML_MEMORY_LIMIT_MB}" -ge 512 ]]
  [[ "${ETL_XML_MEMORY_LIMIT_MB}" -le 8192 ]]
  
  # Timeout should be reasonable
  [[ "${ETL_XML_VALIDATION_TIMEOUT}" -ge 60 ]]
  [[ "${ETL_XML_VALIDATION_TIMEOUT}" -le 3600 ]]
 else
  skip "etl.properties file not found"
 fi
} 

@test "Debug coordinate validation output" {
 # Create a simple test XML file
 cat > "${TMP_DIR}/debug_test.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
 <note lat="40.7128" lon="-74.0060" id="1" created_at="2023-01-01T00:00:00Z" status="open">
  <comment>Test note 1</comment>
 </note>
 <note lat="34.0522" lon="-118.2437" id="2" created_at="2023-01-01T00:00:00Z" status="open">
  <comment>Test note 2</comment>
 </note>
</osm-notes>
EOF

 # Test coordinate validation and capture output
 run __validate_xml_coordinates "${TMP_DIR}/debug_test.xml"
 
 # Show output in test result
 echo "Status: ${status}"
 echo "Output: ${output}"
 
 # Just check that it doesn't fail
 [[ "${status}" -eq 0 ]]
} 

@test "Test XML splitting without xmlstarlet" {
 # Create a simple test XML file with multiple notes
 cat > "${TMP_DIR}/test_splitting.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
 <note lat="40.7128" lon="-74.0060" id="1" created_at="2023-01-01T00:00:00Z" status="open">
  <comment>Test note 1</comment>
 </note>
 <note lat="34.0522" lon="-118.2437" id="2" created_at="2023-01-01T00:00:00Z" status="open">
  <comment>Test note 2</comment>
 </note>
 <note lat="51.5074" lon="-0.1278" id="3" created_at="2023-01-01T00:00:00Z" status="open">
  <comment>Test note 3</comment>
 </note>
</osm-notes>
EOF

 # Test that we can find note lines
 local NOTE_LINES
 NOTE_LINES=$(grep -n '<note' "${TMP_DIR}/test_splitting.xml" | cut -d: -f1)
 
 echo "Note lines found: ${NOTE_LINES}"
 
 # Should find 3 note lines
 local NOTE_COUNT
 NOTE_COUNT=$(echo "${NOTE_LINES}" | wc -l)
 [[ "${NOTE_COUNT}" -eq 3 ]]
 
 # Test that we can extract a range
 local START_LINE=$(echo "${NOTE_LINES}" | head -1)
 local END_LINE=$(echo "${NOTE_LINES}" | tail -1)
 
 echo "Start line: ${START_LINE}, End line: ${END_LINE}"
 
 # Extract range and verify
 local EXTRACTED_CONTENT
 EXTRACTED_CONTENT=$(sed -n "${START_LINE},${END_LINE}p" "${TMP_DIR}/test_splitting.xml")
 
 echo "Extracted content length: ${#EXTRACTED_CONTENT}"
 [[ -n "${EXTRACTED_CONTENT}" ]]
} 

@test "Test __validate_xml_coordinates function directly" {
 # Create a simple test XML file
 cat > "${TMP_DIR}/simple_test.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
 <note lat="40.7128" lon="-74.0060" id="1" created_at="2023-01-01T00:00:00Z" status="open">
  <comment>Test note 1</comment>
 </note>
 <note lat="34.0522" lon="-118.2437" id="2" created_at="2023-01-01T00:00:00Z" status="open">
  <comment>Test note 2</comment>
 </note>
</osm-notes>
EOF

 # Test the function directly
 run __validate_xml_coordinates "${TMP_DIR}/simple_test.xml"
 
 echo "Function status: ${status}"
 echo "Function output: '${output}'"
 
 # Check that the function executed successfully
 [[ "${status}" -eq 0 ]]
 
 # Check that it generated some output
 [[ -n "${output}" ]]
} 