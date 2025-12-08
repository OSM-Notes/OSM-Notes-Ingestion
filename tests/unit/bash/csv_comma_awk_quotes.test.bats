#!/usr/bin/env bats

# CSV Comma AWK Extraction Tests
# Tests for AWK script extraction of comment texts with commas
# Author: Andres Gomez (AngocA)
# Version: 2025-11-24

load "${BATS_TEST_DIRNAME}/../../test_helper"

setup() {
 export SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
 export TMP_DIR="$(mktemp -d)"

 # Create test XML file (API format) with comments containing commas
 cat > "${TMP_DIR}/test_api_notes_with_commas.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6" generator="OpenStreetMap server">
  <note lat="40.7128" lon="-74.0060">
    <id>1001</id>
    <url>https://www.openstreetmap.org/note/1001</url>
    <date_created>2023-01-01T00:00:00Z</date_created>
    <status>open</status>
    <comments>
      <comment>
        <date>2023-01-01T00:00:00Z</date>
        <uid>12345</uid>
        <user>testuser</user>
        <action>opened</action>
        <text>Wegeaufzeichnungen, muss ich nacharbeiten  via StreetComplete 59.3  GPS Trace: https://www.openstreetmap.org/user/ortwinr/traces/11706592</text>
      </comment>
      <comment>
        <date>2023-01-01T01:00:00Z</date>
        <uid>12346</uid>
        <user>testuser2</user>
        <action>commented</action>
        <text>Thanks, marked the hotel as 'disused'</text>
      </comment>
    </comments>
  </note>
  <note lat="40.7129" lon="-74.0061">
    <id>1002</id>
    <url>https://www.openstreetmap.org/note/1002</url>
    <date_created>2023-01-02T00:00:00Z</date_created>
    <status>open</status>
    <comments>
      <comment>
        <date>2023-01-02T00:00:00Z</date>
        <uid>12347</uid>
        <user>testuser3</user>
        <action>opened</action>
        <text>"Bauruine"
The place has gone or never existed. A CoMaps user reported that the POI was visible on the map (see snapshot date below), but was not found on the ground.
OSM snapshot date: 2025-06-22T05:04:15Z
POI name: Mayurca
POI types: building tourism-hotel
 #CoMaps android</text>
      </comment>
      <comment>
        <date>2023-01-02T01:00:00Z</date>
        <action>commented</action>
        <text>Address: 123 Main St, City, State, ZIP</text>
      </comment>
    </comments>
  </note>
  <note lat="40.7130" lon="-74.0062">
    <id>1003</id>
    <url>https://www.openstreetmap.org/note/1003</url>
    <date_created>2023-01-03T00:00:00Z</date_created>
    <status>open</status>
    <comments>
      <comment>
        <date>2023-01-03T00:00:00Z</date>
        <uid>12348</uid>
        <user>testuser4</user>
        <action>opened</action>
        <text>Text with "quotes" and, commas, everywhere</text>
      </comment>
    </comments>
  </note>
  <note lat="40.7131" lon="-74.0063">
    <id>1004</id>
    <url>https://www.openstreetmap.org/note/1004</url>
    <date_created>2023-01-04T00:00:00Z</date_created>
    <status>open</status>
    <comments>
      <comment>
        <date>2023-01-04T00:00:00Z</date>
        <uid>12349</uid>
        <user>testuser5</user>
        <action>opened</action>
        <text>Text with 'single quotes' and "double quotes" and, commas</text>
      </comment>
      <comment>
        <date>2023-01-04T01:00:00Z</date>
        <uid>12350</uid>
        <user>testuser6</user>
        <action>commented</action>
        <text>Multiline comment
with multiple lines
and commas, quotes "test", and 'more'
Line 4 with more content</text>
      </comment>
    </comments>
  </note>
</osm>
EOF

 # Create test XML file (Planet format) with comments containing commas
 cat > "${TMP_DIR}/test_planet_notes_with_commas.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
  <note id="2001" lat="40.7128" lon="-74.0060" created_at="2023-01-01T00:00:00Z" closed_at="">
    <comment action="opened" timestamp="2023-01-01T00:00:00Z" uid="12345" user="testuser">
      Wegeaufzeichnungen, muss ich nacharbeiten  via StreetComplete 59.3  GPS Trace: https://www.openstreetmap.org/user/ortwinr/traces/11706592
    </comment>
    <comment action="commented" timestamp="2023-01-01T01:00:00Z" uid="12346" user="testuser2">
      Thanks, marked the hotel as 'disused'
    </comment>
  </note>
  <note id="2002" lat="40.7129" lon="-74.0061" created_at="2023-01-02T00:00:00Z" closed_at="">
    <comment action="opened" timestamp="2023-01-02T00:00:00Z" uid="12347" user="testuser3">
      "Bauruine"
The place has gone or never existed. A CoMaps user reported that the POI was visible on the map (see snapshot date below), but was not found on the ground.
OSM snapshot date: 2025-06-22T05:04:15Z
POI name: Mayurca
POI types: building tourism-hotel
 #CoMaps android
    </comment>
    <comment action="commented" timestamp="2023-01-02T01:00:00Z">
      Address: 123 Main St, City, State, ZIP
    </comment>
  </note>
  <note id="2003" lat="40.7130" lon="-74.0062" created_at="2023-01-03T00:00:00Z" closed_at="">
    <comment action="opened" timestamp="2023-01-03T00:00:00Z" uid="12352" user="testuser8">
      Text with 'single quotes' and "double quotes" and, commas
    </comment>
    <comment action="commented" timestamp="2023-01-03T01:00:00Z" uid="12353" user="testuser9">
      Multiline comment
with multiple lines
and commas, quotes "test", and 'more'
Line 4 with more content
    </comment>
  </note>
</osm-notes>
EOF
}

