#!/usr/bin/env bats

# Integration test for complete Planet XML processing using mock data
# Author: Andres Gomez
# Version: 2025-08-18

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

@test "XSLT processing works with mock Planet XML (notes CSV)" {
  local xslt_file="${SCRIPT_BASE_DIRECTORY}/xslt/notes-Planet-csv.xslt"
  local output_file="${TEST_OUTPUT_DIR}/mock_notes.csv"
  
  # Verify XSLT file exists
  [ -f "${xslt_file}" ]
  
  # Process XML with XSLT
  run xsltproc --maxdepth "${XSLT_MAX_DEPTH:-4000}" "${xslt_file}" "${MOCK_XML_FILE}" > "${output_file}" 2>&1
  
  [ "$status" -eq 0 ]
  [ -f "${output_file}" ]
  [ -s "${output_file}" ]
  
  # Verify CSV structure
  local line_count
  line_count=$(wc -l < "${output_file}")
  [ "${line_count}" -gt 1 ] # Header + data
  
  # Check first line (should be header)
  head -1 "${output_file}" | grep -q "id,lat,lon,created_at,status,closed_at,comment_count"
  
  # Check data lines
  tail -n +2 "${output_file}" | head -1 | grep -q "^[0-9]"
  
  echo "✓ Notes CSV generated successfully: ${line_count} lines"
}

@test "XSLT processing works with mock Planet XML (comments CSV)" {
  local xslt_file="${SCRIPT_BASE_DIRECTORY}/xslt/note_comments-Planet-csv.xslt"
  local output_file="${TEST_OUTPUT_DIR}/mock_comments.csv"
  
  # Verify XSLT file exists
  [ -f "${xslt_file}" ]
  
  # Process XML with XSLT
  run xsltproc --maxdepth "${XSLT_MAX_DEPTH:-4000}" "${xslt_file}" "${MOCK_XML_FILE}" > "${output_file}" 2>&1
  
  [ "$status" -eq 0 ]
  [ -f "${output_file}" ]
  [ -s "${output_file}" ]
  
  # Verify CSV structure
  local line_count
  line_count=$(wc -l < "${output_file}")
  [ "${line_count}" -gt 1 ] # Header + data
  
  # Check first line (should be header)
  head -1 "${output_file}" | grep -q "note_id,comment_id,action,timestamp,uid,user,text"
  
  # Check data lines
  tail -n +2 "${output_file}" | head -1 | grep -q "^[0-9]"
  
  echo "✓ Comments CSV generated successfully: ${line_count} lines"
}

@test "XSLT processing works with mock Planet XML (text comments CSV)" {
  local xslt_file="${SCRIPT_BASE_DIRECTORY}/xslt/note_comments_text-Planet-csv.xslt"
  local output_file="${TEST_OUTPUT_DIR}/mock_text_comments.csv"
  
  # Verify XSLT file exists
  [ -f "${xslt_file}" ]
  
  # Process XML with XSLT
  run xsltproc --maxdepth "${XSLT_MAX_DEPTH:-4000}" "${xslt_file}" "${MOCK_XML_FILE}" > "${output_file}" 2>&1
  
  [ "$status" -eq 0 ]
  [ -f "${output_file}" ]
  [ -s "${output_file}" ]
  
  # Verify CSV structure
  local line_count
  line_count=$(wc -l < "${output_file}")
  [ "${line_count}" -gt 1 ] # Header + data
  
  # Check first line (should be header)
  head -1 "${output_file}" | grep -q "note_id,comment_id,text"
  
  # Check data lines
  tail -n +2 "${output_file}" | head -1 | grep -q "^[0-9]"
  
  echo "✓ Text comments CSV generated successfully: ${line_count} lines"
}

@test "Mock XML can be processed with robust XSLT function" {
  local xslt_file="${SCRIPT_BASE_DIRECTORY}/xslt/notes-Planet-csv.xslt"
  local output_file="${TEST_OUTPUT_DIR}/mock_robust_notes.csv"
  
  # Test the robust XSLT processing function
  run __process_xml_with_xslt_robust "${MOCK_XML_FILE}" "${xslt_file}" "${output_file}" "" "" "" "false"
  
  [ "$status" -eq 0 ]
  [ -f "${output_file}" ]
  [ -s "${output_file}" ]
  
  echo "✓ Robust XSLT processing completed successfully"
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
    local xslt_file="${SCRIPT_BASE_DIRECTORY}/xslt/notes-Planet-csv.xslt"
    local output_file="${TEST_OUTPUT_DIR}/mock_special_chars.csv"
    
    run xsltproc --maxdepth "${XSLT_MAX_DEPTH:-4000}" "${xslt_file}" "${MOCK_XML_FILE}" > "${output_file}" 2>&1
    
    [ "$status" -eq 0 ]
    [ -f "${output_file}" ]
    [ -s "${output_file}" ]
    
    echo "✓ Special characters processed successfully"
  else
    echo "ℹ Mock XML does not contain special characters"
  fi
}

@test "Mock XML processing performance metrics" {
  local xslt_file="${SCRIPT_BASE_DIRECTORY}/xslt/notes-Planet-csv.xslt"
  local output_file="${TEST_OUTPUT_DIR}/mock_performance.csv"
  
  # Measure processing time
  local start_time
  start_time=$(date +%s.%N)
  
  run xsltproc --maxdepth "${XSLT_MAX_DEPTH:-4000}" "${xslt_file}" "${MOCK_XML_FILE}" > "${output_file}" 2>&1
  
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
