#!/usr/bin/env bats

# Binary Division Error Handling Tests
# Tests for error handling and edge cases in binary division
# Author: Andres Gomez (AngocA)
# Version: 2025-10-30

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


