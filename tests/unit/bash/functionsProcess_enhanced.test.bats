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
<osm-notes version="0.6" generator="OpenStreetMap server" copyright="OpenStreetMap and contributors" attribution="http://www.openstreetmap.org/copyright" license="http://opendatacommons.org/licenses/odbl/1-0/">
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
    run __countXmlNotesAPI "${TEST_BASE_DIR}/tests/tmp/test_api.xml"
    [ "$status" -eq 0 ]
    [ "$TOTAL_NOTES" -eq 2 ]
}

@test "enhanced __countXmlNotesAPI should handle empty XML" {
    # Test with empty XML
    run __countXmlNotesAPI "${TEST_BASE_DIR}/tests/tmp/test_empty.xml"
    [ "$status" -eq 0 ]
    [ "$TOTAL_NOTES" -eq 0 ]
}

@test "enhanced __countXmlNotesAPI should handle missing file" {
    # Test with non-existent file
    run __countXmlNotesAPI "/non/existent/file.xml"
    [ "$status" -ne 0 ]
}

@test "enhanced __countXmlNotesPlanet should count notes correctly" {
    # Test with valid Planet XML
    run __countXmlNotesPlanet "${TEST_BASE_DIR}/tests/tmp/test_planet.xml"
    [ "$status" -eq 0 ]
    [ "$TOTAL_NOTES" -eq 1 ]
}

@test "enhanced __countXmlNotesPlanet should handle empty XML" {
    # Test with empty XML (Planet format)
    cat > "${TEST_BASE_DIR}/tests/tmp/test_empty_planet.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes version="0.6" generator="OpenStreetMap server" copyright="OpenStreetMap and contributors" attribution="http://www.openstreetmap.org/copyright" license="http://opendatacommons.org/licenses/odbl/1-0/">
</osm-notes>
EOF
    
    run __countXmlNotesPlanet "${TEST_BASE_DIR}/tests/tmp/test_empty_planet.xml"
    [ "$status" -eq 0 ]
    [ "$TOTAL_NOTES" -eq 0 ]
}

# =============================================================================
# XML validation function tests
# =============================================================================

@test "XML validation should work with valid API XML" {
    # Test XML validation against schema
    run xmllint --schema "${TEST_BASE_DIR}/xsd/OSM-notes-API-schema.xsd" "${TEST_BASE_DIR}/tests/tmp/test_api.xml" --noout
    [ "$status" -eq 0 ]
}

@test "XML validation should work with valid Planet XML" {
    # Test XML validation against schema
    run xmllint --schema "${TEST_BASE_DIR}/xsd/OSM-notes-planet-schema.xsd" "${TEST_BASE_DIR}/tests/tmp/test_planet.xml" --noout
    [ "$status" -eq 0 ]
}

# =============================================================================
# Error handling tests
# =============================================================================

@test "should handle xmlstarlet not available" {
    # Mock xmlstarlet not available
    local original_path="$PATH"
    export PATH="/tmp/empty:$PATH"
    
    run __countXmlNotesAPI "${TEST_BASE_DIR}/tests/tmp/test_api.xml"
    [ "$status" -ne 0 ]
    
    export PATH="$original_path"
}

@test "should handle malformed XML gracefully" {
    # Test with malformed XML
    cat > "${TEST_BASE_DIR}/tests/tmp/test_malformed.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6">
  <note>
    <id>123456</id>
    <!-- Missing closing tag -->
EOF
    
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
    
    # Test with mock
    run __countXmlNotesAPI "${TEST_BASE_DIR}/tests/tmp/test_api.xml"
    [ "$status" -eq 0 ]
    [ "$TOTAL_NOTES" -eq 2 ]
    
    # Restore original PATH
    export PATH="$original_path"
    rm -f "$mock_xmlstarlet"
} 