#!/usr/bin/env bats

# Binary Division Basic Tests
# Tests for basic binary division functionality and function existence
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

# Test binary division function exists
@test "binary division function exists" {
 # Check if binary division function is available
 declare -f __divide_xml_file_binary > /dev/null
 [ $? -eq 0 ]
}

# Test traditional division function exists
@test "traditional division function exists" {
 # Check if traditional division function is available
 declare -f __divide_xml_file > /dev/null
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


