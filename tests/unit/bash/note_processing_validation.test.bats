#!/usr/bin/env bats

# Note Processing Validation Tests
# Tests for XML coordinate validation
# Author: Andres Gomez (AngocA)
# Version: 2025-12-07

load "${BATS_TEST_DIRNAME}/../../test_helper"

setup() {
 # Create temporary test directory
 TEST_DIR=$(mktemp -d)
 export TEST_DIR

 # Set up test environment variables
 export SCRIPT_BASE_DIRECTORY="${TEST_BASE_DIR}"
 export TMP_DIR="${TEST_DIR}"
 export DBNAME="${TEST_DBNAME:-test_db}"
 export RATE_LIMIT="${RATE_LIMIT:-8}"
 export BASHPID=$$

 # Set log level to DEBUG to capture all log output
 export LOG_LEVEL="DEBUG"
 export __log_level="DEBUG"

 # Load note processing functions
 source "${TEST_BASE_DIR}/bin/lib/noteProcessingFunctions.sh"
}

teardown() {
 # Clean up test files
 rm -rf "${TEST_DIR}"
}

# =============================================================================
# Tests for __validate_xml_coordinates
# =============================================================================

@test "__validate_xml_coordinates should validate valid XML coordinates" {
 local XML_FILE="${TEST_DIR}/valid.xml"
 cat > "${XML_FILE}" << 'EOF'
<?xml version="1.0"?>
<osm-notes>
 <note lat="40.7128" lon="-74.0060" id="1"/>
 <note lat="34.0522" lon="-118.2437" id="2"/>
</osm-notes>
EOF

 # Mock __validate_input_file to return success
 __validate_input_file() {
  return 0
 }

 # Mock __validate_coordinates to return success
 __validate_coordinates() {
  return 0
 }

 run __validate_xml_coordinates "${XML_FILE}"
 [[ "${status}" -eq 0 ]]
}

@test "__validate_xml_coordinates should detect invalid coordinates" {
 local XML_FILE="${TEST_DIR}/invalid.xml"
 cat > "${XML_FILE}" << 'EOF'
<?xml version="1.0"?>
<osm-notes>
 <note lat="200.0" lon="-74.0060" id="1"/>
</osm-notes>
EOF

 # Mock __validate_input_file to return success
 __validate_input_file() {
  return 0
 }

 # Mock __validate_coordinates to return failure for invalid coords
 __validate_coordinates() {
  if [[ "$1" == "200.0" ]]; then
   return 1
  fi
  return 0
 }

 run __validate_xml_coordinates "${XML_FILE}"
 [[ "${status}" -eq 1 ]]
}

@test "__validate_xml_coordinates should handle large files with lite validation" {
 local XML_FILE="${TEST_DIR}/large.xml"
 # Create a large file (>500MB simulation by creating many lines)
 for i in {1..1000}; do
  echo "<note lat=\"40.7128\" lon=\"-74.0060\" id=\"${i}\"/>" >> "${XML_FILE}"
 done

 # Mock stat to return large size
 stat() {
  if [[ "$1" == "--format=%s" ]]; then
   echo "600000000" # 600MB
   return 0
  fi
  return 1
 }
 export -f stat

 # Mock __validate_input_file
 __validate_input_file() {
  return 0
 }

 run __validate_xml_coordinates "${XML_FILE}"
 # Should succeed with lite validation
 [[ "${status}" -eq 0 ]]
}

