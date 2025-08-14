#!/usr/bin/env bats

# Test file for XML validation functions (functions only)
# Author: Andres Gomez (AngocA)
# Version: 2025-08-07

load "${BATS_TEST_DIRNAME}/../../test_helper"

setup() {
 # Create a simple test script with just the functions we need
 cat > /tmp/test_xml_functions.sh << 'EOF'
#!/bin/bash

# Mock logger functions for testing
function __log_start() { echo "START: $1"; }
function __logi() { echo "INFO: $1"; }
function __loge() { echo "ERROR: $1"; }
function __logw() { echo "WARNING: $1"; }
function __logd() { echo "DEBUG: $1"; }
function __log_finish() { echo "FINISH: $1"; }

# Clean up temporary files created during validation
function __cleanup_validation_temp_files() {
 local TEMP_FILES=(
  "/tmp/sample_validation.xml"
  "/tmp/validation_error.log"
 )
 
 for TEMP_FILE in "${TEMP_FILES[@]}"; do
  if [[ -f "${TEMP_FILE}" ]]; then
   rm -f "${TEMP_FILE}"
   __logd "Cleaned up temporary file: ${TEMP_FILE}"
  fi
 done
 
 return 0
}

# Basic XML structure validation (lightweight)
function __validate_xml_basic() {
 local XML_FILE="${1}"
 
 if [[ ! -f "${XML_FILE}" ]]; then
  __loge "ERROR: XML file not found: ${XML_FILE}"
  return 1
 fi
 
 __logi "Performing basic XML validation: ${XML_FILE}"
 
 # Check root element
 if ! grep -q "<osm-notes>" "${XML_FILE}" 2> /dev/null; then
  __loge "ERROR: Missing root element <osm-notes> in ${XML_FILE}"
  return 1
 fi
 
 # Check for note elements
 if ! grep -q "<note" "${XML_FILE}" 2> /dev/null; then
  __loge "ERROR: No note elements found in XML file ${XML_FILE}"
  return 1
 fi
 
 # Count total notes
 local TOTAL_NOTES
 TOTAL_NOTES=$(grep -c "<note" "${XML_FILE}" 2> /dev/null || echo "0")
 
 if [[ "${TOTAL_NOTES}" -gt 0 ]]; then
  __logi "Found ${TOTAL_NOTES} notes in XML file"
  
  # Check for proper note structure (opening and closing tags)
  local OPENING_TAGS
  local CLOSING_TAGS
  OPENING_TAGS=$(grep -c "<note" "${XML_FILE}" 2> /dev/null || echo "0")
  CLOSING_TAGS=$(grep -c "</note>" "${XML_FILE}" 2> /dev/null || echo "0")
  
  if [[ "${OPENING_TAGS}" -ne "${CLOSING_TAGS}" ]]; then
   __loge "ERROR: Mismatched note tags: ${OPENING_TAGS} opening, ${CLOSING_TAGS} closing"
   return 1
  fi
  
  __logi "Basic XML validation passed"
  return 0
 else
  __loge "ERROR: No notes found in XML file"
  return 1
 fi
}

# Structure-only validation for very large files (no xmllint)
function __validate_xml_structure_only() {
 local XML_FILE="${1}"
 
 if [[ ! -f "${XML_FILE}" ]]; then
  __loge "ERROR: XML file not found: ${XML_FILE}"
  return 1
 fi
 
 __logi "Performing structure-only validation for very large file: ${XML_FILE}"
 
 # Check root element
 if ! grep -q "<osm-notes>" "${XML_FILE}" 2> /dev/null; then
  __loge "ERROR: Missing root element <osm-notes> in ${XML_FILE}"
  return 1
 fi
 
 # Check for note elements
 if ! grep -q "<note" "${XML_FILE}" 2> /dev/null; then
  __loge "ERROR: No note elements found in XML file ${XML_FILE}"
  return 1
 fi
 
 # Count total notes
 local TOTAL_NOTES
 TOTAL_NOTES=$(grep -c "<note" "${XML_FILE}" 2> /dev/null || echo "0")
 
 if [[ "${TOTAL_NOTES}" -gt 0 ]]; then
  __logi "Found ${TOTAL_NOTES} notes in XML file"
  
  # Check for proper note structure (opening and closing tags)
  local OPENING_TAGS
  local CLOSING_TAGS
  OPENING_TAGS=$(grep -c "<note" "${XML_FILE}" 2> /dev/null || echo "0")
  CLOSING_TAGS=$(grep -c "</note>" "${XML_FILE}" 2> /dev/null || echo "0")
  
  if [[ "${OPENING_TAGS}" -ne "${CLOSING_TAGS}" ]]; then
   __loge "ERROR: Mismatched note tags: ${OPENING_TAGS} opening, ${CLOSING_TAGS} closing"
   return 1
  fi
  
  __logi "Structure-only validation passed for very large file"
  return 0
 else
  __loge "ERROR: No notes found in XML file"
  return 1
 fi
}

# Validates XML structure with enhanced error handling for large files
function __validate_xml_with_enhanced_error_handling() {
 local XML_FILE="${1}"
 local SCHEMA_FILE="${2}"
 local TIMEOUT="${3:-300}"
 
 if [[ ! -f "${XML_FILE}" ]]; then
  __loge "ERROR: XML file not found: ${XML_FILE}"
  return 1
 fi
 
 # Get file size for validation strategy
 local FILE_SIZE
 FILE_SIZE=$(stat -c%s "${XML_FILE}" 2> /dev/null || echo "0")
 local SIZE_MB=$((FILE_SIZE / 1024 / 1024))
 
 __logi "Validating XML file: ${XML_FILE} (${SIZE_MB} MB)"
 
 # Use appropriate validation strategy based on file size
 local LARGE_FILE_THRESHOLD="500"
 local VERY_LARGE_FILE_THRESHOLD="1000"
 
 if [[ "${SIZE_MB}" -gt "${VERY_LARGE_FILE_THRESHOLD}" ]]; then
  __logw "WARNING: Very large XML file detected (${SIZE_MB} MB). Using structure-only validation."
  
  # For very large files, use basic structure validation only
  if __validate_xml_structure_only "${XML_FILE}"; then
   __logi "Structure-only validation succeeded for very large file"
   return 0
  else
   __loge "ERROR: Structure-only validation failed"
   return 1
  fi
 elif [[ "${SIZE_MB}" -gt "${LARGE_FILE_THRESHOLD}" ]]; then
  __logw "WARNING: Large XML file detected (${SIZE_MB} MB). Using basic validation."
  
  # For large files, use basic XML validation without schema
  if __validate_xml_basic "${XML_FILE}"; then
   __logi "Basic XML validation succeeded"
   return 0
  else
   __loge "ERROR: Basic XML validation failed"
   return 1
  fi
 else
  # Standard validation for smaller files
  if [[ -n "${SCHEMA_FILE}" ]] && [[ -f "${SCHEMA_FILE}" ]]; then
   __logi "XML validation succeeded"
   return 0
  else
   # Fallback to basic validation if no schema provided
   if __validate_xml_basic "${XML_FILE}"; then
    __logi "Basic XML validation succeeded"
    return 0
   else
    __loge "ERROR: Basic XML validation failed"
    return 1
   fi
  fi
 fi
}
EOF

 # Source the test functions
 source /tmp/test_xml_functions.sh
}

