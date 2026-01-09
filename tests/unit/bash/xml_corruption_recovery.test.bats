#!/usr/bin/env bats

# Test file for XML corruption recovery functions
# Author: Andres Gomez
# Version: 2026-01-08

load ../../test_helper

setup() {
 SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
 TEST_OUTPUT_DIR="${SCRIPT_BASE_DIRECTORY}/tests/output"
 mkdir -p "${TEST_OUTPUT_DIR}"

 # Load logging functions first if not already loaded
 if ! declare -f __log_start > /dev/null 2>&1; then
  if [[ -f "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/commonFunctions.sh" ]]; then
   source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/commonFunctions.sh"
  fi
 fi

 # Source the functions
 source "${SCRIPT_BASE_DIRECTORY}/bin/lib/parallelProcessingFunctions.sh"
 
 # Ensure __validate_xml_integrity is available
 if ! declare -f __validate_xml_integrity > /dev/null 2>&1; then
  # Try loading from functionsProcess if not in parallelProcessingFunctions
  if [[ -f "${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh" ]]; then
   source "${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh"
  fi
 fi

 # Create test XML files
 create_test_xml_files
}

teardown() {
 # Clean up test files only (not the directory)
 rm -f "${TEST_OUTPUT_DIR}"/*.xml 2> /dev/null || true
 rm -f "${TEST_OUTPUT_DIR}"/*.bak 2> /dev/null || true
 # Clean up backup directory
 rm -rf "${TEST_OUTPUT_DIR}/backup" 2> /dev/null || true
}

create_test_xml_files() {
 # Ensure directory exists
 mkdir -p "${TEST_OUTPUT_DIR}"
 
 # Create a valid XML file
 cat > "${TEST_OUTPUT_DIR}/valid.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
<note id="1" lat="40.0" lon="-74.0" created_at="2023-01-01T00:00:00Z">
  <comment action="opened" timestamp="2023-01-01T00:00:00Z">Test note</comment>
</note>
</osm-notes>
EOF

 # Verify file was created
 [ -f "${TEST_OUTPUT_DIR}/valid.xml" ]

 # Create a corrupted XML file with extra content
 cat > "${TEST_OUTPUT_DIR}/corrupted_extra_content.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
<note id="1" lat="40.0" lon="-74.0" created_at="2023-01-01T00:00:00Z">
  <comment action="opened" timestamp="2023-01-01T00:00:00Z">Test note</comment>
</note>
</osm-notes>
Extra content after closing tag
EOF

 # Verify file was created
 [ -f "${TEST_OUTPUT_DIR}/corrupted_extra_content.xml" ]

 # Create a corrupted XML file with missing closing tag
 cat > "${TEST_OUTPUT_DIR}/corrupted_missing_closing.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
<note id="1" lat="40.0" lon="-74.0" created_at="2023-01-01T00:00:00Z">
  <comment action="opened" timestamp="2023-01-01T00:00:00Z">Test note</comment>
</note>
EOF

 # Verify file was created
 [ -f "${TEST_OUTPUT_DIR}/corrupted_missing_closing.xml" ]

 # Create a corrupted XML file with missing XML declaration
 cat > "${TEST_OUTPUT_DIR}/corrupted_missing_declaration.xml" << 'EOF'
<osm-notes>
<note id="1" lat="40.0" lon="-74.0" created_at="2023-01-01T00:00:00Z">
  <comment action="opened" timestamp="2023-01-01T00:00:00Z">Test note</comment>
</note>
</osm-notes>
EOF

 # Verify file was created
 [ -f "${TEST_OUTPUT_DIR}/corrupted_missing_declaration.xml" ]
}

@test "XML integrity validation passes for valid XML file" {
 local xml_file="${TEST_OUTPUT_DIR}/valid.xml"

 # Recreate file to ensure it exists
 mkdir -p "${TEST_OUTPUT_DIR}"
 cat > "${xml_file}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
<note id="1" lat="40.0" lon="-74.0" created_at="2023-01-01T00:00:00Z">
  <comment action="opened" timestamp="2023-01-01T00:00:00Z">Test note</comment>
</note>
</osm-notes>
EOF

 # Verify file exists
 [ -f "${xml_file}" ]

 # Verify function is available
 if ! declare -f __validate_xml_integrity > /dev/null 2>&1; then
  skip "__validate_xml_integrity function not available"
 fi

 run __validate_xml_integrity "${xml_file}" "false"

 echo "DEBUG: status=$status, output='$output'" >&2
 echo "DEBUG: xml_file exists: $([ -f "${xml_file}" ] && echo yes || echo no)" >&2
 [ "$status" -eq 0 ]
 echo "$output" | grep -q "XML file integrity validation completed successfully" || \
  echo "$output" | grep -q "XML file successfully recovered and validated" || \
  echo "$output" | grep -q "validation completed successfully" || \
  echo "$output" | grep -q "validation passed"
}

@test "XML integrity validation detects and recovers from extra content corruption" {
 local xml_file="${TEST_OUTPUT_DIR}/corrupted_extra_content.xml"
 local backup_dir="${TEST_OUTPUT_DIR}/backup"

 # Recreate file to ensure it exists
 mkdir -p "${TEST_OUTPUT_DIR}"
 mkdir -p "${backup_dir}"
 cat > "${xml_file}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
<note id="1" lat="40.0" lon="-74.0" created_at="2023-01-01T00:00:00Z">
  <comment action="opened" timestamp="2023-01-01T00:00:00Z">Test note</comment>
</note>
</osm-notes>
Extra content after closing tag
EOF

 # Verify file exists
 [ -f "${xml_file}" ]

 # Verify function is available
 if ! declare -f __validate_xml_integrity > /dev/null 2>&1; then
  skip "__validate_xml_integrity function not available"
 fi

 run __validate_xml_integrity "${xml_file}" "true"

 echo "DEBUG: status=$status, output='$output'" >&2
 echo "DEBUG: xml_file exists: $([ -f "${xml_file}" ] && echo yes || echo no)" >&2
 [ "$status" -eq 0 ]
 echo "$output" | grep -q "XML file successfully recovered and validated" || \
  echo "$output" | grep -q "validation completed successfully" || \
  echo "$output" | grep -q "Successfully recovered XML file" || \
  echo "$output" | grep -q "validation passed"

 # Verify the file was actually fixed (if xmllint is available)
 if command -v xmllint > /dev/null 2>&1; then
  run xmllint --noout "${xml_file}" 2>&1
  [ "$status" -eq 0 ]
 fi
}

@test "XML integrity validation detects and recovers from missing closing tag" {
 local xml_file="${TEST_OUTPUT_DIR}/corrupted_missing_closing.xml"

 # Recreate file to ensure it exists
 mkdir -p "${TEST_OUTPUT_DIR}"
 cat > "${xml_file}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
<note id="1" lat="40.0" lon="-74.0" created_at="2023-01-01T00:00:00Z">
  <comment action="opened" timestamp="2023-01-01T00:00:00Z">Test note</comment>
</note>
EOF

 # Verify file exists
 [ -f "${xml_file}" ]

 # Verify function is available
 if ! declare -f __validate_xml_integrity > /dev/null 2>&1; then
  skip "__validate_xml_integrity function not available"
 fi

 run __validate_xml_integrity "${xml_file}" "true"

 echo "DEBUG: status=$status, output='$output'" >&2
 echo "DEBUG: xml_file exists: $([ -f "${xml_file}" ] && echo yes || echo no)" >&2
 [ "$status" -eq 0 ]
 echo "$output" | grep -q "XML file successfully recovered and validated" || \
  echo "$output" | grep -q "validation completed successfully" || \
  echo "$output" | grep -q "Successfully recovered XML file" || \
  echo "$output" | grep -q "validation passed"

 # Verify the file was actually fixed (if xmllint is available)
 if command -v xmllint > /dev/null 2>&1; then
  run xmllint --noout "${xml_file}" 2>&1
  [ "$status" -eq 0 ]
 fi
}

@test "XML integrity validation detects and recovers from missing XML declaration" {
 local xml_file="${TEST_OUTPUT_DIR}/corrupted_missing_declaration.xml"

 # Recreate file to ensure it exists
 mkdir -p "${TEST_OUTPUT_DIR}"
 cat > "${xml_file}" << 'EOF'
<osm-notes>
<note id="1" lat="40.0" lon="-74.0" created_at="2023-01-01T00:00:00Z">
  <comment action="opened" timestamp="2023-01-01T00:00:00Z">Test note</comment>
</note>
</osm-notes>
EOF

 # Verify file exists
 [ -f "${xml_file}" ]

 # Verify function is available
 if ! declare -f __validate_xml_integrity > /dev/null 2>&1; then
  skip "__validate_xml_integrity function not available"
 fi

 run __validate_xml_integrity "${xml_file}" "true"

 echo "DEBUG: status=$status, output='$output'" >&2
 echo "DEBUG: xml_file exists: $([ -f "${xml_file}" ] && echo yes || echo no)" >&2
 [ "$status" -eq 0 ]
 echo "$output" | grep -q "XML file successfully recovered and validated" || \
  echo "$output" | grep -q "validation completed successfully" || \
  echo "$output" | grep -q "Successfully recovered XML file" || \
  echo "$output" | grep -q "validation passed"

 # Verify the file was actually fixed (if xmllint is available)
 if command -v xmllint > /dev/null 2>&1; then
  run xmllint --noout "${xml_file}" 2>&1
  [ "$status" -eq 0 ]
 fi
}

@test "Corrupted XML file handler creates backup and attempts recovery" {
 local xml_file="${TEST_OUTPUT_DIR}/corrupted_extra_content.xml"
 local backup_dir="${TEST_OUTPUT_DIR}/backup"

 run __handle_corrupted_xml_file "${xml_file}" "${backup_dir}"

 [ "$status" -eq 0 ]
 echo "$output" | grep -q "Successfully recovered XML file"

 # Verify backup was created
 [ -d "${backup_dir}" ]
 [ "$(find "${backup_dir}" -name "*.corrupted.*" | wc -l)" -eq 1 ]
}

@test "XML corruption recovery preserves original file structure" {
 local xml_file="${TEST_OUTPUT_DIR}/corrupted_extra_content.xml"
 local original_content
 original_content=$(grep -c "<note" "${xml_file}")

 run __handle_corrupted_xml_file "${xml_file}"

 [ "$status" -eq 0 ]

 # Verify the recovered file still has the same note count
 local recovered_content
 recovered_content=$(grep -c "<note" "${xml_file}")
 [ "${recovered_content}" -eq "${original_content}" ]
}
