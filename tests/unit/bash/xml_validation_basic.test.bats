#!/usr/bin/env bats

# XML Validation Basic Tests
# Tests for basic XML structure validation functions
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