teardown() {
 rm -rf "${TMP_DIR}"
}
@test "extract_comment_texts.awk should handle quotes in text with commas" {
 local awk_file="${SCRIPT_BASE_DIRECTORY}/awk/extract_comment_texts.awk"
 local output_file="${TMP_DIR}/test_text_comments_quotes.csv"

 [ -f "${awk_file}" ]

 # Process API format XML with quotes and commas
 awk -f "${awk_file}" "${TMP_DIR}/test_api_notes_with_commas.xml" > "${output_file}"

 [ -f "${output_file}" ]
 [ -s "${output_file}" ]

 # Find comment with quotes and commas
 local line_with_quotes
 line_with_quotes=$(grep "quotes.*commas" "${output_file}" | head -1)

 # Should have exactly 4 fields
 validate_csv_field_count "${output_file}" 4 "Text with quotes and commas"

 # Verify quotes are escaped (doubled) in CSV
 # The text "quotes" should become ""quotes"" in CSV
 [[ "${line_with_quotes}" =~ .*\"\".* ]]
}
@test "extract_comment_texts.awk should handle single quotes in text API format" {
 local awk_file="${SCRIPT_BASE_DIRECTORY}/awk/extract_comment_texts.awk"
 local output_file="${TMP_DIR}/test_text_comments_single_quotes.csv"

 [ -f "${awk_file}" ]

 # Process API format XML with single quotes in text
 awk -f "${awk_file}" "${TMP_DIR}/test_api_notes_with_commas.xml" > "${output_file}"

 [ -f "${output_file}" ]
 [ -s "${output_file}" ]

 # Find line with single quotes
 local line_with_single_quotes
 line_with_single_quotes=$(grep "single quotes" "${output_file}" | head -1)

 # Should have exactly 4 fields
 validate_csv_field_count "${output_file}" 4 "Text comments with single quotes (API format)"

 # Verify the text is properly quoted (body field should be in double quotes)
 [[ "${line_with_single_quotes}" =~ ^[0-9]+,[0-9]+,\".* ]]

 # Verify single quotes are preserved in the text (use grep instead of regex)
 echo "${line_with_single_quotes}" | grep -q "'"
}
@test "extract_comment_texts.awk should handle double quotes in text API format" {
 local awk_file="${SCRIPT_BASE_DIRECTORY}/awk/extract_comment_texts.awk"
 local output_file="${TMP_DIR}/test_text_comments_double_quotes.csv"

 [ -f "${awk_file}" ]

 # Process API format XML with double quotes in text
 awk -f "${awk_file}" "${TMP_DIR}/test_api_notes_with_commas.xml" > "${output_file}"

 [ -f "${output_file}" ]
 [ -s "${output_file}" ]

 # Find line with double quotes
 local line_with_double_quotes
 line_with_double_quotes=$(grep "double quotes" "${output_file}" | head -1)

 # Should have exactly 4 fields
 validate_csv_field_count "${output_file}" 4 "Text comments with double quotes (API format)"

 # Verify double quotes are escaped (doubled) in CSV
 # The text "quotes" should become ""quotes"" in CSV
 echo "${line_with_double_quotes}" | grep -q '""'
}
@test "extract_comment_texts.awk should handle both single and double quotes in text" {
 local awk_file="${SCRIPT_BASE_DIRECTORY}/awk/extract_comment_texts.awk"
 local output_file="${TMP_DIR}/test_text_comments_both_quotes.csv"

 [ -f "${awk_file}" ]

 # Process API format XML with both types of quotes
 awk -f "${awk_file}" "${TMP_DIR}/test_api_notes_with_commas.xml" > "${output_file}"

 [ -f "${output_file}" ]
 [ -s "${output_file}" ]

 # Find line with both quote types
 local line_with_both_quotes
 line_with_both_quotes=$(grep "single quotes.*double quotes" "${output_file}" | head -1)

 # Should have exactly 4 fields
 validate_csv_field_count "${output_file}" 4 "Text comments with both quote types"

 # Verify both quote types are present (use grep instead of regex)
 echo "${line_with_both_quotes}" | grep -q "'"
 echo "${line_with_both_quotes}" | grep -q '""'
}
