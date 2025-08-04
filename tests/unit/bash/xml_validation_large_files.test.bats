#!/usr/bin/env bats
# Test XML validation for very large files
# Author: Andres Gomez (AngocA)
# Version: 2025-08-04

# Load test helper
load "${TEST_HELPER}"

# Test setup
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
       <xs:element name="closed_at" type="xs:string" minOccurs="0"/>
       <xs:element name="comments" minOccurs="0">
        <xs:complexType>
         <xs:sequence>
          <xs:element name="comment" maxOccurs="unbounded">
           <xs:complexType>
            <xs:sequence>
             <xs:element name="id" type="xs:integer"/>
             <xs:element name="user" type="xs:string"/>
             <xs:element name="action" type="xs:string"/>
             <xs:element name="text" type="xs:string" minOccurs="0"/>
             <xs:element name="html" type="xs:string" minOccurs="0"/>
             <xs:element name="created_at" type="xs:string"/>
            </xs:sequence>
           </xs:complexType>
          </xs:element>
         </xs:sequence>
        </xs:complexType>
       </xs:element>
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
 <note lat="40.7128" lon="-74.0060">
  <id>${i}</id>
  <lat>40.7128</lat>
  <lon>-74.0060</lon>
  <created_at>2023-01-01T00:00:00Z</created_at>
  <status>open</status>
  <comments>
   <comment>
    <id>${i}1</id>
    <user>testuser</user>
    <action>opened</action>
    <text>Test note ${i}</text>
    <html>Test note ${i}</html>
    <created_at>2023-01-01T00:00:00Z</created_at>
   </comment>
  </comments>
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

@test "validate_xml_structure_only should pass for large valid XML" {
 # Source the script
 source "${BIN_DIR}/process/processPlanetNotes.sh"
 
 # Set up environment variables
 export ETL_VERY_LARGE_FILE_THRESHOLD_MB=1
 export CLEAN=true
 export TMP_DIR="${TMP_DIR}"
 
 # Test structure-only validation
 run __validate_xml_structure_only "${TMP_DIR}/large_test.xml"
 
 # Verify success
 [[ "${status}" -eq 0 ]]
 [[ "${output}" == *"Found 1000 notes in XML file"* ]]
 [[ "${output}" == *"Structure sample validation passed"* ]]
}

@test "validate_xml_structure_alternative should pass for large valid XML" {
 # Source the script
 source "${BIN_DIR}/process/processPlanetNotes.sh"
 
 # Set up environment variables
 export XMLSCHEMA_PLANET_NOTES="${TMP_DIR}/test_schema.xsd"
 export ETL_XML_SAMPLE_SIZE=5
 export CLEAN=true
 export TMP_DIR="${TMP_DIR}"
 
 # Test alternative validation
 run __validate_xml_structure_alternative "${TMP_DIR}/large_test.xml"
 
 # Verify success
 [[ "${status}" -eq 0 ]]
 [[ "${output}" == *"Found 1000 notes in XML file"* ]]
 [[ "${output}" == *"Sample validation passed"* ]]
}

@test "validate_xml_with_enhanced_error_handling should use structure-only for very large files" {
 # Source the script
 source "${BIN_DIR}/process/processPlanetNotes.sh"
 
 # Set up environment variables
 export ETL_VERY_LARGE_FILE_THRESHOLD_MB=1
 export ETL_LARGE_FILE_THRESHOLD_MB=1
 export CLEAN=true
 export TMP_DIR="${TMP_DIR}"
 
 # Create a very large file by duplicating content
 for i in {1..10}; do
  cat "${TMP_DIR}/large_test.xml" >> "${TMP_DIR}/very_large_test.xml"
 done
 
 # Test enhanced validation
 run __validate_xml_with_enhanced_error_handling "${TMP_DIR}/very_large_test.xml" "${TMP_DIR}/test_schema.xsd"
 
 # Verify success
 [[ "${status}" -eq 0 ]]
 [[ "${output}" == *"Very large XML file detected"* ]]
 [[ "${output}" == *"Structure-only validation succeeded"* ]]
}

@test "validate_xml_with_enhanced_error_handling should handle invalid XML" {
 # Source the script
 source "${BIN_DIR}/process/processPlanetNotes.sh"
 
 # Set up environment variables
 export ETL_VERY_LARGE_FILE_THRESHOLD_MB=1
 export CLEAN=true
 export TMP_DIR="${TMP_DIR}"
 
 # Create invalid XML
 cat > "${TMP_DIR}/invalid.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
 <note>
  <id>1</id>
  <!-- Missing required elements -->
 </note>
</osm-notes>
EOF
 
 # Test validation should fail
 run __validate_xml_with_enhanced_error_handling "${TMP_DIR}/invalid.xml" "${TMP_DIR}/test_schema.xsd"
 
 # Verify failure
 [[ "${status}" -eq 1 ]]
 [[ "${output}" == *"ERROR"* ]]
}

@test "validate_xml_with_enhanced_error_handling should handle missing root element" {
 # Source the script
 source "${BIN_DIR}/process/processPlanetNotes.sh"
 
 # Set up environment variables
 export ETL_VERY_LARGE_FILE_THRESHOLD_MB=1
 export CLEAN=true
 export TMP_DIR="${TMP_DIR}"
 
 # Create XML without root element
 cat > "${TMP_DIR}/no_root.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
 <note>
  <id>1</id>
  <lat>40.7128</lat>
  <lon>-74.0060</lon>
  <created_at>2023-01-01T00:00:00Z</created_at>
  <status>open</status>
 </note>
EOF
 
 # Test validation should fail
 run __validate_xml_with_enhanced_error_handling "${TMP_DIR}/no_root.xml" "${TMP_DIR}/test_schema.xsd"
 
 # Verify failure
 [[ "${status}" -eq 1 ]]
 [[ "${output}" == *"Missing root element"* ]]
}

@test "validate_xml_with_enhanced_error_handling should handle memory constraints" {
 # Source the script
 source "${BIN_DIR}/process/processPlanetNotes.sh"
 
 # Set up environment variables
 export ETL_XML_MEMORY_LIMIT_MB=1
 export ETL_VERY_LARGE_FILE_THRESHOLD_MB=1
 export CLEAN=true
 export TMP_DIR="${TMP_DIR}"
 
 # Test with very low memory limit
 run __validate_xml_with_enhanced_error_handling "${TMP_DIR}/large_test.xml" "${TMP_DIR}/test_schema.xsd"
 
 # Should still succeed with structure-only validation
 [[ "${status}" -eq 0 ]]
 [[ "${output}" == *"Structure-only validation succeeded"* ]]
} 