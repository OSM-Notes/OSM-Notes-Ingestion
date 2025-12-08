#!/usr/bin/env bats

# AWK CSV Consistency Tests
# Tests for validating consistent column structure across multiple notes
# Author: Andres Gomez (AngocA)
# Version: 2025-11-24

load "${BATS_TEST_DIRNAME}/../../test_helper"

setup() {
 export SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
 export TMP_DIR="$(mktemp -d)"

 # Create test XML file (API format)
 cat > "${TMP_DIR}/test_api_notes.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6" generator="OpenStreetMap server">
  <note lat="40.7128" lon="-74.0060">
    <id>123</id>
    <url>https://www.openstreetmap.org/note/123</url>
    <comment_url>https://www.openstreetmap.org/api/0.6/notes/123/comments</comment_url>
    <close_url>https://www.openstreetmap.org/api/0.6/notes/123/close</close_url>
    <date_created>2023-01-01T00:00:00Z</date_created>
    <status>open</status>
    <comments>
      <comment>
        <date>2023-01-01T00:00:00Z</date>
        <uid>12345</uid>
        <user>testuser</user>
        <action>opened</action>
        <text>Test note</text>
      </comment>
    </comments>
  </note>
  <note lat="40.7129" lon="-74.0061">
    <id>124</id>
    <url>https://www.openstreetmap.org/note/124</url>
    <comment_url>https://www.openstreetmap.org/api/0.6/notes/124/comments</comment_url>
    <close_url>https://www.openstreetmap.org/api/0.6/notes/124/close</close_url>
    <date_created>2023-01-01T01:00:00Z</date_created>
    <date_closed>2023-01-02T10:00:00Z</date_closed>
    <status>closed</status>
    <comments>
      <comment>
        <date>2023-01-01T01:00:00Z</date>
        <uid>12346</uid>
        <user>testuser2</user>
        <action>opened</action>
        <text>Another test note</text>
      </comment>
      <comment>
        <date>2023-01-02T10:00:00Z</date>
        <uid>12346</uid>
        <user>testuser2</user>
        <action>closed</action>
        <text>Closing this note</text>
      </comment>
    </comments>
  </note>
</osm>
EOF
}

teardown() {
 rm -rf "${TMP_DIR}"
}

# Helper function to count columns in CSV line
count_columns() {
 local line="$1"
 echo "${line}" | awk -F',' '{print NF}'
}

@test "All CSV files should have consistent column structure across multiple notes" {
 local awk_notes="${SCRIPT_BASE_DIRECTORY}/awk/extract_notes.awk"
 local awk_comments="${SCRIPT_BASE_DIRECTORY}/awk/extract_comments.awk"
 local awk_texts="${SCRIPT_BASE_DIRECTORY}/awk/extract_comment_texts.awk"

 local notes_csv="${TMP_DIR}/multi_notes.csv"
 local comments_csv="${TMP_DIR}/multi_comments.csv"
 local texts_csv="${TMP_DIR}/multi_texts.csv"

 # Process with multiple notes
 awk -f "${awk_notes}" "${TMP_DIR}/test_api_notes.xml" > "${notes_csv}"
 awk -f "${awk_comments}" "${TMP_DIR}/test_api_notes.xml" > "${comments_csv}"
 awk -f "${awk_texts}" "${TMP_DIR}/test_api_notes.xml" > "${texts_csv}"

 # Verify all lines have same column count
 local notes_line_count
 notes_line_count=$(wc -l < "${notes_csv}")

 if [[ "${notes_line_count}" -gt 1 ]]; then
  local first_cols
  local second_cols
  first_cols=$(count_columns "$(head -1 "${notes_csv}")")
  second_cols=$(count_columns "$(sed -n '2p' "${notes_csv}")")

  [ "${first_cols}" -eq "${second_cols}" ]
  [ "${first_cols}" -eq 8 ]
 fi

 # Same for comments
 local comments_line_count
 comments_line_count=$(wc -l < "${comments_csv}")

 if [[ "${comments_line_count}" -gt 1 ]]; then
  local first_cols
  local second_cols
  first_cols=$(count_columns "$(head -1 "${comments_csv}")")
  second_cols=$(count_columns "$(sed -n '2p' "${comments_csv}")")

  [ "${first_cols}" -eq "${second_cols}" ]
  [ "${first_cols}" -eq 7 ]
 fi
}


