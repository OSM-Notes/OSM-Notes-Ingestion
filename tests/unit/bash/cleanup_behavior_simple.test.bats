#!/usr/bin/env bats

# Simple test file for CLEAN variable behavior
# Author: Andres Gomez (AngocA)
# Version: 2025-08-02

load "${BATS_TEST_DIRNAME}/../../test_helper"

setup() {
 # Create test files
 echo "test content" > /tmp/sample_validation.xml
 echo "test content" > /tmp/validation_error.log
}

teardown() {
 # Clean up test files regardless of test outcome
 rm -f /tmp/sample_validation.xml
 rm -f /tmp/validation_error.log
 rm -f /tmp/test_cleanup_script.sh
}

@test "test cleanup function respects CLEAN=true" {
 # Set CLEAN to true
 export CLEAN=true
  
 # Create a simple test script
 cat > /tmp/test_cleanup_script.sh << 'EOF'
#!/bin/bash

# Mock logger function
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

# Export functions
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
}

@test "test cleanup function respects CLEAN=false" {
 # Set CLEAN to false
 export CLEAN=false
  
 # Create a simple test script
 cat > /tmp/test_cleanup_script.sh << 'EOF'
#!/bin/bash

# Mock logger function
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

# Export functions
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
}

@test "test cleanup function respects CLEAN unset" {
 # Unset CLEAN
 unset CLEAN
  
 # Create a simple test script
 cat > /tmp/test_cleanup_script.sh << 'EOF'
#!/bin/bash

# Mock logger function
function __logd() { echo "DEBUG: $1"; }

# Clean up temporary files created during validation
function __cleanup_validation_temp_files() {
 # Only clean up if CLEAN is set to true
 if [[ -n "${CLEAN:-}" ]] && [[ "${CLEAN}" = true ]]; then
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

# Export functions
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
} 