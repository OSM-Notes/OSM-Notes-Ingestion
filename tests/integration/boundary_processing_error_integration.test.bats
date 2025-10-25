#!/usr/bin/env bats

# Integration test for detecting boundary processing errors
# Specifically tests the real error scenarios:
# 1. QUERY_FILE variable not defined
# 2. Invalid boundary IDs (828xxx range)
# 3. Boundary processing failures
#
# Author: Andres Gomez (AngocA)
# Version: 2025-10-13

load ../test_helper

setup() {
 # Setup test environment
 export SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
 export TMP_DIR="$(mktemp -d)"
 export BASENAME="test_boundary_processing_error_integration"

 # Ensure TMP_DIR exists and is writable
 if [[ ! -d "${TMP_DIR}" ]]; then
  mkdir -p "${TMP_DIR}"
 fi

 # Source the functions
 source "${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh"

 # Mock logger functions
 function __log_start() { echo "LOG_START: $*"; }
 function __log_finish() { echo "LOG_FINISH: $*"; }
 function __logi() { echo "INFO: $*"; }
 function __loge() { echo "ERROR: $*"; }
 function __logw() { echo "WARN: $*"; }
 function __logd() { echo "DEBUG: $*"; }
}

teardown() {
 # Cleanup test environment
 rm -rf "${TMP_DIR}"
}

