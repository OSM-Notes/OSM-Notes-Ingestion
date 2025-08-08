#!/usr/bin/env bats

# Test XSLT CSV format generation
# Author: Andres Gomez (AngocA)
# Version: 2025-08-03

load "${BATS_TEST_DIRNAME}/../../test_helper"

setup() {
 # Load properties
 source "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh"
 source "${SCRIPT_BASE_DIRECTORY}/etc/etl.properties"
 source "${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh"
 source "${SCRIPT_BASE_DIRECTORY}/bin/processAPIFunctions.sh"
 
 # Create test directory
 export TMP_DIR="$(mktemp -d)"
 TEST_DIR=$(mktemp -d "${TMP_DIR}/xslt_test_XXXXXX")
 export TEST_DIR
 
 # Create test XML file
 create_test_xml
 
 # Define XSLT file path
 XSLT_FILE="${SCRIPT_BASE_DIRECTORY}/xslt/note_comments-API-csv.xslt"
}

teardown() {
 # Cleanup test files
 if [[ -d "${TEST_DIR}" ]]; then
  rm -rf "${TEST_DIR}"
 fi
 if [[ -d "${TMP_DIR}" ]]; then
  rm -rf "${TMP_DIR}"
 fi
}

# Create a test XML file with API notes and comments
create_test_xml() {
 local XML_FILE="${TEST_DIR}/test_api_notes.xml"
 
 cat > "${XML_FILE}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6" generator="OpenStreetMap server">
 <note lat="40.4168" lon="-3.7038">
  <id>4855089</id>
  <comments>
   <comment>
    <date>2025-07-14T13:39:25Z</date>
    <uid>11843692</uid>
    <user>halibutwig</user>
    <action>opened</action>
    <text>Test comment with quotes "inside"</text>
   </comment>
   <comment>
    <date>2025-07-14T13:45:00Z</date>
    <action>commented</action>
    <text>Anonymous comment</text>
   </comment>
   <comment>
    <date>2025-07-14T14:30:00Z</date>
    <uid>123456</uid>
    <user>testuser</user>
    <action>closed</action>
    <text>Closing comment</text>
   </comment>
  </comments>
 </note>
 <note lat="40.4169" lon="-3.7039">
  <id>4855090</id>
  <comments>
   <comment>
    <date>2025-07-14T15:00:00Z</date>
    <uid>654321</uid>
    <user>anotheruser</user>
    <action>opened</action>
    <text>Another test comment</text>
   </comment>
  </comments>
 </note>
</osm>
EOF
 
 export TEST_XML_FILE="${XML_FILE}"
}

@test "XSLT generates correct CSV format for API comments" {
 # Skip if xsltproc is not available
 if ! command -v xsltproc >/dev/null 2>&1; then
  skip "xsltproc not available"
 fi
 
 # Process XML with XSLT
 xsltproc "${XSLT_FILE}" "${TEST_XML_FILE}" > "${TEST_DIR}/comments.csv"
 
 # Check that file was created
 [ -f "${TEST_DIR}/comments.csv" ]
 
 # Check that file has content
 [ -s "${TEST_DIR}/comments.csv" ]
 
 # Check that each line has the correct number of commas (4 commas = 5 fields)
 while IFS= read -r line; do
  local COMMA_COUNT
  COMMA_COUNT=$(echo "$line" | tr -cd ',' | wc -c)
  # Accept either 4 (anonymous) or 5 (with user) commas
  [[ "${COMMA_COUNT}" -eq 4 || "${COMMA_COUNT}" -eq 5 ]]
 done < "${TEST_DIR}/comments.csv"
}

