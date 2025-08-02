#!/usr/bin/env bats

# Test file for CLEAN variable behavior
# Author: Andres Gomez (AngocA)
# Version: 2025-08-02

load "${BATS_TEST_DIRNAME}/../../test_helper"

setup() {
 # Create test files
 echo "test content" > /tmp/test_cleanup_file1.txt
 echo "test content" > /tmp/test_cleanup_file2.txt
 echo "test content" > /tmp/sample_validation.xml
 echo "test content" > /tmp/validation_error.log
}

teardown() {
 # Clean up test files regardless of test outcome
 rm -f /tmp/test_cleanup_file*.txt
 rm -f /tmp/sample_validation.xml
 rm -f /tmp/validation_error.log
}

@test "test __cleanup_validation_temp_files with CLEAN=true" {
 # Set CLEAN to true
 export CLEAN=true
  
 # Create a simple test script with the cleanup function
 cat > /tmp/test_cleanup_script.sh << 'EOF'
#!/bin/bash

# Mock logger functions
function __logd() { echo "DEBUG: $1"; }

# Clean up temporary files created during validation
function __cleanup_validation_temp_files() {
 # Only clean up if CLEAN is set to true
 if [[ -n "${CLEAN}" ]] && [[ "${CLEAN}" = true ]]; then
  local TEMP_FILES=(
   "/tmp/sample_validation.xml"
   "/tmp/validation_error.log"
  )
  
  for TEMP_FILE in "${TEMP_FILES[@]}"; do
   if [[ -f "${TEMP_FILE}" ]]; then
    rm -f "${TEMP_FILE}"
    __logd "Cleaned up temporary file: ${TEMP_FILE}"
   fi
  done
 else
  __logd "Skipping cleanup of temporary files (CLEAN=${CLEAN:-false})"
 fi
 
 return 0
}

# Export the function
export -f __cleanup_validation_temp_files
export -f __logd
EOF

 # Source the script
 source /tmp/test_cleanup_script.sh
  
 # Verify files exist before cleanup
 [[ -f /tmp/sample_validation.xml ]]
 [[ -f /tmp/validation_error.log ]]
  
 # Run cleanup function
 run __cleanup_validation_temp_files
 [[ "${status}" -eq 0 ]]
  
 # Verify files are cleaned up
 [[ ! -f /tmp/sample_validation.xml ]]
 [[ ! -f /tmp/validation_error.log ]]
  
 # Clean up test script
 rm -f /tmp/test_cleanup_script.sh
}

@test "test __cleanup_validation_temp_files with CLEAN=false" {
 # Set CLEAN to false
 export CLEAN=false
  
 # Create a simple test script with the cleanup function
 cat > /tmp/test_cleanup_script.sh << 'EOF'
#!/bin/bash

# Mock logger functions
function __logd() { echo "DEBUG: $1"; }

# Clean up temporary files created during validation
function __cleanup_validation_temp_files() {
 # Only clean up if CLEAN is set to true
 if [[ -n "${CLEAN}" ]] && [[ "${CLEAN}" = true ]]; then
  local TEMP_FILES=(
   "/tmp/sample_validation.xml"
   "/tmp/validation_error.log"
  )
  
  for TEMP_FILE in "${TEMP_FILES[@]}"; do
   if [[ -f "${TEMP_FILE}" ]]; then
    rm -f "${TEMP_FILE}"
    __logd "Cleaned up temporary file: ${TEMP_FILE}"
   fi
  done
 else
  __logd "Skipping cleanup of temporary files (CLEAN=${CLEAN:-false})"
 fi
 
 return 0
}

# Export the function
export -f __cleanup_validation_temp_files
export -f __logd
EOF

 # Source the script
 source /tmp/test_cleanup_script.sh
  
 # Verify files exist before cleanup
 [[ -f /tmp/sample_validation.xml ]]
 [[ -f /tmp/validation_error.log ]]
  
 # Run cleanup function
 run __cleanup_validation_temp_files
 [[ "${status}" -eq 0 ]]
 [[ "${output}" == *"Skipping cleanup of temporary files (CLEAN=false)"* ]]
  
 # Verify files are NOT cleaned up (should still exist)
 [[ -f /tmp/sample_validation.xml ]]
 [[ -f /tmp/validation_error.log ]]
  
 # Clean up test script
 rm -f /tmp/test_cleanup_script.sh
}

@test "test __cleanup_validation_temp_files with CLEAN unset" {
 # Unset CLEAN
 unset CLEAN
  
 # Create a simple test script with the cleanup function
 cat > /tmp/test_cleanup_script.sh << 'EOF'
#!/bin/bash

# Mock logger functions
function __logd() { echo "DEBUG: $1"; }

# Clean up temporary files created during validation
function __cleanup_validation_temp_files() {
 # Only clean up if CLEAN is set to true
 if [[ -n "${CLEAN}" ]] && [[ "${CLEAN}" = true ]]; then
  local TEMP_FILES=(
   "/tmp/sample_validation.xml"
   "/tmp/validation_error.log"
  )
  
  for TEMP_FILE in "${TEMP_FILES[@]}"; do
   if [[ -f "${TEMP_FILE}" ]]; then
    rm -f "${TEMP_FILE}"
    __logd "Cleaned up temporary file: ${TEMP_FILE}"
   fi
  done
 else
  __logd "Skipping cleanup of temporary files (CLEAN=${CLEAN:-false})"
 fi
 
 return 0
}

# Export the function
export -f __cleanup_validation_temp_files
export -f __logd
EOF

 # Source the script
 source /tmp/test_cleanup_script.sh
  
 # Verify files exist before cleanup
 [[ -f /tmp/sample_validation.xml ]]
 [[ -f /tmp/validation_error.log ]]
  
 # Run cleanup function
 run __cleanup_validation_temp_files
 [[ "${status}" -eq 0 ]]
 [[ "${output}" == *"Skipping cleanup of temporary files (CLEAN=false)"* ]]
  
 # Verify files are NOT cleaned up (should still exist)
 [[ -f /tmp/sample_validation.xml ]]
 [[ -f /tmp/validation_error.log ]]
  
 # Clean up test script
 rm -f /tmp/test_cleanup_script.sh
}

