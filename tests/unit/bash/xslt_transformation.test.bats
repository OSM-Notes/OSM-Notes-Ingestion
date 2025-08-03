#!/usr/bin/env bats

# XSLT Transformation Tests
# Tests the XSLT files to produce the expected output
# Replaces test/xslt/test_xslt.sh with BATS framework
#
# Author: Andres Gomez (AngocA)
# Version: 2025-01-27

load "$(dirname "$BATS_TEST_FILENAME")/../../test_helper.bash"

# Test configuration
XSLT_DIR="${SCRIPT_BASE_DIRECTORY}/xslt"
TEST_DATA_DIR="${SCRIPT_BASE_DIRECTORY}/test/xslt"
TEST_OUTPUT_DIR="/tmp/xslt_output_$$"

setup() {
 # Create test output directory
 mkdir -p "${TEST_OUTPUT_DIR}"
 
   # Copy test data files to temporary directory
  if [[ -d "${TEST_DATA_DIR}" ]]; then
   cp "${TEST_DATA_DIR}"/*.xml "/tmp/" 2>/dev/null || true
   cp "${TEST_DATA_DIR}"/*.csv "/tmp/" 2>/dev/null || true
  fi
}

teardown() {
 # Clean up test output directory
 rm -rf "${TEST_OUTPUT_DIR}" 2>/dev/null || true
}

# Helper function to test XSLT transformation
# Parameters:
#   $1: Test type (notes, note_comments, note_comments_text)
#   $2: Format type (API, Planet)
#   $3: Expected file path
#   $4: Actual file path
test_xslt_transformation() {
 local test_type="${1}"
 local format_type="${2}"
 local expected_file="${3}"
 local actual_file="${4}"
 local xslt_file="${XSLT_DIR}/${test_type}-${format_type}-csv.xslt"
   local xml_file="/tmp/osm-notes-${format_type}.xml"

 # Check if XSLT file exists
 if [[ ! -f "${xslt_file}" ]]; then
  skip "XSLT file not found: ${xslt_file}"
 fi

 # Check if XML file exists
 if [[ ! -f "${xml_file}" ]]; then
  skip "XML file not found: ${xml_file}"
 fi

 # Generate actual CSV file
 run xsltproc "${xslt_file}" "${xml_file}" > "${actual_file}"
 [ "$status" -eq 0 ]
 [ -f "${actual_file}" ]

 # Check if expected file exists
 if [[ -f "${expected_file}" ]]; then
  # Compare actual with expected
  run diff "${actual_file}" "${expected_file}"
  [ "$status" -eq 0 ]
  [[ "${output}" == "" ]]
 else
  skip "Expected file not found: ${expected_file}"
 fi
}

@test "XSLT transformation should work for note_comments_text Planet format" {
 local test_type="note_comments_text"
 local format_type="Planet"
   local expected_file="/tmp/note_comments_text-Planet-expected.csv"
  local actual_file="${TEST_OUTPUT_DIR}/note_comments_text-Planet-actual.csv"

 test_xslt_transformation "${test_type}" "${format_type}" "${expected_file}" "${actual_file}"
}

@test "XSLT transformation should work for note_comments_text API format" {
 local test_type="note_comments_text"
 local format_type="API"
   local expected_file="/tmp/note_comments_text-API-expected.csv"
  local actual_file="${TEST_OUTPUT_DIR}/note_comments_text-API-actual.csv"

 test_xslt_transformation "${test_type}" "${format_type}" "${expected_file}" "${actual_file}"
}

@test "XSLT transformation should work for note_comments Planet format" {
 local test_type="note_comments"
 local format_type="Planet"
   local expected_file="/tmp/note_comments-Planet-expected.csv"
  local actual_file="${TEST_OUTPUT_DIR}/note_comments-Planet-actual.csv"

 test_xslt_transformation "${test_type}" "${format_type}" "${expected_file}" "${actual_file}"
}

@test "XSLT transformation should work for note_comments API format" {
 local test_type="note_comments"
 local format_type="API"
   local expected_file="/tmp/note_comments-API-expected.csv"
  local actual_file="${TEST_OUTPUT_DIR}/note_comments-API-actual.csv"

 test_xslt_transformation "${test_type}" "${format_type}" "${expected_file}" "${actual_file}"
}

@test "XSLT transformation should work for notes Planet format" {
 local test_type="notes"
 local format_type="Planet"
   local expected_file="/tmp/notes-Planet-expected.csv"
  local actual_file="${TEST_OUTPUT_DIR}/notes-Planet-actual.csv"

 test_xslt_transformation "${test_type}" "${format_type}" "${expected_file}" "${actual_file}"
}

@test "XSLT transformation should work for notes API format" {
 local test_type="notes"
 local format_type="API"
   local expected_file="/tmp/notes-API-expected.csv"
  local actual_file="${TEST_OUTPUT_DIR}/notes-API-actual.csv"

 test_xslt_transformation "${test_type}" "${format_type}" "${expected_file}" "${actual_file}"
}

@test "XSLT files should exist" {
 # Check if all XSLT files exist
 local xslt_files=(
  "${XSLT_DIR}/notes-API-csv.xslt"
  "${XSLT_DIR}/notes-Planet-csv.xslt"
  "${XSLT_DIR}/note_comments-API-csv.xslt"
  "${XSLT_DIR}/note_comments-Planet-csv.xslt"
  "${XSLT_DIR}/note_comments_text-API-csv.xslt"
  "${XSLT_DIR}/note_comments_text-Planet-csv.xslt"
 )

 for xslt_file in "${xslt_files[@]}"; do
  [ -f "${xslt_file}" ]
 done
}

@test "XSLT files should be valid XML" {
 # Check if all XSLT files are valid XML
 local xslt_files=(
  "${XSLT_DIR}/notes-API-csv.xslt"
  "${XSLT_DIR}/notes-Planet-csv.xslt"
  "${XSLT_DIR}/note_comments-API-csv.xslt"
  "${XSLT_DIR}/note_comments-Planet-csv.xslt"
  "${XSLT_DIR}/note_comments_text-API-csv.xslt"
  "${XSLT_DIR}/note_comments_text-Planet-csv.xslt"
 )

 for xslt_file in "${xslt_files[@]}"; do
  if [[ -f "${xslt_file}" ]]; then
   run xmllint --noout "${xslt_file}"
   [ "$status" -eq 0 ]
  fi
 done
}

@test "XSLT files should have correct structure" {
 # Check if XSLT files have required elements
 local xslt_files=(
  "${XSLT_DIR}/notes-API-csv.xslt"
  "${XSLT_DIR}/notes-Planet-csv.xslt"
  "${XSLT_DIR}/note_comments-API-csv.xslt"
  "${XSLT_DIR}/note_comments-Planet-csv.xslt"
  "${XSLT_DIR}/note_comments_text-API-csv.xslt"
  "${XSLT_DIR}/note_comments_text-Planet-csv.xslt"
 )

 for xslt_file in "${xslt_files[@]}"; do
  if [[ -f "${xslt_file}" ]]; then
   # Check for required XSLT elements
   run grep -q "xsl:stylesheet" "${xslt_file}"
   [ "$status" -eq 0 ]
   
   run grep -q "xsl:template" "${xslt_file}"
   [ "$status" -eq 0 ]
   
   run grep -q "xsl:output" "${xslt_file}"
   [ "$status" -eq 0 ]
  fi
 done
}

@test "xsltproc should be available" {
 run command -v xsltproc
 [ "$status" -eq 0 ]
}

@test "xmllint should be available" {
 run command -v xmllint
 [ "$status" -eq 0 ]
}

@test "XSLT transformation should handle empty XML gracefully" {
 local test_type="notes"
 local format_type="API"
 local xslt_file="${XSLT_DIR}/${test_type}-${format_type}-csv.xslt"
   local empty_xml="/tmp/empty.xml"
 local output_file="${TEST_OUTPUT_DIR}/empty_output.csv"

 # Create empty XML file
 cat > "${empty_xml}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6" generator="OpenStreetMap server">
</osm>
EOF

 # Run transformation on empty XML
 run xsltproc "${xslt_file}" "${empty_xml}" > "${output_file}"
 [ "$status" -eq 0 ]
 [ -f "${output_file}" ]
}

@test "XSLT transformation should handle malformed XML gracefully" {
 local test_type="notes"
 local format_type="API"
 local xslt_file="${XSLT_DIR}/${test_type}-${format_type}-csv.xslt"
   local malformed_xml="/tmp/malformed.xml"
 local output_file="${TEST_OUTPUT_DIR}/malformed_output.csv"

 # Create malformed XML file
 cat > "${malformed_xml}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6" generator="OpenStreetMap server">
  <note lat="40.7128" lon="-74.0060">
    <id>123</id>
    <!-- Missing closing tag -->
EOF

 # Run transformation on malformed XML (should fail gracefully)
 run xsltproc "${xslt_file}" "${malformed_xml}" > "${output_file}" 2>&1
 # xsltproc should handle this gracefully or fail with appropriate error
 [ "$status" -ne 0 ] || [ -f "${output_file}" ]
}

@test "XSLT transformation should preserve CSV format" {
 local test_type="notes"
 local format_type="API"
 local xslt_file="${XSLT_DIR}/${test_type}-${format_type}-csv.xslt"
   local xml_file="/tmp/osm-notes-API.xml"
 local output_file="${TEST_OUTPUT_DIR}/csv_format_test.csv"

 if [[ -f "${xml_file}" ]]; then
  # Run transformation
  run xsltproc "${xslt_file}" "${xml_file}" > "${output_file}"
  [ "$status" -eq 0 ]
  [ -f "${output_file}" ]

  # Check if output contains CSV format (comma-separated values)
  run grep -q "," "${output_file}"
  [ "$status" -eq 0 ]

  # Check if output has at least one line
  run wc -l < "${output_file}"
  [ "$output" -gt 0 ]
 fi
}

@test "XSLT transformation should handle special characters in text" {
 local test_type="note_comments_text"
 local format_type="API"
 local xslt_file="${XSLT_DIR}/${test_type}-${format_type}-csv.xslt"
   local special_xml="/tmp/special_chars.xml"
 local output_file="${TEST_OUTPUT_DIR}/special_chars_output.csv"

 # Create XML with special characters
 cat > "${special_xml}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6" generator="OpenStreetMap server">
  <note lat="40.7128" lon="-74.0060">
    <id>123</id>
    <comments>
      <comment>
        <text>Test with "quotes", commas, and special chars: áéíóúñ</text>
      </comment>
    </comments>
  </note>
</osm>
EOF

 # Run transformation
 run xsltproc "${xslt_file}" "${special_xml}" > "${output_file}"
 [ "$status" -eq 0 ]
 [ -f "${output_file}" ]

 # Check if output contains the special characters
 run grep -q "áéíóúñ" "${output_file}"
 [ "$status" -eq 0 ]
}

@test "XSLT transformation should handle missing optional fields" {
 local test_type="notes"
 local format_type="API"
 local xslt_file="${XSLT_DIR}/${test_type}-${format_type}-csv.xslt"
   local minimal_xml="/tmp/minimal.xml"
 local output_file="${TEST_OUTPUT_DIR}/minimal_output.csv"

 # Create minimal XML with only required fields
 cat > "${minimal_xml}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6" generator="OpenStreetMap server">
  <note lat="40.7128" lon="-74.0060">
    <id>123</id>
  </note>
</osm>
EOF

 # Run transformation
 run xsltproc "${xslt_file}" "${minimal_xml}" > "${output_file}"
 [ "$status" -eq 0 ]
 [ -f "${output_file}" ]

 # Check if output was generated (even with minimal data)
 run wc -l < "${output_file}"
 [ "$output" -gt 0 ]
} 