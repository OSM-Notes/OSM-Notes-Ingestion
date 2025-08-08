#!/usr/bin/env bats

# Tests for XSLT enum format validation
# Ensures enum values in CSV output don't have incorrect quotes
# 
# CRITICAL BUG FIX: This test suite validates the fix for PostgreSQL enum syntax error:
# ERROR: la sintaxis de entrada no es válida para el enum note_event_enum: «"opened"»
# 
# The fix ensures enum values (opened, commented, closed, reopened) are generated 
# WITHOUT quotes in CSV files, which is the correct format for PostgreSQL COPY command.
#
# Author: Andres Gomez (AngocA)
# Version: 2025-08-07

load "$(dirname "$BATS_TEST_FILENAME")/../../test_helper.bash"

# =============================================================================
# Test setup and teardown
# =============================================================================

setup() {
    # Set up test environment
    export TMP_DIR="/tmp/test_xslt_enum_$$"
    mkdir -p "${TMP_DIR}"
    
    # Set up test data directory
    export TEST_DATA_DIR="${TMP_DIR}/test_data"
    mkdir -p "${TEST_DATA_DIR}"
}

teardown() {
    # Clean up test files
    rm -rf "${TMP_DIR}" 2>/dev/null || true
}

# =============================================================================
# Helper functions for creating test XML data
# =============================================================================

create_api_test_xml() {
    local output_file="$1"
    cat > "${output_file}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6" generator="OpenStreetMap server">
  <note lat="40.7128" lon="-74.0060">
    <id>1234</id>
    <date_created>2023-01-01T12:00:00Z</date_created>
    <status>open</status>
    <comments>
      <comment>
        <date>2023-01-01T12:00:00Z</date>
        <uid>12345</uid>
        <user>testuser</user>
        <action>opened</action>
        <text>Test note opened</text>
      </comment>
      <comment>
        <date>2023-01-02T12:00:00Z</date>
        <uid>67890</uid>
        <user>anotheruser</user>
        <action>commented</action>
        <text>Test comment</text>
      </comment>
      <comment>
        <date>2023-01-03T12:00:00Z</date>
        <action>closed</action>
        <text>Anonymous close</text>
      </comment>
    </comments>
  </note>
</osm>
EOF
}

create_planet_test_xml() {
    local output_file="$1"
    cat > "${output_file}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
  <note id="1234" created_at="2023-01-01T12:00:00Z" lat="40.7128" lon="-74.0060">
    <comment action="opened" timestamp="2023-01-01T12:00:00Z" uid="12345" user="testuser">Test note opened</comment>
    <comment action="commented" timestamp="2023-01-02T12:00:00Z" uid="67890" user="anotheruser">Test comment</comment>
    <comment action="closed" timestamp="2023-01-03T12:00:00Z">Anonymous close</comment>
  </note>
</osm-notes>
EOF
}

# =============================================================================
# Test API XSLT enum format
# =============================================================================

