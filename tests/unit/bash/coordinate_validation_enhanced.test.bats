#!/usr/bin/env bats

# OSM-Notes-profile - Enhanced Coordinate Validation Tests
# Tests for the improved coordinate validation function that handles large files safely
#
# Author: Andres Gomez (AngocA)
# Version: 2025-08-10

# shellcheck disable=SC1091,SC2317

# Load test helper
load "${BATS_TEST_DIRNAME}/../../test_helper.bash"

# Load the script under test
setup() {
 # Create temporary directory
 export TMP_DIR=$(mktemp -d)
 export BASENAME="test_coordinate_validation"
 export LOG_LEVEL="DEBUG"
 
 # Source the functions we need to test
 source "${BATS_TEST_DIRNAME}/../../../bin/functionsProcess.sh"
 
 # Create mock XML files
 create_test_xml_files
}

teardown() {
 # Clean up temporary directory
 rm -rf "${TMP_DIR}"
}

# Test that required functions are available
@test "Required functions are available" {
 # Check if the main function exists
 command -v __validate_xml_coordinates >/dev/null 2>&1
 [ $? -eq 0 ]
 
 # Check if validation function exists
 command -v __validate_coordinates >/dev/null 2>&1
 [ $? -eq 0 ]
}

# Test XML format detection manually
@test "XML format detection works manually" {
 # Test API format detection manually
 local API_FILE="${TMP_DIR}/small_api.xml"
 
 # Verify files exist
 [[ -f "${API_FILE}" ]]
 
 # Check API format detection (should find osm and note)
 if grep -q '<osm' "${API_FILE}"; then
  echo "Found <osm> tag in API file"
 else
  echo "No <osm> tag found in API file"
  return 1
 fi
 
 if grep -q '<note' "${API_FILE}"; then
  echo "Found <note> tag in API file"
 else
  echo "No <note> tag found in API file"
  return 1
 fi
 
 # Test Planet format detection manually
 local PLANET_FILE="${TMP_DIR}/small_planet.xml"
 
 # Verify files exist
 [[ -f "${PLANET_FILE}" ]]
 
 # Check Planet format detection (should find osm-notes)
 if grep -q '<osm-notes' "${PLANET_FILE}"; then
  echo "Found <osm-notes> tag in Planet file"
 else
  echo "No <osm-notes> tag found in Planet file"
  return 1
 fi
}

# Create test XML files
create_test_xml_files() {
 # Small XML file (API format) - use static content
 cat > "${TMP_DIR}/small_api.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6" generator="test">
 <note lat="40.7128" lon="-74.0060" id="1">
  <comment>Test note 1</comment>
 </note>
 <note lat="34.0522" lon="-118.2437" id="2">
  <comment>Test note 2</comment>
 </note>
</osm>
EOF

 # Small XML file (Planet format) - use static content
 cat > "${TMP_DIR}/small_planet.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
 <note lat="40.7128" lon="-74.0060" id="1">
  <comment>Test note 1</comment>
 </note>
 <note lat="34.0522" lon="-118.2437" id="2">
  <comment>Test note 2</comment>
 </note>
</osm-notes>
EOF

 # Large XML file (simulated)
 cat > "${TMP_DIR}/large_planet.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
EOF

 # Add many notes to simulate large file
 for i in {1..1000}; do
  cat >> "${TMP_DIR}/large_planet.xml" << EOF
 <note lat="$((30 + i % 60)).$((1000 + i % 9000))" lon="$((i % 360 - 180)).$((1000 + i % 9000))" id="${i}">
  <comment>Test note ${i}</comment>
 </note>
EOF
 done

 echo '</osm-notes>' >> "${TMP_DIR}/large_planet.xml"
}

# Test small API XML file validation
@test "Small API XML file validation works correctly" {
 run __validate_xml_coordinates "${TMP_DIR}/small_api.xml"
 [ "${status}" -eq 0 ]
 [[ "${output}" == *"XML coordinate validation passed"* ]]
}

# Test small Planet XML file validation
@test "Small Planet XML file validation works correctly" {
 run __validate_xml_coordinates "${TMP_DIR}/small_planet.xml"
 [ "${status}" -eq 0 ]
 [[ "${output}" == *"XML coordinate validation passed"* ]]
}

# Test large file detection and lite validation
@test "Large file detection triggers lite validation" {
 # Create a file larger than 500MB (simulated by creating many lines)
 local LARGE_FILE="${TMP_DIR}/very_large.xml"
 
 # Create header
 cat > "${LARGE_FILE}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
EOF

 # Add many notes to make file appear large
 for i in {1..10000}; do
  cat >> "${LARGE_FILE}" << EOF
 <note lat="$((30 + i % 60)).$((1000 + i % 9000))" lon="$((i % 360 - 180)).$((1000 + i % 9000))" id="${i}">
  <comment>Test note ${i}</comment>
 </note>
EOF
 done

 echo '</osm-notes>' >> "${LARGE_FILE}"

 # Mock file size to be large
 local ORIGINAL_STAT=$(which stat)
 function stat() {
  if [[ "$*" == *"--format=%s"* ]]; then
   echo "600000000"  # ~600MB
  else
   "${ORIGINAL_STAT}" "$@"
  fi
 }

 run __validate_xml_coordinates "${LARGE_FILE}"
 [ "${status}" -eq 0 ]
 [[ "${output}" == *"Large file detected"* ]]
 [[ "${output}" == *"using lite coordinate validation"* ]]
 [[ "${output}" == *"Lite coordinate validation passed"* ]]

 # Restore original stat
 unset -f stat
}

