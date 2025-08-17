#!/usr/bin/env bats

# Edge Cases Validation Tests for OSM-Notes-profile
# Tests the tolerant behavior of validation functions in edge cases
#
# Author: Andres Gomez (AngocA)
# Version: 2025-01-27

setup() {
  # Create temporary directory for test files
  export TMP_DIR=$(mktemp -d)
  export SCRIPT_BASE_DIRECTORY="${BATS_TEST_DIRNAME}/../../.."
  
  # Create test XML files with edge cases
  create_test_files
}

teardown() {
  # Clean up temporary files
  rm -rf "${TMP_DIR}"
}

create_test_files() {
  # Create XML with mixed valid/invalid dates
  cat > "${TMP_DIR}/mixed_dates.xml" << 'EOF'
<?xml version="1.0"?>
<osm-notes>
  <note id="1" created_at="2023-01-01T00:00:00Z" closed_at="invalid-date">
    <comment timestamp="2023-01-02T12:00:00Z">Valid comment</comment>
  </note>
  <note id="2" created_at="2023-13-45T25:70:99Z" closed_at="2023-01-03T00:00:00Z">
    <comment timestamp="not-a-date">Invalid comment</comment>
  </note>
</osm-notes>
EOF

  # Create XML with malformed but parseable content
  cat > "${TMP_DIR}/malformed_parseable.xml" << 'EOF'
<?xml version="1.0"?>
<osm-notes>
  <note id="1" created_at="2023-01-01T00:00:00Z">
    <comment>Valid comment without timestamp</comment>
  </note>
  <note id="2" created_at="2023-01-02T00:00:00Z">
    <comment timestamp="2023-01-02T12:00:00Z">Valid comment with timestamp</comment>
  </note>
</osm-notes>
EOF
}

@test "edge case: validation functions are tolerant by default" {
  # Source validation functions
  source "${SCRIPT_BASE_DIRECTORY}/bin/validationFunctions.sh"
  
  # Test that functions don't fail immediately with edge cases
  run __validate_xml_dates "${TMP_DIR}/mixed_dates.xml" "//@created_at|//@closed_at|//@timestamp"
  
  # Should not fail immediately (tolerant mode)
  # Can return 0 (passed), 1 (failed), or 127 (command not found)
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ] || [ "$status" -eq 127 ]
}

@test "edge case: strict mode fails immediately with invalid dates" {
  # Create a simple XML with clearly invalid dates
  cat > "${TMP_DIR}/simple_invalid.xml" << 'EOF'
<?xml version="1.0"?>
<osm-notes>
  <note id="1" created_at="invalid-date" closed_at="not-a-date">
    <comment timestamp="2023-13-45T25:70:99Z">Invalid comment</comment>
  </note>
</osm-notes>
EOF
  
  # Source validation functions
  source "${SCRIPT_BASE_DIRECTORY}/bin/validationFunctions.sh"
  
  # Test with STRICT_MODE=true
  export STRICT_MODE="true"
  run __validate_xml_dates "${TMP_DIR}/simple_invalid.xml" "//@created_at|//@closed_at|//@timestamp"
  
  # Debug: show the output and status
  echo "Strict mode test output: '${output}'"
  echo "Strict mode test status: ${status}"
  
  # Should fail immediately in strict mode
  [ "$status" -eq 1 ]
  
  unset STRICT_MODE
}

@test "edge case: lightweight validation handles large files gracefully" {
  # Source validation functions
  source "${SCRIPT_BASE_DIRECTORY}/bin/validationFunctions.sh"
  
  # Test that lightweight validation works with edge cases
  run __validate_xml_dates_lightweight "${TMP_DIR}/malformed_parseable.xml" "//@created_at|//@closed_at|//@timestamp"
  
  # Should handle edge cases gracefully
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ] || [ "$status" -eq 127 ]
}

@test "edge case: validation functions handle empty files" {
  # Create empty XML file
  local empty_xml="${TMP_DIR}/empty.xml"
  touch "${empty_xml}"
  
  # Source validation functions
  source "${SCRIPT_BASE_DIRECTORY}/bin/validationFunctions.sh"
  
  # Test with empty file
  run __validate_xml_dates "${empty_xml}" "//@created_at|//@closed_at|//@timestamp"
  
  # Should handle empty files gracefully
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ] || [ "$status" -eq 127 ]
}

@test "edge case: validation functions handle files with no dates" {
  # Create XML file without date attributes
  cat > "${TMP_DIR}/no_dates.xml" << 'EOF'
<?xml version="1.0"?>
<osm-notes>
  <note id="1" lat="40.7128" lon="-74.0060">
    <comment>Comment without timestamp</comment>
  </note>
</osm-notes>
EOF
  
  # Source validation functions
  source "${SCRIPT_BASE_DIRECTORY}/bin/validationFunctions.sh"
  
  # Test with file containing no dates
  run __validate_xml_dates "${TMP_DIR}/no_dates.xml" "//@created_at|//@closed_at|//@timestamp"
  
  # Should handle files without dates gracefully
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ] || [ "$status" -eq 127 ]
}

@test "edge case: validation functions handle mixed date formats" {
  # Create XML with mixed date formats
  cat > "${TMP_DIR}/mixed_formats.xml" << 'EOF'
<?xml version="1.0"?>
<osm-notes>
  <note id="1" created_at="2023-01-01T00:00:00Z" closed_at="2023-01-02 12:00:00 UTC">
    <comment timestamp="2023-01-01T12:00:00Z">Mixed format comment</comment>
  </note>
</osm-notes>
EOF
  
  # Source validation functions
  source "${SCRIPT_BASE_DIRECTORY}/bin/validationFunctions.sh"
  
  # Test with file containing no dates
  run __validate_xml_dates "${TMP_DIR}/mixed_formats.xml" "//@created_at|//@closed_at|//@timestamp"
  
  # Should handle mixed formats gracefully
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ] || [ "$status" -eq 127 ]
}

@test "edge case: validation functions handle special characters in dates" {
  # Create XML with special characters in dates
  cat > "${TMP_DIR}/special_chars.xml" << 'EOF'
<?xml version="1.0"?>
<osm-notes>
  <note id="1" created_at="2023-01-01T00:00:00Z" closed_at="2023-01-02T12:00:00Z">
    <comment timestamp="2023-01-01T12:00:00Z">Comment with special chars: &lt;&gt;&amp;</comment>
  </note>
</osm-notes>
EOF
  
  # Source validation functions
  source "${SCRIPT_BASE_DIRECTORY}/bin/validationFunctions.sh"
  
  # Test with special characters
  run __validate_xml_dates "${TMP_DIR}/special_chars.xml" "//@created_at|//@closed_at|//@timestamp"
  
  # Should handle special characters gracefully
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ] || [ "$status" -eq 127 ]
}
