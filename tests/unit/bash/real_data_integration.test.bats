#!/usr/bin/env bats

# Real data integration tests using fixtures
# Author: Andres Gomez (AngocA)
# Version: 2025-08-01

setup() {
 # Setup test environment
 export SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
 export TMP_DIR="$(mktemp -d)"
 export BASENAME="test_real_data_integration"
 export LOG_LEVEL="INFO"
 
 # Ensure TMP_DIR exists and is writable
 if [[ ! -d "${TMP_DIR}" ]]; then
   mkdir -p "${TMP_DIR}" || { echo "ERROR: Could not create TMP_DIR: ${TMP_DIR}" >&2; exit 1; }
 fi
 if [[ ! -w "${TMP_DIR}" ]]; then
   echo "ERROR: TMP_DIR not writable: ${TMP_DIR}" >&2; exit 1;
 fi
 
 # Set fixtures directory
 export FIXTURES_DIR="${SCRIPT_BASE_DIRECTORY}/tests/fixtures"
}

teardown() {
 # Cleanup
 rm -rf "${TMP_DIR}"
}

# Test with real planet data
@test "real planet data should be valid XML" {
 local test_file="${FIXTURES_DIR}/xml/planet_notes_real.xml"
 
 # Check if file exists
 if [[ ! -f "$test_file" ]]; then
   skip "Real planet data file not found: $test_file"
 fi
 
 # Test XML validation
 run xmllint --noout "$test_file"
 [ "$status" -eq 0 ]
}

@test "real planet data should contain notes" {
 local test_file="${FIXTURES_DIR}/xml/planet_notes_real.xml"
 
 # Check if file exists
 if [[ ! -f "$test_file" ]]; then
   skip "Real planet data file not found: $test_file"
 fi
 
 # Count notes
 run xmllint --xpath "count(//note)" "$test_file"
 [ "$status" -eq 0 ]
 [[ "$output" =~ ^[0-9]+$ ]]
 [[ "$output" -gt 0 ]]
}

@test "real planet data should transform to CSV" {
 local test_file="${FIXTURES_DIR}/xml/planet_notes_real.xml"
 local xslt_file="${SCRIPT_BASE_DIRECTORY}/xslt/notes-Planet-csv.xslt"
 
 # Check if files exist
 if [[ ! -f "$test_file" ]]; then
   skip "Real planet data file not found: $test_file"
 fi
 
 if [[ ! -f "$xslt_file" ]]; then
   skip "XSLT file not found: $xslt_file"
 fi
 
 # Test XSLT transformation
 run xsltproc "$xslt_file" "$test_file"
 [ "$status" -eq 0 ]
 [[ "$output" == *","* ]]  # Should contain CSV format
}

# Test with special cases
@test "zero notes should be handled correctly" {
 local test_file="${FIXTURES_DIR}/special_cases/zero_notes.xml"
 
 # Check if file exists
 if [[ ! -f "$test_file" ]]; then
   skip "Zero notes file not found: $test_file"
 fi
 
 # Test XML validation
 run xmllint --noout "$test_file"
 [ "$status" -eq 0 ]
 
 # Count notes (should be 0)
 run xmllint --xpath "count(//note)" "$test_file"
 [ "$status" -eq 0 ]
 [[ "$output" == "0" ]]
}

@test "single note should be processed correctly" {
 local test_file="${FIXTURES_DIR}/special_cases/single_note.xml"
 
 # Check if file exists
 if [[ ! -f "$test_file" ]]; then
   skip "Single note file not found: $test_file"
 fi
 
 # Test XML validation
 run xmllint --noout "$test_file"
 [ "$status" -eq 0 ]
 
 # Count notes (should be 1)
 run xmllint --xpath "count(//note)" "$test_file"
 [ "$status" -eq 0 ]
 [[ "$output" == "1" ]]
}

@test "less than threads should be processed correctly" {
 local test_file="${FIXTURES_DIR}/special_cases/less_than_threads.xml"
 
 # Check if file exists
 if [[ ! -f "$test_file" ]]; then
   skip "Less than threads file not found: $test_file"
 fi
 
 # Test XML validation
 run xmllint --noout "$test_file"
 [ "$status" -eq 0 ]
 
 # Count notes (should be 5)
 run xmllint --xpath "count(//note)" "$test_file"
 [ "$status" -eq 0 ]
 [[ "$output" == "5" ]]
}

