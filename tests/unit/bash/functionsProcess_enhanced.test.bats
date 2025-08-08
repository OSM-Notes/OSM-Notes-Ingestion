#!/usr/bin/env bats

# Enhanced unit tests for functionsProcess.sh with improved testability
# Tests XML counting functions, validation, error handling, and performance
# Author: Andres Gomez (AngocA)
# Version: 2025-01-15

load "$(dirname "$BATS_TEST_FILENAME")/../../test_helper.bash"

# =============================================================================
# Test setup and teardown
# =============================================================================

setup() {
    # Create test XML files for different scenarios
    create_test_xml_files
    
    # Set up required environment variables for functionsProcess.sh
    export BASENAME="test"
    export TMP_DIR="/tmp/test_$$"
    export DBNAME="${TEST_DBNAME:-test_db}"
    export SCRIPT_BASE_DIRECTORY="${TEST_BASE_DIR}"
    export LOG_FILENAME="/tmp/test.log"
    export LOCK="/tmp/test.lock"
    export MAX_THREADS="2"
    
    # Unset any existing readonly variables that might conflict
    unset ERROR_HELP_MESSAGE ERROR_PREVIOUS_EXECUTION_FAILED ERROR_CREATING_REPORT ERROR_MISSING_LIBRARY ERROR_INVALID_ARGUMENT ERROR_LOGGER_UTILITY ERROR_DOWNLOADING_BOUNDARY_ID_LIST ERROR_NO_LAST_UPDATE ERROR_PLANET_PROCESS_IS_RUNNING ERROR_DOWNLOADING_NOTES ERROR_EXECUTING_PLANET_DUMP ERROR_DOWNLOADING_BOUNDARY ERROR_GEOJSON_CONVERSION ERROR_INTERNET_ISSUE ERROR_GENERAL 2>/dev/null || true
    
    # Source the functions to be tested
    source "${TEST_BASE_DIR}/bin/functionsProcess.sh"
    
    # Set up logging function if not available
    if ! declare -f log_info >/dev/null; then
        log_info() { echo "[INFO] $*"; }
        log_error() { echo "[ERROR] $*"; }
        log_start() { echo "[START] $*"; }
        log_finish() { echo "[FINISH] $*"; }
    fi
}

teardown() {
    # Clean up test files to avoid interference between tests
    rm -f "${TEST_BASE_DIR}/tests/tmp/test_*.xml"
}

# =============================================================================
# Helper functions for testing
# =============================================================================

create_test_xml_files() {
    local test_dir="${TEST_BASE_DIR}/tests/tmp"
    mkdir -p "${test_dir}"
    
    # Create test API XML with multiple notes for comprehensive testing
    cat > "${test_dir}/test_api.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6" generator="OpenStreetMap server" copyright="OpenStreetMap and contributors" attribution="http://www.openstreetmap.org/copyright" license="http://opendatacommons.org/licenses/odbl/1-0/">
  <note lon="-3.7038" lat="40.4168">
    <id>123456</id>
    <url>https://api.openstreetmap.org/api/0.6/notes/123456.xml</url>
    <date_created>2025-01-15 10:30:00 UTC</date_created>
    <status>closed</status>
    <comments>
      <comment>
        <date>2025-01-15 10:30:00 UTC</date>
        <uid>123</uid>
        <user>testuser</user>
        <action>opened</action>
        <text>Test note</text>
        <html>&lt;p&gt;Test note&lt;/p&gt;</html>
      </comment>
    </comments>
  </note>
  <note lon="-3.7039" lat="40.4169">
    <id>123457</id>
    <url>https://api.openstreetmap.org/api/0.6/notes/123457.xml</url>
    <date_created>2025-01-15 11:30:00 UTC</date_created>
    <status>open</status>
    <comments>
      <comment>
        <date>2025-01-15 11:30:00 UTC</date>
        <uid>456</uid>
        <user>testuser2</user>
        <action>opened</action>
        <text>Test note 2</text>
        <html>&lt;p&gt;Test note 2&lt;/p&gt;</html>
      </comment>
    </comments>
  </note>
</osm>
EOF

    # Create test Planet XML with single note for format-specific testing
    cat > "${test_dir}/test_planet.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
  <note id="123456" created_at="2025-01-15T10:30:00Z" lat="40.4168" lon="-3.7038">
    <comment action="opened" timestamp="2025-01-15T10:30:00Z" uid="123" user="testuser">Test note</comment>
  </note>
</osm-notes>
EOF

    # Create empty XML
    cat > "${test_dir}/test_empty.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6" generator="OpenStreetMap server" copyright="OpenStreetMap and contributors" attribution="http://www.openstreetmap.org/copyright" license="http://opendatacommons.org/licenses/odbl/1-0/">
</osm>
EOF

    # Create invalid XML
    cat > "${test_dir}/test_invalid.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6">
  <invalid-tag>
    This is not valid XML for notes
  </invalid-tag>
</osm>
EOF
}