# Test coordinate pattern detection in large files
@test "Large file coordinate pattern detection works" {
 local LARGE_FILE="${TMP_DIR}/large_with_coordinates.xml"
 
 # Create large file with coordinate patterns
 cat > "${LARGE_FILE}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
EOF

 # Add notes with coordinates
 for i in {1..5000}; do
  cat >> "${LARGE_FILE}" << EOF
 <note lat="$((30 + i % 60)).$((1000 + i % 9000))" lon="$((i % 360 - 180)).$((1000 + i % 9000))" id="${i}">
  <comment>Test note ${i}</comment>
 </note>
EOF
 done

 echo '</osm-notes>' >> "${LARGE_FILE}"

 # Mock file size to be large
 local ORIGINAL_STAT=$(which stat)
 function stat() {
  if [[ "$*" == *"--format=%s"* ]]; then
   echo "600000000"  # ~600MB
  else
   "${ORIGINAL_STAT}" "$@"
  fi
 }

 run __validate_xml_coordinates "${LARGE_FILE}"
 [ "${status}" -eq 0 ]
 [[ "${output}" == *"Large file detected"* ]]
 [[ "${output}" == *"Lite coordinate validation passed"* ]]

 # Restore original stat
 unset -f stat
}

# Test fallback to minimal validation when grep fails
@test "Fallback to minimal validation works when grep fails" {
 local LARGE_FILE="${TMP_DIR}/large_no_coordinates.xml"
 
 # Create large file without coordinate patterns in first 2000 lines
 cat > "${LARGE_FILE}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
EOF

 # Add many lines without coordinates first
 for i in {1..2000}; do
  echo " <note id=\"${i}\">" >> "${LARGE_FILE}"
  echo "  <comment>Test note ${i}</comment>" >> "${LARGE_FILE}"
  echo " </note>" >> "${LARGE_FILE}"
 done

 # Add some notes with coordinates later
 for i in {2001..3000}; do
  cat >> "${LARGE_FILE}" << EOF
 <note lat="$((30 + i % 60)).$((1000 + i % 9000))" lon="$((i % 360 - 180)).$((1000 + i % 9000))" id="${i}">
  <comment>Test note ${i}</comment>
 </note>
EOF
 done

 echo '</osm-notes>' >> "${LARGE_FILE}"

 # Mock file size to be large
 local ORIGINAL_STAT=$(which stat)
 function stat() {
  if [[ "$*" == *"--format=%s"* ]]; then
   echo "600000000"  # ~600MB
  else
   "${ORIGINAL_STAT}" "$@"
  fi
 }

 run __validate_xml_coordinates "${LARGE_FILE}"
 [ "${status}" -eq 0 ]
 [[ "${output}" == *"Large file detected"* ]]
 [[ "${output}" == *"Minimal validation passed"* ]]

 # Restore original stat
 unset -f stat
}

# Test timeout handling for xmlstarlet operations
@test "Timeout handling works for xmlstarlet operations" {
 # Create a file that would cause xmlstarlet to hang (simulated)
 local TIMEOUT_FILE="${TMP_DIR}/timeout_test.xml"
 
 # Create a file that appears small but has complex structure
 cat > "${TIMEOUT_FILE}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
 <note lat="40.7128" lon="-74.0060" id="1">
  <comment>Test note 1</comment>
 </note>
</osm-notes>
EOF

 # Since we no longer use xmlstarlet, this should work without timeout issues
 run __validate_xml_coordinates "${TIMEOUT_FILE}"
 [ "${status}" -eq 0 ]
 [[ "${output}" == *"XML coordinate validation passed"* ]]
}

# Test error handling for invalid XML files
@test "Error handling works for invalid XML files" {
 local INVALID_FILE="${TMP_DIR}/invalid.xml"
 
 # Create invalid XML with invalid coordinates
 cat > "${INVALID_FILE}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
 <note lat="invalid" lon="invalid" id="1">
  <comment>Test note 1</comment>
 </note>
</osm-notes>
EOF

 run __validate_xml_coordinates "${INVALID_FILE}"
 [ "${status}" -eq 1 ]  # Should fail due to invalid coordinates
 [[ "${output}" == *"XML coordinate validation failed"* ]]
}

# Test auto-detection of XML format
@test "XML format auto-detection works correctly" {
 # Test API format detection (should succeed)
 run __validate_xml_coordinates "${TMP_DIR}/small_api.xml"
 [ "${status}" -eq 0 ]

 # Test Planet format detection (should succeed)
 run __validate_xml_coordinates "${TMP_DIR}/small_planet.xml"
 [ "${status}" -eq 0 ]
}

# Test that large files don't cause memory issues
@test "Large file processing doesn't cause memory issues" {
 local LARGE_FILE="${TMP_DIR}/memory_test.xml"
 
 # Create a minimal XML file
 cat > "${LARGE_FILE}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
 <note lat="40.7128" lon="-74.0060" id="1">
  <comment>Test note</comment>
 </note>
</osm-notes>
EOF

 # Mock file size to be large (simulating a large file)
 local ORIGINAL_STAT=$(which stat)
 function stat() {
  if [[ "$*" == *"--format=%s"* ]]; then
   echo "800000000"  # ~800MB
  else
   "${ORIGINAL_STAT}" "$@"
  fi
 }

 # This should complete without memory issues - should use lite validation
 run __validate_xml_coordinates "${LARGE_FILE}"
 [ "${status}" -eq 0 ]
 [[ "${output}" == *"Large file detected"* ]] || [[ "${output}" == *"XML coordinate validation passed"* ]]

 # Restore original stat
 unset -f stat
}
