#!/usr/bin/env bats

# Test parallel processing failed file generation
# Author: Andres Gomez (AngocA)
# Version: 2025-08-03

load "${BATS_TEST_DIRNAME}/../../test_helper"

setup() {
 # Load properties
 source "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh"
 source "${SCRIPT_BASE_DIRECTORY}/etc/etl.properties"
 source "${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh"
 
 # Create test directory
 export TMP_DIR="$(mktemp -d)"
 TEST_DIR=$(mktemp -d "${TMP_DIR}/parallel_failed_test_XXXXXX")
 export TEST_DIR
 
 # Create test XML parts
 create_test_xml_parts
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

# Create test XML parts
create_test_xml_parts() {
 # Create test XML parts in TMP_DIR
 for i in {1..3}; do
  cat > "${TMP_DIR}/part_${i}.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6" generator="OpenStreetMap server">
 <note id="${i}" lat="40.4168" lon="-3.7038" created_at="2025-07-14T13:39:25Z">
  <comments>
   <comment uid="456" user="testuser" action="opened" date="2025-07-14T13:39:25Z">
    Test comment ${i}
   </comment>
  </comments>
 </note>
</osm>
EOF
 done
}

# Mock processing function that always fails
mock_failing_process_function() {
 local XML_PART="${1}"
 echo "Mock function called with: ${XML_PART}"
 # Always fail
 return 1
}

# Mock processing function that sometimes fails
mock_partial_failing_process_function() {
 local XML_PART="${1}"
 echo "Mock function called with: ${XML_PART}"
 
 # Fail only for part_2.xml
 if [[ "${XML_PART}" == *"part_2.xml" ]]; then
  return 1
 fi
 return 0
}

@test "Parallel processing generates failed file when all jobs fail" {
 # Set up environment for failed file generation
 export GENERATE_FAILED_FILE=true
 export FAILED_EXECUTION_FILE="${TEST_DIR}/failed_execution.log"
 export MAX_THREADS=2
 export LOG_FILENAME="${TEST_DIR}/test.log"
 
 # Run parallel processing with failing function
 run __processXmlPartsParallel "mock_failing_process_function"
 
 # Should fail
 [ "${status}" -ne 0 ]
 
 # Check that failed execution file was created
 [ -f "${FAILED_EXECUTION_FILE}" ]
 
 # Check file content
 local FAILED_CONTENT
 FAILED_CONTENT=$(cat "${FAILED_EXECUTION_FILE}")
 [[ "${FAILED_CONTENT}" =~ "ERROR: Parallel processing failed" ]]
 [[ "${FAILED_CONTENT}" =~ "Failed jobs:" ]]
 [[ "${FAILED_CONTENT}" =~ "Failed markers found:" ]]
}

@test "Parallel processing generates failed file when some jobs fail" {
 # Set up environment for failed file generation
 export GENERATE_FAILED_FILE=true
 export FAILED_EXECUTION_FILE="${TEST_DIR}/failed_execution.log"
 export MAX_THREADS=2
 export LOG_FILENAME="${TEST_DIR}/test.log"
 
 # Run parallel processing with partially failing function
 run __processXmlPartsParallel "mock_partial_failing_process_function"
 
 # Should fail
 [ "${status}" -ne 0 ]
 
 # Check that failed execution file was created
 [ -f "${FAILED_EXECUTION_FILE}" ]
 
 # Check file content
 local FAILED_CONTENT
 FAILED_CONTENT=$(cat "${FAILED_EXECUTION_FILE}")
 [[ "${FAILED_CONTENT}" =~ "ERROR: Parallel processing failed" ]]
 [[ "${FAILED_CONTENT}" =~ "Failed jobs:" ]]
}

@test "Failed job marker files are created" {
 # Set up environment
 export GENERATE_FAILED_FILE=true
 export FAILED_EXECUTION_FILE="${TEST_DIR}/failed_execution.log"
 export MAX_THREADS=2
 export LOG_FILENAME="${TEST_DIR}/test.log"
 
 # Run parallel processing with failing function
 run __processXmlPartsParallel "mock_failing_process_function"
 
 # Should fail
 [ "${status}" -ne 0 ]
 
 # Check that job failed markers were created
 local MARKER_FILES
 MARKER_FILES=$(find "${TMP_DIR}" -name "job_failed_*" 2>/dev/null)
 [ -n "${MARKER_FILES}" ]
 
 # Check that failed job log files were created
 local FAILED_JOB_FILES
 FAILED_JOB_FILES=$(find "${TMP_DIR}" -name "failed_job_*.log" 2>/dev/null)
 [ -n "${FAILED_JOB_FILES}" ]
}

@test "Failed file is not generated when GENERATE_FAILED_FILE is false" {
 # Set up environment to NOT generate failed file
 export GENERATE_FAILED_FILE=false
 export FAILED_EXECUTION_FILE="${TEST_DIR}/failed_execution.log"
 export MAX_THREADS=2
 export LOG_FILENAME="${TEST_DIR}/test.log"
 
 # Run parallel processing with failing function
 run __processXmlPartsParallel "mock_failing_process_function"
 
 # Should fail
 [ "${status}" -ne 0 ]
 
 # Check that failed execution file was NOT created
 [ ! -f "${FAILED_EXECUTION_FILE}" ]
}

@test "Failed file contains detailed error information" {
 # Set up environment for failed file generation
 export GENERATE_FAILED_FILE=true
 export FAILED_EXECUTION_FILE="${TEST_DIR}/failed_execution.log"
 export MAX_THREADS=2
 export LOG_FILENAME="${TEST_DIR}/test.log"
 
 # Run parallel processing with failing function
 run __processXmlPartsParallel "mock_failing_process_function"
 
 # Should fail
 [ "${status}" -ne 0 ]
 
 # Check that failed execution file was created
 [ -f "${FAILED_EXECUTION_FILE}" ]
 
 # Check for specific error details
 local FAILED_CONTENT
 FAILED_CONTENT=$(cat "${FAILED_EXECUTION_FILE}")
 
 # Should contain error message
 [[ "${FAILED_CONTENT}" =~ "ERROR: Parallel processing failed" ]]
 
 # Should contain temporary directory
 [[ "${FAILED_CONTENT}" =~ "${TMP_DIR}" ]]
 
 # Should contain job details
 [[ "${FAILED_CONTENT}" =~ "Failed job details:" ]]
}

@test "Parallel processing succeeds when all jobs succeed" {
 # Mock processing function that always succeeds
 mock_successful_process_function() {
  local XML_PART="${1}"
  echo "Mock function called with: ${XML_PART}"
  return 0
 }
 
 # Set up environment
 export GENERATE_FAILED_FILE=true
 export FAILED_EXECUTION_FILE="${TEST_DIR}/failed_execution.log"
 export MAX_THREADS=2
 export LOG_FILENAME="${TEST_DIR}/test.log"
 
 # Run parallel processing with successful function
 run __processXmlPartsParallel "mock_successful_process_function"
 
 # Should succeed
 [ "${status}" -eq 0 ]
 
 # Check that failed execution file was NOT created
 [ ! -f "${FAILED_EXECUTION_FILE}" ]
} 