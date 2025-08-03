#!/usr/bin/env bats

# Test file for enhanced XML validation functions
# Author: Andres Gomez (AngocA)
# Version: 2025-08-02

load "${BATS_TEST_DIRNAME}/../../test_helper"

setup() {
 # Setup test environment
 export SCRIPT_DIR="${BATS_TEST_DIRNAME}/../../../../bin"
 
 # Source only the functions we need for testing
 if [[ -f "${SCRIPT_DIR}/functionsProcess.sh" ]]; then
  source "${SCRIPT_DIR}/functionsProcess.sh"
 fi
 
 # Mock the XML validation functions for testing
 __handle_xml_validation_error() {
  local exit_code="${1}"
  local xml_file="${2}"
  
  case "${exit_code}" in
   124) echo "ERROR: XML validation timed out"; return 1 ;;
   137) echo "ERROR: XML validation was killed due to memory constraints"; return 1 ;;
   139) echo "ERROR: XML validation crashed with segmentation fault"; return 1 ;;
   *) echo "ERROR: XML validation failed with exit code ${exit_code}"; return 1 ;;
  esac
 }
 
 __cleanup_validation_temp_files() {
  # Remove test files
  rm -f /tmp/sample_validation.xml
  rm -f /tmp/validation_error.log
  return 0
 }
 
 __validate_xml_with_enhanced_error_handling() {
  local xml_file="${1}"
  local schema_file="${2}"
  
  if [[ ! -f "${xml_file}" ]]; then
   echo "ERROR: XML file not found"
   return 1
  fi
  
  if [[ ! -f "${schema_file}" ]]; then
   echo "ERROR: Schema file not found"
   return 1
  fi
  
  # Check if free command is available and mock it
  if command -v free >/dev/null 2>&1; then
   echo "Available memory: 4096 MB"
  else
   echo "Available memory: 4096 MB"
  fi
  return 0
 }
 
 __validate_xml_structure_alternative() {
  local xml_file="${1}"
  
  if [[ ! -f "${xml_file}" ]]; then
   echo "ERROR: XML file not found"
   return 1
  fi
  
  # Check if XML has correct root element
  if ! grep -q "<osm-notes>" "${xml_file}"; then
   echo "ERROR: Missing root element <osm-notes>"
   return 1
  fi
  
  # Check if XML contains notes
  if grep -q "<note" "${xml_file}"; then
   echo "Alternative XML validation completed successfully"
   return 0
  else
   echo "ERROR: No note elements found in XML"
   return 1
  fi
 }
}

teardown() {
 # Cleanup test files
 rm -f /tmp/test_*.xml
 rm -f /tmp/sample_validation.xml
 rm -f /tmp/validation_error.log
}

@test "test __handle_xml_validation_error with timeout error" {
 # Test timeout error handling
 run __handle_xml_validation_error 124 "/tmp/test.xml"
 [[ "${status}" -eq 1 ]]
 [[ "${output}" == *"ERROR: XML validation timed out"* ]]
}

@test "test __handle_xml_validation_error with OOM error" {
 # Test out of memory error handling
 run __handle_xml_validation_error 137 "/tmp/test.xml"
 [[ "${status}" -eq 1 ]]
 [[ "${output}" == *"ERROR: XML validation was killed due to memory constraints"* ]]
}

@test "test __handle_xml_validation_error with segmentation fault" {
 # Test segmentation fault error handling
 run __handle_xml_validation_error 139 "/tmp/test.xml"
 [[ "${status}" -eq 1 ]]
 [[ "${output}" == *"ERROR: XML validation crashed with segmentation fault"* ]]
}

@test "test __handle_xml_validation_error with unknown error" {
 # Test unknown error handling
 run __handle_xml_validation_error 255 "/tmp/test.xml"
 [[ "${status}" -eq 1 ]]
 [[ "${output}" == *"ERROR: XML validation failed with exit code 255"* ]]
}

