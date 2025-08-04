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
 <note id="4855089" lat="40.4168" lon="-3.7038" created_at="2025-07-14T13:39:25Z" closed_at="2025-07-14T14:30:00Z">
  <comments>
   <comment uid="11843692" user="halibutwig" action="opened" date="2025-07-14T13:39:25Z">
    Test comment with quotes "inside"
   </comment>
   <comment action="commented" date="2025-07-14T13:45:00Z">
    Anonymous comment
   </comment>
   <comment uid="123456" user="testuser" action="closed" date="2025-07-14T14:30:00Z">
    Closing comment
   </comment>
  </comments>
 </note>
 <note id="4855090" lat="40.4169" lon="-3.7039" created_at="2025-07-14T15:00:00Z">
  <comments>
   <comment uid="654321" user="anotheruser" action="opened" date="2025-07-14T15:00:00Z">
    Another test comment
   </comment>
  </comments>
 </note>
</osm>
EOF
 
 export TEST_XML_FILE="${XML_FILE}"
}

@test "XSLT generates correct CSV format for API comments" {
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
  [ "${COMMA_COUNT}" -eq 4 ]
 done < "${TEST_DIR}/comments.csv"
}

@test "CSV format matches expected structure" {
 # Process XML with XSLT
 xsltproc "${XSLT_FILE}" "${TEST_XML_FILE}" > "${TEST_DIR}/comments.csv"
 
 # Check that file was created and has content
 [ -f "${TEST_DIR}/comments.csv" ]
 [ -s "${TEST_DIR}/comments.csv" ]
 
 # Check that first line has the expected format
 local FIRST_LINE
 FIRST_LINE=$(head -n 1 "${TEST_DIR}/comments.csv")
 
 # Should contain note_id, sequence_action, event, timestamp
 [[ "${FIRST_LINE}" =~ ^[0-9]+,1,\"[a-z]+\",\"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\",$ ]]
}

@test "Anonymous comments are handled correctly" {
 # Process XML with XSLT
 xsltproc "${XSLT_FILE}" "${TEST_XML_FILE}" > "${TEST_DIR}/comments.csv"
 
 # Check that file was created and has content
 [ -f "${TEST_DIR}/comments.csv" ]
 [ -s "${TEST_DIR}/comments.csv" ]
 
 # Find anonymous comment line (should have empty user_id)
 local ANONYMOUS_LINE
 ANONYMOUS_LINE=$(grep "Anonymous comment" "${TEST_DIR}/comments.csv" || true)
 
 # Should have empty user_id field (two consecutive commas)
 [[ "${ANONYMOUS_LINE}" =~ ,, ]]
}

@test "Quotes in usernames are escaped correctly" {
 # Process XML with XSLT
 xsltproc "${XSLT_FILE}" "${TEST_XML_FILE}" > "${TEST_DIR}/comments.csv"
 
 # Check that file was created and has content
 [ -f "${TEST_DIR}/comments.csv" ]
 [ -s "${TEST_DIR}/comments.csv" ]
 
 # Check that quotes are properly escaped
 local QUOTED_LINE
 QUOTED_LINE=$(grep "halibutwig" "${TEST_DIR}/comments.csv" || true)
 
 # Should contain escaped quotes
 [[ "${QUOTED_LINE}" =~ \"\" ]]
}

@test "CSV can be loaded into database format" {
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
  [ "${COMMA_COUNT}" -eq 5 ]
 done < "${TEST_DIR}/comments_with_part.csv"
}

@test "XSLT handles special characters correctly" {
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
 
 # Check that quotes are properly escaped
 local SPECIAL_LINE
 SPECIAL_LINE=$(head -n 1 "${TEST_DIR}/special.csv")
 
 # Should contain escaped quotes
 [[ "${SPECIAL_LINE}" =~ \"\" ]]
} 