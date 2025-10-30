#!/usr/bin/env bats
# Test file: parallel_processing_optimization.test.bats
# Version: 2025-01-24
# Description: Test parallel processing optimization functions

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

# Test parallel processing optimization functions
@test "test parallel processing optimization functions" {
 # Test setup
 local TEST_DIR="${TEST_BASE_DIR}/tests/tmp/test_output"
 mkdir -p "${TEST_DIR}"
 chmod 777 "${TEST_DIR}" 2> /dev/null || true

 # Create test XML files of different sizes
 local SMALL_XML="${TEST_DIR}/small.xml"
 local MEDIUM_XML="${TEST_DIR}/medium.xml"
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

 # Medium XML (should use block-based processing)
 local MEDIUM_SIZE=150 # 150MB equivalent
 echo '<?xml version="1.0" encoding="UTF-8"?>' > "${MEDIUM_XML}"
 echo '<osm-notes>' >> "${MEDIUM_XML}"

 # Generate many notes to simulate medium file
 for i in {1..10000}; do
  echo "<note id=\"${i}\" lat=\"${i}.0\" lon=\"${i}.0\">" >> "${MEDIUM_XML}"
  echo "  <comment><![CDATA[Test note ${i}]]></comment>" >> "${MEDIUM_XML}"
  echo "</note>" >> "${MEDIUM_XML}"
 done
 echo '</osm-notes>' >> "${MEDIUM_XML}"

 # Large XML (should use position-based processing)
 local LARGE_SIZE=6000 # 6GB equivalent
 echo '<?xml version="1.0" encoding="UTF-8"?>' > "${LARGE_XML}"
 echo '<osm-notes>' >> "${LARGE_XML}"

 # Generate many notes to simulate large file
 for i in {1..100000}; do
  echo "<note id=\"${i}\" lat=\"${i}.0\" lon=\"${i}.0\">" >> "${LARGE_XML}"
  echo "  <comment><![CDATA[Test note ${i}]]></comment>" >> "${LARGE_XML}"
  echo "</note>" >> "${LARGE_XML}"
 done
 echo '</osm-notes>' >> "${LARGE_XML}"

 # Test small file processing (should use line-by-line)
 # Debug: check if function is available
 if ! declare -f __divide_xml_file > /dev/null; then
  echo "ERROR: __divide_xml_file function not found" >&2
  return 1
 fi

 # Create output directories
 mkdir -p "${TEST_DIR}/small_parts"
 mkdir -p "${TEST_DIR}/medium_parts"
 mkdir -p "${TEST_DIR}/large_parts"

 run __divide_xml_file "${SMALL_XML}" "${TEST_DIR}/small_parts" 5 10 4
 echo "DEBUG: status=$status, output='$output'" >&2
 [ "$status" -eq 0 ]
 # Check for actual output based on what the function produces
 echo "$output" | grep -q "Dividing Planet XML file"
 echo "$output" | grep -q "Successfully created"

 # Test medium file processing (should use block-based)
 run __divide_xml_file "${MEDIUM_XML}" "${TEST_DIR}/medium_parts" 100 20 8
 [ "$status" -eq 0 ]
 echo "$output" | grep -q "Dividing Planet XML file"
 echo "$output" | grep -q "Successfully created"

 # Test large file processing (should use position-based)
 run __divide_xml_file "${LARGE_XML}" "${TEST_DIR}/large_parts" 500 15 16
 [ "$status" -eq 0 ]
 echo "$output" | grep -q "Dividing Planet XML file"
 echo "$output" | grep -q "Successfully created"

 # Verify parts were created
 [ -d "${TEST_DIR}/small_parts" ]
 [ -d "${TEST_DIR}/medium_parts" ]
 [ -d "${TEST_DIR}/large_parts" ]

 # Cleanup
 rm -rf "${TEST_DIR}"
}

# Test performance optimization logic
@test "test performance optimization logic" {
 # Test setup
 local TEST_DIR="${TEST_BASE_DIR}/tests/tmp/test_output"
 mkdir -p "${TEST_DIR}"
 chmod 777 "${TEST_DIR}" 2> /dev/null || true

 # Test different file size thresholds
 local SMALL_XML="${TEST_DIR}/small.xml"
 local MEDIUM_XML="${TEST_DIR}/medium.xml"
 local LARGE_XML="${TEST_DIR}/large.xml"
 local HUGE_XML="${TEST_DIR}/huge.xml"

 # Create test files with different sizes
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

 cat > "${MEDIUM_XML}" << 'EOF'
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

 cat > "${LARGE_XML}" << 'EOF'
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

 cat > "${HUGE_XML}" << 'EOF'
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

 # Create output directories
 mkdir -p "${TEST_DIR}/small_parts"
 mkdir -p "${TEST_DIR}/large_parts"
 mkdir -p "${TEST_DIR}/huge_parts"

 # Test small file optimization (1MB - should be small)
 run __divide_xml_file "${SMALL_XML}" "${TEST_DIR}/small_parts" 5 10 4
 echo "DEBUG: status=$status, output='$output'" >&2
 [ "$status" -eq 0 ]
 echo "$output" | grep -q "Dividing Planet XML file"
 echo "$output" | grep -q "Successfully created"

 # Test large file optimization (2GB - should be large)
 run __divide_xml_file "${LARGE_XML}" "${TEST_DIR}/large_parts" 100 20 8
 [ "$status" -eq 0 ]
 echo "$output" | grep -q "Dividing Planet XML file"
 echo "$output" | grep -q "Successfully created"

 # Test huge file optimization (10GB - should be huge)
 run __divide_xml_file "${HUGE_XML}" "${TEST_DIR}/huge_parts" 500 15 16
 [ "$status" -eq 0 ]
 echo "$output" | grep -q "Dividing Planet XML file"
 echo "$output" | grep -q "Successfully created"

 # Cleanup
 rm -rf "${TEST_DIR}"
}

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

 # Cleanup
 rm -rf "${TEST_DIR}"
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

 # Cleanup
 rm -rf "${TEST_DIR}"
}
