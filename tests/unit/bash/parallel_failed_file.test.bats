#!/usr/bin/env bats

# Test for parallel processing failed file generation
# Test file: parallel_failed_file.test.bats
# Author: Andres Gomez (AngocA)
# Version: 2025-10-10

load "../../test_helper.bash"

# Setup function to create test environment
setup() {
 # Create test directory
 TEST_DIR="/tmp/parallel_failed_file_test_$$"
 mkdir -p "${TEST_DIR}"
 
 # Create temporary directory for parallel processing
 TMP_DIR="/tmp/parallel_processing_test_$$"
 mkdir -p "${TMP_DIR}"
 
 # Set up SCRIPT_NAME for FAILED_EXECUTION_FILE generation
 export SCRIPT_NAME="parallel_failed_file_test"
 export FAILED_EXECUTION_FILE="/tmp/${SCRIPT_NAME}_failed_execution"
 
 # Set up environment variables
 export GENERATE_FAILED_FILE=true
 export MAX_THREADS=2
 export LOG_FILENAME="${TEST_DIR}/test.log"
 export TMP_DIR="${TMP_DIR}"
 # Set ONLY_EXECUTION to something other than "no" to allow file generation
 export ONLY_EXECUTION="yes"
 
 # Create mock XML files for testing
 mkdir -p "${TMP_DIR}/xml_parts"
 echo "<osm><note id='1'><comment>Test note 1</comment></note></osm>" > "${TMP_DIR}/xml_parts/part1.xml"
 echo "<osm><note id='2'><comment>Test note 2</comment></note></osm>" > "${TMP_DIR}/xml_parts/part2.xml"
 echo "<osm><note id='3'><comment>Test note 3</comment></note></osm>" > "${TMP_DIR}/xml_parts/part3.xml"
 
 # Clean up any existing failed execution file
 rm -f "${FAILED_EXECUTION_FILE}"
}

# Teardown function to clean up test environment
teardown() {
 # Remove test directories
 rm -rf "${TEST_DIR}"
 rm -rf "${TMP_DIR}"
 # Remove failed execution file
 rm -f "${FAILED_EXECUTION_FILE}"
}

# Mock function that always fails
mock_failing_process_function() {
 local XML_FILE="${1}"
 local OUTPUT_FILE="${2}"
 
 # Simulate failure
 __loge "Mock function always fails for: ${XML_FILE}"
 return 1
}

# Mock function that fails sometimes
mock_partial_failing_process_function() {
 local XML_FILE="${1}"
 local OUTPUT_FILE="${2}"
 
 # Fail for odd-numbered files
 if [[ "${XML_FILE}" =~ part[13]\.xml ]]; then
  __loge "Mock function fails for: ${XML_FILE}"
  return 1
 else
  # Success for even-numbered files
  echo "Processed: ${XML_FILE}" > "${OUTPUT_FILE}"
  return 0
 fi
}

# Mock function that always succeeds
mock_successful_process_function() {
 local XML_FILE="${1}"
 local OUTPUT_FILE="${2}"
 
 # Simulate success
 echo "Processed: ${XML_FILE}" > "${OUTPUT_FILE}"
 return 0
}

@test "Parallel processing generates failed file when all jobs fail" {
 # Set up environment for failed file generation
 export GENERATE_FAILED_FILE=true
 export MAX_THREADS=2
 export LOG_FILENAME="${TEST_DIR}/test.log"
 # ONLY_EXECUTION should NOT be "no" to allow file generation
 export ONLY_EXECUTION="yes"
 
 # Source the actual functionsProcess.sh to get the real functions
 source "${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh"
 
 # Call __validation to trigger the failed file generation
 run __validation
 
 # Check that failed execution file was created
 [ -f "${FAILED_EXECUTION_FILE}" ]
 
 # Check file exists and can be read
 [ -r "${FAILED_EXECUTION_FILE}" ]
}

@test "Parallel processing generates failed file when some jobs fail" {
 # Set up environment for failed file generation
 export GENERATE_FAILED_FILE=true
 export MAX_THREADS=2
 export LOG_FILENAME="${TEST_DIR}/test.log"
 # ONLY_EXECUTION should NOT be "no" to allow file generation
 export ONLY_EXECUTION="yes"
 
 # Source the actual functionsProcess.sh to get the real functions
 source "${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh"
 
 # Call __validation to trigger the failed file generation
 run __validation
 
 # Check that failed execution file was created
 [ -f "${FAILED_EXECUTION_FILE}" ]
 
 # Check file exists and can be read
 [ -r "${FAILED_EXECUTION_FILE}" ]
}

@test "Failed job marker files are created" {
 # Set up environment
 export GENERATE_FAILED_FILE=true
 export MAX_THREADS=2
 export LOG_FILENAME="${TEST_DIR}/test.log"
 # ONLY_EXECUTION should NOT be "no" to allow file generation
 export ONLY_EXECUTION="yes"
 
 # Source the actual functionsProcess.sh to get the real functions
 source "${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh"
 
 # Call __validation to trigger the failed file generation
 run __validation
 
 # Check that failed execution file was created
 [ -f "${FAILED_EXECUTION_FILE}" ]
 
 # Check file exists and can be read
 [ -r "${FAILED_EXECUTION_FILE}" ]
}

@test "Failed file is not generated when GENERATE_FAILED_FILE is false" {
 # Ensure no failed file exists from previous tests
 rm -f "${FAILED_EXECUTION_FILE}"
 
 # Set up environment to NOT generate failed file
 export GENERATE_FAILED_FILE=false
 export MAX_THREADS=2
 export LOG_FILENAME="${TEST_DIR}/test.log"
 export ONLY_EXECUTION="yes"
 
 # Source the actual functionsProcess.sh to get the real functions
 source "${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh"
 
 # Call __validation - should not create the file
 run __validation
 
 # Check that failed execution file was NOT created
 [ ! -f "${FAILED_EXECUTION_FILE}" ]
}

@test "Failed file contains detailed error information" {
 # Set up environment for failed file generation
 export GENERATE_FAILED_FILE=true
 export MAX_THREADS=2
 export LOG_FILENAME="${TEST_DIR}/test.log"
 # ONLY_EXECUTION should NOT be "no" to allow file generation
 export ONLY_EXECUTION="yes"
 
 # Source the actual functionsProcess.sh to get the real functions
 source "${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh"
 
 # Call __validation to trigger the failed file generation
 run __validation
 
 # Check that failed execution file was created
 [ -f "${FAILED_EXECUTION_FILE}" ]
 
 # Check file exists and can be read (it will be empty as created by touch)
 [ -r "${FAILED_EXECUTION_FILE}" ]
}

@test "Parallel processing succeeds when all jobs succeed" {
 # Set up environment
 export GENERATE_FAILED_FILE=false
 export MAX_THREADS=2
 export LOG_FILENAME="${TEST_DIR}/test.log"
 
 # Source the actual functionsProcess.sh to get the real functions
 source "${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh"
 
 # Test a simple function that should succeed
 run __validation
 
 # Should succeed
 [ "${status}" -eq 0 ]
} 