@test "api_xslt_generates_enum_values_without_quotes" {
    # Skip if xsltproc is not available
    if ! command -v xsltproc >/dev/null 2>&1; then
        skip "xsltproc not available"
    fi
    
    local test_xml="${TEST_DATA_DIR}/api_test.xml"
    local output_csv="${TEST_DATA_DIR}/api_comments.csv"
    
    # Create test XML data
    create_api_test_xml "${test_xml}"
    
    # Transform using API XSLT
    run xsltproc "${TEST_BASE_DIR}/xslt/note_comments-API-csv.xslt" "${test_xml}"
    
    echo "Exit code: $status"
    echo "Output: $output"
    
    [ "$status" -eq 0 ]
    
    # Check that enum values don't have quotes around them
    [[ ! "$output" =~ \"opened\" ]]
    [[ ! "$output" =~ \"commented\" ]]
    [[ ! "$output" =~ \"closed\" ]]
    [[ ! "$output" =~ \"reopened\" ]]
    
    # But check that enum values ARE present without quotes
    [[ "$output" =~ ,opened, ]]
    [[ "$output" =~ ,commented, ]]
    [[ "$output" =~ ,closed, ]]
}

@test "api_xslt_handles_different_enum_values_correctly" {
    # Skip if xsltproc is not available
    if ! command -v xsltproc >/dev/null 2>&1; then
        skip "xsltproc not available"
    fi
    
    # Create XML with different action types
    local test_xml="${TEST_DATA_DIR}/api_enum_test.xml"
    cat > "${test_xml}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6" generator="OpenStreetMap server">
  <note lat="40.0" lon="-74.0">
    <id>1</id>
    <comments>
      <comment>
        <date>2023-01-01T12:00:00Z</date>
        <uid>1</uid>
        <user>user1</user>
        <action>opened</action>
      </comment>
      <comment>
        <date>2023-01-02T12:00:00Z</date>
        <uid>2</uid>
        <user>user2</user>
        <action>commented</action>
      </comment>
      <comment>
        <date>2023-01-03T12:00:00Z</date>
        <uid>3</uid>
        <user>user3</user>
        <action>reopened</action>
      </comment>
      <comment>
        <date>2023-01-04T12:00:00Z</date>
        <uid>4</uid>
        <user>user4</user>
        <action>closed</action>
      </comment>
    </comments>
  </note>
</osm>
EOF
    
    # Transform using API XSLT
    run xsltproc "${TEST_BASE_DIR}/xslt/note_comments-API-csv.xslt" "${test_xml}"
    
    echo "Exit code: $status"
    echo "Output: $output"
    
    [ "$status" -eq 0 ]
    
    # Verify all enum values are present without quotes
    local line_count=$(echo "$output" | wc -l)
    [ "$line_count" -eq 4 ]
    
    # Check each line has the correct format (no quotes around enum)
    echo "$output" | while IFS= read -r line; do
        [[ "$line" =~ ^[0-9]+,1,(opened|commented|reopened|closed), ]]
    done
}

# =============================================================================
# Test Planet XSLT enum format
# =============================================================================

@test "planet_xslt_generates_enum_values_without_quotes" {
    # Skip if xsltproc is not available
    if ! command -v xsltproc >/dev/null 2>&1; then
        skip "xsltproc not available"
    fi
    
    local test_xml="${TEST_DATA_DIR}/planet_test.xml"
    local output_csv="${TEST_DATA_DIR}/planet_comments.csv"
    
    # Create test XML data
    create_planet_test_xml "${test_xml}"
    
    # Transform using Planet XSLT
    run xsltproc "${TEST_BASE_DIR}/xslt/note_comments-Planet-csv.xslt" "${test_xml}"
    
    echo "Exit code: $status"
    echo "Output: $output"
    
    [ "$status" -eq 0 ]
    
    # Check that enum values don't have quotes around them
    [[ ! "$output" =~ \"opened\" ]]
    [[ ! "$output" =~ \"commented\" ]]
    [[ ! "$output" =~ \"closed\" ]]
    [[ ! "$output" =~ \"reopened\" ]]
    
    # But check that enum values ARE present without quotes
    [[ "$output" =~ ,opened, ]]
    [[ "$output" =~ ,commented, ]]
    [[ "$output" =~ ,closed, ]]
}

@test "planet_xslt_handles_different_enum_values_correctly" {
    # Skip if xsltproc is not available
    if ! command -v xsltproc >/dev/null 2>&1; then
        skip "xsltproc not available"
    fi
    
    # Create XML with different action types
    local test_xml="${TEST_DATA_DIR}/planet_enum_test.xml"
    cat > "${test_xml}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
  <note id="5678" created_at="2023-01-01T12:00:00Z" lat="41.0" lon="-75.0">
    <comment action="opened" timestamp="2023-01-01T12:00:00Z" uid="1" user="user1">Note opened</comment>
    <comment action="commented" timestamp="2023-01-02T12:00:00Z" uid="2" user="user2">Comment added</comment>
    <comment action="reopened" timestamp="2023-01-03T12:00:00Z" uid="3" user="user3">Note reopened</comment>
    <comment action="closed" timestamp="2023-01-04T12:00:00Z" uid="4" user="user4">Note closed</comment>
  </note>
</osm-notes>
EOF
    
    # Transform using Planet XSLT
    run xsltproc "${TEST_BASE_DIR}/xslt/note_comments-Planet-csv.xslt" "${test_xml}"
    
    echo "Exit code: $status"
    echo "Output: $output"
    
    [ "$status" -eq 0 ]
    
    # Verify all enum values are present without quotes
    local line_count=$(echo "$output" | wc -l)
    [ "$line_count" -eq 4 ]
    
    # Check each line has the correct format (no quotes around enum)
    echo "$output" | while IFS= read -r line; do
        [[ "$line" =~ ^[0-9]+,[0-9]+,(opened|commented|reopened|closed), ]]
    done
}

# =============================================================================
# Test CSV format validation for database import
# =============================================================================

@test "api_csv_format_is_compatible_with_postgresql_enum" {
    # Skip if xsltproc is not available
    if ! command -v xsltproc >/dev/null 2>&1; then
        skip "xsltproc not available"
    fi
    
    local test_xml="${TEST_DATA_DIR}/api_postgres_test.xml"
    create_api_test_xml "${test_xml}"
    
    # Transform and save to CSV file
    local csv_file="${TEST_DATA_DIR}/test_api_comments.csv"
    xsltproc "${TEST_BASE_DIR}/xslt/note_comments-API-csv.xslt" "${test_xml}" > "${csv_file}"
    
    # Verify the CSV file exists and has content
    [ -f "${csv_file}" ]
    [ -s "${csv_file}" ]
    
    # Check specific format: note_id,sequence,enum_value,"timestamp",user_id,"username"
    # The enum value should NOT be quoted
    run head -1 "${csv_file}"
    
    echo "First line: $output"
    
    # Should match pattern: number,number,enum_value,"timestamp",...
    [[ "$output" =~ ^[0-9]+,1,(opened|commented|closed|reopened),\"[^\"]+\" ]]
    
    # Verify no enum values are quoted
    ! grep -q ',"opened",' "${csv_file}"
    ! grep -q ',"commented",' "${csv_file}"
    ! grep -q ',"closed",' "${csv_file}"
    ! grep -q ',"reopened",' "${csv_file}"
}

@test "planet_csv_format_is_compatible_with_postgresql_enum" {
    # Skip if xsltproc is not available
    if ! command -v xsltproc >/dev/null 2>&1; then
        skip "xsltproc not available"
    fi
    
    local test_xml="${TEST_DATA_DIR}/planet_postgres_test.xml"
    create_planet_test_xml "${test_xml}"
    
    # Transform and save to CSV file
    local csv_file="${TEST_DATA_DIR}/test_planet_comments.csv"
    xsltproc "${TEST_BASE_DIR}/xslt/note_comments-Planet-csv.xslt" "${test_xml}" > "${csv_file}"
    
    # Verify the CSV file exists and has content
    [ -f "${csv_file}" ]
    [ -s "${csv_file}" ]
    
    # Check specific format: note_id,sequence,enum_value,"timestamp",user_id,"username"
    # The enum value should NOT be quoted
    run head -1 "${csv_file}"
    
    echo "First line: $output"
    
    # Should match pattern: number,number,enum_value,"timestamp",...
    [[ "$output" =~ ^[0-9]+,[0-9]+,(opened|commented|closed|reopened),\"[^\"]+\" ]]
    
    # Verify no enum values are quoted
    ! grep -q ',"opened",' "${csv_file}"
    ! grep -q ',"commented",' "${csv_file}"
    ! grep -q ',"closed",' "${csv_file}"
    ! grep -q ',"reopened",' "${csv_file}"
}

# =============================================================================
# Test error that was reported in the bug
# =============================================================================

@test "verify_fix_for_reported_enum_error" {
    # Skip if xsltproc is not available
    if ! command -v xsltproc >/dev/null 2>&1; then
        skip "xsltproc not available"
    fi
    
    # Create XML that would have caused the original error
    local test_xml="${TEST_DATA_DIR}/error_reproduction.xml"
    cat > "${test_xml}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6" generator="OpenStreetMap server">
  <note lat="40.0" lon="-74.0">
    <id>123</id>
    <comments>
      <comment>
        <date>2025-08-07T19:31:31Z</date>
        <uid>1</uid>
        <user>testuser</user>
        <action>opened</action>
      </comment>
    </comments>
  </note>
</osm>
EOF
    
    # Transform using corrected API XSLT
    run xsltproc "${TEST_BASE_DIR}/xslt/note_comments-API-csv.xslt" "${test_xml}"
    
    echo "Exit code: $status"
    echo "Output: $output"
    
    [ "$status" -eq 0 ]
    
    # The original error was: «"opened"» - enum with quotes
    # Now it should be: opened - enum without quotes
    [[ ! "$output" =~ \"opened\" ]]
    [[ "$output" =~ ,opened, ]]
    
    # Verify the exact format that should work with PostgreSQL
    [[ "$output" =~ ^123,1,opened,\"2025-08-07T19:31:31Z\",1,\"testuser\" ]]
}

# =============================================================================
# Test CSV format compliance with PostgreSQL COPY command
# =============================================================================

@test "csv_format_is_ready_for_postgresql_copy_command" {
    # Skip if xsltproc is not available
    if ! command -v xsltproc >/dev/null 2>&1; then
        skip "xsltproc not available"
    fi
    
    # Create comprehensive test data that covers all enum values
    local test_xml="${TEST_DATA_DIR}/postgresql_copy_test.xml"
    cat > "${test_xml}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6" generator="OpenStreetMap server">
  <note lat="40.0" lon="-74.0">
    <id>100</id>
    <comments>
      <comment>
        <date>2025-08-07T10:00:00Z</date>
        <uid>1001</uid>
        <user>user_opener</user>
        <action>opened</action>
        <text>Note opened</text>
      </comment>
      <comment>
        <date>2025-08-07T11:00:00Z</date>
        <uid>1002</uid>
        <user>user_commenter</user>
        <action>commented</action>
        <text>Added comment</text>
      </comment>
      <comment>
        <date>2025-08-07T12:00:00Z</date>
        <uid>1003</uid>
        <user>user_closer</user>
        <action>closed</action>
        <text>Closed note</text>
      </comment>
      <comment>
        <date>2025-08-07T13:00:00Z</date>
        <uid>1004</uid>
        <user>user_reopener</user>
        <action>reopened</action>
        <text>Reopened note</text>
      </comment>
    </comments>
  </note>
</osm>
EOF
    
    # Generate CSV using corrected XSLT
    run xsltproc "${TEST_BASE_DIR}/xslt/note_comments-API-csv.xslt" "${test_xml}"
    
    echo "Exit code: $status"
    echo "Output: $output"
    
    [ "$status" -eq 0 ]
    
    # Verify each line has the correct PostgreSQL COPY format:
    # note_id,sequence,enum_value,"timestamp",user_id,"username"
    local expected_format="^[0-9]+,1,(opened|commented|closed|reopened),\"[^\"]+\",[0-9]+,\"[^\"]+\"$"
    
    echo "$output" | while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            [[ "$line" =~ $expected_format ]]
        fi
    done
    
    # Specifically verify the exact format for each enum value
    [[ "$output" =~ 100,1,opened, ]]
    [[ "$output" =~ 100,1,commented, ]]
    [[ "$output" =~ 100,1,closed, ]]
    [[ "$output" =~ 100,1,reopened, ]]
    
    # Ensure NO enum values have quotes (the original bug)
    ! echo "$output" | grep -q ',"opened",'
    ! echo "$output" | grep -q ',"commented",'
    ! echo "$output" | grep -q ',"closed",'
    ! echo "$output" | grep -q ',"reopened",'
    
    # Verify line count matches expected comments
    local line_count=$(echo "$output" | wc -l)
    [ "$line_count" -eq 4 ]
}
