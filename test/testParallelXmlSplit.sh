#!/bin/bash

# Test script for parallel XML splitting functionality
# This script demonstrates that the parallel XML splitting works correctly
# and avoids file access conflicts when multiple processes read the same XML file.

# Version: 2025-07-23

# Base directory for the project.
declare SCRIPT_BASE_DIRECTORY
SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)"
readonly SCRIPT_BASE_DIRECTORY

# Set required environment variables for testing
export LOG_LEVEL="INFO"
export DBNAME="test_db"
export MAX_THREADS=2

# Loads the global properties.
# shellcheck source=../etc/properties.sh
source "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh"

# Loads the functions.
# shellcheck source=../bin/functionsProcess.sh
source "${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh"

# Test directory
declare -r TEST_DIR="/tmp/test_parallel_xml_split"
declare -r TEST_API_XML="${TEST_DIR}/test_api.xml"
declare -r TEST_PLANET_XML="${TEST_DIR}/test_planet.xml"

# Create test XML files
create_test_files() {
 __log_start
 __logi "Creating test XML files"

 mkdir -p "${TEST_DIR}"

 # Create API format test XML
 cat > "${TEST_API_XML}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm>
  <note id="1" lat="40.7128" lon="-74.0060">
    <date>2023-01-01T00:00:00Z</date>
    <status>open</status>
    <comments>
      <comment>
        <date>2023-01-01T00:00:00Z</date>
        <uid>123</uid>
        <user>testuser1</user>
        <text>Test comment 1</text>
      </comment>
    </comments>
  </note>
  <note id="2" lat="40.7129" lon="-74.0061">
    <date>2023-01-02T00:00:00Z</date>
    <status>closed</status>
    <comments>
      <comment>
        <date>2023-01-02T00:00:00Z</date>
        <uid>456</uid>
        <user>testuser2</user>
        <text>Test comment 2</text>
      </comment>
    </comments>
  </note>
  <note id="3" lat="40.7130" lon="-74.0062">
    <date>2023-01-03T00:00:00Z</date>
    <status>open</status>
    <comments>
      <comment>
        <date>2023-01-03T00:00:00Z</date>
        <uid>789</uid>
        <user>testuser3</user>
        <text>Test comment 3</text>
      </comment>
    </comments>
  </note>
</osm>
EOF

 # Create Planet format test XML
 cat > "${TEST_PLANET_XML}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
  <note id="1" lat="40.7128" lon="-74.0060">
    <date>2023-01-01T00:00:00Z</date>
    <status>open</status>
    <comments>
      <comment>
        <date>2023-01-01T00:00:00Z</date>
        <uid>123</uid>
        <user>testuser1</user>
        <text>Test comment 1</text>
      </comment>
    </comments>
  </note>
  <note id="2" lat="40.7129" lon="-74.0061">
    <date>2023-01-02T00:00:00Z</date>
    <status>closed</status>
    <comments>
      <comment>
        <date>2023-01-02T00:00:00Z</date>
        <uid>456</uid>
        <user>testuser2</user>
        <text>Test comment 2</text>
      </comment>
    </comments>
  </note>
  <note id="3" lat="40.7130" lon="-74.0062">
    <date>2023-01-03T00:00:00Z</date>
    <status>open</status>
    <comments>
      <comment>
        <date>2023-01-03T00:00:00Z</date>
        <uid>789</uid>
        <user>testuser3</user>
        <text>Test comment 3</text>
      </comment>
    </comments>
  </note>
</osm-notes>
EOF

 __logi "Test files created successfully"
 __log_finish
}

# Test parallel API XML splitting
test_api_parallel() {
 __log_start
 __logi "Testing parallel API XML splitting"

 # Set test environment
 export TMP_DIR="${TEST_DIR}/api_test"
 export MAX_THREADS=2
 export TOTAL_NOTES=3

 mkdir -p "${TMP_DIR}"

 # Count notes first
 __countXmlNotesAPI "${TEST_API_XML}"

 # Split XML in parallel
 __splitXmlForParallelAPI "${TEST_API_XML}"

 # Verify results
 declare -i PART_COUNT
 PART_COUNT=$(find "${TMP_DIR}" -name "part_*.xml" | wc -l)
 __logi "Created ${PART_COUNT} parts"

 if [[ "${PART_COUNT}" -eq 2 ]]; then
  __logi "✓ API parallel splitting test PASSED"
 else
  __loge "✗ API parallel splitting test FAILED: expected 2 parts, got ${PART_COUNT}"
  return 1
 fi

 __log_finish
}

# Test parallel Planet XML splitting
test_planet_parallel() {
 __log_start
 __logi "Testing parallel Planet XML splitting"

 # Set test environment
 export TMP_DIR="${TEST_DIR}/planet_test"
 export MAX_THREADS=2
 export TOTAL_NOTES=3

 mkdir -p "${TMP_DIR}"

 # Count notes first
 __countXmlNotesPlanet "${TEST_PLANET_XML}"

 # Split XML in parallel
 __splitXmlForParallelPlanet "${TEST_PLANET_XML}"

 # Verify results
 declare -i PART_COUNT
 PART_COUNT=$(find "${TMP_DIR}" -name "part_*.xml" | wc -l)
 __logi "Created ${PART_COUNT} parts"

 if [[ "${PART_COUNT}" -eq 2 ]]; then
  __logi "✓ Planet parallel splitting test PASSED"
 else
  __loge "✗ Planet parallel splitting test FAILED: expected 2 parts, got ${PART_COUNT}"
  return 1
 fi

 __log_finish
}

# Clean up test files
cleanup() {
 __log_start
 __logi "Cleaning up test files"
 rm -rf "${TEST_DIR}"
 __log_finish
}

# Main function
main() {
 __log_start
 __logi "Starting parallel XML splitting tests"

 # Create test files
 create_test_files

 # Test API format
 if ! test_api_parallel; then
  __loge "API parallel test failed"
  cleanup
  exit 1
 fi

 # Test Planet format
 if ! test_planet_parallel; then
  __loge "Planet parallel test failed"
  cleanup
  exit 1
 fi

 __logi "All parallel XML splitting tests PASSED"
 cleanup
 __log_finish
}

# Start logger and run main function
__start_logger
main