# =============================================================================
# Enhanced XML counting function tests
# =============================================================================

@test "enhanced __countXmlNotesAPI should count notes correctly" {
    # Test with valid API XML
    # Temporarily disable logging functions to avoid errors
    __log_start() { :; }
    __logi() { :; }
    __log_finish() { :; }
    
    # Execute function directly to capture output
    __countXmlNotesAPI "${TEST_BASE_DIR}/tests/tmp/test_api.xml"
    [ "$TOTAL_NOTES" -eq 2 ]
}

@test "enhanced __countXmlNotesAPI should handle empty XML" {
    # Test with empty XML
    # Temporarily disable logging functions to avoid errors
    __log_start() { :; }
    __logi() { :; }
    __log_finish() { :; }
    
    # Execute function directly to capture output
    __countXmlNotesAPI "${TEST_BASE_DIR}/tests/tmp/test_empty.xml"
    [ "$TOTAL_NOTES" -eq 0 ]
}

@test "enhanced __countXmlNotesAPI should handle missing file" {
    # Test with non-existent file
    # Temporarily disable logging functions to avoid errors
    __log_start() { :; }
    __logi() { :; }
    __log_finish() { :; }
    
    # Execute function and check if it fails as expected
    run __countXmlNotesAPI "/non/existent/file.xml"
    [ "$status" -ne 0 ]
}

@test "enhanced __countXmlNotesPlanet should count notes correctly" {
    # Test with valid Planet XML
    # Temporarily disable logging functions to avoid errors
    __log_start() { :; }
    __logi() { :; }
    __log_finish() { :; }
    
    # Execute function directly to capture output
    __countXmlNotesPlanet "${TEST_BASE_DIR}/tests/tmp/test_planet.xml"
    [ "$TOTAL_NOTES" -eq 1 ]
}

@test "enhanced __countXmlNotesPlanet should handle empty XML" {
    # Test with empty XML (Planet format)
    # Temporarily disable logging functions to avoid errors
    __log_start() { :; }
    __logi() { :; }
    __log_finish() { :; }
    
    cat > "${TEST_BASE_DIR}/tests/tmp/test_empty_planet.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes version="0.6" generator="OpenStreetMap server" copyright="OpenStreetMap and contributors" attribution="http://www.openstreetmap.org/copyright" license="http://opendatacommons.org/licenses/odbl/1-0/">
</osm-notes>
EOF
    
    # Execute function directly to capture output
    __countXmlNotesPlanet "${TEST_BASE_DIR}/tests/tmp/test_empty_planet.xml"
    [ "$TOTAL_NOTES" -eq 0 ]
}

# =============================================================================
# XML validation function tests
# =============================================================================

@test "XML validation should work with valid API XML" {
 # Test XML validation against schema using enhanced validation
 source "${TEST_BASE_DIR}/bin/functionsProcess.sh"
 run __validate_xml_with_enhanced_error_handling "${TEST_BASE_DIR}/tests/tmp/test_api.xml" "${TEST_BASE_DIR}/xsd/OSM-notes-API-schema.xsd"
 [ "$status" -eq 0 ]
 [[ "$output" == *"XML validation succeeded"* ]]
}