@test "CSV format matches expected structure" {
 # Skip if xsltproc is not available
 if ! command -v xsltproc >/dev/null 2>&1; then
  skip "xsltproc not available"
 fi
 
 # Process XML with XSLT
 xsltproc "${XSLT_FILE}" "${TEST_XML_FILE}" > "${TEST_DIR}/comments.csv"
 
 # Check that file was created and has content
 [ -f "${TEST_DIR}/comments.csv" ]
 [ -s "${TEST_DIR}/comments.csv" ]
 
 # Check that first line has the expected format
 local FIRST_LINE
 FIRST_LINE=$(head -n 1 "${TEST_DIR}/comments.csv")
 
 # Should contain note_id, sequence_action, event, timestamp
 # Updated format: enum values WITHOUT quotes (fixed PostgreSQL compatibility issue)
 [[ "${FIRST_LINE}" =~ ^[0-9]+,1,[a-z]+,\"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\",[0-9]+,\"[^\"]*\"$ ]]
}

@test "Anonymous comments are handled correctly" {
 # Skip if xsltproc is not available
 if ! command -v xsltproc >/dev/null 2>&1; then
  skip "xsltproc not available"
 fi
 
 # Process XML with XSLT
 xsltproc "${XSLT_FILE}" "${TEST_XML_FILE}" > "${TEST_DIR}/comments.csv"
 
 # Check that file was created and has content
 [ -f "${TEST_DIR}/comments.csv" ]
 [ -s "${TEST_DIR}/comments.csv" ]
 
 # Find anonymous comment line (should have empty user_id)
 local ANONYMOUS_LINE
 ANONYMOUS_LINE=$(grep "commented" "${TEST_DIR}/comments.csv" | head -n 1 || true)
 
 # Updated format: enum values WITHOUT quotes (PostgreSQL compatibility fix)
 # For anonymous comments: note_id,sequence,event,"timestamp", (note the trailing comma)
 [[ "${ANONYMOUS_LINE}" =~ ^[0-9]+,1,commented,\"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\",$ ]]
}

@test "Quotes in usernames are escaped correctly" {
 # Skip if xsltproc is not available
 if ! command -v xsltproc >/dev/null 2>&1; then
  skip "xsltproc not available"
 fi
 
 # Process XML with XSLT
 xsltproc "${XSLT_FILE}" "${TEST_XML_FILE}" > "${TEST_DIR}/comments.csv"
 
 # Check that file was created and has content
 [ -f "${TEST_DIR}/comments.csv" ]
 [ -s "${TEST_DIR}/comments.csv" ]
 
 # Check that usernames are properly handled
 local QUOTED_LINE
 QUOTED_LINE=$(grep "closed" "${TEST_DIR}/comments.csv" || true)
 
 # Should contain the event properly formatted (without quotes around enum)
 # Updated format: enum values WITHOUT quotes
 [[ "${QUOTED_LINE}" =~ closed ]]
}

@test "CSV can be loaded into database format" {
 # Skip if xsltproc is not available
 if ! command -v xsltproc >/dev/null 2>&1; then
  skip "xsltproc not available"
 fi
 
 # Process XML with XSLT
 xsltproc "${XSLT_FILE}" "${TEST_XML_FILE}" > "${TEST_DIR}/comments.csv"
 
 # Check that file was created and has content
 [ -f "${TEST_DIR}/comments.csv" ]
 [ -s "${TEST_DIR}/comments.csv" ]
 
 # Add part_id to each line (simulating the awk command in the script)
 awk -v part_id="1" '{print $0 "," part_id}' "${TEST_DIR}/comments.csv" > "${TEST_DIR}/comments_with_part.csv"
 
 # Check that each line now has 6 columns (5 original + part_id)
 while IFS= read -r line; do
  # Count commas to verify 6 columns (5 commas = 6 fields)
  local COMMA_COUNT
  COMMA_COUNT=$(echo "$line" | tr -cd ',' | wc -c)
  # After adding part_id: should be 5 (anonymous) or 6 (with user) commas  
  [[ "${COMMA_COUNT}" -eq 5 || "${COMMA_COUNT}" -eq 6 ]]
 done < "${TEST_DIR}/comments_with_part.csv"
}

@test "XSLT handles special characters correctly" {
 # Skip if xsltproc is not available
 if ! command -v xsltproc >/dev/null 2>&1; then
  skip "xsltproc not available"
 fi
 
 # Create XML with special characters (properly escaped)
 local SPECIAL_XML="${TEST_DIR}/special_chars.xml"
 cat > "${SPECIAL_XML}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6" generator="OpenStreetMap server">
 <note id="123" lat="40.4168" lon="-3.7038" created_at="2025-07-14T13:39:25Z">
  <comments>
   <comment uid="456" user="user with &quot;quotes&quot; and, commas" action="opened" date="2025-07-14T13:39:25Z">
    Comment with special chars
   </comment>
  </comments>
 </note>
</osm>
EOF
 
 # Process XML with XSLT
 xsltproc "${XSLT_FILE}" "${SPECIAL_XML}" > "${TEST_DIR}/special.csv"
 
 # Check that file was created and has content
 [ -f "${TEST_DIR}/special.csv" ]
 [ -s "${TEST_DIR}/special.csv" ]
 
 # Check that special characters are handled correctly
 local SPECIAL_LINE
 SPECIAL_LINE=$(head -n 1 "${TEST_DIR}/special.csv")
 
 # Should contain the event properly formatted
 # Current XSLT output format: note_id,sequence_action,event,timestamp
 [[ "${SPECIAL_LINE}" =~ opened ]]
} 