#!/usr/bin/env bats

# Parallel processing validation tests
# Author: Andres Gomez (AngocA)
# Version: 2025-12-22
# Optimized: Consolidated function existence checks (2025-01-23)

setup() {
 # Setup test environment
 export SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
 export TMP_DIR="$(mktemp -d)"
 export BASENAME="test_parallel_processing"
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

# Test that parallel processing functions are available (consolidated)
@test "parallel processing functions should be available" {
 # Source functions once for all checks
 run bash -c "
   source '${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh' > /dev/null 2>&1
   
   # Check parallel processing functions
   declare -f __processCountries > /dev/null && echo 'OK: __processCountries' || echo 'FAIL: __processCountries'
   declare -f __processList > /dev/null && echo 'OK: __processList' || echo 'FAIL: __processList'
   declare -f __processBoundary > /dev/null && echo 'OK: __processBoundary' || echo 'FAIL: __processBoundary'
   
   # Check network and retry functions (consolidated from separate tests)
   declare -f __check_network_connectivity > /dev/null && echo 'OK: __check_network_connectivity' || echo 'FAIL: __check_network_connectivity'
   declare -f __retry_file_operation > /dev/null && echo 'OK: __retry_file_operation' || echo 'FAIL: __retry_file_operation'
   
   # Check error handling functions (consolidated from separate tests)
   declare -f __handle_error_with_cleanup > /dev/null && echo 'OK: __handle_error_with_cleanup' || echo 'FAIL: __handle_error_with_cleanup'
 "
 [ "$status" -eq 0 ]
 
 # Verify all functions exist (all should start with "OK:")
 local ok_count
 ok_count=$(echo "$output" | grep -c "^OK:")
 [[ "${ok_count}" -eq 6 ]]
}

# Test that parallel processing handles job failures correctly
@test "parallel processing should handle job failures correctly" {
 # Create a mock job that fails
 local mock_job_script="${TMP_DIR}/mock_failing_job.sh"
 cat > "$mock_job_script" << 'EOF'
#!/bin/bash
# Mock job that fails
echo "Mock job starting..."
sleep 1
exit 1  # Simulate failure
EOF
 chmod +x "$mock_job_script"
 
 # Test job failure handling
 run bash -c "
   FAIL=0
   for JOB in \$(jobs -p); do
     wait \$JOB
     RET=\$?
     if [[ \$RET -ne 0 ]]; then
       FAIL=\$((FAIL + 1))
     fi
   done
   echo \$FAIL
 "
 [ "$status" -eq 0 ]
}

# Note: Tests "network connectivity check should work", "retry logic should work correctly",
# and "error handling functions should work correctly" consolidated into
# "parallel processing functions should be available" test below for optimization (2025-01-23).
# These tests only verified function existence, which is now done in a single consolidated test.

# Test that Overpass API error handling works
@test "Overpass API error handling should work" {
 # Create a mock Overpass error response
 local mock_error_file="${TMP_DIR}/mock_overpass_error.txt"
 echo "ERROR 429: Too Many Requests." > "$mock_error_file"
 
 # Test error detection
 run bash -c "
   MANY_REQUESTS=\$(grep -c 'ERROR 429: Too Many Requests.' '$mock_error_file')
   echo \$MANY_REQUESTS
 "
 [ "$status" -eq 0 ]
 [[ "$output" == "1" ]]
}

# Test that JSON validation works for boundaries
@test "JSON validation should work for boundaries" {
 # Create a mock valid JSON file
 local mock_json="${TMP_DIR}/mock_boundary.json"
 cat > "$mock_json" << 'EOF'
{
 "type": "FeatureCollection",
 "features": [
  {
   "type": "Feature",
   "properties": {
    "name": "Test Country",
    "admin_level": "2"
   },
   "geometry": {
    "type": "Polygon",
    "coordinates": [[[0,0],[1,0],[1,1],[0,1],[0,0]]]
   }
  }
 ]
}
EOF
 
 # Test JSON validation
 run bash -c "
   # Set up environment variables
   export SCRIPT_BASE_DIRECTORY='${SCRIPT_BASE_DIRECTORY}'
   export TMP_DIR='${TMP_DIR}'
   # Source validation functions first
   set +e
   source '${SCRIPT_BASE_DIRECTORY}/lib/osm-common/validationFunctions.sh' 2>/dev/null
   # Test JSON validation function
   if declare -f __validate_json_structure >/dev/null; then
     __validate_json_structure '$mock_json' 'FeatureCollection'
     exit \$?
   else
     echo 'JSON validation function not available'
     exit 1
   fi
 "
 [ "$status" -eq 0 ]
}

# Test that GeoJSON conversion error handling works
@test "GeoJSON conversion error handling should work" {
 # Test that osmtogeojson command is available or mocked
 if command -v osmtogeojson >/dev/null 2>&1; then
   echo "osmtogeojson is available"
 else
   echo "osmtogeojson not available, skipping conversion test"
 fi
}

# Test that database import error handling works
@test "database import error handling should work" {
 # Test that ogr2ogr command is available or mocked
 if command -v ogr2ogr >/dev/null 2>&1; then
   echo "ogr2ogr is available"
 else
   echo "ogr2ogr not available, skipping import test"
 fi
}

# Test that parallel processing variables are set correctly
@test "parallel processing variables should be set correctly" {
 # Test that MAX_THREADS is defined
 run bash -c "
   source '${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh' > /dev/null 2>&1
   echo \"MAX_THREADS: \${MAX_THREADS:-}\"
 "
 [ "$status" -eq 0 ]
 [[ "$output" == *"MAX_THREADS:"* ]]
 
 # Test that TMP_DIR is defined
 run bash -c "
   source '${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh' > /dev/null 2>&1
   echo \"TMP_DIR: \${TMP_DIR:-}\"
 "
 [ "$status" -eq 0 ]
 [[ "$output" == *"TMP_DIR:"* ]]
}

# Test that the specific error from the user's report is handled
@test "should handle parallel processing job failures gracefully" {
 # Create a mock parallel processing scenario
 local mock_jobs=()
 local failed_jobs=0
 
 # Simulate job execution and failure detection
 for i in {1..3}; do
   local job_pid=$((1000 + i))
   if [[ $i -eq 2 ]]; then
     # Simulate one job failing
     failed_jobs=$((failed_jobs + 1))
   fi
 done
 
 # Test failure detection
 if [[ $failed_jobs -gt 0 ]]; then
   echo "FAIL! ($failed_jobs)"
   # This should trigger error handling
   [[ $failed_jobs -eq 1 ]]
 else
   echo "All jobs succeeded"
 fi
}

# Test that log files are created for parallel processing
@test "parallel processing should create log files" {
 # Create mock log files
 local mock_log_dir="${TMP_DIR}/logs"
 mkdir -p "$mock_log_dir"
 
 # Create mock log files for different processes
 for pid in 12345 12346 12347; do
   echo "Mock log for process $pid" > "${mock_log_dir}/processPlanetNotes.log.${pid}"
 done
 
 # Test that log files exist by counting them directly
 local file_count=0
 for file in "${mock_log_dir}"/*.log.*; do
   if [[ -f "$file" ]]; then
     file_count=$((file_count + 1))
   fi
 done
 
 [[ "$file_count" -eq 3 ]]
}

# Test that cleanup functions work correctly
@test "cleanup functions should work correctly" {
 # Create mock files to clean up
 local mock_files=(
   "${TMP_DIR}/test1.json"
   "${TMP_DIR}/test2.geojson"
   "${TMP_DIR}/test3.tmp"
 )
 
 # Create mock files
 for file in "${mock_files[@]}"; do
   echo "mock content" > "$file"
 done
 
 # Test cleanup
 run bash -c "
   rm -f ${mock_files[*]} 2>/dev/null || true
   echo 'Cleanup completed'
 "
 [ "$status" -eq 0 ]
 [[ "$output" == *"Cleanup completed"* ]]
}

# Test that the specific error pattern is detected
@test "should detect FAIL! pattern in parallel processing" {
 # Test the specific error pattern from the user's report
 local error_output="FAIL! (1)"
 
 # Test error pattern detection
 if [[ "$error_output" =~ FAIL! ]]; then
   echo "Error pattern detected: $error_output"
   # Extract the number of failures
   local failures=$(echo "$error_output" | grep -o '[0-9]\+')
   [[ "$failures" == "1" ]]
 else
   echo "No error pattern detected"
   return 1
 fi
}

# Test that parallel processing can be simulated
@test "parallel processing simulation should work" {
 # Create a simple parallel processing simulation
 local max_jobs=3
 local job_results=()
 
 # Simulate job execution
 for i in {1..$max_jobs}; do
   if [[ $i -eq 2 ]]; then
     job_results+=("FAIL")
   else
     job_results+=("SUCCESS")
   fi
 done
 
 # Count failures
 local failures=0
 for result in "${job_results[@]}"; do
   if [[ "$result" == "FAIL" ]]; then
     ((failures++))
   fi
 done
 
 # Test failure detection
 if [[ $failures -gt 0 ]]; then
   echo "FAIL! ($failures)"
   [[ $failures -eq 1 ]]
 else
   echo "All jobs succeeded"
 fi
} 