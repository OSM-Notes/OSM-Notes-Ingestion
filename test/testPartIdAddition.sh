#!/bin/bash

# Test script for part_id addition to CSV files
# Tests that part_id is correctly added to the end of each CSV line
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-23

set -euo pipefail

# Define required variables
declare BASENAME="testPartIdAddition"
declare TMP_DIR="/tmp/${BASENAME}_$$"
mkdir -p "${TMP_DIR}"

# Simple logging functions for testing
function log_info() {
 echo "$(date '+%Y-%m-%d %H:%M:%S') - INFO - $*"
}

function log_error() {
 echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR - $*" >&2
}

# Test function to create sample CSV
function create_sample_csv() {
 local CSV_FILE="${1}"

 log_info "Creating sample CSV file: ${CSV_FILE}"

 cat > "${CSV_FILE}" << 'EOF'
123,40.7128,-74.0060,"2013-04-28T02:39:27Z","close","2013-04-29T10:15:30Z",
456,34.0522,-118.2437,"2013-04-30T15:20:45Z","open",,
789,51.5074,-0.1278,"2013-05-01T12:00:00Z","close","2013-05-02T14:30:00Z",
EOF

 log_info "Sample CSV created with 3 lines (without part_id)"
}

# Test function to add part_id
function add_part_id() {
 local CSV_FILE="${1}"
 local PART_ID="${2}"

 log_info "Adding part_id ${PART_ID} to CSV file: ${CSV_FILE}"

 # Add part_id to the end of each line
 awk -v part_id="${PART_ID}" '{print $0 "," part_id}' "${CSV_FILE}" > "${CSV_FILE}.tmp" && mv "${CSV_FILE}.tmp" "${CSV_FILE}"

 log_info "Part_id ${PART_ID} added to CSV file"
}

# Test function to verify part_id addition
function verify_part_id_addition() {
 local CSV_FILE="${1}"
 local EXPECTED_PART_ID="${2}"

 log_info "Verifying part_id addition in CSV file: ${CSV_FILE}"

 if [[ ! -f "${CSV_FILE}" ]]; then
  log_error "CSV file not found: ${CSV_FILE}"
  return 1
 fi

 log_info "CSV content after part_id addition:"
 sed 's/^/  /' < "${CSV_FILE}"

 # Check each line to ensure part_id is added correctly
 local LINE_NUM=0
 declare ALL_CORRECT=true

 while IFS= read -r line; do
  LINE_NUM=$((LINE_NUM + 1))

  # Check if line ends with the expected part_id
  if [[ "${line}" == *",${EXPECTED_PART_ID}" ]]; then
   log_info "Line ${LINE_NUM}: ✓ Correctly ends with part_id ${EXPECTED_PART_ID}"
  else
   log_error "Line ${LINE_NUM}: ✗ Does not end with part_id ${EXPECTED_PART_ID}"
   log_error "  Line content: ${line}"
   ALL_CORRECT=false
  fi

  # Count commas to ensure we have the right number of fields
  declare -i COMMA_COUNT
  COMMA_COUNT=$(echo "${line}" | tr -cd ',' | wc -c)
  declare -i EXPECTED_COMMAS=7 # 7 commas for 8 fields: note_id,lat,lon,created_at,status,closed_at,id_country,part_id

  if [[ ${COMMA_COUNT} -eq ${EXPECTED_COMMAS} ]]; then
   log_info "Line ${LINE_NUM}: ✓ Has correct number of fields (${EXPECTED_COMMAS} commas)"
  else
   log_error "Line ${LINE_NUM}: ✗ Has incorrect number of fields (${COMMA_COUNT} commas, expected ${EXPECTED_COMMAS})"
   ALL_CORRECT=false
  fi

 done < "${CSV_FILE}"

 if [[ "${ALL_CORRECT}" == true ]]; then
  log_info "SUCCESS: All lines have correct part_id and field count"
  return 0
 else
  log_error "FAILED: Some lines have incorrect part_id or field count"
  return 1
 fi
}