@test "equal to cores should be processed correctly" {
 local test_file="${FIXTURES_DIR}/special_cases/equal_to_cores.xml"
 
 # Check if file exists
 if [[ ! -f "$test_file" ]]; then
   skip "Equal to cores file not found: $test_file"
 fi
 
 # Test XML validation
 run xmllint --noout "$test_file"
 [ "$status" -eq 0 ]
 
 # Count notes (should be 12)
 run xmllint --xpath "count(//note)" "$test_file"
 [ "$status" -eq 0 ]
 [[ "$output" == "12" ]]
}

@test "many more than cores should be processed correctly" {
 local test_file="${FIXTURES_DIR}/special_cases/many_more_than_cores.xml"
 
 # Check if file exists
 if [[ ! -f "$test_file" ]]; then
   skip "Many more than cores file not found: $test_file"
 fi
 
 # Test XML validation
 run xmllint --noout "$test_file"
 [ "$status" -eq 0 ]
 
 # Count notes (should be 25)
 run xmllint --xpath "count(//note)" "$test_file"
 [ "$status" -eq 0 ]
 [[ "$output" == "25" ]]
}

# Test error cases
@test "double close should be handled gracefully" {
 local test_file="${FIXTURES_DIR}/special_cases/double_close.xml"
 
 # Check if file exists
 if [[ ! -f "$test_file" ]]; then
   skip "Double close file not found: $test_file"
 fi
 
 # Test XML validation
 run xmllint --noout "$test_file"
 [ "$status" -eq 0 ]
 
 # Count notes
 run xmllint --xpath "count(//note)" "$test_file"
 [ "$status" -eq 0 ]
 [[ "$output" =~ ^[0-9]+$ ]]
}

@test "double reopen should be handled gracefully" {
 local test_file="${FIXTURES_DIR}/special_cases/double_reopen.xml"
 
 # Check if file exists
 if [[ ! -f "$test_file" ]]; then
   skip "Double reopen file not found: $test_file"
 fi
 
 # Test XML validation
 run xmllint --noout "$test_file"
 [ "$status" -eq 0 ]
 
 # Count notes
 run xmllint --xpath "count(//note)" "$test_file"
 [ "$status" -eq 0 ]
 [[ "$output" =~ ^[0-9]+$ ]]
}

@test "create and close should be handled correctly" {
 local test_file="${FIXTURES_DIR}/special_cases/create_and_close.xml"
 
 # Check if file exists
 if [[ ! -f "$test_file" ]]; then
   skip "Create and close file not found: $test_file"
 fi
 
 # Test XML validation
 run xmllint --noout "$test_file"
 [ "$status" -eq 0 ]
 
 # Count notes
 run xmllint --xpath "count(//note)" "$test_file"
 [ "$status" -eq 0 ]
 [[ "$output" =~ ^[0-9]+$ ]]
}

@test "close and reopen should be handled correctly" {
 local test_file="${FIXTURES_DIR}/special_cases/close_and_reopen.xml"
 
 # Check if file exists
 if [[ ! -f "$test_file" ]]; then
   skip "Close and reopen file not found: $test_file"
 fi
 
 # Test XML validation
 run xmllint --noout "$test_file"
 [ "$status" -eq 0 ]
 
 # Count notes
 run xmllint --xpath "count(//note)" "$test_file"
 [ "$status" -eq 0 ]
 [[ "$output" =~ ^[0-9]+$ ]]
}

@test "open close reopen should be handled correctly" {
 local test_file="${FIXTURES_DIR}/special_cases/open_close_reopen.xml"
 
 # Check if file exists
 if [[ ! -f "$test_file" ]]; then
   skip "Open close reopen file not found: $test_file"
 fi
 
 # Test XML validation
 run xmllint --noout "$test_file"
 [ "$status" -eq 0 ]
 
 # Count notes
 run xmllint --xpath "count(//note)" "$test_file"
 [ "$status" -eq 0 ]
 [[ "$output" =~ ^[0-9]+$ ]]
}

@test "open close reopen cycle should be handled correctly" {
 local test_file="${FIXTURES_DIR}/special_cases/open_close_reopen_cycle.xml"
 
 # Check if file exists
 if [[ ! -f "$test_file" ]]; then
   skip "Open close reopen cycle file not found: $test_file"
 fi
 
 # Test XML validation
 run xmllint --noout "$test_file"
 [ "$status" -eq 0 ]
 
 # Count notes
 run xmllint --xpath "count(//note)" "$test_file"
 [ "$status" -eq 0 ]
 [[ "$output" =~ ^[0-9]+$ ]]
}

