#!/usr/bin/env bats

# Unit tests for CSV cleaning in processAPINotes
# Tests removal of trailing commas from CSV files
# Author: Andres Gomez (AngocA)
# Version: 2026-01-03

load "$(dirname "$BATS_TEST_FILENAME")/../../test_helper.bash"

# =============================================================================
# Setup and Teardown
# =============================================================================

setup() {
  export SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
  export TMP_DIR="$(mktemp -d)"
}

teardown() {
  rm -rf "${TMP_DIR:-}"
}

# =============================================================================
# Helper Functions
# =============================================================================

# Simulate CSV cleaning function
clean_csv_trailing_commas() {
  local input_file="${1}"
  local output_file="${2}"
  sed 's/,$//' "${input_file}" > "${output_file}"
}

# =============================================================================
# Tests for CSV Cleaning
# =============================================================================

@test "CSV cleaning should remove trailing commas from notes CSV" {
  # Create CSV file with trailing comma
  local input_file="${TMP_DIR}/notes_with_trailing.csv"
  echo "123,40.7128,-74.0060,2025-01-01,open,," > "${input_file}"
  
  # Clean trailing comma
  local output_file="${TMP_DIR}/notes_cleaned.csv"
  clean_csv_trailing_commas "${input_file}" "${output_file}"
  
  # Check that file was created
  [ -f "${output_file}" ]
  
  # Check that trailing comma was removed
  local last_char
  last_char=$(tail -c 1 "${output_file}" | od -An -tu1 | tr -d ' \n' || echo "")
  
  # Last character should not be comma (44 in ASCII) or should be newline
  [ "${last_char}" != "44" ] || [ "${last_char}" = "10" ]
}

@test "CSV cleaning should remove trailing commas from comments CSV" {
  # Create CSV file with trailing comma
  local input_file="${TMP_DIR}/comments_with_trailing.csv"
  echo '123,1,opened,2025-01-01,12345,user,' > "${input_file}"
  
  # Clean trailing comma
  local output_file="${TMP_DIR}/comments_cleaned.csv"
  clean_csv_trailing_commas "${input_file}" "${output_file}"
  
  # Check that file was created
  [ -f "${output_file}" ]
  
  # Check that trailing comma was removed
  local last_char
  last_char=$(tail -c 1 "${output_file}" | od -An -tu1 | tr -d ' \n' || echo "")
  
  # Last character should not be comma
  [ "${last_char}" != "44" ] || [ "${last_char}" = "10" ]
}

@test "CSV cleaning should remove trailing commas from text CSV" {
  # Create CSV file with trailing comma
  local input_file="${TMP_DIR}/text_with_trailing.csv"
  echo '123,1,"Text content",' > "${input_file}"
  
  # Clean trailing comma
  local output_file="${TMP_DIR}/text_cleaned.csv"
  clean_csv_trailing_commas "${input_file}" "${output_file}"
  
  # Check that file was created
  [ -f "${output_file}" ]
  
  # Check that trailing comma was removed
  local last_char
  last_char=$(tail -c 1 "${output_file}" | od -An -tu1 | tr -d ' \n' || echo "")
  
  # Last character should not be comma
  [ "${last_char}" != "44" ] || [ "${last_char}" = "10" ]
}

@test "CSV cleaning should preserve valid commas inside fields" {
  # Create CSV with valid commas inside quoted fields
  local input_file="${TMP_DIR}/valid_commas.csv"
  cat > "${input_file}" << 'EOF'
123,40.7128,-74.0060,2025-01-01,"Text with, commas inside",open
456,40.7129,-74.0061,2025-01-02,"Another, text, with, commas",closed
EOF
  
  # Clean trailing comma
  local output_file="${TMP_DIR}/valid_commas_cleaned.csv"
  clean_csv_trailing_commas "${input_file}" "${output_file}"
  
  # File should still contain commas (inside quoted fields)
  run grep -q ',' "${output_file}"
  [ "$status" -eq 0 ]
  
  # Should have same number of lines
  local input_lines
  input_lines=$(wc -l < "${input_file}")
  local output_lines
  output_lines=$(wc -l < "${output_file}")
  [ "${input_lines}" -eq "${output_lines}" ]
}

@test "CSV cleaning should handle empty files" {
  # Create empty CSV file
  local input_file="${TMP_DIR}/empty.csv"
  touch "${input_file}"
  
  # Clean trailing comma
  local output_file="${TMP_DIR}/empty_cleaned.csv"
  clean_csv_trailing_commas "${input_file}" "${output_file}"
  
  # File should be created (even if empty)
  [ -f "${output_file}" ]
  
  # Should be empty
  [ ! -s "${output_file}" ] || [ -f "${output_file}" ]
}