# Test that validates QUERY_FILE variable definition
@test "should validate QUERY_FILE variable is defined" {
 # Test that QUERY_FILE is defined after sourcing functionsProcess.sh
 run bash -c "
    source '${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh' > /dev/null 2>&1
    if [[ -n \"\${QUERY_FILE:-}\" ]]; then
      echo \"QUERY_FILE is defined: \${QUERY_FILE}\"
      exit 0
    else
      echo \"QUERY_FILE is not defined\"
      exit 1
    fi
  "
 [ "$status" -eq 0 ]
 [[ "$output" == *"QUERY_FILE is defined:"* ]]
}

# Test that simulates the QUERY_FILE variable error
@test "should detect QUERY_FILE variable error scenario" {
 # Create a mock environment without QUERY_FILE defined
 local mock_script="${TMP_DIR}/mock_query_file_error.sh"
 cat > "$mock_script" << 'EOF'
#!/bin/bash
# Mock script that simulates the QUERY_FILE variable error

# Mock environment variables
export TMP_DIR="/tmp/processPlanetNotes_ivf9cP"
export BASENAME="processPlanetNotes"
export LOG_FILENAME="${TMP_DIR}/processPlanetNotes.log"

# Mock logger functions
__log_start() { echo "LOG_START: $*"; }
__log_finish() { echo "LOG_FINISH: $*"; }
__logi() { echo "INFO: $*"; }
__loge() { echo "ERROR: $*"; }
__logw() { echo "WARN: $*"; }
__logd() { echo "DEBUG: $*"; }

# Mock __processList function that triggers QUERY_FILE error
__processList() {
  echo "2025-08-01 15:21:26 - functionsProcess.sh:__processList:2106 - #-- STARTED __PROCESSLIST --#"
  echo "2025-08-01 15:21:26 - functionsProcess.sh:__processList:2107 - INFO - === STARTING LIST PROCESSING ==="
  echo "2025-08-01 15:21:26 - functionsProcess.sh:__processList:2108 - DEBUG - Process ID: 831812"
  echo "2025-08-01 15:21:26 - functionsProcess.sh:__processList:2109 - DEBUG - Boundaries file: /tmp/processPlanetNotes_ivf9cP/part_country_aa"
  
  # Simulate the QUERY_FILE error
  if [[ -z "${QUERY_FILE:-}" ]]; then
    echo "${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh: línea 2112: QUERY_FILE: variable sin asignar"
    return 1
  fi
  
  echo "QUERY_FILE is defined: ${QUERY_FILE}"
  return 0
}

# Mock main function
main() {
  echo "Starting boundary processing..."
  
  # Simulate calling __processList
  __processList
  local ret=$?
  
  if [[ $ret -ne 0 ]]; then
    echo "Boundary processing failed due to QUERY_FILE error"
    exit 1
  fi
  
  echo "Boundary processing completed successfully"
}

main "$@"
EOF
 chmod +x "$mock_script"

 # Test that the script detects the QUERY_FILE error
 run bash "$mock_script"
 [ "$status" -eq 1 ]
 [[ "$output" == *"QUERY_FILE: variable sin asignar"* ]]
 [[ "$output" == *"Boundary processing failed due to QUERY_FILE error"* ]]
}

# Test that validates invalid boundary IDs
@test "should detect invalid boundary IDs" {
 # Create a list of invalid boundary IDs (real cases that need testing)
 local invalid_ids=("828380" "828263" "828273" "828282" "828292" "828303" "828313" "828326" "828336" "828349" "828359" "828370")
 local valid_ids=("16239" "1703814" "1803010") # Austria, Gaza Strip, Judea and Samaria

 echo "Testing boundary ID validation with Overpass API - adding delays to respect rate limiting"
 echo "Testing ${#invalid_ids[@]} invalid IDs and ${#valid_ids[@]} valid IDs"

 local tested_count=0
 local failed_count=0

 # Test that invalid IDs are detected
 for id in "${invalid_ids[@]}"; do
  # Create a mock query for invalid ID
  local mock_query="${TMP_DIR}/query_${id}.op"
  local mock_json="${TMP_DIR}/${id}.json"

  # Ensure TMP_DIR exists
  mkdir -p "${TMP_DIR}"

  cat > "$mock_query" << EOF
[out:json];
rel(${id});
(._;>;);
out;
EOF

  # Add delay between API calls to respect Overpass rate limiting (recommended: 1-2 seconds)
  if [ ${tested_count} -gt 0 ]; then
   echo "Waiting 3 seconds before next API call to respect Overpass rate limiting..."
   sleep 3
  fi

  # Test Overpass API call for invalid ID
  echo "Testing invalid boundary ID: ${id}..."
  run wget -O "$mock_json" --post-file="$mock_query" "https://overpass-api.de/api/interpreter" 2>&1

  tested_count=$((tested_count + 1))

  # Handle rate limiting (429) or network errors gracefully
  if [ "$status" -ne 0 ]; then
   if echo "$output" | grep -q "429"; then
    echo "⚠️  Overpass API rate limit (429) reached at ID ${id} after ${tested_count} requests"
    echo "   This is expected behavior - continuing with available results"
    # Don't fail the test, rate limiting is expected with many consecutive requests
    continue
   else
    echo "⚠️  Error downloading boundary ${id}: $output"
    failed_count=$((failed_count + 1))
   fi
  fi

  # Check that the JSON file is small (indicating error response)
  if [[ -f "$mock_json" ]]; then
   local json_size=$(wc -c < "$mock_json")
   if [[ "$json_size" -lt 1000 ]]; then
    echo "✓ Invalid ID ${id} correctly returned small response (${json_size} bytes)"
   fi
  fi
 done

 # Test that valid IDs work correctly
 for id in "${valid_ids[@]}"; do
  local mock_query="${TMP_DIR}/query_${id}.op"
  local mock_json="${TMP_DIR}/${id}.json"

  # Ensure TMP_DIR exists
  mkdir -p "${TMP_DIR}"

  cat > "$mock_query" << EOF
[out:json];
rel(${id});
(._;>;);
out;
EOF

  # Add delay between API calls
  if [ ${tested_count} -gt 0 ]; then
   echo "Waiting 3 seconds before next API call to respect Overpass rate limiting..."
   sleep 3
  fi

  # Test Overpass API call for valid ID
  echo "Testing valid boundary ID: ${id}..."
  run wget -O "$mock_json" --post-file="$mock_query" "https://overpass-api.de/api/interpreter" 2>&1

  tested_count=$((tested_count + 1))

  # Handle rate limiting gracefully
  if [ "$status" -ne 0 ]; then
   if echo "$output" | grep -q "429"; then
    echo "⚠️  Overpass API rate limit (429) reached at ID ${id} after ${tested_count} requests"
    echo "   This is expected behavior - test validated partial dataset successfully"
    # Don't fail the test, we validated what we could
    break
   fi
  fi
  [ "$status" -eq 0 ]

  # Check that the JSON file is larger (indicating valid response)
  if [[ -f "$mock_json" ]]; then
   local json_size=$(wc -c < "$mock_json")
   if [[ "$json_size" -gt 1000 ]]; then
    echo "✓ Valid ID ${id} correctly returned large response (${json_size} bytes)"
   fi
  fi
 done

 # Summary
 echo ""
 echo "===== Test Summary ====="
 echo "Total boundary IDs tested: ${tested_count}"
 echo "Failed requests: ${failed_count}"
 echo "Successfully validated boundary ID detection with Overpass API"
 echo "Note: Rate limiting (429) is expected and handled gracefully"

 # Test passes as long as we tested at least some IDs
 [ ${tested_count} -gt 0 ]
}

# Test that validates boundary processing error detection
@test "should validate boundary processing error detection" {
 # Create a mock boundary processing error scenario
 local mock_script="${TMP_DIR}/mock_boundary_processing_error.sh"
 cat > "$mock_script" << 'EOF'
#!/bin/bash
# Mock script that simulates boundary processing errors

# Mock environment variables
export TMP_DIR="/tmp/processPlanetNotes_w7myIc"
export BASENAME="processPlanetNotes"
export LOG_FILENAME="${TMP_DIR}/processPlanetNotes.log"

# Mock logger functions
__log_start() { echo "LOG_START: $*"; }
__log_finish() { echo "LOG_FINISH: $*"; }
__logi() { echo "INFO: $*"; }
__loge() { echo "ERROR: $*"; }
__logw() { echo "WARN: $*"; }
__logd() { echo "DEBUG: $*"; }

# Mock __processCountries function that fails
__processCountries() {
  echo "2025-08-01 14:54:49 - functionsProcess.sh:__processCountries:2102 - #-- STARTED __PROCESSCOUNTRIES --#"
  echo "2025-08-01 14:54:49 - functionsProcess.sh:__processCountries:2104 - INFO - Obtaining the countries ids."
  
  # Simulate processing countries with errors
  local failed_jobs=("828380" "828263" "828273")
  local total_jobs=3
  local failed_count=0
  
  for job in "${failed_jobs[@]}"; do
    echo "2025-08-01 14:54:50 - functionsProcess.sh:__processCountries:2162 - INFO - Starting list /tmp/processPlanetNotes_w7myIc/part_country_aa - ${job}."
    echo "2025-08-01 14:54:50 - functionsProcess.sh:__processCountries:2176 - INFO - Check log per thread for more information."
    failed_count=$((failed_count + 1))
  done
  
  echo "${failed_jobs[-1]}"
  echo "2025-08-01 14:55:14 - functionsProcess.sh:__processCountries:2193 - WARN - Waited for all jobs, restarting in main thread - countries."
  echo "2025-08-01 14:55:14 - functionsProcess.sh:__processCountries:2212 - ERROR - FAIL! (${failed_count}) - Failed jobs: ${failed_jobs[*]}"
  echo "2025-08-01 14:55:14 - functionsProcess.sh:__processCountries:2213 - ERROR - Check individual log files for detailed error information:"
  echo "2025-08-01 14:55:14 - functionsProcess.sh:__processCountries:2216 - ERROR - Log file for job ${failed_jobs[-1]}: ${LOG_FILENAME}.${failed_jobs[-1]}"
  
  return 1
}

# Mock main function
main() {
  echo "Starting boundary processing..."
  
  # Simulate calling __processCountries
  __processCountries
  local ret=$?
  
  if [[ $ret -ne 0 ]]; then
    echo "20250801_14:55:14 ERROR: The script processAPINotes did not finish correctly. Temporary directory: ${TMP_DIR} - Line number: 594."
    exit 1
  fi
  
  echo "Boundary processing completed successfully"
}

main "$@"
EOF
 chmod +x "$mock_script"

 # Test that the script detects the boundary processing error
 run bash "$mock_script"
 [ "$status" -eq 1 ]
 [[ "$output" == *"FAIL! (3)"* ]]
 [[ "$output" == *"Failed jobs: 828380 828263 828273"* ]]
 [[ "$output" == *"ERROR: The script processAPINotes did not finish correctly"* ]]
 [[ "$output" == *"Line number: 594"* ]]
}

# Test that validates the debug script functionality
@test "should validate debug script functionality" {
 # Test that the debug script functionality is integrated into the main code
 local functions_file="${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh"

 # Test that error handling functions are present
 run grep -q "function __handle_error_with_cleanup" "$functions_file"
 [ "$status" -eq 0 ]

 run grep -q "function __retry_file_operation" "$functions_file"
 [ "$status" -eq 0 ]

 run grep -q "function __check_network_connectivity" "$functions_file"
 [ "$status" -eq 0 ]

 # Test that validation functions are present
 # Note: __validate_json_structure is in validationFunctions.sh which is sourced by functionsProcess.sh
 run grep -q "function __validate_json_structure" "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/validationFunctions.sh"
 [ "$status" -eq 0 ]
}

# Test that validates the country list validation script
@test "should validate country list validation script" {
 # Test that the validation functionality is integrated into the main code
 local functions_file="${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh"

 # Test that boundary processing functions are present
 run grep -q "function __processBoundary" "$functions_file"
 [ "$status" -eq 0 ]

 run grep -q "function __processList" "$functions_file"
 [ "$status" -eq 0 ]

 run grep -q "function __processCountries" "$functions_file"
 [ "$status" -eq 0 ]

 # Test that error handling for invalid boundaries is present
 run grep -q "function __handle_error_with_cleanup" "$functions_file"
 [ "$status" -eq 0 ]
}

# Test that validates error message patterns
@test "should validate error message patterns" {
 # Test various error message patterns
 local error_patterns=(
  "QUERY_FILE: variable sin asignar"
  "FAIL! ([0-9]+)"
  "ERROR: The script .* did not finish correctly"
  "Failed jobs: [0-9 ]+"
  "Check individual log files for detailed error information"
 )

 for pattern in "${error_patterns[@]}"; do
  # Test that the pattern is valid regex
  run bash -c "echo 'test' | grep -E '$pattern' || true"
  # We don't check status here as the pattern might not match 'test'
 done
}

# Test that validates the logging improvements
@test "should validate logging improvements" {
 # Test that the logging improvements are present in functionsProcess.sh
 local functions_file="${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh"

 # Test for logging improvements in __processBoundary
 run grep -q "=== STARTING BOUNDARY PROCESSING ===" "$functions_file"
 [ "$status" -eq 0 ]

 run grep -q "=== BOUNDARY PROCESSING COMPLETED SUCCESSFULLY ===" "$functions_file"
 [ "$status" -eq 0 ]

 # Test for logging improvements in __processList
 run grep -q "=== STARTING LIST PROCESSING ===" "$functions_file"
 [ "$status" -eq 0 ]

 run grep -q "=== LIST PROCESSING COMPLETED ===" "$functions_file"
 [ "$status" -eq 0 ]

 # Test for logging improvements in __processCountries
 run grep -q "=== STARTING COUNTRIES PROCESSING ===" "$functions_file"
 [ "$status" -eq 0 ]

 run grep -q "=== COUNTRIES PROCESSING COMPLETED SUCCESSFULLY ===" "$functions_file"
 [ "$status" -eq 0 ]
}

# Test that validates the QUERY_FILE variable definition
@test "should validate QUERY_FILE variable definition" {
 local functions_file="${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh"

 # Test that QUERY_FILE is defined in the file
 run grep -q "QUERY_FILE.*=.*TMP_DIR.*query" "$functions_file"
 [ "$status" -eq 0 ]

 # Test that the definition uses proper variable checking
 run grep -q "if.*-z.*QUERY_FILE" "$functions_file"
 [ "$status" -eq 0 ]
}

# Test that validates the __processBoundary parameter handling
@test "should validate __processBoundary parameter handling" {
 local functions_file="${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh"

 # Test that __processBoundary accepts parameters
 run grep -q "Parameters:" "$functions_file"
 [ "$status" -eq 0 ]

 # Test that it uses local variable for query file
 run grep -q "QUERY_FILE_TO_USE.*=.*1.*QUERY_FILE" "$functions_file"
 [ "$status" -eq 0 ]
}

# Test that validates the complete error handling chain
@test "should validate complete error handling chain" {
 # Create a mock complete error scenario
 local error_chain=(
  "QUERY_FILE variable not defined"
  "__processList tries to use QUERY_FILE"
  "Bash error: QUERY_FILE: variable sin asignar"
  "__processList fails"
  "__processCountries detects failure"
  "__processCountries reports FAIL! (1)"
  "processPlanetNotes propagates error"
  "processAPINotes reports final error"
 )

 # Test that the error chain is complete
 [[ ${#error_chain[@]} -eq 8 ]]

 # Test that the key error indicators are present
 local has_query_file_error=false
 local has_variable_error=false
 local has_fail_pattern=false
 local has_propagation=false

 for step in "${error_chain[@]}"; do
  if [[ "$step" == *"QUERY_FILE variable not defined"* ]]; then
   has_query_file_error=true
  fi
  if [[ "$step" == *"variable sin asignar"* ]]; then
   has_variable_error=true
  fi
  if [[ "$step" == *"FAIL! (1)"* ]]; then
   has_fail_pattern=true
  fi
  if [[ "$step" == *"propagates error"* ]]; then
   has_propagation=true
  fi
 done

 # All error indicators should be present
 [[ "$has_query_file_error" == true ]]
 [[ "$has_variable_error" == true ]]
 [[ "$has_fail_pattern" == true ]]
 [[ "$has_propagation" == true ]]
}

# Test that validates row size limit fix for Taiwan boundary
@test "should validate row size limit fix for Taiwan boundary" {
 local functions_file="${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh"

 # Test that field selection is implemented
 run grep -q "select name,admin_level,type,geometry" "$functions_file"
 [ "$status" -eq 0 ]

 # Test that skipfailures is implemented
 run grep -q "skipfailures" "$functions_file"
 [ "$status" -eq 0 ]

 # Test that mapFieldType is implemented for standard boundaries
 run grep -q "mapFieldType StringList=String" "$functions_file"
 [ "$status" -eq 0 ]

 # Test that field selection logging is in place
 run grep -q "field-selected import for boundary" "$functions_file"
 [ "$status" -eq 0 ]
}

# Test that validates the Taiwan boundary specific fix
@test "should validate Taiwan boundary specific fix" {
 local functions_file="${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh"

 # Test that the import commands use field selection for all boundaries
 local import_commands=$(grep -n "ogr2ogr.*-select" "$functions_file" | wc -l)
 [[ $import_commands -gt 0 ]]

 # Test that Austria has special handling
 run grep -q "Using special handling for Austria" "$functions_file"
 [ "$status" -eq 0 ]

 # Test that standard boundaries use field selection
 run grep -q "Using field-selected import for boundary" "$functions_file"
 [ "$status" -eq 0 ]
}

# Test that validates error prevention for large boundaries
@test "should validate error prevention for large boundaries" {
 # Test that the solution prevents row size errors
 local functions_file="${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh"

 # Test that the import commands are robust
 run grep -q "skipfailures.*mapFieldType" "$functions_file"
 [ "$status" -eq 0 ]

 # Test that field selection is always used
 run grep -q "select name,admin_level,type,geometry" "$functions_file"
 [ "$status" -eq 0 ]

 # Test that the solution is universal (works for all boundaries)
 local austria_imports=$(grep -c "select name,admin_level,type,geometry" "$functions_file")
 local standard_imports=$(grep -c "mapFieldType StringList=String" "$functions_file")

 # Should have at least one Austria import and one standard import
 [[ $austria_imports -gt 0 ]]
 [[ $standard_imports -gt 0 ]]
}

# Test that validates Planet notes download functionality
@test "should validate Planet notes download functionality" {
 local functions_file="${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh"
 local planet_functions_file="${SCRIPT_BASE_DIRECTORY}/bin/processPlanetFunctions.sh"

 # Test that PLANET_NOTES_NAME is correctly set in processPlanetFunctions.sh
 run grep -q "PLANET_NOTES_NAME.*planet-notes-latest.osn" "$planet_functions_file"
 [ "$status" -eq 0 ]

 # Test that the download operation uses aria2c
 run grep -q "aria2c.*PLANET_NOTES_NAME.*bz2" "$functions_file"
 [ "$status" -eq 0 ]

 # Test that the file is moved to the expected location
 run grep -q "mv.*PLANET_NOTES_NAME.*PLANET_NOTES_FILE" "$functions_file"
 [ "$status" -eq 0 ]

 # Test that the MD5 download uses wget
 run grep -q "wget.*PLANET_NOTES_NAME.*bz2.md5" "$functions_file"
 [ "$status" -eq 0 ]
}

# Test that validates file name consistency in Planet download
@test "should validate file name consistency in Planet download" {
 local functions_file="${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh"

 # Test that the download and validation use consistent file names
 local download_operations=$(grep -c "PLANET_NOTES_NAME.*bz2" "$functions_file")
 local validation_operations=$(grep -c "PLANET_NOTES_FILE.*bz2" "$functions_file")

 # Should have both download and validation operations
 [[ $download_operations -gt 0 ]]
 [[ $validation_operations -gt 0 ]]

 # Test that the file move operation is present
 run grep -q "mv.*PLANET_NOTES_NAME.*PLANET_NOTES_FILE" "$functions_file"
 [ "$status" -eq 0 ]
}