@test "XML validation should work with valid Planet XML" {
 # Test XML validation against schema using enhanced validation
 # Skip if schema file doesn't exist
 if [[ -f "${TEST_BASE_DIR}/xsd/OSM-notes-planet-schema.xsd" ]]; then
  source "${TEST_BASE_DIR}/bin/functionsProcess.sh"
  run __validate_xml_with_enhanced_error_handling "${TEST_BASE_DIR}/tests/tmp/test_planet.xml" "${TEST_BASE_DIR}/xsd/OSM-notes-planet-schema.xsd"
  [ "$status" -eq 0 ]
  [[ "$output" == *"XML validation succeeded"* ]]
 else
  skip "Schema file not found"
 fi
}

# =============================================================================
# Error handling tests
# =============================================================================

@test "should handle xmlstarlet not available" {
    # Temporarily disable logging functions to avoid errors
    __log_start() { :; }
    __logi() { :; }
    __log_finish() { :; }
    __loge() { :; }
    
    # Mock xmlstarlet to fail
    xmlstarlet() { return 1; }
    
    # Execute function and check if it fails when xmlstarlet is not available
    run __countXmlNotesAPI "${TEST_BASE_DIR}/tests/tmp/test_api.xml"
    [ "$status" -ne 0 ]
}

@test "should handle malformed XML gracefully" {
    # Test with malformed XML
    # Temporarily disable logging functions to avoid errors
    __log_start() { :; }
    __logi() { :; }
    __log_finish() { :; }
    
    cat > "${TEST_BASE_DIR}/tests/tmp/test_malformed.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6">
  <note>
    <id>123456</id>
    <!-- Missing closing tag -->
EOF
    
    # Execute function and check if it fails as expected
    run __countXmlNotesAPI "${TEST_BASE_DIR}/tests/tmp/test_malformed.xml"
    [ "$status" -ne 0 ]
}

# =============================================================================
# Performance tests
# =============================================================================

@test "XML counting should be fast for small files" {
    # Test performance with small file
    local start_time=$(date +%s%N)
    run __countXmlNotesAPI "${TEST_BASE_DIR}/tests/tmp/test_api.xml"
    local end_time=$(date +%s%N)
    local duration=$((end_time - start_time))
    
    [ "$status" -eq 0 ]
    [ "$duration" -lt 1000000000 ] # Should complete in less than 1 second
}

# =============================================================================
# Integration tests with database
# =============================================================================

@test "database functions should work with test data" {
    # Create test database
    create_test_database
    
    # Test database connection
    run psql -d "${TEST_DBNAME}" -c "SELECT 1;"
    [ "$status" -eq 0 ]
    
    # Clean up
    drop_test_database
}

# =============================================================================
# Mock function tests
# =============================================================================

@test "mock XML counting should work without external dependencies" {
    # Create a mock version of xmlstarlet
    local mock_xmlstarlet="${TEST_BASE_DIR}/tests/tmp/mock_xmlstarlet"
    cat > "$mock_xmlstarlet" << 'EOF'
#!/bin/bash
if [[ "$1" == "sel" ]] && [[ "$2" == "-t" ]] && [[ "$3" == "-v" ]]; then
    if [[ "$4" == "count(/osm/note)" ]]; then
        echo "2"
    elif [[ "$4" == "count(/osm-notes/note)" ]]; then
        echo "1"
    else
        echo "0"
    fi
else
    echo "Invalid arguments" >&2
    exit 1
fi
EOF
    chmod +x "$mock_xmlstarlet"
    
    # Temporarily replace xmlstarlet with mock
    local original_path="$PATH"
    export PATH="${TEST_BASE_DIR}/tests/tmp:$PATH"
    
    # Temporarily disable logging functions to avoid errors
    __log_start() { :; }
    __logi() { :; }
    __log_finish() { :; }
    
    # Test with mock
    __countXmlNotesAPI "${TEST_BASE_DIR}/tests/tmp/test_api.xml"
    [ "$TOTAL_NOTES" -eq 2 ]
    
    # Restore original PATH
    export PATH="$original_path"
    rm -f "$mock_xmlstarlet"
} 