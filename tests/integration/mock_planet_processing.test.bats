#!/usr/bin/env bats

# Integration test for complete Planet XML processing using mock data
# Author: Andres Gomez
# Version: 2025-10-24

load ../test_helper

setup() {
  SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
  TEST_OUTPUT_DIR="${SCRIPT_BASE_DIRECTORY}/tests/output/mock_planet_processing"
  MOCK_XML_FILE="${SCRIPT_BASE_DIRECTORY}/tests/fixtures/xml/mockPlanetDump.osn.xml"
  
  # Create test output directory
  mkdir -p "${TEST_OUTPUT_DIR}"
  
  # Source the main processing functions
  source "${SCRIPT_BASE_DIRECTORY}/bin/parallelProcessingFunctions.sh"
  
  # Verify mock file exists
  if [[ ! -f "${MOCK_XML_FILE}" ]]; then
    echo "ERROR: Mock XML file not found: ${MOCK_XML_FILE}"
    exit 1
  fi
  
  # Get file info for logging
  local file_size
  file_size=$(stat -c%s "${MOCK_XML_FILE}" 2>/dev/null || echo "unknown")
  local note_count
  note_count=$(grep -c "<note" "${MOCK_XML_FILE}" 2>/dev/null || echo "0")
  
  echo "Using mock XML file: ${MOCK_XML_FILE}"
  echo "File size: ${file_size} bytes"
  echo "Note count: ${note_count}"
}

teardown() {
  # Clean up test output
  rm -rf "${TEST_OUTPUT_DIR}"
}

@test "Mock Planet XML file is valid and contains expected content" {
  # Verify XML structure
  [ -f "${MOCK_XML_FILE}" ]
  [ -s "${MOCK_XML_FILE}" ]
  
  # Check for XML declaration
  head -1 "${MOCK_XML_FILE}" | grep -q "<?xml"
  
  # Check for root element
  grep -q "<osm-notes" "${MOCK_XML_FILE}"
  
  # Check for note elements
  local note_count
  note_count=$(grep -c "<note" "${MOCK_XML_FILE}")
  [ "${note_count}" -gt 0 ]
  
  # Check for comment elements
  local comment_count
  comment_count=$(grep -c "<comment" "${MOCK_XML_FILE}")
  [ "${comment_count}" -gt 0 ]
  
  echo "✓ Mock XML file contains ${note_count} notes and ${comment_count} comments"
}

@test "AWK processing works with mock Planet XML (notes CSV)" {
  # Use existing AWK file for testing
  local awk_file="${SCRIPT_BASE_DIRECTORY}/awk/extract_notes.awk"
  local output_file="${TEST_OUTPUT_DIR}/mock_notes.csv"
  
  # Verify AWK file exists
  [ -f "${awk_file}" ]
  
  # Process XML with AWK and redirect output to file
  awk -f "${awk_file}" "${MOCK_XML_FILE}" > "${output_file}"
  
  [ -f "${output_file}" ]
  [ -s "${output_file}" ]
  
  # Verify CSV structure (Planet AWK doesn't generate headers, only data)
  local line_count
  line_count=$(wc -l < "${output_file}")
  [ "${line_count}" -gt 0 ] # At least some data
  
  # Check data lines (first line should start with note ID)
  head -1 "${output_file}" | grep -q "^[0-9]"
  
  echo "✓ Notes CSV generated successfully: ${line_count} lines"
}

@test "AWK processing works with mock Planet XML (comments CSV)" {
  local awk_file="${SCRIPT_BASE_DIRECTORY}/awk/extract_comments.awk"
  local output_file="${TEST_OUTPUT_DIR}/mock_comments.csv"
  
  # Verify AWK file exists
  [ -f "${awk_file}" ]
  
  # Process XML with AWK and redirect output to file
  awk -f "${awk_file}" "${MOCK_XML_FILE}" > "${output_file}"
  
  [ -f "${output_file}" ]
  [ -s "${output_file}" ]
  
  # Verify CSV structure (Planet AWK doesn't generate headers, only data)
  local line_count
  line_count=$(wc -l < "${output_file}")
  [ "${line_count}" -gt 0 ] # At least some data
  
  # Check data lines (first line should start with note ID)
  head -1 "${output_file}" | grep -q "^[0-9]"
  
  echo "✓ Comments CSV generated successfully: ${line_count} lines"
}

@test "AWK processing works with mock Planet XML (text comments CSV)" {
  local awk_file="${SCRIPT_BASE_DIRECTORY}/awk/extract_comment_texts.awk"
  local output_file="${TEST_OUTPUT_DIR}/mock_text_comments.csv"
  
  # Verify AWK file exists
  [ -f "${awk_file}" ]
  
  # Process XML with AWK and redirect output to file
  awk -f "${awk_file}" "${MOCK_XML_FILE}" > "${output_file}"
  
  [ -f "${output_file}" ]
  [ -s "${output_file}" ]
  
  # Verify CSV structure (Planet AWK doesn't generate headers, only data)
  local line_count
  line_count=$(wc -l < "${output_file}")
  [ "${line_count}" -gt 0 ] # At least some data
  
  # Check data lines (first line should start with note ID)
  head -1 "${output_file}" | grep -q "^[0-9]"
  
  echo "✓ Text comments CSV generated successfully: ${line_count} lines"
}

