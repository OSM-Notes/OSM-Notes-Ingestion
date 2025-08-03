#!/usr/bin/env bats

# Simple XSLT Tests
# Basic tests to verify XSLT functionality
# Replaces test/xslt/test_xslt.sh with BATS framework
#
# Author: Andres Gomez (AngocA)
# Version: 2025-01-27

@test "XSLT files should exist" {
 # Check if all XSLT files exist
 local xslt_dir="$(dirname "$BATS_TEST_FILENAME")/../../../xslt"
 
 local xslt_files=(
  "${xslt_dir}/notes-API-csv.xslt"
  "${xslt_dir}/notes-Planet-csv.xslt"
  "${xslt_dir}/note_comments-API-csv.xslt"
  "${xslt_dir}/note_comments-Planet-csv.xslt"
  "${xslt_dir}/note_comments_text-API-csv.xslt"
  "${xslt_dir}/note_comments_text-Planet-csv.xslt"
 )

 for xslt_file in "${xslt_files[@]}"; do
  [ -f "${xslt_file}" ]
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

@test "Basic XSLT transformation should work" {
 local xslt_dir="$(dirname "$BATS_TEST_FILENAME")/../../../xslt"
 local xslt_file="${xslt_dir}/notes-API-csv.xslt"
 local xml_file="/tmp/test_api.xml"
 local output_file="/tmp/test_output.csv"

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

 # Clean up
 rm -f "${xml_file}" "${output_file}"
} 