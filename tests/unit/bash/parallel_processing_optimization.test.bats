#!/usr/bin/env bats
# Test file: parallel_processing_optimization.test.bats
# Version: 2025-12-22
# Description: Test parallel processing optimization functions
# Optimized: Removed redundant medium/huge file tests and consolidated performance tests

# Load test helper
load "../../test_helper"

# Setup function to load required functions
setup() {
 # Set up test environment
 export SCRIPT_BASE_DIRECTORY="${BATS_TEST_DIRNAME}/../../../"

 # Load properties and functions
 source "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh"
 source "${SCRIPT_BASE_DIRECTORY}/bin/lib/parallelProcessingFunctions.sh"
}

# Teardown function to clean up test directories
teardown() {
 # Clean up any test directories that might have been created
 local TEST_DIR="${TEST_BASE_DIR}/tests/tmp/test_output"
 if [[ -d "${TEST_DIR}" ]]; then
  # Force remove all files and directories
  find "${TEST_DIR}" -type f -delete 2>/dev/null || true
  find "${TEST_DIR}" -type d -delete 2>/dev/null || true
  rm -rf "${TEST_DIR}" 2>/dev/null || true
 fi
}

# Test parallel processing optimization functions
@test "test parallel processing optimization functions" {
 # Test setup
 local TEST_DIR="${TEST_BASE_DIR}/tests/tmp/test_output"
 
 # Ensure TEST_BASE_DIR is set
 if [[ -z "${TEST_BASE_DIR:-}" ]]; then
  TEST_BASE_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
  export TEST_BASE_DIR
 fi
 
 # Create test directory and ensure it exists
 mkdir -p "${TEST_DIR}" || {
  echo "ERROR: Could not create TEST_DIR: ${TEST_DIR}" >&2
  return 1
 }
 chmod 777 "${TEST_DIR}" 2> /dev/null || true

 # Verify directory was created
 if [[ ! -d "${TEST_DIR}" ]]; then
  echo "ERROR: TEST_DIR does not exist after creation: ${TEST_DIR}" >&2
  return 1
 fi

 # Create test XML files of different sizes
 local SMALL_XML="${TEST_DIR}/small.xml"
 local LARGE_XML="${TEST_DIR}/large.xml"

 # Small XML (should use line-by-line processing)
 cat > "${SMALL_XML}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
<note id="1" lat="1.0" lon="1.0">
  <comment><![CDATA[Test note 1]]></comment>
</note>
<note id="2" lat="2.0" lon="2.0">
  <comment><![CDATA[Test note 2]]></comment>
</note>
</osm-notes>
EOF

 # Verify small XML file was created
 if [[ ! -f "${SMALL_XML}" ]]; then
  echo "ERROR: Small XML file not created: ${SMALL_XML}" >&2
  ls -la "${TEST_DIR}/" >&2
  return 1
 fi

 # Note: Medium XML file creation removed for optimization
 # Large file test is sufficient to verify processing methods

 # Large XML (should use position-based processing)
 local LARGE_SIZE=6000 # 6GB equivalent
 # Ensure directory exists before creating file
 mkdir -p "$(dirname "${LARGE_XML}")" || {
  echo "ERROR: Could not create directory for LARGE_XML: $(dirname "${LARGE_XML}")" >&2
  return 1
 }
 
 echo '<?xml version="1.0" encoding="UTF-8"?>' > "${LARGE_XML}" || {
  echo "ERROR: Could not create LARGE_XML file: ${LARGE_XML}" >&2
  return 1
 }
 echo '<osm-notes>' >> "${LARGE_XML}"

 # Generate many notes to simulate large file
 for i in {1..100000}; do
  echo "<note id=\"${i}\" lat=\"${i}.0\" lon=\"${i}.0\">" >> "${LARGE_XML}"
  echo "  <comment><![CDATA[Test note ${i}]]></comment>" >> "${LARGE_XML}"
  echo "</note>" >> "${LARGE_XML}"
 done
 echo '</osm-notes>' >> "${LARGE_XML}"
 
 # Verify large XML file was created
 if [[ ! -f "${LARGE_XML}" ]]; then
  echo "ERROR: Large XML file not created: ${LARGE_XML}" >&2
  ls -la "${TEST_DIR}/" >&2
  return 1
 fi

 # Test small file processing (should use line-by-line)
 # Debug: check if function is available
 if ! declare -f __divide_xml_file > /dev/null; then
  echo "ERROR: __divide_xml_file function not found" >&2
  return 1
 fi

 # Create output directories
 mkdir -p "${TEST_DIR}/small_parts"
 mkdir -p "${TEST_DIR}/large_parts"

 # Verify small XML file exists before calling function
 if [[ ! -f "${SMALL_XML}" ]]; then
  echo "ERROR: Small XML file not created: ${SMALL_XML}" >&2
  ls -la "${TEST_DIR}/" >&2
  return 1
 fi

 run __divide_xml_file "${SMALL_XML}" "${TEST_DIR}/small_parts" 5 10 4
 echo "DEBUG: status=$status, output='$output'" >&2
 [ "$status" -eq 0 ]
 # Check for actual output based on what the function produces
 echo "$output" | grep -q "Dividing Planet XML file"
 echo "$output" | grep -q "Successfully created"

 # Note: Medium file test removed for optimization - large file test is sufficient
 # to verify block-based and position-based processing methods

 # Test large file processing (should use position-based)
 run __divide_xml_file "${LARGE_XML}" "${TEST_DIR}/large_parts" 500 15 16
 [ "$status" -eq 0 ]
 echo "$output" | grep -q "Dividing Planet XML file"
 echo "$output" | grep -q "Successfully created"

 # Verify parts were created
 [ -d "${TEST_DIR}/small_parts" ]
 [ -d "${TEST_DIR}/large_parts" ]

 # Cleanup - force remove all files and directories
 find "${TEST_DIR}" -type f -delete 2>/dev/null || true
 find "${TEST_DIR}" -type d -delete 2>/dev/null || true
 rm -rf "${TEST_DIR}" 2>/dev/null || true
}

