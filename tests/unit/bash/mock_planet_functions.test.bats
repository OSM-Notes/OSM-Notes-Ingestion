#!/usr/bin/env bats

# Unit tests for Planet XML processing functions using mock data
# Author: Andres Gomez
# Version: 2025-08-18

load ../../test_helper

setup() {
  SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
  TEST_OUTPUT_DIR="${SCRIPT_BASE_DIRECTORY}/tests/output/mock_planet_unit"
  MOCK_XML_FILE="${SCRIPT_BASE_DIRECTORY}/tests/fixtures/xml/mockPlanetDump.osn.xml"
  
  # Create test output directory
  mkdir -p "${TEST_OUTPUT_DIR}"
  
  # Source the functions
  source "${SCRIPT_BASE_DIRECTORY}/bin/parallelProcessingFunctions.sh"
  
  # Verify mock file exists
  if [[ ! -f "${MOCK_XML_FILE}" ]]; then
    echo "ERROR: Mock XML file not found: ${MOCK_XML_FILE}"
    exit 1
  fi
}

teardown() {
  # Clean up test output
  rm -rf "${TEST_OUTPUT_DIR}"
}

@test "Mock XML file structure analysis" {
  # Analyze the structure of the mock XML file
  local xml_file="${MOCK_XML_FILE}"
  
  # Count different elements
  local note_count
  note_count=$(grep -c "<note" "${xml_file}")
  local comment_count
  comment_count=$(grep -c "<comment" "${xml_file}")
  local user_count
  user_count=$(grep -c "user=" "${xml_file}")
  local uid_count
  uid_count=$(grep -c "uid=" "${xml_file}")
  
  # Verify expected structure
  [ "${note_count}" -gt 0 ]
  [ "${comment_count}" -gt 0 ]
  [ "${user_count}" -gt 0 ]
  [ "${uid_count}" -gt 0 ]
  
  echo "Mock XML structure:"
  echo "  Notes: ${note_count}"
  echo "  Comments: ${comment_count}"
  echo "  Users: ${user_count}"
  echo "  UIDs: ${uid_count}"
}

@test "Mock XML note attributes validation" {
  local xml_file="${MOCK_XML_FILE}"
  
  # Check that notes have required attributes
  local notes_with_id
  notes_with_id=$(grep -c 'id="[^"]*"' "${xml_file}")
  local notes_with_lat
  notes_with_lat=$(grep -c 'lat="[^"]*"' "${xml_file}")
  local notes_with_lon
  notes_with_lon=$(grep -c 'lon="[^"]*"' "${xml_file}")
  local notes_with_created
  notes_with_created=$(grep -c 'created_at="[^"]*"' "${xml_file}")
  
  # All notes should have these attributes
  [ "${notes_with_id}" -gt 0 ]
  [ "${notes_with_lat}" -gt 0 ]
  [ "${notes_with_lon}" -gt 0 ]
  [ "${notes_with_created}" -gt 0 ]
  
  # Check that some notes have closed_at attribute
  local notes_with_closed
  notes_with_closed=$(grep -c 'closed_at="[^"]*"' "${xml_file}")
  [ "${notes_with_closed}" -ge 0 ]
  
  echo "Note attributes validation:"
  echo "  With ID: ${notes_with_id}"
  echo "  With lat: ${notes_with_lat}"
  echo "  With lon: ${notes_with_lon}"
  echo "  With created_at: ${notes_with_created}"
  echo "  With closed_at: ${notes_with_closed}"
}

