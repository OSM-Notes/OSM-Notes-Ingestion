#!/usr/bin/env bats

# Test CSV enum validation function
# Author: Andres Gomez (AngocA)
# Version: 2025-08-03

# Define logging functions for testing
function __logd() { echo "DEBUG: $*"; }
function __logi() { echo "INFO: $*"; }
function __logw() { echo "WARN: $*"; }
function __loge() { echo "ERROR: $*"; }

# Define the CSV validation function locally for testing
function __validate_csv_for_enum_compatibility {
 local CSV_FILE="${1}"
 local FILE_TYPE="${2}"

 if [[ ! -f "${CSV_FILE}" ]]; then
  __loge "ERROR: CSV file not found: ${CSV_FILE}"
  return 1
 fi

 __logd "Validating CSV file for enum compatibility: ${CSV_FILE} (${FILE_TYPE})"

 case "${FILE_TYPE}" in
 "comments")
  # Validate comment events against note_event_enum
  local INVALID_LINES=0
  local LINE_NUMBER=0

  while IFS= read -r line; do
   ((LINE_NUMBER++))

   # Skip empty lines
   if [[ -z "${line}" ]]; then
    continue
   fi

   # Extract event value (3rd field)
   local EVENT
   EVENT=$(echo "${line}" | cut -d',' -f3 | tr -d '"' 2> /dev/null)

   # Check if event is empty or invalid
   if [[ -z "${EVENT}" ]]; then
    __logw "WARNING: Empty event value found in line ${LINE_NUMBER}: ${line}"
    ((INVALID_LINES++))
   elif [[ ! "${EVENT}" =~ ^(opened|closed|reopened|commented|hidden)$ ]]; then
    __logw "WARNING: Invalid event value '${EVENT}' found in line ${LINE_NUMBER}: ${line}"
    ((INVALID_LINES++))
   fi
  done < "${CSV_FILE}"

  if [[ "${INVALID_LINES}" -gt 0 ]]; then
   __loge "ERROR: Found ${INVALID_LINES} lines with invalid event values in ${CSV_FILE}"
   return 1
  fi
  ;;

 "notes")
  # Validate note status against note_status_enum
  local INVALID_LINES=0
  local LINE_NUMBER=0

  while IFS= read -r line; do
   ((LINE_NUMBER++))

   # Skip empty lines
   if [[ -z "${line}" ]]; then
    continue
   fi

   # Extract status value (6th field)
   local STATUS
   STATUS=$(echo "${line}" | cut -d',' -f6 | tr -d '"' 2> /dev/null)

   # Check if status is empty or invalid (status can be empty for open notes)
   if [[ -n "${STATUS}" ]] && [[ ! "${STATUS}" =~ ^(open|close|hidden)$ ]]; then
    __logw "WARNING: Invalid status value '${STATUS}' found in line ${LINE_NUMBER}: ${line}"
    ((INVALID_LINES++))
   fi
  done < "${CSV_FILE}"

  if [[ "${INVALID_LINES}" -gt 0 ]]; then
   __loge "ERROR: Found ${INVALID_LINES} lines with invalid status values in ${CSV_FILE}"
   return 1
  fi
  ;;

 *)
  __logw "WARNING: Unknown file type '${FILE_TYPE}', skipping enum validation"
  return 0
  ;;
 esac

 __logd "CSV enum validation passed for ${CSV_FILE}"
 return 0
}

load "${BATS_TEST_DIRNAME}/../../test_helper"

setup() {
 # Create test directory
 export TMP_DIR="$(mktemp -d)"
 TEST_DIR=$(mktemp -d "${TMP_DIR}/csv_enum_test_XXXXXX")
 export TEST_DIR
 
 # Create test CSV files
 create_test_csv_files
}

teardown() {
 # Cleanup test files
 if [[ -d "${TEST_DIR}" ]]; then
  rm -rf "${TEST_DIR}"
 fi
 if [[ -d "${TMP_DIR}" ]]; then
  rm -rf "${TMP_DIR}"
 fi
}