@test "comment and close should be handled correctly" {
 local test_file="${FIXTURES_DIR}/special_cases/comment_and_close.xml"
 
 # Check if file exists
 if [[ ! -f "$test_file" ]]; then
   skip "Comment and close file not found: $test_file"
 fi
 
 # Test XML validation
 run xmllint --noout "$test_file"
 [ "$status" -eq 0 ]
 
 # Count notes
 run xmllint --xpath "count(//note)" "$test_file"
 [ "$status" -eq 0 ]
 [[ "$output" =~ ^[0-9]+$ ]]
}

# Test large dataset
@test "large dataset should be processed correctly" {
 local test_file="${FIXTURES_DIR}/xml/large_planet_notes.xml"
 
 # Check if file exists
 if [[ ! -f "$test_file" ]]; then
   skip "Large dataset file not found: $test_file"
 fi
 
 # Test XML validation
 run xmllint --noout "$test_file"
 [ "$status" -eq 0 ]
 
 # Count notes
 run xmllint --xpath "count(//note)" "$test_file"
 [ "$status" -eq 0 ]
 [[ "$output" =~ ^[0-9]+$ ]]
 [[ "$output" -gt 0 ]]
}

# Test XSLT transformations for all special cases
@test "all special cases should transform to CSV" {
 local xslt_file="${SCRIPT_BASE_DIRECTORY}/xslt/notes-API-csv.xslt"
 
 # Check if XSLT file exists
 if [[ ! -f "$xslt_file" ]]; then
   skip "XSLT file not found: $xslt_file"
 fi
 
 # Test each special case
 for xml_file in "${FIXTURES_DIR}/special_cases"/*.xml; do
   if [[ -f "$xml_file" ]]; then
     local case_name=$(basename "$xml_file" .xml)
     
     # Test XSLT transformation
     run xsltproc "$xslt_file" "$xml_file"
     [ "$status" -eq 0 ]
     [[ "$output" == *","* ]]  # Should contain CSV format
   fi
 done
}

# Test database operations with real data
@test "database operations should work with real data" {
 # Skip if psql is not available
 if ! command -v psql >/dev/null 2>&1; then
   skip "psql not available"
 fi
 
 # Skip if database is not accessible
 if ! psql -d "${DBNAME:-osm_notes}" -c "SELECT 1;" >/dev/null 2>&1; then
   skip "Database not accessible"
 fi
 
 # Test basic database operation
 run psql -d "${DBNAME:-osm_notes}" -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';"
 [ "$status" -eq 0 ]
 [[ "$output" == *"count"* ]] || [[ "$output" == *"[0-9]"* ]]
}

# Test end-to-end workflow with real data
@test "end-to-end workflow should work with real data" {
 local test_file="${FIXTURES_DIR}/xml/planet_notes_real.xml"
 local xslt_file="${SCRIPT_BASE_DIRECTORY}/xslt/notes-Planet-csv.xslt"
 
 # Check if files exist
 if [[ ! -f "$test_file" ]]; then
   skip "Real planet data file not found: $test_file"
 fi
 
 if [[ ! -f "$xslt_file" ]]; then
   skip "XSLT file not found: $xslt_file"
 fi
 
 # Copy test file to temporary location
 cp "$test_file" "${TMP_DIR}/planet_notes.xml"
 
 # Test XML validation
 run xmllint --noout "${TMP_DIR}/planet_notes.xml"
 [ "$status" -eq 0 ]
 
 # Count notes
 run xmllint --xpath "count(//note)" "${TMP_DIR}/planet_notes.xml"
 [ "$status" -eq 0 ]
 local note_count="$output"
 [[ "$note_count" =~ ^[0-9]+$ ]]
 [[ "$note_count" -gt 0 ]]
 
 # Test XSLT transformation
 run xsltproc "$xslt_file" "${TMP_DIR}/planet_notes.xml" > "${TMP_DIR}/notes.csv"
 [ "$status" -eq 0 ]
 [ -f "${TMP_DIR}/notes.csv" ]
 
 # Check CSV output
 run wc -l < "${TMP_DIR}/notes.csv"
 [ "$status" -eq 0 ]
 local csv_lines="$output"
 [[ "$csv_lines" -gt 0 ]]
} 