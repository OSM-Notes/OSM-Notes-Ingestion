#!/usr/bin/env bats

# Enhanced unit tests for XML processing functions
# Author: Andres Gomez (AngocA)
# Version: 2025-01-15

load "$(dirname "$BATS_TEST_FILENAME")/../../test_helper.bash"

# =============================================================================
# Test setup and teardown
# =============================================================================

setup() {
    # Create test XML files
    create_test_xml_files
    # Source the functions
    source "${TEST_BASE_DIR}/bin/functionsProcess.sh"
    # Set up logging function if not available
    if ! declare -f log_info >/dev/null; then
        log_info() { echo "[INFO] $*"; }
        log_error() { echo "[ERROR] $*"; }
        log_debug() { echo "[DEBUG] $*"; }
        log_start() { echo "[START] $*"; }
        log_finish() { echo "[FINISH] $*"; }
    fi
    # Set up test environment
    export MAX_THREADS=2
    export TMP_DIR="${TEST_BASE_DIR}/tests/tmp"
    mkdir -p "${TMP_DIR}"
}

teardown() {
    # Clean up test files
    rm -rf "${TEST_BASE_DIR}/tests/tmp/part_*"
    rm -f "${TEST_BASE_DIR}/tests/tmp/test_*.xml"
}

# =============================================================================
# Helper functions for testing
# =============================================================================

create_test_xml_files() {
    local test_dir="${TEST_BASE_DIR}/tests/tmp"
    mkdir -p "${test_dir}"
    
    # Create test API XML with multiple notes
    cat > "${test_dir}/test_api_multiple.xml" << 'EOF'
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
        <text>Test note 1</text>
        <html>&lt;p&gt;Test note 1&lt;/p&gt;</html>
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
  <note lon="-3.7040" lat="40.4170">
    <id>123458</id>
    <url>https://api.openstreetmap.org/api/0.6/notes/123458.xml</url>
    <date_created>2025-01-15 12:30:00 UTC</date_created>
    <status>closed</status>
    <comments>
      <comment>
        <date>2025-01-15 12:30:00 UTC</date>
        <uid>789</uid>
        <user>testuser3</user>
        <action>opened</action>
        <text>Test note 3</text>
        <html>&lt;p&gt;Test note 3&lt;/p&gt;</html>
      </comment>
    </comments>
  </note>
</osm>
EOF

    # Create test Planet XML with multiple notes
    cat > "${test_dir}/test_planet_multiple.xml" << 'EOF'
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
        <text>Test note 1</text>
        <html>&lt;p&gt;Test note 1&lt;/p&gt;</html>
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
</osm-notes>
EOF
}

# =============================================================================
# Enhanced XML splitting function tests
# =============================================================================

@test "enhanced __splitXmlForParallelAPI should split XML correctly" {
    # Set up test environment
    export TOTAL_NOTES=3
    export MAX_THREADS=2
    
    # Test XML splitting
    run __splitXmlForParallelAPI "${TEST_BASE_DIR}/tests/tmp/test_api_multiple.xml"
    [ "$status" -eq 0 ]
    
    # Check that parts were created
    [ -f "${TMP_DIR}/part_1.xml" ]
    [ -f "${TMP_DIR}/part_2.xml" ]
}

@test "enhanced __splitXmlForParallelPlanet should split XML correctly" {
    # Set up test environment
    export TOTAL_NOTES=2
    export MAX_THREADS=2
    
    # Test XML splitting
    run __splitXmlForParallelPlanet "${TEST_BASE_DIR}/tests/tmp/test_planet_multiple.xml"
    [ "$status" -eq 0 ]
    
    # Check that parts were created
    [ -f "${TMP_DIR}/part_1.xml" ]
    [ -f "${TMP_DIR}/part_2.xml" ]
}

