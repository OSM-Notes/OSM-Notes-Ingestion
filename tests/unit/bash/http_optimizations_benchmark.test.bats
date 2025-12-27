#!/usr/bin/env bats

# HTTP Optimizations Benchmark Test Suite
# Compares performance with and without HTTP optimizations
# Author: Andres Gomez (AngocA)
# Version: 2025-12-20

load "${BATS_TEST_DIRNAME}/../../test_helper"
load "${BATS_TEST_DIRNAME}/performance_benchmarks_helper.bash"
load "${BATS_TEST_DIRNAME}/../../test_helpers_common.bash"

setup() {
 # Create temporary test directory
 TEST_DIR=$(mktemp -d)
 export TEST_DIR
 export TMP_DIR="${TEST_DIR}"

 # Set up test environment variables
 export SCRIPT_BASE_DIRECTORY="${TEST_BASE_DIR}"
 export LOG_LEVEL="INFO"
 export __log_level="INFO"
 export DOWNLOAD_USER_AGENT="OSM-Notes-Ingestion-Benchmark/1.0"

 # Benchmark results directory
 BENCHMARK_RESULTS_DIR="${TEST_DIR}/benchmark_results"
 export BENCHMARK_RESULTS_DIR
 mkdir -p "${BENCHMARK_RESULTS_DIR}"

 # Load the functions to test
 if [[ -f "${TEST_BASE_DIR}/bin/lib/noteProcessingFunctions.sh" ]]; then
  source "${TEST_BASE_DIR}/bin/lib/noteProcessingFunctions.sh"
 fi

 # Setup mock logger functions
 __common_setup_mock_loggers
}

teardown() {
 # Clean up test files
 if [[ -n "${TEST_DIR:-}" ]] && [[ -d "${TEST_DIR}" ]]; then
  rm -rf "${TEST_DIR}"
 fi
}

# =============================================================================
# Benchmark: OSM API Performance
# =============================================================================

