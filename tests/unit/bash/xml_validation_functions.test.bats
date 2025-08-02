#!/usr/bin/env bats

# Test file for XML validation functions (functions only)
# Author: Andres Gomez (AngocA)
# Version: 2025-08-02

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

# Handle memory and timeout errors for XML validation
function __handle_xml_validation_error() {
 local EXIT_CODE="${1}"
 local XML_FILE="${2}"
 
 case "${EXIT_CODE}" in
  124) # Timeout
   __loge "ERROR: XML validation timed out for file: ${XML_FILE}"
   __loge "ERROR: This may be due to a very large file or system constraints"
   return 1
   ;;
  137) # Killed (OOM)
   __loge "ERROR: XML validation was killed due to memory constraints for file: ${XML_FILE}"
   __loge "ERROR: The file is too large for the available system memory"
   return 1
   ;;
  139) # Segmentation fault
   __loge "ERROR: XML validation crashed with segmentation fault for file: ${XML_FILE}"
   __loge "ERROR: This may indicate corrupted XML or system issues"
   return 1
   ;;
  *) # Other errors
   __loge "ERROR: XML validation failed with exit code ${EXIT_CODE} for file: ${XML_FILE}"
   return 1
   ;;
 esac
}

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

# Alternative XML structure validation for large files
function __validate_xml_structure_alternative() {
 local XML_FILE="${1}"
 
 if [[ ! -f "${XML_FILE}" ]]; then
  __loge "ERROR: XML file not found: ${XML_FILE}"
  return 1
 fi
 
 __logi "Using alternative XML validation method..."
 
 # Check basic XML structure without full schema validation
 if ! xmllint --noout --nonet "${XML_FILE}" 2> /dev/null; then
  __loge "ERROR: Basic XML structure validation failed"
  return 1
 fi
 
 # Check root element
 if ! grep -q "<osm-notes>" "${XML_FILE}" 2> /dev/null; then
  __loge "ERROR: Missing root element <osm-notes>"
  return 1
 fi
 
 # Check for note elements
 if ! grep -q "<note" "${XML_FILE}" 2> /dev/null; then
  __loge "ERROR: No note elements found in XML"
  return 1
 fi
 
 # Validate a sample of notes for structure
 local SAMPLE_SIZE=100
 local TOTAL_NOTES
 TOTAL_NOTES=$(grep -c "<note" "${XML_FILE}" 2>/dev/null || echo "0")
 
 if [[ "${TOTAL_NOTES}" -gt 0 ]]; then
  __logi "Found ${TOTAL_NOTES} notes in XML file"
  
  # Sample validation for large files
  if [[ "${TOTAL_NOTES}" -gt "${SAMPLE_SIZE}" ]]; then
   __logw "WARNING: Large file detected. Validating sample of ${SAMPLE_SIZE} notes only."
   # Extract sample and validate
   head -n $((SAMPLE_SIZE * 10)) "${XML_FILE}" | tail -n $((SAMPLE_SIZE * 5)) | \
    grep -A 5 "<note" | head -n $((SAMPLE_SIZE * 2)) > /tmp/sample_validation.xml 2>/dev/null
   
   if [[ -s /tmp/sample_validation.xml ]]; then
    if ! xmllint --noout --schema "${XMLSCHEMA_PLANET_NOTES}" /tmp/sample_validation.xml 2> /dev/null; then
     __loge "ERROR: Sample validation failed"
     rm -f /tmp/sample_validation.xml
     return 1
    fi
    rm -f /tmp/sample_validation.xml
   fi
  fi
 fi
 
 __logi "Alternative XML validation completed successfully"
 return 0
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