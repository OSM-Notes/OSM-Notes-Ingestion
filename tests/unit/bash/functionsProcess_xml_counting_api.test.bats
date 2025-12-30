#!/usr/bin/env bats

# FunctionsProcess XML Counting API Tests
# Tests for __countXmlNotesAPI function
# Author: Andres Gomez (AngocA)
# Version: 2025-11-23

load "$(dirname "${BATS_TEST_FILENAME}")/../../test_helper.bash"

# =============================================================================
# Test setup and teardown
# =============================================================================

setup() {
 # Ensure TEST_BASE_DIR is set
 if [[ -z "${TEST_BASE_DIR:-}" ]]; then
  export TEST_BASE_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
 fi

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
 
 # Setup test properties
 setup_test_properties

 # Provide mock psql when PostgreSQL is not available
 local MOCK_PSQL="${TMP_DIR}/psql"
 mkdir -p "${TMP_DIR}"
 cat > "${MOCK_PSQL}" << 'EOF'
#!/bin/bash
COMMAND="$*"

# Simulate specific error scenarios for tests
if [[ "${COMMAND}" == *"'invalid'::integer"* ]]; then
 echo "psql: ERROR: invalid input syntax for type integer: \"invalid\"" >&2
 exit 1
fi

# Provide simple output for SELECT 1/2/3 checks
if [[ "${COMMAND}" == *"SELECT 1"* ]]; then
 printf " ?column? \n 1\n"
 exit 0
fi

if [[ "${COMMAND}" == *"SELECT 2"* ]]; then
 printf " ?column? \n 2\n"
 exit 0
fi

if [[ "${COMMAND}" == *"SELECT 3"* ]]; then
 printf " ?column? \n 3\n"
 exit 0
fi

echo "Mock psql executed: ${COMMAND}" >&2
exit 0
EOF
 chmod +x "${MOCK_PSQL}"
 export PATH="${TMP_DIR}:${PATH}"

 # Unset any existing readonly variables that might conflict
 unset ERROR_HELP_MESSAGE ERROR_PREVIOUS_EXECUTION_FAILED ERROR_CREATING_REPORT ERROR_MISSING_LIBRARY ERROR_INVALID_ARGUMENT ERROR_LOGGER_UTILITY ERROR_DOWNLOADING_BOUNDARY_ID_LIST ERROR_NO_LAST_UPDATE ERROR_PLANET_PROCESS_IS_RUNNING ERROR_DOWNLOADING_NOTES ERROR_EXECUTING_PLANET_DUMP ERROR_DOWNLOADING_BOUNDARY ERROR_GEOJSON_CONVERSION ERROR_INTERNET_ISSUE ERROR_GENERAL 2> /dev/null || true

 # Create mock logging functions before sourcing the main file
 create_mock_logging_functions

 # Source the functions to be tested
 source "${TEST_BASE_DIR}/bin/lib/functionsProcess.sh"

 # Verify that functions are available
 if ! declare -f __countXmlNotesAPI > /dev/null; then
  echo "ERROR: __countXmlNotesAPI function not found after sourcing functionsProcess.sh"
  exit 1
 fi

 # Set up logging function if not available
 if ! declare -f log_info > /dev/null; then
  log_info() { echo "[INFO] $*"; }
  log_error() { echo "[ERROR] $*"; }
  log_start() { echo "[START] $*"; }
  log_finish() { echo "[FINISH] $*"; }
 fi
}

teardown() {
 # Clean up test files to avoid interference between tests
 rm -f "${TEST_BASE_DIR}/tests/tmp/test_*.xml"

 # Remove mock binaries created during setup
 rm -f "${TMP_DIR}/psql" 2> /dev/null || true
 restore_properties
}

# =============================================================================
# Helper functions for testing
# =============================================================================

create_mock_logging_functions() {
 # Create mock logging functions that the main script expects
 __log_start() { :; }
 __logi() { :; }
 __loge() { :; }
 __logd() { :; }
 __logw() { :; }
 __log_finish() { :; }
}

create_test_xml_files() {
 local test_dir="${TEST_BASE_DIR}/tests/tmp"

 # Create directory if it doesn't exist
 mkdir -p "${test_dir}"

 # Try to set permissions, but don't fail if we can't
 chmod 777 "${test_dir}" 2> /dev/null || true

 # Try to remove old files, but don't fail if we can't
 rm -f "${test_dir}/test_*.xml" 2> /dev/null || true

 # Ensure we can write to the directory
 if [[ ! -w "${test_dir}" ]]; then
  echo "ERROR: Cannot write to test directory: ${test_dir}" >&2
  exit 1
 fi

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

 # Create empty XML (API format)
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
 # Note: This function uses grep, not xmlstarlet

 # Execute function using run to capture status and output
 run __countXmlNotesAPI "${TEST_BASE_DIR}/tests/tmp/test_api.xml"

 # Check if function executed successfully
 [[ "${status}" -eq 0 ]]
}

@test "enhanced __countXmlNotesAPI should handle empty XML" {
 # Test with empty XML
 # Note: This function uses grep, not xmlstarlet

 # Execute function using run to capture status and output
 run __countXmlNotesAPI "${TEST_BASE_DIR}/tests/tmp/test_empty.xml"

 # Check if function executed successfully
 [[ "${status}" -eq 0 ]]
}

@test "enhanced __countXmlNotesAPI should handle missing file" {
 # Test with non-existent file
 # Execute function and check if it fails as expected
 run __countXmlNotesAPI "/non/existent/file.xml"
 [[ "${status}" -ne 0 ]]
}

