#!/usr/bin/env bats

# Test XSLT enum validation to prevent empty values
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
 TEST_DIR=$(mktemp -d "${TMP_DIR}/xslt_enum_test_XXXXXX")
 export TEST_DIR
 
 # Define XSLT file path
 XSLT_FILE="${SCRIPT_BASE_DIRECTORY}/xslt/note_comments-API-csv.xslt"
 
 # Create test XML files
 create_test_xml_files
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

# Create test XML files with various scenarios
create_test_xml_files() {
 # Normal XML with all attributes
 cat > "${TEST_DIR}/normal.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6" generator="OpenStreetMap server">
 <note id="123" lat="40.4168" lon="-3.7038" created_at="2025-07-14T13:39:25Z">
  <comments>
   <comment uid="456" user="testuser" action="opened" date="2025-07-14T13:39:25Z">
    Test comment
   </comment>
   <comment uid="789" user="anotheruser" action="commented" date="2025-07-14T13:45:00Z">
    Another comment
   </comment>
   <comment uid="101" user="closer" action="closed" date="2025-07-14T14:30:00Z">
    Closing comment
   </comment>
  </comments>
 </note>
</osm>
EOF

 # XML with missing action attribute
 cat > "${TEST_DIR}/missing_action.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6" generator="OpenStreetMap server">
 <note id="123" lat="40.4168" lon="-3.7038" created_at="2025-07-14T13:39:25Z">
  <comments>
   <comment uid="456" user="testuser" date="2025-07-14T13:39:25Z">
    Comment without action
   </comment>
  </comments>
 </note>
</osm>
EOF

 # XML with empty action attribute
 cat > "${TEST_DIR}/empty_action.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6" generator="OpenStreetMap server">
 <note id="123" lat="40.4168" lon="-3.7038" created_at="2025-07-14T13:39:25Z">
  <comments>
   <comment uid="456" user="testuser" action="" date="2025-07-14T13:39:25Z">
    Comment with empty action
   </comment>
  </comments>
 </note>
</osm>
EOF

 # XML with invalid action values
 cat > "${TEST_DIR}/invalid_action.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6" generator="OpenStreetMap server">
 <note id="123" lat="40.4168" lon="-3.7038" created_at="2025-07-14T13:39:25Z">
  <comments>
   <comment uid="456" user="testuser" action="invalid_action" date="2025-07-14T13:39:25Z">
    Comment with invalid action
   </comment>
  </comments>
 </note>
</osm>
EOF
}

@test "XSLT handles normal comments correctly" {
 # Skip if xsltproc is not available
 if ! command -v xsltproc >/dev/null 2>&1; then
  skip "xsltproc not available"
 fi
 
 # Process XML with XSLT
 xsltproc "${XSLT_FILE}" "${TEST_DIR}/normal.xml" > "${TEST_DIR}/normal.csv"
 
 # Check that file was created and has content
 [ -f "${TEST_DIR}/normal.csv" ]
 [ -s "${TEST_DIR}/normal.csv" ]
 
 # Check that each line has valid action values
 while IFS= read -r line; do
  # Extract action value (3rd field)
  local ACTION
  ACTION=$(echo "$line" | cut -d',' -f3 | tr -d '"')
  
  # Action should not be empty
  [[ -n "${ACTION}" ]]
  
  # Action should be one of the valid enum values
  [[ "${ACTION}" =~ ^(opened|closed|reopened|commented|hidden)$ ]]
 done < "${TEST_DIR}/normal.csv"
}

@test "XSLT handles missing action attribute" {
 # Skip if xsltproc is not available
 if ! command -v xsltproc >/dev/null 2>&1; then
  skip "xsltproc not available"
 fi
 
 # Process XML with XSLT
 xsltproc "${XSLT_FILE}" "${TEST_DIR}/missing_action.xml" > "${TEST_DIR}/missing_action.csv"
 
 # Check that file was created and has content
 [ -f "${TEST_DIR}/missing_action.csv" ]
 [ -s "${TEST_DIR}/missing_action.csv" ]
 
 # Check that action defaults to "opened"
 local FIRST_LINE
 FIRST_LINE=$(head -n 1 "${TEST_DIR}/missing_action.csv")
 
 # Extract action value (3rd field)
 local ACTION
 ACTION=$(echo "$FIRST_LINE" | cut -d',' -f3 | tr -d '"')
 
 # Should default to "opened"
 [[ "${ACTION}" = "opened" ]]
}