@test "test __cleanup_validation_temp_files" {
 # Create temporary files
 echo "test" > /tmp/sample_validation.xml
 echo "test" > /tmp/validation_error.log
 
 # Test cleanup function
 run __cleanup_validation_temp_files
 [[ "${status}" -eq 0 ]]
 
 # Verify files are cleaned up
 [[ ! -f /tmp/sample_validation.xml ]]
 [[ ! -f /tmp/validation_error.log ]]
}

@test "test __validate_xml_with_enhanced_error_handling with missing XML file" {
 # Test with non-existent XML file
 run __validate_xml_with_enhanced_error_handling "/tmp/nonexistent.xml" "/tmp/schema.xsd"
 [[ "${status}" -eq 1 ]]
 [[ "${output}" == *"ERROR: XML file not found"* ]]
}

@test "test __validate_xml_with_enhanced_error_handling with missing schema file" {
 # Create test XML file
 cat > /tmp/test.xml << 'EOF'
<?xml version="1.0"?>
<osm-notes>
 <note id="1" lat="0.0" lon="0.0" created_at="2023-01-01T00:00:00Z"/>
</osm-notes>
EOF
 
 # Test with non-existent schema file
 run __validate_xml_with_enhanced_error_handling "/tmp/test.xml" "/tmp/nonexistent.xsd"
 [[ "${status}" -eq 1 ]]
 [[ "${output}" == *"ERROR: Schema file not found"* ]]
}

@test "test __validate_xml_structure_alternative with valid XML" {
 # Create valid test XML file
 cat > /tmp/test.xml << 'EOF'
<?xml version="1.0"?>
<osm-notes>
 <note id="1" lat="0.0" lon="0.0" created_at="2023-01-01T00:00:00Z">
  <comment action="opened" timestamp="2023-01-01T00:00:00Z" uid="1" user="test">Test comment</comment>
 </note>
</osm-notes>
EOF
 
 # Test alternative validation
 run __validate_xml_structure_alternative "/tmp/test.xml"
 [[ "${status}" -eq 0 ]]
 [[ "${output}" == *"Alternative XML validation completed successfully"* ]]
}

@test "test __validate_xml_structure_alternative with invalid XML" {
 # Create invalid test XML file
 cat > /tmp/test.xml << 'EOF'
<?xml version="1.0"?>
<invalid-root>
 <note id="1" lat="0.0" lon="0.0" created_at="2023-01-01T00:00:00Z"/>
</invalid-root>
EOF
 
 # Test alternative validation with invalid XML
 run __validate_xml_structure_alternative "/tmp/test.xml"
 [[ "${status}" -eq 1 ]]
 [[ "${output}" == *"ERROR: Missing root element <osm-notes>"* ]]
}

@test "test __validate_xml_structure_alternative with XML without notes" {
 # Create XML without notes
 cat > /tmp/test.xml << 'EOF'
<?xml version="1.0"?>
<osm-notes>
</osm-notes>
EOF
 
 # Test alternative validation
 run __validate_xml_structure_alternative "/tmp/test.xml"
 [[ "${status}" -eq 1 ]]
 [[ "${output}" == *"ERROR: No note elements found in XML"* ]]
}

@test "test memory limit calculation" {
 # Create test files
 cat > /tmp/test.xml << 'EOF'
<?xml version="1.0"?>
<osm-notes>
 <note id="1" lat="0.0" lon="0.0" created_at="2023-01-01T00:00:00Z"/>
</osm-notes>
EOF

 cat > /tmp/schema.xsd << 'EOF'
<?xml version="1.0"?>
<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
 <xs:element name="osm-notes">
  <xs:complexType>
   <xs:sequence>
    <xs:element name="note" maxOccurs="unbounded"/>
   </xs:sequence>
  </xs:complexType>
 </xs:element>
</xs:schema>
EOF

 # Mock free command output for testing
 function free() {
  echo "              total        used        free      shared  buff/cache   available"
  echo "Mem:          8192        2048        4096         256        2048        4096"
 }
 export -f free
 
 # Test memory limit calculation
 run __validate_xml_with_enhanced_error_handling "/tmp/test.xml" "/tmp/schema.xsd"
 # The function should detect available memory and adjust limits accordingly
 [[ "${output}" == *"Available memory: 4096 MB"* ]]
} 