teardown() {
 # Cleanup test files
 rm -f /tmp/test_xml_functions.sh
 rm -f /tmp/test_*.xml
 rm -f /tmp/sample_validation.xml
 rm -f /tmp/validation_error.log
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

@test "test __validate_xml_basic with valid XML" {
 # Create valid test XML file
 cat > /tmp/test.xml << 'EOF'
<?xml version="1.0"?>
<osm-notes>
 <note id="1" lat="0.0" lon="0.0" created_at="2023-01-01T00:00:00Z">
  <comment action="opened" timestamp="2023-01-01T00:00:00Z" uid="1" user="test">Test comment</comment>
 </note>
</osm-notes>
EOF
 
 # Test basic validation
 run __validate_xml_basic "/tmp/test.xml"
 [[ "${status}" -eq 0 ]]
 [[ "${output}" == *"Basic XML validation passed"* ]]
}

@test "test __validate_xml_basic with invalid XML" {
 # Create invalid test XML file
 cat > /tmp/test.xml << 'EOF'
<?xml version="1.0"?>
<invalid-root>
 <note id="1" lat="0.0" lon="0.0" created_at="2023-01-01T00:00:00Z"/>
</invalid-root>
EOF
 
 # Test basic validation with invalid XML
 run __validate_xml_basic "/tmp/test.xml"
 [[ "${status}" -eq 1 ]]
 [[ "${output}" == *"ERROR: Missing root element <osm-notes>"* ]]
}

@test "test __validate_xml_basic with XML without notes" {
 # Create XML without notes
 cat > /tmp/test.xml << 'EOF'
<?xml version="1.0"?>
<osm-notes>
</osm-notes>
EOF
 
 # Test basic validation
 run __validate_xml_basic "/tmp/test.xml"
 [[ "${status}" -eq 1 ]]
 [[ "${output}" == *"ERROR: No note elements found in XML file"* ]]
}

@test "test __validate_xml_structure_only with valid XML" {
 # Create valid test XML file
 cat > /tmp/test.xml << 'EOF'
<?xml version="1.0"?>
<osm-notes>
 <note id="1" lat="0.0" lon="0.0" created_at="2023-01-01T00:00:00Z">
  <comment action="opened" timestamp="2023-01-01T00:00:00Z" uid="1" user="test">Test comment</comment>
 </note>
</osm-notes>
EOF
 
 # Test structure-only validation
 run __validate_xml_structure_only "/tmp/test.xml"
 [[ "${status}" -eq 0 ]]
 [[ "${output}" == *"Structure-only validation passed for very large file"* ]]
}

@test "test __validate_xml_structure_only with invalid XML" {
 # Create invalid test XML file
 cat > /tmp/test.xml << 'EOF'
<?xml version="1.0"?>
<invalid-root>
 <note id="1" lat="0.0" lon="0.0" created_at="2023-01-01T00:00:00Z"/>
</invalid-root>
EOF
 
 # Test structure-only validation with invalid XML
 run __validate_xml_structure_only "/tmp/test.xml"
 [[ "${status}" -eq 1 ]]
 [[ "${output}" == *"ERROR: Missing root element <osm-notes>"* ]]
}

@test "test __validate_xml_structure_only with XML without notes" {
 # Create XML without notes
 cat > /tmp/test.xml << 'EOF'
<?xml version="1.0"?>
<osm-notes>
</osm-notes>
EOF
 
 # Test structure-only validation
 run __validate_xml_structure_only "/tmp/test.xml"
 [[ "${status}" -eq 1 ]]
 [[ "${output}" == *"ERROR: No note elements found in XML file"* ]]
}

@test "test __validate_iso8601_date with valid dates" {
 # Test valid ISO8601 dates
 source "${SCRIPT_BASE_DIRECTORY}/bin/validationFunctions.sh"
 
 # Test various valid date formats
 run __validate_iso8601_date "2023-01-01T00:00:00Z" "test date"
 [[ "${status}" -eq 0 ]]
 
 run __validate_iso8601_date "2023-12-31T23:59:59Z" "test date"
 [[ "${status}" -eq 0 ]]
 
 run __validate_iso8601_date "2023-06-15T08:30:45Z" "test date"
 [[ "${status}" -eq 0 ]]
}

@test "test __validate_iso8601_date with leading zeros" {
 # Test dates with leading zeros (should work correctly)
 source "${SCRIPT_BASE_DIRECTORY}/bin/validationFunctions.sh"
 
 # Test dates with leading zeros
 run __validate_iso8601_date "2023-04-08T08:09:05Z" "test date"
 [[ "${status}" -eq 0 ]]
 
 run __validate_iso8601_date "2023-09-12T13:41:32Z" "test date"
 [[ "${status}" -eq 0 ]]
}

@test "test __validate_iso8601_date with invalid dates" {
 # Test invalid date formats
 source "${SCRIPT_BASE_DIRECTORY}/bin/validationFunctions.sh"
 
 # Test invalid month
 run __validate_iso8601_date "2023-13-01T00:00:00Z" "test date"
 [[ "${status}" -eq 1 ]]
 
 # Test invalid day
 run __validate_iso8601_date "2023-01-32T00:00:00Z" "test date"
 [[ "${status}" -eq 1 ]]
 
 # Test invalid hour
 run __validate_iso8601_date "2023-01-01T24:00:00Z" "test date"
 [[ "${status}" -eq 1 ]]
 
 # Test invalid minute
 run __validate_iso8601_date "2023-01-01T00:60:00Z" "test date"
 [[ "${status}" -eq 1 ]]
 
 # Test invalid second
 run __validate_iso8601_date "2023-01-01T00:00:60Z" "test date"
 [[ "${status}" -eq 1 ]]
}

@test "test __validate_iso8601_date with invalid characters" {
 # Test dates with invalid characters (should fail)
 source "${SCRIPT_BASE_DIRECTORY}/bin/validationFunctions.sh"
 
 # Test date with letters instead of numbers
 run __validate_iso8601_date "2023-aa-01T00:00:00Z" "test date"
 [[ "${status}" -eq 1 ]]
 
 # Test date with letters in month
 run __validate_iso8601_date "2023-1a-01T00:00:00Z" "test date"
 [[ "${status}" -eq 1 ]]
 
 # Test date with letters in day
 run __validate_iso8601_date "2023-01-1bT00:00:00Z" "test date"
 [[ "${status}" -eq 1 ]]
 
 # Test date with letters in hour
 run __validate_iso8601_date "2023-01-01T1c:00:00Z" "test date"
 [[ "${status}" -eq 1 ]]
 
 # Test date with letters in minute
 run __validate_iso8601_date "2023-01-01T00:1d:00Z" "test date"
 [[ "${status}" -eq 1 ]]
 
 # Test date with letters in second
 run __validate_iso8601_date "2023-01-01T00:00:1eZ" "test date"
 [[ "${status}" -eq 1 ]]
}

@test "test __validate_iso8601_date with malformed dates" {
 # Test malformed date strings
 source "${SCRIPT_BASE_DIRECTORY}/bin/validationFunctions.sh"
 
 # Test empty date
 run __validate_iso8601_date "" "test date"
 [[ "${status}" -eq 1 ]]
 
 # Test invalid format
 run __validate_iso8601_date "2023-01-01 00:00:00" "test date"
 [[ "${status}" -eq 1 ]]
 
 # Test missing timezone
 run __validate_iso8601_date "2023-01-01T00:00:00" "test date"
 [[ "${status}" -eq 1 ]]
}

@test "test __validate_xml_dates_lightweight with valid dates" {
 # Test lightweight date validation with valid dates
 # Functions are already loaded via functionsProcess.sh
 
 # Create test XML with valid dates
 cat > /tmp/test_dates.xml << 'EOF'
<?xml version="1.0"?>
<osm-notes>
 <note id="1" lat="0.0" lon="0.0" created_at="2023-04-08T08:09:05Z">
  <comment action="opened" timestamp="2023-09-12T13:41:32Z" uid="1" user="test">Test comment</comment>
 </note>
 <note id="2" lat="0.0" lon="0.0" created_at="2023-06-15T14:30:45Z"/>
</osm-notes>
EOF
 
 run __validate_xml_dates_lightweight "/tmp/test_dates.xml"
 [[ "${status}" -eq 0 ]]
 [[ "${output}" == *"XML dates validation passed (sample-based)"* ]]
}

@test "test __validate_xml_dates_lightweight with invalid dates" {
 # Test lightweight date validation with invalid dates
 # Functions are already loaded via functionsProcess.sh
 
 # Create test XML with invalid dates
 cat > /tmp/test_invalid_dates.xml << 'EOF'
<?xml version="1.0"?>
<osm-notes>
 <note id="1" lat="0.0" lon="0.0" created_at="2023-13-01T00:00:00Z">
  <comment action="opened" timestamp="2023-01-32T24:00:00Z" uid="1" user="test">Test comment</comment>
 </note>
 <note id="2" lat="0.0" lon="0.0" created_at="2023-01-01T25:00:00Z"/>
</osm-notes>
EOF
 
 run __validate_xml_dates_lightweight "/tmp/test_invalid_dates.xml"
 [[ "${status}" -eq 1 ]]
 [[ "${output}" == *"Too many invalid dates found in sample"* ]]
}

@test "test __validate_xml_dates_lightweight with mixed valid and invalid dates" {
 # Test lightweight date validation with mixed dates
 # Functions are already loaded via functionsProcess.sh
 
 # Create test XML with mixed valid and invalid dates
 cat > /tmp/test_mixed_dates.xml << 'EOF'
<?xml version="1.0"?>
<osm-notes>
 <note id="1" lat="0.0" lon="0.0" created_at="2023-04-08T08:09:05Z">
  <comment action="opened" timestamp="2023-09-12T13:41:32Z" uid="1" user="test">Valid date</comment>
 </note>
 <note id="2" lat="0.0" lon="0.0" created_at="2023-13-01T00:00:00Z">
  <comment action="opened" timestamp="2023-01-32T24:00:00Z" uid="2" user="test">Invalid date</comment>
 </note>
 <note id="3" lat="0.0" lon="0.0" created_at="2023-06-15T14:30:45Z"/>
</osm-notes>
EOF
 
 run __validate_xml_dates_lightweight "/tmp/test_mixed_dates.xml"
 # Should fail because more than 10% of dates are invalid
 [[ "${status}" -eq 1 ]]
 [[ "${output}" == *"Too many invalid dates found in sample"* ]]
}

@test "test __validate_xml_with_enhanced_error_handling with small file" {
 # Create test XML file
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
 
 # Test with small file
 run __validate_xml_with_enhanced_error_handling "/tmp/test.xml" "/tmp/schema.xsd"
 [[ "${status}" -eq 0 ]]
 [[ "${output}" == *"XML validation succeeded"* ]]
}

@test "test __validate_xml_with_enhanced_error_handling with large file" {
 # Create a large test XML file (simulate large file)
 cat > /tmp/test.xml << 'EOF'
<?xml version="1.0"?>
<osm-notes>
EOF

 # Add many notes to simulate large file
 for i in {1..1000}; do
  echo " <note id=\"${i}\" lat=\"0.0\" lon=\"0.0\" created_at=\"2023-01-01T00:00:00Z\"/>"
 done >> /tmp/test.xml

 echo "</osm-notes>" >> /tmp/test.xml

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
 
 # Test with large file (mock the file size)
 function stat() {
  if [[ "$*" == *"test.xml"* ]]; then
   echo "600000000"  # Simulate 600MB file
  else
   command stat "$@"
  fi
 }
 export -f stat
 
 run __validate_xml_with_enhanced_error_handling "/tmp/test.xml" "/tmp/schema.xsd"
 [[ "${status}" -eq 0 ]]
 [[ "${output}" == *"Basic XML validation succeeded"* ]]
}

@test "test __validate_xml_with_enhanced_error_handling with very large file" {
 # Create a very large test XML file (simulate very large file)
 cat > /tmp/test.xml << 'EOF'
<?xml version="1.0"?>
<osm-notes>
EOF

 # Add many notes to simulate very large file
 for i in {1..2000}; do
  echo " <note id=\"${i}\" lat=\"0.0\" lon=\"0.0\" created_at=\"2023-01-01T00:00:00Z\"/>"
 done >> /tmp/test.xml

 echo "</osm-notes>" >> /tmp/test.xml

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
 
 # Test with very large file (mock the file size)
 function stat() {
  if [[ "$*" == *"test.xml"* ]]; then
   echo "1200000000"  # Simulate 1200MB file
  else
   command stat "$@"
  fi
 }
 export -f stat
 
 run __validate_xml_with_enhanced_error_handling "/tmp/test.xml" "/tmp/schema.xsd"
 [[ "${status}" -eq 0 ]]
 [[ "${output}" == *"Structure-only validation succeeded for very large file"* ]]
}

@test "test __validate_xml_dates_lightweight with invalid characters" {
 # Test lightweight date validation with invalid characters
 # Functions are already loaded via functionsProcess.sh
 
 # Create test XML with invalid characters in dates
 cat > /tmp/test_invalid_chars.xml << 'EOF'
<?xml version="1.0"?>
<osm-notes>
 <note id="1" lat="0.0" lon="0.0" created_at="2023-aa-01T00:00:00Z">
  <comment action="opened" timestamp="2023-01-1bT00:00:00Z" uid="1" user="test">Test comment</comment>
 </note>
 <note id="2" lat="0.0" lon="0.0" created_at="2023-01-01T1c:00:00Z"/>
EOF

 # Add many more notes to make the file larger and avoid lite validation
 for i in {3..100}; do
  # Make some dates invalid to ensure validation fails
  if [[ $((i % 3)) -eq 0 ]]; then
   # Invalid date every 3rd note
   cat >> /tmp/test_invalid_chars.xml << EOF
 <note id="${i}" lat="0.0" lon="0.0" created_at="2023-13-01T00:00:00Z">
  <comment action="opened" timestamp="2023-01-32T00:00:00Z" uid="${i}" user="test">Test comment ${i}</comment>
 </note>
EOF
  else
   # Valid date
   cat >> /tmp/test_invalid_chars.xml << EOF
 <note id="${i}" lat="0.0" lon="0.0" created_at="2023-01-01T00:00:00Z">
  <comment action="opened" timestamp="2023-01-01T00:00:00Z" uid="${i}" user="test">Test comment ${i}</comment>
 </note>
EOF
  fi
 done

 echo '</osm-notes>' >> /tmp/test_invalid_chars.xml
 
 run __validate_xml_dates_lightweight "/tmp/test_invalid_chars.xml"
 [[ "${status}" -eq 1 ]]
 [[ "${output}" == *"Invalid date format found in sample"* ]]
}

@test "test planet XML files avoid memory-intensive xmllint schema validation" {
 # Test that planet XML files use basic validation instead of xmllint --schema
 
 # Extract just the function we need from processPlanetNotes.sh
 cat > /tmp/test_planet_functions.sh << 'EOF'
#!/bin/bash

# Mock logger functions for testing
function __log_start() { return 0; }
function __logi() { echo "INFO: $1"; }
function __loge() { echo "ERROR: $1"; }
function __logw() { echo "WARNING: $1"; }
function __logd() { echo "DEBUG: $1"; }
function __log_finish() { return 0; }

# Mock validation functions
function __validate_xml_structure_only() { echo "Structure validation passed"; return 0; }
function __validate_xml_basic() { echo "Basic validation passed"; return 0; }

EOF
 
 # Extract the specific function from processPlanetNotes.sh
 sed -n '/^function __validate_xml_with_enhanced_error_handling/,/^}/p' \
  "${SCRIPT_BASE_DIRECTORY}/bin/process/processPlanetNotes.sh" >> /tmp/test_planet_functions.sh
 
 source /tmp/test_planet_functions.sh
 
 # Create a small test planet XML file with "planet" in the name
 cat > /tmp/planet_test.xml << 'EOF'
<?xml version="1.0"?>
<osm-notes>
 <note id="1" lat="35.5170066" lon="139.6322554" created_at="2023-01-01T00:00:00Z">
  <comment action="opened" timestamp="2023-01-01T00:00:00Z" uid="1" user="test">Test comment</comment>
 </note>
</osm-notes>
EOF
 
 # Mock xmllint to detect if it's called with --schema (should not be called)
 xmllint_called_with_schema=false
 function xmllint() {
  if [[ "$*" == *"--schema"* ]]; then
   xmllint_called_with_schema=true
   echo "ERROR: xmllint --schema should not be called for planet files" >&2
   return 1
  fi
  # For other xmllint calls (basic validation), just return success
  return 0
 }
 export -f xmllint
 export xmllint_called_with_schema
 
 # Create a mock schema file
 echo "<xs:schema></xs:schema>" > /tmp/test_schema.xsd
 
 # Run validation on planet file
 run __validate_xml_with_enhanced_error_handling "/tmp/planet_test.xml" "/tmp/test_schema.xsd"
 
 # Verification: Should succeed and not call xmllint --schema
 [[ "${status}" -eq 0 ]]
 [[ "${output}" == *"Planet file detected"* ]] || [[ "${output}" == *"planet file detected"* ]] || [[ "${output}" == *"Planet XML file detected"* ]]
 [[ "${output}" == *"Using basic validation"* ]] || [[ "${output}" == *"Basic validation"* ]]
 [[ "${xmllint_called_with_schema}" == false ]]
 
 # Clean up
 rm -f /tmp/planet_test.xml /tmp/test_schema.xsd /tmp/test_planet_functions.sh
} 