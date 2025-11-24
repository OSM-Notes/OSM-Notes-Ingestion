#!/usr/bin/env bats

# Test CSV column structure validation for AWK scripts
# Validates that AWK scripts generate CSV files with correct number and order of columns
# Author: Andres Gomez (AngocA)
# Version: 2025-11-12

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

# Helper function to count columns in CSV line
count_columns() {
 local line="$1"
 echo "${line}" | awk -F',' '{print NF}'
}

# Helper function to validate column count
validate_column_count() {
 local csv_file="$1"
 local expected_count="$2"
 local file_type="$3"

 if [[ ! -f "${csv_file}" ]]; then
  echo "ERROR: CSV file not found: ${csv_file}"
  return 1
 fi

 if [[ ! -s "${csv_file}" ]]; then
  echo "WARNING: CSV file is empty: ${csv_file}"
  return 0
 fi

 # Check first non-empty line
 local first_line
 first_line=$(head -1 "${csv_file}" | tr -d '\r\n')

 if [[ -z "${first_line}" ]]; then
  echo "ERROR: First line is empty in ${csv_file}"
  return 1
 fi

 local actual_count
 actual_count=$(count_columns "${first_line}")

 if [[ "${actual_count}" -ne "${expected_count}" ]]; then
  echo "ERROR: ${file_type} CSV has ${actual_count} columns, expected ${expected_count}"
  echo "First line: ${first_line}"
  return 1
 fi

 return 0
}

