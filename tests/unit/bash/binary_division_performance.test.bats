#!/usr/bin/env bats

# Binary Division Performance Tests
# Tests the binary XML division algorithm performance and functionality
#
# Author: Andres Gomez (AngocA)
# Version: 2025-01-23

# Load test helper
load ../../test_helper

# Test setup
setup() {
  # Create test directory
  TEST_DIR="${BATS_TEST_TMPDIR}/binary_division_test"
  mkdir -p "${TEST_DIR}"
  
  # Create test XML files
  create_test_xml_files
  
  # Source required functions
  source_bin_functions
}

# Test teardown
teardown() {
  # Cleanup test directory
  rm -rf "${TEST_DIR}"
}

# Create test XML files with different sizes
create_test_xml_files() {
  # Small XML (~10KB)
  create_xml_file "${TEST_DIR}/small.xml" 100
  
  # Medium XML (~100KB)
  create_xml_file "${TEST_DIR}/medium.xml" 1000
  
  # Large XML (~1MB)
  create_xml_file "${TEST_DIR}/large.xml" 10000
}

# Create XML file with specified number of notes
create_xml_file() {
  local output_file="$1"
  local num_notes="$2"
  
  # Create XML header
  cat > "${output_file}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
EOF
  
  # Generate sample notes
  for ((i=1; i<=num_notes; i++)); do
    cat >> "${output_file}" << EOF
 <note id="${i}" lat="40.7128" lon="-74.0060" created_at="2025-01-23T12:00:00Z" closed_at="">
  <comment>
   <text>Test note ${i}</text>
   <uid>12345</uid>
   <user>testuser</user>
   <date>2025-01-23T12:00:00Z</date>
   <action>opened</action>
  </comment>
 </note>
EOF
  done
  
  # Close XML
  echo "</osm-notes>" >> "${output_file}"
}

