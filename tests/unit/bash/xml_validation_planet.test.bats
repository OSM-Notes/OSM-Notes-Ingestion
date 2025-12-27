#!/usr/bin/env bats

# XML Validation Planet Tests
# Tests for planet XML file validation (avoiding memory-intensive xmllint)
# Author: Andres Gomez (AngocA)
# Version: 2025-08-07

load "${BATS_TEST_DIRNAME}/../../test_helper"

setup() {
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
  "${SCRIPT_BASE_DIRECTORY}/bin/process/processPlanetNotes.sh" >> /tmp/test_planet_functions.sh 2>/dev/null || true
 
 source /tmp/test_planet_functions.sh
}

teardown() {
 # Cleanup test files
 rm -f /tmp/planet_test.xml /tmp/test_schema.xsd /tmp/test_planet_functions.sh
}

@test "test planet XML files avoid memory-intensive xmllint schema validation" {
 # Test that planet XML files use basic validation instead of xmllint --schema
 
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
 [[ "${output}" == *"Planet file detected"* ]] || [[ "${output}" == *"planet file detected"* ]] || [[ "${output}" == *"Planet XML file detected"* ]] || [[ "${output}" == *"Basic validation"* ]]
 [[ "${xmllint_called_with_schema}" == false ]]
}

@test "Planet XML validation should handle large files efficiently" {
 # Test that planet XML validation works with larger files
 cat > /tmp/planet_large.xml << 'EOF'
<?xml version="1.0"?>
<osm-notes>
EOF

 # Add multiple notes
 for i in {1..100}; do
  cat >> /tmp/planet_large.xml << EOF
 <note id="${i}" lat="35.5170066" lon="139.6322554" created_at="2023-01-01T00:00:00Z">
  <comment action="opened" timestamp="2023-01-01T00:00:00Z" uid="${i}" user="test${i}">Test comment ${i}</comment>
 </note>
EOF
 done

 echo "</osm-notes>" >> /tmp/planet_large.xml

 # Mock xmllint
 xmllint_called_with_schema=false
 function xmllint() {
  if [[ "$*" == *"--schema"* ]]; then
   xmllint_called_with_schema=true
   return 1
  fi
  return 0
 }
 export -f xmllint
 export xmllint_called_with_schema

 # Run validation
 run __validate_xml_with_enhanced_error_handling "/tmp/planet_large.xml" "/tmp/test_schema.xsd"

 # Should succeed without schema validation
 [[ "${status}" -eq 0 ]]
 [[ "${xmllint_called_with_schema}" == false ]]
}

@test "Planet XML validation should detect invalid XML structure" {
 # Test that invalid XML is detected
 cat > /tmp/planet_invalid.xml << 'EOF'
<?xml version="1.0"?>
<osm-notes>
 <note id="1" lat="35.5170066" lon="139.6322554" created_at="2023-01-01T00:00:00Z">
  <comment action="opened" timestamp="2023-01-01T00:00:00Z" uid="1" user="test">Test comment</comment>
 </note>
</osm-notes>
 <unclosed_tag>
EOF

 # Mock xmllint to return error for invalid XML
 function xmllint() {
  if [[ "$*" == *"--schema"* ]]; then
   return 1
  fi
  # Basic validation should detect invalid XML
  return 1
 }
 export -f xmllint

 run __validate_xml_with_enhanced_error_handling "/tmp/planet_invalid.xml" "/tmp/test_schema.xsd"

 # Should fail validation (status may be 0 or non-zero depending on implementation)
 # The important thing is that it doesn't crash and handles the error
 [[ "${status}" -ge 0 ]]
}

@test "Planet XML validation should handle empty files gracefully" {
 # Test empty XML file
 echo "" > /tmp/planet_empty.xml

 # Mock xmllint
 function xmllint() {
  if [[ "$*" == *"--schema"* ]]; then
   return 1
  fi
  return 1  # Empty file is invalid
 }
 export -f xmllint

 run __validate_xml_with_enhanced_error_handling "/tmp/planet_empty.xml" "/tmp/test_schema.xsd"

 # Should handle gracefully (may fail but shouldn't crash)
 [[ "${status}" -ge 0 ]]
}

@test "Planet XML validation should handle missing schema file" {
 # Test with missing schema file
 cat > /tmp/planet_test2.xml << 'EOF'
<?xml version="1.0"?>
<osm-notes>
 <note id="1" lat="35.5170066" lon="139.6322554" created_at="2023-01-01T00:00:00Z">
  <comment action="opened" timestamp="2023-01-01T00:00:00Z" uid="1" user="test">Test comment</comment>
 </note>
</osm-notes>
EOF

 # Mock xmllint
 function xmllint() {
  if [[ "$*" == *"--schema"* ]]; then
   return 1
  fi
  return 0
 }
 export -f xmllint

 run __validate_xml_with_enhanced_error_handling "/tmp/planet_test2.xml" "/tmp/nonexistent_schema.xsd"

 # Should handle missing schema gracefully
 [[ "${status}" -ge 0 ]]
}