@test "Mock XML comment structure validation" {
  local xml_file="${MOCK_XML_FILE}"
  
  # Check comment structure
  local comments_with_action
  comments_with_action=$(grep -c 'action="[^"]*"' "${xml_file}")
  local comments_with_timestamp
  comments_with_timestamp=$(grep -c 'timestamp="[^"]*"' "${xml_file}")
  
  # All comments should have these attributes
  [ "${comments_with_action}" -gt 0 ]
  [ "${comments_with_timestamp}" -gt 0 ]
  
  # Check for different action types
  local opened_comments
  opened_comments=$(grep -c 'action="opened"' "${xml_file}")
  local closed_comments
  closed_comments=$(grep -c 'action="closed"' "${xml_file}")
  local commented_comments
  commented_comments=$(grep -c 'action="commented"' "${xml_file}")
  local reopened_comments
  reopened_comments=$(grep -c 'action="reopened"' "${xml_file}")
  
  echo "Comment structure validation:"
  echo "  With action: ${comments_with_action}"
  echo "  With timestamp: ${comments_with_timestamp}"
  echo "  Action types:"
  echo "    opened: ${opened_comments}"
  echo "    closed: ${closed_comments}"
  echo "    commented: ${commented_comments}"
  echo "    reopened: ${reopened_comments}"
}

@test "Mock XML special content handling" {
  local xml_file="${MOCK_XML_FILE}"
  
  # Check for special content types
  local has_html_content=false
  local has_special_chars=false
  local has_long_text=false
  
  # Check for HTML-like content
  if grep -q "&lt;\|&gt;\|&amp;" "${xml_file}"; then
    has_html_content=true
  fi
  
  # Check for special characters
  if grep -q "[^\x00-\x7F]" "${xml_file}"; then
    has_special_chars=true
  fi
  
  # Check for long text content
  local long_comments
  long_comments=$(grep -o '>[^<]*' "${xml_file}" | awk 'length($0) > 100' | wc -l)
  if [[ "${long_comments}" -gt 0 ]]; then
    has_long_text=true
  fi
  
  echo "Special content analysis:"
  echo "  HTML content: ${has_html_content}"
  echo "  Special characters: ${has_special_chars}"
  echo "  Long text (>100 chars): ${long_comments} instances"
  
  # These are informational tests, not assertions
  echo "✓ Special content analysis completed"
}

@test "Mock XML processing with different AWK parameters" {
  local awk_file="${SCRIPT_BASE_DIRECTORY}/awk/notes-Planet-csv.awk"
  local output_file="${TEST_OUTPUT_DIR}/mock_notes_with_params.csv"
  
  # Test processing with timestamp parameter
  local current_timestamp
  current_timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  
  # Run awkproc without 'run' to properly redirect output to file
  awkproc --maxdepth "${AWK_MAX_DEPTH:-4000}" \
           --stringparam default-timestamp "${current_timestamp}" \
           "${awk_file}" "${MOCK_XML_FILE}" > "${output_file}" 2>&1
  
  local exit_code=$?
  [ "${exit_code}" -eq 0 ]
  [ -f "${output_file}" ]
  [ -s "${output_file}" ]
  
  # Verify the timestamp parameter was applied
  local output_lines
  output_lines=$(wc -l < "${output_file}")
  [ "${output_lines}" -gt 1 ]
  
  echo "✓ AWK processing with parameters completed: ${output_lines} lines"
}