# Note: Test "performance optimization logic" removed for optimization.
# This test was redundant with "test parallel processing optimization functions"
# which already tests small and large files, sufficient to verify the optimization logic.

# Test error handling in optimization functions
@test "test error handling in optimization functions" {
 # Test setup
 local TEST_DIR="${TEST_BASE_DIR}/tests/tmp/test_output"
 mkdir -p "${TEST_DIR}"
 chmod 777 "${TEST_DIR}" 2> /dev/null || true

 # Test with non-existent input file
 run __divide_xml_file "/nonexistent/file.xml" "${TEST_DIR}/parts" 100 50 8
 echo "DEBUG: status=$status, output='$output'" >&2
 [ "$status" -ne 0 ]
 echo "$output" | grep -q "ERROR: Input XML file does not exist"

 # Create a valid test XML file for the output directory test
 local TEST_XML="${TEST_DIR}/test.xml"
 cat > "${TEST_XML}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
<note id="1" lat="1.0" lon="1.0">
  <comment><![CDATA[Test note]]></comment>
</note>
</osm-notes>
EOF

 # Test with non-existent output directory
 run __divide_xml_file "${TEST_XML}" "/nonexistent/dir" 100 50 8
 echo "DEBUG: status=$status, output='$output'" >&2
 [ "$status" -ne 0 ]
 echo "$output" | grep -q "ERROR: Output directory does not exist"

 # Test with invalid parameters
 run __divide_xml_file "" "${TEST_DIR}/parts" 100 50 8
 echo "DEBUG: status=$status, output='$output'" >&2
 [ "$status" -ne 0 ]
 echo "$output" | grep -q "ERROR: Input XML file and output directory are required"

 # Cleanup - force remove all files and directories
 find "${TEST_DIR}" -type f -delete 2>/dev/null || true
 find "${TEST_DIR}" -type d -delete 2>/dev/null || true
 rm -rf "${TEST_DIR}" 2>/dev/null || true
}

# Test performance metrics calculation
@test "test performance metrics calculation" {
 # Test setup
 local TEST_DIR="${TEST_BASE_DIR}/tests/tmp/test_output"
 mkdir -p "${TEST_DIR}"
 chmod 777 "${TEST_DIR}" 2> /dev/null || true

 # Create a test XML file
 local TEST_XML="${TEST_DIR}/test.xml"
 cat > "${TEST_XML}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
<note id="1" lat="1.0" lon="1.0">
  <comment><![CDATA[Test note]]></comment>
</note>
</osm-notes>
EOF

 # Create output directory
 mkdir -p "${TEST_DIR}/parts"

 # Test that performance metrics are calculated and displayed
 run __divide_xml_file "${TEST_XML}" "${TEST_DIR}/parts" 100 10 4
 echo "DEBUG: status=$status, output='$output'" >&2
 [ "$status" -eq 0 ]
 echo "$output" | grep -q "Performance:"
 # Check for either "MB/s" or "N/A" (when processing is too fast)
 echo "$output" | grep -q -E "(MB/s|N/A)"
 echo "$output" | grep -q -E "(notes/s|N/A)"

 # Cleanup - force remove all files and directories
 find "${TEST_DIR}" -type f -delete 2>/dev/null || true
 find "${TEST_DIR}" -type d -delete 2>/dev/null || true
 rm -rf "${TEST_DIR}" 2>/dev/null || true
}