@test "XSLT handles empty action attribute" {
 # Skip if xsltproc is not available
 if ! command -v xsltproc >/dev/null 2>&1; then
  skip "xsltproc not available"
 fi
 
 # Process XML with XSLT
 xsltproc "${XSLT_FILE}" "${TEST_DIR}/empty_action.xml" > "${TEST_DIR}/empty_action.csv"
 
 # Check that file was created and has content
 [ -f "${TEST_DIR}/empty_action.csv" ]
 [ -s "${TEST_DIR}/empty_action.csv" ]
 
 # Check that action defaults to "opened"
 local FIRST_LINE
 FIRST_LINE=$(head -n 1 "${TEST_DIR}/empty_action.csv")
 
 # Extract action value (3rd field)
 local ACTION
 ACTION=$(echo "$FIRST_LINE" | cut -d',' -f3 | tr -d '"')
 
 # Should default to "opened"
 [[ "${ACTION}" = "opened" ]]
}

@test "XSLT validates action values against enum" {
 # Define valid enum values
 local VALID_ACTIONS=("opened" "closed" "reopened" "commented" "hidden")
 
 # Process XML with XSLT
 xsltproc "${XSLT_FILE}" "${TEST_DIR}/normal.xml" > "${TEST_DIR}/validation.csv"
 
 # Check that file was created and has content
 [ -f "${TEST_DIR}/validation.csv" ]
 [ -s "${TEST_DIR}/validation.csv" ]
 
 # Check that each action value is valid
 while IFS= read -r line; do
  # Extract action value (3rd field)
  local ACTION
  ACTION=$(echo "$line" | cut -d',' -f3 | tr -d '"')
  
  # Action should not be empty
  [[ -n "${ACTION}" ]]
  
  # Action should be in valid enum values
  local IS_VALID=false
  for valid_action in "${VALID_ACTIONS[@]}"; do
   if [[ "${ACTION}" = "${valid_action}" ]]; then
    IS_VALID=true
    break
   fi
  done
  
  [[ "${IS_VALID}" = "true" ]]
 done < "${TEST_DIR}/validation.csv"
}

@test "XSLT generates consistent CSV format" {
 # Process XML with XSLT
 xsltproc "${XSLT_FILE}" "${TEST_DIR}/normal.xml" > "${TEST_DIR}/format.csv"
 
 # Check that file was created and has content
 [ -f "${TEST_DIR}/format.csv" ]
 [ -s "${TEST_DIR}/format.csv" ]
 
 # Check that each line has the correct format
 while IFS= read -r line; do
  # Count commas to verify 5 columns (4 commas = 5 fields)
  local COMMA_COUNT
  COMMA_COUNT=$(echo "$line" | tr -cd ',' | wc -c)
  [ "${COMMA_COUNT}" -eq 4 ]
  
  # Check that action field is properly quoted
  local ACTION_FIELD
  ACTION_FIELD=$(echo "$line" | cut -d',' -f3)
  # Check that action field is NOT quoted (PostgreSQL enum compatibility fix)
  [[ "${ACTION_FIELD}" =~ ^[^\"]+$ ]]
 done < "${TEST_DIR}/format.csv"
}

@test "XSLT handles edge cases gracefully" {
 # Create XML with various edge cases
 cat > "${TEST_DIR}/edge_cases.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6" generator="OpenStreetMap server">
 <note id="123" lat="40.4168" lon="-3.7038" created_at="2025-07-14T13:39:25Z">
  <comments>
   <comment uid="456" user="testuser" action="opened" date="2025-07-14T13:39:25Z">
    Normal comment
   </comment>
   <comment date="2025-07-14T13:45:00Z">
    Anonymous comment without action
   </comment>
   <comment uid="789" user="anotheruser" action="commented" date="2025-07-14T14:00:00Z">
    Comment with action
   </comment>
  </comments>
 </note>
</osm>
EOF
 
 # Process XML with XSLT
 xsltproc "${XSLT_FILE}" "${TEST_DIR}/edge_cases.xml" > "${TEST_DIR}/edge_cases.csv"
 
 # Check that file was created and has content
 [ -f "${TEST_DIR}/edge_cases.csv" ]
 [ -s "${TEST_DIR}/edge_cases.csv" ]
 
 # Check that all lines have valid actions
 while IFS= read -r line; do
  # Extract action value (3rd field)
  local ACTION
  ACTION=$(echo "$line" | cut -d',' -f3 | tr -d '"')
  
  # Action should not be empty and should be valid
  [[ -n "${ACTION}" ]]
  [[ "${ACTION}" =~ ^(opened|closed|reopened|commented|hidden)$ ]]
 done < "${TEST_DIR}/edge_cases.csv"
 
 # Should have processed all comments (count lines)
 local LINE_COUNT
 LINE_COUNT=$(wc -l < "${TEST_DIR}/edge_cases.csv")
 [ "${LINE_COUNT}" -eq 3 ]
} 