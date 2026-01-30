#!/usr/bin/env bats

# AWK CSV SQL Order Tests
# Tests for validating CSV column order matches SQL COPY command expectations
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

 # Create test XML file (Planet format)
 cat > "${TMP_DIR}/test_planet_notes.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
  <note id="125" lat="40.7130" lon="-74.0062" created_at="2023-01-01T02:00:00Z">
    <comment uid="12347" user="testuser3" action="opened" timestamp="2023-01-01T02:00:00Z">Test note 3</comment>
  </note>
</osm-notes>
EOF
}

teardown() {
 rm -rf "${TMP_DIR}"
}

@test "CSV column order should match SQL COPY command expectations (notes)" {
 local awk_file="${SCRIPT_BASE_DIRECTORY}/awk/extract_notes.awk"
 local output_file="${TMP_DIR}/test_notes_order.csv"
 local sql_file="${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_30_loadApiNotes.sql"

 [ -f "${awk_file}" ]
 [ -f "${sql_file}" ]

 # Generate CSV
 awk -f "${awk_file}" "${TMP_DIR}/test_api_notes.xml" > "${output_file}"

 [ -s "${output_file}" ]

 # SQL expects: note_id, latitude, longitude, created_at, status, closed_at, id_country, part_id
 # Verify order by checking that status (5th) comes before closed_at (6th)
 local first_line
 first_line=$(head -1 "${output_file}" | tr -d '\r\n')

 # Extract fields
 local created_at
 local status
 local closed_at
 created_at=$(echo "${first_line}" | cut -d',' -f4)
 status=$(echo "${first_line}" | cut -d',' -f5)
 closed_at=$(echo "${first_line}" | cut -d',' -f6)

 # created_at should be a timestamp
 [[ "${created_at}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]]

 # status should be 'open' or 'close' (and NOT empty, NOT a timestamp)
 [[ -n "${status}" ]] # Must not be empty
 [[ "${status}" =~ ^(open|close)$ ]]
 # Must NOT be a timestamp (if it is, columns are swapped)
 [[ ! "${status}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]]

 # closed_at should be empty or a timestamp (for open notes, it's empty)
 # CRITICAL: Must NOT be 'open' or 'close' (those belong in status column)
 if [[ -n "${closed_at}" ]]; then
  # If not empty, must be a timestamp
  [[ "${closed_at}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]]
  # Must NOT be status values
  [[ "${closed_at}" != "open" ]]
  [[ "${closed_at}" != "close" ]]
 fi
}

@test "CSV column order should match SQL COPY command expectations (comments)" {
 local awk_file="${SCRIPT_BASE_DIRECTORY}/awk/extract_comments.awk"
 local output_file="${TMP_DIR}/test_comments_order.csv"
 local sql_file="${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_30_loadApiNotes.sql"

 [ -f "${awk_file}" ]
 [ -f "${sql_file}" ]

 # Generate CSV
 awk -f "${awk_file}" "${TMP_DIR}/test_api_notes.xml" > "${output_file}"

 [ -s "${output_file}" ]

 # SQL expects: note_id, sequence_action, event, created_at, id_user, username, part_id
 # Verify order
 local first_line
 first_line=$(head -1 "${output_file}" | tr -d '\r\n')

 # Extract fields
 local note_id
 local sequence_action
 local event
 local created_at
 note_id=$(echo "${first_line}" | cut -d',' -f1)
 sequence_action=$(echo "${first_line}" | cut -d',' -f2)
 event=$(echo "${first_line}" | cut -d',' -f3)
 created_at=$(echo "${first_line}" | cut -d',' -f4)

 # Verify types
 [[ "${note_id}" =~ ^[0-9]+$ ]]
 [[ "${sequence_action}" =~ ^[0-9]+$ ]]
 [[ "${event}" =~ ^(opened|closed|reopened|commented|hidden)$ ]]
 [[ "${created_at}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]]
}

@test "CSV column order should match SQL COPY command expectations (text comments)" {
 local awk_file="${SCRIPT_BASE_DIRECTORY}/awk/extract_comment_texts.awk"
 local output_file="${TMP_DIR}/test_text_comments_order.csv"
 local sql_file="${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_30_loadApiNotes.sql"

 [ -f "${awk_file}" ]
 [ -f "${sql_file}" ]

 # Generate CSV
 awk -f "${awk_file}" "${TMP_DIR}/test_api_notes.xml" > "${output_file}"

 [ -s "${output_file}" ]

 # SQL expects: note_id, sequence_action, body, part_id
 # Verify order (accounting for quoted body field)
 local first_line
 first_line=$(head -1 "${output_file}" | tr -d '\r\n')

 # Extract note_id (first field before first comma)
 local note_id
 note_id=$(echo "${first_line}" | cut -d',' -f1)

 # Verify note_id is numeric
 [[ "${note_id}" =~ ^[0-9]+$ ]]

 # Verify body is quoted (should start with quote after second comma)
 # This is a simplified check - proper CSV parsing would be more complex
 [[ "${first_line}" =~ ^[0-9]+,[0-9]+,\".* ]]
}

@test "CSV column order should match SQL COPY command expectations for Planet notes (processPlanetNotes_30)" {
 local awk_file="${SCRIPT_BASE_DIRECTORY}/awk/extract_notes.awk"
 local output_file="${TMP_DIR}/test_notes_planet_order.csv"
 local sql_file="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_30_loadPartitionedSyncNotes.sql"

 [ -f "${awk_file}" ]
 [ -f "${sql_file}" ]

 # Generate CSV using Planet format XML
 awk -f "${awk_file}" "${TMP_DIR}/test_planet_notes.xml" > "${output_file}"

 [ -s "${output_file}" ]

 # SQL expects: note_id, latitude, longitude, created_at, status, closed_at, id_country, part_id
 # Verify order by checking that status (5th) comes before closed_at (6th)
 local first_line
 first_line=$(head -1 "${output_file}" | tr -d '\r\n')

 # Extract fields
 local created_at
 local status
 local closed_at
 created_at=$(echo "${first_line}" | cut -d',' -f4)
 status=$(echo "${first_line}" | cut -d',' -f5)
 closed_at=$(echo "${first_line}" | cut -d',' -f6)

 # created_at should be a timestamp
 [[ "${created_at}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]]

 # status should be 'open' or 'close' (and NOT empty, NOT a timestamp)
 [[ -n "${status}" ]] # Must not be empty
 [[ "${status}" =~ ^(open|close)$ ]]
 # Must NOT be a timestamp (if it is, columns are swapped)
 [[ ! "${status}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]]

 # closed_at should be empty or a timestamp (for open notes, it's empty)
 # CRITICAL: Must NOT be 'open' or 'close' (those belong in status column)
 if [[ -n "${closed_at}" ]]; then
  # If not empty, must be a timestamp
  [[ "${closed_at}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]]
  # Must NOT be status values
  [[ "${closed_at}" != "open" ]]
  [[ "${closed_at}" != "close" ]]
 fi

 # Verify SQL file has correct column order
 local sql_content
 sql_content=$(cat "${sql_file}")
 # SQL should have status before closed_at in the COPY command
 [[ "${sql_content}" =~ COPY.*created_at.*status.*closed_at ]]
 # SQL should NOT have closed_at before status
 [[ ! "${sql_content}" =~ COPY.*created_at.*closed_at.*status ]]
}