@test "enhanced __splitXmlForParallelSafe should handle zero notes" {
    # Set up test environment
    export TOTAL_NOTES=0
    export MAX_THREADS=2
    
    # Test XML splitting with zero notes
    run __splitXmlForParallelSafe "${TEST_BASE_DIR}/tests/tmp/test_api_multiple.xml" "API"
    [ "$status" -eq 0 ]
    
    # Check that no parts were created
    [ ! -f "${TMP_DIR}/part_1.xml" ]
}

@test "enhanced __splitXmlForParallelSafe should handle single note" {
    # Set up test environment
    export TOTAL_NOTES=1
    export MAX_THREADS=2
    
    # Test XML splitting with single note
    run __splitXmlForParallelSafe "${TEST_BASE_DIR}/tests/tmp/test_api_multiple.xml" "API"
    [ "$status" -eq 0 ]
    
    # Check that one part was created
    [ -f "${TMP_DIR}/part_1.xml" ]
    [ ! -f "${TMP_DIR}/part_2.xml" ]
}

@test "enhanced __splitXmlForParallelSafe should handle more notes than threads" {
    # Set up test environment
    export TOTAL_NOTES=5
    export MAX_THREADS=2
    
    # Test XML splitting with more notes than threads
    run __splitXmlForParallelSafe "${TEST_BASE_DIR}/tests/tmp/test_api_multiple.xml" "API"
    [ "$status" -eq 0 ]
    
    # Check that parts were created
    [ -f "${TMP_DIR}/part_1.xml" ]
    [ -f "${TMP_DIR}/part_2.xml" ]
}

# =============================================================================
# XML processing function tests
# =============================================================================

@test "enhanced __processApiXmlPart should process API XML part correctly" {
    # Create a test part file
    cat > "${TMP_DIR}/test_part.xml" << 'EOF'
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
</osm>
EOF
    
    # Test API XML processing
    run __processApiXmlPart "${TMP_DIR}/test_part.xml" "1"
    [ "$status" -eq 0 ]
    
    # Check that output files were created
    [ -f "${TMP_DIR}/output-notes_part_1.csv" ]
    [ -f "${TMP_DIR}/output-note_comments_part_1.csv" ]
    [ -f "${TMP_DIR}/output-text_comments_part_1.csv" ]
}

@test "enhanced __processPlanetXmlPart should process Planet XML part correctly" {
    # Create a test part file
    cat > "${TMP_DIR}/test_part_planet.xml" << 'EOF'
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
    
    # Test Planet XML processing
    run __processPlanetXmlPart "${TMP_DIR}/test_part_planet.xml" "1"
    [ "$status" -eq 0 ]
    
    # Check that output files were created
    [ -f "${TMP_DIR}/output-notes_part_1.csv" ]
    [ -f "${TMP_DIR}/output-note_comments_part_1.csv" ]
    [ -f "${TMP_DIR}/output-text_comments_part_1.csv" ]
}

# =============================================================================
# Error handling tests
# =============================================================================

@test "enhanced XML splitting should handle missing input file" {
    # Test with non-existent file
    run __splitXmlForParallelAPI "/non/existent/file.xml"
    [ "$status" -ne 0 ]
}

@test "enhanced XML splitting should handle invalid XML format" {
    # Create invalid XML file
    cat > "${TMP_DIR}/test_invalid.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6">
  <invalid-tag>
    This is not valid XML for notes
  </invalid-tag>
</osm>
EOF
    
    # Test with invalid XML
    run __splitXmlForParallelAPI "${TMP_DIR}/test_invalid.xml"
    [ "$status" -ne 0 ]
}

@test "enhanced XML processing should handle missing XSLT files" {
    # Test with missing XSLT files
    local original_xslt="${XSLT_NOTES_API_FILE}"
    export XSLT_NOTES_API_FILE="/non/existent/file.xslt"
    
    run __processApiXmlPart "${TMP_DIR}/test_part.xml" "1"
    [ "$status" -ne 0 ]
    
    export XSLT_NOTES_API_FILE="$original_xslt"
}

