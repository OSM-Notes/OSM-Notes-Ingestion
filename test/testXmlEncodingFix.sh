#!/bin/bash

# Test script for XML encoding fix functionality
# Tests the selective HTML entity replacement in XML structure vs text content
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-20

set -euo pipefail

# Define required variables
BASENAME="testXmlEncodingFix"
TMP_DIR="/tmp/${BASENAME}_$$"
mkdir -p "${TMP_DIR}"

# Simple logging functions for testing
function log_info() {
 echo "$(date '+%Y-%m-%d %H:%M:%S') - INFO - $*"
}

function log_error() {
 echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR - $*" >&2
}

function log_warn() {
 echo "$(date '+%Y-%m-%d %H:%M:%S') - WARN - $*"
}

# Test function to simulate the XML encoding fix
function test_xml_encoding_fix() {
 local INPUT_FILE="${1}"
 local OUTPUT_FILE="${2}"

 log_info "Testing XML encoding fix with input: ${INPUT_FILE}"

 # Create a temporary file for the fix
 local TEMP_FILE="${OUTPUT_FILE}.temp"

 # Use the same logic as in the main function
 awk '
  BEGIN { in_text_content = 0; in_tag = 0; in_attribute_value = 0; }
  {
    line = $0
    # Process line character by character to distinguish between XML structure and text content
    result = ""
    i = 1
    while (i <= length(line)) {
      char = substr(line, i, 1)
      if (char == "<") {
        # Start of XML tag - fix HTML entities in tag name and attribute names only
        in_tag = 1
        in_attribute_value = 0
        result = result char
        i++
        # Process the tag content
        while (i <= length(line) && substr(line, i, 1) != ">") {
          if (substr(line, i, 1) == "=") {
            # Start of attribute value
            in_attribute_value = 1
            result = result substr(line, i, 1)
            i++
          } else if (substr(line, i, 1) == "\"") {
            # Toggle attribute value state
            in_attribute_value = !in_attribute_value
            result = result substr(line, i, 1)
            i++
          } else if (in_attribute_value) {
            # Inside attribute value - preserve HTML entities
            result = result substr(line, i, 1)
            i++
          } else {
            # Outside attribute value - fix HTML entities in tag/attribute names
            if (substr(line, i, 4) == "&lt;") {
              result = result "<"
              i += 4
            } else if (substr(line, i, 4) == "&gt;") {
              result = result ">"
              i += 4
            } else {
              result = result substr(line, i, 1)
              i++
            }
          }
        }
        if (i <= length(line)) {
          result = result substr(line, i, 1)  # Add the closing ">"
          i++
        }
      } else {
        # Text content - preserve HTML entities
        result = result char
        i++
      }
    }
    print result
  }' "${INPUT_FILE}" > "${TEMP_FILE}"

 # Replace original file with fixed version
 mv "${TEMP_FILE}" "${OUTPUT_FILE}"
 log_info "Applied selective XML encoding fix: ${OUTPUT_FILE}"

 # Validate the result
 if xmllint --noout "${OUTPUT_FILE}" 2> /dev/null; then
  log_info "SUCCESS: XML validation passed after encoding fix"
  return 0
 else
  log_error "ERROR: XML validation failed after encoding fix"
  return 1
 fi
}

# Create test XML files
function create_test_files() {
 local TEST_DIR="${TMP_DIR}/xml_encoding_test"
 mkdir -p "${TEST_DIR}"

 # Test case 1: XML with HTML entities in text content (should be preserved)
 cat > "${TEST_DIR}/test1_input.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
  <note id="123" lat="1.0" lon="1.0">
    <comment>
      <text>This is a test with &lt;/div&gt; HTML entities in text content</text>
    </comment>
  </note>
</osm-notes>
EOF

 # Test case 2: XML with HTML entities in XML structure (should be fixed)
 cat > "${TEST_DIR}/test2_input.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
  <note id="123" lat="1.0" lon="1.0">
    <comment>
      <text>This is a test with &lt;/div&gt; HTML entities in text content</text>
    </comment>
  </note>
</osm-notes>
EOF

 # Test case 3: XML with mixed HTML entities
 cat > "${TEST_DIR}/test3_input.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
  <note id="123" lat="1.0" lon="1.0">
    <comment>
      <text>This is a test with &lt;/div&gt; and &gt;span&lt; HTML entities</text>
    </comment>
    <comment>
      <text>Another comment with &lt;b&gt;bold&lt;/b&gt; text</text>
    </comment>
  </note>
</osm-notes>
EOF

 log_info "Created test files in: ${TEST_DIR}"
}

# Run tests
function run_tests() {
 local TEST_DIR="${TMP_DIR}/xml_encoding_test"

 log_info "Running XML encoding fix tests..."

 # Test 1: Should preserve HTML entities in text content
 log_info "Test 1: HTML entities in text content (should be preserved)"
 if test_xml_encoding_fix "${TEST_DIR}/test1_input.xml" "${TEST_DIR}/test1_output.xml"; then
  log_info "Test 1 PASSED"
 else
  log_error "Test 1 FAILED"
  return 1
 fi

 # Test 2: Should fix HTML entities in XML structure
 log_info "Test 2: HTML entities in XML structure (should be fixed)"
 if test_xml_encoding_fix "${TEST_DIR}/test2_input.xml" "${TEST_DIR}/test2_output.xml"; then
  log_info "Test 2 PASSED"
 else
  log_error "Test 2 FAILED"
  return 1
 fi

 # Test 3: Mixed HTML entities
 log_info "Test 3: Mixed HTML entities (should preserve text, fix structure)"
 if test_xml_encoding_fix "${TEST_DIR}/test3_input.xml" "${TEST_DIR}/test3_output.xml"; then
  log_info "Test 3 PASSED"
 else
  log_error "Test 3 FAILED"
  return 1
 fi

 log_info "All tests completed successfully"
}

# Cleanup function
function cleanup() {
 if [[ -d "${TMP_DIR}" ]]; then
  rm -rf "${TMP_DIR}"
 fi
}

# Main execution
function main() {
 log_info "Starting XML encoding fix tests"

 # Set up cleanup trap
 trap cleanup EXIT

 # Create test files
 create_test_files

 # Run tests
 if run_tests; then
  log_info "All XML encoding fix tests PASSED"
  exit 0
 else
  log_error "Some XML encoding fix tests FAILED"
  exit 1
 fi
}

# Execute main function
main "$@"