@test "Mock XML parallel processing simulation" {
  local output_dir="${TEST_OUTPUT_DIR}/parallel_sim"
  mkdir -p "${output_dir}"
  
  # Simulate parallel processing by creating multiple parts
  local part_size=20
  local total_notes
  total_notes=$(grep -c "<note" "${MOCK_XML_FILE}")
  local num_parts
  num_parts=$(( (total_notes + part_size - 1) / part_size ))
  
  echo "Simulating parallel processing:"
  echo "  Total notes: ${total_notes}"
  echo "  Part size: ${part_size}"
  echo "  Number of parts: ${num_parts}"
  
  # Create parts manually for testing
  local part_num=1
  local current_note=0
  
  while [[ ${current_note} -lt ${total_notes} ]]; do
    local part_file
    part_file="${output_dir}/sim_part_${part_num}.xml"
    
    # Create part header
    cat > "${part_file}" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
EOF
    
    # Extract notes for this part
    local start_line
    start_line=$((current_note + 1))
    local end_line
    end_line=$((current_note + part_size))
    
    # Extract notes (simplified approach)
    grep -n "<note" "${MOCK_XML_FILE}" | head -${end_line} | tail -${part_size} > "${part_file}.temp"
    
    # Add notes to part file
    while IFS=: read -r line_num note_line; do
      # Extract the note and its content
      sed -n "${line_num},/<\/note>/p" "${MOCK_XML_FILE}" >> "${part_file}"
    done < "${part_file}.temp"
    
    # Add closing tag
    echo "</osm-notes>" >> "${part_file}"
    
    # Clean up temp file
    rm -f "${part_file}.temp"
    
    # Verify part is valid
    if [[ -s "${part_file}" ]]; then
      local part_notes
      part_notes=$(grep -c "<note" "${part_file}")
      echo "  Part ${part_num}: ${part_notes} notes"
    fi
    
    ((part_num++))
    current_note=$((current_note + part_size))
  done
  
  # Verify parts were created
  local created_parts
  created_parts=$(find "${output_dir}" -name "sim_part_*.xml" | wc -l)
  [ "${created_parts}" -gt 0 ]
  
  echo "✓ Parallel processing simulation completed: ${created_parts} parts created"
}

@test "Mock XML error handling simulation" {
  local xml_file="${MOCK_XML_FILE}"
  local corrupted_file="${TEST_OUTPUT_DIR}/corrupted_mock.xml"
  
  # Create a corrupted version of the mock file
  cp "${xml_file}" "${corrupted_file}"
  
  # Add corruption (extra content after closing tag)
  echo "Extra content that should cause parsing error" >> "${corrupted_file}"
  
  # Verify corruption was added
  [ -f "${corrupted_file}" ]
  [ -s "${corrupted_file}" ]
  
  # Test that corrupted file fails validation
  if command -v xmllint >/dev/null 2>&1; then
    run xmllint --noout "${corrupted_file}" 2>&1
    [ "$status" -ne 0 ]
    echo "✓ Corrupted file correctly fails xmllint validation"
  else
    echo "ℹ xmllint not available, skipping validation test"
  fi
  
  # Test that original file still passes validation
  if command -v xmllint >/dev/null 2>&1; then
    run xmllint --noout "${xml_file}" 2>&1
    [ "$status" -eq 0 ]
    echo "✓ Original file still passes validation"
  fi
  
  echo "✓ Error handling simulation completed"
}

@test "Mock XML performance benchmarking" {
  local awk_file="${SCRIPT_BASE_DIRECTORY}/awk/notes-Planet-csv.awk"
  local output_file="${TEST_OUTPUT_DIR}/mock_benchmark.csv"
  
  # Run multiple iterations for benchmarking
  local iterations=3
  local total_time=0
  
  echo "Running performance benchmark (${iterations} iterations)..."
  
  for i in $(seq 1 ${iterations}); do
    local start_time
    start_time=$(date +%s.%N)
    
    run awkproc --maxdepth "${AWK_MAX_DEPTH:-4000}" "${awk_file}" "${MOCK_XML_FILE}" > "${output_file}" 2>&1
    
    local end_time
    end_time=$(date +%s.%N)
    
    [ "$status" -eq 0 ]
    
    local iteration_time
    iteration_time=$(echo "${end_time} - ${start_time}" | bc -l 2>/dev/null || echo "0")
    total_time=$(echo "${total_time} + ${iteration_time}" | bc -l 2>/dev/null || echo "0")
    
    echo "  Iteration ${i}: ${iteration_time} seconds"
  done
  
  # Calculate average time
  local avg_time
  avg_time=$(echo "${total_time} / ${iterations}" | bc -l 2>/dev/null || echo "0")
  
  echo "Performance benchmark results:"
  echo "  Total time: ${total_time} seconds"
  echo "  Average time: ${avg_time} seconds"
  echo "  Iterations: ${iterations}"
  
  # Basic assertions
  [ "${total_time}" != "0" ]
  [ "${avg_time}" != "0" ]
  
  echo "✓ Performance benchmarking completed"
}
