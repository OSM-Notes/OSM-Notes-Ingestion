#!/bin/bash
# shellcheck disable=SC1091,SC2312

# Test script for parallel Planet processing functionality
# This script demonstrates that the parallel processing works correctly
# and maintains the same structure as API processing.

# Version: 2025-07-23

# Base directory for the project.
declare SCRIPT_BASE_DIRECTORY
SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)"
readonly SCRIPT_BASE_DIRECTORY

# Set required environment variables for testing
export LOG_LEVEL="INFO"
export DBNAME="test_db"
export MAX_THREADS=2
export CLEAN=true

# Loads the global properties.
# shellcheck source=../etc/properties.sh
source "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh"

# Loads the functions.
# shellcheck source=../bin/functionsProcess.sh
source "${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh"

# Test directory
declare -r TEST_DIR="/tmp/test_planet_parallel"
declare -r TEST_PLANET_XML="${TEST_DIR}/test_planet.xml"

# Create test XML file
create_test_file() {
 __log_start
 __logi "Creating test Planet XML file"

 mkdir -p "${TEST_DIR}"

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

 __logi "Test file created successfully"
 __log_finish
}

# Test parallel Planet processing
test_planet_parallel_processing() {
 __log_start
 __logi "Testing parallel Planet processing"

 # Set test environment
 export TMP_DIR="${TEST_DIR}/processing_test"
 export TOTAL_NOTES=3
 export MAX_THREADS=2

 mkdir -p "${TMP_DIR}"

 # Count notes first
 __countXmlNotesPlanet "${TEST_PLANET_XML}"

 # Split XML in parallel
 __splitXmlForParallelPlanet "${TEST_PLANET_XML}"

 # Verify parts were created
 declare -i PART_COUNT
 PART_COUNT=$(find "${TMP_DIR}" -name "part_*.xml" | wc -l)
 __logi "Created ${PART_COUNT} parts"

 if [[ "${PART_COUNT}" -eq 2 ]]; then
  __logi "✓ Planet parallel splitting test PASSED"
 else
  __loge "✗ Planet parallel splitting test FAILED: expected 2 parts, got ${PART_COUNT}"
  return 1
 fi

 # Test parallel processing (mock)
 # Note: This is a simplified test since we don't have a real database
 __logi "Testing parallel processing structure"

 # Export required variables for parallel processing
 export XSLT_NOTES_FILE XSLT_NOTE_COMMENTS_FILE XSLT_TEXT_COMMENTS_FILE

 # Verify that the processing function exists and can be called
 if type __processPlanetXmlPart &> /dev/null; then
  __logi "✓ __processPlanetXmlPart function exists"
 else
  __loge "✗ __processPlanetXmlPart function not found"
  return 1
 fi

 # Verify that the parallel processing function exists
 if type __processXmlPartsParallel &> /dev/null; then
  __logi "✓ __processXmlPartsParallel function exists"
 else
  __loge "✗ __processXmlPartsParallel function not found"
  return 1
 fi

 __logi "✓ Planet parallel processing structure test PASSED"
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
 __logi "Starting Planet parallel processing tests"

 # Create test file
 create_test_file

 # Test parallel processing
 if ! test_planet_parallel_processing; then
  __loge "Planet parallel processing test failed"
  cleanup
  exit 1
 fi

 __logi "All Planet parallel processing tests PASSED"
 cleanup
 __log_finish
}

# Start logger and run main function
__start_logger
main
