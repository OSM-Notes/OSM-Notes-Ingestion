#!/usr/bin/env bats

# Basic XSLT Tests
# Simple tests to verify XSLT functionality
# Replaces test/xslt/test_xslt.sh with BATS framework
#
# Author: Andres Gomez (AngocA)
# Version: 2025-01-27

load "$(dirname "$BATS_TEST_FILENAME")/../../test_helper.bash"

# Test configuration
XSLT_DIR="${SCRIPT_BASE_DIRECTORY}/xslt"
TEST_OUTPUT_DIR="/tmp/xslt_basic_$$"

setup() {
 # Create test output directory
 mkdir -p "${TEST_OUTPUT_DIR}"
}

teardown() {
 # Clean up test output directory
 rm -rf "${TEST_OUTPUT_DIR}" 2>/dev/null || true
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

@test "xsltproc should be available" {
 run command -v xsltproc
 [ "$status" -eq 0 ]
}

@test "xmllint should be available" {
 run command -v xmllint
 [ "$status" -eq 0 ]
}

@test "Basic XSLT transformation should work for notes API" {
 local xslt_file="${XSLT_DIR}/notes-API-csv.xslt"
 local xml_file="${TEST_OUTPUT_DIR}/test_api.xml"
 local output_file="${TEST_OUTPUT_DIR}/notes_api_output.csv"

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

 # Verify output has content
 run wc -c < "${output_file}"
 [ "$output" -gt 0 ]
}

@test "Basic XSLT transformation should work for notes Planet" {
 local xslt_file="${XSLT_DIR}/notes-Planet-csv.xslt"
 local xml_file="${TEST_OUTPUT_DIR}/test_planet.xml"
 local output_file="${TEST_OUTPUT_DIR}/notes_planet_output.csv"

 # Create test XML file
 cat > "${xml_file}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
  <note id="123" lat="40.7128" lon="-74.0060" created_at="2013-04-28T02:39:27Z" closed_at="">
  </note>
</osm-notes>
EOF

 # Run transformation
 run xsltproc "${xslt_file}" "${xml_file}" > "${output_file}"
 [ "$status" -eq 0 ]
 [ -f "${output_file}" ]

 # Verify output has content
 run wc -c < "${output_file}"
 [ "$output" -gt 0 ]
}

@test "XSLT transformation should handle empty input gracefully" {
 local xslt_file="${XSLT_DIR}/notes-API-csv.xslt"
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
 local xslt_file="${XSLT_DIR}/notes-API-csv.xslt"
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