@test "test __cleanNotesFiles with CLEAN=true" {
 # Set CLEAN to true
 export CLEAN=true
  
 # Create test files
 echo "test content" > /tmp/test_planet_notes.xml
 echo "test content" > /tmp/test_output_notes.csv
  
 # Create a simple test script with the cleanup function
 cat > /tmp/test_cleanup_script.sh << 'EOF'
#!/bin/bash

# Mock logger functions
function __log_start() { echo "START: $1"; }
function __log_finish() { echo "FINISH: $1"; }

# Mock variables
PLANET_NOTES_FILE="/tmp/test_planet_notes"
OUTPUT_NOTES_FILE="/tmp/test_output_notes.csv"
OUTPUT_NOTE_COMMENTS_FILE="/tmp/test_output_comments.csv"
OUTPUT_TEXT_COMMENTS_FILE="/tmp/test_output_text.csv"
TMP_DIR="/tmp"

# Cleans files generated during the process.
function __cleanNotesFiles {
 __log_start
 if [[ -n "${CLEAN}" ]] && [[ "${CLEAN}" = true ]]; then
  rm -f "${PLANET_NOTES_FILE}.xml" "${OUTPUT_NOTES_FILE}" \
   "${OUTPUT_NOTE_COMMENTS_FILE}" "${OUTPUT_TEXT_COMMENTS_FILE}"
  rm -f "${TMP_DIR}"/part_country_* "${TMP_DIR}"/part_maritime_*
 fi
 __log_finish
}

# Export the function
export -f __cleanNotesFiles
export -f __log_start
export -f __log_finish
EOF

 # Source the script
 source /tmp/test_cleanup_script.sh
  
 # Verify files exist before cleanup
 [[ -f /tmp/test_planet_notes.xml ]]
 [[ -f /tmp/test_output_notes.csv ]]
  
 # Run cleanup function
 run __cleanNotesFiles
 [[ "${status}" -eq 0 ]]
  
 # Verify files are cleaned up
 [[ ! -f /tmp/test_planet_notes.xml ]]
 [[ ! -f /tmp/test_output_notes.csv ]]
  
 # Clean up test script
 rm -f /tmp/test_cleanup_script.sh
}

@test "test __cleanNotesFiles with CLEAN=false" {
 # Set CLEAN to false
 export CLEAN=false
  
 # Create test files
 echo "test content" > /tmp/test_planet_notes.xml
 echo "test content" > /tmp/test_output_notes.csv
  
 # Create a simple test script with the cleanup function
 cat > /tmp/test_cleanup_script.sh << 'EOF'
#!/bin/bash

# Mock logger functions
function __log_start() { echo "START: $1"; }
function __log_finish() { echo "FINISH: $1"; }

# Mock variables
PLANET_NOTES_FILE="/tmp/test_planet_notes"
OUTPUT_NOTES_FILE="/tmp/test_output_notes.csv"
OUTPUT_NOTE_COMMENTS_FILE="/tmp/test_output_comments.csv"
OUTPUT_TEXT_COMMENTS_FILE="/tmp/test_output_text.csv"
TMP_DIR="/tmp"

# Cleans files generated during the process.
function __cleanNotesFiles {
 __log_start
 if [[ -n "${CLEAN}" ]] && [[ "${CLEAN}" = true ]]; then
  rm -f "${PLANET_NOTES_FILE}.xml" "${OUTPUT_NOTES_FILE}" \
   "${OUTPUT_NOTE_COMMENTS_FILE}" "${OUTPUT_TEXT_COMMENTS_FILE}"
  rm -f "${TMP_DIR}"/part_country_* "${TMP_DIR}"/part_maritime_*
 fi
 __log_finish
}

# Export the function
export -f __cleanNotesFiles
export -f __log_start
export -f __log_finish
EOF

 # Source the script
 source /tmp/test_cleanup_script.sh
  
 # Verify files exist before cleanup
 [[ -f /tmp/test_planet_notes.xml ]]
 [[ -f /tmp/test_output_notes.csv ]]
  
 # Run cleanup function
 run __cleanNotesFiles
 [[ "${status}" -eq 0 ]]
  
 # Verify files are NOT cleaned up (should still exist)
 [[ -f /tmp/test_planet_notes.xml ]]
 [[ -f /tmp/test_output_notes.csv ]]
  
 # Clean up test script
 rm -f /tmp/test_cleanup_script.sh
} 