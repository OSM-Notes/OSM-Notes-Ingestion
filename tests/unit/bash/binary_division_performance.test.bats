#!/usr/bin/env bats

# Binary Division Performance Tests
# Tests for performance comparison between binary and traditional division methods
# Author: Andres Gomez (AngocA)
# Version: 2025-12-22
# Optimized: Removed redundant medium file tests and simplified parallel configuration

# Load test helper
load ../../test_helper

# Test setup
setup() {
 # Setup test properties first (this must be done before any script sources properties.sh)
 if declare -f setup_test_properties > /dev/null 2>&1; then
  setup_test_properties
 fi
 
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
 # Restore original properties if needed
 if declare -f restore_properties > /dev/null 2>&1; then
  restore_properties
 fi
 
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

 if [[ -f "${PROJECT_ROOT}/bin/lib/parallelProcessingFunctions.sh" ]]; then
  source "${PROJECT_ROOT}/bin/lib/parallelProcessingFunctions.sh"
 else
  echo "ERROR: parallelProcessingFunctions.sh not found at ${PROJECT_ROOT}/bin/lib/parallelProcessingFunctions.sh" >&2
  return 1
 fi
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

# Note: Medium file tests removed for optimization - binary division with large file
# is sufficient to test the functionality. Medium file tests were redundant.

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

# Note: Traditional division with large file test removed for optimization.
# Binary division with large file is sufficient to test large file handling.
# Traditional division is already tested with small file.

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

# Test parallel processing configuration (simplified - only test with 2 threads)
@test "binary division parallel processing configuration" {
 local input_file="${TEST_DIR}/medium.xml"
 local output_dir="${TEST_DIR}/parallel_test"
 local threads=2

 # Create fresh output directory
 rm -rf "${output_dir}"
 mkdir -p "${output_dir}"

 echo "Testing with ${threads} threads"

 # Run binary division
 run __divide_xml_file_binary "${input_file}" "${output_dir}" 50 10 "${threads}"

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

# Test file size threshold detection
@test "binary division file size threshold detection" {
 local small_file="${TEST_DIR}/small.xml"
 local large_file="${TEST_DIR}/large.xml"

 # Check files exist
 [ -f "${small_file}" ]
 [ -f "${large_file}" ]

 # Get file sizes in bytes
 local small_size
 small_size=$(stat -c%s "${small_file}")
 local large_size
 large_size=$(stat -c%s "${large_file}")

 # Convert to KB for better comparison (since small file is only ~10KB)
 local small_size_kb
 small_size_kb=$((small_size / 1024))
 local large_size_kb
 large_size_kb=$((large_size / 1024))

 echo "Small file: ${small_size_kb} KB (${small_size} bytes)"
 echo "Large file: ${large_size_kb} KB (${large_size} bytes)"

 # Both files should exist and have reasonable sizes
 [ "${small_size}" -gt 0 ]
 [ "${large_size}" -gt 0 ]
 [ "${large_size}" -gt "${small_size}" ]
}