@test "extract_notes.awk should generate CSV with 8 columns (API format)" {
 local awk_file="${SCRIPT_BASE_DIRECTORY}/awk/extract_notes.awk"
 local output_file="${TMP_DIR}/test_notes.csv"

 [ -f "${awk_file}" ]

 # Process API format XML
 awk -f "${awk_file}" "${TMP_DIR}/test_api_notes.xml" > "${output_file}"

 [ -f "${output_file}" ]
 [ -s "${output_file}" ]

 # Expected columns: note_id,latitude,longitude,created_at,closed_at,status,id_country,part_id
 # Total: 8 columns
 validate_column_count "${output_file}" 8 "Notes (API format)"

 # Verify column order: first should be note_id (numeric), 5th should be closed_at or empty, 6th should be status
 local first_line
 first_line=$(head -1 "${output_file}" | tr -d '\r\n')

 # Extract fields to verify order
 local note_id
 local closed_at
 local status
 note_id=$(echo "${first_line}" | cut -d',' -f1)
 closed_at=$(echo "${first_line}" | cut -d',' -f5)
 status=$(echo "${first_line}" | cut -d',' -f6)

 # First column should be numeric (note_id)
 [[ "${note_id}" =~ ^[0-9]+$ ]]

 # 5th column should be closed_at (empty or timestamp, NOT status)
 if [[ -n "${closed_at}" ]]; then
  # If not empty, must be a timestamp
  [[ "${closed_at}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]]
  # Must NOT be status values
  [[ "${closed_at}" != "open" ]]
  [[ "${closed_at}" != "close" ]]
 fi

 # 6th column should be status (open or close, NOT empty, NOT timestamp)
 [[ -n "${status}" ]] # Must not be empty
 [[ "${status}" =~ ^(open|close)$ ]]
 # Must NOT be a timestamp (if it is, columns are swapped)
 [[ ! "${status}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]]
}

@test "extract_notes.awk should generate CSV with 8 columns (Planet format)" {
 local awk_file="${SCRIPT_BASE_DIRECTORY}/awk/extract_notes.awk"
 local output_file="${TMP_DIR}/test_notes_planet.csv"

 [ -f "${awk_file}" ]

 # Process Planet format XML
 awk -f "${awk_file}" "${TMP_DIR}/test_planet_notes.xml" > "${output_file}"

 [ -f "${output_file}" ]
 [ -s "${output_file}" ]

 # Expected columns: note_id,latitude,longitude,created_at,closed_at,status,id_country,part_id
 # Total: 8 columns
 validate_column_count "${output_file}" 8 "Notes (Planet format)"
}

@test "extract_comments.awk should generate CSV with 7 columns (API format)" {
 local awk_file="${SCRIPT_BASE_DIRECTORY}/awk/extract_comments.awk"
 local output_file="${TMP_DIR}/test_comments.csv"

 [ -f "${awk_file}" ]

 # Process API format XML
 awk -f "${awk_file}" "${TMP_DIR}/test_api_notes.xml" > "${output_file}"

 [ -f "${output_file}" ]
 [ -s "${output_file}" ]

 # Expected columns: note_id,sequence_action,event,created_at,id_user,username,part_id
 # Total: 7 columns
 validate_column_count "${output_file}" 7 "Comments (API format)"

 # Verify column order: 1st should be note_id, 2nd should be sequence_action, 3rd should be event
 local first_line
 first_line=$(head -1 "${output_file}" | tr -d '\r\n')

 local note_id
 local sequence_action
 local event
 note_id=$(echo "${first_line}" | cut -d',' -f1)
 sequence_action=$(echo "${first_line}" | cut -d',' -f2)
 event=$(echo "${first_line}" | cut -d',' -f3)

 # First column should be numeric (note_id)
 [[ "${note_id}" =~ ^[0-9]+$ ]]

 # Second column should be numeric (sequence_action)
 [[ "${sequence_action}" =~ ^[0-9]+$ ]]

 # Third column should be event (opened, closed, etc.)
 [[ "${event}" =~ ^(opened|closed|reopened|commented|hidden)$ ]]
}

@test "extract_comments.awk should generate CSV with 7 columns (Planet format)" {
 local awk_file="${SCRIPT_BASE_DIRECTORY}/awk/extract_comments.awk"
 local output_file="${TMP_DIR}/test_comments_planet.csv"

 [ -f "${awk_file}" ]

 # Process Planet format XML
 awk -f "${awk_file}" "${TMP_DIR}/test_planet_notes.xml" > "${output_file}"

 [ -f "${output_file}" ]
 [ -s "${output_file}" ]

 # Expected columns: note_id,sequence_action,event,created_at,id_user,username,part_id
 # Total: 7 columns
 validate_column_count "${output_file}" 7 "Comments (Planet format)"
}

@test "extract_comment_texts.awk should generate CSV with 4 columns (API format)" {
 local awk_file="${SCRIPT_BASE_DIRECTORY}/awk/extract_comment_texts.awk"
 local output_file="${TMP_DIR}/test_text_comments.csv"

 [ -f "${awk_file}" ]

 # Process API format XML
 awk -f "${awk_file}" "${TMP_DIR}/test_api_notes.xml" > "${output_file}"

 [ -f "${output_file}" ]
 [ -s "${output_file}" ]

 # Expected columns: note_id,sequence_action,"body",part_id
 # Total: 4 columns (body may contain commas, but it's quoted)
 # Note: We need to count columns accounting for quoted fields
 local first_line
 first_line=$(head -1 "${output_file}" | tr -d '\r\n')

 # For quoted CSV, we need a more sophisticated parser
 # Simple check: should have at least 3 commas (4 fields minimum)
 local comma_count
 comma_count=$(echo "${first_line}" | tr -cd ',' | wc -c)

 # Should have exactly 3 commas (4 fields: note_id,sequence_action,body,part_id)
 [ "${comma_count}" -eq 3 ]

 # Verify structure: first field should be note_id (numeric)
 local note_id
 note_id=$(echo "${first_line}" | cut -d',' -f1)
 [[ "${note_id}" =~ ^[0-9]+$ ]]
}

@test "extract_comment_texts.awk should generate CSV with 4 columns (Planet format)" {
 local awk_file="${SCRIPT_BASE_DIRECTORY}/awk/extract_comment_texts.awk"
 local output_file="${TMP_DIR}/test_text_comments_planet.csv"

 [ -f "${awk_file}" ]

 # Process Planet format XML
 awk -f "${awk_file}" "${TMP_DIR}/test_planet_notes.xml" > "${output_file}"

 [ -f "${output_file}" ]
 [ -s "${output_file}" ]

 # Expected columns: note_id,sequence_action,"body",part_id
 # Verify by counting commas (should be 3 for 4 fields)
 local first_line
 first_line=$(head -1 "${output_file}" | tr -d '\r\n')

 local comma_count
 comma_count=$(echo "${first_line}" | tr -cd ',' | wc -c)

 [ "${comma_count}" -eq 3 ]
}

@test "CSV column order should match SQL COPY command expectations (notes)" {
 local awk_file="${SCRIPT_BASE_DIRECTORY}/awk/extract_notes.awk"
 local output_file="${TMP_DIR}/test_notes_order.csv"
 local sql_file="${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_31_loadApiNotes.sql"

 [ -f "${awk_file}" ]
 [ -f "${sql_file}" ]

 # Generate CSV
 awk -f "${awk_file}" "${TMP_DIR}/test_api_notes.xml" > "${output_file}"

 [ -s "${output_file}" ]

 # SQL expects: note_id, latitude, longitude, created_at, closed_at, status, id_country, part_id
 # Verify order by checking that closed_at (5th) comes before status (6th)
 local first_line
 first_line=$(head -1 "${output_file}" | tr -d '\r\n')

 # Extract fields
 local created_at
 local closed_at
 local status
 created_at=$(echo "${first_line}" | cut -d',' -f4)
 closed_at=$(echo "${first_line}" | cut -d',' -f5)
 status=$(echo "${first_line}" | cut -d',' -f6)

 # created_at should be a timestamp
 [[ "${created_at}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]]

 # closed_at should be empty or a timestamp (for open notes, it's empty)
 # CRITICAL: Must NOT be 'open' or 'close' (those belong in status column)
 if [[ -n "${closed_at}" ]]; then
  # If not empty, must be a timestamp
  [[ "${closed_at}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]]
  # Must NOT be status values
  [[ "${closed_at}" != "open" ]]
  [[ "${closed_at}" != "close" ]]
 fi

 # status should be 'open' or 'close' (and NOT empty, NOT a timestamp)
 [[ -n "${status}" ]] # Must not be empty
 [[ "${status}" =~ ^(open|close)$ ]]
 # Must NOT be a timestamp (if it is, columns are swapped)
 [[ ! "${status}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]]
}

@test "CSV column order should match SQL COPY command expectations (comments)" {
 local awk_file="${SCRIPT_BASE_DIRECTORY}/awk/extract_comments.awk"
 local output_file="${TMP_DIR}/test_comments_order.csv"
 local sql_file="${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_31_loadApiNotes.sql"

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
 local sql_file="${SCRIPT_BASE_DIRECTORY}/sql/process/processAPINotes_31_loadApiNotes.sql"

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

@test "CSV column order should match SQL COPY command expectations for Planet notes (processPlanetNotes_41)" {
 local awk_file="${SCRIPT_BASE_DIRECTORY}/awk/extract_notes.awk"
 local output_file="${TMP_DIR}/test_notes_planet_order.csv"
 local sql_file="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_41_loadPartitionedSyncNotes.sql"

 [ -f "${awk_file}" ]
 [ -f "${sql_file}" ]

 # Generate CSV using Planet format XML
 awk -f "${awk_file}" "${TMP_DIR}/test_planet_notes.xml" > "${output_file}"

 [ -s "${output_file}" ]

 # SQL expects: note_id, latitude, longitude, created_at, closed_at, status, id_country, part_id
 # Verify order by checking that closed_at (5th) comes before status (6th)
 local first_line
 first_line=$(head -1 "${output_file}" | tr -d '\r\n')

 # Extract fields
 local created_at
 local closed_at
 local status
 created_at=$(echo "${first_line}" | cut -d',' -f4)
 closed_at=$(echo "${first_line}" | cut -d',' -f5)
 status=$(echo "${first_line}" | cut -d',' -f6)

 # created_at should be a timestamp
 [[ "${created_at}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]]

 # closed_at should be empty or a timestamp (for open notes, it's empty)
 # CRITICAL: Must NOT be 'open' or 'close' (those belong in status column)
 if [[ -n "${closed_at}" ]]; then
  # If not empty, must be a timestamp
  [[ "${closed_at}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]]
  # Must NOT be status values
  [[ "${closed_at}" != "open" ]]
  [[ "${closed_at}" != "close" ]]
 fi

 # status should be 'open' or 'close' (and NOT empty, NOT a timestamp)
 [[ -n "${status}" ]] # Must not be empty
 [[ "${status}" =~ ^(open|close)$ ]]
 # Must NOT be a timestamp (if it is, columns are swapped)
 [[ ! "${status}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]]

 # Verify SQL file has correct column order
 local sql_content
 sql_content=$(cat "${sql_file}")
 # SQL should have closed_at before status in the COPY command
 [[ "${sql_content}" =~ COPY.*created_at.*closed_at.*status ]]
 # SQL should NOT have status before closed_at
 [[ ! "${sql_content}" =~ COPY.*created_at.*status.*closed_at ]]
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