@test "Mock XML can be processed with robust AWK function" {
  # This function has been consolidated into __processLargeXmlFile
  # Skip this test as the original function no longer exists
  skip "Robust AWK processing function consolidated into __processLargeXmlFile"
}

@test "Mock XML can be manually divided into parts for testing" {
  local output_dir="${TEST_OUTPUT_DIR}/manual_parts"
  mkdir -p "${output_dir}"
  
  # Manually create parts for testing (simplified approach)
  local total_notes
  total_notes=$(grep -c "<note" "${MOCK_XML_FILE}")
  local part_size=20
  local num_parts
  num_parts=$(( (total_notes + part_size - 1) / part_size ))
  
  echo "Creating ${num_parts} parts manually for testing..."
  
  # Create first part as example
  local part_file="${output_dir}/part_1.xml"
  
  # Create part header
  cat > "${part_file}" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
EOF
  
  # Add first few notes (simplified)
  head -50 "${MOCK_XML_FILE}" | grep -A 20 "<note" >> "${part_file}"
  
  # Add closing tag
  echo "</osm-notes>" >> "${part_file}"
  
  # Verify part was created
  [ -f "${part_file}" ]
  [ -s "${part_file}" ]
  
  # Check basic structure
  head -1 "${part_file}" | grep -q "<?xml"
  grep -q "<osm-notes" "${part_file}"
  
  local part_notes
  part_notes=$(grep -c "<note" "${part_file}" 2>/dev/null || echo "0")
  [ "${part_notes}" -gt 0 ]
  
  echo "✓ Manual part creation completed: ${part_notes} notes in part 1"
}

@test "Mock XML processing handles edge cases and special characters" {
  # Check for special characters in the mock data
  local has_special_chars=false
  
  if grep -q "は\|は\|は" "${MOCK_XML_FILE}"; then
    has_special_chars=true
  fi
  
  if grep -q "&lt;\|&gt;\|&amp;" "${MOCK_XML_FILE}"; then
    has_special_chars=true
  fi
  
  if [[ "${has_special_chars}" == "true" ]]; then
    echo "✓ Mock XML contains special characters for testing"
    
    # Test processing with special characters
    # Use existing AWK file for testing
    local awk_file="${SCRIPT_BASE_DIRECTORY}/awk/extract_notes.awk"
    local output_file="${TEST_OUTPUT_DIR}/mock_special_chars.csv"
    
    # Only test if awkproc is available
    if command -v awkproc > /dev/null 2>&1; then
      run awkproc --maxdepth "${XSLT_MAX_DEPTH:-4000}" -o "${output_file}" "${awk_file}" "${MOCK_XML_FILE}"
      
      [ "$status" -eq 0 ]
      [ -f "${output_file}" ]
      [ -s "${output_file}" ]
      
      echo "✓ Special characters processed successfully"
    else
      echo "ℹ awkproc not available, skipping special characters test"
    fi
  else
    echo "ℹ Mock XML does not contain special characters"
  fi
}

@test "Mock XML processing performance metrics" {
  # Skip if awkproc is not available
  if ! command -v awkproc > /dev/null 2>&1; then
    skip "awkproc not available, skipping performance test"
  fi
  
  # Use existing AWK file for testing
  local awk_file="${SCRIPT_BASE_DIRECTORY}/awk/extract_notes.awk"
  local output_file="${TEST_OUTPUT_DIR}/mock_performance.csv"
  
  # Measure processing time
  local start_time
  start_time=$(date +%s.%N)
  
  run awkproc --maxdepth "${XSLT_MAX_DEPTH:-4000}" -o "${output_file}" "${awk_file}" "${MOCK_XML_FILE}"
  
  local end_time
  end_time=$(date +%s.%N)
  
  [ "$status" -eq 0 ]
  [ -f "${output_file}" ]
  [ -s "${output_file}" ]
  
  # Calculate processing time
  local processing_time
  processing_time=$(echo "${end_time} - ${start_time}" | bc -l 2>/dev/null || echo "0")
  
  # Get file sizes
  local input_size
  input_size=$(stat -c%s "${MOCK_XML_FILE}" 2>/dev/null || echo "0")
  local output_size
  output_size=$(stat -c%s "${output_file}" 2>/dev/null || echo "0")
  
  # Get note counts
  local input_notes
  input_notes=$(grep -c "<note" "${MOCK_XML_FILE}" 2>/dev/null || echo "0")
  local output_lines
  output_lines=$(wc -l < "${output_file}")
  
  echo "Performance metrics:"
  echo "  Input: ${input_size} bytes, ${input_notes} notes"
  echo "  Output: ${output_size} bytes, ${output_lines} lines"
  echo "  Processing time: ${processing_time} seconds"
  
  # Basic performance assertions
  [ "${processing_time}" != "0" ]
  [ "${output_lines}" -gt 1 ]
  
  echo "✓ Performance metrics calculated successfully"
}
