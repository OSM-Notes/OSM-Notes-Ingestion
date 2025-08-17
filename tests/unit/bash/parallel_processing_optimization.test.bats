#!/usr/bin/env bats
# Test file: parallel_processing_optimization.test.bats
# Version: 2025-01-17
# Description: Test parallel processing optimization functions

# Load test helper
load test_helper

# Test parallel processing optimization functions
@test "test parallel processing optimization functions" {
  # Test setup
  local TEST_DIR="${BATS_TEST_DIRNAME}/test_output"
  mkdir -p "${TEST_DIR}"
  
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
  local MEDIUM_SIZE=150  # 150MB equivalent
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
  local LARGE_SIZE=6000  # 6GB equivalent
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
  run __divide_xml_file "${SMALL_XML}" "${TEST_DIR}/small_parts" 5 10 4
  assert_success
  assert_output --partial "Using line-by-line processing"
  
  # Test medium file processing (should use block-based)
  run __divide_xml_file "${MEDIUM_XML}" "${TEST_DIR}/medium_parts" 100 20 8
  assert_success
  assert_output --partial "Using block-based processing"
  
  # Test large file processing (should use position-based)
  run __divide_xml_file "${LARGE_XML}" "${TEST_DIR}/large_parts" 500 15 16
  assert_success
  assert_output --partial "Using position-based processing"
  
  # Verify parts were created
  assert [ -d "${TEST_DIR}/small_parts" ]
  assert [ -d "${TEST_DIR}/medium_parts" ]
  assert [ -d "${TEST_DIR}/large_parts" ]
  
  # Cleanup
  rm -rf "${TEST_DIR}"
}

# Test performance optimization logic
@test "test performance optimization logic" {
  # Test setup
  local TEST_DIR="${BATS_TEST_DIRNAME}/test_output"
  mkdir -p "${TEST_DIR}"
  
  # Test different file size thresholds
  local SMALL_XML="${TEST_DIR}/small.xml"
  local MEDIUM_XML="${TEST_DIR}/medium.xml"
  local LARGE_XML="${TEST_DIR}/large.xml"
  local HUGE_XML="${TEST_DIR}/huge.xml"
  
  # Create test files with different sizes
  echo '<?xml version="1.0" encoding="UTF-8"?><osm-notes></osm-notes>' > "${SMALL_XML}"
  echo '<?xml version="1.0" encoding="UTF-8"?><osm-notes></osm-notes>' > "${MEDIUM_XML}"
  echo '<?xml version="1.0" encoding="UTF-8"?><osm-notes></osm-notes>' > "${LARGE_XML}"
  echo '<?xml version="1.0" encoding="UTF-8"?><osm-notes></osm-notes>' > "${HUGE_XML}"
  
  # Mock file sizes using stat
  local MOCK_STAT="${BATS_TEST_DIRNAME}/../mock_commands/stat"
  chmod +x "${MOCK_STAT}"
  
  # Test small file optimization
  echo "echo 1048576" > "${MOCK_STAT}"  # 1MB
  run __divide_xml_file "${SMALL_XML}" "${TEST_DIR}/small_parts" 5 10 4
  assert_success
  assert_output --partial "Medium file detected"
  
  # Test large file optimization
  echo "echo 2097152000" > "${MOCK_STAT}"  # 2GB
  run __divide_xml_file "${LARGE_XML}" "${TEST_DIR}/large_parts" 100 20 8
  assert_success
  assert_output --partial "Large file detected"
  
  # Test huge file optimization
  echo "echo 10485760000" > "${MOCK_STAT}"  # 10GB
  run __divide_xml_file "${HUGE_XML}" "${TEST_DIR}/huge_parts" 500 15 16
  assert_success
  assert_output --partial "Extremely large file detected"
  
  # Cleanup
  rm -rf "${TEST_DIR}"
}

# Test error handling in optimization functions
@test "test error handling in optimization functions" {
  # Test setup
  local TEST_DIR="${BATS_TEST_DIRNAME}/test_output"
  mkdir -p "${TEST_DIR}"
  
  # Test with non-existent input file
  run __divide_xml_file "/nonexistent/file.xml" "${TEST_DIR}/parts" 100 50 8
  assert_failure
  assert_output --partial "ERROR: Input XML file does not exist"
  
  # Test with non-existent output directory
  run __divide_xml_file "${BATS_TEST_DIRNAME}/test.xml" "/nonexistent/dir" 100 50 8
  assert_failure
  assert_output --partial "ERROR: Output directory does not exist"
  
  # Test with invalid parameters
  run __divide_xml_file "" "${TEST_DIR}/parts" 100 50 8
  assert_failure
  assert_output --partial "ERROR: Input XML file and output directory are required"
  
  # Cleanup
  rm -rf "${TEST_DIR}"
}

# Test performance metrics calculation
@test "test performance metrics calculation" {
  # Test setup
  local TEST_DIR="${BATS_TEST_DIRNAME}/test_output"
  mkdir -p "${TEST_DIR}"
  
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
  
  # Test that performance metrics are calculated and displayed
  run __divide_xml_file "${TEST_XML}" "${TEST_DIR}/parts" 100 10 4
  assert_success
  assert_output --partial "Performance:"
  assert_output --regexp "MB/s"
  assert_output --regexp "notes/s"
  
  # Cleanup
  rm -rf "${TEST_DIR}"
}