# Test function to simulate SQL COPY
function test_sql_copy_simulation() {
 local CSV_FILE="${1}"
 local PART_ID="${2}"

 log_info "Simulating SQL COPY command with CSV: ${CSV_FILE}"
 log_info "Expected part_id: ${PART_ID}"

 # Parse the CSV and show what would be inserted
 log_info "Simulated INSERT statements:"

 declare -i LINE_NUM=0
 while IFS= read -r line; do
  LINE_NUM=$((LINE_NUM + 1))

  # Parse CSV line (simple parsing, assumes no commas in quoted fields)
  IFS=',' read -ra FIELDS <<< "${line}"

  if [[ ${#FIELDS[@]} -eq 8 ]]; then
   declare NOTE_ID="${FIELDS[0]}"
   declare LAT="${FIELDS[1]}"
   declare LON="${FIELDS[2]}"
   declare CREATED_AT="${FIELDS[3]//\"/}"
   declare STATUS="${FIELDS[4]//\"/}"
   declare CLOSED_AT="${FIELDS[5]//\"/}"
   declare ID_COUNTRY="${FIELDS[6]}"
   declare ACTUAL_PART_ID="${FIELDS[7]}"

   log_info "Line ${LINE_NUM}: INSERT INTO notes_sync_part_${PART_ID} (...) VALUES (${NOTE_ID}, ${LAT}, ${LON}, '${CREATED_AT}', '${STATUS}', ${CLOSED_AT:+"'${CLOSED_AT}'"}, ${ID_COUNTRY:+"'${ID_COUNTRY}'"}, ${ACTUAL_PART_ID});"

   # Check if part_id matches expected
   if [[ "${ACTUAL_PART_ID}" == "${PART_ID}" ]]; then
    log_info "  ✓ Part_id '${ACTUAL_PART_ID}' matches expected '${PART_ID}'"
   else
    log_error "  ✗ Part_id '${ACTUAL_PART_ID}' does not match expected '${PART_ID}'"
    return 1
   fi
  else
   log_error "Line ${LINE_NUM} has ${#FIELDS[@]} fields, expected 8"
   return 1
  fi
 done < "${CSV_FILE}"

 log_info "SUCCESS: All lines would insert correctly into database with correct part_id"
 return 0
}

# Run tests
function run_tests() {
 local PART_ID="${1:-5}"
 local CSV_FILE="${TMP_DIR}/sample.csv"

 log_info "Starting part_id addition tests"
 log_info "Test part_id: ${PART_ID}"

 # Test 1: Create sample CSV
 log_info "Test 1: Creating sample CSV"
 if create_sample_csv "${CSV_FILE}"; then
  log_info "Test 1 PASSED"
 else
  log_error "Test 1 FAILED"
  return 1
 fi

 # Test 2: Add part_id
 log_info "Test 2: Adding part_id to CSV"
 if add_part_id "${CSV_FILE}" "${PART_ID}"; then
  log_info "Test 2 PASSED"
 else
  log_error "Test 2 FAILED"
  return 1
 fi

 # Test 3: Verify part_id addition
 log_info "Test 3: Verifying part_id addition"
 if verify_part_id_addition "${CSV_FILE}" "${PART_ID}"; then
  log_info "Test 3 PASSED"
 else
  log_error "Test 3 FAILED"
  return 1
 fi

 # Test 4: Simulate SQL COPY
 log_info "Test 4: Simulating SQL COPY command"
 if test_sql_copy_simulation "${CSV_FILE}" "${PART_ID}"; then
  log_info "Test 4 PASSED"
 else
  log_error "Test 4 FAILED"
  return 1
 fi

 log_info "All part_id addition tests completed successfully"
}

# Cleanup function
# shellcheck disable=SC2317
function cleanup() {
 if [[ -d "${TMP_DIR}" ]]; then
  rm -rf "${TMP_DIR}"
 fi
}

# Main execution
function main() {
 log_info "Starting part_id addition tests"

 # Set up cleanup trap
 trap cleanup EXIT

 # Get PART_ID from command line or use default
 local PART_ID="${1:-5}"

 # Run tests
 if run_tests "${PART_ID}"; then
  log_info "All part_id addition tests PASSED"
  exit 0
 else
  log_error "Some part_id addition tests FAILED"
  exit 1
 fi
}

# Execute main function
main "$@"
