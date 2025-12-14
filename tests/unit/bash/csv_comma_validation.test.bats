#!/usr/bin/env bats

# CSV Comma Validation Tests
# Tests for CSV validation with commas in text
# Author: Andres Gomez (AngocA)
# Version: 2025-12-09

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
}

teardown() {
 rm -rf "${TMP_DIR}"
}

@test "CSV validation function should accept valid CSV with commas in text" {
 # Source the validation function
 source "${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh"

 local awk_file="${SCRIPT_BASE_DIRECTORY}/awk/extract_comment_texts.awk"
 local output_file="${TMP_DIR}/test_text_comments_for_validation.csv"

 [ -f "${awk_file}" ]

 # Generate CSV with commas in text
 awk -f "${awk_file}" "${TMP_DIR}/test_api_notes_with_commas.xml" > "${output_file}"

 [ -f "${output_file}" ]
 [ -s "${output_file}" ]

 # Validate CSV structure using the actual validation function
 # Note: This requires proper environment setup
 export LOG_LEVEL="INFO"

 # Source bash_logger if available, otherwise mock logging functions
 if [[ -f "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/bash_logger.sh" ]]; then
  source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/bash_logger.sh"
 else
  # Mock the logging functions if not available
  function __logi() { :; }
  function __logd() { :; }
  function __loge() { echo "ERROR: $*" >&2; }
  function __logw() { echo "WARN: $*" >&2; }
  function __log_start() { :; }
  function __log_finish() { :; }
 fi

 # Run validation
 run __validate_csv_structure "${output_file}" "text"

 # Validation should pass (exit code 0)
 [ "${status}" -eq 0 ]
}

@test "CSV with commas should be parseable by Python CSV parser" {
 local awk_file="${SCRIPT_BASE_DIRECTORY}/awk/extract_comment_texts.awk"
 local output_file="${TMP_DIR}/test_text_comments_parseable.csv"

 [ -f "${awk_file}" ]

 # Generate CSV
 awk -f "${awk_file}" "${TMP_DIR}/test_api_notes_with_commas.xml" > "${output_file}"

 [ -f "${output_file}" ]
 [ -s "${output_file}" ]

 # Validate CSV can be parsed by Python CSV parser
 python3 -c "
import csv
import sys

errors = []
with open('${output_file}', 'r', encoding='utf-8') as f:
    reader = csv.reader(f)
    for line_num, row in enumerate(reader, 1):
        if len(row) != 4:
            errors.append(f'Line {line_num}: Expected 4 fields, got {len(row)}')
            errors.append(f'  Content: {row}')

if errors:
    for error in errors:
        print(error, file=sys.stderr)
    sys.exit(1)
else:
    print('OK')
" > /dev/null 2>&1

 [ $? -eq 0 ]
}