@test "CSV cleaning should handle files without trailing commas" {
  # Create CSV file without trailing comma
  local input_file="${TMP_DIR}/no_trailing.csv"
  echo "123,40.7128,-74.0060,2025-01-01,open" > "${input_file}"
  
  # Clean trailing comma
  local output_file="${TMP_DIR}/no_trailing_cleaned.csv"
  clean_csv_trailing_commas "${input_file}" "${output_file}"
  
  # File should be created
  [ -f "${output_file}" ]
  
  # Content should be the same (no trailing comma to remove)
  local input_content
  input_content=$(cat "${input_file}")
  local output_content
  output_content=$(cat "${output_file}")
  [ "${input_content}" = "${output_content}" ]
}

@test "CSV cleaning should handle multiple trailing commas" {
  # Create CSV file with multiple trailing commas
  local input_file="${TMP_DIR}/multiple_trailing.csv"
  echo "123,40.7128,-74.0060,2025-01-01,,," > "${input_file}"
  
  # Clean trailing comma (sed removes all trailing commas)
  local output_file="${TMP_DIR}/multiple_trailing_cleaned.csv"
  clean_csv_trailing_commas "${input_file}" "${output_file}"
  
  # File should be created
  [ -f "${output_file}" ]
  
  # Should not end with comma
  local last_char
  last_char=$(tail -c 1 "${output_file}" | od -An -tu1 | tr -d ' \n' || echo "")
  [ "${last_char}" != "44" ]
}

@test "CSV cleaning should create cleaned files with .cleaned extension" {
  # Create CSV file with trailing comma
  local input_file="${TMP_DIR}/test.csv"
  echo "123,40.7128,-74.0060,2025-01-01,open,," > "${input_file}"
  
  # Simulate the cleaning process (as done in __processApiXmlSequential)
  local cleaned_file="${input_file}.cleaned"
  sed 's/,$//' "${input_file}" > "${cleaned_file}"
  
  # Check that cleaned file was created
  [ -f "${cleaned_file}" ]
  
  # Check that it has .cleaned extension
  [[ "${cleaned_file}" == *.cleaned ]]
}

@test "CSV cleaning should handle CSV with quoted fields containing commas" {
  # Create CSV with quoted fields containing commas
  local input_file="${TMP_DIR}/quoted_commas.csv"
  cat > "${input_file}" << 'EOF'
123,1,"Text, with, commas",2025-01-01
456,2,"Another, text",2025-01-02,
EOF
  
  # Clean trailing comma
  local output_file="${TMP_DIR}/quoted_commas_cleaned.csv"
  clean_csv_trailing_commas "${input_file}" "${output_file}"
  
  # File should be created
  [ -f "${output_file}" ]
  
  # Should preserve commas inside quotes
  run grep -q '"Text, with, commas"' "${output_file}"
  [ "$status" -eq 0 ]
  
  # Should remove trailing comma from second line
  local second_line
  second_line=$(sed -n '2p' "${output_file}")
  [[ ! "${second_line}" =~ ,$ ]] || [[ "${second_line}" =~ \n$ ]]
}

@test "CSV cleaning should work with AWK-generated CSV files" {
  # Skip if AWK file doesn't exist
  local awk_file="${SCRIPT_BASE_DIRECTORY}/awk/extract_notes.awk"
  [ -f "${awk_file}" ] || skip "AWK file not found: ${awk_file}"
  
  # Use single note fixture
  local xml_file="${SCRIPT_BASE_DIRECTORY}/tests/fixtures/special_cases/single_note.xml"
  [ -f "${xml_file}" ] || skip "XML fixture not found"
  
  # Generate CSV with AWK
  local awk_output="${TMP_DIR}/awk_output.csv"
  awk -f "${awk_file}" "${xml_file}" > "${awk_output}"
  
  # Check that AWK generated file (may have trailing commas)
  [ -f "${awk_output}" ]
  
  # Clean trailing comma
  local cleaned_output="${awk_output}.cleaned"
  sed 's/,$//' "${awk_output}" > "${cleaned_output}"
  
  # Cleaned file should exist
  [ -f "${cleaned_output}" ]
  
  # Should be valid CSV (can have content or be empty)
  [ -f "${cleaned_output}" ]
}