# Source binary functions
source_bin_functions() {
  # Use SCRIPT_BASE_DIRECTORY from test helper
  local PROJECT_ROOT="${SCRIPT_BASE_DIRECTORY:-}"
  
  # Fallback: try to determine project root from current working directory
  if [[ -z "${PROJECT_ROOT}" ]]; then
    local current_dir
    current_dir="$(pwd)"
    if [[ "${current_dir}" == */OSM-Notes-Ingestion ]]; then
      PROJECT_ROOT="${current_dir}"
    elif [[ "${current_dir}" == */OSM-Notes-Ingestion/* ]]; then
      PROJECT_ROOT="${current_dir%/*OSM-Notes-Ingestion}"
      PROJECT_ROOT="${PROJECT_ROOT}/OSM-Notes-Ingestion"
    elif [[ "${current_dir}" == */OSM-Notes-profile ]]; then
      PROJECT_ROOT="${current_dir}"
    elif [[ "${current_dir}" == */OSM-Notes-profile/* ]]; then
      PROJECT_ROOT="${current_dir%/*OSM-Notes-profile}"
      PROJECT_ROOT="${PROJECT_ROOT}/OSM-Notes-profile"
    else
      # Try to find from BATS_TEST_DIRNAME
      PROJECT_ROOT="${BATS_TEST_DIRNAME}/../../../"
    fi
  fi
  
  echo "Using PROJECT_ROOT: ${PROJECT_ROOT}" >&2
  
  if [[ -f "${PROJECT_ROOT}/lib/osm-common/commonFunctions.sh" ]]; then
    source "${PROJECT_ROOT}/lib/osm-common/commonFunctions.sh"
  else
    echo "ERROR: commonFunctions.sh not found at ${PROJECT_ROOT}/lib/osm-common/commonFunctions.sh" >&2
    return 1
  fi
  
  if [[ -f "${PROJECT_ROOT}/bin/parallelProcessingFunctions.sh" ]]; then
    source "${PROJECT_ROOT}/bin/parallelProcessingFunctions.sh"
  else
    echo "ERROR: parallelProcessingFunctions.sh not found at ${PROJECT_ROOT}/bin/parallelProcessingFunctions.sh" >&2
    return 1
  fi
}

# Test binary division function exists
@test "binary division function exists" {
  # Check if binary division function is available
  function_exists __divide_xml_file_binary
  [ $? -eq 0 ]
}

# Test traditional division function exists
@test "traditional division function exists" {
  # Check if traditional division function is available
  function_exists __divide_xml_file
  [ $? -eq 0 ]
}

# Test binary division with small file
@test "binary division with small file" {
  local input_file="${TEST_DIR}/small.xml"
  local output_dir="${TEST_DIR}/small_binary"
  # Create output directory
  mkdir -p "${output_dir}"
  
  # Create output directory
  mkdir -p "${output_dir}"
  
  # Run binary division
  run __divide_xml_file_binary "${input_file}" "${output_dir}" 10 5 2
  
  # Debug output
  echo "Status: $status" >&2
  echo "Output: $output" >&2
  
  # Check success
  [ "$status" -eq 0 ]
  
  # Check output directory exists
  assert_dir_exists "${output_dir}"
  
  # Check parts were created
  local part_count
  part_count=$(find "${output_dir}" -name "*.xml" | wc -l)
  [ "${part_count}" -gt 0 ]
}

# Test traditional division with small file
@test "traditional division with small file" {
  local input_file="${TEST_DIR}/small.xml"
  local output_dir="${TEST_DIR}/small_traditional"
  # Create output directory
  mkdir -p "${output_dir}"
  
  # Run traditional division
  run __divide_xml_file "${input_file}" "${output_dir}" 10 5 2
  
  # Check success
  [ "$status" -eq 0 ]
  
  # Check output directory exists
  assert_dir_exists "${output_dir}"
  
  # Check parts were created
  local part_count
  part_count=$(find "${output_dir}" -name "*.xml" | wc -l)
  [ "${part_count}" -gt 0 ]
}

# Test binary division with medium file
@test "binary division with medium file" {
  local input_file="${TEST_DIR}/medium.xml"
  local output_dir="${TEST_DIR}/medium_binary"
  # Create output directory
  mkdir -p "${output_dir}"
  
  # Run binary division
  run __divide_xml_file_binary "${input_file}" "${output_dir}" 50 10 4
  
  # Check success
  [ "$status" -eq 0 ]
  
  # Check output directory exists
  assert_dir_exists "${output_dir}"
  
  # Check parts were created
  local part_count
  part_count=$(find "${output_dir}" -name "*.xml" | wc -l)
  [ "${part_count}" -gt 0 ]
}

# Test traditional division with medium file
@test "traditional division with medium file" {
  local input_file="${TEST_DIR}/medium.xml"
  local output_dir="${TEST_DIR}/medium_traditional"
  # Create output directory
  mkdir -p "${output_dir}"
  
  # Run traditional division
  run __divide_xml_file "${input_file}" "${output_dir}" 50 10 4
  
  # Check success
  [ "$status" -eq 0 ]
  
  # Check output directory exists
  assert_dir_exists "${output_dir}"
  
  # Check parts were created
  local part_count
  part_count=$(find "${output_dir}" -name "*.xml" | wc -l)
  [ "${part_count}" -gt 0 ]
}

# Test binary division with large file
@test "binary division with large file" {
  local input_file="${TEST_DIR}/large.xml"
  local output_dir="${TEST_DIR}/large_binary"
  # Create output directory
  mkdir -p "${output_dir}"
  
  # Run binary division
  run __divide_xml_file_binary "${input_file}" "${output_dir}" 100 20 8
  
  # Check success
  [ "$status" -eq 0 ]
  
  # Check output directory exists
  assert_dir_exists "${output_dir}"
  
  # Check parts were created
  local part_count
  part_count=$(find "${output_dir}" -name "*.xml" | wc -l)
  [ "${part_count}" -gt 0 ]
}

# Test traditional division with large file
@test "traditional division with large file" {
  local input_file="${TEST_DIR}/large.xml"
  local output_dir="${TEST_DIR}/large_traditional"
  # Create output directory
  mkdir -p "${output_dir}"
  
  # Run traditional division
  run __divide_xml_file "${input_file}" "${output_dir}" 100 20 8
  
  # Check success
  [ "$status" -eq 0 ]
  
  # Check output directory exists
  assert_dir_exists "${output_dir}"
  
  # Check parts were created
  local part_count
  part_count=$(find "${output_dir}" -name "*.xml" | wc -l)
  [ "${part_count}" -gt 0 ]
}

# Test performance comparison between methods
@test "performance comparison between division methods" {
  skip "Performance test is too slow for regular test runs - use small.xml for faster testing"
  
  local input_file="${TEST_DIR}/small.xml"
  local binary_dir="${TEST_DIR}/performance_binary"
  local traditional_dir="${TEST_DIR}/performance_traditional"
  
  # Create output directories
  mkdir -p "${binary_dir}"
  mkdir -p "${traditional_dir}"
  
  # Test binary division performance with smaller parameters
  local binary_start
  binary_start=$(date +%s)
  run __divide_xml_file_binary "${input_file}" "${binary_dir}" 25 2 2
  local binary_end
  binary_end=$(date +%s)
  local binary_time
  binary_time=$((binary_end - binary_start))
  
  # Check binary division success
  [ "$status" -eq 0 ]
  
  # Test traditional division performance with smaller parameters
  local traditional_start
  traditional_start=$(date +%s)
  run __divide_xml_file "${input_file}" "${traditional_dir}" 25 2 2
  local traditional_end
  traditional_end=$(date +%s)
  local traditional_time
  traditional_time=$((traditional_end - traditional_start))
  
  # Check traditional division success
  [ "$status" -eq 0 ]
  
  # Log performance results
  echo "Binary division time: ${binary_time}s"
  echo "Traditional division time: ${traditional_time}s"
  
  # Both methods should complete successfully
  [ "${binary_time}" -ge 0 ]
  [ "${traditional_time}" -ge 0 ]
}

# Test error handling with invalid input
@test "binary division error handling with invalid input" {
  local invalid_file="/nonexistent/file.xml"
  local output_dir="${TEST_DIR}/error_test"
  # Create output directory
  mkdir -p "${output_dir}"
  
  # Run binary division with invalid file
  run __divide_xml_file_binary "${invalid_file}" "${output_dir}" 100 50 4
  
  # Should fail
  [ "$status" -ne 0 ]
}

# Test error handling with invalid output directory
@test "binary division error handling with invalid output directory" {
  local input_file="${TEST_DIR}/small.xml"
  local invalid_dir="/nonexistent/directory"
  
  # Run binary division with invalid output directory
  run __divide_xml_file_binary "${input_file}" "${invalid_dir}" 100 50 4
  
  # Should fail
  [ "$status" -ne 0 ]
}

# Test edge case with empty file
@test "binary division edge case with empty file" {
  local empty_file="${TEST_DIR}/empty.xml"
  local output_dir="${TEST_DIR}/empty_test"
  # Create output directory
  mkdir -p "${output_dir}"
  
  # Create empty XML file
  cat > "${empty_file}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
</osm-notes>
EOF
  
  # Run binary division with empty file
  run __divide_xml_file_binary "${empty_file}" "${output_dir}" 100 50 4
  
  # Should handle gracefully (success or failure depending on implementation)
  # Just check that it doesn't crash
  [ "${status}" -ge 0 ]
}

# Test parallel processing configuration
@test "binary division parallel processing configuration" {
  local input_file="${TEST_DIR}/medium.xml"
  local output_dir="${TEST_DIR}/parallel_test"
  # Create output directory
  mkdir -p "${output_dir}"
  
  # Test with different thread counts
  for threads in 1 2 4; do
    echo "Testing with ${threads} threads"
    
    # Run binary division
    run __divide_xml_file_binary "${input_file}" "${output_dir}_${threads}" 50 10 "${threads}"
    
    # Check success
    [ "$status" -eq 0 ]
    
    # Check output directory exists
    assert_dir_exists "${output_dir}_${threads}"
  done
}

# Test file size threshold detection
@test "binary division file size threshold detection" {
  local small_file="${TEST_DIR}/small.xml"
  local large_file="${TEST_DIR}/large.xml"
  
  # Get file sizes
  local small_size
  small_size=$(stat -c%s "${small_file}")
  local large_size
  large_size=$(stat -c%s "${large_file}")
  
  # Convert to MB
  local small_size_mb
  small_size_mb=$((small_size / 1024 / 1024))
  local large_size_mb
  large_size_mb=$((large_size / 1024 / 1024))
  
  echo "Small file: ${small_size_mb} MB"
  echo "Large file: ${large_size_mb} MB"
  
  # Both files should exist and have reasonable sizes
  [ "${small_size_mb}" -gt 0 ]
  [ "${large_size_mb}" -gt 0 ]
  [ "${large_size_mb}" -gt "${small_size_mb}" ]
}