# Create test CSV files with various scenarios
create_test_csv_files() {
 # Valid comments CSV
 cat > "${TEST_DIR}/valid_comments.csv" << 'EOF'
123,1,"opened","2025-07-14T13:39:25Z",456,"testuser"
124,1,"commented","2025-07-14T13:45:00Z",789,"anotheruser"
125,1,"closed","2025-07-14T14:30:00Z",101,"closer"
126,1,"reopened","2025-07-14T15:00:00Z",202,"reopener"
127,1,"hidden","2025-07-14T16:00:00Z",303,"hider"
EOF

 # Invalid comments CSV with empty event
 cat > "${TEST_DIR}/invalid_comments_empty.csv" << 'EOF'
123,1,"","2025-07-14T13:39:25Z",456,"testuser"
124,1,"commented","2025-07-14T13:45:00Z",789,"anotheruser"
EOF

 # Invalid comments CSV with invalid event
 cat > "${TEST_DIR}/invalid_comments_bad_event.csv" << 'EOF'
123,1,"invalid_action","2025-07-14T13:39:25Z",456,"testuser"
124,1,"commented","2025-07-14T13:45:00Z",789,"anotheruser"
EOF

 # Valid notes CSV
 cat > "${TEST_DIR}/valid_notes.csv" << 'EOF'
123,40.4168,-3.7038,"2025-07-14T13:39:25Z",,"open",1,1
124,40.4169,-3.7039,"2025-07-14T13:45:00Z","2025-07-14T14:30:00Z","close",1,1
125,40.4170,-3.7040,"2025-07-14T15:00:00Z",,"hidden",1,1
EOF

 # Invalid notes CSV with invalid status
 cat > "${TEST_DIR}/invalid_notes_bad_status.csv" << 'EOF'
123,40.4168,-3.7038,"2025-07-14T13:39:25Z",,"invalid_status",1,1
124,40.4169,-3.7039,"2025-07-14T13:45:00Z","2025-07-14T14:30:00Z","close",1,1
EOF
}

@test "Enum validation passes for valid comments CSV" {
 run __validate_csv_for_enum_compatibility "${TEST_DIR}/valid_comments.csv" "comments"
 [ "${status}" -eq 0 ]
}

@test "Enum validation fails for comments CSV with empty event" {
 run __validate_csv_for_enum_compatibility "${TEST_DIR}/invalid_comments_empty.csv" "comments"
 [ "${status}" -eq 1 ]
 [[ "${output}" =~ "WARN] WARNING: Empty event value found" ]]
}

@test "Enum validation fails for comments CSV with invalid event" {
 run __validate_csv_for_enum_compatibility "${TEST_DIR}/invalid_comments_bad_event.csv" "comments"
 [ "${status}" -eq 1 ]
 [[ "${output}" =~ "WARN] WARNING: Invalid event value" ]]
}

@test "Enum validation passes for valid notes CSV" {
 run __validate_csv_for_enum_compatibility "${TEST_DIR}/valid_notes.csv" "notes"
 [ "${status}" -eq 0 ]
}

@test "Enum validation fails for notes CSV with invalid status" {
 run __validate_csv_for_enum_compatibility "${TEST_DIR}/invalid_notes_bad_status.csv" "notes"
 [ "${status}" -eq 1 ]
 [[ "${output}" =~ "WARN] WARNING: Invalid status value" ]]
}

@test "Enum validation handles missing files gracefully" {
 run __validate_csv_for_enum_compatibility "/nonexistent/file.csv" "comments"
 [ "${status}" -eq 1 ]
 [[ "${output}" =~ "ERROR] ERROR: CSV file not found" ]]
}

@test "Enum validation handles unknown file types" {
 run __validate_csv_for_enum_compatibility "${TEST_DIR}/valid_comments.csv" "unknown"
 [ "${status}" -eq 0 ]
 [[ "${output}" =~ "WARN] WARNING: Unknown file type" ]]
}

@test "Enum validation handles empty files" {
 # Create empty file
 touch "${TEST_DIR}/empty.csv"
 
 run __validate_csv_for_enum_compatibility "${TEST_DIR}/empty.csv" "comments"
 [ "${status}" -eq 0 ]
}

@test "Enum validation counts invalid lines correctly" {
 # Create CSV with multiple invalid lines
 cat > "${TEST_DIR}/multiple_invalid.csv" << 'EOF'
123,1,"","2025-07-14T13:39:25Z",456,"testuser"
124,1,"invalid_action","2025-07-14T13:45:00Z",789,"anotheruser"
125,1,"opened","2025-07-14T14:00:00Z",101,"validuser"
126,1,"","2025-07-14T15:00:00Z",202,"anotheruser"
EOF

 run __validate_csv_for_enum_compatibility "${TEST_DIR}/multiple_invalid.csv" "comments"
 [ "${status}" -eq 1 ]
 [[ "${output}" =~ "ERROR] ERROR: Found" ]]
} 