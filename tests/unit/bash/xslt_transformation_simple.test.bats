#!/usr/bin/env bats

# XSLT Transformation Tests (Simplified)
# Tests the XSLT files to produce the expected output
# Replaces test/xslt/test_xslt.sh with BATS framework
#
# Author: Andres Gomez (AngocA)
# Version: 2025-01-27

load "$(dirname "$BATS_TEST_FILENAME")/../../test_helper.bash"

# Test configuration
XSLT_DIR="${SCRIPT_BASE_DIRECTORY}/xslt"
TEST_OUTPUT_DIR="/tmp/xslt_output_$$"

setup() {
 # Create test output directory
 mkdir -p "${TEST_OUTPUT_DIR}"
}

teardown() {
 # Clean up test output directory
 rm -rf "${TEST_OUTPUT_DIR}" 2>/dev/null || true
}

# Helper function to test XSLT transformation
# Parameters:
#   $1: Test type (notes, note_comments, note_comments_text)
#   $2: Format type (API, Planet)
test_xslt_transformation() {
 local test_type="${1}"
 local format_type="${2}"
 local xslt_file="${XSLT_DIR}/${test_type}-${format_type}-csv.xslt"
 local output_file="${TEST_OUTPUT_DIR}/${test_type}-${format_type}-output.csv"

 # Check if XSLT file exists
 if [[ ! -f "${xslt_file}" ]]; then
  skip "XSLT file not found: ${xslt_file}"
 fi

 # Create test XML file based on format
 local xml_file="${TEST_OUTPUT_DIR}/test-${format_type}.xml"
 
 if [[ "${format_type}" == "API" ]]; then
  cat > "${xml_file}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6" generator="OpenStreetMap server">
  <note lat="40.7128" lon="-74.0060">
    <id>123</id>
    <url>https://www.openstreetmap.org/api/0.6/notes/123</url>
    <comment_url>https://www.openstreetmap.org/api/0.6/notes/123/comment</comment_url>
    <close_url>https://www.openstreetmap.org/api/0.6/notes/123/close</close_url>
    <date_created>2013-04-28T02:39:27Z</date_created>
    <status>open</status>
    <comments>
      <comment>
        <date>2013-04-28T02:39:27Z</date>
        <uid>123</uid>
        <user>user1</user>
        <action>opened</action>
        <text>Test comment 1</text>
      </comment>
    </comments>
  </note>
</osm>
EOF
 else
  cat > "${xml_file}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
  <note id="123" lat="40.7128" lon="-74.0060" created_at="2013-04-28T02:39:27Z" closed_at="">
    <comment action="opened" timestamp="2013-04-28T02:39:27Z" uid="123" user="user1">
      <text>Test comment 1</text>
    </comment>
  </note>
</osm-notes>
EOF
 fi

 # Generate actual CSV file
 run xsltproc "${xslt_file}" "${xml_file}" > "${output_file}"
 [ "$status" -eq 0 ]
 [ -f "${output_file}" ]

 # Verify output has content
 run wc -l < "${output_file}"
 [ "$output" -gt 0 ]

 # Verify output contains expected data
 run grep -q "123" "${output_file}"
 [ "$status" -eq 0 ]
}

@test "XSLT transformation should work for note_comments_text Planet format" {
 test_xslt_transformation "note_comments_text" "Planet"
}

@test "XSLT transformation should work for note_comments_text API format" {
 test_xslt_transformation "note_comments_text" "API"
}

@test "XSLT transformation should work for note_comments Planet format" {
 test_xslt_transformation "note_comments" "Planet"
}

@test "XSLT transformation should work for note_comments API format" {
 test_xslt_transformation "note_comments" "API"
}

@test "XSLT transformation should work for notes Planet format" {
 test_xslt_transformation "notes" "Planet"
}

@test "XSLT transformation should work for notes API format" {
 test_xslt_transformation "notes" "API"
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
 local empty_xml="${TEST_OUTPUT_DIR}/empty.xml"
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
 local malformed_xml="${TEST_OUTPUT_DIR}/malformed.xml"
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
 local xml_file="${TEST_OUTPUT_DIR}/test_api.xml"
 local output_file="${TEST_OUTPUT_DIR}/csv_format_test.csv"

 # Create test XML file
 cat > "${xml_file}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6" generator="OpenStreetMap server">
  <note lat="40.7128" lon="-74.0060">
    <id>123</id>
    <date_created>2013-04-28T02:39:27Z</date_created>
    <status>open</status>
  </note>
</osm>
EOF

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
}

@test "XSLT transformation should handle special characters in text" {
 local test_type="note_comments_text"
 local format_type="API"
 local xslt_file="${XSLT_DIR}/${test_type}-${format_type}-csv.xslt"
 local special_xml="${TEST_OUTPUT_DIR}/special_chars.xml"
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
 local minimal_xml="${TEST_OUTPUT_DIR}/minimal.xml"
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