@test "BENCHMARK: OSM API with optimizations vs without" {
 # Test: Benchmark OSM API performance with and without HTTP optimizations
 # Purpose: Measure performance improvement from HTTP optimizations
 # Expected: With optimizations should be faster or equal (with network variance margin)
 # Note: This test requires network access for real benchmarks. With mocks, it verifies structure.

 # Check if network access is required (set REQUIRE_EXTERNAL_SERVICES=true for real benchmarks)
 if [[ "${REQUIRE_EXTERNAL_SERVICES:-false}" != "true" ]]; then
  # Use mocks to verify test structure works correctly
  local output_file_with="${TEST_DIR}/output_with.xml"
  local output_file_without="${TEST_DIR}/output_without.xml"
  local url="https://api.openstreetmap.org/api/0.6/notes/search.xml?limit=100"
  
  # Mock curl for OSM API calls
  __setup_mock_curl_for_api "${url}" '<?xml version="1.0"?><osm version="0.6"></osm>' 0
  
  # Test WITH optimizations
  export ENABLE_HTTP_OPTIMIZATIONS="true"
  export ENABLE_HTTP_CACHE="true"
  
  __benchmark_start "osm_api_with_optimizations"
  
  if __retry_osm_api "${url}" "${output_file_with}" 1 1 30 2>/dev/null; then
   local duration_with
   duration_with=$(__benchmark_end "osm_api_with_optimizations")
   
   __benchmark_record "http_optimizations" "osm_api_time_with" \
    "${duration_with}" "seconds"
   
   # Test WITHOUT optimizations
   export ENABLE_HTTP_OPTIMIZATIONS="false"
   export ENABLE_HTTP_CACHE="false"
   
   __benchmark_start "osm_api_without_optimizations"
   
   if __retry_osm_api "${url}" "${output_file_without}" 1 1 30 2>/dev/null; then
    local duration_without
    duration_without=$(__benchmark_end "osm_api_without_optimizations")
    
    __benchmark_record "http_optimizations" "osm_api_time_without" \
     "${duration_without}" "seconds"
    
    # Verify both requests succeeded
    [[ -f "${output_file_with}" ]]
    [[ -f "${output_file_without}" ]]
   fi
  fi
  
  rm -f "${output_file_with}" "${output_file_without}"
 else
  # Real benchmark with network access
  local output_file_with
  local output_file_without
  local url="https://api.openstreetmap.org/api/0.6/notes/search.xml?limit=100"
  
  # Test WITH optimizations
  export ENABLE_HTTP_OPTIMIZATIONS="true"
  export ENABLE_HTTP_CACHE="true"
  
  output_file_with=$(mktemp)
  __benchmark_start "osm_api_with_optimizations"
  
  if __retry_osm_api "${url}" "${output_file_with}" 1 1 30; then
   local duration_with
   duration_with=$(__benchmark_end "osm_api_with_optimizations")
   
   __benchmark_record "http_optimizations" "osm_api_time_with" \
    "${duration_with}" "seconds"
   
   # Test WITHOUT optimizations
   export ENABLE_HTTP_OPTIMIZATIONS="false"
   export ENABLE_HTTP_CACHE="false"
   
   output_file_without=$(mktemp)
   __benchmark_start "osm_api_without_optimizations"
   
   if __retry_osm_api "${url}" "${output_file_without}" 1 1 30; then
    local duration_without
    duration_without=$(__benchmark_end "osm_api_without_optimizations")
    
    __benchmark_record "http_optimizations" "osm_api_time_without" \
     "${duration_without}" "seconds"
    
    # Calculate improvement
    local improvement
    if command -v bc > /dev/null 2>&1; then
     improvement=$(echo "scale=2; (${duration_without} - ${duration_with}) / ${duration_without} * 100" | bc -l)
    else
     improvement="0"
    fi
    
    __benchmark_record "http_optimizations" "osm_api_improvement_percent" \
     "${improvement}" "percent"
    
    # Verify both requests succeeded
    [[ -f "${output_file_with}" ]]
    [[ -f "${output_file_without}" ]]
    
    # With optimizations should be faster or equal
    # Allow small margin for network variance
    local margin="0.1"
    if command -v bc > /dev/null 2>&1; then
     local diff
     diff=$(echo "${duration_without} - ${duration_with}" | bc -l)
     # Improvement should be positive (with < without) or very small negative
     [[ $(echo "${diff} > -${margin}" | bc -l) -eq 1 ]]
    fi
   fi
  fi
  
  rm -f "${output_file_with}" "${output_file_without}"
 fi
}

@test "BENCHMARK: Overpass API with optimizations vs without" {
 skip "Requires network access to Overpass API"
 
 local output_file_with
 local output_file_without
 local query="[out:json][timeout:10];node(1);out;"
 
 # Test WITH optimizations
 export ENABLE_HTTP_OPTIMIZATIONS="true"
 
 output_file_with=$(mktemp)
 __benchmark_start "overpass_api_with_optimizations"
 
 if __retry_overpass_api "${query}" "${output_file_with}" 1 1 30; then
  local duration_with
  duration_with=$(__benchmark_end "overpass_api_with_optimizations")
  
  __benchmark_record "http_optimizations" "overpass_api_time_with" \
   "${duration_with}" "seconds"
  
  # Test WITHOUT optimizations
  export ENABLE_HTTP_OPTIMIZATIONS="false"
  
  output_file_without=$(mktemp)
  __benchmark_start "overpass_api_without_optimizations"
  
  if __retry_overpass_api "${query}" "${output_file_without}" 1 1 30; then
   local duration_without
   duration_without=$(__benchmark_end "overpass_api_without_optimizations")
   
   __benchmark_record "http_optimizations" "overpass_api_time_without" \
    "${duration_without}" "seconds"
   
   # Calculate improvement
   local improvement
   if command -v bc > /dev/null 2>&1; then
    improvement=$(echo "scale=2; (${duration_without} - ${duration_with}) / ${duration_without} * 100" | bc -l)
   else
    improvement="0"
   fi
   
   __benchmark_record "http_optimizations" "overpass_api_improvement_percent" \
    "${improvement}" "percent"
   
   # Verify both requests succeeded
   [[ -f "${output_file_with}" ]]
   [[ -f "${output_file_without}" ]]
  fi
 fi
 
 rm -f "${output_file_with}" "${output_file_without}"
}