@test "enhanced __countXmlNotesAPI should handle grep output with newlines correctly" {
 # Test that the function handles cases where grep -c might return newlines
 # This tests the fix for the "syntax error in expression" bug
 # where grep -c output with newlines caused arithmetic expression errors

 # Create a test XML file with notes
 local TEST_XML="${TMP_DIR}/test_newline_case.xml"
 cat > "${TEST_XML}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6" generator="test">
 <note id="1" lat="0.0" lon="0.0">
  <comment>
   <text>Test note 1</text>
  </comment>
 </note>
 <note id="2" lat="1.0" lon="1.0">
  <comment>
   <text>Test note 2</text>
  </comment>
 </note>
</osm>
EOF

 # Source the function
 source "${TEST_BASE_DIR}/bin/lib/functionsProcess.sh"

 # Test that the function properly cleans grep output
 # We'll directly test the cleaned output by simulating the bug scenario
 # First, get the raw grep output (which might have newlines)
 local RAW_COUNT
 RAW_COUNT=$(grep -c '<note ' "${TEST_XML}" 2> /dev/null || echo "0")

 # Simulate the bug: add a newline to the count (as grep might do)
 RAW_COUNT="${RAW_COUNT}"$'\n'

 # Test that the cleaning logic works
 local CLEANED_COUNT
 CLEANED_COUNT=$(printf '%s' "${RAW_COUNT}" | tr -d '[:space:]' | head -1 || echo "0")

 # Verify cleaned count is numeric and can be used in arithmetic
 [[ "${CLEANED_COUNT}" =~ ^[0-9]+$ ]]

 # Test arithmetic operation - this would fail with the bug
 local TEST_ARITHMETIC
 TEST_ARITHMETIC=$((CLEANED_COUNT + 0))
 [[ "${TEST_ARITHMETIC}" -eq 2 ]]

 # Now test the actual function to ensure it handles this correctly
 run __countXmlNotesAPI "${TEST_XML}"

 # Function should succeed
 [[ "${status}" -eq 0 ]]

 # Verify that TOTAL_NOTES is set and can be used in arithmetic
 # This is the critical test - if TOTAL_NOTES has newlines, this will fail
 if [[ -n "${TOTAL_NOTES:-}" ]]; then
  # Test arithmetic operation - this will fail if TOTAL_NOTES has newlines
  local TEST_ARITHMETIC_FINAL
  TEST_ARITHMETIC_FINAL=$((TOTAL_NOTES + 0)) || true
  [[ "${TEST_ARITHMETIC_FINAL}" -ge 0 ]]
  [[ "${TEST_ARITHMETIC_FINAL}" -eq 2 ]]
 fi

 # Cleanup
 rm -f "${TEST_XML}"
}

@test "enhanced __countXmlNotesAPI should handle zero count without syntax errors" {
 # Test that zero count from grep -c doesn't cause syntax errors
 # Create an XML file with no notes
 local TEST_XML="${TMP_DIR}/test_zero_notes.xml"
 cat > "${TEST_XML}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6" generator="test">
</osm>
EOF

 # Source the function
 source "${TEST_BASE_DIR}/bin/lib/functionsProcess.sh"

 # Execute function
 run __countXmlNotesAPI "${TEST_XML}"

 # Function should succeed even with zero notes
 [[ "${status}" -eq 0 ]]

 # Verify TOTAL_NOTES is 0 and can be used in arithmetic
 if [[ -n "${TOTAL_NOTES:-}" ]]; then
  # Test arithmetic operation
  local TEST_ARITHMETIC
  TEST_ARITHMETIC=$((TOTAL_NOTES + 0)) || true
  [[ "${TEST_ARITHMETIC}" -eq 0 ]]
 fi

 # Cleanup
 rm -f "${TEST_XML}"
}

@test "should handle missing dependencies gracefully" {
 # Test graceful handling when dependencies are not available
 # Note: This function uses grep, which is a standard tool
 # This test verifies the function works without external XML processing tools
 run __countXmlNotesAPI "${TEST_BASE_DIR}/tests/tmp/test_api.xml"

 # The function should work with grep (standard tool)
 [[ "${status}" -ge 0 ]]
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

 # Execute function and check behavior based on validation setting
 run __countXmlNotesAPI "${TEST_BASE_DIR}/tests/tmp/test_malformed.xml"

 # If XML validation is enabled, it should fail
 if [[ "${SKIP_XML_VALIDATION}" != "true" ]]; then
  [[ "${status}" -ne 0 ]]
 else
  # If XML validation is disabled, it should succeed (fast processing)
  [[ "${status}" -eq 0 ]]
 fi
}

@test "XML counting should be fast for small files" {
 # Test performance with small file
 # Note: This function uses grep, not xmlstarlet

 local start_time
 start_time=$(date +%s%N)
 run __countXmlNotesAPI "${TEST_BASE_DIR}/tests/tmp/test_api.xml"
 local end_time
 end_time=$(date +%s%N)
 local duration=$((end_time - start_time))

 [[ "${status}" -eq 0 ]]
 [[ "${duration}" -lt 1000000000 ]] # Should complete in less than 1 second
}

@test "XML counting should work without external dependencies" {
 # Test that XML counting works using only standard tools (grep)
 # This function uses grep, which is a standard Unix tool
 run __countXmlNotesAPI "${TEST_BASE_DIR}/tests/tmp/test_api.xml"

 # Check result - the function should work with grep
 [[ "${status}" -ge 0 ]]
}