@test "CSV with commas should maintain correct field count after adding part_id" {
 local awk_file="${SCRIPT_BASE_DIRECTORY}/awk/extract_comment_texts.awk"
 local output_file="${TMP_DIR}/test_text_comments_before_partid.csv"
 local output_with_partid="${TMP_DIR}/test_text_comments_with_partid.csv"
 local part_id="1"

 [ -f "${awk_file}" ]

 # Generate CSV
 awk -f "${awk_file}" "${TMP_DIR}/test_api_notes_with_commas.xml" > "${output_file}"

 [ -f "${output_file}" ]
 [ -s "${output_file}" ]

 # Add part_id (simulating the process that adds part_id)
 # The CSV ends with a trailing comma (empty field), we remove it and add ,part_id
 # Format: note_id,sequence_action,"body",part_id
 # Note: The CSV from AWK ends with , (empty 4th field), we use gsub to remove trailing comma and add ,part_id
 # This matches the actual code in functionsProcess.sh line 631
 awk -v part_id="${part_id}" '{gsub(/,$/, ""); print $0 "," part_id}' "${output_file}" > "${output_with_partid}"

 [ -f "${output_with_partid}" ]
 [ -s "${output_with_partid}" ]

 # Validate field count after adding part_id (should still be 4)
 # Note: The CSV before part_id has 4 fields (last is empty), after adding part_id it should still be 4
 validate_csv_field_count "${output_with_partid}" 4 "Text comments with part_id added"

 # Verify part_id was added correctly
 local first_line
 first_line=$(head -1 "${output_with_partid}")

 # Should end with the part_id value (after the quoted body field)
 # Format: note_id,sequence_action,"body",part_id
 # The part_id should be after the closing quote of the body field
 [[ "${first_line}" =~ .*\",${part_id}$ ]]
}

@test "All CSV lines should have consistent field count with commas in text" {
 local awk_file="${SCRIPT_BASE_DIRECTORY}/awk/extract_comment_texts.awk"
 local output_file="${TMP_DIR}/test_text_comments_consistent.csv"

 [ -f "${awk_file}" ]

 # Generate CSV
 awk -f "${awk_file}" "${TMP_DIR}/test_api_notes_with_commas.xml" > "${output_file}"

 [ -f "${output_file}" ]
 [ -s "${output_file}" ]

 # Check all lines have the same field count
 local field_counts
 field_counts=$(python3 -c "
import csv
with open('${output_file}', 'r', encoding='utf-8') as f:
    reader = csv.reader(f)
    counts = [len(row) for row in reader]
    print(' '.join(map(str, counts)))
" 2>/dev/null)

 # All counts should be 4
 local invalid_lines
 invalid_lines=$(echo "${field_counts}" | tr ' ' '\n' | grep -v "^4$" | wc -l)

 [ "${invalid_lines}" -eq 0 ]
}

@test "CSV with multiline text should be parseable by Python CSV parser" {
 local awk_file="${SCRIPT_BASE_DIRECTORY}/awk/extract_comment_texts.awk"
 local output_file="${TMP_DIR}/test_text_comments_multiline_parseable.csv"

 [ -f "${awk_file}" ]

 # Generate CSV with multiline text
 awk -f "${awk_file}" "${TMP_DIR}/test_api_notes_with_commas.xml" > "${output_file}"

 [ -f "${output_file}" ]
 [ -s "${output_file}" ]

 # Validate CSV can be parsed by Python CSV parser (handles multiline correctly)
 python3 -c "
import csv
import sys

errors = []
with open('${output_file}', 'r', encoding='utf-8') as f:
    reader = csv.reader(f)
    for line_num, row in enumerate(reader, 1):
        if len(row) != 4:
            errors.append(f'Line {line_num}: Expected 4 fields, got {len(row)}')
            errors.append(f'  Content: {row}')

if errors:
    for error in errors:
        print(error, file=sys.stderr)
    sys.exit(1)
else:
    print('OK')
" > /dev/null 2>&1

 [ $? -eq 0 ]
}

@test "CSV with quotes and commas should maintain text integrity" {
 local awk_file="${SCRIPT_BASE_DIRECTORY}/awk/extract_comment_texts.awk"
 local output_file="${TMP_DIR}/test_text_comments_quotes_integrity.csv"

 [ -f "${awk_file}" ]

 # Generate CSV
 awk -f "${awk_file}" "${TMP_DIR}/test_api_notes_with_commas.xml" > "${output_file}"

 [ -f "${output_file}" ]
 [ -s "${output_file}" ]

 # Extract text from CSV and verify quotes are preserved
 python3 -c "
import csv
import sys

with open('${output_file}', 'r', encoding='utf-8') as f:
    reader = csv.reader(f)
    for row in reader:
        if len(row) >= 3:
            body = row[2]
            # Check if text contains both single and double quotes
            if \"single quotes\" in body.lower() and \"double quotes\" in body.lower():
                if \"'\" not in body or '\"' not in body:
                    print(f'ERROR: Quotes not preserved in text: {body}', file=sys.stderr)
                    sys.exit(1)
                print('OK')
                break
" > /dev/null 2>&1

 [ $? -eq 0 ]
}