# =============================================================================
# Benchmark: Conditional Caching Performance
# =============================================================================

@test "BENCHMARK: Conditional caching performance (304 response)" {
 skip "Requires network access and server supporting conditional requests"
 
 local output_file
 local url="https://api.openstreetmap.org/api/0.6/notes/search.xml?limit=100"
 
 export ENABLE_HTTP_OPTIMIZATIONS="true"
 export ENABLE_HTTP_CACHE="true"
 
 # First request - full download
 output_file=$(mktemp)
 __benchmark_start "osm_api_first_request"
 
 if __retry_osm_api "${url}" "${output_file}" 1 1 30; then
  local duration_first
  duration_first=$(__benchmark_end "osm_api_first_request")
  
  __benchmark_record "http_optimizations" "osm_api_first_request_time" \
   "${duration_first}" "seconds"
  
  # Second request - should get 304 if server supports it
  __benchmark_start "osm_api_conditional_request"
  
  if __retry_osm_api "${url}" "${output_file}" 1 1 30; then
   local duration_conditional
   duration_conditional=$(__benchmark_end "osm_api_conditional_request")
   
   __benchmark_record "http_optimizations" "osm_api_conditional_request_time" \
    "${duration_conditional}" "seconds"
   
   # Conditional request should be faster
   if command -v bc > /dev/null 2>&1; then
    local improvement
    improvement=$(echo "scale=2; (${duration_first} - ${duration_conditional}) / ${duration_first} * 100" | bc -l)
    
    __benchmark_record "http_optimizations" "conditional_cache_improvement_percent" \
     "${improvement}" "percent"
    
    # Conditional should be faster (or equal if 304 not supported)
    [[ $(echo "${duration_conditional} <= ${duration_first}" | bc -l) -eq 1 ]]
   fi
  fi
 fi
 
 rm -f "${output_file}"
}

# =============================================================================
# Benchmark: Multiple Sequential Requests (Connection Reuse)
# =============================================================================

@test "BENCHMARK: Connection reuse performance (multiple requests)" {
 skip "Requires network access"
 
 local url="https://api.openstreetmap.org/api/0.6/notes/search.xml?limit=10"
 local num_requests=5
 local i
 
 export ENABLE_HTTP_OPTIMIZATIONS="true"
 
 # WITH optimizations - connection reuse
 __benchmark_start "multiple_requests_with_optimizations"
 
 for ((i=1; i<=num_requests; i++)); do
  local output_file
  output_file=$(mktemp -p "${TEST_DIR}" "request_${i}_XXXXXX")
  __retry_osm_api "${url}" "${output_file}" 1 1 30 > /dev/null 2>&1 || true
  rm -f "${output_file}"
 done
 
 local duration_with
 duration_with=$(__benchmark_end "multiple_requests_with_optimizations")
 
 __benchmark_record "http_optimizations" "multiple_requests_time_with" \
  "${duration_with}" "seconds"
 
 # WITHOUT optimizations
 export ENABLE_HTTP_OPTIMIZATIONS="false"
 
 __benchmark_start "multiple_requests_without_optimizations"
 
 for ((i=1; i<=num_requests; i++)); do
  local output_file
  output_file=$(mktemp -p "${TEST_DIR}" "request_${i}_XXXXXX")
  __retry_osm_api "${url}" "${output_file}" 1 1 30 > /dev/null 2>&1 || true
  rm -f "${output_file}"
 done
 
 local duration_without
 duration_without=$(__benchmark_end "multiple_requests_without_optimizations")
 
 __benchmark_record "http_optimizations" "multiple_requests_time_without" \
  "${duration_without}" "seconds"
 
 # Calculate improvement
 local improvement
 if command -v bc > /dev/null 2>&1; then
  improvement=$(echo "scale=2; (${duration_without} - ${duration_with}) / ${duration_without} * 100" | bc -l)
  
  __benchmark_record "http_optimizations" "connection_reuse_improvement_percent" \
   "${improvement}" "percent"
  
  # With connection reuse, multiple requests should be faster
  # Allow some margin for network variance
  local margin="0.05"
  [[ $(echo "${duration_with} < ${duration_without} + ${margin}" | bc -l) -eq 1 ]]
 fi
}