# =============================================================================
# Performance tests
# =============================================================================

@test "enhanced XML splitting should be fast for small files" {
    # Test performance with small file
    local start_time=$(date +%s%N)
    export TOTAL_NOTES=3
    export MAX_THREADS=2
    
    run __splitXmlForParallelAPI "${TEST_BASE_DIR}/tests/tmp/test_api_multiple.xml"
    local end_time=$(date +%s%N)
    local duration=$((end_time - start_time))
    
    [ "$status" -eq 0 ]
    [ "$duration" -lt 2000000000 ] # Should complete in less than 2 seconds
}

@test "enhanced XML processing should be fast for small parts" {
    # Create a small test part
    cat > "${TMP_DIR}/test_small_part.xml" << 'EOF'
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
</osm>
EOF
    
    # Test performance
    local start_time=$(date +%s%N)
    run __processApiXmlPart "${TMP_DIR}/test_small_part.xml" "1"
    local end_time=$(date +%s%N)
    local duration=$((end_time - start_time))
    
    [ "$status" -eq 0 ]
    [ "$duration" -lt 3000000000 ] # Should complete in less than 3 seconds
}

# =============================================================================
# Integration tests
# =============================================================================

@test "enhanced XML processing pipeline should work end-to-end" {
    # Test complete pipeline: count -> split -> process
    export TOTAL_NOTES=3
    export MAX_THREADS=2
    
    # Count notes
    run __countXmlNotesAPI "${TEST_BASE_DIR}/tests/tmp/test_api_multiple.xml"
    [ "$status" -eq 0 ]
    [ "$TOTAL_NOTES" -eq 3 ]
    
    # Split XML
    run __splitXmlForParallelAPI "${TEST_BASE_DIR}/tests/tmp/test_api_multiple.xml"
    [ "$status" -eq 0 ]
    
    # Process parts
    run __processApiXmlPart "${TMP_DIR}/part_1.xml" "1"
    [ "$status" -eq 0 ]
    
    run __processApiXmlPart "${TMP_DIR}/part_2.xml" "2"
    [ "$status" -eq 0 ]
    
    # Check that all output files were created
    [ -f "${TMP_DIR}/output-notes_part_1.csv" ]
    [ -f "${TMP_DIR}/output-note_comments_part_1.csv" ]
    [ -f "${TMP_DIR}/output-text_comments_part_1.csv" ]
    [ -f "${TMP_DIR}/output-notes_part_2.csv" ]
    [ -f "${TMP_DIR}/output-note_comments_part_2.csv" ]
    [ -f "${TMP_DIR}/output-text_comments_part_2.csv" ]
}

# =============================================================================
# Mock function tests
# =============================================================================

@test "mock XML processing should work without external dependencies" {
    # Create mock versions of required tools
    local mock_dir="${TEST_BASE_DIR}/tests/tmp/mock_tools"
    mkdir -p "$mock_dir"
    
    # Mock xsltproc
    cat > "$mock_dir/xsltproc" << 'EOF'
#!/bin/bash
if [[ "$1" == "--version" ]]; then
    echo "xsltproc 1.1.34"
elif [[ "$1" == "-o" ]]; then
    # Create output file
    echo "id,lon,lat,date_created,status" > "$2"
    echo "123456,-3.7038,40.4168,2025-01-15 10:30:00 UTC,closed" >> "$2"
    echo "0"
else
    echo "0"
fi
EOF
    chmod +x "$mock_dir/xsltproc"
    
    # Temporarily replace PATH with mock tools
    local original_path="$PATH"
    export PATH="$mock_dir:$PATH"
    
    # Test with mocks
    run __processApiXmlPart "${TMP_DIR}/test_part.xml" "1"
    [ "$status" -eq 0 ]
    
    # Restore original PATH
    export PATH="$original_path"
    rm -rf "$mock_dir"
} 